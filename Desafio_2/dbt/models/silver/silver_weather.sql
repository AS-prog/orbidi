-- Silver layer: Curated weather data
-- Dataset: silver_data
-- Materialización: table

with stg_weather as (
    select * from {{ ref('stg_weather') }}
),

transformed as (
    select
        -- Primary key
        date,

        -- Temperatures (Celsius) with 2 decimal precision
        round(cast(temperature_mean as float64), 2) as temperature_mean_c,
        round(cast(temperature_max as float64), 2) as temperature_max_c,
        round(cast(temperature_min as float64), 2) as temperature_min_c,

        -- Temperature range
        round(cast(temperature_max as float64) - cast(temperature_min as float64), 2) as temperature_range_c,

        -- Precipitation (mm)
        round(cast(precipitation_sum as float64), 2) as precipitation_mm,
        round(cast(rain_sum as float64), 2) as rain_mm,
        round(cast(snowfall_sum as float64), 2) as snowfall_cm,

        -- Wind (km/h)
        round(cast(wind_speed_max as float64), 2) as wind_speed_max_kmh,

        -- Derived categories
        case
            when cast(temperature_mean as float64) < 0 then 'freezing'
            when cast(temperature_mean as float64) < 10 then 'cold'
            when cast(temperature_mean as float64) < 20 then 'mild'
            when cast(temperature_mean as float64) < 30 then 'warm'
            else 'hot'
        end as temperature_category,

        case
            when cast(precipitation_sum as float64) = 0 then 'dry'
            when cast(precipitation_sum as float64) < 5 then 'light_rain'
            when cast(precipitation_sum as float64) < 20 then 'moderate_rain'
            else 'heavy_rain'
        end as precipitation_category,

        -- Adverse conditions flag
        case
            when cast(snowfall_sum as float64) > 0
                 or cast(precipitation_sum as float64) > 10
                 or cast(wind_speed_max as float64) > 50
            then true
            else false
        end as adverse_conditions,

        -- Metadata
        current_timestamp() as processed_at

    from stg_weather
)

select * from transformed
order by date
