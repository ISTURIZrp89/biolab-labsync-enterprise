from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel


class AuditLogResponse(BaseModel):
    id: str
    action: str
    user_id: Optional[str] = None
    device_id: Optional[str] = None
    timestamp: datetime
    details: Dict[str, Any]
    entity_id: Optional[str] = None
    changed_fields: List[Dict[str, Any]] = []
    has_diff: bool = False


class AuditWriteRequest(BaseModel):
    action: str
    user_id: Optional[str] = None
    device_id: Optional[str] = None
    entity_id: Optional[str] = None
    details: dict = {}
    changed_fields: list[dict[str, Any]] = []
