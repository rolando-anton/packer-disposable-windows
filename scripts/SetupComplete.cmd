netsh advfirewall firewall set rule name="Allow WinRM HTTPS" new action=allow
sc.exe config wuauserv start=disabled
sc.exe stop wuauserv
powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
powercfg -Change -monitor-timeout-ac 0
powercfg -Change -monitor-timeout-dc 0
powercfg -hibernate OFF
