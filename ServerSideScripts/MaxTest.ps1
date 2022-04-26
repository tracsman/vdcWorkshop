# Connect with the VM's managed identity
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