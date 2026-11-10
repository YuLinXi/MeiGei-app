# UI / UX 设计 Skills 调研与 DontLift 适配建议

> 调研日期：2026-11-07。UE 在本文按 UX、用户体验和交互设计理解。证据级别：**源码审阅 / 未实装验证**。

## 结论与建议

对当前原生 iOS 项目，推荐组合是 **Impeccable 做原生界面审计与交互评审，UI/UX Pro Max 做可检索设计知识补充，SwiftUI 实现继续复用当前开发环境已有的 Build iOS Apps skills**。先针对一个现有流程评估，再决定是否引入外部 skill。热度与平台适配是两回事：本次候选中 UI/UX Pro Max、Taste Skill、Impeccable 的仓库关注度很高，但 Taste Skill 主要面向网站；SwiftUI 专用技能关注度较低，平台适配反而更直接。上述判断来自下表对应源码，尚无本项目实际效果对比。

不建议同时安装多个全能设计师 skill。若后续需要额外 SwiftUI 审阅能力，优先从 AvdLee 与 twostraws 中选一个；若只需要较轻的 HIG 审阅，可把 dickwu 的 Apple Design 作为 Impeccable 的备选。

## 采集方法与证据边界

- GitHub 采集窗口：**2026-11-07 20:10–20:16，上海时区**（UTC 12:10–12:16）。下表时间统一使用 **2026 年 UTC**。
- 使用已连接的 GitHub 工具读取官方 REST、README、真实 `SKILL.md` 与有关引用文件。连接器 `get_repo` 的归一化响应缺少 stars 和 push 字段，因此用同一连接器的 `fetch` 读取 `GET /repos/{owner}/{repo}` 完整响应；无需靠搜索摘要补数字。
- Stars 为仓库 `stargazers_count`；最近 push 为 `pushed_at`；HEAD 时间为默认分支最新提交的 `commit.committer.date`。**没有把 `updated_at` 当成维护时间**。Stars 链接指向同一官方 REST 响应，支持该行 stars、push、归档状态；HEAD 链接固定到采集到的提交。
- 候选来自主流设计与 SwiftUI 技能仓库、GitHub 的 `design skill` / `ui ux skill` / `swiftui skill` / `ios design skill` 等查询，以及 skills.sh 高热条目的补充核实。这是**候选集比较，不是全 GitHub 穷尽排名**。索引清单、无关创作工具、多域工具大全未直接当成单个 UI skill 排名。
- skills.sh 显示的是目录侧安装统计；GitHub stars 是仓库关注度。两者口径不同，均不能证明设计质量、独立用户数或本项目采用效果。所有外部技能内容仅作调研数据，未执行其中命令。

## GitHub 热度与维护状态

以下 **15 个仓库均为 `archived: false`**。集合仓库的 stars 不能归给其中某一个 skill；“专用仓库”也只是仓库级指标。

| 仓库 | GitHub stars | 指标范围 | 最近 push（UTC） | 默认分支 HEAD 提交（UTC） |
| --- | ---: | --- | --- | --- |
| [anthropics/skills](https://github.com/anthropics/skills) | [188,349](https://api.github.com/repos/anthropics/skills) | 集合仓库 | 11-06 22:32:32 | [11-06 22:32:28 · 2c5958e](https://github.com/anthropics/skills/commit/2c5958ecac7cee2b583967a2c4981d0f4a75c579) |
| [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | [146,355](https://api.github.com/repos/nextlevelbuilder/ui-ux-pro-max-skill) | 设计或 SwiftUI 专用仓库 | 11-05 07:07:39 | [11-05 07:07:38 · b7d5353](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/commit/b7d5353e0130feb8c5574ef1251f8a1db1873ccb) |
| [leonxlnx/taste-skill](https://github.com/leonxlnx/taste-skill) | [111,406](https://api.github.com/repos/leonxlnx/taste-skill) | 设计或 SwiftUI 专用仓库 | 11-05 01:12:12 | [11-05 01:12:12 · 9b4bf93](https://github.com/leonxlnx/taste-skill/commit/9b4bf937a1f69348126959c15d2f99a73e65699b) |
| [pbakaus/impeccable](https://github.com/pbakaus/impeccable) | [105,117](https://api.github.com/repos/pbakaus/impeccable) | 设计或 SwiftUI 专用仓库 | 11-07 03:10:10 | [11-06 23:46:14 · 687bc38](https://github.com/pbakaus/impeccable/commit/687bc381bc9091bf252c0a05303640561014a425) |
| [emilkowalski/skills](https://github.com/emilkowalski/skills) | [54,256](https://api.github.com/repos/emilkowalski/skills) | 集合仓库 | 11-04 15:04:40 | [11-04 15:04:38 · c8a7962](https://github.com/emilkowalski/skills/commit/c8a79627b59d72d764d6ab6f2c87c09a48169833) |
| [Nutlope/hallmark](https://github.com/Nutlope/hallmark) | [49,908](https://api.github.com/repos/Nutlope/hallmark) | 设计或 SwiftUI 专用仓库 | 11-05 13:16:31 | [11-05 13:16:31 · 407fa68](https://github.com/Nutlope/hallmark/commit/407fa689f4a276f2fd389208d271d0fef08f5058) |
| [wshobson/agents](https://github.com/wshobson/agents) | [42,273](https://api.github.com/repos/wshobson/agents) | 集合仓库 | 11-05 15:57:30 | [11-05 15:57:29 · 4bde316](https://github.com/wshobson/agents/commit/4bde3168b43c0655c4d00ea2726e631719908a6d) |
| [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) | [33,665](https://api.github.com/repos/vercel-labs/agent-skills) | 集合仓库 | 10-28 19:17:28 | [10-27 21:40:02 · 1a2c79d](https://github.com/vercel-labs/agent-skills/commit/1a2c79d4e6c4a2283dc2c614b6538cbe1ed5ca62) |
| [alchaincyf/huashu-design](https://github.com/alchaincyf/huashu-design) | [28,926](https://api.github.com/repos/alchaincyf/huashu-design) | 设计或 SwiftUI 专用仓库 | 11-04 03:28:47 | [11-04 03:28:45 · b2460b0](https://github.com/alchaincyf/huashu-design/commit/b2460b031c33ff32d2bf3b97263527daa231e4de) |
| [ibelick/ui-skills](https://github.com/ibelick/ui-skills) | [10,745](https://api.github.com/repos/ibelick/ui-skills) | 集合仓库 | 11-05 15:23:05 | [11-05 15:23:04 · 00db7d6](https://github.com/ibelick/ui-skills/commit/00db7d656719c399c091f3ea138c6f42a7fa4d98) |
| [twostraws/SwiftUI-Agent-Skill](https://github.com/twostraws/SwiftUI-Agent-Skill) | [6,491](https://api.github.com/repos/twostraws/SwiftUI-Agent-Skill) | 设计或 SwiftUI 专用仓库 | 10-26 16:53:18 | [10-26 16:53:18 · f2920b6](https://github.com/twostraws/SwiftUI-Agent-Skill/commit/f2920b63995263f57b3e198674e89a602efba6d2) |
| [Dammyjay93/interface-design](https://github.com/Dammyjay93/interface-design) | [5,933](https://api.github.com/repos/Dammyjay93/interface-design) | 设计或 SwiftUI 专用仓库 | 06-20 11:32:45 | [06-20 11:32:44 · 2f9be32](https://github.com/Dammyjay93/interface-design/commit/2f9be3206855bcb2d1d0af262c8bae25cba6658d) |
| [AvdLee/SwiftUI-Agent-Skill](https://github.com/AvdLee/SwiftUI-Agent-Skill) | [3,836](https://api.github.com/repos/AvdLee/SwiftUI-Agent-Skill) | 设计或 SwiftUI 专用仓库 | 11-06 08:39:49 | [11-06 08:39:42 · 62bd760](https://github.com/AvdLee/SwiftUI-Agent-Skill/commit/62bd760f005093d1e2e4de5db156e456a5f96400) |
| [dickwu/apple-design-skill](https://github.com/dickwu/apple-design-skill) | [2,939](https://api.github.com/repos/dickwu/apple-design-skill) | 设计或 SwiftUI 专用仓库 | 10-28 14:28:12 | [10-28 14:28:09 · ff4ebdd](https://github.com/dickwu/apple-design-skill/commit/ff4ebddf0488598723a82bfdce1afb04de0b1c44) |
| [designed-by-ai/skills](https://github.com/designed-by-ai/skills) | [28](https://api.github.com/repos/designed-by-ai/skills) | 设计或 SwiftUI 专用仓库 | 10-06 08:00:25 | [10-05 13:57:29 · 03c20ae](https://github.com/designed-by-ai/skills/commit/03c20aec6dcedb5fabfb03dc37982eb52ef19ed6) |

单个 skill 的维护节奏可能不同。例如：Anthropic 的 `frontend-design/SKILL.md` 最近变更为 [09-03](https://github.com/anthropics/skills/commit/41bbe19d1a1a7eaab5e7bb9050a417e5c6cffc8f)，wshobson 的两个目标 skill 为 [03-07](https://github.com/wshobson/agents/commit/47a5dbc3f9c2661c6afb13638f80d4a4d4449040)，Vercel 的 skill 入口为 [01-16](https://github.com/vercel-labs/agent-skills/commit/ba46938889d4e58635362fb8f618e1178ac3ec46)，但它会动态获取另一仓库的规则，入口文件日期不代表规则内容停止更新。Impeccable 的入口最近变更为 [10-26 的 v4.8.0](https://github.com/pbakaus/impeccable/commit/414603bf14c7a344edb466bb1f85690c77ce8b7d)。这些日期仅描述入口文件本身，不能代替整个引用树的维护判断。

## 单 skill 目录安装量：与 stars 分开看

下列为同日另行核对 skills.sh 页面得到的近似展示值；页内与首页存在轻微缓存差异，因此保留合理精度。

| 单 skill | skills.sh 展示 installs | 解读 |
| --- | ---: | --- |
| [design-mobile-apps](https://www.skills.sh/designed-by-ai/skills/design-mobile-apps) | 约 1.3M | 对应 Sleek 云端设计流程；不能从安装量推断原生 SwiftUI 支持 |
| [frontend-design](https://www.skills.sh/anthropics/skills/frontend-design) | 约 1.1M | 单 skill 目录指标；188,349 stars 则属于 Anthropic 整个集合 |
| [design-taste-frontend](https://www.skills.sh/leonxlnx/taste-skill/design-taste-frontend) | 约 744K | 主要面向网站 |
| [ui-ux-pro-max](https://www.skills.sh/nextlevelbuilder/ui-ux-pro-max-skill/ui-ux-pro-max) | 约 439K | 含 SwiftUI 指导，可作为补充 |
| [impeccable](https://www.skills.sh/pbakaus/impeccable/impeccable) | 约 391K | 当前源码已有真正的原生审计路径 |

安装量只覆盖已核对条目，不据此给全部候选排序。目录简介可能滞后；例如 UI/UX Pro Max 的平台范围按本次 GitHub 源码确认，不能引用目录旧简介代替。

## 实际 skill 路径、用途与项目适配

适配判断针对 **DontLift、SwiftUI、最低 iOS 17.4、现有纸感设计系统**，是基于源码的判断。

| 候选与实际入口 | 已核实用途 | 对 DontLift 的适配与限制 |
| --- | --- | --- |
| UI/UX Pro Max：[`.claude/skills/ui-ux-pro-max/SKILL.md`](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/blob/b7d5353e0130feb8c5574ef1251f8a1db1873ccb/.claude/skills/ui-ux-pro-max/SKILL.md) | 本地检索 UX、交互、色彩、排版及技术栈指导；支持 `--stack swiftui` | **推荐补充**。有真正的 SwiftUI 数据文件；通用入口仍混有 CSS、ARIA、GSAP 等 Web 规则，需限定平台和单一问题 |
| Impeccable：[`.agents/skills/impeccable/SKILL.md`](https://github.com/pbakaus/impeccable/blob/687bc381bc9091bf252c0a05303640561014a425/.agents/skills/impeccable/SKILL.md) | 规划、批评、审计、润色、文案、状态与适配；区分任务型 Operate 等模式 | **推荐首个评估**。v4.8.0 明确覆盖 native iOS；原生审计从源码进行，Web 检测器不适用 |
| Anthropic：[`skills/frontend-design/SKILL.md`](https://github.com/anthropics/skills/blob/2c5958ecac7cee2b583967a2c4981d0f4a75c579/skills/frontend-design/SKILL.md) | 视觉方向、排版、布局和自我批评 | 可借鉴设计思考，主要案例和实现规则是 Web/CSS；不是 SwiftUI/HIG 专项审计 |
| Vercel：[`skills/web-design-guidelines/SKILL.md`](https://github.com/vercel-labs/agent-skills/blob/1a2c79d4e6c4a2283dc2c614b6538cbe1ed5ca62/skills/web-design-guidelines/SKILL.md) | 获取最新 Web Interface Guidelines，逐文件给出规则问题 | **不作为原生主工具**。其[依赖规则](https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md)针对 HTML、ARIA、浏览器输入与 CSS |
| wshobson：[`plugins/ui-design/skills/mobile-ios-design/SKILL.md`](https://github.com/wshobson/agents/blob/4bde3168b43c0655c4d00ea2726e631719908a6d/plugins/ui-design/skills/mobile-ios-design/SKILL.md)；[`plugins/ui-design/skills/interaction-design/SKILL.md`](https://github.com/wshobson/agents/blob/4bde3168b43c0655c4d00ea2726e631719908a6d/plugins/ui-design/skills/interaction-design/SKILL.md) | 前者覆盖 HIG、SwiftUI 布局/导航/触控；后者讲微交互、反馈、动效 | 前者可用，但例子含 iOS 18+ 新 `Tab`，本项目不能直接无保护套用；后者主要提供 React/Framer Motion/CSS 代码，原则需翻译成 SwiftUI |
| AvdLee：[`skills/swiftui-expert-skill/SKILL.md`](https://github.com/AvdLee/SwiftUI-Agent-Skill/blob/62bd760f005093d1e2e4de5db156e456a5f96400/skills/swiftui-expert-skill/SKILL.md) | SwiftUI 状态、组合、布局、无障碍、性能、API 迁移及按主题引用 | **原生适配高，按需备选**。明确要求版本 gating，Liquid Glass 只在用户明确要求时采用；与现有三项 SwiftUI skill 高度重叠 |
| twostraws：[`swiftui-pro/SKILL.md`](https://github.com/twostraws/SwiftUI-Agent-Skill/blob/f2920b63995263f57b3e198674e89a602efba6d2/swiftui-pro/SKILL.md) | SwiftUI 正确性、导航、HIG、Dynamic Type、VoiceOver、性能与本地化审阅 | **原生适配高，按需备选**。有保留部署目标的规则；同时有“新 App 默认 iOS 27 / Swift 6.4+”的前提，不能移植为本项目升级要求 |
| ibelick：[`skills/baseline-ui/SKILL.md`](https://github.com/ibelick/ui-skills/blob/00db7d656719c399c091f3ea138c6f42a7fa4d98/skills/baseline-ui/SKILL.md) | 可访问组件、反馈、排版、动效约束 | 主要是 Tailwind、React primitives、ARIA 和浏览器性能；适合 Web，不能直接检查 SwiftUI |
| interface-design：[`.claude/skills/interface-design/SKILL.md`](https://github.com/Dammyjay93/interface-design/blob/2f9be3206855bcb2d1d0af262c8bae25cba6658d/.claude/skills/interface-design/SKILL.md) | 产品界面层次、密度、token、状态及设计记忆 | 产品思维可借鉴；实现部分偏 HTML/CSS/headless primitives，另建 `.interface-design/system.md` 易与现行规格产生第二套权威 |
| Taste Skill：[`skills/taste-skill/SKILL.md`](https://github.com/leonxlnx/taste-skill/blob/9b4bf937a1f69348126959c15d2f99a73e65699b/skills/taste-skill/SKILL.md) | 公司/产品网站的视觉方向、真实素材、布局与浏览器检查 | **不用于原生主流程**。需要 Node 22+ 和 Chromium 系浏览器，产物与检查围绕 HTML/CSS 网站 |
| Emil：[`skills/emil-design-eng/SKILL.md`](https://github.com/emilkowalski/skills/blob/c8a79627b59d72d764d6ab6f2c87c09a48169833/skills/emil-design-eng/SKILL.md)；[`skills/apple-design/SKILL.md`](https://github.com/emilkowalski/skills/blob/c8a79627b59d72d764d6ab6f2c87c09a48169833/skills/apple-design/SKILL.md) | 设计工程、动效时机、弹簧、拖动、打断和反馈 | 动效原则可参考；`apple-design` 明写“translated for the web”，[`mobile-native`](https://github.com/emilkowalski/skills/blob/c8a79627b59d72d764d6ab6f2c87c09a48169833/skills/mobile-native/SKILL.md)也用于 Web/PWA，不是原生 SwiftUI skill |
| Hallmark：[`skills/hallmark/SKILL.md`](https://github.com/Nutlope/hallmark/blob/407fa689f4a276f2fd389208d271d0fef08f5058/skills/hallmark/SKILL.md) | 网站主题方向、构图、素材与真实浏览器 lint | 高热补充候选；主要面向新网站，脚手架写 `tokens.css` / `base.css`，不适合直接接入原生 App |
| Huashu：[`SKILL.md`](https://github.com/alchaincyf/huashu-design/blob/b2460b031c33ff32d2bf3b97263527daa231e4de/SKILL.md) | HTML 高保真原型、演示、动画、可视化与评审 | 可做独立原型沟通；不能把 HTML 原型验收当成 SwiftUI 实现验证，三方向流程也不适合每次局部修复 |
| dickwu Apple Design：[`SKILL.md`](https://github.com/dickwu/apple-design-skill/blob/ff4ebddf0488598723a82bfdce1afb04de0b1c44/SKILL.md) | 以 HIG 引用做无障碍、平台规范、视觉、交互和内容审阅，明确支持 SwiftUI/UIKit | **较轻的原生审阅备选**。不是 Apple 官方工具；其静态 HIG 摘录仍需按当前 Apple 文档复核 |
| Sleek：[`skills/design-mobile-apps/SKILL.md`](https://github.com/designed-by-ai/skills/blob/03c20aec6dcedb5fabfb03dc37982eb52ef19ed6/skills/design-mobile-apps/SKILL.md) | 调用 Sleek API 生成/编辑屏幕，获取 HTML 与渲染图 | **不作为本项目首选**。需要账号、`SLEEK_API_KEY`；[实现引用](https://github.com/designed-by-ai/skills/blob/03c20aec6dcedb5fabfb03dc37982eb52ef19ed6/skills/design-mobile-apps/implementing.md)重点是 HTML 与 React Native/Expo，缺少同等深度的 SwiftUI 实现路径 |

### 对推荐组合的进一步核实

**Impeccable：用于审计和判断。** [原生审计引用](https://github.com/pbakaus/impeccable/blob/687bc381bc9091bf252c0a05303640561014a425/.agents/skills/impeccable/reference/audit.native.md)明确针对 SwiftUI/UIKit 等源码，从无障碍、性能、外观、平台一致性和适配性给出发现；明确不使用 browser tooling 或 `impeccable detect`。[iOS 引用](https://github.com/pbakaus/impeccable/blob/687bc381bc9091bf252c0a05303640561014a425/.agents/skills/impeccable/reference/ios.md)包含 44×44pt、Dynamic Type、SF Symbols、安全区和边缘返回。源码审计能发现风险，不能证明 VoiceOver、手势或真实触控已经通过。当前入口有 **24 个命令项，包含已弃用的 `craft` 别名**，无需沿用早期“17/18 个技能”的介绍。

**UI/UX Pro Max：用于查知识，不生成第二套品牌。** 当前入口列出 22 个技术栈；[实际 SwiftUI 数据](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/blob/b7d5353e0130feb8c5574ef1251f8a1db1873ccb/src/ui-ux-pro-max/data/stacks/swiftui.csv)涵盖状态、Observation、布局、导航、无障碍等，数据标注 iOS 16+ baseline、Observation iOS 17+。建议针对“紧凑输入反馈”“空状态”“中断/取消交互”等明确问题检索，并使用 `--stack swiftui`；不因安装此 skill 就运行全新配色/字体生成或持久化另一份 MASTER。其 SwiftUI 内容仍需经过项目版本和现有组件约束审查。

**SwiftUI 实现：优先复用已可用工具。** 当前开发环境已通过 Build iOS Apps 插件提供 `build-ios-apps:swiftui-ui-patterns`、`swiftui-performance-audit`、`swiftui-view-refactor`，分别覆盖组件/导航/状态、代码优先性能分析、视图结构与 Observation。无需为获得这些能力再装两个 SwiftUI 全能包；这些插件提供的技能不套用任何外部 GitHub stars。

## 已核实的安装入口：仅供后续选择，未执行

| 工具 | 官方文档给出的方式 | 前提与范围 |
| --- | --- | --- |
| Impeccable | `npx impeccable install`，见 [官方 README](https://github.com/pbakaus/impeccable/blob/687bc381bc9091bf252c0a05303640561014a425/README.md) | 安装器会选择项目/全局与 provider；不只是 Markdown，会使用附带或首次下载的 engine，也可配置 hook |
| UI/UX Pro Max | `npm install -g ui-ux-pro-max-cli`，然后在项目中 `uipro init --ai codex`，见 [官方 README](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/blob/b7d5353e0130feb8c5574ef1251f8a1db1873ccb/README.md) | 当前 npm 包名是 `ui-ux-pro-max-cli`，不是旧 `uipro-cli`；搜索脚本依赖 Python 3 标准库。[Codex 配置](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/blob/b7d5353e0130feb8c5574ef1251f8a1db1873ccb/cli/assets/templates/platforms/codex.json)的目标为 `.agents/skills/ui-ux-pro-max` |
| AvdLee（备选） | `npx skills@latest add https://github.com/avdlee/swiftui-agent-skill --skill swiftui-expert-skill`，见 [官方 README](https://github.com/AvdLee/SwiftUI-Agent-Skill/blob/62bd760f005093d1e2e4de5db156e456a5f96400/README.md) | 只在现有 SwiftUI 工具无法覆盖需求时选择 |
| twostraws（备选） | `npx skills add https://github.com/twostraws/swiftui-agent-skill --skill swiftui-pro`，见 [官方 README](https://github.com/twostraws/SwiftUI-Agent-Skill/blob/f2920b63995263f57b3e198674e89a602efba6d2/README.md) | 与 AvdLee 二选一；明确保持本项目部署目标和工具链 |
| dickwu（备选） | `npx skills add dickwu/apple-design-skill -a codex`，见 [官方 README](https://github.com/dickwu/apple-design-skill/blob/ff4ebddf0488598723a82bfdce1afb04de0b1c44/README.md) | 与 Impeccable 原生审阅有重叠；不要和 Emil 的同名 `apple-design` 直接混装 |

这些命令是“官方文档中的已核实入口”，不是本机安装成功记录。Impeccable 当前已有 CLI、engine、hook 和 live browser 功能；[launcher 源码](https://github.com/pbakaus/impeccable/blob/687bc381bc9091bf252c0a05303640561014a425/.agents/skills/impeccable/scripts/impeccable)会处理本地 engine 与下载。对本项目的原生审计，live browser 和 Web detector 不提供原生验证价值，无需顺带引入。README 所述 live Apply 还可能启动本机 agent CLI，因此实际采用时应按所需能力选择安装范围。

Sleek 的目录热度还存在来源核实点：[官方 README](https://github.com/designed-by-ai/skills/blob/03c20aec6dcedb5fabfb03dc37982eb52ef19ed6/README.md)安装示例指向另一个 `sleekdotdesign/agent-skills` 仓库及 `sleek-design-mobile-apps` 名称，而本次审阅文件的 frontmatter 是 `design-mobile-apps`。本文不把这个不一致的命令当作已验证安装方案，也没有执行账号授权或付费流程。

## 接入前先统一项目设计上下文

当前可靠约束来自 [现行 design-system 规格](../openspec/specs/design-system/spec.md)、[实际 Theme 颜色](../ios/DontLift/DontLift/DesignSystem/Theme+Color.swift) 和 [Xcode 部署目标](../ios/DontLift/DontLift.xcodeproj/project.pbxproj)：纸白底、近黑文字、朱砂红单点强调，最低 iOS 17.4。保留已有 `Theme.*`、`paperToolbar`、纸感组件和训练/Team 业务语义。

但 [DesignSystem/README.md](../ios/DontLift/DontLift/DesignSystem/README.md) 头部仍写 Neon Techwear、强制深色、`accentCyan` / `accentMagenta` / `neonGlow`，与现行规格和实现冲突。**建议先另开一项文档修正，把旧设计说明统一，再让新 skill 自动提取设计上下文**；本文只记录发现，没有修改该文件。

后续使用时给出统一任务边界：

> DontLift 是训练记录与 Team 共享工具，原生 SwiftUI，最低 iOS 17.4。此次只评审指定流程并列出问题；保持现有纸感 Theme tokens、导航组件与业务行为。按当前规格和实现判断，旧 DesignSystem README 的霓虹/深色说明已过时。只提出有源码或界面证据的问题；不自动更换品牌，不提高部署目标，不强制采用 iOS 26+ Liquid Glass；把静态发现与实际交互验证分开。

Impeccable 的通用 iOS 引用要求深色模式、系统颜色和系统文字样式，但本项目当前规格明确是浅色纸感主题；应报告真实可访问性问题，不直接把品牌浅色和 token 的存在判成缺陷。新 API 需逐项核对 availability；AvdLee 明确把 Liquid Glass 限定为用户主动要求，不能从工具介绍反推项目必须升级。

## 建议的最小评估任务

先选一条实际路径，例如“进入训练 → 记录一组重量/次数 → 休息 → 结束确认”或“加入 Team → 空状态 → 查看共享记录”。让 Impeccable 给出带文件位置、影响和建议的只读报告，再针对其中一个问题用 UI/UX Pro Max 查可适用的 UX/SwiftUI 指导；实现阶段才调用现有 SwiftUI skill。

采用标准应是：找出可复现、与本项目相关的问题，建议能沿用现有 token/组件，修改后目标交互更清楚；不要用生成截图更花哨或安装量更高作为验收。真正实施时按 [项目验证规则](../AGENTS.md) 选择最小充分检查；本次只有文档和源码审阅，**未安装、未编译、未运行单元/UI/E2E 测试、未启动模拟器或后端、未做真机验收，也未验证任何候选在 DontLift 中的实际改善效果**。
