#!/usr/bin/env python3
"""Generate deterministic fallback sheets for declared mount species."""

from __future__ import annotations

import pathlib
import re
import sys
import math

from PIL import Image


def mount_dexes(config: pathlib.Path) -> list[int]:
    text = config.read_text(encoding="utf-8")
    values = sorted({int(value) for value in re.findall(r"\bdex\s*=\s*(\d+)", text)})
    if not values:
        raise SystemExit("no mount dex ids found")
    return values


def mount_heights(config: pathlib.Path) -> dict[int, float]:
    text = config.read_text(encoding="utf-8")
    rows = re.findall(
        r"\bdex\s*=\s*(\d+).*?\bheightM\s*=\s*([0-9]+(?:\.[0-9]+)?)"
        r".*?\bmodes\s*=",
        text,
        flags=re.DOTALL,
    )
    values = {int(dex): float(height) for dex, height in rows}
    if len(values) != len(mount_dexes(config)):
        raise SystemExit("every mount must declare one Pokédex heightM")
    return values


def scale_constants(path: pathlib.Path) -> dict[str, float]:
    """Read the runtime's sizing constants so build and renderer cannot drift."""
    text = path.read_text(encoding="utf-8")
    values: dict[str, float] = {}
    for name in (
        "BASE_HEIGHT_M",
        "BASE_FRAME_PX",
        "MIN_FRAME_PX",
        "MAX_FRAME_PX",
    ):
        match = re.search(
            rf"\blocal\s+{name}\s*=\s*([0-9]+(?:\.[0-9]+)?)", text
        )
        if not match:
            raise SystemExit(f"missing runtime mount-scale constant {name}")
        values[name] = float(match.group(1))
    return values


def frame_size(height_m: float, constants: dict[str, float]) -> int:
    pixels = math.floor(
        constants["BASE_FRAME_PX"]
        * math.sqrt(max(0.1, height_m) / constants["BASE_HEIGHT_M"])
        + 0.5
    )
    return max(
        int(constants["MIN_FRAME_PX"]),
        min(int(constants["MAX_FRAME_PX"]), pixels),
    )


def main() -> None:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    source = root / "assets" / "fallback" / "pokepc" / "sprites"
    output = root / "assets" / "fallback" / "pokepc" / "scaled"
    config = root / "config" / "mounts.lua"
    dexes = mount_dexes(config)
    heights = mount_heights(config)
    constants = scale_constants(root / "src" / "rendering" / "MountScale.lua")

    count = 0
    for scale in (2, 3, 4):
        destination = output / f"{scale}x"
        destination.mkdir(parents=True, exist_ok=True)
        for dex in dexes:
            name = f"follower_{dex:03d}.png"
            with Image.open(source / name) as image:
                generated = image.convert("RGBA").resize(
                    (image.width * scale, image.height * scale),
                    Image.Resampling.NEAREST,
                )
                generated.save(destination / name, format="PNG", optimize=True)
            count += 1

    sized = root / "assets" / "fallback" / "pokepc" / "sized"
    sized.mkdir(parents=True, exist_ok=True)
    for dex in dexes:
        name = f"follower_{dex:03d}.png"
        size = frame_size(heights[dex], constants)
        with Image.open(source / name) as image:
            generated = image.convert("RGBA").resize(
                (size, size * 6), Image.Resampling.NEAREST
            )
            generated.save(sized / name, format="PNG", optimize=True)
        count += 1
    print(f"generated {count} legacy and Pokédex-sized mount sheets")


if __name__ == "__main__":
    main()
