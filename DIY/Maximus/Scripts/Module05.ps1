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

# Module 5 - Data Tier - Create Spoke2 VNet, Load Balancer, VMSS configured as a File Server
# 5.1 Validate and Initialize
# 5.2 Create Spoke VNet and NSG
# 5.3 Enable VNet Peering to the hub
# 5.4 Get secrets from Key Vault
# 5.5 Create load balancer
# 5.6 Create VMSS as File Server

# 5.1 Validate and Initialize
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
$SpokeName   = "Spoke02"
$VNetName    = $SpokeName + "-VNet"
$VNetAddress = "10.2.0.0/16"
$snTenant    = "10.2.1.0/24"
$HubName     = "Hub-VNet"
$SpokeLBIP   = "10.2.1.254" # Using the last usable IP of the tenant subnet
$VMSSName    = $SpokeName + "VM"
$VMSize      = "Standard_B2S"
$UserName    = "User01"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting Module 5, estimated total time 25 minutes" -ForegroundColor Cyan

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
$kvName  = (Get-AzKeyVault -ResourceGroupName $RGName | Select-Object -First 1).VaultName
$fwRouteTable = Get-AzRouteTable -Name $HubName'-rt-fw' -ResourceGroupName $RGName -ErrorAction Stop
Try {$hubvnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $HubName -ErrorAction Stop}
Catch {Write-Warning "Hub VNet not found, please execute Module 1 from this workshop before running this script."
	  Return}

# 5.2 Create Spoke VNet and NSG
# Create Tenant Subnet NSG
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Spoke02 NSG" -ForegroundColor Cyan
Try {$nsg = Get-AzNetworkSecurityGroup -Name $VNetName'-nsg' -ResourceGroupName $RGName -ErrorAction Stop
Write-Host "  NSG exists, skipping"}
Catch {$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $RGName -Location $ShortRegion -Name $VNetName'-nsg'}

# Create Virtual Network, apply NSG and UDR
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Virtual Network" -ForegroundColor Cyan
Try {$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
     Write-Host "  resource exists, skipping"}
Catch {$vnet = New-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -AddressPrefix $VNetAddress -Location $ShortRegion
       # Add Subnets
       Write-Host (Get-Date)' - ' -NoNewline
       Write-Host "Adding subnets" -ForegroundColor Cyan
       Add-AzVirtualNetworkSubnetConfig -Name "Tenant" -VirtualNetwork $vnet -AddressPrefix $snTenant -NetworkSecurityGroup $nsg -RouteTable $fwRouteTable | Out-Null
       Set-AzVirtualNetwork -VirtualNetwork $vnet | Out-Null
       $vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
}

# 5.3 Enable VNet Peering to the hub
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Peering Hub to Spoke" -ForegroundColor Cyan
Try {Get-AzVirtualNetworkPeering -Name HubToSpoke02 -VirtualNetworkName $hubvnet.Name -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
     Write-Host "  peering exists, skipping" }
Catch {Try {Add-AzVirtualNetworkPeering -Name HubToSpoke02 -VirtualNetwork $hubvnet -RemoteVirtualNetworkId $vnet.Id -AllowGatewayTransit -ErrorAction Stop | Out-Null}
	   Catch {Write-Warning "Error creating VNet Peering"; Return}}

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Peering Spoke to Hub" -ForegroundColor Cyan
Try {Get-AzVirtualNetworkPeering -Name Spoke02ToHub -VirtualNetworkName $vnet.Name -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
     Write-Host "  peering exists, skipping" }
Catch {Try {Add-AzVirtualNetworkPeering -Name Spoke02ToHub -VirtualNetwork $vnet -RemoteVirtualNetworkId $hubvnet.Id -ErrorAction Stop | Out-Null}
	   Catch {Write-Warning "Error creating VNet Peering"; Return}}

# 5.4 Get secret from Key Vault
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Obtaining secret from Key Vault" -ForegroundColor Cyan
$kvName = (Get-AzKeyVault -ResourceGroupName $RGName | Select-Object -First 1).VaultName
$kvs = Get-AzKeyVaultSecret -VaultName $kvName -Name $UserName -ErrorAction Stop
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kvs.SecretValue)
try {
    $kvs = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
} finally {
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
}

# 5.5 Create load balancer
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Internal Load Balancer" -ForegroundColor Cyan
$snTenant = Get-AzVirtualNetworkSubnetConfig -Name "Tenant" -VirtualNetwork $vnet
Try {$Spoke02LB = Get-AzLoadBalancer -Name $SpokeName"-lb" -ResourceGroupName $RGName -ErrorAction Stop
	 Write-Host "  resource exists, skipping"}
Catch {$FrontEndIPConfig = New-AzLoadBalancerFrontendIpConfig -Name LB-Frontend -PrivateIpAddress $SpokeLBIP -SubnetId $snTenant.Id
       $BackEndPool= New-AzLoadBalancerBackendAddressPoolConfig -Name "LB-backend"
	  $HealthProbe = New-AzLoadBalancerProbeConfig -Name "HealthProbe" -Protocol Tcp -Port 445 -IntervalInSeconds 15 -ProbeCount 2
       $LBRule = @()
	  $LBRule += New-AzLoadBalancerRuleConfig -Name "SMB445" -FrontendIpConfiguration $FrontEndIPConfig -BackendAddressPool $BackEndPool `
								       -Probe $HealthProbe -Protocol Tcp -FrontendPort 445 -BackendPort 445 -IdleTimeoutInMinutes 15
	  $LBRule += New-AzLoadBalancerRuleConfig -Name "SMB137" -FrontendIpConfiguration $FrontEndIPConfig -BackendAddressPool $BackEndPool `
									  -Probe $HealthProbe -Protocol Tcp -FrontendPort 137 -BackendPort 137 -IdleTimeoutInMinutes 15
	  $LBRule += New-AzLoadBalancerRuleConfig -Name "SMB139" -FrontendIpConfiguration $FrontEndIPConfig -BackendAddressPool $BackEndPool `
									  -Probe $HealthProbe -Protocol Tcp -FrontendPort 139 -BackendPort 139 -IdleTimeoutInMinutes 15
	  $Spoke02LB = New-AzLoadBalancer -ResourceGroupName $RGName -Location $ShortRegion -Name $SpokeName"-lb" -FrontendIpConfiguration $FrontEndIPConfig `
	   						    -LoadBalancingRule $LBRule -BackendAddressPool $BackEndPool -Probe $HealthProbe
	  $Spoke02LB = Get-AzLoadBalancer -ResourceGroupName $RGName -Name $SpokeName"-lb" -ErrorAction Stop}

# 5. Create VMSS
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating VM Scale Set" -ForegroundColor Cyan
$ScriptStorageAccount = "vdcworkshop"
$ScriptName = "FSBuild.ps1"
$ExtensionName = 'BuildFS'
$timestamp = (Get-Date).Ticks
$ScriptLocation = "https://$ScriptStorageAccount.blob.core.windows.net/scripts/" + $ScriptName
$ScriptExe = ".\$ScriptName"
$PublicConfiguration = @{"fileUris" = [Object[]]"$ScriptLocation";"timestamp" = "$timestamp";"commandToExecute" = "powershell.exe -ExecutionPolicy Unrestricted -Command $ScriptExe"}

Try {Get-AzVmss -ResourceGroupName $RGName -VMScaleSetName $VMSSName -ErrorAction Stop | Out-Null
	 Write-Host "  resource exists, skipping"}
Catch {$IPCfg = New-AzVmssIPConfig -Name "VMSSIPConfig" -LoadBalancerInboundNatPoolsId $Spoke02LB.InboundNatPools[0].Id `
				-LoadBalancerBackendAddressPoolsId $Spoke02LB.BackendAddressPools[0].Id -SubnetId $vnet.Subnets[0].Id
	  $VMSSConfig = New-AzVmssConfig -Location $ShortRegion -SkuCapacity 2 -SkuName $VMSize -UpgradePolicyMode "Automatic" | `
                     Add-AzVmssNetworkInterfaceConfiguration -Name "NIC1" -Primary $True -IPConfiguration $IPCfg | `
                     Set-AzVmssOSProfile -ComputerNamePrefix $VMSSName -AdminUsername $UserName -AdminPassword $kvs  | `
                     Set-AzVmssStorageProfile -OsDiskCreateOption 'FromImage' -OsDiskCaching "None" -ImageReferencePublisher MicrosoftWindowsServer `
                                              -ImageReferenceOffer WindowsServer -ImageReferenceSku 2022-Datacenter -ImageReferenceVersion latest `
                                              -ManagedDisk Standard_LRS | `
                    Add-AzVmssExtension -Name $ExtensionName -Publisher 'Microsoft.Compute' -Type 'CustomScriptExtension' -TypeHandlerVersion '1.9' `
                                        -Setting $PublicConfiguration -AutoUpgradeMinorVersion $True
	   New-AzVmss -ResourceGroupName $RGName -Name $VMSSName -VirtualMachineScaleSet $VMSSConfig | Out-Null}

# End Nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 5 completed successfully" -ForegroundColor Green
Write-Host "  All environment components are built, time to play!" -ForegroundColor Green
Write-Host
