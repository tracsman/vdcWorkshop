#
# Azure Firewall Workshop
#
# Use your corporate credentials to login (your @microsoft.com account) to Azure
#
#
# Step 1 Create Virtual Network
# Step 2 Create an internet facing VM
# Step 3 Create an ExpressRoute circuit and ER Gateway
# Step 4 Bring up ExpressRoute Private Peering
# Step 5 Create the connection between the ER Gateway and the ER Circuit
# Step 6 Create and configure the Azure Firewall
# Step 7 Create Spoke VNet with IIS Server and a firewall rule to allow traffic
# 

# Step 6 Create and configure the Azure Firewall
#  6.1 Validate and Initialize
#  6.2 Create the Azure Firewall
#  6.3 Configure the Azure Firewall
#  6.4 Create the UDR tables
#  6.5 Assign the UDR tables to the subnets

# 6.1 Validate and Initialize
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
$RGName = "Company" + $CompanyID
$VNetName = "C" + $CompanyID + "-VNet"
$VMName = "C" + $CompanyID + "-VM01"
$GatewayUDRs = ("10.17." + $CompanyID + ".0/27"), ("10.17." + $CompanyID + ".128/26")
$RDPUDRs = ("10.17." + $CompanyID + ".0/27"), ("10.3." + $CompanyID + ".0/25")

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 6, estimated total time 10 minutes" -ForegroundColor Cyan

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

# Initialize VNet variable
$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName
$snTenant = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "Tenant"
$snGateway = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "GatewaySubnet"
$HubVMIP = (Get-AzNetworkInterface -ResourceGroupName $RGName -Name $VMName'-nic' -ErrorAction Stop).IpConfigurations[0].PrivateIpAddress

# 6.2 Create the Azure Firewall
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating the firewall" -ForegroundColor Cyan
# 6.2.1 Create Public IP
Write-Host "  Creating Public IP"
Try {$pip = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $RGName'-Firewall-pip' -ErrorAction Stop
     Write-Host "    Public IP exists, skipping"}
Catch {$pip = New-AzPublicIpAddress -ResourceGroupName $RGName -Name $RGName'-Firewall-pip' -Location $ShortRegion -AllocationMethod Static -Sku Standard}

# 6.2.2 Create Firewall
Write-Host "  Creating Firewall"
Try {$firewall = Get-AzFirewall -ResourceGroupName $RGName -Name $RGName'-Firewall' -ErrorAction Stop
     Write-Host "    Firewall exists, skipping"}
Catch {$firewall = New-AzFirewall -Name $RGName'-Firewall' -ResourceGroupName $RGName -Location $ShortRegion -VirtualNetworkName $vnet.Name -PublicIpName $pip.Name}

# 6.3 Configure the Azure Firewall
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Configuring Firewall" -ForegroundColor Cyan
If ($firewall.NetworkRuleCollections.Name -contains 'FWNetRDPRules') {
     Write-Host "  Firewall already configured, skipping"}
Else {$RuleRDP = New-AzFirewallNetworkRule -Name "RDPAllow" -SourceAddress $RDPUDRs -DestinationAddress $HubVMIP -DestinationPort 3389 -Protocol TCP
      $RuleCollection = New-AzFirewallNetworkRuleCollection -Name "FWNetRDPRules" -Priority 100 -Rule $RuleRDP -ActionType "Allow"
      $firewall.NetworkRuleCollections = $RuleCollection
      Set-AzFirewall -AzureFirewall $firewall | Out-Null
      $firewall = Get-AzFirewall -ResourceGroupName $RGName -Name $RGName'-Firewall'}

# 6.4 Create the UDR tables
$fwIP = $firewall.IpConfigurations[0].PrivateIPAddress
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
       
# 6.5 Assign the UDR tables to the subnets
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Associating UDR Table to Hub Gateway subnet" -ForegroundColor Cyan
If ($null -eq $snGateway.RouteTable) {$snGateway.RouteTable = $erRouteTable
                                      Set-AzVirtualNetwork -VirtualNetwork $vnet | Out-Null
                                      $vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName}
Else {Write-Host "  A Route Table is already assigned to the subnet, skipping"}

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Associating UDR Table to Hub Tenant subnet" -ForegroundColor Cyan
If ($null -eq $snTenant.RouteTable) {$snTenant.RouteTable = $fwRouteTable
                                     Set-AzVirtualNetwork -VirtualNetwork $vnet | Out-Null
                                     $vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName}
Else {Write-Host "  A Route Table is already assigned to the subnet, skipping"}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 6 completed successfully" -ForegroundColor Green
Write-Host "  Checkout the Firewall in the Azure portal."
Write-Host "  Be sure to check out the Application rule collection for web traffic."
Write-Host "  Also, checkout the Route Table and it's association to the subnet"
Write-Host
