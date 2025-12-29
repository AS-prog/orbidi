-- Staging model for taxi trips data
-- Materialización: ephemeral (CTE, no genera tabla)

with source as (
    select * from {{ source('raw_data', 'taxi_trips_ext') }}
),

renamed as (
    select
        unique_key,
        taxi_id,
        trip_start_timestamp,
        trip_end_timestamp,
        trip_seconds,
        trip_miles,
        fare,
        tips,
        tolls,
        extras,
        trip_total,
        payment_type,
        company,
        pickup_community_area,
        dropoff_community_area,
        pickup_latitude,
        pickup_longitude,
        dropoff_latitude,
        dropoff_longitude
    from source
    where trip_start_timestamp is not null
)

select * from renamed
