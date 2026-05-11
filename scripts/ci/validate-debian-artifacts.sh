#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/ci/validate-debian-artifacts.sh --artifacts-dir <dir> [options]

Options:
  --architectures <csv>       Default: amd64,arm64,armhf
  --expected-version <ver>    Validate every package and changes file version
  --changes-list <path>       Write sorted .changes paths for repository publish
EOF
}

artifacts_dir=""
architectures="amd64,arm64,armhf"
expected_version=""
changes_list=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifacts-dir)
      artifacts_dir="${2:?missing value for --artifacts-dir}"
      shift 2
      ;;
    --architectures)
      architectures="${2:?missing value for --architectures}"
      shift 2
      ;;
    --expected-version)
      expected_version="${2:?missing value for --expected-version}"
      shift 2
      ;;
    --changes-list)
      changes_list="${2:?missing value for --changes-list}"
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

if [[ -z "$artifacts_dir" ]]; then
  usage >&2
  exit 2
fi

artifacts_dir="$(cd "$artifacts_dir" && pwd)"
IFS=',' read -r -a arch_list <<< "$architectures"
collected_changes=()

find_one() {
  local pattern="$1"
  mapfile -t matches < <(find "$artifacts_dir" -name "$pattern" -type f | sort)
  if [[ "${#matches[@]}" -ne 1 ]]; then
    echo "Expected exactly one $pattern under $artifacts_dir, found ${#matches[@]}." >&2
    printf '  %s\n' "${matches[@]:-}" >&2
    exit 1
  fi
  printf '%s\n' "${matches[0]}"
}

for arch in "${arch_list[@]}"; do
  changes_file="$(find_one "lofibox_*_${arch}.changes")"
  deb_file="$(find_one "lofibox_*_${arch}.deb")"
  buildinfo_file="$(find_one "lofibox_*_${arch}.buildinfo")"
  test -s "$changes_file"
  test -s "$deb_file"
  test -s "$buildinfo_file"

  actual_arch="$(dpkg-deb -f "$deb_file" Architecture)"
  if [[ "$actual_arch" != "$arch" ]]; then
    echo "Package architecture mismatch for $deb_file: expected $arch, got $actual_arch." >&2
    exit 1
  fi

  if [[ -n "$expected_version" ]]; then
    deb_version="$(dpkg-deb -f "$deb_file" Version)"
    changes_version="$(awk '/^Version:/ {print $2; exit}' "$changes_file")"
    if [[ "$deb_version" != "$expected_version" ]]; then
      echo "Package version mismatch for $deb_file: expected $expected_version, got $deb_version." >&2
      exit 1
    fi
    if [[ "$changes_version" != "$expected_version" ]]; then
      echo "Changes version mismatch for $changes_file: expected $expected_version, got $changes_version." >&2
      exit 1
    fi
  fi

  collected_changes+=("$changes_file")
done

if [[ -n "$changes_list" ]]; then
  printf '%s\n' "${collected_changes[@]}" | sort > "$changes_list"
fi

echo "Debian artifacts validated for architectures: $architectures."
