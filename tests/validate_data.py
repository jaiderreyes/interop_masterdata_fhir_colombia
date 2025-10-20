#!/usr/bin/env python3
# ================================================================
# 🩺 validate_data.py - Interoperabilidad en Salud FHIR
# Proyecto: interop_masterdata_fhir_colombia
# Autor: Jaider Reyes Herazo
# Descripción:
#   - Se conecta a PostgreSQL usando psycopg2
#   - Ejecuta validaciones estructurales, de dominio y referenciales
#   - Genera un reporte HTML con timestamp en /reports/
#   - Produce gráficos estadísticos con matplotlib
# ================================================================

import psycopg2
import pandas as pd
import matplotlib.pyplot as plt
import os
from datetime import datetime

# 📁 Crear carpeta reports si no existe
os.makedirs("reports", exist_ok=True)

# 📅 Timestamp para el nombre del reporte
timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M")
report_path = f"reports/ge_report_{timestamp}.html"

# 🐘 Conexión a PostgreSQL
conn = psycopg2.connect(
    host="localhost",   # Cambia a "postgres" si ejecutas dentro del contenedor
    port="5432",
    dbname="interop_db",
    user="postgres",
    password="postgres"
)

# ✨ Función auxiliar para ejecutar queries y devolver DataFrame
def query_df(sql):
    return pd.read_sql_query(sql, conn)

# 📊 Diccionario de validaciones
validations = {
    "usuario": {
        "sql": "SELECT * FROM usuario;",
        "tests": [
            ("documento_id uniqueness", "SELECT documento_id, COUNT(*) FROM usuario GROUP BY documento_id HAVING COUNT(*) > 1;"),
            ("sexo domain", "SELECT DISTINCT sexo FROM usuario WHERE sexo NOT IN ('Masculino','Femenino','Intersexual','No especificado');")
        ]
    },
    "atencion": {
        "sql": "SELECT * FROM atencion;",
        "tests": [
            ("FK usuario", "SELECT a.documento_id FROM atencion a LEFT JOIN usuario u ON a.documento_id=u.documento_id WHERE u.documento_id IS NULL;")
        ]
    },
    "diagnostico": {
        "sql": "SELECT * FROM diagnostico;",
        "tests": [
            ("FK atencion", "SELECT d.atencion_id FROM diagnostico d LEFT JOIN atencion a ON d.atencion_id=a.atencion_id WHERE a.atencion_id IS NULL;")
        ]
    },
    "tecnologia_salud": {
        "sql": "SELECT * FROM tecnologia_salud;",
        "tests": [
            ("FK atencion", "SELECT t.atencion_id FROM tecnologia_salud t LEFT JOIN atencion a ON t.atencion_id=a.atencion_id WHERE a.atencion_id IS NULL;")
        ]
    },
    "egreso": {
        "sql": "SELECT * FROM egreso;",
        "tests": [
            ("FK atencion", "SELECT e.atencion_id FROM egreso e LEFT JOIN atencion a ON e.atencion_id=a.atencion_id WHERE a.atencion_id IS NULL;")
        ]
    }
}

# 📈 Reporte HTML
html = f"""
<html>
<head>
<title>Data Quality Report - {timestamp}</title>
<style>
body {{ font-family: Arial, sans-serif; margin: 20px; }}
h1 {{ color: #2F4F4F; }}
table {{ border-collapse: collapse; width: 100%; margin-bottom: 20px; }}
th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
th {{ background-color: #2F4F4F; color: white; }}
.warning {{ color: red; font-weight: bold; }}
</style>
</head>
<body>
<h1>📊 Data Quality Report</h1>
<p><b>Generated:</b> {timestamp}</p>
"""

print("🔎 Ejecutando validaciones de datos...\n")

# 🧪 Validaciones por tabla
for table, info in validations.items():
    df = query_df(info["sql"])
    html += f"<h2>📁 Tabla: {table}</h2>"
    html += f"<p>Total registros: <b>{len(df)}</b></p>"

    # 📊 Estadísticas descriptivas básicas
    html += df.describe(include='all').to_html(classes="table table-striped")

    # 🧪 Ejecutar pruebas definidas
    for name, test_sql in info["tests"]:
        result = query_df(test_sql)
        if not result.empty:
            print(f"⚠️ Advertencia: {name} - {len(result)} filas problemáticas en {table}")
            html += f"<p class='warning'>⚠️ {name}: {len(result)} filas problemáticas.</p>"
            html += result.to_html()
        else:
            print(f"✅ OK: {name}")
            html += f"<p>✅ {name}: sin problemas detectados.</p>"

    # 📉 Gráfico de conteo por columnas no nulas
    non_null_counts = df.count()
    plt.figure(figsize=(8, 4))
    non_null_counts.plot(kind='bar', title=f"Non-null counts - {table}")
    plt.tight_layout()
    img_path = f"reports/{table}_non_null_{timestamp}.png"
    plt.savefig(img_path)
    plt.close()
    html += f'<img src="{img_path}" alt="Non-null counts - {table}" style="width:100%"><br>'

# 📊 Finalizar HTML
html += """
</body>
</html>
"""

with open(report_path, "w", encoding="utf-8") as f:
    f.write(html)

conn.close()

print("\n✅ Validación completada.")
print(f"📁 Reporte generado en: {report_path}")
