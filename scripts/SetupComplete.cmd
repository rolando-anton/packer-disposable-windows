netsh advfirewall firewall set rule name="Allow WinRM HTTPS" new action=allow
sc.exe config wuauserv start=disabled
sc.exe stop wuauserv
