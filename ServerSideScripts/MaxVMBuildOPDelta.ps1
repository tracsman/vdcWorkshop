# Deploy On-Prem NVA to Hub NVA Script
#
# Sends delta router config to router to connect to the Hub NVA Router (via IPSec and BGP)
#
# 1. Pull Config File
# 2. Push Router Config
#

Start-Transcript -Path "C:\Workshop\MaxVMBuildOPDelta.log"

# 1. Pull Config File
# Get sa and download blob (router config file)
Write-Host "Downloading Router config file from the Storage Account"
$sa = (Get-AzStorageAccount | Select-Object -First 1)
Try {Get-AzStorageBlobContent -Container "config" -Blob 'OPDelta.txt' -Context $sa.Context -Destination "C:\Workshop\OPDelta.txt" -Force -ErrorAction Stop | Out-Null
     $RouterConfigDownloadError = $false
     Write-Host "  Config file downloaded"
}
Catch {$RouterConfigDownloadError = $true
       Write-Host "  Config file download failed!!"}

# 2. Push Router Config to router
If (-Not $RouterConfigDownloadError) {
     Write-Host "Sending config to router"
     $LocalIP = (Get-NetIPConfiguration).IPv4Address.IPAddress | Select-Object -First 1
     $RouterIP = $LocalIP.Split(".")[0] + "." + $LocalIP.Split(".")[1] + "." + $LocalIP.Split(".")[2] + "." + ($LocalIP.Split(".")[3] - 1)
     Get-Content -Path "C:\Workshop\OPDelta.txt" | ssh -o "StrictHostKeyChecking no" $User1@$RouterIP -E C:\Workshop\RouterDelta.err > C:\Workshop\RouterDelta.log
     Write-Host "  Config sent to router, hopefully successfully"
}

# End Nicely
Write-Host "On-Prem NVA Delta Script Complete"
Stop-Transcript