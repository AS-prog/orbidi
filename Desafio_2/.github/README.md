# CI/CD Setup - GitHub Actions

## Workflows

| Workflow | Trigger | Acciones |
|----------|---------|----------|
| `terraform.yml` | PR con cambios en `terraform/` | fmt, validate |
| `cloud-functions.yml` | PR con cambios en `src/` | ruff lint |
| `dbt.yml` | PR + merge a main en `dbt/` | compile, test, run |

## Configuración Requerida

### 1. Crear Service Account en GCP

```bash
# Crear SA
gcloud iam service-accounts create github-actions-sa \
  --display-name="GitHub Actions CI/CD" \
  --project=orbidi-challenge

# Asignar roles necesarios
SA_EMAIL="github-actions-sa@orbidi-challenge.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding orbidi-challenge \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/bigquery.admin"

gcloud projects add-iam-policy-binding orbidi-challenge \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding orbidi-challenge \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/datacatalog.categoryFineGrainedReader"

# Crear key JSON
gcloud iam service-accounts keys create ~/github-actions-key.json \
  --iam-account="${SA_EMAIL}"
```

### 2. Agregar Secret en GitHub

1. Ve a tu repositorio en GitHub
2. Settings → Secrets and variables → Actions
3. New repository secret:
   - **Name:** `GCP_SA_KEY`
   - **Value:** Contenido del archivo `~/github-actions-key.json`

### 3. Crear Environment "production" (opcional)

Para proteger el deploy de dbt:

1. Settings → Environments → New environment
2. Name: `production`
3. Configurar:
   - Required reviewers: tu usuario
   - Wait timer: 0 (o el tiempo que prefieras)

## Ejecución Manual de dbt

Puedes ejecutar dbt manualmente desde GitHub:

1. Actions → dbt → Run workflow
2. Seleccionar `run_models: true`

## Diagrama de Flujo

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   PR abre   │────►│  Validación │────►│  PR Review  │
└─────────────┘     └─────────────┘     └─────────────┘
                          │
                          ▼
                    ┌─────────────┐
                    │ terraform   │ fmt, validate
                    │ cloud-func  │ ruff lint
                    │ dbt         │ compile, test
                    └─────────────┘
                          │
                          ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Merge PR   │────►│ dbt deploy  │────►│ Policy Tags │
└─────────────┘     └─────────────┘     └─────────────┘
                    (environment:
                     production)
```

## Notas

- **Terraform apply** se ejecuta localmente (POC)
- **Cloud Functions** se despliegan via Terraform local
- **dbt** puede ejecutarse en CI/CD ya que solo consume BigQuery
