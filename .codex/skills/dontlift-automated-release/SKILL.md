---
name: dontlift-automated-release
description: 为 DontLift 准备、审查并执行后端生产部署与 iOS TestFlight 全自动发布。用于发布准备、版本递增、Release PR、发布状态检查、失败处置和回滚。
license: MIT
compatibility: Requires git, gh, Java 21, Gradle wrapper, Xcode 26, OpenSpec 1.6+, GitHub Actions and App Store Connect API credentials.
metadata:
  author: dontlift
  version: "1.0"
---

# DontLift 全自动发布

把“全自动”解释为：Release PR 通过并合并后，无需再手动 SSH、Xcode Archive 或 App Store Connect 上传，即可完成后端部署、iOS TestFlight 内部测试发布、自动验收、Tag 和 GitHub Release。不要把 TestFlight 发布等同于 App Store 正式上架。

## 首先读取

每次使用都完整读取：

- `references/release-policy.md`：分支、版本、Tag、发布顺序与失败规则。
- `references/acceptance-gates.md`：发布前 review 和自动化验收标准。

执行首次接入或发现 CI/凭据缺失时，再读取 `references/setup.md`。创建发版文档时使用 `templates/`，不要从旧 checklist 机械复制状态。

## 判断运行模式

根据用户意图选择一个模式；不确定时优先做只读的 `status`，不要触发生产变更。

- `setup`：安装或更新 GitHub Actions，检查 GitHub ruleset、environment、Secrets/Variables 与 Apple 一次性配置。
- `prepare`：从候选提交创建 Release PR，递增版本并生成两份发版文档。
- `release`：完成 `prepare`，在 PR 合并后监控全自动发布直到成功或明确失败。
- `status`：只读检查当前分支、最近 Tag、CI、生产 health、Flyway 与 TestFlight 状态。
- `rollback`：处理失败发布。只自动回滚后端应用镜像；绝不自动回滚 Flyway migration。

## Setup 流程

1. 读取 `references/setup.md` 并实时检查仓库配置，不把文档里的日期快照当现状。
2. 对比 `assets/workflows/` 与 `.github/workflows/`。只有用户要求接入或更新自动发布时才安装；用差异合并，不盲目覆盖用户工作流。
3. 校验 GitHub Secrets/Variables 只检查名称，不读取或输出值。
4. Apple API Key、Distribution Certificate、Provisioning Profile 或内部测试组缺失时，列出一次性配置项并停止发布；不要生成虚假凭据，也不要降低签名要求。
5. 完成接入后，先用 `workflow_dispatch` 做一次受控演练，再启用 Release PR 合并触发。

## Prepare 流程

1. 读取根目录 `AGENTS.md`、最近 Tag 对应 checklist/功能介绍、当前 diff 和本次涉及的 OpenSpec change。
2. 执行 `git fetch origin main --tags --prune`。发布工作必须在干净 worktree 中完成；若用户当前 worktree 有未提交改动，创建独立 worktree，不移动、不暂存、不提交用户改动。
3. 确认候选提交已在远端且来源明确。新流程使用 `release/v<MARKETING_VERSION>-b<CURRENT_PROJECT_VERSION>`；历史 `feature/vX.Y-bN` 只作兼容，不继续扩散该命名。
4. build 号取以下最大值再加一：工程内 build、Git Tag build、App Store Connect 对应版本的最高 build。build 一经上传永不复用，失败修复也必须使用新 build。
5. 同步修改 App、Tests、UITests、Widget 的 `MARKETING_VERSION` 与 `CURRENT_PROJECT_VERSION`，不得让 Xcode 上传时代改 build 号。
6. 基于“上一 Tag 到候选提交”的实际 diff 生成：
   - `docs/release-<version>-b<build>-checklist.md`
   - `docs/release-<version>-b<build>-feature-intro.md`
7. 运行 `ALLOW_DIRTY=1 RELEASE_BRANCH=<branch> bash .codex/skills/dontlift-automated-release/scripts/preflight.sh`，再执行完整 build/test。任何阻断门禁失败都先修复，不得用描述性文字代替证据。
8. 做一次面向发布的 diff review，按 `P0/P1/P2` 报告。`P0` 或 `P1` 未清零不得创建可合并的 Release PR。
9. 提交只包含版本、发版文档和本次候选功能的预期改动，推送 Release 分支并创建 PR。PR 标题使用 `release: vX.Y-bN`。

## Release 流程

1. 确认 `main` ruleset 要求 PR、至少一名 reviewer、必需 CI checks、解决全部 review conversation，并禁止 force push/delete。
2. Release PR 合并后由 `.github/workflows/release.yml` 自动执行。不要在本地重复运行 `release-update.sh` 或手动上传同一 build。
3. 持续监控同一次 workflow：发布上下文 → 后端/客户端复验 → 后端备份与部署 → 生产探针 → iOS 签名归档 → TestFlight 上传并等待处理 → Tag/GitHub Release。
4. 成功条件必须同时满足：
   - 后端 health 连续通过，生产 dev token 为 `404`，最新 Flyway 为 `success=true`；若无后端改动，也必须跑生产探针。
   - App Store Connect 中 `com.yulinxi.app.DontLift` 的目标 version/build 处理状态为 `VALID`，且内部测试组已自动分发。
   - `vX.Y-bN` 指向已发布的 `main` 提交，GitHub Release 和两份发版文档可访问。
5. 最终回复必须给出 workflow、Tag/GitHub Release、checklist、功能介绍链接，并明确列出尚未由自动化覆盖的真机项目。

## 失败与恢复

- PR 门禁失败：不合并、不部署、不递增第二次 build；在同一 Release PR 修复。
- 后端构建或迁移前备份失败：停止，线上保持原状。
- 新后端未通过 health：自动恢复上一应用镜像并保留日志/备份；migration 只能前向修复，不执行 down migration。
- 后端成功但 iOS 上传失败：保持向后兼容的后端，修复后使用新 build；不得覆盖或复用失败 build。
- TestFlight 处理为 `FAILED/INVALID`：不打 Tag，保存 Apple 错误证据，修复后递增 build。
- Tag/GitHub Release 收尾失败：不得重跑部署和上传；只重跑幂等的 finalize 阶段。

## 硬性守则

- 不发布脏工作区、未提交提交或未通过 review 的代码。
- 不把 Apple `.p8`、Distribution `.p12`、Provisioning Profile、SSH 私钥写入仓库、日志或发版文档。
- 不自动接受破坏性数据库迁移、删除/重命名既有 API、关闭旧客户端兼容路径。
- 不以单次 `health=UP` 代替生产验收，不以“上传成功”代替 TestFlight 处理完成。
- HealthKit、Sign in with Apple、APNs 真投递、Live Activity/灵动岛、Widget 系统刷新等真机能力没有真实设备执行证据时，必须标为“未自动覆盖”；它们阻断 App Store 正式上架，但不伪造为 TestFlight 上传失败。
