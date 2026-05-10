[CmdletBinding()]
param(
    [string]$Target = "root@push",
    [string]$DocPath = "",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($DocPath)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $DocPath = Join-Path $scriptDir '..\docs\AbletonOS-toolset.md'
}

function Remove-SshNoise {
    param([string[]]$Lines)

    $result = New-Object System.Collections.Generic.List[string]
    $skipWarningBlock = $false

    foreach ($line in $Lines) {
        if ($null -eq $line) {
            continue
        }

        if ($line -match '^@{10,}$') {
            $skipWarningBlock = -not $skipWarningBlock
            continue
        }

        if ($skipWarningBlock) {
            continue
        }

        if ($line -match '^(Offending ECDSA key|Password authentication is disabled|Keyboard-interactive authentication is disabled|UpdateHostkeys is disabled because the host key is not trusted\.)') {
            continue
        }

        $result.Add($line)
    }

    return $result
}

function Invoke-RemoteScript {
    param([string]$ScriptBody)

    $remoteScript = @"
set +e
PATH=/usr/sbin:/sbin:/usr/bin:/bin
$ScriptBody
"@

    $remoteScriptBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($remoteScript))

    $sshArgs = @(
        '-o', 'StrictHostKeyChecking=no',
        '-o', 'LogLevel=ERROR',
        '-o', 'UserKnownHostsFile=NUL',
        '-o', 'GlobalKnownHostsFile=NUL',
        $Target,
        "printf '%s' '$remoteScriptBase64' | base64 -d | sh 2>&1"
    )

    $output = & ssh.exe @sshArgs 2>&1

    $clean = Remove-SshNoise -Lines @($output | ForEach-Object { "$_" })
    return ($clean -join "`n").Trim()
}

function Get-RemoteFirstLine {
    param([string]$ScriptBody)

    $text = Invoke-RemoteScript $ScriptBody
    if ([string]::IsNullOrWhiteSpace($text)) {
        return ""
    }

    return ($text -split "`r?`n" | Select-Object -First 1).Trim()
}

function Test-RemoteCommand {
    param([string]$CommandName)

    return -not [string]::IsNullOrWhiteSpace((Get-RemoteFirstLine "command -v '$CommandName' 2>/dev/null || true"))
}

function Test-RemotePath {
    param([string]$Path)

    $escaped = $Path.Replace("'", "'\''")
    $result = Get-RemoteFirstLine "[ -e '$escaped' ] && echo yes || true"
    return $result -eq "yes"
}

function Find-RemoteFirst {
    param([string]$FindExpression)

    return Get-RemoteFirstLine "find $FindExpression 2>/dev/null | sed -n '1p'"
}

function Normalize-Whitespace {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    return ([regex]::Replace($Text.Trim(), '\s+', ' '))
}

function Convert-FromBase64Utf8 {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    try {
        $bytes = [Convert]::FromBase64String((Normalize-Whitespace $Text))
        return [System.Text.Encoding]::UTF8.GetString($bytes)
    } catch {
        return ""
    }
}

function Normalize-BannerText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $normalized = $Text -replace "`r", ""
    return $normalized.Trim("`n")
}

function Get-Basename {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }

    return [System.IO.Path]::GetFileName($Path.TrimEnd([char[]]@('/','\')))
}

function Normalize-Coreutils {
    param([string]$Line)

    if ($Line -match '\((GNU coreutils)\)\s+([0-9.]+)') {
        return "$($Matches[1]) $($Matches[2])"
    }

    return $Line
}

function Normalize-Findutils {
    param([string]$Line)

    if ($Line -match '\((GNU findutils)\)\s+([0-9.]+)') {
        return "$($Matches[1]) $($Matches[2])"
    }

    return $Line
}

function Normalize-Grep {
    param([string]$Line)

    if ($Line -match '\((GNU grep)\)\s+([0-9.]+)') {
        return "$($Matches[1]) $($Matches[2])"
    }

    return $Line
}

function Normalize-Gawk {
    param([string]$Line)

    if ($Line -match '^(GNU Awk\s+[0-9.]+)') {
        return $Matches[1]
    }

    return $Line
}

function Normalize-Sed {
    param([string]$Line)

    if ($Line -match '\((GNU sed)\)\s+([0-9.]+)') {
        return "$($Matches[1]) $($Matches[2])"
    }

    return $Line
}

function Normalize-Bash {
    param([string]$Line)

    if ($Line -match '^GNU bash,\s+version\s+([0-9.()A-Za-z-]+)') {
        return "GNU bash $($Matches[1])"
    }

    return $Line
}

function Normalize-AlsaTool {
    param([string]$Line)

    if ($Line -match 'version\s+([0-9.]+)') {
        return "alsa-utils $($Matches[1])"
    }

    if ($Line -match '^speaker-test\s+([0-9.]+)') {
        return "alsa-utils $($Matches[1])"
    }

    return $Line
}

function Normalize-Dmesg {
    param([string]$Line)

    if ($Line -match 'util-linux\s+([0-9.]+)') {
        return "util-linux $($Matches[1])"
    }

    return $Line
}

function Normalize-Kmod {
    param([string]$Line)

    if ($Line -match '^kmod version\s+([0-9.]+)') {
        return "kmod $($Matches[1])"
    }

    return $Line
}

function Normalize-Lsusb {
    param([string]$Line)

    if ($Line -match '\((usbutils)\)\s+([0-9A-Za-z.]+)') {
        return "$($Matches[1]) $($Matches[2])"
    }

    return $Line
}

function Normalize-Ip {
    param([string]$Line)

    if ($Line -match '(iproute2-[0-9.]+)') {
        return $Matches[1]
    }

    return $Line
}

function Normalize-Rsync {
    param([string]$Line)

    if ($Line -match 'version\s+([0-9.]+)\s+protocol version\s+([0-9]+)') {
        return "$($Matches[1]) (protocol $($Matches[2]))"
    }

    return $Line
}

function Normalize-Strace {
    param([string]$Line)

    if ($Line -match 'version\s+([0-9.]+)') {
        return $Matches[1]
    }

    return $Line
}

function Normalize-SshVersion {
    param([string]$Line)

    if ($Line -match '(OpenSSH_[0-9A-Za-z.p]+(?:,\s*OpenSSL\s+[0-9A-Za-z.\s]+)?)') {
        return $Matches[1].Trim()
    }

    return $Line
}

function Split-MarkdownRow {
    param([string]$Line)

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return @()
    }

    return (($Line.Trim() -replace '^\|', '' -replace '\|$', '') -split '\|') | ForEach-Object { $_.Trim() }
}

function Get-MarkdownTableSections {
    param(
        [string]$Content,
        [string]$StartHeading,
        [string]$EndHeading
    )

    $lines = $Content -split "`r?`n"
    $startIndex = [Array]::IndexOf($lines, $StartHeading)
    $endIndex = [Array]::IndexOf($lines, $EndHeading)

    if ($startIndex -lt 0 -or $endIndex -lt 0 -or $endIndex -le $startIndex) {
        throw "Could not locate section range: $StartHeading -> $EndHeading"
    }

    $sections = @()
    $currentHeading = ""
    $i = $startIndex + 1

    while ($i -lt $endIndex) {
        $line = $lines[$i]

        if ($line -match '^###\s+') {
            $currentHeading = $line.Trim()
            $i++
            continue
        }

        if ($currentHeading -and $line.Trim().StartsWith('|')) {
            $headers = Split-MarkdownRow $line
            $i += 2

            $rows = New-Object System.Collections.Generic.List[object]
            while ($i -lt $endIndex -and $lines[$i].Trim().StartsWith('|')) {
                $cells = Split-MarkdownRow $lines[$i]
                $rowMap = [ordered]@{}
                for ($cellIndex = 0; $cellIndex -lt $headers.Count; $cellIndex++) {
                    $rowMap[$headers[$cellIndex]] = if ($cellIndex -lt $cells.Count) { $cells[$cellIndex] } else { "" }
                }

                $rows.Add([pscustomobject]$rowMap)
                $i++
            }

            $sections += [pscustomobject]@{
                Heading = $currentHeading
                Headers = [string[]]$headers
                Rows    = $rows.ToArray()
            }

            continue
        }

        $i++
    }

    return $sections
}

function Invoke-RemoteProbeDefinitions {
    param([object[]]$Definitions)

    $results = @{}

    foreach ($definition in $Definitions) {
        switch ($definition.Mode) {
            'first-line' {
                $value = Get-RemoteFirstLine $definition.Command
            }
            'script' {
                $value = Invoke-RemoteScript $definition.Command
            }
            'path-exists' {
                $value = Test-RemotePath $definition.Path
            }
            'find-first' {
                $value = Find-RemoteFirst $definition.FindExpression
            }
            default {
                throw "Unsupported probe mode: $($definition.Mode)"
            }
        }

        if ($definition.Transform) {
            $value = & $definition.Transform $value
        }

        $results[$definition.Key] = $value
    }

    return $results
}

function Resolve-AvailableToolRow {
    param(
        [pscustomobject]$Row,
        [hashtable]$Shared
    )

    $tool = $Row.Tool
    $resolved = [ordered]@{
        Tool    = $tool
        Status  = $Row.Status
        Version = $Row.Version
        Notes   = $Row.Notes
    }

    switch ($tool) {
        '`ssh` server' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.SshdVersion
        }
        '`scp` server' {
            $resolved.Status = 'Available'
            $resolved.Version = if ($Shared.SshdVersion) { ($Shared.SshdVersion -split ',')[0] } else { 'N/A' }
        }
        '`rsync`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.RsyncVersion
        }
        '`sh`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.BashVersion
        }
        '`test`' {
            $resolved.Status = 'Available'
            $resolved.Version = 'Bash builtin'
        }
        '`mkdir`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.CoreutilsMkdir
        }
        '`printf`' {
            $resolved.Status = 'Available'
            $resolved.Version = 'Bash builtin'
        }
        '`cat`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.CoreutilsCat
        }
        '`ls`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.CoreutilsLs
        }
        '`find`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.FindutilsVersion
        }
        '`grep` / `egrep`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.GrepVersion
        }
        '`awk`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.GawkVersion
        }
        '`sed`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.SedVersion
        }
        '`head` / `tail`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.CoreutilsHead
        }
        '`wc`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.CoreutilsWc
        }
        '`sha256sum`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.CoreutilsSha
        }
        '`uname`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.CoreutilsUname
            $resolved.Notes = ('Used to confirm `{0}`.' -f $Shared.KernelRelease)
        }
        '`dmesg`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.DmesgVersion
        }
        '`lsmod`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.KmodVersion
        }
        '`insmod`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.KmodVersion
        }
        '`rmmod`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.KmodVersion
        }
        '`modinfo`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.KmodVersion
        }
        '`aplay`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.AlsaAplay
        }
        '`arecord`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.AlsaArecord
        }
        '`speaker-test`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.AlsaSpeakerTest
        }
        '`lsusb`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.LsusbVersion
        }
        '`lsusb -t`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.LsusbVersion
        }
        '`lsusb -v`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.LsusbVersion
        }
        '`ip`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.IpVersion
        }
        '`hostname`' {
            $resolved.Status = if ($Shared.HostnameIWorks) { 'Available' } else { 'Partially available' }
            $resolved.Version = $Shared.CoreutilsHostname
            $resolved.Notes = if ($Shared.HostnameIWorks) {
                'Worked, including `hostname -I`.'
            } else {
                'Worked, but `hostname -I` was not supported.'
            }
        }
        '`strace`' {
            $resolved.Status = 'Available'
            $resolved.Version = $Shared.StraceVersion
        }
        default {
            if ($tool -match '^`/proc/' -or $tool -match '^`/dev/snd/\*`$' -or $tool -match '^`/lib/modules/' ) {
                $resolved.Status = 'Available'
                $resolved.Version = 'N/A'
            }
        }
    }

    return [pscustomobject]$resolved
}

function Resolve-UnavailableToolRow {
    param(
        [pscustomobject]$Row,
        [hashtable]$Shared
    )

    $keyColumn = if ($Row.PSObject.Properties.Name -contains 'Tool / Artifact') { 'Tool / Artifact' } else { 'Module' }
    $label = $Row.$keyColumn
    $resolved = [ordered]@{}

    foreach ($property in $Row.PSObject.Properties.Name) {
        $resolved[$property] = $Row.$property
    }

    switch ($label) {
        '`gcc` / native compiler on Push' {
            $resolved.Status = if ($Shared.GccPath) { 'Present' } else { 'Not available for this project' }
            $resolved.Notes = if ($Shared.GccPath) {
                ('Observed at `{0}`; decide per project whether the shipped compiler is usable.' -f $Shared.GccPath)
            } else {
                'Push Standalone was treated as lacking a usable on-device compiler; builds are done externally.'
            }
        }
        'Kernel headers/build tree' {
            $resolved.Status = if ($Shared.KernelBuildExists) { 'Present' } else { 'Absent' }
            $resolved.Notes = if ($Shared.KernelBuildExists) {
                ('`/lib/modules/{0}/build` exists.' -f $Shared.KernelRelease)
            } else {
                ('`/lib/modules/{0}/build` was not present.' -f $Shared.KernelRelease)
            }
        }
        'Kernel source symlink/tree' {
            $resolved.Status = if ($Shared.KernelSourceExists) { 'Present' } else { 'Absent' }
            $resolved.Notes = if ($Shared.KernelSourceExists) {
                ('`/lib/modules/{0}/source` exists.' -f $Shared.KernelRelease)
            } else {
                ('`/lib/modules/{0}/source` was not present.' -f $Shared.KernelRelease)
            }
        }
        'Target `Module.symvers`' {
            $resolved.Status = if ($Shared.ModuleSymvers) { 'Found' } else { 'Not found' }
            $resolved.Notes = if ($Shared.ModuleSymvers) {
                ('First observed match: `{0}`.' -f $Shared.ModuleSymvers)
            } else {
                'Searches under `/lib/modules`, `/usr/src`, `/boot`, `/opt`, and `/data` did not find it.'
            }
        }
        '`/proc/config.gz`' {
            $resolved.Status = if ($Shared.ProcConfigExists) { 'Present' } else { 'Absent' }
            $resolved.Notes = if ($Shared.ProcConfigExists) {
                'Live kernel config was exposed there during inspection.'
            } else {
                'No live kernel config was exposed there during inspection.'
            }
        }
        '`/boot/config-*`' {
            $resolved.Status = if ($Shared.BootConfig) { 'Found' } else { 'Absent/not found' }
            $resolved.Notes = if ($Shared.BootConfig) {
                ('First observed match: `{0}`.' -f $Shared.BootConfig)
            } else {
                'No matching boot config was available in the expected locations.'
            }
        }
        '`snd-aloop`' {
            $resolved.Status = if ($Shared.SndAloop) { 'Present' } else { 'Absent' }
            $resolved.Notes = if ($Shared.SndAloop) {
                ('Observed module path: `{0}`.' -f $Shared.SndAloop)
            } else {
                'Not available as an easy virtual loopback-card route.'
            }
        }
        '`snd-dummy`' {
            $resolved.Status = if ($Shared.SndDummy) { 'Present' } else { 'Absent' }
            $resolved.Notes = if ($Shared.SndDummy) {
                ('Observed module path: `{0}`.' -f $Shared.SndDummy)
            } else {
                'Not available as an easy dummy-card route.'
            }
        }
    }

    return [pscustomobject]$resolved
}

function Format-MarkdownTable {
    param(
        [string[]]$Headers,
        [object[]]$Rows
    )

    $allRows = New-Object System.Collections.Generic.List[object[]]
    $allRows.Add($Headers)

    foreach ($row in $Rows) {
        $values = foreach ($header in $Headers) {
            $value = $row.$header
            if ($null -eq $value -or $value -eq "") {
                "N/A"
            } else {
                [string]$value
            }
        }

        $allRows.Add($values)
    }

    $widths = for ($i = 0; $i -lt $Headers.Count; $i++) {
        ($allRows | ForEach-Object { $_[$i].Length } | Measure-Object -Maximum).Maximum
    }

    $lines = New-Object System.Collections.Generic.List[string]

    $headerLine = "| " + (($Headers | ForEach-Object -Begin { $i = 0 } -Process {
        $text = $_.PadRight($widths[$i])
        $i++
        $text
    }) -join " | ") + " |"
    $lines.Add($headerLine)

    $dividerLine = "| " + (($widths | ForEach-Object { "-" * $_ }) -join " | ") + " |"
    $lines.Add($dividerLine)

    foreach ($row in $Rows) {
        $cells = foreach ($header in $Headers) {
            $value = $row.$header
            if ($null -eq $value -or $value -eq "") {
                $value = "N/A"
            }

            [string]$value
        }

        $line = "| " + (($cells | ForEach-Object -Begin { $i = 0 } -Process {
            $text = $_.PadRight($widths[$i])
            $i++
            $text
        }) -join " | ") + " |"
        $lines.Add($line)
    }

    return ($lines -join "`r`n")
}

function Replace-Section {
    param(
        [string]$Content,
        [string]$StartHeading,
        [string]$EndHeading,
        [string]$Replacement
    )

    $pattern = "(?s)$([regex]::Escape($StartHeading)).*?(?=$([regex]::Escape($EndHeading)))"
    return [regex]::Replace($Content, $pattern, $Replacement)
}

$osPrettyName = Get-RemoteFirstLine @'
if [ -r /etc/os-release ]; then
    . /etc/os-release
    printf '%s\n' "${PRETTY_NAME:-}"
elif [ -r /usr/lib/os-release ]; then
    . /usr/lib/os-release
    printf '%s\n' "${PRETTY_NAME:-}"
fi
'@
$osVersionRaw = Get-RemoteFirstLine @'
if [ -r /etc/os-release ]; then
    . /etc/os-release
    printf '%s\n' "${VERSION:-}"
elif [ -r /usr/lib/os-release ]; then
    . /usr/lib/os-release
    printf '%s\n' "${VERSION:-}"
fi
'@
$bannerBase64 = Invoke-RemoteScript @'
base64 /etc/banner.txt 2>/dev/null | tr -d '\n'
'@
$latestLiveDir = Get-RemoteFirstLine "ls -1dt /data/.config/Ableton/Live* 2>/dev/null | sed -n '1p'"
$pushFwRaw = Get-RemoteFirstLine @'
awk -F"'" '/^VERSION = / { print $2; exit }' /opt/push3/products/push3/python/Push2/version.py 2>/dev/null
'@
$kernelRelease = Get-RemoteFirstLine "uname -r"
$kernelArch = Get-RemoteFirstLine "uname -m"
$kernelVersionLine = Get-RemoteFirstLine "cat /proc/version"

$osPrettyName = Normalize-Whitespace $osPrettyName
$osVersionRaw = Normalize-Whitespace $osVersionRaw
$bannerText = Normalize-BannerText (Convert-FromBase64Utf8 $bannerBase64)
$liveVersion = Get-Basename $latestLiveDir
$pushFwVersion = Normalize-Whitespace $pushFwRaw

if ($osVersionRaw -match 'v([0-9][0-9A-Za-z.\-]*)') {
    $abletonOsVersion = $Matches[1]
} else {
    $abletonOsVersion = $osVersionRaw
}

if ($liveVersion -match '^Live\s+(.+)$') {
    $liveVersion = $Matches[1]
}

if ([string]::IsNullOrWhiteSpace($abletonOsVersion)) {
    $abletonOsVersion = "Unknown"
}

if ([string]::IsNullOrWhiteSpace($liveVersion)) {
    $liveVersion = "Unknown"
}

if ([string]::IsNullOrWhiteSpace($pushFwVersion)) {
    $pushFwVersion = "Unknown"
}

$prettyNameSuffix = if ($osPrettyName) { ' (' + [char]96 + $osPrettyName + [char]96 + ')' } else { '' }

$content = Get-Content -Raw $DocPath

$sharedProbeDefinitions = @(
    @{ Key = 'BashVersion';        Mode = 'first-line'; Command = "/bin/sh --version 2>&1 | sed -n '1p'";                                            Transform = { param($v) Normalize-Bash $v } }
    @{ Key = 'CoreutilsCat';       Mode = 'first-line'; Command = "cat --version 2>&1 | sed -n '1p'";                                                Transform = { param($v) Normalize-Coreutils $v } }
    @{ Key = 'CoreutilsLs';        Mode = 'first-line'; Command = "ls --version 2>&1 | sed -n '1p'";                                                 Transform = { param($v) Normalize-Coreutils $v } }
    @{ Key = 'CoreutilsMkdir';     Mode = 'first-line'; Command = "mkdir --version 2>&1 | sed -n '1p'";                                              Transform = { param($v) Normalize-Coreutils $v } }
    @{ Key = 'CoreutilsHead';      Mode = 'first-line'; Command = "head --version 2>&1 | sed -n '1p'";                                               Transform = { param($v) Normalize-Coreutils $v } }
    @{ Key = 'CoreutilsTail';      Mode = 'first-line'; Command = "tail --version 2>&1 | sed -n '1p'";                                               Transform = { param($v) Normalize-Coreutils $v } }
    @{ Key = 'CoreutilsWc';        Mode = 'first-line'; Command = "wc --version 2>&1 | sed -n '1p'";                                                 Transform = { param($v) Normalize-Coreutils $v } }
    @{ Key = 'CoreutilsSha';       Mode = 'first-line'; Command = "sha256sum --version 2>&1 | sed -n '1p'";                                          Transform = { param($v) Normalize-Coreutils $v } }
    @{ Key = 'CoreutilsUname';     Mode = 'first-line'; Command = "uname --version 2>&1 | sed -n '1p'";                                              Transform = { param($v) Normalize-Coreutils $v } }
    @{ Key = 'CoreutilsHostname';  Mode = 'first-line'; Command = "hostname --version 2>&1 | sed -n '1p'";                                           Transform = { param($v) Normalize-Coreutils $v } }
    @{ Key = 'FindutilsVersion';   Mode = 'first-line'; Command = "find --version 2>&1 | sed -n '1p'";                                               Transform = { param($v) Normalize-Findutils $v } }
    @{ Key = 'GrepVersion';        Mode = 'first-line'; Command = "grep --version 2>&1 | sed -n '1p'";                                               Transform = { param($v) Normalize-Grep $v } }
    @{ Key = 'GawkVersion';        Mode = 'first-line'; Command = "awk --version 2>&1 | sed -n '1p'";                                                Transform = { param($v) Normalize-Gawk $v } }
    @{ Key = 'SedVersion';         Mode = 'first-line'; Command = "sed --version 2>&1 | sed -n '1p'";                                                Transform = { param($v) Normalize-Sed $v } }
    @{ Key = 'AlsaAplay';          Mode = 'first-line'; Command = "aplay --version 2>&1 | sed -n '1p'";                                              Transform = { param($v) Normalize-AlsaTool $v } }
    @{ Key = 'AlsaArecord';        Mode = 'first-line'; Command = "arecord --version 2>&1 | sed -n '1p'";                                            Transform = { param($v) Normalize-AlsaTool $v } }
    @{ Key = 'AlsaSpeakerTest';    Mode = 'first-line'; Command = "speaker-test --help 2>&1 | sed -n '1p'";                                          Transform = { param($v) Normalize-AlsaTool $v } }
    @{ Key = 'DmesgVersion';       Mode = 'first-line'; Command = "dmesg --version 2>&1 | sed -n '1p'";                                              Transform = { param($v) Normalize-Dmesg $v } }
    @{ Key = 'KmodVersion';        Mode = 'first-line'; Command = "/sbin/insmod --version 2>&1 | sed -n '1p'";                                       Transform = { param($v) Normalize-Kmod $v } }
    @{ Key = 'LsusbVersion';       Mode = 'first-line'; Command = "lsusb --version 2>&1 | sed -n '1p'";                                              Transform = { param($v) Normalize-Lsusb $v } }
    @{ Key = 'IpVersion';          Mode = 'first-line'; Command = "/sbin/ip -V 2>&1 | sed -n '1p'";                                                  Transform = { param($v) Normalize-Ip $v } }
    @{ Key = 'StraceVersion';      Mode = 'first-line'; Command = "strace -V 2>&1 | sed -n '1p'";                                                    Transform = { param($v) Normalize-Strace $v } }
    @{ Key = 'RsyncVersion';       Mode = 'first-line'; Command = "rsync --version 2>&1 | sed -n '1p'";                                              Transform = { param($v) Normalize-Rsync $v } }
    @{ Key = 'SshdVersion';        Mode = 'first-line'; Command = "strings /usr/sbin/sshd 2>/dev/null | grep -m1 '^OpenSSH_'";                      Transform = { param($v) Normalize-SshVersion $v } }
    @{ Key = 'HostnameIWorks';     Mode = 'first-line'; Command = "hostname -I >/dev/null 2>&1 && echo yes || true";                                 Transform = { param($v) $v -eq 'yes' } }
    @{ Key = 'GccPath';            Mode = 'first-line'; Command = "command -v gcc 2>/dev/null || true";                                               Transform = { param($v) $v.Trim() } }
    @{ Key = 'KernelBuildExists';  Mode = 'path-exists'; Path = "/lib/modules/$kernelRelease/build";                                                  Transform = { param($v) [bool]$v } }
    @{ Key = 'KernelSourceExists'; Mode = 'path-exists'; Path = "/lib/modules/$kernelRelease/source";                                                 Transform = { param($v) [bool]$v } }
    @{ Key = 'ProcConfigExists';   Mode = 'path-exists'; Path = "/proc/config.gz";                                                                     Transform = { param($v) [bool]$v } }
    @{ Key = 'BootConfig';         Mode = 'find-first'; FindExpression = "/boot -maxdepth 1 -name 'config-*'";                                        Transform = { param($v) $v.Trim() } }
    @{ Key = 'ModuleSymvers';      Mode = 'find-first'; FindExpression = "/lib/modules /usr/src /boot /opt /data -name 'Module.symvers'";            Transform = { param($v) $v.Trim() } }
    @{ Key = 'SndAloop';           Mode = 'find-first'; FindExpression = "/lib/modules/$kernelRelease -type f -name 'snd-aloop*'";                    Transform = { param($v) $v.Trim() } }
    @{ Key = 'SndDummy';           Mode = 'find-first'; FindExpression = "/lib/modules/$kernelRelease -type f -name 'snd-dummy*'";                    Transform = { param($v) $v.Trim() } }
)

$sharedProbeResults = Invoke-RemoteProbeDefinitions $sharedProbeDefinitions
$shared = @{}
foreach ($key in $sharedProbeResults.Keys) {
    $shared[$key] = $sharedProbeResults[$key]
}
$shared['KernelRelease'] = $kernelRelease

$availableDocSections = Get-MarkdownTableSections -Content $content -StartHeading "## Available Tools" -EndHeading "## Unavailable Or Absent"
$unavailableDocSections = Get-MarkdownTableSections -Content $content -StartHeading "## Unavailable Or Absent" -EndHeading "## Known Useful Command Bundles"

$availableLines = New-Object System.Collections.Generic.List[string]
$availableLines.Add("## Available Tools")
$availableLines.Add("")
foreach ($section in $availableDocSections) {
    $resolvedRows = foreach ($row in $section.Rows) {
        Resolve-AvailableToolRow -Row $row -Shared $shared
    }

    $availableLines.Add($section.Heading)
    $availableLines.Add("")
    $availableLines.Add((Format-MarkdownTable -Headers $section.Headers -Rows $resolvedRows))
    $availableLines.Add("")
}
$availableSectionText = ($availableLines -join "`r`n").TrimEnd()

$unavailableLines = New-Object System.Collections.Generic.List[string]
$unavailableLines.Add("## Unavailable Or Absent")
$unavailableLines.Add("")
foreach ($section in $unavailableDocSections) {
    $resolvedRows = foreach ($row in $section.Rows) {
        Resolve-UnavailableToolRow -Row $row -Shared $shared
    }

    $unavailableLines.Add($section.Heading)
    $unavailableLines.Add("")
    $unavailableLines.Add((Format-MarkdownTable -Headers $section.Headers -Rows $resolvedRows))
    $unavailableLines.Add("")
}
$unavailableSectionText = ($unavailableLines -join "`r`n").TrimEnd()

$mdTick = [string]([char]96)
$targetContextLines = New-Object System.Collections.Generic.List[string]
$targetContextLines.Add("Target context observed during collection:")
$targetContextLines.Add("")
$targetContextLines.Add("- Device: Ableton Push 3 Standalone")
$targetContextLines.Add("- OS family: AbletonOS $kernelArch Intel image")
$targetContextLines.Add("- AbletonOS: " + $mdTick + $abletonOsVersion + $mdTick + $prettyNameSuffix)
$targetContextLines.Add("- Live: " + $mdTick + $liveVersion + $mdTick)
$targetContextLines.Add("- Push FW: " + $mdTick + $pushFwVersion + $mdTick)
$targetContextLines.Add("- Kernel: " + $mdTick + $kernelRelease + $mdTick)
$targetContextLines.Add('- Remote access used: `ssh root@push` / `scp`')
$targetContextLines.Add("")
$targetContextLines.Add('## SSH Banner Splash')
$targetContextLines.Add("")
$targetContextLines.Add('```text')
if ($bannerText) {
    foreach ($line in ($bannerText -split "`n")) {
        $targetContextLines.Add($line)
    }
}
$targetContextLines.Add('```')
$targetContextLines.Add("")

$targetContextSectionText = ($targetContextLines -join "`r`n")

$content = [regex]::Replace(
    $content,
    '(?s)Target context observed during collection:.*?(?=\r?\n- \[AbletonOS Toolset Reference\])',
    $targetContextSectionText
)

$content = Replace-Section -Content $content -StartHeading "## Available Tools" -EndHeading "## Unavailable Or Absent" -Replacement ($availableSectionText + "`r`n`r`n")
$content = Replace-Section -Content $content -StartHeading "## Unavailable Or Absent" -EndHeading "## Known Useful Command Bundles" -Replacement ($unavailableSectionText + "`r`n`r`n")

if ($DryRun) {
    $content
    exit 0
}

Set-Content -Path $DocPath -Value $content -NoNewline -Encoding UTF8
Write-Host "Updated $DocPath for $Target"
Write-Host "Kernel: $kernelRelease"
Write-Host "Proc version: $kernelVersionLine"
