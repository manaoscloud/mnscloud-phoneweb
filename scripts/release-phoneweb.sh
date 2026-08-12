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

sync_app_build_info_command='
const pubspec = await Deno.readTextFile("pubspec.yaml");
const version = pubspec.match(/^version:\s*(.+)$/m)?.[1]?.trim();
if (!version) {
  throw new Error("pubspec.yaml version field was not found");
}
const file = "lib/src/version/app_build_info.dart";
const text = await Deno.readTextFile(file);
const versionLine = /^(\s*)version:\s*.+,$/m;
if (!versionLine.test(text)) {
  throw new Error(`${file} version field was not found`);
}
const updated = text.replace(versionLine, `$1version: "${version}",`);
await Deno.writeTextFile(file, updated);
'

mrtk_release_prepare \
  --product mnscloud-phoneweb \
  --repository manaoscloud/mnscloud-phoneweb \
  --minimum-version 0.1.0 \
  --sync-pubspec \
  --add-path lib/src/version/app_build_info.dart \
  --validate "grep -q '^version:' pubspec.yaml" \
  --validate "deno eval '${sync_app_build_info_command}'" \
  --validate "deno eval 'const pub=(await Deno.readTextFile(\"pubspec.yaml\")).match(/^version:\\\\s*(.+)$/m)?.[1]?.trim(); const line=(await Deno.readTextFile(\"lib/src/version/app_build_info.dart\")).split(\"\\\\n\").find((item)=>item.trim().startsWith(\"version:\")); const info=line?.match(/[0-9]+[.][0-9]+[.][0-9]+(?:[-+][0-9A-Za-z.-]+)?/)?.[0]; if (pub !== info) throw new Error(\"app build version mismatch: pubspec=\" + pub + \" appBuildInfo=\" + info);'" \
  "$@"
