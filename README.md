# interop_masterdata_fhir_colombia — Lab README
**Fecha:** 2025-10-19  
**Autor:** Equipo académico-productivo (Jaider + GPT Lab)

> Laboratorio académico con carácter productivo para la **Historia Clínica Electrónica Interoperable** en Colombia, integrando **datos maestros**, **validación de calidad**, **HL7-FHIR R4** y despliegue con **Docker**.

---

## 🎯 Objetivos del laboratorio
- Construir y gobernar un **catálogo de datos maestros** (con CIE-10, ISO-3166, SNOMED, UCUM).
- Desplegar un **PostgreSQL** con esquema clínico (`hcd`) y datos de ejemplo.
- Ejecutar **validaciones automáticas** (script Python 3.8) y generar reporte HTML.
- Probar **mapeos HL7-FHIR R4** (Patient, Encounter, Condition, MedicationAdministration, Practitioner) en **HAPI-FHIR**.
- Integrar **tests de dbt** (integridad y dominios).

---

## 🧾 Marco normativo y técnico
- 🇨🇴 Ley 1581 de 2012 — Protección de datos personales.
- 🇨🇴 Resolución 1995 de 1999 — Manejo de la historia clínica.
- 🇨🇴 Resolución 866 de 2021 — Historia Clínica Electrónica interoperable (HCEi).
- 🌐 HL7 FHIR **R4** — Interoperabilidad clínica.
- 📑 **CIE-10**, 🌎 **ISO-3166**, 🧬 **SNOMED CT** (muestras), ⚗️ **UCUM**.

> Nota: Los ejemplos SNOMED se usan **con fines educativos** (no sustituyen licencia ni set oficial).

---

## 📦 Estructura del proyecto
```
interop_masterdata_fhir_colombia/
├─ catalogo/
│  └─ masterdata_interoperabilidad_salud.xlsx
├─ docker/
│  └─ init.sql
├─ tests/
│  ├─ great_expectations.yml
│  ├─ dbt_schema.yml
│  └─ validate_data.py
├─ fhir_mapping/
│  ├─ Patient.json
│  ├─ Encounter.json
│  ├─ Condition.json
│  ├─ MedicationAdministration.json
│  └─ Practitioner.json
└─ reports/   ← se genera automáticamente para los reportes HTML
```
> Si alguna carpeta no existe (p. ej. `reports/`), créala manualmente.

---

## 🖥️ Requisitos previos
- **Docker** o **Docker Desktop** (Windows/macOS).
- **Python 3.8** en el host (si ejecutas validaciones manuales).
- (Opcional) **dbt Core** para correr `dbt test`.

---

## ⚙️ Despliegue rápido (Docker Compose — ejemplo mínimo)
Crea un archivo `docker-compose.yml` **en el directorio raíz del proyecto** con el siguiente contenido:

```yaml
version: "3.9"
services:
  postgres:
    image: postgres:14
    container_name: interop_postgres
    environment:
      POSTGRES_PASSWORD: postgres
      POSTGRES_USER: postgres
      POSTGRES_DB: interop_db
    ports:
      - "5432:5432"
    volumes:
      - ./docker/init.sql:/docker-entrypoint-initdb.d/init.sql:ro

  hapi:
    image: hapiproject/hapi:latest
    container_name: interop_hapi
    ports:
      - "8080:8080"
    depends_on:
      - postgres

  adminer:
    image: adminer
    container_name: interop_adminer
    ports:
      - "8081:8080"
    depends_on:
      - postgres

  interop_container:
    image: python:3.8-slim
    container_name: interop_container
    depends_on:
      - postgres
    working_dir: /work
    volumes:
      - ./:/work
      - ./reports:/reports
    # ⚠️ validate_data.py usa 'localhost' como host de DB.
    # Para ejecutarlo dentro del contenedor, reemplazamos 'localhost' por 'postgres' on-the-fly.
    command: >
      bash -lc "
        pip install --no-cache-dir psycopg2-binary pandas matplotlib &&
        sed -i "s/\"host\": \"localhost\"/\"host\": \"postgres\"/" tests/validate_data.py &&
        python tests/validate_data.py &&
        tail -f /dev/null
      "
```

> **Por qué ese `sed`:** el script `tests/validate_data.py` está configurado para `localhost` en el host. En Docker, el servicio de BD se llama `postgres`. Con ese comando lo ajustamos automáticamente **solo dentro del contenedor**.

### ▶️ Levantar el entorno
```bash
docker-compose up -d
```

- `postgres` expone **5432**
- `hapi` expone **8080**
- `adminer` expone **8081**
- `interop_container` ejecuta **validate_data.py** automáticamente y deja el reporte en `reports/`

### 🌐 Accesos rápidos
- Adminer (GUI BD): http://localhost:8081  → **System:** PostgreSQL, **Server:** postgres, **User/Pass:** postgres/postgres, **Database:** interop_db
- HAPI-FHIR: http://localhost:8080/fhir/

---

## 🧪 Validaciones automáticas (Python 3.8 + Matplotlib)
El script `tests/validate_data.py`:
- Conecta a `interop_db` (esquema `hcd`)
- Ejecuta validaciones estructurales y clínicas
- Genera un **reporte HTML con timestamp** en `reports/ge_report_YYYY-MM-DD_HH-MM.html`
- **No detiene** el contenedor si encuentra errores; muestra advertencias

### Ejecutar manualmente (opcional)
**Linux / macOS:**
```bash
python3 -m pip install --user psycopg2-binary pandas matplotlib
python3 tests/validate_data.py
open reports/ge_report_*.html   # macOS
xdg-open reports/ge_report_*.html  # Linux
```

**Windows (PowerShell):**
```powershell
py -m pip install psycopg2-binary pandas matplotlib
py tests/validate_data.py
start .\reports\ge_report_*.html
```

---

## 📊 Tests de dbt (integridad y dominios)
1) Instala `dbt-postgres` en tu host (o en un contenedor dedicado).  
2) Crea un proyecto base (ejemplo):
```bash
dbt init interop_dbt
cd interop_dbt
mkdir -p models/hcd
```
3) Copia `tests/dbt_schema.yml` dentro de `models/hcd/schema.yml`.  
4) Configura `profiles.yml` (ruta depende de OS) apuntando a `interop_db` y `schema: hcd`.  
Ejemplo de perfil:
```yaml
interop_dbt:
  target: dev
  outputs:
    dev:
      type: postgres
      host: localhost
      user: postgres
      password: postgres
      port: 5432
      dbname: interop_db
      schema: hcd
      threads: 4
```
5) Ejecuta los tests:
```bash
dbt debug
dbt test
```

---

## 🩺 HL7-FHIR R4 — carga de recursos de ejemplo
Están en `fhir_mapping/` con **IDs simples** y comentarios didácticos.

**Patient:**
```bash
curl -X POST -H "Content-Type: application/fhir+json"   -d @fhir_mapping/Patient.json http://localhost:8080/fhir/Patient
```

**Encounter:**
```bash
curl -X POST -H "Content-Type: application/fhir+json"   -d @fhir_mapping/Encounter.json http://localhost:8080/fhir/Encounter
```

**Condition:**
```bash
curl -X POST -H "Content-Type: application/fhir+json"   -d @fhir_mapping/Condition.json http://localhost:8080/fhir/Condition
```

**MedicationAdministration:**
```bash
curl -X POST -H "Content-Type: application/fhir+json"   -d @fhir_mapping/MedicationAdministration.json http://localhost:8080/fhir/MedicationAdministration
```

**Practitioner:**
```bash
curl -X POST -H "Content-Type: application/fhir+json"   -d @fhir_mapping/Practitioner.json http://localhost:8080/fhir/Practitioner
```

> Verifica los recursos en el navegador:  
> - `http://localhost:8080/fhir/Patient/1001001001`  
> - `http://localhost:8080/fhir/Encounter/1`

---

## ⚡ (Opcional) Citus / Distribución
Si despliegas Citus, habilita la extensión y distribuye tablas (ver `docker/init.sql`):
```sql
-- En la BD interop_db:
CREATE EXTENSION IF NOT EXISTS citus;

-- Referencia (no particionadas, pequeñas)
SELECT create_reference_table('hcd.usuario');
SELECT create_reference_table('hcd.profesional_salud');

-- Tablas de eventos, colocaladas por atención
SELECT create_distributed_table('hcd.atencion', 'documento_id');
SELECT create_distributed_table('hcd.diagnostico', 'atencion_id', colocate_with => 'hcd.atencion');
SELECT create_distributed_table('hcd.tecnologia_salud', 'atencion_id', colocate_with => 'hcd.atencion');
SELECT create_distributed_table('hcd.egreso', 'atencion_id', colocate_with => 'hcd.atencion');
```

---

## 🧩 Retos para estudiantes (evaluables)
1. **Observation.json:** crear un recurso FHIR de signos vitales y publicarlo en HAPI-FHIR.  
2. **Nuevos catálogos:** agregar un país a ISO-3166 o un código CIE-10 y validar con el script.  
3. **dbt:** provocar un error de dominio (p. ej., `sexo='X'`) y hacer que un test falle; documentar el fix.  
4. **Query clínica:** construir una vista SQL de pacientes con HTA (`I10`) y su medicación activa.

---

## 🛠️ Solución de problemas
- **`psycopg2` no compila (host):** usa `psycopg2-binary`.  
- **Puertos ocupados 5432/8080/8081:** cambia el mapeo en `docker-compose.yml`.  
- **Windows:** habilita WSL2 y back-end de Docker Desktop.  
- **Reporte no aparece:** revisa logs de `interop_container`; confirma que existe `reports/` y que el script se ejecutó.

---

## 🔒 Sensibilidad de datos
El catálogo clasifica **ALTA / MEDIA / BAJA** acorde a Ley 1581: evita registrar datos reales; usa solo datos de ejemplo.

---

## 📜 Licencias y uso de terminologías
- **SNOMED CT**: se incluyen **muestras** con fines educativos. Para uso productivo consulta licenciamiento.  
- **CIE-10, ISO-3166, UCUM**: catálogos de uso referencial académico.

---

### ✅ Checklist rápido
- [ ] `docker/init.sql` montado y BD creada (`interop_db` / esquema `hcd`)  
- [ ] `tests/validate_data.py` ejecutado y `reports/ge_report_*.html` generado  
- [ ] Recursos FHIR publicados en `http://localhost:8080/fhir/`  
- [ ] `dbt test` ejecutado (opcional)

---

¡Éxitos y buen laboratorio! 🔬💻
