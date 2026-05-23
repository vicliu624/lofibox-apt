#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/ci/import-apt-signing-key.sh --env-file <github-env-file>

Imports LOFIBOX_APT_GPG_PRIVATE_KEY and writes LOFIBOX_IMPORTED_GPG_KEY_ID to
the given GitHub Actions environment file.
EOF
}

env_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
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

if [[ -z "$env_file" ]]; then
  usage >&2
  exit 2
fi

if [[ -z "${LOFIBOX_APT_GPG_PRIVATE_KEY:-}" ]]; then
  echo "Missing LOFIBOX_APT_GPG_PRIVATE_KEY." >&2
  exit 1
fi

if [[ -z "${LOFIBOX_APT_GPG_KEY_ID:-}" ]]; then
  echo "Missing LOFIBOX_APT_GPG_KEY_ID." >&2
  exit 1
fi

install -d -m 0700 "$HOME/.gnupg"

key_input="${RUNNER_TEMP:-/tmp}/lofibox-apt-private-key.input"
key_material="${RUNNER_TEMP:-/tmp}/lofibox-apt-private-key.asc"
printf '%s' "$LOFIBOX_APT_GPG_PRIVATE_KEY" > "$key_input"

if grep -q '\\n' "$key_input"; then
  python3 - "$key_input" "$key_material" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1])
target = Path(sys.argv[2])
target.write_text(source.read_text(encoding="utf-8").replace("\\n", "\n"), encoding="utf-8")
PY
elif grep -q -- '-----BEGIN PGP ' "$key_input"; then
  cp "$key_input" "$key_material"
else
  if ! base64 -d "$key_input" > "$key_material"; then
    echo "LOFIBOX_APT_GPG_PRIVATE_KEY is neither ASCII-armored OpenPGP material nor base64-encoded OpenPGP material." >&2
    exit 1
  fi
fi

if ! gpg --batch --import "$key_material"; then
  echo "LOFIBOX_APT_GPG_PRIVATE_KEY is not an importable OpenPGP private key." >&2
  exit 1
fi

imported_fingerprint="$(gpg --batch --with-colons --list-secret-keys | awk -F: '/^fpr:/ {print $10; exit}')"
if [[ -z "$imported_fingerprint" ]]; then
  echo "LOFIBOX_APT_GPG_PRIVATE_KEY did not import a secret key." >&2
  exit 1
fi

if gpg --batch --list-secret-keys "$LOFIBOX_APT_GPG_KEY_ID" >/dev/null 2>&1; then
  signing_key="$LOFIBOX_APT_GPG_KEY_ID"
else
  echo "::warning::LOFIBOX_APT_GPG_KEY_ID did not match the imported secret key. Falling back to the imported fingerprint."
  signing_key="$imported_fingerprint"
fi

printf 'LOFIBOX_IMPORTED_GPG_KEY_ID=%s\n' "$signing_key" >> "$env_file"
rm -f "$key_input" "$key_material"
echo "Imported APT signing key."
