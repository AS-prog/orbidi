# Resumen de Sesion - 29 Diciembre 2025

## Contexto del Proyecto

**Proyecto**: Orbidi Technical Challenge - Chicago Taxi & Weather Analysis
**Ubicacion**: `Desafio_2/terraform`
**Objetivo**: Implementar infraestructura de datos en GCP usando Terraform

## Lo Que Se Implemento

### 1. BigQuery - Capa Raw (Medallion Architecture)

Se crearon 3 datasets siguiendo la arquitectura medallion:
- `raw_data` (Bronze): Datos crudos
- `silver_data` (Silver): Para transformaciones con dbt
- `analytics` (Gold): Para reportes y BI

**Tablas creadas en raw_data:**
- `taxi_trips`: Particionada por `trip_start_timestamp`
- `weather_daily`: Particionada por `date` (legacy, no se usa)
- `weather_daily_ext`: External Table que lee de Parquet en GCS
- `_metadata_control`: Control de ejecucion

### 2. BigQuery Data Transfer Service

Se configuro un Data Transfer para copiar datos de taxis desde el dataset publico de Google (US) a nuestro dataset en EU.

- **Fuente**: `bigquery-public-data.chicago_taxi_trips.taxi_trips`
- **Destino**: `orbidi-challenge.raw_data.taxi_trips`
- **Schedule**: `every day 03:00`
- **Filtro**: Jun-Dec 2023

### 3. Cloud Function - ingest_weather

Funcion Python que obtiene datos climaticos de Open-Meteo API para Chicago.

**Ubicacion del codigo**: `Desafio_2/src/ingest_weather/main.py`

**Caracteristicas implementadas:**
- Escribe ficheros Parquet a GCS (no directamente a BigQuery)
- Particionamiento Hive-style: `weather/date=YYYY-MM-DD/data.parquet`
- Carga incremental: solo procesa fechas que no existen
- Dos modos de operacion:
  - `range`: Procesa un rango de fechas
  - `daily_offset`: Calcula fecha automaticamente (hoy - 364 dias)

**Variables de entorno:**
- `GCP_PROJECT`: orbidi-challenge
- `GCS_BUCKET`: orbidi-challenge-data-landing
- `OFFSET_DAYS`: 364

### 4. External Table con Hive Partitioning

En lugar de cargar datos directamente a BigQuery, se usa una External Table que lee de los ficheros Parquet en GCS.

**Ventajas:**
- No duplica datos (ahorra costos)
- Particionamiento automatico por fecha
- Carga incremental natural

**Configuracion:**
```hcl
external_data_configuration {
  autodetect    = true
  source_format = "PARQUET"
  source_uris   = ["gs://orbidi-challenge-data-landing/weather/*"]

  hive_partitioning_options {
    mode                     = "AUTO"
    source_uri_prefix        = "gs://orbidi-challenge-data-landing/weather/"
    require_partition_filter = false
  }
}
```

### 5. Cloud Scheduler

Job que ejecuta la Cloud Function diariamente.

- **Nombre**: `trigger-weather-ingestion`
- **Schedule**: `0 3 * * *` (3:00 AM)
- **Timezone**: `Europe/Madrid`
- **URI**: `https://ingest-weather-xxx.a.run.app?mode=daily_offset`

### 6. Estrategia de Offset de 364 Dias

Para "simular" carga historica dia a dia:
- El 2025-12-30 a las 3 AM -> descarga datos del 2024-01-01
- El 2025-12-31 a las 3 AM -> descarga datos del 2024-01-02
- Y asi sucesivamente...

Esto permite que cada dia se agregue un nuevo fichero Parquet con datos de hace exactamente 364 dias.

## Estructura de Ficheros Creados/Modificados

```
Desafio_2/
├── terraform/
│   ├── environments/dev/
│   │   ├── main.tf              # Config principal con todos los modulos
│   │   ├── variables.tf         # Variables
│   │   ├── outputs.tf           # Outputs
│   │   └── terraform.tfvars     # Valores
│   ├── modules/
│   │   ├── bigquery/            # Datasets, tablas, Data Transfer
│   │   ├── cloud_functions/     # Function + buckets + IAM
│   │   └── cloud_scheduler/     # Scheduler job
│   └── README.md                # Documentacion actualizada
├── src/
│   └── ingest_weather/
│       ├── main.py              # Codigo de la Cloud Function
│       └── requirements.txt     # Dependencias
└── docs/
    └── SESSION_SUMMARY_2025-12-29.md  # Este archivo
```

## Comandos Utiles

### Ejecutar Cloud Function manualmente
```bash
# Modo daily_offset
curl "https://ingest-weather-eviwr2rngq-ew.a.run.app?mode=daily_offset"

# Modo range
curl "https://ingest-weather-eviwr2rngq-ew.a.run.app?start_date=2024-01-01&end_date=2024-01-31"

# Forzar reprocesamiento
curl "https://ingest-weather-eviwr2rngq-ew.a.run.app?mode=daily_offset&force=true"
```

### Ejecutar Cloud Scheduler manualmente
```bash
gcloud scheduler jobs run trigger-weather-ingestion \
  --location=europe-west1 \
  --project=orbidi-challenge
```

### Ver logs
```bash
gcloud functions logs read ingest-weather \
  --region=europe-west1 \
  --project=orbidi-challenge \
  --limit=20
```

### Consultar datos
```sql
-- Ver todos los registros
SELECT COUNT(*) as total, MIN(date) as first, MAX(date) as last
FROM `orbidi-challenge.raw_data.weather_daily_ext`;

-- Ver datos de una fecha especifica
SELECT * FROM `orbidi-challenge.raw_data.weather_daily_ext`
WHERE date = '2024-01-01';
```

## Estado Actual de los Datos

- **Weather 2023**: 214 registros (Jun-Dec 2023) - cargados manualmente
- **Weather 2024-12-30**: 1 registro - cargado via daily_offset

## Proximos Pasos Sugeridos

1. **Implementar funcion para taxis** (opcional si Data Transfer es suficiente)
2. **Configurar dbt** para transformaciones silver y gold
3. **Crear vistas/dashboards** en Looker Studio
4. **Monitoreo y alertas** para los jobs

## Problemas Resueltos Durante la Sesion

1. **Cross-region data copy**: Datos de taxi estan en US, nuestro proyecto en EU
   - Solucion: BigQuery Data Transfer Service (gratuito)

2. **External Table requiere fichero existente**: Terraform fallaba si el Parquet no existia
   - Solucion: Ejecutar la funcion primero para crear el fichero, luego aplicar Terraform

3. **Fichero antiguo causaba error de particionamiento**: El fichero `weather_daily.parquet` sin particiones causaba conflicto
   - Solucion: Eliminar el fichero antiguo con `gcloud storage rm`

4. **Autenticacion de cuenta**: Se cambio de cuenta gcloud
   - Solucion: `gcloud auth login` con la cuenta correcta

## Notas Importantes

- El estado de Terraform esta en local (`terraform.tfstate`)
- La cuenta activa es `andresrsotelo@gmail.com`
- El proyecto GCP es `orbidi-challenge`
- La region principal es `europe-west1` (Belgium)
- BigQuery esta en location `EU`
