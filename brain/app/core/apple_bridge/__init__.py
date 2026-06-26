"""Abstraction over the Atoll / Apple bridge.

Each Apple area (Calendar, Reminders, Clock, Contacts, Phone, Messages, Notes,
Notifications) is wired independently. Until a real Atoll bridge transport is
connected, every area reports unavailable with a clear reason so capabilities
are never advertised as working when they are not.
"""

from .areas import APPLE_BRIDGE_AREAS, AppleBridgeArea, default_area_status

__all__ = ["APPLE_BRIDGE_AREAS", "AppleBridgeArea", "default_area_status"]
