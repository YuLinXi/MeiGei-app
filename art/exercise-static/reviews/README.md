# 审核记录

每个角色、风格或动作母版必须使用独立审核记录。历史人工审核主体为 `project-owner`；全量自治生产按 `autopilot-production-policy-v1.md` 使用 `production-autopilot`，并保留同等完整的输入、技术和可追溯证据。

## 最小记录格式

```json
{
  "status": "approved | rejected",
  "reviewerId": "project-owner | production-autopilot",
  "reviewedAt": "ISO-8601",
  "sourceCommit": "git sha",
  "evidence": ["仓库相对路径或检查编号"],
  "notes": "人工决定或自治策略的可核验证据"
}
```

角色和动作审核必须逐项记录，不得用一次笼统确认同时通过 `identity`、`art`、`movement`、`equipment` 和 `rights`。自治生产遇到无唯一标准或无法满足现有规则的动作必须写入跳过台账，不得伪造批准。
