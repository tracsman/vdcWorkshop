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
# 9.4 Create On-Prem NVA
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
$kvName  = (Get-AzKeyVault -ResourceGroupName $RGName | Select-Object -First 1).VaultName
if ($null -eq $kvName) {Write-Warning "The Key Vault was not found, please run Module 1 to ensure this critical resource is created."; Return}
Try {$hubvnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $HubName -ErrorAction Stop}
Catch {Write-Warning "The Hub VNet was not found, please run Module 1 to ensure this critical resource is created."; Return}
Try {$firewall = Get-AzFirewall -ResourceGroupName $RGName -Name $FWName -ErrorAction Stop}
Catch {Write-Warning "The Hub Firewall was not found, please run Module 3 to ensure this critical resource is created."; Return}
try {Get-AzPrivateDnsZone -ResourceGroupName $RGName -Name privatelink.web.core.windows.net -ErrorAction Stop | Out-Null}
Catch {Write-Warning "The Private DNS Zone was not found, please run Module 6 to ensure this critical resource is created."; Return}
$kvs = Get-AzKeyVaultSecret -VaultName $kvName -Name "UniversalKey"
If ($null -eq $kvs) {Write-Warning "The Universal Key was not found in the Key Vault secrets, please run Module 1 to ensure this critical resource is created."; Return}
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kvs.SecretValue)
try {$keyUniversal = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)}
finally {[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)}

$fwIP = $firewall.IpConfigurations[0].PrivateIPAddress
$WebAppName=$SpokeName + $keyUniversal + '-app'
$PEPName = $RGName.ToLower() + "sa" + $keyUniversal
$fdName = $SpokeName + $keyUniversal + "-fd"

# 9.2 Create RouteServer
# 9.3 Create VNet NVA
# 9.4 Create On-Prem NVA
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
