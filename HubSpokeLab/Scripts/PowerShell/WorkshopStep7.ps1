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

# Step 7 
# In Hub, deploy load balancer, NVA Firewall, NSGs, and UDR, build firewall
# Description: In this script we will create a Network Virtual Application (NVA) in the the Hub behind a Standard Load Balancer, then create NSGs and UDRs to allow/deny traffic.

# Detailed steps:
# 1. Create Subnet NSGs
# 2. Create NVA VMs
# 3. Do post deploy Firewall build
# 4. Create UDR rules to force traffic to the firewall

# Notes: For this workshop, the NVA is an HA-Port load balanced set of two Linux VMs with IP Forwarding turned on.
#        While this isn't a real firewall, it does represent the network traffic flow pattern for a firewll. In a
#        real-world scenario, you would select the firewall of your choice from the Azure Marketplace, or at a
#        minium, set IPTables rules in the Linux VMs to allow/deny/log traffic as needed for your use case.

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
$Spoke1Name = "Spoke01-VNet01"
$Spoke2Name = "Spoke02-VNet01"
$HubName =  "Hub01-VNet01"
$IPSecondOctet = "10" # 10 is for East US
$IPThirdOctet = $CompanyID
$HubLBIP = "10.$IPSecondOctet.$IPThirdOctet.30"  # Using the last usable IP of the tenant subnet
$VMUserName = "User01"
$VMSize = "Standard_A4_v2"
$VMNamePrefix = "Hub01-FW"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 7, estimated total time 15 minutes" -ForegroundColor Cyan

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

# 1. Create Subnet NSGs

# 2. Create NVA VMs
# 2.1. Create load balancer
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Internal Load Balancer" -ForegroundColor Cyan
Try {$vnet = Get-AzVirtualNetwork -Name $HubName -ResourceGroupName $RGName
     $sn = Get-AzVirtualNetworkSubnetConfig -Name "Firewall" -VirtualNetwork $vnet}
Catch {Write-Warning 'There was an issue getting VNet config. Complete the first step of the workshop, if that has already been done, review the VNet config and subnets or contact the proctor for more help.'
       Return}
Try {$HubLB = Get-AzLoadBalancer -Name $VMNamePrefix"-lb" -ResourceGroupName $RGName -ErrorAction Stop
     Write-Host "  resource exists, skipping"}
Catch {$FrontEndIPConfig = New-AzLoadBalancerFrontendIpConfig -Name LB-Frontend -PrivateIpAddress $HubLBIP -SubnetId $sn.Id
       $BackEndPool = New-AzLoadBalancerBackendAddressPoolConfig -Name "LB-backend"
       $HealthProbe = New-AzLoadBalancerProbeConfig -Name "HealthProbe" -RequestPath ".noindex.html" -Protocol http -Port 80 -IntervalInSeconds 15 -ProbeCount 2
       $LBRule = New-AzLoadBalancerRuleConfig -Name "HAPortsRule" -FrontendIpConfiguration $FrontEndIPConfig -BackendAddressPool $BackEndPool `
	                                           -Probe $HealthProbe -Protocol "All" -FrontendPort 0 -BackendPort 0 -IdleTimeoutInMinutes 15 `
	                                           -LoadDistribution SourceIP -EnableFloatingIP

       $HubLB = New-AzLoadBalancer -ResourceGroupName $RGName -Location $ShortRegion -Name $VMNamePrefix"-lb" -FrontendIpConfiguration $FrontEndIPConfig `
					-LoadBalancingRule $LBRule -BackendAddressPool $BackEndPool -Probe $HealthProbe -Sku Standard
       $HubLB = Get-AzLoadBalancer -ResourceGroupName $RGName -Name $VMNamePrefix"-lb" -ErrorAction Stop}

# 2.2. Create NSG
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating NSG and SSH rule" -ForegroundColor Cyan
Try {$nsg = Get-AzNetworkSecurityGroup -Name $VMNamePrefix"-nic-nsg" -ResourceGroupName $RGName -ErrorAction Stop
     Write-Host "  resource exists, skipping"}
Catch {
       # Create a network security group rule
       $nsgRuleRDP = New-AzNetworkSecurityRuleConfig -Name myNSGRuleSSH -Protocol Tcp -Direction Inbound `
                                                          -Priority 1000 -SourceAddressPrefix * -SourcePortRange * `
                                                          -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
       # Create a network security group
       $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $RGName -Location $ShortRegion -Name $VMNamePrefix"-nic-nsg" -SecurityRules $nsgRuleRDP
}

# 2.3. Get secrets from KeyVault
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Obtaining secrets from Key Vault" -ForegroundColor Cyan
$kvName = $RGName + '-kv'
$kvs = Get-AzKeyVaultSecret -VaultName $kvName -Name $VMUserName -ErrorAction Stop
$cred = New-Object System.Management.Automation.PSCredential ($kvs.Name, $kvs.SecretValue) -ErrorAction Stop

# 2.4 Create VM Availability Set
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating VM Availability Set" -ForegroundColor Cyan
Try {$FWAvailabilitySet = Get-AzAvailabilitySet -ResourceGroupName $RGName -Name $VMNamePrefix"-as" -ErrorAction Stop
     Write-Host "  resource exists, skipping"}
Catch {$FWAvailabilitySet = New-AzAvailabilitySet -ResourceGroupName $RGName -Location $ShortRegion -Name $VMNamePrefix"-as" `
       -Sku aligned -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 2}

For ($i=1; $i -le 2; $i++) {
        $VMName = $VMNamePrefix + $i.ToString("00")
        # 2.5. Create a NIC, associate NSG
        Write-Host (Get-Date)' - ' -NoNewline
        Write-Host "Creating NIC0$i" -ForegroundColor Cyan
        Try {$nic = Get-AzNetworkInterface -Name $VMName'-nic' -ResourceGroupName $RGName -ErrorAction Stop
                Write-Host "  resource exists, skipping"}
        Catch {$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $HubName
        $nic = New-AzNetworkInterface -Name $VMName'-nic' -ResourceGroupName $RGName -Location $ShortRegion `
                                                -SubnetId $sn.Id -NetworkSecurityGroupId $nsg.Id `
                                                -LoadBalancerBackendAddressPoolId $HubLB.BackendAddressPools[0].Id -EnableIPForwarding  -ErrorAction Stop}

        # 2.6. Create a virtual machine configuration
        Write-Host (Get-Date)' - ' -NoNewline
        Write-Host "Creating $VMName" -ForegroundColor Cyan
        $vmConfig = New-AzVMConfig -VMName $VMName -VMSize $VMSize -AvailabilitySetId $FWAvailabilitySet.Id | `
                    Set-AzVMOperatingSystem -Linux -ComputerName $VMName -Credential $cred | `
                    Set-AzVMSourceImage -PublisherName OpenLogic -Offer CentOS -Skus "7.5"  -Version latest | `
                    Add-AzVMNetworkInterface -Id $nic.Id | Set-AzVMBootDiagnostic -Disable
        Try {Get-AzVM -ResourceGroupName $RGName -Name $VMName -ErrorAction Stop | Out-Null
        Write-Host "  resource exists, skipping"}
        Catch {New-AzVM -ResourceGroupName $RGName -Location $ShortRegion -VM $vmConfig -AsJob -ErrorAction Stop | Out-Null}
        }

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Waiting for VM Build Jobs to finish, this script will continue after 5 minutes or when VMs are built, whichever is first." -ForegroundColor Cyan
Get-Job -Command "New-AzVM" | wait-job -Timeout 300 | Out-Null

# 3. Do post deploy Firewall build
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Running post VM deploy build scripts" -ForegroundColor Cyan
$ScriptStorageAccount = "vdcworkshop"
$ScriptName = "FWBuild.sh"
$ExtensionName = 'BuildFW'
$ScriptLocation = "https://$ScriptStorageAccount.blob.core.windows.net/scripts/" + $ScriptName
$ScriptExe = "$ScriptName"
$PublicConfiguration = @{"fileUris" = [Object[]]"$ScriptLocation";"commandToExecute" = "sh $ScriptExe"}
For ($i=2; $i -le 2; $i++) {
	$VMName = $VMNamePrefix + $i.ToString("00")
	Try {Get-AzVMExtension -ResourceGroupName $RGName -VMName $VMName -Name $ExtensionName -ErrorAction Stop | Out-Null}
        Catch {Write-Host "  queuing FW build job for $VMName"
               Set-AzVMExtension -ResourceGroupName $RGName -VMName $VMName -Location $ShortRegion -Name $ExtensionName `
                                      -Publisher 'Microsoft.Azure.Extensions' -ExtensionType 'CustomScript' -TypeHandlerVersion '2.0' -Settings $PublicConfiguration  `
                                      -AsJob -ErrorAction Stop | Out-Null }
}

# 4. Create UDR rules to force traffic to the firewall
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Route Tables" -ForegroundColor Cyan
$Spoke1VNet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name "Spoke01-VNet01" -ErrorAction Stop
$Spoke2VNet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name "Spoke02-VNet01" -ErrorAction Stop

Try {$Spoke1RT = Get-AzRouteTable -Name $Spoke1Name'-rt' -ResourceGroupName $RGName -ErrorAction Stop
     Write-Host "  $Spoke1Name route table exists, skipping"}
Catch {$Spoke1RT = New-AzRouteTable -Name $Spoke1Name'-rt' -ResourceGroupName $RGName -location $ShortRegion
       Get-AzRouteTable -ResourceGroupName $RGName -Name $Spoke1Name'-rt' | `
                Add-AzRouteConfig -Name "Spoke01ToIIS" -AddressPrefix $Spoke2VNet.Subnets[0].AddressPrefix[0] -NextHopType "VirtualAppliance" -NextHopIpAddress $HubLBIP | `
                Set-AzRouteTable | Out-Null }

Try {$Spoke2RT = Get-AzRouteTable -Name $Spoke2Name'-rt' -ResourceGroupName $RGName -ErrorAction Stop
     Write-Host "  $Spoke2Name route table exists, skipping"}
Catch {$Spoke2RT = New-AzRouteTable -Name $Spoke2Name'-rt' -ResourceGroupName $RGName -location $ShortRegion
       Get-AzRouteTable -ResourceGroupName $RGName -Name $Spoke2Name'-rt' | `
                Add-AzRouteConfig -Name "Spoke02ToFS" -AddressPrefix $Spoke1VNet.Subnets[0].AddressPrefix[0] -NextHopType "VirtualAppliance" -NextHopIpAddress $HubLBIP | `
                Set-AzRouteTable | Out-Null}

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Assigning Route Tables to Subnets" -ForegroundColor Cyan
Try {Set-AzVirtualNetworkSubnetConfig -Name $Spoke1VNet.Subnets[0].Name -VirtualNetwork $Spoke1VNet -AddressPrefix $Spoke1VNet.Subnets[0].AddressPrefix `
                                           -RouteTable $Spoke1RT | Set-AzVirtualNetwork | Out-Null
     Set-AzVirtualNetworkSubnetConfig -Name $Spoke2VNet.Subnets[0].Name -VirtualNetwork $Spoke2VNet -AddressPrefix $Spoke2VNet.Subnets[0].AddressPrefix `
                                           -RouteTable $Spoke2RT | Set-AzVirtualNetwork | Out-Null
}
Catch {
       Write-Warning 'Assigning route tables to subnets failed. Please review or contact the proctor for more assistance'
       Return
}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 7 completed successfully" -ForegroundColor Green
Write-Host
