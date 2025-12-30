# ==============================================================================
# CI/CD Module - Outputs
# ==============================================================================

output "service_account_email" {
  description = "Email of the GitHub Actions service account"
  value       = google_service_account.github_actions.email
}

output "service_account_id" {
  description = "ID of the GitHub Actions service account"
  value       = google_service_account.github_actions.id
}

output "key_file_path" {
  description = "Path to the service account key file (if created)"
  value       = var.create_key ? var.key_output_path : null
}

output "key_secret_data" {
  description = "Base64 encoded key for GitHub secret (sensitive)"
  value       = var.create_key ? google_service_account_key.github_actions_key[0].private_key : null
  sensitive   = true
}
