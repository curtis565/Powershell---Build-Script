$liscensekey = <insert server activation key>

Read-Host -prompt "Prelimary Tasks Before You Run The Script!
1. Run Sysprep under C:\Windows\system32\Sysprep
2. Make Sure Interfaces have been added in VMware

If these steps have been done hit enter to continue...
"
#Start Transcription Log
$logfilepath = "C:\ScriptResults"
Start-Transcript -path $logfilepath

#Default Hostname of VM template for
$tfhostname = Get-WMIObject Win32_ComputerSystem | Select-Object -ExpandProperty name

#Input for  New Hostname
$hostname = Read-host -prompt "Hostname of New Server"

#Input for Date and Time
$date = Read-Host -prompt "Todays Date (Example : 12/2/2014)"
$daycycle = Read-Host -prompt "Time of Day AM or PM (Example: PM)"
$time = Read-Host -prompt "Time of Day in Hours (Example 8:30)"

#Set Date and Time
Set-Date -date "$date $time $daycycle"

#Input for IP Configuration Disabled
Write-Host -foreground Green "List of Interfaces"
netsh interface ipv4 show interfaces
$interfacename = Read-host -prompt "Name of Interface to Configure (Example: Ethernet)"
$ipaddress = Read-host -prompt "IP Address of New Server (Example: 192.168.1.10)"
$subnet= Read-host -prompt "Subnet of New Server (Example: 24)"
$gateway = Read-host -prompt "Default Gateway of New Server (Example: 192.168.1.1)"

#Input for DNS Configuration disabled
$dns1 = Read-host -prompt "DNS Server 1 (Example: 172.30.3.35)" 
$dns2 = Read-host -prompt "DNS Server 2 (Example: 172.30.83.35)"

#Timestamping of Files
$title = "File Timestamping"
$message = " Enable or Disable File Timestamping (Select Disable Unless This Will Be a Fileserver)"

$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Enable"

$no = New-Object System.Management.Automation.Host.ChoiceDescription "&Disable"

$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

$result = $host.ui.PromptForChoice($title, $message, $options, 1) 

switch ($result)
    {
        0 {"Enabled."}
        1 {"Disabled."
        fsutil behavior set disablelastaccess 1
        }
    }

#Add Windows Features for Server
Add-WindowsFeature SNMP-Service -IncludeAllSubFeature
Add-WindowsFeature RSAT-SNMP
Add-WindowsFeature Desktop-Experience

#Rename Server
Rename-Computer $hostname

#Turns off Internet Explorer Enhanced Security
$AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
$UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
Stop-Process -Name Explorer
Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
    
#Turn of UAC
New-ItemProperty -Path HKLM:Software\Microsoft\Windows\CurrentVersion\policies\system -Name EnableLUA -PropertyType DWord -Value 0 -Force

#Activate Server 2012 R2
slmgr /upk
start-sleep -s 5
slmgr /cpky
start-sleep -s 5
slmgr -ipk $liscensekey
#slmgr -ato

#Disable Windows Auto Update
New-Item HKLM:\SOFTWARE\Policies\Microsoft\Windows -Name WindowsUpdate
start-sleep -s 2
New-Item HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -Name AU
start-sleep -s 2
New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -Name NoAutoUpdate -Value 1

#Disable Windows Firewall
Set-NetFirewallProfile -Profile Domain -Enabled False
Set-NetFirewallProfile -Profile Private -Enabled False

#Enable Remote Desktop with Net Level Authentication
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 1

#Ip Configuration Disabled
Set-NetIPinterface -dhcp disable
Disable-NetAdapterBinding -name $interfacename -ComponentID ms_rspndr
Disable-NetAdapterBinding -name $interfacename -ComponentID ms_lltdio
Disable-NetAdapterBinding -name $interfacename -ComponentID ms_implat
Disable-NetAdapterBinding -name $interfacename -ComponentID ms_tcpip6
Disable-NetAdapterBinding -name $interfacename -ComponentID ms_pacer
Set-DnsClient -InterfaceAlias $interfacename -UseSuffixWhenRegistering 1
New-NetIPAddress –InterfaceAlias $interfacename –IPAddress $ipaddress –PrefixLength $subnet -DefaultGateway $gateway

#DNS Configuration
Set-DnsClientServerAddress -InterfaceAlias $interfacename -ServerAddresses $dns1 , $dns2

#Rename Admin Account on Local Server
$servicetag = (gwmi win32_bios).SerialNumber

$admin=[adsi]"WinNT://./Administrator,user" 
$admin.psbase.rename("adm4ahfc")

#Enable Reliability Monitoring
Set-ItemProperty HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Reliability_Analysis -name WMIEnable -Value 1

#Power configuration
powercfg -h off

#Initialize and correctly label Swap Drive as S:
Initialize-Disk 1
Set-Partition -DriveLetter E -NewDriveLetter S

#relabel DVD Drive to X:
$drv = Get-WmiObject win32_volume -filter 'DriveLetter = "D:"'
$drv.DriveLetter = "X:"
$drv.Put() | out-null

#Relabel Drive Descriptions
Set-Volume -DriveLetter C -NewFileSystemLabel "OS"
Set-Volume -DriveLetter S -NewFileSystemLabel "Swap"

#Final Message to User
Read-Host -prompt "Some items will still need to be configured"
#Stop Logging of script
Stop-Transcript
Write-Host -foreground Green " Script Log Saved to C:\ScriptResults.txt "

#Cleanes Up Script
function Delete () {
$Invocation = (Get-Variable MyInvocation -Scope 1).Value
$Path = $Invocation.MyCommand.Path
Write-Host $Path
Remote-Item $Path
Write-Host "Delete"
}
Delete

#Final Restart
Restart-Computer
