# =====================================================================
# Action1-Deploy-OnePrinter-v2.ps1
# Trien khai 1 MAY IN tu GitHub repo JaxVN/Printers - dua len repo,
# duoc goi tu Action1-Loader-OnePrinter.ps1 (paste trong Action1) voi
# tham so -PrinterName.
# Console (Action1 nhin thay) CHI hien tom tat. Log chi tiet luu vao
# C:\Soft\Printers\DeployLog_<TenMayIn>_<thoigian>.log
# =====================================================================
param(
    [Parameter(Mandatory = $true)]
    [string]$PrinterName
)

# ---- CAU HINH CHUNG ----
$RepoRawBase    = "https://raw.githubusercontent.com/JaxVN/Printers/main"
$DriverRootBase = "C:\Soft\Printers"
$LogFile        = Join-Path $DriverRootBase "DeployLog_${PrinterName}_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not (Test-Path $DriverRootBase)) {
    New-Item -ItemType Directory -Path $DriverRootBase -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$ts][$Level] $Message" -Encoding UTF8
}

# ---- KIEM TRA QUYEN ADMIN ----
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Script can chay voi quyen Administrator." -ForegroundColor Red
    exit 1
}

Write-Log "===== Bat dau trien khai may in $PrinterName ====="

try {
    $driverFolderPath = Join-Path $DriverRootBase $PrinterName
    $tempZip          = Join-Path $env:TEMP "$PrinterName.zip"
    $tempScript       = Join-Path $env:TEMP "Install-Printer-$PrinterName.ps1"

    Write-Log "Dang tai driver: $RepoRawBase/$PrinterName.zip"
    Invoke-WebRequest -Uri "$RepoRawBase/$PrinterName.zip" -OutFile $tempZip -UseBasicParsing

    if (-not (Test-Path $driverFolderPath)) {
        New-Item -ItemType Directory -Path $driverFolderPath -Force | Out-Null
    }

    Write-Log "Dang giai nen driver vao: $driverFolderPath"
    Expand-Archive -Path $tempZip -DestinationPath $driverFolderPath -Force
    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue

    Write-Log "Dang tai script cai dat: $RepoRawBase/Install-Printer-$PrinterName.ps1"
    Invoke-WebRequest -Uri "$RepoRawBase/Install-Printer-$PrinterName.ps1" -OutFile $tempScript -UseBasicParsing

    $scriptContent = Get-Content -Path $tempScript -Raw
    $newDriverFolderLine = "`$DriverFolder = `"$driverFolderPath`""
    $evaluator = [System.Text.RegularExpressions.MatchEvaluator] { param($m) $newDriverFolderLine }
    $scriptContent = [System.Text.RegularExpressions.Regex]::Replace($scriptContent, '\$DriverFolder\s*=\s*".*"', $evaluator)
    Set-Content -Path $tempScript -Value $scriptContent -Encoding UTF8

    Write-Log "Dang chay script cai dat (DriverFolder = $driverFolderPath)..."
    & $tempScript *>&1 | ForEach-Object { Add-Content -Path $LogFile -Value $_.ToString() -Encoding UTF8 }

    Remove-Item $tempScript -Force -ErrorAction SilentlyContinue

    Write-Log "===== Hoan tat trien khai $PrinterName - THANH CONG ====="

    # ---- CHI PHAN NAY HIEN RA CONSOLE ----
    Write-Host "===== KET QUA TRIEN KHAI MAY IN =====" 
    Write-Host "May in : $PrinterName"
    Write-Host "Trang thai : THANH CONG"
    Write-Host "Log chi tiet: $LogFile"
}
catch {
    Write-Log "LOI: $($_.Exception.Message)" "ERROR"
    Write-Log "===== Hoan tat trien khai $PrinterName - THAT BAI ====="

    Write-Host "===== KET QUA TRIEN KHAI MAY IN ====="
    Write-Host "May in : $PrinterName"
    Write-Host "Trang thai : THAT BAI"
    Write-Host "Loi: $($_.Exception.Message)"
    Write-Host "Log chi tiet: $LogFile"
    exit 1
}
