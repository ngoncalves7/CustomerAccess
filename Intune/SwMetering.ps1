<#
.SYNOPSIS
    Endpoint Software Usage Meter for Windows

.DESCRIPTION
    Monitors and reports application usage on Windows devices by leveraging native
    Windows Security Audit events (Process Creation - Event ID 4688 and Process
    Termination - Event ID 4689). The script automatically enables the required
    auditing policies, tracks the runtime of configured applications, maintains
    persistent usage history across executions, and generates a summarized usage
    report for a configurable reporting period.

    Designed for Microsoft Intune Proactive Remediations, Scheduled Tasks, or
    other automation platforms, the script stores usage data locally, prevents
    duplicate session tracking, recovers from interrupted executions, and outputs
    a concise application usage summary suitable for reporting.

.NOTES
    Version        : v3.0
    Author         : Chander Mani Pandey
    Creation Date  : 18 July 2026
    Updated        : 2026

    YouTube  : https://www.youtube.com/@chandermanipandey8763
    Twitter  : https://twitter.com/Mani_CMPandey
    LinkedIn : https://www.linkedin.com/in/chandermanipandey

.INPUTS
    Configure the following values in the User Input Section:
        - Applications to monitor
        - Reporting window (days)
        - Data retention period
        - Local storage folder

.OUTPUTS
    - Application usage summary written to the Intune console.
    - Daily usage ledger stored as JSON.
    - Checkpoint and session state files.
    - Activity log for troubleshooting.
    - Persistent usage history under C:\ProgramData\EndpointSoftwareUsageMeter.
#>
# =====================================================================
# User Input Scection
# =====================================================================
# Applications to meter. Add or remove entries as needed.
#   FriendlyName  - the label shown in the summary output.
#   ProcessNames  - one or more exe names that count toward this app

$TrackedApplications = @(

    [PSCustomObject]@{ FriendlyName = "Calculadora";   ProcessNames = @("calc.exe") }
    [PSCustomObject]@{ FriendlyName = "Notepad";   ProcessNames = @("notepad.exe") }

    )


$ReportingWindowDays   = 30                                          # How many trailing days of usage to summarize on every run.
$MeterHomeFolder       = "C:\ProgramData\EndpointSoftwareUsageMeter" # Root folder for the usage ledger, checkpoint, and logs.
$LedgerRetentionDays   = 90                                          # How long daily totals are kept before being pruned.
# =====================================================================

$ErrorActionPreference = 'Stop'

$RunStateFolder      = Join-Path $MeterHomeFolder "RunState"
$CheckpointFilePath  = Join-Path $RunStateFolder "Checkpoint.json"
$UsageLedgerPath     = Join-Path $RunStateFolder "DailyUsageLedger.json"
$SessionGuardPath    = Join-Path $RunStateFolder "CompletedSessionGuard.json"
$AppFirstSeenPath    = Join-Path $RunStateFolder "AppFirstSeen.json"
$ActivityLogPath     = Join-Path $RunStateFolder "ActivityLog.log"
$RunLockFilePath     = Join-Path $RunStateFolder "RunLock.pid"

function Write-ActivityLine {
    param([string]$Text)
    $stamped = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Text
    try { Add-Content -Path $ActivityLogPath -Value $stamped } catch { }
}

function Read-JsonStateFile {
    param([string]$Path, [string]$FriendlyLabel)
    if (-not (Test-Path $Path)) { return $null }
    try {
        $raw = Get-Content $Path -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        return ($raw | ConvertFrom-Json)
    } catch {
        $corruptBackupPath = "{0}.corrupt-{1}" -f $Path, (Get-Date -Format "yyyyMMddHHmmss")
        try { Move-Item -Path $Path -Destination $corruptBackupPath -Force -ErrorAction SilentlyContinue } catch { }
        Write-ActivityLine "WARNING: $FriendlyLabel was corrupt/unreadable and could not be parsed. Backed up to '$corruptBackupPath' and resetting this file to a fresh default."
        return $null
    }
}

function Save-JsonStateFile {
    param($Object, [string]$Path)
    $tempPath = "$Path.tmp"
    $Object | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 $tempPath
    Move-Item -Path $tempPath -Destination $Path -Force
}

function Test-AnotherInstanceRunning {
    if (-not (Test-Path $RunLockFilePath)) { return $false }
    try {
        $lockedPid = (Get-Content $RunLockFilePath -Raw).Trim()
        $lockedProcess = Get-Process -Id ([int]$lockedPid) -ErrorAction SilentlyContinue
        if ($lockedProcess -and $lockedProcess.ProcessName -match 'powershell|pwsh') {
            return $true
        }
    } catch { }
    return $false
}

function Initialize-MeterHome {
    foreach ($folder in @($MeterHomeFolder, $RunStateFolder)) {
        if (-not (Test-Path $folder)) {
            New-Item -Path $folder -ItemType Directory -Force | Out-Null
            Write-ActivityLine "Created folder: $folder"
        }
    }
}

function Confirm-AuditingEnabled {
    Write-ActivityLine "Checking prerequisite: audit policy for Process Creation (4688)..."
    $creationStatus = (auditpol /get /subcategory:"Process Creation" /r | ConvertFrom-Csv)
    $creationEnabled = $creationStatus."Inclusion Setting" -match "Success"
    if (-not $creationEnabled) {
        auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable | Out-Null
        Write-ActivityLine "Process Creation auditing was OFF - enabled it now."
    } else {
        Write-ActivityLine "Process Creation auditing already enabled - no action needed."
    }

    Write-ActivityLine "Checking prerequisite: audit policy for Process Termination (4689)..."
    $terminationStatus = (auditpol /get /subcategory:"Process Termination" /r | ConvertFrom-Csv)
    $terminationEnabled = $terminationStatus."Inclusion Setting" -match "Success"
    if (-not $terminationEnabled) {
        auditpol /set /subcategory:"Process Termination" /success:enable /failure:enable | Out-Null
        Write-ActivityLine "Process Termination auditing was OFF - enabled it now."
    } else {
        Write-ActivityLine "Process Termination auditing already enabled - no action needed."
    }

    Write-ActivityLine "Checking prerequisite: command-line capture on process creation events..."
    $cmdLinePolicyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit"
    $cmdLineValue = $null
    try { $cmdLineValue = (Get-ItemProperty -Path $cmdLinePolicyPath -Name "ProcessCreationIncludeCmdLine_Enabled" -ErrorAction SilentlyContinue).ProcessCreationIncludeCmdLine_Enabled } catch { }
    if ($cmdLineValue -ne 1) {
        if (-not (Test-Path $cmdLinePolicyPath)) { New-Item -Path $cmdLinePolicyPath -Force | Out-Null }
        Set-ItemProperty -Path $cmdLinePolicyPath -Name "ProcessCreationIncludeCmdLine_Enabled" -Value 1 -Type DWord -Force
        Write-ActivityLine "Command-line capture was OFF - enabled it now."
    } else {
        Write-ActivityLine "Command-line capture already enabled - no action needed."
    }
}

function New-ProcessAliasMap {
    param($Catalog)
    $aliasMap = @{}
    foreach ($app in $Catalog) {
        foreach ($procName in $app.ProcessNames) {
            $aliasMap[$procName.ToLower()] = $app.FriendlyName
        }
    }
    return $aliasMap
}

function Get-RunCheckpoint {
    $loaded = Read-JsonStateFile -Path $CheckpointFilePath -FriendlyLabel "Checkpoint file"
    if ($null -ne $loaded) {
        $openSessions = @()
        if ($loaded.OpenSessions) {
            $openSessions = if ($loaded.OpenSessions -isnot [System.Array]) { @($loaded.OpenSessions) } else { $loaded.OpenSessions }
        }
        return [PSCustomObject]@{
            FirstRunUtc  = [datetime]$loaded.FirstRunUtc
            LastScanUtc  = [datetime]$loaded.LastScanUtc
            OpenSessions = $openSessions
        }
    } else {
        $nowUtc = (Get-Date).ToUniversalTime()
        Write-ActivityLine "No checkpoint found - treating this as first run. Tracking begins now."
        return [PSCustomObject]@{
            FirstRunUtc  = $nowUtc
            LastScanUtc  = $nowUtc.AddMinutes(-60)
            OpenSessions = @()
        }
    }
}

function Save-RunCheckpoint {
    param($Checkpoint)
    Save-JsonStateFile -Object $Checkpoint -Path $CheckpointFilePath
}

function Get-SessionGuard {
    $loaded = Read-JsonStateFile -Path $SessionGuardPath -FriendlyLabel "Session guard file"
    $guard = @{}
    if ($loaded) { foreach ($p in $loaded.PSObject.Properties) { $guard[$p.Name] = $p.Value } }
    return $guard
}

function Get-UsageLedger {
    $loaded = Read-JsonStateFile -Path $UsageLedgerPath -FriendlyLabel "Usage ledger file"
    $ledger = @{}
    if ($loaded) { foreach ($p in $loaded.PSObject.Properties) { $ledger[$p.Name] = [double]$p.Value } }
    return $ledger
}

function Get-AppFirstSeenMap {
    $loaded = Read-JsonStateFile -Path $AppFirstSeenPath -FriendlyLabel "App first-seen file"
    $map = @{}
    if ($loaded) { foreach ($p in $loaded.PSObject.Properties) { $map[$p.Name] = $p.Value } }
    return $map
}

function Save-AppFirstSeenMap {
    param($Map)
    Save-JsonStateFile -Object $Map -Path $AppFirstSeenPath
}

function ConvertFrom-RawEvent {
    param($RawEvent, [bool]$IsStartEvent)
    $xmlDoc = [xml]$RawEvent.ToXml()
    $fields = @{}
    foreach ($node in $xmlDoc.Event.EventData.Data) { $fields[$node.Name] = $node.'#text' }

    $pidRaw = if ($IsStartEvent) { $fields["NewProcessId"] } else { $fields["ProcessId"] }
    if ([string]::IsNullOrWhiteSpace($pidRaw)) { return $null }
    try {
        $pidValue = if ($pidRaw -match '^0x[0-9a-fA-F]+$') { [convert]::ToInt32($pidRaw, 16) } else { [int]$pidRaw }
    } catch { return $null }

    return [PSCustomObject]@{
        ProcessId   = "$pidValue"
        ProcessPath = if ($IsStartEvent) { $fields["NewProcessName"] } else { $null }
        AccountName = $fields["SubjectUserName"]
        OccurredAt  = $RawEvent.TimeCreated
    }
}

function Format-ClockString {
    param([double]$TotalSeconds)
    $span = [TimeSpan]::FromSeconds([math]::Round($TotalSeconds))
    return "{0}h {1}m {2}s" -f [int]$span.TotalHours, $span.Minutes, $span.Seconds
}

# =====================================================================
# MAIN
# =====================================================================
try {
    Initialize-MeterHome

    if (Test-AnotherInstanceRunning) {
        Write-ActivityLine "Another instance appears to already be running (active lock found) - exiting without doing any work, to avoid two runs corrupting shared state files concurrently."
        Write-Output "Skipped this run: a previous run is still in progress."
        exit 0
    }
    "$PID" | Set-Content -Path $RunLockFilePath -Force

    Write-ActivityLine "----- Run started -----"

    Confirm-AuditingEnabled

    $aliasMap  = New-ProcessAliasMap -Catalog $TrackedApplications
    $checkpoint = Get-RunCheckpoint
    $sessionGuard = Get-SessionGuard
    $usageLedger  = Get-UsageLedger
    $appFirstSeen = Get-AppFirstSeenMap
    $todayDateString = (Get-Date).Date.ToString("yyyy-MM-dd")
    $firstSeenChanged = $false
    foreach ($app in $TrackedApplications) {
        if (-not $appFirstSeen.ContainsKey($app.FriendlyName)) {
            $appFirstSeen[$app.FriendlyName] = $todayDateString
            $firstSeenChanged = $true
            Write-ActivityLine "First time seeing '$($app.FriendlyName)' in the catalog - tracking starts today ($todayDateString)."
        }
    }

    $scanStartUtc = $checkpoint.LastScanUtc
    $scanEndUtc   = (Get-Date).ToUniversalTime()
    Write-ActivityLine "Scanning process activity from $($scanStartUtc.ToLocalTime()) to $($scanEndUtc.ToLocalTime())."

    $openSessions = @()
    if ($checkpoint.OpenSessions) { $openSessions = @($checkpoint.OpenSessions) }

    $startEvents = Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4688; StartTime = $scanStartUtc.ToLocalTime() } -ErrorAction SilentlyContinue
    $stopEvents  = Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4689; StartTime = $scanStartUtc.ToLocalTime() } -ErrorAction SilentlyContinue
    Write-ActivityLine "Retrieved $($startEvents.Count) start event(s) and $($stopEvents.Count) stop event(s)."

    # --- Register new starts of tracked applications ---
    foreach ($rawEvent in $startEvents) {
        $parsed = ConvertFrom-RawEvent -RawEvent $rawEvent -IsStartEvent $true
        if ($null -eq $parsed -or -not $parsed.ProcessPath) { continue }
        $exeName = [System.IO.Path]::GetFileName($parsed.ProcessPath).ToLower()
        if (-not $aliasMap.ContainsKey($exeName)) { continue }
        $alreadyOpen = $openSessions | Where-Object { $_.ProcessId -eq $parsed.ProcessId -and $_.AccountName -eq $parsed.AccountName }
        if (-not $alreadyOpen) {
            $openSessions += [PSCustomObject]@{
                ProcessId    = $parsed.ProcessId
                FriendlyName = $aliasMap[$exeName]
                AccountName  = $parsed.AccountName
                StartedAtUtc = $parsed.OccurredAt.ToUniversalTime()
            }
        }
    }

    # --- Close out matching stops and roll time into the daily ledger ---
    foreach ($rawEvent in $stopEvents) {
        $parsed = ConvertFrom-RawEvent -RawEvent $rawEvent -IsStartEvent $false
        if ($null -eq $parsed) { continue }
        $match = $openSessions | Where-Object { $_.ProcessId -eq $parsed.ProcessId -and $_.AccountName -eq $parsed.AccountName } | Select-Object -First 1
        if ($null -eq $match) { continue }

        $endedAtUtc = $parsed.OccurredAt.ToUniversalTime()
        $durationSeconds = ($endedAtUtc - $match.StartedAtUtc).TotalSeconds
        if ($durationSeconds -lt 0) { $durationSeconds = 0 }

        $guardKey = "{0}|{1}|{2}" -f $match.ProcessId, $match.StartedAtUtc.ToString("o"), $match.AccountName
        if (-not $sessionGuard.ContainsKey($guardKey)) {
            $ledgerDate = $endedAtUtc.ToLocalTime().ToString("yyyy-MM-dd")
            $ledgerKey  = "{0}|{1}" -f $ledgerDate, $match.FriendlyName
            if ($usageLedger.ContainsKey($ledgerKey)) {
                $usageLedger[$ledgerKey] = $usageLedger[$ledgerKey] + $durationSeconds
            } else {
                $usageLedger[$ledgerKey] = $durationSeconds
            }
            $sessionGuard[$guardKey] = $endedAtUtc.ToString("o")
        }

        $openSessions = @($openSessions | Where-Object { -not ($_.ProcessId -eq $match.ProcessId -and $_.StartedAtUtc -eq $match.StartedAtUtc -and $_.AccountName -eq $match.AccountName) })
    }

    # --- Drop stale open sessions (still "open" after 24h = likely a missed stop event) ---
    $staleCutoffUtc = (Get-Date).ToUniversalTime().AddHours(-24)
    $openSessions = @($openSessions | Where-Object {
        $pidNum = 0
        [int]::TryParse($_.ProcessId, [ref]$pidNum) | Out-Null
        (Get-Process -Id $pidNum -ErrorAction SilentlyContinue) -and ([datetime]$_.StartedAtUtc -gt $staleCutoffUtc)
    })

    # --- Adopt tracked applications already running but never seen starting ---
    $trackedProcessNames = $aliasMap.Keys
    Get-Process | Where-Object { $trackedProcessNames -contains ($_.Name.ToLower() + ".exe") } | ForEach-Object {
        $proc = $_
        $procIdText = "$($proc.Id)"
        $alreadyTracked = $openSessions | Where-Object { $_.ProcessId -eq $procIdText }
        if (-not $alreadyTracked) {
            $exeKey = $proc.Name.ToLower() + ".exe"
            $owningUser = $env:USERNAME
            try {
                $cimMatch = Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction SilentlyContinue
                if ($cimMatch) {
                    $ownerInfo = $cimMatch | Invoke-CimMethod -MethodName GetOwner
                    if ($ownerInfo.ReturnValue -eq 0) { $owningUser = $ownerInfo.User }
                }
            } catch { }
            $openSessions += [PSCustomObject]@{
                ProcessId    = $procIdText
                FriendlyName = $aliasMap[$exeKey]
                AccountName  = $owningUser
                StartedAtUtc = $proc.StartTime.ToUniversalTime()
            }
        }
    }

    # --- Prune ledger and session guard beyond retention ---
    $retentionCutoffDate = (Get-Date).AddDays(-$LedgerRetentionDays).Date
    $trimmedLedger = @{}
    foreach ($key in $usageLedger.Keys) {
        $datePart = $key.Split('|')[0]
        if ([datetime]$datePart -ge $retentionCutoffDate) { $trimmedLedger[$key] = $usageLedger[$key] }
    }
    $usageLedger = $trimmedLedger

    $trimmedGuard = @{}
    foreach ($key in $sessionGuard.Keys) {
        $guardTime = [datetime]$sessionGuard[$key]
        if ($guardTime -ge $retentionCutoffDate) { $trimmedGuard[$key] = $sessionGuard[$key] }
    }
    $sessionGuard = $trimmedGuard

    # --- Persist state for next run ---
    $checkpoint.LastScanUtc  = $scanEndUtc
    $checkpoint.OpenSessions = $openSessions
    Save-RunCheckpoint -Checkpoint $checkpoint
    Save-JsonStateFile -Object $usageLedger -Path $UsageLedgerPath
    Save-JsonStateFile -Object $sessionGuard -Path $SessionGuardPath
    if ($firstSeenChanged -or -not (Test-Path $AppFirstSeenPath)) {
        Save-AppFirstSeenMap -Map $appFirstSeen
    }

    $todayDate = (Get-Date).Date
    Write-ActivityLine "----- Usage summary (requested $ReportingWindowDays day(s) per app) -----"

    $consoleSummary = New-Object System.Collections.Generic.List[string]

    $rampingUpApps = New-Object System.Collections.Generic.List[string]

    foreach ($app in $TrackedApplications) {
        $appFirstSeenDate = [datetime]$appFirstSeen[$app.FriendlyName]
        $appDaysTracked   = [math]::Max(1, [math]::Ceiling(($todayDate - $appFirstSeenDate).TotalDays) + 1)
        $appEffectiveDays = [math]::Min($ReportingWindowDays, $appDaysTracked)
        $appWindowStartDate = $todayDate.AddDays(-($appEffectiveDays - 1))

        if ($appEffectiveDays -lt $ReportingWindowDays) {
            $rampingUpApps.Add("$($app.FriendlyName) ($appEffectiveDays of $ReportingWindowDays day(s))")
        }

        $totalSeconds = 0.0
        foreach ($key in $usageLedger.Keys) {
            $parts = $key.Split('|')
            $entryDate = [datetime]$parts[0]
            $entryApp  = $parts[1]
            if ($entryApp -eq $app.FriendlyName -and $entryDate -ge $appWindowStartDate) {
                $totalSeconds += $usageLedger[$key]
            }
        }
        $effectiveDayLabel  = "{0}/{1} days" -f $appEffectiveDays, $ReportingWindowDays
        $isoCulture = [System.Globalization.CultureInfo]::InvariantCulture
        $rangeStartLabel = $appWindowStartDate.ToString("dd-MMM-yyyy", $isoCulture)
        $rangeEndLabel    = $todayDate.ToString("dd-MMM-yyyy", $isoCulture)
        $summaryLine = "{0} : {1} (last {2}: {3} to {4})" -f $app.FriendlyName, (Format-ClockString -TotalSeconds $totalSeconds), $effectiveDayLabel, $rangeStartLabel, $rangeEndLabel
        Write-ActivityLine $summaryLine
        $consoleSummary.Add($summaryLine)
    }

    if ($rampingUpApps.Count -gt 0) {
        Write-ActivityLine "Note: still ramping up to the full $ReportingWindowDays-day window for: $($rampingUpApps -join '; ')."
    }

    Write-ActivityLine "----- Run completed -----"
    Write-HOST ($consoleSummary -join ";")
    
    exit 0
}
catch {
    Write-ActivityLine "ERROR: $($_.Exception.Message)"
    Write-Output "ERROR: $($_.Exception.Message)"
    exit 0
}
finally {
    try { Remove-Item -Path $RunLockFilePath -Force -ErrorAction SilentlyContinue } catch { }
}
