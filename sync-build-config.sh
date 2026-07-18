#!/usr/bin/env bash
#
# sync-build-config.sh — distribute canonical .NET build/lint config to the
# AKA-BK repos that share it. The canonical files live in ./config; the set of
# target repos and the files each receives are declared in ./targets.tsv (the
# single source of truth — no hardcoded list here).
#
#   ./sync-build-config.sh              copy canonical files into each target repo
#   ./sync-build-config.sh --check      report drift, exit non-zero if any (CI-friendly)
#   ./sync-build-config.sh --from REPO  reverse-promote: copy REPO's edited file(s)
#                                       back into ./config (inverse of the push)
#
# Repos stay fully independent git repos — this just keeps the shared subset in
# lockstep. Edit the canonical files in ./config, then run this to propagate.
# If an ad-hoc edit was made directly in a consumer repo, use --from to promote
# it to canonical instead of letting the next sync clobber it.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HERE/config"
ROOT="$(cd "$HERE/.." && pwd)"   # the aka-bk workspace root (parent of this repo)
MANIFEST="$HERE/targets.tsv"

usage() {
  cat <<'EOF'
Usage:
  ./sync-build-config.sh              copy canonical files into each target repo
  ./sync-build-config.sh --check      report drift, exit non-zero if any (CI-friendly)
  ./sync-build-config.sh --from REPO  reverse-promote: copy REPO's edited file(s)
                                      back into ./config (inverse of the push)

Targets are declared in ./targets.tsv (TAB-separated: repo-dir<TAB>files).
EOF
}

# Load the target list from the manifest into the TARGETS array, using the same
# "repo|comma-separated-files" internal shape the rest of the script expects.
# Blank lines and '#' comments are skipped; the TAB separator is normalized to '|'.
TARGETS=()
if [ ! -f "$MANIFEST" ]; then
  echo "  MISSING manifest: targets.tsv (expected at $MANIFEST)" >&2
  exit 1
fi
while IFS=$'\t' read -r repo files; do
  # strip leading/trailing whitespace on the repo field
  repo="${repo#"${repo%%[![:space:]]*}"}"
  repo="${repo%"${repo##*[![:space:]]}"}"
  [ -z "$repo" ] && continue          # blank line
  [ "${repo#\#}" != "$repo" ] && continue   # comment line
  if [ -z "${files:-}" ]; then
    echo "  MALFORMED manifest line (no files for '$repo'); expected TAB separator" >&2
    exit 1
  fi
  TARGETS+=("$repo|$files")
done < "$MANIFEST"

CHECK=0
FROM=""

case "${1:-}" in
  --check)
    CHECK=1
    ;;
  --from)
    FROM="${2:-}"
    if [ -z "$FROM" ]; then
      echo "  --from requires a repo name, e.g. ./sync-build-config.sh --from AKABK-MCP" >&2
      exit 2
    fi
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    echo "  unknown argument: $1" >&2
    usage >&2
    exit 2
    ;;
esac

# ---------------------------------------------------------------------------
# --from REPO: reverse-promote a consumer's file(s) back into ./config.
# This is the inverse of the normal push — it lets a local ad-hoc edit in a
# consumer repo become canonical instead of being silently overwritten by the
# next sync. Only files that REPO is declared to receive (per the manifest) are
# eligible, so we never promote a file the repo isn't supposed to own.
# ---------------------------------------------------------------------------
if [ -n "$FROM" ]; then
  match=""
  for entry in "${TARGETS[@]}"; do
    if [ "${entry%%|*}" = "$FROM" ]; then
      match="$entry"
      break
    fi
  done
  if [ -z "$match" ]; then
    echo "  '$FROM' is not a known target in targets.tsv." >&2
    echo "  Known targets:" >&2
    for entry in "${TARGETS[@]}"; do echo "    - ${entry%%|*}" >&2; done
    exit 2
  fi
  if [ ! -d "$ROOT/$FROM" ]; then
    echo "  repo not found: $ROOT/$FROM" >&2
    exit 1
  fi

  echo "Reverse-promoting from $FROM into canonical config/ ..."
  fail=0
  IFS=',' read -ra flist <<< "${match#*|}"
  for f in "${flist[@]}"; do
    src="$ROOT/$FROM/$f"    # consumer's (possibly edited) copy — the source now
    dst="$CONFIG_DIR/$f"    # canonical copy — the destination now
    if [ ! -f "$src" ]; then
      echo "  MISSING in $FROM: $f"
      fail=1
      continue
    fi
    if diff -q "$src" "$dst" >/dev/null 2>&1; then
      echo "  ok (already canonical) $f"
    else
      cp "$src" "$dst"
      echo "  promoted $f  <-  $FROM/$f"
    fi
  done
  if [ "$fail" -eq 0 ]; then
    echo
    echo "Done. Review the change in config/, then run ./sync-build-config.sh to"
    echo "propagate it to the other consumers, and commit here and in each repo."
  fi
  exit "$fail"
fi

# ---------------------------------------------------------------------------
# Default push  /  --check drift report (behavior unchanged).
# ---------------------------------------------------------------------------
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
