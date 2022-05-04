$DomainName = "GetToTheCloud.local"
$DomainRecovery = "R3C0verP@ssw0rd!"
$DomainRecovery = ConvertTo-SecureString $DomainRecovery -AsPlainText -Force
$NetBiosName = $DomainName.Split(".")[0]
$DNS = "127.0.0.1", "8.8.8.8"
Set-TimeZone -id "W. Europe Standard Time"

# #setting static ip
$Adapter = Get-NetAdapter
$Adapter = $Adapter | Get-NetIPConfiguration
$IP = $Adapter.IPv4Address.IpAddress
$Gateway = $Adapter.IPv4DefaultGateway.Nexthop
$IPType = $Adapter.IPv4DefaultGateway.AddressFamily
$Mask = $Adapter.IPv4Address.PrefixLength

If (($adapter | Get-NetIPConfiguration).IPv4Address.IPAddress) {
    $adapter | Remove-NetIPAddress -AddressFamily $IPType -Confirm:$false
}
If (($adapter | Get-NetIPConfiguration).Ipv4DefaultGateway) {
    $adapter | Remove-NetRoute -AddressFamily $IPType -Confirm:$false
}

$Adapter | New-NetIPAddress -AddressFamily $IPType -IPAddress $IP -PrefixLength $Mask -DefaultGateway $Gateway 
$adapter | Set-DnsClientServerAddress -ServerAddresses $DNS

#installing prerequisites
Write-Host "[INFO] Installing AD Domain Services"
Add-WindowsFeature -Name "ad-domain-services" -IncludeAllSubFeature -IncludeManagementTools | out-Null
Write-Host "[SUCCESS] Domain Services installed"
Write-Host "[INFO] Installing DNS Services"
Add-WindowsFeature -Name "dns" -IncludeAllSubFeature -IncludeManagementTools | out-Null
Write-Host "[SUCCESS] DNS Services installed"
Write-Host "[INFO] Installing Group Policy Management installed"
Add-WindowsFeature -Name "gpmc" -IncludeAllSubFeature -IncludeManagementTools | out-Null
Write-Host "[SUCCESS] Group Policy Management installed"
Write-Host "[INFO] Installing RSAT-AD-Tools installed"
Add-WindowsFeature -Name "RSAT-AD-Tools" | out-Null
Write-Host "[SUCCESS] RSAT-AD-Tools installed"

Write-Host "[INFO] Installing Active Directory"
Import-Module ADDSDeployment
Install-ADDSForest -CreateDnsDelegation:$false -SafeModeAdministratorPassword $DomainRecovery -DatabasePath "C:\Windows\NTDS" -DomainMode "WinThreshold" -DomainName "$DomainName" -DomainNetbiosName "$NetBiosName" -ForestMode "WinThreshold" -InstallDns:$true -LogPath "C:\Windows\NTDS" -NoRebootOnCompletion:$false -SysvolPath "C:\Windows\SYSVOL" -Force:$true  | out-Null
Write-Host "[SUCCESS] Active Directory Installed for domain $DOmainName" 
