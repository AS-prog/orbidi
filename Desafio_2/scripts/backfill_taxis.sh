#!/bin/bash
# ==============================================================================
# Script para cargar datos históricos de taxis en lotes
# ==============================================================================
# Uso: ./backfill_taxis.sh
# 
# Procesa datos de taxis desde 2023-06-01 hasta 2023-12-31 en lotes mensuales
# para evitar timeouts de Cloud Functions (máx 540s)
# ==============================================================================

FUNCTION_URL="https://ingest-taxis-eviwr2rngq-ew.a.run.app"

# Definir rangos mensuales
declare -a RANGES=(
    "2023-06-01,2023-06-30"
    "2023-07-01,2023-07-31"
    "2023-08-01,2023-08-31"
    "2023-09-01,2023-09-30"
    "2023-10-01,2023-10-31"
    "2023-11-01,2023-11-30"
    "2023-12-01,2023-12-31"
)

echo "🚕 Iniciando backfill de datos de taxis..."
echo "📅 Rango total: 2023-06-01 a 2023-12-31"
echo "================================================"

for range in "${RANGES[@]}"; do
    IFS=',' read -r START END <<< "$range"
    
    echo ""
    echo "📆 Procesando: $START a $END"
    echo "⏳ Esto puede tomar varios minutos..."
    
    RESPONSE=$(curl -s "${FUNCTION_URL}?mode=range&start_date=${START}&end_date=${END}")
    
    # Extraer información del response
    STATUS=$(echo $RESPONSE | python3 -c "import sys, json; print(json.load(sys.stdin).get('status', 'unknown'))" 2>/dev/null)
    MESSAGE=$(echo $RESPONSE | python3 -c "import sys, json; print(json.load(sys.stdin).get('message', 'No message'))" 2>/dev/null)
    NEW_DATES=$(echo $RESPONSE | python3 -c "import sys, json; print(json.load(sys.stdin).get('new_dates_processed', 0))" 2>/dev/null)
    
    if [ "$STATUS" == "success" ] || [ "$STATUS" == "partial_success" ]; then
        echo "✅ $STATUS: $MESSAGE"
        echo "   Días procesados: $NEW_DATES"
    else
        echo "❌ Error: $MESSAGE"
        echo "   Response completo: $RESPONSE"
    fi
    
    # Pequeña pausa entre lotes
    sleep 2
done

echo ""
echo "================================================"
echo "🎉 Backfill completado!"
echo ""
echo "Para verificar los datos:"
echo "  gsutil ls gs://orbidi-challenge-data-landing/taxis/ | wc -l"
