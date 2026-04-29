# 本地生成预览 APT 源

这个流程用于本机检查，不会上传 GitHub Pages。

```sh
git clone https://github.com/vicliu624/LoFiBox-Zero.git
cd LoFiBox-Zero
dpkg-buildpackage -us -uc -b

gpg --import /path/to/private.asc

scripts/build-github-pages-apt-repository.sh \
  --suite trixie \
  --component main \
  --output ../lofibox-apt/public \
  --repo-name lofibox-preview \
  --origin LoFiBox \
  --label "LoFiBox Preview" \
  --gpg-key "$LOFIBOX_APT_GPG_KEY_ID" \
  --changes ../lofibox_0.1.0-1~lofibox1_amd64.changes
```

生成结果在 `public/`。用任意静态文件服务器暴露 `public/` 后，即可用 deb822 `.sources` 文件测试安装。
