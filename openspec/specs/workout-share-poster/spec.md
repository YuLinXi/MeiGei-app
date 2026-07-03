# workout-share-poster Specification

## Purpose
TBD - created by archiving change add-workout-share-poster. Update Purpose after archive.
## Requirements
### Requirement: 训练结束海报入口
系统 SHALL 在用户完成训练后的结束流程中提供生成训练海报图片的入口。

#### Scenario: 从训练结束流程打开海报预览
- **WHEN** 用户完成一次训练并进入训练结束结果界面
- **THEN** 系统 SHALL 展示「分享海报」入口
- **AND** 点击入口 SHALL 打开该训练的海报预览

### Requirement: 历史详情海报入口
系统 SHALL 在历史训练详情中提供再次生成该训练海报图片的入口。

#### Scenario: 从历史训练详情打开海报预览
- **WHEN** 用户查看一条历史训练详情
- **THEN** 系统 SHALL 展示分享海报入口
- **AND** 点击入口 SHALL 打开该历史训练的海报预览

### Requirement: 海报风格选择
系统 SHALL 提供两种固定海报风格供用户选择：训练收据和社交视觉卡。

#### Scenario: 切换海报风格
- **WHEN** 用户在海报预览中选择训练收据或社交视觉卡
- **THEN** 系统 SHALL 使用同一训练数据重新展示所选风格的海报预览

### Requirement: 海报内容
系统 SHALL 在海报图片中默认展示训练日期、训练标题、训练时长、总容量、组数、次数、动作摘要、重量信息和可重算的 PR 信息。

#### Scenario: 生成包含重量的海报
- **WHEN** 用户打开任一训练的海报预览
- **THEN** 系统 SHALL 在海报中展示该训练的重量相关信息
- **AND** 系统 SHALL NOT 要求用户额外开启重量展示

#### Scenario: 动作过多时摘要展示
- **WHEN** 训练包含超过 4 个动作
- **THEN** 系统 SHALL 在海报中展示前 4 个动作摘要
- **AND** 系统 SHALL 展示剩余动作数量提示

### Requirement: 图片保存与系统分享
系统 SHALL 将海报渲染为图片，并允许用户保存图片或通过 iOS 系统分享面板分享图片。

#### Scenario: 保存海报图片
- **WHEN** 用户在海报预览中选择保存图片
- **THEN** 系统 SHALL 将当前风格的海报图片保存到相册

#### Scenario: 分享海报图片
- **WHEN** 用户在海报预览中选择分享
- **THEN** 系统 SHALL 打开 iOS 系统分享面板
- **AND** 分享内容 SHALL 是当前风格渲染出的图片

### Requirement: 弱化品牌预留位
系统 SHALL 在海报底部保留弱化的 App 品牌或二维码预留位，但该区域不得抢占训练主体内容。

#### Scenario: 海报展示品牌预留位
- **WHEN** 系统展示或生成海报
- **THEN** 海报底部 SHALL 包含弱化的 App 品牌或二维码预留区域
- **AND** 训练标题、关键指标和动作摘要 SHALL 保持视觉优先级高于品牌预留位

### Requirement: 本地派生且不新增服务端依赖
系统 SHALL 从本地训练记录派生海报内容，不新增后端 API、数据库表、对象存储或同步实体。

#### Scenario: 离线生成海报
- **WHEN** 设备离线且本地存在目标训练记录
- **THEN** 用户 SHALL 能打开海报预览并生成图片
- **AND** 系统 SHALL NOT 依赖网络请求完成海报生成
