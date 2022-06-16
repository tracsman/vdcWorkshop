$KillApp  = $false  # Remove things related to the App Service
$KillVNet = $false   # Remove things related to the VNet
$KillAFD  = $true   # Remove things related to the Front Door
$KillAll  = $true  # Remove all of the above

if ($KillAll) {
    $KillApp  = $true
    $KillVNet = $true
    $KillAFD  = $true
}

$RGName    = "MaxLab"
$SpokeName = "Spoke03-VNet"
$HubName   = "Hub-VNet"

if ($KillApp) {
    Write-Host "Killing App Service" -ForegroundColor Cyan
    try {$WepApp = (Get-AzWebApp -ResourceGroupName $RGName -ErrorAction Stop | Select-Object -First 1)
         Remove-AzWebApp -ResourceGroupName $RGName -Name $WepApp.Name -Force -DeleteAppServicePlan -AsJob | Out-Null}
    catch {Write-Host "  It's not there"}
}

if ($KillVNet) {
    Write-Host "Removing Hub to Spoke Peering" -ForegroundColor Cyan
    Try {Get-AzVirtualNetworkPeering -Name HubToSpoke03 -VirtualNetworkName $HubName -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
         Remove-AzVirtualNetworkPeering -Name HubToSpoke03 -VirtualNetworkName $HubName -ResourceGroupName $RGName -Force -ErrorAction Stop | Out-Null}
    Catch {Write-Host "  It's not there"}

    Write-Host "Removing Spoke03 VNet" -ForegroundColor Cyan
    Try {Get-AzVirtualNetwork -Name $SpokeName -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
         Remove-AzVirtualNetwork -Name $SpokeName -ResourceGroupName $RGName -Force -ErrorAction Stop | Out-Null}
    Catch {Write-Host "  It's not there"}

    Write-Host "Removing Spoke03 Route Table" -ForegroundColor Cyan
    Try {Get-AzRouteTable -Name $SpokeName'-rt-fw' -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
         Remove-AzRouteTable -Name $SpokeName'-rt-fw' -ResourceGroupName $RGName -Force -AsJob | Out-Null}
    Catch {Write-Host "  It's not there"}

    Write-Host "Removing Spoke03 NSG" -ForegroundColor Cyan
    Try {Get-AzNetworkSecurityGroup -Name $SpokeName'-nsg' -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
         Remove-AzNetworkSecurityGroup -Name $SpokeName'-nsg' -ResourceGroupName $RGName -Force -AsJob | Out-Null}
    Catch {Write-Host "  It's not there"}
}

if ($KillAFD) {
    Write-Host "Killing AFD" -ForegroundColor Cyan
    Try {$fd = Get-AzFrontDoor -ResourceGroupName $RGname -ErrorAction Stop | Select-Object -First 1
         Remove-AzFrontDoor -ResourceGroupName $RGname -Name $fd.Name | Out-Null}
    Catch {Write-Host "  It's not there"}
}

Write-Host "Waiting for All Jobs to complete"
Get-Job  | Wait-Job -Timeout 600 | Out-Null
Write-Host "All Done!" -ForegroundColor Green