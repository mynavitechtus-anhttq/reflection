# Báo cáo tháng {{MONTH}}

Bỏ danh xưng "tôi". Chủ ngữ là công việc. Đây là bản tổng kết, không phải
nhật ký — người đọc muốn biết tháng qua tạo ra được gì, không phải tuần
nào làm gì.

## Cách trình bày

Khuôn của ba mục dưới đây giống nhau:

- Đánh số `1/ 2/ 3/`, mỗi ý là **một đoạn văn liền mạch**. Không gạch đầu
  dòng, không bảng, không danh sách lồng.
- Mỗi đoạn **mở bằng động từ hành động**: Triển khai…, Xây…, Rút ngắn…,
  Đóng…, Chuyển giao… Đừng mở bằng danh từ hay bằng bối cảnh.
- Mỗi đoạn **kết bằng ích lợi cụ thể**: nhờ đó ai đỡ việc gì, tránh được
  chuyện gì. Đoạn chỉ tả việc mà không nói ích lợi là chưa xong.
- Ba đến bốn ý mỗi mục là vừa. Mục Hợp tác có thể năm hoặc sáu.

**Hạ bớt thuật ngữ.** Người đọc báo cáo tháng không phải lúc nào cũng là
dev. Viết "đăng nhập hai lớp" thay cho MFA, "tầng cân bằng tải" thay cho
ALB, "bộ nhớ đệm trình duyệt" thay cho bfcache. Bản ngày và bản tuần thì
giữ nguyên thuật ngữ.

**Không nêu tên dự án và mã ticket.** Bản ngày và bản tuần cần chúng để
tra lại; bản tháng thì không, và nêu ra là đang kể việc thay vì tổng kết.
Viết "một dự án khác", "ba dự án khác trong tháng". Gộp mấy ca cùng loại
thành một nhận định chung, ví dụ "phần lớn góp ý rơi vào chỗ report kết
luận sớm khi chưa soát hết những gì đang chạy trên máy chủ" thay vì kể
từng ca một.

## Chất lượng

{{Kết quả đo được và ai xác nhận. Có số thì nói phần trăm kèm nguồn (khách
xác nhận, metrics hệ thống), không kể quy trình đo.

Chất lượng không chỉ là bug ít. Tính cả: bộ test bổ sung, công cụ dựng cho
người khác dùng, quy trình đặt ra để lỗi không lặp lại, tài liệu giúp
người sau đỡ mò.}}

## Hiệu quả

{{Đúng hạn hay không, và vì sao. Việc gì rút ngắn được thời gian — tự động
hoá cái gì, bỏ được bước thủ công nào, dùng AI vào đâu và tiết kiệm được
gì.

Nói theo hướng "trước thế nào, giờ thế nào", đừng chỉ nói "đã tự động
hoá".}}

## Hợp tác

{{Hỗ trợ ai, review gì cho ai, chia sẻ lại kiến thức bằng cách nào, làm
việc với khách ra sao khi có bất đồng hoặc sự cố.

Đây là mục dễ viết chung chung nhất. Mỗi ý phải gắn với một việc có thật.}}
