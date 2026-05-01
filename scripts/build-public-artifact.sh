#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/build-public-artifact.sh --lofibox-zero <dir> --changes <file.changes> --gpg-key <key-id> [options]

Build the complete GitHub Pages artifact:
  1. signed APT repository under public/debian
  2. public keyring at public/lofibox-archive-keyring.pgp
  3. official website at public/

Options:
  --site <dir>           Website source directory. Default: site
  --output <dir>         Pages artifact directory. Default: public
  --lofibox-zero <dir>   LoFiBox-Zero checkout containing scripts/build-github-pages-apt-repository.sh
  --changes <file>       Debian .changes file to include. May be repeated.
  --suite <name>         Debian suite. Default: trixie
  --component <name>     APT component. Default: main
  --architectures <csv>  APT architectures such as amd64 or amd64,arm64.
  --repo-name <name>     Internal aptly repo name. Default: lofibox-preview
  --origin <text>        Release Origin field. Default: LoFiBox
  --label <text>         Release Label field. Default: LoFiBox Preview
  --gpg-key <key-id>     GPG key id/fingerprint used to sign Release/InRelease
  --gpg-passphrase-file <path>
                         Optional passphrase file for protected signing keys.
  --help                 Show this help.
EOF
}

site_dir="site"
output_dir="public"
lofibox_zero_dir=""
suite="trixie"
component="main"
architectures=""
repo_name="lofibox-preview"
origin="LoFiBox"
label="LoFiBox Preview"
gpg_key=""
gpg_passphrase_file=""
changes=()

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
    --lofibox-zero)
      lofibox_zero_dir="${2:?missing value for --lofibox-zero}"
      shift 2
      ;;
    --changes)
      changes+=("${2:?missing value for --changes}")
      shift 2
      ;;
    --suite)
      suite="${2:?missing value for --suite}"
      shift 2
      ;;
    --component)
      component="${2:?missing value for --component}"
      shift 2
      ;;
    --architectures)
      architectures="${2:?missing value for --architectures}"
      shift 2
      ;;
    --repo-name)
      repo_name="${2:?missing value for --repo-name}"
      shift 2
      ;;
    --origin)
      origin="${2:?missing value for --origin}"
      shift 2
      ;;
    --label)
      label="${2:?missing value for --label}"
      shift 2
      ;;
    --gpg-key)
      gpg_key="${2:?missing value for --gpg-key}"
      shift 2
      ;;
    --gpg-passphrase-file)
      gpg_passphrase_file="${2:?missing value for --gpg-passphrase-file}"
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

if [[ -z "$lofibox_zero_dir" ]]; then
  echo "--lofibox-zero is required." >&2
  exit 2
fi

if [[ -z "$gpg_key" ]]; then
  echo "--gpg-key is required." >&2
  exit 2
fi

if [[ ${#changes[@]} -eq 0 ]]; then
  echo "At least one --changes file is required." >&2
  exit 2
fi

if [[ -n "$gpg_passphrase_file" && ! -f "$gpg_passphrase_file" ]]; then
  echo "GPG passphrase file not found: $gpg_passphrase_file" >&2
  exit 2
fi

repo_builder="$lofibox_zero_dir/scripts/build-github-pages-apt-repository.sh"
if [[ ! -x "$repo_builder" ]]; then
  echo "APT repository builder not found or not executable: $repo_builder" >&2
  exit 2
fi

site_dir="$(cd "$site_dir" && pwd)"
output_parent="$(mkdir -p "$(dirname "$output_dir")" && cd "$(dirname "$output_dir")" && pwd)"
output_dir="$output_parent/$(basename "$output_dir")"
lofibox_zero_dir="$(cd "$lofibox_zero_dir" && pwd)"
repo_builder="$lofibox_zero_dir/scripts/build-github-pages-apt-repository.sh"

absolute_changes=()
for changes_file in "${changes[@]}"; do
  changes_parent="$(cd "$(dirname "$changes_file")" && pwd)"
  absolute_changes+=("$changes_parent/$(basename "$changes_file")")
done

builder_args=(
  --suite "$suite"
  --component "$component"
  --output "$output_dir"
  --repo-name "$repo_name"
  --origin "$origin"
  --label "$label"
  --gpg-key "$gpg_key"
)

if [[ -n "$architectures" ]]; then
  builder_args+=(--architectures "$architectures")
fi

if [[ -n "$gpg_passphrase_file" ]]; then
  builder_args+=(--gpg-passphrase-file "$gpg_passphrase_file")
fi

for changes_file in "${absolute_changes[@]}"; do
  builder_args+=(--changes "$changes_file")
done

(
  cd "$lofibox_zero_dir"
  "$repo_builder" "${builder_args[@]}"
)

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$script_dir/stage-pages-site.sh" \
  --site "$site_dir" \
  --output "$output_dir" \
  --suite "$suite" \
  --require-apt
