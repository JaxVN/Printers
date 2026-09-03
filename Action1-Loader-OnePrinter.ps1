# =====================================================================
# ACTION1 LOADER - Cai 1 MAY IN, tai script chinh tu GitHub repo
# =====================================================================
# Paste doan nay vao Action1. Voi moi policy/may in khac nhau, CHI CAN
# doi gia tri $PrinterName ben duoi - logic that su nam o repo, khong
# can dong lai gi khac.
# =====================================================================

# ---- CHI CAN SUA DONG NAY CHO TUNG MAY IN ----
$PrinterName = "STCP001"

# ---- KHONG CAN SUA PHAN DUOI ----
$RepoRawBase = "https://raw.githubusercontent.com/JaxVN/Printers/main"
$MainScript  = "Action1-Deploy-OnePrinter-v2.ps1"
$LocalCopy   = Join-Path $env:TEMP $MainScript

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    Invoke-WebRequest -Uri "$RepoRawBase/$MainScript" -OutFile $LocalCopy -UseBasicParsing
    & $LocalCopy -PrinterName $PrinterName
    $exitCode = $LASTEXITCODE
}
catch {
    Write-Host "LOI khi tai/chay script chinh tu repo: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Remove-Item $LocalCopy -Force -ErrorAction SilentlyContinue
}

if ($exitCode) { exit $exitCode }
