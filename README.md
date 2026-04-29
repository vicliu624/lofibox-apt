# LoFiBox APT 预览源

这个仓库用于发布 LoFiBox 进入 Debian 官方源之前的第三方 APT 预览源。它不替代 Debian 官方打包路线，只负责把已经通过 LoFiBox 主仓库 CI/打包检查的 `.deb` 以标准 APT 仓库形式发布给早期用户。

当前用户安装入口：

```sh
sudo install -d -m 0755 /etc/apt/keyrings

curl -fsSL https://vicliu624.github.io/lofibox-apt/lofibox-archive-keyring.pgp \
  | sudo tee /etc/apt/keyrings/lofibox-archive-keyring.pgp >/dev/null

sudo chmod 0644 /etc/apt/keyrings/lofibox-archive-keyring.pgp

sudo tee /etc/apt/sources.list.d/lofibox.sources >/dev/null <<'EOF'
Types: deb
URIs: https://vicliu624.github.io/lofibox-apt/debian
Suites: trixie
Components: main
Signed-By: /etc/apt/keyrings/lofibox-archive-keyring.pgp
EOF

sudo apt update
sudo apt install lofibox
```

不要使用 `apt-key`。这个预览源必须使用独立 keyring 和 deb822 `.sources` 文件。

## 仓库结构

GitHub Pages 发布产物由 workflow 生成，形状如下：

```text
public/
  .nojekyll
  lofibox-archive-keyring.pgp
  debian/
    dists/trixie/InRelease
    dists/trixie/Release
    dists/trixie/Release.gpg
    dists/trixie/main/binary-amd64/
    pool/
```

## 发布方式

手动触发 `.github/workflows/publish.yml`。

必需 secrets：

```text
LOFIBOX_APT_GPG_PRIVATE_KEY
LOFIBOX_APT_GPG_KEY_ID
```

workflow 会：

1. 拉取 `vicliu624/LoFiBox-Zero` 指定 ref。
2. 安装 Debian 打包依赖和 `aptly`。
3. 将包版本加上 `~lofiboxN` 预览后缀。
4. 执行 `dpkg-buildpackage -us -uc -b`。
5. 调用主仓库脚本 `scripts/build-github-pages-apt-repository.sh` 生成并签名 APT 仓库。
6. 部署到 GitHub Pages。

## 版本策略

预览源版本必须低于未来官方 Debian 版本：

```text
0.1.0-1~lofibox1
0.1.0-1~lofibox2
0.1.1-1~lofibox1
```

这样 Debian 官方源出现 `0.1.0-1` 时，会自然覆盖预览源版本。

## 架构策略

当前 GitHub-hosted runner 负责 `amd64`。`arm64` 应从 192.168.50.92 这类真实 arm64 设备或未来自托管 arm64 runner 产出，再合入同一个 `aptly` 仓库快照。
