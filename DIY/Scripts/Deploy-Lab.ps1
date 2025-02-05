Write-Host
Write-Host "DIY Lab Deploy Utility" -ForegroundColor Cyan
Write-Host
# Ensure we're in a Cloud Shell session
If (-not ([environment]::GetEnvironmentVariable("AZUREPS_HOST_ENVIRONMENT") -match "cloud-shell")) {
    Write-Host
    Write-Host "FATAL ERROR: Not in an Azure Cloud Shell session" -ForegroundColor Red
    Write-Host
    Write-Host "This utility and the associcate DIY Lab scripts are designed to be run only from the Azure CloudShell environment."
    Write-Host "Please initiate a CloudShell session from the Azure Portal by doing the following:"
    Write-Host "  Open the Azure Portal at https://portal.azure.com"
    Write-Host "  The icon immediately to the right of the search bar is the Cloud Shell start button"
    Write-Host "  Click this icon will open a Cloud Shell session in your Portal browser tab"
    Write-Host "  At the top of the Cloud Shell is a drop down where you can select ""PowerShell"""
    Write-Host " Once at the Cloud Shell PowerShell prompt, rerun this script."
    Write-Host
    Return
}

Write-Host "Please select the lab you wish to deploy to your cloud shell:"
Write-Host
Write-Host "   1. Firewall"
Write-Host "   2. TBD"
Write-Host "   3. Basic Network Training"
Write-Host "   4. ExpressRoute Resiliency"
Write-Host "   0. Exit"
Write-Host
Write-Host "  Waiting for your selection [0-4]: " -NoNewline
$MenuItem = $Host.UI.RawUI.ReadKey()
Write-Host
Write-Host
switch ($MenuItem.Character) {
    "1" {Write-Host "Firewall Lab was selected" -ForegroundColor Cyan
         $RGName = "FWLab"
         $Files = @()
         $Files += 'Validate-Lab.ps1'
         $Files += 'WorkshopStep1.ps1'
         $Files += 'WorkshopStep2.ps1'
         $Files += 'WorkshopStep3.ps1'
         $Files += 'WorkshopStep4.ps1'
         $Files += 'WorkshopStep5.ps1'
         $uri = 'https://raw.githubusercontent.com/tracsman/vdcWorkshop/main/DIY/Firewall/Scripts/'}
    "3" {Write-Host "Basic Network Training Lab was selected" -ForegroundColor Cyan
         $RGName = "NetTrain"
         $Files = @()
         $Files += 'Validate-Lab.ps1'
         $Files += 'BuildLab.ps1'
         $uri = 'https://raw.githubusercontent.com/tracsman/vdcWorkshop/main/DIY/BasicNetworking/Scripts/'}
    "4" {Write-Host "ExpressRoute Resiliency Part 1 Lab was selected" -ForegroundColor Cyan
         $RGName = "CompanyXX"
         $Files = @()
         $Files += 'Validate-Lab1.ps1'
         $Files += 'ER1WorkshopStep1.ps1'
         $Files += 'ER2WorkshopStep1.ps1'
         $Files += 'ER2WorkshopStep2.ps1'
         $Files += 'ER2WorkshopStep3.ps1'
         $uri = 'https://raw.githubusercontent.com/tracsman/vdcWorkshop/main/ERResilience/Scripts/'}         
    "0" {Write-Host "Exiting" -ForegroundColor Cyan
         Write-Host
         Return}
    default {Write-Host "Invalid input, " -NoNewline
             Write-Host "exiting" -ForegroundColor Cyan 
             Write-Host
             Return}
}

# Start nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Initializing workshop environment, estimated total time < 1 minute" -ForegroundColor Cyan

# Check for folder, create if not found
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Scripts Folder" -ForegroundColor Cyan
$ScriptPath = "$env:HOME/Scripts"
If (-Not (Test-Path $ScriptPath)){New-Item -ItemType Directory -Force -Path $ScriptPath | Out-Null}

# Create and fill init.txt
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Init File" -ForegroundColor Cyan
If (-Not (Test-Path $ScriptPath\init.txt)){
     if ($MenuItem.Character -eq "4") {
          $FileContent = "SubID=e4a176ec-f695-407c-8eeb-185fb94076b8" + "`nRGName=" + $RGName
     } else {
          $FileContent = "SubID=00000000-0000-0000-0000-000000000000" + "`nShortRegion=westus2" + "`nRGName=" + $RGName
     }
    Out-File -FilePath "$ScriptPath\init.txt" -Encoding ascii -InputObject $FileContent -Force
}

# Download lab files
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Downloading PowerShell Scripts" -ForegroundColor Cyan
ForEach ($File in $Files) {
    Invoke-WebRequest -Uri "$uri$File" -OutFile "$ScriptPath\$File" -Headers @{"Cache-Control"="no-cache"} | Out-Null
}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Lab Files Download complete" -ForegroundColor Cyan
Write-Host 
Write-Host "Next Steps:`n1. Navigate to the Scripts folder"
Write-Host "2. Update the " -NoNewline
Write-Host "init.txt" -ForegroundColor Yellow -NoNewline
Write-Host " file with your Subscription ID"
Write-Host "3. Run the " -NoNewline
Write-Host "./Validate-Lab.ps1" -ForegroundColor Yellow -NoNewline
Write-Host " script to validate your sub and region"
Write-Host "4. Begin the lab per the instructions"
Write-Host
