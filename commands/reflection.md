---
description: Ghi nhận công việc theo ngày, tổng hợp theo tuần hoặc tháng
argument-hint: "day|week|month [ngày|tuần|tháng]  ·  vd: day -1, month 2026-08"
---

Dùng skill `reflection`.

Tham số: `$ARGUMENTS`

- Không có tham số, hoặc bắt đầu bằng `day` → luồng một ngày.
- Bắt đầu bằng `week` → luồng một tuần.
- Bắt đầu bằng `month` → luồng một tháng.
- Phần còn lại là mốc thời gian cần ghi; bỏ trống thì lấy kỳ hiện tại.

Nhớ: không truy cập hệ thống của khách hàng. Backlog chỉ gọi tới space nội
bộ khai trong config; ticket của khách chỉ nhận khi người dùng tự dán vào.
