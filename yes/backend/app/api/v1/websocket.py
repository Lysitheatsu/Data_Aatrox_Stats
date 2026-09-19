"""
websocket.py

FastAPI WebSocket router for real-time emergency session telemetry streams.
"""

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from app.websocket.connection_manager import ws_manager
from app.core.logging import logger

router = APIRouter(tags=["Emergency WebSockets"])


@router.websocket("/ws/emergency/{session_id}")
async def emergency_session_websocket(websocket: WebSocket, session_id: str):
    await ws_manager.connect(session_id, websocket)
    try:
        while True:
            data = await websocket.receive_json()
            logger.info(f"Received WS message for session {session_id}: {data.get('event')}")
            # Echo heartbeat or state sync
            await websocket.send_json({
                "status": "ack",
                "received_event": data.get("event"),
                "timestamp": data.get("timestamp")
            })
    except WebSocketDisconnect:
        ws_manager.disconnect(session_id, websocket)
    except Exception as e:
        logger.error(f"WebSocket error in session {session_id}: {e}")
        ws_manager.disconnect(session_id, websocket)
