# gitleaks_scan.ps1 -- run gitleaks against the working tree + git history
# and write the JSON report under .claude/plan/output/.
#
# ASCII-only (CLAUDE.md rule). Invoke as:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/security/gitleaks_scan.ps1
#
# Exit codes:
#   0 = no leaks (or hits suppressed by allowlist)
#   1 = leaks found (see report)
#   2 = gitleaks not installed

param(
    [switch]$StagedOnly,
    [string]$ReportPath = ".claude/plan/output/gitleaks_report.json"
)

$ErrorActionPreference = "Stop"

# Locate gitleaks: try PATH first, then fall back to winget shim path.
$gl = Get-Command gitleaks -ErrorAction SilentlyContinue
if (-not $gl) {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + `
                [System.Environment]::GetEnvironmentVariable("Path", "User")
    $gl = Get-Command gitleaks -ErrorAction SilentlyContinue
}
if (-not $gl) {
    Write-Host "[gitleaks] not installed. Run: winget install --id Gitleaks.Gitleaks" -ForegroundColor Red
    exit 2
}

$repoRoot = git rev-parse --show-toplevel
if (-not $repoRoot) {
    Write-Host "[gitleaks] not inside a git repo." -ForegroundColor Red
    exit 2
}

Push-Location $repoRoot
try {
    $reportFull = Join-Path $repoRoot $ReportPath
    $reportDir = Split-Path $reportFull -Parent
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }

    $cfg = Join-Path $repoRoot ".gitleaks.toml"
    if (-not (Test-Path $cfg)) {
        Write-Host "[gitleaks] missing config $cfg" -ForegroundColor Red
        exit 2
    }

    if ($StagedOnly) {
        Write-Host "[gitleaks] scanning staged diff..." -ForegroundColor Cyan
        & gitleaks protect --staged --config $cfg --redact --no-banner `
            --report-path $reportFull --report-format json
    } else {
        Write-Host "[gitleaks] scanning working tree + history..." -ForegroundColor Cyan
        & gitleaks detect --source . --config $cfg --redact --no-banner `
            --report-path $reportFull --report-format json
    }

    $exit = $LASTEXITCODE
    if ($exit -eq 0) {
        Write-Host "[gitleaks] OK -- no leaks." -ForegroundColor Green
    } else {
        Write-Host "[gitleaks] LEAKS FOUND -- see $ReportPath" -ForegroundColor Red
    }
    exit $exit
} finally {
    Pop-Location
}
