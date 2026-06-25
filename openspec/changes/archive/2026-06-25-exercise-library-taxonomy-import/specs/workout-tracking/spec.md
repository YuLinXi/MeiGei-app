## MODIFIED Requirements

### Requirement: 动作库（ExerciseLibrary）版式

`ExerciseLibraryView` SHALL 顶部依次渲染：导航栏（标题「动作」+ 右上 `+` 添加按钮）、搜索框（占位「搜索 {N} 个动作」，N=内置+自定义合计）、**双轴筛选**——部位轴（`ExerciseCategory` 细分父级，左栏或可滚动呈现，**有子分类的父级可展开二级**）× 器械轴（`EquipmentType` 顶部 `HorizontalChipPicker`）。两轴 MUST 正交叠加筛选。下方为动作列表，每个动作行 SHALL 显示 thumb（emoji 或部位图占位）+ 双语名（中文粗体 + 英文 muted）+ 右侧最新 PR 副标。配图 MUST 沿用别练了自绘纸感风格，MUST NOT 引入第三方写实解剖线稿。

#### Scenario: 数据库空
- **WHEN** 内置动作 0 条且自定义 0 条
- **THEN** 列表渲染单张占位卡「动作库尚未采集，点右上 + 添加自定义动作」+ CTA。

#### Scenario: 双轴正交筛选
- **WHEN** 用户在部位轴选「胸」、器械轴选「哑铃」
- **THEN** 列表过滤为 `category` 命中「胸」**且** `equipmentType == "哑铃"` 的动作；任一轴留「全部」则该轴不约束。

#### Scenario: 子分类展开收窄
- **WHEN** 用户选中有子分类的父级「胸」，其下展开「上胸 / 中下胸」，用户再点「上胸」
- **THEN** 列表在「胸」基础上进一步过滤 `subcategory == "上胸"`；父级无子分类时不展开二级。

#### Scenario: 命中 PR 副标
- **WHEN** 某动作历史最佳 1RM > 0
- **THEN** 行右侧副标显示「PR · {重量}」mono 字体，重量按当前单位（kg / lb）。
