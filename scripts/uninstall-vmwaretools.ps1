$regpath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
$regkey = $regpath | Get-ChildItem | Get-ItemProperty | Where-Object { 'VMware Tools' -contains $_.DisplayName }
msiexec.exe /x $regkey.PSChildName /passive /norestart
shutdown /t 120 /f /r
