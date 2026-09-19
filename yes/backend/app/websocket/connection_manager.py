"""
connection_manager.py

WebSocket connection manager for handling real-time emergency session broadcasts.
"""

from typing import Dict, Set
from fastapi import WebSocket
from app.core.logging import logger


class ConnectionManager:
    def __init__(self) -> None:
        # Maps session_id -> Set of active WebSocket connections
        self._active_sessions: Dict[str, Set[WebSocket]] = {}

    async def connect(self, session_id: str, websocket: WebSocket) -> None:
        await websocket.accept()
        if session_id not in self._active_sessions:
            self._active_sessions[session_id] = set()
        self._active_sessions[session_id].add(websocket)
        logger.info(f"WebSocket client connected to emergency session {session_id}")

    def disconnect(self, session_id: str, websocket: WebSocket) -> None:
        if session_id in self._active_sessions:
            self._active_sessions[session_id].discard(websocket)
            if not self._active_sessions[session_id]:
                del self._active_sessions[session_id]
        logger.info(f"WebSocket client disconnected from emergency session {session_id}")

    async def broadcast_to_session(self, session_id: str, message: dict) -> None:
        if session_id in self._active_sessions:
            dead_sockets = set()
            for connection in self._active_sessions[session_id]:
                try:
                    await connection.send_json(message)
                except Exception as e:
                    logger.warning(f"Error sending message to WebSocket client: {e}")
                    dead_sockets.add(connection)

            for dead in dead_sockets:
                self.disconnect(session_id, dead)


ws_manager = ConnectionManager()
