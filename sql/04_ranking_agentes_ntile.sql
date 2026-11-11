-- ============================================================================
-- CONSULTA 04: BENCHMARKING DE AGENTES CON NTILE(4) Y COMPARACIÓN INTRA-EQUIPO
-- Objetivo: Clasificar a los operadores en cuartiles de rendimiento combinando
--           resolución real (FCR), velocidad (AHT) y satisfacción (CSAT) frente
--           al promedio de su propio supervisor.
-- ============================================================================

WITH metricas_agente AS (
    SELECT
        agente_id,
        equipo_supervisor,
        COUNT(llamada_id) AS llamadas_atendidas,
        AVG(duracion_minutos) AS aht_agente_min,
        AVG(resuelto_en_sistema) * 100.0 AS tasa_resolucion_pct,
        AVG(csat_encuesta_1a5) AS csat_agente
    FROM llamadas_cx
    GROUP BY agente_id, equipo_supervisor
),
comparativa_equipo AS (
    SELECT
        *,
        AVG(csat_agente) OVER (PARTITION BY equipo_supervisor) AS csat_promedio_equipo,
        AVG(aht_agente_min) OVER (PARTITION BY equipo_supervisor) AS aht_promedio_equipo,
        -- Puntaje integral ponderado (escala de 0 a 100 puntos)
        ROUND((tasa_resolucion_pct * 0.50) + ((csat_agente / 5.0) * 100.0 * 0.50), 1) AS score_calidad_0a100
    FROM metricas_agente
),
cuartiles_performance AS (
    SELECT
        *,
        DENSE_RANK() OVER (ORDER BY score_calidad_0a100 DESC) AS posicion_general,
        NTILE(4) OVER (ORDER BY score_calidad_0a100 DESC) AS cuartil_rendimiento
    FROM comparativa_equipo
)
SELECT
    posicion_general AS "Posición",
    agente_id AS "ID Agente",
    equipo_supervisor AS "Célula / Supervisor",
    llamadas_atendidas AS "Llamadas (Cant)",
    ROUND(aht_agente_min, 1) || ' min' AS "AHT Agente",
    ROUND(tasa_resolucion_pct, 1) || '%' AS "Resolución (%)",
    ROUND(csat_agente, 2) || ' pts' AS "CSAT Agente (1-5)",
    CASE 
        WHEN (csat_agente - csat_promedio_equipo) >= 0 
        THEN '+' || ROUND(csat_agente - csat_promedio_equipo, 2)
        ELSE CAST(ROUND(csat_agente - csat_promedio_equipo, 2) AS TEXT)
    END AS "Desvío CSAT vs Equipo",
    score_calidad_0a100 || ' pts' AS "Score QA (0-100)",
    CASE cuartil_rendimiento
        WHEN 1 THEN 'Q1 - Top Performer (Bono)'
        WHEN 2 THEN 'Q2 - Estándar Alto'
        WHEN 3 THEN 'Q3 - En Desarrollo'
        WHEN 4 THEN 'Q4 - Plan de Coaching Crítico'
    END AS "Segmento Cuartil (NTILE)"
FROM cuartiles_performance
ORDER BY score_calidad_0a100 DESC
LIMIT 15;