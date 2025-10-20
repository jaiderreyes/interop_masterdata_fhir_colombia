#!/bin/bash
# ============================================================
# 🩺 Script de laboratorio - Interoperabilidad en Salud FHIR
# Proyecto: interop_masterdata_fhir_colombia
# Autor: Jaider Reyes Herazo
# Descripción:
#   - Verifica instalación de Docker
#   - Levanta contenedores (PostgreSQL, HAPI-FHIR, Adminer)
#   - Ejecuta validaciones de datos automáticamente
#   - Abre el reporte HTML en navegador
# ============================================================

echo "🔎 Verificando instalación de Docker..."
if ! command -v docker &> /dev/null; then
  echo "Docker no está instalado. Instálalo antes de continuar."
  echo "En Ubuntu/Debian: sudo apt install docker.io -y"
  echo "En macOS: brew install --cask docker"
  echo "En Windows: instala Docker Desktop y habilita WSL2"
  exit 1
fi

echo " Creando carpeta reports/ si no existe..."
mkdir -p reports

echo "🐳 Levantando entorno con Docker Compose..."
docker-compose -f docker/docker-compose.yml up -d --build

if [ $? -ne 0 ]; then
  echo "⚠️ Hubo un error al levantar los contenedores. Revisa el archivo docker-compose.yml"
  exit 1
fi

echo "⏱️ Esperando 10 segundos para inicializar servicios..."
sleep 10

echo "✅ Entorno desplegado correctamente."
echo "📊 Contenedores activos:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo "🧪 Ejecutando validaciones de datos..."
docker logs interop_container --tail 100

echo "📂 Buscando último reporte generado..."
REPORT=$(ls -t reports/ge_report_*.html 2>/dev/null | head -n 1)

if [[ -n "$REPORT" ]]; then
  echo "📊 Último reporte generado: $REPORT"
  echo "🌐 Abriendo reporte en el navegador..."

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    xdg-open "$REPORT" >/dev/null 2>&1
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    open "$REPORT"
  elif grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null ; then
    explorer.exe "$(wslpath -w "$REPORT")"
  else
    echo "⚠️ No se pudo abrir automáticamente. Ábrelo manualmente en tu navegador."
  fi

else
  echo "⚠️ No se encontró ningún reporte generado en /reports."
  echo "👉 Ejecuta manualmente: docker logs interop_container"
fi

echo "✅ Laboratorio finalizado. Todo listo para comenzar a experimentar con FHIR 🚀"
