
# 🗄️ Healthcare SQL Advanced Analytics: CX, Auditoría Médica & Siniestralidad

[![SQL](<https://img.shields.io/badge/SQL-Advanced%20Analytics-4479A1?logo=postgresql&logoColor=white>)](#)
[![SQLite](<https://img.shields.io/badge/Engine-SQLite3%20%2F%20ANSI%20SQL-003B57?logo=sqlite&logoColor=white>)](#)
[![Python 3.10+](<https://img.shields.io/badge/Orchestrator-Python%203.10%2B-3776AB?logo=python&logoColor=white>)](#)
[![Currency: ARS](<https://img.shields.io/badge/Moneda-Pesos%20Argentinos%20(%24%20ARS)-2ea44f>)](#)

Repositorio especializado en **SQL Avanzado aplicado a Operaciones de Salud, Obras Sociales y Experiencia del Afiliado (CX)**. El proyecto resuelve casos reales de negocio utilizando **Window Functions (`LEAD`, `LAG`, `NTILE`, `DENSE_RANK`, `SUM OVER`), Common Table Expressions (`CTEs`) encadenadas, análisis de cohortes de retención y cálculo de Siniestralidad Médica (`MLR`) en Pesos Argentinos (`$ ARS`)**.

---

## 🎯 1. Habilidades Técnicas de SQL Demostradas

| Técnica SQL Avanzada                           | Script donde se aplica             | Problema de Negocio Resuelto                                                                                                                                                 |
| :---------------------------------------------- | :--------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`LEAD() OVER (PARTITION BY ...)`**    | `01_fcr_reincidencia_window.sql` | Detección longitudinal de re-llamados en menos de 48 horas por el mismo motivo para auditar la brecha entre el *FCR Declarado* en el CRM y el *FCR Real*.               |
| **Cohortes & Agregación Condicional**    | `02_cohortes_retencion.sql`      | Seguimiento de supervivencia de afiliados al Mes 3 y Mes 6 según su trimestre de alta y cálculo del ingreso mensual recurrente retenido vs. perdido (`$ ARS`).           |
| **`RANK() OVER` & `SUM() OVER ()`**   | `03_auditoria_medica_sla.sql`    | Ranking de cuellos de botella en autorizaciones médicas (> 48 hs de demora) y cálculo del peso porcentual de cada especialidad sobre el presupuesto total.                 |
| **`NTILE(4)` & Particiones de Equipo**  | `04_ranking_agentes_ntile.sql`   | Segmentación estadística de operadores en cuartiles de desempeño (`Q1` a `Q4`) y cálculo del desvío individual de `CSAT` frente al promedio de su propia célula. |
| **Multi-Table CTEs & Ratios Financieros** | `05_siniestralidad_mlr.sql`      | Cruce de 4 tablas transaccionales para calcular el *Medical Loss Ratio (MLR)*, el costo operativo de atención telefónica y el margen neto en `$ Millones ARS`.         |

---

## 🏗️ 2. Modelo Entidad-Relación (Esquema de Base de Datos)

El archivo `sql/00_schema_ddl.sql` construye un esquema relacional normalizado e indexado compuesto por **4 tablas**:

```text
+---------------------------+       +-------------------------------+
|         afiliados         |       |        ordenes_medicas        |
+---------------------------+       +-------------------------------+
| PK afiliado_id            |1     N| PK orden_id                   |
|    fecha_alta             |------>| FK afiliado_id                |
|    fecha_baja             |       |    fecha_solicitud            |
|    estado_actual          |       |    fecha_resolucion           |
|    plan_salud             |       |    especialidad               |
|    tipo_contratacion      |       |    estado_auditoria           |
|    region                 |       |    costo_prestacion_ars ($ARS)|
|    cuota_mensual_ars($ARS)|       +-------------------------------+
+---------------------------+
       | 1                 | 1
       |                   +------------------------+
       | N                                          | N
       v                                            v
+-------------------------------+       +-------------------------------+
|          llamadas_cx          |       |      facturacion_mensual      |
+-------------------------------+       +-------------------------------+
| PK llamada_id                 |       | PK factura_id                 |
| FK afiliado_id                |       | FK afiliado_id                |
|    agente_id                  |       |    periodo_mes (YYYY-MM)      |
|    equipo_supervisor          |       |    monto_facturado_ars ($ARS) |
|    fecha_hora_llamada         |       |    gasto_medico_mes_ars ($ARS)|
|    motivo_contacto            |       |    estado_pago (Pagado/Mora)  |
|    duracion_minutos (AHT)     |       +-------------------------------+
|    resuelto_en_sistema (0/1)  |
|    csat_encuesta_1a5 (1 a 5)  |
+-------------------------------+
```
