import os
import sqlite3
import random
from datetime import datetime, timedelta
import numpy as np
import pandas as pd

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, "database", "healthcare_ops.db")
SQL_DIR = os.path.join(BASE_DIR, "sql")
OUT_DIR = os.path.join(BASE_DIR, "reports", "sql_outputs")

os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
os.makedirs(OUT_DIR, exist_ok=True)


def poblar_base_datos(conn):
    random.seed(42)
    np.random.seed(42)

    print("[1/3] Ejecutando DDL (00_schema_ddl.sql) y creando esquema relacional...")
    with open(os.path.join(SQL_DIR, "00_schema_ddl.sql"), "r", encoding="utf-8") as f:
        conn.executescript(f.read())

    print("[2/3] Poblando tablas con datos transaccionales en Pesos Argentinos ($ ARS)...")
    planes = [
        ("Plan 100 - Básico", 92_000, 0.78),
        ("Plan 200 - Integral", 148_000, 0.72),
        ("Plan 300 - Superior", 225_000, 0.66),
        ("Plan 400 - Exclusivo", 340_000, 0.61)
    ]
    contrataciones = ["Relación de Dependencia", "Voluntario Particular", "Monotributo", "Corporativo"]
    regiones = ["Córdoba Capital", "Gran Córdoba", "Interior Sur", "CABA / GBA"]

    afiliados_rows = []
    facturacion_rows = []
    ordenes_rows = []
    llamadas_rows = []

    factura_id = 1
    orden_id = 10001
    llamada_id = 50001

    inicio_base = datetime(2025, 7, 1)
    fin_base = datetime(2026, 10, 31)

    agentes = [(f"AG_{i:02d}", f"Célula {(i % 4) + 1}") for i in range(1, 21)]
    especialidades = [
        ("Diagnóstico por Imágenes", "Resonancia / Tomografía", 145_000, 38, 0.14),
        ("Cirugía General e Internación", "Intervención Quirúrgica", 680_000, 56, 0.22),
        ("Odontología y Ortodoncia", "Prótesis / Endodoncia", 95_000, 28, 0.18),
        ("Kinesiología y Rehabilitación", "Sesiones Fisioterapia", 48_000, 19, 0.08),
        ("Laboratorio Bioquímico", "Alta Complejidad", 62_000, 14, 0.06),
        ("Salud Mental y Psicología", "Psicoterapia Mensual", 54_000, 22, 0.09)
    ]
    motivos_cx = [
        ("Reclamo por Demora de Autorización", 7.8, 0.74, 0.34),
        ("Consulta de Reintegros y Facturación", 6.2, 0.81, 0.22),
        ("Cobertura de Medicamentos y Farmacia", 5.4, 0.85, 0.16),
        ("Turnos y Cartilla de Prestadores", 4.5, 0.91, 0.09),
        ("Problemas con Credencial Digital / App", 3.8, 0.94, 0.06)
    ]

    for i in range(1, 1501):
        af_id = f"AF_{i:05d}"
        plan_nombre, cuota_base, mlr_objetivo = random.choices(planes, weights=[0.32, 0.38, 0.20, 0.10])[0]
        edad = int(np.clip(np.random.normal(42, 14), 19, 78))
        cuota_ars = round(cuota_base * (1 + (edad - 30) * 0.008), -2)

        dias_offset_alta = random.randint(0, 360)
        fecha_alta_dt = inicio_base + timedelta(days=dias_offset_alta)

        # Determinar si sigue activo o se dio de baja
        es_baja = random.random() < 0.19
        if es_baja:
            dias_vida = random.randint(45, max(60, (fin_base - fecha_alta_dt).days))
            fecha_baja_dt = min(fin_base, fecha_alta_dt + timedelta(days=dias_vida))
            estado = "Baja"
            fecha_baja_str = fecha_baja_dt.strftime("%Y-%m-%d")
        else:
            fecha_baja_dt = fin_base
            estado = "Activo"
            fecha_baja_str = None

        afiliados_rows.append((
            af_id, fecha_alta_dt.strftime("%Y-%m-%d"), fecha_baja_str, estado,
            plan_nombre, random.choice(contrataciones), random.choice(regiones), edad, cuota_ars
        ))

        # Generar últimos 3 meses de facturación para el afiliado
        for mes_num in [8, 9, 10]:
            periodo = f"2026-{mes_num:02d}"
            gasto_medico = round(float(np.random.gamma(shape=2.0, scale=(cuota_ars * mlr_objetivo) / 2.0)), -2)
            estado_pago = "Mora" if random.random() < 0.09 else "Pagado"
            facturacion_rows.append((factura_id, af_id, periodo, cuota_ars, gasto_medico, estado_pago))
            factura_id += 1

        # Generar órdenes médicas
        cant_ordenes = np.random.poisson(lam=2.4)
        for _ in range(cant_ordenes):
            esp, prac, costo_base, demora_base_hs, prob_rechazo = random.choice(especialidades)
            f_sol = datetime(2026, random.randint(8, 10), random.randint(1, 27), random.randint(8, 18), 0)
            horas_demora = max(2.0, float(np.random.normal(demora_base_hs, 16)))
            f_res = f_sol + timedelta(hours=horas_demora)

            r_val = random.random()
            if r_val < prob_rechazo:
                est_aud = "Rechazada"
            elif r_val < prob_rechazo + 0.12:
                est_aud = "Observada"
            else:
                est_aud = "Aprobada"

            costo_final = round(costo_base * np.random.uniform(0.85, 1.25), -2)
            copago = round(costo_final * 0.10, -2) if "Básico" in plan_nombre else 0.0

            ordenes_rows.append((
                orden_id, af_id,
                f_sol.strftime("%Y-%m-%d %H:%M:%S"),
                f_res.strftime("%Y-%m-%d %H:%M:%S"),
                esp, prac, est_aud, costo_final, copago
            ))
            orden_id += 1

        # Generar llamadas al Contact Center (con reincidencias reales en < 48 hs)
        cant_llamadas_base = np.random.poisson(lam=1.8)
        for _ in range(cant_llamadas_base):
            motivo, aht_base, prob_resuelto_crm, prob_reincidir = random.choice(motivos_cx)
            ag_id, equipo = random.choice(agentes)
            f_call = datetime(2026, random.randint(8, 10), random.randint(1, 26), random.randint(9, 19), random.randint(0, 59))

            # Diferencia de rendimiento entre agentes
            ag_num = int(ag_id.split("_")[1])
            bonus_calidad = 0.08 if ag_num <= 6 else (-0.10 if ag_num >= 16 else 0.0)

            dur_min = round(max(1.5, np.random.normal(aht_base - bonus_calidad * 5, 1.4)), 2)
            espera_seg = int(max(10, np.random.exponential(45)))
            resuelto_crm = 1 if random.random() < min(0.98, prob_resuelto_crm + bonus_calidad) else 0
            csat = int(np.clip(round(np.random.normal(3.8 + bonus_calidad * 6, 0.8)), 1, 5))

            llamadas_rows.append((
                llamada_id, af_id, ag_id, equipo,
                f_call.strftime("%Y-%m-%d %H:%M:%S"),
                motivo, dur_min, espera_seg, resuelto_crm, csat
            ))
            llamada_id += 1

            # Simular reincidencia en menos de 48 horas por el mismo motivo (Falso FCR)
            if random.random() < prob_reincidir:
                f_reincidencia = f_call + timedelta(hours=random.uniform(4.0, 42.0))
                ag_id2, equipo2 = random.choice(agentes)
                llamadas_rows.append((
                    llamada_id, af_id, ag_id2, equipo2,
                    f_reincidencia.strftime("%Y-%m-%d %H:%M:%S"),
                    motivo, round(dur_min * 1.15, 2), espera_seg + 25, 1, max(1, csat - 1)
                ))
                llamada_id += 1

    conn.executemany("INSERT INTO afiliados VALUES (?,?,?,?,?,?,?,?,?)", afiliados_rows)
    conn.executemany("INSERT INTO facturacion_mensual VALUES (?,?,?,?,?,?)", facturacion_rows)
    conn.executemany("INSERT INTO ordenes_medicas VALUES (?,?,?,?,?,?,?,?,?)", ordenes_rows)
    conn.executemany("INSERT INTO llamadas_cx VALUES (?,?,?,?,?,?,?,?,?,?)", llamadas_rows)
    conn.commit()
    print(f" -> Base poblada: {len(afiliados_rows):,} afiliados | {len(ordenes_rows):,} órdenes médicas | {len(llamadas_rows):,} llamadas CX.\n")


def ejecutar_consultas_sql(conn):
    print("[3/3] Ejecutando Suite de Consultas de SQL Avanzado...\n")
    archivos_sql = sorted([f for f in os.listdir(SQL_DIR) if f.endswith(".sql") and not f.startswith("00_")])

    for archivo in archivos_sql:
        ruta_sql = os.path.join(SQL_DIR, archivo)
        with open(ruta_sql, "r", encoding="utf-8") as f:
            query = f.read()

        df_res = pd.read_sql_query(query, conn)
        nombre_csv = archivo.replace(".sql", ".csv")
        df_res.to_csv(os.path.join(OUT_DIR, nombre_csv), index=False)

        print("=" * 105)
        print(f" EJECUTANDO: {archivo}")
        print("=" * 105)
        print(df_res.to_string(index=False))
        print("\n")


if __name__ == "__main__":
    with sqlite3.connect(DB_PATH) as conexion:
        poblar_base_datos(conexion)
        ejecutar_consultas_sql(conexion)
    print(f"Todos los reportes SQL fueron exportados exitosamente a: {OUT_DIR}")