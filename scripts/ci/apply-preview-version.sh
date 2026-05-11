#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/ci/apply-preview-version.sh --source-dir <LoFiBox-Zero> --preview-version <version> [options]

Options:
  --suite <suite>       APT suite being published. Default: trixie
EOF
}

source_dir=""
preview_version=""
suite="trixie"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-dir)
      source_dir="${2:?missing value for --source-dir}"
      shift 2
      ;;
    --preview-version)
      preview_version="${2:?missing value for --preview-version}"
      shift 2
      ;;
    --suite)
      suite="${2:?missing value for --suite}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$source_dir" || -z "$preview_version" ]]; then
  usage >&2
  exit 2
fi

source_dir="$(cd "$source_dir" && pwd)"
export DEBEMAIL="${DEBEMAIL:-maintainers@example.invalid}"
export DEBFULLNAME="${DEBFULLNAME:-LoFiBox contributors}"

(
  cd "$source_dir"
  dch -b \
    --newversion "$preview_version" \
    --distribution unstable \
    "Preview APT repository build for $suite."
  actual_version="$(dpkg-parsechangelog -S Version)"
  if [[ "$actual_version" != "$preview_version" ]]; then
    echo "Preview version application failed: expected $preview_version, got $actual_version." >&2
    exit 1
  fi
  dpkg-parsechangelog -S Version
)
