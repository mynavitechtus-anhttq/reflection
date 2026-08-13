---
name: reflection
description: Use when the user wants to write a daily / weekly work reflection, work log, or standup-style summary of what they did — collects evidence from Claude Code sessions, git and GitHub, asks about the work that leaves no machine trace, then drafts in the user's own voice. Also use when reviewing an existing reflection for vagueness or missing evidence.
---

# Reflection

Viết bản ghi công việc theo ngày, rồi gộp thành tuần.

Máy chỉ nhìn thấy một phần việc. Kỹ năng này lấy phần máy thấy được làm
điểm tựa, còn phần máy không thấy — hỗ trợ team, review, họp, điều tra,
lên kế hoạch — thì **hỏi**, không đoán.

## Ranh giới bắt buộc

- **Không truy cập hệ thống của khách hàng.** Backlog, Jira, wiki hay bất
  cứ thứ gì thuộc khách: chỉ nhận khi người dùng tự dán vào. Không tự gọi
  API, không tự mở link.
  `backlog.sh` chỉ gọi đúng một space — space khai trong config. Nếu người
  dùng định khai space của khách vào đó, nói rõ đây là ranh giới đã đặt ra
  và để họ quyết định.
- Chỉ đọc, không sửa repo. Ghi duy nhất vào thư mục lưu bản ghi.
- Không đưa nội dung thuộc khách ra ngoài máy người dùng.

## Nơi lưu

```
<gốc>/
  2026-08/
    W1/  2026-08-03.md  2026-08-04.md  …  W1.md
    W2/  …                                W2.md
    2026-08.md
```

Gốc lấy theo thứ tự: `$REFLECT_ROOT` → `~/.config/reflection/config.json`
(`.root`) → `~/reflections`. Lần chạy đầu chưa có gốc thì hỏi người dùng
muốn lưu ở đâu rồi ghi vào config.

Tuần đánh số theo vị trí trong tháng (W1 là tuần chứa ngày 1), không phải
số tuần ISO — người ta nhớ "tuần 2 của tháng 8" chứ ít ai nhớ "tuần 32".

## Ngày làm việc kết thúc lúc 4 giờ sáng

Commit lúc 1h sáng gần như luôn thuộc về ngày hôm trước. Mốc mặc định là
04:00 giờ máy, đổi qua `REFLECT_DAY_START_HOUR`.

---

## Luồng: một ngày

`reflection day` · `reflection day 2026-08-04` · `reflection day -1`

**1 — Gom dấu vết**

**Xem có bản chụp sẵn chưa trước khi gom lại từ đầu.** Người dùng có thể
đã đặt lịch chụp cuối mỗi ngày:

```bash
cat <root>/.raw/<ngày>.json
```

Có file thì dùng luôn — nhanh hơn, và quan trọng hơn: nó là dấu vết tại
đúng thời điểm cuối ngày hôm đó. Viết bù sau vài ngày mà gom lại thì log
phiên có thể đã bị dồn hoặc xoá bớt.

**Nhưng khi viết bù một ngày đã qua, chạy thêm `collect.sh` cho ngày đó và
so với snapshot.** Snapshot chụp lúc cuối giờ chiều nên thiếu ba thứ:
commit làm sau giờ chụp, commit nằm trong worktree hay nhánh phụ chỉ về
repo chính khi merge, và giờ log lên ticket sau đó. Hai nguồn lệch nhau
thì lấy hợp của cả hai — thiếu việc là lỗi nặng hơn thừa một dòng.

Không có thì gom trực tiếp:

```bash
scripts/collect.sh [ngày]
```

Cả hai đường cho ra cùng một thứ: commit trên mọi nhánh, PR mình mở /
merge / review / góp ý, ticket Backlog nội bộ có động tới, các lượt trao
đổi trong phiên Claude Code (nhóm theo repo), file `.md` bị đụng tới. Thêm
`--json` nếu cần đọc bằng máy.

Nếu không tìm thấy repo nào, hỏi người dùng liệt kê đường dẫn rồi ghi vào
`~/.config/reflection/config.json` → `.repos`.

Phần Backlog im lặng bỏ qua khi chưa cấu hình — đừng coi đó là lỗi. Ticket
lấy theo **hoạt động trong ngày** (tạo, sửa, comment), không theo ngày bắt
đầu và hạn chót: ticket kéo dài hai tuần mà lọc theo hạn thì ngày nào cũng
hiện, kể cả ngày không đụng tới.

Ticket của khách vẫn nằm ngoài — vẫn phải hỏi và nhận bằng cách dán tay.

**Cho mục việc tiếp theo, chạy thêm một lượt nhìn tới trước:**

```bash
scripts/backlog.sh --plan <đầu kỳ sau> <cuối kỳ sau>
```

Ở đây `startDate`–`dueDate` mới là thứ đúng, vì câu hỏi đổi từ "đã đụng
vào gì" sang "sắp tới phải làm gì". Đừng để mục việc tiếp theo chỉ dựa vào
phỏng đoán khi lịch đã nằm sẵn trong Backlog.

Vẫn phải hỏi người dùng: việc không có ticket — buổi chia sẻ, việc tự học,
việc đang chờ người khác — sẽ không xuất hiện ở đây.

**2 — Tóm lại cho người dùng xem, rồi hỏi**

Trình tự cố định, không đảo:

1. Đọc dấu vết, gộp thành 3–6 mảng việc. Đừng đưa bản thô rồi bảo họ tự lọc.

   **Ticket nào có `hours > 0` thì chắc chắn phải nằm trong phần việc đã
   làm.** Số giờ đã log là bằng chứng, và nó thắng mọi suy đoán từ những
   trường khác — `kinds: "cập nhật"` trông y hệt nhau dù là sửa một dòng
   mô tả hay ngồi làm cả buổi. `done: true` nghĩa là ticket đã chuyển sang
   trạng thái xong trong hôm đó; nói rõ điều này thay vì để người đọc đoán.

2. **Trình bày bản tóm đó ra cho người dùng đọc** — họ cần thấy mình đã
   nắm được gì thì mới biết cái gì còn thiếu.
3. Hỏi: *"Ngoài những việc trên, hôm nay bạn còn làm gì thêm không?"* cùng
   hai câu bắt buộc còn lại.
4. Đợi trả lời. Rồi mới viết.

Xem `references/questions.md` để biết hỏi gì và khi nào.

**Không viết trước khi hỏi.** Kể cả khi dấu vết trông đã đầy đủ, kể cả khi
đang viết bù nhiều ngày một lúc — nhất là khi viết bù nhiều ngày, vì đó là
lúc dễ chạy thẳng từ dữ liệu sang bản ghi nhất. Dấu vết chỉ phủ phần việc
đụng vào repo; phần còn lại không hỏi thì không có. Đợi người dùng trả lời
rồi mới viết.

Ba câu luôn phải hỏi, vì máy không bao giờ trả lời được:

- Hôm nay có việc nào không đụng tới repo không? (hỗ trợ ai, review gì,
  họp gì, điều tra gì)
- Danh sách ticket đã đủ chưa? Thiếu thì dán thêm.
- Có việc nào chưa xong, hoặc đang chờ ai không?

Nếu dấu vết cho thấy ngày có nhiều trao đổi mà không commit dòng nào, nói
thẳng ra và hỏi hôm đó làm gì — đó gần như chắc chắn là việc ngoài repo.

**3 — Viết**

Theo mẫu trong `templates/` và luật viết trong `references/style-guide.md`.
Đọc style guide trước khi viết câu đầu tiên; nó tồn tại vì bản nháp đầu
tay của mô hình thường sai đúng những lỗi liệt kê trong đó.

**4 — Lưu và báo lại**

Ghi vào đúng vị trí, in đường dẫn ra. Không tự sửa file ngày đã có mà
không hỏi.

---

## Luồng: một tuần

`reflection week` · `reflection week 2026-W32` · `reflection week -1`

**1 — Rà soát trước khi tổng hợp**

```bash
scripts/coverage.sh --week 2026-W32
```

Ngày nào có dấu vết mà chưa có file, hỏi người dùng có muốn viết bù không.
Viết tuần từ một tuần thủng ngày sẽ ra bản ghi thiếu.

**2 — Đọc các file ngày, gộp theo chủ đề chứ không theo thứ tự thời gian**

Một ticket kéo dài bốn ngày thì viết thành một đoạn, không phải bốn gạch
đầu dòng. Ticket cùng bản chất (cùng loại việc, cùng hệ thống) gộp chung.

**3 — Viết theo mẫu tuần, rồi lưu vào `W<n>/W<n>.md`**

---

## Luồng: một tháng

`reflection month` · `reflection month 2026-08` · `reflection month -1`

**1 — Rà soát**

```bash
scripts/coverage.sh --month 2026-08
```

Mất khoảng 25 giây cho một tháng — nói trước cho người dùng biết thay vì
để họ ngồi đợi im lặng.

Tuần nào chưa có bản tổng hợp thì hỏi có viết bù không. Đây là bước không
được bỏ: bản tháng gộp từ các tuần, tuần thủng thì tháng thiếu.

**2 — Đọc các file `W*.md` của tháng, không đọc lại file ngày**

File ngày đã được gộp vào tuần rồi. Đọc lại chỉ kéo bản tháng về phía liệt
kê chi tiết — đúng thứ cần tránh.

**3 — Viết theo trục, không theo thời gian**

Bản tháng không kể "tuần 1 làm gì, tuần 2 làm gì". Nó trả lời: tháng qua
tạo ra được gì, đo được gì, đóng góp gì ngoài phần việc của mình.

Bỏ danh xưng "tôi" — chủ ngữ là công việc.

**4 — Lưu vào `<root>/<tháng>/<tháng>.md`**

---

## Nhập ngày, tuần, tháng

| Gõ | Nghĩa |
|---|---|
| *(bỏ trống)* | hôm nay / tuần này / tháng này |
| `2026-08-04` | ngày đó |
| `0804` | ngày đó trong năm hiện tại |
| `-1`, `-3` | lùi 1 hoặc 3 đơn vị (ngày / tuần / tháng) |
| `2026-W32` | tuần ISO đó (chỉ dùng cho `week`) |
| `2026-08` | tháng đó (chỉ dùng cho `month`) |

## Tệp kèm theo

- `references/style-guide.md` — luật viết, kèm ví dụ sai và cách sửa. **Đọc trước khi viết.**
- `references/questions.md` — hỏi gì để lấp phần máy không thấy.
- `templates/generic-{day,week,month}.md` — mẫu mặc định.
- `templates/myprofile-{day,week,month}.md` — mẫu cho hệ thống My Profile nội bộ
  (Tasks / EVD / What did I learn / What's next; bản tháng theo ba trục
  Chất lượng / Hiệu quả / Hợp tác).

Chọn bộ mẫu theo `.template` trong config; chưa khai báo thì dùng `generic`.

## Script

| Script | Việc |
|---|---|
| `collect.sh [ngày]` | Gom dấu vết một ngày |
| `coverage.sh --week\|--month` | Chỉ ra chỗ hổng trước khi tổng hợp |
| `backlog.sh <từ> [đến]` | Ticket đã động tới trong kỳ |
| `backlog.sh --plan <từ> <đến>` | Ticket chưa đóng có lịch trong kỳ — cho mục việc tiếp theo |
| `_lib.sh` | Helper `date`/`stat` cho macOS và Linux — chỉ `source`, không chạy |
