# 静态动作图跨电脑恢复

## 新电脑恢复

```bash
git clone git@github.com:YuLinXi/MeiGei-app.git
cd MeiGei-app
git checkout feature/v1.1-b01
git lfs install
git lfs pull
```

如果仓库尚未配置静态母版 LFS 规则，`git lfs pull` 不会下载额外对象，这是正常状态。只有实测批准母版超过普通 Git 预算并确认远端 LFS 可用后，才允许新增路径限定规则。

恢复后必须存在：

- `references/approved/` 中已批准角色/风格母版及 prompt/brief；
- `masters/approved/` 中已批准动作母版；
- `briefs/`、`manifests/`、`reviews/`、`scripts/`；
- App 随包的 288×288、JPEG 质量 82、≤24 KiB JPG 和运行时 manifest。

以下内容不得依赖 Git 恢复：

- `staging/`、`candidates/`、`cache/`、`logs/`；
- imagegen 会话缓存或旧电脑临时目录；
- API key、账户凭证和 `.env`。

## 恢复验收

1. 运行 schema 和来源台账校验。
2. 从已批准母版重新导出 288×288 JPG，并核对质量、≤24 KiB 大小与 SHA-256 规则。
3. 不登录 imagegen、不安装 Blender，完成 iOS Simulator Debug 构建。
4. 若使用 Git LFS，在 fresh clone 中确认所有指针均已 materialize，不存在只拉到 pointer 的正式母版。
