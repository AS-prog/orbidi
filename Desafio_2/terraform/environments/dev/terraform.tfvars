project_id        = "orbidi-challenge"
region            = "europe-west1"   # Cambiamos Madrid por Bélgica para compatibilidad
bigquery_location = "EU"
weather_schedule  = "0 2 * * *"

# Data Security - Column-Level Access Control
payment_data_readers = [
  "user:andresrsotelo@gmail.com"  # Usuario con acceso a columna payment_type
]
enable_payment_masking = false  # Cambiar a true para enmascarar datos a usuarios sin acceso