#
# DIY Workshop Maximus
#
#
# Module 1 - Hub - Create resource group, key vault and secret, Hub VNet, VM, and deploy website
# Module 2 - Access - Create NSG, Public IP, IP Prefix, Bastion, VNet NAT
# Module 3 - Secure - Create Firewall, Firewall Policy, Log Analytics, UDR
# Module 4 - Web Tier - Create Spoke1 VNet, VNet Peering, 3xVM with Web Site, App Gateway
# Module 5 - Data Tier - Create Spoke2 VNet, Load Balancer, VMSS configured as a File Server
# 

# Module 2 - Access - Create NSG, Public IPs, IP Prefix, Bastion, VNet NAT
# 2.1 Validate and Initialize
# 2.2 Create NSG
# 2.3 Create Public IP for Bastion
# 2.4 Create IP Prefix for NAT
# 2.5 Create Bastion
# 2.6 VNet NAT
#

# 2.1 Validate and Initialize
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
$VNetName    = "Hub-VNet"
$BastionName = "Hub-Bastion"
$NATName     = "Hub-NAT"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting Module 2, estimated total time 8 minutes" -ForegroundColor Cyan

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

# 2.2 Create Tenant Subnet NSG
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "  Creating NSG"
Try {$nsg = Get-AzNetworkSecurityGroup -Name $VNetName'-nsg' -ResourceGroupName $RGName -ErrorAction Stop
Write-Host "    NSG exists, skipping"}
Catch {$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $RGName -Location $ShortRegion -Name $VNetName'-nsg'}

# Assign NSG to the Tenant Subnet
Write-Host "    Assigning NSG"
$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
$sn =  Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "Tenant"
if ($null -eq $sn.NetworkSecurityGroup) {
    $sn.NetworkSecurityGroup = $nsg
    Set-AzVirtualNetwork -VirtualNetwork $vnet | Out-Null
} Else {
    Write-Host "    NSG already assigned, skipping"}

# 2.3 Create Public IP for Bastion)
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "  Creating Bastion Public IP"
Try {$pipBastion = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $BastionName'-pip' -ErrorAction Stop
     Write-Host "    Public IP exists, skipping"}
Catch {$pipBastion = New-AzPublicIpAddress -ResourceGroupName $RGName -Name $BastionName'-pip' -Location $ShortRegion -AllocationMethod Static -Sku Standard -Zone 1, 2, 3}

# 2.4 Create IP Prefix for NAT
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "  Creating IP Prefix for VNet NAT"
Try {$ippNAT = Get-AzPublicIpPrefix -ResourceGroupName $RGName -Name $NATName'-ipp' -ErrorAction Stop
     Write-Host "    Public IP exists, skipping"}
Catch {$ippNAT = New-AzPublicIpPrefix -ResourceGroupName $RGName -Name $NATName'-ipp' -Location $ShortRegion -IpAddressVersion "IPv4" -PrefixLength 31 -Sku Standard -Zone 1, 2, 3}

# 2.5 Create Bastion
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "  Creating Bastion"
$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
Try {Get-AzBastion -ResourceGroupName $RGName -Name $BastionName -ErrorAction Stop | Out-Null
     Write-Host "    Bastion exists, skipping"}
Catch {New-AzBastion -ResourceGroupName $RGName -Name $BastionName -PublicIpAddress $pipBastion -VirtualNetwork $vnet -AsJob | Out-Null}

# 2.6 VNet NAT
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "  Creating VNet NAT"
Try {$nat = Get-AzNatGateway -ResourceGroupName $RGName -Name $NATName -ErrorAction Stop
Write-Host "    VNet NAT exists, skipping"}
Catch {$nat = New-AzNatGateway -ResourceGroupName $RGName -Name $NATName -Location $ShortRegion -IdleTimeoutInMinutes 10 -Sku "Standard" -PublicIpPrefix $ippNAT}

# Add NAT to Tenant subnet
Write-Host "    Assigning NAT to Tenant Subnet"
$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
$sn =  Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "Tenant"
if ($null -eq $sn.NatGateway) {
    $sn.NatGateway = $nat
    Set-AzVirtualNetwork -VirtualNetwork $vnet | Out-Null
} Else {
    Write-Host "    NAT already assigned, skipping"}

# Wait for Bastion to finish
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Waiting for Bastion to deploy, this script will continue after 10 minutes or when the deployment is complete, whichever comes first." -ForegroundColor Cyan
Get-Job -Command "New-AzBastion" | wait-job -Timeout 600 | Out-Null

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Module 2 completed successfully" -ForegroundColor Green
Write-Host "  Explore your new IP Prefix, NAT, and Bastion in the Azure Portal."
Write-Host "  Try RDPing to your VM via the Bastion host (use the credentials from Secrets in your Key Vault)."
Write-Host
