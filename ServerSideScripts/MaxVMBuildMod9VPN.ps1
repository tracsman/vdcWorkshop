# OnPrem VM Module 9 NVA Build Script
#
# 1. Connect with the VM's managed identity
# 2. Pull Config File
# 3. Push Router Config
#

Start-Transcript -Path "C:\Workshop\MaxVMBuildMod9VPN.log"
$User1 = "User01"
$HubRouterIP = "10.0.1.5"

# 1. Connect with the VM's managed identity
Write-Host "Connecting using the VM Managed Identity"
$i = 0
Connect-AzAccount -Identity
$ctx = Get-AzContext
If ($null -eq $ctx.Subscription.Id) {
     Do {Write-Host "*"
         Start-Sleep -Seconds 2
         Connect-AzAccount -Identity
         $ctx = Get-AzContext}
     Until ($i -gt 15 -or $null -ne $ctx.Subscription.Id)
}
If ($null -eq $ctx.Subscription.Id) {Write-Output "  There is no system-assigned user identity. Aborting."; exit 1}
Else {Write-Host "  Identity connected"}

# 2. Pull Config Files
# Get sa and download blob (hub router config file)
$sa = (Get-AzStorageAccount | Select-Object -First 1)
Write-Host "Downloading Router config files from the Storage Account"
Try {Get-AzStorageBlobContent -Container "config" -Blob 'HubRouter.txt' -Context $sa.Context -Destination "C:\Workshop\HubRouter.txt" -Force -ErrorAction Stop | Out-Null
     Get-AzStorageBlobContent -Container "config" -Blob 'OPDelta.txt' -Context $sa.Context -Destination "C:\Workshop\OPDelta.txt" -Force -ErrorAction Stop | Out-Null
     $RouterConfigDownloadError = $false
     Write-Host "  Config file downloaded"
}
Catch {$RouterConfigDownloadError = $true
       Write-Host "  Config file download failed!!"}


If (-Not $RouterConfigDownloadError) {
     # 3. Push Router Config to routers
     Write-Host "Sending config to Hub router"
     Get-Content -Path "C:\Workshop\HubRouter.txt" | ssh -o "StrictHostKeyChecking no" $User1@$HubRouterIP -E C:\Workshop\HubRouter.err > C:\Workshop\HubRouter.log
     Write-Host "  Config sent to hub router, hopefully successfully"

     Write-Host "Sending config to OnPrem router"
     $LocalIP = (Get-NetIPConfiguration).IPv4Address.IPAddress | Select-Object -First 1
     $RouterIP = $LocalIP.Split(".")[0] + "." + $LocalIP.Split(".")[1] + "." + $LocalIP.Split(".")[2] + "." + ($LocalIP.Split(".")[3] - 1)
     Get-Content -Path "C:\Workshop\OPDelta.txt" | ssh -o "StrictHostKeyChecking no" $User1@$RouterIP -E C:\Workshop\RouterDelta.err > C:\Workshop\RouterDelta.log
     Write-Host "  Config sent to OnPrem router, hopefully successfully"
}

# End Nicely
Write-Host "Module 9 Script Complete"
Stop-Transcript
