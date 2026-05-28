from pydantic import BaseModel
from typing import List, Optional, Any, Dict


class TemplateField(BaseModel):
    key: str
    label: str
    type: str
    required: bool = False
    min: Optional[float] = None
    max: Optional[float] = None
    options: Optional[List[str]] = None


class TemplateResponse(BaseModel):
    id: str
    name: str
    module: str = ""
    version: int
    fields: List[TemplateField] = []
