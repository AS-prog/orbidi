# Resumen de Sesión - CI/CD y Seguridad

**Fecha:** 2025-12-30
**Proyecto:** Orbidi Technical Challenge - Chicago Taxi & Weather Analysis
**Objetivo:** Implementar CI/CD, control de acceso y optimizaciones

---

## Trabajo Realizado

### 1. CI/CD con GitHub Actions

Se implementaron 3 workflows separados por tecnología:

| Workflow | Archivo | Trigger | Acciones |
|----------|---------|---------|----------|
| **Terraform** | `.github/workflows/terraform.yml` | PR a main | `fmt -check`, `validate` |
| **Cloud Functions** | `.github/workflows/cloud-functions.yml` | PR a main | `ruff lint` |
| **dbt** | `.github/workflows/dbt.yml` | PR + merge a main | `compile`, `test`, `run` |

**Archivos creados:**
- `.github/workflows/terraform.yml`
- `.github/workflows/cloud-functions.yml`
- `.github/workflows/dbt.yml`
- `.github/README.md` - Instrucciones de configuración

### 2. Service Account para GitHub Actions

Se creó módulo Terraform para gestionar la SA de CI/CD:

```
terraform/modules/cicd/
├── main.tf       # SA + IAM roles + key generation
├── variables.tf  # Configuración
└── outputs.tf    # SA email y key path
```

**Service Account creada:**
- Email: `github-actions-sa@orbidi-challenge.iam.gserviceaccount.com`
- Roles:
  - `roles/bigquery.admin`
  - `roles/storage.admin`
  - `roles/datacatalog.categoryFineGrainedReader`

**Key generada:** `terraform/environments/dev/github-actions-key.json`

### 3. Control de Acceso a Datos

#### Usuarios Configurados

| Usuario | Acceso | Cuota BigQuery |
|---------|--------|----------------|
| `andresrsotelo@gmail.com` | Completo (incluye `payment_type`) | Sin límite |
| `estefaniacanon@gmail.com` | General (sin `payment_type`) | 2 GB/día |

#### Nuevas Variables Terraform

```hcl
# terraform/environments/dev/terraform.tfvars

payment_data_readers = [
  "user:andresrsotelo@gmail.com"
]

bigquery_data_viewers = [
  "user:estefaniacanon@gmail.com"
]
```

#### Módulo data_security Actualizado

- Agregada variable `bigquery_data_viewers` para usuarios con acceso limitado
- IAM bindings para datasets `analytics` y `silver_data`
- Cuotas por usuario via `null_resource` con gcloud

### 4. Modelos dbt Incrementales

Se convirtieron los modelos principales a incrementales para reducir costos:

| Modelo | Antes | Después | Estrategia |
|--------|-------|---------|------------|
| `silver_taxis` | `table` | `incremental` | `insert_overwrite` |
| `taxis_weather_enriched` | `table` | `incremental` | `insert_overwrite` |

**Configuración:**
```sql
{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        partition_by={"field": "date", "data_type": "date"},
        on_schema_change='append_new_columns'
    )
}}

-- Filtro incremental
{% if is_incremental() %}
where date > (select max(date) from {{ this }})
{% endif %}
```

**Ahorro estimado:**
- Full refresh: ~2.7 GiB procesados
- Incremental (1 día): ~15-20 MiB procesados

### 5. Scripts de Automatización

**Nuevos scripts creados:**

| Script | Propósito |
|--------|-----------|
| `scripts/run_dbt_pipeline.sh` | Ejecuta dbt run + test + policy tags |
| `scripts/set_bigquery_quotas.sh` | Configura cuotas por usuario |

### 6. Vista Agregada para Looker Studio

Se creó `analytics.vw_trips_weather_summary` para responder la pregunta del alcalde:

> "¿Afectan las condiciones climáticas a la duración de los viajes en taxi?"

**Hallazgo preliminar:**
- Con condiciones adversas: 513K viajes, 21.50 min promedio
- Sin condiciones adversas: 2.95M viajes, 21.58 min promedio

---

## Estructura Final del Proyecto

```
Desafio_2/
├── .github/
│   ├── README.md
│   └── workflows/
│       ├── terraform.yml
│       ├── cloud-functions.yml
│       └── dbt.yml
├── terraform/
│   ├── environments/dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars
│   │   └── github-actions-key.json  # .gitignore
│   └── modules/
│       ├── bigquery/
│       ├── cloud_functions/
│       ├── cloud_scheduler/
│       ├── data_security/
│       └── cicd/                    # NUEVO
├── dbt/
│   ├── models/
│   │   ├── staging/
│   │   ├── silver/
│   │   └── analytics/
│   └── cloudbuild.yaml              # NUEVO
├── src/
│   ├── ingest_weather/
│   └── ingest_taxis/
├── scripts/
│   ├── apply_policy_tags.sh
│   ├── run_dbt_pipeline.sh          # NUEVO
│   └── set_bigquery_quotas.sh       # NUEVO
└── docs/
    ├── SESSION_SUMMARY_2025-12-29.md
    ├── SESSION_SUMMARY_2025-12-29_dbt.md
    └── SESSION_SUMMARY_2025-12-30_cicd.md  # ESTE ARCHIVO
```

---

## Comandos Útiles

### CI/CD
```bash
# Ver key de GitHub Actions
cat terraform/environments/dev/github-actions-key.json

# Regenerar key si es necesario
terraform apply -replace="module.cicd.google_service_account_key.github_actions_key[0]"
```

### dbt Incremental
```bash
# Ejecución incremental (por defecto)
uv run dbt run --profiles-dir .

# Forzar full refresh
uv run dbt run --full-refresh --profiles-dir .
```

### Permisos
```bash
# Ver usuarios con acceso a payment_type
gcloud data-catalog taxonomies policy-tags get-iam-policy \
  projects/orbidi-challenge/locations/eu/taxonomies/695482576383744880/policyTags/7669445918618705383

# Configurar cuotas manualmente (si gcloud alpha no disponible)
./scripts/set_bigquery_quotas.sh
```

---

## Estado Final

✅ CI/CD con GitHub Actions (3 workflows)
✅ Service Account para GitHub Actions con key
✅ Control de acceso diferenciado por usuario
✅ Cuotas BigQuery por usuario (2 GB/día)
✅ Modelos dbt incrementales (ahorro ~99% en ejecución diaria)
✅ Scripts de automatización
✅ Vista agregada para Looker Studio
