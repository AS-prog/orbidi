-- Staging model for weather data
-- Materialización: ephemeral (CTE, no genera tabla)

with source as (
    select * from {{ source('raw_data', 'weather_daily_ext') }}
),

renamed as (
    select
        date,
        temperature_mean,
        temperature_max,
        temperature_min,
        precipitation_sum,
        rain_sum,
        snowfall_sum,
        wind_speed_max
    from source
)

select * from renamed
