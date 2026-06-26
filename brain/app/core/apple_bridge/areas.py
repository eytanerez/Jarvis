from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict


@dataclass(frozen=True)
class AppleBridgeArea:
    key: str
    label: str
    # Whether this area supports write/mutate operations at all (vs read-only).
    supports_write: bool
    # Friendly reason shown when the area is not connected.
    offline_reason: str


# Independent areas. Calendar/Reminders/Clock/Contacts/Phone/Messages/Notes
# match the Atoll bridge surface; notifications is added for notification skills.
APPLE_BRIDGE_AREAS: Dict[str, AppleBridgeArea] = {
    "calendar": AppleBridgeArea("calendar", "Calendar", True, "Atoll Calendar bridge is not connected yet"),
    "reminders": AppleBridgeArea("reminders", "Reminders", True, "Atoll Reminders bridge is not connected yet"),
    "clock": AppleBridgeArea("clock", "Clock", True, "Atoll Clock beta is not connected yet"),
    "contacts": AppleBridgeArea("contacts", "Contacts", False, "Atoll Contacts bridge is not connected yet"),
    "phone": AppleBridgeArea("phone", "Phone / FaceTime", True, "Atoll Phone/FaceTime bridge is not connected yet"),
    "messages": AppleBridgeArea("messages", "Messages", True, "Atoll Messages send bridge is not connected yet"),
    "notes": AppleBridgeArea("notes", "Notes", True, "Atoll Notes bridge is not connected yet"),
    "notifications": AppleBridgeArea("notifications", "Notifications", True, "Atoll Notifications bridge is not connected yet"),
}


def default_area_status(area: AppleBridgeArea) -> Dict[str, Any]:
    return {
        "available": False,
        "read": False,
        "write": False,
        "label": area.label,
        "reason": area.offline_reason,
    }
