from datetime import datetime, timezone

from fastapi import WebSocket, WebSocketDisconnect


class ConnectionManager:
    def __init__(self):
        self.active: dict[str, WebSocket] = {}

    async def connect(self, websocket: WebSocket, device_id: str):
        await websocket.accept()
        self.active[device_id] = websocket

    def disconnect(self, device_id: str):
        self.active.pop(device_id, None)

    async def broadcast(self, message: dict, exclude: str | None = None):
        for device_id, ws in self.active.items():
            if device_id != exclude:
                try:
                    await ws.send_json(message)
                except Exception:
                    self.disconnect(device_id)


manager = ConnectionManager()


async def sync_websocket(websocket: WebSocket, device_id: str):
    await manager.connect(websocket, device_id)
    try:
        while True:
            data = await websocket.receive_json()
            response = {
                "type": "sync_ack",
                "device_id": device_id,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "changes": data.get("changes", []),
            }
            await websocket.send_json(response)
            await manager.broadcast(
                {"type": "peer_update", "device_id": device_id, "data": data},
                exclude=device_id,
            )
    except WebSocketDisconnect:
        manager.disconnect(device_id)
