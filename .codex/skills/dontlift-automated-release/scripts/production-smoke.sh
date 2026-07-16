#!/usr/bin/env bash
# 生产 HTTP 探针；可通过 EVIDENCE_FILE 保存 Markdown 证据。
set -euo pipefail

BASE_URL="${PROD_BASE_URL:-https://dontlift.peipadada.com}"
HEALTH_URL="${PROD_HEALTH_URL:-$BASE_URL/actuator/health}"
EVIDENCE_FILE="${EVIDENCE_FILE:-}"

fail() {
  printf '生产验收失败：%s\n' "$*" >&2
  exit 1
}

health_body=""
for attempt in 1 2 3; do
  health_body="$(curl --fail --silent --show-error --max-time 15 "$HEALTH_URL")" \
    || fail "第 $attempt 次 health 请求失败"
  printf '%s' "$health_body" | grep -q '"status":"UP"' \
    || fail "第 $attempt 次 health 非 UP：$health_body"
done

dev_token_status="$(
  curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
    --max-time 15 --request POST "$BASE_URL/auth/dev/token"
)"
[ "$dev_token_status" = "404" ] || fail "生产 dev token 应返回 404，实际 $dev_token_status"

privacy_status="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' --max-time 15 "$BASE_URL/privacy")"
terms_status="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' --max-time 15 "$BASE_URL/terms")"
[ "$privacy_status" = "200" ] || fail "隐私政策应返回 200，实际 $privacy_status"
[ "$terms_status" = "200" ] || fail "服务条款应返回 200，实际 $terms_status"

printf '生产验收通过：health=UP x3，dev_token=404，privacy=200，terms=200\n'

if [ -n "$EVIDENCE_FILE" ]; then
  {
    printf '# 生产验收证据\n\n'
    printf -- '- 时间：`%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Health：`UP`，连续 3 次通过\n'
    printf -- '- Dev token：`404`\n'
    printf -- '- Privacy：`200`\n'
    printf -- '- Terms：`200`\n'
  } > "$EVIDENCE_FILE"
fi
