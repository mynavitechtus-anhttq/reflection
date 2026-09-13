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

# ── Ngày làm việc, cùng mốc 04:00 với collect.sh và backlog.sh ────────────
# Log giờ lúc 1h sáng là phần việc của ngày hôm trước. Lọc theo ngày lịch
# thì những lần log đó rơi nhầm sang hôm sau, và báo cáo thiếu ticket.
DAY_START_HOUR="${REFLECT_DAY_START_HOUR:-4}"
S=$(epoch_of "$(printf '%s %02d:00:00' "$DAY" "$DAY_START_HOUR")")
E=$(( S + 86400 ))
S_ISO=$(fmt_epoch "$S" "+%Y-%m-%dT%H:%M:%S")
E_ISO=$(fmt_epoch "$E" "+%Y-%m-%dT%H:%M:%S")

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
  # Lùi thêm một tháng: cần cả lịch sử log của những ngày trước để biết
  # phần nào của ticket đã tính rồi.
  [[ "${oldest:0:10}" < "$(fmt_epoch $(( S - 30 * 86400 )) "+%Y-%m-%d")" ]] && break
  MAXID=$(echo "$batch" | jq -r '.[-1].id')
done

# Mọi ticket có hoạt động hôm nay, kể cả chưa log giờ — dùng để đánh dấu
# "continue" ở phần Tomorrow: đã đụng vào rồi thì mai là làm tiếp.
TOUCHED=$(echo "$ALL" | jq -c --arg s "$S_ISO" --arg e "$E_ISO" '
  map(select((.created | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime
              | strflocaltime("%Y-%m-%dT%H:%M:%S")) as $t | $t >= $s and $t < $e))
  | map((.project.projectKey // "?") + "-" + ((.content.key_id // 0) | tostring))
  | unique')

# Giờ log riêng trong ngày, gom theo ticket. Ticket kéo dài cả tuần mà mỗi
# ngày log một ít thì mỗi ngày chỉ tính phần của ngày đó.
DELTA=$(echo "$ALL" | jq -c --arg s "$S_ISO" --arg e "$E_ISO" '
  map(select((.created | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime
              | strflocaltime("%Y-%m-%dT%H:%M:%S")) as $t | $t >= $s and $t < $e))
  | map({
      key: ((.project.projectKey // "?") + "-" + ((.content.key_id // 0) | tostring)),
      hours: ([ .content.changes[]? | select(.field == "actualHours")
                | ((.new_value | tonumber? // 0) - (.old_value | tonumber? // 0)) ] | add // 0)
    })
  | group_by(.key)
  | map({ key: .[0].key, hours: (map(.hours) | add) })
  | INDEX(.key) | map_values(.hours)')

# Giờ đã log TRƯỚC ngày này, gom theo ticket. Dùng để biết phần nào của
# một ticket dài ngày đã được tính cho những ngày trước rồi.
PRIOR=$(echo "$ALL" | jq -c --arg s "$S_ISO" '
  map(select((.created | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime
              | strflocaltime("%Y-%m-%dT%H:%M:%S")) < $s))
  | map({
      key: ((.project.projectKey // "?") + "-" + ((.content.key_id // 0) | tostring)),
      hours: ([ .content.changes[]? | select(.field == "actualHours")
                | ((.new_value | tonumber? // 0) - (.old_value | tonumber? // 0)) ] | add // 0)
    })
  | group_by(.key)
  | map({ key: .[0].key, hours: (map(.hours) | add) })
  | INDEX(.key) | map_values(.hours)')

# Ticket thuộc về ngày này: khoảng startDate–dueDate có chứa nó. Lấy cả
# ticket đã đóng, vì phần lớn ticket trong ngày là đóng luôn cuối ngày.
ST_ALL="statusId[]=1&statusId[]=2&statusId[]=3&statusId[]=4"
QA="assigneeId[]=$UID_&$ST_ALL&count=100"
SCOPE=$(jq -sc 'add // []' \
  <(bl_get "issues?$QA&startDateUntil=$DAY&dueDateSince=$DAY") \
  <(bl_get "issues?$QA&startDateSince=$DAY&startDateUntil=$DAY") \
  | jq -c 'unique_by(.issueKey)')

# Giờ hiển thị cho mỗi ticket:
#   - Có log trong chính ngày này thì lấy đúng phần đó.
#   - Không có, mà đây là ngày hết hạn của ticket: lấy phần còn lại chưa
#     tính cho ngày nào (tổng trừ đi những gì đã log trước đó). Đây là
#     trường hợp log muộn — làm ngày 11 nhưng tới ngày 13 mới ghi giờ.
#   - Còn lại thì không tính, vì chưa có gì chứng minh ngày đó có làm.
TODAY=$(echo "$SCOPE" | jq -c --argjson d "$DELTA" --argjson p "$PRIOR" --arg day "$DAY" '
  map({
    key: .issueKey,
    summary: .summary,
    done: ((.status.id // 0) >= 3),
    hours: (($d[.issueKey] // 0) as $delta
            | ($p[.issueKey] // 0) as $before
            | if $delta > 0 then $delta
              elif (.dueDate // "")[0:10] == $day
              then (((.actualHours // 0) - $before) | if . > 0 then . else 0 end)
              else 0 end)
  })
  | map(select(.hours > 0))
  | sort_by(.key)')

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
