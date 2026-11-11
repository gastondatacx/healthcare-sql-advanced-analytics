-- ============================================================================
-- ESQUEMA RELACIONAL: OPERACIONES, AUDITORÍA Y CX EN SALUD (OBRAS SOCIALES)
-- ============================================================================

DROP TABLE IF EXISTS facturacion_mensual;
DROP TABLE IF EXISTS llamadas_cx;
DROP TABLE IF EXISTS ordenes_medicas;
DROP TABLE IF EXISTS afiliados;

-- 1. Tabla Maestra de Padrón de Afiliados
CREATE TABLE afiliados (
    afiliado_id VARCHAR(15) PRIMARY KEY,
    fecha_alta DATE NOT NULL,
    fecha_baja DATE NULL,
    estado_actual VARCHAR(15) NOT NULL, -- 'Activo' o 'Baja'
    plan_salud VARCHAR(35) NOT NULL,
    tipo_contratacion VARCHAR(35) NOT NULL,
    region VARCHAR(30) NOT NULL,
    edad_anos INTEGER NOT NULL,
    cuota_mensual_ars DECIMAL(12, 2) NOT NULL
);

-- 2. Tabla Transaccional de Auditoría Médica y Prestaciones
CREATE TABLE ordenes_medicas (
    orden_id INTEGER PRIMARY KEY,
    afiliado_id VARCHAR(15) NOT NULL,
    fecha_solicitud TIMESTAMP NOT NULL,
    fecha_resolucion TIMESTAMP NOT NULL,
    especialidad VARCHAR(40) NOT NULL,
    tipo_practica VARCHAR(45) NOT NULL,
    estado_auditoria VARCHAR(25) NOT NULL, -- 'Aprobada', 'Observada', 'Rechazada'
    costo_prestacion_ars DECIMAL(12, 2) NOT NULL,
    copago_afiliado_ars DECIMAL(12, 2) NOT NULL,
    FOREIGN KEY (afiliado_id) REFERENCES afiliados(afiliado_id)
);

-- 3. Tabla Transaccional de Interacciones en Contact Center (CX)
CREATE TABLE llamadas_cx (
    llamada_id INTEGER PRIMARY KEY,
    afiliado_id VARCHAR(15) NOT NULL,
    agente_id VARCHAR(15) NOT NULL,
    equipo_supervisor VARCHAR(25) NOT NULL,
    fecha_hora_llamada TIMESTAMP NOT NULL,
    motivo_contacto VARCHAR(45) NOT NULL,
    duracion_minutos DECIMAL(6, 2) NOT NULL,
    espera_segundos INTEGER NOT NULL,
    resuelto_en_sistema INTEGER NOT NULL, -- 1 = Sí, 0 = No
    csat_encuesta_1a5 INTEGER NULL,
    FOREIGN KEY (afiliado_id) REFERENCES afiliados(afiliado_id)
);

-- 4. Tabla de Facturación y Aportes Mensuales
CREATE TABLE facturacion_mensual (
    factura_id INTEGER PRIMARY KEY,
    afiliado_id VARCHAR(15) NOT NULL,
    periodo_mes VARCHAR(7) NOT NULL, -- Formato 'YYYY-MM'
    monto_facturado_ars DECIMAL(12, 2) NOT NULL,
    gasto_medico_mes_ars DECIMAL(12, 2) NOT NULL,
    estado_pago VARCHAR(20) NOT NULL, -- 'Pagado', 'Mora'
    FOREIGN KEY (afiliado_id) REFERENCES afiliados(afiliado_id)
);

-- Índices para optimizar Window Functions y Joins masivos
CREATE INDEX idx_llamadas_afiliado_fecha ON llamadas_cx(afiliado_id, fecha_hora_llamada);
CREATE INDEX idx_ordenes_especialidad ON ordenes_medicas(especialidad, estado_auditoria);
CREATE INDEX idx_afiliados_alta ON afiliados(fecha_alta, plan_salud);
CREATE INDEX idx_facturacion_periodo ON facturacion_mensual(periodo_mes, afiliado_id);