#!/usr/bin/env bash
# backlog.sh — ticket từ space Backlog nội bộ, nhìn về sau hoặc nhìn tới trước.
#
# Hai chế độ, dùng cho hai mục khác nhau của bản ghi:
#   mặc định  — ticket bạn ĐÃ động tới trong khoảng (tạo, sửa, comment) → mục việc đã làm
#   --plan    — ticket CHƯA đóng có lịch rơi vào khoảng                 → mục việc tiếp theo
#
# CHỈ gọi tới space khai trong config. Không tự dò, không tự đoán space
# khác. Space của khách hàng thì đừng khai vào đây — ticket của khách cứ
# dán tay khi được hỏi.
#
#   ./backlog.sh 2026-08-04                       # một ngày, việc đã làm
#   ./backlog.sh 2026-08-01 2026-08-31            # một khoảng
#   ./backlog.sh --plan 2026-08-10 2026-08-14     # kế hoạch tuần tới
#   ./backlog.sh 2026-08-04 --json
#
# Cấu hình — ~/.config/reflection/config.json:
#   { "backlog": { "base": "https://myspace.backlog.jp" } }
# Khoá đọc từ $BACKLOG_API_KEY, hoặc .backlog.apiKey trong config.
# Đặt config chmod 600 nếu để khoá trong đó.

set -uo pipefail
# shellcheck source=_lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

CFG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/reflection/config.json"

FROM=""; TO=""; OUT_JSON=0; MODE="done"
for a in "$@"; do
  case "$a" in
    --json) OUT_JSON=1 ;;
    --plan) MODE="plan" ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) if [[ -z "$FROM" ]]; then FROM="$a"; else TO="$a"; fi ;;
  esac
done
[[ -z "$FROM" ]] && { sed -n '2,22p' "$0"; exit 1; }
[[ -z "$TO"   ]] && TO="$FROM"

BASE=""
[[ -f "$CFG_FILE" ]] && BASE=$(jq -r '.backlog.base // empty' "$CFG_FILE" 2>/dev/null)
BASE="${BACKLOG_BASE:-$BASE}"
BASE="${BASE%/}"

KEY="${BACKLOG_API_KEY:-}"
if [[ -z "$KEY" && -f "$CFG_FILE" ]]; then
  KEY=$(jq -r '.backlog.apiKey // empty' "$CFG_FILE" 2>/dev/null)
fi

if [[ -z "$BASE" || -z "$KEY" ]]; then
  # Thiếu cấu hình không phải lỗi — chỉ là nhánh này không dùng.
  [[ "$OUT_JSON" == "1" ]] && echo '[]' || echo "_Backlog chưa cấu hình_"
  exit 0
fi

# ── Gọi API ───────────────────────────────────────────────────────────────
# Truyền URL qua stdin (`curl -K -`) thay vì đối số, để khoá không nằm
# trong bảng tiến trình — `ps` trên máy dùng chung đọc được đối số.
bl_get() {
  printf 'url = "%s/api/v2/%s%sapiKey=%s"\nsilent\nfail\n' \
    "$BASE" "$1" "$([[ "$1" == *\?* ]] && echo '&' || echo '?')" "$KEY" \
  | curl -K - 2>/dev/null
}

ME=$(bl_get "users/myself")
UID_=$(echo "$ME" | jq -r '.id // empty' 2>/dev/null)
if [[ -z "$UID_" ]]; then
  echo "Không gọi được Backlog ($BASE). Kiểm tra base URL và API key." >&2
  [[ "$OUT_JSON" == "1" ]] && echo '[]'
  exit 1
fi

# ── Chế độ nhìn tới trước: ticket chưa đóng có lịch trong khoảng ──────────
# Ở đây start/due mới là thứ đúng: câu hỏi không còn là "đã đụng vào gì"
# mà là "sắp tới phải làm gì". Trạng thái 1/2/3 = chưa đóng.
if [[ "$MODE" == "plan" ]]; then
  ST="statusId[]=1&statusId[]=2&statusId[]=3"
  Q="assigneeId[]=$UID_&$ST&count=100"
  PLAN=$(jq -sc 'add // []' \
    <(bl_get "issues?$Q&dueDateSince=$FROM&dueDateUntil=$TO") \
    <(bl_get "issues?$Q&startDateSince=$FROM&startDateUntil=$TO"))

  RESULT=$(echo "$PLAN" | jq -c '
    map({ key: .issueKey, summary: .summary, status: .status.name,
          start: (.startDate // "" | .[0:10]), due: (.dueDate // "" | .[0:10]) })
    | unique_by(.key)
    | sort_by(.start, .due)
  ')

  if [[ "$OUT_JSON" == "1" ]]; then echo "$RESULT"; exit 0; fi

  n=$(echo "$RESULT" | jq 'length')
  echo "## Kế hoạch Backlog ($n ticket, $FROM → $TO)"
  if [[ "$n" -gt 0 ]]; then
    echo "$RESULT" | jq -r '.[] |
      "- \(.key) \(.summary)  _(\(.status)"
      + (if .start != "" or .due != "" then " · \(.start)→\(.due)" else "" end) + ")_"'
  else
    echo "_không có ticket nào lên lịch trong khoảng này_"
  fi
  exit 0
fi

# ── Hoạt động, không phải ngày bắt đầu / hạn chót ─────────────────────────
# Ticket kéo dài hai tuần mà lọc theo startDate–dueDate thì ngày nào cũng
# hiện, kể cả ngày không đụng tới. Lọc theo hoạt động mới trả lời đúng câu
# "hôm đó tôi làm gì".
#   1 課題の追加 · 2 課題の更新 · 3 課題にコメント
#   4 課題の削除 · 5-7 Wiki · 12 プロジェクト参加 · 13 脱退 · 14 一括更新
TYPES="activityTypeId[]=1&activityTypeId[]=2&activityTypeId[]=3&activityTypeId[]=14"

# Khoảng ngày tính theo giờ máy, cùng mốc 04:00 với collect.sh.
DAY_START_HOUR="${REFLECT_DAY_START_HOUR:-4}"
S=$(epoch_of "$(printf '%s %02d:00:00' "$FROM" "$DAY_START_HOUR")")
E=$(( $(epoch_of "$(printf '%s %02d:00:00' "$TO" "$DAY_START_HOUR")") + 86400 ))
S_ISO=$(fmt_epoch "$S" "+%Y-%m-%dT%H:%M:%S")
E_ISO=$(fmt_epoch "$E" "+%Y-%m-%dT%H:%M:%S")

# Phân trang lùi bằng maxId cho tới khi vượt qua đầu khoảng.
ALL="[]"; MAXID=""; PAGE=0
while [[ $PAGE -lt 20 ]]; do
  PAGE=$(( PAGE + 1 ))
  q="users/$UID_/activities?count=100&$TYPES"
  [[ -n "$MAXID" ]] && q="$q&maxId=$MAXID"
  batch=$(bl_get "$q")
  n=$(echo "$batch" | jq 'length' 2>/dev/null) || break
  [[ -z "$n" || "$n" -eq 0 ]] && break

  ALL=$(jq -sc '.[0] + .[1]' <(echo "$ALL") <(echo "$batch"))

  oldest=$(echo "$batch" | jq -r '.[-1].created')
  oldest_epoch=$(epoch_of_utc "$oldest" 2>/dev/null) || break
  [[ "$oldest_epoch" -lt "$S" ]] && break
  MAXID=$(echo "$batch" | jq -r '.[-1].id')
done

RESULT=$(echo "$ALL" | jq -c --arg s "$S_ISO" --arg e "$E_ISO" '
  map(
    select((.created | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime
            | strflocaltime("%Y-%m-%dT%H:%M:%S")) as $t | $t >= $s and $t < $e)
    | {
        key:  ((.project.projectKey // "?") + "-" + ((.content.key_id // 0) | tostring)),
        summary: (.content.summary // ""),
        kind: (if .type == 1 then "tạo" elif .type == 3 then "comment" else "cập nhật" end),
        # Số giờ log trong ngày và trạng thái là bằng chứng mạnh nhất cho
        # "hôm nay có thật sự làm ticket này không". Thiếu hai trường này
        # thì `kinds: "cập nhật"` trông y hệt một lần sửa mô tả, và ticket
        # làm cả buổi dễ bị bỏ ra khỏi bản ghi.
        hours: ([ .content.changes[]? | select(.field == "actualHours")
                  | ((.new_value | tonumber? // 0) - (.old_value | tonumber? // 0)) ] | add // 0),
        done:  (([ .content.changes[]? | select(.field == "status")
                   | (.new_value | tonumber? // 0) ] | max // 0) >= 3),
        at:   (.created | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime | strflocaltime("%H:%M"))
      }
  )
  # Một ticket động vào năm lần trong ngày vẫn là một dòng.
  | group_by(.key)
  | map({ key: .[0].key, summary: (map(.summary) | map(select(. != "")) | first // ""),
          kinds: (map(.kind) | unique | join("/")),
          hours: (map(.hours) | add), done: (map(.done) | any),
          at: (map(.at) | min) })
  | sort_by(.at)
')

if [[ "$OUT_JSON" == "1" ]]; then
  echo "$RESULT"
  exit 0
fi

n=$(echo "$RESULT" | jq 'length')
echo "## Backlog ($n ticket, $FROM → $TO)"
if [[ "$n" -gt 0 ]]; then
  echo "$RESULT" | jq -r '.[] |
    "- \(.at) · \(.key) \(.summary)  _(\(.kinds)"
    + (if .hours > 0 then " · \(.hours)h" else "" end)
    + (if .done then " · xong" else "" end) + ")_"'
else
  echo "_không có_"
fi
