#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/validate-pages-artifact.sh [options] <public-dir>

Validate the GitHub Pages artifact that carries both the LoFiBox website and
the machine-readable APT repository.

Options:
  --suite <name>   Debian suite to validate. Default: trixie
  --require-apt    Require signed APT repository files under <public-dir>/debian
  --help           Show this help.
EOF
}

suite="trixie"
require_apt="false"
public_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
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
      if [[ -n "$public_dir" ]]; then
        echo "Unexpected argument: $1" >&2
        usage >&2
        exit 2
      fi
      public_dir="$1"
      shift
      ;;
  esac
done

if [[ -z "$public_dir" ]]; then
  echo "Missing public artifact directory." >&2
  usage >&2
  exit 2
fi

if [[ ! -d "$public_dir" ]]; then
  echo "Artifact directory not found: $public_dir" >&2
  exit 2
fi

need_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Required file missing: $path" >&2
    exit 1
  fi
}

need_nonempty_file() {
  local path="$1"
  need_file "$path"
  if [[ ! -s "$path" ]]; then
    echo "Required file is empty: $path" >&2
    exit 1
  fi
}

need_file "$public_dir/index.html"
need_file "$public_dir/.nojekyll"
need_file "$public_dir/assets/site.css"
need_file "$public_dir/docs/index.html"
need_file "$public_dir/docs/get-started.html"
need_file "$public_dir/docs/gui.html"
need_file "$public_dir/docs/tui.html"
need_file "$public_dir/docs/cli.html"
need_file "$public_dir/docs/remote-sources.html"
need_file "$public_dir/docs/metadata-lyrics.html"
need_file "$public_dir/docs/packaging.html"
need_file "$public_dir/zh/index.html"
need_file "$public_dir/zh/docs/index.html"
need_file "$public_dir/zh/docs/get-started.html"
need_file "$public_dir/zh/docs/gui.html"
need_file "$public_dir/zh/docs/tui.html"
need_file "$public_dir/zh/docs/cli.html"
need_file "$public_dir/zh/docs/remote-sources.html"
need_file "$public_dir/zh/docs/metadata-lyrics.html"
need_file "$public_dir/zh/docs/packaging.html"

if [[ "$require_apt" == "true" ]]; then
  apt_root="$public_dir/debian"
  dist_root="$apt_root/dists/$suite"

  need_nonempty_file "$public_dir/lofibox-archive-keyring.pgp"
  need_nonempty_file "$dist_root/InRelease"
  need_nonempty_file "$dist_root/Release"

  if ! find "$dist_root" -path "*/binary-*/*Packages*" -type f -size +0c | grep -q .; then
    echo "No non-empty Packages index found under $dist_root." >&2
    exit 1
  fi

  if ! find "$apt_root/pool" -name '*.deb' -type f -size +0c | grep -q .; then
    echo "No .deb package found under $apt_root/pool." >&2
    exit 1
  fi

  if find "$apt_root" -name '*.html' -type f | grep -q .; then
    echo "HTML files must not be published inside the APT repository path: $apt_root" >&2
    exit 1
  fi
fi

echo "Pages artifact validated: $public_dir"
