#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/ci/collect-debian-artifacts.sh --arch <arch> --output-dir <dir> [options]

Options:
  --source-dir <dir>          LoFiBox-Zero checkout. Search defaults to its parent.
  --search-dir <dir>          Directory containing dpkg-buildpackage outputs.
  --expected-version <ver>    Validate the binary package version.
  --env-file <path>           Write LOFIBOX_CHANGES for later workflow steps.
EOF
}

arch=""
source_dir=""
search_dir=""
output_dir=""
expected_version=""
env_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch)
      arch="${2:?missing value for --arch}"
      shift 2
      ;;
    --source-dir)
      source_dir="${2:?missing value for --source-dir}"
      shift 2
      ;;
    --search-dir)
      search_dir="${2:?missing value for --search-dir}"
      shift 2
      ;;
    --output-dir)
      output_dir="${2:?missing value for --output-dir}"
      shift 2
      ;;
    --expected-version)
      expected_version="${2:?missing value for --expected-version}"
      shift 2
      ;;
    --env-file)
      env_file="${2:?missing value for --env-file}"
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

if [[ -z "$arch" || -z "$output_dir" ]]; then
  usage >&2
  exit 2
fi

if [[ -z "$search_dir" ]]; then
  if [[ -z "$source_dir" ]]; then
    echo "Either --search-dir or --source-dir is required." >&2
    exit 2
  fi
  source_dir="$(cd "$source_dir" && pwd)"
  search_dir="$(dirname "$source_dir")"
fi

search_dir="$(cd "$search_dir" && pwd)"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"

find_one() {
  local pattern="$1"
  mapfile -t matches < <(find "$search_dir" -maxdepth 1 -name "$pattern" -type f | sort)
  if [[ "${#matches[@]}" -ne 1 ]]; then
    echo "Expected exactly one $pattern in $search_dir, found ${#matches[@]}." >&2
    printf '  %s\n' "${matches[@]:-}" >&2
    exit 1
  fi
  printf '%s\n' "${matches[0]}"
}

changes_file="$(find_one "lofibox_*_${arch}.changes")"
deb_file="$(find_one "lofibox_*_${arch}.deb")"
buildinfo_file="$(find_one "lofibox_*_${arch}.buildinfo")"

actual_arch="$(dpkg-deb -f "$deb_file" Architecture)"
if [[ "$actual_arch" != "$arch" ]]; then
  echo "Package architecture mismatch for $deb_file: expected $arch, got $actual_arch." >&2
  exit 1
fi

if [[ -n "$expected_version" ]]; then
  actual_version="$(dpkg-deb -f "$deb_file" Version)"
  if [[ "$actual_version" != "$expected_version" ]]; then
    echo "Package version mismatch for $deb_file: expected $expected_version, got $actual_version." >&2
    exit 1
  fi
fi

cp -f "$changes_file" "$deb_file" "$buildinfo_file" "$output_dir/"

copied_changes="$output_dir/$(basename "$changes_file")"
if [[ -n "$env_file" ]]; then
  printf 'LOFIBOX_CHANGES=%s\n' "$copied_changes" >> "$env_file"
fi

echo "Collected $arch artifacts into $output_dir."
