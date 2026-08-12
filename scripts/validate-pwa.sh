#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build/web"
MANIFEST="${BUILD_DIR}/manifest.json"
INDEX="${BUILD_DIR}/index.html"

fail() {
  printf '[validate-pwa] ERROR: %s\n' "$*" >&2
  exit 1
}

ok() {
  printf '[validate-pwa] OK %s\n' "$*"
}

[[ -f "$INDEX" ]] || fail "build/web/index.html was not found. Run flutter build web first."
[[ -f "$MANIFEST" ]] || fail "build/web/manifest.json was not found. Run flutter build web first."
[[ -f "${BUILD_DIR}/flutter_service_worker.js" ]] || fail "Flutter service worker was not generated."

grep -q '<base href="/phoneweb/">' "$INDEX" || fail "index.html was not built with --base-href /phoneweb/."
grep -q 'rel="manifest"' "$INDEX" || fail "manifest link is missing from index.html."
grep -q 'name="theme-color"' "$INDEX" || fail "theme-color meta tag is missing from index.html."
grep -q '"display": "standalone"' "$MANIFEST" || fail "manifest display must be standalone."
grep -q '"scope": "."' "$MANIFEST" || fail "manifest scope must remain relative for portable hosting."
grep -q '"start_url": "."' "$MANIFEST" || fail "manifest start_url must remain relative for portable hosting."
grep -q '"purpose": "maskable"' "$MANIFEST" || fail "manifest must include maskable icons."

ok "PWA manifest, service worker, icons, and /phoneweb/ base href are valid."
