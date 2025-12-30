# ==============================================================================
# Data Security Module - Column-Level Security with Policy Tags
# ==============================================================================
# Implementa seguridad a nivel de columna usando Data Catalog Policy Tags
# ==============================================================================

# ------------------------------------------------------------------------------
# Taxonomy: Contenedor de Policy Tags
# ------------------------------------------------------------------------------
resource "google_data_catalog_taxonomy" "main" {
  project      = var.project_id
  # Para BigQuery multi-región (EU/US), el taxonomy debe estar en la misma multi-región
  region       = lower(var.bigquery_location)
  display_name = var.taxonomy_name
  description  = "Taxonomy para clasificación de datos sensibles - ${var.project_id}"

  activated_policy_types = ["FINE_GRAINED_ACCESS_CONTROL"]
}

# ------------------------------------------------------------------------------
# Policy Tag: Datos de Pago (payment_type)
# ------------------------------------------------------------------------------
resource "google_data_catalog_policy_tag" "payment_data" {
  taxonomy     = google_data_catalog_taxonomy.main.id
  display_name = "payment_data"
  description  = "Datos sensibles relacionados con métodos de pago. Requiere autorización para acceder."
}

# ------------------------------------------------------------------------------
# IAM: Roles para acceso a datos protegidos
# ------------------------------------------------------------------------------

# Rol para usuarios que pueden ver datos de pago (Fine Grained Reader)
resource "google_data_catalog_policy_tag_iam_member" "payment_readers" {
  for_each = toset(var.payment_data_readers)

  policy_tag = google_data_catalog_policy_tag.payment_data.name
  role       = "roles/datacatalog.categoryFineGrainedReader"
  member     = each.value
}

# ------------------------------------------------------------------------------
# Data Policy: Enmascaramiento de datos (opcional)
# ------------------------------------------------------------------------------
resource "google_bigquery_datapolicy_data_policy" "payment_masking" {
  count = var.enable_data_masking ? 1 : 0

  project          = var.project_id
  location         = var.bigquery_location
  data_policy_id   = "payment_type_masking"
  policy_tag       = google_data_catalog_policy_tag.payment_data.name
  data_policy_type = "DATA_MASKING_POLICY"

  data_masking_policy {
    predefined_expression = "DEFAULT_MASKING_VALUE"
  }
}

# ------------------------------------------------------------------------------
# IAM: BigQuery Data Viewers (acceso general sin columnas protegidas)
# ------------------------------------------------------------------------------

# Job User - permite ejecutar queries
resource "google_project_iam_member" "bigquery_job_user" {
  for_each = toset(var.bigquery_data_viewers)

  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = each.value
}

# Data Viewer en analytics dataset
resource "google_bigquery_dataset_iam_member" "analytics_viewer" {
  for_each = toset(var.bigquery_data_viewers)

  project    = var.project_id
  dataset_id = "analytics"
  role       = "roles/bigquery.dataViewer"
  member     = each.value
}

# Data Viewer en silver_data dataset
resource "google_bigquery_dataset_iam_member" "silver_viewer" {
  for_each = toset(var.bigquery_data_viewers)

  project    = var.project_id
  dataset_id = "silver_data"
  role       = "roles/bigquery.dataViewer"
  member     = each.value
}

# ------------------------------------------------------------------------------
# BigQuery Per-User Quotas (2GB/día por defecto)
# ------------------------------------------------------------------------------
# NOTA: Las cuotas por usuario se configuran via gcloud.
# Este recurso ejecuta el comando para establecer el límite.
# ------------------------------------------------------------------------------

locals {
  # Convertir GB a bytes (2GB = 2 * 1024^3 = 2147483648 bytes)
  quota_bytes = var.bigquery_daily_quota_gb * 1024 * 1024 * 1024

  # Extraer emails de los members (quitar prefijo "user:")
  viewer_emails = [
    for member in var.bigquery_data_viewers :
    trimprefix(member, "user:")
    if startswith(member, "user:")
  ]
}

resource "null_resource" "bigquery_user_quotas" {
  for_each = toset(local.viewer_emails)

  triggers = {
    user_email  = each.value
    quota_bytes = local.quota_bytes
    project_id  = var.project_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Configurando cuota de ${var.bigquery_daily_quota_gb}GB/día para ${each.value}..."
      gcloud alpha bq update-per-user-quota \
        --project=${var.project_id} \
        --user=${each.value} \
        --custom-quota=${local.quota_bytes} \
        2>/dev/null || echo "NOTA: Requiere gcloud alpha. Ejecutar manualmente si falla."
    EOT
  }

  depends_on = [google_project_iam_member.bigquery_job_user]
}
