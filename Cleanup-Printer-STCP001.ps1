# =====================================================================
# CLEANUP SCRIPT - Go may in, port va driver STCP001 de test lai tu dau
# =====================================================================
# Script nay se go theo thu tu: Printer -> Printer Port -> Printer Driver
# -> Thu muc driver local (C:\Soft\Printers\STCP001)
# Sau khi chay xong, may se ve trang thai "chua co gi", chay lai
# Action1-Deploy-STCP001.ps1 se tai driver + tao port + tao may in tu dau.
# =====================================================================

# ---- CAU HINH (doi lai cho tung may in khi can) ----
$PrinterName      = "STCP001"
$PortName         = "IP_10.10.12.214"
$DriverName       = "RICOH Aficio MP 5001 PCL 6"
$DriverFolderPath = "C:\Soft\Printers\STCP001"

# Xoa sau khoi Driver Store (pnputil) - true = xoa triet de ca goi driver da nap vao he thong,
# khong chi bo lien ket voi Print Spooler. Dat $false neu chi muon test lai buoc tao printer/port.
$RemoveFromDriverStore = $true

$ErrorActionPreference = "Continue"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts][$Level] $Message"
}

# 0. Kiem tra quyen Admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Log "Script can chay voi quyen Administrator." "ERROR"
    exit 1
}

# 1. Xoa may in
Write-Log "----- Xoa may in '$PrinterName' -----"
$printer = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
if ($printer) {
    try {
        Remove-Printer -Name $PrinterName -ErrorAction Stop
        Write-Log "Da xoa may in '$PrinterName'." "SUCCESS"
    }
    catch {
        Write-Log "Loi khi xoa may in: $($_.Exception.Message)" "ERROR"
    }
}
else {
    Write-Log "May in '$PrinterName' khong ton tai. Bo qua."
}

# 2. Xoa printer port
Write-Log "----- Xoa port '$PortName' -----"
$port = Get-PrinterPort -Name $PortName -ErrorAction SilentlyContinue
if ($port) {
    try {
        Remove-PrinterPort -Name $PortName -ErrorAction Stop
        Write-Log "Da xoa port '$PortName'." "SUCCESS"
    }
    catch {
        Write-Log "Loi khi xoa port (co the con printer khac dang dung port nay): $($_.Exception.Message)" "ERROR"
    }
}
else {
    Write-Log "Port '$PortName' khong ton tai. Bo qua."
}

# 3. Xoa printer driver (khoi Print Spooler)
Write-Log "----- Xoa driver '$DriverName' -----"
$driver = Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue
if ($driver) {
    try {
        Remove-PrinterDriver -Name $DriverName -ErrorAction Stop
        Write-Log "Da xoa driver '$DriverName' khoi Print Spooler." "SUCCESS"
    }
    catch {
        Write-Log "Loi khi xoa driver (co the con may in khac dang dung driver nay, hoac driver dang bi khoa): $($_.Exception.Message)" "ERROR"
    }
}
else {
    Write-Log "Driver '$DriverName' khong ton tai trong Print Spooler. Bo qua."
}

# 3b. (Tuy chon) Xoa triet de goi driver khoi Driver Store bang pnputil
if ($RemoveFromDriverStore) {
    Write-Log "----- Tim va xoa goi driver trong Driver Store (pnputil) -----"
    try {
        $pnpList = pnputil.exe /enum-drivers
        $blocks = ($pnpList -join "`n") -split "(?=Published Name\s*:)"
        $matchedOem = $null

        foreach ($block in $blocks) {
            if ($block -match "Original Name\s*:\s*(.+)" ) {
                $origName = $Matches[1].Trim()
            }
            if ($block -match [regex]::Escape($DriverName)) {
                if ($block -match "Published Name\s*:\s*(oem\d+\.inf)") {
                    $matchedOem = $Matches[1]
                    break
                }
            }
        }

        if ($matchedOem) {
            Write-Log "Tim thay goi driver $matchedOem khop voi '$DriverName'. Dang xoa..."
            pnputil.exe /delete-driver $matchedOem /uninstall /force | Out-Null
            Write-Log "Da xoa $matchedOem khoi Driver Store." "SUCCESS"
        }
        else {
            Write-Log "Khong tim thay goi driver nao trong Driver Store khop ten '$DriverName'. Co the da bi xoa hoac ten khong khop." "WARN"
        }
    }
    catch {
        Write-Log "Loi khi thao tac voi pnputil: $($_.Exception.Message)" "WARN"
    }
}

# 4. Xoa thu muc driver local (de lan sau tai lai tu GitHub, khong bi anh huong boi ban cu)
Write-Log "----- Xoa thu muc driver local '$DriverFolderPath' -----"
if (Test-Path $DriverFolderPath) {
    try {
        Remove-Item -Path $DriverFolderPath -Recurse -Force -ErrorAction Stop
        Write-Log "Da xoa thu muc '$DriverFolderPath'." "SUCCESS"
    }
    catch {
        Write-Log "Loi khi xoa thu muc: $($_.Exception.Message)" "ERROR"
    }
}
else {
    Write-Log "Thu muc '$DriverFolderPath' khong ton tai. Bo qua."
}

Write-Log "----- Hoan tat don dep. May da san sang de test lai tu dau. -----" "SUCCESS"
