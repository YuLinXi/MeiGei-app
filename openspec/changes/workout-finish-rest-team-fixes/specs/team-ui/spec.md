## ADDED Requirements

### Requirement: 删除训练后今日动态一致性

当一条已打卡的训练记录被删除并同步成功后，Team 今日动态 Feed MUST 反映该动态的移除——不得继续展示已删除训练对应的打卡。后端在 workout 墓碑同步时已级联撤销对应 checkin；`TeamDetailView` MUST 在本端「同步完成」后重新拉取 checkins 以反映该移除，并 SHALL 在场景回到前台时兜底刷新。

刷新触发 MUST 绑定「同步完成」事件而非「删除动作」瞬间：删除为离线 `pendingDelete`，须等下一次同步 push 成功、后端撤销 checkin 后再拉取，方能避免拉回尚未撤销的旧动态。

#### Scenario: 删训练后动态消失
- **WHEN** 用户停留在 Team 详情页，于训练 tab 删除一条已打卡训练，随后同步完成
- **THEN** 该 Team 的今日动态 Feed 自动重新加载并不再显示该条动态，无需用户手动下拉刷新

#### Scenario: 同步未完成前不误刷
- **WHEN** 删除已发生但尚未同步到后端（仍为 `pendingDelete`）
- **THEN** Team Feed 不因「删除动作」本身提前刷新而拉回旧动态；待同步完成后再反映移除

#### Scenario: 回前台兜底刷新
- **WHEN** 删除并同步在 App 处于后台期间完成，用户随后将 App 切回前台并停留在 Team 详情页
- **THEN** Team Feed 兜底重新加载，反映该动态的移除
