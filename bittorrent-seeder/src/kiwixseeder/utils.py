import os
from pathlib import Path

import humanfriendly

from kiwixseeder.context import NAME, Context


def get_config_path(fname: str) -> Path:
    """Path to save/read a config file from/to"""
    xdg_config_home = os.getenv("XDG_CONFIG_HOME")
    # favor this env on any platform
    if xdg_config_home:
        return Path(xdg_config_home) / fname
    if Context.is_mac:
        return Path.home() / "Library" / "Preferences" / NAME / fname
    if Context.is_win:
        return Path(os.getenv("APPDATA", "C:")) / NAME / fname
    return Path.home() / ".config" / NAME / fname


def get_cache_path(fname: str) -> Path:
    """Path to save/read cache from/to"""
    xdg_cache_home = os.getenv("XDG_CACHE_HOME")
    # favor this env on any platform
    if xdg_cache_home:
        return Path(xdg_cache_home) / fname
    if Context.is_mac:
        return Path.home() / "Library" / "Caches" / NAME / fname
    if Context.is_win:
        return Path(os.getenv("APPDATA", "C:")) / NAME / fname
    return Path.home() / ".config" / NAME / fname


def format_size(value: int) -> str:
    """human friendly size in binary"""
    return humanfriendly.format_size(value, binary=True)


def format_duration(value: float) -> str:
    """human friendly duration"""
    return humanfriendly.format_timespan(value)
