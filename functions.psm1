function Add-ScriptExtension {
    param (
        [parameter(Mandatory = $true,
            HelpMessage = "Provide a string with the name of the Azure VM.")]
        [ValidateNotNullOrEmpty()]
        [string]$FileUri,

        [parameter(Mandatory = $true,
            HelpMessage = "Provide a string with the name of the Azure VM.")]
        [ValidateNotNullOrEmpty()]
        [string]$VMName,

        [parameter(Mandatory = $true,
            HelpMessage = "Provide a string with the name of the Azure VM.")]
        [ValidateNotNullOrEmpty()]
        [string]$Script,

        [parameter(Mandatory = $true,
            HelpMessage = "Provide a string with the name of the Azure VM.")]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName,

        [parameter(Mandatory = $true,
            HelpMessage = "Provide a string with the name of the Azure VM.")]
        [ValidateNotNullOrEmpty()]
        [string]$LocationName
    )

    Set-AzVMCustomScriptExtension -ResourceGroupName $ResourceGroupName `
    -VMName $VMName `
    -Location $LocationName `
    -FileUri $FileUri `
    -Run  $Script`
    -Name EnablePSRemoting
    
}

function New-TestLabVM {
    param (
        [parameter(Mandatory = $true,
            HelpMessage = "Provide a string with the name of the Azure VM.")]
        [ValidateNotNullOrEmpty()]
        [string]$VMName,

        [parameter(Mandatory = $true,
            HelpMessage = "Provide a string with the name of the Azure VM.")]
        [ValidateNotNullOrEmpty()]
        [string]$VMSize,

        [parameter(Mandatory = $true,
            HelpMessage = "Provide a string with the name of the Azure VM.")]
        [ValidateNotNullOrEmpty()]
        [PSCredential]$Credential,

        [parameter(Mandatory = $true,
            HelpMessage = "Provide a valid array object.")]
        [ValidateNotNullOrEmpty()]
        [string]$NICID,

        [parameter(Mandatory = $true,
            HelpMessage = "Provide a valid array object.")]
        [ValidateNotNullOrEmpty()]
        [string]$Skus,

        [parameter(Mandatory = $true,
            HelpMessage = "Provide a valid array object.")]
        [ValidateNotNullOrEmpty()]
        [string]$Offer,

        [parameter(Mandatory = $true,
            HelpMessage = "Provide a valid array object.")]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName,

        [parameter(Mandatory = $true,
            HelpMessage = "Provide a valid array object.")]
        [ValidateNotNullOrEmpty()]
        [string]$PublisherName,

        [parameter(Mandatory = $true,
            HelpMessage = "Provide a valid array object.")]
        [ValidateNotNullOrEmpty()]
        [string]$LocationName
    )

    $VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
    $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
    $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
    $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $PublisherName -Offer $Offer -Skus $Skus -Version latest
    New-AzVm -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine
    
}

function New-TestLabNSG {
    param (
        [parameter(Mandatory = $true,
            HelpMessage = "Provide a string with the location where the NSG needs to be created")]
        [ValidateNotNullOrEmpty()]
        [string]$LocationName,

        [parameter(Mandatory = $true,
            HelpMessage = "Provide a string with the RemoteAddress for the NSG.")]
        [ValidateNotNullOrEmpty()]
        [string]$RemoteAddress,

        [parameter(Mandatory = $true,
            HelpMessage = "Provide a string with the type of NSG that needs to be created.")]
        [ValidateSet(“DomainController”,”ExchangeServer”,”Client”)] 
        [string]$Type
    )

    # Based on the type parameter, determine what rules needs to be created in the NSG
    switch ($Type) {
        "DomainController" { 
            $rule1 = New-AzNetworkSecurityRuleConfig -Name 'WinRM HTTP' `
                -Description "Allow WinRM for PowerShell Remoting" `
                -Access Allow `
                -Protocol TCP `
                -Direction Inbound `
                -Priority 100 `
                -SourceAddressPrefix $RemoteAddress `
                -SourcePortRange * `
                -DestinationAddressPrefix * `
                -DestinationPortRange 5985 
            
            New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName `
                -Location $LocationName `
                -Name 'DC-NSG' `
                -SecurityRules $rule1
         }
        "ExchangeServer" { 
            $rule1 = New-AzNetworkSecurityRuleConfig -Name 'HTTPS' `
            -Description "Allow HTTPS for Exchange Server" `
            -Access Allow `
            -Protocol TCP `
            -Direction Inbound `
            -Priority 100 `
            -SourceAddressPrefix $RemoteAddress `
            -SourcePortRange * `
            -DestinationAddressPrefix * `
            -DestinationPortRange 443 
            
            $rule2 = New-AzNetworkSecurityRuleConfig -Name 'SMTP' `
            -Description "Allow SMTP for Exchange Server" `
            -Access Allow `
            -Protocol TCP `
            -Direction Inbound `
            -Priority 101 `
            -SourceAddressPrefix $RemoteAddress `
            -SourcePortRange * `
            -DestinationAddressPrefix * `
            -DestinationPortRange 25

            $rule1 = New-AzNetworkSecurityRuleConfig -Name 'WinRM HTTP' `
            -Description "Allow WinRM for PowerShell Remoting" `
            -Access Allow `
            -Protocol TCP `
            -Direction Inbound `
            -Priority 102 `
            -SourceAddressPrefix $RemoteAddress `
            -SourcePortRange * `
            -DestinationAddressPrefix * `
            -DestinationPortRange 5985 

            New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName `
            -Location $LocationName `
            -Name 'EXCHANGE-NSG' `
            -SecurityRules $rule1,$rule2
         }
        "Client" { 
            $rule1 = New-AzNetworkSecurityRuleConfig -Name 'RDP' `
            -Description "Allow RDP" `
            -Access Allow `
            -Protocol TCP `
            -Direction Inbound `
            -Priority 101 `
            -SourceAddressPrefix $RemoteAddress `
            -SourcePortRange * `
            -DestinationAddressPrefix * `
            -DestinationPortRange 3389

            New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName `
            -Location $LocationName `
            -Name 'CLIENT-NSG' `
            -SecurityRules $rule1
         }
    }
}