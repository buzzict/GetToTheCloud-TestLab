Do {
    $check = (Get-Service ADWS).Status
    Write-Host "Waiting for ADWS Services to be running"
    Start-Sleep 2
    
    }
    until (
    (Get-Service ADWS).Status -eq "running"
    )
     
Write-Host "[SUCCESS] Active Directory is UP" -ForegroundColor Green
Write-Host ""
Import-Module ActiveDirectory

#$AddUPN = Read-Host "Which domain "

$Company = (Get-ADDomain).NetBiosName

# Setting variables based on $Company

$Domain = "DC=$Company,DC=LOCAL"
$DomainSub= "OU=$Company,DC=$Company,DC=LOCAL"

# Variables for Groups
$DomainSecurity = "OU=Security Groups,$DomainSub"
$DomainApplication = "OU=Application Groups,$DomainSub"
$DomainLocalSecurity = "OU=Local Security Groups,$DomainSecurity"
$DomainGlobalSecurity = "OU=Global Security Groups,$DomainSecurity"
$DomainUniversalSecurity = "OU=Universal Security Groups,$DomainSecurity"
$DomainDistributionGroups = "OU=Distribution Groups,$DomainSub"


# Variables for User Accounts
$DomainUsers = "OU=Users,$DomainSub"
$DomainServiceUsers = "OU=Service Accounts,$DomainUsers"
$DomainPersonUsers = "OU=Personal,$DomainUsers"
$DomainPersonMailUsers = "OU=Mail Users,$DomainPersonUsers"
$DomainAdminUsers = "OU=Admin Accounts,$DomainUsers"

# Creating OU for groups
Write-Host "Creating OU for $Company … " -ForeGroundColor Green
New-ADOrganizationalUnit -Name $Company -Path $domain -Description "Company $Company"

Write-Host "Creating OU for Security Groups … " -ForeGroundColor Green
New-ADOrganizationalUnit -Name "Security Groups" -Path $DomainSub -Description "Security Groups for $Company"

Write-Host "Creating OU for Application Groups … " -ForeGroundColor Green
New-ADOrganizationalUnit -Name "Application Groups"  -Path $DomainSub -Description "Application Groups for $Company" 

Write-Host "Creating OU for Distribution Groups … " -ForeGroundColor Green
New-ADOrganizationalUnit -Name "Distribution Groups"  -Path $DomainSub -Description "Distribution Groups for $Company" 

Write-Host "Creating OU for Local Security Groups in Security Groups OU … " -ForeGroundColor Green 
New-ADOrganizationalUnit -Name "Local Security Groups" -Path $DomainSecurity -Description "Local Security Groups for $Company"

Write-Host "Creating OU for Global Security Groups in Security Groups OU … " -ForeGroundColor Green
New-ADOrganizationalUnit -Name "Global Security Groups" -Path $DomainSecurity -Description "Global Security Groups for $Company"

Write-Host "Creating OU for Universal Security Groups in Security Groups OU … " -ForeGroundColor Green
New-ADOrganizationalUnit -Name "Universal Security Groups" -Path $DomainSecurity -Description "Universal Security Groups for $Company"


# Creating OU for Users

Write-Host "Creating OU for Users… " -ForeGroundColor Green
New-ADOrganizationalUnit -Name "Users" -Path $DomainSub -Description "Users OU for $Company"

Write-Host "Creating OU for Service Accounts in Users … " -ForeGroundColor Green
New-ADOrganizationalUnit -Name "Service Accounts" -Path $DomainUsers -Description "Service Accounts for $Company"

Write-Host "Creating OU for Personal Accounts in Users … " -ForeGroundColor Green
New-ADOrganizationalUnit -Name "Personal" -Path $DomainUsers -Description "Personal Accounts for $Company"

Write-Host "Creating OU for Mail Users Accounts in Personal … " -ForeGroundColor Green
New-ADOrganizationalUnit -Name "Mail Users" -Path $DomainPersonUsers -Description "Mail Users Accounts for $Company"

Write-Host "Creating OU for Admin Accounts in Users … " -ForeGroundColor Green
New-ADOrganizationalUnit -Name "Admin" -Path $DomainUsers -Description "Admin Accounts for $Company"


# Sumup of Creation
Write-Host "What was created:"
Write-Host ""
Get-ADOrganizationalUnit -LDAPFilter '(name=*)' -SearchBase $DomainSub  | Format-Table Name, DistinguisheDName


#region Creating Users
$Users = "35"

Write-Host ""

$OUPath = $DomainPersonUsers
Write-Host "Creating $Users Users in $($OUPath)"

$i = 1
Do {
$FirstNames = "Jacob","Isabella","Ethan","Sophia","Michael","Emma","Jayden","Olivia","William","Ava","Alexander","Emily","Noah","Abigail","Daniel","Madison","Aiden","Chloe","Anthony","Mia","Ryan","Gregory","Kyle","Deron","Josey","Joseph","Kevin","Robert","Michelle","Mandi","Amanda","Ella"
$LastNames = "Smith","Johnson","Williams","Jones","Brown","Davis","Miller","Wilson","Moore","Taylor","Anderson","Thomas","Jackson","White","Harris","Martin","Thompson","Garcia","Martinez","Robinson","Clark","Rodriguez","Lewis","Lee","Dennis"
$fname = $FirstNames | Get-Random
$lname = $LastNames | Get-Random
$samAccountName = $fname.Substring(0,1)+$lname
$UPN = $fname+$lname+"@"+$Company + ".local"
$password = ConvertTo-SecureString p@ssw0rd -AsPlainText -Force
$name = $fname+ " " + $lname
$DisplayName = $name
Try {
    $new = New-ADUser -SamAccountName $samAccountName -Name $name -DisplayName $Displayname -GivenName $fname -Surname $lname -AccountPassword $password -Path $OUpath -UserPrincipalName $UPN -Enabled $true -ErrorAction SilentlyContinue
}
catch {
    #do nothing
}
$i++
}
while ($i -le $users)

Write-Host ""
Write-Host "Users are created:"
Get-ADUser -SearchBase $OUpath -Filter * | Format-Table Name,SamAccountname,UserPrincipalName

#endregion Creating Users

#region Creating MailUsers
$Users = "5"

Write-Host ""

$OUPath = Get-ADOrganizationalUnit -LDAPFilter '(name=*)' | Where-Object {$_.DistinguisheDName -like "*Mail users*"}
Write-Host "Creating $Users Users in $($OUPath.DistinguisheDName)"

$i = 1
Do {
$FirstNames = "Jacob","Isabella","Ethan","Sophia","Michael","Emma","Jayden","Olivia","William","Ava","Alexander","Emily","Noah","Abigail","Daniel","Madison","Aiden","Chloe","Anthony","Mia","Ryan","Gregory","Kyle","Deron","Josey","Joseph","Kevin","Robert","Michelle","Mandi","Amanda","Ella"
$LastNames = "Smith","Johnson","Williams","Jones","Brown","Davis","Miller","Wilson","Moore","Taylor","Anderson","Thomas","Jackson","White","Harris","Martin","Thompson","Garcia","Martinez","Robinson","Clark","Rodriguez","Lewis","Lee","Dennis"
$fname = $FirstNames | Get-Random
$lname = $LastNames | Get-Random
$samAccountName = $fname.Substring(0,1)+$lname
$UPN = $fname+$lname+"@"+$Company + ".local"
$password = ConvertTo-SecureString p@ssw0rd -AsPlainText -Force
$name = $fname+ " " + $lname
$DisplayName = $name
try {
    $mail = New-ADUser -SamAccountName $samAccountName -Name $name -DisplayName $Displayname -GivenName $fname -Surname $lname -AccountPassword $password -Path $OUpath.DistinguisheDName -UserPrincipalName $UPN -Enabled $true -ErrorAction SilentlyContinue
}
catch {
    #do nothing
}
$i++
}
while ($i -le $users)

Write-Host ""
Write-Host "Users are created:"
Get-ADUser -SearchBase $OUpath.DistinguisheDName -Filter * | Format-Table Name,SamAccountname,UserPrincipalName

#endregion Creating MailUsers

#region Creating Groups
Write-Host "Creating Distribution Groups ..."
$DistributionGroups = "DG-TestGroup1","DG-TestGroup2","DG-TestGroup3","DG-TestGroup4"
ForEach ($Group in $DistributionGroups){
    Try {
    New-ADGroup -Name $Group -SamAccountName $Group -GroupCategory Distribution -GroupScope Universal -DisplayName $Group -Path $DomainDistributionGroups -Description "$($Group) is a Distribution Group"
    }
    Catch {
        Write-Host "ERROR creating $($Group)" -ForegroundColor RED 
    }
}
Write-Host "Creating Local Security Groups ..."
$LocalGroups = "DL-Data-Directie-RW","DL-Data-Directie-RR","DL-Data-HR-RW","DL-Data-HR-RR","A-Microsoft RDP","A-Microsoft Calculator"
ForEach ($Group in $LocalGroups){
    if ($Group -like "A-*"){
        $OU = $DomainApplication
        $Name = "$($Group) is an Application Domain Local Group"
    }
    Else {
        $OU = $DomainLocalSecurity
        $Name = "$($Group) is an Domain Local Group"
    }
    Try {
    New-ADGroup -Name $Group -SamAccountName $Group -GroupCategory Security -GroupScope DomainLocal -DisplayName $Group -Path $OU -Description $Name
    }
    Catch {
        Write-Host "ERROR creating $($Group)" -ForegroundColor RED 
    }
}

Write-Host "Creating Global Security Groups ..."
$GlobalGroups = $LocalGroups | where-Object {$_ -like "DL-*"}
ForEach ($Group in $GlobalGroups){
    $GGGroup = $Group.substring(2)
    $GGGroup = "GG"+$GGGroup
    Try {
        New-ADGroup -Name $GGGroup -SamAccountName $GGGroup -GroupCategory Security -GroupScope Global -DisplayName $GGGroup -Path $DomainGlobalSecurity -Description "$($GGGroup) is a Global Group"
        }
        Catch {
            Write-Host "ERROR creating $($Group)" -ForegroundColor RED 
        }
    Try {
        Write-Host "-Adding $($GGGroup) to $($Group) ..."
        Add-ADGroupMember -Identity $Group -members $GGGroup
    }
    catch {
        Write-Host "ERROR cannot add $($GGGroup) to $($Group) " -ForegroundColor RED 
    }
}

Write-Host "Creating Universal Security Groups ..."
$UniversalGroups = "UG-Not Mail Enabled","UG-Mail Enabled","UG-Mail Enabled 1"
ForEach ($Group in $UniversalGroups){
    $Name = "$($Group) is a Universal Security Group"
    Try {
    New-ADGroup -Name $Group -SamAccountName $Group -GroupCategory Security -GroupScope Universal -DisplayName $Group -Path $DomainUniversalSecurity -Description $Name
    }
    Catch {
        Write-Host "ERROR creating $($Group)" -ForegroundColor RED 
    }
}

#add random users to Global Security Groups

Write-Host "Adding random users to Global Security Groups..."
$users = Get-ADUser -Filter * -SearchBase $DomainSub
$array = Get-ADGroup -SearchBase $DomainGlobalSecurity -Filter *
foreach($userVar in $users)
{
    $group = $array[(Get-Random -Minimum 1 -Maximum $($array.count-1))]
    Add-ADGroupMember -Identity $group -members $userVar
}

#add random users to Distribution Groups
Write-Host "Adding random users to Distribution Groups..."
$array = Get-ADGroup -SearchBase $DomainDistributionGroups -Filter *
foreach($userVar in $users)
{
    $group = $array[(Get-Random -Minimum 1 -Maximum $($array.count-1))]
    Add-ADGroupMember -Identity $group -members $userVar
}

#add random users to Universal Security Groups
Write-Host "Adding random users to Universal Security Groups..."
$array = Get-ADGroup -SearchBase $DomainUniversalSecurity -Filter *
foreach($userVar in $users)
{
    $group = $array[(Get-Random -Minimum 1 -Maximum 3)]
    Add-ADGroupMember -Identity $group -members $userVar
}

#endregion creating groups 
