
-- =====================================================================
--  interop_masterdata_fhir_colombia / docker/init.sql
--  Propósito: Inicializar esquema HCD con catálogos, tablas clínicas,
--             constraints, distribución Citus (opcional) e inserción
--             de datos de ejemplo.
--  Autor: generado por asistente
--  Fecha: 2025-10-19
--  Notas:
--   - Compatible con PostgreSQL 14+ y Citus 11+ (opcional).
--   - Comentado con enfoque académico y carácter productivo.
--   - Campos mapeables a HL7 FHIR R4 (Patient, Encounter, Condition,
--     MedicationAdministration, Practitioner).
-- =====================================================================

-- [0] CONFIGURACIÓN INICIAL ----------------------------------------------------
CREATE SCHEMA IF NOT EXISTS hcd;
SET search_path TO hcd, public;

-- Activar extensiones útiles (idempotentes)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- CREATE EXTENSION IF NOT EXISTS citus; -- Descomenta si usas Citus

-- =====================================================================
-- [1] CATÁLOGOS DE REFERENCIA (para validar dominios de datos)
--     Incluye: ISO-3166 (país), UCUM (unidades), CIE-10 (diagnósticos),
--              SNOMED (muestra: rutas de administración y términos clave)
-- =====================================================================

-- 1.1 ISO-3166: países (alfabético-2 como clave)
DROP TABLE IF EXISTS catalogo_iso3166 CASCADE;
CREATE TABLE catalogo_iso3166 (
    code VARCHAR(3) PRIMARY KEY,   -- 'CO', 'US', 'BR' (alpha-2) o 'COL' (alpha-3)
    name VARCHAR(100) NOT NULL
);

INSERT INTO catalogo_iso3166 (code, name) VALUES
('CO','Colombia'),
('US','Estados Unidos'),
('BR','Brasil'),
('AR','Argentina'),
('MX','México'),
('CL','Chile'),
('PE','Perú'),
('ES','España'),
('FR','Francia'),
('DE','Alemania');

-- 1.2 UCUM: unidades clínicas de medida
DROP TABLE IF EXISTS catalogo_ucum CASCADE;
CREATE TABLE catalogo_ucum (
    code VARCHAR(20) PRIMARY KEY,  -- 'mg','g','mL','h','d','IU'
    description VARCHAR(120) NOT NULL
);

INSERT INTO catalogo_ucum (code, description) VALUES
('mg','milligram'),
('g','gram'),
('mL','milliliter'),
('L','liter'),
('IU','international unit'),
('h','hour'),
('d','day'),
('kg','kilogram'),
('mcg','microgram'),
('tab','tablet');

-- 1.3 CIE-10: diagnósticos (muestra)
DROP TABLE IF EXISTS catalogo_cie10 CASCADE;
CREATE TABLE catalogo_cie10 (
    codigo VARCHAR(8) PRIMARY KEY,        -- 'E11', 'I10', etc.
    descripcion VARCHAR(255) NOT NULL
);

INSERT INTO catalogo_cie10 (codigo, descripcion) VALUES
('A00','Cólera'),
('B20','Enfermedad por VIH'),
('E11','Diabetes mellitus tipo 2'),
('I10','Hipertensión esencial (primaria)'),
('J45','Asma'),
('K21','Enfermedad por reflujo gastroesofágico'),
('N39','Otros trastornos del tracto urinario'),
('O80','Parto único espontáneo'),
('S06','Traumatismo intracraneal'),
('Z00','Examen general de personas sin quejas o diagnóstico');

-- 1.4 SNOMED (muestra mínima para el laboratorio)
-- Nota: este set es educativo (no sustituye licencia ni set oficial)
DROP TABLE IF EXISTS catalogo_snomed CASCADE;
CREATE TABLE catalogo_snomed (
    concept_id VARCHAR(20) PRIMARY KEY,
    term VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL           -- p.ej. 'route','allergy','procedure'
);

-- Rutas de administración (ejemplos)
INSERT INTO catalogo_snomed (concept_id, term, category) VALUES
('26643006','Vía oral','route'),           -- Oral route
('46713006','Vía intravenosa','route'),    -- Intravenous route
('78421000','Vía intramuscular','route');  -- Intramuscular route

-- Términos clínicos frecuentes (ejemplos)
INSERT INTO catalogo_snomed (concept_id, term, category) VALUES
('91936005','Alergia a penicilina','allergy'),
('235595009','Procedimiento de administración de medicamento','procedure');

-- =====================================================================
-- [2] TABLAS CLÍNICAS PRINCIPALES CON CONSTRAINTS Y FKs
--     Basadas en el esquema provisto por el usuario
-- =====================================================================

-- 2.1 USUARIO (Patient)
DROP TABLE IF EXISTS usuario CASCADE;
CREATE TABLE usuario (
    documento_id      BIGINT PRIMARY KEY,
    pais_nacionalidad VARCHAR(100) NOT NULL,     -- Recomendado: almacenar alpha-2 o alpha-3
    nombre_completo   VARCHAR(255) NOT NULL,
    fecha_nacimiento  DATE NOT NULL,
    edad              INT GENERATED ALWAYS AS (EXTRACT(YEAR FROM age(current_date, fecha_nacimiento))) STORED,
    sexo              VARCHAR(10) NOT NULL,
    genero            VARCHAR(20),
    ocupacion         VARCHAR(100),
    voluntad_anticipada BOOLEAN DEFAULT FALSE,
    categoria_discapacidad VARCHAR(50),
    pais_residencia   VARCHAR(100),
    municipio_residencia VARCHAR(100),
    etnia             VARCHAR(50),
    comunidad_etnica  VARCHAR(100),
    zona_residencia   VARCHAR(50),
    CONSTRAINT chk_usuario_sexo CHECK (sexo IN ('M','F','Intersex')),
    CONSTRAINT chk_usuario_zona CHECK (zona_residencia IS NULL OR zona_residencia IN ('Urbana','Rural','Dispersa'))
);

-- Buenas prácticas: referenciar países a ISO-3166 (alpha-2/3) aunque la columna sea VARCHAR(100)
ALTER TABLE usuario
    ADD CONSTRAINT fk_usuario_pais_nacionalidad
        FOREIGN KEY (pais_nacionalidad) REFERENCES catalogo_iso3166(code) ON UPDATE CASCADE,
    ADD CONSTRAINT fk_usuario_pais_residencia
        FOREIGN KEY (pais_residencia) REFERENCES catalogo_iso3166(code) ON UPDATE CASCADE;

CREATE INDEX idx_usuario_nombre ON usuario (nombre_completo);

-- 2.2 ATENCIÓN (Encounter)
DROP TABLE IF EXISTS atencion CASCADE;
CREATE TABLE atencion (
    atencion_id        SERIAL PRIMARY KEY,
    documento_id       BIGINT NOT NULL,
    entidad_salud      VARCHAR(255) NOT NULL,
    fecha_ingreso      TIMESTAMP NOT NULL,
    modalidad_entrega  VARCHAR(50) NOT NULL,     -- 'Presencial','Telemedicina','Domiciliaria'
    entorno_atencion   VARCHAR(50) NOT NULL,     -- 'Urgencias','Hospitalización','Consulta'
    via_ingreso        VARCHAR(50),              -- 'Referencia','Contrarreferencia','Espontáneo'
    causa_atencion     TEXT,
    fecha_triage       TIMESTAMP,
    clasificacion_triage VARCHAR(10),            -- '1'..'5'
    CONSTRAINT fk_atencion_paciente FOREIGN KEY (documento_id) REFERENCES usuario(documento_id),
    CONSTRAINT chk_atencion_modalidad CHECK (modalidad_entrega IN ('Presencial','Telemedicina','Domiciliaria')),
    CONSTRAINT chk_atencion_entorno CHECK (entorno_atencion IN ('Urgencias','Hospitalización','Consulta','UCI','Procedimiento','Domiciliaria')),
    CONSTRAINT chk_atencion_triage CHECK (clasificacion_triage IS NULL OR clasificacion_triage IN ('1','2','3','4','5')),
    CONSTRAINT chk_atencion_fechas CHECK (fecha_triage IS NULL OR fecha_triage >= fecha_ingreso)
);
CREATE INDEX idx_atencion_doc ON atencion (documento_id);
CREATE INDEX idx_atencion_fecha ON atencion (fecha_ingreso);

-- 2.3 TECNOLOGÍA EN SALUD (MedicationAdministration / Procedure)
DROP TABLE IF EXISTS tecnologia_salud CASCADE;
CREATE TABLE tecnologia_salud (
    tecnologia_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    atencion_id           INT NOT NULL,
    descripcion_medicamento VARCHAR(255) NOT NULL,  -- Ideal: normalizar a catálogo de medicamentos (CUM)
    dosis                 VARCHAR(50),
    via_administracion    VARCHAR(50),         -- SNOMED route (concept_id)
    frecuencia            VARCHAR(50),
    dias_tratamiento      INT,
    unidades_aplicadas    INT DEFAULT 0,
    id_personal_salud     UUID,
    finalidad_tecnologia  VARCHAR(255),
    CONSTRAINT fk_tec_atencion FOREIGN KEY (atencion_id) REFERENCES atencion(atencion_id),
    CONSTRAINT fk_tec_route_snomed FOREIGN KEY (via_administracion) REFERENCES catalogo_snomed(concept_id),
    CONSTRAINT fk_tec_profesional FOREIGN KEY (id_personal_salud) REFERENCES profesional_salud(id_personal_salud),
    CONSTRAINT chk_tec_unidades CHECK (unidades_aplicadas >= 0),
    CONSTRAINT chk_tec_dias_trat CHECK (dias_tratamiento IS NULL OR (dias_tratamiento BETWEEN 0 AND 365))
);

-- 2.4 DIAGNÓSTICO (Condition)
DROP TABLE IF EXISTS diagnostico CASCADE;
CREATE TABLE diagnostico (
    diagnostico_id        SERIAL PRIMARY KEY,
    atencion_id           INT NOT NULL,
    tipo_diagnostico_ingreso VARCHAR(50),   -- 'Presuntivo','Confirmado'
    diagnostico_ingreso   VARCHAR(255) NOT NULL,   -- CIE-10
    tipo_diagnostico_egreso  VARCHAR(50),
    diagnostico_egreso    VARCHAR(255),
    diagnostico_rel1      VARCHAR(255),
    diagnostico_rel2      VARCHAR(255),
    diagnostico_rel3      VARCHAR(255),
    CONSTRAINT fk_dx_atencion FOREIGN KEY (atencion_id) REFERENCES atencion(atencion_id),
    CONSTRAINT fk_dx_ingreso_cie FOREIGN KEY (diagnostico_ingreso) REFERENCES catalogo_cie10(codigo),
    CONSTRAINT fk_dx_egreso_cie FOREIGN KEY (diagnostico_egreso) REFERENCES catalogo_cie10(codigo),
    CONSTRAINT fk_dx_rel1_cie FOREIGN KEY (diagnostico_rel1) REFERENCES catalogo_cie10(codigo),
    CONSTRAINT fk_dx_rel2_cie FOREIGN KEY (diagnostico_rel2) REFERENCES catalogo_cie10(codigo),
    CONSTRAINT fk_dx_rel3_cie FOREIGN KEY (diagnostico_rel3) REFERENCES catalogo_cie10(codigo),
    CONSTRAINT chk_dx_tipo_ingreso CHECK (tipo_diagnostico_ingreso IS NULL OR tipo_diagnostico_ingreso IN ('Presuntivo','Confirmado')),
    CONSTRAINT chk_dx_tipo_egreso CHECK (tipo_diagnostico_egreso IS NULL OR tipo_diagnostico_egreso IN ('Presuntivo','Confirmado','Definitivo'))
);
CREATE INDEX idx_dx_atencion ON diagnostico (atencion_id);

-- 2.5 EGRESO (Encounter discharge)
DROP TABLE IF EXISTS egreso CASCADE;
CREATE TABLE egreso (
    egreso_id            SERIAL PRIMARY KEY,
    atencion_id          INT NOT NULL,
    fecha_salida         TIMESTAMP NOT NULL,
    condicion_salida     VARCHAR(100) NOT NULL,    -- 'Vivo','Mejorado','Remitido','Fallecido'
    diagnostico_muerte   VARCHAR(255),
    codigo_prestador     VARCHAR(20),
    tipo_incapacidad     VARCHAR(100),
    dias_incapacidad     INT,
    dias_lic_maternidad  INT,
    alergias             TEXT,
    antecedente_familiar TEXT,
    riesgos_ocupacionales TEXT,
    responsable_egreso   VARCHAR(255),
    CONSTRAINT fk_egreso_atencion FOREIGN KEY (atencion_id) REFERENCES atencion(atencion_id),
    CONSTRAINT fk_egreso_diag_muerte FOREIGN KEY (diagnostico_muerte) REFERENCES catalogo_cie10(codigo),
    CONSTRAINT chk_egreso_condicion CHECK (condicion_salida IN ('Vivo','Mejorado','Remitido','Fallecido')),
    CONSTRAINT chk_egreso_dias_incap CHECK (dias_incapacidad IS NULL OR dias_incapacidad BETWEEN 0 AND 180),
    CONSTRAINT chk_egreso_dias_licmat CHECK (dias_lic_maternidad IS NULL OR dias_lic_maternidad BETWEEN 0 AND 126)
);
CREATE INDEX idx_egreso_atencion ON egreso (atencion_id);

-- 2.6 PROFESIONAL DE SALUD (Practitioner)
DROP TABLE IF EXISTS profesional_salud CASCADE;
CREATE TABLE profesional_salud (
    id_personal_salud UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre            VARCHAR(255) NOT NULL,
    especialidad      VARCHAR(100) NOT NULL
);
CREATE INDEX idx_prof_nombre ON profesional_salud (nombre);

-- =====================================================================
-- [3] DISTRIBUCIÓN EN CITUS (OPCIONAL)
--     Recomendación: replicar tablas pequeñas como 'usuario' y 'profesional_salud'
--     como 'REFERENCE TABLE' y distribuir por claves de negocio las tablas de eventos
--     (atencion, diagnostico, tecnologia_salud, egreso) colocaladas.
-- =====================================================================

-- Descomenta si usas Citus en el contenedor
-- SELECT create_reference_table('usuario');
-- SELECT create_reference_table('profesional_salud');
-- SELECT create_distributed_table('atencion', 'documento_id');
-- SELECT create_distributed_table('diagnostico', 'atencion_id', colocate_with => 'atencion');
-- SELECT create_distributed_table('tecnologia_salud', 'atencion_id', colocate_with => 'atencion');
-- SELECT create_distributed_table('egreso', 'atencion_id', colocate_with => 'atencion');

-- =====================================================================
-- [4] DATOS DE EJEMPLO (para pruebas académicas)
-- =====================================================================

-- Profesionales
INSERT INTO profesional_salud (id_personal_salud, nombre, especialidad) VALUES
(uuid_generate_v4(),'Dra. Andrea Borrero','Medicina Interna'),
(uuid_generate_v4(),'Dr. Luis Pineda','Urgencias'),
(uuid_generate_v4(),'Enf. Camila Hoyos','Enfermería');

-- Usuarios (pacientes)
INSERT INTO usuario (documento_id, pais_nacionalidad, nombre_completo, fecha_nacimiento, sexo, genero,
                     ocupacion, voluntad_anticipada, categoria_discapacidad, pais_residencia,
                     municipio_residencia, etnia, comunidad_etnica, zona_residencia)
VALUES
(1001001001,'CO','Carlos Arias','1990-05-12','M','Masculino','Ingeniero',FALSE,NULL,'CO','Sincelejo',NULL,NULL,'Urbana'),
(1002002002,'CO','María Gómez','1985-08-30','F','Femenino','Docente',TRUE,'Visual','CO','Medellín','Indígena','Zenú','Urbana');

-- Atenciones
INSERT INTO atencion (documento_id, entidad_salud, fecha_ingreso, modalidad_entrega, entorno_atencion,
                      via_ingreso, causa_atencion, fecha_triage, clasificacion_triage)
VALUES
(1001001001,'IPS Centro Salud Sucre','2025-10-01 08:30:00','Presencial','Urgencias','Espontáneo','Dolor torácico desde la madrugada','2025-10-01 08:45:00','2'),
(1002002002,'Clínica UPB','2025-10-02 09:00:00','Telemedicina','Consulta',NULL,'Control de diabetes y ajustes de tratamiento',NULL,NULL);

-- Diagnósticos (CIE-10)
INSERT INTO diagnostico (atencion_id, tipo_diagnostico_ingreso, diagnostico_ingreso, tipo_diagnostico_egreso, diagnostico_egreso)
VALUES
(1,'Presuntivo','I10','Definitivo','I10'),
(2,'Confirmado','E11','Confirmado','E11');

-- Egresos
INSERT INTO egreso (atencion_id, fecha_salida, condicion_salida, diagnostico_muerte, codigo_prestador,
                    tipo_incapacidad, dias_incapacidad, dias_lic_maternidad, alergias, antecedente_familiar,
                    riesgos_ocupacionales, responsable_egreso)
VALUES
(1,'2025-10-01 12:30:00','Mejorado',NULL,'12345','Temporal',5,NULL,'Alergia a penicilina','Historial de HTA','Exposición a ruido','Dr. Luis Pineda'),
(2,'2025-10-02 09:40:00','Vivo',NULL,'98765',NULL,NULL,NULL,NULL,'Madre con DM2',NULL,'Dra. Andrea Borrero');

-- Tecnología en salud (medicación)
-- Obtener un id_personal_salud cualquiera
WITH p AS (
  SELECT id_personal_salud FROM profesional_salud ORDER BY nombre LIMIT 1
)
INSERT INTO tecnologia_salud (atencion_id, descripcion_medicamento, dosis, via_administracion, frecuencia,
                              dias_tratamiento, unidades_aplicadas, id_personal_salud, finalidad_tecnologia)
SELECT 1, 'Lisinopril', '10 mg', '26643006', 'Cada 24 h', 30, 30, p.id_personal_salud, 'Tratamiento HTA' FROM p;

WITH p AS (
  SELECT id_personal_salud FROM profesional_salud ORDER BY nombre DESC LIMIT 1
)
INSERT INTO tecnologia_salud (atencion_id, descripcion_medicamento, dosis, via_administracion, frecuencia,
                              dias_tratamiento, unidades_aplicadas, id_personal_salud, finalidad_tecnologia)
SELECT 2, 'Metformina', '850 mg', '26643006', 'Cada 12 h', 60, 120, p.id_personal_salud, 'Tratamiento DM2' FROM p;

-- =====================================================================
-- FIN DEL init.sql
-- =====================================================================
