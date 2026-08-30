#!/usr/bin/env python3
"""Enforce the clean-room product and integration boundaries."""

from __future__ import annotations

import json
import pathlib
import re
import sys


def fail(message: str) -> None:
    raise SystemExit(f"scope validation failed: {message}")


def load_policy(root: pathlib.Path) -> dict[str, object]:
    path = root / "config" / "integration_scope.json"
    try:
        policy = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(str(exc))
    if not isinstance(policy, dict):
        fail("integration scope must be a JSON object")
    return policy


def validate_policy(policy: dict[str, object]) -> None:
    if policy.get("schema") != 1:
        fail("unsupported integration scope schema")

    active = policy.get("active_integration_order")
    if not isinstance(active, list) or not active:
        fail("active integration order is missing")
    if "stadium" in active:
        fail("Stadium must remain outside active integration work")
    if "open_sky" in active:
        fail("Open Sky is abandoned and cannot be an active integration")

    maintenance = policy.get("maintenance_only")
    stadium = maintenance.get("stadium") if isinstance(maintenance, dict) else None
    if not isinstance(stadium, dict):
        fail("the frozen Stadium policy is missing")
    if stadium.get("contract") != "tag_untag":
        fail("Stadium is limited to the existing tag/untag contract")
    if stadium.get("feature_development") is not False:
        fail("Stadium feature development must remain disabled")
    allowed = stadium.get("allowed_work")
    if set(allowed if isinstance(allowed, list) else []) != {
        "cleanup",
        "fallback",
        "regression_fixes",
    }:
        fail("unexpected Stadium maintenance allowance")

    excluded = policy.get("excluded")
    gen2_3d = excluded.get("gen2_3d_sprites") if isinstance(excluded, dict) else None
    if not isinstance(gen2_3d, dict) or gen2_3d.get("status") != "unsupported":
        fail("Gen2-3D-Sprites must remain explicitly unsupported")
    if gen2_3d.get("runtime_adapter") is not False:
        fail("Gen2-3D-Sprites runtime adapters are forbidden")
    if gen2_3d.get("provider_tagging") is not False:
        fail("Gen2-3D-Sprites provider tagging is forbidden")
    open_sky = excluded.get("open_sky") if isinstance(excluded, dict) else None
    if not isinstance(open_sky, dict) or open_sky.get("status") != "abandoned":
        fail("Open Sky must remain explicitly abandoned")
    if open_sky.get("runtime_modules") is not False:
        fail("Open Sky runtime modules are forbidden")
    if open_sky.get("assets") is not False:
        fail("Open Sky assets are forbidden")


def validate_runtime_tree(root: pathlib.Path) -> None:
    allowed_stadium_source = pathlib.PurePosixPath(
        "src/providers/StadiumProvider.lua"
    )
    forbidden_path = re.compile(r"open[ _-]?sky|dramatic[ _-]?sky[ _-]?ride", re.I)
    forbidden_source = re.compile(
        r"open[ _-]?sky|dramatic[ _-]?sky[ _-]?ride", re.I
    )

    runtime_paths: list[pathlib.Path] = [root / "main.lua", root / "manifest.json"]
    for directory in (root / "src", root / "assets"):
        if directory.is_dir():
            runtime_paths.extend(path for path in directory.rglob("*") if path.is_file())

    for path in runtime_paths:
        relative = pathlib.PurePosixPath(path.relative_to(root).as_posix())
        if forbidden_path.search(relative.as_posix()):
            fail(f"forbidden runtime path: {relative}")
        if "stadium" in relative.as_posix().lower() and relative != allowed_stadium_source:
            fail(f"new Stadium runtime module is outside the frozen scope: {relative}")
        if path.suffix.lower() not in {".lua", ".json"}:
            continue
        try:
            source = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        if forbidden_source.search(source):
            fail(f"forbidden Sky Ride/Open Sky runtime reference in {relative}")


def main() -> None:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    policy = load_policy(root)
    validate_policy(policy)
    validate_runtime_tree(root)
    print("integration scope ok")


if __name__ == "__main__":
    main()
