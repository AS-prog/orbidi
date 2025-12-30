#!/bin/bash
# ==============================================================================
# Script: apply_policy_tags.sh
# Aplica policy tags de seguridad a columnas sensibles después de dbt run
# ==============================================================================

set -e

PROJECT_ID="${PROJECT_ID:-orbidi-challenge}"
DATASET="analytics"
TABLE="taxis_weather_enriched"
COLUMN="payment_type"

# Obtener el policy tag desde terraform output
cd "$(dirname "$0")/../terraform/environments/dev"
POLICY_TAG=$(terraform output -raw payment_policy_tag 2>/dev/null)

if [ -z "$POLICY_TAG" ]; then
    echo "Error: No se pudo obtener el policy tag. Ejecuta 'terraform apply' primero."
    exit 1
fi

echo "Aplicando policy tag a ${PROJECT_ID}:${DATASET}.${TABLE}.${COLUMN}"
echo "Policy Tag: ${POLICY_TAG}"

# Obtener schema actual
TEMP_DIR=$(mktemp -d)
bq --project_id=${PROJECT_ID} show --format=prettyjson --schema ${PROJECT_ID}:${DATASET}.${TABLE} > "${TEMP_DIR}/current_schema.json"

# Modificar schema para agregar policy tag
python3 << EOF
import json

with open('${TEMP_DIR}/current_schema.json') as f:
    schema = json.load(f)

modified = False
for field in schema:
    if field['name'] == '${COLUMN}':
        field['policyTags'] = {'names': ['${POLICY_TAG}']}
        modified = True
        print(f"Policy tag agregado a columna: {field['name']}")

if not modified:
    print(f"Advertencia: Columna '${COLUMN}' no encontrada en el schema")
    exit(1)

with open('${TEMP_DIR}/new_schema.json', 'w') as f:
    json.dump(schema, f, indent=2)
EOF

# Aplicar nuevo schema
bq --project_id=${PROJECT_ID} update ${PROJECT_ID}:${DATASET}.${TABLE} "${TEMP_DIR}/new_schema.json"

# Limpiar
rm -rf "${TEMP_DIR}"

echo "Policy tag aplicado exitosamente."
