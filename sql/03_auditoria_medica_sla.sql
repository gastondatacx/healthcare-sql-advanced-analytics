-- ============================================================================
-- CONSULTA 03: CUELLOS DE BOTELLA EN AUDITORÍA MÉDICA, SLA Y COSTOS ($ ARS)
-- Objetivo: Identificar qué especialidades médicas concentran las mayores
--           demoras de autorización (> 48 hs), rechazos y peso presupuestario.
-- ============================================================================

WITH tiempos_auditoria AS (
    SELECT
        orden_id,
        especialidad,
        tipo_practica,
        estado_auditoria,
        costo_prestacion_ars,
        copago_afiliado_ars,
        ROUND((JULIANDAY(fecha_resolucion) - JULIANDAY(fecha_solicitud)) * 24.0, 1) AS horas_resolucion
    FROM ordenes_medicas
),
resumen_especialidad AS (
    SELECT
        especialidad,
        COUNT(orden_id) AS total_ordenes,
        AVG(horas_resolucion) AS demora_media_hs,
        SUM(CASE WHEN horas_resolucion > 48.0 THEN 1 ELSE 0 END) AS ordenes_fuera_sla,
        SUM(CASE WHEN estado_auditoria = 'Rechazada' THEN 1 ELSE 0 END) AS ordenes_rechazadas,
        SUM(costo_prestacion_ars) AS costo_total_especialidad_ars
    FROM tiempos_auditoria
    GROUP BY especialidad
)
SELECT
    RANK() OVER (ORDER BY (ordenes_fuera_sla * 1.0 / total_ordenes) DESC) AS "Ranking Crítico",
    especialidad AS "Especialidad Médica",
    total_ordenes AS "Órdenes Auditadas (Cant)",
    ROUND(demora_media_hs, 1) || ' hs' AS "Tiempo Medio Resolución",
    ROUND((ordenes_fuera_sla * 100.0) / total_ordenes, 1) || '%' AS "Incumplimiento SLA >48hs (%)",
    ROUND((ordenes_rechazadas * 100.0) / total_ordenes, 1) || '%' AS "Tasa de Rechazo (%)",
    '$ ' || PRINTF('%,.0f', costo_total_especialidad_ars) || ' ARS' AS "Costo Prestacional ($ ARS)",
    ROUND(
        (costo_total_especialidad_ars * 100.0) / SUM(costo_total_especialidad_ars) OVER (),
        1
    ) || '%' AS "Peso sobre Presupuesto (%)"
FROM resumen_especialidad
ORDER BY "Ranking Crítico" ASC;