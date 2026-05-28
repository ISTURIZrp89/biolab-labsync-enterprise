from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session

router = APIRouter(prefix="/sync", tags=["sync"])


@router.post("/push")
async def sync_push(payload: dict, session: AsyncSession = Depends(get_session)):
    return {"status": "ok", "applied": len(payload.get("changes", []))}


@router.get("/pull/{since}")
async def sync_pull(
    since: str, device_id: str, session: AsyncSession = Depends(get_session)
):
    return {"changes": [], "timestamp": since}
