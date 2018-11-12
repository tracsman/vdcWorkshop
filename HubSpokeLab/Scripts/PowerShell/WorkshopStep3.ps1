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
If (Test-Path -Path .\init.txt) {
    Get-Content init.txt | Foreach-Object{
    $var = $_.Split('=')
    New-Variable -Name $var[0] -Value $var[1]
    }
}
Else {$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
      Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present."
      Return
}

# Non-configurable Variable Initialization (ie don't modify these)
$SubID = 'e4a176ec-f695-407c-8eeb-185fb94076b8'
$ResourceGroup = "Company" + $CompanyID.PadLeft(2,"0")
$ERCircuitName = $ResourceGroup + "-er"
$VNetName = "Hub01-VNet01"
$GWName = $VNetName + "-gw"
$PIPName = $GWName + "-ip"
$ConnectionName = $GWName + "-conn"
$ASN = "65021"
$IPThirdOctet = "1" + $CompanyID.PadLeft(2,"0")
$VLANTag =  "1" + $CompanyID.PadLeft(2,"0") + "0"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 3, estimated total time 20 minutes" -ForegroundColor Cyan

# Login and permissions check
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Checking login and permissions" -ForegroundColor Cyan
Try {$rg = Get-AzureRmResourceGroup -Name $ResourceGroup -ErrorAction Stop}
Catch {# Login and set subscription for ARM
       Write-Host "Logging in to ARM"
       Try {$Sub = (Set-AzureRmContext -Subscription $subID -ErrorAction Stop).Subscription}
       Catch {Login-AzureRmAccount | Out-Null
              $Sub = (Set-AzureRmContext -Subscription $subID -ErrorAction Stop).Subscription}
       Write-Host "Current Sub:",$Sub.Name,"(",$Sub.Id,")"
           Try {$rg = Get-AzureRmResourceGroup -Name $ResourceGroup -ErrorAction Stop}
           Catch {Write-Warning "Permission check failed, ensure company id is set correctly!"
                  Return}
}

# 1. Create the ExpressRoute Gateway
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Creating Gateway' -ForegroundColor Cyan
Try {$gw = Get-AzureRmVirtualNetworkGateway -Name $GWName -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {
    $VNet = Get-AzureRmVirtualNetwork -ResourceGroupName $rg.ResourceGroupName -Name $VNetName
    $subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name GatewaySubnet -VirtualNetwork $VNet
    Try {$pip = Get-AzureRmPublicIpAddress -Name $PIPName  -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop}
    Catch {$pip = New-AzureRmPublicIpAddress -Name $PIPName  -ResourceGroupName $rg.ResourceGroupName -Location $rg.Location -AllocationMethod Dynamic}
    $ipconf = New-AzureRmVirtualNetworkGatewayIpConfig -Name gwipconf -Subnet $subnet -PublicIpAddress $pip
    New-AzureRmVirtualNetworkGateway -Name $GWName -ResourceGroupName $rg.ResourceGroupName -Location $rg.Location `
                                     -IpConfigurations $ipconf -GatewayType Expressroute -GatewaySku Standard | Out-Null
}

# 2. Ensure the circuit has been provisioned
Try {$circuit = Get-AzureRmExpressRouteCircuit -ResourceGroupName $rg.ResourceGroupName -Name $ERCircuitName -ErrorAction Stop}
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
Try {Get-AzureRmExpressRouteCircuitPeeringConfig -Name AzurePrivatePeering -ExpressRouteCircuit $circuit -ErrorAction Stop | Out-Null
     Write-Host '  resource exists, skipping'}
Catch {Add-AzureRmExpressRouteCircuitPeeringConfig -Name AzurePrivatePeering -ExpressRouteCircuit $circuit `
       -PrimaryPeerAddressPrefix "192.168.$IPThirdOctet.16/30" -SecondaryPeerAddressPrefix "192.168.$IPThirdOctet.20/30" `
       -PeeringType AzurePrivatePeering -PeerASN $ASN -VlanId $VLANTag
}

# Save Peering to Circuit
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Saving Peerings to Circuit' -ForegroundColor Cyan
Try {Set-AzureRmExpressRouteCircuit -ExpressRouteCircuit $circuit -ErrorAction Stop | Out-Null}
Catch {
    Write-Warning 'Some or all of the ER Circuit peerings were NOT saved. Use the Azure Portal to manually verify and correct.'
}

# 4. Create the connection object connecting the Gateway and the Circuit 
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Connecting Gateway to ExpressRoute' -ForegroundColor Cyan
Try {Get-AzureRmVirtualNetworkGatewayConnection -Name $ConnectionName -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop | Out-Null
     Write-Host '  resource exists, skipping'}
Catch {
    $gw = Get-AzureRmVirtualNetworkGateway -Name $GWName -ResourceGroupName $rg.ResourceGroupName
    New-AzureRmVirtualNetworkGatewayConnection -Name $ConnectionName -ResourceGroupName $rg.ResourceGroupName -Location $rg.Location `
                                               -VirtualNetworkGateway1 $gw -PeerId $circuit.Id -ConnectionType ExpressRoute | Out-Null
}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 3 completed successfully" -ForegroundColor Green
Write-Host
