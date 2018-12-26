#
# Azure Front Door / Global Reach Workshop
# Microsoft READY 2019 - Azure Networking Pre-day
#
# Use your corporate credentials to login (your @microsoft.com account) to Azure
#
#
# Step 1 Create two ExpressRoute Circuits, one in Seattle, one in Washington, DC
# Step 2 Establish ExpressRoute Global Peering between the two circuits
# Step 3 Create two VNets each with an ER Gateway, Public IP, and IIS server running a simple web site
# Step 4 Create an Azure Front Door to geo-load balance across the two sites
#

# Step 3
# Create two VNets each with an ER Gateway, Public IP, and IIS server running a simple web site
# Description: In this script we will create indepentndt web servers in East and West US Azure
#              regions. These web sites will be identical, and both pull a file from a file server
#              already prepared for you in your Seattle On-Prem server.
# 3.1 Create VNets in East and West US
# 3.2 Create ER Gateways in both VNets
# 3.3 Create Public IPs, Web servers, install web app, attach to Public IPs
# 3.4 Connect both ER Gateways to the respective ER Circuits

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
$ResourceGroup = "Company" + $CompanyID.PadLeft(2,"0")
$EastRegion = "eastus"
$WestRegion = "west2us"
$ERCircuit1Name = $ResourceGroup + "-ASH-er"
$ERCircuit2Name = $ResourceGroup + "-SEA-er"
$VNetNameASH = "ASH-VNet01"
$AddressSpaceASH = "10.10." + $CompanyID + ".0/24"
$TenantSpaceASH = "10.10." + $CompanyID + ".0/25"
$GatewaySpaceASH = "10.10." + $CompanyID + ".224/27"
$VNetNameSEA = "SEA-VNet01"
$AddressSpaceSEA = "10.17." + $CompanyID + ".0/24"
$TenantSpaceSEA = "10.17." + $CompanyID + ".0/25"
$GatewaySpaceSEA = "10.17." + $CompanyID + ".224/27"

$VMNameASH = "ASH-VM01"
$VMNameSEA = "SEA-VM01"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 3, estimated total time 35 minutes" -ForegroundColor Cyan

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

# 3.1 Create VNets in East and West US
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Virtual Networks" -ForegroundColor Cyan
Try {$vnetASH = Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroup -Name $VNetNameASH -ErrorAction Stop
     Write-Host "Resource exsists, skipping"}
Catch {$vnetASH = New-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroup -Name $VNetNameASH -AddressPrefix $AddressSpaceASH -Location $EastRegion  
       # Add Subnets
       Write-Host (Get-Date)' - ' -NoNewline
       Write-Host "Adding subnets" -ForegroundColor Cyan
       Add-AzureRmVirtualNetworkSubnetConfig -Name "Tenant" -VirtualNetwork $vnet -AddressPrefix $TenantSpaceASH | Out-Null
       Add-AzureRmVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet -AddressPrefix $GatewaySpaceASH | Out-Null
       Set-AzureRmVirtualNetwork -VirtualNetwork $vnetASH | Out-Null
       }
Try {$vnetSEA = Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroup -Name $VNetNameSEA -ErrorAction Stop
     Write-Host "Resource exsists, skipping"}
Catch {$vnetSEA = New-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroup -Name $VNetNameSEA -AddressPrefix $AddressSpaceSEA -Location $WestRegion  
       # Add Subnets
       Write-Host (Get-Date)' - ' -NoNewline
       Write-Host "Adding subnets" -ForegroundColor Cyan
       Add-AzureRmVirtualNetworkSubnetConfig -Name "Tenant" -VirtualNetwork $vnet -AddressPrefix $TenantSpaceSEA | Out-Null
       Add-AzureRmVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet -AddressPrefix $GatewaySpaceSEA | Out-Null
       Set-AzureRmVirtualNetwork -VirtualNetwork $vnetSEA | Out-Null
       }

# 3.2 Create ER Gateways in both VNets
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating gateways" -ForegroundColor Cyan
Try {Get-AzureRmVirtualNetworkGateway -Name $VNetNameASH'-gw' -ResourceGroupName $ResourceGroup -ErrorAction Stop | Out-Null
     Write-Host "Resource exsists, skipping"}
Catch {
    $vnetASH = Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroup -Name $VNetNameASH
    $subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnetASH
    Try {$pipASH = Get-AzureRmPublicIpAddress -Name $VNetNameASH'-gw-pip'  -ResourceGroupName $ResourceGroup -ErrorAction Stop}
    Catch {$pipASH = New-AzureRmPublicIpAddress -Name $VNetNameASH'-gw-pip' -ResourceGroupName $ResourceGroup -Location $EastRegion -AllocationMethod Dynamic}
    $ipconf = New-AzureRmVirtualNetworkGatewayIpConfig -Name "gwipconf" -Subnet $subnet -PublicIpAddress $pipASH
    New-AzureRmVirtualNetworkGateway -Name $VNetNameASH'-gw' -ResourceGroupName $ResourceGroup -Location $EastRegion -IpConfigurations $ipconf -GatewayType Expressroute -GatewaySku Standard -AsJob
    }
Try {Get-AzureRmVirtualNetworkGateway -Name $VNetNameSEA'-gw' -ResourceGroupName $ResourceGroup -ErrorAction Stop | Out-Null
    Write-Host "Resource exsists, skipping"}
Catch {
   $vnetSEA = Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroup -Name $VNetNameSEA
   $subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnetSEA
   Try {$pipSEA = Get-AzureRmPublicIpAddress -Name $VNetNameSEA'-gw-pip'  -ResourceGroupName $ResourceGroup -ErrorAction Stop}
   Catch {$pipSEA = New-AzureRmPublicIpAddress -Name $VNetNameSEA'-gw-pip' -ResourceGroupName $ResourceGroup -Location $WestRegion -AllocationMethod Dynamic}
   $ipconf = New-AzureRmVirtualNetworkGatewayIpConfig -Name "gwipconf" -Subnet $subnet -PublicIpAddress $pipSEA
   New-AzureRmVirtualNetworkGateway -Name $VNetNameSEA'-gw' -ResourceGroupName $ResourceGroup -Location $WestRegion -IpConfigurations $ipconf -GatewayType Expressroute -GatewaySku Standard -AsJob
   }

# 3.3 Create Public IPs, Web servers, install web app, attach to Public IPs
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating VMs" -ForegroundColor Cyan

	$VMNameSEA = "SEA-VM01"
	Write-Host "Building $VMName"
	Write-Host "  creating NSG and RDP rule"
	Try {$nsg = Get-AzureRmNetworkSecurityGroup -Name $VMName"-nic-nsg" -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop
	     Write-Host "    resource exists, skipping"}
	Catch {$nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name myNSGRuleRDP -Protocol Tcp -Direction Inbound `
                                                                  -Priority 1000 -SourceAddressPrefix * -SourcePortRange * `
                                                                  -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
               $nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $rg.ResourceGroupName -Location $rg.Location -Name $VMName"-nic-nsg" -SecurityRules $nsgRuleRDP}
	Write-Host "  creating NIC"
	Try {$nic = Get-AzureRmNetworkInterface -Name $VMName'-nic' -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop
		 Write-Host "    resource exists, skipping"}
	Catch {$nic = New-AzureRmNetworkInterface -Name $VMName'-nic' -ResourceGroupName $rg.ResourceGroupName -Location $rg.Location `
											  -SubnetId $vnet.Subnets[0].Id -NetworkSecurityGroupId $nsg.Id -ErrorAction Stop}
	Write-Host "  creating VM"
	Try {Get-AzureRmVM -ResourceGroupName $rg.ResourceGroupName -Name $VMName -ErrorAction Stop | Out-Null
		 Write-Host "    VM exists, skipping"}
	Catch {$vmConfig = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize -ErrorAction Stop| `
		   Set-AzureRmVMOperatingSystem -Windows -ComputerName $VMName -Credential $cred -EnableAutoUpdate -ProvisionVMAgent | `
		   Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2016-Datacenter -Version latest | `
		   Add-AzureRmVMNetworkInterface -Id $nic.Id | Set-AzureRmVMBootDiagnostics -Disable
		   Write-Host "    queuing VM build job"
		   New-AzureRmVM -ResourceGroupName $rg.ResourceGroupName -Location $rg.Location -VM $vmConfig -AsJob | Out-Null}

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Waiting for VM Build Jobs to finish, this script will continue after 10 minutes or when VMs are built, whichever is first." -ForegroundColor Cyan
Get-Job -Command "New-AzureRmVM" | wait-job -Timeout 600 | Out-Null

# 5. Do post deploy IIS build
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Running post VM deploy build scripts" -ForegroundColor Cyan
$ScriptStorageAccount = "vdcworkshop"
$ScriptName = "IISBuild.ps1"
$ExtensionName = 'BuildIIS'
$timestamp = (Get-Date).Ticks
$ScriptLocation = "https://$ScriptStorageAccount.blob.core.windows.net/scripts/" + $ScriptName
$ScriptExe = "(.\$ScriptName -theAdmin '$VMUserName' -theSecret '" + $kvs.SecretValueText + "')"
$PublicConfiguration = @{"fileUris" = [Object[]]"$ScriptLocation";"timestamp" = "$timestamp";"commandToExecute" = "powershell.exe -ExecutionPolicy Unrestricted -Command $ScriptExe"}
For ($i=1; $i -le 3; $i++) {
	$VMName = $VMNamePrefix + $i.ToString("00")
	Try {Get-AzureRmVMExtension -ResourceGroupName $rg.ResourceGroupName -VMName $VMName -Name $ExtensionName -ErrorAction Stop | Out-Null}
	Catch {Write-Host "  queuing IIS build job for $VMName"
		   Set-AzureRmVMExtension -ResourceGroupName $rg.ResourceGroupName -VMName $VMName -Location $rg.Location -Name $ExtensionName `
								  -Publisher 'Microsoft.Compute' -ExtensionType 'CustomScriptExtension' -TypeHandlerVersion '1.9' -Settings $PublicConfiguration  `
								  -AsJob -ErrorAction Stop | Out-Null}
}

# 3.4 Connect both ER Gateways to the respective ER Circuits

# Get Circuit Info
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Pulling circuit information' -ForegroundColor Cyan
Try {$ckt1 = Get-AzureRmExpressRouteCircuit -ResourceGroupName $rg.ResourceGroupName -Name $ERCircuit1Name -ErrorAction Stop | Out-Null
     $ckt2 = Get-AzureRmExpressRouteCircuit -ResourceGroupName $rg.ResourceGroupName -Name $ERCircuit2Name -ErrorAction Stop | Out-Null
}
Catch {Write-Warning "One or both circuits weren't found, please ensure step one is successful before running this script."
       Return
}

# Ensure both circuits are provisioned and ready to go
If ($ckt.provisioned -eq "Provisioned" -and $ckt.Provisioned -eq "Provisioned") {
    Add-AzureRmExpressRouteCircuitConnectionConfig -Name 'SEAtoASH' -ExpressRouteCircuit $ckt1 -PeerExpressRouteCircuitPeering $ckt2.Peerings[0].Id -AddressPrefix '__.__.__.__/29'
}
Else {Write-Warning "One or both circuits aren't in the provisioend state. Please ensure your proctor has provisioned both circuits before running this script."
      Return
}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 2 completed successfully" -ForegroundColor Green
Write-Host "Please proceed with the step 2 validation"
Write-Host
