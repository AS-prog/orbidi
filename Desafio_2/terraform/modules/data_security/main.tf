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
