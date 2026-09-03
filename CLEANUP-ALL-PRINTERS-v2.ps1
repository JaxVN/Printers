# =====================================================================
# CLEANUP-ALL-PRINTERS - Go TOAN BO may in mang + port + driver,
# GIU LAI cac may in ao/he thong (Microsoft Print to PDF, OneNote, Fax...)
# =====================================================================
# Dung de reset may test ve trang thai sach truoc khi chay lai
# Action1-Deploy-AllPrinters-v2.ps1 tu dau.
#
# AN TOAN: co che $DryRun - de $true de XEM TRUOC se xoa nhung gi,
# chua xoa that. Kiem tra ky output roi moi doi sang $false de xoa that.
# =====================================================================

# ---- CO CHE AN TOAN: xem truoc, chua xoa that ----
$DryRun = $true    # DOI THANH $false KHI DA KIEM TRA KY DANH SACH SE XOA

#$DryRun = $false    # DOI THANH $false KHI DA KIEM TRA KY DANH SACH SE XOA

# ---- DANH SACH MAY IN/DRIVER CAN GIU LAI (khong dong vao) ----
# Ho tro wildcard (*). Them ten neu moi truong ban co may in ao khac
# (vd: "Adobe PDF", "Foxit Reader PDF Printer", "CutePDF Writer"...)
$KeepPrinterNamePatterns = @(
    "Microsoft Print to PDF",
    "Microsoft XPS Document Writer",
    "Fax",
    "OneNote*",
    "Send To OneNote*",
    "Adobe PDF"
)

# Thu muc goc chua driver local (de xoa thu muc con tuong ung may in bi go)
$DriverRootBase = "C:\Soft\Printers"

$ErrorActionPreference = "Continue"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts][$Level] $Message"
}

function Test-KeepPrinter {
    param([string]$Name)
    foreach ($pattern in $KeepPrinterNamePatterns) {
        if ($Name -like $pattern) { return $true }
    }
    return $false
}

# 0. Kiem tra quyen Admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Log "Script can chay voi quyen Administrator." "ERROR"
    exit 1
}

if ($DryRun) {
    Write-Log "==== CHE DO DRY RUN - CHI XEM TRUOC, CHUA XOA GI CA ====" "WARN"
}

$allPrinters   = Get-Printer -ErrorAction SilentlyContinue
$printersToRemove = $allPrinters | Where-Object { -not (Test-KeepPrinter -Name $_.Name) }
$printersToKeep   = $allPrinters | Where-Object { Test-KeepPrinter -Name $_.Name }

Write-Log "Tong so may in tren may: $($allPrinters.Count)"
Write-Log "Se GIU LAI: $($printersToKeep.Count) may in -> $($printersToKeep.Name -join ', ')"
Write-Log "Se XOA    : $($printersToRemove.Count) may in -> $($printersToRemove.Name -join ', ')"

if ($printersToRemove.Count -eq 0) {
    Write-Log "Khong co may in nao can xoa. Ket thuc." "SUCCESS"
    exit 0
}

# Ghi lai port + driver cua nhung may in SE GIU, de khong dam vao chung o buoc sau
$portsInUse   = $printersToKeep | Select-Object -ExpandProperty PortName -Unique
$driversInUse = $printersToKeep | Select-Object -ExpandProperty DriverName -Unique

# Ghi lai port + driver + ten cua nhung may in SE XOA (de xu ly o cac buoc tiep theo)
$portsToCheck   = $printersToRemove | Select-Object -ExpandProperty PortName -Unique
$driversToCheck = $printersToRemove | Select-Object -ExpandProperty DriverName -Unique
$printerNamesToRemove = $printersToRemove | Select-Object -ExpandProperty Name

# ---- 1. XOA MAY IN ----
Write-Log "----- Buoc 1: Xoa may in -----"
foreach ($p in $printersToRemove) {
    if ($DryRun) {
        Write-Log "[DRY RUN] Se xoa may in: $($p.Name)"
    }
    else {
        try {
            Remove-Printer -Name $p.Name -ErrorAction Stop
            Write-Log "Da xoa may in '$($p.Name)'." "SUCCESS"
        }
        catch {
            Write-Log "Loi khi xoa may in '$($p.Name)': $($_.Exception.Message)" "ERROR"
        }
    }
}

# ---- 2. XOA PORT (chi xoa port khong con may in nao GIU LAI dang dung) ----
Write-Log "----- Buoc 2: Xoa printer port -----"
$portsToRemove = $portsToCheck | Where-Object { $portsInUse -notcontains $_ }
foreach ($portName in $portsToRemove) {
    $port = Get-PrinterPort -Name $portName -ErrorAction SilentlyContinue
    if (-not $port) { continue }

    if ($DryRun) {
        Write-Log "[DRY RUN] Se xoa port: $portName"
    }
    else {
        try {
            Remove-PrinterPort -Name $portName -ErrorAction Stop
            Write-Log "Da xoa port '$portName'." "SUCCESS"
        }
        catch {
            Write-Log "Loi khi xoa port '$portName' (co the con may in khac dang dung): $($_.Exception.Message)" "ERROR"
        }
    }
}

# ---- 3. XOA DRIVER (chi xoa driver khong con may in nao GIU LAI dang dung) ----
Write-Log "----- Buoc 3: Xoa printer driver -----"
$driversToRemove = $driversToCheck | Where-Object { $driversInUse -notcontains $_ }
foreach ($driverName in $driversToRemove) {
    $driver = Get-PrinterDriver -Name $driverName -ErrorAction SilentlyContinue
    if (-not $driver) { continue }

    if ($DryRun) {
        Write-Log "[DRY RUN] Se xoa driver: $driverName"
    }
    else {
        try {
            Remove-PrinterDriver -Name $driverName -ErrorAction Stop
            Write-Log "Da xoa driver '$driverName' khoi Print Spooler." "SUCCESS"
        }
        catch {
            Write-Log "Loi khi xoa driver '$driverName': $($_.Exception.Message)" "ERROR"
        }
    }
}

# ---- 3b. (Tuy chon) Xoa goi driver khoi Driver Store bang pnputil ----
if (-not $DryRun -and $driversToRemove.Count -gt 0) {
    Write-Log "----- Buoc 3b: Tim va xoa goi driver trong Driver Store (pnputil) -----"
    try {
        $pnpList = pnputil.exe /enum-drivers
        $blocks = ($pnpList -join "`n") -split "(?=Published Name\s*:)"

        foreach ($driverName in $driversToRemove) {
            $matchedOem = $null
            foreach ($block in $blocks) {
                if ($block -match [regex]::Escape($driverName)) {
                    if ($block -match "Published Name\s*:\s*(oem\d+\.inf)") {
                        $matchedOem = $Matches[1]
                        break
                    }
                }
            }
            if ($matchedOem) {
                Write-Log "Tim thay goi driver $matchedOem khop '$driverName'. Dang xoa..."
                pnputil.exe /delete-driver $matchedOem /uninstall /force | Out-Null
                Write-Log "Da xoa $matchedOem khoi Driver Store." "SUCCESS"
            }
            else {
                Write-Log "Khong tim thay goi Driver Store khop '$driverName'." "WARN"
            }
        }
    }
    catch {
        Write-Log "Loi khi thao tac voi pnputil: $($_.Exception.Message)" "WARN"
    }
}


if ($DryRun) {
    Write-Log "==== DRY RUN HOAN TAT - CHUA XOA GI. Kiem tra danh sach o tren, sau do dat `$DryRun = `$false` de xoa that. ====" "WARN"
}
else {
    Write-Log "==== HOAN TAT DON DEP. May da san sang de test lai tu dau. ====" "SUCCESS"
}
