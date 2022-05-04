#username & password

## getting credentials for virtual machines
$Username = "LabAdmin"
$Password = "Gghewakleqq01!" | ConvertTo-SecureString -Force -AsPlainText
$Credential = New-Object -TypeName PSCredential -ArgumentList ($Username, $Password)



##########################################################################################################################################################
# DO NOT EDIT BELOW !!!!                                                                                                                                 #
##########################################################################################################################################################

## installing Azure Module in Powershell 7.1.4
#Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force
$Time = Get-Date
Write-Host "[INFO] Start time of script $($Time)"

Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

## connecting to Azure
Connect-AzAccount -InformationAction SilentlyContinue | out-Null

## creating network
$LocationName = "westeurope"
$ResourceGroupName = "GetToTheCloudTestLab"
$VMSize = "Standard_B2s"
$NetworkName = "GetToTheCloud-TestLab"
$SubnetName = "TestLab"
$SubnetAddressPrefix = "10.10.0.0/24"
$VnetAddressPrefix = "10.10.0.0/24"

## creating resource group
Try {
    $newGroup = New-AzResourceGroup -Name $ResourceGroupName -Location $LocationName -InformationAction SilentlyContinue
    Write-host "[SUCCESS] Resource Group is created with the name $($ResourceGroupName)" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Creating Resource group" -ForegroundColor Red
}

$SingleSubnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix
$Vnet = New-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet


function New-TestLabVirtualMachine {
    # Parameter help description
    param ([string]$ComputerName, [string]$VMName, [string]$PublisherName, [string]$Offer, [string]$Skus)

    $NICName = -join ("NIC-", $VMName)
    $NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $Vnet.Subnets[0].Id 
    $VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
    $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
    $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
    $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $PublisherName -Offer $Offer -Skus $Skus -Version latest
    $VirtualMachine = Set-AzVMBootDiagnostic -VM $VirtualMachine -Disable
    Try {
        Write-Host "[INFO] Creating a vm with the name $($VMName)"
        $NewVM = New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine
    }
    Catch {
        Write-Host "[ERROR] Something went wrong creating vm: $($Vmname)" -ForegroundColor Red
    }
}
Function Add-TestLabPublicIP {
    param ([string]$VMName, [string]$NICName, [string]$ResourceGroupName, [string]$NetworkName)

    $NewIP = New-AzPublicIpAddress -Name "$($VMName)PublicIP" -ResourceGroupName $ResourceGroupName -AllocationMethod Dynamic -Location $LocationName -InformationAction SilentlyContinue | out-Null

    $vnet = Get-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -InformationAction SilentlyContinue 
    $subnet = Get-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $vnet -InformationAction SilentlyContinue | out-Null
    $NicName = (Get-AzNetworkInterface | where-Object { $_.Name -like "*$vmname*" }).Name
    $nic = Get-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -InformationAction SilentlyContinue | out-Null
    $pip = Get-AzPublicIpAddress -Name "$($VMName)PublicIP" -ResourceGroupName $ResourceGroupName -InformationAction SilentlyContinue | out-Null
    $nic | Set-AzNetworkInterfaceIpConfig -Name ipconfig1 -PublicIPAddress $pip -Subnet $subnet -InformationAction SilentlyContinue | out-Null
    $nic | Set-AzNetworkInterface -InformationAction SilentlyContinue | out-Null
}

$IP = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content

## create domain controller server
$ComputerName = "DC01"
$VMName = "DC01"
$PublisherName = "MicrosoftWindowsServer"
$Offer = "WindowsServer"
$Skus = "2019-datacenter-gensecond"
$NICName = -join ("NIC-", $VMName)

New-TestLabVirtualMachine -ComputerName $Computername -VMName $VMName -PublisherName $PublisherName -Offer $Offer -Skus $Skus  | out-Null
$Check = Get-AzVM -Name $VMName
if ($Check) {
    Write-Host "[SUCCESS] Virtual Machine with the name $($VMName) is created" -ForegroundColor Green
}
else {
    Write-Host "[ERROR] Something went wrong creating a Virtual Machine with the name $($VMName)" -ForegroundColor Red
    break
}
Add-TestLabPublicIP -VMName $Vmname -ResourceGroupName $ResourceGroupName -NICName $NicName -NetworkName $NetworkName | out-Null
$SecGroupname = -Join ($vmname, "NetworkSecurityGroup")
try {
    $newGroup = New-AZNetworkSecurityGroup -Name $SecGroupname -ResourceGroupName $ResourceGroupName -Location $LocationName -InformationAction SilentlyContinue
    Write-Host "[SUCCESS] Network Security group with the name $($SecGroupname) is created" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Something went wrong creating a Network Security group with the name $($SecGroupname)" -ForegroundColor RED
    break
}
$NSG = Get-AZNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $SecGroupname -InformationAction SilentlyContinue
$vNIC = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name $NicName -InformationAction SilentlyContinue
$vNIC.NetworkSecurityGroup = $NSG
try {
    $vNIC | Set-AzNetworkInterface -InformationAction SilentlyContinue | out-Null
    Write-Host "[SUCCESS] $($SecGroupname) is set to $($NicName)" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] There was a problem setting $($SecGroupname) to $($NicName)" -ForegroundColor Red
    break
}
    
$nsg | Add-AzNetworkSecurityRuleConfig -Name WINRM -Description "Allow WINRM port" -Access Allow `
    -Protocol * -Direction Inbound -Priority 100 -SourceAddressPrefix $IP -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 5985 -InformationAction SilentlyContinue | out-Null
        
$nsg | Set-AzNetworkSecurityGroup -InformationAction SilentlyContinue | out-Null

## create exchange server
$ComputerName = "EX01"
$VMName = "EX01"
$PublisherName = "MicrosoftWindowsServer"
$Offer = "WindowsServer"
$Skus = "2019-datacenter-gensecond"
$NICName = -join ("NIC-", $VMName)

New-TestLabVirtualMachine -ComputerName $Computername -VMName $VMName -PublisherName $PublisherName -Offer $Offer -Skus $Skus  | out-Null
$Check = Get-AzVM -Name $VMName
if ($Check) {
    Write-Host "[SUCCESS] Virtual Machine with the name $($VMName) is created" -ForegroundColor Green
}
else {
    Write-Host "[ERROR] Something went wrong creating a Virtual Machine with the name $($VMName)" -ForegroundColor Red
}
Add-TestLabPublicIP -VMName $Vmname -ResourceGroupName $ResourceGroupName -NICName $NicName -NetworkName $NetworkName | out-Null
$SecGroupname = -Join ($vmname, "NetworkSecurityGroup")
try {
    $newGroup = New-AZNetworkSecurityGroup -Name $SecGroupname -ResourceGroupName $ResourceGroupName -Location $LocationName -InformationAction SilentlyContinue
    Write-Host "[SUCCESS] Network Security group with the name $($SecGroupname) is created" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Something went wrong creating a Network Security group with the name $($SecGroupname)" -ForegroundColor RED
}
$NSG = Get-AZNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $SecGroupname -InformationAction SilentlyContinue
$vNIC = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name $NicName -InformationAction SilentlyContinue
$vNIC.NetworkSecurityGroup = $NSG
try {
    $vNIC | Set-AzNetworkInterface -InformationAction SilentlyContinue | out-Null
    Write-Host "[SUCCESS] $($SecGroupname) is set to $($NicName)" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] There was a problem setting $($SecGroupname) to $($NicName)" -ForegroundColor Red
}
$nsg | Add-AzNetworkSecurityRuleConfig -Name WINRM -Description "Allow WINRM port" -Access Allow `
    -Protocol * -Direction Inbound -Priority 100 -SourceAddressPrefix $IP -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 5985 -InformationAction SilentlyContinue | out-Null
$nsg | Add-AzNetworkSecurityRuleConfig -Name SMTP -Description "Allow SMTP port" -Access Allow `
    -Protocol * -Direction Inbound -Priority 101 -SourceAddressPrefix "*" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 25  -InformationAction SilentlyContinue | out-Null
$nsg | Set-AzNetworkSecurityGroup -InformationAction SilentlyContinue | out-Null


## create windows 11 
$ComputerName = "WIN11"
$VMName = "WIN11"
$PublisherName = "microsoftwindowsdesktop"
$Offer = "windows-11"
$Skus = "win11-21h2-pron"
$NICName = -join ("NIC-", $VMName)

New-TestLabVirtualMachine -ComputerName $Computername -VMName $VMName -PublisherName $PublisherName -Offer $Offer -Skus $Skus  | out-Null
$Check = Get-AzVM -Name $VMName
if ($Check) {
    Write-Host "[SUCCESS] Virtual Machine with the name $($VMName) is created" -ForegroundColor Green
}
else {
    Write-Host "[ERROR] Something went wrong creating a Virtual Machine with the name $($VMName)" -ForegroundColor Red
}
Add-TestLabPublicIP -VMName $Vmname -ResourceGroupName $ResourceGroupName -NICName $NicName -NetworkName $NetworkName | out-Null
$SecGroupname = -Join ($vmname, "NetworkSecurityGroup")
try {
    $newGroup = New-AZNetworkSecurityGroup -Name $SecGroupname -ResourceGroupName $ResourceGroupName -Location $LocationName -InformationAction SilentlyContinue
    Write-Host "[SUCCESS] Network Security group with the name $($SecGroupname) is created" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Something went wrong creating a Network Security group with the name $($SecGroupname)" -ForegroundColor RED
}
$NSG = Get-AZNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $SecGroupname -InformationAction SilentlyContinue 
$vNIC = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name $NicName -InformationAction SilentlyContinue 
$vNIC.NetworkSecurityGroup = $NSG
try {
    $vNIC | Set-AzNetworkInterface -InformationAction SilentlyContinue | out-Null
    Write-Host "[SUCCESS] $($SecGroupname) is set to $($NicName)" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] There was a problem setting $($SecGroupname) to $($NicName)" -ForegroundColor Red
}
        
Try {
    Write-host "[INFO] adding security rule to $($SecGroupname)"
    $nsg | Add-AzNetworkSecurityRuleConfig -Name RDP -Description "Allow RDP port" -Access Allow `
        -Protocol * -Direction Inbound -Priority 100 -SourceAddressPrefix $IP -SourcePortRange * `
        -DestinationAddressPrefix * -DestinationPortRange 3389 -InformationAction SilentlyContinue | out-Null
    Write-Host "[SUCCESS] security rule is added to $($SecGroupname)" -ForegroundColor Green
}
Catch {
    Write-Host "[ERROR] there was a problem adding a security rule to $($SecGroupname)" -ForegroundColor Red
}

$nsg | Set-AzNetworkSecurityGroup -InformationAction SilentlyContinue | out-Null

#region Azure VM Extention

$Time = Get-Date
Write-Host "[INFO] End time of script $($Time)"