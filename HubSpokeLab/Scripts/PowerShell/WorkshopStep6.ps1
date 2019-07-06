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

# Step 6 Deploy App Gateway, Public IPs
# Create Spoke (Spoke02-VNet01): Enable VNet Peering to hub, deploy load balancer, App Gateway, build IIS farm
# Description: In this script we will create a new VNet (Spoke02-VNet01), peer it with the Hub,
#              then create an app gateway, and add three VMs as web servers.

# Detailed steps:
# 1. Create Spoke VNet and NSG
# 2. Enable VNet Peering to the hub using remote gateway
# 3. Get secrets from KeyVault
# 4. Loop: Create VMs
# 5. Do post deploy IIS build
# 6. Create AppGateway

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
$VNetName = "Spoke02-VNet01"
$HubName =  "Hub01-VNet01"
$IPSecondOctet = "10" # 10 is for East US
$IPThirdOctet = $CompanyID
$AddressSpace  = "10.$IPSecondOctet.$IPThirdOctet.192/26"
$TenantSpace   = "10.$IPSecondOctet.$IPThirdOctet.192/28"
$AppGWSpace    = "10.$IPSecondOctet.$IPThirdOctet.208/28"
$VMUserName = "User01"
$VMSize = "Standard_A4_v2"
$VMNamePrefix = "Spoke02-VM"
$AppGWName = "Spoke02-AppGw"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 6, estimated total time 15 minutes" -ForegroundColor Cyan

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

# 1. Create Spoke VNet and NSG
# Create Virtual Network
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Virtual Network" -ForegroundColor Cyan
Try {$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
	 Write-Host "  resource exists, skipping"}
Catch {$vnet = New-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -AddressPrefix $AddressSpace -Location $ShortRegion
	   # Add Subnets
	   Write-Host (Get-Date)' - ' -NoNewline
	   Write-Host "Adding subnets" -ForegroundColor Cyan
	   Add-AzVirtualNetworkSubnetConfig -Name "Tenant" -VirtualNetwork $vnet -AddressPrefix $TenantSpace | Out-Null
	   Add-AzVirtualNetworkSubnetConfig -Name "AppGateway" -VirtualNetwork $vnet -AddressPrefix $AppGWSpace | Out-Null
	   Set-AzVirtualNetwork -VirtualNetwork $vnet | Out-Null
	   $vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
}

# 2. Enable VNet Peering to the hub using remote gateway
Try {$hubvnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $HubName -ErrorAction Stop}
Catch {Write-Warning "Hub VNet not found, please execute Step 1 from this workshop before running this script."
	   Return}
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Peering Hub to Spoke" -ForegroundColor Cyan
Try {Get-AzVirtualNetworkPeering -Name Hub01toSpoke02 -VirtualNetworkName $hubvnet.Name -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
	 Write-Host "  peering exists, skipping" }
Catch {Try {Add-AzVirtualNetworkPeering -Name Hub01toSpoke02 -VirtualNetwork $hubvnet -RemoteVirtualNetworkId $vnet.Id -AllowGatewayTransit -ErrorAction Stop | Out-Null}
	   Catch {Write-Warning "Error creating VNet Peering"; Return}}

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Peering Spoke to Hub" -ForegroundColor Cyan
Try {Get-AzVirtualNetworkPeering -Name Spoke02toHub01 -VirtualNetworkName $vnet.Name -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
	Write-Host "  peering exists, skipping" }
Catch {Try {Add-AzVirtualNetworkPeering -Name Spoke02toHub01 -VirtualNetwork $vnet -RemoteVirtualNetworkId $hubvnet.Id -UseRemoteGateways -ErrorAction Stop | Out-Null}
	   Catch {Write-Warning "Error creating VNet Peering"; Return}}

# 3. Get secrets from KeyVault
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Obtaining secrets from Key Vault" -ForegroundColor Cyan
$kvName = $RGName + '-kv'
$kvs = Get-AzKeyVaultSecret -VaultName $kvName -Name $VMUserName -ErrorAction Stop
$cred = New-Object System.Management.Automation.PSCredential ($kvs.Name, $kvs.SecretValue) -ErrorAction Stop

# 4. Loop: Create VMs
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating VMs" -ForegroundColor Cyan
For ($i=1; $i -le 3; $i++) {
	$VMName = $VMNamePrefix + $i.ToString("00")
	Write-Host "Building $VMName"
	Write-Host "  creating NSG and RDP rule"
	Try {$nsg = Get-AzNetworkSecurityGroup -Name $VMName"-nic-nsg" -ResourceGroupName $RGName -ErrorAction Stop
			Write-Host "    resource exists, skipping"}
	Catch {$nsgRuleRDP = New-AzNetworkSecurityRuleConfig -Name myNSGRuleRDP -Protocol Tcp -Direction Inbound `
															  -Priority 1000 -SourceAddressPrefix * -SourcePortRange * `
															  -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
		   $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $RGName -Location $ShortRegion -Name $VMName"-nic-nsg" -SecurityRules $nsgRuleRDP}
	Write-Host "  creating NIC"
	Try {$nic = Get-AzNetworkInterface -Name $VMName'-nic' -ResourceGroupName $RGName -ErrorAction Stop
		 Write-Host "    resource exists, skipping"}
	Catch {$nic = New-AzNetworkInterface -Name $VMName'-nic' -ResourceGroupName $RGName -Location $ShortRegion `
											  -SubnetId $vnet.Subnets[0].Id -NetworkSecurityGroupId $nsg.Id -ErrorAction Stop}
	Write-Host "  creating VM"
	Try {Get-AzVM -ResourceGroupName $RGName -Name $VMName -ErrorAction Stop | Out-Null
		 Write-Host "    VM exists, skipping"}
	Catch {$vmConfig = New-AzVMConfig -VMName $VMName -VMSize $VMSize -ErrorAction Stop| `
		   Set-AzVMOperatingSystem -Windows -ComputerName $VMName -Credential $cred -EnableAutoUpdate -ProvisionVMAgent | `
		   Set-AzVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2019-Datacenter -Version latest | `
		   Add-AzVMNetworkInterface -Id $nic.Id | Set-AzVMBootDiagnostic -Disable
		   Write-Host "    queuing VM build job"
		   New-AzVM -ResourceGroupName $RGName -Location $ShortRegion -VM $vmConfig -AsJob | Out-Null}
	}
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Waiting for VM Build Jobs to finish, this script will continue after 10 minutes or when VMs are built, whichever is first." -ForegroundColor Cyan
Get-Job -Command "New-AzVM" | wait-job -Timeout 600 | Out-Null

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
	Try {Get-AzVMExtension -ResourceGroupName $RGName -VMName $VMName -Name $ExtensionName -ErrorAction Stop | Out-Null}
	Catch {Write-Host "  queuing IIS build job for $VMName"
		   Set-AzVMExtension -ResourceGroupName $RGName -VMName $VMName -Location $ShortRegion -Name $ExtensionName `
								  -Publisher 'Microsoft.Compute' -ExtensionType 'CustomScriptExtension' -TypeHandlerVersion '1.9' -Settings $PublicConfiguration  `
								  -AsJob -ErrorAction Stop | Out-Null}
}

# 6. Create AppGateway
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Application Gateway" -ForegroundColor Cyan
Write-Host "  creating Public IP address"
Try {$pip = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $AppGWName'-pip' -ErrorAction Stop
	 Write-Host "    resource exists, skipping"}
Catch {$pip = New-AzPublicIpAddress -ResourceGroupName $RGName -Location $ShortRegion -AllocationMethod Static -Name $AppGWName'-pip' -Sku Standard}
Write-Host "  creating Application Gateway"
Try {Get-AzApplicationGateway -ResourceGroupName $RGName -Name $AppGWName -ErrorAction Stop | Out-Null
	 Write-Host "    resource exists, skipping"}
Catch {$gipconfig = New-AzApplicationGatewayIPConfiguration -Name myAGIPConfig -Subnet $vnet.Subnets[1]
	   $fipconfig = New-AzApplicationGatewayFrontendIPConfig -Name myAGFrontendIPConfig -PublicIPAddress $pip
	   $frontendport = New-AzApplicationGatewayFrontendPort -Name myFrontendPort -Port 80

	   $address1 = Get-AzNetworkInterface -ResourceGroupName $RGName -Name "Spoke02-VM01-nic"
	   $address2 = Get-AzNetworkInterface -ResourceGroupName $RGName -Name "Spoke02-VM02-nic"
	   $address3 = Get-AzNetworkInterface -ResourceGroupName $RGName -Name "Spoke02-VM03-nic"

	   $backendPool = New-AzApplicationGatewayBackendAddressPool -Name myAGBackendPool -BackendIPAddresses $address1.ipconfigurations[0].privateipaddress, $address2.ipconfigurations[0].privateipaddress, $address3.ipconfigurations[0].privateipaddress
	   $poolSettings = New-AzApplicationGatewayBackendHttpSettings -Name myPoolSettings -Port 80 -Protocol Http -CookieBasedAffinity Enabled -RequestTimeout 120

	   $defaultlistener = New-AzApplicationGatewayHttpListener -Name myAGListener -Protocol Http -FrontendIPConfiguration $fipconfig -FrontendPort $frontendport
	   $frontendRule = New-AzApplicationGatewayRequestRoutingRule -Name rule1 -RuleType Basic -HttpListener $defaultlistener -BackendAddressPool $backendPool -BackendHttpSettings $poolSettings

	   $sku = New-AzApplicationGatewaySku -Name WAF_v2 -Tier WAF_v2 -Capacity 2

	   New-AzApplicationGateway -Name $AppGWName -ResourceGroupName $RGName -Location $ShortRegion -Sku $sku `
									 -BackendAddressPools $backendPool -BackendHttpSettingsCollection $poolSettings -FrontendIpConfigurations $fipconfig `
									 -GatewayIpConfigurations $gipconfig -FrontendPorts $frontendport -HttpListeners $defaultlistener -RequestRoutingRules $frontendRule | Out-Null
	}

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Waiting for IIS Build Jobs to finish, this script will continue after 10 minutes or when IIS build jobs complete, whichever is first." -ForegroundColor Cyan
Get-Job -Command "Set-AzVMExtension" | wait-job -Timeout 600 | Out-Null

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 6 completed successfully" -ForegroundColor Green
Write-Host
