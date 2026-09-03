# Luật viết

Đọc hết trước khi viết câu đầu tiên. Mỗi luật ở đây ứng với một lỗi mà bản
nháp đầu tay hay mắc phải.

## 1. Bài học phải là điều học được, không phải việc đã làm

Đây là chỗ sai nhiều nhất. Kể lại việc đã làm rồi thêm chữ "học được" ở
đầu câu thì vẫn là kể việc.

> ✗ Học được cách nâng version base image và build lại CI.

Đó là mô tả công việc. Người đọc không rút ra được gì.

> ✓ Nâng version chỉ là bước cuối. Phần lâu nhất là dựng được đường lùi:
> giữ tag cũ để rollback trong vài phút nếu image mới hỏng.

Thử: nếu bỏ tên ticket và tên hệ thống đi mà câu vẫn còn giá trị cho
người khác, thì đó là bài học thật.

## 2. Không viết câu triết lý mơ hồ

> ✗ Phần khó không phải là làm cho nhanh, mà là chứng minh kết quả không đổ.

Nghe kêu nhưng người đọc không biết "chứng minh" bằng cách nào. Nếu định
viết một câu kiểu này, thay bằng cách làm cụ thể.

> ✓ Trước khi đổi cache, phải chốt trước cái gì được coi là "không đổi" —
> so nội dung trả về trên cùng một tập URL trước và sau, chứ không so
> thời gian phản hồi.

## 3. Câu ngắn, mỗi câu một ý

Đây là luật hay bị vi phạm nhất, và cũng là thứ làm người đọc nhận ra ngay
văn do máy viết. Người viết mệt thì viết ngắn; máy thì càng viết càng thêm
mệnh đề bổ nghĩa.

Một bài học nên là hai đến bốn câu ngắn, chứ không phải một câu dài gánh
ba ý.

Ba dấu hiệu câu đang quá dài:

- Có mệnh đề chèn giữa hai dấu gạch ngang.
- Có "và" nối hai ý vốn không liên quan.
- Đọc tới cuối phải quay lại đầu câu mới hiểu.

> ✗ Hiểu được cơ chế caching ở mức dùng được, thay vì mức "cache theo URL"
> như trước — hai thứ quyết định mọi chuyện là vòng đời của object, do ba
> tham số thuộc ba chủ thể khác nhau chi phối và chỉ một trong ba sửa được
> từ phía mình, cùng với cache key, thứ tinh hơn URL rất nhiều và mới thực
> sự quyết định hai request có dùng chung ô cache hay không.

Cùng nội dung, tách câu:

> ✓ Hiểu được CDN thực sự cache như thế nào. Trước đây chỉ nghĩ đơn giản là
> cache theo URL, hết hạn thì lấy bản mới. Thực tế mỗi object có một vòng
> đời do nhiều tham số quyết định, và không phải tham số nào mình cũng sửa
> được. Hai request cùng một URL vẫn có thể nằm ở hai ô cache khác nhau.

Ngắn không có nghĩa là cụt. Bản ✓ dài hơn về số chữ nhưng đọc một lượt là
hiểu, còn bản ✗ phải đọc lại.

## 3a. Đừng tự đặt ẩn dụ cho thứ đã có tên cụ thể

Bản nháp hay gọn hoá bằng hình ảnh tự nghĩ ra: "đường hai chặng", "đi trọn
một vòng", "tài liệu và code trôi mỗi thứ một hướng". Nghe súc tích, nhưng
người đọc phải giải mã, và giải sai thì hiểu lệch.

> ✗ Chạy đường hai chặng trước, rồi mới thử đường thẳng.
> ✓ Kế hoạch ban đầu nâng qua hai bước: 8.0.6 lên 8.4, rồi 8.4 lên 8.8.
> Sau đó thử nâng thẳng lên 8.8.5 thì chạy được ngay.

Thứ gì có version, có tên hàm, có tên bước thì gọi đúng tên nó.

## 3b. Kể theo mạch việc, không kể theo lịch

"Đầu tuần… giữa tuần… cuối tuần…" là cách sắp xếp của cuốn lịch, không
phải của công việc. Người đọc cần biết việc nào dẫn tới việc nào.

> ✗ Đầu tuần chạy đường hai chặng. Giữa tuần kiểm chứng. Cuối tuần thử PoC.
> ✓ Làm xong cả hai bước rồi kiểm chứng. Sau đó thử nâng thẳng, hoá ra
> chạy được, nên bỏ bước trung gian.

## 3c. Bài học kỹ thuật không phải bản tóm tài liệu điều tra

Tên tham số, tên hàm, tên file cấu hình thuộc về report. Đưa chúng vào bản
ghi thì đoạn văn trông có vẻ chắc chắn, nhưng người đọc — kể cả chính bạn
sáu tháng sau — chỉ thấy một đống danh từ lạ.

Giữ lại điều mình hiểu ra, bỏ phần chứng minh. Ai cần chi tiết thì mở
report.

> ✗ Hàm `fixISRHeaders` gán `s-maxage=2` cho response ở trạng thái stale,
> nên path có traffic tự lành trong vài giây.
> ✓ Đọc source thư viện nhanh hơn ngồi đoán. Mất hai ngày không giải thích
> nổi vì sao lỗi chỉ thỉnh thoảng xảy ra, mở source ra thì câu trả lời nằm
> sẵn ở đó.

## 4. Gom việc cùng bản chất

Bốn ticket cùng là "vá lỗ hổng thư viện" thì viết một đoạn, nhắc mã ticket
trong ngoặc. Đừng liệt kê bốn gạch đầu dòng gần như giống nhau.

> ✓ Vá bốn lỗ hổng ở tầng base image (ABC-85, ABC-86, ABC-88, ABC-91).
> Cả bốn đều nằm ở thư viện hệ thống chứ không ở code ứng dụng, nên gom
> chung một lần dựng lại image thay vì bốn lần.

## 5. Số liệu phải đi kèm nguồn xác nhận

Nói mức cải thiện theo phần trăm và ai/cái gì xác nhận. Không kể quy trình
đo — người đọc báo cáo không cần biết bạn chạy bao nhiêu URL hay lưu
snapshot ở đâu.

> ✗ Từ 4673ms xuống 649ms, đo bằng bộ regression 20 URL, có snapshot trước sau.
> ✓ Thời gian phản hồi giảm khoảng 85%, khách hàng xác nhận cải thiện rõ
> rệt và số liệu khớp với metrics trên ALB.

## 6. Có dùng AI thì nói ra, kèm việc cụ thể

Không viết chung chung "có áp dụng AI". Nói dùng vào đâu và được gì.

> ✓ Dùng Claude Code dựng bộ sinh test case cho QC — QC mô tả luồng, công
> cụ sinh ra khung test case để họ sửa lại, thay vì viết từ đầu.

## 7. Báo cáo tháng bỏ danh xưng "Tôi"

Bản ngày và tuần xưng "tôi" bình thường. Bản tháng viết theo lối tổng kết,
chủ ngữ là công việc chứ không phải người.

> ✗ Tôi đã hoàn thành việc nâng cấp base image đúng hạn.
> ✓ Việc nâng cấp base image hoàn thành đúng hạn, không phát sinh rollback.

## 8. Giữ giọng người, nhưng không đùa

Viết như đang kể cho đồng nghiệp nghe. Nhưng những mục nghiêm túc — bảo
mật, sự cố, cam kết với khách — thì viết nghiêm túc. Không ví von, không
đùa cợt.

Cũng tránh nhịp câu máy móc. Ba khuôn dưới đây đọc lên là biết máy viết,
và bản nháp đầu tay gần như luôn rơi vào một trong ba:

- Mọi gạch đầu dòng cùng dạng "Động từ + tân ngữ + kết quả".
- "Không phải A, mà là B" — nghe sâu sắc nhưng thường chẳng nói gì thêm.
- "Muốn X thì phải Y trước" — công thức, dùng cho việc gì cũng vừa.

Nếu ba bài học trong một bản ghi cùng một khuôn thì viết lại, kể cả khi
từng câu nghe đều ổn.

Thêm hai thứ hay lọt vào cuối đoạn:

- **Câu tổng kết sáo.** "Cách chia này giữ được tốc độ mà không giao phán
  đoán cho máy." Đoạn trên đã nói đủ rồi, câu này chỉ nhắc lại bằng giọng
  trịnh trọng. Xoá đi là đoạn văn chặt hơn.
- **Nhân hoá công cụ.** "AI gánh phần giấy tờ", "script tự lo phần còn
  lại". Viết "Dùng AI cho…" là xong.

## 9. Không suy diễn ra ngoài dấu vết

Chỉ viết việc có bằng chứng hoặc do người dùng nói ra. Không gán một việc
sang tuần nó không xảy ra, không phỏng đoán "chắc là đang làm phase 2".
Không chắc thì hỏi.

## 10. Ngắn

Bản ngày: dưới 15 dòng. Bản tuần: dưới một trang. Nếu dài hơn, gần như
luôn là do đang liệt kê thay vì tổng hợp.

## Không dùng

- Emoji.
- "Successfully", "hoàn thành xuất sắc", "đáng kể" khi không có số.
- Danh sách lồng quá hai cấp.
- Câu mở đầu kiểu "Trong tuần này, tôi đã…" — vào thẳng việc.

## Đọc lại trước khi lưu

Bốn câu hỏi, trả lời "không" ở câu nào thì sửa câu đó:

1. Đọc một lượt có hiểu không, hay phải đọc lại?
2. Bỏ tên ticket và tên hệ thống đi, bài học còn giá trị không?
3. Các gạch đầu dòng có khác khuôn nhau không?
4. Người viết ra đoạn này nghe có giống một người đang kể việc mình vừa
   làm không?
