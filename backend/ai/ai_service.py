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


# ---------------------------------------------------------------------------
# Lightweight Local AI Engine - Silent System Monitoring
# ---------------------------------------------------------------------------

import threading
import time

class AnomalyDetector:
    def __init__(self):
        self._thread = None
        self._running = False
        self.anomalies = []

    def start(self):
        if self._running:
            return
        self._running = True
        self._thread = threading.Thread(target=self._run_loop, daemon=True)
        self._thread.start()

    def stop(self):
        self._running = False

    def _run_loop(self):
        # Allow system startup before first scan
        time.sleep(5)
        while self._running:
            try:
                self.scan_for_anomalies()
            except Exception as e:
                print(f"AnomalyDetector Error: {e}")
            
            # Scan every 60 seconds
            for _ in range(60):
                if not self._running:
                    break
                time.sleep(1)

    def scan_for_anomalies(self):
        from database import SessionLocal
        import models
        db = SessionLocal()
        try:
            detected = []
            entries = db.query(models.FormEntry).all()
            
            batch_to_entry = {}
            time_entries = {} # (user_id, date): list of (start_min, end_min, entry_id, module)
            
            for entry in entries:
                try:
                    data = json.loads(entry.data_json) if isinstance(entry.data_json, str) else entry.data_json
                except Exception:
                    continue
                if not data:
                    continue
                
                module = entry.module
                entry_date = entry.date
                user_id = entry.user_id
                
                # 1. Duplicate batch/lot detection
                recursos = data.get("_recursos", [])
                for r in recursos:
                    if isinstance(r, dict):
                        reactivo = r.get("reactivo", "")
                        lote = r.get("lote", "")
                        if reactivo and lote:
                            key = (reactivo.lower().strip(), lote.lower().strip())
                            if key in batch_to_entry:
                                prev = batch_to_entry[key]
                                if prev["entry_id"] != entry.id:
                                    detected.append({
                                        "id": f"anomaly-batch-{entry.id}-{prev['entry_id']}",
                                        "type": "DUPLICATE_BATCH",
                                        "severity": "WARNING",
                                        "module": module,
                                        "date": entry_date,
                                        "message": f"El reactivo '{reactivo}' con lote '{lote}' se reporta en múltiples bitácoras (Módulos: {prev['module']} y {module})",
                                        "details": {"reactivo": reactivo, "lote": lote, "entries": [prev["entry_id"], entry.id]}
                                    })
                            else:
                                batch_to_entry[key] = {"entry_id": entry.id, "module": module}

                # 2. Time inconsistencies
                start = data.get("hora_inicio", "")
                end = data.get("hora_fin", "")
                if start and end:
                    try:
                        s_parts = list(map(int, start.split(":")))
                        e_parts = list(map(int, end.split(":")))
                        s_min = s_parts[0] * 60 + s_parts[1]
                        e_min = e_parts[0] * 60 + e_parts[1]
                        
                        if e_min <= s_min:
                            detected.append({
                                "id": f"anomaly-time-{entry.id}",
                                "type": "TIME_INCONSISTENCY",
                                "severity": "ERROR",
                                "module": module,
                                "date": entry_date,
                                "message": f"En el módulo {module}, la hora final ({end}) es menor o igual a la de inicio ({start})",
                                "details": {"entry_id": entry.id, "start": start, "end": end}
                            })
                        elif e_min - s_min > 480:
                            detected.append({
                                "id": f"anomaly-duration-{entry.id}",
                                "type": "TIME_INCONSISTENCY",
                                "severity": "WARNING",
                                "module": module,
                                "date": entry_date,
                                "message": f"Duración de la jornada reportada en {module} supera las 8 horas ({((e_min - s_min)/60.0):.1f} hrs)",
                                "details": {"entry_id": entry.id, "duration_mins": e_min - s_min}
                            })
                            
                        # Overlapping schedules for same user on same day
                        key = (user_id, entry_date)
                        if key not in time_entries:
                            time_entries[key] = []
                        for prev_s, prev_e, prev_id, prev_mod in time_entries[key]:
                            if max(s_min, prev_s) < min(e_min, prev_e):
                                detected.append({
                                    "id": f"anomaly-overlap-{entry.id}-{prev_id}",
                                    "type": "TIME_OVERLAP",
                                    "severity": "ERROR",
                                    "module": module,
                                    "date": entry_date,
                                    "message": f"Traslape de horario en la fecha {entry_date} ({start}-{end} en {module} vs {prev_s//60:02d}:{prev_s%60:02d}-{prev_e//60:02d}:{prev_e%60:02d} en {prev_mod})",
                                    "details": {"user_id": user_id, "date": entry_date, "entries": [prev_id, entry.id]}
                                })
                        time_entries[key].append((s_min, e_min, entry.id, module))
                    except Exception:
                        pass

                # 3. Out of bounds physical variables
                if module == "incubadoras":
                    lecturas = data.get("_lecturas", [])
                    for idx, lec in enumerate(lecturas):
                        if not isinstance(lec, dict):
                            continue
                        try:
                            temp = float(lec.get("temperatura", 37.0))
                            co2 = float(lec.get("co2", 5.0))
                            equipo = lec.get("equipo", "Incubadora")
                            if temp < 35.0 or temp > 39.0:
                                detected.append({
                                    "id": f"anomaly-temp-{entry.id}-{idx}",
                                    "type": "OUT_OF_BOUNDS",
                                    "severity": "ERROR",
                                    "module": module,
                                    "date": entry_date,
                                    "message": f"Temperatura fuera de rango en {equipo}: {temp}°C (Rango: 35-39°C)",
                                    "details": {"entry_id": entry.id, "equipo": equipo, "temp": temp}
                                })
                            if co2 < 4.0 or co2 > 6.0:
                                detected.append({
                                    "id": f"anomaly-co2-{entry.id}-{idx}",
                                    "type": "OUT_OF_BOUNDS",
                                    "severity": "ERROR",
                                    "module": module,
                                    "date": entry_date,
                                    "message": f"CO2 fuera de rango en {equipo}: {co2}% (Rango: 4-6%)",
                                    "details": {"entry_id": entry.id, "equipo": equipo, "co2": co2}
                                })
                        except (ValueError, TypeError):
                            pass

                elif module == "ultracongeladores":
                    temperaturas = data.get("_temperaturas", [])
                    for idx, temp_row in enumerate(temperaturas):
                        if not isinstance(temp_row, dict):
                            continue
                        try:
                            temp = float(temp_row.get("temperatura", -80.0))
                            equipo = temp_row.get("equipo", "Ultracongelador")
                            if temp < -95.0 or temp > -60.0:
                                detected.append({
                                    "id": f"anomaly-ultratemp-{entry.id}-{idx}",
                                    "type": "OUT_OF_BOUNDS",
                                    "severity": "ERROR",
                                    "module": module,
                                    "date": entry_date,
                                    "message": f"Temperatura crítica en {equipo}: {temp}°C (Rango seguro: -95°C a -60°C)",
                                    "details": {"entry_id": entry.id, "equipo": equipo, "temp": temp}
                                })
                        except (ValueError, TypeError):
                            pass

            self.anomalies = detected
        finally:
            db.close()


# ---------------------------------------------------------------------------
# Distributed AI Consensus Mechanism
# ---------------------------------------------------------------------------

class ConsensusManager:
    def __init__(self):
        self.peers = {}

    def register_peer(self, device_id: str, ip: str, hostname: str, port: int):
        self.peers[device_id] = {
            "ip": ip,
            "hostname": hostname,
            "port": port,
            "last_seen": datetime.utcnow()
        }

    def get_active_peers(self) -> list[dict]:
        now = datetime.utcnow()
        active = []
        for dev_id, info in list(self.peers.items()):
            if now - info["last_seen"] < timedelta(seconds=90):
                active.append({**info, "device_id": dev_id})
            else:
                self.peers.pop(dev_id, None)
        return active

    async def propose_consensus(self, entity: str, entity_id: str, local_data: dict) -> dict:
        import httpx
        peers = self.get_active_peers()
        if not peers:
            return {"resolved": True, "winner": "local", "reason": "Sin otros nodos activos en la red local"}

        versions = [{"source": "local", "data": local_data, "weight": self._calculate_weight(local_data)}]

        async with httpx.AsyncClient() as client:
            for peer in peers:
                try:
                    url = f"http://{peer['ip']}:{peer['port']}/api/ai/consensus/get-record"
                    response = await client.get(url, params={"entity": entity, "entity_id": entity_id}, timeout=2.0)
                    if response.statusCode == 200:
                        peer_data = response.json().get("data")
                        if peer_data:
                            versions.append({
                                "source": peer["device_id"],
                                "peer_ip": peer["ip"],
                                "peer_port": peer["port"],
                                "data": peer_data,
                                "weight": self._calculate_weight(peer_data)
                            })
                except Exception:
                    pass

        winner = max(versions, key=lambda x: x["weight"])
        if winner["source"] != "local":
            return {
                "resolved": True,
                "winner": winner["source"],
                "data": winner["data"],
                "reason": f"El nodo '{winner['source']}' posee un registro más completo y/o reciente"
            }

        return {
            "resolved": True,
            "winner": "local",
            "data": local_data,
            "reason": "El registro local es el más completo y actualizado consensuado"
        }

    def _calculate_weight(self, data: dict) -> float:
        if not data:
            return 0.0
        score = 0.0
        non_empty = sum(1 for v in data.values() if v and str(v).strip())
        score += non_empty * 10
        for sub in ["_actividades", "_recursos", "_cajas"]:
            sub_list = data.get(sub, [])
            if isinstance(sub_list, list):
                for item in sub_list:
                    if isinstance(item, dict):
                        score += sum(5 for v in item.values() if v and str(v).strip())
        updated_at = data.get("updated_at")
        if updated_at:
            try:
                dt = datetime.fromisoformat(updated_at.replace("Z", "+00:00"))
                score += dt.timestamp() / 1000000.0
            except Exception:
                pass
        return score


# ---------------------------------------------------------------------------
# Singletons
# ---------------------------------------------------------------------------

_suggestion_engine: Optional[SuggestionEngine] = None
_anomaly_detector: Optional[AnomalyDetector] = None
_consensus_manager: Optional[ConsensusManager] = None

def get_suggestion_engine() -> SuggestionEngine:
    global _suggestion_engine
    if _suggestion_engine is None:
        _suggestion_engine = SuggestionEngine()
    return _suggestion_engine

def get_anomaly_detector() -> AnomalyDetector:
    global _anomaly_detector
    if _anomaly_detector is None:
        _anomaly_detector = AnomalyDetector()
        _anomaly_detector.start()
    return _anomaly_detector

def get_consensus_manager() -> ConsensusManager:
    global _consensus_manager
    if _consensus_manager is None:
        _consensus_manager = ConsensusManager()
    return _consensus_manager

