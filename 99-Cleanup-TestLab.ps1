#remove groups

Install-Module MSONline -Force
Install-Module ExchangeOnlineManagement -Force
Install-Module AZ -Force
Import-Module MSONline

Connect-AzAccount
Connect-ExchangeOnline
Connect-MSOLService

Set-MsolDirSyncEnabled -EnableDirSync $false -force


Get-AZAdGroup | Where-Object {$_.Displayname -like "A-*" -or $_.DisplayName -like "GG-*" -or $_.DisplayName -Like "DG-*" -or $_.DisplayName -like "UG-*"} | Remove-AzADGroup
Get-DistributionGroup | Remove-DistributionGroup -confirm:$false
Get-MSOLUser | Where-Object {$_.immutableID -ne $null} | Remove-MSOLuser -force
Get-AZResourceGroup | Where-Object {$_.ResourceGroupName -like "GetToTheCloud*"} | Remove-AZResourceGroup -Force
