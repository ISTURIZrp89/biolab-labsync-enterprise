"""
BioLab LABSYNC - AI Service (Phase 1)
Smart rules engine: suggestions, validation, autocomplete based on history.
Phase 2: Qwen2 0.5B / SmolLM / TinyLlama via ONNX/GGUF on the powerful PC.
"""

import json
import re
from datetime import datetime, timedelta
from typing import Any, Optional
from pathlib import Path

SUGGESTIONS_DIR = Path(__file__).parent / "data"
SUGGESTIONS_DIR.mkdir(exist_ok=True)

# ---------------------------------------------------------------------------
# History-based suggestions
# ---------------------------------------------------------------------------

class SuggestionEngine:
    def __init__(self):
        self._history_cache: dict[str, list[str]] = {}
        self._context_cache: dict[str, list[dict]] = {}

    def _history_path(self, field_key: str) -> Path:
        safe = re.sub(r"[^a-zA-Z0-9_]", "_", field_key)
        return SUGGESTIONS_DIR / f"history_{safe}.json"

    def _context_path(self, module: str, section: str) -> Path:
        safe = f"{re.sub(r'[^a-zA-Z0-9_]', '_', module)}_{re.sub(r'[^a-zA-Z0-9_]', '_', section)}"
        return SUGGESTIONS_DIR / f"context_{safe}.json"

    def get_suggestions(self, field_key: str, query: str = "", max_results: int = 8) -> list[str]:
        path = self._history_path(field_key)
        if not path.exists():
            return []
        try:
            with open(path, "r", encoding="utf-8") as f:
                values: list[str] = json.load(f)
        except (json.JSONDecodeError, FileNotFoundError):
            return []
        if not query:
            return values[:max_results]
        q = query.lower()
        return [v for v in values if q in v.lower()][:max_results]

    def record_value(self, field_key: str, value: str) -> None:
        if not value:
            return
        path = self._history_path(field_key)
        values: list[str] = []
        if path.exists():
            try:
                with open(path, "r", encoding="utf-8") as f:
                    values = json.load(f)
            except (json.JSONDecodeError, FileNotFoundError):
                values = []
        if value in values:
            values.remove(value)
        values.insert(0, value)
        if len(values) > 50:
            values = values[:50]
        with open(path, "w", encoding="utf-8") as f:
            json.dump(values, f, ensure_ascii=False)

    def get_contextual_suggestions(
        self, module: str, section: str, context: dict[str, Any], max_results: int = 5
    ) -> list[dict]:
        path = self._context_path(module, section)
        if not path.exists():
            return []
        try:
            with open(path, "r", encoding="utf-8") as f:
                entries: list[dict] = json.load(f)
        except (json.JSONDecodeError, FileNotFoundError):
            return []
        scored = []
        for entry in entries:
            score = 0
            ctx = entry.get("context", {})
            for k, v in context.items():
                if str(ctx.get(k, "")).lower() == str(v).lower():
                    score += 10
            score += entry.get("frequency", 1)
            scored.append({**entry, "_score": score})
        scored.sort(key=lambda x: x.get("_score", 0), reverse=True)
        return scored[:max_results]

    def record_contextual(self, module: str, section: str, data: dict[str, Any]) -> None:
        contextual_keys = ["responsable", "area", "turno", "equipo", "reactivo"]
        context = {k: data[k] for k in contextual_keys if k in data and data[k]}
        if not context:
            return
        path = self._context_path(module, section)
        entries: list[dict] = []
        if path.exists():
            try:
                with open(path, "r", encoding="utf-8") as f:
                    entries = json.load(f)
            except (json.JSONDecodeError, FileNotFoundError):
                entries = []
        idx = next(
            (i for i, e in enumerate(entries) if all(
                str(e.get("context", {}).get(k, "")) == str(v)
                for k, v in context.items()
            )),
            -1,
        )
        if idx >= 0:
            entries[idx]["frequency"] = entries[idx].get("frequency", 1) + 1
            entries[idx]["last_used"] = datetime.utcnow().isoformat()
        else:
            entries.insert(0, {
                "context": context,
                "frequency": 1,
                "last_used": datetime.utcnow().isoformat(),
            })
        if len(entries) > 100:
            entries = entries[:100]
        with open(path, "w", encoding="utf-8") as f:
            json.dump(entries, f, ensure_ascii=False)


# ---------------------------------------------------------------------------
# Validation rules
# ---------------------------------------------------------------------------

class ValidationEngine:
    @staticmethod
    def validate(data: dict[str, Any], section: Optional[dict] = None) -> dict:
        errors = []
        warnings = []
        suggestions = []

        required_fields = []
        if section:
            for f in section.get("general_fields", []):
                if f.get("required"):
                    required_fields.append(f["key"])

        for key in required_fields:
            val = data.get(key, "")
            if not val or not str(val).strip():
                errors.append(f"{key} es requerido")

        start = data.get("hora_inicio", "")
        end = data.get("hora_fin", "")
        if start and end:
            try:
                s_parts = start.split(":")
                e_parts = end.split(":")
                s_min = int(s_parts[0]) * 60 + int(s_parts[1])
                e_min = int(e_parts[0]) * 60 + int(e_parts[1])
                if e_min <= s_min:
                    warnings.append("Hora fin debe ser posterior a hora inicio")
                if e_min - s_min > 480:
                    warnings.append("Periodo mayor a 8 horas, verificar")
            except (ValueError, IndexError):
                pass

        actividades = data.get("_actividades", [])
        if actividades:
            empty = sum(
                1 for a in actividades
                if isinstance(a, dict) and all(not str(v).strip() for v in a.values())
            )
            if empty == len(actividades):
                suggestions.append("Agregar al menos una actividad con datos")

        incidencias = data.get("incidencias", "")
        if incidencias and len(incidencias) < 5:
            warnings.append("Descripcion de incidencia muy corta, detallar")

        fecha = data.get("fecha", "")
        if fecha:
            try:
                dt = datetime.fromisoformat(fecha)
                if dt > datetime.now() + timedelta(days=1):
                    warnings.append("Fecha en el futuro, verificar")
            except (ValueError, TypeError):
                errors.append("Formato de fecha invalido")

        recursos = data.get("_recursos", [])
        for r in recursos:
            if isinstance(r, dict):
                reactivo = r.get("reactivo", "")
                lote = r.get("lote", "")
                if reactivo and not lote:
                    warnings.append(f'Reactivo "{reactivo}" sin numero de lote')
                cad = r.get("caducidad", "")
                if cad:
                    try:
                        cad_dt = datetime.fromisoformat(cad)
                        if cad_dt < datetime.now():
                            errors.append(f'Reactivo "{reactivo}" con fecha de caducidad vencida')
                    except (ValueError, TypeError):
                        pass

        return {
            "is_valid": len(errors) == 0,
            "errors": errors,
            "warnings": warnings,
            "suggestions": suggestions,
        }

    @staticmethod
    def validate_for_closure(data: dict) -> list[str]:
        issues = []
        actividades = data.get("_actividades", [])
        if not actividades or all(
            isinstance(a, dict) and all(not str(v).strip() for v in a.values())
            for a in actividades
        ):
            issues.append("Sin actividades registradas")
        if not data.get("responsable"):
            issues.append("Sin responsable asignado")
        return issues


# ---------------------------------------------------------------------------
# Prediction helpers
# ---------------------------------------------------------------------------

PREDICT_NEXT_FIELD: dict[str, str] = {
    "hora_inicio": "hora_fin",
    "responsable": "cargo_operativo",
    "area": "supervisor",
    "reactivo": "lote",
    "lote": "caducidad",
    "caducidad": "cantidad",
    "equipo": "tipo_equipo",
}

def predict_next_field(current_field: str) -> Optional[str]:
    return PREDICT_NEXT_FIELD.get(current_field)

def predict_value(field_key: str, context: dict[str, Any]) -> Optional[str]:
    if field_key == "hora_fin" and "hora_inicio" in context:
        start = context["hora_inicio"]
        try:
            parts = start.split(":")
            h = int(parts[0]) + 1
            return f"{h:02d}:{parts[1]}"
        except (ValueError, IndexError):
            pass
    if field_key == "turno":
        now = datetime.now().hour
        return "MATUTINO" if now < 14 else "VESPERTINO"
    return None


# Singleton
_suggestion_engine: Optional[SuggestionEngine] = None

def get_suggestion_engine() -> SuggestionEngine:
    global _suggestion_engine
    if _suggestion_engine is None:
        _suggestion_engine = SuggestionEngine()
    return _suggestion_engine
