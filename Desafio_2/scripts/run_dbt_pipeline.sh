#!/bin/bash
# ==============================================================================
# Script: run_dbt_pipeline.sh
# Ejecuta el pipeline completo de dbt + aplica policy tags
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DBT_DIR="${PROJECT_ROOT}/dbt"

echo "=============================================="
echo "dbt Pipeline - $(date)"
echo "=============================================="

cd "$DBT_DIR"

# Step 1: Verificar conexión
echo ""
echo "[1/4] Verificando conexión a BigQuery..."
uv run dbt debug --profiles-dir . --quiet

# Step 2: Ejecutar modelos (incremental)
echo ""
echo "[2/4] Ejecutando modelos dbt (incremental)..."
uv run dbt run --profiles-dir .

# Step 3: Ejecutar tests
echo ""
echo "[3/4] Ejecutando tests..."
uv run dbt test --profiles-dir .

# Step 4: Aplicar policy tags
echo ""
echo "[4/4] Aplicando policy tags..."
if [ -f "${SCRIPT_DIR}/apply_policy_tags.sh" ]; then
    "${SCRIPT_DIR}/apply_policy_tags.sh" || echo "⚠️ Policy tags pueden requerir aplicación manual"
else
    echo "⚠️ Script apply_policy_tags.sh no encontrado"
fi

echo ""
echo "=============================================="
echo "Pipeline completado exitosamente"
echo "=============================================="
