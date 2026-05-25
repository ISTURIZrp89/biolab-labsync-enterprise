from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime

class UserLogin(BaseModel):
    user_id: str
    pin: Optional[str] = None
    password: Optional[str] = None
    device_id: str

class Token(BaseModel):
    access_token: str
    token_type: str
    user_id: str
    nombre: str
    rol: str

class UserCreate(BaseModel):
    id: str
    nombre: str
    cargo: Optional[str] = None
    cargo_operativo: Optional[str] = None
    area: Optional[str] = None
    supervisor: Optional[str] = None
    firma: Optional[str] = None
    rol: str
    pin: Optional[str] = None
    password: Optional[str] = None

class DeviceRegister(BaseModel):
    device_id: str
    device_name: str
    os: str

class SyncQueueItem(BaseModel):
    id: str
    action: str # CREATE, UPDATE, DELETE
    entity: str # form_entries, day_closures, audit_logs
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

class AuditLogSchema(BaseModel):
    id: str
    action: str
    user_id: Optional[str] = None
    device_id: Optional[str] = None
    timestamp: datetime
    details: Dict[str, Any]

    class Config:
        from_attributes = True

class FormEntrySchema(BaseModel):
    id: str
    module: str
    date: str
    user_id: str
    device_id: str
    version: int
    data: Dict[str, Any]
    status: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
