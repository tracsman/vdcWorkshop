#
# ExpressRoute Resiliency Workshop Part 1
#
# Use your corporate credentials to login (your @microsoft.com account) to Azure
#
#
# Step 1  Create the connection between the ER Gateway and the ER Circuit
# Step 2  Fail Seattle and validate traffic flows through Washington DC (no script)
# 

# Step 1 Create the connection between the ER Gateway and the ER Circuit
#  1.1 Validate and Initialize
#  1.2 Create the connection between the ER East Gateway and the Seattle ER Circuit
#  1.3 Create the connection between the ER West US 2 Gateway and the DC ER Circuit

# 1.1 Validate and Initialize
# Az Module Test
$ModCheck = Get-Module Az.Network -ListAvailable
If ($Null -eq $ModCheck) {
    Write-Warning "The Az PowerShell module was not found. This script uses the Az modules for PowerShell"
    Write-Warning "See the blob post for more information at: https://azure.microsoft.com/blog/how-to-migrate-from-azurerm-to-az-in-azure-powershell/"
    Return
    }

# Load Initialization Variables
$ScriptDir = "$env:HOME/Scripts"
If (Test-Path -Path $ScriptDir/init.txt) {
        Get-Content $ScriptDir/init.txt | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}}}
Else {Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}

# Non-configurable Variable Initialization (ie don't modify these)
$ShortRegionWest = "westus2"
$ShortRegionEast = "eastus"
$CompanyID = $RGName.Substring($RGName.Length - 2)
$VNetNameWest = "C" + $CompanyID + "w-VNetHub"
$VNetNameEast = "C" + $CompanyID + "e-VNetHub"
$CircuitNameSEA = "C" + $CompanyID + "w-er"
$CircuitNameASH = "C" + $CompanyID + "e-er"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 1, estimated total time 5 minutes" -ForegroundColor Cyan

# Login and permissions check
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Checking login and permissions" -ForegroundColor Cyan
Try {Get-AzResourceGroup -Name $RGName -ErrorAction Stop | Out-Null}
Catch {# Login and set subscription for ARM
       Write-Host "Logging in to ARM"
       Try {$Sub = (Set-AzContext -Subscription $SubID -ErrorAction Stop -WarningAction SilentlyContinue).Subscription}
       Catch {Connect-AzAccount | Out-Null
              $Sub = (Set-AzContext -Subscription $SubID -ErrorAction Stop -WarningAction SilentlyContinue).Subscription}
       Write-Host "Current Sub:",$Sub.Name,"(",$Sub.Id,")"
       Try {Get-AzResourceGroup -Name $RGName -ErrorAction Stop | Out-Null}
       Catch {Write-Warning "Permission check failed, ensure company id is set correctly!"
              Return}
}

# Get Circuit Info
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Pulling Seattle circuit information' -ForegroundColor Cyan
Try {$cktSEA = Get-AzExpressRouteCircuit -ResourceGroupName $RGName -Name $CircuitNameSEA -ErrorAction Stop}
Catch {Write-Warning "The circuit wasn't found, please ensure step three is successful before running this script."
       Return}

Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Pulling DC circuit information' -ForegroundColor Cyan
Try {$cktASH = Get-AzExpressRouteCircuit -ResourceGroupName $RGName -Name $CircuitNameASH -ErrorAction Stop}
Catch {Write-Warning "The circuit wasn't found, please ensure step three is successful before running this script."
       Return}

# Ensure Private Peering is enabled, then create connection objects
Try {Get-AzExpressRouteCircuitPeeringConfig -ExpressRouteCircuit $cktSEA -Name AzurePrivatePeering -ErrorAction Stop | Out-Null}
Catch {Write-Warning "Private Peering isn't enabled on the Seattle ExpressRoute circuit. Please ensure private peering is enable successfully."
       Return}

Try {Get-AzExpressRouteCircuitPeeringConfig -ExpressRouteCircuit $cktASH -Name AzurePrivatePeering -ErrorAction Stop | Out-Null}
Catch {Write-Warning "Private Peering isn't enabled on the DC ExpressRoute circuit. Please ensure private peering is enable successfully."
       Return}

#  1.2 Create the connection between the ER East Gateway and the Seattle ER Circuit
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Connecting East Gateway to Seattle ExpressRoute in $($cktSEA.ServiceProviderProperties.PeeringLocation)" -ForegroundColor Cyan
Try {Get-AzVirtualNetworkGatewayConnection -Name $VNetNameEast"-gw-er-conn-SEA" -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
    Write-Host '  connection exists, skipping'}
Catch {$gwEast = Get-AzVirtualNetworkGateway -Name $VNetNameEast"-gw-er" -ResourceGroupName $RGName
       If ($gwEast.ProvisioningState -eq 'Succeeded') {
           Write-Host '  East Gateway is provisioned'
           Write-Host '  Connecting to ExpressRoute in Seattle'
           New-AzVirtualNetworkGatewayConnection -Name $VNetNameEast"-gw-er-conn-SEA" -ResourceGroupName $RGName -Location $ShortRegionEast `
                                                 -VirtualNetworkGateway1 $gwEast -PeerId $cktSEA.Id -ConnectionType ExpressRoute | Out-Null}
       Else {Write-Warning 'An issue occurred with East ER gateway provisioning.'
             Write-Host 'Current Gateway Provisioning State' -NoNewLine
             Write-Host $gw.ProvisioningState
             Return}
}

#  1.3 Create the connection between the ER West US 2 Gateway and the DC ER Circuit
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Connecting West Gateway to DC ExpressRoute in $($cktASH.ServiceProviderProperties.PeeringLocation)" -ForegroundColor Cyan
Try {Get-AzVirtualNetworkGatewayConnection -Name $VNetNameWest"-gw-er-conn-DC" -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
    Write-Host '  connection exists, skipping'}
Catch {$gwWest = Get-AzVirtualNetworkGateway -Name $VNetNameWest"-gw-er" -ResourceGroupName $RGName
       If ($gwWest.ProvisioningState -eq 'Succeeded') {
           Write-Host '  West Gateway is provisioned'
           Write-Host '  Connecting to ExpressRoute in DC'
           New-AzVirtualNetworkGatewayConnection -Name $VNetNameWest"-gw-er-conn-DC" -ResourceGroupName $RGName -Location $ShortRegionWest `
                                                 -VirtualNetworkGateway1 $gwWest -PeerId $cktASH.Id -ConnectionType ExpressRoute | Out-Null}
       Else {Write-Warning 'An issue occurred with West ER gateway provisioning.'
             Write-Host 'Current Gateway Provisioning State' -NoNewLine
             Write-Host $gw.ProvisioningState
             Return}
}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 1 completed successfully" -ForegroundColor Green
Write-Host "  Review your route table on the Private Peering in each circuit."
Write-Host "  You should now see your VNet routes from both Azure regions."
Write-Host
