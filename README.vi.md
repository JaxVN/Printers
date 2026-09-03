# Printers

Repo lưu driver + script triển khai máy in tự động cho hệ thống KAG, dùng kết hợp với **Action1** (RMM) để cài đặt hàng loạt hoặc từng máy in trên các máy trạm mà không cần thao tác tay.

## Cấu trúc repo

| File | Vai trò |
|---|---|
| `Install-Printer-<TênMáyIn>.ps1` | Script cài đặt **1 máy in cụ thể**: cài driver (từ thư mục local), tạo TCP/IP Port, tạo Printer. Đây là "nguồn sự thật" chứa cấu hình (tên driver, IP, port) của từng máy in. |
| `<TênMáyIn>.zip` | Bộ driver nén tương ứng (chứa file `.inf` + các file driver liên quan) cho từng máy in. |
| `Action1-Deploy-OnePrinter-v2.ps1` | Script core: tải zip driver + script cài của **1 máy in** (tên truyền qua tham số `-PrinterName`), giải nén, sửa lại đường dẫn driver cho khớp, rồi chạy. Log chi tiết ghi ra file, console chỉ hiện tóm tắt. |
| `Action1-Loader-OnePrinter.ps1` | Đoạn **paste trực tiếp vào Action1** cho policy cài 1 máy in. Chỉ cần sửa 1 dòng `$PrinterName`, còn lại tự tải `Action1-Deploy-OnePrinter-v2.ps1` từ repo về chạy. |
| `Action1-Deploy-AllPrinters-v2.ps1` | Script core cài **toàn bộ danh sách máy in** trong 1 lần chạy, lỗi 1 máy không dừng cả batch. Log chi tiết ghi ra file, console chỉ hiện bảng tóm tắt OK/FAILED. **(Bản nên dùng)** |
| `Action1-Deploy-AllPrinters.ps1` | Bản v1 (cũ) của script cài toàn bộ — in log chi tiết thẳng ra console. Giữ lại để đối chiếu, nên dùng bản v2 thay thế. |
| `Action1-Deploy-STCP001.ps1` | Bản bootstrapper cũ, viết riêng cho STCP001 trước khi tách thành core + loader dùng chung. Giữ lại tham khảo, không cần dùng nữa — thay bằng `Action1-Loader-OnePrinter.ps1`. |

> ⚠️ **Chưa có trên repo, cần upload bổ sung:** `Action1-Loader.ps1` (loader ngắn để paste vào Action1 cho kịch bản "cài tất cả", gọi `Action1-Deploy-AllPrinters-v2.ps1`), `Cleanup-Printer-STCP001.ps1` (gỡ printer/port/driver để test lại từ đầu), và cặp `Install-Printer-STCP014.ps1` + `STCP014.zip` (Canon PRO-100, IP `10.10.6.211`, dùng Standard TCP/IP Port thay vì Canon BJ Network Port).

## Quy ước đặt tên & thư mục

- Tên file luôn theo **tên máy in** (khớp tên Printer Queue trên Windows): `STCP001`, `STCP002`...
- Trên máy trạm, driver được giải nén vào: `C:\Soft\Printers\<TênMáyIn>\` (thư mục = tên máy in = tên file zip, không phải tên driver).
- Log chi tiết của các script `-v2` lưu tại: `C:\Soft\Printers\DeployLog_<TênMáyIn>_<yyyyMMdd_HHmmss>.log` (cài 1 máy) hoặc `C:\Soft\Printers\DeployLog_<yyyyMMdd_HHmmss>.log` (cài hàng loạt).

## Danh sách máy in hiện tại

| Máy in | Driver | IP | Port | Loại port |
|---|---|---|---|---|
| STCP001 | RICOH Aficio MP 5001 PCL 6 | 10.10.12.214 | IP_10.10.12.214 | Standard TCP/IP |
| STCP002 | HP Universal Printing PCL 6 (v6.6.5) | 10.10.12.208 | IP_10.10.12.208 | Standard TCP/IP |
| STCP004 | HP Designjet 510ps 42in Printer | 10.10.12.201 | IP_10.10.12.201 | Standard TCP/IP |
| STCP005 | HP LaserJet Pro M402-M403 PCL 6 | 10.10.12.213 | IP_10.10.12.213 | Standard TCP/IP |
| STCP007 | HP LaserJet Pro M402-M403 PCL 6 | 10.10.12.218 | IP_10.10.12.218 | Standard TCP/IP |
| STCP008 | HP LaserJet Pro M402-M403 PCL 6 | 10.10.12.210 | IP_10.10.12.210 | Standard TCP/IP |
| STCP010 | HP LaserJet 700 M712 PCL 6 | 10.10.12.212 | IP_10.10.12.212 | Standard TCP/IP |
| STCP012 | HP LaserJet Pro M402-M403 PCL 6 | 10.10.12.209 | IP_10.10.12.209 | Standard TCP/IP |
| STCP013 | HP LaserJet Pro M402-M403 PCL 6 | 10.10.12.204 | IP_10.10.12.204 | Standard TCP/IP |

## Cách sử dụng

### 1. Cài thủ công trên 1 máy (không qua Action1)

```powershell
# Tải Install-Printer-STCP001.ps1 va STCP001.zip ve cung 1 thu muc, giai nen zip
# vao C:\Soft\Printers\STCP001, roi chay:
.\Install-Printer-STCP001.ps1
```

### 2. Cài qua Action1 — 1 máy in

1. Upload/cập nhật `Action1-Deploy-OnePrinter-v2.ps1` lên repo (chỉ cần làm 1 lần, hoặc khi sửa logic).
2. Trong Action1, tạo policy nhắm đúng máy trạm cần cài, paste nội dung `Action1-Loader-OnePrinter.ps1`.
3. Sửa dòng `$PrinterName = "STCP001"` thành tên máy in tương ứng cho policy đó.
4. Chạy policy. Console Action1 chỉ hiện: tên máy in, trạng thái, log path. Chi tiết xem trong file log trên máy trạm.

### 3. Cài qua Action1 — toàn bộ máy in

1. Upload `Action1-Deploy-AllPrinters-v2.ps1` lên repo.
2. Upload thêm `Action1-Loader.ps1` (xem phần "chưa có trên repo" ở trên) — paste vào Action1.
3. Danh sách máy in cần cài khai báo trong mảng `$PrinterList` **bên trong** `Action1-Deploy-AllPrinters-v2.ps1` trên repo — sửa ở đây, không cần đụng vào Action1.

### 4. Test lại từ đầu (reset máy trạm)

Dùng `Cleanup-Printer-STCP001.ps1` (xem phần "chưa có trên repo") để gỡ Printer → Port → Driver (kể cả trong Driver Store) → xóa thư mục driver local, đưa máy về trạng thái "chưa cài gì" trước khi chạy lại để test.

## Thêm 1 máy in mới vào hệ thống

1. Tạo `Install-Printer-<TênMáyIn>.ps1` theo mẫu các file hiện có (đổi `$PrinterName`, `$DriverName`, `$PrinterIP`, `$PortName`).
2. Nén bộ driver (`.inf` + file liên quan) thành `<TênMáyIn>.zip`.
3. Upload cả 2 file lên repo (root, không để trong thư mục con).
4. Nếu muốn máy in này được cài khi chạy "cài tất cả": thêm tên vào mảng `$PrinterList` trong `Action1-Deploy-AllPrinters-v2.ps1`.
5. Nếu cài lẻ qua Action1: tạo policy mới dùng `Action1-Loader-OnePrinter.ps1`, sửa `$PrinterName`.

## Lưu ý vận hành

- Repo đang **Public** — ai cũng đọc được nội dung script/driver, nhưng script chạy với quyền **SYSTEM/Admin** trên máy trạm qua Action1, nên chỉ nên cấp quyền **push/write** cho tài khoản tin cậy, bật thêm 2FA cho tài khoản GitHub quản lý repo này.
- `raw.githubusercontent.com` cache CDN ~5 phút — push xong test ngay có thể vẫn ăn bản cũ trong vài phút.
- Máy trạm cần ra được Internet tới `raw.githubusercontent.com`; nếu có máy sau proxy chặn domain này, các script tải-từ-repo sẽ lỗi ngay bước đầu — cần allowlist domain hoặc dùng phương án cài thủ công (mục 1).
- Tên thư mục driver trong `$DriverFolder` bên trong từng `Install-Printer-*.ps1` **phải khớp chính xác** với quy ước `C:\Soft\Printers\<TênMáyIn>` — các script Action1 (`-v2`) tự động ghi đè dòng này khi tải về nên không bắt buộc phải sửa tay, nhưng nếu chạy `Install-Printer-*.ps1` độc lập (mục 1) thì cần đảm bảo đúng.
