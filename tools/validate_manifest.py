#!/usr/bin/env python3
"""Small dependency-free manifest gate used by local tests and packaging."""

from __future__ import annotations

import json
import pathlib
import sys


def fail(message: str) -> None:
    raise SystemExit(f"manifest validation failed: {message}")


def main() -> None:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    path = root / "manifest.json"
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(str(exc))

    expected = {
        "id": "pokemon_mount_system",
        "entry": "main.lua",
        "api": 2,
        "github": "burgerslayer7/PMS",
    }
    for key, value in expected.items():
        if manifest.get(key) != value:
            fail(f"{key!r} must be {value!r}")

    games = manifest.get("games")
    if games != ["gen1", "gen2"]:
        fail("games must target gen1 and gen2")
    if not (root / manifest["entry"]).is_file():
        fail("entry file is missing")
    if manifest.get("dependencies"):
        fail("PMS must not have mandatory mod dependencies")
    if "engine_internals" not in manifest.get("permissions", []):
        fail("the isolated ActorBridge permission must remain explicit")

    print("manifest ok")


if __name__ == "__main__":
    main()
