#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

find_runtime_kit() {
  local candidate
  for candidate in \
    "${MNSCLOUD_RUNTIME_KIT_DIR:-}" \
    "${ROOT_DIR}/../mnscloud-runtime-kit" \
    "/opt/mnscloud/runtime-kit" \
    "/opt/mnscloud/repos/mnscloud-runtime-kit"; do
    [[ -n "$candidate" && -r "${candidate}/lib/release.sh" ]] || continue
    printf '%s\n' "$candidate"
    return 0
  done
  return 1
}

cd "$ROOT_DIR"
RUNTIME_KIT_DIR="$(find_runtime_kit)" || {
  printf '[mnscloud-phoneweb] ERROR: mnscloud-runtime-kit lib/release.sh not found\n' >&2
  exit 1
}

# shellcheck source=/opt/mnscloud/runtime-kit/lib/release.sh
source "${RUNTIME_KIT_DIR}/lib/release.sh"

sync_app_build_info() {
  local version="$1"
  deno eval '
const version = Deno.args[0];
const file = "lib/src/version/app_build_info.dart";
const text = await Deno.readTextFile(file);
const updated = text.replace(/^  version:\s*.+,$/m, `  version: "${version}",`);
if (updated === text) {
  throw new Error(`${file} version field was not found`);
}
await Deno.writeTextFile(file, updated);
' "$version"
}

if [[ " $* " == *" --version "* ]]; then
  for ((index = 1; index <= $#; index += 1)); do
    if [[ "${!index}" == "--version" ]]; then
      next_index=$((index + 1))
      sync_app_build_info "${!next_index}"
      break
    fi
  done
fi

mrtk_release_prepare \
  --product mnscloud-phoneweb \
  --repository manaoscloud/mnscloud-phoneweb \
  --minimum-version 0.1.0 \
  --sync-pubspec \
  --add-path lib/src/version/app_build_info.dart \
  --validate "grep -q '^version:' pubspec.yaml" \
  --validate "deno eval 'const pub=(await Deno.readTextFile(\"pubspec.yaml\")).match(/^version:\\\\s*(.+)$/m)?.[1]?.trim(); const line=(await Deno.readTextFile(\"lib/src/version/app_build_info.dart\")).split(\"\\\\n\").find((item)=>item.trim().startsWith(\"version:\")); const info=line?.match(/[0-9]+[.][0-9]+[.][0-9]+(?:[-+][0-9A-Za-z.-]+)?/)?.[0]; if (pub !== info) throw new Error(\"app build version mismatch: pubspec=\" + pub + \" appBuildInfo=\" + info);'" \
  "$@"
