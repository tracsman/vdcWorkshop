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

# Step 5
# Create Spoke (Spoke01-VNet01): Enable VNet Peering to hub, deploy load balancer, VMSS, build file server
# Description: In this script we will create a new VNet (Spoke01-VNet01), peer it with the Hub,
#              then create a basic load balancer, and a VM scale set configured as file servers.

# Detailed steps:
# 1. Create Spoke VNet
# 2. Enable VNet Peering to the hub using remote gateway
# 3. Get secrets from KeyVault
# 4. Create load balancer
# 5. Create VMSS

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
$VNetName = "Spoke01-VNet01"
$HubName =  "Hub01-VNet01"
$IPSecondOctet = "10" # 10 is for East US
$IPThirdOctet = $CompanyID
$AddressSpace  = "10.$IPSecondOctet.$IPThirdOctet.128/26"
$TenantSpace   = "10.$IPSecondOctet.$IPThirdOctet.128/28"
$SpokeLBIP     = "10.$IPSecondOctet.$IPThirdOctet.142" # Using the last usable IP of the tenant subnet
$VMUserName = "User01"
$VMSize = "Standard_A4_v2"
$VMSSName = "Spoke01VM"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 5, estimated total time 15 minutes" -ForegroundColor Cyan

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

# 1. Create Spoke VNet
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
       Set-AzVirtualNetwork -VirtualNetwork $vnet | Out-Null
       $vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
}

# 2. Enable VNet Peering to the hub using remote gateway
Try {$hubvnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $HubName -ErrorAction Stop}
Catch {Write-Warning "Hub VNet not found, please execute Step 1 from this workshop before running this script."
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
Catch {Try {Add-AzVirtualNetworkPeering -Name Spoke01toHub01 -VirtualNetwork $vnet -RemoteVirtualNetworkId $hubvnet.Id -UseRemoteGateways -ErrorAction Stop | Out-Null}
	   Catch {Write-Warning "Error creating VNet Peering"; Return}}

# 3. Get secrets from KeyVault
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Obtaining secrets from Key Vault" -ForegroundColor Cyan
$kvName = $RGName + '-kv'
$kvs = Get-AzKeyVaultSecret -VaultName $kvName -Name $VMUserName -ErrorAction Stop

# 4. Create load balancer
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Internal Load Balancer" -ForegroundColor Cyan
Try {$Spoke01LB = Get-AzLoadBalancer -Name "Spoke01-lb" -ResourceGroupName $RGName -ErrorAction Stop
	 Write-Host "  resource exists, skipping"}
Catch {$FrontEndIPConfig = New-AzLoadBalancerFrontendIpConfig -Name LB-Frontend -PrivateIpAddress $SpokeLBIP -SubnetId $vnet.subnets[0].Id
       $BackEndPool= New-AzLoadBalancerBackendAddressPoolConfig -Name "LB-backend"
	   $HealthProbe = New-AzLoadBalancerProbeConfig -Name "HealthProbe" -Protocol Tcp -Port 445 -IntervalInSeconds 15 -ProbeCount 2
	   #$InboundNATPool= New-AzLoadBalancerInboundNatPoolConfig -Name "RDP" -FrontendIpConfiguration $FrontEndIPConfig -Protocol TCP `
	   #															-FrontendPortRangeStart 3400 -FrontendPortRangeEnd 3410 -BackendPort 3389
	   $LBRule = @()
	   $LBRule += New-AzLoadBalancerRuleConfig -Name "SMB445" -FrontendIpConfiguration $FrontEndIPConfig -BackendAddressPool $BackEndPool `
												-Probe $HealthProbe -Protocol Tcp -FrontendPort 445 -BackendPort 445 -IdleTimeoutInMinutes 15
	   $LBRule += New-AzLoadBalancerRuleConfig -Name "SMB137" -FrontendIpConfiguration $FrontEndIPConfig -BackendAddressPool $BackEndPool `
												-Probe $HealthProbe -Protocol Tcp -FrontendPort 137 -BackendPort 137 -IdleTimeoutInMinutes 15
	   $LBRule += New-AzLoadBalancerRuleConfig -Name "SMB139" -FrontendIpConfiguration $FrontEndIPConfig -BackendAddressPool $BackEndPool `
												-Probe $HealthProbe -Protocol Tcp -FrontendPort 139 -BackendPort 139 -IdleTimeoutInMinutes 15
	   $Spoke01LB = New-AzLoadBalancer -ResourceGroupName $RGName -Location $ShortRegion -Name "Spoke01-lb" -FrontendIpConfiguration $FrontEndIPConfig `
	   										-LoadBalancingRule $LBRule -BackendAddressPool $BackEndPool -Probe $HealthProbe
											#-InboundNatPool $InboundNATPool -LoadBalancingRule $LBRule -BackendAddressPool $BackEndPool -Probe $HealthProbe
	   $Spoke01LB = Get-AzLoadBalancer -ResourceGroupName $RGName -Name "Spoke01-lb" -ErrorAction Stop}

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
Catch {$IPCfg = New-AzVmssIPConfig -Name "VMSSIPConfig" -LoadBalancerInboundNatPoolsId $Spoke01LB.InboundNatPools[0].Id `
				-LoadBalancerBackendAddressPoolsId $Spoke01LB.BackendAddressPools[0].Id -SubnetId $vnet.Subnets[0].Id
	   $VMSSConfig = New-AzVmssConfig -Location $ShortRegion -SkuCapacity 2 -SkuName $VMSize -UpgradePolicyMode "Automatic" | `
					 Add-AzVmssNetworkInterfaceConfiguration -Name "NIC1" -Primary $True -IPConfiguration $IPCfg | `
					 Set-AzVmssOSProfile -ComputerNamePrefix $VMSSName -AdminUsername $kvs.Name -AdminPassword $kvs.SecretValueText  | `
					 Set-AzVmssStorageProfile -OsDiskCreateOption 'FromImage' -OsDiskCaching "None" -ImageReferenceOffer WindowsServer `
				     -ImageReferenceSku 2016-Datacenter -ImageReferenceVersion latest -ImageReferencePublisher MicrosoftWindowsServer -ManagedDisk Standard_LRS | `
					 Add-AzVmssExtension -Name $ExtensionName -Publisher 'Microsoft.Compute' -Type 'CustomScriptExtension' -TypeHandlerVersion '1.9' `
					 -Setting $PublicConfiguration -AutoUpgradeMinorVersion $True
	   New-AzVmss -ResourceGroupName $RGName -Name $VMSSName -VirtualMachineScaleSet $VMSSConfig | Out-Null}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 5 completed successfully" -ForegroundColor Green
Write-Host
