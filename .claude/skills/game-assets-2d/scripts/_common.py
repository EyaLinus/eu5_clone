"""Shared helpers for game-assets-2d scripts."""
from __future__ import annotations

import re
import sys
from pathlib import Path

HEX_RE = re.compile(r"^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$")


def die(msg: str, code: int = 1):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(code)


def hex_to_rgba(value: str) -> tuple[int, int, int, int]:
    m = HEX_RE.match(value.strip())
    if not m:
        raise ValueError(f"not a hex color: {value!r}")
    h = m.group(1)
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    if len(h) == 6:
        h += "ff"
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4, 6))  # type: ignore


def rgba_to_hex(c) -> str:
    return "#%02x%02x%02x" % tuple(c[:3])


def load_profile(path: str | None) -> dict:
    if not path:
        return {}
    try:
        import yaml
    except ImportError:
        die("pyyaml missing: pip install pyyaml")
    p = Path(path)
    if not p.exists():
        die(f"profile not found: {path}")
    return yaml.safe_load(p.read_text(encoding="utf-8")) or {}


def load_palette(profile: dict) -> dict[str, tuple[int, int, int, int]]:
    """name -> rgba from profile['palette'] (+ optional faction_colors)."""
    pal = {}
    for section in ("palette", "faction_colors"):
        entries = profile.get(section) or {}
        if isinstance(entries, list):  # list of hex
            entries = {f"{section}_{i}": v for i, v in enumerate(entries)}
        for name, val in entries.items():
            try:
                pal[str(name)] = hex_to_rgba(str(val))
            except ValueError:
                print(f"warning: palette entry {name}={val!r} is not hex, skipped", file=sys.stderr)
    return pal


def resolve_color(token: str, palette: dict) -> tuple[int, int, int, int]:
    """Palette name or hex -> rgba."""
    if token in palette:
        return palette[token]
    return hex_to_rgba(token)


def nearest(c, palette_rgb: list[tuple[int, int, int]]):
    best, bd = None, 1e18
    for p in palette_rgb:
        d = (c[0] - p[0]) ** 2 + (c[1] - p[1]) ** 2 + (c[2] - p[2]) ** 2
        if d < bd:
            best, bd = p, d
    return best, bd ** 0.5
