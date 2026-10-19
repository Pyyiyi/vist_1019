#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3000/api/v1}"
OUT_DIR="${OUT_DIR:-$(pwd)}"
JAR="$OUT_DIR/h5.txt"
TOKEN_FILE="$OUT_DIR/h5.token"
mkdir -p "$OUT_DIR"
D1="$(date -d '+1 day' +%F)"
ID_NO="P$(date +%s)"

rm -f "$JAR" "$TOKEN_FILE"
curl -sS -c "$JAR" "$BASE_URL/auth/csrf" >/dev/null
CSRF="$(awk '$6 == "vs.csrf" { print $7 }' "$JAR" | tail -1)"

RESPONSE="$(curl -sS -b "$JAR" -c "$JAR" \
  -H 'Content-Type: application/json' \
  -H "X-CSRF-Token: $CSRF" \
  --data "{\"visitor_name\":\"钱多\",\"visitor_phone\":\"13700137000\",\"visitor_id_no\":\"$ID_NO\",\"visitor_type_id\":\"55555555-5555-4555-8555-555555555551\",\"host_id\":\"33333333-3333-4333-8333-333333333333\",\"visit_start\":\"${D1}T13:00:00+08:00\",\"visit_end\":\"${D1}T14:00:00+08:00\",\"reason\":\"咨询入学\",\"consent\":{\"safety\":true,\"privacy\":true}}" \
  "$BASE_URL/visitor/appointments")"

if ! printf '%s' "$RESPONSE" | jq -e '.code == 0 and (.data.visitor_token // .data.visitorToken)' >/dev/null; then
  printf '访客夹具提交失败: %s\n' "$RESPONSE" >&2
  exit 1
fi

printf '%s' "$RESPONSE" | jq -r '.data.visitor_token // .data.visitorToken' > "$TOKEN_FILE"
printf '已生成: %s %s\n' "$JAR" "$TOKEN_FILE"
