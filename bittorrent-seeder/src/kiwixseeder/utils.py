import humanfriendly


def format_size(value: int) -> str:
    """human friendly size in binary"""
    return humanfriendly.format_size(value, binary=True)


def format_duration(value: float) -> str:
    """human friendly duration"""
    return humanfriendly.format_timespan(value)
