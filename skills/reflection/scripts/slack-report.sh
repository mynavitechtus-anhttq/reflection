#!/usr/bin/env bash
# slack-report.sh — báo cáo ngày dạng markdown, dán thẳng lên channel.
#
#   Today:     ticket đã log giờ hôm nay, kèm số giờ và trạng thái
#   Tomorrow:  ticket có lịch vào ngày làm việc kế tiếp
#
# Số giờ lấy từ chính các lần bạn sửa actualHours trong ngày (cộng phần
# chênh lệch), không phải tổng tích luỹ của ticket — nên ticket kéo dài
# nhiều ngày vẫn ra đúng số giờ của riêng hôm nay.
#
#   ./slack-report.sh                 # hôm nay
#   ./slack-report.sh 2026-08-07      # ngày cụ thể
#
# Ngày mai bỏ qua thứ Bảy và Chủ nhật: chạy chiều thứ Sáu thì phần
# Tomorrow là thứ Hai.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$HERE/_lib.sh"

CFG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/reflection/config.json"

DAY="${1:-$(date "+%Y-%m-%d")}"
[[ "$DAY" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { sed -n '2,17p' "$0"; exit 1; }

BASE=""; KEY="${BACKLOG_API_KEY:-}"
if [[ -f "$CFG_FILE" ]]; then
  BASE=$(jq -r '.backlog.base // empty' "$CFG_FILE" 2>/dev/null)
  [[ -z "$KEY" ]] && KEY=$(jq -r '.backlog.apiKey // empty' "$CFG_FILE" 2>/dev/null)
fi
BASE="${BACKLOG_BASE:-$BASE}"; BASE="${BASE%/}"
[[ -z "$BASE" || -z "$KEY" ]] && { echo "Backlog chưa cấu hình." >&2; exit 1; }

bl_get() {
  printf 'url = "%s/api/v2/%s%sapiKey=%s"\nsilent\nfail\n' \
    "$BASE" "$1" "$([[ "$1" == *\?* ]] && echo '&' || echo '?')" "$KEY" \
  | curl -K - 2>/dev/null
}

UID_=$(bl_get "users/myself" | jq -r '.id // empty')
[[ -z "$UID_" ]] && { echo "Không gọi được Backlog ($BASE)." >&2; exit 1; }

# ── Ngày làm việc kế tiếp ─────────────────────────────────────────────────
NEXT_EPOCH=$(( $(epoch_of "$DAY 12:00:00") + 86400 ))
while :; do
  d=$(fmt_epoch "$NEXT_EPOCH" "+%u")          # 6 = thứ Bảy, 7 = Chủ nhật
  [[ "$d" -le 5 ]] && break
  NEXT_EPOCH=$(( NEXT_EPOCH + 86400 ))
done
NEXT=$(fmt_epoch "$NEXT_EPOCH" "+%Y-%m-%d")

# ── Today: gom mọi lần sửa actualHours trong ngày ─────────────────────────
# Một ticket có thể được sửa nhiều lần; cộng hết phần chênh lệch lại.
# status 3 = đã xử lý, 4 = đã đóng → coi là xong.
ALL="[]"; MAXID=""; PAGE=0
while [[ $PAGE -lt 10 ]]; do
  PAGE=$(( PAGE + 1 ))
  q="users/$UID_/activities?count=100&activityTypeId[]=1&activityTypeId[]=2&activityTypeId[]=3"
  [[ -n "$MAXID" ]] && q="$q&maxId=$MAXID"
  batch=$(bl_get "$q")
  n=$(echo "$batch" | jq 'length' 2>/dev/null) || break
  [[ -z "$n" || "$n" -eq 0 ]] && break
  ALL=$(jq -sc 'add' <(echo "$ALL") <(echo "$batch"))
  oldest=$(echo "$batch" | jq -r '.[-1].created')
  [[ "${oldest:0:10}" < "$DAY" ]] && break
  MAXID=$(echo "$batch" | jq -r '.[-1].id')
done

# Mọi ticket có hoạt động hôm nay, kể cả chưa log giờ — dùng để đánh dấu
# "continue" ở phần Tomorrow: đã đụng vào rồi thì mai là làm tiếp.
TOUCHED=$(echo "$ALL" | jq -c --arg d "$DAY" '
  map(select((.created | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime
              | strflocaltime("%Y-%m-%d")) == $d))
  | map((.project.projectKey // "?") + "-" + ((.content.key_id // 0) | tostring))
  | unique')

TODAY=$(echo "$ALL" | jq -c --arg d "$DAY" '
  map(select((.created | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime
              | strflocaltime("%Y-%m-%d")) == $d))
  | map({
      key: ((.project.projectKey // "?") + "-" + ((.content.key_id // 0) | tostring)),
      summary: (.content.summary // ""),
      hours: ([ .content.changes[]? | select(.field == "actualHours")
                | ((.new_value | tonumber? // 0) - (.old_value | tonumber? // 0)) ] | add // 0),
      done:  (([ .content.changes[]? | select(.field == "status")
                 | (.new_value | tonumber? // 0) ] | max // 0) >= 3)
    })
  | group_by(.key)
  | map({ key: .[0].key,
          summary: (map(.summary) | map(select(. != "")) | first // ""),
          hours: (map(.hours) | add),
          done:  (map(.done) | any) })
  | map(select(.hours > 0))
  | sort_by(.key)
')

# ── Tomorrow: ticket chưa đóng có lịch vào ngày làm việc kế tiếp ──────────
ST="statusId[]=1&statusId[]=2&statusId[]=3"
Q="assigneeId[]=$UID_&$ST&count=100"
PLAN=$(jq -sc 'add // []' \
  <(bl_get "issues?$Q&startDateSince=$NEXT&startDateUntil=$NEXT") \
  <(bl_get "issues?$Q&dueDateSince=$NEXT&dueDateUntil=$NEXT") \
  | jq -c 'map({key: .issueKey, summary: .summary}) | unique_by(.key) | sort_by(.key)')

# ── Render ────────────────────────────────────────────────────────────────
# Giờ viết theo lối dấu phẩy thập phân, bỏ phần lẻ bằng 0: 3 · 0,5 · 3,5
JQ_HOURS='def h: (. * 10 | round / 10) as $v
  | (if $v == ($v | floor) then ($v | floor | tostring)
     else ($v | tostring | sub("\\."; ",")) end);'

echo "Today:"
echo
if [[ "$(echo "$TODAY" | jq 'length')" -gt 0 ]]; then
  echo "$TODAY" | jq -r --arg b "$BASE" "$JQ_HOURS"'
    .[] | "* [\(.key)](\($b)/view/\(.key)) \(.summary) — `\(.hours | h)h\(if .done then " done" else "" end)`"'
else
  echo "_chưa log giờ cho ticket nào hôm nay_"
fi

echo
echo "Tomorrow:"
echo
if [[ "$(echo "$PLAN" | jq 'length')" -gt 0 ]]; then
  echo "$PLAN" | jq -r --arg b "$BASE" --argjson t "$TOUCHED" '.[] as $p |
    ($t | index($p.key)) as $seen |
    "* [\($p.key)](\($b)/view/\($p.key)) \($p.summary)" + (if $seen then " continue" else "" end)'
else
  echo "_chưa có ticket nào lên lịch_"
fi
