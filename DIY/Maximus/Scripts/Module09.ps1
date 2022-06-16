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
# 9.5 Kick-off config for Azure NVA
# 9.6 Kick-off config for On-Prem NVA
# 9.7 Create additional monitoring to Log Analytics

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
$OPName  = "OnPrem-VNet"
$HubName = "Hub-VNet"
$VMSize  = "Standard_DS2_v2"

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

# 9.2 Create RouteServer (AsJob)
# 9.2.1 Create Public IP
Try {$pipRS = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $HubName'-rs-pip4' -ErrorAction Stop
     Write-Host "  Public IP exists, skipping"}
Catch {$pipRS = New-AzPublicIpAddress -ResourceGroupName $RGName -Name $HubName'-rs-pip4' -Location $ShortRegion -AllocationMethod Static -Sku Standard -IpAddressVersion IPv4}
# 9.2.2 Build Route Server
$subnetRS = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $hubvnet -Name "RouteServerSubnet"
$rsConfig = @{
    RouteServerName =  $HubName + '-rs'
    ResourceGroupName = $RGName 
    Location = $ShortRegion
    HostedSubnet = $subnetRS.Id
    PublicIP = $pipRS
}
try {Get-AzRouteServer -ResourceGroupName $rsConfig.ResourceGroupName -RouteServerName $rsConfig.RouteServerName -ErrorAction Stop
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
       $VMConfig = New-AzVMConfig -VMName $OPName'-Router01' -VMSize $VMSize
       Set-AzVMPlan -VM $VMConfig -Publisher "cisco" -Product "cisco-csr-1000v" -Name $latestsku | Out-Null
       $VMConfig = Set-AzVMOperatingSystem -VM $VMConfig -Linux -ComputerName $HubName'-Router' -Credential $cred
       $VMConfig = Set-AzVMOSDisk -VM $VMConfig -CreateOption FromImage -Name $HubName'-Router-disk-os' -Linux -StorageAccountType Premium_LRS -DiskSizeInGB 30
       $VMConfig = Set-AzVMSourceImage -VM $VMConfig -PublisherName "cisco" -Offer "cisco-csr-1000v" -Skus $latestsku -Version latest
       $VMConfig = Add-AzVMSshPublicKey -VM $VMConfig -KeyData $PublicKey -Path "/home/User01/.ssh/authorized_keys"
       $VMConfig = Add-AzVMNetworkInterface -VM $VMConfig -NetworkInterface $nic
       $VMConfig = Set-AzVMBootDiagnostic -VM $VMConfig -Disable
       New-AzVM -ResourceGroupName $RGName -Location $ShortRegion -VM $VMConfig -AsJob | Out-Null
}

# 9.5 Kick-off config for Azure NVA
# 9.6 Kick-off config for On-Prem NVA
# 9.7 Create additional monitoring to Log Analytics


# End Nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Module 9 completed successfully" -ForegroundColor Green
Write-Host "  All environment components are built, time to play!" -ForegroundColor Green
Write-Host
Write-Host "  Try going to your AppGW IP again, notice you now have data from the VMSS File Server!"
Write-Host
