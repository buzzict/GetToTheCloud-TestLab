$Adapter = Get-NetAdapter
$Adapter = $Adapter | Get-NetIPConfiguration
$DNS = "8.8.8.8"
$adapter | Set-DnsClientServerAddress -ServerAddresses $DNS
$ProgressPreference = 'SilentlyContinue'
Set-TimeZone -id "W. Europe Standard Time"

$OutputFolder = “C:\ExchangeDownload”
if (Test-Path -path $OutputFolder) {
    #do nothing
}
else {
    $Location = $OutputFolder.Split("\")
    New-Item -Path "$($Location[0])\" -Name $Location[1] -ItemType Directory | Out-Null
}

$TLS12Protocol = [System.Net.SecurityProtocolType] 'Ssl3 , Tls12'
[System.Net.ServicePointManager]::SecurityProtocol = $TLS12Protocol

## download latest CU Exchange Server 2019
Write-Host "[INFO] Downloading Exchange Server 2019 CU11"
#Invoke-WebRequest -Uri "https://download.microsoft.com/download/b/c/7/bc766694-8398-4258-8e1e-ce4ddb9b3f7d/ExchangeServer2019-x64-CU12.ISO" -OutFile "$OutputFolder\Exchange2019-Latest.iso"
Invoke-WebRequest -Uri "https://gettothecloudcourses.blob.core.windows.net/exchange/ExchangeServer2019-x64-CU11.ISO" -OutFile "$Outputfolder\Exchange2019-Latest.iso"

## download .NET Framework 4.8
Write-Host "[INFO] Downloading .NET Framework 4.8"
Invoke-Webrequest -Uri "https://download.visualstudio.microsoft.com/download/pr/014120d7-d689-4305-befd-3cb711108212/0fd66638cde16859462a6243a4629a50/ndp48-x86-x64-allos-enu.exe" -OutFile "$OutputFolder\FrameWork48.exe"

## download IIS-Rewrite module
Write-Host "[INFO] Downloading IIS-Rewrite module"
Invoke-Webrequest -Uri "http://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi" -OutFile "$OutputFolder\rewrite_amd64_en-US.msi"

## download UCMA Runtime
Write-Host "[INFO] Downloading UCMA Runtime"
Invoke-Webrequest -Uri "https://download.microsoft.com/download/2/C/4/2C47A5C1-A1F3-4843-B9FE-84C0032C61EC/UcmaRuntimeSetup.exe" -OutFile "$OutputFolder\UcmaRuntimeSetup.exe"

## download Visual C++ Redistributable Packages for Visual Studio 
Write-Host "[INFO] Downloading Visual C++ Redistributable Packages for Visual Studio"
Invoke-Webrequest -Uri "https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe" -OutFile "$OutputFolder\vcredist_x64.exe"

## download CertifyTheWeb for a SSL certificate
Write-Host "[INFO] Downloading CertifyTheWeb for a SSL certificate"
Invoke-Webrequest -uri "https://certifytheweb.s3.amazonaws.com/downloads/archive/CertifyTheWebSetup_V5.6.8.exe" -OutFile "$Outputfolder\CertifyTheWeb_V5.6.8.exe"

## download ADConnect
Write-Host "[INFO] Downloading Azure AD Connect"
Invoke-WebRequest -uri "https://download.microsoft.com/download/B/0/0/B00291D0-5A83-4DE7-86F5-980BC00DE05A/AzureADConnect.msi" -OutFile "$Outputfolder\AzureADConnect.msi"

## install the downloaded files
Write-Host "[INFO] Installing Windows Features needed for installation Exchange Server 2019 CU12"
Start-Job -Name "Features" -ScriptBlock { 
    Install-WindowsFeature NET-Framework-45-Features, RPC-over-HTTP-proxy, RSAT-Clustering, RSAT-Clustering-CmdInterface, RSAT-Clustering-Mgmt, RSAT-Clustering-PowerShell, Web-Mgmt-Console, WAS-Process-Model, Web-Asp-Net45, Web-Basic-Auth, Web-Client-Auth, Web-Digest-Auth, Web-Dir-Browsing, Web-Dyn-Compression, Web-Http-Errors, Web-Http-Logging, Web-Http-Redirect, Web-Http-Tracing, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Lgcy-Mgmt-Console, Web-Metabase, Web-Mgmt-Console, Web-Mgmt-Service, Web-Net-Ext45, Web-Request-Monitor, Web-Server, Web-Stat-Compression, Web-Static-Content, Web-Windows-Auth, Web-WMI, Windows-Identity-Foundation, RSAT-ADDS
} | out-Null
Write-Host "[INFO] waiting for Windows Features to be installed"
Do {
    $Job = Get-Job -Name "Features"
    
    start-sleep 10
}
until ($job.state -eq "Completed")
Write-Host "[INFO] Installing Prerequirements"
Start-Job -Name "Prerequirements" -ScriptBlock { 
    C:\ExchangeDownload\Framework48.exe /q /norestart 
    C:\ExchangeDownload\UcmaRuntimeSetup.exe /passive /norestart 
    msiexec.exe /i C:\ExchangeDownload\rewrite_amd64_en-US.msi /qn 
    C:\ExchangeDownload\vcredist_x64.EXE /Q 
} | Out-Null
Write-Host "[INFO] Waiting for job to finish "
Do {
    $job = (Get-Job -name "PreRequirements").State
    if ($Job -ne "Completed") {
        
        Start-Sleep 10
    }
   
}
Until (
    ($Job -eq "Completed")
)
#wait-Job -Name "Prerequirements"
Write-Host "[INFO] Waiting for Framework to finish"
Do {
    $process = Get-Process | Where-Object { $_.ProcessName -eq "Framework48" }
    
    Start-Sleep 10
}
Until (!($Process))


Write-Host "[SUCCESS] Framework48.exe is finished installing"
Write-Host ""
Write-Host "[INFO] Waiting for IISRewrite to finish"
Do {
    $process = Get-Process | Where-Object { $_.ProcessName -eq "msiexec" }
  
    Start-Sleep 10
}
Until (!($Process))

Write-Host "[SUCCESS] IIS-Rewrite is finished installing"
Write-Host ""
Write-Host "[INFO] Waiting for UcmaRuntime to finish"
Do {
    $process = Get-Process | Where-Object { $_.ProcessName -eq "UcmaRuntimeSetup" }

    Start-Sleep 10
}
Until (!($Process))

Write-Host "[SUCCESS] UcmaRuntimeSetup is finished installing"
Write-Host ""
Write-Host "Waiting for Visual C++ Redistributable Packages for Visual Studio to finish"
Do {
    $process = Get-Process | Where-Object { $_.ProcessName -eq "vcredist_x64" }

    Start-Sleep 10
}
Until (!($Process))

Write-Host "[SUCCESS] vcredist_x64.exe is finished installing"
Write-Host ""
Write-Host "[INFO] Done downloading and installing Exchange Server PreRequisites"

