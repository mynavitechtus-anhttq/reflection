#!/usr/bin/env bash
# coverage.sh — chỉ ra chỗ hổng giữa dấu vết máy để lại và những gì đã ghi.
#
# Không tự viết gì. Chỉ trả lời: còn ngày nào chưa ghi, mã ticket nào có
# trong commit/PR mà chưa thấy trong bản ghi, ngày nào có phiên Claude
# nhưng không có commit (thường là việc không đụng repo — phải hỏi).
#
#   ./coverage.sh 2026-08-03 2026-08-07 ~/reflections
#   ./coverage.sh --week  2026-W32
#   ./coverage.sh --month 2026-08

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$HERE/_lib.sh"
COLLECT="$HERE/collect.sh"

usage() { sed -n '2,13p' "$0"; exit "${1:-0}"; }

FROM=""; TO=""; ROOT=""; MODE="day"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage ;;
    --week)
      # 2026-W32 -> thứ Hai tới thứ Sáu của tuần ISO đó
      wk="${2:-}"; shift 2
      [[ "$wk" =~ ^([0-9]{4})-W([0-9]{1,2})$ ]] || { echo "Tuần không hợp lệ: $wk" >&2; exit 1; }
      y="${BASH_REMATCH[1]}"; w="${BASH_REMATCH[2]}"
      jan4=$(epoch_of "$y-01-04 12:00:00")
      dow=$(fmt_epoch "$jan4" "+%u")
      mon1=$(( jan4 - (dow - 1) * 86400 ))
      mon=$(( mon1 + (10#$w - 1) * 604800 ))
      FROM=$(fmt_epoch "$mon" "+%Y-%m-%d")
      TO=$(fmt_epoch $(( mon + 4 * 86400 )) "+%Y-%m-%d")
      MODE="week"
      ;;
    --month)
      # 2026-08 -> ngày 1 tới ngày cuối tháng
      mo="${2:-}"; shift 2
      [[ "$mo" =~ ^([0-9]{4})-([0-9]{2})$ ]] || { echo "Tháng không hợp lệ: $mo" >&2; exit 1; }
      FROM="$mo-01"
      ny="${BASH_REMATCH[1]}"; nm=$(( 10#${BASH_REMATCH[2]} + 1 ))
      [[ "$nm" -gt 12 ]] && { nm=1; ny=$(( ny + 1 )); }
      nxt=$(epoch_of "$(printf '%04d-%02d-01 12:00:00' "$ny" "$nm")")
      TO=$(fmt_epoch $(( nxt - 86400 )) "+%Y-%m-%d")
      MODE="month"
      ;;
    *)
      if   [[ -z "$FROM" ]]; then FROM="$1"
      elif [[ -z "$TO"   ]]; then TO="$1"
      else ROOT="$1"; fi
      shift ;;
  esac
done

[[ -z "$FROM" ]] && usage 1
[[ -z "$TO"   ]] && TO="$FROM"
# Thứ tự: tham số dòng lệnh → biến môi trường → config → mặc định.
if [[ -z "$ROOT" ]]; then
  CFG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/reflection/config.json"
  ROOT="${REFLECT_ROOT:-}"
  if [[ -z "$ROOT" && -f "$CFG_FILE" ]]; then
    ROOT=$(jq -r '.root // empty' "$CFG_FILE" 2>/dev/null)
  fi
  ROOT="${ROOT:-$HOME/reflections}"
fi
ROOT="${ROOT/#\~/$HOME}"

# ── Vị trí file, theo cây thư mục tháng → tuần ────────────────────────────
#   <root>/2026-08/W1/2026-08-04.md   ·   <root>/2026-08/W1/W1.md
# Tuần đánh số theo vị trí trong tháng (W1 là tuần chứa ngày 1), không phải
# số tuần ISO — người ta nhớ "tuần 2 của tháng 8".
week_of() {
  local d="$1" first dow offset
  first="${d:0:8}01"
  dow=$(fmt_epoch "$(epoch_of "$first 12:00:00")" "+%u")   # thứ của ngày 1
  offset=$(( 10#${d:8:2} + dow - 2 ))
  echo $(( offset / 7 + 1 ))
}
day_file()   { echo "$ROOT/${1:0:7}/W$(week_of "$1")/$1.md"; }
week_file()  { echo "$ROOT/${1:0:7}/W$(week_of "$1")/W$(week_of "$1").md"; }
month_file() { echo "$ROOT/${1:0:7}/${1:0:7}.md"; }

# ── Duyệt từng ngày trong khoảng ──────────────────────────────────────────
cur=$(epoch_of "$FROM 12:00:00")
end=$(epoch_of "$TO 12:00:00")

missing_days=(); silent_days=(); untracked=(); missing_weeks=()

# Quét cả tháng mà gọi GitHub cho từng ngày thì mất vài phút. Ở mức tháng
# chỉ cần biết ngày/tuần nào chưa ghi — chi tiết PR đã soát ở mức tuần.
[[ "$MODE" == "month" ]] && export REFLECT_SKIP_GITHUB=1

while [[ "$cur" -le "$end" ]]; do
  d=$(fmt_epoch "$cur" "+%Y-%m-%d")
  cur=$(( cur + 86400 ))

  raw=$("$COLLECT" "$d" --json 2>/dev/null) || continue
  nc=$(echo "$raw" | jq '.git     | map(select(.sha)) | length')
  ng=$(echo "$raw" | jq '.github  | length')
  np=$(echo "$raw" | jq '.prompts | length')
  nb=$(echo "$raw" | jq '.backlog | length')

  # Tuần nào có ngày làm việc mà chưa có bản tổng hợp — chỉ soát ở chế độ
  # tháng, vì viết tháng từ các tuần thủng thì ra bản thiếu.
  if [[ "$MODE" == "month" ]]; then
    wf=$(week_file "$d")
    # Một phiên lẻ ngày Chủ nhật không làm nên một tuần làm việc.
    if [[ ! -f "$wf" ]] && [[ ! " ${missing_weeks[*]:-} " == *" $(basename "$wf") "* ]]; then
      [[ "$nc" -gt 0 || "$nb" -gt 0 || "$np" -ge 10 ]] && missing_weeks+=("$(basename "$wf")")
    fi
  fi

  # Ngày hoàn toàn im lặng thì bỏ qua — nhiều khả năng là nghỉ.
  [[ "$nc" -eq 0 && "$ng" -eq 0 && "$np" -eq 0 && "$nb" -eq 0 ]] && continue

  f=$(day_file "$d")
  if [[ ! -f "$f" ]]; then
    extra=""; [[ "$nb" -gt 0 ]] && extra="  ticket:$nb"
    missing_days+=("$d  (commit:$nc  pr:$ng  phiên:$np$extra)")
    continue
  fi

  # Mã ticket trong commit/PR/Backlog mà bản ghi không nhắc tới.
  # Backlog chỉ tính ticket có log giờ: ticket mới tạo để mai làm thì không
  # thuộc về bản ghi hôm nay, báo lên chỉ thành nhiễu.
  ids=$(echo "$raw" \
    | jq -r '[(.git[]?.subject // ""), (.github[]?.title // ""),
              (.backlog[]? | select(.hours > 0) | .key)] | .[]' \
    | grep -oE '[A-Z][A-Z0-9_]{2,}-[0-9]+' | sort -u)
  for id in $ids; do
    grep -q "$id" "$f" 2>/dev/null || untracked+=("$d  $id")
  done

  # Có trao đổi nhưng không commit: gần như chắc là việc ngoài repo
  # (hỗ trợ team, review, họp, điều tra) — thứ chỉ hỏi mới biết.
  # Bỏ qua khi ngày đó đã có ticket Backlog: phần việc ngoài repo đã có
  # dấu vết riêng, và vòng đối chiếu ticket ở trên lo nốt phần còn lại.
  [[ "$nc" -eq 0 && "$np" -gt 5 && "$nb" -eq 0 ]] \
    && silent_days+=("$d  ($np lượt trao đổi, 0 commit)")
done

echo "# Rà soát $FROM → $TO"
echo "_gốc lưu: ${ROOT}_"
echo

if [[ ${#missing_days[@]} -gt 0 ]]; then
  echo "## Ngày có dấu vết nhưng chưa ghi"
  printf -- '- %s\n' "${missing_days[@]}"
  echo
fi

if [[ ${#untracked[@]} -gt 0 ]]; then
  echo "## Ticket xuất hiện trong commit/PR nhưng bản ghi không nhắc"
  printf -- '- %s\n' "${untracked[@]}"
  echo
fi

if [[ ${#silent_days[@]} -gt 0 ]]; then
  echo "## Ngày làm việc ngoài repo — cần hỏi lại"
  printf -- '- %s\n' "${silent_days[@]}"
  echo
fi

if [[ ${#missing_weeks[@]} -gt 0 ]]; then
  echo "## Tuần chưa có bản tổng hợp"
  printf -- '- %s\n' "${missing_weeks[@]}"
  echo "Viết tháng từ các tuần còn thiếu sẽ ra bản không đầy đủ."
  echo
fi

if [[ ${#missing_days[@]} -eq 0 && ${#untracked[@]} -eq 0 \
   && ${#silent_days[@]} -eq 0 && ${#missing_weeks[@]} -eq 0 ]]; then
  echo "Không thấy chỗ hổng nào."
fi
