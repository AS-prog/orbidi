import functions_framework
from google.cloud import bigquery
import requests
import pandas as pd
from datetime import datetime

@functions_framework.http
def ingest_weather(request):
    # FORZAMOS el Project ID correcto aquí
    project_id = "orbidi-challenge" 
    client = bigquery.Client(project=project_id)
    
    dataset_id = "raw_data"
    table_id = "weather_daily"
    table_ref = f"{project_id}.{dataset_id}.{table_id}"

    url = "https://archive-api.open-meteo.com/v1/archive"
    params = {
        "latitude": 41.87,
        "longitude": -87.62,
        "start_date": "2023-06-01", 
        "end_date": "2023-12-31",
        "daily": [
            "temperature_2m_max", "temperature_2m_min", "temperature_2m_mean",
            "precipitation_sum", "rain_sum", "snowfall_sum",
            "wind_speed_10m_max", "wind_gusts_10m_max", "weather_code"
        ],
        "timezone": "America/Chicago"
    }

    try:
        print(f"📡 Solicitando datos a Open-Meteo...")
        response = requests.get(url, params=params, timeout=30)
        response.raise_for_status()
        data = response.json()["daily"]
        
        df = pd.DataFrame(data)
        df = df.rename(columns={
            "time": "date",
            "temperature_2m_max": "temperature_max",
            "temperature_2m_min": "temperature_min",
            "temperature_2m_mean": "temperature_mean",
            "wind_speed_10m_max": "wind_speed_max",
            "wind_gusts_10m_max": "wind_gusts_max"
        })
        
        df['date'] = pd.to_datetime(df['date']).dt.date
        df['loaded_at'] = datetime.utcnow()

        # Configuración de carga
        job_config = bigquery.LoadJobConfig(
            write_disposition="WRITE_TRUNCATE",
        )

        print(f"📤 Cargando a BigQuery proyecto: {project_id}...")
        job = client.load_table_from_dataframe(df, table_ref, job_config=job_config)
        job.result() 

        return {"status": "success", "message": f"Cargados {len(df)} registros"}, 200

    except Exception as e:
        print(f"❌ Error detalle: {str(e)}")
        return {"status": "error", "message": str(e)}, 500