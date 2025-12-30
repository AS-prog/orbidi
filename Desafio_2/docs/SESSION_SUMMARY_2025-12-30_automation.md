# Resumen de Sesión - Automatización dbt Post-Ingesta

**Fecha:** 2025-12-30
**Proyecto:** Orbidi Technical Challenge - Chicago Taxi & Weather Analysis
**Objetivo:** Implementar automatización de dbt después de la ingesta de datos

---

## Trabajo Realizado

### 1. Módulo Terraform `cloud_build`

Se creó un nuevo módulo para automatizar la ejecución de dbt:

```
terraform/modules/cloud_build/
├── main.tf       # SA + Cloud Build Trigger + Cloud Scheduler
├── variables.tf  # Configuración
└── outputs.tf    # IDs y nombres
```

**Recursos creados:**
- Service Account: `cloud-build-dbt@orbidi-challenge.iam.gserviceaccount.com`
- Cloud Build Trigger: `dbt-run-trigger`
- Cloud Scheduler Job: `dbt-post-ingesta`

### 2. Schedule de Ejecución

| Hora (Madrid) | Job | Acción |
|---------------|-----|--------|
| 3:00 AM | `trigger-weather-ingestion` | Ingesta datos clima |
| 3:05 AM | `trigger-taxis-ingestion` | Ingesta datos taxis |
| **4:00 AM** | **`dbt-post-ingesta`** | **dbt run + test** |

### 3. Cloud Build Configuration

**Archivo:** `dbt/cloudbuild.yaml`

```yaml
steps:
  - id: 'install-deps'    # Instala uv y dependencias
  - id: 'dbt-run'         # Ejecuta modelos incrementales
  - id: 'dbt-test'        # Valida calidad de datos
  - id: 'apply-policy-tags' # Aplica seguridad (opcional)
```

**Fix aplicado:** Instalación de `git` en cada step (requerido por dbt).

### 4. Permisos del Service Account

| Rol | Propósito |
|-----|-----------|
| `roles/bigquery.admin` | Ejecutar queries y crear tablas |
| `roles/storage.objectViewer` | Leer datos de GCS |
| `roles/logging.logWriter` | Escribir logs |
| `roles/iam.serviceAccountUser` | Usar SA en Cloud Build |

---

## Pipeline Completo

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ORQUESTACIÓN DIARIA                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  03:00 AM                 03:05 AM                 04:00 AM                  │
│     │                        │                        │                      │
│     ▼                        ▼                        ▼                      │
│ ┌─────────┐             ┌─────────┐             ┌─────────┐                 │
│ │ Cloud   │             │ Cloud   │             │ Cloud   │                 │
│ │Scheduler│             │Scheduler│             │Scheduler│                 │
│ └────┬────┘             └────┬────┘             └────┬────┘                 │
│      │                       │                       │                       │
│      ▼                       ▼                       ▼                       │
│ ┌─────────┐             ┌─────────┐             ┌─────────┐                 │
│ │ Cloud   │             │ Cloud   │             │ Cloud   │                 │
│ │Function │             │Function │             │  Build  │                 │
│ │ Weather │             │  Taxis  │             │   dbt   │                 │
│ └────┬────┘             └────┬────┘             └────┬────┘                 │
│      │                       │                       │                       │
│      ▼                       ▼                       ▼                       │
│ ┌─────────────────────────────────┐             ┌─────────┐                 │
│ │           GCS Landing           │────────────►│ BigQuery│                 │
│ │    (Parquet + Hive Partitions)  │             │  silver │                 │
│ └─────────────────────────────────┘             │analytics│                 │
│                                                  └─────────┘                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Archivos Modificados

| Archivo | Cambio |
|---------|--------|
| `terraform/modules/cloud_build/main.tf` | Nuevo módulo |
| `terraform/modules/cloud_build/variables.tf` | Variables del módulo |
| `terraform/modules/cloud_build/outputs.tf` | Outputs del módulo |
| `terraform/environments/dev/main.tf` | Integración del módulo |
| `terraform/environments/dev/variables.tf` | Variables `github_repo_url`, `dbt_schedule` |
| `terraform/environments/dev/outputs.tf` | Outputs de Cloud Build |
| `dbt/cloudbuild.yaml` | Fix: instalación de git |

---

## Comandos Útiles

### Probar Cloud Build manualmente
```bash
# Desde el directorio del proyecto
gcloud builds submit \
  --config=Desafio_2/dbt/cloudbuild.yaml \
  --project=orbidi-challenge \
  --region=europe-west1

# Ver estado de un build
gcloud builds describe BUILD_ID \
  --region=europe-west1 \
  --project=orbidi-challenge
```

### Ver logs de Cloud Build
```bash
gcloud builds log BUILD_ID \
  --region=europe-west1 \
  --project=orbidi-challenge
```

### Ejecutar Cloud Scheduler manualmente
```bash
gcloud scheduler jobs run dbt-post-ingesta \
  --location=europe-west1 \
  --project=orbidi-challenge
```

---

# Plan de Verificación End-to-End

## Checklist de Validación del Desarrollo

### Fase 1: Infraestructura Base

- [ ] **1.1 APIs habilitadas**
  ```bash
  gcloud services list --enabled --project=orbidi-challenge | grep -E "bigquery|cloudfunctions|cloudbuild|scheduler|datacatalog"
  ```

- [ ] **1.2 Buckets GCS creados**
  ```bash
  gsutil ls gs://orbidi-challenge-data-landing/
  gsutil ls gs://orbidi-challenge-functions-source/
  ```

- [ ] **1.3 Datasets BigQuery**
  ```bash
  bq ls --project_id=orbidi-challenge
  # Esperado: raw_data, silver_data, analytics
  ```

### Fase 2: Ingesta de Datos

- [ ] **2.1 Cloud Functions desplegadas**
  ```bash
  gcloud functions list --project=orbidi-challenge --region=europe-west1
  # Esperado: ingest-weather, ingest-taxis
  ```

- [ ] **2.2 Probar ingesta weather**
  ```bash
  curl "https://ingest-weather-eviwr2rngq-ew.a.run.app?mode=daily_offset"
  ```

- [ ] **2.3 Probar ingesta taxis**
  ```bash
  curl "https://ingest-taxis-eviwr2rngq-ew.a.run.app?mode=daily_offset"
  ```

- [ ] **2.4 Verificar datos en GCS**
  ```bash
  gsutil ls gs://orbidi-challenge-data-landing/weather/
  gsutil ls gs://orbidi-challenge-data-landing/taxis/
  ```

- [ ] **2.5 Verificar tablas externas BigQuery**
  ```sql
  SELECT COUNT(*) FROM `orbidi-challenge.raw_data.weather_daily_ext`;
  SELECT COUNT(*) FROM `orbidi-challenge.raw_data.taxi_trips_ext`;
  ```

### Fase 3: Transformaciones dbt

- [ ] **3.1 Ejecutar dbt localmente**
  ```bash
  cd Desafio_2/dbt
  uv run dbt run --profiles-dir .
  uv run dbt test --profiles-dir .
  ```

- [ ] **3.2 Verificar modelos Silver**
  ```sql
  SELECT COUNT(*) FROM `orbidi-challenge.silver_data.silver_taxis`;
  SELECT COUNT(*) FROM `orbidi-challenge.silver_data.silver_weather`;
  ```

- [ ] **3.3 Verificar modelos Analytics**
  ```sql
  SELECT COUNT(*) FROM `orbidi-challenge.analytics.taxis_weather_enriched`;
  SELECT * FROM `orbidi-challenge.analytics.vw_trips_weather_summary`;
  ```

### Fase 4: Automatización

- [ ] **4.1 Cloud Scheduler jobs creados**
  ```bash
  gcloud scheduler jobs list --location=europe-west1 --project=orbidi-challenge
  # Esperado: trigger-weather-ingestion, trigger-taxis-ingestion, dbt-post-ingesta
  ```

- [ ] **4.2 Cloud Build trigger creado**
  ```bash
  gcloud builds triggers list --region=europe-west1 --project=orbidi-challenge
  # Esperado: dbt-run-trigger
  ```

- [ ] **4.3 Probar Cloud Build manualmente**
  ```bash
  gcloud builds submit \
    --config=Desafio_2/dbt/cloudbuild.yaml \
    --project=orbidi-challenge \
    --region=europe-west1
  ```

### Fase 5: Seguridad

- [ ] **5.1 Taxonomy y Policy Tags**
  ```bash
  gcloud data-catalog taxonomies list \
    --location=eu \
    --project=orbidi-challenge
  ```

- [ ] **5.2 Verificar acceso usuario admin**
  ```sql
  -- Como andresrsotelo@gmail.com
  SELECT payment_type, COUNT(*)
  FROM `orbidi-challenge.analytics.taxis_weather_enriched`
  GROUP BY 1;
  -- Debe funcionar
  ```

- [ ] **5.3 Verificar restricción usuario limitado**
  ```sql
  -- Como estefaniacanon@gmail.com
  SELECT payment_type, COUNT(*)
  FROM `orbidi-challenge.analytics.taxis_weather_enriched`
  GROUP BY 1;
  -- Debe dar error de acceso denegado
  ```

### Fase 6: CI/CD

- [ ] **6.1 Crear rama de prueba**
  ```bash
  git checkout -b test/cicd-validation
  echo "# Test" >> Desafio_2/dbt/README.md
  git add . && git commit -m "test: validar CI/CD"
  git push origin test/cicd-validation
  ```

- [ ] **6.2 Crear PR y verificar workflows**
  ```bash
  gh pr create --base main --head test/cicd-validation --title "Test CI/CD"
  gh pr checks <PR_NUMBER>
  ```

- [ ] **6.3 Verificar workflows ejecutados**
  - Terraform: `fmt -check`, `validate`
  - Cloud Functions: `ruff lint`
  - dbt: `compile`, `test`

### Fase 7: Resultado de Negocio

- [ ] **7.1 Query de respuesta al alcalde**
  ```sql
  SELECT
    has_adverse_conditions,
    total_trips,
    avg_duration_minutes,
    avg_speed_mph
  FROM `orbidi-challenge.analytics.vw_trips_weather_summary`;
  ```

- [ ] **7.2 Validar insight**
  - Condiciones adversas: ~513K viajes, ~21.5 min promedio
  - Condiciones normales: ~2.95M viajes, ~21.6 min promedio
  - Conclusión: Impacto mínimo en duración

---

## Resumen de Endpoints y Recursos

| Recurso | Identificador |
|---------|---------------|
| Proyecto GCP | `orbidi-challenge` |
| Región | `europe-west1` |
| Weather Function | `https://ingest-weather-eviwr2rngq-ew.a.run.app` |
| Taxis Function | `https://ingest-taxis-eviwr2rngq-ew.a.run.app` |
| Data Landing Bucket | `gs://orbidi-challenge-data-landing/` |
| Cloud Build Trigger | `dbt-run-trigger` |
| Scheduler (Weather) | `trigger-weather-ingestion` (3:00 AM) |
| Scheduler (Taxis) | `trigger-taxis-ingestion` (3:05 AM) |
| Scheduler (dbt) | `dbt-post-ingesta` (4:00 AM) |

---

## Estado Final

✅ Infraestructura base (BigQuery, GCS, APIs)
✅ Ingesta de datos (Cloud Functions)
✅ Transformaciones (dbt Silver + Analytics)
✅ Automatización (Cloud Scheduler + Cloud Build)
✅ Seguridad (Column-level security, cuotas)
✅ CI/CD (GitHub Actions)
✅ Documentación
