#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lua_bin="${LUA_BIN:-luajit}"

if ! command -v "$lua_bin" >/dev/null 2>&1 && [[ ! -x "$lua_bin" ]]; then
  echo "LuaJIT not found. Set LUA_BIN to a Lua 5.1/LuaJIT executable." >&2
  exit 2
fi

"$lua_bin" "$project_dir/tests/run.lua" "$project_dir"
python3 "$project_dir/tools/validate_manifest.py" "$project_dir"
python3 "$project_dir/tools/validate_assets.py" "$project_dir"
