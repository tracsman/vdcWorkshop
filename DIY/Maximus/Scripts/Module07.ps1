#
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
# 7.3 Create On-prem and Coffee Shop VNets
# 7.4 Create Public and Private RSA keys
# 7.5 Create On-prem NVA (AsJob)
#     7.5.1 Create Public IP
#     7.5.2 Create NIC
#     7.5.3 Build VM
# 7.6 Create On-prem VM (AsJob)
#     7.6.1 Create NIC
#     7.6.2 Build VM
# ????7.6.3 Build On-Prem Bastion
# 7.7 Create Coffee Shop Laptop (AsJob)
#     7.7.1 Create NIC
#     7.7.2 Build VM
# ????7.7.3 Build On-Prem Bastion
# 7.8 Create On-Prem Local Gateway
# 7.9 Run post deployment jobs
#      7.9.1 Configure On-Prem VM
#      7.9.2 Configure P2S VPN on Coffee Shop Laptop
#      7.9.3 Configure On-prem NVA S2S VPN
# 7.10 Wait for everything to finish

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
$OPName        = "OnPrem-VNet"
$OPAddress     = "10.10.1.0/24"
$OPVMName      = "OnPrem-VM01"
$OPASN         = "65000"

$CSName        = "CoffeeShop-VNet"
$CSAddress     = "10.10.2.0/24"
$CSVMName      = "CoffeeShop-PC"

$HubVNetName   = "Hub-VNet"
$VMSize        = "Standard_B2ms"

$UserName01    = "User01"
$UserName02    = "User02"
$UserName03    = "User03"

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
Try {$vnetHub = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $HubVNetName -ErrorAction Stop}
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
Try {Get-AzVirtualNetworkGateway -Name $HubVNetName'-gw' -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
     Write-Host "  resource exists, skipping"}
Catch {
    $subnet = Get-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnetHub
    Try {$pip = Get-AzPublicIpAddress -Name $HubVNetName'-gw-pip'  -ResourceGroupName $RGName -ErrorAction Stop}
    Catch {$pip = New-AzPublicIpAddress -Name $HubVNetName'-gw-pip' -ResourceGroupName $RGName -Location $ShortRegion -AllocationMethod Dynamic}
    $ipconf = New-AzVirtualNetworkGatewayIpConfig -Name "gwipconf" -SubnetId $subnet.Id -PublicIpAddressId $pip.Id
    New-AzVirtualNetworkGateway -Name $HubVNetName'-gw' -ResourceGroupName $RGName -Location $ShortRegion -IpConfigurations $ipconf -GatewayType Vpn -VpnType RouteBased -GatewaySku VpnGw1 -AsJob | Out-Null
    }

# 7.3 Create On-prem and Coffee Shop VNets
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
    Try {$vnetOP = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $OPVNetName -ErrorAction Stop
    Write-Host "  VNet exists, skipping"}
    Catch {$vnetOP = New-AzVirtualNetwork -ResourceGroupName $RGName -Name $OPVNetName -AddressPrefix $OPAddress -Location $ShortRegion  
           Write-Host (Get-Date)' - ' -NoNewline
           Write-Host "  Adding subnet" -ForegroundColor Cyan
           Add-AzVirtualNetworkSubnetConfig -Name "Tenant" -VirtualNetwork $vnetOP -AddressPrefix $OPAddress -NetworkSecurityGroupId $nsg.Id | Out-Null
           Set-AzVirtualNetwork -VirtualNetwork $vnetOP | Out-Null}
} else {Write-Host "  Marketplace terms not accepted skipping"}

# Coffee Shop VNet
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Coffee Shop VNet" -ForegroundColor Cyan
$nsgRule = New-AzNetworkSecurityRuleConfig -Name AllowAdminAccess -Protocol Tcp -Direction Inbound -Priority 1000 `
                                           -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
                                           -DestinationPortRange 3389 -Access Allow
Try {$nsg = Get-AzNetworkSecurityGroup -Name $CSName'-nsg' -ResourceGroupName $RGName -ErrorAction Stop
 Write-Host "  NSG exists, skipping"}
Catch {$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $CSName -Location $ShortRegion -Name $CSName'-nsg' -SecurityRules $nsgRule}
Try {$vnetCS = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $CSVNetName -ErrorAction Stop
     Write-Host "  resource exists, skipping"}
Catch {$vnetCS = New-AzVirtualNetwork -ResourceGroupName $RGName -Name $CSVNetName -AddressPrefix $CSAddress -Location $ShortRegion
        Write-Host (Get-Date)' - ' -NoNewline
        Write-Host "  Adding subnet" -ForegroundColor Cyan
        Add-AzVirtualNetworkSubnetConfig -Name "Tenant" -VirtualNetwork $vnetCS -AddressPrefix $CSAddress -NetworkSecurityGroupId $nsg.Id | Out-Null
        Set-AzVirtualNetwork -VirtualNetwork $vnetCS | Out-Null
        }
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
    $vnetOP = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $OPVNetName -ErrorAction Stop
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

# 7.8 Create On-Prem Local Gateway
New-AzLocalNetworkGateway -Name $OPName'-lgw' -ResourceGroupName $RGName -Location $ShortRegion -GatewayIpAddress $pipOPGW.IpAddress -AddressPrefix $OPAddress

# Wait for VMs (not gateway)
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Waiting for the VMs to deploy, this script will continue after 10 minutes or when the VMs are built, whichever comes first." -ForegroundColor Cyan
Get-Job -Command "New-AzVM" | wait-job -Timeout 600 | Out-Null

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

#      7.10.3 Configure On-prem NVA S2S VPN

# Non-configurable Variable Initialization (ie don't modify these)
$site02BGPASN = "65002"
$site02BGPIP = "10.17." + $CompanyID +".252"
$site02Tunnel0IP = "10.17." + $CompanyID +".250"
$site02Tunnel1IP = "10.17." + $CompanyID +".251"
$site02Prefix = "10.17." + $CompanyID +".160"
$site02Subnet = "255.255.255.224" # = CIDR /27
$site02DfGate = "10.17." + $CompanyID +".161"

# Get vWAN VPN Settings
$URI = 'https://company' + $CompanyID + 'vwanconfig.blob.core.windows.net/config/vWANConfig.json'
$vWANConfigs = Invoke-RestMethod $URI
$vWANFound = $false
foreach ($vWanConfig in $vWANConfigs) {
    if ($vWANConfig.vpnSiteConfiguration.Name -eq ("C" + $CompanyID + "-Site02-vpn")) {$myvWanConfig = $vWANConfig;$vWANFound = $true}
}
if (-Not $vWANFound) {Write-Warning "vWAN Config for Site02 was not found, run Step 5";Return}

# 6.7 Provide configuration instructions
$MyOutput = @"
####
# Cisco CSR VPN Script
####
interface Loopback0
ip address $site02BGPIP 255.255.255.255
no shut
crypto ikev2 proposal az-PROPOSAL
encryption aes-cbc-256 aes-cbc-128 3des
integrity sha1
group 2
crypto ikev2 policy az-POLICY
proposal az-PROPOSAL
crypto ikev2 keyring key-peer1
peer azvpn1
 address $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.IpAddresses.Instance0)
 pre-shared-key $($myvWanConfig.vpnSiteConnections.connectionConfiguration.PSK)
crypto ikev2 keyring key-peer2
peer azvpn2
 address $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.IpAddresses.Instance1)
 pre-shared-key $($myvWanConfig.vpnSiteConnections.connectionConfiguration.PSK)
crypto ikev2 profile az-PROFILE1
match address local interface GigabitEthernet1
match identity remote address $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.IpAddresses.Instance0) 255.255.255.255
authentication remote pre-share
authentication local pre-share
keyring local key-peer1
crypto ikev2 profile az-PROFILE2
match address local interface GigabitEthernet1
match identity remote address $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.IpAddresses.Instance1) 255.255.255.255
authentication remote pre-share
authentication local pre-share
keyring local key-peer2
crypto ipsec transform-set az-IPSEC-PROPOSAL-SET esp-aes 256 esp-sha-hmac
mode tunnel
crypto ipsec profile az-VTI1
set transform-set az-IPSEC-PROPOSAL-SET
set ikev2-profile az-PROFILE1
crypto ipsec profile az-VTI2
set transform-set az-IPSEC-PROPOSAL-SET
set ikev2-profile az-PROFILE2
interface Tunnel0
ip address $site02Tunnel0IP 255.255.255.255
ip tcp adjust-mss 1350
tunnel source GigabitEthernet1
tunnel mode ipsec ipv4
tunnel destination $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.IpAddresses.Instance0)
tunnel protection ipsec profile az-VTI1
interface Tunnel1
ip address $site02Tunnel1IP 255.255.255.255
ip tcp adjust-mss 1350
tunnel source GigabitEthernet1
tunnel mode ipsec ipv4
tunnel destination $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.IpAddresses.Instance1)
tunnel protection ipsec profile az-VTI2
router bgp $site02BGPASN
bgp router-id interface Loopback0
bgp log-neighbor-changes
neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance0) remote-as 65515
neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance0) ebgp-multihop 5
neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance0) update-source Loopback0
neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance1) remote-as 65515
neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance1) ebgp-multihop 5
neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance1) update-source Loopback0
address-family ipv4
 network $site02Prefix mask $site02Subnet
 neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance0) activate
 neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance0) next-hop-self
 neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance0) soft-reconfiguration inbound
 neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance1) activate
 neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance1) next-hop-self
 neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance1) soft-reconfiguration inbound
 maximum-paths eibgp 2
ip route 0.0.0.0 0.0.0.0 $site02DfGate
ip route $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance0) 255.255.255.255 Tunnel0
ip route $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance1) 255.255.255.255 Tunnel1
"@



#-- Wait for Gateway






# End Nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Module 5 completed successfully" -ForegroundColor Green
Write-Host "  All environment components are built, time to play!" -ForegroundColor Green
Write-Host
Write-Host "  Try going to your AppGW IP again, notice you now have data from the VMSS File Server!"
Write-Host
