<!-- SPDX-License-Identifier: GPL-3.0-or-later -->

# Local Preview APT Publishing

This document describes local validation. It does not upload GitHub Pages.

The release surfaces are layered:

- `site/`: static website source, committed to git.
- `public/`: one generated Pages artifact, not committed to git.
- `public/debian/`: machine-readable APT repository, not a website path.

## Build A Debian Package Locally

For ad-hoc local package construction:

```sh
git clone https://github.com/vicliu624/LoFiBox-Zero.git
cd LoFiBox-Zero
chmod +x debian/rules debian/tests/smoke
dpkg-buildpackage -us -uc -b
```

Generated `.changes`, `.deb`, and `.buildinfo` files are written next to the
`LoFiBox-Zero` checkout.

## Build A Complete Pages Artifact

```sh
gpg --import /path/to/private.asc

lofibox-apt/scripts/build-public-artifact.sh \
  --site lofibox-apt/site \
  --lofibox-zero LoFiBox-Zero \
  --suite trixie \
  --component main \
  --architectures amd64,arm64,armhf \
  --output lofibox-apt/public \
  --repo-name lofibox-preview \
  --origin LoFiBox \
  --label "LoFiBox Preview" \
  --gpg-key "$LOFIBOX_APT_GPG_KEY_ID" \
  --changes ./lofibox_<preview-version>_amd64.changes \
  --changes ./lofibox_<preview-version>_arm64.changes \
  --changes ./lofibox_<preview-version>_armhf.changes
```

The command calls the LoFiBox-Zero APT repo builder, stages the website, and
validates the final artifact.

Expected shape:

```text
public/
  index.html
  assets/
  docs/
  lofibox-archive-keyring.pgp
  debian/
    dists/trixie/...
    pool/...
```

## Website-Only Preview

```sh
lofibox-apt/scripts/stage-pages-site.sh \
  --site lofibox-apt/site \
  --output lofibox-apt/public

python3 -m http.server --directory lofibox-apt/public 8080
```

If an APT repository already exists and should be validated after staging:

```sh
lofibox-apt/scripts/stage-pages-site.sh \
  --site lofibox-apt/site \
  --output lofibox-apt/public \
  --require-apt
```

## GitHub Pages Publishing

Remote repository:

```text
git@github.com:vicliu624/lofibox-apt.git
```

Repository settings:

- Pages source: `GitHub Actions`
- Required secrets: `LOFIBOX_APT_GPG_PRIVATE_KEY`, `LOFIBOX_APT_GPG_KEY_ID`
- Optional secret: `LOFIBOX_APT_GPG_PASSPHRASE`

Publishing is manual or triggered by the `LoFiBox-Zero` source release
workflow. It is not triggered by pushing website changes to `main`.

Recommended manual inputs:

```text
source_ref: v0.2.1
expected_upstream_version: 0.2.1
suite: trixie
preview_suffix: auto
```

`preview_suffix: auto` resolves to a suffix such as
`~lofibox123.1`, producing a preview package version like
`0.2.1-1~lofibox123.1`. The `~` makes preview packages sort below a future
official Debian package such as `0.2.1-1`.

The APT suite remains `trixie`, while the package changelog distribution is
rewritten to `unstable` before package construction. This avoids lintian
misclassifying a third-party repository suite as an invalid Debian upload
target.

Lintian must use the Debian profile:

```sh
lintian --profile debian "$LOFIBOX_CHANGES"
```

GitHub runners are Ubuntu hosts; the Debian profile keeps lintian's distribution
rules aligned with the package being built.

## Cross-Build Boundary

The GitHub publisher builds three package architectures:

- `amd64`, built natively and validated with lintian and autopkgtest.
- `arm64`, cross-built for Raspberry Pi CM4/CM5 class 64-bit systems.
- `armhf`, built inside a Raspberry Pi OS/Raspbian ARMv6 userspace for
  Raspberry Pi CM0 / ARMv6 hard-float systems.

Cross builds are package-construction jobs, not runtime execution jobs. They use
`DEB_BUILD_OPTIONS=nocheck` because the GitHub runner is x86_64 and must not try
to execute target architecture test binaries. Runtime smoke coverage stays on
the native package job and device validation stays on real hardware.

The arm64 cross-build environment must install target development libraries and
target runtime libraries required by `dh_shlibdeps`, including target
`libstdc++6`.

The Raspberry Pi CM0 package is a Raspberry Pi OS/Raspbian armhf package, not a
generic Ubuntu/Debian armhf package. Generic Ubuntu armhf start files are ARMv7
and can make the final ELF unsuitable for ARM1176JZF-S devices. The publish
workflow therefore creates a Raspbian `bookworm` ARMv6 userspace with
`debootstrap` and `qemu-arm-static`.

The CM0 build must validate the final installed executable with `readelf -A`.
Accepted attributes are ARMv6 / ARM1176-class, for example:

```text
Tag_CPU_name: "6"
Tag_CPU_arch: v6
Tag_FP_arch: VFPv2
```
