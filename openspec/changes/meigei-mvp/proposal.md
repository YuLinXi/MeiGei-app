## Why

市面主流健身 App（训记、Keep、薄荷）要么把训练记录做得专业但社交薄弱，要么社交化但训练不够严肃。本项目面向「认真训练 + 有小圈子互相督促」的健身爱好者——他们需要一个极简而专业的训练记录工具，以及一个能让业余教练给三五好友发计划并彼此打卡鼓励的私密空间。MVP 的目标是验证「严肃工具 + 小圈子协作」这一组合是否成立。

> **范围调整（2026-06-01）**：饮食记录模块现阶段暂不做考虑，已从本 change 移出（原 `nutrition-tracking` capability、相关 tasks 与数据表设计一并删除）。MVP 聚焦训练记录 + Team 共享两大模块。

> **范围调整（2026-06-24）**：训练计划的严格 / 自适应模式、开始训练历史优先预填、训练完成后自适应回写与回写撤销，已由后续 `workout-tracking` 主规格纳入 1.0 能力。下方旧 Non-goal 中“不做训练计划的周期化/自适应、不做自动重量预填”仅代表初稿范围，不再作为当前验收依据；周期化计划仍不在 1.0 范围。

## What Changes

- 新建一个全新的 iOS 原生 App（iOS 17.4+）与配套 Java 后端，从零搭建。
- **账户与同步**：仅 Apple Sign-In 登录；建立离线优先的本地存储 + 自建云同步机制（不使用 SwiftData 的 CloudKit 自动同步）。
- **训练记录**：内置 150-200 个动作（无动图；部位高亮图已于 2026-06-10 移出 MVP 范围，留待后续单独立项）；单次训练模板；记录 重量×次数×组数 + 备注 + 组间休息计时器；训练日历、单动作历史曲线、PR 自动识别；训练完成写入 HealthKit；Live Activity 锁屏/灵动岛显示休息倒计时（并经配对 Apple Watch 的 Smart Stack 呈现，含 App Intent 按钮）。
- **Team 共享**：邀请码加入的私密小空间（每空间 ≤10 人，每用户 ≤3 个空间）；Owner（业余教练）+ Member 两角色；训练计划模板可被成员 Fork 为独立副本；训练即打卡、Team 内训练数据全员可见、4 个 emoji 表情回应；训练完成可生成海报分享到外部。

## Capabilities

### New Capabilities
- `account-sync`: Apple Sign-In 登录、用户身份三层模型、离线优先的本地存储与云同步、冲突处理、APNs 推送通道。
- `workout-tracking`: 动作库、训练计划模板、训练记录、历史与 PR 统计、休息计时器与 Live Activity、HealthKit 写入。
- `team-sharing`: 私密小空间与成员管理、计划模板发布与 Fork、训练打卡与可见性、表情回应、海报分享。

### Modified Capabilities
<!-- 全新项目，无既有 capability 被修改 -->

## Impact

- **新增代码库**：iOS App（SwiftUI / SwiftData / Swift Charts / ActivityKit / HealthKit）、Java 后端（Spring Boot 3.3 / MyBatis-Plus / PostgreSQL 16 / Flyway / Pushy）。
- **外部依赖**：Apple 开发者账号（Sign in with Apple、APNs、HealthKit、Live Activity 能力）、PostgreSQL、对象存储（头像）。
- **基础设施**：Docker 部署（Fly.io/Railway/国内云）、Sentry 监控、Cloudflare。
- **Non-goals（MVP 明确不做）**：
  - 不做 Android / Web / 独立 WatchKit App（Watch 仅靠 Live Activity 呈现）。
  - **不做饮食记录**：内置食材库、自定义食材、饮食日记、每日营养目标等现阶段暂不考虑，整体移出 MVP。
  - 不做 LLM、不做拍照识别。
  - 不做 WebSocket 双向长连接（实时性用 APNs 推送 + 进页面拉取实现）。
  - 不做训练计划的周期化，不做 RPE/RIR。严格 / 自适应模式、历史预填与训练后回写已由后续 `workout-tracking` 规格 supersede，属于当前 1.0 范围。
  - 不做 Team 内文字评论 / 群聊 / 私信（社交沟通走微信）、不做公开广场/计划商店、不做教练一对一定向分配计划。
  - 不做 Apple Sign-In 之外的登录方式（手机号/微信/邮箱）。
  - 不做复杂同步合并（冲突仅 last-write-wins + 人工提示）。
