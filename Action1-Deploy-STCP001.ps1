# =====================================================================
# ACTION1 DEPLOY SCRIPT - Trien khai may in STCP001 tu GitHub repo JaxVN/Printers
# =====================================================================
# Repo: https://github.com/JaxVN/Printers (public, branch: main)
# Script nay se:
#   1. Tai driver STCP001.zip ve va giai nen dung vao thu muc driver ma
#      Install-Printer-STCP001.ps1 dang tro toi.
#   2. Tai Install-Printer-STCP001.ps1 ve may tram.
#   3. Chay script do de cai driver + tao port + tao may in.
# Chay voi quyen SYSTEM/Admin (Action1 mac dinh da chay elevated).
# =====================================================================

# ---- CAU HINH ----
$PrinterName    = "STCP001"
$RepoRawBase    = "https://raw.githubusercontent.com/JaxVN/Printers/main"
$DriverRootBase = "C:\Soft\Printers"

# Quy uoc: ten thu muc driver = ten file zip = ten may in (vd: STCP001.zip -> C:\Soft\Printers\STCP001)
$DriverFolderName = $PrinterName

$ErrorActionPreference = "Stop"
# Bat buoc TLS 1.2 vi mot so may tram Windows cu (Server 2012/Win7) mac dinh dung TLS cu, GitHub se tu choi ket noi
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts][$Level] $Message"
}

try {
    $driverFolderPath = Join-Path $DriverRootBase $DriverFolderName
    $tempZip          = Join-Path $env:TEMP "$PrinterName.zip"
    $tempScript       = Join-Path $env:TEMP "Install-Printer-$PrinterName.ps1"

    # 1. Tai driver zip
    Write-Log "Dang tai driver: $RepoRawBase/$PrinterName.zip"
    Invoke-WebRequest -Uri "$RepoRawBase/$PrinterName.zip" -OutFile $tempZip -UseBasicParsing

    if (-not (Test-Path $driverFolderPath)) {
        New-Item -ItemType Directory -Path $driverFolderPath -Force | Out-Null
    }

    Write-Log "Dang giai nen driver vao: $driverFolderPath"
    Expand-Archive -Path $tempZip -DestinationPath $driverFolderPath -Force
    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue

    # 2. Tai script cai dat may in
    Write-Log "Dang tai script cai dat: $RepoRawBase/Install-Printer-$PrinterName.ps1"
    Invoke-WebRequest -Uri "$RepoRawBase/Install-Printer-$PrinterName.ps1" -OutFile $tempScript -UseBasicParsing

    # 2b. Ghi de dong $DriverFolder trong script vua tai, cho khop quy uoc thu muc moi
    #     (script goc tren repo co the dang tro toi thu muc dat theo ten driver, khac quy uoc nay)
    $scriptContent = Get-Content -Path $tempScript -Raw
    $newDriverFolderLine = "`$DriverFolder = `"$driverFolderPath`""
    $evaluator = [System.Text.RegularExpressions.MatchEvaluator] { param($m) $newDriverFolderLine }
    $scriptContent = [System.Text.RegularExpressions.Regex]::Replace($scriptContent, '\$DriverFolder\s*=\s*".*"', $evaluator)
    Set-Content -Path $tempScript -Value $scriptContent -Encoding UTF8

    # 3. Chay script cai dat
    Write-Log "Dang chay script cai dat may in $PrinterName (DriverFolder da duoc chinh thanh $driverFolderPath)..."
    & $tempScript

    Write-Log "Hoan tat trien khai may in $PrinterName qua Action1." "SUCCESS"
}
catch {
    Write-Log "LOI trien khai $PrinterName : $($_.Exception.Message)" "ERROR"
    exit 1
}
finally {
    Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
}
