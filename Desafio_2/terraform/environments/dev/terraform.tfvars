project_id        = "orbidi-challenge"
region            = "europe-west1"   # Cambiamos Madrid por Bélgica para compatibilidad
bigquery_location = "EU"
weather_schedule  = "0 2 * * *"

# ==============================================================================
# Data Security - Access Control
# ==============================================================================

# Usuarios con acceso COMPLETO (incluye payment_type)
payment_data_readers = [
  "user:andresrsotelo@gmail.com"
]

# Usuarios con acceso GENERAL (pueden consultar pero NO ven payment_type)
bigquery_data_viewers = [
  "user:estefaniacanon@gmail.com",
  "user:cristina.delpuerto@orbidi.com",
  "user:felipe.bereilh@orbidi.com"
]

# Enmascaramiento de datos (opcional)
enable_payment_masking = false

# ==============================================================================
# CI/CD - GitHub Actions
# ==============================================================================
create_github_actions_key = true  # Genera archivo github-actions-key.json