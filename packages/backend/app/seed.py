import json
from datetime import datetime, timezone

from passlib.context import CryptContext
from sqlalchemy import select

from app.core.database import async_session
from app.models.usuario import Usuario, UserRole
from app.models.template import Template
from app.models.audit_log import AuditLog

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

SEED_USERS = [
    Usuario(
        id="usr-admin",
        nombre="Administrador",
        cargo="ADMINISTRADOR",
        area="Administracion",
        rol=UserRole.ADMIN,
        pin_hash=pwd_context.hash("1234"),
        pass_hash=pwd_context.hash("admin"),
    ),
    Usuario(
        id="usr-jefe",
        nombre="Dr. Alberto Parra Barrera",
        cargo="JEFE DE LABORATORIO",
        area="Laboratorio Central",
        supervisor="Director General",
        firma="Dr. Alberto Parra Barrera",
        rol=UserRole.JEFE,
        pin_hash=pwd_context.hash("0000"),
        pass_hash=pwd_context.hash("biolab"),
    ),
    Usuario(
        id="usr-t1",
        nombre="Biol. Maria Guadalupe Ramirez Padilla",
        cargo="BIOLOGO",
        area="Cultivo Celular",
        supervisor="Dr. Alberto Parra Barrera",
        firma="Biol. Maria Guadalupe Ramirez Padilla",
        rol=UserRole.LABORATORIO,
        pin_hash=pwd_context.hash("1111"),
        pass_hash=pwd_context.hash("biolab"),
    ),
    Usuario(
        id="usr-auditor",
        nombre="Auditor Externo",
        cargo="QFB",
        area="Calidad",
        supervisor="Director General",
        firma="Auditor Externo",
        rol=UserRole.AUDITOR,
        pin_hash=pwd_context.hash("2222"),
        pass_hash=pwd_context.hash("biolab"),
    ),
    Usuario(
        id="usr-dueno",
        nombre="Director General",
        cargo="DIRECTOR GENERAL",
        area="Direccion General",
        firma="Director General",
        rol=UserRole.DUENO,
        pin_hash=pwd_context.hash("3333"),
        pass_hash=pwd_context.hash("biolab"),
    ),
]

TEMPLATES_SEED = [
    {"id": "tpl-incubadoras", "name": "Bitacora de Incubadoras", "module": "incubadoras", "version": 1, "fields": [
        {"key": "temperatura", "label": "Temperatura (C)", "type": "number", "required": True, "min": 30, "max": 45},
        {"key": "humedad", "label": "Humedad (%)", "type": "number", "required": True, "min": 0, "max": 100},
        {"key": "co2", "label": "CO2 (%)", "type": "number", "required": False},
        {"key": "observaciones", "label": "Observaciones", "type": "text", "required": False},
        {"key": "firma", "label": "Firma del Tecnico", "type": "signature", "required": True},
    ]},
    {"id": "tpl-autoclaves", "name": "Control de Autoclave", "module": "autoclaves", "version": 1, "fields": [
        {"key": "temperatura", "label": "Temperatura (C)", "type": "number", "required": True},
        {"key": "presion", "label": "Presion (psi)", "type": "number", "required": True},
        {"key": "tiempo", "label": "Tiempo (min)", "type": "number", "required": True},
        {"key": "ciclo", "label": "Tipo de Ciclo", "type": "select", "required": True, "options": ["Liquidos", "Instrumentos", "Residuos", "Rapido"]},
        {"key": "observaciones", "label": "Observaciones", "type": "text", "required": False},
    ]},
    {"id": "tpl-ultracongeladores", "name": "Registro de Ultracongeladores", "module": "ultracongeladores", "version": 1, "fields": [
        {"key": "temperatura", "label": "Temperatura (C)", "type": "number", "required": True, "min": -90, "max": -60},
        {"key": "alarma", "label": "Estado de Alarma", "type": "select", "required": True, "options": ["Normal", "Alerta", "Critico"]},
        {"key": "respaldo_co2", "label": "Respaldo CO2", "type": "select", "required": True, "options": ["OK", "Bajo", "Vacio"]},
        {"key": "observaciones", "label": "Observaciones", "type": "text", "required": False},
    ]},
    {"id": "tpl-equipos", "name": "Bitacora de Equipos", "module": "equipos", "version": 1, "fields": [
        {"key": "equipo", "label": "Nombre del Equipo", "type": "text", "required": True},
        {"key": "estado", "label": "Estado", "type": "select", "required": True, "options": ["Operativo", "En Mantenimiento", "Fuera de Servicio"]},
        {"key": "horas_uso", "label": "Horas de Uso", "type": "number", "required": False},
        {"key": "observaciones", "label": "Observaciones", "type": "text", "required": False},
    ]},
    {"id": "tpl-procesamiento", "name": "Control de Procesamiento", "module": "procesamiento", "version": 1, "fields": [
        {"key": "tipo_muestra", "label": "Tipo de Muestra", "type": "text", "required": True},
        {"key": "cantidad", "label": "Cantidad", "type": "number", "required": True},
        {"key": "proceso", "label": "Proceso Realizado", "type": "select", "required": True, "options": ["Centrifugacion", "Incubacion", "Esterilizacion", "Almacenamiento"]},
        {"key": "responsable", "label": "Responsable", "type": "text", "required": True},
        {"key": "observaciones", "label": "Observaciones", "type": "text", "required": False},
    ]},
]


async def seed_users():
    async with async_session() as db:
        result = await db.execute(select(Usuario))
        if result.first() is None:
            db.add_all(SEED_USERS)
            await db.commit()
            print("Usuarios seeded exitosamente.")


async def seed_templates():
    async with async_session() as db:
        result = await db.execute(select(Template))
        if result.first() is None:
            for tpl_data in TEMPLATES_SEED:
                template = Template(
                    id=tpl_data["id"],
                    name=tpl_data["name"],
                    module=tpl_data["module"],
                    version=tpl_data["version"],
                    structure_json=json.dumps(tpl_data),
                )
                db.add(template)
            await db.commit()
            print(f"Plantillas seeded: {len(TEMPLATES_SEED)} templates")


async def run_safe_migrations():
    from sqlalchemy import text
    from app.core.database import engine
    async with engine.begin() as conn:
        additions = [
            ("audit_logs", "entity_id", "VARCHAR"),
            ("audit_logs", "changed_fields_json", "TEXT"),
        ]
        for table, column, col_type in additions:
            try:
                await conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {column} {col_type}"))
                print(f"Migration: added {table}.{column}")
            except Exception:
                pass
