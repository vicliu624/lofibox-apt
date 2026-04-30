# LoFiBox APT / Official Portal

这个仓库发布两个东西：

1. **LoFiBox Zero 官方门户**：`site/` 中的极简静态网站，发布到 GitHub Pages 根目录。
2. **LoFiBox Zero 预览 APT 源**：发布到 GitHub Pages 的 `/debian` 目录，供 `apt` 机器解析。

这两个入口共享同一个 Pages artifact，但语义必须分开：官网是给人读的，APT repo 是给 `apt` 使用的稳定目录结构。

## 用户安装

当前预览源面向 Debian trixie / amd64：

```bash
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://vicliu624.github.io/lofibox-apt/lofibox-archive-keyring.pgp \
  | sudo tee /etc/apt/keyrings/lofibox-archive-keyring.pgp >/dev/null

sudo tee /etc/apt/sources.list.d/lofibox.sources >/dev/null <<'EOF'
Types: deb
URIs: https://vicliu624.github.io/lofibox-apt/debian
Suites: trixie
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/lofibox-archive-keyring.pgp
EOF

sudo apt update
sudo apt install lofibox
```

也可以直接参考仓库里的 `lofibox.sources.example`。

## GitHub Pages 输出结构

发布后的 artifact 应保持：

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

不要把 HTML 文档放进 `public/debian`，也不要移动 `debian/` 目录；用户的 `URIs:` 已经依赖这个路径。

## 官网本地预览

官网是零依赖静态站点：

```bash
python3 -m http.server --directory site 8080
```

然后打开 `http://127.0.0.1:8080/`。

Windows PowerShell 下也可以直接打开：

```powershell
Start-Process .\site\index.html
```

## 发布流程

首次发布前，在 GitHub 仓库设置里完成三件事：

1. `Settings -> Pages -> Build and deployment` 选择 `GitHub Actions`。
2. `Settings -> Secrets and variables -> Actions` 增加 APT signing secrets。
3. 确认仓库启用了 Actions。

`.github/workflows/publish.yml` 是唯一正式发布入口。它会在 `master/main` 推送时自动发布，也可以手动触发指定 LoFiBox-Zero ref。它会：

1. checkout `lofibox-apt`；
2. checkout `vicliu624/LoFiBox-Zero`；
3. 安装 Debian 打包工具；
4. 导入 APT signing key；
5. 构建 `.deb`；
6. 调用 `scripts/build-public-artifact.sh` 生成完整 `public/`；
7. 校验 `public/index.html`、`public/debian/dists/<suite>/InRelease`、`Packages`、`pool/*.deb`、公开 keyring 等发布边界；
8. 上传并部署 GitHub Pages。

需要的 GitHub Secrets：

- `LOFIBOX_APT_GPG_PRIVATE_KEY`
- `LOFIBOX_APT_GPG_KEY_ID`

`LOFIBOX_APT_GPG_PRIVATE_KEY` 可以是 ASCII-armored 私钥，也可以是 base64 后的私钥内容。`LOFIBOX_APT_GPG_KEY_ID` 推荐填写 fingerprint。
如果 key id 和导入出的私钥 fingerprint 不匹配，workflow 会自动使用导入出的 fingerprint；但 private key secret 不能只填 public key。

自动发布：

```text
git push origin master
```

自动发布使用：

```text
source_ref: main
suite: trixie
preview_suffix: auto
```

手动发布：

```text
GitHub Actions -> Publish LoFiBox APT Repository -> Run workflow
source_ref: main
suite: trixie
preview_suffix: auto
```

发布成功后：

```text
官网: https://vicliu624.github.io/lofibox-apt/
APT:  https://vicliu624.github.io/lofibox-apt/debian
```

## 文档

- 官网入口：`site/index.html`
- 用户文档：`site/docs/`
- APT key 管理：`docs/key-management.md`
- 本地发布说明：`docs/local-publish.md`
- 发布脚本：
  - `scripts/build-public-artifact.sh`
  - `scripts/stage-pages-site.sh`
  - `scripts/validate-pages-artifact.sh`

## 边界约束

- APT repo 路径保持 `/debian`。
- 官网资源放在 `site/assets`，发布后对应 Pages 根目录的 `/assets`。
- `lofibox-archive-keyring.pgp` 放在 Pages 根目录，方便 deb822 `Signed-By` 示例下载。
- 预览源不替代 Debian 官方源；进入官方源前，它是用户安装和验证的第三方通道。
