#
# Azure Firewall Workshop
#
# Use your corporate credentials to login (your @microsoft.com account) to Azure
#
#
# Step 1 Create Virtual Network
# Step 2 Create an internet facing VM
# Step 3 Create an ExpressRoute circuit and ER Gateway
# Step 4 Bring up ExpressRoute Private Peering
# Step 5 Create the connection between the ER Gateway and the ER Circuit
# Step 6 Create and configure the Azure Firewall
# Step 7 Create Spoke VNet with IIS Server and a firewall rule to allow traffic
# 

# Step 3 Create an ExpressRoute circuit and ER Gateway
#  3.1 Validate and Initialize
#  3.2 Create ExpressRoute Circuit
#  3.3 Create ExpressRoute Gateway

# 3.1 Validate and Initialize
# Az Module Test
$ModCheck = Get-Module Az.Network -ListAvailable
If ($Null -eq $ModCheck) {
    Write-Warning "The Az PowerShell module was not found. This script uses the Az modules for PowerShell"
    Write-Warning "See the blob post for more information at: https://azure.microsoft.com/blog/how-to-migrate-from-azurerm-to-az-in-azure-powershell/"
    Return
    }

# Load Initialization Variables
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
If (Test-Path -Path $ScriptDir\init.txt) {
        Get-Content $ScriptDir\init.txt | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}}}
Else {Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}

# Non-configurable Variable Initialization (ie don't modify these)
$ShortRegion = "centralus"
$RGName = "AComp" + $CompanyID
$VNetName = "C" + $CompanyID + "-VNet"
$CircuitName = $RGName + "-er"
$CircuitLocation = 'Washington DC'

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 3, estimated total time 4 minutes" -ForegroundColor Cyan

# Login and permissions check
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Checking login and permissions" -ForegroundColor Cyan
Try {Get-AzResourceGroup -Name $RGName -ErrorAction Stop | Out-Null}
Catch {# Login and set subscription for ARM
       Write-Host "Logging in to ARM"
       Try {$Sub = (Set-AzContext -Subscription $SubID -ErrorAction Stop).Subscription}
       Catch {Connect-AzAccount | Out-Null
              $Sub = (Set-AzContext -Subscription $SubID -ErrorAction Stop).Subscription}
       Write-Host "Current Sub:",$Sub.Name,"(",$Sub.Id,")"
       Try {Get-AzResourceGroup -Name $RGName -ErrorAction Stop | Out-Null}
       Catch {Write-Warning "Permission check failed, ensure company id is set correctly!"
              Return}
}

#  3.2 Create ExpressRoute Circuit
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating ExpressRoute Circuit in $CircuitLocation" -ForegroundColor Cyan
Try {Get-AzExpressRouteCircuit -ResourceGroupName $RGName -Name $CircuitName -ErrorAction Stop | Out-Null
        Write-Host '  resource exists, skipping'}
Catch {New-AzExpressRouteCircuit -ResourceGroupName $RGName -Name $CircuitName -Location eastus `
                                      -ServiceProviderName Equinix -PeeringLocation $CircuitLocation `
                                      -BandwidthInMbps 50 -SkuFamily MeteredData -SkuTier Standard | Out-Null
}

#  3.3 Create ExpressRoute Gateway
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating ExpressRoute Gateway" -ForegroundColor Cyan
Try {Get-AzVirtualNetworkGateway -Name $VNetName'-gw' -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
     Write-Host "  resource exists, skipping"}
Catch {
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName
    $subnet = Get-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet
    Try {$pip = Get-AzPublicIpAddress -Name $VNetName'-gw-pip'  -ResourceGroupName $RGName -ErrorAction Stop}
    Catch {$pip = New-AzPublicIpAddress -Name $VNetName'-gw-pip' -ResourceGroupName $RGName -Location $ShortRegion -AllocationMethod Dynamic}
    $ipconf = New-AzVirtualNetworkGatewayIpConfig -Name "gwipconf" -Subnet $subnet -PublicIpAddress $pip
    New-AzVirtualNetworkGateway -Name $VNetName'-gw' -ResourceGroupName $RGName -Location $ShortRegion -IpConfigurations $ipconf -GatewayType Expressroute -GatewaySku Standard -AsJob | Out-Null
    }

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 3 completed successfully" -ForegroundColor Green
Write-Host "  Review your circuit in the Azure Portal, especially note the 'Provider status'"
Write-Host "  The instructor will now contact the service provider to provision your circuit"
Write-Host
