<#
.SYNOPSIS
  Performs various tasks on this host to prepare it for imaging.
 
 
.DESCRIPTION
  This script will perform various tasks depending on the parameters provided, to cleanup, anonymise and compact the image.
 
.INPUTS
  None.
 
.OUTPUTS
  None.
#>
 
Param (
  # Remove cached update files. Prevents uninstalling updates. Fairly quick.
  [Switch] $CleanUpdates = $true,
 
  # Empty out Windows Event Logs. Fairly quick.
  [Switch] $CleanEventLogs = $false,
 
  # Remove temporary files used during build, such as Temp, Panther, Nuget and logs folders. Fairly quick.
  [Switch] $DeleteBuildfiles = $true,
 
  # Defragment the system drive. Can take a long time so defaults to false.
  [Switch] $DefragDisk = $true,
 
  # Force an optimisation of the SxS cache. Can take a long time so defaults to false.
  [Switch] $CleanSxS = $true,
 
  # Zero out all unused parts of the system disk, which can improve compression of the VMDK. Can take a long time so defaults to false.
  [Switch] $ZeroDisk = $true
)
 
 
# Disable auto-login
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value 0
 
 
# Remove cached update files.
If($CleanUpdates) {
  Write-Host "Cleaning updates.."
  Stop-Service -Name wuauserv -Force
  Remove-Item c:\Windows\SoftwareDistribution\Download\* -Recurse -Force
  Start-Service -Name wuauserv
}
 
 
# Emptying Logs
# This shouldn't really be necessary, as SysPrep should do this too
If($CleanEventLogs) {
  (Get-WinEvent -ListLog *).logname | ForEach-Object {[System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog("$psitem")}
}
 
 
# Write-Host "Cleaning SxS..."
If($CleanSxS) {
  Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
}
 
$directories = @()
$directories += "$env:localappdata\Nuget"
$directories += "$env:localappdata\temp\*"
$directories += "$env:windir\logs"
$directories += "$env:windir\panther"
$directories += "$env:windir\winsxs\manifestcache"
# $directories += "C:\packer" # Don't remove the packer folder any more, we need the unattend.xml
 
If($CleanBuildFiles) {
  $directories | % {
      if(Test-Path $_) {
          Write-Host "Removing $_"
          try {
            Takeown /d Y /R /f $_
            Icacls $_ /GRANT:r administrators:F /T /c /q  2>&1 | Out-Null
            Remove-Item $_ -Recurse -Force | Out-Null
          } catch { $global:error.RemoveAt(0) }
      }
  }
}
 
If($DefragDisk) {
  Write-Host "Defragging..."
  if (Get-Command Optimize-Volume -ErrorAction SilentlyContinue) {
      Optimize-Volume -DriveLetter C
      } else {
      Defrag.exe c: /H
  }
}
 
 
If($ZeroDisk) {
  Write-Host "Zeroing out empty space..."
  $FilePath="c:\zero.tmp"
  $Volume = Get-WmiObject win32_logicaldisk -filter "DeviceID='C:'"
  $ArraySize= 64kb
  $SpaceToLeave= $Volume.Size * 0.05
  $FileSize= $Volume.FreeSpace - $SpacetoLeave
  $ZeroArray= new-object byte[]($ArraySize)
 
  $Stream= [io.File]::OpenWrite($FilePath)
  try {
     $CurFileSize = 0
      while($CurFileSize -lt $FileSize) {
          $Stream.Write($ZeroArray,0, $ZeroArray.Length)
          $CurFileSize +=$ZeroArray.Length
      }
  }
  finally {
      if($Stream) {
          $Stream.Close()
      }
  }
 
  Del $FilePath
}
