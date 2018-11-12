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

# Step 8
# Create Remote VNet (Remote-VNet01) connected back to ER
# Description: In this script we will create a new VNet in Erupoe with a VM connected to the ExpressRoute circuit in Washington, DC

# Detailed Steps:
#  1. Create Virtual Network
#  2. Create the ExpressRoute Gateway (AsJob)
#  3. Create an inbound network security group rule for port 3389
#  4. Create a public IP
#  5. Create a NIC, associate the NSG and IP
#  6. Get secrets from KeyVault
#  7. Create a VM config
#  8. Create the VM (AsJob)
#  9. Wait for Gateway and VM jobs to complete
# 10. Post installation config
# 11. Create the connection object connecting the Gateway and the Circuit 

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
$VNetName = "Remote-VNet01"
$IPSecondOctet = "40" # 40 is for West Europe
$IPThirdOctet = "1" + $CompanyID.PadLeft(2,"0")
$AddressSpace  = "10.$IPSecondOctet.$IPThirdOctet.0/24"
$TenantSpace   = "10.$IPSecondOctet.$IPThirdOctet.0/28"
$GatewaySpace  = "10.$IPSecondOctet.$IPThirdOctet.96/27"
$ERCircuitName = $ResourceGroup + "-er"
$GWName = $VNetName + "-gw"
$PIPName = $GWName + "-ip"
$ConnectionName = $GWName + "-conn"
$VMName = "Remote-VM01"
$VMUserName = "Company" + $CompanyID.PadLeft(2,"0") + "User"
$ShortRegion = "westeurope"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 8, estimated total time 20 minutes" -ForegroundColor Cyan

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

# 1. Create Virtual Network
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Virtual Network" -ForegroundColor Cyan
Try {$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $rg.ResourceGroupName -Name $VNetName -ErrorAction Stop
	 Write-Host "  resource exists, skipping"}
Catch {$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $rg.ResourceGroupName -Name $VNetName -AddressPrefix $AddressSpace -Location $ShortRegion  -WarningAction SilentlyContinue
       # Add Subnets
       Write-Host (Get-Date)' - ' -NoNewline
       Write-Host "Adding subnets" -ForegroundColor Cyan
       Add-AzureRmVirtualNetworkSubnetConfig -Name "Tenant" -VirtualNetwork $vnet -AddressPrefix $TenantSpace | Out-Null
       Add-AzureRmVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet -AddressPrefix $GatewaySpace | Out-Null
       Set-AzureRmVirtualNetwork -VirtualNetwork $vnet | Out-Null
	   $vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $rg.ResourceGroupName -Name $VNetName
}

# 2. Create the ExpressRoute Gateway (AsJob)
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Creating Gateway' -ForegroundColor Cyan
Try {$gw = Get-AzureRmVirtualNetworkGateway -Name $GWName -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {
    $subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name GatewaySubnet -VirtualNetwork $VNet
    Try {$pip = Get-AzureRmPublicIpAddress -Name $PIPName  -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop}
    Catch {$pip = New-AzureRmPublicIpAddress -Name $PIPName  -ResourceGroupName $rg.ResourceGroupName -Location $ShortRegion -AllocationMethod Dynamic}
    $ipconf = New-AzureRmVirtualNetworkGatewayIpConfig -Name gwipconf -Subnet $subnet -PublicIpAddress $pip
    $gw = New-AzureRmVirtualNetworkGateway -Name $GWName -ResourceGroupName $rg.ResourceGroupName -Location $ShortRegion `
										   -IpConfigurations $ipconf -GatewayType Expressroute -GatewaySku Standard -AsJob
}

# 3. Create an inbound network security group rule for port 3389
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating NSG and RDP rule" -ForegroundColor Cyan
Try {$nsg = Get-AzureRmNetworkSecurityGroup -Name $VMName"-nic-nsg" -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop
        Write-Host "  resource exists, skipping"}
Catch {
       # Create a network security group rule
       $nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name myNSGRuleRDP -Protocol Tcp -Direction Inbound `
                                                          -Priority 1000 -SourceAddressPrefix * -SourcePortRange * `
                                                          -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
       # Create a network security group
       $nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $rg.ResourceGroupName -Location $ShortRegion -Name $VMName"-nic-nsg" -SecurityRules $nsgRuleRDP
}

# 4. Create a public IP address
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Public IP address" -ForegroundColor Cyan
Try {$pip = Get-AzureRmPublicIpAddress -ResourceGroupName $rg.ResourceGroupName -Name $VMName'-nic-pip' -ErrorAction Stop
        Write-Host "  resource exists, skipping"}
Catch {$pip = New-AzureRmPublicIpAddress -ResourceGroupName $rg.ResourceGroupName -Location $ShortRegion -AllocationMethod Dynamic -Name $VMName'-nic-pip'}

# 5. Create a virtual network card and associate with public IP address and NSG
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating NIC" -ForegroundColor Cyan
Try {$nic = Get-AzureRmNetworkInterface -Name $VMName'-nic' -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop
        Write-Host "  resource exists, skipping"}
Catch {$nic = New-AzureRmNetworkInterface -Name $VMName'-nic' -ResourceGroupName $rg.ResourceGroupName -Location $ShortRegion `
                                          -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id -ErrorAction Stop}

# 6. Get secrets from KeyVault
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Obtaining secrets from Key Vault" -ForegroundColor Cyan
$kvName = $rg.ResourceGroupName + '-kv'
$kvs = Get-AzureKeyVaultSecret -VaultName $kvName -Name $VMUserName -ErrorAction Stop
$cred = New-Object System.Management.Automation.PSCredential ($kvs.Name, $kvs.SecretValue) -ErrorAction Stop

# 7. Create a virtual machine configuration
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating VM" -ForegroundColor Cyan
$vmConfig = New-AzureRmVMConfig -VMName $VMName -VMSize Standard_A4_v2 -ErrorAction Stop| `
        Set-AzureRmVMOperatingSystem -Windows -ComputerName $VMName -Credential $cred -EnableAutoUpdate -ProvisionVMAgent | `
        Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer `
        -Skus 2016-Datacenter -Version latest | Add-AzureRmVMNetworkInterface -Id $nic.Id | Set-AzureRmVMBootDiagnostics -Disable

# 8. Create the VM (AsJob)
Try {Get-AzureRmVM -ResourceGroupName $rg.ResourceGroupName -Name $VMName -ErrorAction Stop | Out-Null
     Write-Host "  resource exists, skipping"}
Catch {New-AzureRmVM -ResourceGroupName $rg.ResourceGroupName -Location $ShortRegion -VM $vmConfig -AsJob -ErrorAction Stop | Out-Null}

# 9.  Wait for Gateway and VM jobs to complete
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Waiting for Gateway and VM Build Jobs to finish..." -ForegroundColor Cyan
Get-Job | wait-job -Timeout 900 | Out-Null

# 10. Post installation config
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Running post-deployment scripts on VM" -ForegroundColor Cyan
Try {Get-AzureRmVMExtension -Name AllowICMP -ResourceGroupName $rg.ResourceGroupName -VMName $VMName -ErrorAction Stop
     Write-Host "Extension already deployed, skipping"}
Catch {
    $ScriptStorageAccount = "vdcworkshop"
    $ScriptName = "AllowICMPv4.ps1"
    $ExtensionName = 'AllowICMP'
    $timestamp = (Get-Date).Ticks

    $ScriptLocation = "https://$ScriptStorageAccount.blob.core.windows.net/scripts/" + $ScriptName
    $ScriptExe = ".\$ScriptName"
 
    $PublicConfiguration = @{"fileUris" = [Object[]]"$ScriptLocation";"timestamp" = "$timestamp";"commandToExecute" = "powershell.exe -ExecutionPolicy Unrestricted -Command $ScriptExe"}
 
    Set-AzureRmVMExtension -ResourceGroupName $rg.ResourceGroupName -VMName $VMName -Location $ShortRegion `
    -Name $ExtensionName -Publisher 'Microsoft.Compute' -ExtensionType 'CustomScriptExtension' -TypeHandlerVersion '1.9' `
    -Settings $PublicConfiguration -ErrorAction Stop | Out-Null
}

# 11. Create the connection object connecting the Gateway and the Circuit 
Try {$circuit = Get-AzureRmExpressRouteCircuit -ResourceGroupName $rg.ResourceGroupName -Name $ERCircuitName -ErrorAction Stop}
Catch {
    Write-Warning 'The ExpressRoute Circuit was not found. Complete the second step of the workshop first, then have the proctor provision the circuit before running this script!'
    Return
}
If ($circuit.ServiceProviderProvisioningState -ne 'Provisioned') { 
    Write-Warning 'The ExpressRoute Circuit has not been provisioned by your Service Provider, have the proctor provision your circuit before running this script!'
    Return
}
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Connecting Gateway to ExpressRoute' -ForegroundColor Cyan
Try {Get-AzureRmVirtualNetworkGatewayConnection -Name $ConnectionName -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop | Out-Null
     Write-Host '  resource exists, skipping'}
Catch {$gw = Get-AzureRmVirtualNetworkGateway -Name $GWName -ResourceGroupName $rg.ResourceGroupName
       New-AzureRmVirtualNetworkGatewayConnection -Name $ConnectionName -ResourceGroupName $rg.ResourceGroupName -Location $ShortRegion `
       -VirtualNetworkGateway1 $gw -PeerId $circuit.Id -ConnectionType ExpressRoute | Out-Null
}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 8 completed successfully" -ForegroundColor Green
Write-Host
