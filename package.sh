#!/bin/bash
# ============================================================
# Script de empaquetado del proyecto
# Proyecto: interop_masterdata_fhir_colombia
# Autor: Jaider Reyes Herazo
# Descripción:
#   - Empaqueta todos los archivos del laboratorio en un ZIP
#   - Archivo final: interop_masterdata_fhir_colombia.zip
# ============================================================

echo "📦 Empaquetando proyecto interop_masterdata_fhir_colombia.zip ..."

# Crear el ZIP con toda la estructura del laboratorio
zip -r interop_masterdata_fhir_colombia.zip \
  README.md \
  docker/ \
  tests/ \
  catalogo/ \
  fhir_mapping/ \
  reports/ \
  requirements.txt \
  run_lab.sh

# Verificar resultado
if [ $? -eq 0 ]; then
  echo "✅ ZIP creado con éxito: interop_masterdata_fhir_colombia.zip"
  echo "📁 El archivo está listo para entregar o compartir."
else
  echo "❌ Hubo un error al crear el ZIP. Verifica que 'zip' esté instalado."
  echo "👉 En Ubuntu/Debian: sudo apt install zip -y"
  echo "👉 En macOS: brew install zip"
fi
