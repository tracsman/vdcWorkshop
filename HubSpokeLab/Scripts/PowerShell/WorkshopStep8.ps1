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
$VNetName = "Remote-VNet01"
$IPSecondOctet = "40" # 40 is for West Europe
$IPThirdOctet = $CompanyID
$AddressSpace  = "10.$IPSecondOctet.$IPThirdOctet.0/24"
$TenantSpace   = "10.$IPSecondOctet.$IPThirdOctet.0/28"
$GatewaySpace  = "10.$IPSecondOctet.$IPThirdOctet.96/27"
$ERCircuitName = $RGName + "-er"
$GWName = $VNetName + "-gw"
$PIPName = $GWName + "-ip"
$ConnectionName = $GWName + "-conn"
$VMName = "Remote-VM01"
$VMUserName = "User01"
$ShortRegion = "westeurope"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 8, estimated total time 20 minutes" -ForegroundColor Cyan

# Login and permissions check
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Checking login and permissions" -ForegroundColor Cyan
Try {Get-AzResourceGroup -Name $RGName -ErrorAction Stop | Out-Null}
Catch {# Login and set subscription for ARM
        Write-Host "Logging in to ARM"
        Try {$Sub = (Set-AzContext -Subscription $subID -ErrorAction Stop).Subscription}
        Catch {Connect-AzAccount | Out-Null
                $Sub = (Set-AzContext -Subscription $subID -ErrorAction Stop).Subscription}
        Write-Host "Current Sub:",$Sub.Name,"(",$Sub.Id,")"
        Try {Get-AzResourceGroup -Name $RGName -ErrorAction Stop | Out-Null}
        Catch {Write-Warning "Permission check failed, ensure company id is set correctly!"
               Return}
}

# 1. Create Virtual Network
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Virtual Network" -ForegroundColor Cyan
Try {$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
	 Write-Host "  resource exists, skipping"}
Catch {$vnet = New-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -AddressPrefix $AddressSpace -Location $ShortRegion  -WarningAction SilentlyContinue
       # Add Subnets
       Write-Host (Get-Date)' - ' -NoNewline
       Write-Host "Adding subnets" -ForegroundColor Cyan
       Add-AzVirtualNetworkSubnetConfig -Name "Tenant" -VirtualNetwork $vnet -AddressPrefix $TenantSpace | Out-Null
       Add-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet -AddressPrefix $GatewaySpace | Out-Null
       Set-AzVirtualNetwork -VirtualNetwork $vnet | Out-Null
	   $vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName
}

# 2. Create the ExpressRoute Gateway (AsJob)
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Creating Gateway' -ForegroundColor Cyan
Try {$gw = Get-AzVirtualNetworkGateway -Name $GWName -ResourceGroupName $RGName -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {
    $subnet = Get-AzVirtualNetworkSubnetConfig -Name GatewaySubnet -VirtualNetwork $VNet
    Try {$pip = Get-AzPublicIpAddress -Name $PIPName  -ResourceGroupName $RGName -ErrorAction Stop}
    Catch {$pip = New-AzPublicIpAddress -Name $PIPName  -ResourceGroupName $RGName -Location $ShortRegion -AllocationMethod Dynamic}
    $ipconf = New-AzVirtualNetworkGatewayIpConfig -Name gwipconf -Subnet $subnet -PublicIpAddress $pip
    $gw = New-AzVirtualNetworkGateway -Name $GWName -ResourceGroupName $RGName -Location $ShortRegion `
										   -IpConfigurations $ipconf -GatewayType Expressroute -GatewaySku Standard -AsJob
}

# 3. Create an inbound network security group rule for port 3389
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating NSG and RDP rule" -ForegroundColor Cyan
Try {$nsg = Get-AzNetworkSecurityGroup -Name $VMName"-nic-nsg" -ResourceGroupName $RGName -ErrorAction Stop
        Write-Host "  resource exists, skipping"}
Catch {
       # Create a network security group rule
       $nsgRuleRDP = New-AzNetworkSecurityRuleConfig -Name myNSGRuleRDP -Protocol Tcp -Direction Inbound `
                                                          -Priority 1000 -SourceAddressPrefix * -SourcePortRange * `
                                                          -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
       # Create a network security group
       $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $RGName -Location $ShortRegion -Name $VMName"-nic-nsg" -SecurityRules $nsgRuleRDP
}

# 4. Create a public IP address
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Public IP address" -ForegroundColor Cyan
Try {$pip = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $VMName'-nic-pip' -ErrorAction Stop
        Write-Host "  resource exists, skipping"}
Catch {$pip = New-AzPublicIpAddress -ResourceGroupName $RGName -Location $ShortRegion -AllocationMethod Dynamic -Name $VMName'-nic-pip'}

# 5. Create a virtual network card and associate with public IP address and NSG
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating NIC" -ForegroundColor Cyan
Try {$nic = Get-AzNetworkInterface -Name $VMName'-nic' -ResourceGroupName $RGName -ErrorAction Stop
        Write-Host "  resource exists, skipping"}
Catch {$nic = New-AzNetworkInterface -Name $VMName'-nic' -ResourceGroupName $RGName -Location $ShortRegion `
                                          -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id -ErrorAction Stop}

# 6. Get secrets from KeyVault
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Obtaining secrets from Key Vault" -ForegroundColor Cyan
$kvName = $RGName + '-kv'
$kvs = Get-AzKeyVaultSecret -VaultName $kvName -Name $VMUserName -ErrorAction Stop
$cred = New-Object System.Management.Automation.PSCredential ($kvs.Name, $kvs.SecretValue) -ErrorAction Stop

# 7. Create a virtual machine configuration
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating VM" -ForegroundColor Cyan
$vmConfig = New-AzVMConfig -VMName $VMName -VMSize Standard_A4_v2 -ErrorAction Stop| `
        Set-AzVMOperatingSystem -Windows -ComputerName $VMName -Credential $cred -EnableAutoUpdate -ProvisionVMAgent | `
        Set-AzVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer `
        -Skus 2019-Datacenter -Version latest | Add-AzVMNetworkInterface -Id $nic.Id | Set-AzVMBootDiagnostic -Disable

# 8. Create the VM (AsJob)
Try {Get-AzVM -ResourceGroupName $RGName -Name $VMName -ErrorAction Stop | Out-Null
     Write-Host "  resource exists, skipping"}
Catch {New-AzVM -ResourceGroupName $RGName -Location $ShortRegion -VM $vmConfig -AsJob -ErrorAction Stop | Out-Null}

# 9.  Wait for Gateway and VM jobs to complete
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Waiting for Gateway and VM Build Jobs to finish..." -ForegroundColor Cyan
Get-Job | wait-job -Timeout 900 | Out-Null

# 10. Post installation config
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Running post-deployment scripts on VM" -ForegroundColor Cyan
Try {Get-AzVMExtension -Name AllowICMP -ResourceGroupName $RGName -VMName $VMName -ErrorAction Stop | Out-Null
     Write-Host "Extension already deployed, skipping"}
Catch {
    $ScriptStorageAccount = "vdcworkshop"
    $ScriptName = "AllowICMPv4.ps1"
    $ExtensionName = 'AllowICMP'
    $timestamp = (Get-Date).Ticks

    $ScriptLocation = "https://$ScriptStorageAccount.blob.core.windows.net/scripts/" + $ScriptName
    $ScriptExe = ".\$ScriptName"
 
    $PublicConfiguration = @{"fileUris" = [Object[]]"$ScriptLocation";"timestamp" = "$timestamp";"commandToExecute" = "powershell.exe -ExecutionPolicy Unrestricted -Command $ScriptExe"}
 
    Set-AzVMExtension -ResourceGroupName $RGName -VMName $VMName -Location $ShortRegion `
    -Name $ExtensionName -Publisher 'Microsoft.Compute' -ExtensionType 'CustomScriptExtension' -TypeHandlerVersion '1.9' `
    -Settings $PublicConfiguration -ErrorAction Stop | Out-Null
}

# 11. Create the connection object connecting the Gateway and the Circuit 
Try {$circuit = Get-AzExpressRouteCircuit -ResourceGroupName $RGName -Name $ERCircuitName -ErrorAction Stop}
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
Try {Get-AzVirtualNetworkGatewayConnection -Name $ConnectionName -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
     Write-Host '  resource exists, skipping'}
Catch {$gw = Get-AzVirtualNetworkGateway -Name $GWName -ResourceGroupName $RGName
       New-AzVirtualNetworkGatewayConnection -Name $ConnectionName -ResourceGroupName $RGName -Location $ShortRegion `
       -VirtualNetworkGateway1 $gw -PeerId $circuit.Id -ConnectionType ExpressRoute | Out-Null
}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 8 completed successfully" -ForegroundColor Green
Write-Host
