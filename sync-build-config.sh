#!/usr/bin/env bash
#
# sync-build-config.sh — distribute canonical .NET build/lint config to the
# AKA-BK repos that share it. The canonical files live in ./config; each target
# repo below receives the listed files.
#
#   ./sync-build-config.sh            copy canonical files into each target repo
#   ./sync-build-config.sh --check    report drift, exit non-zero if any (CI-friendly)
#
# Repos stay fully independent git repos — this just keeps the shared subset in
# lockstep. Edit the canonical files in ./config, then run this to propagate.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HERE/config"
ROOT="$(cd "$HERE/.." && pwd)"   # the aka-bk workspace root (parent of this repo)

# repo-dir | comma-separated files (relative to repo root and to ./config)
TARGETS=(
  "AKABK-Brain|Directory.Build.props,.editorconfig,GitVersion.yml"
  "AKABK-MCP|Directory.Build.props,.editorconfig,GitVersion.yml"
  # CLI opt-in: its Directory.Build.props is an app profile, not the shared
  # library profile — only the shared lint config is safe to sync.
  # "AKABK-CLI|.editorconfig"
)

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

fail=0
for entry in "${TARGETS[@]}"; do
  repo="${entry%%|*}"
  files="${entry#*|}"
  IFS=',' read -ra flist <<< "$files"
  for f in "${flist[@]}"; do
    src="$CONFIG_DIR/$f"
    dst="$ROOT/$repo/$f"
    if [ ! -f "$src" ]; then
      echo "  MISSING canonical: config/$f"
      fail=1
      continue
    fi
    if [ ! -d "$ROOT/$repo" ]; then
      echo "  SKIP (repo not found): $repo"
      continue
    fi
    if [ "$CHECK" = "1" ]; then
      if diff -q "$src" "$dst" >/dev/null 2>&1; then
        echo "  ok    $repo/$f"
      else
        echo "  DRIFT $repo/$f"
        fail=1
      fi
    else
      cp "$src" "$dst"
      echo "  synced $repo/$f"
    fi
  done
done

if [ "$CHECK" = "1" ] && [ "$fail" -ne 0 ]; then
  echo
  echo "Drift detected. Run ./sync-build-config.sh to bring targets back in line,"
  echo "or update the canonical file in ./config if the change belongs there."
  exit 1
fi

exit "$fail"
