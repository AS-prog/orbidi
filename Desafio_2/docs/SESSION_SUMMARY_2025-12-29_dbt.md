# Resumen de Sesión - Implementación dbt

**Fecha:** 2025-12-29
**Proyecto:** Orbidi Technical Challenge - Chicago Taxi & Weather Analysis
**Objetivo:** Implementar dbt para gestionar transformaciones de capas Silver y Analytics en BigQuery

---

## Contexto Previo

- Infraestructura Terraform desplegada con datasets BigQuery: `raw_data`, `silver_data`, `analytics`
- Cloud Functions para ingesta de datos (weather y taxis) con Parquet + Hive partitioning
- External Tables en BigQuery leyendo desde GCS: `weather_daily_ext`, `taxi_trips_ext`
- Datos disponibles: Junio-Diciembre 2023 (~3.9M viajes, 215 días de clima)

---

## Trabajo Realizado

### 1. Estructura del Proyecto dbt

Creamos la estructura completa del proyecto dbt:

```
Desafio_2/dbt/
├── .gitignore
├── dbt_project.yml
├── profiles.yml
├── macros/
│   └── generate_schema_name.sql    # Override para evitar prefijos en schemas
└── models/
    ├── staging/
    │   ├── _staging.yml            # Sources: raw_data.taxi_trips_ext, weather_daily_ext
    │   ├── stg_taxis.sql           # ephemeral
    │   └── stg_weather.sql         # ephemeral
    ├── silver/
    │   ├── _silver.yml             # Tests: unique, not_null
    │   ├── silver_taxis.sql        # table, partitioned, clustered
    │   └── silver_weather.sql      # table
    └── analytics/
        ├── _analytics.yml          # Tests: unique, not_null
        └── taxis_weather_enriched.sql  # table, partitioned, clustered
```

### 2. Configuración BigQuery

- **Project:** `orbidi-challenge`
- **Location:** `EU`
- **Método auth:** OAuth (Application Default Credentials)

### 3. Modelos Implementados

#### Staging (ephemeral - CTEs)
| Modelo | Source | Descripción |
|--------|--------|-------------|
| `stg_weather` | `raw_data.weather_daily_ext` | Selección de columnas weather |
| `stg_taxis` | `raw_data.taxi_trips_ext` | Filtro `trip_start_timestamp IS NOT NULL` |

#### Silver (tables en `silver_data`)
| Modelo | Filas | Transformaciones |
|--------|-------|------------------|
| `silver_weather` | 215 | Categorías temperatura (freezing/cold/mild/warm/hot), categorías precipitación (dry/light_rain/moderate_rain/heavy_rain), flag `adverse_conditions` |
| `silver_taxis` | 3.9M | Extracciones temporales (start_hour, day_of_week, time_of_day), métricas calculadas (trip_minutes, trip_km, avg_speed_mph, tip_percentage, cost_per_mile), flag `is_valid_trip`. Particionado por `date`, clustered por `pickup_community_area`, `payment_type` |

#### Analytics (tables en `analytics`)
| Modelo | Filas | Descripción |
|--------|-------|-------------|
| `taxis_weather_enriched` | 3.9M | JOIN de silver_taxis + silver_weather por fecha. Particionado por `date`, clustered por `pickup_community_area`, `temperature_category` |

### 4. Problemas Resueltos

#### 4.1 Schema duplicado en nombres
**Problema:** dbt generaba `silver_data_silver_data` como nombre de dataset.
**Solución:** Macro `generate_schema_name.sql` para usar schema exacto sin prefijo.

#### 4.2 External Table con tipos incorrectos
**Problema:** `autodetect=true` infirió `unique_key`, `taxi_id`, `company`, `payment_type` como INTEGER en lugar de STRING.
**Error:** `Parquet column 'company' has type BYTE_ARRAY which does not match the target cpp_type INT64`
**Solución:** Actualizar Terraform con schema explícito y `autodetect=false`:

```hcl
schema = jsonencode([
  { name = "unique_key", type = "STRING", mode = "NULLABLE" },
  { name = "taxi_id", type = "STRING", mode = "NULLABLE" },
  { name = "payment_type", type = "STRING", mode = "NULLABLE" },
  { name = "company", type = "STRING", mode = "NULLABLE" },
  # ... resto de columnas
])
```

### 5. Tests Ejecutados

Todos los tests pasaron exitosamente:

| Test | Tabla | Resultado |
|------|-------|-----------|
| `unique_silver_weather_date` | silver_weather | PASS |
| `not_null_silver_weather_date` | silver_weather | PASS |
| `unique_silver_taxis_unique_key` | silver_taxis | PASS |
| `not_null_silver_taxis_unique_key` | silver_taxis | PASS |
| `unique_taxis_weather_enriched_unique_key` | taxis_weather_enriched | PASS |
| `not_null_taxis_weather_enriched_unique_key` | taxis_weather_enriched | PASS |
| `not_null_taxis_weather_enriched_date` | taxis_weather_enriched | PASS |

---

## Lineage dbt

```
raw_data.weather_daily_ext ──► stg_weather ──► silver_weather ──┐
                                                                 ├──► taxis_weather_enriched
raw_data.taxi_trips_ext ──► stg_taxis ──► silver_taxis ─────────┘
```

---

## Consumo BigQuery

| Modelo | Datos Procesados |
|--------|------------------|
| silver_weather | 11.8 KiB |
| silver_taxis | 1.2 GiB |
| taxis_weather_enriched | 1.5 GiB |
| **Total aproximado** | **~2.7 GiB** |

---

## Comandos Útiles

```bash
cd Desafio_2/dbt

# Compilar sin ejecutar (sin costo)
uv run dbt compile --profiles-dir .

# Ejecutar todos los modelos
uv run dbt run --profiles-dir .

# Ejecutar modelo específico
uv run dbt run --select silver_weather --profiles-dir .

# Ejecutar modelo con dependencias upstream
uv run dbt run --select +taxis_weather_enriched --profiles-dir .

# Ejecutar tests
uv run dbt test --profiles-dir .

# Generar y servir documentación
uv run dbt docs generate --profiles-dir .
uv run dbt docs serve --profiles-dir .
```

---

## Archivos Modificados

### Nuevos
- `dbt/dbt_project.yml`
- `dbt/profiles.yml`
- `dbt/.gitignore`
- `dbt/macros/generate_schema_name.sql`
- `dbt/models/staging/_staging.yml`
- `dbt/models/staging/stg_weather.sql`
- `dbt/models/staging/stg_taxis.sql`
- `dbt/models/silver/_silver.yml`
- `dbt/models/silver/silver_weather.sql`
- `dbt/models/silver/silver_taxis.sql`
- `dbt/models/analytics/_analytics.yml`
- `dbt/models/analytics/taxis_weather_enriched.sql`

### Modificados
- `terraform/environments/dev/main.tf` - External Table `taxi_trips_ext` con schema explícito

---

## Próximos Pasos Sugeridos

1. **Agregar más tests de calidad:** accepted_values, relationships, rangos válidos
2. **Crear modelos Gold adicionales:** agregaciones por hora, día, zona, clima
3. **Implementar incremental models:** para cargas incrementales diarias
4. **Configurar CI/CD:** GitHub Actions para dbt build en PRs
5. **Documentación:** Agregar descripciones detalladas en YAML files
6. **Exposures:** Definir dashboards/reportes que consumen los modelos

---

---

## Seguridad de Columna (Column-Level Security)

### Implementación

Se implementó seguridad a nivel de columna para la columna `payment_type` en la tabla `analytics.taxis_weather_enriched` usando Data Catalog Policy Tags.

| Componente | Valor |
|------------|-------|
| **Taxonomy** | `projects/orbidi-challenge/locations/eu/taxonomies/695482576383744880` |
| **Policy Tag** | `payment_data` |
| **Columna protegida** | `analytics.taxis_weather_enriched.payment_type` |
| **Rol requerido** | `roles/datacatalog.categoryFineGrainedReader` |

### Arquitectura de Seguridad

```
┌─────────────────────────────────────────────────────────────┐
│                    Data Catalog (EU)                         │
├─────────────────────────────────────────────────────────────┤
│  Taxonomy: orbidi_sensitive_data                            │
│  └── Policy Tag: payment_data                               │
│       └── IAM: roles/datacatalog.categoryFineGrainedReader  │
│            └── Usuarios autorizados                         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  BigQuery: analytics.taxis_weather_enriched                 │
│  └── Columna: payment_type [PROTECTED]                      │
│       └── Solo usuarios con Fine Grained Reader pueden ver │
└─────────────────────────────────────────────────────────────┘
```

### Archivos de Seguridad

| Archivo | Descripción |
|---------|-------------|
| `terraform/modules/data_security/main.tf` | Taxonomy y Policy Tags |
| `terraform/modules/data_security/variables.tf` | Variables del módulo |
| `terraform/modules/data_security/outputs.tf` | Outputs (policy_tag_name) |
| `scripts/apply_policy_tags.sh` | Script para reaplicar tags post-dbt |

### Cómo Agregar Nuevos Usuarios Autorizados

Para dar acceso a la columna `payment_type` a nuevos usuarios:

**1. Editar `terraform/environments/dev/terraform.tfvars`:**

```hcl
payment_data_readers = [
  "user:andresrsotelo@gmail.com",      # Usuario existente
  "user:nuevo_usuario@ejemplo.com",     # Agregar nuevo usuario
  "group:data-analysts@company.com",    # O un grupo de Google
  "serviceAccount:sa@project.iam.gserviceaccount.com"  # O una service account
]
```

**2. Aplicar Terraform:**

```bash
cd terraform/environments/dev
terraform apply
```

**3. (Opcional) Si dbt recreó la tabla, reaplicar policy tag:**

```bash
./scripts/apply_policy_tags.sh
```

### Formatos de IAM Members

| Tipo | Formato | Ejemplo |
|------|---------|---------|
| Usuario | `user:email` | `user:analyst@company.com` |
| Grupo | `group:email` | `group:data-team@company.com` |
| Service Account | `serviceAccount:email` | `serviceAccount:looker@project.iam.gserviceaccount.com` |
| Dominio | `domain:domain` | `domain:company.com` |

### Verificar Acceso

```bash
# Ver usuarios con acceso al policy tag
gcloud data-catalog taxonomies policy-tags get-iam-policy \
  projects/orbidi-challenge/locations/eu/taxonomies/695482576383744880/policyTags/7669445918618705383

# Verificar que la columna tiene el policy tag
bq show --format=prettyjson --schema orbidi-challenge:analytics.taxis_weather_enriched | grep -A5 payment_type
```

### Comportamiento de Seguridad

| Usuario | Acceso a `payment_type` |
|---------|------------------------|
| Con `categoryFineGrainedReader` | ✅ Ve valores reales |
| Sin el rol | ❌ Error: "Access Denied" al consultar la columna |
| Con `enable_payment_masking=true` | 👁️ Ve valores enmascarados |

---

## Vista Agregada para Looker Studio

### Propósito

Responder la pregunta del alcalde de Chicago: **"¿Afectan las condiciones climáticas a la duración de los viajes en taxi?"**

### Modelo dbt

| Atributo | Valor |
|----------|-------|
| **Nombre** | `vw_trips_weather_summary` |
| **Dataset** | `analytics` |
| **Tipo** | VIEW (bajo costo, siempre actualizado) |
| **Source** | `taxis_weather_enriched` (solo viajes válidos) |

### Dimensiones Disponibles

- `date` - Fecha del viaje
- `day_of_week` - Día de la semana (1-7)
- `day_type` - weekday / weekend
- `time_of_day` - morning / afternoon / evening / night
- `temperature_category` - freezing / cold / mild / warm / hot
- `precipitation_category` - dry / light_rain / moderate_rain / heavy_rain
- `adverse_conditions` - true/false

### Métricas Disponibles

- `total_trips` - Número de viajes
- `avg_duration_min` / `median_duration_min` - Duración promedio/mediana
- `avg_distance_miles` / `total_distance_miles` - Distancia
- `avg_speed_mph` - Velocidad promedio
- `avg_fare` / `total_revenue` - Tarifas e ingresos
- `avg_tip_pct` - Porcentaje de propina

### Hallazgos Preliminares

| Condición | Total Viajes | Duración Promedio | Velocidad Promedio |
|-----------|--------------|-------------------|-------------------|
| **Sin condiciones adversas** | 2,954,391 | 21.58 min | 22.38 mph |
| **Con condiciones adversas** | 513,837 | 21.50 min | 22.09 mph |

**Observación:** Las condiciones adversas muestran velocidad ligeramente menor (-1.3%) pero duración similar, sugiriendo que los pasajeros optan por viajes más cortos cuando hay mal tiempo.

### Ejecutar en dbt

```bash
cd Desafio_2/dbt
uv run dbt run --select vw_trips_weather_summary --profiles-dir .
```

### Conectar en Looker Studio

1. Crear nuevo informe en [Looker Studio](https://lookerstudio.google.com)
2. Agregar fuente de datos → BigQuery
3. Seleccionar: `orbidi-challenge` → `analytics` → `vw_trips_weather_summary`
4. Crear visualizaciones sugeridas:
   - **Barras agrupadas**: `temperature_category` vs `avg_duration_min`
   - **Barras agrupadas**: `precipitation_category` vs `avg_duration_min`
   - **Scorecard con comparación**: Duración con/sin condiciones adversas
   - **Serie temporal**: `date` vs `avg_duration_min` coloreado por `adverse_conditions`

---

## CI/CD con GitHub Actions

### Workflows Implementados

| Workflow | Archivo | Trigger | Acciones |
|----------|---------|---------|----------|
| **Terraform** | `.github/workflows/terraform.yml` | PR a main | fmt, validate |
| **Cloud Functions** | `.github/workflows/cloud-functions.yml` | PR a main | ruff lint |
| **dbt** | `.github/workflows/dbt.yml` | PR + merge a main | compile, test, run |

### Configuración Requerida

1. **Secret de GitHub:** `GCP_SA_KEY` - JSON de service account con permisos BigQuery
2. **Environment:** `production` - Para deploy de dbt (opcional, requiere aprobación)

Ver instrucciones completas en `.github/README.md`

---

## Control de Acceso a Datos

### Usuarios Configurados

| Usuario | Acceso | Cuota Diaria |
|---------|--------|--------------|
| `andresrsotelo@gmail.com` | **Completo** (incluye `payment_type`) | Sin límite |
| `estefaniacanon@gmail.com` | **General** (sin `payment_type`) | 2 GB/día |

### Archivos de Configuración

- `terraform/environments/dev/terraform.tfvars` - Lista de usuarios
- `terraform/modules/data_security/main.tf` - IAM bindings y cuotas

### Agregar Nuevos Usuarios

```hcl
# terraform/environments/dev/terraform.tfvars

# Acceso completo (incluye payment_type)
payment_data_readers = [
  "user:andresrsotelo@gmail.com",
  "user:nuevo_admin@ejemplo.com"
]

# Acceso general (sin payment_type, con cuota 2GB/día)
bigquery_data_viewers = [
  "user:estefaniacanon@gmail.com",
  "user:nuevo_analista@ejemplo.com"
]
```

---

## Modelos Incrementales

### Configuración

Los modelos `silver_taxis` y `taxis_weather_enriched` ahora son **incrementales**:

```sql
{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        partition_by={"field": "date", "data_type": "date"},
        on_schema_change='append_new_columns'
    )
}}
```

### Beneficios

| Modo | Datos Procesados (estimado) |
|------|----------------------------|
| Full refresh | ~2.7 GiB |
| Incremental (1 día nuevo) | ~15-20 MiB |

### Forzar Full Refresh

```bash
uv run dbt run --full-refresh --profiles-dir .
```

---

## Automatización dbt

### Script Manual

```bash
# Ejecutar pipeline completo
./scripts/run_dbt_pipeline.sh
```

### CI/CD Automático

dbt se ejecuta automáticamente en GitHub Actions cuando:
- Se hace **merge a main** con cambios en `dbt/`
- Se dispara **manualmente** desde Actions → dbt → Run workflow

### Cloud Build (opcional)

Archivo `dbt/cloudbuild.yaml` disponible para ejecución en GCP.

---

## Estado Final

✅ dbt proyecto configurado y funcional
✅ 3 tablas materializadas en BigQuery (silver_weather, silver_taxis, taxis_weather_enriched)
✅ 1 vista agregada para Looker Studio (vw_trips_weather_summary)
✅ 7 tests de datos pasando
✅ Particionamiento y clustering configurado para optimizar queries
✅ External Table corregida con schema explícito
✅ Column-Level Security implementada en `payment_type`
✅ Módulo Terraform para gestión de Policy Tags
✅ Script para reaplicar seguridad post-dbt
✅ CI/CD con GitHub Actions (Terraform, Cloud Functions, dbt)
✅ Control de acceso por usuario con cuotas BigQuery
✅ Modelos incrementales para reducir costos
✅ Scripts de automatización dbt
