{% macro generate_schema_name(custom_schema_name, node) -%}
    {#
        Override default schema generation.
        When custom_schema is set, use it exactly (without default prefix).
        Otherwise use the target schema (default dataset).
    #}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
