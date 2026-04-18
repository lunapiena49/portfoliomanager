#Requires -Version 5.1
<#
PreToolUse hook -- blocca comandi Bash che usano binari "filtrati" da RTK senza il prefisso `rtk`.
RTK (Rust Token Killer) e' un wrapper installato globalmente che taglia l'output token-heavy.

Input (stdin, JSON):
  {
    "tool_name": "Bash",
    "tool_input": { "command": "...", "description": "..." }
  }

Output (stdout, JSON):
  { "decision": "block", "reason": "..." }  -> blocca l'esecuzione
  (vuoto)                                    -> consente l'esecuzione

Whitelist eccezioni: comandi "puri" di flutter che non beneficiano di rtk
  (flutter analyze, flutter test, flutter pub get, flutter doctor, flutter devices)
  sono gia' in permissions.allow e vanno lasciati passare se usati diretti.
#>

$ErrorActionPreference = 'Stop'

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }

    $payload = $raw | ConvertFrom-Json
    if ($payload.tool_name -ne 'Bash') { exit 0 }

    $command = [string]$payload.tool_input.command
    if ([string]::IsNullOrWhiteSpace($command)) { exit 0 }

    # Comandi "filtrati" che DEVONO passare via rtk per risparmio token.
    $filtered = @(
        'git', 'gh', 'flutter', 'dart', 'cargo',
        'pnpm', 'npm', 'npx', 'pip', 'python',
        'ls', 'grep', 'find', 'docker', 'kubectl', 'curl', 'wget'
    )

    # Comandi "plain" che sono ammessi direttamente (passthrough in allow-list di settings).
    # Questi restano efficienti anche senza rtk -- gli hook non li bloccano.
    $plainAllowed = @(
        'flutter analyze',
        'flutter test',
        'flutter pub get',
        'flutter pub run',
        'flutter doctor',
        'flutter devices'
    )

    # Split su && / ; / | per ispezionare ogni segmento.
    $segments = [regex]::Split($command, '\s*(?:&&|\|\||;|\|)\s*') | Where-Object { $_ -ne '' }

    foreach ($seg in $segments) {
        $trim = $seg.Trim()
        if ($trim -eq '') { continue }

        # Salta segmenti "cd X" o assignment VAR=value.
        if ($trim -match '^(cd|export|set)\s') { continue }
        if ($trim -match '^\w+=') { continue }

        # Plain allowed: skip check.
        $isPlainAllowed = $false
        foreach ($ok in $plainAllowed) {
            if ($trim -eq $ok -or $trim.StartsWith("$ok ")) { $isPlainAllowed = $true; break }
        }
        if ($isPlainAllowed) { continue }

        # Estrai primo token del segmento.
        $tokens = $trim -split '\s+'
        $first = $tokens[0]

        # Se e' rtk, ok.
        if ($first -eq 'rtk') { continue }

        # Se e' powershell/pwsh (wrapper legittimo per script), ok.
        if ($first -match '^(powershell|pwsh|cmd)$') { continue }

        # Se e' un binario filtrato senza rtk -> blocca.
        if ($filtered -contains $first) {
            $suggestion = "rtk $trim"
            $reason = "Comando '$first' va prefissato con 'rtk' per risparmio token (vedi CLAUDE.md §3). Sostituisci con: $suggestion"
            $out = @{ decision = 'block'; reason = $reason } | ConvertTo-Json -Compress
            Write-Output $out
            exit 0
        }
    }

    exit 0
}
catch {
    # Non bloccare per errori interni dell'hook.
    $msg = "rtk-rewrite hook error: $($_.Exception.Message)"
    [Console]::Error.WriteLine($msg)
    exit 0
}
