# Plan de Implementación dbt - Chicago Taxi & Weather

## Resumen

Implementar dbt para gestionar las transformaciones de la capa Silver y Analytics en BigQuery.

**Datasets BigQuery existentes:**
- `raw_data` - Bronze layer (taxi_trips, weather_daily)
- `silver_data` - Silver layer (destino dbt)
- `analytics` - Gold layer (destino dbt)

---

## Pasos de Implementación

### Paso 1: Crear estructura del proyecto dbt

```
Desafio_2/
└── dbt/
    ├── dbt_project.yml
    ├── profiles.yml          # Conexión a BigQuery
    ├── models/
    │   ├── staging/          # Referencias a raw_data
    │   │   ├── _staging.yml
    │   │   ├── stg_taxis.sql
    │   │   └── stg_weather.sql
    │   ├── silver/           # Transformaciones -> silver_data
    │   │   ├── _silver.yml
    │   │   ├── silver_weather.sql
    │   │   └── silver_taxis.sql
    │   └── analytics/        # Agregaciones -> analytics
    │       ├── _analytics.yml
    │       └── taxis_weather_enriched.sql
    └── packages.yml          # dbt-utils (opcional)
```

### Paso 2: Configurar conexión BigQuery

- Usar service account existente o Application Default Credentials
- Configurar `profiles.yml` con proyecto GCP

### Paso 3: Crear modelos Staging (vistas efímeras)

- `stg_taxis`: Referencia a `raw_data.taxi_trips`
- `stg_weather`: Referencia a `raw_data.weather_daily`
- Materialización: `ephemeral` (no genera tablas, solo CTEs)

### Paso 4: Crear modelos Silver

**`silver_weather`** (Dataset: silver_data)
- Categorías de temperatura (freezing/cold/mild/warm/hot)
- Categorías de precipitación (dry/light_rain/moderate_rain/heavy_rain)
- Flag `adverse_conditions`
- Materialización: `table`

**`silver_taxis`** (Dataset: silver_data)
- Extracciones temporales (start_hour, day_of_week, time_of_day)
- Métricas calculadas (trip_minutes, trip_km, avg_speed_mph, tip_percentage, cost_per_mile)
- Flag `is_valid_trip`
- Materialización: `table`

### Paso 5: Crear modelo Analytics

**`taxis_weather_enriched`** (Dataset: analytics)
- Join de silver_taxis + silver_weather por fecha
- Materialización: `table`

### Paso 6: Validar con dbt compile (sin ejecutar)

- `dbt compile` genera SQL sin ejecutar
- Revisar queries generadas antes de run

### Paso 7: Ejecutar dbt run (con precaución)

- Primera ejecución: `dbt run --select silver_weather` (1 tabla pequeña)
- Verificar costos en BigQuery console
- Continuar con resto de modelos

---

## Consideraciones de Costos

| Acción | Impacto |
|--------|---------|
| `dbt compile` | Sin costo (solo genera SQL) |
| `dbt run` silver_weather | Bajo (~61 filas weather) |
| `dbt run` silver_taxis | Moderado (depende de filas en raw_data.taxi_trips) |
| `dbt run --full-refresh` | Alto (recrea tablas completas) |

**Recomendaciones:**
- Usar `LIMIT` en desarrollo para probar
- Revisar siempre el SQL compilado antes de ejecutar
- Considerar materialización `view` en desarrollo, `table` en producción

---

## Comandos clave

```bash
# Solo compilar (sin costo)
dbt compile

# Ejecutar un modelo específico
dbt run --select silver_weather

# Ejecutar con dependencias upstream
dbt run --select +taxis_weather_enriched

# Ver lineage
dbt docs generate && dbt docs serve
```

---

## Siguiente paso

Confirmar si procedo con **Paso 1: Crear estructura del proyecto dbt**
