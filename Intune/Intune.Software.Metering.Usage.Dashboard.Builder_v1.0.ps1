<#
.SYNOPSIS
    Intune Software Metering (Usage) Dashboard Builder

.DESCRIPTION
    Pulls the latest detection-script output for every device running a given Intune Proactive Remediation (produced by the companion device-side
    metering script), via Microsoft Graph using an app registration (client credentials). Each run is a "poll" - a snapshot of every device's current
    rolling usage total. Offline-capable HTML dashboard is generated , with client-side filtering, charts, a sortable table, and CSV export.
 
.REQUIRED GRAPH PERMISSIONS (Application, with admin consent)
    - DeviceManagementScripts.Read.All

#Version:                   v1.0
#Date :                     11 Oct 2026

#Original Author:           Chander Mani Pandey
#Youtube:-                  https://www.youtube.com/@chandermanipandey
#Twitter:-                  https://twitter.com/Mani_CMPandey
#LinkedIn:-                 https://www.linkedin.com/in/chandermanipandey

#>

# ===========================================================================================================
#                                  USER INPUT Start
# ===========================================================================================================

# Entra ID App registration (client credentials)

$TenantId                  = "xxxxxxxxxxxxxxxxxxxxx"
$AppId                     = "yyyyyyyyyyyyyyyyyyyyyyyy"
$ClientSecret              = "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"

# Provide EITHER the Proactive Remediation script's display name OR its Id (GUID) - not both are required.

$ProactiveRemediationScriptName = "Detect-Software Metering"
$ProactiveRemediationScriptId   = ""   # e.g. "1a2b3c4d-5678-90ab-cdef-1234567890ab" - leave blank to use the name instead

# Branding shown on the dashboard itself

$CompanyName                = "your logo"
$CompanyLogoPath            = ""   # e.g. "C:\IntuneReporting\logo.png" - local path to a .png/.jpg/.gif/.svg file. Leave blank for no logo.

# Alternative to CompanyLogoPath: paste a base64-encoded image string [Convert]::ToBase64String([System.IO.File]::ReadAllBytes("C:\path\to\logo.png"))
#Example $A = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes("C:\Users\PandeyCh\Downloads\images.png"))

$CompanyLogoBase64          = "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"
$CompanyLogoBase64MimeType  = "image/png"   # only used with CompanyLogoBase64 - e.g. "image/png", "image/jpeg"
$BrandHeaderColor           = "#111827"     # Dashboard header bar background color (hex, e.g. "#0b3d91")
$BrandAccentColor           = "#2563eb"     # Buttons, chart bars/lines, and other highlight color (hex)

# Where data & the dashboard are stored on the system

$ReportingHomeFolder        = "C:\IntuneReporting"

# ===========================================================================================================
#                                  USER INPUT End
# ===========================================================================================================

$HistoryDataPath            = Join-Path $ReportingHomeFolder "UsageHistory.json"
$DashboardOutputFolder      = Join-Path $ReportingHomeFolder "Dashboards"
$CollectorLogPath           = Join-Path $ReportingHomeFolder "CollectorLog.log"

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
$ErrorActionPreference = 'Stop'

function Write-CollectorLog {
    param([string]$Text)
    $stamped = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Text
    Write-Host $stamped
    try {
        if (-not (Test-Path $ReportingHomeFolder)) { New-Item -Path $ReportingHomeFolder -ItemType Directory -Force | Out-Null }
        Add-Content -Path $CollectorLogPath -Value $stamped
    } catch { }
}

function Save-JsonStateFile {
    # Atomic-ish write: write to a temp file first, then rename it over
    # the real file, so a crash mid-write is far less likely to leave a
    # half-written, corrupt JSON file behind.
    param($Object, [string]$Path)
    $folder = Split-Path -Path $Path -Parent
    if ($folder -and -not (Test-Path $folder)) { New-Item -Path $folder -ItemType Directory -Force | Out-Null }
    $tempPath = "$Path.tmp"
    $Object | ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 $tempPath
    Move-Item -Path $tempPath -Destination $Path -Force
}

function Get-GraphAccessToken {
    param([string]$TenantId, [string]$AppId, [string]$ClientSecret)
    $tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    $body = @{
        client_id     = $AppId
        client_secret = $ClientSecret
        scope         = "https://graph.microsoft.com/.default"
        grant_type    = "client_credentials"
    }
    $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
    return $response.access_token
}

function Invoke-GraphGetAll {
    # Follows @odata.nextLink pagination automatically and returns every
    # item across all pages as one combined array.
    param([string]$Uri, [string]$AccessToken)
    $allItems = New-Object System.Collections.Generic.List[object]
    $nextUri = $Uri
    $headers = @{ Authorization = "Bearer $AccessToken" }

    while ($nextUri) {
        $attempt = 0
        $response = $null
        while ($true) {
            $attempt++
            try {
                $response = Invoke-RestMethod -Uri $nextUri -Method Get -Headers $headers
                break
            } catch {
                $statusCode = $null
                try { $statusCode = [int]$_.Exception.Response.StatusCode } catch { }
                if (($statusCode -eq 429 -or $statusCode -ge 500) -and $attempt -lt 5) {
                    Write-CollectorLog "Graph request throttled/errored (HTTP $statusCode) - retrying in 5 seconds (attempt $attempt)..."
                    Start-Sleep -Seconds 5
                } else {
                    throw
                }
            }
        }
        if ($response.value) { foreach ($item in $response.value) { $allItems.Add($item) } }
        elseif ($response) { $allItems.Add($response) }
        $nextUri = $response.'@odata.nextLink'
    }
    return $allItems
}

function Resolve-RemediationScriptId {
    param([string]$AccessToken, [string]$DisplayName)
    $encodedName = [System.Uri]::EscapeDataString($DisplayName)
    $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts?`$filter=displayName eq '$encodedName'"
    $results = Invoke-GraphGetAll -Uri $uri -AccessToken $AccessToken
    if ($results.Count -eq 0) {
        throw "No Proactive Remediation script found with display name '$DisplayName'. Check the exact name in Intune (Devices > Scripts and remediations) and update `$ProactiveRemediationScriptName."
    }
    if ($results.Count -gt 1) {
        Write-CollectorLog "WARNING: multiple scripts matched the name '$DisplayName' - using the first match (Id: $($results[0].id))."
    }
    return $results[0].id
}

function Get-AllDeviceRunStates {
    param([string]$AccessToken, [string]$ScriptId)
    # NOTE: $expand=managedDevice here is only used to get the device name
    # and id quickly - it may return a shallow/partial device object, so
    # Model/JoinType/OsVersion etc. are fetched separately and
    # authoritatively via Get-ManagedDeviceDetails below.
    $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts('$ScriptId')/deviceRunStates?`$expand=managedDevice"
    return Invoke-GraphGetAll -Uri $uri -AccessToken $AccessToken
}

function Get-ManagedDeviceDetails {
    # Fetches full managedDevice entities directly from
    # /deviceManagement/managedDevices/{id} - the same endpoint/entity
    # Intune's own device export uses - via Graph's $batch endpoint, up
    # to 20 devices per round trip, rather than trusting whatever a
    # shallow $expand elsewhere in the API might return.
    param([string]$AccessToken, [string[]]$DeviceIds)

    $detailsById = @{}
    if ($DeviceIds.Count -eq 0) { return $detailsById }

    $selectFields = "id,deviceName,userPrincipalName,emailAddress,userDisplayName,osVersion,model,joinType,azureADRegistered,lastSyncDateTime"
    $headers = @{ Authorization = "Bearer $AccessToken"; "Content-Type" = "application/json" }
    $chunkSize = 20
    $uniqueIds = $DeviceIds | Select-Object -Unique

    for ($i = 0; $i -lt $uniqueIds.Count; $i += $chunkSize) {
        $chunk = $uniqueIds[$i..([math]::Min($i + $chunkSize - 1, $uniqueIds.Count - 1))]
        $batchRequests = @()
        $reqIndex = 0
        foreach ($id in $chunk) {
            $reqIndex++
            $batchRequests += @{
                id     = "$reqIndex"
                method = "GET"
                url    = "/deviceManagement/managedDevices/$id`?`$select=$selectFields"
            }
        }
        $batchBody = @{ requests = $batchRequests } | ConvertTo-Json -Depth 5

        $attempt = 0
        while ($true) {
            $attempt++
            try {
                $batchResponse = Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/`$batch" -Method Post -Headers $headers -Body $batchBody
                break
            } catch {
                $statusCode = $null
                try { $statusCode = [int]$_.Exception.Response.StatusCode } catch { }
                if (($statusCode -eq 429 -or $statusCode -ge 500) -and $attempt -lt 5) {
                    Start-Sleep -Seconds 5
                } else {
                    Write-CollectorLog "WARNING: batch device-detail fetch failed (HTTP $statusCode) for a chunk of $($chunk.Count) device(s) - those devices will fall back to expand data. Error: $($_.Exception.Message)"
                    $batchResponse = $null
                    break
                }
            }
        }

        if ($batchResponse -and $batchResponse.responses) {
            foreach ($resp in $batchResponse.responses) {
                if ($resp.status -eq 200 -and $resp.body -and $resp.body.id) {
                    $detailsById[$resp.body.id] = $resp.body
                }
            }
        }
    }

    return $detailsById
}

function Parse-UsageSummaryLine {
    # Parses one segment like:
    # "Microsoft Teams : 28h 15m 54s (last 30/30 days: 12-Jul-2026 to 10-Aug-2026)"
    param([string]$Segment)
    $pattern = '^\s*(?<app>.+?)\s*:\s*(?<h>\d+)h\s*(?<m>\d+)m\s*(?<s>\d+)s\s*\(last\s*(?<eff>\d+)/(?<req>\d+)\s*days:\s*(?<start>\d{2}-[A-Za-z]{3}-\d{4})\s*to\s*(?<end>\d{2}-[A-Za-z]{3}-\d{4})\)\s*$'
    $match = [regex]::Match($Segment, $pattern)
    if (-not $match.Success) { return $null }

    $totalSeconds = ([int]$match.Groups['h'].Value * 3600) + ([int]$match.Groups['m'].Value * 60) + [int]$match.Groups['s'].Value
    $invariantCulture = [System.Globalization.CultureInfo]::InvariantCulture

    return [PSCustomObject]@{
        AppName          = $match.Groups['app'].Value.Trim()
        TotalSeconds     = $totalSeconds
        EffectiveDays    = [int]$match.Groups['eff'].Value
        RequestedDays    = [int]$match.Groups['req'].Value
        WindowStartDate  = [datetime]::ParseExact($match.Groups['start'].Value, "dd-MMM-yyyy", $invariantCulture)
        WindowEndDate    = [datetime]::ParseExact($match.Groups['end'].Value, "dd-MMM-yyyy", $invariantCulture)
    }
}

function Get-LogoDataUri {
    # Converts a local image file into a base64 data: URI so it can be
    # embedded directly in the self-contained dashboard HTML - a plain
    # file path would break once the dashboard is exported or emailed to
    # someone else's machine. If LogoBase64 is provided, it's used
    # directly instead - fully self-contained, no image file needed on
    # whatever machine runs this script.
    param([string]$LogoPath, [string]$LogoBase64 = "", [string]$LogoBase64MimeType = "image/png")

    if (-not [string]::IsNullOrWhiteSpace($LogoBase64)) {
        return "data:$LogoBase64MimeType;base64,$LogoBase64"
    }

    if ([string]::IsNullOrWhiteSpace($LogoPath)) { return "" }
    if (-not (Test-Path $LogoPath)) {
        Write-CollectorLog "WARNING: CompanyLogoPath '$LogoPath' was not found - dashboard will show no logo."
        return ""
    }

    $extension = [System.IO.Path]::GetExtension($LogoPath).ToLower()
    $mimeType = switch ($extension) {
        ".png"  { "image/png" }
        ".jpg"  { "image/jpeg" }
        ".jpeg" { "image/jpeg" }
        ".gif"  { "image/gif" }
        ".svg"  { "image/svg+xml" }
        ".webp" { "image/webp" }
        default { $null }
    }
    if (-not $mimeType) {
        Write-CollectorLog "WARNING: CompanyLogoPath '$LogoPath' has an unsupported extension ($extension) - dashboard will show no logo."
        return ""
    }

    try {
        $bytes = [System.IO.File]::ReadAllBytes($LogoPath)
        $base64 = [Convert]::ToBase64String($bytes)
        return "data:$mimeType;base64,$base64"
    } catch {
        Write-CollectorLog "WARNING: Could not read CompanyLogoPath '$LogoPath': $($_.Exception.Message)"
        return ""
    }
}

function Get-FriendlyJoinType {
    # Maps Graph's managedDevice.joinType enum to the same wording Intune's
    # own UI/export uses. If your tenant's Graph response uses a different
    # property name or value here, adjust this mapping - the raw value is
    # still shown as a fallback rather than silently hidden.
    param($JoinTypeRaw, $AzureADRegisteredFallback)
    if (-not [string]::IsNullOrWhiteSpace($JoinTypeRaw) -and $JoinTypeRaw -ne "unknown") {
        switch ($JoinTypeRaw) {
            "azureADJoined"       { return "Azure AD joined" }
            "azureADRegistered"   { return "Azure AD registered" }
            "hybridAzureADJoined" { return "Hybrid Azure AD joined" }
            "workplaceJoined"     { return "Workplace joined" }
            default               { return $JoinTypeRaw }
        }
    }
    # joinType came back blank or literally "unknown" - fall back to the
    # azureADRegistered boolean, which is a longer-standing, more
    # reliably populated field on managedDevice.
    if ($AzureADRegisteredFallback -eq $true) { return "Azure AD registered" }
    return "Unknown"
}

function ConvertTo-UsageRows {
    # Turns raw Graph deviceRunStates into flat rows: one row per
    # device+app+poll, ready to append to the history file.
    # DeviceDetailsLookup (id -> full managedDevice object, from
    # Get-ManagedDeviceDetails) is the AUTHORITATIVE source for device/user
    # metadata - the same endpoint Intune's own export uses. The
    # deviceRunStates expand is used only as a fallback if a device's
    # batch detail fetch failed for some reason.
    param($RunStates, [datetime]$CollectedAtLocal, [hashtable]$DeviceDetailsLookup = @{})
    $rows = New-Object System.Collections.Generic.List[object]

    foreach ($state in $RunStates) {
        $deviceName   = $null
        $deviceId     = $null
        $userEmail    = "Unknown"
        $userName     = "Unknown"
        $osVersion    = "Unknown"
        $deviceModel  = "Unknown"
        $joinType     = "Unknown"
        $lastSyncTime = $null

        if ($state.managedDevice) {
            $deviceId = $state.managedDevice.id
            $deviceName = $state.managedDevice.deviceName
        }

        # Prefer the authoritative, directly-fetched device details.
        $md = $null
        if ($deviceId -and $DeviceDetailsLookup.ContainsKey($deviceId)) {
            $md = $DeviceDetailsLookup[$deviceId]
        } elseif ($state.managedDevice) {
            $md = $state.managedDevice
        }

        if ($md) {
            if ($md.deviceName)        { $deviceName = $md.deviceName }
            if ($md.userPrincipalName) { $userEmail = $md.userPrincipalName }
            elseif ($md.emailAddress)  { $userEmail = $md.emailAddress }
            if ($md.userDisplayName)   { $userName = $md.userDisplayName } else { $userName = $userEmail }
            if ($md.osVersion)         { $osVersion = $md.osVersion }
            if ($md.model)             { $deviceModel = $md.model }
            $joinType = Get-FriendlyJoinType -JoinTypeRaw $md.joinType -AzureADRegisteredFallback $md.azureADRegistered
            if ($md.lastSyncDateTime)  { $lastSyncTime = ([datetime]$md.lastSyncDateTime).ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss") }
        }
        if (-not $deviceName) { $deviceName = "Unknown device ($($state.id))" }
        if (-not $lastSyncTime) { $lastSyncTime = "" }

        $outputText = $state.preRemediationDetectionScriptOutput
        if ([string]::IsNullOrWhiteSpace($outputText)) { continue }

        $segments = $outputText -split ';'
        foreach ($segment in $segments) {
            if ([string]::IsNullOrWhiteSpace($segment)) { continue }
            $parsed = Parse-UsageSummaryLine -Segment $segment
            if ($null -eq $parsed) { continue }

            $rows.Add([PSCustomObject]@{
                DeviceId        = $deviceId
                DeviceName      = $deviceName
                UserEmail       = $userEmail
                UserName        = $userName
                OsVersion       = $osVersion
                DeviceModel     = $deviceModel
                JoinType        = $joinType
                LastSyncTime    = $lastSyncTime
                AppName         = $parsed.AppName
                TotalSeconds    = $parsed.TotalSeconds
                EffectiveDays   = $parsed.EffectiveDays
                RequestedDays   = $parsed.RequestedDays
                WindowStartDate = $parsed.WindowStartDate.ToString("yyyy-MM-dd")
                WindowEndDate   = $parsed.WindowEndDate.ToString("yyyy-MM-dd")
                CollectedAtLocal = $CollectedAtLocal.ToString("yyyy-MM-dd HH:mm:ss")
            })
        }
    }
    return $rows
}

function New-DashboardHtml {
    param($History, [string]$OutputPath, [string]$CompanyName = "", [string]$CompanyLogoPath = "", [string]$CompanyLogoBase64 = "", [string]$CompanyLogoBase64MimeType = "image/png", [string]$HeaderColor = "#111827", [string]$AccentColor = "#2563eb")

    $jsonData = $History | ConvertTo-Json -Depth 6 -Compress
    if ([string]::IsNullOrWhiteSpace($jsonData) -or $History.Count -eq 0) { $jsonData = "[]" }

    $htmlTemplate = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Software Usage Dashboard</title>
<style>
  :root {
    --bg: #f4f6f8; --card-bg: #ffffff; --border: #dde3e8; --text: #1f2933;
    --muted: #64748b; --accent: __ACCENT_COLOR__; --warn-bg: #fff4e5; --warn-text: #9a5b00;
    --good: #16a34a;
  }
  * { box-sizing: border-box; }
  body { margin:0; font-family: Segoe UI, Arial, sans-serif; background:var(--bg); color:var(--text); }
  header { background:__HEADER_COLOR__; color:#fff; padding:18px 24px; display:flex; justify-content:space-between; align-items:center; gap:20px; flex-wrap:wrap; }
  header .header-titles h1 { margin:0; font-size:20px; }
  header .header-titles p { margin:4px 0 0; color:#9ca3af; font-size:13px; }
  header .company-name { font-size:18px; font-weight:600; color:#fff; white-space:nowrap; }
  header .branding { display:flex; flex-direction:column; align-items:center; gap:6px; }
  header .branding img { height:44px; width:auto; max-width:180px; border-radius:8px; display:block; object-fit:contain; }
  .container { padding:20px; max-width:1400px; margin:0 auto; }
  .panel { background:var(--card-bg); border:1px solid var(--border); border-radius:8px; padding:16px; margin-bottom:18px; }
  .filters { display:grid; grid-template-columns: repeat(5, 1fr); gap:12px 14px; align-items:end; }
  .filter-item { display:flex; flex-direction:column; font-size:12px; color:var(--muted); gap:4px; min-width:0; }
  .filter-item select, .filter-item input { padding:6px 8px; border:1px solid var(--border); border-radius:6px; font-size:13px; width:100%; box-sizing:border-box; }
  select:disabled { background:#f3f4f6; color:#9ca3af; cursor:not-allowed; }
  .custom-select { position:relative; width:100%; }
  .custom-select-btn { width:100%; text-align:left; background:#fff; color:var(--text); border:1px solid var(--border); border-radius:6px; padding:6px 8px; font-size:13px; cursor:pointer; display:flex; justify-content:space-between; align-items:center; }
  .custom-select-btn::after { content:"▾"; color:var(--muted); font-size:11px; margin-left:8px; }
  .custom-select-panel { position:absolute; top:calc(100% + 4px); left:0; right:0; background:#fff; border:1px solid var(--border); border-radius:6px; box-shadow:0 4px 14px rgba(0,0,0,0.12); z-index:50; max-height:320px; overflow-y:auto; }
  .custom-select-option { padding:7px 10px; font-size:13px; cursor:pointer; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
  .custom-select-option:hover { background:#f3f4f6; }
  .custom-select-option.selected { background:#eef2ff; font-weight:600; }
  .filter-item label { white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
  .filters button { padding:8px 14px; font-size:13px; width:100%; }
  button { background:var(--accent); color:#fff; border:none; padding:8px 14px; border-radius:6px; font-size:13px; cursor:pointer; }
  button.secondary { background:#6b7280; }
  button:hover { opacity:0.9; }
  .cards { display:flex; gap:14px; flex-wrap:wrap; }
  .card { flex:1; min-width:160px; background:var(--card-bg); border:1px solid var(--border); border-radius:8px; padding:14px 16px; }
  .card .label { font-size:12px; color:var(--muted); }
  .card .value { font-size:24px; font-weight:600; margin-top:4px; }
  .card-blue { background:#eff6ff; border-color:#bfdbfe; }
  .card-blue .value { color:#1d4ed8; }
  .card-green { background:#f0fdf4; border-color:#bbf7d0; }
  .card-green .value { color:#15803d; }
  .card-purple { background:#faf5ff; border-color:#e9d5ff; }
  .card-purple .value { color:#7e22ce; }
  .card-amber { background:#fffbeb; border-color:#fde68a; }
  .card-teal { background:#f0fdfa; border-color:#99f6e4; }
  .card-teal .value { color:#0f766e; }
  .card-amber .value { color:#b45309; }
  .charts { display:block; }
  .chart-box { width:100%; }
  .chart-box h3 { font-size:14px; margin:0 0 8px; text-align:center; }
  .chart-box .note { text-align:center; }
  .au-search-row { display:flex; gap:14px; justify-content:center; margin-bottom:14px; flex-wrap:wrap; }
  .au-search-row .filter-item input { width:200px; }
  .au-current-view { text-align:center; font-size:13px; color:var(--muted); margin:0 0 10px; }
  .au-current-view b { color:var(--text); }
  .au-chart-wrap { max-width:800px; margin:0 auto; }
  .display-controls { display:flex; gap:14px; align-items:center; margin-bottom:12px; flex-wrap:wrap; }
  .display-count { font-size:12px; color:var(--muted); margin:0; }
  .leaderboard { max-height:460px; overflow-y:auto; border:1px solid var(--border); border-radius:6px; padding:6px; }
  .lb-row { display:flex; align-items:center; gap:10px; padding:6px 4px; }
  .lb-name { width:180px; font-size:12px; flex-shrink:0; text-align:right; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
  .lb-track { flex:1; background:#e5e7eb; border-radius:5px; height:16px; overflow:hidden; }
  .lb-fill { height:100%; border-radius:5px; }
  .lb-pct { width:80px; font-size:12px; font-weight:600; flex-shrink:0; }
  .lb-detail { width:150px; font-size:11px; color:var(--muted); flex-shrink:0; }
  .lb-good { background:#16a34a; }
  .lb-mid { background:#d97706; }
  .lb-low { background:#dc2626; }
  .lb-pct.lb-good { color:#16a34a; }
  .lb-pct.lb-mid { color:#d97706; }
  .lb-pct.lb-low { color:#dc2626; }
  table { width:100%; border-collapse:collapse; font-size:13px; }
  th, td { text-align:left; padding:8px 10px; border-bottom:1px solid var(--border); }
  th { cursor:pointer; user-select:none; color:var(--muted); font-weight:600; background:#fafafa; position:sticky; top:0; }
  th:hover { color:var(--text); }
  tr:hover td { background:#f9fafb; }
  .zero-row td { color:var(--text); background-color:#fdf6ec; }
  .zero-row:hover td { background-color:#faedd4; }
  .table-scroll { max-height:480px; overflow:auto; border:1px solid var(--border); border-radius:6px; }
  .warn-box { background:var(--warn-bg); color:var(--warn-text); border:1px solid #f0c36d; border-radius:8px; padding:12px 16px; font-size:13px; }
  .footer-actions { display:flex; gap:10px; margin-top:10px; }
  .note { font-size:12px; color:var(--muted); margin-top:6px; }
  canvas { max-width:100%; width:100%; display:block; }
</style>
</head>
<body>
<header>
  <div class="header-titles">
    <h1>Software Usage Dashboard</h1>
    <p id="headerSubtitle">Loading...</p>
  </div>
  <div class="branding">
    __COMPANY_LOGO_IMG__
    <div class="company-name">__COMPANY_NAME__</div>
  </div>
</header>
<div class="container">

  <div class="panel" id="filterBarPanel">
    <div class="filters">
      <div class="filter-item">
        <label>Device</label>
        <div class="custom-select" id="deviceFilterWrap">
          <button type="button" class="custom-select-btn" id="deviceFilterBtn">All devices</button>
          <input type="hidden" id="deviceFilter" value="">
          <div class="custom-select-panel" id="deviceFilterPanel" hidden></div>
        </div>
      </div>
      <div class="filter-item">
        <label>Application</label>
        <div class="custom-select" id="appFilterWrap">
          <button type="button" class="custom-select-btn" id="appFilterBtn">All applications</button>
          <input type="hidden" id="appFilter" value="">
          <div class="custom-select-panel" id="appFilterPanel" hidden></div>
        </div>
      </div>
      <div class="filter-item">
        <label>User (email or username)</label>
        <input type="text" id="userFilter" placeholder="e.g. jdoe or jdoe@contoso.com">
      </div>
      <div class="filter-item">
        <label>Collected from</label>
        <input type="date" id="collectedFrom">
      </div>
      <div class="filter-item">
        <label>Collected to</label>
        <input type="date" id="collectedTo">
      </div>
      <div class="filter-item">
        <label>Min usage (hours)</label>
        <input type="number" id="minHours" min="0" step="0.5" placeholder="0">
      </div>
      <div class="filter-item">
        <label>Show</label>
        <select id="zeroToggle">
          <option value="all">All entries</option>
          <option value="zero">Zero-usage only</option>
          <option value="nonzero">Used only</option>
        </select>
      </div>
      <div class="filter-item">
        <button onclick="applyFilters()">Apply</button>
      </div>
      <div class="filter-item">
        <button class="secondary" onclick="resetFilters()">Reset</button>
      </div>
    </div>
    <p class="note">User filter matches partial text, so typing just "jdoe" works whether the underlying record shows "jdoe@contoso.com" or "CONTOSO\jdoe" - the exact format depends on how each device reports it (Azure AD-joined devices typically show an email/UPN; hybrid or on-prem AD-joined devices typically show DOMAIN\username).</p>
    <p class="note">Note: charts and summary cards use each device+app+user's <b>most recent poll</b> within the selected collection date range (not a sum of every poll) - since each poll is a rolling usage total, summing polls would over-count. The trend chart below shows how that rolling total changed across polls over time.</p>
  </div>

  <div class="panel">
    <div class="cards">
      <div class="card card-blue"><div class="label">Devices</div><div class="value" id="cardDevices">-</div></div>
      <div class="card card-green"><div class="label">Applications</div><div class="value" id="cardApps">-</div></div>
      <div class="card card-purple"><div class="label">Total Hours (cumulative, sum across all matching devices)</div><div class="value" id="cardHours">-</div></div>
      <div class="card card-teal"><div class="label">Devices with app usage</div><div class="value" id="cardUsed">-</div></div>
      <div class="card card-amber"><div class="label">Devices with zero usage</div><div class="value" id="cardZero">-</div></div>
    </div>
  </div>

  <div class="panel charts">
    <div class="chart-box">
      <h3>Application Usage</h3>
      <p class="note">By default, shows total hours per application across every device (latest reported value, not a sum of every past poll). Search below to drill into one specific application, device, or user instead - only one search applies at a time.</p>

      <div class="au-search-row">
        <div class="filter-item">
          <label>Select Application</label>
          <input type="text" id="auSearchApp" list="auAppOptions" placeholder="Select an application...">
          <datalist id="auAppOptions"></datalist>
        </div>
        <div class="filter-item">
          <label>Select Device</label>
          <input type="text" id="auSearchDevice" list="auDeviceOptions" placeholder="Select a device...">
          <datalist id="auDeviceOptions"></datalist>
        </div>
        <div class="filter-item">
          <label>Select User</label>
          <input type="text" id="auSearchUser" list="auUserOptions" placeholder="Select a user...">
          <datalist id="auUserOptions"></datalist>
        </div>
        <div class="filter-item" style="flex:0 0 auto;">
          <label>&nbsp;</label>
          <button class="secondary" onclick="clearAppUsageSearch()">Clear</button>
        </div>
      </div>

      <p class="au-current-view" id="auCurrentView">Showing: <b>All applications (aggregate)</b></p>
      <div class="au-chart-wrap">
        <canvas id="barChart" height="260"></canvas>
      </div>
    </div>
  </div>

  <div class="panel">
    <h3 style="margin-top:0; text-align:center;">License Utilization by Application</h3>
    <p class="note" style="text-align:center;">For each app: the % of its devices that showed ANY usage (more than 0 hours) in the current filtered range - the same rule used by the Unused License Candidates list below, so the two never contradict each other. Sorted worst-utilized first by default, so the apps most worth reviewing for cost savings are always visible first, regardless of how many apps you're tracking.</p>
    <div style="display:flex; gap:14px; align-items:center; margin-bottom:12px; flex-wrap:wrap;">
      <div class="filter-item" style="flex:0 0 auto; min-width:200px;">
        <label>Show</label>
        <select id="utilScopeFilter">
          <option value="all">All apps</option>
          <option value="under50">Only underutilized (below 50%)</option>
          <option value="zero">Only unused (0%)</option>
        </select>
      </div>
      <div class="filter-item" style="flex:0 0 auto; min-width:200px;">
        <label>Sort</label>
        <select id="utilSortFilter">
          <option value="worst">Worst utilization first</option>
          <option value="best">Best utilization first</option>
          <option value="alpha">Alphabetical</option>
        </select>
      </div>
    </div>
    <div class="leaderboard" id="utilizationLeaderboard"></div>
  </div>

  <div class="panel">
    <h3 style="margin-top:0;">Detailed Rows</h3>
    <div class="display-controls">
      <div class="filter-item" style="flex:0 0 auto; min-width:150px;">
        <label>Show</label>
        <select id="tableShowLimit">
          <option value="20">Top 20</option>
          <option value="50">Top 50</option>
          <option value="all">All</option>
        </select>
      </div>
      <div class="filter-item" style="flex:0 0 auto; min-width:200px;">
        <label>Select Device</label>
        <input type="text" id="tableDeviceSearch" list="auDeviceOptions" placeholder="Select a device...">
      </div>
      <p class="display-count" id="tableDisplayCount"></p>
    </div>
    <div class="table-scroll">
      <table id="dataTable">
        <thead>
          <tr>
            <th data-key="DeviceName">Device</th>
            <th data-key="UserEmail">User Email</th>
            <th data-key="OsVersion">OS Version</th>
            <th data-key="DeviceModel">Model</th>
            <th data-key="JoinType">Join Type</th>
            <th data-key="LastSyncTime">Last Sync</th>
            <th data-key="AppName">Application</th>
            <th data-key="TotalSeconds">Usage</th>
            <th data-key="WindowStartDate">Reported Window</th>
            <th data-key="CollectedAtLocal">Collected At</th>
          </tr>
        </thead>
        <tbody id="tableBody"></tbody>
      </table>
    </div>
    <div class="footer-actions">
      <button onclick="exportCsv()">Export Filtered View to CSV</button>
      <button onclick="exportHtml()">Export Filtered View to HTML</button>
    </div>
  </div>

  <div class="panel">
    <h3 style="margin-top:0;">Unused License Candidates (zero usage in selected range)</h3>
    <div class="display-controls">
      <div class="filter-item" style="flex:0 0 auto; min-width:150px;">
        <label>Show</label>
        <select id="unusedShowLimit">
          <option value="20">Top 20</option>
          <option value="50">Top 50</option>
          <option value="all">All</option>
        </select>
      </div>
      <div class="filter-item" style="flex:0 0 auto; min-width:200px;">
        <label>Select Device</label>
        <input type="text" id="unusedDeviceSearch" list="auDeviceOptions" placeholder="Select a device...">
      </div>
    </div>
    <div id="unusedBox"></div>
    <div class="footer-actions">
      <button onclick="exportUnusedCsv()">Export Unused List to CSV</button>
      <button onclick="exportUnusedHtml()">Export Unused List to HTML</button>
    </div>
  </div>


</div>



<script>
/*RAW_DATA_START*/const RAW_DATA = __USAGE_DATA_JSON__;/*RAW_DATA_END*/
const ACCENT_COLOR = "__ACCENT_COLOR__";
// A distinct color per application in the bar chart, so apps are easy
// to tell apart at a glance instead of every bar being the same color.
// The trend line chart intentionally stays a single color (ACCENT_COLOR)
// since it's one continuous series, not separate categories.
const CHART_PALETTE = ["#2563eb", "#16a34a", "#f59e0b", "#dc2626", "#7c3aed", "#0891b2", "#db2777", "#65a30d", "#ea580c", "#4338ca"];

function formatHms(totalSeconds) {
  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  const s = Math.floor(totalSeconds % 60);
  return h + "h " + m + "m " + s + "s";
}

function parseLocalDate(s) {
  return new Date(s.replace(" ", "T"));
}

let currentSortKey = "DeviceName";
let currentSortDir = 1;
let latestFilteredSnapshot = [];

function safeGetVal(id, fallback) {
  // Returns fallback instead of throwing when an element is missing -
  // needed because exported HTML snapshots remove the filter bar
  // entirely, but this same rendering code still runs inside them.
  const el = document.getElementById(id);
  return el ? el.value : fallback;
}
function safeSetVal(id, value) {
  const el = document.getElementById(id);
  if (el) el.value = value;
}
function safeSetText(id, text) {
  const el = document.getElementById(id);
  if (el) el.textContent = text;
}

function setupCustomDropdown(wrapId, btnId, panelId, hiddenInputId, values, allLabel) {
  // A native <select>'s open popup is OS-level chrome that CSS cannot
  // style or constrain in height, so with many options it can grow to
  // show everything at once with no scroll. This builds the dropdown
  // ourselves instead, so a fixed visible height (about 10 rows) and
  // scrolling for the rest both work consistently in every browser.
  const wrap = document.getElementById(wrapId);
  const btn = document.getElementById(btnId);
  const panel = document.getElementById(panelId);
  const hiddenInput = document.getElementById(hiddenInputId);
  if (!wrap || !btn || !panel || !hiddenInput) return;

  function renderOptions() {
    panel.innerHTML = "";
    const allOpt = document.createElement("div");
    allOpt.className = "custom-select-option" + (hiddenInput.value === "" ? " selected" : "");
    allOpt.textContent = allLabel;
    allOpt.addEventListener("click", () => selectValue("", allLabel));
    panel.appendChild(allOpt);

    values.forEach(v => {
      const opt = document.createElement("div");
      opt.className = "custom-select-option" + (hiddenInput.value === v ? " selected" : "");
      opt.textContent = v;
      opt.addEventListener("click", () => selectValue(v, v));
      panel.appendChild(opt);
    });
  }

  function selectValue(value, label) {
    hiddenInput.value = value;
    btn.textContent = label;
    panel.hidden = true;
  }

  btn.addEventListener("click", (e) => {
    e.stopPropagation();
    const isOpen = !panel.hidden;
    document.querySelectorAll(".custom-select-panel").forEach(p => p.hidden = true);
    if (!isOpen) {
      renderOptions();
      panel.hidden = false;
    }
  });

  document.addEventListener("click", (e) => {
    if (!wrap.contains(e.target)) panel.hidden = true;
  });

  btn.textContent = allLabel;
}

function populateDropdowns() {
  const devices = [...new Set(RAW_DATA.map(r => norm(r.DeviceName)))].sort();
  const apps = [...new Set(RAW_DATA.map(r => norm(r.AppName)))].sort();

  setupCustomDropdown("deviceFilterWrap", "deviceFilterBtn", "deviceFilterPanel", "deviceFilter", devices, "All devices");
  setupCustomDropdown("appFilterWrap", "appFilterBtn", "appFilterPanel", "appFilter", apps, "All applications");

  const users = [...new Set(RAW_DATA.map(r => norm(r.UserEmail)).filter(Boolean))].sort();
  function fillDatalist(id, values) {
    const el = document.getElementById(id);
    if (!el) return;
    el.innerHTML = "";
    values.forEach(v => { const o = document.createElement("option"); o.value = v; el.appendChild(o); });
  }
  fillDatalist("auAppOptions", apps);
  fillDatalist("auDeviceOptions", devices);
  fillDatalist("auUserOptions", users);

  if (RAW_DATA.length > 0) {
    const dates = RAW_DATA.map(r => parseLocalDate(r.CollectedAtLocal));
    const minDate = new Date(Math.min(...dates));
    // Collected from/to start blank on purpose - the date filter only
    // applies once the user explicitly picks a range and clicks Apply,
    // rather than being pre-selected (and silently restricting results)
    // on page load.
    safeSetText("headerSubtitle",
      RAW_DATA.length + " row(s) from the latest poll across " + devices.length + " device(s), collected " + minDate.toLocaleString());
  } else {
    safeSetText("headerSubtitle", "No data collected yet.");
  }
}

function getFilteredRows() {
  const device = safeGetVal("deviceFilter", "");
  const app = safeGetVal("appFilter", "");
  const userText = safeGetVal("userFilter", "").trim().toLowerCase();
  const fromVal = safeGetVal("collectedFrom", "");
  const toVal = safeGetVal("collectedTo", "");
  const minHours = parseFloat(safeGetVal("minHours", "0")) || 0;
  const zeroMode = safeGetVal("zeroToggle", "all");

  const fromDate = fromVal ? new Date(fromVal + "T00:00:00") : null;
  const toDate = toVal ? new Date(toVal + "T23:59:59") : null;

  return RAW_DATA.filter(r => {
    if (device && norm(r.DeviceName) !== device) return false;
    if (app && norm(r.AppName) !== app) return false;
    if (userText && !((r.UserEmail || "") + " " + (r.UserName || "")).toLowerCase().includes(userText)) return false;
    const collected = parseLocalDate(r.CollectedAtLocal);
    if (fromDate && collected < fromDate) return false;
    if (toDate && collected > toDate) return false;
    return true;
  }).filter(r => {
    const hours = r.TotalSeconds / 3600;
    if (minHours > 0 && hours < minHours) return false;
    if (zeroMode === "zero" && r.TotalSeconds > 0) return false;
    if (zeroMode === "nonzero" && r.TotalSeconds === 0) return false;
    return true;
  });
}

function getLatestSnapshotPerDeviceApp(rows) {
  const latestMap = new Map();
  rows.forEach(r => {
    const key = norm(r.DeviceName) + "||" + norm(r.AppName);
    const existing = latestMap.get(key);
    if (!existing || parseLocalDate(r.CollectedAtLocal) > parseLocalDate(existing.CollectedAtLocal)) {
      latestMap.set(key, r);
    }
  });
  return Array.from(latestMap.values());
}

function renderCards(snapshotRows) {
  const devices = new Set(snapshotRows.map(r => r.DeviceName));
  const apps = new Set(snapshotRows.map(r => r.AppName));
  const totalHours = snapshotRows.reduce((sum, r) => sum + r.TotalSeconds, 0) / 3600;
  const zeroCount = snapshotRows.filter(r => r.TotalSeconds === 0).length;
  const usedCount = snapshotRows.length - zeroCount;

  document.getElementById("cardDevices").textContent = devices.size;
  document.getElementById("cardApps").textContent = apps.size;
  document.getElementById("cardHours").textContent = totalHours.toFixed(1);
  document.getElementById("cardUsed").textContent = usedCount;
  document.getElementById("cardZero").textContent = zeroCount;
}

function getDeviceSearchFiltered(rows, inputId) {
  const val = norm(safeGetVal(inputId, "")).toLowerCase();
  if (!val) return rows;
  return rows.filter(r => norm(r.DeviceName).toLowerCase().includes(val));
}

function applyDisplayLimit(rows, selectId) {
  const mode = safeGetVal(selectId, "20");
  if (mode === "all") return rows;
  const n = parseInt(mode, 10) || 20;
  return rows.slice(0, n);
}

function renderTable(rows) {
  const searched = getDeviceSearchFiltered(rows, "tableDeviceSearch");
  const sorted = [...searched].sort((a, b) => {
    let av = a[currentSortKey], bv = b[currentSortKey];
    if (currentSortKey === "TotalSeconds") { av = a.TotalSeconds; bv = b.TotalSeconds; }
    if (av < bv) return -1 * currentSortDir;
    if (av > bv) return 1 * currentSortDir;
    return 0;
  });
  const limited = applyDisplayLimit(sorted, "tableShowLimit");

  safeSetText("tableDisplayCount", "Showing " + limited.length + " of " + searched.length + " row(s)" + (searched.length !== rows.length ? " (filtered from " + rows.length + " total)" : ""));

  const body = document.getElementById("tableBody");
  body.innerHTML = "";
  limited.forEach(r => {
    const tr = document.createElement("tr");
    if (r.TotalSeconds === 0) tr.className = "zero-row";
    tr.innerHTML =
      "<td>" + r.DeviceName + "</td>" +
      "<td>" + (r.UserEmail || "Unknown") + "</td>" +
      "<td>" + (r.OsVersion || "Unknown") + "</td>" +
      "<td>" + (r.DeviceModel || "Unknown") + "</td>" +
      "<td>" + (r.JoinType || "Unknown") + "</td>" +
      "<td>" + (r.LastSyncTime || "") + "</td>" +
      "<td>" + r.AppName + "</td>" +
      "<td>" + formatHms(r.TotalSeconds) + "</td>" +
      "<td>" + r.WindowStartDate + " to " + r.WindowEndDate + "</td>" +
      "<td>" + r.CollectedAtLocal + "</td>";
    body.appendChild(tr);
  });
}

let latestUnusedList = [];

function renderUnused(snapshotRows) {
  const unused = snapshotRows.filter(r => r.TotalSeconds === 0);
  latestUnusedList = unused; // full list - exports always use this, unaffected by the display controls below

  const box = document.getElementById("unusedBox");
  if (unused.length === 0) {
    box.innerHTML = "<p class='note'>No zero-usage entries in the current filter.</p>";
    return;
  }

  const searched = getDeviceSearchFiltered(unused, "unusedDeviceSearch");
  const limited = applyDisplayLimit(searched, "unusedShowLimit");

  if (limited.length === 0) {
    box.innerHTML = "<p class='note'>No zero-usage entries match your device search.</p>";
    return;
  }

  let html = "<div class='warn-box'>" + unused.length + " device/app/user combination(s) show zero usage in the selected range";
  if (searched.length !== unused.length || limited.length !== searched.length) {
    html += " (showing " + limited.length + " of " + searched.length + " matching)";
  }
  html += ":<ul>";
  limited.forEach(r => { html += "<li>" + r.DeviceName + " — " + r.AppName + " — " + (r.UserEmail || "Unknown") + "</li>"; });
  html += "</ul></div>";
  box.innerHTML = html;
}

function drawBarChart(labels, values) {
  const canvas = document.getElementById("barChart");
  const ctx = canvas.getContext("2d");
  canvas.width = canvas.clientWidth; canvas.height = 260;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  if (labels.length === 0) {
    ctx.fillStyle = "#9ca3af";
    ctx.font = "13px Segoe UI";
    ctx.textAlign = "center";
    ctx.fillText("No data for this selection.", canvas.width / 2, canvas.height / 2);
    return;
  }

  const maxVal = Math.max(...values, 1);
  const bottomMargin = 70; // room for the rotated labels below each bar
  const barWidth = canvas.width / labels.length * 0.6;
  const gap = canvas.width / labels.length;

  labels.forEach((label, i) => {
    const barHeight = (values[i] / maxVal) * (canvas.height - bottomMargin - 20);
    const x = i * gap + (gap - barWidth) / 2;
    const y = canvas.height - bottomMargin - barHeight;
    ctx.fillStyle = CHART_PALETTE[i % CHART_PALETTE.length];
    ctx.fillRect(x, y, barWidth, barHeight);
    ctx.fillStyle = "#1f2933";
    ctx.font = "11px Segoe UI";
    ctx.textAlign = "center";
    ctx.fillText(values[i].toFixed(1) + "h", x + barWidth / 2, y - 6);

    // Rotated label so names never overlap each other, regardless of
    // how many bars there are or how long their names are.
    const shortLabel = label.length > 20 ? label.slice(0, 19) + "…" : label;
    ctx.save();
    ctx.translate(x + barWidth / 2, canvas.height - bottomMargin + 8);
    ctx.rotate(-Math.PI / 4);
    ctx.textAlign = "right";
    ctx.fillText(shortLabel, 0, 0);
    ctx.restore();
  });
}

function norm(val) {
  // Normalizes a value for comparison/grouping: trims whitespace so
  // historical rows collected by an earlier version of the device
  // script (which might have stray leading/trailing spaces baked in)
  // don't silently fail to match otherwise-identical values.
  return (val || "").toString().trim();
}

function sumByKey(rows, keyFn) {
  const totals = {};
  rows.forEach(r => {
    const key = norm(keyFn(r));
    totals[key] = (totals[key] || 0) + r.TotalSeconds;
  });
  const labels = Object.keys(totals);
  const values = labels.map(l => totals[l] / 3600);
  return { labels, values };
}

function renderAppUsageChart(snapshotRows) {
  const appVal = norm(safeGetVal("auSearchApp", "")).toLowerCase();
  const deviceVal = norm(safeGetVal("auSearchDevice", "")).toLowerCase();
  const userVal = norm(safeGetVal("auSearchUser", "")).toLowerCase();

  let dataset, viewLabel;

  if (deviceVal) {
    const matched = snapshotRows.filter(r => norm(r.DeviceName).toLowerCase() === deviceVal);
    if (matched.length > 0) {
      dataset = sumByKey(matched, r => r.AppName);
      viewLabel = "Device - " + norm(matched[0].DeviceName) + " (by application)";
    } else {
      dataset = sumByKey(snapshotRows, r => r.AppName);
      viewLabel = "All applications (aggregate) - no exact device match yet, keep typing or pick from the list";
    }
  } else if (userVal) {
    const matched = snapshotRows.filter(r => norm(r.UserEmail).toLowerCase() === userVal);
    if (matched.length > 0) {
      dataset = sumByKey(matched, r => r.AppName);
      viewLabel = "User - " + norm(matched[0].UserEmail) + " (by application)";
    } else {
      dataset = sumByKey(snapshotRows, r => r.AppName);
      viewLabel = "All applications (aggregate) - no exact user match yet, keep typing or pick from the list";
    }
  } else if (appVal) {
    const matched = snapshotRows.filter(r => norm(r.AppName).toLowerCase() === appVal);
    if (matched.length > 0) {
      dataset = sumByKey(matched, r => r.DeviceName);
      viewLabel = norm(matched[0].AppName) + " (by device) - which devices are actually using this app";
    } else {
      dataset = sumByKey(snapshotRows, r => r.AppName);
      viewLabel = "All applications (aggregate) - no exact application match yet, keep typing or pick from the list";
    }
  } else {
    dataset = sumByKey(snapshotRows, r => r.AppName);
    viewLabel = "All applications (aggregate)";
  }

  const viewEl = document.getElementById("auCurrentView");
  if (viewEl) viewEl.innerHTML = "Showing: <b>" + viewLabel + "</b>";

  drawBarChart(dataset.labels, dataset.values);
}

function clearAppUsageSearch() {
  safeSetVal("auSearchApp", "");
  safeSetVal("auSearchDevice", "");
  safeSetVal("auSearchUser", "");
  renderAppUsageChart(latestFilteredSnapshot);
}

function computeUtilizationData(snapshotRows) {
  // "Used" = any usage greater than 0 hours in the current filtered
  // range - matching the exact same rule as the Unused License
  // Candidates list, so the two sections never contradict each other.
  const perApp = new Map();
  snapshotRows.forEach(r => {
    const key = norm(r.AppName);
    if (!perApp.has(key)) perApp.set(key, { total: 0, used: 0 });
    const entry = perApp.get(key);
    entry.total += 1;
    if (r.TotalSeconds > 0) entry.used += 1;
  });

  return Array.from(perApp.entries()).map(([app, counts]) => ({
    app,
    used: counts.used,
    total: counts.total,
    idle: counts.total - counts.used,
    pct: counts.total > 0 ? Math.round((counts.used / counts.total) * 100) : 0
  }));
}

function colorClassForPct(pct) {
  if (pct < 25) return "lb-low";
  if (pct < 60) return "lb-mid";
  return "lb-good";
}

function renderUtilizationLeaderboard(snapshotRows) {
  const board = document.getElementById("utilizationLeaderboard");
  if (!board) return;

  let data = computeUtilizationData(snapshotRows);

  const scope = safeGetVal("utilScopeFilter", "all");
  if (scope === "under50") data = data.filter(d => d.pct < 50);
  if (scope === "zero") data = data.filter(d => d.pct === 0);

  const sortMode = safeGetVal("utilSortFilter", "worst");
  if (sortMode === "worst") data.sort((a, b) => a.pct - b.pct);
  else if (sortMode === "best") data.sort((a, b) => b.pct - a.pct);
  else data.sort((a, b) => a.app.localeCompare(b.app));

  if (data.length === 0) {
    board.innerHTML = "<p class='note' style='padding:8px;'>No applications match the current filters.</p>";
    return;
  }

  board.innerHTML = "";
  data.forEach(d => {
    const cls = colorClassForPct(d.pct);
    const row = document.createElement("div");
    row.className = "lb-row";
    row.innerHTML =
      "<div class='lb-name' title='" + d.app + "'>" + d.app + "</div>" +
      "<div class='lb-track'><div class='lb-fill " + cls + "' style='width:" + Math.max(d.pct, 2) + "%'></div></div>" +
      "<div class='lb-pct " + cls + "'>" + d.pct + "%</div>" +
      "<div class='lb-detail'>" + d.used + " of " + d.total + " device(s) used" + (d.idle > 0 ? " · " + d.idle + " idle" : "") + "</div>";
    board.appendChild(row);
  });
}

function downloadTextFile(content, filename, mimeType) {
  const blob = new Blob([content], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url; a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

function rowsToCsv(rows) {
  let csv = "Device,UserEmail,OsVersion,Model,JoinType,LastSyncTime,Application,UsageSeconds,UsageFormatted,WindowStart,WindowEnd,CollectedAt\n";
  rows.forEach(r => {
    csv += [r.DeviceName, (r.UserEmail || "Unknown"), (r.OsVersion || "Unknown"), (r.DeviceModel || "Unknown"), (r.JoinType || "Unknown"), (r.LastSyncTime || ""), r.AppName, r.TotalSeconds, formatHms(r.TotalSeconds), r.WindowStartDate, r.WindowEndDate, r.CollectedAtLocal]
      .map(v => '"' + String(v).replace(/"/g,'""') + '"').join(",") + "\n";
  });
  return csv;
}

function exportCsv() {
  const rows = renderAndReturnSnapshot();
  downloadTextFile(rowsToCsv(rows), "SoftwareUsageExport_" + new Date().toISOString().slice(0,10) + ".csv", "text/csv");
}

function buildStandaloneHtml(datasetRows, reportLabel) {
  // Reuses this very page's own HTML/CSS/JS (so the exported file stays
  // fully interactive - filters, sorting, charts, all still work inside
  // it) but swaps in just the given dataset instead of the full history.
  // Works on a CLONE of the document, not the live page, so removing the
  // export buttons here never affects what you see on screen.
  const newDataJson = JSON.stringify(datasetRows);
  const clonedDoc = document.cloneNode(true);
  clonedDoc.querySelectorAll(".footer-actions").forEach(el => el.remove());
  const filterPanel = clonedDoc.getElementById("filterBarPanel");
  if (filterPanel) filterPanel.remove();

  // Clear, visible banner at the very top so it's never ambiguous which
  // of the two export types you're looking at, even if their row counts
  // happen to look similar.
  const banner = clonedDoc.createElement("div");
  banner.setAttribute("style", "background:#1f2933; color:#fff; padding:10px 20px; font-size:13px; font-weight:600;");
  banner.textContent = "Report type: " + reportLabel + " - exported " + new Date().toLocaleString() + " (" + datasetRows.length + " row(s))";
  const bodyEl = clonedDoc.querySelector("body");
  if (bodyEl) bodyEl.insertBefore(banner, bodyEl.firstChild);

  const fullSource = clonedDoc.documentElement.outerHTML;
  const markerPattern = /\/\*RAW_DATA_START\*\/const RAW_DATA = .*?;\/\*RAW_DATA_END\*\//s;
  const replacement = "/*RAW_DATA_START*/const RAW_DATA = " + newDataJson + ";/*RAW_DATA_END*/";
  const swapped = fullSource.replace(markerPattern, replacement);
  return "<!DOCTYPE html>\n" + swapped;
}

function exportHtml() {
  // Uses the DEDUPED snapshot (same as what's currently on screen in the
  // Detailed Rows table), not the raw multi-poll history - so what you
  // export always matches what you were actually looking at.
  const html = buildStandaloneHtml(latestFilteredSnapshot, "Filtered View");
  downloadTextFile(html, "SoftwareUsageExport_" + new Date().toISOString().slice(0,10) + ".html", "text/html");
}

function exportUnusedCsv() {
  downloadTextFile(rowsToCsv(latestUnusedList), "UnusedLicenseCandidates_" + new Date().toISOString().slice(0,10) + ".csv", "text/csv");
}

function exportUnusedHtml() {
  const html = buildStandaloneHtml(latestUnusedList, "Unused License Candidates");
  downloadTextFile(html, "UnusedLicenseCandidates_" + new Date().toISOString().slice(0,10) + ".html", "text/html");
}

function renderAndReturnSnapshot() {
  const filtered = getFilteredRows();
  const snapshot = getLatestSnapshotPerDeviceApp(filtered);
  renderCards(snapshot);
  renderTable(snapshot);
  renderUnused(snapshot);
  renderAppUsageChart(snapshot);
  renderUtilizationLeaderboard(snapshot);
  latestFilteredSnapshot = snapshot;
  return snapshot;
}

function applyFilters() { renderAndReturnSnapshot(); }
function resetFilters() {
  safeSetVal("deviceFilter", "");
  safeSetText("deviceFilterBtn", "All devices");
  safeSetVal("appFilter", "");
  safeSetText("appFilterBtn", "All applications");
  safeSetVal("userFilter", "");
  safeSetVal("minHours", "");
  safeSetVal("zeroToggle", "all");
  safeSetVal("collectedFrom", "");
  safeSetVal("collectedTo", "");
  renderAndReturnSnapshot();
}

document.querySelectorAll("#dataTable th").forEach(th => {
  th.addEventListener("click", () => {
    const key = th.getAttribute("data-key");
    if (currentSortKey === key) { currentSortDir *= -1; } else { currentSortKey = key; currentSortDir = 1; }
    renderTable(latestFilteredSnapshot);
  });
});
const utilScopeFilterEl = document.getElementById("utilScopeFilter");
if (utilScopeFilterEl) utilScopeFilterEl.addEventListener("change", () => renderUtilizationLeaderboard(latestFilteredSnapshot));
const utilSortFilterEl = document.getElementById("utilSortFilter");
if (utilSortFilterEl) utilSortFilterEl.addEventListener("change", () => renderUtilizationLeaderboard(latestFilteredSnapshot));

function wireAppUsageSearchInput(inputId, othersToClear) {
  const el = document.getElementById(inputId);
  if (!el) return;
  el.addEventListener("input", () => {
    othersToClear.forEach(otherId => safeSetVal(otherId, ""));
    renderAppUsageChart(latestFilteredSnapshot);
  });
}
wireAppUsageSearchInput("auSearchApp", ["auSearchDevice", "auSearchUser"]);
wireAppUsageSearchInput("auSearchDevice", ["auSearchApp", "auSearchUser"]);
wireAppUsageSearchInput("auSearchUser", ["auSearchApp", "auSearchDevice"]);

const tableShowLimitEl = document.getElementById("tableShowLimit");
if (tableShowLimitEl) tableShowLimitEl.addEventListener("change", () => renderTable(latestFilteredSnapshot));
const tableDeviceSearchEl = document.getElementById("tableDeviceSearch");
if (tableDeviceSearchEl) tableDeviceSearchEl.addEventListener("input", () => renderTable(latestFilteredSnapshot));

const unusedShowLimitEl = document.getElementById("unusedShowLimit");
if (unusedShowLimitEl) unusedShowLimitEl.addEventListener("change", () => renderUnused(latestFilteredSnapshot));
const unusedDeviceSearchEl = document.getElementById("unusedDeviceSearch");
if (unusedDeviceSearchEl) unusedDeviceSearchEl.addEventListener("input", () => renderUnused(latestFilteredSnapshot));

populateDropdowns();
renderAndReturnSnapshot();
</script>
</body>
</html>
'@

    $safeCompanyName = ""
    if (-not [string]::IsNullOrWhiteSpace($CompanyName)) {
        $safeCompanyName = $CompanyName -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;'
    }

    $logoDataUri = Get-LogoDataUri -LogoPath $CompanyLogoPath -LogoBase64 $CompanyLogoBase64 -LogoBase64MimeType $CompanyLogoBase64MimeType
    $logoImgTag = if ([string]::IsNullOrWhiteSpace($logoDataUri)) { "" } else { "<img src=`"$logoDataUri`" alt=`"Company logo`">" }

    # Basic hex validation - falls back to the known-good default rather
    # than injecting something invalid into the CSS/JS if the input is
    # malformed (missing #, wrong length, non-hex characters, etc.).
    $safeHeaderColor = if ($HeaderColor -match '^#[0-9A-Fa-f]{6}$') { $HeaderColor } else { "#111827" }
    $safeAccentColor = if ($AccentColor -match '^#[0-9A-Fa-f]{6}$') { $AccentColor } else { "#2563eb" }

    $finalHtml = $htmlTemplate.Replace('__USAGE_DATA_JSON__', $jsonData).Replace('__COMPANY_NAME__', $safeCompanyName).Replace('__COMPANY_LOGO_IMG__', $logoImgTag).Replace('__HEADER_COLOR__', $safeHeaderColor).Replace('__ACCENT_COLOR__', $safeAccentColor)

    if (-not (Test-Path $DashboardOutputFolder)) { New-Item -Path $DashboardOutputFolder -ItemType Directory -Force | Out-Null }
    Set-Content -Path $OutputPath -Value $finalHtml -Encoding utf8
}

# =====================================================================
# MAIN
# =====================================================================
try {
    Write-CollectorLog "----- Collection run started -----"

    if ($TenantId -eq "YOUR-TENANT-ID" -or $AppId -eq "YOUR-APP-REGISTRATION-CLIENT-ID" -or $ClientSecret -eq "YOUR-CLIENT-SECRET") {
        throw "Please fill in TenantId, AppId, and ClientSecret in the USER INPUT section before running this script."
    }

    Write-CollectorLog "Authenticating to Microsoft Graph..."
    $accessToken = Get-GraphAccessToken -TenantId $TenantId -AppId $AppId -ClientSecret $ClientSecret
    Write-CollectorLog "Authentication successful."

    if (-not [string]::IsNullOrWhiteSpace($ProactiveRemediationScriptId)) {
        $scriptId = $ProactiveRemediationScriptId.Trim()
        Write-CollectorLog "Using provided Proactive Remediation script Id directly: $scriptId"
    } else {
        Write-CollectorLog "No ScriptId provided - resolving by display name '$ProactiveRemediationScriptName'..."
        $scriptId = Resolve-RemediationScriptId -AccessToken $accessToken -DisplayName $ProactiveRemediationScriptName
        Write-CollectorLog "Resolved script Id: $scriptId"
    }

    Write-CollectorLog "Pulling device run states..."
    $runStates = Get-AllDeviceRunStates -AccessToken $accessToken -ScriptId $scriptId
    Write-CollectorLog "Retrieved $($runStates.Count) device run state(s)."

    $deviceIds = $runStates | Where-Object { $_.managedDevice -and $_.managedDevice.id } | ForEach-Object { $_.managedDevice.id }
    Write-CollectorLog "Fetching authoritative device details for $($deviceIds.Count) device(s) via Graph batch..."
    $deviceDetailsLookup = Get-ManagedDeviceDetails -AccessToken $accessToken -DeviceIds $deviceIds
    Write-CollectorLog "Retrieved full details for $($deviceDetailsLookup.Count) of $($deviceIds.Count) device(s)."

    $collectedAtLocal = Get-Date
    $newRows = ConvertTo-UsageRows -RunStates $runStates -CollectedAtLocal $collectedAtLocal -DeviceDetailsLookup $deviceDetailsLookup
    Write-CollectorLog "Parsed $($newRows.Count) usage row(s) from this poll."

    # No accumulation across runs: every feature in this dashboard (Application
    # Usage, License Utilization, Detailed Rows, Unused License Candidates)
    # only ever needs the CURRENT poll's data, not a growing history. So each
    # run simply replaces the data file with this run's rows - at any point
    # in time there is exactly one data file and one dashboard file, both
    # reflecting the latest poll only. If you want to keep a particular
    # day's snapshot, just copy or rename SoftwareUsageDashboard.html
    # yourself before the next scheduled run overwrites it.
    Save-JsonStateFile -Object $newRows -Path $HistoryDataPath
    Write-CollectorLog "Data file replaced with this poll's $($newRows.Count) row(s) (no accumulation - see note above)."

    $dashboardPath = Join-Path $DashboardOutputFolder "SoftwareUsageDashboard.html"
    New-DashboardHtml -History $newRows -OutputPath $dashboardPath -CompanyName $CompanyName -CompanyLogoPath $CompanyLogoPath -CompanyLogoBase64 $CompanyLogoBase64 -CompanyLogoBase64MimeType $CompanyLogoBase64MimeType -HeaderColor $BrandHeaderColor -AccentColor $BrandAccentColor
    Write-CollectorLog "Dashboard generated (overwriting any previous version): $dashboardPath"

    # Auto-open in the default browser. Wrapped in try/catch since this
    # will fail harmlessly (and should) when running unattended via Task
    # Scheduler with no logged-on interactive session - the dashboard
    # file itself is still generated either way.
    try {
        Start-Process -FilePath $dashboardPath
        Write-CollectorLog "Opened dashboard in default browser."
    } catch {
        Write-CollectorLog "Could not auto-open the dashboard (likely running in a non-interactive session): $($_.Exception.Message)"
    }

    Write-CollectorLog "----- Collection run completed -----"
    Write-Output "Dashboard updated: $dashboardPath ($($newRows.Count) rows from this poll)"
}
catch {
    Write-CollectorLog "ERROR: $($_.Exception.Message)"
    Write-Output "ERROR: $($_.Exception.Message)"
    exit 1
}