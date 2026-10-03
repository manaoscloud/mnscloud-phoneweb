#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build/web"
MANIFEST="${BUILD_DIR}/manifest.json"
INDEX="${BUILD_DIR}/index.html"
BASE_HREF="/phoneweb/"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-href) BASE_HREF="${2:-}"; shift 2 ;;
    --help|-h)
      printf 'Usage: scripts/validate-pwa.sh [--base-href /phoneweb/]\n'
      exit 0
      ;;
    *) printf '[validate-pwa] ERROR: unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

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

grep -qF "<base href=\"${BASE_HREF}\">" "$INDEX" || fail "index.html was not built with --base-href ${BASE_HREF}."
grep -q 'rel="manifest"' "$INDEX" || fail "manifest link is missing from index.html."
grep -q 'name="theme-color"' "$INDEX" || fail "theme-color meta tag is missing from index.html."
grep -q '"display": "standalone"' "$MANIFEST" || fail "manifest display must be standalone."
grep -q '"scope": "."' "$MANIFEST" || fail "manifest scope must remain relative for portable hosting."
grep -q '"start_url": "."' "$MANIFEST" || fail "manifest start_url must remain relative for portable hosting."
grep -q '"purpose": "maskable"' "$MANIFEST" || fail "manifest must include maskable icons."

ok "PWA manifest, service worker, icons, and ${BASE_HREF} base href are valid."
