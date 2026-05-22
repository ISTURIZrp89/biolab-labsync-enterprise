from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from passlib.context import CryptContext
from sqlalchemy.orm import Session

import models
from database import engine, get_db
from config import CORS_ORIGINS
import json
from routers import health, auth, sync, audit, updates, pdf, templates, calendar, users

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="LABSYNC Enterprise API", version="7.0")

origins = [o.strip() for o in CORS_ORIGINS.split(",")] if CORS_ORIGINS != "*" else ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def seed_users():
    db = next(get_db())
    try:
        if db.query(models.Usuario).count() == 0:
            admin = models.Usuario(
                id="usr-admin",
                nombre="Administrador",
                cargo="ADMINISTRADOR",
                cargo_operativo="ADMINISTRADOR",
                area="Administracion",
                supervisor="",
                firma="Administrador",
                rol="ADMIN",
                pin_hash=pwd_context.hash("1234"),
                pass_hash=pwd_context.hash("admin"),
                activo=True
            )
            jefe = models.Usuario(
                id="usr-jefe",
                nombre="Dr. Alberto Parra Barrera",
                cargo="JEFE DE LABORATORIO",
                cargo_operativo="JEFE DE LABORATORIO",
                area="Laboratorio Central",
                supervisor="Director General",
                firma="Dr. Alberto Parra Barrera",
                rol="JEFE",
                pin_hash=pwd_context.hash("0000"),
                pass_hash=pwd_context.hash("biolab"),
                activo=True
            )
            tecnico = models.Usuario(
                id="usr-t1",
                nombre="Biol. Maria Guadalupe Ramirez Padilla",
                cargo="BIÓLOGO",
                cargo_operativo="BIÓLOGO",
                area="Cultivo Celular",
                supervisor="Dr. Alberto Parra Barrera",
                firma="Biol. Maria Guadalupe Ramirez Padilla",
                rol="LABORATORIO",
                pin_hash=pwd_context.hash("1111"),
                pass_hash=pwd_context.hash("biolab"),
                activo=True
            )
            auditor = models.Usuario(
                id="usr-auditor",
                nombre="Auditor Externo",
                cargo="QFB",
                cargo_operativo="QFB",
                area="Calidad",
                supervisor="Director General",
                firma="Auditor Externo",
                rol="AUDITOR",
                pin_hash=pwd_context.hash("2222"),
                pass_hash=pwd_context.hash("biolab"),
                activo=True
            )
            dueno = models.Usuario(
                id="usr-dueno",
                nombre="Director General",
                cargo="DIRECTOR GENERAL",
                cargo_operativo="DIRECTOR GENERAL",
                area="Direccion General",
                supervisor="",
                firma="Director General",
                rol="DUEÑO",
                pin_hash=pwd_context.hash("3333"),
                pass_hash=pwd_context.hash("biolab"),
                activo=True
            )
            db.add_all([admin, jefe, tecnico, auditor, dueno])
            db.commit()
            print("Usuarios seeded exitosamente.")
    except Exception as e:
        print(f"Error seeding usuarios: {e}")
    finally:
        db.close()

seed_users()

db = next(get_db())
try:
    templates.seed_templates(db)
finally:
    db.close()

app.include_router(health.router)
app.include_router(auth.router)
app.include_router(sync.router)
app.include_router(audit.router)
app.include_router(updates.router)
app.include_router(pdf.router)
app.include_router(templates.router)
app.include_router(calendar.router)
app.include_router(users.router)
