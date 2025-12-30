#!/bin/bash
# ==============================================================================
# Script: set_bigquery_quotas.sh
# Configura cuotas de BigQuery por usuario (2GB/día por defecto)
# ==============================================================================

set -e

PROJECT_ID="${PROJECT_ID:-orbidi-challenge}"
QUOTA_GB="${QUOTA_GB:-2}"
QUOTA_BYTES=$((QUOTA_GB * 1024 * 1024 * 1024))

# Lista de usuarios con acceso limitado
USERS=(
  "estefaniacanon@gmail.com"
)

echo "=============================================="
echo "Configurando cuotas BigQuery - ${QUOTA_GB}GB/día"
echo "Proyecto: ${PROJECT_ID}"
echo "=============================================="

for USER_EMAIL in "${USERS[@]}"; do
  echo ""
  echo "Usuario: ${USER_EMAIL}"
  echo "Cuota: ${QUOTA_GB}GB (${QUOTA_BYTES} bytes)"

  # Intentar con gcloud alpha
  if gcloud alpha bq update-per-user-quota \
    --project="${PROJECT_ID}" \
    --user="${USER_EMAIL}" \
    --custom-quota="${QUOTA_BYTES}" 2>/dev/null; then
    echo "✅ Cuota configurada exitosamente"
  else
    echo "⚠️  gcloud alpha no disponible. Configurar manualmente:"
    echo ""
    echo "   1. Ir a: https://console.cloud.google.com/bigquery?project=${PROJECT_ID}"
    echo "   2. Administración > Cuotas"
    echo "   3. Buscar 'Query usage per user per day'"
    echo "   4. Editar y agregar override para ${USER_EMAIL}: ${QUOTA_BYTES} bytes"
    echo ""
  fi
done

echo ""
echo "=============================================="
echo "Para verificar cuotas configuradas:"
echo "gcloud alpha bq show-per-user-quota --project=${PROJECT_ID}"
echo "=============================================="
