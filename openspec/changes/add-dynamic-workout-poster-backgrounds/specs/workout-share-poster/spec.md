## MODIFIED Requirements

### Requirement: 海报背景推荐与选择
系统 SHALL 提供完成庆典台、能量环游轨迹、迷你综合训练场、伙伴击掌、训练装备花环共 5 张随 App 打包的插画背景。系统 SHALL 根据 PR、Team 分享来源、训练时长、训练量、组数、动作数和复杂训练结构推荐初始背景，并 SHALL 允许用户在首屏可见的海报分页器中从全部 5 张背景里手动切换。手动选择仅在当前预览会话有效，MUST NOT 写入训练记录、SwiftData 或同步协议。

#### Scenario: PR 训练使用庆典背景
- **WHEN** 本次训练产生至少一项 PR
- **THEN** 系统 SHALL 推荐完成庆典台背景

#### Scenario: Team 分享训练使用伙伴背景
- **WHEN** 本次训练未产生 PR且来自 Team 分享计划
- **THEN** 系统 SHALL 推荐伙伴击掌背景

#### Scenario: 高投入或复杂训练使用对应背景
- **WHEN** 训练达到长时长、高组数或高训练量阈值
- **THEN** 系统 SHALL 推荐能量环游轨迹背景
- **WHEN** 训练包含不少于 5 个动作或包含超级组/递减组
- **THEN** 系统 SHALL 推荐迷你综合训练场背景
- **AND** 同时满足动作丰富与高投入条件时，系统 SHALL 使用训练 UUID 在这两张背景间稳定选择

#### Scenario: 普通训练使用装备花环背景
- **WHEN** 训练未命中更高优先级的语义条件
- **THEN** 系统 SHALL 推荐训练装备花环背景

#### Scenario: 在海报区域切换真实背景
- **WHEN** 用户左右滑动大海报、点击海报左右按钮或点击紧邻海报的小版式预览
- **THEN** 系统 SHALL 立即将对应插画切换为当前页并重新展示同一份训练内容
- **AND** 训练标题、指标、动作摘要和 PR SHALL 保持不变
- **AND** 当前页、页码、小版式预览选中态 SHALL 保持同步
- **AND** 保存与分享 SHALL 使用当前页对应的版式

### Requirement: 训练海报视觉融合
系统 SHALL 使用固定 9:16 全画幅插画作为背景，并 SHALL 将训练信息放入更通透但保持文字可读的暖白半透明训练凭证中。系统 SHALL 根据背景的 `topCompact`、`upperCenter` 或 `centerReceipt` safe zone 放置凭证，MUST NOT 遮挡主要人物或器械。海报 MUST NOT 继续展示旧黑红侧栏、假 QR 或固定口号。

#### Scenario: 背景使用适配布局
- **WHEN** 系统渲染任意一张内置背景
- **THEN** 训练凭证 SHALL 使用该背景声明的 safe zone
- **AND** 文字 SHALL 使用深暖棕，强调数字和 PR SHALL 使用珊瑚橙
- **AND** 底部 SHALL 只保留简洁品牌签名

#### Scenario: 长动作列表保持可读
- **WHEN** 训练包含任意数量的动作摘要
- **THEN** 系统 SHALL 在凭证中逐条展示全部动作摘要
- **AND** 系统 SHALL NOT 使用“另有 N 个动作”或其他方式省略动作
- **WHEN** 训练动作摘要超过 6 条
- **THEN** 系统 SHALL 使用紧凑分栏布局承载全部动作摘要
- **AND** 凭证 SHALL 保持在背景安全区内

### Requirement: 图片保存与系统分享
系统 SHALL 将海报渲染为 `1080×1920` 图片，并允许用户保存图片或通过 iOS 系统分享面板分享图片。屏幕预览、保存图片和分享图片 SHALL 使用同一份训练数据、同一 safe zone 和当前选中的背景。

#### Scenario: 保存当前背景的海报图片
- **WHEN** 用户选择一款背景并点击保存图片
- **THEN** 系统 SHALL 将当前 9:16 海报保存到相册
- **AND** 保存结果 SHALL 与点击保存时的屏幕预览一致

#### Scenario: 分享当前背景的海报图片
- **WHEN** 用户选择一款背景并点击分享
- **THEN** 系统 SHALL 打开 iOS 系统分享面板
- **AND** 分享内容 SHALL 是当前 9:16 海报图片

## ADDED Requirements

### Requirement: 背景资源本地可用并兼容回退
所有 5 张背景 SHALL 随 iOS App 本地提供，背景选择与渲染 MUST NOT 依赖网络请求。无法解析背景值时系统 SHALL 回退训练装备花环；图片资源异常时 SHALL 使用暖白底完成海报渲染。

#### Scenario: 离线切换和导出
- **WHEN** 设备离线且本地存在目标训练记录
- **THEN** 用户 SHALL 能切换全部 5 张背景并保存或分享当前海报
- **AND** 系统 SHALL NOT 发起获取背景的网络请求

#### Scenario: 未知背景回退
- **WHEN** 系统收到未知背景值
- **THEN** 系统 SHALL 使用训练装备花环完成预览和导出
