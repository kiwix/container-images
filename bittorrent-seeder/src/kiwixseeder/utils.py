from dataclasses import dataclass

import humanfriendly


def format_size(value: int) -> str:
    """human friendly size in binary"""
    return humanfriendly.format_size(value, binary=True)


def format_duration(value: float) -> str:
    """human friendly duration"""
    return humanfriendly.format_timespan(value)

nd = 0

@dataclass(kw_only=True)
class SizeRange:
    """ Size Range calculator ensuring min and max are usable (both optional)"""
    minimum: int = nd
    maximum: int = nd

    def is_valid(self) -> bool:
        """ whether range is usable or not"""
        if self.minimum == self.maximum == nd:
            return True
        # maximum is either not set or positive
        if self.maximum != nd:
            return max(self.maximum, 0) >= max(self.minimum, 0)
        return True

    def is_above_min(self, value: int) -> bool:
        """ whether value is greater-or-equal than our minimum"""
        return value >= max(self.minimum, 0)

    def is_below_max(self, value: int) -> bool:
        """ whether value is lower-or-equal than our maximum"""
        if self.maximum == nd:
            return True
        return value <= self.maximum

    def match(self, value: int) -> bool:
        """ whether value is within the bounds of the range"""
        # not valid, not matching.
        if not self.is_valid():
            return False
        # no bound, always OK
        if self.minimum == self.maximum == nd:
            return True
        return self.is_above_min(value) and self.is_below_max(value)

    def __str__(self) -> str:
        if not self.is_valid():
            return f"Invalid range: min={self.minimum}, max={self.maximum}"
        if self.minimum == self.maximum == nd:
            return "all"
        if self.minimum == self.maximum:
            return f"exactly {format_size(self.maximum)}"
        if self.minimum == nd:
            return f"below {format_size(self.maximum)}"
        if self.maximum == nd:
            return f"above {format_size(self.minimum)}"
        return f"between {format_size(self.minimum)} and {format_size(self.maximum)}"
