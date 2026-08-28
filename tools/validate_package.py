#!/usr/bin/env python3
"""Validate the launcher ZIP root, manifest and bundled fallback coverage."""

from __future__ import annotations

import json
import pathlib
import sys
import zipfile


def fail(message: str) -> None:
    raise SystemExit(f"package validation failed: {message}")


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: validate_package.py <zip>")
    path = pathlib.Path(sys.argv[1]).resolve()
    if not path.is_file():
        fail(f"missing archive: {path}")
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if "manifest.json" not in names or "main.lua" not in names:
            fail("manifest.json and main.lua must be at archive root")
        if any(name.startswith((".git/", "dist/")) for name in names):
            fail("archive contains development-only directories")
        manifest = json.loads(archive.read("manifest.json"))
        if manifest.get("id") != "pokemon_mount_system":
            fail("unexpected manifest id")
        sprites = {
            name
            for name in names
            if name.startswith("assets/fallback/pokepc/sprites/follower_")
            and name.endswith(".png")
        }
        expected = {
            f"assets/fallback/pokepc/sprites/follower_{dex_number:03d}.png"
            for dex_number in range(1, 252)
        }
        if sprites != expected:
            fail(f"fallback sprite coverage mismatch ({len(sprites)}/251)")
    print(f"package ok: {path.name}, {len(names)} entries, 251 fallback sheets")


if __name__ == "__main__":
    main()
