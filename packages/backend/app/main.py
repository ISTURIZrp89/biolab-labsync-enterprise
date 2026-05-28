from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.database import engine, Base
from app.seed import seed_users, seed_templates, run_safe_migrations
from app.modules.auth.router import router as auth_router
from app.modules.sync.router import router as sync_router
from app.modules.audit.router import router as audit_router
from app.modules.calendar.router import router as calendar_router
from app.modules.reports.router import router as reports_router
from app.modules.health.router import router as health_router
from app.modules.templates.router import router as templates_router
from app.modules.users.router import router as users_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await run_safe_migrations()
    await seed_users()
    await seed_templates()
    yield
    await engine.dispose()


app = FastAPI(
    title=settings.app_name,
    version=settings.version,
    lifespan=lifespan,
)

if settings.cors_origins == "*":
    origins = ["*"]
elif settings.debug:
    origins = ["*"]
else:
    origins = [o.strip() for o in settings.cors_origins.split(",")]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=origins != ["*"],
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
