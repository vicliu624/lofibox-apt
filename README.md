<!-- SPDX-License-Identifier: GPL-3.0-or-later -->

# LoFiBox APT / Official Portal

This repository publishes two surfaces:

- The static LoFiBox Zero official portal from `site/` to the GitHub Pages root.
- The signed preview APT repository under `/debian` for `apt` clients.

Those surfaces share one Pages artifact, but their responsibilities are
separate. The website is for humans; `/debian` is a stable machine interface for
APT.

## Release Boundary

`LoFiBox-Zero` owns source releases. A source release creates an immutable tag
such as `v0.2.1` and, when configured, triggers this repository's publishing
workflow.

`lofibox-apt` owns distribution publishing. It consumes a LoFiBox-Zero source
ref, applies a preview Debian suffix, builds packages for the supported
architectures, signs the APT repository, merges it with the static site, and
deploys the Pages artifact.

Prefer release tags over `main` when publishing:

```text
source_ref: v0.2.1
expected_upstream_version: 0.2.1
suite: trixie
preview_suffix: auto
```

`preview_suffix: auto` resolves to:

```text
~lofibox<GITHUB_RUN_NUMBER>.<GITHUB_RUN_ATTEMPT>
```

For example, source version `0.2.1-1` becomes a preview package version like
`0.2.1-1~lofibox123.1`. The `~` keeps preview packages below a future official
Debian `0.2.1-1` package.

## User Installation

The current preview repository targets Debian trixie for `amd64`, `arm64`, and
Raspberry Pi ARMv6-compatible `armhf`:

```bash
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://vicliu624.github.io/lofibox-apt/lofibox-archive-keyring.pgp \
  | sudo tee /etc/apt/keyrings/lofibox-archive-keyring.pgp >/dev/null

sudo tee /etc/apt/sources.list.d/lofibox.sources >/dev/null <<'EOF'
Types: deb
URIs: https://vicliu624.github.io/lofibox-apt/debian
Suites: trixie
Components: main
Architectures: amd64 arm64 armhf
Signed-By: /etc/apt/keyrings/lofibox-archive-keyring.pgp
EOF

sudo apt update
sudo apt install lofibox
```

`lofibox.sources.example` carries the same deb822 source definition.

## Pages Artifact Shape

The deployed artifact must keep this shape:

```text
public/
  index.html
  assets/
  docs/
  .nojekyll
  lofibox-archive-keyring.pgp
  debian/
    dists/trixie/...
    pool/...
```

Do not put HTML inside `public/debian`, and do not move the `debian/` path; user
source files depend on that URI.

## Publishing Workflow

The only publishing entry point is:

```text
.github/workflows/publish.yml
```

It is intentionally `workflow_dispatch` only. Website edits in this repository
should not silently create a new package build. A source release in
`LoFiBox-Zero` can trigger this workflow after it creates a `vX.Y.Z` tag, or it
can be run manually from the Actions UI.

The workflow:

1. Checks out this repository and `vicliu624/LoFiBox-Zero`.
2. Resolves the upstream version, Debian base version, preview suffix, and
   source commit once in the `prepare` job.
3. Builds `amd64`, cross-builds `arm64`, and builds Raspberry Pi ARMv6 `armhf`
   in a Raspbian userspace.
4. Runs lintian on each package and autopkgtest on the native `amd64` package.
5. Validates that all packages share the same preview version and expected
   architecture.
6. Imports the APT signing key.
7. Calls `scripts/build-public-artifact.sh` to build the signed repository and
   merge the static website.
8. Validates the final Pages artifact and deploys it.

## Required Secrets

In `lofibox-apt`:

- `LOFIBOX_APT_GPG_PRIVATE_KEY`: ASCII-armored or base64-encoded private key
  material used for APT repository signing.
- `LOFIBOX_APT_GPG_KEY_ID`: signing key id or fingerprint. A full fingerprint is
  recommended.
- `LOFIBOX_APT_GPG_PASSPHRASE`: optional passphrase for protected signing keys.

In `LoFiBox-Zero`, only if the source release workflow should trigger APT
publishing automatically:

- `LOFIBOX_APT_WORKFLOW_TOKEN`: token with permission to run Actions workflows
  in `vicliu624/lofibox-apt`.

## Local Website Preview

```bash
python3 -m http.server --directory site 8080
```

Then open `http://127.0.0.1:8080/`.

On Windows PowerShell:

```powershell
Start-Process .\site\index.html
```

## Scripts

- `scripts/build-public-artifact.sh`: builds a complete `public/` artifact from
  `.changes` files, the LoFiBox-Zero APT repo builder, and `site/`.
- `scripts/stage-pages-site.sh`: stages only the static website into `public/`.
- `scripts/validate-pages-artifact.sh`: validates website and optional APT repo
  boundaries.
- `scripts/ci/*.sh`: GitHub Actions helpers for preview version resolution,
  Debian artifact validation, and signing key import.
