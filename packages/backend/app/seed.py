import json
import logging
import secrets

from passlib.context import CryptContext
from sqlalchemy import select

from app.core.database import async_session
from app.models.template import Template
from app.models.usuario import UserRole, Usuario

logger = logging.getLogger(__name__)

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def _generate_pin() -> str:
    return f"{secrets.randbelow(10000):04d}"


def _generate_password() -> str:
    return secrets.token_urlsafe(16)


def _build_seed_users() -> list[Usuario]:
    admin_pin = _generate_pin()
    admin_pass = _generate_password()
    jefe_pin = _generate_pin()
    jefe_pass = _generate_password()
    t1_pin = _generate_pin()
    t1_pass = _generate_password()
    auditor_pin = _generate_pin()
    auditor_pass = _generate_password()
    dueno_pin = _generate_pin()
    dueno_pass = _generate_password()

    logger.warning("=== SEED USERS CREATED (first run only) ===")
    logger.warning("Admin  -> ID: usr-admin  | PIN: %s | Pass: %s", admin_pin, admin_pass)
    logger.warning("Jefe   -> ID: usr-jefe   | PIN: %s | Pass: %s", jefe_pin, jefe_pass)
    logger.warning("Lab    -> ID: usr-t1     | PIN: %s | Pass: %s", t1_pin, t1_pass)
    logger.warning("Auditor-> ID: usr-auditor| PIN: %s | Pass: %s", auditor_pin, auditor_pass)
    logger.warning("Dueño  -> ID: usr-dueno  | PIN: %s | Pass: %s", dueno_pin, dueno_pass)
    logger.warning("================================================")

    return [
        Usuario(
            id="usr-admin",
            nombre="Administrador",
            cargo="ADMINISTRADOR",
            area="Administracion",
            rol=UserRole.ADMIN,
            pin_hash=pwd_context.hash(admin_pin),
            pass_hash=pwd_context.hash(admin_pass),
        ),
        Usuario(
            id="usr-jefe",
            nombre="Dr. Alberto Parra Barrera",
            cargo="JEFE DE LABORATORIO",
            area="Laboratorio Central",
            supervisor="Director General",
            firma="Dr. Alberto Parra Barrera",
            rol=UserRole.JEFE,
            pin_hash=pwd_context.hash(jefe_pin),
            pass_hash=pwd_context.hash(jefe_pass),
        ),
        Usuario(
            id="usr-t1",
            nombre="Biol. Maria Guadalupe Ramirez Padilla",
            cargo="BIOLOGO",
            area="Cultivo Celular",
            supervisor="Dr. Alberto Parra Barrera",
            firma="Biol. Maria Guadalupe Ramirez Padilla",
            rol=UserRole.LABORATORIO,
            pin_hash=pwd_context.hash(t1_pin),
            pass_hash=pwd_context.hash(t1_pass),
        ),
        Usuario(
            id="usr-auditor",
            nombre="Auditor Externo",
            cargo="QFB",
            area="Calidad",
            supervisor="Director General",
            firma="Auditor Externo",
            rol=UserRole.AUDITOR,
            pin_hash=pwd_context.hash(auditor_pin),
            pass_hash=pwd_context.hash(auditor_pass),
        ),
        Usuario(
            id="usr-dueno",
            nombre="Director General",
            cargo="DIRECTOR GENERAL",
            area="Direccion General",
            firma="Director General",
            rol=UserRole.DUENO,
            pin_hash=pwd_context.hash(dueno_pin),
            pass_hash=pwd_context.hash(dueno_pass),
        ),
    ]


SEED_USERS = _build_seed_users()

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
            logger.info("Usuarios seeded exitosamente.")


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
            logger.info("Plantillas seeded: %d templates", len(TEMPLATES_SEED))


async def run_safe_migrations():
    from sqlalchemy import text

    from app.core.database import engine

    SAFE_MIGRATIONS = {
        "audit_logs": {
            "entity_id": "VARCHAR",
            "changed_fields_json": "TEXT",
        },
    }

    async with engine.begin() as conn:
        for table, columns in SAFE_MIGRATIONS.items():
            for column, col_type in columns.items():
                try:
                    await conn.execute(
                        text(f"ALTER TABLE {table} ADD COLUMN {column} {col_type}")
                    )
                    logger.info("Migration: added %s.%s", table, column)
                except Exception:
                    pass
