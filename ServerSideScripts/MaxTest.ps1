# Connect with the VM's managed identity
Start-Transcript -Path "C:\Workshop\MaxTest.log"
Write-Host "Starting"
Write-Host "Connect-AzAccount"
Connect-AzAccount -Identity
Write-Host "Get-AzContext"
Get-AzContext
$ctx = Get-AzContext
Write-Host "SubID: $($ctx.Subscription.Id)"
Write-Host "Set-AzContext"
Set-AzContext ExpressRoute-lab
Write-Host "Get-AzContext"
Get-AzContext
$ctx = Get-AzContext
Write-Host "SubID: $($ctx.Subscription.Id)"
Write-Host "Done"
Stop-Transcript