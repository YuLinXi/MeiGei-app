# 一次性接入与凭据配置

## 当前仓库快照

截至 2026-07-16 的只读检查：仓库 `YuLinXi/MeiGei-app` 为 public，默认分支 `main`；尚无 `.github/workflows`、branch protection/ruleset、GitHub Environment、Actions Secrets/Variables。使用本 Skill 时必须实时复查，不能假设该快照仍有效。

## GitHub Actions 文件

将以下模板按差异安装：

- `assets/workflows/ci.yml` → `.github/workflows/ci.yml`
- `assets/workflows/release.yml` → `.github/workflows/release.yml`

模板中的第三方 Action 使用完整 commit SHA 固定版本。更新 SHA 时先核对上游 release 和变更记录，不改用浮动 `main`。

当前锁定值（2026-07-16 验证）：

| Action | Release | Commit SHA |
|---|---|---|
| `actions/checkout` | `v4.2.2` | `11bd71901bbe5b1630ceea73d27597364c9af683` |
| `actions/setup-java` | `v4.7.1` | `c5195efecf7bdfc987ee8bae7a71cb8b11521c00` |
| `actions/upload-artifact` | `v4.6.2` | `ea165f8d65b6e75b540449e92b4886f43607fa02` |
| `Apple-Actions/upload-testflight-build` | `v5.2.1` | `1ad58030672057aa084b4e96beb6f7a8c627f9e6` |

## Ruleset

为 `main` 建立 active ruleset：

- Require a pull request before merging；required approvals = 1。
- Dismiss stale approvals；require review conversation resolution。
- Require status checks：`release-policy`、`backend-test`、`ios-test`。
- Require branch to be up to date before merging。
- Block force pushes 和 deletions；管理员不绕过。

## Environments

创建两个 Environment，部署分支只允许 `main`：

1. `production-backend`：保存服务器部署凭据。
2. `testflight`：保存 Apple 签名和 App Store Connect 凭据。

人工 review 已发生在受保护 Release PR；若目标是“合并后全自动”，Environment 不再增加人工 reviewer。若需要双人发布批准，可在 Environment 增加 reviewer，但这会变成半自动发布，应在规则中明确。

## Repository / Environment Variables

| 名称 | 建议作用域 | 示例/说明 |
|---|---|---|
| `PROD_SSH_TARGET` | `production-backend` | `root@<server>`，不要硬编码进 workflow |
| `PROD_HEALTH_URL` | `production-backend` | `https://dontlift.peipadada.com/actuator/health` |
| `APPSTORE_ISSUER_ID` | `testflight` | App Store Connect Issuer ID |
| `APPSTORE_API_KEY_ID` | `testflight` | API Key ID |
| `APPLE_TEAM_ID` | `testflight` | `D566UZ8QG4` |
| `IOS_BUNDLE_ID` | `testflight` | `com.yulinxi.app.DontLift` |

## Secrets

| 名称 | 作用域 | 内容 |
|---|---|---|
| `PROD_SSH_PRIVATE_KEY` | `production-backend` | 专用 deploy key，最小服务器权限 |
| `PROD_SSH_KNOWN_HOSTS` | `production-backend` | 预先核验的 `known_hosts` 行，禁止运行时盲信 `ssh-keyscan` |
| `APPSTORE_API_PRIVATE_KEY` | `testflight` | App Store Connect `AuthKey_*.p8` 原文 |
| `IOS_DISTRIBUTION_CERT_P12_BASE64` | `testflight` | Apple Distribution 证书及私钥导出的 `.p12` base64 |
| `IOS_DISTRIBUTION_CERT_PASSWORD` | `testflight` | `.p12` 导出密码 |

不要把服务器已有 APNs `.p8` 复制到 GitHub；APNs 运行凭据和 TestFlight 上传 API Key 是不同的安全边界。

## Apple 一次性配置

1. App Store Connect Account Holder 先开通 API access；创建权限最小化的 API Key。上传/测试信息/内部组管理建议使用 App Manager 权限。
2. 创建有效的 Apple Distribution certificate，连同 private key 导出为密码保护 `.p12`。
3. 确认 App ID 和 Widget ID 已启用现有 capabilities；App Group `group.com.yulinxi.app.DontLift` 同时分配给主 App 与 Widget。
4. 确认 Xcode automatic signing 能通过 API Key 下载/创建发布所需 provisioning profiles。
5. 在 App Store Connect 创建内部测试组并勾选 automatic distribution；加入内部测试员。
6. 完成 TestFlight Beta App Description、Feedback Email、测试说明和出口合规信息。

`.p8` 只能下载一次。完成 GitHub Secret 配置后，把离线备份放入密码管理器或加密介质，不留在仓库目录。

## Runner 与工具版本

- Backend：`ubuntu-24.04`、Java 21、仓库 `./gradlew`。
- iOS：`macos-26`、稳定版 Xcode 26；workflow 输出实际 `xcodebuild -version`，major 不匹配即失败。
- OpenSpec：固定 `@fission-ai/openspec@1.6.0`，升级时同时验证项目已有 change。
- Release 使用 `concurrency: dontlift-production-release`，禁止取消正在运行的生产发布。

## 首次演练

1. 先只合并 `ci.yml`，使必需 checks 稳定通过。
2. 配置 ruleset、Environments、Variables 和 Secrets。
3. 安装 `release.yml`，用新的未上传 build 在 `workflow_dispatch` 运行。
4. 核对后端备份、生产探针、IPA version/build、TestFlight processing、内部组分发、Tag/GitHub Release。
5. 演练成功后才启用 Release PR 合并自动触发。

任何签名或上传失败都使用新 build 重试；演练 build 也视为已消耗。

## 官方依据

- [App Store Connect API 入门](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/)
- [App Store Connect API 的 TestFlight 能力](https://developer.apple.com/documentation/appstoreconnectapi)
- [TestFlight 内部测试组与 automatic distribution](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers)
- [GitHub Actions Environments 与 deployment protection](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)
- [GitHub Hosted Runner images](https://github.com/actions/runner-images)
