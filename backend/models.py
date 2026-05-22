from sqlalchemy import Column, String, Boolean, Integer, DateTime, Text, ForeignKey
from sqlalchemy.sql import func
from database import Base

class Usuario(Base):
    __tablename__ = "usuarios"
    id = Column(String, primary_key=True, index=True)
    nombre = Column(String, nullable=False)
    cargo = Column(String) # Cargo operativo que aparece en reportes (TECNICO, BIOLOGO, QFB, etc.)
    cargo_operativo = Column(String) # Alias para compatibilidad (se mapea a cargo)
    area = Column(String, default="Cultivo Celular")
    supervisor = Column(String, default="")
    firma = Column(String, default="")
    rol = Column(String, nullable=False) # ADMIN, JEFE, LABORATORIO, AUDITOR, DUEÑO
    pin_hash = Column(String)
    pass_hash = Column(String)
    activo = Column(Boolean, default=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

class Device(Base):
    __tablename__ = "devices"
    id = Column(String, primary_key=True, index=True)
    device_name = Column(String)
    os = Column(String) # Windows, macOS, Android
    is_approved = Column(Boolean, default=False)
    registered_at = Column(DateTime, default=func.now())
    approved_at = Column(DateTime, nullable=True)

class Template(Base):
    __tablename__ = "templates"
    id = Column(String, primary_key=True, index=True)
    name = Column(String, nullable=False)
    version = Column(Integer, default=1)
    structure_json = Column(Text) # JSON structure containing fields and validations
    created_at = Column(DateTime, default=func.now())

class FormEntry(Base):
    __tablename__ = "form_entries"
    id = Column(String, primary_key=True, index=True)
    module = Column(String, index=True)
    date = Column(String, index=True)
    user_id = Column(String, ForeignKey("usuarios.id"))
    device_id = Column(String, ForeignKey("devices.id"))
    version = Column(Integer, default=1)
    data_json = Column(Text) # JSON encoded data dictionary
    status = Column(String) # saved, excused
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

class DayClosure(Base):
    __tablename__ = "day_closures"
    id = Column(String, primary_key=True, index=True)
    date = Column(String, unique=True, index=True)
    status = Column(String) # CERRADO, CERRADO_OBSERVACION, ABIERTO
    closed_by = Column(String, ForeignKey("usuarios.id"))
    closed_at = Column(DateTime, default=func.now())
    notes = Column(Text)
    reopen_log_json = Column(Text, default="[]") # History log of reopens

class AuditLog(Base):
    __tablename__ = "audit_logs"
    id = Column(String, primary_key=True, index=True)
    action = Column(String, index=True) # LOGIN, LOGOUT, SAVE_ENTRY, CLOSE_DAY, etc.
    user_id = Column(String, ForeignKey("usuarios.id"), nullable=True)
    device_id = Column(String, ForeignKey("devices.id"), nullable=True)
    timestamp = Column(DateTime, default=func.now())
    details_json = Column(Text) # Additional JSON metadata

class SyncHistory(Base):
    __tablename__ = "sync_history"
    id = Column(String, primary_key=True, index=True)
    device_id = Column(String, ForeignKey("devices.id"))
    synced_at = Column(DateTime, default=func.now())
    records_uploaded = Column(Integer, default=0)
    records_downloaded = Column(Integer, default=0)
    status = Column(String) # success, failed

class UpdateInfo(Base):
    __tablename__ = "updates"
    id = Column(String, primary_key=True, index=True)
    version = Column(String, unique=True)
    file_url = Column(String)
    release_notes = Column(Text)
    is_mandatory = Column(Boolean, default=False)
    released_at = Column(DateTime, default=func.now())

class Setting(Base):
    __tablename__ = "settings"
    key = Column(String, primary_key=True, index=True)
    value = Column(Text)
    description = Column(Text)
