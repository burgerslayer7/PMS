#!/usr/bin/env python3
"""Generate nearest-neighbour 2x/3x/4x sheets for declared mount species."""

from __future__ import annotations

import pathlib
import re
import sys

from PIL import Image


def mount_dexes(config: pathlib.Path) -> list[int]:
    text = config.read_text(encoding="utf-8")
    values = sorted({int(value) for value in re.findall(r"\bdex\s*=\s*(\d+)", text)})
    if not values:
        raise SystemExit("no mount dex ids found")
    return values


def main() -> None:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    source = root / "assets" / "fallback" / "pokepc" / "sprites"
    output = root / "assets" / "fallback" / "pokepc" / "scaled"
    dexes = mount_dexes(root / "config" / "mounts.lua")

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
    print(f"generated {count} scaled mount sheets")


if __name__ == "__main__":
    main()
