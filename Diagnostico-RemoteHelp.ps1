#requires -Version 5.1
<##
.SYNOPSIS
  Instala o requisito WebView2, configura o firewall do Remote Help
  e executa verificacoes finais de conectividade e logs.

.DESCRIPTION
  Execute em uma janela do PowerShell como Administrador.
  O script nao desativa o firewall e nao remove regras existentes.
  Se o winget nao estiver disponivel, o WebView2 sera apenas reportado.
#>

[CmdletBinding()]
param(
    [switch]$SkipWebView2Install
)

$ErrorActionPreference = 'Continue'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$workDir = Join-Path $env:ProgramData 'RemoteHelpDiagnostics'
$reportPath = Join-Path $workDir "RemoteHelp-Diagnostico-$timestamp.txt"
New-Item -Path $workDir -ItemType Directory -Force | Out-Null

try { Start-Transcript -Path $reportPath -Force | Out-Null } catch {}

function Write-Section {
    param([string]$Title)
    Write-Host "`n==== $Title ====" -ForegroundColor Cyan
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-WebView2Installation {
    $guid = '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\$guid",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\$guid",
        "HKCU:\SOFTWARE\Microsoft\EdgeUpdate\Clients\$guid",
        "HKCU:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\$guid"
    )

    $items = foreach ($path in $paths) {
        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
            Select-Object name, pv, version
    }

    @($items | Where-Object { $_ })
}

function Install-WebView2IfNeeded {
    $installed = @(Get-WebView2Installation)
    if ($installed.Count -gt 0) {
        Write-Host 'WebView2: encontrado.' -ForegroundColor Green
        $installed | Format-Table -AutoSize
        return
    }

    Write-Host 'WebView2: nao encontrado.' -ForegroundColor Yellow
    if ($SkipWebView2Install) {
        Write-Host 'Instalacao automatica ignorada pelo parametro -SkipWebView2Install.' -ForegroundColor Yellow
        return
    }

    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Host 'winget nao encontrado; instale o Microsoft Edge WebView2 Runtime manualmente.' -ForegroundColor Yellow
        return
    }

    Write-Host 'Tentando instalar Microsoft Edge WebView2 Runtime via winget...'
    & $winget.Source install --id Microsoft.EdgeWebView2Runtime --exact --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'Comando de instalacao do WebView2 concluido.' -ForegroundColor Green
    } else {
        Write-Host "winget retornou codigo $LASTEXITCODE. Verifique a instalacao manualmente." -ForegroundColor Yellow
    }
}

function Add-RemoteHelpFirewallRule {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$Program
    )

    $existing = Get-NetFirewallRule -DisplayName $Name -ErrorAction SilentlyContinue
    if ($existing) {
        Set-NetFirewallRule -DisplayName $Name -Enabled True -Action Allow -Direction Outbound -Profile Domain,Private,Public -ErrorAction SilentlyContinue
        Write-Host "Regra ja existente, habilitada: $Name" -ForegroundColor Green
    } else {
        New-NetFirewallRule `
            -DisplayName $Name `
            -Description 'Remote Help - permitir comunicacao de saida HTTPS/TCP 443' `
            -Direction Outbound `
            -Action Allow `
            -Profile Domain,Private,Public `
            -Protocol TCP `
            -RemotePort 443 `
            -Program $Program `
            -Enabled True `
            -ErrorAction SilentlyContinue | Out-Null
        Write-Host "Regra criada: $Name" -ForegroundColor Green
    }
}

function Test-Endpoint443 {
    param([Parameter(Mandatory)] [string]$HostName)

    Write-Host "`nEndpoint: $HostName"
    try {
        $dns = Resolve-DnsName -Name $HostName -Type A -ErrorAction Stop
        $addresses = ($dns | Where-Object Type -eq 'A' | Select-Object -ExpandProperty IPAddress) -join ', '
        Write-Host "  DNS: OK ($addresses)" -ForegroundColor Green
    } catch {
        Write-Host "  DNS: FALHA - $($_.Exception.Message)" -ForegroundColor Red
    }

    try {
        $tcp = Test-NetConnection -ComputerName $HostName -Port 443 -InformationLevel Detailed -WarningAction SilentlyContinue
        if ($tcp.TcpTestSucceeded) {
            Write-Host '  TCP 443: OK' -ForegroundColor Green
        } else {
            Write-Host '  TCP 443: FALHA' -ForegroundColor Red
        }
    } catch {
        Write-Host "  TCP 443: erro no teste - $($_.Exception.Message)" -ForegroundColor Red
    }
}

if (-not (Test-IsAdministrator)) {
    Write-Host 'ERRO: abra o PowerShell como Administrador e execute novamente.' -ForegroundColor Red
    try { Stop-Transcript | Out-Null } catch {}
    exit 1
}

Write-Section 'Preparacao'
Write-Host "Computador: $env:COMPUTERNAME"
Write-Host "Usuario: $env:USERDOMAIN\$env:USERNAME"
Write-Host "Relatorio: $reportPath"

Write-Section 'Requisito WebView2'
Install-WebView2IfNeeded
Write-Host 'Estado final do WebView2:'
$webview2Final = @(Get-WebView2Installation)
if ($webview2Final.Count -gt 0) {
    $webview2Final | Format-Table -AutoSize
} else {
    Write-Host 'NAO CONFIRMADO' -ForegroundColor Yellow
}

Write-Section 'Arquivos do Remote Help'
$remoteHelpDir = Join-Path $env:ProgramFiles 'Remote help'
$remoteHelpFiles = @(
    (Join-Path $remoteHelpDir 'RemoteHelp.exe'),
    (Join-Path $remoteHelpDir 'RHService.exe'),
    (Join-Path $remoteHelpDir 'RemoteHelpRDP.exe')
)

$remoteHelpFiles | ForEach-Object {
    $exists = Test-Path $_
    if ($exists) {
        $item = Get-Item $_ -ErrorAction SilentlyContinue
        Write-Host "OK      $($_) | Versao: $($item.VersionInfo.ProductVersion)" -ForegroundColor Green
    } else {
        Write-Host "AUSENTE $_" -ForegroundColor Yellow
    }
}

Write-Section 'Firewall'
$ruleNames = @(
    'Remote Help - RemoteHelp.exe - Outbound 443',
    'Remote Help - RHService.exe - Outbound 443',
    'Remote Help - RemoteHelpRDP.exe - Outbound 443'
)

for ($i = 0; $i -lt $remoteHelpFiles.Count; $i++) {
    Add-RemoteHelpFirewallRule -Name $ruleNames[$i] -Program $remoteHelpFiles[$i]
}

Write-Host '`nRegras Remote Help encontradas:'
Get-NetFirewallRule -DisplayName 'Remote Help -*' -ErrorAction SilentlyContinue |
    Get-NetFirewallPortFilter -ErrorAction SilentlyContinue |
    Select-Object Name, Protocol, RemotePort | Format-Table -AutoSize

Write-Section 'Perfil e proxy'
Get-NetConnectionProfile -ErrorAction SilentlyContinue |
    Select-Object InterfaceAlias, NetworkCategory, IPv4Connectivity, IPv6Connectivity |
    Format-Table -AutoSize

Write-Host 'Configuracao WinHTTP:'
netsh winhttp show proxy

Write-Section 'Conectividade Remote Help'
$endpoints = @(
    'remotehelp.microsoft.com',
    'remoteassistance.support.services.microsoft.com',
    'remoteassistanceprodacs.communication.azure.com'
)
foreach ($endpoint in $endpoints) {
    Test-Endpoint443 -HostName $endpoint
}

Write-Section 'Eventos recentes do Remote Help'
$logName = 'Microsoft-Windows-RemoteHelp/Operational'
$logExists = Get-WinEvent -ListLog $logName -ErrorAction SilentlyContinue
if ($logExists) {
    $events = Get-WinEvent -FilterHashtable @{ LogName = $logName; StartTime = (Get-Date).AddHours(-2) } -MaxEvents 100 -ErrorAction SilentlyContinue
    if ($events) {
        $events |
            Select-Object TimeCreated, Id, LevelDisplayName, Message |
            Format-List
    } else {
        Write-Host 'Nenhum evento nas ultimas 2 horas.'
    }
} else {
    Write-Host "Log nao encontrado: $logName" -ForegroundColor Yellow
}

Write-Section 'Resumo'
Write-Host '1. Se DNS ou TCP 443 falhar: investigar DNS, firewall, proxy ou inspecao SSL.'
Write-Host '2. Se os arquivos estiverem ausentes: reparar/reinstalar o Remote Help.'
Write-Host '3. Se o evento 13 continuar com 0x80070490: anexar este relatorio e os logs de %LOCALAPPDATA%\Temp ao chamado.'
Write-Host "`nRelatorio salvo em: $reportPath" -ForegroundColor Green

try { Stop-Transcript | Out-Null } catch {}
