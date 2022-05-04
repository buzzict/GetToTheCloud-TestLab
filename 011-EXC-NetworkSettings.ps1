$Username = "LabAdmin"
$Password = "Welkom01!!"
$Cred = $Password | ConvertTo-SecureString -Force -AsPlainText
$Credential = New-Object -TypeName PSCredential -ArgumentList ($Username, $Cred)
$DomainName = "GetToTheCloud.local"
$Domain = $DomainName.Split(".")[0]
$DomainUser = $domain + "\" + $Username
$DomainCredential = New-Object -TypeName PSCredential -ArgumentList ($DomainUser, $Cred)

Write-Host "[INFO] Changing pagefile to AutomaticManaged"
$pagefile = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
$pagefile.AutomaticManagedPagefile = $True
$pagefile.put() | Out-Null

#setting static ip
$Adapter = Get-NetAdapter
$Adapter = $Adapter | Get-NetIPConfiguration
$DNS = "10.10.0.4"

Write-Host "[INFO] Setting $DNS as DNS Server"
$adapter | Set-DnsClientServerAddress -ServerAddresses $DNS

# adding to domain

Try {
    Write-Host "[INFO] adding server to $($Domain)"
    Add-Computer -DomainName $DomainName -Credential $DomainCredential
    Write-Host "[SUCCESS] server is added to $($Domain)" -ForegroundColor Green
    $status = "success"
}
Catch {
    Write-Host "[ERROR] cannot add server to $($Domain)" -ForegroundColor Red
    $status = "failed"
}

If ($Status -eq "Failed"){
    $DNSServer = Get-DNSClientServerAddress -AddressFamily ipv4
}
 
