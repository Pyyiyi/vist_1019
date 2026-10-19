#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3000/api/v1}"
OUT_DIR="${OUT_DIR:-$(pwd)}"
mkdir -p "$OUT_DIR"

login() {
  local username="$1"
  local jar="$2"
  rm -f "$jar"
  curl -sS -c "$jar" "$BASE_URL/auth/csrf" >/dev/null
  local response
  response="$(curl -sS -b "$jar" -c "$jar" \
    -H 'Content-Type: application/json' \
    --data "{\"username\":\"$username\",\"password\":\"abc@123\"}" \
    "$BASE_URL/auth/login")"
  if ! printf '%s' "$response" | jq -e '.code == 0 and .data.user.role_code != null' >/dev/null; then
    printf '登录失败: %s -> %s\n' "$username" "$response" >&2
    return 1
  fi
}

login admin "$OUT_DIR/admin.txt"
login guard01 "$OUT_DIR/guard.txt"
login T001 "$OUT_DIR/host.txt"

printf '已生成: %s/admin.txt %s/guard.txt %s/host.txt\n' "$OUT_DIR" "$OUT_DIR" "$OUT_DIR"
