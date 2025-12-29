"""
Cloud Function: ingest_taxis
Ingesta datos de taxis de Chicago desde BigQuery Public Dataset y los guarda como Parquet en GCS.
Usa estrategia de sharding diario (un fichero Parquet por día).

Triggers soportados:
- HTTP: GET/POST request
- Pub/Sub: CloudEvent desde Cloud Scheduler

Variables de entorno:
- GCP_PROJECT: Project ID de GCP (default: orbidi-challenge)
- GCS_BUCKET: Bucket de GCS para datos landing (default: orbidi-challenge-data-landing)
- OFFSET_DAYS: Días de offset para modo daily_offset (default: 364)

Modos de operación:
- daily_offset: Calcula la fecha a procesar basándose en la fecha actual menos OFFSET_DAYS
  Ejemplo: Si hoy es 2025-12-30 y OFFSET_DAYS=364, procesa 2024-01-01
- range: Procesa un rango de fechas

Lógica incremental:
- Verifica si la partición ya existe en GCS antes de procesar
- Si existe, omite el procesamiento (idempotente)
- Opción force=true para reprocesar
"""

import os
import json
import logging
from datetime import datetime, timedelta
from typing import List, Set

import functions_framework
from google.cloud import storage, bigquery
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
import io

# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuracion desde variables de entorno
PROJECT_ID = os.environ.get("GCP_PROJECT", "orbidi-challenge")
GCS_BUCKET = os.environ.get("GCS_BUCKET", "orbidi-challenge-data-landing")

# Offset para modo daily_offset (2025-12-29 - 730 = 2023-12-29)
OFFSET_DAYS = int(os.environ.get("OFFSET_DAYS", "730"))

# Dataset público de taxis de Chicago
PUBLIC_TAXI_TABLE = "bigquery-public-data.chicago_taxi_trips.taxi_trips"

# Ruta base para Parquet en GCS (Hive-style partitioning)
PARQUET_BASE_PATH = "taxis"

# Columnas a extraer del dataset público
TAXI_COLUMNS = [
    "unique_key",
    "taxi_id", 
    "trip_start_timestamp",
    "trip_end_timestamp",
    "trip_seconds",
    "trip_miles",
    "pickup_community_area",
    "dropoff_community_area",
    "fare",
    "tips",
    "tolls",
    "extras",
    "trip_total",
    "payment_type",
    "company",
    "pickup_latitude",
    "pickup_longitude",
    "dropoff_latitude",
    "dropoff_longitude"
]


def calculate_offset_date(offset_days: int | None = None) -> str:
    """
    Calcula la fecha objetivo basándose en la fecha actual menos el offset.

    Args:
        offset_days: Número de días a restar (default: OFFSET_DAYS)

    Returns:
        Fecha en formato YYYY-MM-DD

    Ejemplo:
        Si hoy es 2025-12-30 y offset_days=364, retorna 2024-01-01
    """
    offset = offset_days if offset_days is not None else OFFSET_DAYS
    today = datetime.now()
    target_date = today - timedelta(days=offset)
    return target_date.strftime("%Y-%m-%d")


def get_existing_dates(bucket_name: str) -> Set[str]:
    """
    Obtiene las fechas que ya existen en GCS (particiones existentes).

    Args:
        bucket_name: Nombre del bucket GCS

    Returns:
        Set de fechas en formato YYYY-MM-DD
    """
    client = storage.Client(project=PROJECT_ID)
    bucket = client.bucket(bucket_name)

    existing_dates = set()
    prefix = f"{PARQUET_BASE_PATH}/date="

    blobs = bucket.list_blobs(prefix=prefix)
    for blob in blobs:
        # Extraer fecha del path: taxis/date=2024-01-01/data.parquet
        try:
            parts = blob.name.split("/")
            for part in parts:
                if part.startswith("date="):
                    date_str = part.replace("date=", "")
                    existing_dates.add(date_str)
                    break
        except Exception:
            continue

    logger.info(f"Found {len(existing_dates)} existing taxi dates in GCS")
    return existing_dates


def get_date_range(start_date: str, end_date: str) -> List[str]:
    """
    Genera lista de fechas entre start y end.

    Args:
        start_date: Fecha inicio (YYYY-MM-DD)
        end_date: Fecha fin (YYYY-MM-DD)

    Returns:
        Lista de fechas en formato YYYY-MM-DD
    """
    start = datetime.strptime(start_date, "%Y-%m-%d")
    end = datetime.strptime(end_date, "%Y-%m-%d")

    dates = []
    current = start
    while current <= end:
        dates.append(current.strftime("%Y-%m-%d"))
        current += timedelta(days=1)

    return dates


def fetch_taxi_data_for_date(date: str) -> pd.DataFrame:
    """
    Obtiene datos de taxis del dataset público de BigQuery para una fecha específica.

    Args:
        date: Fecha (YYYY-MM-DD)

    Returns:
        DataFrame con datos de taxis de ese día
    """
    # Cliente BigQuery - lee de US (dataset público) 
    client = bigquery.Client(project=PROJECT_ID)
    
    columns_str = ", ".join(TAXI_COLUMNS)
    
    query = f"""
        SELECT {columns_str}
        FROM `{PUBLIC_TAXI_TABLE}`
        WHERE DATE(trip_start_timestamp) = '{date}'
    """
    
    logger.info(f"Querying taxi data for date: {date}")
    
    # Ejecutar query
    df = client.query(query).to_dataframe()
    
    logger.info(f"Retrieved {len(df)} taxi trips for {date}")
    
    # Añadir columna de auditoría
    df['loaded_at'] = datetime.utcnow()
    
    return df


def write_daily_parquet(df: pd.DataFrame, bucket_name: str, date: str) -> str:
    """
    Escribe DataFrame como Parquet a GCS usando particionamiento Hive.

    Args:
        df: DataFrame a escribir
        bucket_name: Nombre del bucket GCS
        date: Fecha de la partición (YYYY-MM-DD)

    Returns:
        URI completa del archivo en GCS
    """
    # Path con particionamiento Hive: taxis/date=YYYY-MM-DD/data.parquet
    blob_path = f"{PARQUET_BASE_PATH}/date={date}/data.parquet"

    # Si el DataFrame está vacío, crear archivo vacío con schema
    if df.empty:
        logger.warning(f"No taxi data for {date} - writing empty parquet with schema")
    
    # Convertir DataFrame a tabla PyArrow
    table = pa.Table.from_pandas(df)

    # Crear cliente de storage
    client = storage.Client(project=PROJECT_ID)
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(blob_path)

    # Escribir Parquet a memoria y subir
    buffer = io.BytesIO()
    pq.write_table(table, buffer)
    buffer.seek(0)

    blob.upload_from_file(buffer, content_type="application/octet-stream")

    gcs_uri = f"gs://{bucket_name}/{blob_path}"
    logger.info(f"Written parquet to {gcs_uri}")
    return gcs_uri


def process_single_date(target_date: str, force: bool = False) -> dict:
    """
    Procesa una única fecha (usado por modo daily_offset).

    Args:
        target_date: Fecha a procesar (YYYY-MM-DD)
        force: Si es True, reprocesa aunque exista

    Returns:
        Dict con resultado de la operacion
    """
    try:
        # Verificar si ya existe
        if not force:
            existing_dates = get_existing_dates(GCS_BUCKET)
            if target_date in existing_dates:
                return {
                    "status": "success",
                    "message": f"Date {target_date} already exists - skipping",
                    "target_date": target_date,
                    "processed": False,
                    "trips_count": 0
                }

        # Fetch y escribir
        logger.info(f"Processing single date: {target_date}")
        df = fetch_taxi_data_for_date(target_date)
        trips_count = len(df)
        gcs_uri = write_daily_parquet(df, GCS_BUCKET, target_date)

        return {
            "status": "success",
            "message": f"Processed {trips_count} taxi trips for {target_date}",
            "target_date": target_date,
            "gcs_uri": gcs_uri,
            "processed": True,
            "trips_count": trips_count
        }

    except Exception as e:
        logger.error(f"Error processing date {target_date}: {str(e)}")
        raise


def process_taxi_ingestion(start_date: str, end_date: str, force: bool = False) -> dict:
    """
    Proceso principal de ingestion de datos de taxis con sharding diario.
    Solo procesa fechas que no existen en GCS (incremental).

    Args:
        start_date: Fecha inicio (YYYY-MM-DD)
        end_date: Fecha fin (YYYY-MM-DD)
        force: Si es True, reprocesa todas las fechas aunque existan

    Returns:
        Dict con resultado de la operacion
    """
    try:
        # Obtener fechas existentes en GCS
        existing_dates = set() if force else get_existing_dates(GCS_BUCKET)

        # Obtener rango de fechas a procesar
        all_dates = get_date_range(start_date, end_date)

        # Filtrar solo fechas que no existen
        missing_dates = [d for d in all_dates if d not in existing_dates]

        if not missing_dates:
            return {
                "status": "success",
                "message": "No new dates to process - all data already exists",
                "date_range": {"start": start_date, "end": end_date},
                "existing_records": len(existing_dates),
                "new_records": 0
            }

        logger.info(f"Processing {len(missing_dates)} missing dates out of {len(all_dates)} total")

        # Procesar cada fecha faltante
        processed_count = 0
        total_trips = 0
        errors = []

        for date in missing_dates:
            try:
                # Fetch data for this date
                df = fetch_taxi_data_for_date(date)
                total_trips += len(df)

                # Write to GCS
                gcs_uri = write_daily_parquet(df, GCS_BUCKET, date)
                processed_count += 1

                if processed_count % 10 == 0:
                    logger.info(f"Processed {processed_count}/{len(missing_dates)} dates")

            except Exception as e:
                logger.error(f"Error processing date {date}: {str(e)}")
                errors.append({"date": date, "error": str(e)})

        result = {
            "status": "success",
            "message": f"Processed {processed_count} new daily taxi records ({total_trips} trips total)",
            "date_range": {"start": start_date, "end": end_date},
            "total_dates_in_range": len(all_dates),
            "existing_dates": len(existing_dates),
            "new_dates_processed": processed_count,
            "total_trips": total_trips,
            "gcs_path": f"gs://{GCS_BUCKET}/{PARQUET_BASE_PATH}/date=*/"
        }

        if errors:
            result["errors"] = errors
            result["status"] = "partial_success" if processed_count > 0 else "error"

        return result

    except Exception as e:
        logger.error(f"Processing error: {str(e)}")
        raise


@functions_framework.http
def ingest_taxis(request):
    """
    HTTP trigger para ingestion de datos de taxis.

    Query params opcionales:
    - mode: "daily_offset" (default) o "range"
    - start_date: Fecha inicio (YYYY-MM-DD) - solo para mode=range
    - end_date: Fecha fin (YYYY-MM-DD) - solo para mode=range
    - offset_days: Días de offset para mode=daily_offset (default: 364)
    - force: Si es "true", reprocesa aunque exista

    Ejemplos:
    - /ingest?mode=daily_offset  → Procesa fecha de hace 364 días
    - /ingest?mode=daily_offset&offset_days=365  → Procesa fecha de hace 365 días
    - /ingest?mode=range&start_date=2024-01-01&end_date=2024-01-31  → Procesa rango

    Returns:
        JSON response con resultado
    """
    try:
        # Obtener parametros del request
        mode = request.args.get("mode", "daily_offset")
        force = request.args.get("force", "").lower() == "true"

        # Si es POST, intentar leer del body
        body = {}
        if request.method == "POST":
            try:
                body = request.get_json(silent=True) or {}
                mode = body.get("mode", mode)
                force = force or body.get("force", False)
            except Exception:
                pass

        # Modo daily_offset: calcula fecha basada en offset
        if mode == "daily_offset":
            offset_days_param = request.args.get("offset_days") or body.get("offset_days")
            offset_days = int(offset_days_param) if offset_days_param else None
            target_date = calculate_offset_date(offset_days)

            logger.info(f"Mode: daily_offset, offset_days: {offset_days or OFFSET_DAYS}, target_date: {target_date}")
            result = process_single_date(target_date, force)
            result["mode"] = "daily_offset"
            result["offset_days"] = offset_days or OFFSET_DAYS
            result["execution_date"] = datetime.now().strftime("%Y-%m-%d")

        # Modo range: procesa rango de fechas
        else:
            start_date = request.args.get("start_date") or body.get("start_date")
            end_date = request.args.get("end_date") or body.get("end_date")
            
            if not start_date or not end_date:
                return json.dumps({
                    "status": "error",
                    "message": "start_date and end_date are required for range mode"
                }), 400, {"Content-Type": "application/json"}
            
            result = process_taxi_ingestion(start_date, end_date, force)
            result["mode"] = "range"

        return json.dumps(result), 200, {"Content-Type": "application/json"}

    except Exception as e:
        error_response = {"status": "error", "message": str(e)}
        logger.exception("Error in ingest_taxis")
        return json.dumps(error_response), 500, {"Content-Type": "application/json"}


@functions_framework.cloud_event
def ingest_taxis_pubsub(cloud_event):
    """
    Pub/Sub (CloudEvent) trigger para ingestion de datos de taxis.
    Usado por Cloud Scheduler.

    El mensaje puede contener:
    - mode: "daily_offset" (default) o "range"
    - start_date: Fecha inicio (YYYY-MM-DD) - solo para mode=range
    - end_date: Fecha fin (YYYY-MM-DD) - solo para mode=range
    - offset_days: Días de offset para mode=daily_offset
    - force: Si es true, reprocesa aunque exista
    """
    import base64

    try:
        # Decodificar mensaje de Pub/Sub
        data = {}
        if cloud_event.data and "message" in cloud_event.data:
            message_data = cloud_event.data["message"].get("data", "")
            if message_data:
                decoded = base64.b64decode(message_data).decode("utf-8")
                data = json.loads(decoded) if decoded else {}

        mode = data.get("mode", "daily_offset")  # Default a daily_offset para scheduler
        force = data.get("force", False)

        if mode == "daily_offset":
            offset_days = data.get("offset_days")
            target_date = calculate_offset_date(offset_days)
            logger.info(f"Pub/Sub trigger - Mode: daily_offset, target_date: {target_date}")
            result = process_single_date(target_date, force)
        else:
            start_date = data.get("start_date")
            end_date = data.get("end_date")
            if not start_date or not end_date:
                raise ValueError("start_date and end_date required for range mode")
            result = process_taxi_ingestion(start_date, end_date, force)

        logger.info(f"Pub/Sub trigger completed: {result}")

    except Exception as e:
        logger.exception(f"Error in Pub/Sub trigger: {str(e)}")
        raise