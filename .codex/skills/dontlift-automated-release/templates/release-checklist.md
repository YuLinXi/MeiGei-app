# 发版操作清单：别练了 {{VERSION}} (build {{BUILD}})

> 生成时间：{{GENERATED_AT}}  
> 发布分支：`{{RELEASE_BRANCH}}`  
> 候选提交：`{{RELEASE_SHA}}`  
> 上一版本：`{{PREVIOUS_TAG}}`  
> 功能介绍：[`release-{{VERSION}}-b{{BUILD}}-feature-intro.md`](./release-{{VERSION}}-b{{BUILD}}-feature-intro.md)

## 0. 发布摘要

- 版本号：`MARKETING_VERSION={{VERSION}}`，`CURRENT_PROJECT_VERSION={{BUILD}}`。
- 一句话摘要：{{SUMMARY}}
- 后端发布：{{BACKEND_PLAN}}
- iOS 发布：Release PR 合并后自动签名、Archive、上传并等待 TestFlight processing=`VALID`。
- 发布顺序：{{RELEASE_ORDER}}
- Tag：全部自动化门禁通过后创建 `v{{VERSION}}-b{{BUILD}}`。

## 1. 发布前 Review

- [ ] Review 范围为 `{{PREVIOUS_TAG}}..{{RELEASE_SHA}}`，无遗漏提交。
- [ ] 至少 1 名非提交者 approval，全部 conversation 已解决。
- [ ] `P0=0`、`P1=0`；接受的 `P2` 已记录原因和负责人。
- [ ] API、同步 JSON 和数据库 migration 对上一 TestFlight 客户端向后兼容。
- [ ] 未提交 `.p8`、`.p12`、`.mobileprovision`、`.env`、SSH 私钥或 Token。
- [ ] 本次涉及的 OpenSpec change 与 tasks 状态一致。

### Review 结论

{{REVIEW_RESULT}}

## 2. 自动化验收

- [ ] `release-policy`：版本、分支、Tag、文档、Flyway immutability、生产配置检查通过。
- [ ] `backend-test`：Java 21 + `./gradlew build` + Docker build 通过。
- [ ] `ios-test`：Xcode 26 simulator unit/UI tests 通过，`.xcresult` 已归档。
- [ ] OpenSpec：`openspec validate --all --strict --no-interactive` 通过。
- [ ] signed archive 与 IPA 的 bundle ID/version/build 校验通过。
- [ ] Workflow：{{WORKFLOW_URL}}

## 3. 后端发布

- [ ] migration 前生产数据库备份成功。
- [ ] 仅更新 `dontlift-app`，未重启共享 PostgreSQL/Caddy。
- [ ] 公网 health 连续 3 次为 `UP`。
- [ ] 最新 Flyway migration 为 `success=true`。
- [ ] `POST /auth/dev/token` 返回 `404`。
- [ ] `/privacy` 与 `/terms` 均返回 `200`。
- [ ] 若本次无 `backend/` 改动，确认已跳过重建但保留上述生产探针。

## 4. iOS TestFlight 发布

- [ ] App、Tests、UITests、Widget 的 version/build 全部一致。
- [ ] Apple Distribution 签名与 provisioning profiles 有效。
- [ ] `ITSAppUsesNonExemptEncryption=false`。
- [ ] TestFlight `{{VERSION}} ({{BUILD}})` 上传成功且 processing=`VALID`。
- [ ] 内部测试组 automatic distribution 已启用并收到该 build。
- [ ] Tag `v{{VERSION}}-b{{BUILD}}` 与 GitHub Release 已创建。

## 5. 真机回归重点

> 下列项目不是 Simulator/Hosted Runner 可证明的门禁。它们不阻断内部 TestFlight 上传，但阻断 App Store 正式提交。

{{DEVICE_REGRESSION_ITEMS}}

## 6. 失败恢复

- PR/测试失败：修复同一 Release PR，不部署。
- 后端失败且无 migration：恢复上一应用镜像；发布保持失败。
- 后端失败且含 migration：不自动恢复旧应用，不回滚 migration，进入人工事故处理。
- TestFlight 上传/处理失败：不打 Tag；修复后递增 build，不复用 `{{BUILD}}`。
- Finalize 失败：只重跑 Tag/GitHub Release 收尾，不重复部署或上传。

## 发布结果

- Workflow：{{WORKFLOW_URL}}
- Git Tag：`v{{VERSION}}-b{{BUILD}}`
- GitHub Release：{{GITHUB_RELEASE_URL}}
- TestFlight：`{{VERSION}} ({{BUILD}})`
- 未自动覆盖项：见“真机回归重点”。
