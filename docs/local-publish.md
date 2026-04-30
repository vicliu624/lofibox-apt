# 本地生成预览 APT 源

这个流程用于本机检查，不会上传 GitHub Pages。

发布物分成三层：

- `site/`：官网源码，提交到 git。
- `public/`：一次性 Pages artifact，不提交到 git。
- `public/debian/`：APT 机器接口，不允许混入 HTML。

## 构建 Debian 包

```sh
git clone https://github.com/vicliu624/LoFiBox-Zero.git
cd LoFiBox-Zero
chmod +x debian/rules debian/tests/smoke
dpkg-buildpackage -us -uc -b
```

生成的 `.changes` 文件会在 `LoFiBox-Zero` 上级目录。

## 生成完整 Pages artifact

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
  --changes ./lofibox_0.1.0-1~lofibox1_amd64.changes
```

这个命令会先调用 LoFiBox-Zero 的 APT repo builder，再复制官网，并校验最终 artifact。

最终结构应包含：

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

## 只预览官网

如果只想检查官网，不生成 APT repo：

```sh
lofibox-apt/scripts/stage-pages-site.sh \
  --site lofibox-apt/site \
  --output lofibox-apt/public

python3 -m http.server --directory lofibox-apt/public 8080
```

如果已经有 APT repo，并希望强制校验它：

```sh
lofibox-apt/scripts/stage-pages-site.sh \
  --site lofibox-apt/site \
  --output lofibox-apt/public \
  --require-apt
```

## 本地测试

```sh
python3 -m http.server --directory lofibox-apt/public 8080
```

然后临时把 deb822 source 的 `URIs:` 指向本地服务，例如：

```text
URIs: http://127.0.0.1:8080/debian
```

注意：本地 HTTP 测试只用于验证路径和索引，不代表最终 GitHub Pages 部署已经成功。

## GitHub Pages 发布

远端仓库使用：

```text
git@github.com:vicliu624/lofibox-apt.git
```

GitHub 仓库设置中需要：

- Pages source 选择 `GitHub Actions`。
- Actions secrets 增加 `LOFIBOX_APT_GPG_PRIVATE_KEY`。
- Actions secrets 增加 `LOFIBOX_APT_GPG_KEY_ID`。

推送到 `main` 会自动触发 `Publish LoFiBox APT Repository` workflow，使用：

```text
source_ref: main
suite: trixie
preview_suffix: auto
```

架构发布约束：预览源必须同时发布 `amd64`、`arm64` 和 `armhf`。`arm64` 面向 CM4/CM5 的 64-bit Raspberry Pi OS/Debian；`armhf` 面向 CM0/ARMv6，因此必须在 Raspberry Pi OS ARMv6/arm1176 环境构建，不能用普通 ARMv7 baseline 的 armhf 包冒充。

预览包版本默认使用 `0.1.0-1~lofiboxN` 这类后缀。`~` 让预览源版本低于未来 Debian 官方源的 `0.1.0-1`，所以 workflow 使用 `dch -b` 明确允许这次有意的预览降版本。注意这里有两层命名：APT 仓库 suite 仍然是 `trixie`，但 Debian 包构建产物 `.changes` 的 changelog distribution 固定为 `unstable`，避免 Lintian 把第三方源 suite 误判成无效上传目标。

也可以手动触发 workflow，并输入：

```text
source_ref: main
suite: trixie
preview_suffix: auto
```
