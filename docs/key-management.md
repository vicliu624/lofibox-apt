# APT 源密钥管理

LoFiBox APT 预览源只发布签名后的仓库元数据，私钥不得进入 git。

## 必需 GitHub Secrets

```text
LOFIBOX_APT_GPG_PRIVATE_KEY
LOFIBOX_APT_GPG_KEY_ID
```

`LOFIBOX_APT_GPG_PRIVATE_KEY` 是 ASCII-armored 私钥。`LOFIBOX_APT_GPG_KEY_ID` 是用于签名 `Release` / `InRelease` 的 key id 或 fingerprint。

## 用户侧安装

用户只安装公开 keyring：

```sh
curl -fsSL https://vicliu624.github.io/lofibox-apt/lofibox-archive-keyring.pgp \
  | sudo tee /etc/apt/keyrings/lofibox-archive-keyring.pgp >/dev/null
```

然后在 `.sources` 文件中使用：

```text
Signed-By: /etc/apt/keyrings/lofibox-archive-keyring.pgp
```

不要使用 `apt-key`，也不要把这个 key 设成全局信任。
