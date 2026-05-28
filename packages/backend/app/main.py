from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.database import engine, Base
from app.modules.auth.router import router as auth_router
from app.modules.health.router import router as health_router
from app.modules.sync.router import router as sync_router
from app.modules.reports.router import router as reports_router
from app.modules.audit.router import router as audit_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    await engine.dispose()


app = FastAPI(
    title=settings.app_name,
    version=settings.version,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router)
app.include_router(auth_router)
app.include_router(sync_router)
app.include_router(reports_router)
app.include_router(audit_router)


@app.get("/")
async def root():
    return {"app": settings.app_name, "version": settings.version}
