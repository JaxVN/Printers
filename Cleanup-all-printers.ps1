# Danh sách máy in cần xóa
$PrintersToRemove = @(
    "STCP001", "STCP002", "STCP004", "STCP005", "STCP007",
    "STCP008", "STCP010", "STCP012", "STCP013", "STCP014"
)

Write-Host "=== Bắt đầu xóa máy in ===" -ForegroundColor Cyan

foreach ($name in $PrintersToRemove) {
    $printer = Get-Printer -Name $name -ErrorAction SilentlyContinue
    
    if ($printer) {
        try {
            Remove-Printer -Name $name -Confirm:$false -ErrorAction Stop
            Write-Host "[OK] Đã xóa: $name" -ForegroundColor Green
        }
        catch {
            Write-Host "[X] Lỗi khi xóa $name : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "[!] Không tìm thấy: $name → bỏ qua" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Hoàn tất ===" -ForegroundColor Cyan
