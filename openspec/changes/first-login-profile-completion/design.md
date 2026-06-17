## Context

Apple Sign In 是本 App 唯一登录方式：协议层**不返回性别**，**姓名仅首次授权返回一次且可为空**（中转邮箱 / 隐藏姓名 / 重装静默登录都拿不到）。现状：

- 后端 `app_user` 仅有 `display_name` / `first_login_email`；`user_identity` 存 Apple `sub` / `email`（身份三层已就位）。`AccountController` 只有 `DELETE` / `GET deletion-impact`，**无 profile 读写接口**。`AuthResponse` 已带 `newUser` 布尔但 iOS 仅解析未使用。
- iOS `UserProfile`（SwiftData，纯本地）有 `displayName` / `email` / `sex: BodySex = .male`；`sex` 注释明确「纯本地、不参与云同步」，仅用于切肌群高亮图底图。
- 登录后 `RootView` 直接进 `MainTabView`，无 onboarding。`sex` 默认男 → 女性用户手动改前肌群图渲染错误。
- `ProfileView` header 称呼只展示不可编辑；副标当前为「训练龄」（由最早一条 `Workout` 推算），本次改为加入月份 + 已记录次数。

本设计新增首登补全门控，把 Apple 给不了的称呼 / 性别收齐并落后端，作为账号资料的服务端权威真相。

## Goals / Non-Goals

**Goals:**
- 首登强制补全称呼（必填）、性别（必填、默认男），持久化到后端 `app_user`。
- 以**后端画像称呼是否为空**判定是否补全（中途杀 App 不漏人），不依赖 `newUser`。
- Profile 用**服务端权威 REST**承载（`GET /me` + `PATCH /account/profile`），登录回灌、支持重装 / 多设备读回。
- 合并 `sex` 语义为「资料 + 顺带切图」单一字段，提升为后端存储。

**Non-Goals:**
- 不引入多档性别（MVP 仅男 / 女，对齐肌群图 SDK 体型）。
- 不把 Profile 改造成 LWW 同步实体（无信封 / 墓碑）。
- 不在 Team 队友资料展示性别（超出本次范围）。
- 不在本设计定 iOS 像素级视觉——交 OpenDesign 高保真稿。

## Decisions

### 决策 1：Profile 走服务端权威 REST，不进 LWW 同步域
账号资料是单一真相、极少并发冲突、需登录即时回灌，天然适合服务端权威（与 `team` 同类），而非离线优先的 LWW 同步实体。
- **读**：`GET /me` 返回完整画像（`userId/displayName/sex/email`），供登录回灌与门控判定。做成「完整画像」而非单字段补丁，给后续画像字段留扩展位。
- **写**：`PATCH /account/profile`（**带幂等键**，遵守 Day-1 写接口铁律）部分更新，缺省字段不动。
- **iOS**：`UserProfile` 仍本地即时落盘（离线可读），保存时乐观本地写 + 异步 PATCH，失败静默重试；**不**加入 `SyncEngine` push/pull、**不**加同步信封字段。
- **Alternatives**：塞进现有同步域 → 需补 `serverId/updatedAt/deletedAt/version` 信封 + 软删墓碑 + LWW 合并，对一条几乎不冲突的账号记录是过度工程，弃。

### 决策 2：以「后端称呼为空」判定补全，不用 `newUser`
`AuthResponse.newUser` 在「首登进补全页 → 未提交即杀 App → 再登录 newUser=false」时漏人。
- **方案**：登录后拉 `GET /me`，`displayName` 为空 = 未补全 → `RootView` 路由到补全页；非空 → 进主 App。判定的唯一真相在服务端，重装 / 换设备一致。`newUser` 仅保留作辅助（如预填埋点）。
- **Alternatives**：UserDefaults 存「已看过补全卡」→ 重装 / 换设备丢失、与服务端脱节，弃。

### 决策 3：性别语义合并，不另开列；后端 sex 可空
现有 `sex` 仅本地切图。本次不新增 `gender` 列，直接把 `sex` 提升为后端字段，一字段两用（资料 + 切图）。
- 后端 `app_user.sex text check (sex in ('male','female'))`，**可空、不设默认**。null = 从未设置，区别于「显式选了男」。这样 `GET /me` 回灌时 null → 客户端保留本地值，避免服务端默认 `male` 覆盖存量用户本地已选的女（否则需引入一次性迁移标记才能避免 clobber，过度复杂）。
- iOS `UserProfile.sex` 保持非空（默认男，纯展示用）；回灌规则：服务端 `sex` 非空才覆盖本地，为空则保留本地。补全页 / 我的页编辑时显式提交 `sex`，提交后服务端即非空。
- 「是否补全」由称呼判定，与 sex 可空性无关。

### 决策 4：不采集训练资历 / 训练年限
产品决定不采集训练资历（年限）。后端不加相关列、PATCH/GET 不含该字段；我的页 header 副标由「训练龄」改为「加入于 {createdAt:yyyy.MM} · 已记录 {总训练次数} 次」，移除从 Workout 推算训练龄的展示逻辑。

### 决策 5：称呼预填与降级
补全页称呼优先用 Apple `credential.fullName`（仅首登有）预填；为空则留空且必填，强制输入，避免 Team 出现「已登录」占位名。校验：去空白后 1–20 字符。

### 决策 6：iOS 设计先行
补全页 / 我的页编辑入口的 UI 先经 OpenDesign 出高保真稿（复用 `meigei-c-login` / `meigei-c-profile-v2` token），用户确认后再写 SwiftUI。apply 时后端 + 数据契约可先行，iOS UI 待稿定。

### 决策 7：删除重装 = 干净重来（修复「重装后跳过 Apple 登录却又要求输名字」）

**现象**：用户首登 Apple + 补全称呼后，删除并重装 App，重装冷启动直接跳过 Apple 登录、却又弹出补全页要求输名字。

**根因**：iOS 三种存储在「删除重装」时存活性不一致——

```
删除重装后：  Keychain(JWT) ✅存活   SwiftData(本地画像) ❌清空   UserDefaults(pending/水位) ❌清空
```

`SessionStore.init()` 把「Keychain 有 token」直接当「已登录」（`isLoggedIn = token != nil`）且**从不校验 token 有效性** → 跳过 Apple 登录；随后 `refreshProfile()` 的兜底把「`GET /me` 失败」**误判为「用户没填过名字」**（`localDisplayNameMissing()`，而 SwiftData 已清空故必为空）→ 弹补全页。两者叠加即本 bug。若那个存活的 JWT 已过期（TTL 90 天），还会升级为**死锁**：补全页无任何「退出 / 换账号」出口，提交 PATCH 同样 401，永久卡死。

**方案（选定 A：重装重来）+ 三条地基**：

1. **重装首启清孤儿 token（方案 A 主体）**：用 UserDefaults 哨兵位（如 `hasLaunchedBefore`）判定「重装 / 全新安装首启」——UserDefaults 随重装清空、Keychain 不清空，故「哨兵缺失」恰等价于「重装首启」。此时 MUST 先清掉残留 Keychain JWT 再判登录态，使重装后回到登录页、重新 Apple 登录（Face ID 一下即可，名字随登录后 `GET /me` 正常回填，不再误弹补全页）。
2. **地基·全局 401 → 登出**：任何 REST 收到 401（token 失效 / 过期）MUST 触发 `SessionStore.logout()` 回登录页，消灭「token 在但全请求 401」的幽灵态。
3. **地基·补全页逃生口**：`ProfileCompletionView` MUST 提供「退出登录 / 换账号」出口，作为任何异常态的兜底逃生，杜绝硬门死锁。
4. **地基·区分「拉取失败」与「确认无名字」**：`refreshProfile()` 在 `GET /me` **失败**（网络 / 401 / 超时）时 MUST NOT 置 `needsProfileCompletion = true`；应停在 `loadingGate` 重试，仅在**成功**拿到响应且称呼确为空时才判定需补全。把「拿不到服务端数据」错判成「该补全」是本 bug 的逻辑根因。

- **为何不选 B（重装保持登录）**：B 需校验 token 有效性 + 全套防护才不致幽灵态，逻辑面更大；且用户心智模型是「删了就重来」，Apple 登录摩擦极低、重装频率低，A 更简单且直接消灭幽灵态。但地基 2/3/4 与 A/B 无关，**无论如何都要做**（防御任何使失效 token 进补全页的路径）。
- **判定不变**：是否补全仍以「后端称呼为空」为唯一真相（决策 2），本决策只是修正「拉取失败」的兜底分支与重装时的孤儿登录态，不改判定口径。

## Risks / Trade-offs

- [`GET /me` 增加一次登录后往返] → 轻量只读、可与首屏并行；离线时用本地 `UserProfile` 兜底渲染，门控延迟到联网后校正（离线首登极少见，且 Apple 登录本身需联网）。
- [移除训练龄展示后 header 信息量下降] → 改为「加入于 {月份} · 已记录 {n} 次」，仍提供有意义的资历感，且无字段过期问题。
- [与已归档 `profile-account-deletion-and-prefs` 的我的页编辑分组重叠] → 沿用其 `groupCard` 范式，性别行原地升级语义而非新建；归档前查同一 requirement 是否被多 change 改动（见 memory「归档 sync 重叠坑」）。
- [强制补全增加首登摩擦] → 一屏、称呼预填、性别一点即选、资历可跳过，控制在数秒内。
- [收集性别的 App Store 隐私合规] → 性别用于肌群图体型属功能必要，隐私说明如实声明用途，仅男 / 女两档。
- [重装清 token 让重装后必重新 Apple 登录（决策 7）] → 与用户心智模型一致；Apple 登录 Face ID 一下即可，重装频率低，摩擦可接受；换来幽灵态 / 死锁的彻底消除。
- [哨兵位若误判（如系统异常重置 UserDefaults 但 Keychain 仍在）会多要一次登录] → 退化结果仅是「多登一次」，不丢数据（画像在后端、训练数据走同步域），可接受。

## Migration Plan

1. 后端先行：`V3__profile_fields.sql` 加 `sex`（可空、无默认）；上线 `GET /me` + `PATCH /account/profile`。
2. iOS：`UserProfile.sex` 纳入回灌；`SessionStore` 登录后拉 `GET /me` 回灌并以服务端为准；实现补全页 + `RootView` 门控 + 我的页「个人资料」分组（称呼行内编辑 + 性别）。
3. 存量用户（称呼从未填过）下次登录 `GET /me` 称呼为空 → 拦补全页补齐；本地 `sex` 默认值随首次 PATCH 回填后端，平滑迁移。
4. 回滚：后端两列向后兼容（sex 有默认、year 可空），回滚 App 端不影响后端；必要时关闭门控即可降级（字段仍可在我的页编辑）。

## Open Questions

- ~~开始训练年份输入控件形态~~ —— 训练资历已取消采集，不适用。
- 称呼编辑形态 —— OpenDesign 稿已定：在「个人资料」分组内行内编辑（非顶部、非弹层）。
