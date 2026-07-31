# OpenAI imagegen 条款核对（2026-07-24）

> 本记录是工程输入政策证据，不构成法律意见。实际适用协议取决于生成时使用的账户和产品；每次大规模扩量或条款更新后必须重新核对。

## 官方来源

- [OpenAI Terms of Use](https://openai.com/policies/row-terms-of-use/)：发布并生效于 2026-01-01，适用于 ChatGPT、DALL·E 等个人服务。
- [OpenAI Service Terms](https://openai.com/policies/service-terms/)：包含 Image and Video Capabilities 的附加约束。
- [OpenAI Usage Policies](https://openai.com/policies/usage-policies/)：当前页面 changelog 标明 2025-10-29 更新为跨产品统一政策。
- 若生成账户属于 API、ChatGPT Business 或 Enterprise，还需以当时适用的 [OpenAI Services Agreement](https://openai.com/policies/services-agreement/) 为准。

## 与本项目直接相关的结论

1. OpenAI 与用户之间，在适用法律允许范围内，用户保留 Input 权利并拥有 Output；但用户必须确保自己拥有提交 Input 所需的全部权利、许可和授权。
2. AI Output 可能不唯一，其他用户可能获得相似内容。因此本项目不得宣称角色或图片天然独占。
3. Output 可能不准确，官方要求用户在使用或分享前评估准确性和适用性，并在适当时进行人工审核。本项目据此保留动作、器械、人物一致性和权利审核闸门。
4. Visual Capabilities 不得在没有明确同意和必要权利时复制真人 likeness。本项目只生成原创虚构角色，不使用真人或名人参考图。
5. 服务不得用于侵犯、挪用或违反他人权利。本项目禁止把 `hasaneyldrm/exercises-dataset` 或其他未许可媒体作为 reference/edit 输入。

## 工程决定

- 当前允许：原创文字 brief + 本项目自有并已批准的角色/风格母版。
- 当前禁止：任何来源不清或许可未覆盖 AI 输入的第三方媒体。
- 每张正式母版仍须记录 prompt、工具/模型、输入、SHA-256 和人工 `rights` 审核。
- 条款证据只说明 OpenAI 与用户之间的合同分配和使用约束，不替代第三方权利检索、商标审查或专业法律意见。
