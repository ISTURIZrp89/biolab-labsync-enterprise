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


@router.get("/health")
def health():
    return {"status": "ok", "phase": 1, "engine": "smart-rules"}
