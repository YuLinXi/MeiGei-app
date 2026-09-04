# profile-ui Specification Delta

## ADDED Requirements

### Requirement: 成就徽章概览卡片与二级徽章馆导航

`ProfileView` SHALL 在「总训练」统计卡片下方渲染「成就勋章」概览入口卡片：
- **视觉排布**：采用白底纸感卡片（`Theme.Color.surface`）与 `Theme.Color.border` 描边；左侧为奖章图标 + 大字「成就徽章」，右侧显示 `已解锁 {count} / 24 >`；
- **展示前置图腾**：卡片内部水平平铺展示最新获得的 4~5 枚已解锁徽章微缩图；
- **点击交互**：点击整卡导航进入全屏二级「成就徽章馆（Badge Wall）」。

#### Scenario: 渲染成就徽章概览卡
- **WHEN** 用户进入「我的」Tab
- **THEN** 在总训练统计卡下方呈现「成就徽章」概览卡，清晰呈现已解锁数（如 `8 / 24`）与最近获得的徽章图标。

#### Scenario: 点击进入二级徽章馆
- **WHEN** 用户点击成就徽章概览卡
- **THEN** 导航进入二级「成就徽章馆」，以 3 列网格展示全量 24 枚徽章。
