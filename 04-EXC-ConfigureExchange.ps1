$ExchangeServer = $env:Computername
$ExchangeServer = (Get-ADComputer $ExchangeServer).DNSHostname

$DomainToAdd = Read-Host "Enter external domain to add to Exchange (contoso.com)"
Get-ADForest | Set-ADForest -UPNSuffixes @{add=$DomainToAdd}
## connection to exchange
$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$ExchangeServer/Powershell -Authentication Kerberos
Import-PSSession $Session -DisableNameChecking -AllowClobber
Import-Module ActiveDirectory
# adding accepted domain

New-AcceptedDomain -Name $DomainToAdd -DomainName $DomainToAdd -DomainType Authoritative | out-Null
Set-AcceptedDomain -Identity $DomainToAdd -MakeDefault $true | out-Null
Write-Host "Added $DomainToAdd as an accepted domain"
## Getting the right OU's

$OU = Get-ADOrganizationalUnit -Filter * | Where-Object {$_.DistinguisheDName -like "OU=Personal,OU=Users*"}

#creating mailboxes
$UsersToCreate = Get-ADUser -Filter * -SearchBase $OU -properties * | Where-Object {$_.DistinguisheDName -notlike "*OU=Mail User*"}

#setting location for users
ForEach ($User in $UsersToCreate){
    Try {
        Set-ADUser $user.SamAccountname -replace @{msExchUsageLocation="NL"}
    }
    Catch {
        Write-Host "ERROR: cannot set NL as location"
    }
}

ForEach ($User in $UsersToCreate){
    try {
        Enable-Mailbox -Identity $User.SamAccountName | Out-null
        Write-Host "INFO: Created a mailbox for $($User.Displayname)" -ForegroundColor Green
    }
    Catch {
        Write-Host "ERROR: Failed to create a mailbox for $($User.Displayname)" -ForegroundColor RED
    }
    
}

#creating Mail users
$OU = Get-ADOrganizationalUnit -Filter *  | Where-Object {$_.DistinguisheDName -like "OU=Mail User*"}
$Mailusers = Get-ADUser -Filter *  -SearchBase $OU

ForEach ($Mailuser in $Mailusers){
    Try {
        $ExternalMail = $Mailuser.UserPrincipalName.Split("@")[0]+"@gmail.com"
        Enable-Mailuser -Identity $Mailuser.SamAccountName -ExternalEmailAddress $ExternalMail | Out-Null
        Write-Host "INFO: Mailuser created for $($Mailuser.Name) with $ExternalMail as Mail"
    }
    Catch {
        Write-Host "ERROR: Cannot create mailuser for $($MailUser.DisplayName)" -ForegroundColor Red
    }
}

#creating distribution groups
$OU = Get-ADOrganizationalUnit -Filter *  | Where-Object {$_. DistinguishedName -like "OU=Distribution Groups*"}
$Groups = Get-ADGroup -Filter *  -SearchBase $OU

ForEach ($Group in $groups){
    try {
        Enable-DistributionGroup -Identity $Group.Name | out-Null
        Write-Host "INFO: Distribution group with the name $($Group.Name) is created" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Problem creating a distribution group with the name $($Group.name)" -ForegroundColor red
    }
}

#creating mail-enabled security groups
$OU = Get-ADOrganizationalUnit -Filter *  | Where-Object {$_.DistinguisheDName -like "OU=Universal Security Groups*"}
$Groups = Get-ADGroup -Filter * -SearchBase $OU | where-Object {$_.Name -like "UG-Mail*"}

ForEach ($Group in $groups){
    try {
        Enable-DistributionGroup -Identity $Group.DistinguisheDName | out-Null
        Write-Host "INFO: Mail Enabled security group with the name $($Group.Name) is created" -ForegroundColor Green
        Set-DistributionGroup -Identity $Group.DistinguisheDName -HiddenFromAddressListsEnabled $true | out-Null
        Write-Host "INFO: Mail Enabled security group is hide from address list" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Problem creating a Mail Enabled security group with the name $($Group.name)" -ForegroundColor red
    }
}

#set full access permissions
 
$OU = Get-ADOrganizationalUnit -Filter *  | Where-Object {$_.DistinguisheDName -like "OU=Personal*"}
$ADUsers = Get-ADUser  -Filter * -Searchbase $OU | Where-Object {$_.DistinguishedName -notlike "*OU=Mail Users*"}
$usersToSet = "6"
$i = 1
Do {
    $user = Get-Random $ADUsers
    $userToSet = Get-Random $ADUsers

    Try {
        $set = Add-MailboxPermission -identity $user.SamAccountName -User $UserToSet.SamAccountName -AccessRights FullAccess -InheritanceType All
        Write-Host "INFO: User $($UserToSet.Name) has now Full Access permissions at mailbox $($user.Name)"
    }
    Catch {
        Write-Host "ERROR: Cannot set Full Access permissions for $($UserToSet.name) at $($User.Name) " -ForegroundColor red
    }
$i++
}
While ($i -le $usersToSet) 



#set sendas permissions
$OU = Get-ADOrganizationalUnit -Filter * | Where-Object {$_.DistinguisheDName -like "OU=Personal*"}
$ADUsers = Get-ADUser  -Filter * -Searchbase $OU | Where-Object {$_.DistinguishedName -notlike "*OU=Mail Users*"}
$usersToSet = "4"
$i = 1
Do {
    $user = Get-Random $ADUsers
    $userToSet = Get-Random $ADUsers

    Try {
        $set = Add-ADPermission -Identity $User.Name -user $UserToSet.Name -AccessRights ExtendedRight -ExtendedRights "Send As"
        #$set = Add-RecipientPermission $user.SamAccountName -AccessRights SendAs -Trustee $UserToSet
        Write-Host "INFO: User $($UserToSet.Name) has now SendAs permissions at mailbox $($user.Name)"
    }
    Catch {
        Write-Host "ERROR: Cannot set SendAs permissions for $($UserToSet.name) at $($User.Name) " -ForegroundColor red
    }
$i++
}
while ($i -le $usersToSet) 


#send connector
Try {
    new-SendConnector -Internet -Name $DomainToAdd -AddressSpaces $DomainToAdd | out-Null
    Write-Host "INFO: New-SendConnector is made for $($DomainToAdd)" -ForegroundColor Green
}
Catch {
    Write-Host "ERROR: Cannot create a new SendConnector for $($DomainToAdd)" -ForegroundColor Red
}

#setting email adres policy

New-EmailAddressPolicy -Name "Default Policy $DomainToAdd" -IncludedRecipients AllRecipients -EnabledEmailAddressTemplates "SMTP:%m@$DomainToAdd" | Out-Null
if (!(Get-EmailAddressPolicy -identity "Default Policy $DomainToAdd")){
    Write-Host "[ERROR] Address policy not created"
}
else {
    Write-Host "[INFO] Address policy created"
}
Update-EmailAddressPolicy -identity "Default Policy $DomaintoAdd"

$LocalUsers = Get-ADUser -Filter {UserPrincipalName -like '*.local'} -Properties UserPrincipalName -ResultSetSize $null

ForEach ($User in $LocalUsers){
    $userUpn= ($user.Userprincipalname).Split("@")[0]
    $userUpn = $Userupn + "@" + $DomainToAdd
    Set-ADUser $User.SamAccountName -UserPrincipalName $userupn
}

Write-Host "[WARNING] Restarting computer in 20 seconds ..."
Start-Sleep 20
Restart-Computer

#start azure ad sync

    # Import-Module ADSync
    # Start-ADSyncSyncCycle -PolicyType Delta
    # Start-sleep -seconds 2
    # While ((Get-ADSyncScheduler).SyncCycleInProgress -eq $true)
    # {
    #     Start-sleep -seconds 1
    # }
