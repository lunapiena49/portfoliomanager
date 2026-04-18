#Requires -Version 5.1
<#
SessionStart hook -- eseguito all'avvio di ogni sessione Claude Code.

Azioni:
  1. Se la branch corrente e' main, tenta `git pull --ff-only` (non-blocking).
  2. Verifica la freshness del market snapshot locale (top_movers.json).
     - Se stale (> 24h) o mancante, lancia `sync_market_snapshot_from_pages.ps1`
       in **background detached**: il DB pesante (~950MB) e i JSON vengono scaricati
       senza bloccare l'avvio del hook (timeout 20s).
  3. Verifica l'ultimo run del workflow daily-data-commit.yml.
     Se > 24h o mai eseguito, segnala nell'additionalContext cosi' Claude puo'
     proporre `rtk gh workflow run daily-data-commit.yml` (conferma via permissions.ask).

Output (opzionale, JSON su stdout):
  { "hookSpecificOutput": { "hookEventName": "SessionStart", "additionalContext": "..." } }

Non blocca mai l'avvio. Errori silenziosi (registrati su stderr).

Convenzione sul DB:
  - Il .db/.db.zip NON viene committato nel repo (vedi .gitignore).
  - La verita' del DB e' su GitHub Pages, aggiornata dal workflow `market-data-snapshot.yml`.
  - Ogni sessione locale lo pulla (fire-and-forget), mai lo pusha.
  - Il commit "proof of freshness" nel repo e' solo `top_movers.json` + `docs/DATA_SNAPSHOT_LOG.md`,
    curato dal workflow `daily-data-commit.yml`.
#>

$ErrorActionPreference = 'Continue'

function Get-RepoRoot {
    try {
        $root = & git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0) { return $root.Trim() }
    } catch { }
    return $null
}

function Get-CurrentBranch {
    try {
        $b = & git rev-parse --abbrev-ref HEAD 2>$null
        if ($LASTEXITCODE -eq 0) { return $b.Trim() }
    } catch { }
    return $null
}

function Test-StaleJson {
    param([string]$Path, [int]$MaxAgeHours = 24)
    if (-not (Test-Path $Path)) { return @{ stale = $true; reason = 'snapshot mancante' } }
    try {
        $json = Get-Content -Raw -Path $Path | ConvertFrom-Json
        $ts = $null
        foreach ($k in @('generated_at_utc', 'as_of_date')) {
            if ($json.$k) { $ts = $json.$k; break }
        }
        if (-not $ts) { return @{ stale = $true; reason = 'timestamp assente' } }
        $dt = [DateTime]::Parse($ts).ToUniversalTime()
        $age = ([DateTime]::UtcNow - $dt).TotalHours
        if ($age -gt $MaxAgeHours) {
            return @{ stale = $true; reason = ("snapshot vecchio di {0:N1}h" -f $age) }
        }
        return @{ stale = $false }
    } catch {
        return @{ stale = $true; reason = "parse error: $($_.Exception.Message)" }
    }
}

function Test-StaleDb {
    param([string]$Path, [int]$MaxAgeHours = 24)
    if (-not (Test-Path $Path)) { return @{ stale = $true; reason = 'db mancante' } }
    $age = ([DateTime]::UtcNow - (Get-Item $Path).LastWriteTimeUtc).TotalHours
    if ($age -gt $MaxAgeHours) {
        return @{ stale = $true; reason = ("db vecchio di {0:N1}h" -f $age) }
    }
    return @{ stale = $false }
}

function Start-BackgroundSync {
    param([string]$ScriptPath)
    try {
        # Detached: Claude-independent. Lo script prosegue anche se il hook termina.
        $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath)
        Start-Process -FilePath 'powershell.exe' -ArgumentList $args -WindowStyle Hidden -ErrorAction Stop | Out-Null
        return $true
    } catch {
        [Console]::Error.WriteLine("Start-BackgroundSync error: $($_.Exception.Message)")
        return $false
    }
}

$messages = New-Object System.Collections.Generic.List[string]

$repo = Get-RepoRoot
if (-not $repo) { exit 0 }
Set-Location $repo

# Step 1: pull ff-only se main
$branch = Get-CurrentBranch
if ($branch -eq 'main') {
    & git pull --ff-only 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $messages.Add('git pull --ff-only: ok su main')
    } else {
        $messages.Add('git pull --ff-only: skip (diverge o offline)')
    }
}

# Step 2: freshness snapshot + DB; sync in background se stale
$snapshotPath = Join-Path $repo 'dist/market-data/top_movers.json'
$dbPath       = Join-Path $repo 'dist/market-data/market_history.db.zip'
$syncScript   = Join-Path $repo 'scripts/eodhd/sync_market_snapshot_from_pages.ps1'

$snapCheck = Test-StaleJson -Path $snapshotPath -MaxAgeHours 24
$dbCheck   = Test-StaleDb   -Path $dbPath       -MaxAgeHours 24

if ($snapCheck.stale -or $dbCheck.stale) {
    $reasons = @()
    if ($snapCheck.stale) { $reasons += "snapshot: $($snapCheck.reason)" }
    if ($dbCheck.stale)   { $reasons += "db: $($dbCheck.reason)" }
    $reasonStr = $reasons -join '; '

    if (Test-Path $syncScript) {
        $ok = Start-BackgroundSync -ScriptPath $syncScript
        if ($ok) {
            $messages.Add("Dati stale ($reasonStr). Sync avviato in background da GitHub Pages (JSON veloce, DB ~950MB puo' richiedere minuti).")
        } else {
            $messages.Add("Dati stale ($reasonStr). Background sync non avviabile -- usa skill 'market-data-local' manualmente.")
        }
    } else {
        $messages.Add("Dati stale ($reasonStr) ma sync script non trovato in scripts/eodhd/.")
    }
}

# Step 3: ultimo run del workflow daily-data-commit
try {
    $runJson = & gh run list --workflow=daily-data-commit.yml --limit 1 --json createdAt,status,conclusion 2>$null
    if ($LASTEXITCODE -eq 0 -and $runJson) {
        $runs = $runJson | ConvertFrom-Json
        if ($runs.Count -eq 0) {
            $messages.Add("daily-data-commit.yml mai eseguito. Suggerimento: 'rtk gh workflow run daily-data-commit.yml'")
        } else {
            $last = [DateTime]::Parse($runs[0].createdAt).ToUniversalTime()
            $age = ([DateTime]::UtcNow - $last).TotalHours
            if ($age -gt 24) {
                $roundedAge = [math]::Round($age, 1)
                $messages.Add("daily-data-commit ultima esecuzione ${roundedAge}h fa. Suggerimento: 'rtk gh workflow run daily-data-commit.yml'")
            }
        }
    }
} catch {
    # gh non autenticato o workflow assente. Silent.
}

if ($messages.Count -gt 0) {
    $ctx = "Session start checks:`n- " + ($messages -join "`n- ")
    $out = @{
        hookSpecificOutput = @{
            hookEventName     = 'SessionStart'
            additionalContext = $ctx
        }
    } | ConvertTo-Json -Compress -Depth 4
    Write-Output $out
}

exit 0
