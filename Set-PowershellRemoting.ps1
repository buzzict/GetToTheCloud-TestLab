# Enable WinRM for HTTP rules in Windows Firewall
Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -RemoteAddress Any
Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP-NoScope" -RemoteAddress Any
Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP-PUBLIC" -RemoteAddress Any

# Enable PowerShell Remoting forcefully
Enable-PSRemoting -Force