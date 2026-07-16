# 发布与版本管理规则

## 目标状态

发布模型采用“PR 前审查，合并后全自动 CD”：功能开发和发布审批发生在 PR；Release PR 一旦合并，后端部署、TestFlight 上传、处理等待、Tag 和 GitHub Release 不再要求手工操作。

## 分支规则

| 分支 | 用途 | 允许内容 | 合并目标 |
|---|---|---|---|
| `main` | 唯一可发布主线，始终可构建 | 已 review、已通过 CI 的提交 | 不直接 push |
| `feature/<slug>` | 单一功能 | 功能代码、规格、测试 | `main` |
| `fix/<slug>` | 非紧急缺陷 | 修复与回归测试 | `main` |
| `release/vX.Y-bN` | 发布候选 | 版本号、发版文档、阻断性修复 | `main` |
| `hotfix/vX.Y-bN-<slug>` | 线上紧急修复 | 最小修复与回归测试 | `main`，并发布新 build |

仓库历史使用 `feature/v1.0-bN` 承载整次发版。Skill 必须兼容正在进行的此类分支，但下一次新建发布分支时切换到 `release/vX.Y-bN`。不要为改名而重写历史或移动已推送分支。

### `main` 保护

- 仅允许 PR 合并；至少 1 名非提交者 reviewer。
- 必需 checks：`release-policy`、`backend-test`、`ios-test`。
- review 后新提交使旧 approval 失效；所有 conversation 必须解决。
- 禁止 force push、删除分支和绕过规则。
- Release PR 推荐 squash merge，使发布提交和候选内容边界清晰。

## 版本来源与一致性

| 位置 | 值 | 规则 |
|---|---|---|
| Xcode `MARKETING_VERSION` | `X.Y` | App、Tests、UITests、Widget 全部一致 |
| Xcode `CURRENT_PROJECT_VERSION` | `N` | 全 target 一致，正整数，单调递增 |
| Release 分支 | `release/vX.Y-bN` | 必须与工程一致 |
| Git Tag | `vX.Y-bN` | TestFlight 处理完成后创建，不移动、不复用 |
| 发版文档 | `release-X.Y-bN-*` | 文件名与正文版本一致 |

build 号的真实上界不是 Git Tag，而是 App Store Connect。下一 build 必须是以下最大值加一：

1. 当前 Xcode 工程 build；
2. 所有远端 `v*-b*` Tag 的 build；
3. App Store Connect 对当前 `MARKETING_VERSION` 已存在或正在处理的最高 build。

不要启用 Xcode 的 `manageAppVersionAndBuildNumber`。CI 归档、IPA、Tag 和文档必须能追溯到同一个明确 build。

## 发布边界

上一 Tag（不含）到候选提交（含）的全部 diff 构成本次发布。发版介绍必须从这个 diff 和规格中提炼，不能只复制 commit log。

- 有 `backend/` 变更：先部署后端，再上传 iOS。
- 无 `backend/` 变更：跳过重建，但仍验证生产 health、dev token、法务页。
- 仅后端变更：本 Skill 仍按 iOS TestFlight 联合发版处理；若确需后端独立紧急发布，必须显式选择 hotfix 流程并生成独立发布证据。
- 新后端必须兼容上一 TestFlight 客户端。删除字段、收紧枚举、改变 JSON 结构或移除旧 endpoint 不能进入全自动通道。

## Tag 与发布状态

`vX.Y-bN` 表示该提交的后端状态已验收，iOS build 已在 App Store Connect 处理为可用于 TestFlight 的有效构建。Tag 不代表 App Store 正式上架，也不代表所有真机专属能力已人工回归。

GitHub Release 至少包含：

- version/build、commit SHA、上一个 Tag；
- 后端是否部署、Flyway 版本与 health 证据；
- TestFlight 处理状态与内部测试分发状态；
- checklist 和功能介绍链接；
- 未自动覆盖的真机回归重点；
- workflow run 链接和失败恢复说明。

## Hotfix 与失败 build

- TestFlight 已接收的 build 永不复用，即使处理失败或主动 expire。
- hotfix 从最新 `main` 创建，使用新 build；不得在旧 Tag 上补提交后移动 Tag。
- 数据库 migration 只前进。已运行 migration 出错时，新增修复 migration；不编辑已发布的 `V*__*.sql`。
- 后端应用可以回滚到上一镜像，但只有新旧 schema 双向兼容时才允许。无法确认时停止自动回滚并升级为人工事故处理。

## 发布并发

GitHub Actions 使用仓库级 `dontlift-production-release` concurrency group，`cancel-in-progress=false`。同一时间只能有一次生产发布；后来的发布排队，不得取消正在运行的 migration 或上传。
