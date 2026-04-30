#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/stage-pages-site.sh [options]

Copy the static official website into a GitHub Pages artifact directory without
touching any existing APT repository under <output>/debian.

Options:
  --site <dir>     Static website source directory. Default: site
  --output <dir>   Pages artifact directory. Default: public
  --suite <name>   Debian suite used when validating an existing APT repo. Default: trixie
  --require-apt    Require and validate the APT repository after staging the site
  --help           Show this help.
EOF
}

site_dir="site"
output_dir="public"
suite="trixie"
require_apt="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --site)
      site_dir="${2:?missing value for --site}"
      shift 2
      ;;
    --output)
      output_dir="${2:?missing value for --output}"
      shift 2
      ;;
    --suite)
      suite="${2:?missing value for --suite}"
      shift 2
      ;;
    --require-apt)
      require_apt="true"
      shift
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

if [[ ! -d "$site_dir" ]]; then
  echo "Website source directory not found: $site_dir" >&2
  exit 2
fi

if [[ -z "$output_dir" || "$output_dir" == "/" ]]; then
  echo "Refusing unsafe output directory: $output_dir" >&2
  exit 2
fi

need_site_file() {
  local path="$site_dir/$1"
  if [[ ! -f "$path" ]]; then
    echo "Website source file missing: $path" >&2
    exit 1
  fi
}

need_site_file index.html
need_site_file assets/site.css
need_site_file docs/index.html
need_site_file zh/index.html

mkdir -p "$output_dir"
cp -a "$site_dir/." "$output_dir/"
touch "$output_dir/.nojekyll"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
validate_args=(--suite "$suite")
if [[ "$require_apt" == "true" ]]; then
  validate_args+=(--require-apt)
fi

"$script_dir/validate-pages-artifact.sh" "${validate_args[@]}" "$output_dir"
