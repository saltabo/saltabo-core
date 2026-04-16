#!/usr/bin/env bash
# Generate appcast.xml for Saltabo using Sparkle's generate_appcast (Sparkle 2.x).
#
# Prerequisites:
#   1) Download a Sparkle release from https://github.com/sparkle-project/Sparkle/releases
#      and unpack it, or build Sparkle from source. The tool lives at:
#        Sparkle-*/bin/generate_appcast
#   2) Create an EdDSA key pair for signing updates:
#        Sparkle-*/bin/generate_keys
#      Then either:
#        - pass the private key file with --ed-key-file (see Sparkle docs), or
#        - export SPARKLE_EDDSA_PRIVATE_KEY (if your Sparkle build supports it).
#
# Usage:
#   export GITHUB_OWNER=yourname
#   export GITHUB_REPO=Saltabo
#   export RELEASE_TAG=v1.0.1
#   ./scripts/generate-appcast.sh path/to/Saltabo.zip
#
# Output:
#   Writes appcast.xml in the current working directory (override with -o).
#
set -euo pipefail

usage() {
  sed -n '1,30p' "$0" >&2
  exit 1
}

OUT="appcast.xml"
ZIP_PATH=""
SPARKLE_BIN="${SPARKLE_BIN:-generate_appcast}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      OUT="${2:?}"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      if [[ -n "${ZIP_PATH}" ]]; then
        echo "Unexpected argument: $1" >&2
        usage
      fi
      ZIP_PATH="$1"
      shift
      ;;
  esac
done

[[ -n "${ZIP_PATH}" ]] || usage
[[ -f "${ZIP_PATH}" ]] || { echo "Not a file: ${ZIP_PATH}" >&2; exit 1; }

GITHUB_OWNER="${GITHUB_OWNER:?Set GITHUB_OWNER (GitHub username or org)}"
GITHUB_REPO="${GITHUB_REPO:?Set GITHUB_REPO}"
RELEASE_TAG="${RELEASE_TAG:?Set RELEASE_TAG (e.g. v1.0.1)}"

PREFIX="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/download/${RELEASE_TAG}/"
STAGE=$(mktemp -d)
trap 'rm -rf "${STAGE}"' EXIT

cp "${ZIP_PATH}" "${STAGE}/"

extra_args=()
if [[ -n "${SPARKLE_EDDSA_KEY_FILE:-}" ]]; then
  extra_args+=(--ed-key-file "${SPARKLE_EDDSA_KEY_FILE}")
fi

"${SPARKLE_BIN}" "${extra_args[@]}" "${STAGE}" \
  --download-url-prefix "${PREFIX}" \
  -o "${OUT}"

echo "Wrote ${OUT}"
echo "Enclosure URLs use prefix: ${PREFIX}"
echo "Host this file on GitHub Pages and set SUFeedURL to:"
echo "  https://${GITHUB_OWNER}.github.io/${GITHUB_REPO}/appcast.xml"
