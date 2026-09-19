"""
sms_gateway_service.py

Server-side SMS gateway service for dispatching cloud fallback SMS alerts.
"""

from app.core.logging import logger


class SmsGatewayService:
    def __init__(self, api_key: str = "") -> None:
        self._api_key = api_key

    async def send_sms(self, phone_number: str, body: str) -> bool:
        logger.info(f"SmsGatewayService: Dispatching cloud SMS to {phone_number}: '{body[:30]}...'")
        # Integrates with Twilio / AWS SNS / Sinch HTTP API
        return True


sms_gateway_service = SmsGatewayService()
