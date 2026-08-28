#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
engine_dir="${GEN1RECOMP_ROOT:?Set GEN1RECOMP_ROOT to a Gen1Recomp++ checkout}"
lua_bin="${LUA_BIN:-luajit}"
mount_path="$engine_dir/mods/pokemon_mount_system"

if ! command -v "$lua_bin" >/dev/null 2>&1 && [[ ! -x "$lua_bin" ]]; then
  echo "LuaJIT not found. Set LUA_BIN to a LuaJIT executable." >&2
  exit 2
fi

if [[ -e "$mount_path" || -L "$mount_path" ]]; then
  echo "Refusing to replace existing $mount_path" >&2
  exit 2
fi

mkdir -p "$engine_dir/mods"
ln -s "$project_dir" "$mount_path"
cleanup() { rm -f "$mount_path"; }
trap cleanup EXIT

cd "$engine_dir"
for generation in 1 2; do
  LUA_PATH="./?.lua;./?/init.lua;;" "$lua_bin" \
    "$mount_path/tests/engine_load.lua" "$generation"
done
