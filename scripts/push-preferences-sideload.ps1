[CmdletBinding()]
param(
    [string]$Target = "ableton@push",
    [string]$ServiceTarget = "root@push",
    [string]$LocalCfg = "reverse-engineering\preferences-config\p3sa\in-all-enabled.cfg",
    [string]$RemotePreferencesPath = "",
    [switch]$VerifyOnly,
    [switch]$DeleteRemotePreferences
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-RepoPath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
    return [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
}

function ConvertTo-ShSingleQuoted {
    param([string]$Value)
    return "'" + $Value.Replace("'", "'`"'`"'") + "'"
}

function Invoke-PushSh {
    param(
        [string]$ScriptBody,
        [string]$RemoteTarget = $Target
    )

    $remoteScript = @"
set -eu
PATH=/usr/sbin:/sbin:/usr/bin:/bin
$ScriptBody
"@

    $remoteScript = $remoteScript -replace "`r`n", "`n"
    $remoteScriptBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($remoteScript))
    $sshArgs = @(
        "-o", "StrictHostKeyChecking=no",
        "-o", "LogLevel=ERROR",
        $RemoteTarget,
        "printf '%s' '$remoteScriptBase64' | base64 -d | sh"
    )

    $oldErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = & ssh.exe @sshArgs 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $oldErrorActionPreference
    }

    if ($exitCode -ne 0) {
        throw ("ssh.exe failed with exit code {0}: {1}" -f $exitCode, ($output -join "`n"))
    }

    return $output
}

function Stop-PushService {
    Write-Host "Stopping push3 service via /etc/init.d/push3 stop"
    Invoke-PushSh -RemoteTarget $ServiceTarget -ScriptBody "/etc/init.d/push3 stop || true"
}

function Start-PushService {
    Write-Host "Starting push3 service via /etc/init.d/push3 start"
    Invoke-PushSh -RemoteTarget $ServiceTarget -ScriptBody "/etc/init.d/push3 start"
}

function Add-ByteWithWrap {
    param(
        [byte]$Value,
        [int]$Delta
    )

    return [byte](($Value + $Delta) -band 0xff)
}

function Save-RemoteFileFromBase64 {
    param(
        [string]$RemotePath,
        [string]$LocalPath
    )

    $remotePathQ = ConvertTo-ShSingleQuoted $RemotePath
    $base64 = Invoke-PushSh @"
remote_path=$remotePathQ
if [ ! -f "`$remote_path" ]; then
  echo "Remote file not found: `$remote_path" >&2
  exit 1
fi
base64 "`$remote_path"
"@

    $base64Text = (($base64 -join "") -replace "\s", "")
    [System.IO.File]::WriteAllBytes($LocalPath, [Convert]::FromBase64String($base64Text))
}

function Copy-ByteRange {
    param(
        [byte[]]$Source,
        [byte[]]$Destination,
        [int]$Offset,
        [int]$Length
    )

    for ($i = 0; $i -lt $Length; $i++) {
        $Destination[$Offset + $i] = $Source[$Offset + $i]
    }
}
function New-AudioChannelStatePatch {
    param([string]$SourcePath)

    $audioStateOffset = 0x55EB
    $audioStateLength = 0x2E6
    $sourceBytes = [System.IO.File]::ReadAllBytes($SourcePath)
    if ($sourceBytes.Length -lt ($audioStateOffset + $audioStateLength)) {
        throw "Cfg is too short for known Push 3 audio-channel state range: $SourcePath"
    }

    $patchBytes = [byte[]]::new($audioStateLength)
    [Array]::Copy($sourceBytes, $audioStateOffset, $patchBytes, 0, $audioStateLength)

    $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ("push-dev-p3sa-audio-channel-state-{0}.bin" -f ([Guid]::NewGuid().ToString("N")))
    [System.IO.File]::WriteAllBytes($tempPath, $patchBytes)

    return [pscustomobject]@{
        Path = $tempPath
        Offset = $audioStateOffset
        Length = $audioStateLength
        Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $tempPath).Hash.ToLowerInvariant()
    }
}

function New-PatchedAudioChannelCfg {
    param(
        [string]$BasePath,
        [string]$DesiredStatePath
    )

    $offsets = @{
        SaveCounter        = 0x58D0
        AudioRecord        = 0x55EB
    }

    $baseBytes = [System.IO.File]::ReadAllBytes($BasePath)
    $desiredBytes = [System.IO.File]::ReadAllBytes($DesiredStatePath)
    $audioRecordLength = $offsets.SaveCounter - $offsets.AudioRecord
    $maxOffset = $offsets.SaveCounter + 1
    if ($baseBytes.Length -lt $maxOffset) {
        throw "Remote base cfg is too short for known Push 3 audio-channel offsets: $BasePath"
    }
    if ($desiredBytes.Length -lt $maxOffset) {
        throw "Desired-state cfg is too short for known Push 3 audio-channel offsets: $DesiredStatePath"
    }

    Copy-ByteRange -Source $desiredBytes -Destination $baseBytes -Offset $offsets.AudioRecord -Length $audioRecordLength

    $baseBytes[$offsets.SaveCounter] = Add-ByteWithWrap -Value $baseBytes[$offsets.SaveCounter] -Delta 1

    $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ("push-dev-p3sa-preferences-{0}.cfg" -f ([Guid]::NewGuid().ToString("N")))
    [System.IO.File]::WriteAllBytes($tempPath, $baseBytes)

    Write-Host "Copied audio-channel record from local cfg into current remote cfg"
    Write-Host "Preserved audio-channel record metadata from local cfg; advanced current remote save counter: 0x58D0 += 1"

    return $tempPath
}

function Get-RemotePreferencesPath {
    if (-not [string]::IsNullOrWhiteSpace($RemotePreferencesPath)) {
        return $RemotePreferencesPath
    }

    $path = Invoke-PushSh @"
pref_file="`$(ls -1dt /data/.config/Ableton/Live*/Preferences.cfg 2>/dev/null | sed -n '1p')"
if [ -n "`$pref_file" ]; then
  printf '%s\n' "`$pref_file"
  exit 0
fi
pref_dir="`$(ls -1dt /data/.config/Ableton/Live*/Preferences 2>/dev/null | sed -n '1p')"
if [ -n "`$pref_dir" ]; then
  printf '%s/Preferences.cfg\n' "`$pref_dir"
  exit 0
fi
echo "Could not find /data/.config/Ableton/Live*/Preferences.cfg" >&2
exit 1
"@

    return (($path | Select-Object -First 1) -as [string]).Trim()
}

$localCfgPath = Resolve-RepoPath $LocalCfg
if (-not $DeleteRemotePreferences -and -not (Test-Path -LiteralPath $localCfgPath -PathType Leaf)) {
    throw "Local cfg file does not exist: $localCfgPath"
}

$remoteCfgPath = Get-RemotePreferencesPath
if ([string]::IsNullOrWhiteSpace($remoteCfgPath)) {
    throw "Remote Preferences.cfg path discovery returned an empty path"
}

$remoteTmpPath = "/tmp/push-dev-audio-channel-state.bin"
$remoteCfgQ = ConvertTo-ShSingleQuoted $remoteCfgPath
$remoteTmpQ = ConvertTo-ShSingleQuoted $remoteTmpPath

if ($DeleteRemotePreferences) {
    Write-Host "Remote cfg: $remoteCfgPath"
    Stop-PushService
    Invoke-PushSh @"
remote_cfg=$remoteCfgQ
if [ -f "`$remote_cfg" ]; then
  backup_path="`$remote_cfg.push-dev-delete-backup.`$(date +%Y%m%d-%H%M%S)"
  cp -p "`$remote_cfg" "`$backup_path"
  rm "`$remote_cfg"
  sync
  printf 'Deleted remote Preferences.cfg. Backup cfg: %s\n' "`$backup_path"
else
  echo 'Remote Preferences.cfg already absent.'
fi
"@
    Start-PushService
    Write-Host "Live should regenerate Preferences.cfg after the Push service starts. Reboot if it does not."
    exit 0
}

$audioStatePatch = New-AudioChannelStatePatch -SourcePath $localCfgPath
$patchOffset = $audioStatePatch.Offset
$patchLength = $audioStatePatch.Length
$patchHash = $audioStatePatch.Hash

Write-Host "Local cfg:  $localCfgPath"
Write-Host "Patch bin:  $($audioStatePatch.Path)"
Write-Host ("Patch range: 0x{0:X}..0x{1:X} ({2} bytes)" -f $patchOffset, ($patchOffset + $patchLength - 1), $patchLength)
Write-Host "Patch sha:  $patchHash"
Write-Host "Remote cfg: $remoteCfgPath"

if ($VerifyOnly) {
    Invoke-PushSh @"
remote_cfg=$remoteCfgQ
if [ ! -f "`$remote_cfg" ]; then
  echo 'Remote Preferences.cfg not found' >&2
  exit 1
fi
remote_patch_sha="`$(dd if="`$remote_cfg" bs=1 skip=$patchOffset count=$patchLength 2>/dev/null | sha256sum | awk '{ print `$1 }')"
printf 'Remote size: '
wc -c < "`$remote_cfg"
printf 'Remote audio-channel state sha: %s\n' "`$remote_patch_sha"
printf 'Local  audio-channel state sha: %s\n' "$patchHash"
if [ "`$remote_patch_sha" != "$patchHash" ]; then
  echo 'Remote audio-channel state does not match local cfg template.' >&2
  exit 1
fi
"@
    exit 0
}

Stop-PushService

Write-Host "Uploading audio-channel state patch to ${Target}:$remoteTmpPath"
$oldErrorActionPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    $scpOutput = & scp.exe -q -o StrictHostKeyChecking=no -o LogLevel=ERROR $audioStatePatch.Path "${Target}:$remoteTmpPath" 2>&1
    $scpExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $oldErrorActionPreference
}

if ($scpExitCode -ne 0) {
    throw ("scp.exe failed with exit code {0}: {1}" -f $scpExitCode, ($scpOutput -join "`n"))
}

Invoke-PushSh @"
remote_cfg=$remoteCfgQ
remote_tmp=$remoteTmpQ
if [ ! -f "`$remote_tmp" ]; then
  echo 'Uploaded audio-channel state patch is missing' >&2
  exit 1
fi

remote_tmp_size="`$(wc -c < "`$remote_tmp")"
if [ "`$remote_tmp_size" != "$patchLength" ]; then
  echo "Patch size mismatch: `$remote_tmp_size != $patchLength" >&2
  exit 1
fi

remote_tmp_sha="`$(sha256sum "`$remote_tmp" | awk '{ print `$1 }')"
if [ "`$remote_tmp_sha" != "$patchHash" ]; then
  echo "Patch hash mismatch: `$remote_tmp_sha != $patchHash" >&2
  exit 1
fi

if [ ! -f "`$remote_cfg" ]; then
  echo 'Remote Preferences.cfg not found' >&2
  exit 1
fi

backup_path="`$remote_cfg.push-dev-backup.`$(date +%Y%m%d-%H%M%S)"
cp -p "`$remote_cfg" "`$backup_path"
printf 'Backup cfg: %s\n' "`$backup_path"

dd if="`$remote_tmp" of="`$remote_cfg" bs=1 seek=$patchOffset conv=notrunc 2>/dev/null
sync

remote_patch_sha="`$(dd if="`$remote_cfg" bs=1 skip=$patchOffset count=$patchLength 2>/dev/null | sha256sum | awk '{ print `$1 }')"
if [ "`$remote_patch_sha" != "$patchHash" ]; then
  echo "Installed range hash mismatch: `$remote_patch_sha != $patchHash" >&2
  exit 1
fi

printf 'Installed size: '
wc -c < "`$remote_cfg"
printf 'Installed audio-channel state sha: %s\n' "`$remote_patch_sha"
"@

Write-Host ""
Write-Host "Audio-channel state patch installed."
Start-PushService
Write-Host "After Live starts, run this script with -VerifyOnly."
Write-Host "If Live rejects the file, run this script with -DeleteRemotePreferences."