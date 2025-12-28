from google.cloud import bigquery
from google.auth import exceptions as auth_exceptions

def test_connection():
    # REEMPLAZA con tu Project ID real de la consola de GCP
    project_id = "orbidi-challenge" 
    
    try:
        # Si no pasas credenciales, busca automáticamente el archivo ADC
        client = bigquery.Client(project=project_id)
        
        print(f"🔍 Conectando a BigQuery en el proyecto: {project_id}...")
        
        # Realizamos una consulta simple que no requiere tablas existentes
        query = "SELECT 'Conexión Exitosa' as estado, 1 as test"
        query_job = client.query(query)
        results = query_job.result()
        
        for row in results:
            print(f"✅ Resultado: {row.estado} (valor: {row.test})")

    except auth_exceptions.DefaultCredentialsError:
        print("❌ ERROR: No se encontraron credenciales ADC.")
        print("Ejecuta: gcloud auth application-default login")
    except Exception as e:
        print(f"❌ ERROR inesperado: {e}")

if __name__ == "__main__":
    test_connection()