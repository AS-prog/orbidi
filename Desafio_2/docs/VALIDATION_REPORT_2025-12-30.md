# Informe de Validación End-to-End

**Fecha:** 2025-12-30
**Proyecto:** Orbidi Technical Challenge - Chicago Taxi & Weather Analysis

---

## Fase 1: Infraestructura Base ✅

| Componente | Estado | Notas |
|------------|--------|-------|
| APIs habilitadas | ✅ 15 APIs | BigQuery, Cloud Functions, Cloud Build, Scheduler, Data Catalog |
| Bucket Landing | ✅ Existe | `gs://orbidi-challenge-data-landing/` |
| Bucket Functions | ✅ Existe | `gs://orbidi-challenge-functions-source/` |
| Datasets BigQuery | ✅ 3 datasets | `raw_data`, `silver_data`, `analytics` |

**💰 Costos Infraestructura:**

| Recurso | Uso | Free Tier | Costo |
|---------|-----|-----------|-------|
| GCS Landing | 276 MB | 5 GB gratis | **$0** |
| GCS Functions | 13 KB | 5 GB gratis | **$0** |
| APIs | Habilitación | Sin costo | **$0** |

---

## Fase 2: Ingesta de Datos ✅

| Componente | Estado | Detalles |
|------------|--------|----------|
| `ingest-weather` | ✅ ACTIVE | Cloud Function Gen2 |
| `ingest-taxis` | ✅ ACTIVE | Cloud Function Gen2 |
| Datos Weather GCS | ✅ Particionado | `date=2023-06-01/` ... `date=2023-12-31/` |
| Datos Taxis GCS | ✅ Particionado | `date=2023-06-01/` ... `date=2023-12-31/` |

**💰 Costos Ingesta:**

| Recurso | Uso Actual | Free Tier | Costo Estimado |
|---------|------------|-----------|----------------|
| Cloud Functions | ~60 inv/mes | 2M inv/mes gratis | **$0** |
| Egress Open-Meteo | ~1 KB/día | N/A | **$0** |
| Egress Chicago Data | ~5 MB/día | N/A | **$0** |

---

## Fase 3: Transformaciones dbt ✅

| Tabla | Tipo | Partición | Clustering |
|-------|------|-----------|------------|
| `silver_taxis` | TABLE | DAY (date) | pickup_community_area, payment_type |
| `silver_weather` | TABLE | - | - |
| `taxis_weather_enriched` | TABLE | DAY (date) | pickup_community_area, temperature_category |
| `vw_trips_weather_summary` | VIEW | - | - |

**💰 Costos dbt/BigQuery:**

| Operación | Datos Procesados | Free Tier | Costo |
|-----------|------------------|-----------|-------|
| Full refresh | ~2.7 GiB | 1 TB/mes gratis | **$0** |
| Incremental (diario) | ~15-20 MiB | 1 TB/mes gratis | **$0** |
| Storage | ~3 GB | 10 GB gratis | **$0** |

---

## Fase 4: Automatización ✅

| Job | Schedule | Estado |
|-----|----------|--------|
| `trigger-weather-ingestion` | `0 3 * * *` (3:00 AM) | ✅ ENABLED |
| `trigger-taxis-ingestion` | `5 3 * * *` (3:05 AM) | ✅ ENABLED |
| `dbt-post-ingesta` | `0 4 * * *` (4:00 AM) | ✅ ENABLED |
| `dbt-run-trigger` | Cloud Build | ✅ Creado 2025-12-30 |

**💰 Costos Automatización:**

| Recurso | Uso | Free Tier | Costo |
|---------|-----|-----------|-------|
| Cloud Scheduler | 3 jobs | 3 jobs gratis | **$0** |
| Cloud Build | ~5 min/día | 120 min/día gratis | **$0** |

---

## Fase 5: Seguridad ✅

| Componente | Estado |
|------------|--------|
| Taxonomy `orbidi_sensitive_data` | ✅ Creada en EU |
| Policy Tag `payment_type` | ✅ Aplicado |
| Admin access (`andresrsotelo@gmail.com`) | ✅ Configurado |
| Limited access (`estefaniacanon@gmail.com`) | ✅ Configurado (2GB/día) |

**💰 Costos Seguridad:**

| Recurso | Costo |
|---------|-------|
| Data Catalog | **$0** (sin costo adicional) |
| Policy Tags | **$0** (incluido en BigQuery) |

---

## Fase 6: CI/CD ✅

| Workflow | Últimas Ejecuciones | Estado |
|----------|---------------------|--------|
| Terraform | 2 runs | ✅ success |
| Cloud Functions | 1 run | ✅ success |
| dbt | 5 runs | ✅ success |

**💰 Costos CI/CD:**

| Recurso | Uso | Free Tier | Costo |
|---------|-----|-----------|-------|
| GitHub Actions | ~10 min/PR | 2000 min/mes gratis | **$0** |

---

## Fase 7: Cloud Build History

| Build ID | Estado | Fecha |
|----------|--------|-------|
| `30a0393c...` | ✅ SUCCESS | 2025-12-30 10:47 |
| `de193771...` | ❌ FAILURE | 2025-12-30 10:44 (faltaba git) |
| `6b4596db...` | ✅ SUCCESS | 2025-12-29 06:29 |

---

## 💰 RESUMEN DE COSTOS

| Categoría | Costo Mensual Estimado |
|-----------|------------------------|
| **Infraestructura (GCS, APIs)** | $0 |
| **Ingesta (Cloud Functions)** | $0 |
| **Transformaciones (BigQuery)** | $0 |
| **Automatización (Scheduler, Cloud Build)** | $0 |
| **Seguridad (Data Catalog)** | $0 |
| **CI/CD (GitHub Actions)** | $0 |
| **TOTAL** | **$0** |

---

## ⚠️ Operaciones que Incurren en Costos

| Operación | Costo Aproximado | Cuándo Aplica |
|-----------|------------------|---------------|
| `dbt run --full-refresh` | ~$0.01 | Si se supera 1 TB/mes de queries |
| Consultas BigQuery manuales | $5/TB | Si se supera 1 TB/mes |
| Cloud Build > 120 min/día | $0.003/min | Si se supera free tier |
| GCS Storage > 5 GB | $0.02/GB/mes | Si se supera free tier |

---

## ✅ ESTADO FINAL

```
[✅] Fase 1: Infraestructura Base
[✅] Fase 2: Ingesta de Datos
[✅] Fase 3: Transformaciones dbt
[✅] Fase 4: Automatización
[✅] Fase 5: Seguridad
[✅] Fase 6: CI/CD
[✅] Fase 7: Builds exitosos

PROYECTO 100% OPERATIVO - COSTO: $0/mes (dentro de Free Tier)
```

---

## Recursos del Proyecto

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
