sc.exe config wuauserv start=disabled
sc.exe stop wuauserv
powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
powercfg -Change -monitor-timeout-ac 0
powercfg -Change -monitor-timeout-dc 0
powercfg -hibernate OFF
dism.exe /online /cleanup-image /scanhealth
dism.exe /online /cleanup-image /restorehealth
powershell.exe -ExecutionPolicy Bypass -Command "C:\Windows\packer\uninstall-vmwaretools.ps1"
rd /S /Q "C:\Windows\packer\"
