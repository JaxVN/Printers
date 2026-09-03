# Printer Deployment Toolkit (GitHub + Action1)

A lightweight, repo-driven framework for deploying network printers (driver install, TCP/IP port, printer queue) to Windows endpoints via any RMM tool that can run PowerShell — this guide uses **Action1** as the example, but the same pattern works with Intune, PDQ, SCCM, or any script-push tool.

The core idea: **the RMM only holds a tiny loader**. All real logic (driver packages, per-printer config, install steps) lives in a Git repo, so updates ship by pushing to `main` — no need to edit the RMM policy every time.

## How it works

```
RMM policy (short loader script)
        │
        ▼
Downloads a "deploy" script + driver .zip from GitHub (raw.githubusercontent.com)
        │
        ▼
Extracts driver → installs printer driver → creates TCP/IP port → creates printer
        │
        ▼
Detailed log written to disk; RMM console shows only a short summary
```

## Repo structure (suggested)

| File pattern | Purpose |
|---|---|
| `Install-Printer-<PrinterName>.ps1` | Single source of truth for **one** printer: driver name, IP, port name, install steps. Can be run standalone on a machine that already has the driver files locally. |
| `<PrinterName>.zip` | The driver package (`.inf` + supporting files) for that printer, named to match the printer exactly. |
| `Deploy-OnePrinter.ps1` | Core script: takes `-PrinterName` as a parameter, downloads that printer's zip + install script from the repo, fixes up the local driver path, runs it. Logs details to file, prints a short summary to the console. |
| `Loader-OnePrinter.ps1` | The snippet you actually paste into the RMM. One editable line (`$PrinterName = "..."`), the rest just downloads and runs `Deploy-OnePrinter.ps1`. |
| `Deploy-AllPrinters.ps1` | Same idea but loops over a list of printers in one run; one failure doesn't stop the rest. Prints an OK/FAILED summary table at the end. |
| `Loader-AllPrinters.ps1` | Paste-into-RMM snippet for the "deploy everything" policy. |
| `Cleanup-Printer.ps1` | Removes a printer queue, its port, and its driver (including from the Windows Driver Store) — useful for resetting a test machine to a clean state. |
| `README.md` | This file, or an org-specific one describing your actual printer inventory. |

## Naming conventions

- File names always match the **printer queue name** exactly (e.g. `HQ-PRINT-01`), not the driver's friendly name — driver names often contain spaces, parentheses, and version numbers that are awkward to script around.
- On the endpoint, drivers are extracted to a folder named after the printer, not the driver:
  `C:\<YourDriverRoot>\<PrinterName>\`
- Deployment logs are written per run:
  `C:\<YourDriverRoot>\DeployLog_<PrinterName>_<yyyyMMdd_HHmmss>.log` (single printer)
  `C:\<YourDriverRoot>\DeployLog_<yyyyMMdd_HHmmss>.log` (batch)

## Usage

### 1. Manual install on one machine (no RMM)

Download `Install-Printer-<Name>.ps1` and `<Name>.zip` to the same folder, extract the zip into `C:\<YourDriverRoot>\<Name>\`, then run the script directly.

### 2. RMM-driven install — one printer

1. Push `Deploy-OnePrinter.ps1` to the repo (only needs updating when the logic changes).
2. In your RMM, create one policy per target printer/machine group; paste `Loader-OnePrinter.ps1`.
3. Edit the single `$PrinterName` line to match.
4. Run. The RMM console shows only printer name, status, and the log file path — full detail is on disk.

### 3. RMM-driven install — all printers

1. Push `Deploy-AllPrinters.ps1` to the repo; maintain the printer list as an array inside that file.
2. Paste `Loader-AllPrinters.ps1` into a single RMM policy targeting all relevant machines.
3. Adding/removing a printer from the fleet-wide rollout is a one-line change to the array on the repo — no RMM edit needed.

### 4. Resetting a test machine

Run `Cleanup-Printer.ps1` to remove the printer queue, its port, and its driver (Print Spooler + Driver Store), and delete the local driver folder — puts the machine back to a "nothing installed" state for repeat testing.

## Adding a new printer

1. Copy an existing `Install-Printer-*.ps1` as a template; update the printer name, driver name, IP, and port variables.
2. Zip the driver package as `<PrinterName>.zip`.
3. Push both files to the repo root.
4. Add the printer name to `Deploy-AllPrinters.ps1`'s list if it should be part of the bulk rollout.
5. Optionally create a dedicated RMM policy using `Loader-OnePrinter.ps1` with that printer name.

## Operational notes

- **Repo write access = code execution as SYSTEM/Admin fleet-wide.** Anyone who can push to this repo can affect every endpoint on the next scheduled run. Keep write access restricted, and enable 2FA on the accounts that have it. A public repo is fine for read access (no secrets should ever live here — driver files and install scripts only), but access control matters far more than repo visibility.
- **CDN caching**: `raw.githubusercontent.com` caches responses for a few minutes. A push may take a short while to be visible to endpoints pulling immediately after.
- **Network dependency**: endpoints need outbound HTTPS to GitHub's raw content domain. Behind restrictive proxies, allowlist the domain, or fall back to the manual install path (section 1).
- **Pin for stability if needed**: pulling from `main` is convenient but live — for critical rollouts, consider referencing a specific commit SHA in the raw URL instead of `main`, so an in-progress edit can't affect a deployment mid-flight.
- **Vendor-specific ports**: some printers (e.g. certain Canon consumer models) use a proprietary port monitor (like a "Bonjour"/network discovery port) that Windows' built-in `Add-PrinterPort` cannot create. In those cases, use a standard TCP/IP port pointed at the printer's IP instead — it prints fine, you just lose the vendor's bidirectional status extras.
- **Idempotency**: install scripts should check whether the driver, port, and printer already exist before creating them, so re-running a deployment (e.g. after a failed run, or on a periodic RMM schedule) is safe and doesn't error out or duplicate objects.

## Adapting this to your organization

Replace every `<PrinterName>`, `<YourDriverRoot>`, and repo URL placeholder with your own values, and swap "Action1" for whichever RMM/config-management tool you use — the loader pattern (small script in the RMM, real logic in Git) works the same way regardless of the tool, as long as it can execute an arbitrary PowerShell script with local admin rights on the endpoint.
