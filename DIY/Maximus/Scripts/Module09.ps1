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
# Module 8 - Geo Load Balance - Create Spoke3 VNet, Web App, AFD
# Module 9 - Route Server and Logging
#

# Module 9 - Route Server and Logging
# 9.1 Validate and Initialize
# 9.2 Create RouteServer
# 9.3 Create VNet NVA
# 9.4 Wait for jobs to finish
# 9.5 Deploy config for Hub and On-Prem NVAs
# 9.5.1 Create router configs
# 9.5.2 Save router configs to storage account
# 9.5.3 Call VM Extensions to kick off builds
# 9.6 Create additional monitoring to Log Analytics

# 9.1 Validate and Initialize
# Setup and Start Logging
$LogDir = "$env:HOME/Logs"
If (-Not (Test-Path -Path $LogDir)) {New-Item $LogDir -ItemType Directory | Out-Null}
Start-Transcript -Path "$LogDir/Module09.log"

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
$OPName    = "OnPrem-VNet"
$OPVMName  = "OnPrem-VM01"
$HubName   = "Hub-VNet"
$VMSize    = "Standard_DS2_v2"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting Module 9, estimated total time 25 minutes" -ForegroundColor Cyan

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
    Write-Host "Script Ending, Module 9, Failure Code 1"
    Exit 1
}
Write-Host "  Current User: ",$myContext.Account.Id

# Pulling required components
Try {$hubvnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $HubName -ErrorAction Stop}
Catch {Write-Warning "The Hub VNet was not found, please run Module 1 to ensure this critical resource is created."; Return}
$MPTermsAccepted = (Get-AzMarketplaceTerms -Publisher "cisco" -Product "cisco-csr-1000v" -Name "csr-azure-byol").Accepted
if (-Not $MPTermsAccepted) {Write-Warning "MarketPlace terms for the required image could not be accepted. please run Module 7 to ensure this critical step is completed."; Return}
$kvName  = (Get-AzKeyVault -ResourceGroupName $RGName | Select-Object -First 1).VaultName
if ($null -eq $kvName) {Write-Warning "The Key Vault was not found, please run Module 1 to ensure this critical resource is created."; Return}
try {$PublicKey = Get-Content "$HOME/.ssh/id_rsa.pub"}
catch {Write-Warning "The Public Key RSA file was not found, please run Module 7 to ensure this critical resource is created."; Return}
$kvs = Get-AzKeyVaultSecret -VaultName $kvName -Name "S2SPSK"
If ($null -eq $kvs) {Write-Warning "The S2S PSK was not found in the Key Vault secrets, please run Module 7 to ensure this critical resource is created."; Return}
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kvs.SecretValue)
try {$pskS2S = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)}
finally {[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)}
$kvs = Get-AzKeyVaultSecret -VaultName $kvName -Name "UniversalKey"
If ($null -eq $kvs) {Write-Warning "The Universal Key was not found in the Key Vault secrets, please run Module 1 to ensure this critical resource is created."; Return}
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kvs.SecretValue)
try {$keyUniversal = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)}
finally {[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)}
$SAName = $RGName.ToLower() + "sa" + $keyUniversal
try {$sa = Get-AzStorageAccount -ResourceGroupName $RGName -Name $SAName -ErrorAction Stop}
catch {Write-Warning "The Storage Account was not found, please run Module 6 to ensure this critical resource is created."; Return}
$sactx = $sa.Context

# 9.2 Create RouteServer (AsJob)
# 9.2.1 Create Public IP
Try {$pipRS = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $HubName'-rs-pip' -ErrorAction Stop
     Write-Host "  Public IP exists, skipping"}
Catch {$pipRS = New-AzPublicIpAddress -ResourceGroupName $RGName -Name $HubName'-rs-pip' -Location $ShortRegion -AllocationMethod Static -Sku Standard -IpAddressVersion IPv4}

# 9.2.2 Build Route Server
$subnetRS = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $hubvnet -Name "RouteServerSubnet"
$rsConfig = @{
    RouteServerName =  $HubName + '-rs'
    ResourceGroupName = $RGName 
    Location = $ShortRegion
    HostedSubnet = $subnetRS.Id
    PublicIP = $pipRS
}
try {Get-AzRouteServer -ResourceGroupName $RGName -RouteServerName $HubName'-rs' -ErrorAction Stop | Out-Null
     Write-Host "  Route Server exists, skipping"}
catch {New-AzRouteServer @rsConfig -AsJob | Out-Null}

# 9.3 Create Hub NVA (AsJob)
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Hub Cisco Virtual Appliance" -ForegroundColor Cyan
# 9.3.1 Create Public IP
Try {$pipHubNVA = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $HubName'-Router-pip' -ErrorAction Stop
        Write-Host "  Public IP exists, skipping"}
Catch {$pipHubNVA = New-AzPublicIpAddress -ResourceGroupName $RGName -Name $HubName'-Router-pip' -Location $ShortRegion -AllocationMethod Static -Sku Standard -IpAddressVersion IPv4}
# 9.3.2 Create NIC
$snTenant =  Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $hubvnet -Name "Tenant"
Try {$nic = Get-AzNetworkInterface -ResourceGroupName $RGName -Name $HubName'-Router-nic' -ErrorAction Stop
        Write-Host "  NIC exists, skipping"}
Catch {$nic = New-AzNetworkInterface -ResourceGroupName $RGName -Name $HubName'-Router-nic' -Location $ShortRegion `
                                     -Subnet $snTenant -PublicIpAddress $pipHubNVA -EnableIPForwarding}
# 9.3.3 Build NVA
# Get-AzVMImage -Location westus2 -Offer cisco-csr-1000v -PublisherName cisco -Skus csr-azure-byol -Version latest
Try {Get-AzVM -ResourceGroupName $RGName -Name $HubName'-Router' -ErrorAction Stop | Out-Null
     Write-Host "  Cisco Router exists, skipping"}
Catch {$kvs = Get-AzKeyVaultSecret -VaultName $KVName -Name "User01" -ErrorAction Stop
       $cred = New-Object System.Management.Automation.PSCredential ($kvs.Name, $kvs.SecretValue)
       $latestsku = Get-AzVMImageSku -Location $ShortRegion -Offer cisco-csr-1000v -PublisherName cisco | Sort-Object Skus | Where-Object {$_.skus -match 'byol'} | Select-Object Skus -First 1 | ForEach-Object {$_.Skus}
       $VMConfig = New-AzVMConfig -VMName $HubName'-Router' -VMSize $VMSize
       Set-AzVMPlan -VM $VMConfig -Publisher "cisco" -Product "cisco-csr-1000v" -Name $latestsku | Out-Null
       $VMConfig = Set-AzVMOperatingSystem -VM $VMConfig -Linux -ComputerName $HubName'-Router' -Credential $cred
       $VMConfig = Set-AzVMOSDisk -VM $VMConfig -CreateOption FromImage -Name $HubName'-Router-disk-os' -Linux -StorageAccountType Premium_LRS -DiskSizeInGB 30
       $VMConfig = Set-AzVMSourceImage -VM $VMConfig -PublisherName "cisco" -Offer "cisco-csr-1000v" -Skus $latestsku -Version latest
       $VMConfig = Add-AzVMSshPublicKey -VM $VMConfig -KeyData $PublicKey -Path "/home/User01/.ssh/authorized_keys"
       $VMConfig = Add-AzVMNetworkInterface -VM $VMConfig -NetworkInterface $nic
       $VMConfig = Set-AzVMBootDiagnostic -VM $VMConfig -Disable
       New-AzVM -ResourceGroupName $RGName -Location $ShortRegion -VM $VMConfig -AsJob | Out-Null
}

# 9.4 Wait for jobs to finish
If ((Get-Job -State Running).Count -gt 0) {
     Write-Host "  Waiting for the Route Server and NVA to deploy, this script will continue after they are built."
     Get-Job | Wait-Job | Out-Null}
Write-Host "  Deployments complete"

# Add remote peer
$rs = Get-AzRouteServer -ResourceGroupName $RGName -RouteServerName $HubName'-rs'
$hubnva = Get-AzVM -ResourceGroupName $RGName -Name $HubName'-Router'
$HubNVAPrivateIP = (Get-AzNetworkInterface -ResourceId $hubnva.NetworkProfile.NetworkInterfaces[0].Id).IpConfigurations[0].PrivateIpAddress
try {Get-AzRouteServerPeer -ResourceGroupName $RGName -RouteServerName $HubName'-rs' -PeerName "HubNVA" -ErrorAction Stop | Out-Null
     Write-Host "  Route Server Peer exists, skipping"}
catch {Add-AzRouteServerPeer -ResourceGroupName $RGName -RouteServerName $HubName'-rs' -PeerName "HubNVA" -PeerIp $HubNVAPrivateIP -PeerAsn 65500 -RouteServerName $rs.Name | Out-Null}

# 9.5 Deploy config for Hub and On-Prem NVAs
# 9.5.1 Create router configs
# Build Hub NVA Config Script
$OPPIP  = (Get-AzPublicIpAddress -ResourceGroupName MaxLab -Name $OPName-Router-pip).IpAddress
$OPPriv = (Get-AzNetworkInterface -ResourceGroupName MaxLab -Name $OPName-Router-nic).IpConfigurations.PrivateIpAddress
$OPASN  = "65000"
$HubASN = "65500"
$rs     = Get-AzRouteServer -ResourceGroupName $RGName -RouteServerName $HubName'-rs' -ErrorAction Stop
$RSIP0  = $rs.RouteServerIps[0]
$RSIP1  = $rs.RouteServerIps[1]
$siteRSPrefix = "10.0.5.0"
$siteRSSubnet = "255.255.255.0"
$siteHubDfGate = "10.0.1.1"
$HubOutput = @"
term width 200
conf t
# VPN to On-Prem CSR
# IKE Config
crypto ikev2 proposal az-PROPOSAL
 encryption aes-cbc-256 aes-cbc-128 3des
 integrity sha1
 group 2

crypto ikev2 policy az-POLICY
 proposal az-PROPOSAL

crypto ikev2 keyring key-peer
 peer azvpn1
  address $OPPIP
  pre-shared-key $pskS2S

crypto ikev2 profile az-PROFILE
 match address local interface GigabitEthernet1
 match identity remote address $OPPriv 255.255.255.255
 authentication remote pre-share
 authentication local pre-share
 keyring local key-peer

# IPsec Config
crypto ipsec transform-set az-IPSEC-PROPOSAL-SET esp-aes 256 esp-sha256-hmac
 mode tunnel
crypto ipsec profile az-VTI
 set transform-set az-IPSEC-PROPOSAL-SET
 set ikev2-profile az-PROFILE

# Tunnel Config
interface Tunnel0
  ip address 169.254.0.4 255.255.255.255
  ip tcp adjust-mss 1350
  tunnel source GigabitEthernet1
  tunnel mode ipsec ipv4
  tunnel destination $OPPIP
  tunnel protection ipsec profile az-VTI

# Static Route for the Tunnel
ip route $OPPriv 255.255.255.255 Tunnel0

# BGP To Route Server and On-prem CSR
router bgp $HubASN
 bgp log-neighbor-changes
 neighbor $RSIP0 remote-as 65515
 neighbor $RSIP0 ebgp-multihop 5
 neighbor $RSIP0 update-source Gi1
 neighbor $RSIP1 remote-as 65515
 neighbor $RSIP1 ebgp-multihop 5
 neighbor $RSIP1 update-source Gi1
 neighbor $OPPriv remote-as $OPASN
 neighbor $OPPriv ebgp-multihop 5
 neighbor $OPPriv update-source Gi1

 address-family ipv4
  neighbor $RSIP0 activate
  neighbor $RSIP0 next-hop-self
  neighbor $RSIP0 soft-reconfiguration inbound
  neighbor $RSIP1 activate
  neighbor $RSIP1 next-hop-self
  neighbor $RSIP1 soft-reconfiguration inbound
  neighbor $OPPriv activate
  neighbor $OPPriv next-hop-self
  neighbor $OPPriv soft-reconfiguration inbound

# Static Route to Route Server Instances
ip route $siteRSPrefix $siteRSSubnet $siteHubDfGate
end
wr
"@

# Build On-Prem NVA Config Script
$HubPIP  = (Get-AzPublicIpAddress -ResourceGroupName MaxLab -Name $HubName-Router-pip).IpAddress
$HubPriv = (Get-AzNetworkInterface -ResourceGroupName MaxLab -Name $HubName-Router-nic).IpConfigurations.PrivateIpAddress
$OPOutput = @"
term width 200
conf t
# VPN to Hub CSR
# IKE Config
crypto ikev2 keyring key-peer-RS
 peer vpnRS
  address $HubPIP
  pre-shared-key $pskS2S

crypto ikev2 profile az-PROFILE-RS
 match address local interface GigabitEthernet1
 match identity remote address $HubPriv 255.255.255.255
 authentication remote pre-share
 authentication local pre-share
 keyring local key-peer-RS

# IPsec Config
crypto ipsec profile az-VTI-RS
 set transform-set az-IPSEC-PROPOSAL-SET
 set ikev2-profile az-PROFILE-RS

# Tunnel Config
interface Tunnel2
 ip address 169.254.0.3 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source GigabitEthernet1
 tunnel mode ipsec ipv4
 tunnel destination $HubPIP
 tunnel protection ipsec profile az-VTI-RS

# BGP Config
router bgp $OPASN
 bgp log-neighbor-changes
 neighbor $HubPriv remote-as $HubASN
 neighbor $HubPriv ebgp-multihop 5
 neighbor $HubPriv update-source GigabitEthernet1

 address-family ipv4
  neighbor $HubPriv activate
  neighbor $HubPriv next-hop-self
  neighbor $HubPriv soft-reconfiguration inbound

# Static Route for Tunnel
ip route $HubPriv 255.255.255.255 Tunnel2
end
wr
"@

# 9.5.2 Save router configs to storage account
# Save config file
# Get file names in the Web Container
Write-Host "  adding html files to storage"
$saFiles = Get-AzStorageBlob -Container 'config' -Context $sactx

# Check for HubRouter.txt
if ($null -ne ($saFiles | Where-Object -Property Name -eq "HubRouter.txt")) {
    Write-Host "    HubRouter.txt exists, skipping"}
 else {$HubOutput | Out-File "HubRouter.txt"
       Set-AzStorageBlobContent -Context $sactx -Container 'config' -File "HubRouter.txt" -Properties @{"ContentType" = "text/plain"} | Out-Null}

# Check for OPDelta.txt
if ($null -ne ($saFiles | Where-Object -Property Name -eq "OPDelta.txt")) {
    Write-Host "    OPDelta.txt exists, skipping"}
 else {$OPOutput | Out-File "OPDelta.txt"
       Set-AzStorageBlobContent -Context $sactx -Container 'config' -File "OPDelta.txt" -Properties @{"ContentType" = "text/plain"} | Out-Null}

# Clean up local files
if (Test-Path -Path "HubRouter.txt") {Remove-Item -Path "HubRouter.txt"}
if (Test-Path -Path "OPDelta.txt") {Remove-Item -Path "OPDelta.txt"}

# 9.5.3 Call VM Extensions to kick off builds
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Pushing out NVA build script" -ForegroundColor Cyan

# Configure Hub and OnPrem NVA (via OnPrem VM PS extension)
# Note: the Hub NVA is configured from the OnPrem VM via SSH using
#       the network path through the existing VPN connection to the
#       Azure VPN Gateway to the Hub Router, this path is allowed
#       by the Allow-SSH firewall rule.
Write-Host "  running OnPrem VM build script" -ForegroundColor Cyan
$ScriptStorageAccount = "vdcworkshop"
$ScriptName = "MaxVMBuildMod9VPN.ps1"
$ExtensionName = 'MaxVMBuildMod9VPN'
$timestamp = (Get-Date).Ticks
$ScriptLocation = "https://$ScriptStorageAccount.blob.core.windows.net/scripts/" + $ScriptName
$ScriptExe = "(.\$ScriptName)"
$PublicConfiguration = @{"fileUris" = [Object[]]"$ScriptLocation";"timestamp" = "$timestamp";"commandToExecute" = "powershell.exe -ExecutionPolicy Unrestricted -Command $ScriptExe"}

Try {Get-AzVMExtension -ResourceGroupName $RGName -VMName $OPVMName -Name 'MaxVMBuildOP' -ErrorAction Stop | Out-Null
     Write-Host "    old extension exists, deleting"
     Remove-AzVMExtension -ResourceGroupName $RGName -VMName $OPVMName -Name 'MaxVMBuildOP' -Force | Out-Null}
Catch {}

Try {Get-AzVMExtension -ResourceGroupName $RGName -VMName $OPVMName -Name $ExtensionName -ErrorAction Stop | Out-Null
     Write-Host "    extension exists, skipping"}
Catch {Write-Host "    queuing build job."
       Set-AzVMExtension -ResourceGroupName $RGName -VMName $OPVMName -Location $ShortRegion -Name $ExtensionName `
                         -Publisher 'Microsoft.Compute' -ExtensionType 'CustomScriptExtension' -TypeHandlerVersion '1.9' `
                         -Settings $PublicConfiguration -AsJob -ErrorAction Stop | Out-Null}

# 9.6 Create additional monitoring to Log Analytics


# End Nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Module 9 completed successfully" -ForegroundColor Green
Write-Host "  All environment components are built, time to play!" -ForegroundColor Green
Write-Host
Write-Host "  Try going to your AppGW IP again, notice you now have data from the VMSS File Server!"
Write-Host
Stop-Transcript
