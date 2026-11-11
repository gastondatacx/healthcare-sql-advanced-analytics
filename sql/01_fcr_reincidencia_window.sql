-- ============================================================================
-- CONSULTA 01: TRAZABILIDAD DE REINCIDENCIA (< 48 HS) Y FCR REAL CON LEAD()
-- Objetivo: Auditar cuántas llamadas marcadas como "Resueltas" por el operador
--           fueron falsos cierres porque el afiliado volvió a llamar en < 48 hs
--           por el mismo motivo médico o administrativo.
-- ============================================================================

WITH llamadas_con_proximo_contacto AS (
    SELECT
        llamada_id,
        afiliado_id,
        agente_id,
        motivo_contacto,
        fecha_hora_llamada,
        duracion_minutos,
        resuelto_en_sistema,
        csat_encuesta_1a5,
        -- Buscamos la fecha de la SIGUIENTE llamada del mismo afiliado por el mismo motivo
        LEAD(fecha_hora_llamada) OVER (
            PARTITION BY afiliado_id, motivo_contacto
            ORDER BY fecha_hora_llamada ASC
        ) AS proxima_llamada_mismo_motivo
    FROM llamadas_cx
),
clasificacion_fcr AS (
    SELECT
        *,
        ROUND(
            (JULIANDAY(proxima_llamada_mismo_motivo) - JULIANDAY(fecha_hora_llamada)) * 24.0,
            1
        ) AS horas_hasta_reincidencia,
        CASE
            WHEN proxima_llamada_mismo_motivo IS NOT NULL
             AND ((JULIANDAY(proxima_llamada_mismo_motivo) - JULIANDAY(fecha_hora_llamada)) * 24.0) <= 48.0
            THEN 1 ELSE 0
        END AS flag_reincidencia_48hs,
        CASE
            WHEN resuelto_en_sistema = 1
             AND (
                 proxima_llamada_mismo_motivo IS NULL
                 OR ((JULIANDAY(proxima_llamada_mismo_motivo) - JULIANDAY(fecha_hora_llamada)) * 24.0) > 48.0
             )
            THEN 1 ELSE 0
        END AS flag_fcr_real
    FROM llamadas_con_proximo_contacto
)
SELECT
    motivo_contacto AS "Motivo de Contacto",
    COUNT(llamada_id) AS "Volumen Llamadas (Cant)",
    ROUND(AVG(duracion_minutos), 1) || ' min' AS "Duración Media (AHT)",
    ROUND(AVG(resuelto_en_sistema) * 100.0, 1) || '%' AS "FCR Declarado CRM (%)",
    ROUND(AVG(flag_fcr_real) * 100.0, 1) || '%' AS "FCR Real Auditado (%)",
    ROUND((AVG(resuelto_en_sistema) - AVG(flag_fcr_real)) * 100.0, 1) || '%' AS "Brecha Falso Cierre (%)",
    ROUND(AVG(flag_reincidencia_48hs) * 100.0, 1) || '%' AS "Tasa Reincidencia <48hs (%)",
    ROUND(AVG(csat_encuesta_1a5), 2) || ' / 5.0' AS "Satisfacción CSAT"
FROM clasificacion_fcr
GROUP BY motivo_contacto
ORDER BY (AVG(resuelto_en_sistema) - AVG(flag_fcr_real)) DESC;