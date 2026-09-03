# --- CAU HINH MAY IN STCP004 ---
$PrinterName  = "STCP004"
$DriverName   = "HP Designjet 510ps 42in Printer"
$PrinterIP    = "10.10.12.201"
$PortName     = "IP_10.10.12.201"
# Thu muc chua driver cua may in nay (sua lai neu ten thu muc thuc te khac)
$DriverFolder = "C:\Soft\Printers\HP Designjet 510ps 42in Printer"

# --- BAT DAU SCRIPT ---
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts][$Level] $Message"
}

# 0. Kiem tra quyen Admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Log "Script can chay voi quyen Administrator. Mo PowerShell as Admin va chay lai." "ERROR"
    exit 1
}

try {
    # 1. Cai driver neu chua co
    Write-Log "Kiem tra driver '$DriverName'..."
    $existingDriver = Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue

    if (-not $existingDriver) {
        Write-Log "Driver chua co. Dang tim file .inf trong '$DriverFolder'..."

        if (-not (Test-Path $DriverFolder)) {
            throw "Khong tim thay thu muc driver: $DriverFolder"
        }

        $infFiles = Get-ChildItem -Path $DriverFolder -Filter "*.inf" -Recurse -ErrorAction SilentlyContinue
        if (-not $infFiles) {
            throw "Khong tim thay file .inf nao trong '$DriverFolder'"
        }

        foreach ($inf in $infFiles) {
            try { pnputil.exe /add-driver "$($inf.FullName)" /install | Out-Null }
            catch { Write-Log "pnputil loi voi $($inf.Name): $($_.Exception.Message)" "WARN" }
        }

        $matchInf = $infFiles | Where-Object {
            Select-String -Path $_.FullName -Pattern ([regex]::Escape($DriverName)) -SimpleMatch -Quiet -ErrorAction SilentlyContinue
        } | Select-Object -First 1

        if ($matchInf) {
            Add-PrinterDriver -Name $DriverName -InfPath $matchInf.FullName -ErrorAction Stop
        }
        else {
            Add-PrinterDriver -Name $DriverName -ErrorAction Stop
        }
        Write-Log "Da cai driver '$DriverName' thanh cong."
    }
    else {
        Write-Log "Driver '$DriverName' da ton tai. Bo qua."
    }

    # 2. Tao port neu chua co
    Write-Log "Kiem tra port '$PortName'..."
    if (-not (Get-PrinterPort -Name $PortName -ErrorAction SilentlyContinue)) {
        Add-PrinterPort -Name $PortName -PrinterHostAddress $PrinterIP
        Write-Log "Da tao port '$PortName'."
    }
    else {
        Write-Log "Port '$PortName' da ton tai. Bo qua."
    }

    # 3. Tao may in neu chua co
    Write-Log "Kiem tra may in '$PrinterName'..."
    if (-not (Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue)) {
        Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $PortName
        Write-Log "Da cai may in '$PrinterName' thanh cong!" "SUCCESS"
    }
    else {
        Write-Log "May in '$PrinterName' da ton tai. Bo qua."
    }

    Get-Printer -Name $PrinterName | Select-Object Name, DriverName, PortName, PrinterStatus | Format-Table -AutoSize
}
catch {
    Write-Log "LOI: $($_.Exception.Message)" "ERROR"
    exit 1
}
