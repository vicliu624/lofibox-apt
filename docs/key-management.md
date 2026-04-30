# APT 源密钥管理

LoFiBox 预览 APT 源只发布签名后的仓库元数据，私钥不得进入 git。

## GitHub Secrets

发布 workflow 需要两个 secrets：

```text
LOFIBOX_APT_GPG_PRIVATE_KEY
LOFIBOX_APT_GPG_KEY_ID
```

- `LOFIBOX_APT_GPG_PRIVATE_KEY`：ASCII-armored GPG 私钥，用于 CI 导入。也可以填写 base64 后的私钥内容；如果 secret 中换行被保存成字面量 `\n`，workflow 会还原。
- `LOFIBOX_APT_GPG_KEY_ID`：用于签名 `Release` / `InRelease` 的 key id 或 fingerprint。

`LOFIBOX_APT_GPG_PRIVATE_KEY` 只进入 GitHub Actions secret，不进入 git、不放进 `site/`、不放进 `public/`。
`LOFIBOX_APT_GPG_KEY_ID` 可以是短 key id、长 key id 或 fingerprint；推荐使用 fingerprint，避免同名/同短 id 混淆。

## 用户侧安装 keyring

用户只安装公开 keyring：

```sh
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://vicliu624.github.io/lofibox-apt/lofibox-archive-keyring.pgp \
  | sudo tee /etc/apt/keyrings/lofibox-archive-keyring.pgp >/dev/null
```

然后在 deb822 `.sources` 文件中使用：

```text
Signed-By: /etc/apt/keyrings/lofibox-archive-keyring.pgp
```

不要使用 `apt-key`，也不要把这个 key 设置成全局信任。

## 轮换原则

如果 key 泄漏或需要轮换：

1. 生成新 GPG key。
2. 更新 GitHub Secrets。
3. 重新发布 `lofibox-archive-keyring.pgp`。
4. 在官网和 release note 中明确通知用户更新 keyring。
5. 保留旧 key 的过渡说明，直到旧源不再需要验证。
