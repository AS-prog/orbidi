"""
Cloud Function: ingest_weather
Ingesta datos climaticos de Chicago desde Open-Meteo API y los guarda como Parquet en GCS.
Usa estrategia de sharding diario (un fichero Parquet por día).

Triggers soportados:
- HTTP: GET/POST request
- Pub/Sub: CloudEvent desde Cloud Scheduler

Variables de entorno:
- GCP_PROJECT: Project ID de GCP (default: orbidi-challenge)
- GCS_BUCKET: Bucket de GCS para datos landing (default: orbidi-challenge-data-landing)
- WEATHER_START_DATE: Fecha inicio (default: 2023-06-01)
- WEATHER_END_DATE: Fecha fin (default: 2023-12-31)
- OFFSET_DAYS: Días de offset para modo daily_offset (default: 364)

Modos de operación:
- range: Procesa un rango de fechas (default)
- daily_offset: Calcula la fecha a procesar basándose en la fecha actual menos OFFSET_DAYS
  Ejemplo: Si hoy es 2025-12-30 y OFFSET_DAYS=364, procesa 2024-01-01
"""

import os
import json
import logging
from datetime import datetime, timedelta
from typing import List, Set

import functions_framework
from google.cloud import storage
import requests
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
DEFAULT_START_DATE = os.environ.get("WEATHER_START_DATE", "2023-06-01")
DEFAULT_END_DATE = os.environ.get("WEATHER_END_DATE", "2023-12-31")

# Offset para modo daily_offset (2025-12-29 - 730 = 2023-12-29)
OFFSET_DAYS = int(os.environ.get("OFFSET_DAYS", "730"))

# Coordenadas de Chicago
CHICAGO_LAT = 41.8781
CHICAGO_LON = -87.6298

# Open-Meteo API
OPEN_METEO_URL = "https://archive-api.open-meteo.com/v1/archive"

# Ruta base para Parquet en GCS (Hive-style partitioning)
PARQUET_BASE_PATH = "weather"


def calculate_offset_date(offset_days: int = None) -> str:
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
        # Extraer fecha del path: weather/date=2023-06-01/data.parquet
        try:
            parts = blob.name.split("/")
            for part in parts:
                if part.startswith("date="):
                    date_str = part.replace("date=", "")
                    existing_dates.add(date_str)
                    break
        except Exception:
            continue

    logger.info(f"Found {len(existing_dates)} existing dates in GCS")
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


def fetch_weather_for_date(date: str) -> pd.DataFrame:
    """
    Obtiene datos climaticos de Open-Meteo API para una fecha específica.

    Args:
        date: Fecha (YYYY-MM-DD)

    Returns:
        DataFrame con datos climaticos de ese día
    """
    params = {
        "latitude": CHICAGO_LAT,
        "longitude": CHICAGO_LON,
        "start_date": date,
        "end_date": date,
        "daily": [
            "temperature_2m_max",
            "temperature_2m_min",
            "temperature_2m_mean",
            "precipitation_sum",
            "rain_sum",
            "snowfall_sum",
            "wind_speed_10m_max",
            "wind_gusts_10m_max",
            "weather_code"
        ],
        "timezone": "America/Chicago"
    }

    response = requests.get(OPEN_METEO_URL, params=params, timeout=60)
    response.raise_for_status()

    data = response.json()["daily"]
    df = pd.DataFrame(data)

    # Renombrar columnas para coincidir con schema de BigQuery
    df = df.rename(columns={
        "time": "date",
        "temperature_2m_max": "temperature_max",
        "temperature_2m_min": "temperature_min",
        "temperature_2m_mean": "temperature_mean",
        "wind_speed_10m_max": "wind_speed_max",
        "wind_gusts_10m_max": "wind_gusts_max"
    })

    # Convertir tipos
    df['date'] = pd.to_datetime(df['date']).dt.date
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
    # Path con particionamiento Hive: weather/date=YYYY-MM-DD/data.parquet
    blob_path = f"{PARQUET_BASE_PATH}/date={date}/data.parquet"

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
                    "processed": False
                }

        # Fetch y escribir
        logger.info(f"Processing single date: {target_date}")
        df = fetch_weather_for_date(target_date)
        gcs_uri = write_daily_parquet(df, GCS_BUCKET, target_date)

        return {
            "status": "success",
            "message": f"Processed weather data for {target_date}",
            "target_date": target_date,
            "gcs_uri": gcs_uri,
            "processed": True
        }

    except Exception as e:
        logger.error(f"Error processing date {target_date}: {str(e)}")
        raise


def process_weather_ingestion(start_date: str = None, end_date: str = None, force: bool = False) -> dict:
    """
    Proceso principal de ingestion de datos climaticos con sharding diario.
    Solo procesa fechas que no existen en GCS (incremental).

    Args:
        start_date: Fecha inicio (opcional, usa default)
        end_date: Fecha fin (opcional, usa default)
        force: Si es True, reprocesa todas las fechas aunque existan

    Returns:
        Dict con resultado de la operacion
    """
    start = start_date or DEFAULT_START_DATE
    end = end_date or DEFAULT_END_DATE

    try:
        # Obtener fechas existentes en GCS
        existing_dates = set() if force else get_existing_dates(GCS_BUCKET)

        # Obtener rango de fechas a procesar
        all_dates = get_date_range(start, end)

        # Filtrar solo fechas que no existen
        missing_dates = [d for d in all_dates if d not in existing_dates]

        if not missing_dates:
            return {
                "status": "success",
                "message": "No new dates to process - all data already exists",
                "date_range": {"start": start, "end": end},
                "existing_records": len(existing_dates),
                "new_records": 0
            }

        logger.info(f"Processing {len(missing_dates)} missing dates out of {len(all_dates)} total")

        # Procesar cada fecha faltante
        processed_count = 0
        errors = []

        for date in missing_dates:
            try:
                # Fetch data for this date
                df = fetch_weather_for_date(date)

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
            "message": f"Processed {processed_count} new daily weather records",
            "date_range": {"start": start, "end": end},
            "total_dates_in_range": len(all_dates),
            "existing_dates": len(existing_dates),
            "new_dates_processed": processed_count,
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
def ingest_weather(request):
    """
    HTTP trigger para ingestion de datos climaticos.

    Query params opcionales:
    - mode: "range" (default) o "daily_offset"
    - start_date: Fecha inicio (YYYY-MM-DD) - solo para mode=range
    - end_date: Fecha fin (YYYY-MM-DD) - solo para mode=range
    - offset_days: Días de offset para mode=daily_offset (default: 364)
    - force: Si es "true", reprocesa aunque exista

    Ejemplos:
    - /ingest?mode=daily_offset  → Procesa fecha de hace 364 días
    - /ingest?mode=daily_offset&offset_days=365  → Procesa fecha de hace 365 días
    - /ingest?start_date=2024-01-01&end_date=2024-01-31  → Procesa rango

    Returns:
        JSON response con resultado
    """
    try:
        # Obtener parametros del request
        mode = request.args.get("mode", "range")
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
            result = process_weather_ingestion(start_date, end_date, force)
            result["mode"] = "range"

        return json.dumps(result), 200, {"Content-Type": "application/json"}

    except Exception as e:
        error_response = {"status": "error", "message": str(e)}
        logger.exception("Error in ingest_weather")
        return json.dumps(error_response), 500, {"Content-Type": "application/json"}


@functions_framework.cloud_event
def ingest_weather_pubsub(cloud_event):
    """
    Pub/Sub (CloudEvent) trigger para ingestion de datos climaticos.
    Usado por Cloud Scheduler.

    El mensaje puede contener:
    - mode: "range" o "daily_offset"
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
            result = process_weather_ingestion(start_date, end_date, force)

        logger.info(f"Pub/Sub trigger completed: {result}")

    except Exception as e:
        logger.exception(f"Error in Pub/Sub trigger: {str(e)}")
        raise
