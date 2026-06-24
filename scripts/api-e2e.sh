#!/usr/bin/env bash
# DontLift 后端 API 端到端联调脚本（纯服务端 curl，不含 iOS UI）
#
# 覆盖链路：登录 → 离线同步(push/pull/幂等/LWW 冲突) → Team 建团/加入/成员
#           → Team 自动分享偏好 / 显式 checkin API（默认不 fan-out）→ 表情回应。双用户(A=owner / B=member)。
#
# 前置：后端在线（另开终端 ./backend/scripts/dev-start.sh，已注入 APP_DEV_TOKEN=true）。
#       需要 jq、uuidgen（macOS 自带）。
#
# 用法（仓库根目录）：./scripts/api-e2e.sh
# 可用环境变量：BASE（默认 http://localhost:8001）
#
# 端点契约均按 backend 源码核验（见 controller/DTO/entity）：
#   push 体 {"items":[...]}；pull 回 {"changes":[],"serverTime":}；
#   push 回 {"applied":[],"conflicts":[{"id","serverValue"}],"serverTime":}；
#   push 服务端强制 userId（客户端不必传）；LWW: incoming.updatedAt >= server 即胜。

if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi
set -uo pipefail

BASE="${BASE:-http://localhost:8001}"
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
FAILS=0
section() { echo -e "\n${BLUE}== $* ==${NC}"; }
pass() { echo -e "  ${GREEN}✓${NC} $*"; }
fail() { echo -e "  ${RED}✗${NC} $*"; FAILS=$((FAILS+1)); }

# ---- 依赖检查 ----
command -v jq >/dev/null      || { echo -e "${RED}缺少 jq${NC}（brew install jq）"; exit 2; }
command -v uuidgen >/dev/null || { echo -e "${RED}缺少 uuidgen${NC}"; exit 2; }
if ! curl -sf "$BASE/actuator/health" >/dev/null 2>&1; then
  echo -e "${RED}后端未在线：$BASE${NC} — 先跑 ./backend/scripts/dev-start.sh"; exit 1
fi

uuid() { uuidgen | tr 'A-Z' 'a-z'; }
TS_NOW=$(date -u +%Y-%m-%dT%H:%M:%S.000000Z)
TS_OLD=$(date -u -v-1d +%Y-%m-%dT%H:%M:%S.000000Z)   # 昨天（BSD date）
TS_NEW=$(date -u -v+1S +%Y-%m-%dT%H:%M:%S.000000Z)   # 稍新但仍在服务端时钟容忍窗口内
TODAY=$(date -u +%Y-%m-%d)

# call METHOD PATH [BODY] [TOKEN] [IDEMPOTENCY_KEY] → 设置 RESP_BODY / RESP_CODE
RESP_BODY=""; RESP_CODE=""
call() {
  local method=$1 path=$2 body=${3:-} token=${4:-} idem=${5:-}
  local args=(-sS -X "$method" "$BASE$path" -w $'\n%{http_code}')
  [ -n "$token" ] && args+=(-H "Authorization: Bearer $token")
  [ -n "$idem" ]  && args+=(-H "Idempotency-Key: $idem")
  [ -n "$body" ]  && args+=(-H "Content-Type: application/json" -d "$body")
  local out; out=$(curl "${args[@]}")
  RESP_CODE=$(printf '%s' "$out" | tail -n1)
  RESP_BODY=$(printf '%s' "$out" | sed '$d')
}
# GET 带 since（URL 编码 + 号）
call_pull() {
  local path=$1 token=$2 since=${3:-}
  local out
  if [ -n "$since" ]; then
    out=$(curl -sS -G "$BASE$path" --data-urlencode "since=$since" -H "Authorization: Bearer $token" -w $'\n%{http_code}')
  else
    out=$(curl -sS -G "$BASE$path" -H "Authorization: Bearer $token" -w $'\n%{http_code}')
  fi
  RESP_CODE=$(printf '%s' "$out" | tail -n1)
  RESP_BODY=$(printf '%s' "$out" | sed '$d')
}
jqr() { printf '%s' "$RESP_BODY" | jq -r "$1" 2>/dev/null; }
expect_code() { [ "$RESP_CODE" = "$1" ] && pass "HTTP $1 — $2" || fail "期望 HTTP $1 实际 $RESP_CODE — $2 | $RESP_BODY"; }

# ============================================================
section "1. 登录（dev token，造两个用户 A/B）"
call POST /auth/dev/token
expect_code 200 "A /auth/dev/token"
TOKEN_A=$(jqr '.token'); USER_A=$(jqr '.userId')
[ -n "$TOKEN_A" ] && [ "$TOKEN_A" != "null" ] && pass "A token+userId 获取（userId=${USER_A}）" || fail "A token 缺失"

call POST /auth/dev/token
expect_code 200 "B /auth/dev/token"
TOKEN_B=$(jqr '.token'); USER_B=$(jqr '.userId')
[ -n "$TOKEN_B" ] && [ "$TOKEN_B" != "null" ] && pass "B token+userId 获取（userId=${USER_B}）" || fail "B token 缺失"

# ============================================================
section "2. 同步域：custom-exercise（push/pull/幂等/LWW）"
EX_ID=$(uuid); IDEM1=$(uuid)
EX_BODY=$(cat <<JSON
{"items":[{"id":"$EX_ID","name":"E2E 自定义动作","primaryMuscle":"chest","equipmentType":"bodyweight","createdAt":"$TS_NOW","updatedAt":"$TS_NOW","deletedAt":null,"version":1}]}
JSON
)
# 2.1 push 新增
call POST /sync/custom-exercises/push "$EX_BODY" "$TOKEN_A" "$IDEM1"
expect_code 200 "push 自定义动作"
[ "$(jqr ".applied | index(\"$EX_ID\")")" != "null" ] && pass "applied 含 $EX_ID" || fail "applied 不含新动作 | $RESP_BODY"
ST1=$(jqr '.serverTime')

# 2.2 全量 pull
call_pull /sync/custom-exercises/pull "$TOKEN_A"
expect_code 200 "全量 pull"
[ "$(jqr ".changes[] | select(.id==\"$EX_ID\") | .name")" = "E2E 自定义动作" ] && pass "全量 pull 含该动作且 name 正确" || fail "全量 pull 未含该动作"

# 2.3 增量 pull（since=昨天 → 应含刚写入的行）
call_pull /sync/custom-exercises/pull "$TOKEN_A" "$TS_OLD"
expect_code 200 "增量 pull(since=昨天)"
[ "$(jqr ".changes[] | select(.id==\"$EX_ID\") | .id")" = "$EX_ID" ] && pass "增量 pull 命中该动作" || fail "增量 pull 漏掉该动作"

# 2.4 幂等：同 Idempotency-Key 重放 → serverTime 应与首次完全一致（证明是缓存重放而非重执行）
call POST /sync/custom-exercises/push "$EX_BODY" "$TOKEN_A" "$IDEM1"
expect_code 200 "幂等重放（同 key）"
[ "$(jqr '.serverTime')" = "$ST1" ] && pass "serverTime 与首次一致 → 幂等命中缓存" || fail "serverTime 变化 → 幂等未生效（首=$ST1 再=$(jqr '.serverTime')）"

# 2.5 LWW 冲突：用更旧 updatedAt 推同一行（新 key）→ 服务端较新，应进 conflicts 回传 serverValue
EX_OLD=$(cat <<JSON
{"items":[{"id":"$EX_ID","name":"过时的覆盖","primaryMuscle":"back","equipmentType":"barbell","createdAt":"$TS_OLD","updatedAt":"$TS_OLD","deletedAt":null,"version":1}]}
JSON
)
call POST /sync/custom-exercises/push "$EX_OLD" "$TOKEN_A" "$(uuid)"
expect_code 200 "LWW：推更旧版本"
[ "$(jqr ".conflicts[] | select(.id==\"$EX_ID\") | .serverValue.name")" = "E2E 自定义动作" ] \
  && pass "进 conflicts 且 serverValue 回传服务端当前值（未被旧值覆盖）" || fail "LWW 冲突未按预期 | $RESP_BODY"

# 2.6 LWW 覆盖：用更新 updatedAt 推同一行 → 应 applied，全量 pull 反映新 name
EX_NEW=$(cat <<JSON
{"items":[{"id":"$EX_ID","name":"E2E 动作改名","primaryMuscle":"chest","equipmentType":"dumbbell","createdAt":"$TS_NOW","updatedAt":"$TS_NEW","deletedAt":null,"version":1}]}
JSON
)
call POST /sync/custom-exercises/push "$EX_NEW" "$TOKEN_A" "$(uuid)"
expect_code 200 "LWW：推更新版本"
[ "$(jqr ".applied | index(\"$EX_ID\")")" != "null" ] && pass "applied 含该动作（较新覆盖）" || fail "较新版本未被应用"
call_pull /sync/custom-exercises/pull "$TOKEN_A"
[ "$(jqr ".changes[] | select(.id==\"$EX_ID\") | .name")" = "E2E 动作改名" ] && pass "pull 反映改名后值" || fail "改名未落库"

# ============================================================
section "3. 同步域：workout 聚合树（根 + 动作 + 组整树上传）"
W_ID=$(uuid); WE_ID=$(uuid); WS1=$(uuid); WS2=$(uuid)
W_BODY=$(cat <<JSON
{"items":[{
  "workout":{"id":"$W_ID","planId":null,"title":"E2E 训练","startedAt":"$TS_NOW","endedAt":"$TS_NOW","note":"端到端","createdAt":"$TS_NOW","updatedAt":"$TS_NOW","deletedAt":null,"version":1},
  "exercises":[{
    "exercise":{"id":"$WE_ID","builtinExerciseCode":"BB_BENCH_PRESS","customExerciseId":null,"exerciseName":"杠铃卧推","primaryMuscle":"chest","orderIndex":1,"note":null},
    "sets":[
      {"id":"$WS1","setIndex":1,"weightKg":80.0,"reps":8,"completed":true,"note":null},
      {"id":"$WS2","setIndex":2,"weightKg":80.0,"reps":10,"completed":true,"note":null}
    ]}]
}]}
JSON
)
call POST /sync/workouts/push "$W_BODY" "$TOKEN_A" "$(uuid)"
expect_code 200 "push 训练聚合树"
[ "$(jqr ".applied | index(\"$W_ID\")")" != "null" ] && pass "applied 含 workoutId" || fail "训练未落库 | $RESP_BODY"
call_pull /sync/workouts/pull "$TOKEN_A"
[ "$(jqr ".changes[] | select(.workout.id==\"$W_ID\") | .exercises[0].sets | length")" = "2" ] \
  && pass "pull 回整树：动作 1 + 组 2" || fail "聚合树子节点数不符"

# ============================================================
section "4. Team：A 建团 → B 用邀请码加入 → 成员列表"
call POST /teams '{"name":"E2E 小队"}' "$TOKEN_A" "$(uuid)"
expect_code 200 "A 建团"
TEAM_ID=$(jqr '.id'); INVITE=$(jqr '.inviteCode')
[ -n "$INVITE" ] && [ "$INVITE" != "null" ] && pass "建团返回 inviteCode=${INVITE}（teamId=${TEAM_ID}）" || fail "建团无 inviteCode"
[ "$(jqr '.ownerUserId')" = "$USER_A" ] && pass "ownerUserId=A" || fail "ownerUserId 非 A"

call POST /teams/join "{\"inviteCode\":\"$INVITE\"}" "$TOKEN_B" "$(uuid)"
expect_code 200 "B 加入"
[ "$(jqr '.id')" = "$TEAM_ID" ] && pass "B 加入同一 team" || fail "加入返回的 team 不一致"

call GET "/teams/$TEAM_ID/members" "" "$TOKEN_A"
expect_code 200 "成员列表"
MCOUNT=$(jqr 'length')
[ "$MCOUNT" = "2" ] && pass "成员数=2" || fail "成员数=${MCOUNT}（期望 2）"
[ "$(jqr "[.[].userId] | index(\"$USER_A\")")" != "null" ] && [ "$(jqr "[.[].userId] | index(\"$USER_B\")")" != "null" ] \
  && pass "A、B 均在成员中" || fail "成员缺 A 或 B"
[ "$(jqr ".[] | select(.userId==\"$USER_A\") | .autoShareWorkouts")" = "false" ] \
  && pass "A 自动分享偏好默认关闭" || fail "A 自动分享偏好不是默认关闭 | $RESP_BODY"

call PATCH "/teams/$TEAM_ID/members/me/share-preferences" '{"autoShareWorkouts":true}' "$TOKEN_A" "$(uuid)"
expect_code 200 "A 开启 Team 自动分享偏好"
[ "$(jqr '.autoShareWorkouts')" = "true" ] && pass "A 偏好已开启" || fail "A 偏好未开启 | $RESP_BODY"

call GET "/teams/members/me/share-preferences" "" "$TOKEN_A"
expect_code 200 "A 查询自己的 Team 分享偏好"
[ "$(jqr ".[] | select(.teamId==\"$TEAM_ID\") | .autoShareWorkouts")" = "true" ] \
  && pass "偏好列表包含已开启的 Team" || fail "偏好列表未反映开启状态 | $RESP_BODY"

# ============================================================
section "5. Team checkin API：显式 teamIds 写入（默认不 fan-out）"
CK_IDEM=$(uuid)
CK_EMPTY_BODY=$(cat <<JSON
{"workoutId":"$W_ID","checkinDate":"$TODAY","summary":{"exerciseCount":1,"totalSets":2,"totalVolume":1440},"teamIds":[]}
JSON
)
call POST /checkins "$CK_EMPTY_BODY" "$TOKEN_A" "$(uuid)"
expect_code 400 "teamIds 为空时服务端拒绝创建 checkin"

call GET "/teams/$TEAM_ID/checkins?date=$TODAY" "" "$TOKEN_B"
expect_code 200 "B 列当日打卡（显式分享前）"
[ "$(jqr "[.[] | select(.workoutId==\"$W_ID\")] | length")" = "0" ] \
  && pass "checkin API 写入前 Team feed 不出现该训练" || fail "teamIds 为空却出现 checkin | $RESP_BODY"

CK_BODY=$(cat <<JSON
{"workoutId":"$W_ID","checkinDate":"$TODAY","summary":{"exerciseCount":1,"totalSets":2,"totalVolume":1440},"teamIds":["$TEAM_ID"]}
JSON
)
call POST /checkins "$CK_BODY" "$TOKEN_A" "$CK_IDEM"
expect_code 200 "A 显式分享到 Team"
CK_LEN=$(jqr 'length')
[ "$CK_LEN" = "1" ] 2>/dev/null && pass "仅生成所选 Team 的 1 条打卡" || fail "打卡数量不符 | $RESP_BODY"
CHECKIN_ID=$(jqr ".[] | select(.teamId==\"$TEAM_ID\") | .id")
[ -n "$CHECKIN_ID" ] && [ "$CHECKIN_ID" != "null" ] && pass "命中本 team 的打卡（checkinId=${CHECKIN_ID}）" || fail "未命中本 team 打卡"

# 幂等重放（同 key）→ 打卡 id 不变
call POST /checkins "$CK_BODY" "$TOKEN_A" "$CK_IDEM"
expect_code 200 "打卡幂等重放"
[ "$(jqr ".[] | select(.teamId==\"$TEAM_ID\") | .id")" = "$CHECKIN_ID" ] && pass "重放 checkinId 不变（幂等）" || fail "重放产生新打卡"

# B 视角：列当日打卡，应看到 A 的
call GET "/teams/$TEAM_ID/checkins?date=$TODAY" "" "$TOKEN_B"
expect_code 200 "B 列当日打卡"
[ "$(jqr ".[] | select(.id==\"$CHECKIN_ID\") | .userId")" = "$USER_A" ] && pass "B 看到 A 的打卡" || fail "B 未看到 A 的打卡"

# ============================================================
section "6. 表情回应（B 对 A 的打卡）"
call POST "/checkins/$CHECKIN_ID/reactions" '{"emoji":"muscle"}' "$TOKEN_B" "$(uuid)"
expect_code 200 "B 发 muscle"
[ "$(jqr '.emoji')" = "muscle" ] && [ "$(jqr '.userId')" = "$USER_B" ] && pass "回应 emoji=muscle / userId=B" || fail "回应字段不符 | $RESP_BODY"

call GET "/checkins/$CHECKIN_ID/reactions" "" "$TOKEN_A"
expect_code 200 "A 列回应"
[ "$(jqr "[.[] | select(.userId==\"$USER_B\")] | length")" = "1" ] && pass "列表含 B 的回应" || fail "列表缺 B 的回应"

# 同一用户改表情（uq(checkin,user) → 更新而非新增）
call POST "/checkins/$CHECKIN_ID/reactions" '{"emoji":"fire"}' "$TOKEN_B" "$(uuid)"
expect_code 200 "B 改 fire"
call GET "/checkins/$CHECKIN_ID/reactions" "" "$TOKEN_A"
RCOUNT=$(jqr 'length')
[ "$RCOUNT" = "1" ] && [ "$(jqr '.[0].emoji')" = "fire" ] && pass "仍 1 条且 emoji=fire（upsert 一人一表情）" || fail "回应数=$RCOUNT 或未更新为 fire"

# ============================================================
echo ""
if [ "$FAILS" -eq 0 ]; then
  echo -e "${GREEN}全部通过 ✓${NC}  端到端链路：登录→同步(push/pull/幂等/LWW)→建团/加入→显式 Team 分享→表情 均符合契约。"
  exit 0
else
  echo -e "${RED}有 $FAILS 项断言失败 ✗${NC}  见上方 ✗ 行。"
  exit 1
fi
