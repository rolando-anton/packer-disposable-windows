<#
.SYNOPSIS
  Configures the local firewall and access restrictions.
 
 
.DESCRIPTION
  By default the server will prevent incoming ICMP requests. As the Jenkins pipeline uses Ping to
  see if the server is up yet or not, we need to make sure this is enabled.
  Also enables Remote Desktop. In theory this should be set by Puppet or GPO, but it makes deployment checks easier.
 
.INPUTS
  None.
 
.OUTPUTS
  None.
#>
 
 
# Allow incoming ping
Set-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv4-In)" -Enabled True
 
# Enable Remote Desktop.
(Get-WmiObject Win32_TerminalServiceSetting -Namespace root\cimv2\TerminalServices).SetAllowTsConnections(1,1) | Out-Null
(Get-WmiObject -Class "Win32_TSGeneralSetting" -Namespace root\cimv2\TerminalServices -Filter "TerminalName='RDP-tcp'").SetUserAuthenticationRequired(1) | Out-Null
Set-NetFirewallRule -DisplayName "Remote Desktop*" -Enabled True

# Enable WMI
netsh advfirewall firewall set rule group="windows management instrumentation (wmi)" new enable=yes
