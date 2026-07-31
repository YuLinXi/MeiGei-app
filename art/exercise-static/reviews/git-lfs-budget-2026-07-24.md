# 静态母版 Git LFS 实测

## 当前测量

| 资产 | 状态 | 尺寸 | 文件大小 |
| --- | --- | ---: | ---: |
| `character-v1.png` | 已批准 | 1536×1024 | 2,004,340 bytes |
| `style-v1.png` | 已批准 | 1254×1254 | 1,630,497 bytes |
| `PEC_DECK_FLY-v1.png` | 已批准 | 1254×1254 | 1,813,582 bytes |

## 暂定结论

三个已批准 PNG 合计 5,448,419 bytes（约 5.20 MiB）；按当前动作母版大小估算，12 个动作母版约增加 20.76 MiB，且后续版本会继续累积。该规模已超过本 change 对普通 Git 二进制历史的预算，因此启用路径限定 Git LFS：只匹配 `references/approved/*.png` 与 `masters/approved/*.png`。

当前本机 `git-lfs/3.7.1` 可用，origin 暴露 GitHub LFS endpoint。任务 1.4 仍保持未完成，直到实际提交后推送 LFS 对象，并从远端或 fresh clone 拉取、比对摘要。

边界如下：

- 候选图继续由 `.gitignore` 排除，不进入普通 Git 或 LFS；
- 288×288 运行时 JPG、JSON、Markdown 和脚本继续使用普通 Git；
- 不改变仓库内其他图片的存储方式；
- 只有上述两个已批准 PNG 路径可使用 LFS。
