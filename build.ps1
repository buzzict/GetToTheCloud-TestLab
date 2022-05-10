# Import the functions
$ModuleFile = "$ENV:TEMP\GetToTheCloud.psm1"
$Module = (Invoke-WebRequest -uri "https://raw.githubusercontent.com/buzzict/GetToTheCloud-TestLab/main/functions.psm1" -UseBasicParsing).Content | Out-File $ModuleFile
Import-Module $ModuleFile

Connect-AzAccount

# Get the public IP Address from where the script is run
$remoteAddress = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content

# checking azure location close by and if eligible
## current connection

# $regions = Get-AZLocation
# $locations = $regions | Select-Object displayName,latitude,longitude | Sort-Object displayName

# $request = (Invoke-WebRequest -Uri  https://ipapi.co/$remoteAddress/json).Content | ConvertFrom-Json
# $latitude = $request.lat
# $longitude = $request.lon

# $locations = (Invoke-WebRequest -uri "https://raw.githubusercontent.com/buzzict/GetToTheCloud-TestLab/main/locations.json" -UseBasicParsing).Content | ConvertFrom-Json

# $hash = [ordered]@{
#     latitude="$latitude";
#     longitude="$longitude";
#     locations=@($locations)
# }

# $body = $hash | ConvertTo-Json -Depth 100

# $uri = 'https://azureregion.azurewebsites.net/api/nearestRegionFromIp'
# Invoke-RestMethod -Method Put -Uri $uri -Body $body

# Stop displaying warning messages from the Az module
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"



# Import JSON configuration file 
$jsonPrompt = Read-Host -Prompt 'Enter the URL of the configuration file'
try {
    $Json = Invoke-WebRequest $jsonPrompt -UseBasicParsing |Out-file "$ENV:TEMP\input.json"
    $json = Get-Content "$ENV:TEMP\input.json" | ConvertFrom-Json
}
catch {
    Write-Host "Configuration file could not be found. Please enter the correct full path"
    Exit
}

$username = $json.UserName
$Cred = $json.Password | ConvertTo-SecureString -Force -AsPlainText
$Credential = New-Object -TypeName PSCredential -ArgumentList ($Username, $Cred)
$DomainName = $json.DomainName
$Domain = $DomainName.Split(".")[0]
$DomainUser = $domain + "\" + $Username
$DomainCredential = New-Object -TypeName PSCredential -ArgumentList ($DomainUser, $Cred)



# Check if the resource group is already present. If not, create a new resource group.
try {
    Get-AzResourceGroup -Name $json.resourceGroupName -ErrorAction Stop
    Write-Host "[WARNING] - Resource group already exists ($($json.resourceGroupName))"
}
catch {
    New-AzResourceGroup -Name $json.resourceGroupName -Location $json.locationName | Out-Null
    Write-Host "[SUCCESS] - Resource group is created ($($json.resourceGroupName))"
}

# Create a new subnet and Azure Virtual Network when it does not exist
$vnet = Get-AzVirtualNetwork -Name $json.vnetName
if ($vnet) {
    Write-Host "[WARNING] - Virtual network already exists ($($json.vnetName))"
}

else {
    # Process each subnet that has been defined in the JSON file and add it to the config for the new virtual network
    foreach ($subnet in $json.subnets) {
        $subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $subnet.subnetName -AddressPrefix $subnet.subnetPrefix
        Write-Output "[INFO] - Subnet is added to the virtual network configuration ($($subnet.subnetName))"
    }

    # Create a new virtual network and include the configured subnets from the previous cmdlet
    $vnet = New-AzVirtualNetwork -Name $json.vnetName -ResourceGroupName $json.resourceGroupName -Location $json.locationName -AddressPrefix $json.vnetAddressPrefix -Subnet $subnetConfig
    Write-Host "[SUCCES] - Virtual network is created ($($json.vnetName))"
}

# Process every machine that is found in the JSON file to speed up the virtual machine deployment
foreach ($machine in $json.machines) {

    $vmPublicIP = $machine.vmName + '-ip'
    $vmNicName = $machine.vmName + '-nic'

    $pip = New-AzPublicIpAddress -Name $vmPublicIP -ResourceGroupName $json.resourceGroupName -Location $json.locationName -AllocationMethod Dynamic
    $nic = New-AzNetworkInterface -Name $vmNicName -ResourceGroupName $json.resourceGroupName -Location $json.locationName -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id

    # Create a public IP address, a network interface card and a Network Security Group
    switch ($machine.type) {
        "DomainController" { $nsg = New-TestLabNSG -LocationName $json.locationName -RemoteAddress $remoteAddress -Type 'DomainController' }
        "ExchangeServer" { $nsg = New-TestLabNSG -LocationName $json.locationName -RemoteAddress $remoteAddress -Type 'ExchangeServer' }
        "Client" { $nsg = New-TestLabNSG -LocationName $json.locationName -RemoteAddress $remoteAddress -Type 'Client' }
        Default {}
    }

    # Assign Network Security Group to the network interface card
    $nic.NetworkSecurityGroup = $nsg
    $nic | Set-AzNetworkInterface

    # Create a new virtual machine in Microsoft Azure
    New-TestLabVM -Credential $credential -VMName $machine.vmName -VMSize $machine.vmSize -NICID $nic.Id -Skus $machine.skus -Offer $machine.offer -ResourceGroupName $json.resourceGroupName -LocationName $json.locationName -PublisherName $machine.publisherName
}

foreach ($machine in $json.machines) {
    # Based on the type of the virtual machine, execute a different script extension
    switch ($machine.type) {
        "DomainController" { 
            # Add a new script extension to the VM
            $fileUri = $json.UrlPSRemote
            $script = 'Set-PowerShellRemoting.ps1'

            Add-ScriptExtension -FileUri $fileUri -Script $script -ResourceGroupName $json.resourceGroupName -VMName $machine.vmName -LocationName $json.locationName
        }
        "ExchangeServer" { 
            # Add a new script extension to the VM
            $fileUri = $json.UrlPSRemote
            $script = 'Set-PowerShellRemoting.ps1'

            Add-ScriptExtension -FileUri $fileUri -Script $script -ResourceGroupName $json.resourceGroupName -VMName $machine.vmName -LocationName $json.locationName
        }
        "Client" {  }
        Default {}
    }
}

foreach ($machine in $json.machines) {
    # Based on the type of the virtual machine, execute a ps1 script via WINRM
    switch ($machine.type) {
        "DomainController" { 
            # Add a new script extension to the VM
            $VMName = $json.vmname
            $Pip = $VMName + "PublicIP"
            $fileUri = "https://raw.githubusercontent.com/GetToThe-Cloud/GetToTheCloud-Lab/main/01-DC-SetupDomainController.ps1"
            $IP = (Get-AZPublicIPAddress -Name $Pip).IpAddress
            
            Write-Host "[INFO] Connecting to $($VMName) with IP $IP for installing Domain Controller"
            Invoke-Command -Computername $IP -ScriptBlock {
                Param ($fileuri)
                $OutputFolder = "C:\Temp"
                if (Test-Path -path $OutputFolder) {
                    #do nothing
                }
                else {
                    $Location = $OutputFolder.Split("\")
                    New-Item -Path "$($Location[0])\" -Name $Location[1] -ItemType Directory
                }
            
                $Script = (Invoke-WebRequest -Uri $fileUri -UseBasicParsing).Content
                $Script | Out-File C:\Temp\script.ps1
                powershell C:\temp\script.ps1
                Remove-Item C:\Temp\script.ps1 -force
            } -Credential $Credential -ArgumentList $fileUri
            $FileUri = "https://raw.githubusercontent.com/GetToThe-Cloud/GetToTheCloud-Lab/main/03-DC-ConfigureActiveDirectory.ps1"

            Write-Host "[INFO] Connecting to $($VMName) with IP $IP for Creating Domain structure"
            Invoke-Command -Computername $IP -ScriptBlock {
                Param ($fileuri)
                $OutputFolder = "C:\Temp"
                if (Test-Path -path $OutputFolder) {
                    #do nothing
                }
                else {
                    $Location = $OutputFolder.Split("\")
                    New-Item -Path "$($Location[0])\" -Name $Location[1] -ItemType Directory
                }

                $Script = (Invoke-WebRequest -Uri $fileUri -UseBasicParsing).Content
                $Script | Out-File C:\Temp\script.ps1
                powershell C:\temp\script.ps1
                Remove-Item C:\Temp\script.ps1 -force
            } -Credential $DomainCredential -ArgumentList $fileUri
        }
        "ExchangeServer" { 
            # Add a new script extension to the VM
            $VMName = $json.Vname
            $Pip = $VMName + "PublicIP"
            $fileUri = "https://raw.githubusercontent.com/GetToThe-Cloud/GetToTheCloud-Lab/main/02-EXC-DownloadExchange.ps1"
            $IP = (Get-AZPublicIPAddress -Name $Pip).IpAddress
            Write-Host "[INFO] Connecting to $($VMName) with IP $IP for downloading Exchange software"
            
            Invoke-Command -Computername $IP -ScriptBlock {
                Param ($fileuri)
                $OutputFolder = "C:\Temp"
                if (Test-Path -path $OutputFolder) {
                    #do nothing
                }
                else {
                    $Location = $OutputFolder.Split("\")
                    New-Item -Path "$($Location[0])\" -Name $Location[1] -ItemType Directory
                }
                $Script = (Invoke-WebRequest -Uri $fileUri -UseBasicParsing).Content
                $Script | Out-File C:\Temp\script.ps1
                powershell C:\temp\script.ps1
                Remove-Item C:\Temp\script.ps1 -force
                $Download = (Invoke-WebRequest -uri "https://raw.githubusercontent.com/GetToThe-Cloud/GetToTheCloud-Lab/main/04-EXC-ConfigureExchange.ps1" -UseBasicParsing).Content
                $Download | Out-File C:\ExchangeDownload\04-EXC-ConfigureExchange.ps1
                $Download = (Invoke-WebRequest -uri "https://raw.githubusercontent.com/GetToThe-Cloud/GetToTheCloud-Lab/main/Scripts/Replace-OAuthCertificate.ps1" -UseBasicParsing).Content
                $Download | Out-File C:\ExchangeDownload\Replace-OAuthCertificate.ps1
                $Download = (Invoke-WebRequest -uri "https://raw.githubusercontent.com/GetToThe-Cloud/GetToTheCloud-Lab/main/Scripts/Run-HybridConfigWizard.ps1" -UseBasicParsing).Content
                $Download | Out-File C:\ExchangeDownload\Run-HybridConfigWizard.ps1
                $Download = (Invoke-WebRequest -uri "https://raw.githubusercontent.com/GetToThe-Cloud/GetToTheCloud-Lab/main/Scripts/GetToTheCloudFunctions.psm1" -UseBasicParsing).Content
                $Download | Out-File C:\ExchangeDownload\GetToTheCloudFunctions.psm1
            } -Credential $Credential -ArgumentList $fileUri

            $fileUri = "https://raw.githubusercontent.com/GetToThe-Cloud/GetToTheCloud-Lab/main/011-EXC-NetworkSettings.ps1"
            $EXIP = $IP
            Write-Host "[INFO] Connecting to $($VMName) with IP $IP for setting Network Settings Exchange server"

            Invoke-Command -Computername $IP -ScriptBlock {
                Param ($fileuri)
                $Script = ""
                $OutputFolder = "C:\Temp"
                if (Test-Path -path $OutputFolder) {
                    #do nothing
                }
                else {
                    $Location = $OutputFolder.Split("\")
                    New-Item -Path "$($Location[0])\" -Name $Location[1] -ItemType Directory
                }
                $Script = (Invoke-WebRequest -Uri $fileUri -UseBasicParsing).Content
                $Script | Out-File C:\Temp\script.ps1
                powershell C:\temp\script.ps1
                Remove-Item C:\Temp\script.ps1 -force
            } -Credential $Credential -ArgumentList $fileUri
            Write-Host "[INFO] Restarting $($Vmname) now"
            Restart-AZVM -ResourceGroupName $ResourceGroupName -Name $VMName 
        }
        "Client" {  }
        Default {}
    }
}