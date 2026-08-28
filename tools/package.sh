#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-$project_dir/dist}"
version="$(sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$project_dir/manifest.json" | head -n 1)"

if [[ -z "$version" ]]; then
  echo "Unable to read manifest version" >&2
  exit 2
fi
if ! git -C "$project_dir" diff --quiet --ignore-submodules -- || \
   ! git -C "$project_dir" diff --cached --quiet --ignore-submodules --; then
  echo "Refusing to package a dirty tracked worktree" >&2
  exit 2
fi

mkdir -p "$output_dir"
archive="$output_dir/pokemon-mount-system-v${version}.zip"
git -C "$project_dir" archive --format=zip --output="$archive" HEAD
python3 "$project_dir/tools/validate_package.py" "$archive"
sha256sum "$archive" > "$archive.sha256"
echo "$archive"
