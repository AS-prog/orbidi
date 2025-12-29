# Terraform - Orbidi Challenge

Infraestructura como Codigo para el pipeline de datos de Chicago Taxi & Weather Analysis.

## Arquitectura

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DATA PIPELINE ARCHITECTURE                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   INGESTA DE DATOS                                                           │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                                                                      │   │
│   │  TAXIS (BigQuery Data Transfer - Scheduled Query)                   │   │
│   │  ├─ Fuente: bigquery-public-data.chicago_taxi_trips (US)            │   │
│   │  ├─ Destino: raw_data.taxi_trips (EU)                               │   │
│   │  └─ Schedule: every day 03:00                                       │   │
│   │                                                                      │   │
│   │  WEATHER (Cloud Function + Cloud Scheduler)                         │   │
│   │  ├─ Fuente: Open-Meteo API                                          │   │
│   │  ├─ Destino: GCS (Parquet) -> External Table                        │   │
│   │  ├─ Particionamiento: Hive-style (date=YYYY-MM-DD)                  │   │
│   │  ├─ Modo: daily_offset (hoy - 364 dias)                             │   │
│   │  └─ Schedule: 0 3 * * * (3 AM Madrid)                               │   │
│   │                                                                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   STORAGE (GCS)                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  orbidi-challenge-data-landing/                                      │   │
│   │  └── weather/                                                        │   │
│   │      ├── date=2023-06-01/data.parquet                               │   │
│   │      ├── date=2023-06-02/data.parquet                               │   │
│   │      └── ...                                                         │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   MEDALLION ARCHITECTURE (BigQuery)                                          │
│   ┌──────────────────┐    ┌──────────────┐    ┌──────────────┐             │
│   │     raw_data     │───►│  silver_data │───►│  analytics   │             │
│   │     (Bronze)     │    │   (Silver)   │    │    (Gold)    │             │
│   ├──────────────────┤    ├──────────────┤    ├──────────────┤             │
│   │ taxi_trips       │    │   (dbt)      │    │   (dbt)      │             │
│   │ weather_daily    │    │              │    │              │             │
│   │ weather_daily_ext│    │              │    │              │             │
│   │ _metadata        │    │              │    │              │             │
│   └──────────────────┘    └──────────────┘    └──────────────┘             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Estructura del Proyecto

```
terraform/
├── environments/
│   └── dev/
│       ├── main.tf              # Configuracion principal y APIs
│       ├── variables.tf         # Variables de entrada
│       ├── outputs.tf           # Outputs del stack
│       └── terraform.tfvars     # Valores de variables
└── modules/
    ├── bigquery/                # Datasets, tablas y Data Transfer
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── cloud_functions/         # Cloud Function para weather
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── cloud_scheduler/         # Scheduler para ejecucion diaria
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Recursos Creados

### APIs Habilitadas
| API | Descripcion |
|-----|-------------|
| `bigquery.googleapis.com` | BigQuery |
| `bigquerydatatransfer.googleapis.com` | Data Transfer Service |
| `iam.googleapis.com` | Identity and Access Management |
| `cloudfunctions.googleapis.com` | Cloud Functions |
| `cloudbuild.googleapis.com` | Cloud Build |
| `run.googleapis.com` | Cloud Run |
| `storage.googleapis.com` | Cloud Storage |
| `artifactregistry.googleapis.com` | Artifact Registry |
| `cloudscheduler.googleapis.com` | Cloud Scheduler |

### BigQuery Datasets
| Dataset | Capa | Descripcion |
|---------|------|-------------|
| `raw_data` | Bronze | Landing zone - datos crudos |
| `silver_data` | Silver | Datos limpios y validados |
| `analytics` | Gold | Agregaciones y marts para BI |

### BigQuery Tables (raw_data)
| Tabla | Tipo | Particionamiento | Descripcion |
|-------|------|------------------|-------------|
| `taxi_trips` | Native | `trip_start_timestamp` (DAY) | Viajes de taxi Chicago |
| `weather_daily` | Native | `date` (DAY) | Clima diario (legacy) |
| `weather_daily_ext` | External | Hive (`date`) | Clima diario desde Parquet |
| `_metadata_control` | Native | - | Control de ejecucion |

### Cloud Storage Buckets
| Bucket | Descripcion |
|--------|-------------|
| `orbidi-challenge-functions-source` | Codigo fuente de Cloud Functions |
| `orbidi-challenge-data-landing` | Ficheros Parquet de weather |

### Cloud Functions
| Funcion | Runtime | Trigger | Descripcion |
|---------|---------|---------|-------------|
| `ingest-weather` | Python 3.11 | HTTP | Ingesta datos del clima |

### Cloud Scheduler Jobs
| Job | Schedule | Timezone | Descripcion |
|-----|----------|----------|-------------|
| `trigger-weather-ingestion` | `0 3 * * *` | Europe/Madrid | Ejecuta ingesta diaria |

### Service Accounts
| Service Account | Rol | Uso |
|-----------------|-----|-----|
| `bq-data-transfer-sa` | `roles/bigquery.admin` | Data Transfer |
| `cloud-functions-sa` | `roles/bigquery.dataEditor`, `roles/storage.objectAdmin` | Cloud Functions |

## Cloud Function: ingest-weather

### Modos de Operacion

**1. Modo `daily_offset` (usado por Cloud Scheduler)**
```bash
curl "https://ingest-weather-xxx.a.run.app?mode=daily_offset"
```
- Calcula automaticamente la fecha: `hoy - 364 dias`
- Ejemplo: 2025-12-30 -> procesa 2024-01-01

**2. Modo `range` (carga manual de rango)**
```bash
curl "https://ingest-weather-xxx.a.run.app?start_date=2024-01-01&end_date=2024-01-31"
```

**3. Forzar reprocesamiento**
```bash
curl "https://ingest-weather-xxx.a.run.app?mode=daily_offset&force=true"
```

### Variables de Entorno
| Variable | Default | Descripcion |
|----------|---------|-------------|
| `GCP_PROJECT` | `orbidi-challenge` | Project ID |
| `GCS_BUCKET` | `orbidi-challenge-data-landing` | Bucket destino |
| `OFFSET_DAYS` | `364` | Dias de offset para daily_offset |

## Configuracion

### 1. Prerequisitos

```bash
# Autenticarse en GCP
gcloud auth login
gcloud auth application-default login

# Configurar proyecto
gcloud config set project orbidi-challenge
```

### 2. Variables

Crear `terraform.tfvars` en `environments/dev/`:

```hcl
project_id        = "orbidi-challenge"
region            = "europe-west1"
bigquery_location = "EU"
```

### 3. Desplegar

```bash
cd terraform/environments/dev

# Inicializar
terraform init

# Ver cambios
terraform plan

# Aplicar
terraform apply
```

### 4. Verificar

```bash
# Ver outputs
terraform output

# Ver recursos
terraform state list
```

## Comandos Utiles

### Ejecutar Cloud Scheduler manualmente
```bash
gcloud scheduler jobs run trigger-weather-ingestion \
  --location=europe-west1 \
  --project=orbidi-challenge
```

### Ver logs de Cloud Function
```bash
gcloud functions logs read ingest-weather \
  --region=europe-west1 \
  --project=orbidi-challenge \
  --limit=20
```

### Ejecutar Data Transfer manualmente
```bash
bq mk --transfer_run \
  --run_time=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  projects/862995509008/locations/europe/transferConfigs/69d153bc-0000-237b-b509-14c14ef67f5c
```

### Consultar External Table
```sql
SELECT
  date,
  temperature_max,
  temperature_min,
  precipitation_sum
FROM `orbidi-challenge.raw_data.weather_daily_ext`
WHERE date >= '2024-01-01'
ORDER BY date DESC
LIMIT 10;
```

## Outputs

```bash
$ terraform output

analytics_dataset       = "analytics"
data_landing_bucket     = "orbidi-challenge-data-landing"
functions_source_bucket = "orbidi-challenge-functions-source"
raw_data_dataset        = "raw_data"
scheduler_job_name      = "trigger-weather-ingestion"
scheduler_schedule      = "0 3 * * *"
scheduler_timezone      = "Europe/Madrid"
silver_data_dataset     = "silver_data"
taxi_trips_table        = "orbidi-challenge.raw_data.taxi_trips"
weather_daily_table     = "orbidi-challenge.raw_data.weather_daily"
weather_external_table  = "orbidi-challenge.raw_data.weather_daily_ext"
weather_function_name   = "ingest-weather"
weather_function_sa     = "cloud-functions-sa@orbidi-challenge.iam.gserviceaccount.com"
weather_function_uri    = "https://ingest-weather-eviwr2rngq-ew.a.run.app"
```

## Notas Importantes

1. **Cross-Region Copy**: Los datos de taxi se copian de US (public dataset) a EU usando BigQuery Data Transfer (gratuito).

2. **Sharding Diario**: Los datos de weather se guardan como ficheros Parquet individuales por dia, permitiendo carga incremental.

3. **External Table**: `weather_daily_ext` lee directamente de GCS sin duplicar datos en BigQuery.

4. **Offset de 364 dias**: La estrategia `daily_offset` permite "replicar" datos historicos dia a dia (2025-12-30 -> 2024-01-01).

5. **dbt**: Los datasets `silver_data` y `analytics` seran poblados por dbt.

6. **Estado**: El estado de Terraform se guarda localmente. Para produccion, usar backend remoto (GCS).
