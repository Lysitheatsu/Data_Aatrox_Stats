"""
emergency.py

FastAPI router for handling emergency packet dispatch & session management.
"""

from datetime import datetime, timezone
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.session import get_db
from app.schemas.packet_schema import (
    EmergencyDataPacketCreate,
    EmergencyDataPacketResponse,
    PacketStatus
)
from app.models.emergency_packet import EmergencyPacketModel
from app.websocket.connection_manager import ws_manager
from app.core.logging import logger

router = APIRouter(prefix="/emergency", tags=["Emergency Dispatch"])


@router.post(
    "/dispatch",
    response_model=EmergencyDataPacketResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Receive and validate Smart Emergency Data Packet"
)
async def dispatch_emergency_packet(
    packet: EmergencyDataPacketCreate,
    db: AsyncSession = Depends(get_db)
) -> EmergencyDataPacketResponse:
    logger.info(f"Received emergency packet {packet.packet_id} for user {packet.user_id}")

    db_packet = EmergencyPacketModel(
        packet_id=packet.packet_id,
        session_id=packet.session_id,
        user_id=packet.user_id,
        packet_version=packet.packet_version,
        sequence_number=packet.sequence_number,
        status=packet.status.value,
        priority=packet.priority.value,
        packet_hash=packet.packet_hash,
        packet_checksum=packet.packet_checksum,
        latitude=packet.location.latitude,
        longitude=packet.location.longitude,
        address=packet.location.address,
        transcript_text=packet.transcript.text if packet.transcript else None,
        parsed_intent=packet.transcript.parsed_intent if packet.transcript else None,
        speech_confidence=packet.transcript.confidence if packet.transcript else 0.0,
        ai_models_meta=packet.ai_models.model_dump() if packet.ai_models else None,
        biomarker_summary=packet.biomarker_summary.model_dump() if packet.biomarker_summary else None,
        medical_data=packet.medical.model_dump() if packet.medical else None,
        device_data=packet.device.model_dump() if packet.device else None,
        created_at=packet.generated_at,
        acknowledged_at=datetime.now(timezone.utc)
    )

    db.add(db_packet)
    await db.flush()

    # Broadcast emergency alert to active WebSocket listeners for this session
    broadcast_payload = {
        "event": "EmergencyPacketReceived",
        "packet_id": packet.packet_id,
        "session_id": packet.session_id,
        "user_id": packet.user_id,
        "priority": packet.priority.value,
        "location": {"lat": packet.location.latitude, "lng": packet.location.longitude},
        "transcript": packet.transcript.text if packet.transcript else None,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }
    await ws_manager.broadcast_to_session(packet.session_id, broadcast_payload)

    confirmation_code = f"ACK-{uuid.uuid4().hex[:8].upper()}"

    return EmergencyDataPacketResponse(
        packet_id=packet.packet_id,
        session_id=packet.session_id,
        user_id=packet.user_id,
        status=PacketStatus.UPLOADED,
        acknowledged_at=datetime.now(timezone.utc),
        confirmation_code=confirmation_code
    )