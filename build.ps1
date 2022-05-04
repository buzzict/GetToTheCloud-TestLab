# Import the functions
Import-Module '/Users/bjorn/github/powershell/Azure Deployment/functions.psm1'

Connect-AzAccount

# Stop displaying warning messages from the Az module
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

# Credentials
$userName = "Labadmin"
$password = ConvertTo-SecureString "Welkom01!!" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($userName, $password)

# Import JSON configuration file 
$jsonPrompt = Read-Host -Prompt 'Enter the full file path of the configuration file'
try {
    $json = Get-Content $jsonPrompt | ConvertFrom-Json
}
catch {
    Write-Host "Configuration file could not be found. Please enter the correct full path"
    Exit
}

# Get the public IP Address from where the script is run
$remoteAddress = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content

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
            $fileUri = "https://storageaccountbpbjoac05.blob.core.windows.net/scripts/Set-PowerShellRemoting.ps1"
            $script = 'Set-PowerShellRemoting.ps1'

            Add-ScriptExtension -FileUri $fileUri -Script $script -ResourceGroupName $json.resourceGroupName -VMName $machine.vmName -LocationName $json.locationName
        }
        "ExchangeServer" { 
            # Add a new script extension to the VM
            $fileUri = "https://storageaccountbpbjoac05.blob.core.windows.net/scripts/Set-PowerShellRemoting.ps1"
            $script = 'Set-PowerShellRemoting.ps1'

            Add-ScriptExtension -FileUri $fileUri -Script $script -ResourceGroupName $json.resourceGroupName -VMName $machine.vmName -LocationName $json.locationName
         }
        "Client" {  }
        Default {}
    }
}
