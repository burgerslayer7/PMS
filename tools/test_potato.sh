#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
engine_dir="${GEN1RECOMP_ROOT:?Set GEN1RECOMP_ROOT to a Gen1Recomp++ checkout}"
potato_dir="${POTATO_VOXEL_ROOT:?Set POTATO_VOXEL_ROOT to a PotatoVoxel checkout}"
lua_bin="${LUA_BIN:-luajit}"
pms_mount="$engine_dir/mods/pokemon_mount_system"
potato_mount="$engine_dir/mods/potato_voxel"

if ! command -v "$lua_bin" >/dev/null 2>&1 && [[ ! -x "$lua_bin" ]]; then
  echo "LuaJIT not found. Set LUA_BIN to a LuaJIT executable." >&2
  exit 2
fi
for target in "$pms_mount" "$potato_mount"; do
  if [[ -e "$target" || -L "$target" ]]; then
    echo "Refusing to replace existing $target" >&2
    exit 2
  fi
done

mkdir -p "$engine_dir/mods"
ln -s "$project_dir" "$pms_mount"
ln -s "$potato_dir" "$potato_mount"
cleanup() {
  unlink "$pms_mount"
  unlink "$potato_mount"
}
trap cleanup EXIT

cd "$engine_dir"
for generation in 1 2; do
  LUA_PATH="./?.lua;./?/init.lua;;" "$lua_bin" \
    "$pms_mount/tests/engine_potato_load.lua" "$generation"
done
