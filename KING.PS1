$Host.UI.RawUI.WindowTitle = "INTERNETDEPT"

$size = New-Object System.Management.Automation.Host.Size(70,20)
$Host.UI.RawUI.BufferSize = $size
$Host.UI.RawUI.WindowSize = $size


Clear-Host

$input = Read-Host "(Y/N)"

if ($input -eq "Y" -or $input -eq "y") {

    Write-Host ""
    Write-Host "กำลังเริ่มทำงาน..." -ForegroundColor Green

# Run as Administrator
$ErrorActionPreference = 'SilentlyContinue'


$InterfaceAlias = "Ethernet"
$GameProcessName = "FiveM"
$DNSv4 = @("1.1.1.1","8.8.8.8")
$DNSv6 = @("2001:4860:4860::8888","2001:4860:4860::8844")
$MTU = 1480

$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host "Please run PowerShell as Administrator." -ForegroundColor Red
    exit 1
}

Write-Host "Applying tweaks..." -ForegroundColor Cyan

netsh int tcp set global autotuninglevel=experimental | Out-Null
netsh int tcp set global congestionprovider=ctcp | Out-Null
netsh int tcp set global rss=enabled | Out-Null
netsh int tcp set global chimney=disabled | Out-Null
netsh int tcp set global dca=enabled | Out-Null
netsh int tcp set global ecncapability=default | Out-Null
netsh int tcp set global timestamps=disabled | Out-Null
netsh int tcp set global rsc=disabled | Out-Null
netsh int tcp set global fastopen=enabled | Out-Null
netsh int tcp set heuristics disabled | Out-Null
netsh int tcp set global maxsynretransmissions=2 | Out-Null
netsh int tcp set global initialrto=1000 | Out-Null
netsh int tcp set global delayedacktimeout=100 | Out-Null
netsh int tcp set global datalinklayerretries=3 | Out-Null
netsh int tcp set global netdma=enabled | Out-Null
netsh int tcp set global minrto=100 | Out-Null
netsh int ipv4 set dynamicport tcp start=1024 num=64511 | Out-Null
netsh int ipv4 set dynamicport udp start=1024 num=64511 | Out-Null

netsh interface ipv4 set subinterface "$InterfaceAlias" mtu=$MTU store=persistent | Out-Null
netsh interface ipv6 set subinterface "$InterfaceAlias" mtu=$MTU store=persistent | Out-Null

netsh int ip set global taskoffload=enabled | Out-Null
netsh interface ipv4 set global icmpredirects=disabled | Out-Null
netsh interface ipv4 set global multicastforwarding=disabled | Out-Null
netsh interface ipv6 set global randomizeidentifiers=disabled | Out-Null
netsh interface ipv6 set privacy state=disabled | Out-Null
netsh interface ipv6 set teredo disabled | Out-Null
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DNSv4
netsh interface ipv6 set dnsservers "$InterfaceAlias" static $($DNSv6[0]) | Out-Null
netsh interface ipv6 add dnsservers "$InterfaceAlias" $($DNSv6[1]) index=2 | Out-Null

New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpNoDelay" -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpAckFrequency" -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TCPDelAckTicks" -Value 0 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpDelAckFrequency" -Value 1 -PropertyType DWord -Force | Out-Null

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class TimerResolution {
[DllImport("ntdll.dll", SetLastError=true)]
public static extern uint NtSetTimerResolution(uint DesiredResolution, bool SetResolution, ref uint CurrentResolution);
}
"@

$cur = 0
[void][TimerResolution]::NtSetTimerResolution(5000, $true, [ref]$cur)

New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -Value 0xffffffff -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -Value 0 -PropertyType DWord -Force | Out-Null
New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "GPU Priority" -Value 8
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "Priority" -Value 6
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "Scheduling Category" -Value "High"
Disable-NetAdapterPowerManagement -Name $InterfaceAlias
Enable-NetAdapterRss -Name $InterfaceAlias
Set-NetOffloadGlobalSetting -ReceiveSideScaling Enabled
Set-NetOffloadGlobalSetting -ReceiveSegmentCoalescing Disabled
Set-NetOffloadGlobalSetting -TaskOffload Enabled

Set-NetAdapterAdvancedProperty -Name $InterfaceAlias -DisplayName "Receive Buffers" -DisplayValue "8192"
Set-NetAdapterAdvancedProperty -Name $InterfaceAlias -DisplayName "Transmit Buffers" -DisplayValue "8192"
Set-NetAdapterAdvancedProperty -Name $InterfaceAlias -DisplayName "Interrupt Moderation" -DisplayValue "Disabled"
Set-NetAdapterAdvancedProperty -Name $InterfaceAlias -DisplayName "Flow Control" -DisplayValue "Disabled"
Set-NetAdapterAdvancedProperty -Name $InterfaceAlias -DisplayName "Energy Efficient Ethernet" -DisplayValue "Disabled"
Disable-NetAdapterLso -Name $InterfaceAlias
Disable-NetAdapterChecksumOffload -Name $InterfaceAlias
Disable-NetAdapterRsc -Name $InterfaceAlias
netsh interface set interface "$InterfaceAlias" admin=enabled | Out-Null

$proc = Get-Process -Name "$GameProcessName*" -ErrorAction SilentlyContinue
if ($proc) {
    foreach ($p in $proc) {
        try {
            $p.ProcessorAffinity = 0xFFF
            $p.PriorityClass = "High"
        } catch {}
    }
}


powercfg -setactive SCHEME_MIN | Out-Null

Write-Host ""
Write-Host "=== TCP Settings ===" -ForegroundColor Yellow
Get-NetTCPSetting | Format-Table -AutoSize
Write-Host ""
Write-Host "=== Offload Global Settings ===" -ForegroundColor Yellow
Get-NetOffloadGlobalSetting | Format-List
Write-Host ""
Write-Host "=== RSS Status ===" -ForegroundColor Yellow
Get-NetAdapterRss -Name $InterfaceAlias | Format-List
Write-Host ""
Write-Host "=== DNS Settings ===" -ForegroundColor Yellow
Get-DnsClientServerAddress -InterfaceAlias $InterfaceAlias | Format-Table -AutoSize
Write-Host ""
Write-Host "=== Adapter Advanced Properties ===" -ForegroundColor Yellow
Get-NetAdapterAdvancedProperty -Name $InterfaceAlias | Sort-Object DisplayName | Format-Table -AutoSize
New-Item -ItemType File -Path (Get-PSReadLineOption).HistorySavePath -Force
Write-Host ""
Write-Host "Done. Reboot recommended." -ForegroundColor Green


   
    Start-Sleep -Seconds 1
    Write-Host "รันสำเร็จ!"

}
else {
    Write-Host ""
    Write-Host "ยกเลิกการทำงาน" -ForegroundColor Red
}

Exit