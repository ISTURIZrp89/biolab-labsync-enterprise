import json
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from passlib.context import CryptContext
from sqlalchemy import select

from app.core.config import settings
from app.core.database import engine, Base, async_session
from app.models.usuario import Usuario, UserRole
from app.modules.auth.router import router as auth_router
from app.modules.sync.router import router as sync_router
from app.modules.audit.router import router as audit_router
from app.modules.calendar.router import router as calendar_router
from app.modules.reports.router import router as reports_router
from app.modules.health.router import router as health_router
from app.modules.templates.router import router as templates_router, seed_templates
from app.modules.users.router import router as users_router

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


async def seed_users():
    async with async_session() as db:
        result = await db.execute(select(Usuario))
        if result.first() is None:
            users = [
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
            db.add_all(users)
            await db.commit()
            print("Usuarios seeded exitosamente.")


async def run_safe_migrations():
    from sqlalchemy import text
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


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await run_safe_migrations()
    await seed_users()
    async with async_session() as db:
        await seed_templates(db)
    yield
    await engine.dispose()


app = FastAPI(
    title=settings.app_name,
    version=settings.version,
    lifespan=lifespan,
)

origins = [o.strip() for o in settings.cors_origins.split(",")] if settings.cors_origins != "*" else ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router)
app.include_router(auth_router)
app.include_router(sync_router)
app.include_router(audit_router)
app.include_router(calendar_router)
app.include_router(reports_router)
app.include_router(templates_router)
app.include_router(users_router)


@app.get("/")
async def root():
    return {"app": settings.app_name, "version": settings.version}
