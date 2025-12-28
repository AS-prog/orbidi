import functions_framework
from google.cloud import bigquery
import pandas as pd

@functions_framework.http
def ingest_taxis(request):
    project_id = "orbidi-challenge"
    # IMPORTANTE: El cliente debe saber que leerá de US y escribirá en EU
    client = bigquery.Client(project=project_id)
    
    destination_table = f"{project_id}.raw_data.taxi_trips"
    public_table = "bigquery-public-data.chicago_taxi_trips.taxi_trips"

    # Limitamos columnas y filas para no saturar la memoria local
    query = f"""
        SELECT 
            unique_key, taxi_id, trip_start_timestamp, trip_end_timestamp,
            trip_seconds, trip_miles, pickup_community_area, dropoff_community_area,
            fare, tips, tolls, extras, trip_total, payment_type, company,
            pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude
        FROM `{public_table}`
        WHERE trip_start_timestamp >= '2023-06-01'
          AND trip_start_timestamp <= '2023-12-31'
        LIMIT 100000 
    """

    try:
        print(f"🚕 Extrayendo datos desde US (Dataset Público)...")
        # Bajamos los datos a la memoria de tu Mac
        df = client.query(query).to_dataframe()
        
        print(f"✅ Datos descargados ({len(df)} filas). Preparando carga en EU...")
        
        # Añadimos la columna de auditoría
        df['loaded_at'] = pd.Timestamp.now()

        # Configuración de carga para tu tabla en EU
        job_config = bigquery.LoadJobConfig(
            write_disposition="WRITE_TRUNCATE",
        )

        # Subimos los datos a tu dataset en orbidi-challenge (EU)
        job = client.load_table_from_dataframe(df, destination_table, job_config=job_config)
        job.result() 

        return {
            "status": "success",
            "message": f"Se movieron {len(df)} viajes de taxi de US a EU correctamente",
        }, 200

    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return {"status": "error", "message": str(e)}, 500