# Chicago Taxi & Weather Analysis

Pipeline de datos en GCP que analiza la relación entre condiciones climáticas y viajes en taxi en Chicago.

## Objetivo

Responder la pregunta del alcalde de Chicago:

> **"¿Afectan las condiciones climáticas a la duración de los viajes en taxi?"**

## Arquitectura

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              INGESTA                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────────┐  │
│  │ Cloud        │    │ Cloud        │    │ Cloud Functions          │  │
│  │ Scheduler    │───►│ Functions    │───►│ - ingest_weather         │  │
│  │ (3:00 AM)    │    │ Gen2         │    │ - ingest_taxis           │  │
│  └──────────────┘    └──────────────┘    └────────────┬─────────────┘  │
│                                                        │                 │
│                                                        ▼                 │
│                                          ┌──────────────────────────┐   │
│                                          │ GCS (Parquet + Hive)     │   │
│                                          │ orbidi-challenge-data-   │   │
│                                          │ landing/                 │   │
│                                          └────────────┬─────────────┘   │
│                                                        │                 │
└────────────────────────────────────────────────────────┼─────────────────┘
                                                         │
┌────────────────────────────────────────────────────────┼─────────────────┐
│                           BIGQUERY                     │                 │
├────────────────────────────────────────────────────────┼─────────────────┤
│                                                        ▼                 │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ raw_data (External Tables)                                       │    │
│  │ ├── taxi_trips_ext (3.9M filas)                                  │    │
│  │ └── weather_daily_ext (215 días)                                 │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                              │                                           │
│                              ▼ dbt                                       │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ silver_data (Curated)                                            │    │
│  │ ├── silver_taxis (incremental, partitioned)                      │    │
│  │ └── silver_weather                                               │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                              │                                           │
│                              ▼ dbt                                       │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ analytics (Gold)                                                 │    │
│  │ ├── taxis_weather_enriched (incremental)                         │    │
│  │ └── vw_trips_weather_summary (view para Looker)                  │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                         VISUALIZACIÓN                                     │
├──────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ Looker Studio Dashboard                                           │   │
│  │ - Duración promedio por condición climática                       │   │
│  │ - Comparación días adversos vs normales                           │   │
│  │ - Tendencias temporales                                           │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────┘
```

## Stack Tecnológico

| Componente | Tecnología | Propósito |
|------------|------------|-----------|
| **IaC** | Terraform | Infraestructura como código |
| **Ingesta** | Cloud Functions (Python) | ETL serverless |
| **Storage** | GCS + BigQuery | Data Lake + Data Warehouse |
| **Transformaciones** | dbt Core | Medallion Architecture |
| **Orquestación** | Cloud Scheduler | Ejecución diaria automatizada |
| **CI/CD** | GitHub Actions | Validación y deploy |
| **Visualización** | Looker Studio | Dashboard interactivo |
| **Seguridad** | Data Catalog Policy Tags | Column-level security |

## Estructura del Proyecto

```
Desafio_2/
├── .github/workflows/       # CI/CD pipelines
├── terraform/
│   ├── environments/dev/    # Configuración del entorno
│   └── modules/             # Módulos reutilizables
│       ├── bigquery/        # Datasets y tablas
│       ├── cloud_functions/ # Functions de ingesta
│       ├── cloud_scheduler/ # Jobs programados
│       ├── data_security/   # Column-level security
│       └── cicd/            # Service Account CI/CD
├── dbt/
│   └── models/
│       ├── staging/         # CTEs efímeras
│       ├── silver/          # Datos curados
│       └── analytics/       # Modelos de negocio
├── src/
│   ├── ingest_weather/      # Cloud Function weather
│   └── ingest_taxis/        # Cloud Function taxis
├── scripts/                 # Utilidades
└── docs/                    # Documentación de sesiones
```

## Datos

| Dataset | Registros | Período | Fuente |
|---------|-----------|---------|--------|
| Taxi Trips | ~3.9M | Jun-Dic 2023 | Chicago Data Portal |
| Weather | 215 días | Jun-Dic 2023 | Open-Meteo API |

## Seguridad

### Column-Level Security

La columna `payment_type` está protegida con Data Catalog Policy Tags:

| Usuario | Acceso a `payment_type` | Cuota BigQuery |
|---------|-------------------------|----------------|
| Admin | ✅ Completo | Sin límite |
| Analyst | ❌ Denegado | 2 GB/día |

## Quick Start

### Prerrequisitos

- GCP Project con billing habilitado
- Terraform >= 1.5.0
- Python 3.11+ con `uv`
- gcloud CLI autenticado

### Despliegue

```bash
# 1. Clonar repositorio
git clone <repo-url>
cd Desafio_2

# 2. Configurar variables
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars
# Editar terraform.tfvars con tus valores

# 3. Desplegar infraestructura
cd terraform/environments/dev
terraform init
terraform apply

# 4. Ejecutar ingesta inicial
curl "$(terraform output -raw weather_function_uri)?start_date=2023-06-01&end_date=2023-12-31"

# 5. Ejecutar dbt
cd ../../../dbt
uv sync
uv run dbt run --profiles-dir .
uv run dbt test --profiles-dir .
```

## CI/CD

| Workflow | Trigger | Acciones |
|----------|---------|----------|
| `terraform.yml` | PR | `fmt`, `validate` |
| `cloud-functions.yml` | PR | `ruff lint` |
| `dbt.yml` | PR + merge | `compile`, `test`, `run` |

### Configurar GitHub Secret

1. Ejecutar `terraform apply` (genera `github-actions-key.json`)
2. GitHub → Settings → Secrets → New: `GCP_SA_KEY`
3. Pegar contenido del JSON

## Hallazgos

### Impacto del Clima en Duración de Viajes

| Condición | Viajes | Duración Promedio | Velocidad |
|-----------|--------|-------------------|-----------|
| Normal | 2.95M | 21.58 min | 22.38 mph |
| Adversa | 513K | 21.50 min | 22.09 mph |

**Conclusión:** Las condiciones adversas reducen ligeramente la velocidad (-1.3%) pero la duración es similar, sugiriendo que los pasajeros optan por viajes más cortos durante mal tiempo.

## Documentación

- [Resumen Infraestructura](docs/SESSION_SUMMARY_2025-12-29.md)
- [Implementación dbt](docs/SESSION_SUMMARY_2025-12-29_dbt.md)
- [CI/CD y Seguridad](docs/SESSION_SUMMARY_2025-12-30_cicd.md)
- [Configuración GitHub Actions](.github/README.md)

## Costos Estimados (Free Tier)

| Servicio | Uso | Límite Free | Costo |
|----------|-----|-------------|-------|
| BigQuery Storage | ~3 GB | 10 GB | $0 |
| BigQuery Queries | ~50 GB/mes | 1 TB/mes | $0 |
| Cloud Functions | ~60 inv/mes | 2M/mes | $0 |
| Cloud Storage | ~2 GB | 5 GB | $0 |
| **Total** | | | **$0** |

## Licencia

Proyecto desarrollado como parte del Orbidi Technical Challenge.
