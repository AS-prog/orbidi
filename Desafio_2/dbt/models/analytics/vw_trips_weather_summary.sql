-- Analytics layer: Aggregated trips by weather conditions for Looker Studio
-- Dataset: analytics
-- Purpose: Answer the Chicago Mayor's question: "Does weather affect taxi trip duration?"
-- Materialización: view (bajo costo, siempre actualizado)

{{
    config(
        materialized='view'
    )
}}

with valid_trips as (
    select *
    from {{ ref('taxis_weather_enriched') }}
    where is_valid_trip = true
),

-- Agregación principal por fecha y condiciones climáticas
daily_weather_summary as (
    select
        -- Dimensiones temporales
        date,
        day_of_week,
        day_type,
        time_of_day,

        -- Dimensiones climáticas
        temperature_category,
        precipitation_category,
        adverse_conditions,

        -- Métricas de viajes
        count(*) as total_trips,

        -- Duración del viaje
        avg(trip_minutes) as avg_duration_min,
        min(trip_minutes) as min_duration_min,
        max(trip_minutes) as max_duration_min,
        approx_quantiles(trip_minutes, 2)[offset(1)] as median_duration_min,
        stddev(trip_minutes) as stddev_duration_min,

        -- Distancia
        avg(trip_miles) as avg_distance_miles,
        sum(trip_miles) as total_distance_miles,

        -- Velocidad
        avg(avg_speed_mph) as avg_speed_mph,

        -- Tarifas
        avg(trip_total) as avg_fare,
        sum(trip_total) as total_revenue,
        avg(tip_percentage) as avg_tip_pct,

        -- Clima detallado (para contexto)
        avg(temperature_mean_c) as avg_temperature_c,
        avg(precipitation_mm) as avg_precipitation_mm,
        avg(wind_speed_max_kmh) as avg_wind_speed_kmh

    from valid_trips
    group by 1, 2, 3, 4, 5, 6, 7
)

select * from daily_weather_summary
