#!/usr/bin/env bash
# DontLift Release PR 的确定性发布门禁。只读检查，不修改仓库。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

fail() {
  printf '发布门禁失败：%s\n' "$*" >&2
  exit 1
}

note() {
  printf '==> %s\n' "$*"
}

unique_setting() {
  local key="$1"
  sed -nE "s/^[[:space:]]*$key = ([^;]+);/\\1/p" ios/DontLift/DontLift.xcodeproj/project.pbxproj \
    | awk 'NF' \
    | sort -u
}

require_heading() {
  local file="$1"
  local heading="$2"
  grep -Fqx "$heading" "$file" || fail "$file 缺少章节：$heading"
}

branch="${RELEASE_BRANCH:-$(git branch --show-current)}"
if [[ "$branch" =~ ^release/v([0-9]+\.[0-9]+)-b([1-9][0-9]*)$ ]]; then
  version="${BASH_REMATCH[1]}"
  build="${BASH_REMATCH[2]}"
elif [[ "$branch" =~ ^feature/v([0-9]+\.[0-9]+)-b([1-9][0-9]*)$ ]]; then
  version="${BASH_REMATCH[1]}"
  build="${BASH_REMATCH[2]}"
  note "兼容历史分支 ${branch}；后续新发版改用 release/vX.Y-bN"
else
  fail "发布分支必须为 release/vX.Y-bN；历史兼容 feature/vX.Y-bN。当前：${branch:-detached HEAD}"
fi

if [ "${ALLOW_DIRTY:-0}" != "1" ] && [ -n "$(git status --porcelain)" ]; then
  fail "发布 worktree 必须干净"
fi

versions="$(unique_setting MARKETING_VERSION)"
builds="$(unique_setting CURRENT_PROJECT_VERSION)"
[ "$(printf '%s\n' "$versions" | awk 'NF' | wc -l | tr -d ' ')" = "1" ] \
  || fail "所有 Xcode target 的 MARKETING_VERSION 必须唯一，当前：$versions"
[ "$(printf '%s\n' "$builds" | awk 'NF' | wc -l | tr -d ' ')" = "1" ] \
  || fail "所有 Xcode target 的 CURRENT_PROJECT_VERSION 必须唯一，当前：$builds"
[ "$versions" = "$version" ] || fail "工程 MARKETING_VERSION=${versions}，与分支 version=$version 不一致"
[ "$builds" = "$build" ] || fail "工程 CURRENT_PROJECT_VERSION=${builds}，与分支 build=$build 不一致"

tag="v${version}-b${build}"
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  fail "Tag $tag 已存在，build 不得复用"
fi
if git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1; then
  fail "远端 Tag $tag 已存在，build 不得复用"
fi

max_tag_build="$(
  git tag --list 'v*-b*' \
    | sed -nE 's/^v[0-9]+\.[0-9]+-b([0-9]+)$/\1/p' \
    | sort -nr \
    | head -1
)"
if [ -n "$max_tag_build" ] && [ "$build" -le "$max_tag_build" ]; then
  fail "build=$build 必须大于现有 Tag 的最高 build=$max_tag_build"
fi

checklist="docs/release-${version}-b${build}-checklist.md"
feature_intro="docs/release-${version}-b${build}-feature-intro.md"
[ -f "$checklist" ] || fail "缺少 $checklist"
[ -f "$feature_intro" ] || fail "缺少 $feature_intro"
if grep -En '\{\{[A-Z0-9_]+\}\}' "$checklist" "$feature_intro"; then
  fail "发版文档仍含未替换模板变量"
fi

for heading in \
  "## 0. 发布摘要" \
  "## 1. 发布前 Review" \
  "## 2. 自动化验收" \
  "## 3. 后端发布" \
  "## 4. iOS TestFlight 发布" \
  "## 5. 真机回归重点" \
  "## 6. 失败恢复"; do
  require_heading "$checklist" "$heading"
done

for heading in \
  "## 版本与状态" \
  "## 一句话摘要" \
  "## 面向测试用户的更新说明" \
  "## 内部技术变更" \
  "## 兼容性说明" \
  "## 已完成验证" \
  "## TestFlight 回归重点"; do
  require_heading "$feature_intro" "$heading"
done

previous_tag="${BASE_REF:-$(git tag --list 'v*-b*' --sort=-version:refname | head -1)}"
[ -n "$previous_tag" ] || fail "找不到上一发布 Tag，请显式设置 BASE_REF"
git rev-parse --verify "$previous_tag^{commit}" >/dev/null 2>&1 || fail "BASE_REF=$previous_tag 不是有效提交"
git diff --check "$previous_tag" -- || fail "git diff --check 未通过"

changed_files="$(git diff --name-only "$previous_tag" --)"
if printf '%s\n' "$changed_files" | grep -Eqi '(^|/)(AuthKey_.*\.p8|.*\.p12|.*\.mobileprovision|\.env($|\.)|id_(rsa|ed25519))$'; then
  fail "diff 中出现疑似凭据文件"
fi

migration_changes="$(git diff --name-status "$previous_tag" -- backend/src/main/resources/db/migration || true)"
if printf '%s\n' "$migration_changes" | awk 'NF && $1 != "A" { found=1 } END { exit found ? 0 : 1 }'; then
  fail "已发布 Flyway migration 不得修改、重命名或删除：$migration_changes"
fi

while IFS=$'\t' read -r status path; do
  [ "$status" = "A" ] || continue
  if grep -Eni '(DROP[[:space:]]+(TABLE|COLUMN)|TRUNCATE|RENAME[[:space:]]+(TABLE|COLUMN)|ALTER[[:space:]]+.*[[:space:]]TYPE|SET[[:space:]]+NOT[[:space:]]+NULL|DELETE[[:space:]]+FROM)' "$path"; then
    fail "新 migration $path 含破坏性操作，必须退出全自动通道做专项审批"
  fi
done <<< "$migration_changes"

while IFS= read -r task_file; do
  [ -n "$task_file" ] || continue
  if grep -En '^- \[[ ~]\]' "$task_file"; then
    fail "本次 OpenSpec tasks 仍有未完成/未解释条目：$task_file"
  fi
done < <(git diff --name-only "$previous_tag" -- 'openspec/changes/*/tasks.md')

grep -Fq 'token-enabled: ${APP_DEV_TOKEN:false}' backend/src/main/resources/application.yml \
  || fail "APP_DEV_TOKEN 默认值必须为 false"
grep -Fq 'static let current: Backend = .production' ios/DontLift/DontLift/Networking/AppConfig.swift \
  || fail "iOS Release 必须强制使用 production 后端"
if grep -Rqs 'NSAllowsArbitraryLoads' ios/DontLift; then
  fail "发布包不得启用 NSAllowsArbitraryLoads"
fi
grep -A1 -F '<key>ITSAppUsesNonExemptEncryption</key>' ios/DontLift/DontLift-Info.plist | grep -Fq '<false/>' \
  || fail "缺少 ITSAppUsesNonExemptEncryption=false"

privacy_url="$(sed -nE 's/.*privacyPolicyURL = URL\(string: "([^"]+)"\).*/\1/p' ios/DontLift/DontLift/Networking/AppConfig.swift)"
terms_url="$(sed -nE 's/.*termsOfServiceURL = URL\(string: "([^"]+)"\).*/\1/p' ios/DontLift/DontLift/Networking/AppConfig.swift)"
[ -n "$privacy_url" ] && [ -n "$terms_url" ] || fail "无法读取法务 URL"
[ "$privacy_url" != "$terms_url" ] || fail "隐私政策与服务条款 URL 必须不同"

backend_changed=false
migration_changed=false
git diff --quiet "$previous_tag" -- backend/ || backend_changed=true
git diff --quiet "$previous_tag" -- backend/src/main/resources/db/migration/ || migration_changed=true

note "发布门禁通过：${tag}，base=${previous_tag}，backend_changed=$backend_changed"
if [ -n "${OUTPUT_FILE:-}" ]; then
  {
    printf 'version=%s\n' "$version"
    printf 'build=%s\n' "$build"
    printf 'tag=%s\n' "$tag"
    printf 'previous_tag=%s\n' "$previous_tag"
    printf 'backend_changed=%s\n' "$backend_changed"
    printf 'migration_changed=%s\n' "$migration_changed"
    printf 'checklist=%s\n' "$checklist"
    printf 'feature_intro=%s\n' "$feature_intro"
  } >> "$OUTPUT_FILE"
fi
