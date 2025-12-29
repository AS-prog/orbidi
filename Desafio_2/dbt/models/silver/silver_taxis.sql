-- Silver layer: Curated taxi trips data
-- Dataset: silver_data
-- Materialización: table

{{
    config(
        materialized='table',
        partition_by={
            "field": "date",
            "data_type": "date",
            "granularity": "day"
        },
        cluster_by=["pickup_community_area", "payment_type"]
    )
}}

with stg_taxis as (
    select * from {{ ref('stg_taxis') }}
),

transformed as (
    select
        -- Primary key and partition
        unique_key,
        cast(trip_start_timestamp as date) as date,

        -- Timestamps
        trip_start_timestamp as trip_start_ts,
        trip_end_timestamp as trip_end_ts,

        -- Time extractions
        extract(hour from trip_start_timestamp) as start_hour,
        extract(dayofweek from trip_start_timestamp) as day_of_week,
        case
            when extract(dayofweek from trip_start_timestamp) in (1, 7) then 'weekend'
            else 'weekday'
        end as day_type,
        case
            when extract(hour from trip_start_timestamp) between 6 and 9 then 'morning_rush'
            when extract(hour from trip_start_timestamp) between 10 and 15 then 'midday'
            when extract(hour from trip_start_timestamp) between 16 and 19 then 'evening_rush'
            when extract(hour from trip_start_timestamp) between 20 and 23 then 'night'
            else 'late_night'
        end as time_of_day,

        -- Trip duration
        cast(trip_seconds as int64) as trip_seconds,
        round(cast(trip_seconds as float64) / 60, 2) as trip_minutes,

        -- Distance
        round(cast(trip_miles as float64), 2) as trip_miles,
        round(cast(trip_miles as float64) * 1.60934, 2) as trip_km,

        -- Average speed (only if trip_seconds > 0)
        case
            when cast(trip_seconds as int64) > 0
            then round((cast(trip_miles as float64) / (cast(trip_seconds as float64) / 3600)), 2)
            else null
        end as avg_speed_mph,

        -- Financial metrics
        round(cast(fare as float64), 2) as fare,
        round(cast(tips as float64), 2) as tips,
        round(cast(tolls as float64), 2) as tolls,
        round(cast(extras as float64), 2) as extras,
        round(cast(trip_total as float64), 2) as trip_total,

        -- Tip percentage
        case
            when cast(fare as float64) > 0
            then round((cast(tips as float64) / cast(fare as float64)) * 100, 2)
            else 0
        end as tip_percentage,

        -- Cost per mile
        case
            when cast(trip_miles as float64) > 0
            then round(cast(trip_total as float64) / cast(trip_miles as float64), 2)
            else null
        end as cost_per_mile,

        -- Categories
        coalesce(cast(payment_type as string), 'Unknown') as payment_type,
        coalesce(cast(company as string), 'Unknown') as company,
        cast(taxi_id as string) as taxi_id,

        -- Location
        cast(pickup_community_area as int64) as pickup_community_area,
        cast(dropoff_community_area as int64) as dropoff_community_area,
        cast(pickup_latitude as float64) as pickup_lat,
        cast(pickup_longitude as float64) as pickup_lon,
        cast(dropoff_latitude as float64) as dropoff_lat,
        cast(dropoff_longitude as float64) as dropoff_lon,

        -- Valid trip flag
        case
            when cast(trip_seconds as int64) > 0
                 and cast(trip_miles as float64) > 0
                 and cast(fare as float64) >= 0
            then true
            else false
        end as is_valid_trip,

        -- Metadata
        current_timestamp() as processed_at

    from stg_taxis
)

select * from transformed
