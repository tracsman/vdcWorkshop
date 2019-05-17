#
# Azure Virtual WAN Workshop
#
# Use your corporate credentials to login (your @microsoft.com account) to Azure
#
#
# Step 1 Create a vWAN, a vWAN Hub, and vWAN VPN Gateway
# Step 2 Create a NetFoundry Virtual Appliance
# Step 3 Create a Cisco CSR Virtual Appliance
# Step 4 Connect the two Azure VNets to the vWAN Hub
# Step 5 Configure and Connect Site 1 (NetFoundry) using the partner experience
# Step 6 Configure and Connect Site 2 (Cisco) using manual VPN provisioning
# (Not included) Step 7 Configure and Connect Client01, a Point-to-Site manual VPN connection
# (Not included) Step 8 Configure and Connect ExpressRoute to vWAN Hub
# 

# Step 2 - Create a NetFoundry Virtual Appliance
# 2.1 Accept Marketplace Terms
# 2.2 Validate and Initialize
# 2.3 Create the NetFoundry Virtual Appliance
# 2.3.1 Create Public IP
# 2.3.2 Create NSG
# 2.3.3 Create NIC
# 2.3.4 Create Public and Private RSA keys
# 2.3.5 Build VM
# 2.4 Create UDR Route Table

# 2.1 Accept Marketplace Terms
##  To run the script you need to accept the terms. Run one time in the target Azure subscription:
##  Get-AzMarketplaceTerms -Publisher "tata_communications" -Product "netfoundry_cloud_gateway" -Name "netfoundry-cloud-gateway" | Set-AzMarketplaceTerms -Accept

# 2.2 Validate and Initialize
# Az Module Test
$ModCheck = Get-Module Az.Network -ListAvailable
If ($Null -eq $ModCheck) {
    Write-Warning "The Az PowerShell module was not found. This script uses the Az modules for PowerShell"
    Write-Warning "See the blob post for more information at: https://azure.microsoft.com/blog/how-to-migrate-from-azurerm-to-az-in-azure-powershell/"
    Return
    }

# Load Initialization Variables
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
If (Test-Path -Path $ScriptDir\init.txt) {
        Get-Content $ScriptDir\init.txt | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}}}
Else {Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}

# Non-configurable Variable Initialization (ie don't modify these)
$ShortRegion = "westus2"
$RGName = "Company" + $CompanyID + "-Site01"
$KVName = "Company" + $CompanyID + "-kv"
$NameStub = "C" + $CompanyID + "-Site01"
$VMSize = "Standard_B2ms"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 2, estimated total time 5 minutes" -ForegroundColor Cyan

# Login and permissions check
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Checking login and permissions" -ForegroundColor Cyan
Try {Get-AzResourceGroup -Name $RGName -ErrorAction Stop | Out-Null}
Catch {# Login and set subscription for ARM
       Write-Host "Logging in to ARM"
       Try {$Sub = (Set-AzContext -Subscription $SubID -ErrorAction Stop).Subscription}
       Catch {Connect-AzAccount | Out-Null
              $Sub = (Set-AzContext -Subscription $SubID -ErrorAction Stop).Subscription}
       Write-Host "Current Sub:",$Sub.Name,"(",$Sub.Id,")"
       Try {Get-AzResourceGroup -Name $RGName -ErrorAction Stop | Out-Null}
       Catch {Write-Warning "Permission check failed, ensure company id is set correctly!"
              Return}
}

# 2.3 Create the NetFoundry Virtual Appliance
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating NetFoundry Virtual Appliance" -ForegroundColor Cyan
# 2.3.1 Create Public IP
Try {$pip = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $NameStub'-Router01-pip' -ErrorAction Stop
     Write-Host "  Public IP exists, skipping"}
Catch {$pip = New-AzPublicIpAddress -ResourceGroupName $RGName -Name $NameStub'-Router01-pip' -Location $ShortRegion -AllocationMethod Dynamic}

# 2.3.2 Create NSG
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name myNSGRuleSSH -Protocol Tcp -Direction Inbound -Priority 1000 `
              -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
Try {$nsg = Get-AzNetworkSecurityGroup -Name $NameStub'-Router01-nic-nsg' -ResourceGroupName $RGName -ErrorAction Stop
Write-Host "  NSG exists, skipping"}
Catch {$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $RGName -Location $ShortRegion -Name $NameStub'-Router01-nic-nsg' -SecurityRules $nsgRuleSSH}
                                         
# 2.3.3 Create NIC
$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $NameStub'-VNet01'
$sn =  Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "Tenant"
Try {$nic = Get-AzNetworkInterface  -ResourceGroupName $RGName -Name $NameStub'-Router01-nic' -ErrorAction Stop
     Write-Host "  NIC exists, skipping"}
Catch {$nic = New-AzNetworkInterface  -ResourceGroupName $RGName -Name $NameStub'-Router01-nic' -Location $ShortRegion -Subnet $sn -PublicIpAddress $pip -NetworkSecurityGroup $nsg -EnableIPForwarding}

# 2.3.4 Create Public and Private RSA keys
$FileName = "id_rsa"
If (-not (Test-Path -Path "$HOME\.ssh\")) {New-Item "$HOME\.ssh\" -ItemType Directory | Out-Null}
If (-not (Test-Path -Path "$HOME\.ssh\$FileName")) {ssh-keygen.exe -t rsa -b 2048 -f "$HOME\.ssh\$FileName" -P """" | Out-Null}
Else {Write-Host "  Key Files exists, skipping"}
$PublicKey =  Get-Content "$HOME\.ssh\$FileName.pub"

# 2.3.5 Build VM
# Get-AzVMImage -Location westus2 -Offer netfoundry_cloud_gateway -PublisherName tata_communications -Skus netfoundry-cloud-gateway -Version 2.13.0
$kvs = Get-AzKeyVaultSecret -VaultName $KVName -Name "User01" -ErrorAction Stop
$cred = New-Object System.Management.Automation.PSCredential ($kvs.Name, $kvs.SecretValue)
Try {Get-AzVM -ResourceGroupName $RGName -Name $NameStub'-Router01' -ErrorAction Stop | Out-Null
     Write-Host "  NetFoundry Router exists, skipping"}
Catch {$VMConfig = New-AzVMConfig -VMName $NameStub'-Router01' -VMSize $VMSize
       Set-AzVMPlan -VM $VMConfig -Publisher "tata_communications" -Product "netfoundry_cloud_gateway" -Name "netfoundry-cloud-gateway" | Out-Null
       $VMConfig = Set-AzVMOperatingSystem -VM $VMConfig -Linux -ComputerName $NameStub'-Router01' -Credential $cred
       $VMConfig = Set-AzVMOSDisk -VM $VMConfig -CreateOption FromImage -Name $NameStub'-Router01-disk-os' -Linux -StorageAccountType Premium_LRS -DiskSizeInGB 30
       $VMConfig = Set-AzVMSourceImage -VM $VMConfig -PublisherName "tata_communications" -Offer "netfoundry_cloud_gateway" -Skus "netfoundry-cloud-gateway" -Version "2.13.0"
       $VMConfig = Add-AzVMSshPublicKey -VM $VMConfig -KeyData $PublicKey -Path "/home/User01/.ssh/authorized_keys"
       $VMConfig = Add-AzVMNetworkInterface -VM $VMConfig -NetworkInterface $nic
       $VMConfig = Set-AzVMBootDiagnostics -VM $VMConfig -Disable
       New-AzVM -ResourceGroupName $RGName -Location $ShortRegion -VM $VMConfig | Out-Null
}

# 2.4 Create UDR Route Table
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating VNet Route Table" -ForegroundColor Cyan
Try {$rt = Get-AzRouteTable -ResourceGroupName $RGName -Name $NameStub'-VNet01-rt' -ErrorAction Stop
     Write-Host "  Route Table exists, skipping"}
Catch {$rt = New-AzRouteTable -ResourceGroupName $RGName -Name $NameStub'-VNet01-rt' -location $ShortRegion -DisableBgpRoutePropagation
       $rt = Get-AzRouteTable -ResourceGroupName $RGName -Name $NameStub'-VNet01-rt' }

# Add routes to the route table
Try {Get-AzRouteConfig -RouteTable $rt -Name "ToHub" -ErrorAction Stop | Out-Null
     Write-Host "  Hub Route exists, skipping"}
Catch {Add-AzRouteConfig -RouteTable $rt -Name "ToHub" -AddressPrefix "172.16.$CompanyID.0/24" -NextHopType VirtualAppliance -NextHopIpAddress "10.17.$CompanyID.133" | Out-Null
       Set-AzRouteTable -RouteTable $rt | Out-Null}
Try {Get-AzRouteConfig -RouteTable $rt -Name "ToAz01" -ErrorAction Stop | Out-Null
     Write-Host "  Az01 route exists, skipping"}
Catch {Add-AzRouteConfig -RouteTable $rt -Name "ToAz01" -AddressPrefix "10.17.$CompanyID.0/27"  -NextHopType VirtualAppliance -NextHopIpAddress "10.17.$CompanyID.133" | Out-Null
       Set-AzRouteTable -RouteTable $rt | Out-Null}
Try {Get-AzRouteConfig -RouteTable $rt -Name "ToAz02" -ErrorAction Stop | Out-Null
     Write-Host "  Az02 route exists, skipping"}
Catch {Add-AzRouteConfig -RouteTable $rt -Name "ToAz02" -AddressPrefix "10.17.$CompanyID.32/27" -NextHopType VirtualAppliance -NextHopIpAddress "10.17.$CompanyID.133" | Out-Null
       Set-AzRouteTable -RouteTable $rt | Out-Null}

# Assign Route Table to the subnet
$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $NameStub'-VNet01'
$sn =  Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "Tenant"
if ($null -eq $sn.RouteTable) {
    $sn.RouteTable = $rt
    Set-AzVirtualNetwork -VirtualNetwork $vnet | Out-Null}
Else {Write-Host "  Route Table already assigned to subnet, skipping"}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 2 completed successfully" -ForegroundColor Green
Write-Host "  Navigate to https://pathlab.nfconsole.io/signup to configure your VPN device"
Write-Host "  Your VPN Device Public IP is " -NoNewline
Write-Host (Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $NameStub'-Router01-pip').IpAddress
Write-Host
