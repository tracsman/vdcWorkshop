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
$VNetName = "Spoke01-VNet01"
$HubName =  "Hub01-VNet01"
$IPSecondOctet = "10" # 10 is for East US
$IPThirdOctet = "1" + $CompanyID.PadLeft(2,"0")
$AddressSpace  = "10.$IPSecondOctet.$IPThirdOctet.128/26"
$TenantSpace   = "10.$IPSecondOctet.$IPThirdOctet.128/28"
$SpokeLBIP     = "10.$IPSecondOctet.$IPThirdOctet.142" # Using the last usable IP of the tenant subnet
$VMUserName = "Company" + $CompanyID.PadLeft(2,"0") + "User"
$VMSize = "Standard_A4_v2"
$VMSSName = "Spoke01VM"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 5, estimated total time 15 minutes" -ForegroundColor Cyan

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

# 1. Create Spoke VNet
# Create Virtual Network
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Virtual Network" -ForegroundColor Cyan
Try {$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $rg.ResourceGroupName -Name $VNetName -ErrorAction Stop
     Write-Host "  resource exists, skipping"}
Catch {$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $rg.ResourceGroupName -Name $VNetName -AddressPrefix $AddressSpace -Location $rg.Location
       # Add Subnets
       Write-Host (Get-Date)' - ' -NoNewline
       Write-Host "Adding subnets" -ForegroundColor Cyan
       Add-AzureRmVirtualNetworkSubnetConfig -Name "Tenant" -VirtualNetwork $vnet -AddressPrefix $TenantSpace | Out-Null
       Set-AzureRmVirtualNetwork -VirtualNetwork $vnet | Out-Null
       $vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $rg.ResourceGroupName -Name $VNetName -ErrorAction Stop
}

# 2. Enable VNet Peering to the hub using remote gateway
Try {$hubvnet = Get-AzureRmVirtualNetwork -ResourceGroupName $rg.ResourceGroupName -Name $HubName -ErrorAction Stop}
Catch {Write-Warning "Hub VNet not found, please execute Step 1 from this workshop before running this script."
	   Return}
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Peering Hub to Spoke" -ForegroundColor Cyan
Try {Get-AzureRmVirtualNetworkPeering -Name Hub01toSpoke01 -VirtualNetworkName $hubvnet.Name -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop | Out-Null
     Write-Host "  peering exists, skipping" }
Catch {Try {Add-AzureRmVirtualNetworkPeering -Name Hub01toSpoke01 -VirtualNetwork $hubvnet -RemoteVirtualNetworkId $vnet.Id -AllowGatewayTransit -ErrorAction Stop | Out-Null}
	   Catch {Write-Warning "Error creating VNet Peering"; Return}}

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Peering Spoke to Hub" -ForegroundColor Cyan
Try {Get-AzureRmVirtualNetworkPeering -Name Spoke01toHub01 -VirtualNetworkName $vnet.Name -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop | Out-Null
     Write-Host "  peering exists, skipping" }
Catch {Try {Add-AzureRmVirtualNetworkPeering -Name Spoke01toHub01 -VirtualNetwork $vnet -RemoteVirtualNetworkId $hubvnet.Id -UseRemoteGateways -ErrorAction Stop | Out-Null}
	   Catch {Write-Warning "Error creating VNet Peering"; Return}}

# 3. Get secrets from KeyVault
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Obtaining secrets from Key Vault" -ForegroundColor Cyan
$kvName = $rg.ResourceGroupName + '-kv'
$kvs = Get-AzureKeyVaultSecret -VaultName $kvName -Name $VMUserName -ErrorAction Stop

# 4. Create load balancer
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Internal Load Balancer" -ForegroundColor Cyan
Try {$Spoke01LB = Get-AzureRmLoadBalancer -Name "Spoke01-lb" -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop
	 Write-Host "  resource exists, skipping"}
Catch {$FrontEndIPConfig = New-AzureRmLoadBalancerFrontendIpConfig -Name LB-Frontend -PrivateIpAddress $SpokeLBIP -SubnetId $vnet.subnets[0].Id
       $BackEndPool= New-AzureRmLoadBalancerBackendAddressPoolConfig -Name "LB-backend"
	   $HealthProbe = New-AzureRmLoadBalancerProbeConfig -Name "HealthProbe" -Protocol Tcp -Port 445 -IntervalInSeconds 15 -ProbeCount 2
	   #$InboundNATPool= New-AzureRmLoadBalancerInboundNatPoolConfig -Name "RDP" -FrontendIpConfiguration $FrontEndIPConfig -Protocol TCP `
	   #															-FrontendPortRangeStart 3400 -FrontendPortRangeEnd 3410 -BackendPort 3389
	   $LBRule = @()
	   $LBRule += New-AzureRmLoadBalancerRuleConfig -Name "SMB445" -FrontendIpConfiguration $FrontEndIPConfig -BackendAddressPool $BackEndPool `
												-Probe $HealthProbe -Protocol Tcp -FrontendPort 445 -BackendPort 445 -IdleTimeoutInMinutes 15
	   $LBRule += New-AzureRmLoadBalancerRuleConfig -Name "SMB137" -FrontendIpConfiguration $FrontEndIPConfig -BackendAddressPool $BackEndPool `
												-Probe $HealthProbe -Protocol Tcp -FrontendPort 137 -BackendPort 137 -IdleTimeoutInMinutes 15
	   $LBRule += New-AzureRmLoadBalancerRuleConfig -Name "SMB139" -FrontendIpConfiguration $FrontEndIPConfig -BackendAddressPool $BackEndPool `
												-Probe $HealthProbe -Protocol Tcp -FrontendPort 139 -BackendPort 139 -IdleTimeoutInMinutes 15
	   $Spoke01LB = New-AzureRmLoadBalancer -ResourceGroupName $rg.ResourceGroupName -Location $rg.Location -Name "Spoke01-lb" -FrontendIpConfiguration $FrontEndIPConfig `
	   										-LoadBalancingRule $LBRule -BackendAddressPool $BackEndPool -Probe $HealthProbe
											#-InboundNatPool $InboundNATPool -LoadBalancingRule $LBRule -BackendAddressPool $BackEndPool -Probe $HealthProbe
	   $Spoke01LB = Get-AzureRmLoadBalancer -ResourceGroupName $rg.ResourceGroupName -Name "Spoke01-lb" -ErrorAction Stop}

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

Try {Get-AzureRmVmss -ResourceGroupName $rg.ResourceGroupName -VMScaleSetName $VMSSName -ErrorAction Stop | Out-Null
	 Write-Host "  resource exists, skipping"}
Catch {$IPCfg = New-AzureRmVmssIPConfig -Name "VMSSIPConfig" -LoadBalancerInboundNatPoolsId $Spoke01LB.InboundNatPools[0].Id `
				-LoadBalancerBackendAddressPoolsId $Spoke01LB.BackendAddressPools[0].Id -SubnetId $vnet.Subnets[0].Id
	   $VMSSConfig = New-AzureRmVmssConfig -Location $rg.Location -SkuCapacity 2 -SkuName $VMSize -UpgradePolicyMode "Automatic" | `
					 Add-AzureRmVmssNetworkInterfaceConfiguration -Name "NIC1" -Primary $True -IPConfiguration $IPCfg | `
					 Set-AzureRmVmssOSProfile -ComputerNamePrefix $VMSSName -AdminUsername $kvs.Name -AdminPassword $kvs.SecretValueText  | `
					 Set-AzureRmVmssStorageProfile -OsDiskCreateOption 'FromImage' -OsDiskCaching "None" -ImageReferenceOffer WindowsServer `
				     -ImageReferenceSku 2016-Datacenter -ImageReferenceVersion latest -ImageReferencePublisher MicrosoftWindowsServer -ManagedDisk Standard_LRS | `
					 Add-AzureRmVmssExtension -Name $ExtensionName -Publisher 'Microsoft.Compute' -Type 'CustomScriptExtension' -TypeHandlerVersion '1.9' `
					 -Setting $PublicConfiguration -AutoUpgradeMinorVersion $True
	   New-AzureRmVmss -ResourceGroupName $rg.ResourceGroupName -Name $VMSSName -VirtualMachineScaleSet $VMSSConfig | Out-Null}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 5 completed successfully" -ForegroundColor Green
Write-Host
