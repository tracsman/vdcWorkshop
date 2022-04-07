﻿#
# DIY Workshop Maximus
#
#
# Module 1 - Hub - Create resource group, key vault and secret, Hub VNet, VM, and deploy website
# Module 2 - Access - Create NSG, Public IPs, IP Prefix, Bastion, VNet NAT
# Module 3 - Secure - Create Firewall, Firewall Policy, Log Analytics, UDR
# Module 4 - Web Tier - Create Spoke1 VNet, VNet Peering, 3xVM with Web Site, App Gateway
# Module 5 - Data Tier - Create Spoke2 VNet, Load Balancer, VMSS configured as a File Server
# Module 6 - PaaS - Create DNS, Storage Account, Private Endpoint
# Module 7 - VPN - Create On-prem and Coffee Shop, VPN Gateway, NVA and VMs 
# Module 8 - Kubernetes - Create Spoke3 VNet, AppGW Ingress, AppGW, K8N Cluster with App
#

# Module 7 - VPN - Create On-prem and Coffee Shop, VPN Gateway, NVA and VMs 
# 7.1 Validate and Initialize
# 7.2 Create VPN Gateway (AsJob)
# 7.3 Create On-prem and Coffee Shop VNets and Bastions
# 7.4 Create Public and Private RSA keys
# 7.5 Create On-prem NVA (AsJob)
#     7.5.1 Create Public IP
#     7.5.2 Create NIC
#     7.5.3 Build VM
# 7.6 Create On-prem VM (AsJob)
#     7.6.1 Create NIC
#     7.6.2 Build VM
# 7.7 Create Coffee Shop Laptop (AsJob)
#     7.7.1 Create NIC
#     7.7.2 Build VM
# 7.8 Create On-Prem UDR Route Table
# 7.9 Create On-Prem Local Gateway
# 7.10 Run post deployment jobs
#      7.10.1 Configure On-Prem VM
#      7.10.2 Configure P2S VPN on Coffee Shop Laptop
#      7.10.3 Configure On-prem NVA S2S VPN
# 7.11 Create S2S Connection
#

# 7.1 Validate and Initialize
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
$OPName     = "OnPrem-VNet"
$OPAddress  = "10.10.1.0/24"
$OPTenant   = "10.10.1.0/25"
$OPBastion  = "10.10.1.128/25"
$OPVMName   = "OnPrem-VM01"
$OPASN      = "65000"

$CSName     = "CoffeeShop-VNet"
$CSAddress  = "10.10.2.0/24"
$CSTenant   = "10.10.2.0/25"
$CSBastion  = "10.10.2.128/25"
$CSVMName   = "CoffeeShop-PC"

$HubName    = "Hub-VNet"
$HubP2SPool = "172.16.0.0/24"
$HubAddress = "10.0.0.0/16"
$S1Address = "10.1.0.0/16"
$S2Address = "10.2.0.0/16"
$S3Address = "10.3.0.0/16"

$VMSize     = "Standard_B2ms"

$UserName01 = "User01"
$UserName02 = "User02"
$UserName03 = "User03"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting Module 6, estimated total time 40 minutes" -ForegroundColor Cyan

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
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Validating required resources" -ForegroundColor Cyan
Try {$vnetHub = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $HubName -ErrorAction Stop}
Catch {Write-Warning "The Hub VNet was not found, please run Module 1 to ensure this critical resource is created."; Return}
$kvName = (Get-AzKeyVault -ResourceGroupName $RGName | Select-Object -First 1).VaultName
If ($null -eq $kvName) {Write-Warning "The Key Vault was not found, please run Module 1 to ensure this critical resource is created."; Return}
$kvs01 = Get-AzKeyVaultSecret -VaultName $kvName -Name $UserName01 -ErrorAction Stop
If ($null -eq $kvs01) {Write-Warning "The User01 Key Vault secret was not found, please run Module 1 to ensure this critical resource is created."; Return}
$kvs02 = Get-AzKeyVaultSecret -VaultName $kvName -Name $UserName02 -ErrorAction Stop
If ($null -eq $kvs02) {Write-Warning "The User02 Key Vault secret was not found, please run Module 1 to ensure this critical resource is created."; Return}
$kvs03 = Get-AzKeyVaultSecret -VaultName $kvName -Name $UserName03 -ErrorAction Stop 
If ($null -eq $kvs03) {Write-Warning "The User03 Key Vault secret was not found, please run Module 1 to ensure this critical resource is created."; Return}
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

# Accept Marketplace Terms for the NVA
##  To install a marketplace image you need to accept the vendor terms. This is done one time for each
##  vendor product type in the target Azure subscription and persists thereafter.
##  Note: Using marketplace images isn't an option for certain subscription. If this is the case, steps
##        related to or requiring the on-prem NVA will be skipped.
$MPTermsAccepted = (Get-AzMarketplaceTerms -Publisher "cisco" -Product "cisco-csr-1000v" -Name "csr-azure-byol").Accepted
if (-Not $MPTermsAccepted) {Get-AzMarketplaceTerms -Publisher "cisco" -Product "cisco-csr-1000v" -Name "csr-azure-byol" | Set-AzMarketplaceTerms -Accept}
$MPTermsAccepted = (Get-AzMarketplaceTerms -Publisher "cisco" -Product "cisco-csr-1000v" -Name "csr-azure-byol").Accepted
if (-Not $MPTermsAccepted) {Write-Host "MarketPlace terms for the required image could not be accepted. All steps relating to the NVA will be skipped" -ForegroundColor Red}

# 7.2 Create VPN Gateway (AsJob)
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Hub VPN Gateway" -ForegroundColor Cyan
Try {$gwHub = Get-AzVirtualNetworkGateway -Name $HubName'-gw' -ResourceGroupName $RGName -ErrorAction Stop
     Write-Host "  resource exists, skipping"}
Catch {
    $subnet = Get-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnetHub
    Try {$pipHub = Get-AzPublicIpAddress -Name $HubName'-gw-pip'  -ResourceGroupName $RGName -ErrorAction Stop}
    Catch {$pipHub = New-AzPublicIpAddress -Name $HubName'-gw-pip' -ResourceGroupName $RGName -Location $ShortRegion -AllocationMethod Dynamic}
    $ipconf = New-AzVirtualNetworkGatewayIpConfig -Name "gwipconf" -SubnetId $subnet.Id -PublicIpAddressId $pipHub.Id
    $gwHub = New-AzVirtualNetworkGateway -Name $HubName'-gw' -ResourceGroupName $RGName -Location $ShortRegion `
                                         -IpConfigurations $ipconf -GatewayType Vpn -VpnType RouteBased -GatewaySku VpnGw1 `
                                         -VpnClientProtocol "IkeV2" -VpnClientAddressPool $HubP2SPool -AsJob
    }

# 7.3 Create On-prem and Coffee Shop VNets and Bastions
# On-Prem VNet
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating On-Prem VNet" -ForegroundColor Cyan
if ($MPTermsAccepted) {
    $nsgRule = New-AzNetworkSecurityRuleConfig -Name AllowAdminAccess -Protocol Tcp -Direction Inbound -Priority 1000 `
                                               -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
                                               -DestinationPortRange 22, 3389 -Access Allow
    Try {$nsg = Get-AzNetworkSecurityGroup -Name $OPName'-nsg' -ResourceGroupName $RGName -ErrorAction Stop
         Write-Host "  NSG exists, skipping"}
    Catch {$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $RGName -Location $ShortRegion -Name $OPName'-nsg' -SecurityRules $nsgRule}
    Try {$vnetOP = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $OPName -ErrorAction Stop
    Write-Host "  VNet exists, skipping"}
    Catch {$vnetOP = New-AzVirtualNetwork -ResourceGroupName $RGName -Name $OPName -AddressPrefix $OPAddress -Location $ShortRegion  
           Write-Host (Get-Date)' - ' -NoNewline
           Write-Host "  Adding subnet" -ForegroundColor Cyan
           Add-AzVirtualNetworkSubnetConfig -Name "Tenant" -VirtualNetwork $vnetOP -AddressPrefix $OPTenant -NetworkSecurityGroupId $nsg.Id | Out-Null
           Add-AzVirtualNetworkSubnetConfig -Name "AzureBastionSubnet" -VirtualNetwork $vnetOP -AddressPrefix $OPBastion | Out-Null
           Set-AzVirtualNetwork -VirtualNetwork $vnetOP | Out-Null}
    # Create On-Prem Bastion
    Write-Host "  Creating On-Prem Bastion Public IP"
    Try {$pipBastion = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $OPName'-bas-pip' -ErrorAction Stop
         Write-Host "    Public IP exists, skipping"}
    Catch {$pipBastion = New-AzPublicIpAddress -ResourceGroupName $RGName -Name $OPName'-bas-pip' -Location $ShortRegion -AllocationMethod Static -Sku Standard -Zone 1, 2, 3}
    Write-Host "  Creating On-Prem Bastion"
    $vnetOP = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $OPName -ErrorAction Stop
    Try {Get-AzBastion -ResourceGroupName $RGName -Name $OPName-bas -ErrorAction Stop | Out-Null
         Write-Host "    Bastion exists, skipping"}
    Catch {New-AzBastion -ResourceGroupName $RGName -Name $OPName-bas -PublicIpAddress $pipBastion -VirtualNetwork $vnetOP -AsJob | Out-Null}
} else {Write-Host "  Marketplace terms not accepted skipping"}

# Coffee Shop VNet
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Coffee Shop VNet" -ForegroundColor Cyan
$nsgRule = New-AzNetworkSecurityRuleConfig -Name AllowAdminAccess -Protocol Tcp -Direction Inbound -Priority 1000 `
                                           -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
                                           -DestinationPortRange 3389 -Access Allow
Try {$nsg = Get-AzNetworkSecurityGroup -Name $CSName'-nsg' -ResourceGroupName $RGName -ErrorAction Stop
 Write-Host "  NSG exists, skipping"}
Catch {$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $RGName -Location $ShortRegion -Name $CSName'-nsg' -SecurityRules $nsgRule}
Try {$vnetCS = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $CSName -ErrorAction Stop
     Write-Host "  resource exists, skipping"}
Catch {$vnetCS = New-AzVirtualNetwork -ResourceGroupName $RGName -Name $CSName -AddressPrefix $CSAddress -Location $ShortRegion
        Write-Host (Get-Date)' - ' -NoNewline
        Write-Host "  Adding subnet" -ForegroundColor Cyan
        Add-AzVirtualNetworkSubnetConfig -Name "Tenant" -VirtualNetwork $vnetCS -AddressPrefix $CSTenant -NetworkSecurityGroupId $nsg.Id | Out-Null
        Add-AzVirtualNetworkSubnetConfig -Name "AzureBastionSubnet" -VirtualNetwork $vnetCS -AddressPrefix $CSBastion | Out-Null
        Set-AzVirtualNetwork -VirtualNetwork $vnetCS | Out-Null
        }
# Create Coffee Shop Bastion
Write-Host "  Creating Coffe Shop Bastion Public IP"
Try {$pipBastion = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $CSName'-bas-pip' -ErrorAction Stop
        Write-Host "    Public IP exists, skipping"}
Catch {$pipBastion = New-AzPublicIpAddress -ResourceGroupName $RGName -Name $CSName'-bas-pip' -Location $ShortRegion -AllocationMethod Static -Sku Standard -Zone 1, 2, 3}
Write-Host "  Creating Coffee Shop Bastion"
$vnetCS = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $CSName -ErrorAction Stop
Try {Get-AzBastion -ResourceGroupName $RGName -Name $CSName-bas -ErrorAction Stop | Out-Null
        Write-Host "    Bastion exists, skipping"}
Catch {New-AzBastion -ResourceGroupName $RGName -Name $CSName-bas -PublicIpAddress $pipBastion -VirtualNetwork $vnetCS -AsJob | Out-Null}
    
# 7.4 Create Public and Private RSA keys
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating RSA keys" -ForegroundColor Cyan
$FileName = "id_rsa"
If (-not (Test-Path -Path "$HOME/.ssh/")) {New-Item "$HOME\.ssh\" -ItemType Directory | Out-Null}
If (-not (Test-Path -Path "$HOME/.ssh/config")) {
     $FileContent = "MACs=""hmac-sha2-512,hmac-sha1,hmac-sha1-96""`nServerAliveInterval=120`nServerAliveCountMax=30"
     Out-File -FilePath "$HOME/.ssh/config" -Encoding ascii -InputObject $FileContent -Force
}
If (-not (Test-Path -Path "$HOME/.ssh/$FileName")) {ssh-keygen.exe -t rsa -b 2048 -f "$HOME/.ssh/$FileName" -P """" | Out-Null}
Else {Write-Host "  Key Files exists, skipping"}
$PublicKey =  Get-Content "$HOME/.ssh/$FileName.pub"

# 7.5 Create On-prem NVA (AsJob)
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating On-Prem Cisco Virtual Appliance" -ForegroundColor Cyan
if ($MPTermsAccepted) {
    # 7.5.1 Create Public IP
    Try {$pipOPGW = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $OPName'-Router01-pip' -ErrorAction Stop
         Write-Host "  Public IP exists, skipping"}
    Catch {$pipOPGW = New-AzPublicIpAddress -ResourceGroupName $RGName -Name $OPName'-Router01-pip' -Location $ShortRegion -AllocationMethod Dynamic}
    # 7.5.2 Create NIC
    $vnetOP = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $OPName -ErrorAction Stop
    $snTenant =  Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnetOP -Name "Tenant"
    Try {$nic = Get-AzNetworkInterface  -ResourceGroupName $RGName -Name $OPName'-Router01-nic' -ErrorAction Stop
         Write-Host "  NIC exists, skipping"}
    Catch {$nic = New-AzNetworkInterface  -ResourceGroupName $RGName -Name $OPName'-Router01-nic' -Location $ShortRegion -Subnet $snTenant -PublicIpAddress $pipOPGW -EnableIPForwarding}
    # 7.5.3 Build VM
    # Get-AzVMImage -Location westus2 -Offer cisco-csr-1000v -PublisherName cisco -Skus csr-azure-byol -Version latest
    Try {Get-AzVM -ResourceGroupName $RGName -Name $OPName'-Router01' -ErrorAction Stop | Out-Null
         Write-Host "  Cisco Router exists, skipping"}
    Catch {$kvs = Get-AzKeyVaultSecret -VaultName $KVName -Name "User01" -ErrorAction Stop
           $cred = New-Object System.Management.Automation.PSCredential ($kvs.Name, $kvs.SecretValue)
           $latestsku = Get-AzVMImageSku -Location $ShortRegion -Offer cisco-csr-1000v -PublisherName cisco | Sort-Object Skus | Where-Object {$_.skus -match 'byol'} | Select-Object Skus -First 1 | ForEach-Object {$_.Skus}
           $VMConfig = New-AzVMConfig -VMName $OPName'-Router01' -VMSize $VMSize
           Set-AzVMPlan -VM $VMConfig -Publisher "cisco" -Product "cisco-csr-1000v" -Name $latestsku | Out-Null
           $VMConfig = Set-AzVMOperatingSystem -VM $VMConfig -Linux -ComputerName $OPName'-Router01' -Credential $cred
           $VMConfig = Set-AzVMOSDisk -VM $VMConfig -CreateOption FromImage -Name $OPName'-Router01-disk-os' -Linux -StorageAccountType Premium_LRS -DiskSizeInGB 30
           $VMConfig = Set-AzVMSourceImage -VM $VMConfig -PublisherName "cisco" -Offer "cisco-csr-1000v" -Skus $latestsku -Version latest
           $VMConfig = Add-AzVMSshPublicKey -VM $VMConfig -KeyData $PublicKey -Path "/home/User01/.ssh/authorized_keys"
           $VMConfig = Add-AzVMNetworkInterface -VM $VMConfig -NetworkInterface $nic
           $VMConfig = Set-AzVMBootDiagnostic -VM $VMConfig -Disable
           New-AzVM -ResourceGroupName $RGName -Location $ShortRegion -VM $VMConfig -AsJob | Out-Null
    }
} else {Write-Host "  Marketplace terms not accepted skipping"}

# 7.6 Create On-prem VM (AsJob)
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating On-Prem VM" -ForegroundColor Cyan
# 7.6.1 Create NIC
Write-Host "  Creating NIC"
$vnetOP = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $OPName
$snTenant = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnetOP -Name "Tenant"
Try {$nic = Get-AzNetworkInterface -ResourceGroupName $RGName -Name $OPVMName'-nic' -ErrorAction Stop
     Write-Host "    NIC exists, skipping"}
Catch {$nic = New-AzNetworkInterface -ResourceGroupName $RGName -Name $OPVMName'-nic' -Location $ShortRegion -Subnet $snTenant}

# 7.6.2 Build On-Prem VM
Write-Host "  Creating On-Prem VM"
Try {Get-AzVM -ResourceGroupName $RGName -Name $OPVMName -ErrorAction Stop | Out-Null
     Write-Host "    VM exists, skipping"}
Catch {$vmConfig = New-AzVMConfig -VMName $OPVMName -VMSize $VMSize -ErrorAction Stop
       $vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $OPVMName -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
       #$vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2019-Datacenter -Version latest
       #$vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName MicrosoftWindowsDesktop -Offer windows-11 -Skus win11-21h2-pro -Version latest
       $vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2022-Datacenter -Version latest
       $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id
       $vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Disable
       Write-Host "    queuing VM build job"
       New-AzVM -ResourceGroupName $RGName -Location $ShortRegion -VM $vmConfig -AsJob | Out-Null}

# 7.7 Create Coffee Shop Laptop (AsJob)
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Coffee Shop Laptop" -ForegroundColor Cyan
# 7.7.1 Create NIC
Write-Host "  Creating NIC"
$vnetCS = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $CSName
$snTenant = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnetCS -Name "Tenant"
Try {$nic = Get-AzNetworkInterface -ResourceGroupName $RGName -Name $CSVMName'-nic' -ErrorAction Stop
     Write-Host "    NIC exists, skipping"}
Catch {$nic = New-AzNetworkInterface -ResourceGroupName $RGName -Name $CSVMName'-nic' -Location $ShortRegion -Subnet $snTenant}

# 7.7.2 Build Coffee Shop Laptop
Write-Host "  Creating Coffee Shop Laptop"
Try {Get-AzVM -ResourceGroupName $RGName -Name $CSVMName -ErrorAction Stop | Out-Null
     Write-Host "    VM exists, skipping"}
Catch {$vmConfig = New-AzVMConfig -VMName $CSVMName -VMSize $VMSize -ErrorAction Stop
       $vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $OPVMName -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
       #$vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2019-Datacenter -Version latest
       $vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName MicrosoftWindowsDesktop -Offer windows-11 -Skus win11-21h2-pro -Version latest
       #$vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2022-Datacenter -Version latest
       $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id
       $vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Disable
       Write-Host "    queuing VM build job"
       New-AzVM -ResourceGroupName $RGName -Location $ShortRegion -VM $vmConfig -AsJob | Out-Null}

# 7.8 Create On-Prem UDR Route Table
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating VNet Route Table" -ForegroundColor Cyan
Try {$rt = Get-AzRouteTable -ResourceGroupName $RGName -Name $OPName'-rt' -ErrorAction Stop
     Write-Host "  Route Table exists, skipping"}
Catch {$rt = New-AzRouteTable -ResourceGroupName $RGName -Name $OPName'-rt' -location $ShortRegion
       $rt = Get-AzRouteTable -ResourceGroupName $RGName -Name $OPName'-rt' }

# Add routes to the route table
$NVAPrivateIP = (Get-AzNetworkInterface  -ResourceGroupName $RGName -Name $OPName'-Router01-nic').IpConfigurations[0].PrivateIpAddress
Try {Get-AzRouteConfig -RouteTable $rt -Name "ToHub" -ErrorAction Stop | Out-Null
     Write-Host "  Hub Route exists, skipping"}
Catch {Add-AzRouteConfig -RouteTable $rt -Name "ToHub" -AddressPrefix $HubAddress -NextHopType VirtualAppliance -NextHopIpAddress $NVAPrivateIP | Out-Null
       Set-AzRouteTable -RouteTable $rt | Out-Null}
Try {Get-AzRouteConfig -RouteTable $rt -Name "ToS1" -ErrorAction Stop | Out-Null
     Write-Host "  Spoke01 route exists, skipping"}
Catch {Add-AzRouteConfig -RouteTable $rt -Name "ToS1" -AddressPrefix $S1Address  -NextHopType VirtualAppliance -NextHopIpAddress $NVAPrivateIP | Out-Null
       Set-AzRouteTable -RouteTable $rt | Out-Null}
Try {Get-AzRouteConfig -RouteTable $rt -Name "ToS2" -ErrorAction Stop | Out-Null
     Write-Host "  Spoke02 route exists, skipping"}
Catch {Add-AzRouteConfig -RouteTable $rt -Name "ToS2" -AddressPrefix $S2Address -NextHopType VirtualAppliance -NextHopIpAddress $NVAPrivateIP | Out-Null
       Set-AzRouteTable -RouteTable $rt | Out-Null}
Try {Get-AzRouteConfig -RouteTable $rt -Name "ToS3" -ErrorAction Stop | Out-Null
     Write-Host "  Spoke03 route exists, skipping"}
Catch {Add-AzRouteConfig -RouteTable $rt -Name "ToS3" -AddressPrefix $S3Address -NextHopType VirtualAppliance -NextHopIpAddress $NVAPrivateIP | Out-Null
       Set-AzRouteTable -RouteTable $rt | Out-Null}

# Assign Route Table to the subnet
$snTenant = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnetOP -Name "Tenant"
if ($null -eq $snTenant.RouteTable) {
    $snTenant.RouteTable = $rt
    Set-AzVirtualNetwork -VirtualNetwork $vnetOP | Out-Null}
Else {Write-Host "  Route Table already assigned to On-Prem subnet, skipping"}

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Waiting for the VMs to deploy, this script will continue after 10 minutes or when the VMs are built, whichever comes first." -ForegroundColor Cyan
Get-Job -Command "New-AzVM" | wait-job -Timeout 600 | Out-Null

# 7.9 Create On-Prem Local Gateway
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating On-Prem Local GW in Azure" -ForegroundColor Cyan
$pipOPGW = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $OPName'-Router01-pip' -ErrorAction Stop
try {$gwOP = Get-AzLocalNetworkGateway -Name $OPName'-lgw' -ResourceGroupName $RGName -ErrorAction Stop
     Write-Host "  resource exists, skipping"}
catch {$gwOP = New-AzLocalNetworkGateway -Name $OPName'-lgw' -ResourceGroupName $RGName -Location $ShortRegion -GatewayIpAddress $pipOPGW.IpAddress -AddressPrefix $OPAddress -Asn $OPASN -BgpPeeringAddress "10.100.1.1"}

# 7.10 Run post deployment jobs
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Running post VM deploy build scripts" -ForegroundColor Cyan

# 7.10.1 Configure On-Prem VM
Write-Host "  running On-Prem VM build script" -ForegroundColor Cyan
$ScriptStorageAccount = "vdcworkshop"
$ScriptName = "MaxVMBuildOP.ps1"
$ExtensionName = 'MaxVMBuildOP'
$timestamp = (Get-Date).Ticks
$ScriptLocation = "https://$ScriptStorageAccount.blob.core.windows.net/scripts/" + $ScriptName
$ScriptExe = "(.\$ScriptName -User2 '$UserName02' -Pass2 '" + $kvs02 + "' -User3 '$UserName03' -Pass3 '" + $kvs03 + "')"
$PublicConfiguration = @{"fileUris" = [Object[]]"$ScriptLocation";"timestamp" = "$timestamp";"commandToExecute" = "powershell.exe -ExecutionPolicy Unrestricted -Command $ScriptExe"}

Try {Get-AzVMExtension -ResourceGroupName $RGName -VMName $OPVMName -Name $ExtensionName -ErrorAction Stop | Out-Null
     Write-Host "    extension exists, skipping"}
Catch {Write-Host "    queuing build job."
       Set-AzVMExtension -ResourceGroupName $RGName -VMName $OPVMName -Location $ShortRegion -Name $ExtensionName `
                         -Publisher 'Microsoft.Compute' -ExtensionType 'CustomScriptExtension' -TypeHandlerVersion '1.9' `
                         -Settings $PublicConfiguration -AsJob -ErrorAction Stop | Out-Null}

# 7.10.2 Configure P2S VPN on Coffee Shop Laptop
Write-Host "  running Coffee Shop Laptop build script" -ForegroundColor Cyan
$ScriptStorageAccount = "vdcworkshop"
$ScriptName = "MaxVMBuildCS.ps1"
$ExtensionName = 'MaxVMBuildCS'
$timestamp = (Get-Date).Ticks
$ScriptLocation = "https://$ScriptStorageAccount.blob.core.windows.net/scripts/" + $ScriptName
$ScriptExe = "(.\$ScriptName -User2 '$UserName02' -Pass2 '" + $kvs02 + "' -User3 '$UserName03' -Pass3 '" + $kvs03 + "')"
$PublicConfiguration = @{"fileUris" = [Object[]]"$ScriptLocation";"timestamp" = "$timestamp";"commandToExecute" = "powershell.exe -ExecutionPolicy Unrestricted -Command $ScriptExe"}

Try {Get-AzVMExtension -ResourceGroupName $RGName -VMName $CSVMName -Name $ExtensionName -ErrorAction Stop | Out-Null
     Write-Host "    extension exists, skipping"}
Catch {Write-Host "    queuing build job."
       Set-AzVMExtension -ResourceGroupName $RGName -VMName $CSVMName -Location $ShortRegion -Name $ExtensionName `
                         -Publisher 'Microsoft.Compute' -ExtensionType 'CustomScriptExtension' -TypeHandlerVersion '1.9' `
                         -Settings $PublicConfiguration -AsJob -ErrorAction Stop | Out-Null}

# 7.10.3 Configure On-prem NVA S2S VPN
$gwHub = Get-AzVirtualNetworkGateway -Name $HubName'-gw' -ResourceGroupName $RGName -ErrorAction Stop
$pipOPGW = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $OPName'-Router01-pip' -ErrorAction Stop

# Create Router Config
$azurePubIP   = $gwHub.BgpSettings.BgpPeeringAddresses.TunnelIpAddresses
$azureBGPIP   = $gwHub.BgpSettings.BgpPeeringAddress
$siteOPBGPIP  = "10.100.1.1"
$siteOPPubIP  = $pipOPGW.IpAddress
$siteOPPrefix = "10.10.1.0"
$siteOPSubnet = "255.255.255.128"
$siteOPDfGate = "10.10.1.1"
$siteOPPSK    = "Apples2Apples"
$MyOutput = @"
conf t
####
# Cisco CSR VPN Config
####
# IKE Config
crypto ikev2 proposal az-PROPOSAL
  encryption aes-cbc-256 aes-cbc-128 3des
  integrity sha1
  group 2
crypto ikev2 policy az-POLICY
  proposal az-PROPOSAL
  match address local $siteOPPubIP
crypto ikev2 keyring key-peer1
  peer azvpn1
   address $azurePubIP
   pre-shared-key $siteOPPSK
crypto ikev2 profile az-PROFILE1
  match address local $siteOPPubIP
  match identity remote address $azurePubIP 255.255.255.255
  authentication remote pre-share
  authentication local pre-share
  keyring local key-peer1
# IPsec Config
crypto ipsec transform-set az-IPSEC-PROPOSAL-SET esp-aes 256 esp-sha256-hmac
  mode tunnel
crypto ipsec profile az-VTI1
  set transform-set az-IPSEC-PROPOSAL-SET
  set ikev2-profile az-PROFILE1
# Tunnel Config
interface Tunnel0
  ip address 169.254.0.1 255.255.255.255
  ip tcp adjust-mss 1350
  tunnel source GigabitEthernet1
  tunnel mode ipsec ipv4
  tunnel source $siteOPPubIP
  tunnel destination $azurePubIP
  tunnel protection ipsec profile az-VTI1
interface Loopback0
  ip address $siteOPBGPIP 255.255.255.255
# BGP Config
router bgp $OPASN
  bgp log-neighbor-changes
  neighbor $azureBGPIP remote-as 65515
  neighbor $azureBGPIP ebgp-multihop 5
  neighbor $azureBGPIP update-source Loopback0
  address-family ipv4
   network $siteOPPrefix mask $siteOPSubnet
   neighbor $azureBGPIP activate
   neighbor $azureBGPIP next-hop-self
   neighbor $azureBGPIP soft-reconfiguration inbound
ip route 0.0.0.0 0.0.0.0 $siteOPDfGate
ip route $azureBGPIP 255.255.255.255 Tunnel 0
#ip route $azureBGPIP 255.255.255.255 Tunnel0
end
wr
"@

# Send Router Config
Write-Host $MyOutput
# ???
# ???
# ???

# 7.11 Create S2S Connection
# 7.11.1 Wait for VMs to complete (not gateway)
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Connecting S2S VPN between On-Prem NVA and Hub VPN Gateway' -ForegroundColor Cyan
Try {Get-AzVirtualNetworkGatewayConnection -Name $HubName-gw-op-conn -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
     Write-Host '  resource exists, skipping'}
Catch {
    $gwHub = Get-AzVirtualNetworkGateway -Name $HubName'-gw' -ResourceGroupName $RGName -ErrorAction Stop
    $i=0
    If ($gwHub.ProvisioningState -eq 'Updating') {
        Write-Host '  waiting for VPN gateway to finish provisioning: ' -NoNewline
        Start-Sleep 10}
    While ($gwHub.ProvisioningState -eq 'Updating') {
        $i++
        If ($i%6) {Write-Host '*' -NoNewline}
        Else {Write-Host "$($i/6)" -NoNewline}
        Start-Sleep 10
        $gwHub = Get-AzVirtualNetworkGateway -Name $HubName-gw -ResourceGroupName $RGName}
    If ($i -gt 0) {
        Write-Host
        Write-Host '  VPN Gateway deployment complete'
        Write-Host '  building connection'}

    # 7.11.2 Create the connection object
    If ($gwHub.ProvisioningState -eq 'Succeeded') {
        New-AzVirtualNetworkGatewayConnection -Name $HubName-gw-op-conn -ResourceGroupName $RGName `
                -Location $ShortRegion -VirtualNetworkGateway1 $gwHub -LocalNetworkGateway2 $gwOP `
                -ConnectionType IPsec -SharedKey $siteOPPSK -EnableBgp $true | Out-Null}
    Else {Write-Warning 'An issue occured with VPN gateway provisioning.'
          Write-Host 'Current Gateway Provisioning State' -NoNewLine
          Write-Host $gwHub.ProvisioningState
          Write-Host "Often the easiest fix is to delete the gateway and re-run this script."}
    }

# End Nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Module 7 completed successfully" -ForegroundColor Green
Write-Host "  All environment components are built, time to play!" -ForegroundColor Green
Write-Host
Write-Host "  Something something something, pretty neat right?"
Write-Host