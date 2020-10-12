powershell -c "New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name 'BgInfo' -Value 'C:\ProgramData\chocolatey\lib\bginfo\Tools\Bginfo.exe C:\ProgramData\chocolatey\lib\bginfo\Tools\bginfo.bgi /silent /timer:0 /nolicprompt' -PropertyType 'String' -force"
sc.exe config wuauserv start=disabled
sc.exe stop wuauserv
powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
powercfg -Change -monitor-timeout-ac 0
powercfg -Change -monitor-timeout-dc 0
powercfg -hibernate OFF
dism.exe /online /cleanup-image /scanhealth
dism.exe /online /cleanup-image /restorehealth
