# =====================================================================
# ACTION1 DEPLOY SCRIPT v2 - Trien khai TOAN BO may in tu GitHub repo JaxVN/Printers
# =====================================================================
# Khac biet so voi v1:
#   - Console (log Action1 nhin thay) CHI hien BANG TOM TAT cuoi cung.
#   - Toan bo log chi tiet (tung buoc tai driver/port/printer) duoc ghi
#     vao file: C:\Soft\Printers\DeployLog_<thoigian>.log
# =====================================================================

# ---- DANH SACH MAY IN CAN CAI (them/bot ten o day) ----
$PrinterList = @(
    "STCP001",
    "STCP002",
    "STCP004",
    "STCP005",
    "STCP007",
    "STCP008",
    "STCP010",
    "STCP012",
    "STCP013"
    # "STCP014"   # <- bo comment khi da upload Install-Printer-STCP014.ps1 + STCP014.zip len repo
)

# ---- CAU HINH CHUNG ----
$RepoRawBase    = "https://raw.githubusercontent.com/JaxVN/Printers/main"
$DriverRootBase = "C:\Soft\Printers"
$LogFile        = Join-Path $DriverRootBase "DeployLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"   # an progress bar cua Invoke-WebRequest, khong can thiet trong log
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not (Test-Path $DriverRootBase)) {
    New-Item -ItemType Directory -Path $DriverRootBase -Force | Out-Null
}

# Write-Log: mac dinh CHI ghi vao file. Truyen -Console de dong nay cung hien ra console (dung cho phan tom tat).
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [switch]$Console
    )
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts][$Level] $Message"
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    if ($Console) { Write-Host $line }
}

function Install-OnePrinterFromRepo {
    param([string]$PrinterName)

    $driverFolderPath = Join-Path $DriverRootBase $PrinterName
    $tempZip          = Join-Path $env:TEMP "$PrinterName.zip"
    $tempScript       = Join-Path $env:TEMP "Install-Printer-$PrinterName.ps1"

    Write-Log "[$PrinterName] Dang tai driver: $RepoRawBase/$PrinterName.zip"
    Invoke-WebRequest -Uri "$RepoRawBase/$PrinterName.zip" -OutFile $tempZip -UseBasicParsing

    if (-not (Test-Path $driverFolderPath)) {
        New-Item -ItemType Directory -Path $driverFolderPath -Force | Out-Null
    }

    Write-Log "[$PrinterName] Dang giai nen driver vao: $driverFolderPath"
    Expand-Archive -Path $tempZip -DestinationPath $driverFolderPath -Force
    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue

    Write-Log "[$PrinterName] Dang tai script cai dat: $RepoRawBase/Install-Printer-$PrinterName.ps1"
    Invoke-WebRequest -Uri "$RepoRawBase/Install-Printer-$PrinterName.ps1" -OutFile $tempScript -UseBasicParsing

    $scriptContent = Get-Content -Path $tempScript -Raw
    $newDriverFolderLine = "`$DriverFolder = `"$driverFolderPath`""
    $evaluator = [System.Text.RegularExpressions.MatchEvaluator] { param($m) $newDriverFolderLine }
    $scriptContent = [System.Text.RegularExpressions.Regex]::Replace($scriptContent, '\$DriverFolder\s*=\s*".*"', $evaluator)
    Set-Content -Path $tempScript -Value $scriptContent -Encoding UTF8

    Write-Log "[$PrinterName] Dang chay script cai dat (DriverFolder = $driverFolderPath)..."
    # Gom toan bo output/log cua script con (Write-Host, Write-Error...) va ghi vao file,
    # KHONG cho chay thang ra console cua Action1.
    & $tempScript *>&1 | ForEach-Object { Add-Content -Path $LogFile -Value $_.ToString() -Encoding UTF8 }

    Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
}

# ---- KIEM TRA QUYEN ADMIN ----
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Script can chay voi quyen Administrator." -ForegroundColor Red
    exit 1
}

Write-Log "===== Bat dau trien khai $($PrinterList.Count) may in tu repo JaxVN/Printers ====="

$results = @()
foreach ($printerName in $PrinterList) {
    Write-Log "===== [$printerName] Bat dau ====="
    try {
        Install-OnePrinterFromRepo -PrinterName $printerName
        Write-Log "[$printerName] Thanh cong."
        $results += [PSCustomObject]@{ Printer = $printerName; Status = "OK"; Ghi_chu = "" }
    }
    catch {
        Write-Log "[$printerName] LOI: $($_.Exception.Message)" "ERROR"
        $results += [PSCustomObject]@{ Printer = $printerName; Status = "FAILED"; Ghi_chu = $_.Exception.Message }
    }
}

Write-Log "===== Ket thuc trien khai ====="

# ---- CHI PHAN NAY HIEN RA CONSOLE (Action1 nhin thay) ----
$okCount   = ($results | Where-Object { $_.Status -eq "OK" }).Count
$failCount = ($results | Where-Object { $_.Status -eq "FAILED" }).Count

Write-Host "===== TOM TAT TRIEN KHAI MAY IN ====="
Write-Host "Thanh cong: $okCount / $($PrinterList.Count)"
Write-Host "That bai  : $failCount / $($PrinterList.Count)"
$results | Format-Table -AutoSize | Out-String | Write-Host
Write-Host "Log chi tiet: $LogFile"

# Ghi lai phan tom tat vao file log luon, de sau nay mo file van thay duoc ket qua tong quan
Write-Log "TOM TAT: Thanh cong $okCount/$($PrinterList.Count), That bai $failCount/$($PrinterList.Count)"
($results | Format-Table -AutoSize | Out-String) -split "`n" | ForEach-Object { Write-Log $_ }

if ($failCount -gt 0) {
    exit 1
}
