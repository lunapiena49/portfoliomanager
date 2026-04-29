# build_repo_split.ps1 -- materialize the two-repo split into ./repo_split/.
#
# Source: this monorepo (the working tree at git rev-parse --show-toplevel).
# Destination:
#   repo_split/app/   -- private repo "portfolio-manager-app"
#   repo_split/data/  -- public repo  "portfoliomanager-data"
#
# The output cleanly separates concerns:
#   * app/   -> Flutter sources, lib/, android/, ios/, test/, plus its own
#               README + .gitignore. Excludes anything market-data related.
#   * data/  -> Python pipeline (scripts/eodhd/), market-data workflows,
#               docs/DATA_SNAPSHOT_LOG.md, dist/market-data/.gitkeep, plus
#               its own README + .gitignore. Excludes app sources.
#
# Idempotent: existing repo_split/ is wiped before regeneration.
# Templates live next to this script under repo_split_templates/.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/release/build_repo_split.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/release/build_repo_split.ps1 -KeepGitHistory
#
# -KeepGitHistory: NOT IMPLEMENTED in v1.0. The split repos start with a
# clean history; the old monorepo history is intentionally not carried over.
# When phase 2 needs partial history-preserving extraction, use
# git-filter-repo with --paths-from-file (see scripts/security/filter_repo*).

param(
    [switch]$KeepGitHistory
)

$ErrorActionPreference = "Stop"

if ($KeepGitHistory) {
    Write-Host "[repo-split] -KeepGitHistory not implemented in v1.0; aborting." -ForegroundColor Red
    exit 2
}

$repoRoot = git rev-parse --show-toplevel
if (-not $repoRoot) {
    Write-Host "[repo-split] not inside a git repo." -ForegroundColor Red
    exit 1
}

Push-Location $repoRoot
try {
    $stagingRoot = Join-Path $repoRoot "repo_split"
    $appOut = Join-Path $stagingRoot "app"
    $dataOut = Join-Path $stagingRoot "data"
    $tmplRoot = Join-Path $repoRoot "scripts/release/repo_split_templates"

    if (Test-Path $stagingRoot) {
        Write-Host "[repo-split] cleaning existing $stagingRoot..." -ForegroundColor Yellow
        Remove-Item -Path $stagingRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $appOut -Force | Out-Null
    New-Item -ItemType Directory -Path $dataOut -Force | Out-Null

    # ---------------------------------------------------------------- APP repo
    Write-Host "[repo-split] populating $appOut ..." -ForegroundColor Cyan

    # Top-level files to copy into the private repo
    $appFiles = @(
        "CLAUDE.md",
        "QUICK_START.md",
        "USER_FEATURES.md",
        "IMPLEMENTATION_HISTORY.md",
        "LICENSE",
        "analysis_options.yaml",
        "pubspec.yaml",
        "pubspec.lock",
        ".gitleaks.toml",
        "formati_brokers.md",
        "flutter_workflow.md"
    )
    foreach ($f in $appFiles) {
        $src = Join-Path $repoRoot $f
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination (Join-Path $appOut $f) -Force
        }
    }

    # Top-level directories carried over verbatim
    $appDirs = @(
        "lib",
        "test",
        "android",
        "ios",
        "linux",
        "macos",
        "windows",
        "web",
        "assets",
        ".githooks"
    )
    foreach ($d in $appDirs) {
        $src = Join-Path $repoRoot $d
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination (Join-Path $appOut $d) -Recurse -Force
        }
    }

    # scripts/: keep release + security; drop eodhd (data-repo only).
    $appScriptsOut = Join-Path $appOut "scripts"
    New-Item -ItemType Directory -Path $appScriptsOut -Force | Out-Null
    foreach ($subdir in @("release", "security")) {
        $src = Join-Path $repoRoot "scripts/$subdir"
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination (Join-Path $appScriptsOut $subdir) -Recurse -Force
        }
    }
    # cleanup_orphan_i18n.py is project-wide and stays with the app.
    $orphanScript = Join-Path $repoRoot "scripts/cleanup_orphan_i18n.py"
    if (Test-Path $orphanScript) {
        Copy-Item -Path $orphanScript -Destination (Join-Path $appScriptsOut "cleanup_orphan_i18n.py") -Force
    }

    # .github/workflows/: drop market-data + daily-data; keep release.yml etc.
    # (release.yml will be added in S9 -- for now copy whatever else exists.)
    $appWorkflowsOut = Join-Path $appOut ".github/workflows"
    New-Item -ItemType Directory -Path $appWorkflowsOut -Force | Out-Null
    Get-ChildItem -Path (Join-Path $repoRoot ".github/workflows") -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -notin @("market-data-snapshot.yml", "daily-data-commit.yml")
        } |
        ForEach-Object {
            Copy-Item -Path $_.FullName -Destination (Join-Path $appWorkflowsOut $_.Name) -Force
        }

    # docs/: skip DATA_SNAPSHOT_LOG (lives in data repo). Keep planning docs.
    $appDocsOut = Join-Path $appOut "docs"
    if (Test-Path (Join-Path $repoRoot "docs")) {
        New-Item -ItemType Directory -Path $appDocsOut -Force | Out-Null
        Get-ChildItem -Path (Join-Path $repoRoot "docs") -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne "DATA_SNAPSHOT_LOG.md" } |
            ForEach-Object {
                Copy-Item -Path $_.FullName -Destination (Join-Path $appDocsOut $_.Name) -Force
            }
        # Carry archived snapshots if present (read-only history reference)
        $archive = Join-Path $repoRoot "docs/archive"
        if (Test-Path $archive) {
            Copy-Item -Path $archive -Destination (Join-Path $appDocsOut "archive") -Recurse -Force
        }
    }

    # README + .gitignore from templates (overrides any copied ones).
    Copy-Item -Path (Join-Path $tmplRoot "app/README.md") `
              -Destination (Join-Path $appOut "README.md") -Force
    Copy-Item -Path (Join-Path $tmplRoot "app/.gitignore") `
              -Destination (Join-Path $appOut ".gitignore") -Force

    # ---------------------------------------------------------------- DATA repo
    Write-Host "[repo-split] populating $dataOut ..." -ForegroundColor Cyan

    # Pipeline source
    $eodhd = Join-Path $repoRoot "scripts/eodhd"
    if (Test-Path $eodhd) {
        $dataScriptsOut = Join-Path $dataOut "scripts"
        New-Item -ItemType Directory -Path $dataScriptsOut -Force | Out-Null
        Copy-Item -Path $eodhd -Destination (Join-Path $dataScriptsOut "eodhd") -Recurse -Force
    }

    # Workflows: only market-data + daily-data
    $dataWorkflowsOut = Join-Path $dataOut ".github/workflows"
    New-Item -ItemType Directory -Path $dataWorkflowsOut -Force | Out-Null
    foreach ($wf in @("market-data-snapshot.yml", "daily-data-commit.yml")) {
        $src = Join-Path $repoRoot ".github/workflows/$wf"
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination (Join-Path $dataWorkflowsOut $wf) -Force
        }
    }

    # docs: only DATA_SNAPSHOT_LOG.md
    $dataDocsOut = Join-Path $dataOut "docs"
    New-Item -ItemType Directory -Path $dataDocsOut -Force | Out-Null
    $log = Join-Path $repoRoot "docs/DATA_SNAPSHOT_LOG.md"
    if (Test-Path $log) {
        Copy-Item -Path $log -Destination (Join-Path $dataDocsOut "DATA_SNAPSHOT_LOG.md") -Force
    }

    # dist/market-data/.gitkeep + (if present) the published top_movers.json
    $marketOut = Join-Path $dataOut "dist/market-data"
    New-Item -ItemType Directory -Path $marketOut -Force | Out-Null
    "" | Set-Content -Path (Join-Path $marketOut ".gitkeep") -Encoding utf8 -NoNewline
    $movers = Join-Path $repoRoot "dist/market-data/top_movers.json"
    if (Test-Path $movers) {
        Copy-Item -Path $movers -Destination (Join-Path $marketOut "top_movers.json") -Force
    }

    # README + .gitignore from templates
    Copy-Item -Path (Join-Path $tmplRoot "data/README.md") `
              -Destination (Join-Path $dataOut "README.md") -Force
    Copy-Item -Path (Join-Path $tmplRoot "data/.gitignore") `
              -Destination (Join-Path $dataOut ".gitignore") -Force

    # ----------------------------------------------------------------- Summary
    Write-Host ""
    Write-Host "[repo-split] DONE" -ForegroundColor Green
    Write-Host "  app/  -> $appOut"
    Write-Host "  data/ -> $dataOut"
    Write-Host ""
    Write-Host "Next steps (manual, S10 of the master plan):"
    Write-Host "  cd repo_split/app  && git init && git add . && git commit -m 'initial import'"
    Write-Host "  cd repo_split/data && git init && git add . && git commit -m 'initial import'"
    Write-Host "  Then push each to its respective remote (see plan S10)."
} finally {
    Pop-Location
}
