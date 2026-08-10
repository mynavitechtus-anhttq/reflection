# _lib.sh — vài thứ khác nhau giữa macOS và Linux, gom lại một chỗ.
# Nạp bằng `source`, không chạy trực tiếp.

# `date` của BSD (macOS mặc định) và của GNU nhận cờ hoàn toàn khác nhau.
if date -j -f "%Y-%m-%d" "2000-01-01" "+%s" >/dev/null 2>&1; then
  _DATE_BSD=1
else
  _DATE_BSD=0
fi

# epoch_of "YYYY-MM-DD HH:MM:SS" — hiểu theo giờ máy
epoch_of() {
  if [[ "$_DATE_BSD" == "1" ]]; then
    date -j -f "%Y-%m-%d %H:%M:%S" "$1" "+%s"
  else
    date -d "$1" "+%s"
  fi
}

# epoch_of_utc "YYYY-MM-DDTHH:MM:SSZ"
epoch_of_utc() {
  if [[ "$_DATE_BSD" == "1" ]]; then
    date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$1" "+%s"
  else
    date -u -d "$1" "+%s"
  fi
}

# fmt_epoch <epoch> <định dạng> — in theo giờ máy
fmt_epoch() {
  if [[ "$_DATE_BSD" == "1" ]]; then
    date -r "$1" "$2"
  else
    date -d "@$1" "$2"
  fi
}

# shift_days <±n> — ngày hôm nay cộng/trừ n ngày, dạng YYYY-MM-DD
shift_days() {
  if [[ "$_DATE_BSD" == "1" ]]; then
    date -v"${1}d" "+%Y-%m-%d"
  else
    date -d "$1 days" "+%Y-%m-%d"
  fi
}

# file_mtime <file> — lần ghi cuối, tính bằng epoch.
# Không dùng `find -newermt` vì BSD find không nhận cú pháp @epoch của GNU
# và im lặng trả về rỗng.
if stat -f %m . >/dev/null 2>&1; then
  file_mtime() { stat -f %m "$1"; }        # BSD / macOS
else
  file_mtime() { stat -c %Y "$1"; }        # GNU / Linux
fi
