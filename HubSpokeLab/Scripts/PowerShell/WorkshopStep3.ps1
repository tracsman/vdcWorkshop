#
# Virtual Data Center Workshop
# Ignite 2018 - PRE24
#
# Use your student credentials to login (StudentNNN@azlab.xyz)
#
# Step 1 Create a VNet (Hub01-VNet01)
# Step 2 Create an ExpressRoute circuit (incl provisioning)
# Step 3 Create an ExpressRoute Gateway and VNet connection
# Step 4 Create a VM on the VNet
# Step 5 Create Spoke (Spoke01-VNet01): Enable VNet Peering to hub, deploy load balancer, VMSS, build file server
# Step 6 Create Spoke (Spoke02-VNet01): Enable VNet Peering to hub, deploy load balancer, App Gateway, build IIS farm
# Step 7 In Hub, deploy load balancer, NVA Firewall, NSGs, and UDR, build firewall
# Step 8 Create Remote VNet (Remote-VNet01) connected back to ER

# Step 3
# Create an ExpressRoute Gateway and VNet connection
# Description: In this script we will create an ExpressRoute gateway in your VNet (from Step 1) and connect to the ExpressRoute circuit (from Step 2)
# Detailed Steps
# 1. Create the ExpressRoute Gateway
# 2. Ensure the circuit has been provisioned
# 3. Enable Private Peering on the circuit
# 4. Create the connection object connecting the Gateway and the Circuit 

# Notes:
# P2P are 192.168.1xx.0/29 where xx is Company ID
# For the workshop, VLAN tag uses the pattern of third octet plus a trailing zero
# e.g. Company 1 would be 3rd octet 101, and thus VLAN 1010

# Load Initialization Variables
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
If (Test-Path -Path $ScriptDir\init.txt) {
        Get-Content $ScriptDir\init.txt | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}}}
Else {Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}

# Non-configurable Variable Initialization (ie don't modify these)
$SubID = 'e4a176ec-f695-407c-8eeb-185fb94076b8'
$RGName = "Company" + $CompanyID
$ShortRegion = "eastus"
$ERCircuitName = $RGName + "-er"
$VNetName = "Hub01-VNet01"
$GWName = $VNetName + "-gw"
$PIPName = $GWName + "-ip"
$ConnectionName = $GWName + "-conn"
$ASN = "65021"
$IPThirdOctet = $CompanyID
$VLANTag =  "20" + $CompanyID

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 3, estimated total time 20 minutes" -ForegroundColor Cyan

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

# 1. Create the ExpressRoute Gateway
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Creating Gateway' -ForegroundColor Cyan
Try {$gw = Get-AzVirtualNetworkGateway -Name $GWName -ResourceGroupName $RGName -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {
    $VNet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName
    $subnet = Get-AzVirtualNetworkSubnetConfig -Name GatewaySubnet -VirtualNetwork $VNet
    Try {$pip = Get-AzPublicIpAddress -Name $PIPName  -ResourceGroupName $RGName -ErrorAction Stop}
    Catch {$pip = New-AzPublicIpAddress -Name $PIPName  -ResourceGroupName $RGName -Location $ShortRegion -AllocationMethod Dynamic}
    $ipconf = New-AzVirtualNetworkGatewayIpConfig -Name gwipconf -Subnet $subnet -PublicIpAddress $pip
    New-AzVirtualNetworkGateway -Name $GWName -ResourceGroupName $RGName -Location $ShortRegion `
                                     -IpConfigurations $ipconf -GatewayType Expressroute -GatewaySku Standard | Out-Null
}

# 2. Ensure the circuit has been provisioned
Try {$circuit = Get-AzExpressRouteCircuit -ResourceGroupName $RGName -Name $ERCircuitName -ErrorAction Stop}
Catch {
    Write-Warning 'The ExpressRoute Circuit was not found. Complete the second step of the workshop first, then have the proctor provision the circuit before running this script!'
    Return
}

If ($circuit.ServiceProviderProvisioningState -ne 'Provisioned') { 
    Write-Warning 'The ExpressRoute Circuit has not been provisioned by your Service Provider, have the proctor provision your circuit before running this script!'
    Return
}

# 3. Enable Private Peering on the circuit
# Create Private Peering
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Creating Private Peering' -ForegroundColor Cyan
Try {Get-AzExpressRouteCircuitPeeringConfig -Name AzurePrivatePeering -ExpressRouteCircuit $circuit -ErrorAction Stop | Out-Null
     Write-Host '  resource exists, skipping'}
Catch {Add-AzExpressRouteCircuitPeeringConfig -Name AzurePrivatePeering -ExpressRouteCircuit $circuit `
       -PrimaryPeerAddressPrefix "192.168.$IPThirdOctet.216/30" -SecondaryPeerAddressPrefix "192.168.$IPThirdOctet.220/30" `
       -PeeringType AzurePrivatePeering -PeerASN $ASN -VlanId $VLANTag
}

# Save Peering to Circuit
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Saving Peerings to Circuit' -ForegroundColor Cyan
Try {Set-AzExpressRouteCircuit -ExpressRouteCircuit $circuit -ErrorAction Stop | Out-Null}
Catch {
    Write-Warning 'Some or all of the ER Circuit peerings were NOT saved. Use the Azure Portal to manually verify and correct.'
}

# 4. Create the connection object connecting the Gateway and the Circuit 
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Connecting Gateway to ExpressRoute' -ForegroundColor Cyan
Try {Get-AzVirtualNetworkGatewayConnection -Name $ConnectionName -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
     Write-Host '  resource exists, skipping'}
Catch {
    $gw = Get-AzVirtualNetworkGateway -Name $GWName -ResourceGroupName $RGName
    New-AzVirtualNetworkGatewayConnection -Name $ConnectionName -ResourceGroupName $RGName -Location $ShortRegion `
                                               -VirtualNetworkGateway1 $gw -PeerId $circuit.Id -ConnectionType ExpressRoute | Out-Null
}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 3 completed successfully" -ForegroundColor Green
Write-Host
