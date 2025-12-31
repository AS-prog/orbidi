# Resumen de Sesión - Validación Pipeline E2E

**Fecha:** 2025-12-31
**Proyecto:** Orbidi Technical Challenge - Chicago Taxi & Weather Analysis
**Objetivo:** Resolver problemas de automatización y validar pipeline completo

---

## Issue #6: Cloud Scheduler no dispara Cloud Build

### Problema
El job `dbt-post-ingesta` fallaba con código 3 (INVALID_ARGUMENT) al intentar disparar Cloud Build via API.

### Causa Raíz
El trigger Cloud Build usaba URL directa de GitHub (`source_to_build.uri`) en lugar de una conexión GitHub 2nd gen, lo cual no permite triggers via API.

### Solución Implementada

1. **Crear conexión GitHub en Cloud Build Console**
   - Nombre: `github-connection`
   - Repositorio vinculado: `orbidi-repo`

2. **Actualizar trigger Terraform para usar la conexión**
   ```hcl
   source_to_build {
     repository = "projects/.../connections/github-connection/repositories/orbidi-repo"
     ref        = "refs/heads/main"
     repo_type  = "GITHUB"
   }
   ```

3. **Cambiar body del scheduler a vacío**
   ```hcl
   body = base64encode("{}")  # Triggers 2nd gen no necesitan branchName
   ```

### Verificación
```bash
gcloud scheduler jobs run dbt-post-ingesta
# status: {} (SUCCESS)
# Build creado: a67726e5-d5fc-4848-957b-b9f1c66627cf
```

---

## Issue #7: Datos de 2024 no visibles en tabla externa

### Problema
Los datos de taxis para 2024-01-01 existían en GCS pero no eran visibles en BigQuery.

### Diagnóstico
```
Log función: "No taxi data for 2024-01-01 - writing empty parquet with schema"
```

El parquet existía pero tenía **0 filas**. Se verificó que el dataset público de Chicago (`bigquery-public-data.chicago_taxi_trips.taxi_trips`) no tiene datos para 2024.

### Solución Implementada

1. **Ajustar offset de ambas funciones**
   ```hcl
   taxis_offset_days   = "738"  # 2025-12-31 - 738 = 2023-12-24
   weather_offset_days = "738"
   ```

2. **Eliminar parquets vacíos de GCS**
   ```bash
   gsutil -m rm -r gs://orbidi-challenge-data-landing/taxis/date=2023-12-2[5-9]/
   gsutil -m rm -r gs://orbidi-challenge-data-landing/taxis/date=2024-*/
   # Ídem para weather
   ```

3. **Limpiar capas silver y gold**
   ```sql
   DELETE FROM silver_data.silver_weather WHERE date > '2023-12-23';
   DELETE FROM silver_data.silver_taxis WHERE date > '2023-12-23';
   DELETE FROM analytics.taxis_weather_enriched WHERE date > '2023-12-23';
   ```

---

## Validación Pipeline E2E

### Estado Inicial (post-limpieza)
| Capa | Tabla | Registros 2023-12-24 |
|------|-------|---------------------|
| Raw | `weather_daily_ext` | 1 |
| Raw | `taxi_trips_ext` | 7,676 |
| Silver | `silver_weather` | 0 |
| Silver | `silver_taxis` | 0 |
| Gold | `taxis_weather_enriched` | 0 |

### Ejecución del Pipeline
```bash
# 1. Ingesta (datos ya existían en raw)
curl "https://ingest-weather-eviwr2rngq-ew.a.run.app?mode=daily_offset"
# {"status": "success", "message": "Date 2023-12-24 already exists - skipping"}

curl "https://ingest-taxis-eviwr2rngq-ew.a.run.app?mode=daily_offset"
# {"status": "success", "message": "Date 2023-12-24 already exists - skipping"}

# 2. dbt via Cloud Build
gcloud builds triggers run dbt-run-trigger --branch=main
# Build ID: ef1061ce-c907-4eba-af1b-86b7766304a1
# Status: SUCCESS
```

### Estado Final (post-pipeline)
| Capa | Tabla | Registros 2023-12-24 | Estado |
|------|-------|---------------------|--------|
| Raw | `weather_daily_ext` | 1 | ✅ |
| Raw | `taxi_trips_ext` | 7,676 | ✅ |
| Silver | `silver_weather` | **1** | ✅ Procesado |
| Silver | `silver_taxis` | **7,676** | ✅ Procesado |
| Gold | `taxis_weather_enriched` | **7,676** | ✅ Procesado |

---

## Commits Realizados

| Commit | Descripción |
|--------|-------------|
| `0567a38` | fix(cloud-build): corregir trigger para usar GitHub connection 2nd gen |
| `0108d05` | fix(ingestion): ajustar offset a 738 días para datos de 2023-12-24 |

---

## Issues Cerrados

- **#6** - Las cargas programadas no se han ejecutado → CLOSED
- **#7** - Datos de 2024 no visibles en tabla externa → CLOSED (not planned - falta de datos en fuente)

---

## Próximas Ejecuciones Automáticas

| Fecha Ejecución | Fecha Datos | Hora |
|-----------------|-------------|------|
| 2026-01-01 | 2023-12-25 | 3:00 AM (ingesta) / 4:00 AM (dbt) |
| 2026-01-02 | 2023-12-26 | 3:00 AM (ingesta) / 4:00 AM (dbt) |
| ... | ... | ... |
| 2026-01-07 | 2023-12-31 | Último día con datos disponibles |

---

## Tablas Obsoletas Identificadas

Las siguientes tablas nativas no tienen proceso asociado (dbt usa `_ext`):
- `raw_data.taxi_trips` → Puede eliminarse
- `raw_data.weather_daily` → Puede eliminarse
