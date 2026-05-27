"""
BioLab LABSYNC - AI API Router (Phase 1)
Lightweight smart rules endpoint consumed by the Flutter app.
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Any, Optional

from .ai_service import (
    get_suggestion_engine,
    ValidationEngine,
    predict_value,
    predict_next_field,
)

router = APIRouter(prefix="/api/ai", tags=["ai"])


# ---------------------------------------------------------------------------
# Request / Response schemas
# ---------------------------------------------------------------------------

class SuggestRequest(BaseModel):
    field_key: str
    query: str = ""
    max_results: int = 8


class SuggestResponse(BaseModel):
    suggestions: list[str]


class ContextSuggestRequest(BaseModel):
    module: str
    section: str
    context: dict[str, Any] = {}
    max_results: int = 5


class RecordRequest(BaseModel):
    field_key: str
    value: str


class RecordContextRequest(BaseModel):
    module: str
    section: str
    data: dict[str, Any] = {}


class ValidateRequest(BaseModel):
    data: dict[str, Any]
    section: Optional[dict] = None


class ValidateResponse(BaseModel):
    is_valid: bool
    errors: list[str]
    warnings: list[str]
    suggestions: list[str]


class PredictRequest(BaseModel):
    field_key: str
    context: dict[str, Any] = {}


class PredictNextFieldRequest(BaseModel):
    current_field: str


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.post("/suggest", response_model=SuggestResponse)
def suggest(req: SuggestRequest):
    engine = get_suggestion_engine()
    results = engine.get_suggestions(req.field_key, req.query, req.max_results)
    return SuggestResponse(suggestions=results)


@router.post("/suggest/contextual")
def suggest_contextual(req: ContextSuggestRequest):
    engine = get_suggestion_engine()
    results = engine.get_contextual_suggestions(
        req.module, req.section, req.context, req.max_results
    )
    return {"suggestions": results}


@router.post("/record")
def record(req: RecordRequest):
    engine = get_suggestion_engine()
    engine.record_value(req.field_key, req.value)
    return {"status": "ok"}


@router.post("/record/contextual")
def record_contextual(req: RecordContextRequest):
    engine = get_suggestion_engine()
    engine.record_contextual(req.module, req.section, req.data)
    return {"status": "ok"}


@router.post("/validate", response_model=ValidateResponse)
def validate(req: ValidateRequest):
    result = ValidationEngine.validate(req.data, req.section)
    return ValidateResponse(**result)


@router.post("/predict/value")
def predict(req: PredictRequest):
    value = predict_value(req.field_key, req.context)
    return {"value": value}


@router.post("/predict/next-field")
def predict_next(req: PredictNextFieldRequest):
    field = predict_next_field(req.current_field)
    return {"next_field": field}


# ---------------------------------------------------------------------------
# Silent AI Monitoring & Consensus Endpoints
# ---------------------------------------------------------------------------

from fastapi import Depends
from sqlalchemy.orm import Session
import models
import json
from database import get_db
from .ai_service import get_anomaly_detector, get_consensus_manager

class PeerRegisterRequest(BaseModel):
    device_id: str
    ip: str
    hostname: str
    port: int

class ConsensusProposeRequest(BaseModel):
    entity: str
    entity_id: str
    local_data: dict

@router.get("/anomalies")
def get_anomalies(role: Optional[str] = None):
    # Quiet warning system: restrict viewing to ADMIN or AUDITOR roles
    if role and role not in ["ADMIN", "AUDITOR", "JEFE"]:
         raise HTTPException(status_code=403, detail="Acceso denegado: rol insuficiente")
    detector = get_anomaly_detector()
    return {"anomalies": detector.anomalies}

@router.post("/consensus/register-peer")
def register_peer(req: PeerRegisterRequest):
    manager = get_consensus_manager()
    manager.register_peer(req.device_id, req.ip, req.hostname, req.port)
    return {"status": "ok", "active_peers": len(manager.get_active_peers())}

@router.get("/consensus/peers")
def get_peers():
    manager = get_consensus_manager()
    return {"peers": manager.get_active_peers()}

@router.get("/consensus/get-record")
def get_record(entity: str, entity_id: str, db: Session = Depends(get_db)):
    if entity == "form_entries":
        record = db.query(models.FormEntry).filter(models.FormEntry.id == entity_id).first()
        if record:
            try:
                data = json.loads(record.data_json) if isinstance(record.data_json, str) else record.data_json
            except Exception:
                data = {}
            return {
                "data": {
                    "id": record.id,
                    "module": record.module,
                    "date": record.date,
                    "user_id": record.user_id,
                    "device_id": record.device_id,
                    "version": record.version,
                    "data": data,
                    "status": record.status,
                    "created_at": record.created_at.isoformat() if record.created_at else "",
                    "updated_at": record.updated_at.isoformat() if record.updated_at else "",
                }
            }
    elif entity == "day_closures":
        record = db.query(models.DayClosure).filter(models.DayClosure.id == entity_id).first()
        if record:
            try:
                reopen_log = json.loads(record.reopen_log_json) if isinstance(record.reopen_log_json, str) else record.reopen_log_json
            except Exception:
                reopen_log = []
            return {
                "data": {
                    "id": record.id,
                    "date": record.date,
                    "status": record.status,
                    "closed_by": record.closed_by,
                    "closed_at": record.closed_at.isoformat() if record.closed_at else "",
                    "notes": record.notes,
                    "reopen_log": reopen_log,
                }
            }
    return {"data": None}

@router.post("/consensus/propose")
async def propose(req: ConsensusProposeRequest):
    manager = get_consensus_manager()
    resolution = await manager.propose_consensus(req.entity, req.entity_id, req.local_data)
    return resolution


@router.get("/health")
def health():
    # Make sure background threads are active
    get_anomaly_detector()
    return {"status": "ok", "phase": 2, "engine": "local-ai-consensus"}

