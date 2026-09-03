# =====================================================================
# ACTION1 DEPLOY SCRIPT - Trien khai TOAN BO may in tu GitHub repo JaxVN/Printers
# =====================================================================
# Repo: https://github.com/JaxVN/Printers (public, branch: main)
# Voi MOI may in trong danh sach $PrinterList, script se:
#   1. Tai <TenMayIn>.zip -> giai nen vao C:\Soft\Printers\<TenMayIn>
#   2. Tai Install-Printer-<TenMayIn>.ps1
#   3. Ghi de dong $DriverFolder trong script do cho khop thu muc o buoc 1
#   4. Chay script de cai driver + tao port + tao may in
# Loi o 1 may in KHONG lam dung ca batch - se log lai va chay tiep may ke tiep.
# Chay voi quyen SYSTEM/Admin (Action1 mac dinh da chay elevated).
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

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts][$Level] $Message"
}

function Install-OnePrinterFromRepo {
    param([string]$PrinterName)

    $driverFolderPath = Join-Path $DriverRootBase $PrinterName
    $tempZip          = Join-Path $env:TEMP "$PrinterName.zip"
    $tempScript       = Join-Path $env:TEMP "Install-Printer-$PrinterName.ps1"

    # 1. Tai driver zip
    Write-Log "[$PrinterName] Dang tai driver: $RepoRawBase/$PrinterName.zip"
    Invoke-WebRequest -Uri "$RepoRawBase/$PrinterName.zip" -OutFile $tempZip -UseBasicParsing

    if (-not (Test-Path $driverFolderPath)) {
        New-Item -ItemType Directory -Path $driverFolderPath -Force | Out-Null
    }

    Write-Log "[$PrinterName] Dang giai nen driver vao: $driverFolderPath"
    Expand-Archive -Path $tempZip -DestinationPath $driverFolderPath -Force
    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue

    # 2. Tai script cai dat
    Write-Log "[$PrinterName] Dang tai script cai dat: $RepoRawBase/Install-Printer-$PrinterName.ps1"
    Invoke-WebRequest -Uri "$RepoRawBase/Install-Printer-$PrinterName.ps1" -OutFile $tempScript -UseBasicParsing

    # 2b. Ghi de dong $DriverFolder trong script vua tai, cho khop quy uoc thu muc = ten may in
    $scriptContent = Get-Content -Path $tempScript -Raw
    $newDriverFolderLine = "`$DriverFolder = `"$driverFolderPath`""
    $evaluator = [System.Text.RegularExpressions.MatchEvaluator] { param($m) $newDriverFolderLine }
    $scriptContent = [System.Text.RegularExpressions.Regex]::Replace($scriptContent, '\$DriverFolder\s*=\s*".*"', $evaluator)
    Set-Content -Path $tempScript -Value $scriptContent -Encoding UTF8

    # 3. Chay script cai dat
    Write-Log "[$PrinterName] Dang chay script cai dat (DriverFolder = $driverFolderPath)..."
    & $tempScript

    Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
}

# ---- KIEM TRA QUYEN ADMIN ----
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Log "Script can chay voi quyen Administrator." "ERROR"
    exit 1
}

# ---- CHAY CAI DAT HANG LOAT ----
$results = @()
Write-Log "===== Bat dau trien khai $($PrinterList.Count) may in tu repo JaxVN/Printers ====="

foreach ($printerName in $PrinterList) {
    Write-Log "===== [$printerName] Bat dau ====="
    try {
        Install-OnePrinterFromRepo -PrinterName $printerName
        Write-Log "[$printerName] Thanh cong." "SUCCESS"
        $results += [PSCustomObject]@{ Printer = $printerName; Status = "OK"; Error = "" }
    }
    catch {
        Write-Log "[$printerName] LOI: $($_.Exception.Message)" "ERROR"
        $results += [PSCustomObject]@{ Printer = $printerName; Status = "FAILED"; Error = $_.Exception.Message }
    }
}

# ---- TONG KET ----
Write-Log "===== TONG KET TRIEN KHAI ====="
$results | Format-Table -AutoSize | Out-String | Write-Host

$failCount = ($results | Where-Object { $_.Status -eq "FAILED" }).Count
if ($failCount -gt 0) {
    Write-Log "$failCount / $($PrinterList.Count) may in trien khai LOI. Xem log ben tren de biet chi tiet." "ERROR"
    exit 1
}
else {
    Write-Log "Tat ca $($PrinterList.Count) may in da trien khai thanh cong." "SUCCESS"
}
