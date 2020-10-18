$ErrorActionPreference = 'Stop'
$tmp_dir = "$env:SystemDrive\temp"

if (-not (Test-Path -Path $tmp_dir)) {
    New-Item -Path $tmp_dir -ItemType Directory | Out-Null
}

Function Write-Log($message, $level="INFO") {
    # Poor man's implementation of Log4Net
    $date_stamp = Get-Date -Format s
    $log_entry = "$date_stamp - $level - $message"
    $log_file = "$tmp_dir\bootstrap.log"
    Write-Host $log_entry
    Add-Content -Path $log_file -Value $log_entry
}
Function Extract-Zip($zip, $dest) {
    Write-Log -message "extracting '$zip' to '$dest'"
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem > $null
        $legacy = $false
    } catch {
        $legacy = $true
    }

    if ($legacy) {
        try {
            $shell = New-Object -ComObject Shell.Application
            $zip_src = $shell.NameSpace($zip)
            $zip_dest = $shell.NameSpace($dest)
            $zip_dest.CopyHere($zip_src.Items(), 1044)
        } catch {
            Write-Log -message "failed to extract zip file: $($_.Exception.Message)" -level "ERROR"
            throw $_
        }
    } else {
        try {
            [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $dest)
        } catch {
            Write-Log -message "failed to extract zip file: $($_.Exception.Message)" -level "ERROR"
            throw $_
        }
    }
}

#Install EC2Config:
$url = "https://s3.amazonaws.com/ec2-downloads-windows/EC2Config/EC2Install.zip"
$src = $url.Split("/")[-1]
Invoke-WebRequest -Uri $url -OutFile "$tmp_dir\$src"
$zip_src = "$tmp_dir\$src"
Extract-Zip -zip $zip_src -dest $tmp_dir
&cmd.exe /c "$tmp_dir\EC2Install.exe" /quiet

#Install ENA Drivers
$url = "https://s3.amazonaws.com/ec2-windows-drivers-downloads/ENA/Latest/AwsEnaNetworkDriver.zip"
$src = $url.Split("/")[-1]
Invoke-WebRequest -Uri $url -OutFile "$tmp_dir\$src"
$zip_src = "$tmp_dir\$src"
Extract-Zip -zip $zip_src -dest $tmp_dir
& "$tmp_dir\install.ps1"


