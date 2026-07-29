"""Small, explicit lunar-to-solar conversion helpers for CHARLS dates."""

from __future__ import annotations

from datetime import date
from typing import Optional

from lunardate import LunarDate


def convert_lunar_to_solar(year: int, month: int, day: int) -> Optional[date]:
    """Convert a non-leap Chinese lunar date; return None for invalid input."""
    try:
        return LunarDate(int(year), int(month), int(day)).to_solar_date()
    except (TypeError, ValueError, OverflowError):
        return None

