# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Initializing workshop environment, estimated total time < 1 minute" -ForegroundColor Cyan

# Check for folder, create if not found
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Scripts Folder" -ForegroundColor Cyan
$ScriptPath = ".\Scripts" 
If (-Not (Test-Path $ScriptPath)){New-Item -ItemType Directory -Force -Path $ScriptPath | Out-Null}

# Create and fill init.txt
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Init File" -ForegroundColor Cyan
If (-Not (Test-Path $ScriptPath\init.txt)){
    $FileContent = "SubID=00000000-0000-0000-0000-000000000000" + "`nShortRegion=westus2" + "`nRGName=FWLab"
    Out-File -FilePath "$ScriptPath\init.txt" -Encoding ascii -InputObject $FileContent -Force
}

# Download lab files
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Downloading PowerShell Scripts" -ForegroundColor Cyan
$FileName = @()
$FileName += 'Validate-Lab.ps1'
$FileName += 'WorkshopStep1.ps1'
$FileName += 'WorkshopStep2.ps1'
$FileName += 'WorkshopStep3.ps1'
$FileName += 'WorkshopStep4.ps1'
$FileName += 'WorkshopStep5.ps1'
$uri = 'https://raw.githubusercontent.com/tracsman/vdcWorkshop/master/DIY/Firewall/Scripts/PowerShell/'
ForEach ($File in $FileName) {
    Invoke-WebRequest -Uri "$uri$File" -OutFile "$ScriptPath\$File" | Out-Null
}

./Script/Validate-Lab.ps1

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Environment initialization completed successfully" -ForegroundColor Green
Write-Host
