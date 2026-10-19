<#
.SYNOPSIS
    Intune detection inventory script to pulls installed application info from the Windows registry uninstall keys (HKLM system-wide and HKU per-user hives).

.DESCRIPTION
    Collects AppName, Version, InstallDate, InstallScope (Device/User/All), andUninstallString for installed Win32 apps and stores them in a single     variable ($AppInventory) as an array of objects.

.NOTES
    Only per-user hives currently LOADED under HKEY_USERS are scanned (i.e. logged-on users). Profiles for users who are not currently logged on will not have a loaded HKU hive and won't be captured by this method.

#Author:                    Chander Mani Pandey
#Version:                   v1.0
#Creation Date:             09 Sep 2026
#Youtube:-                  https://www.youtube.com/@chandermanipandey
#Twitter:-                  https://twitter.com/Mani_CMPandey
#LinkedIn:-                 https://www.linkedin.com/in/chandermanipandey
#>
#>

Set-ExecutionPolicy -ExecutionPolicy Bypass

# ============================================================================
#                             USER INPUT SECTION
# ============================================================================
$InstallScopeFilter  =   "All"     # Allowed values: 'Device', 'User', 'All'
                                 #   Device = only machine-wide (HKLM) installs
                                 #   User   = only per-user (HKU) installs
                                 #   All    = both (default)
$AppName             =    @("*google*")    
                                 #   Array of wildcard patterns to match app DisplayName against, e.g. @("*zip*","CapCut","Webex*")
                                 #   Default @("*") returns every installed app. An app matching ANY pattern in the array is included.

$ExcludeAppNames     =    @("*Microsoft Device Inventory Agent*","*Microsoft Intune Management Extension*","*Microsoft Visual C++*","*Teams*","*OneDrive*","*Edge*","*Administrative Templates*","*Application Compatibility Fix*","*Microsoft 365 Apps for enterprise*","*Office 16 Click-to-Run*")
                                 #   Array of full names or keywords to EXCLUDE from results, e.g. @("*Visual C++*","*Update*","OneDrive")
                                 #   Each entry is matched as a wildcard against DisplayName. Leave @() to exclude nothing.
                                 #   Useful for dropping noisy/repetitive entries (redistributables, updates) to save characters.
$IncludeUninstallCmd =   $false   
                                 #   $true  = include the uninstall command in output
                                 #   $false = exclude it, to reduce character count toward the 2048-char limit
# ============================================================================
#                            END OF USER INPUT SECTION
# ============================================================================

# --- Validate user input ---------------------------------------------------------
if ($InstallScopeFilter -notin @("Device", "User", "All")) {
    Write-Host "Invalid `$InstallScopeFilter value '$InstallScopeFilter'. Must be 'Device', 'User', or 'All'."
    exit 1
}

# --- Win32 API fallback for InstallDate ------------------------------------------

Add-Type -Namespace Win32 -Name Registry -MemberDefinition @"
[DllImport("advapi32.dll", SetLastError = true)]
public static extern int RegQueryInfoKey(
    Microsoft.Win32.SafeHandles.SafeRegistryHandle hKey,
    System.Text.StringBuilder lpClass,
    ref uint lpcchClass,
    IntPtr lpReserved,
    out uint lpcSubKeys,
    out uint lpcbMaxSubKeyLen,
    out uint lpcbMaxClassLen,
    out uint lpcValues,
    out uint lpcbMaxValueNameLen,
    out uint lpcbMaxValueLen,
    out uint lpcbSecurityDescriptor,
    out long lpftLastWriteTime);
"@ -ErrorAction SilentlyContinue

function Get-RegKeyLastWriteTime {
    param([Microsoft.Win32.RegistryKey]$Key)
    try {
        $classBuilder = New-Object System.Text.StringBuilder 255
        [uint32]$classLen = 255
        [uint32]$subKeys = 0; [uint32]$maxSubKeyLen = 0; [uint32]$maxClassLen = 0
        [uint32]$values = 0; [uint32]$maxValueNameLen = 0; [uint32]$maxValueLen = 0
        [uint32]$secDesc = 0; [long]$lastWriteFileTime = 0

        $result = [Win32.Registry]::RegQueryInfoKey(
            $Key.Handle, $classBuilder, [ref]$classLen, [IntPtr]::Zero,
            [ref]$subKeys, [ref]$maxSubKeyLen, [ref]$maxClassLen,
            [ref]$values, [ref]$maxValueNameLen, [ref]$maxValueLen,
            [ref]$secDesc, [ref]$lastWriteFileTime)

        if ($result -eq 0 -and $lastWriteFileTime -gt 0) {
            return [DateTime]::FromFileTime($lastWriteFileTime)
        }
    } catch { }
    return $null
}

# --- Registry locations to scan -------------------------------------------------
$scanTargets = @()

if ($InstallScopeFilter -in @("Device", "All")) {
    $scanTargets += @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall";              Scope = "Device" }
    $scanTargets += @{ Path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"; Scope = "Device" }
}

if ($InstallScopeFilter -in @("User", "All")) {
    # Per-user (only currently loaded hives under HKEY_USERS)
    $loadedSids = Get-ChildItem "Registry::HKEY_USERS" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.PSChildName -match '^S-1-' -and
            $_.PSChildName -notmatch '_Classes$' -and
            $_.PSChildName -notin @('S-1-5-18', 'S-1-5-19', 'S-1-5-20')
        }

    foreach ($sid in $loadedSids) {
        $userUninstallPath = "Registry::HKEY_USERS\$($sid.PSChildName)\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
        if (Test-Path $userUninstallPath) {
            $scanTargets += @{ Path = $userUninstallPath; Scope = "User"; Sid = $sid.PSChildName }
        }
    }
}

# --- Collect ---------------------------------------------------------------------
$AppInventory = foreach ($target in $scanTargets) {

        Get-ChildItem -Path $target.Path -ErrorAction SilentlyContinue | ForEach-Object {

        $subKey = $_
        $props  = Get-ItemProperty -Path $subKey.PSPath -ErrorAction SilentlyContinue

        if ($props.DisplayName) {

            # Include only if it matches ANY pattern in $AppName
            $isIncluded = $false
            foreach ($namePattern in $AppName) {
                if ($props.DisplayName -like $namePattern) {
                    $isIncluded = $true
                    break
                }
            }
            if (-not $isIncluded) { return }

            # Skip if it matches any exclude pattern
            $isExcluded = $false
            foreach ($excludePattern in $ExcludeAppNames) {
                if ($props.DisplayName -like $excludePattern) {
                    $isExcluded = $true
                    break
                }
            }
            if ($isExcluded) { return }

            $installDate       = $props.InstallDate
            $installDateSource = "Registry InstallDate value"

            if (-not $installDate) {
                $lastWrite = Get-RegKeyLastWriteTime -Key $subKey
                if ($lastWrite) {
                    $installDate       = $lastWrite.ToString("yyyyMMdd")
                    $installDateSource = "Key last-write time (fallback)"
                } else {
                    $installDate       = $null
                    $installDateSource = "Unavailable"
                }
            }

            $uninstallCmd = if ($props.QuietUninstallString -and $props.UninstallString) {
                $props.QuietUninstallString
            } elseif ($props.UninstallString) {
                $props.UninstallString
            } else {
                "N/P"
            }

            [PSCustomObject]@{
                AppName            = $props.DisplayName
                Version            = $props.DisplayVersion
                InstallDate        = $installDate
                InstallDateSource  = $installDateSource
                InstallScope       = $target.Scope
                UserSid            = $target.Sid
                UninstallString    = $uninstallCmd
                Publisher          = $props.Publisher 
            }
        }
    }
}

# Dedupe 
$AppInventory = $AppInventory | Sort-Object AppName, Version, InstallScope -Unique

# --- Output / detection logic -----------------------------------------------------
$MAX_OUTPUT_CHARS = 2048

if ($AppInventory) {

    $lines = foreach ($app in $AppInventory) {
        $scopeLetter = if ($app.InstallScope -eq "Device") { "D" } else { "U" }
        if ($IncludeUninstallCmd) {
            "{0}|{1}|{2}|{3}|U:{4}" -f `
                $app.AppName, $app.Version, $app.InstallDate, $scopeLetter, $app.UninstallString
        } else {
            "{0}|{1}|{2}|{3}" -f `
                $app.AppName, $app.Version, $app.InstallDate, $scopeLetter
        }
    }

    # Build the single semicolon-delimited variable while staying under the cap.
    $sb = New-Object System.Text.StringBuilder
    $truncated = $false

    foreach ($line in $lines) {
        $separator = if ($sb.Length -gt 0) { ";" } else { "" }
        $addLen    = $line.Length + $separator.Length
        if (($sb.Length + $addLen) -gt ($MAX_OUTPUT_CHARS - 20)) {  # reserve 20 chars for truncation note
            $truncated = $true
            break
        }
        [void]$sb.Append($separator).Append($line)
    }

    if ($truncated) {
        [void]$sb.Append(";...[truncated]")
    }

$DetectionOutput = $sb.ToString()
$charCount = $DetectionOutput.Length
if ($charCount -gt 2048) {
    Write-Host""
    Write-Host "DetectionOutput length: $charCount characters (OVER LIMIT) ( Output size limit is 2,048 characters )" -ForegroundColor Red
} elseif ($charCount -gt 1800) {
    Write-Host""
    Write-Host "DetectionOutput length: $charCount characters (close to limit) ( Output size limit is 2,048 characters )" -ForegroundColor Yellow
} else {
    Write-Host""
    Write-Host "DetectionOutput length: $charCount characters ( Output size limit is 2,048 characters )" -ForegroundColor Green
}
    Write-Host""
    Write-Host $DetectionOutput
    exit 0   # detected
} else {
    $DetectionOutput = "No app found matching Name='$($AppName -join ', ')', Scope='$InstallScopeFilter'."
    Write-Host""
    Write-Host $DetectionOutput
    exit 1   # not detected
}