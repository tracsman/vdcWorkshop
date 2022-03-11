#
# DIY Workshop Maximus
#
#
# Module 1 - Hub - Create resource group, key vault and secret, Hub VNet, VM, and deploy website
# Module 2 - Access - Create NSG, Public IPs, IP Prefix, Bastion, VNet NAT
# Module 3 - Secure - Create Firewall, Firewall Policy, Log Analytics, UDR
# Module 4 - Web Tier - Create Spoke1 VNet, VNet Peering, 3xVM with Web Site, App Gateway
# Module 5 - Data Tier - Create Spoke2 VNet, Load Balancer, VMSS configured as a File Server
# 

# Module 4 - Web Tier - Create Spoke1 VNet, VNet Peering, 3xVM with Web Site, App Gateway
# 4.1 Validate and Initialize
# 4.2 Create Spoke VNet and NSG, apply UDR
# 4.3 Enable VNet Peering to the hub using remote gateway
# 4.4 Get secrets from KeyVault
# 4.5 Loop: Create VMs
# 4.6 Do post deploy IIS build
# 4.7 Create AppGateway


# 4.1 Validate and Initialize
# Load Initialization Variables
$ScriptDir = "$env:HOME/Scripts"
If (Test-Path -Path $ScriptDir/init.txt) {
        Get-Content $ScriptDir/init.txt | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}}}
Else {Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}

# Variable Initialization
# $SubID     = defined in and pulled from the init.txt file above
# $ShortRegion defined in and pulled from the init.txt file above
# $RGName    = defined in and pulled from the init.txt file above
# Non-configurable Variable Initialization (ie don't modify these)
$VNetName     = "Spoke01-VNet"
$HubName      =  "Hub-VNet"
$AddressSpace = "10.1.0.0/16"
$TenantSpace  = "10.1.1.0/24"
$AppGWSpace   = "10.1.2.0/24"
$VMSize       = "Standard_B2S"
$VMNamePrefix = "Spoke01-VM"
$AppGWName    = "Spoke01-AppGw"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting Module 4, estimated total time 15 minutes" -ForegroundColor Cyan

# Set Subscription and Login
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Setting Subscription Context" -ForegroundColor Cyan
Try {$myContext = Set-AzContext -Subscription $SubID -ErrorAction Stop}
Catch {Write-Warning "Permission check failed, ensure Sub ID is set correctly!"
        Return}
Write-Host "  Current Sub:",$myContext.Subscription.Name,"(",$myContext.Subscription.Id,")"

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "  Checking Login" -ForegroundColor Cyan
$RegEx = '^([\w-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([\w-]+\.)+))([a-zA-Z]{2,5}|[0-9]{1,3})(\]?)$'
If ($myContext.Account.Id -notmatch $RegEx) {
        Write-Host "Fatal Error: You are logged in with a Managed Service bearer token" -ForegroundColor Red
        Write-Host "To correct this, you'll need to login using your Azure credentials."
        Write-Host "To do this, at the command prompt, enter: " -NoNewline
        Write-Host "Connect-AzAccount -UseDeviceAuthentication" -ForegroundColor Yellow
        Write-Host "This command will show a URL and Code. Open a new browser tab and navigate to that URL, enter the code, and login with your Azure credentials"
        Write-Host
        Return
}
Write-Host "  Current User: ",$myContext.Account.Id

# Pulling required components
$fwRouteTable = Get-AzRouteTable -Name $HubName'-rt-fw' -ResourceGroupName $RGName -ErrorAction Stop

# 4.2 Create Spoke VNet and NSG, apply UDR

# Create Tenant Subnet NSG
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Spoke01 NSG" -ForegroundColor Cyan
Try {$nsg = Get-AzNetworkSecurityGroup -Name $VNetName'-nsg' -ResourceGroupName $RGName -ErrorAction Stop
Write-Host "  NSG exists, skipping"}
Catch {$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $RGName -Location $ShortRegion -Name $VNetName'-nsg'}

# Create Virtual Network, apply NSG and UDR
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Virtual Network" -ForegroundColor Cyan
Try {$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
	 Write-Host "  resource exists, skipping"}
Catch {$vnet = New-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -AddressPrefix $AddressSpace -Location $ShortRegion
	   # Add Subnets
	   Write-Host (Get-Date)' - ' -NoNewline
	   Write-Host "Adding subnets" -ForegroundColor Cyan
	   Add-AzVirtualNetworkSubnetConfig -Name "Tenant" -VirtualNetwork $vnet -AddressPrefix $TenantSpace -RouteTable $fwRouteTable -NetworkSecurityGroup $nsg| Out-Null
	   Add-AzVirtualNetworkSubnetConfig -Name "AppGateway" -VirtualNetwork $vnet -AddressPrefix $AppGWSpace | Out-Null
	   Set-AzVirtualNetwork -VirtualNetwork $vnet | Out-Null
	   $vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop}

# 4.3 Enable VNet Peering to the hub using remote gateway
Try {$hubvnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $HubName -ErrorAction Stop}
Catch {Write-Warning "Hub VNet not found, please execute Module 1 from this workshop before running this script."
	  Return}
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Peering Hub to Spoke" -ForegroundColor Cyan
Try {Get-AzVirtualNetworkPeering -Name Hub01toSpoke01 -VirtualNetworkName $hubvnet.Name -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
	Write-Host "  peering exists, skipping" }
Catch {Try {Add-AzVirtualNetworkPeering -Name Hub01toSpoke01 -VirtualNetwork $hubvnet -RemoteVirtualNetworkId $vnet.Id -AllowGatewayTransit -ErrorAction Stop | Out-Null}
	  Catch {Write-Warning "Error creating VNet Peering"; Return}}

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Peering Spoke to Hub" -ForegroundColor Cyan
Try {Get-AzVirtualNetworkPeering -Name Spoke01toHub01 -VirtualNetworkName $vnet.Name -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
	Write-Host "  peering exists, skipping" }
Catch {Try {Add-AzVirtualNetworkPeering -Name Spoke01toHub01 -VirtualNetwork $vnet -RemoteVirtualNetworkId $hubvnet.Id -ErrorAction Stop | Out-Null}
	  Catch {Write-Warning "Error creating VNet Peering"; Return}}

# 4.4 Get secrets from KeyVault
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Obtaining secrets from Key Vault" -ForegroundColor Cyan
$kvName = (Get-AzKeyVault -ResourceGroupName $RGName | Select-Object -First 1).VaultName
$kvs01 = Get-AzKeyVaultSecret -VaultName $kvName -Name $UserName01 -ErrorAction Stop
$kvs02 = Get-AzKeyVaultSecret -VaultName $kvName -Name $UserName02 -ErrorAction Stop
$kvs03 = Get-AzKeyVaultSecret -VaultName $kvName -Name $UserName03 -ErrorAction Stop 
$cred = New-Object System.Management.Automation.PSCredential ($kvs01.Name, $kvs01.SecretValue)
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kvs02.SecretValue)
try {
    $kvs02 = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
} finally {
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
}
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kvs03.SecretValue)
try {
    $kvs03 = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
} finally {
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
}

# 4.5 Loop: Create VMs
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating VMs" -ForegroundColor Cyan
$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName
$snTenant = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "Tenant"
For ($i=1; $i -le 3; $i++) {
	$VMName = $VMNamePrefix + $i.ToString("00")
	Write-Host "Building $VMName"
	Write-Host "  creating NIC"
	Try {$nic = Get-AzNetworkInterface -Name $VMName'-nic' -ResourceGroupName $RGName -ErrorAction Stop
		 Write-Host "    resource exists, skipping"}
	Catch {$nic = New-AzNetworkInterface -Name $VMName'-nic' -ResourceGroupName $RGName -Location $ShortRegion `
								  -SubnetId $snTenant.Id -ErrorAction Stop}
	Write-Host "  creating VM"
	Try {Get-AzVM -ResourceGroupName $RGName -Name $VMName -ErrorAction Stop | Out-Null
		 Write-Host "    VM exists, skipping"}
	Catch {$vmConfig = New-AzVMConfig -VMName $VMName -VMSize $VMSize -ErrorAction Stop| `
		   Set-AzVMOperatingSystem -Windows -ComputerName $VMName -Credential $cred -EnableAutoUpdate -ProvisionVMAgent | `
		   Set-AzVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2022-Datacenter -Version latest | `
		   Add-AzVMNetworkInterface -Id $nic.Id | Set-AzVMBootDiagnostic -Disable
		   Write-Host "    queuing VM build job"
		   New-AzVM -ResourceGroupName $RGName -Location $ShortRegion -VM $vmConfig -AsJob | Out-Null}
	}
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Waiting for VM Build Jobs to finish, this script will continue after 10 minutes or when VMs are built, whichever is first." -ForegroundColor Cyan
Get-Job -Command "New-AzVM" | wait-job -Timeout 600 | Out-Null

# 4.6 Do post deploy IIS build
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Running post VM deploy build scripts" -ForegroundColor Cyan
$ScriptStorageAccount = "vdcworkshop"
$ScriptName = "MaxIISBuild.ps1"
$ExtensionName = 'MaxBuildIIS'
$timestamp = (Get-Date).Ticks
$ScriptLocation = "https://$ScriptStorageAccount.blob.core.windows.net/scripts/" + $ScriptName
$ScriptExe = "(.\$ScriptName -User2 '$UserName02' -Pass2 '" + $kvs02 + "' -User3 '$UserName03' -Pass3 '" + $kvs03 + "')"
$PublicConfiguration = @{"fileUris" = [Object[]]"$ScriptLocation";"timestamp" = "$timestamp";"commandToExecute" = "powershell.exe -ExecutionPolicy Unrestricted -Command $ScriptExe"}
For ($i=1; $i -le 3; $i++) {
	$VMName = $VMNamePrefix + $i.ToString("00")
	Try {Get-AzVMExtension -ResourceGroupName $RGName -VMName $VMName -Name $ExtensionName -ErrorAction Stop | Out-Null}
	Catch {Write-Host "  queuing IIS build job for $VMName"
		   Set-AzVMExtension -ResourceGroupName $RGName -VMName $VMName -Location $ShortRegion -Name $ExtensionName `
						 -Publisher 'Microsoft.Compute' -ExtensionType 'CustomScriptExtension' -TypeHandlerVersion '1.9' `
                               -Settings $PublicConfiguration -AsJob -ErrorAction Stop | Out-Null}
}

# 4.7 Create AppGateway
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Application Gateway" -ForegroundColor Cyan
$vnet   = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName
$snAppGW = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name AppGateway
Write-Host "  creating Public IP address"
Try {$pip = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $AppGWName'-pip' -ErrorAction Stop
	 Write-Host "    resource exists, skipping"}
Catch {$pip = New-AzPublicIpAddress -ResourceGroupName $RGName -Location $ShortRegion -AllocationMethod Static -Name $AppGWName'-pip' -Sku Standard}
Write-Host "  creating Application Gateway"
Try {Get-AzApplicationGateway -ResourceGroupName $RGName -Name $AppGWName -ErrorAction Stop | Out-Null
	 Write-Host "    resource exists, skipping"}
Catch {$gipconfig = New-AzApplicationGatewayIPConfiguration -Name myAGIPConfig -Subnet $snAppGW
	  $fipconfig = New-AzApplicationGatewayFrontendIPConfig -Name myAGFrontendIPConfig -PublicIPAddress $pip
	  $frontendport = New-AzApplicationGatewayFrontendPort -Name myFrontendPort -Port 80

	  $address1 = Get-AzNetworkInterface -ResourceGroupName $RGName -Name $VMNamePrefix"01-nic"
	  $address2 = Get-AzNetworkInterface -ResourceGroupName $RGName -Name $VMNamePrefix"02-nic"
	  $address3 = Get-AzNetworkInterface -ResourceGroupName $RGName -Name $VMNamePrefix"03-nic"

	  $backendPool = New-AzApplicationGatewayBackendAddressPool -Name myAGBackendPool -BackendIPAddresses $address1.ipconfigurations[0].privateipaddress, $address2.ipconfigurations[0].privateipaddress, $address3.ipconfigurations[0].privateipaddress
	  $poolSettings = New-AzApplicationGatewayBackendHttpSettings -Name myPoolSettings -Port 80 -Protocol Http -CookieBasedAffinity Enabled -RequestTimeout 120

	  $defaultlistener = New-AzApplicationGatewayHttpListener -Name myAGListener -Protocol Http -FrontendIPConfiguration $fipconfig -FrontendPort $frontendport
	  $frontendRule = New-AzApplicationGatewayRequestRoutingRule -Name rule1 -RuleType Basic -HttpListener $defaultlistener -BackendAddressPool $backendPool -BackendHttpSettings $poolSettings

	  $sku = New-AzApplicationGatewaySku -Name WAF_v2 -Tier WAF_v2 -Capacity 2

	  New-AzApplicationGateway -Name $AppGWName -ResourceGroupName $RGName -Location $ShortRegion -Sku $sku `
						  -BackendAddressPools $backendPool -BackendHttpSettingsCollection $poolSettings `
                                -FrontendIpConfigurations $fipconfig -FrontendPorts $frontendport -RequestRoutingRules $frontendRule `
                                -GatewayIpConfigurations $gipconfig -HttpListeners $defaultlistener | Out-Null
	}

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Waiting for IIS Build Jobs to finish, this script will continue after 10 minutes or when IIS build jobs complete, whichever is first." -ForegroundColor Cyan
Get-Job -Command "Set-AzVMExtension" | wait-job -Timeout 600 | Out-Null

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 4 completed successfully" -ForegroundColor Green
Write-Host "  Checkout your new web farm by going to your App Gateway IP ($($pip.IpAddress))."
Write-Host "  You can also navigate to http://$($pip.IpAddress)/headers to have"
Write-Host "  App Gateway redirect to another backend pool on a remote site."
Write-Host "  Also, WAF Rules and VNet Peerings and UDR settings on the Spoke01 vnet."
Write-Host
