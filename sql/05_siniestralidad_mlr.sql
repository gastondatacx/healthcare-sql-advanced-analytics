-- ============================================================================
-- CONSULTA 05: SINIESTRALIDAD MÉDICA (MLR), COSTO CX Y MARGEN NETO POR PLAN
-- Objetivo: Cruzar Facturación, Prestaciones Médicas y Costo de Llamadas para
--           conocer la rentabilidad real en Pesos ($ ARS) por Plan de Salud.
-- ============================================================================

WITH facturacion_por_afiliado AS (
    SELECT
        afiliado_id,
        SUM(monto_facturado_ars) AS ingresos_totales_ars,
        SUM(gasto_medico_mes_ars) AS costo_prestaciones_ars,
        SUM(CASE WHEN estado_pago = 'Mora' THEN 1 ELSE 0 END) AS meses_en_mora
    FROM facturacion_mensual
    GROUP BY afiliado_id
),
costo_cx_por_afiliado AS (
    SELECT
        afiliado_id,
        COUNT(llamada_id) AS total_llamadas,
        -- Cada llamada atendida tiene un costo operativo estimado de $ 4.200 ARS
        COUNT(llamada_id) * 4200.0 AS costo_atencion_cx_ars
    FROM llamadas_cx
    GROUP BY afiliado_id
),
consolidado_financiero AS (
    SELECT
        a.plan_salud,
        a.afiliado_id,
        COALESCE(f.ingresos_totales_ars, 0) AS ingresos_ars,
        COALESCE(f.costo_prestaciones_ars, 0) AS gasto_medico_ars,
        COALESCE(c.costo_atencion_cx_ars, 0) AS gasto_cx_ars,
        (COALESCE(f.ingresos_totales_ars, 0) - COALESCE(f.costo_prestaciones_ars, 0) - COALESCE(c.costo_atencion_cx_ars, 0)) AS margen_neto_ars
    FROM afiliados a
    LEFT JOIN facturacion_por_afiliado f ON a.afiliado_id = f.afiliado_id
    LEFT JOIN costo_cx_por_afiliado c ON a.afiliado_id = c.afiliado_id
)
SELECT
    plan_salud AS "Plan de Salud",
    COUNT(afiliado_id) AS "Afiliados (Cant)",
    '$ ' || PRINTF('%,.1f', SUM(ingresos_ars) / 1000000.0) || ' M' AS "Facturación Total ($ Millones ARS)",
    '$ ' || PRINTF('%,.1f', SUM(gasto_medico_ars) / 1000000.0) || ' M' AS "Gasto Médico ($ Millones ARS)",
    ROUND((SUM(gasto_medico_ars) * 100.0) / SUM(ingresos_ars), 1) || '%' AS "Siniestralidad Médica - MLR (%)",
    '$ ' || PRINTF('%,.1f', SUM(gasto_cx_ars) / 1000000.0) || ' M' AS "Costo Operativo CX ($ Millones ARS)",
    '$ ' || PRINTF('%,.1f', SUM(margen_neto_ars) / 1000000.0) || ' M' AS "Margen Neto ($ Millones ARS)",
    ROUND((SUM(margen_neto_ars) * 100.0) / SUM(ingresos_ars), 1) || '%' AS "Rentabilidad Neta (%)"
FROM consolidado_financiero
GROUP BY plan_salud
ORDER BY (SUM(margen_neto_ars) / SUM(ingresos_ars)) DESC;