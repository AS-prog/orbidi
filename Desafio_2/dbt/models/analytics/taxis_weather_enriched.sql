-- Analytics layer: Taxi trips enriched with weather data
-- Dataset: analytics
-- Materialización: incremental (insert_overwrite por partición)

{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        partition_by={
            "field": "date",
            "data_type": "date",
            "granularity": "day"
        },
        cluster_by=["pickup_community_area", "temperature_category"],
        on_schema_change='append_new_columns'
    )
}}

with silver_taxis as (
    select * from {{ ref('silver_taxis') }}
    {% if is_incremental() %}
    where date > (select coalesce(max(date), '1900-01-01') from {{ this }})
    {% endif %}
),

silver_weather as (
    select * from {{ ref('silver_weather') }}
),

enriched as (
    select
        -- All taxi fields
        t.unique_key,
        t.date,
        t.trip_start_ts,
        t.trip_end_ts,
        t.start_hour,
        t.day_of_week,
        t.day_type,
        t.time_of_day,
        t.trip_seconds,
        t.trip_minutes,
        t.trip_miles,
        t.trip_km,
        t.avg_speed_mph,
        t.fare,
        t.tips,
        t.tolls,
        t.extras,
        t.trip_total,
        t.tip_percentage,
        t.cost_per_mile,
        t.payment_type,
        t.company,
        t.taxi_id,
        t.pickup_community_area,
        t.dropoff_community_area,
        t.pickup_lat,
        t.pickup_lon,
        t.dropoff_lat,
        t.dropoff_lon,
        t.is_valid_trip,

        -- Weather fields
        w.temperature_mean_c,
        w.temperature_category,
        w.precipitation_mm,
        w.precipitation_category,
        w.wind_speed_max_kmh,
        w.adverse_conditions,

        -- Metadata
        current_timestamp() as processed_at

    from silver_taxis t
    left join silver_weather w on t.date = w.date
)

select * from enriched
