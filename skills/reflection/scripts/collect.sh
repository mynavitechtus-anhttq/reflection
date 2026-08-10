#!/usr/bin/env bash
# collect.sh — gom dữ liệu thô cho một ngày làm việc.
#
# Nguồn: phiên Claude Code, git commit, PR tạo/review, tài liệu markdown.
# Không gọi ra hệ thống của khách. Không ghi gì ngoài stdout.
#
#   ./collect.sh                 # hôm nay
#   ./collect.sh 2026-08-06      # ngày cụ thể
#   ./collect.sh -1              # hôm qua
#   ./collect.sh --json          # máy đọc thay vì người đọc

set -uo pipefail
# shellcheck source=_lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

# ── Ngày làm việc tính từ 04:00 local tới 04:00 hôm sau ───────────────────
# Commit lúc 1h sáng gần như luôn là phần việc của ngày hôm trước.
DAY_START_HOUR="${REFLECT_DAY_START_HOUR:-4}"

CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/reflection"
CFG_FILE="$CFG_DIR/config.json"
SESSION_DIR="$HOME/.claude/projects"

DATE_ARG=""
OUT_JSON=0
for a in "$@"; do
  case "$a" in
    --json) OUT_JSON=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) DATE_ARG="$a" ;;
  esac
done

# ── Giải nghĩa tham số ngày ───────────────────────────────────────────────
if [[ -z "$DATE_ARG" ]]; then
  DAY=$(date "+%Y-%m-%d")
elif [[ "$DATE_ARG" =~ ^-[0-9]+$ ]]; then
  DAY=$(shift_days "$DATE_ARG")
elif [[ "$DATE_ARG" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  DAY="$DATE_ARG"
elif [[ "$DATE_ARG" =~ ^[0-9]{4}$ ]]; then          # 0806 -> năm hiện tại
  DAY="$(date +%Y)-${DATE_ARG:0:2}-${DATE_ARG:2:2}"
else
  echo "Không hiểu tham số ngày: $DATE_ARG" >&2; exit 1
fi

START_LOCAL=$(printf '%s %02d:00:00' "$DAY" "$DAY_START_HOUR")
START_EPOCH=$(epoch_of "$START_LOCAL")
END_EPOCH=$((START_EPOCH + 86400))
START_ISO=$(fmt_epoch "$START_EPOCH" "+%Y-%m-%dT%H:%M:%S")
END_ISO=$(fmt_epoch "$END_EPOCH" "+%Y-%m-%dT%H:%M:%S")

# File có lần ghi cuối trước lúc mở ngày thì chắc chắn không chứa dòng nào
# trong ngày — bỏ sớm để khỏi phải đọc.
sessions_touched_in_window() {
  find "$SESSION_DIR" -maxdepth 2 -name '*.jsonl' 2>/dev/null \
  | while read -r f; do
      m=$(file_mtime "$f" 2>/dev/null) || continue
      [[ "$m" -ge "$START_EPOCH" ]] && echo "$f"
    done
}

# ── Repo: lấy từ cấu hình nếu có, còn không thì dò từ phiên Claude ────────
# Đọc thẳng trường cwd trong file phiên — chắc hơn giải mã tên thư mục,
# vì tên repo cũng chứa dấu gạch ngang.
discover_repos() {
  if [[ -f "$CFG_FILE" ]] && jq -e '.repos | length > 0' "$CFG_FILE" >/dev/null 2>&1; then
    jq -r '.repos[]' "$CFG_FILE"
    return
  fi
  find "$SESSION_DIR" -maxdepth 2 -name '*.jsonl' 2>/dev/null \
    | while read -r f; do head -20 "$f" | jq -r 'select(.cwd) | .cwd' 2>/dev/null | head -1; done \
    | sort -u \
    | while read -r d; do [[ -d "$d/.git" ]] && echo "$d"; done
}

REPOS=$(discover_repos)
[[ -z "$REPOS" ]] && echo "Không tìm thấy repo nào. Khai báo trong $CFG_FILE" >&2

# ── Phiên Claude Code ─────────────────────────────────────────────────────
# Chỉ lấy câu bạn gõ, bỏ kết quả công cụ và nội dung file.
# content có thể là chuỗi (gõ tay) hoặc mảng (có dán ảnh/file kèm theo).
collect_prompts() {
  sessions_touched_in_window \
  | while read -r f; do
      jq -rc --arg s "$START_ISO" --arg e "$END_ISO" '
        select(.type == "user" and .timestamp != null)
        | select((.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601 | strflocaltime("%Y-%m-%dT%H:%M:%S")) as $t
                 | $t >= $s and $t < $e)
        | {
            t: (.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601 | strflocaltime("%H:%M")),
            p: (.cwd // "" | split("/") | last),
            m: (if (.message.content | type) == "string"
                then .message.content
                else ([.message.content[]? | select(.type == "text") | .text] | join(" "))
                end)
          }
        | select(.m != null and .m != "" and (.m | startswith("<") | not))
        # Secret gõ thẳng vào chat sẽ nằm trong log phiên, và từ đó chui
        # vào bản ghi. Che trước khi nó ra khỏi script.
        | .m |= gsub("(?<k>api[_-]?key|token|secret|password|passwd|bearer)(?<s>\\s*[=:]\\s*)(?<v>[^\\s\"]+)";
                     "\(.k)\(.s)***"; "i")
      ' "$f" 2>/dev/null
    done | jq -sc 'unique_by(.t + .m) | sort_by(.t)'
}

# ── Git ───────────────────────────────────────────────────────────────────
collect_git() {
  echo "$REPOS" | while read -r repo; do
    [[ -z "$repo" || ! -d "$repo/.git" ]] && continue
    local email; email=$(git -C "$repo" config user.email 2>/dev/null)
    [[ -z "$email" ]] && continue
    local name; name=$(basename "$repo")

    # Commit trên MỌI nhánh, không chỉ nhánh hiện tại — squash merge và
    # nhánh làm việc chưa merge vẫn phải được tính.
    git -C "$repo" log --all --author="$email" \
        --since="$START_ISO" --until="$END_ISO" \
        --format='%H%x09%h%x09%ad%x09%s' --date=format:'%H:%M' 2>/dev/null \
    | while IFS=$'\t' read -r full short time subj; do
        jq -nc --arg r "$name" --arg h "$short" --arg t "$time" --arg s "$subj" \
          '{repo:$r, sha:$h, time:$t, subject:$s}'
      done

    # Tài liệu markdown bị đụng tới — không giả định thư mục tên gì.
    git -C "$repo" log --all --author="$email" \
        --since="$START_ISO" --until="$END_ISO" \
        --name-only --format='' 2>/dev/null \
    | grep -E '\.(md|txt)$' | sort -u \
    | while read -r doc; do
        jq -nc --arg r "$name" --arg d "$doc" '{repo:$r, doc:$d}'
      done
  done
}

# ── GitHub: PR mình mở và PR mình review ─────────────────────────────────
collect_github() {
  # Bốn lệnh `gh` là phần chậm nhất (~6s/ngày). Quét cả tháng thì tắt đi,
  # vì lúc đó chỉ cần biết ngày nào chưa ghi chứ không cần từng PR.
  [[ "${REFLECT_SKIP_GITHUB:-0}" == "1" ]] && return 0
  command -v gh >/dev/null 2>&1 || return 0
  gh auth status >/dev/null 2>&1 || return 0
  local d="$DAY"

  gh search prs --author=@me --created="$d" --limit 30 \
     --json number,title,repository,url 2>/dev/null \
   | jq -c '.[] | {kind:"authored", n:.number, title, repo:.repository.nameWithOwner, url}' 2>/dev/null

  gh search prs --author=@me --merged="$d" --limit 30 \
     --json number,title,repository,url 2>/dev/null \
   | jq -c '.[] | {kind:"merged", n:.number, title, repo:.repository.nameWithOwner, url}' 2>/dev/null

  # Bằng chứng cho phần hỗ trợ team — thứ mà mô tả "review PR cho team"
  # vẫn luôn chung chung nếu thiếu.
  gh search prs --reviewed-by=@me --updated="$d" --limit 30 \
     --json number,title,repository,author,url 2>/dev/null \
   | jq -c '.[] | {kind:"reviewed", n:.number, title, repo:.repository.nameWithOwner, who:.author.login, url}' 2>/dev/null

  gh search prs --commenter=@me --updated="$d" --limit 30 \
     --json number,title,repository,author,url 2>/dev/null \
   | jq -c '.[] | {kind:"commented", n:.number, title, repo:.repository.nameWithOwner, who:.author.login, url}' 2>/dev/null
}

PROMPTS=$(collect_prompts); PROMPTS=${PROMPTS:-[]}
GIT=$(collect_git | jq -sc '.'); GIT=${GIT:-[]}
GH=$(collect_github | jq -sc 'unique_by(.kind + (.n|tostring))'); GH=${GH:-[]}

# Backlog nội bộ — im lặng bỏ qua nếu chưa cấu hình.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BL=$("$HERE/backlog.sh" "$DAY" --json 2>/dev/null); BL=${BL:-[]}

if [[ "$OUT_JSON" == "1" ]]; then
  jq -nc --arg day "$DAY" --argjson p "$PROMPTS" --argjson g "$GIT" \
         --argjson h "$GH" --argjson b "$BL" \
    '{day:$day, prompts:$p, git:$g, github:$h, backlog:$b}'
  exit 0
fi

# ── Bản cho người đọc ─────────────────────────────────────────────────────
echo "# Dữ liệu thô — $DAY"
echo "_khung giờ ${DAY_START_HOUR}:00 hôm nay đến ${DAY_START_HOUR}:00 hôm sau, giờ máy_"
echo

commits=$(echo "$GIT" | jq '[.[] | select(.sha)] | length')
docs=$(echo "$GIT"    | jq '[.[] | select(.doc)] | length')
echo "## Commit ($commits)"
if [[ "$commits" -gt 0 ]]; then
  echo "$GIT" | jq -r '.[] | select(.sha) | "- \(.time) · \(.repo) · \(.sha) \(.subject)"'
else
  echo "_không có_"
fi
echo

if [[ "$docs" -gt 0 ]]; then
  echo "## Tài liệu đụng tới ($docs)"
  echo "$GIT" | jq -r '.[] | select(.doc) | "- \(.repo) · \(.doc)"'
  echo
fi

echo "## GitHub"
if [[ "$(echo "$GH" | jq 'length')" -gt 0 ]]; then
  for k in authored merged reviewed commented; do
    n=$(echo "$GH" | jq --arg k "$k" '[.[] | select(.kind==$k)] | length')
    [[ "$n" -eq 0 ]] && continue
    case $k in
      authored)  echo "### PR mở mới" ;;
      merged)    echo "### PR merge" ;;
      reviewed)  echo "### PR đã review" ;;
      commented) echo "### PR có góp ý" ;;
    esac
    echo "$GH" | jq -r --arg k "$k" '.[] | select(.kind==$k)
      | "- \(.repo)#\(.n) \(.title)" + (if .who then " _(của \(.who))_" else "" end)'
  done
else
  echo "_không có_"
fi
echo

nb=$(echo "$BL" | jq 'length')
if [[ "$nb" -gt 0 ]]; then
  echo "## Backlog ($nb ticket)"
  echo "$BL" | jq -r '.[] | "- \(.at) · \(.key) \(.summary)  _(\(.kinds))_"'
  echo
fi

np=$(echo "$PROMPTS" | jq 'length')
echo "## Phiên Claude ($np lượt trao đổi)"
if [[ "$np" -gt 0 ]]; then
  echo "$PROMPTS" | jq -r 'group_by(.p) | .[] |
    "### \(.[0].p)\n" + ([.[] | "- \(.t) \(.m[0:110] | gsub("\n"; " "))"] | join("\n"))'
else
  echo "_không có_"
fi
echo

# Phần trên là những gì máy nhìn thấy. Ba câu dưới đây là phần máy không
# bao giờ trả lời được — in kèm ngay ở đây để không ai viết bản ghi mà
# quên hỏi, kể cả khi chạy script một mình.
cat <<'ASK'
## Chưa hỏi thì chưa đủ

1. Ngoài những việc trên, hôm nay còn hỗ trợ ai, review gì, họp gì, hay
   điều tra vấn đề nào không?
2. Danh sách ticket đủ chưa? Ticket của khách không nằm trong dữ liệu trên
   — thiếu thì dán vào.
3. Còn việc nào chưa xong, hoặc đang chờ ai không?
ASK
