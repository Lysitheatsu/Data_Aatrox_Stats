"""
telemetry.py

FastAPI router for receiving and storing client operational telemetry & system metrics.
"""

from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.session import get_db
from app.core.logging import logger

router = APIRouter(prefix="/telemetry", tags=["Operational Telemetry"])


class TelemetryPoint(BaseModel):
    metric_name: str
    value: float
    timestamp: datetime
    tags: Optional[dict] = None


class TelemetryBatchLog(BaseModel):
    user_id: str
    device_id: str
    points: List[TelemetryPoint]


@router.post("/log", status_code=status.HTTP_202_ACCEPTED)
async def log_telemetry_batch(
    payload: TelemetryBatchLog,
    db: AsyncSession = Depends(get_db)
):
    logger.info(f"Received telemetry batch from user {payload.user_id} ({len(payload.points)} points)")
    # Store or stream telemetry data points
    return {
        "status": "ACCEPTED",
        "processed_points": len(payload.points),
        "timestamp": datetime.now(timezone.utc).isoformat()
    }
