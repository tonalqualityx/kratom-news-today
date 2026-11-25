#!/usr/bin/env bash
# Private preview build: renders unpublished Industry Perspective drafts, no
# tracking, noindex everywhere. Usage: scripts/build-preview.sh [ABS_OUTPUT_DIR]
# Default output: <repo>/_preview. Never modifies tracked files.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$REPO/_preview}"
case "$OUT" in /*) ;; *) echo "Output dir must be an absolute path: $OUT" >&2; exit 2 ;; esac
case "$OUT" in "$REPO"|"$REPO/"|/|"$HOME") echo "Refusing unsafe output dir: $OUT" >&2; exit 2 ;; esac

mkdir -p "$OUT"
# Clear previous preview output (only inside OUT, never a glob in the cwd).
find "$OUT" -mindepth 1 -delete

cd "$REPO"
KNT_PREVIEW=1 KNT_OUT="$OUT" npx @11ty/eleventy

printf 'User-agent: *\nDisallow: /\n' > "$OUT/robots.txt"
printf '/*\n  X-Robots-Tag: noindex, nofollow\n' > "$OUT/_headers"
echo "Preview built in $OUT"
