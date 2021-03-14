#
# DIY Azure Firewall Workshop
#
#
# Step 1 Create resource group, key vault, and secret
# Step 2 Create Virtual Network
# Step 3 Create an internet facing VM
# Step 4 Create and configure the Azure Firewall
# Step 5 Create Spoke VNet with IIS Server and a firewall rule to allow traffic
# 

# Step 4 Create and configure the Azure Firewall
#  4.1 Validate and Initialize
#  4.2 Create the Azure Firewall
#  4.3 Configure the Azure Firewall
#  4.4 Create the UDR tables
#  4.5 Assign the UDR tables to the subnets

# 4.1 Validate and Initialize
# Load Initialization Variables
$ScriptDir = "$env:HOME/Scripts"
If (Test-Path -Path $ScriptDir\init.txt) {
        Get-Content $ScriptDir\init.txt | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}}}
Else {Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}

# Variable Initialization
# $SubID     = defined in and pulled from the init.txt file above
# $ShortRegion defined in and pulled from the init.txt file above
# $RGName    = defined in and pulled from the init.txt file above
$VNetName    = "VNet01"
$VMName      = "Hub-VM01"
$FWName      = "Hub-FW01"
$GatewayUDRs = ("10.11.12.0/27"), ("10.17.12.128/25")
$RDPRules    = ("10.11.12.0/27"), ("10.3.12.0/25")

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 4, estimated total time 10 minutes" -ForegroundColor Cyan

# Set Subscription
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Setting Subscription Context" -ForegroundColor Cyan
Try {$myContext = Set-AzContext -Subscription $SubID -ErrorAction Stop}
Catch {Write-Warning "Permission check failed, ensure Sub ID is set correctly!"
        Return}
Write-Host "  Current Sub:",$myContext.Subscription.Name,"(",$myContext.Subscription.Id,")"

# Initialize VNet variables
$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName
$snTenant = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "Tenant"
$snGateway = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "GatewaySubnet"
$HubVMIP = (Get-AzNetworkInterface -ResourceGroupName $RGName -Name $VMName'-nic' -ErrorAction Stop).IpConfigurations[0].PrivateIpAddress

# 4.2 Create the Azure Firewall
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating the firewall" -ForegroundColor Cyan

# 4.2.1 Create Public IP
Write-Host "  Creating Public IP"
Try {$pip = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $FWName'-pip' -ErrorAction Stop
     Write-Host "    Public IP exists, skipping"}
Catch {$pip = New-AzPublicIpAddress -ResourceGroupName $RGName -Name $FWName'-pip' -Location $ShortRegion -AllocationMethod Static -Sku Standard}

# 4.2.2 Create Firewall
Write-Host "  Creating Firewall"
Try {$firewall = Get-AzFirewall -ResourceGroupName $RGName -Name $FWName -ErrorAction Stop
     Write-Host "    Firewall exists, skipping"}
Catch {$firewall = New-AzFirewall -Name $FWName -ResourceGroupName $RGName -Location $ShortRegion -VirtualNetworkName $vnet.Name -PublicIpName $pip.Name}

# 4.3 Configure the Azure Firewall
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Configuring Firewall Network Rules" -ForegroundColor Cyan
If ($firewall.NetworkRuleCollections.Name -contains 'FWNetRules') {
     Write-Host "  Firewall already configured, skipping"}
Else {$RuleRDP = New-AzFirewallNetworkRule -Name "RDPAllow" -SourceAddress $RDPRules -DestinationAddress $HubVMIP -DestinationPort 3389 -Protocol TCP
      $RuleCollection = New-AzFirewallNetworkRuleCollection -Name "FWNetRules" -Priority 100 -Rule $RuleRDP -ActionType "Allow"
      $firewall.NetworkRuleCollections = $RuleCollection
      Set-AzFirewall -AzureFirewall $firewall | Out-Null
      $firewall = Get-AzFirewall -ResourceGroupName $RGName -Name $FWName}

# 4.4 Create the UDR tables
$fwIP = $firewall.IpConfigurations[0].PrivateIPAddress
$erRouteTable = $null
$fwRouteTable = $null
$RouteTablesUpdated = $false
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating ER UDR Table" -ForegroundColor Cyan
Try {$erRouteTable = Get-AzRouteTable -Name $VNetName'-rt-er' -ResourceGroupName $RGName -ErrorAction Stop
     Write-Host "  ER UDR Table exists, skipping"}
Catch {$erRouteTableName = $VNetName + '-rt-er'
       $erRoute = @()
       ForEach ($GatewayUDR in $GatewayUDRs) {
                $erRouteName = 'ERGateway-Route' + ($GatewayUDRs.IndexOf($GatewayUDR) + 1).ToString("00")
                $erRoute += New-AzRouteConfig -Name $erRouteName -AddressPrefix $GatewayUDR -NextHopType VirtualAppliance -NextHopIpAddress $fwIP}
       $erRouteTable = New-AzRouteTable -Name $erRouteTableName -ResourceGroupName $RGName -location $ShortRegion -Route $erRoute}

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Tenant UDR Table" -ForegroundColor Cyan
Try {$fwRouteTable = Get-AzRouteTable -Name $VNetName'-rt-fw' -ResourceGroupName $RGName -ErrorAction Stop
     Write-Host "  Tenant UDR Table exists, skipping"}
Catch {$fwRouteName = 'Default-Route'
       $fwRouteTableName = $VNetName + '-rt-fw'
       $fwRoute = New-AzRouteConfig -Name $fwRouteName -AddressPrefix "0.0.0.0/0" -NextHopType VirtualAppliance -NextHopIpAddress $fwIP
       $fwRouteTable = New-AzRouteTable -Name $fwRouteTableName -ResourceGroupName $RGName -location $ShortRegion -Route $fwRoute -DisableBgpRoutePropagation}
       
# 4.5 Assign the UDR tables to the subnets
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Associating UDR Table to Hub Gateway subnet" -ForegroundColor Cyan
If ($null -eq $snGateway.RouteTable) {$snGateway.RouteTable = $erRouteTable
                                      $RouteTablesUpdated = $true}
Else {Write-Host "  A Route Table is already assigned to the subnet, skipping"}

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Associating UDR Table to Hub Tenant subnet" -ForegroundColor Cyan
If ($null -eq $snTenant.RouteTable) {$snTenant.RouteTable = $fwRouteTable
                                     $RouteTablesUpdated = $true}
Else {Write-Host "  A Route Table is already assigned to the subnet, skipping"}

If ($RouteTablesUpdated){
     Set-AzVirtualNetwork -VirtualNetwork $vnet | Out-Null
     $vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName
     Write-Host "  Route table(s) saved to VNet"}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 4 completed successfully" -ForegroundColor Green
Write-Host "  Checkout the Firewall in the Azure portal."
Write-Host "  Be sure to check out the Application rule collection for RDP traffic."
Write-Host "  Also, checkout the Route Table and it's association to the subnet"
Write-Host
