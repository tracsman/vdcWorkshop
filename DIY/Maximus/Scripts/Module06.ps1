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

# Module 6 - PaaS - Create DNS, Storage Account, Private Endpoint
# 6.1 Validate and Initialize
# 6.2 Create Storage Account with Files and FW Rules
# 6.3 Create Private Endpoint 
# 6.4 Create and Assign DNS

# 6.1 Validate and Initialize
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
$HubVNetName = "Hub-VNet"
$S1VNetName  = "Spoke01-VNet"
$SASku       = "Standard_LRS"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting Module 6, estimated total time 10 minutes" -ForegroundColor Cyan

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
Write-Host "  Validating required resources" -ForegroundColor Cyan
Try {$vnetHub = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $HubVNetName -ErrorAction Stop}
Catch {Write-Warning "The Hub VNet was not found, please run Module 1 to ensure this critical resource is created."; Return}
Try {$vnetSpoke01 = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $S1VNetName -ErrorAction Stop}
Catch {Write-Warning "The Spoke01 VNet was not found, please run Module 4 to ensure this critical resource is created."; Return}
Try {$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop}
Catch {Write-Warning "The Spoke02 VNet was not found, please run Module 5 to ensure this critical resource is created."; Return}
$kvName = (Get-AzKeyVault -ResourceGroupName $RGName | Select-Object -First 1).VaultName
$kvs = Get-AzKeyVaultSecret -VaultName $kvName -Name "UniversalKey"
If ($null -eq $kvs) {Write-Warning "The Universal Key was not found in the Key Vault secrets, please run Module 1 to ensure this critical resource is created."; Return}
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kvs.SecretValue)
try {$keyUniversal = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)}
finally {[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)}

# 6.2 Create Storage Account with Files and FW Rules
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Storage Account and Web Site" -ForegroundColor Cyan
# Get/Create Storage Account
Write-Host "  creating base storage account"
$SAName = $RGName.ToLower() + "sa" + $keyUniversal
try {$sa = Get-AzStorageAccount -ResourceGroupName $RGName -Name $SAName -ErrorAction Stop
     Write-Host "    base storage account exists, skipping"}
catch {$sa = New-AzStorageAccount -ResourceGroupName $RGName -Location $ShortRegion -Name $SAName -SkuName $SASku -EnableHttpsTrafficOnly $false}
$sactx = $sa.Context

# Add Static Web Pages
Write-Host "  adding storage web endpoint"
try {Get-AzStorageContainer -Context $sactx -Name '$web' -ErrorAction Stop | Out-Null
     Write-Host "    storage web endpoint exists, skipping"}
catch {Enable-AzStorageStaticWebsite -Context $sactx -IndexDocument "index.html" -ErrorDocument404Path "404.html" | Out-Null}

# Create Index and 404 Html Pages
# Get file names in the Web Container
Write-Host "  adding html files to storage"
$saFiles = Get-AzStorageBlob -Container '$web' -Context $sactx

# Check for index.html
if ($null -ne ($saFiles | Where-Object -Property Name -eq "index.html")) {
    Write-Host "    index.html exists, skipping"}
else {"Hello, I'm content from a PaaS storage account via a Private Endpoint." | Out-File "index.html"
      Set-AzStorageBlobContent -Context $sactx -Container '$web' -File "index.html" -Properties @{"ContentType" = "text/html"} | Out-Null}
        
# Check for 404.html
if ($null -ne ($saFiles | Where-Object -Property Name -eq "404.html")) {
    Write-Host "    404.html exists, skipping"}
else {"<!DOCTYPE html><html><body><h1>404</h1></body></html>" | Out-File "404.html"
      Set-AzStorageBlobContent -Context $sactx -Container '$web' -File "404.html" -Properties @{"ContentType" = "text/html"} | Out-Null}

# Clean up local files
if (Test-Path -Path "*.html") {Remove-Item -Path "*.html"}

# 6.3 Create Private Endpoint
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Private Endpoint" -ForegroundColor Cyan
$peConn = New-AzPrivateLinkServiceConnection -Name $VNetName"-pe-conn" -PrivateLinkServiceId $sa.Id -GroupId web
$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
$snTenant = Get-AzVirtualNetworkSubnetConfig -Name "Tenant" -VirtualNetwork $vnet -ErrorAction Stop
if ($snTenant.PrivateEndpointNetworkPolicies -eq "Disabled") {
    Write-Host "  Endpoint Network Polices already disabled, skipping"}
else {$snTenant.PrivateEndpointNetworkPolicies = "Disabled"
      Set-AzVirtualNetwork -VirtualNetwork $vnet}
try {$privateEP = Get-AzPrivateEndpoint -ResourceGroupName $RGName -Name $VNetName"-pe" -ErrorAction Stop
     Write-Host "  Endpoint already exists, skipping"}
catch {$privateEP = New-AzPrivateEndpoint -ResourceGroupName $RGName -Location $ShortRegion -Name $VNetName"-pe" -Subnet $snTenant -PrivateLinkServiceConnection $peConn}

# 6.4 Create and Assign DNS
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Private DNS Zone and Associating" -ForegroundColor Cyan
$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop

# Get/Create DNS Zone
Write-Host "  creating DNS Zone"
try {Get-AzPrivateDnsZone -ResourceGroupName $RGName -Name privatelink.web.core.windows.net -ErrorAction Stop | Out-Null
     Write-Host "    DNS Zone already exists, skipping"}
catch {New-AzPrivateDnsZone -ResourceGroupName $RGName -Name privatelink.web.core.windows.net | Out-Null}

# Get/Link Zone to the Hub VNet
Write-Host "  linking zone to hub vnet"
try {Get-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $RGName -ZoneName privatelink.web.core.windows.net -Name linkHub -ErrorAction Stop | Out-Null
     Write-Host "    DNS link to the Hub already exists, skipping"}
catch {New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $RGName -ZoneName privatelink.web.core.windows.net -Name linkHub -VirtualNetworkId $vnetHub.Id -EnableRegistration | Out-Null}

# Get/Link Zone to Spoke01 VNet
Write-Host "  linking zone to spoke01 vnet"
try {Get-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $RGName -ZoneName privatelink.web.core.windows.net -Name linkSpoke01 -ErrorAction Stop | Out-Null
     Write-Host "    DNS link to Spoke01 already exists, skipping"}
catch {New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $RGName -ZoneName privatelink.web.core.windows.net -Name linkSpoke01 -VirtualNetworkId $vnetSpoke01.Id -EnableRegistration | Out-Null}

# Get/Link Zone to Spoke02 VNet
Write-Host "  linking zone to spoke02 vnet"
try {Get-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $RGName -ZoneName privatelink.web.core.windows.net -Name linkSpoke02 -ErrorAction Stop | Out-Null
     Write-Host "    DNS link to Spoke02 already exists, skipping"}
catch {New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $RGName -ZoneName privatelink.web.core.windows.net -Name linkSpoke02 -VirtualNetworkId $vnet.Id -EnableRegistration | Out-Null}

# Add the A Record for the Endpoint to the DNS Zone
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Create DNS A Record for the Private Endpoint" -ForegroundColor Cyan
$peIP = New-AzPrivateDnsRecordConfig  -IPv4Address $privateEP.CustomDnsConfigs[0].IpAddresses[0]
try {Get-AzPrivateDnsRecordSet -ResourceGroupName $RGName -Name $sa.StorageAccountName -ZoneName privatelink.web.core.windows.net -RecordType A -ErrorAction Stop | Out-Null
    Write-Host "  DNS A Record already exists, skipping"}
catch {New-AzPrivateDnsRecordSet -ResourceGroupName $RGName -Name $sa.StorageAccountName -ZoneName privatelink.web.core.windows.net -RecordType A -Ttl 3600 -PrivateDnsRecord $peIP | Out-Null}

# End Nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Module 6 completed successfully" -ForegroundColor Green
Write-Host
Write-Host "  Try going to your AppGW IP again, notice you now have data from the Storage Account via a Private Endpoint!"
Write-Host
