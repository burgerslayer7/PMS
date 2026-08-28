#!/usr/bin/env python3
"""Fail the build if PokéPC fallback coverage or generated sheets drift."""

from __future__ import annotations

import hashlib
import json
import pathlib
import re
import sys

from PIL import Image, UnidentifiedImageError


EXPECTED_MANIFEST_HASH = "596d00a45517aaaa82441b3837d2354ce8ef08140785f8bb5b235ef08ff4363e"


def fail(message: str) -> None:
    raise SystemExit(f"asset validation failed: {message}")


def mount_dexes(path: pathlib.Path) -> list[int]:
    text = path.read_text(encoding="utf-8")
    return sorted({int(value) for value in re.findall(r"\bdex\s*=\s*(\d+)", text)})


def pixel_data(path: pathlib.Path) -> bytes:
    with Image.open(path) as image:
        return image.convert("RGBA").tobytes()


def main() -> None:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    base = root / "assets" / "fallback" / "pokepc"
    sprite_dir = base / "sprites"
    receipt = json.loads((base / "SOURCE.json").read_text(encoding="utf-8"))

    expected_names = [f"follower_{dex:03d}.png" for dex in range(1, 252)]
    actual_names = sorted(path.name for path in sprite_dir.glob("follower_*.png"))
    if actual_names != expected_names:
        missing = sorted(set(expected_names) - set(actual_names))
        extra = sorted(set(actual_names) - set(expected_names))
        fail(f"numbered coverage mismatch; missing={missing}, extra={extra}")

    manifest_lines: list[str] = []
    for dex, name in enumerate(expected_names, 1):
        path = sprite_dir / name
        try:
            with Image.open(path) as image:
                image.verify()
            with Image.open(path) as image:
                if image.format != "PNG" or image.size != (16, 96):
                    fail(f"{name} must be a 16x96 PNG, got {image.format} {image.size}")
                if image.height % 6 or image.height // 6 != 16:
                    fail(f"{name} does not contain six 16px frames")
                image.convert("RGBA").load()
        except (OSError, UnidentifiedImageError) as exc:
            fail(f"{name} is not usable: {exc}")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        manifest_lines.append(f"{digest}  {name}\n")

    aggregate = hashlib.sha256("".join(manifest_lines).encode("utf-8")).hexdigest()
    expected_hash = receipt["files"]["sha256_manifest"]
    if aggregate != expected_hash or aggregate != EXPECTED_MANIFEST_HASH:
        fail(f"source aggregate checksum changed: {aggregate}")

    dexes = mount_dexes(root / "config" / "mounts.lua")
    if len(dexes) != 40:
        fail(f"expected 40 unique mount species, got {len(dexes)}")
    for scale in (2, 3, 4):
        for dex in dexes:
            name = f"follower_{dex:03d}.png"
            original = sprite_dir / name
            generated = base / "scaled" / f"{scale}x" / name
            if not generated.is_file():
                fail(f"missing generated sheet {generated.relative_to(root)}")
            with Image.open(generated) as image:
                if image.size != (16 * scale, 96 * scale):
                    fail(f"wrong scaled dimensions for {name} at {scale}x")
                expected = Image.open(original).convert("RGBA").resize(
                    image.size, Image.Resampling.NEAREST
                )
                if image.convert("RGBA").tobytes() != expected.tobytes():
                    fail(f"scaled pixels differ from nearest-neighbour source: {name} {scale}x")

    print(f"assets ok: 251 source sheets, {len(dexes) * 3} scaled mount sheets")


if __name__ == "__main__":
    main()
