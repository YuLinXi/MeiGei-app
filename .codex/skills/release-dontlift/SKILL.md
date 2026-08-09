---
name: release-dontlift
description: 为《别练了》（DontLift）准备、核验、执行和收口 iOS TestFlight 与后端生产发版。用于用户要求盘点本次上线功能、判断是否需要后端部署、递增版本或 build、生成发版 checklist 与功能介绍、运行发布门禁、部署后端、上传 TestFlight、完成真机回归、合并 main、创建发布 tag，或更新既有发版记录时。
---

# 发布《别练了》

在仓库根目录工作。先阅读根目录 `AGENTS.md`，以其中当前发版约定为最高优先级；历史发版文档只作为格式和操作证据，不覆盖最新规则。

## 先确定任务边界

区分用户当前要求：

- “盘点、检查、生成清单、准备发版”：只做只读探查、文档生成和本地验证，不部署、上传、提交、推送、合并或打 tag。
- “执行、完成、发布上线”：可执行用户明确授权范围内的状态变更；生产部署、TestFlight 上传、合并 `main` 和 tag 仍必须满足各自门禁。
- “更新发版记录”：只回填已有事实，不把待办、推测或仅本地通过写成已完成。

发现脏工作树时保留全部既有改动。先区分已提交候选、已跟踪未提交改动和未跟踪文件；不要擅自暂存、提交、清理或把所有本地文件默认为本次发版范围。

## 1. 锁定发布基线与候选范围

先核对真实 Git 根、分支、远端、工作树和 tag：

```bash
git rev-parse --show-toplevel
git status --short
git branch --show-current
git remote -v
git tag --merged HEAD --sort=-version:refname | rg '^v[0-9]+\.[0-9]+-b[0-9]+$' | head -1
```

以最近一个已经完成 TestFlight/生产发布并打 tag 的版本为基线。不得用分支起点、单个 commit、未发布 build 或 `main` 的任意位置代替。若 tag 与历史发版记录无法证明其已发布状态，先向用户确认。

分别检查基线到 `HEAD` 和当前工作树，避免遗漏本地候选或把中间实现写进发布说明：

```bash
git log --oneline --decorate <baseline>..HEAD
git diff --name-status <baseline>...HEAD
git diff --name-status
git status --short
```

逐项读取真实实现、相关 OpenSpec proposal/spec/tasks 和测试。按最终用户行为合并同一功能的多次调整。将结果分为：

1. 用户可感知新增与优化；
2. 仅当问题在基线版本真实存在时才可称为“修复”；
3. 后端、迁移、同步、兼容和重构等内部技术变化；
4. 尚未提交、未完成或未验证的候选，不得写成已上线事实。

## 2. 确定版本与发布文件

从 `ios/DontLift/DontLift.xcodeproj/project.pbxproj` 读取所有 target 的 `MARKETING_VERSION` 与 `CURRENT_PROJECT_VERSION`。主 App、widget extension 和测试 target 必须保持一致。不要复用已经上传到 App Store Connect 的 build 号；若上传失败或真机发现阻塞问题，递增 build。

每次发版创建或更新以下两份简体中文文档：

```text
docs/release-<version>-b<build>-checklist.md
docs/release-<version>-b<build>-feature-intro.md
```

Checklist 至少包含：

- 版本、基线、候选分支、当前状态和发布顺序；
- 已完成准备与仍未完成门禁；
- 后端是否需要部署及判断证据；
- iOS Archive/TestFlight 上传步骤；
- 按本次差异生成的真机回归路径；
- 合并、tag、回滚和发布记录回填项。

功能介绍至少包含：

- 版本与状态：版本号、build、后端部署状态、iOS 上传状态；
- 一句话摘要；
- 面向测试用户的更新说明；
- 内部技术变更；
- 兼容性说明；
- 已完成验证；
- TestFlight 回归重点。

两份文档互相链接。状态必须使用当前事实：未执行写“待执行”，未通过写“未通过”，无法验证写明原因。不要复制上一版本的测试数量、迁移版本、时间、commit 或设备信息。

## 3. 判断后端是否需要发布

比较基线、`HEAD` 与工作树中的 `backend/` 改动并追踪 iOS 契约依赖：

- 后端运行时代码、配置、API、数据库迁移、容器或生产部署内容改变：通常需要部署，记录预期 Flyway 版本和兼容顺序。
- 只有 `backend/src/test/` 变化，且生产代码和迁移均未变化：不需要部署；在文档中写明这是契约验证，不是服务更新。
- iOS 只在既有 workout JSON 中增加向后兼容字段，后端保持透明透传：核对同步测试后可判定无需部署。
- 无法证明旧客户端兼容或新版依赖已上线 API：停止发布排序判断，先完成契约核对。

无后端更新时仍执行生产只读健康检查，并记录现有 Flyway 最新成功版本。需要更新时，先完成候选提交、推送、数据库备份确认和部署范围复核；只使用：

```bash
cd backend
./deploy/release-update.sh
```

不要在服务器直接 `git pull`，不要用会覆盖共享基础设施的 `local-deploy.sh`，不要打印或修改密钥。部署后至少验证：连续 health=`UP`、预期 Flyway `success=true`、生产 dev token=`404`、`/privacy` 与 `/terms`=`200`、启动日志无持续错误。记录部署 commit、时间、备份位置和迁移结果。

## 4. 执行本地发布门禁

根据改动范围运行最小但完整的发布验证，并保存真实结果。

后端在 `backend/` 下使用仓库 Gradle wrapper 和 JDK 21：

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
./gradlew clean build
./gradlew test --rerun-tasks
```

iOS 在 `ios/DontLift/` 下验证 build 与 tests：

```bash
xcodebuild -project DontLift.xcodeproj -scheme DontLift \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build

xcodebuild test -project DontLift.xcodeproj -scheme DontLift \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```

同时执行：

- `git diff --check`；
- 对本次相关 active OpenSpec change 逐个运行 `openspec validate <change> --strict`；
- 对功能差异执行真实 Simulator 路径回归，区分自动测试与人工 UI 验收；
- 若动作图或动作库资源有变化，遵循项目 `produce-exercise-artwork` skill 的发布校验，并至少运行静态资源 `validate`、`coverage` 与真实动作库路径检查。

任何命令没有实际运行或没有通过，都不得写成已通过。已知的既有 warning 与本次新增失败分开报告。

## 5. 上传 TestFlight 与真机回归

只有本地门禁通过、版本号一致、候选范围冻结后才进入 Archive。使用 Xcode 标准流程，不手写或替换 `.xcodeproj`：

1. 打开 `ios/DontLift/DontLift.xcodeproj`，选择 `DontLift` 与 `Any iOS Device (arm64)`；
2. 核对 App、widget 的签名、App Group 和 Push Notifications entitlement；
3. 执行 `Product -> Archive`；
4. 在 Organizer 中执行 `Distribute App -> App Store Connect -> Upload`；
5. 等待 App Store Connect 状态为 `VALID` 且 TestFlight 可安装；
6. 按 checklist 在真机回归本次功能、Apple 登录、冷启动、同步、Team、Live Activity、通知、HealthKit 和 widget 等受影响主路径。

若当前环境不能代表用户执行签名、上传或真机操作，明确保留为用户门禁，不声称已完成。用户确认结果后，回填准确时间、设备/iOS 版本、结论和已知问题。

## 6. 合并、Tag 与发布收口

仅在以下条件全部满足后合并 `main` 并创建 tag：

- 必要的后端生产部署及兼容验证完成；若无需部署，生产健康检查完成；
- TestFlight 对应 build 已为 `VALID`、可安装；
- 真机主流程回归通过，阻塞问题清零并由用户确认；
- 候选分支、版本号和两份发版文档已推送，最终范围无遗漏；
- 合并后相关门禁重新通过。

Tag 使用 `v<version>-b<build>`，优先创建 annotated tag：

```bash
git tag -a v<version>-b<build> -m "TestFlight 发版：<version> (build <build>)"
git push origin v<version>-b<build>
```

未满足门禁时明确写“不要打 tag”。不要把 TestFlight 上传成功等同于真机验收完成。最后回填 checklist 与功能介绍中的后端、TestFlight、回归、`main` 合并、tag 和完成时间。

## 交付格式

最终回复必须同时提供 checklist 与功能介绍的可点击链接，并简要列出：

- 本次最终用户功能；
- 是否涉及后端部署及证据；
- 已通过验证与未完成门禁；
- 当前 TestFlight、`main` 与 tag 状态；
- 下一步需要用户完成的操作。

只有实际完成的 Git 操作才报告为已提交、已推送、已合并或已打 tag。
