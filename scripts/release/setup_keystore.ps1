# setup_keystore.ps1
# Generates the Android upload keystore for Portfolio Manager (PluriFin).
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\release\setup_keystore.ps1
#
# Behavior:
#   - Generates an RSA 4096 bit keypair valid for 10000 days under
#     ~\.plurifin\keys\upload-keystore.jks (outside the repo, profile-scoped).
#   - Writes android\key.properties wiring the keystore into Gradle.
#   - Both files are gitignored. The script never echoes passwords back.
#
# After running:
#   1) Back up upload-keystore.jks to: 1Password/Bitwarden vault, USB-1, USB-2, paper printout of fingerprint.
#   2) Back up the password to a SEPARATE vault entry (never alongside the .jks file).
#   3) Verify the keystore can sign with: keytool -list -v -keystore <path>
#
# Recovery: losing the upload key permanently locks you out of submitting
# updates to this Play Store listing (Google does not transfer signing keys
# in v1.0; recovery requires Play App Signing migration ticket which can
# take weeks). Treat the .jks file as a master credential.
#
# ASCII-only by design. Windows PowerShell 5.1 reads .ps1 as Windows-1252
# without BOM; non-ASCII characters break the parser.

[CmdletBinding()]
param(
    [string]$KeyAlias = "upload",
    [int]$ValidityDays = 10000,
    [int]$KeySize = 4096,
    [string]$OutputDir = (Join-Path $env:USERPROFILE ".plurifin\keys")
)

$ErrorActionPreference = "Stop"

function Write-Section($Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Resolve-Keytool {
    $cmd = Get-Command keytool -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    if ($env:JAVA_HOME) {
        $candidate = Join-Path $env:JAVA_HOME "bin\keytool.exe"
        if (Test-Path $candidate) { return $candidate }
    }

    throw "keytool not found. Install a JDK and ensure JAVA_HOME is set or keytool is on PATH."
}

function Read-Secret($Prompt) {
    $secure = Read-Host -AsSecureString -Prompt $Prompt
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

# ---- Pre-flight ----
Write-Section "Pre-flight"
$keytool = Resolve-Keytool
Write-Host "Using keytool: $keytool"

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$keystorePath = Join-Path $OutputDir "upload-keystore.jks"
if (Test-Path $keystorePath) {
    Write-Host "Existing keystore detected at: $keystorePath" -ForegroundColor Yellow
    $reply = Read-Host "Overwrite? Type 'yes' to replace, anything else to abort"
    if ($reply -ne "yes") {
        Write-Host "Aborted. Existing keystore preserved." -ForegroundColor Yellow
        exit 1
    }
    Remove-Item $keystorePath -Force
}

# ---- Distinguished Name ----
Write-Section "Owner identity"
$ownerName = Read-Host "Owner CN (e.g. Filippo Salemi)"
$ownerOrgUnit = Read-Host "Organizational Unit (e.g. PluriFin)"
$ownerOrg = Read-Host "Organization (e.g. PluriFin)"
$ownerLocality = Read-Host "City"
$ownerState = Read-Host "State/Province"
$ownerCountry = Read-Host "Country code (ISO 3166, e.g. IT)"

$dname = "CN=$ownerName, OU=$ownerOrgUnit, O=$ownerOrg, L=$ownerLocality, ST=$ownerState, C=$ownerCountry"

# ---- Passphrase ----
Write-Section "Passphrase"
Write-Host "Choose a passphrase 16+ characters with letters, numbers, symbols."
$pass1 = Read-Secret "Passphrase"
$pass2 = Read-Secret "Confirm passphrase"
if ($pass1 -ne $pass2) {
    throw "Passphrase mismatch. Aborting."
}
if ($pass1.Length -lt 12) {
    throw "Passphrase must be at least 12 characters."
}

# ---- Generate ----
Write-Section "Generating keystore (this takes a few seconds)"
$args = @(
    "-genkeypair",
    "-v",
    "-keystore", $keystorePath,
    "-keyalg", "RSA",
    "-keysize", $KeySize,
    "-validity", $ValidityDays,
    "-alias", $KeyAlias,
    "-dname", $dname,
    "-storepass", $pass1,
    "-keypass", $pass1
)

& $keytool @args
if ($LASTEXITCODE -ne 0) {
    throw "keytool failed with exit code $LASTEXITCODE."
}

# ---- key.properties ----
Write-Section "Wiring Gradle (android/key.properties)"
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$keyPropsPath = Join-Path $repoRoot "android\key.properties"

# Forward slashes for Gradle Kotlin DSL compatibility.
$storeFileForGradle = $keystorePath -replace '\\', '/'

$content = @"
storeFile=$storeFileForGradle
storePassword=$pass1
keyAlias=$KeyAlias
keyPassword=$pass1
"@

Set-Content -Path $keyPropsPath -Value $content -Encoding ASCII -NoNewline

Write-Section "Done"
Write-Host "Keystore: $keystorePath"
Write-Host "Gradle wiring: $keyPropsPath"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1) Verify: keytool -list -v -keystore '$keystorePath'"
Write-Host "  2) Back up the .jks file to AT LEAST 4 separate locations:"
Write-Host "     - encrypted USB stick #1 (offline drawer)"
Write-Host "     - encrypted USB stick #2 (different physical location)"
Write-Host "     - 1Password/Bitwarden secure attachment"
Write-Host "     - paper printout of SHA-256 fingerprint (recovery sanity check)"
Write-Host "  3) Back up the passphrase in a SEPARATE vault entry."
Write-Host "  4) Never commit android/key.properties or the .jks file to git."
Write-Host ""

# Clear secrets from memory.
$pass1 = $null
$pass2 = $null
[System.GC]::Collect()
