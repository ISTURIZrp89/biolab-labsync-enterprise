
from pydantic import BaseModel


class DayClosureRequest(BaseModel):
    date: str
    status: str
    closed_by: str
    notes: str


class DayReopenRequest(BaseModel):
    date: str
    reopened_by: str
    reason: str


class MonthClosureRequest(BaseModel):
    year: int
    month: int
    status: str
    closed_by: str
    notes: str


class MonthReopenRequest(BaseModel):
    year: int
    month: int
    reopened_by: str
    reason: str
