#Requires -Version 5.1
<#
Stop hook -- eseguito quando Claude sta per chiudere la sessione.

Azione: se dall'inizio della sessione ci sono commit nuovi o file modificati non committati
che toccano `lib/`, `assets/translations/`, o `.github/workflows/`, emette un
additionalContext per invitare Claude a eseguire la skill `session-wrap` (aggiorna
IMPLEMENTATION_HISTORY.md e USER_FEATURES.md).

Il hook NON esegue automaticamente la skill per evitare loop Stop (`stop_hook_active`).
Si limita a suggerire l'azione nel reminder finale.

Input (stdin, JSON):
  {
    "session_id": "...",
    "stop_hook_active": bool,
    ...
  }
#>

$ErrorActionPreference = 'Continue'

try {
    $raw = [Console]::In.ReadToEnd()
    $payload = $null
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        $payload = $raw | ConvertFrom-Json
    }

    # Evita loop: se siamo gia' in uno stop hook attivo, non reiterare.
    if ($payload -and $payload.stop_hook_active) { exit 0 }

    $root = & git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) { exit 0 }
    Set-Location $root

    # Conta commit non ancora riflessi in IMPLEMENTATION_HISTORY.md (confronto con l'ultima data presente).
    $historyPath = Join-Path $root 'IMPLEMENTATION_HISTORY.md'
    $touched = $false
    $reasons = New-Object System.Collections.Generic.List[string]

    if (Test-Path $historyPath) {
        $content = Get-Content -Raw -Path $historyPath
        # Ultima data sessione: pattern "## Sessione YYYY-MM-DD"
        $match = [regex]::Matches($content, '##\s+Sessione\s+(\d{4}-\d{2}-\d{2})')
        if ($match.Count -gt 0) {
            $lastDate = $match[$match.Count - 1].Groups[1].Value
            $since = "$lastDate 00:00:00"
            $log = & git log --since="$since" --pretty=format:"%h %s" 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($log)) {
                $count = ($log -split "`n").Length
                if ($count -gt 0) {
                    $reasons.Add("$count commit dopo l'ultima voce IMPLEMENTATION_HISTORY.md")
                    $touched = $true
                }
            }
        }
    }

    # File modificati/staged che matchano pattern feature/translations/workflow.
    $statusPorcelain = & git status --porcelain 2>$null
    if ($LASTEXITCODE -eq 0 -and $statusPorcelain) {
        $patterns = @('lib/features/', 'assets/translations/', '.github/workflows/')
        $hits = @()
        foreach ($line in ($statusPorcelain -split "`n")) {
            $path = $line.Substring(3).Trim()
            foreach ($p in $patterns) {
                if ($path -like "$p*") { $hits += $path; break }
            }
        }
        if ($hits.Count -gt 0) {
            $reasons.Add("modifiche uncommitted in: " + (($hits | Select-Object -Unique | Select-Object -First 5) -join ', '))
            $touched = $true
        }
    }

    if ($touched) {
        $ctx = "Prima di chiudere la sessione: esegui la skill 'session-wrap' per aggiornare IMPLEMENTATION_HISTORY.md" +
               " e (se toccati lib/features/*/presentation/pages o assets/translations) USER_FEATURES.md.`n" +
               "Motivi: " + ($reasons -join '; ')
        $out = @{
            hookSpecificOutput = @{
                hookEventName     = 'Stop'
                additionalContext = $ctx
            }
        } | ConvertTo-Json -Compress -Depth 4
        Write-Output $out
    }

    exit 0
}
catch {
    [Console]::Error.WriteLine("stop-wrap hook error: $($_.Exception.Message)")
    exit 0
}
