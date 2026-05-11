#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/ci/resolve-preview-version.sh --source-dir <LoFiBox-Zero> [options]

Options:
  --expected-upstream-version <X.Y.Z>
  --preview-suffix <suffix>       Default: auto
  --suite <suite>                 Default: trixie
  --github-output <path>          Write GitHub Actions outputs
EOF
}

source_dir=""
expected_upstream_version=""
preview_suffix="auto"
suite="trixie"
github_output=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-dir)
      source_dir="${2:?missing value for --source-dir}"
      shift 2
      ;;
    --expected-upstream-version)
      expected_upstream_version="${2:-}"
      shift 2
      ;;
    --preview-suffix)
      preview_suffix="${2:?missing value for --preview-suffix}"
      shift 2
      ;;
    --suite)
      suite="${2:?missing value for --suite}"
      shift 2
      ;;
    --github-output)
      github_output="${2:?missing value for --github-output}"
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

if [[ -z "$source_dir" ]]; then
  echo "--source-dir is required." >&2
  exit 2
fi

source_dir="$(cd "$source_dir" && pwd)"

project_version="$(
  sed -nE 's/^project\(LoFiBoxZero VERSION ([0-9]+\.[0-9]+\.[0-9]+) LANGUAGES C CXX\)$/\1/p' "$source_dir/CMakeLists.txt"
)"
if [[ -z "$project_version" ]]; then
  echo "Could not parse project version from $source_dir/CMakeLists.txt." >&2
  exit 1
fi

debian_base_version="$(dpkg-parsechangelog -l "$source_dir/debian/changelog" -S Version)"
upstream_version="${debian_base_version%%-*}"
if [[ "$upstream_version" != "$project_version" ]]; then
  echo "CMake version $project_version does not match Debian upstream version $upstream_version." >&2
  exit 1
fi

if [[ -n "$expected_upstream_version" && "$expected_upstream_version" != "$upstream_version" ]]; then
  echo "Expected upstream version $expected_upstream_version, got $upstream_version." >&2
  exit 1
fi

if [[ "$preview_suffix" == "auto" ]]; then
  run_number="${GITHUB_RUN_NUMBER:?GITHUB_RUN_NUMBER is required for auto preview suffix}"
  run_attempt="${GITHUB_RUN_ATTEMPT:-1}"
  resolved_preview_suffix="~lofibox${run_number}.${run_attempt}"
else
  resolved_preview_suffix="$preview_suffix"
fi

if [[ ! "$resolved_preview_suffix" =~ ^~[A-Za-z0-9.+~-]+$ ]]; then
  echo "Preview suffix must start with ~ and contain Debian-version-safe characters, got: $resolved_preview_suffix" >&2
  exit 1
fi

preview_version="${debian_base_version}${resolved_preview_suffix}"
source_sha="$(git -C "$source_dir" rev-parse HEAD)"

cat <<EOF
source_sha=$source_sha
upstream_version=$upstream_version
debian_base_version=$debian_base_version
preview_suffix=$resolved_preview_suffix
preview_version=$preview_version
suite=$suite
EOF

if [[ -n "$github_output" ]]; then
  {
    printf 'source_sha=%s\n' "$source_sha"
    printf 'upstream_version=%s\n' "$upstream_version"
    printf 'debian_base_version=%s\n' "$debian_base_version"
    printf 'preview_suffix=%s\n' "$resolved_preview_suffix"
    printf 'preview_version=%s\n' "$preview_version"
    printf 'suite=%s\n' "$suite"
  } >> "$github_output"
fi
