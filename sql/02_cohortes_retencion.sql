-- ============================================================================
-- CONSULTA 02: ANÁLISIS DE COHORTES DE RETENCIÓN Y PÉRDIDA DE INGRESOS ($ ARS)
-- Objetivo: Evaluar la supervivencia de los afiliados según su trimestre de
--           ingreso y cuantificar el dinero mensual retenido vs perdido.
-- ============================================================================

WITH base_cohortes AS (
    SELECT
        afiliado_id,
        plan_salud,
        cuota_mensual_ars,
        estado_actual,
        STRFTIME('%Y-Q', fecha_alta) || 
        CASE 
            WHEN CAST(STRFTIME('%m', fecha_alta) AS INTEGER) BETWEEN 1 AND 3 THEN '1'
            WHEN CAST(STRFTIME('%m', fecha_alta) AS INTEGER) BETWEEN 4 AND 6 THEN '2'
            WHEN CAST(STRFTIME('%m', fecha_alta) AS INTEGER) BETWEEN 7 AND 9 THEN '3'
            ELSE '4'
        END AS cohorte_ingreso,
        ROUND(
            (JULIANDAY(COALESCE(fecha_baja, '2026-10-31')) - JULIANDAY(fecha_alta)) / 30.44,
            1
        ) AS meses_permanencia
    FROM afiliados
),
metricas_por_cohorte AS (
    SELECT
        cohorte_ingreso,
        COUNT(afiliado_id) AS altas_iniciales,
        SUM(CASE WHEN meses_permanencia >= 3.0 THEN 1 ELSE 0 END) AS vivos_mes_3,
        SUM(CASE WHEN meses_permanencia >= 6.0 THEN 1 ELSE 0 END) AS vivos_mes_6,
        SUM(CASE WHEN estado_actual = 'Activo' THEN 1 ELSE 0 END) AS activos_actuales,
        SUM(CASE WHEN estado_actual = 'Activo' THEN cuota_mensual_ars ELSE 0 END) AS facturacion_retenida_ars,
        SUM(CASE WHEN estado_actual = 'Baja' THEN cuota_mensual_ars ELSE 0 END) AS facturacion_perdida_ars
    FROM base_cohortes
    GROUP BY cohorte_ingreso
)
SELECT
    cohorte_ingreso AS "Cohorte de Ingreso",
    altas_iniciales AS "Afiliados Iniciales (Cant)",
    ROUND((vivos_mes_3 * 100.0) / altas_iniciales, 1) || '%' AS "Retención al Mes 3 (%)",
    ROUND((vivos_mes_6 * 100.0) / altas_iniciales, 1) || '%' AS "Retención al Mes 6 (%)",
    ROUND((activos_actuales * 100.0) / altas_iniciales, 1) || '%' AS "Retención Actual (%)",
    '$ ' || PRINTF('%,.0f', facturacion_retenida_ars) || ' ARS' AS "Ingresos Mensuales Activos ($ ARS)",
    '$ ' || PRINTF('%,.0f', facturacion_perdida_ars) || ' ARS' AS "Ingresos Mensuales Perdidos ($ ARS)"
FROM metricas_por_cohorte
ORDER BY cohorte_ingreso ASC;