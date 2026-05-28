from pydantic import BaseModel
from typing import List, Optional, Dict, Any


class SyncQueueItem(BaseModel):
    id: str
    action: str
    entity: str
    entity_id: str
    data: Dict[str, Any]
    timestamp: str


class SyncPayload(BaseModel):
    device_id: str
    queue: List[SyncQueueItem]
    last_sync_timestamp: Optional[str] = None


class SyncResponse(BaseModel):
    success: bool
    processed_ids: List[str]
    updates_to_pull: List[Dict[str, Any]]
    conflicts: List[Dict[str, Any]] = []
    server_time: str
