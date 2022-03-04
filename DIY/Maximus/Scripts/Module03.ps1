﻿#
# DIY Workshop Maximus
#
#
# Module 1 - Hub - Create resource group, key vault and secret, Hub VNet, VM, and deploy website
# Module 2 - Access - Create NSG, Public IPs, IP Prefix, Bastion, VNet NAT
# Module 3 - Secure - Create Firewall, Firewall Policy, Log Analytics, UDR
# Module 4 - Web Tier - Create Spoke1 VNet, VNet Peering, 3xVM with Web Site, App Gateway
# Module 5 - Data Tier - Create Spoke2 VNet, Load Balancer, VMSS configured as a File Server
# 

# Module 3 - Secure - Create Firewall, Firewall Policy, UDR, Log Analytics
# 3.1 Validate and Initialize
# 3.2 Create Firewall
# 3.2.1 Create Public IP
# 3.2.2 Create Firewall Policy
# 3.2.2.1 Create Firewall Policy Collections and Rules
# 3.2.3 Create Firewall
# 3.2.4 Create and assign UDR
# 3.3 Add Log Analystics Workspace
# 3.3.1 Create Log Analytics Workspace
# 3.3.2 Create Diagnotic Rules on Firewall


# 3.1 Validate and Initialize
# Load Initialization Variables
$ScriptDir = "$env:HOME/Scripts"
If (Test-Path -Path $ScriptDir/init.txt) {
        Get-Content $ScriptDir/init.txt | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}}}
Else {Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}

# Variable Initialization
# $SubID       = defined in and pulled from the init.txt file above
# $ShortRegion = defined in and pulled from the init.txt file above
# $RGName      = defined in and pulled from the init.txt file above
$VNetName      = "Hub-VNet"
$FWName        = "Hub-FW"
$VMName        = "Hub-VM01"
$TenantSubnets = ("10.0.1.2/24"), ("10.1.1.0/24"), ("10.2.1.0/24"), ("10.3.1.0/24")
$RDPRules      = ("10.0.1.2/24"), ("10.1.1.0/24"), ("10.2.1.0/24"), ("10.3.1.0/24"), ("10.10.1.0/24"), ("10.10.2.0/24")

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 3, estimated total time 15 minutes" -ForegroundColor Cyan

# Set Subscription and Login
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Setting Subscription Context" -ForegroundColor Cyan
Try {$myContext = Set-AzContext -Subscription $SubID -ErrorAction Stop}
Catch {Write-Warning "Permission check failed, ensure Sub ID is set correctly!"
        Return}
Write-Host "  Current Sub:",$myContext.Subscription.Name,"(",$myContext.Subscription.Id,")"

# 3.2 Create Firewall
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating the firewall" -ForegroundColor Cyan

# 3.2.1 Create Public IP
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "  Creating Firewall Public IP"
Try {$pipFW = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $FWName'-pip' -ErrorAction Stop
     Write-Host "    Public IP exists, skipping"}
Catch {$pipFW = New-AzPublicIpAddress -ResourceGroupName $RGName -Name $FWName'-pip' -Location $ShortRegion -AllocationMethod Static -Sku Standard}

# 3.2.2 Create Firewall Policy
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "  Creating Firewall Policy"
Try {$fwPolicy = Get-AzFirewallPolicy -Name $FWName-pol -ResourceGroupName $RGName -ErrorAction Stop
    Write-Host "    Firewall exists, skipping"}
Catch {$fwPolicy = New-AzFirewallPolicy -Name $FWName-pol -ResourceGroupName $RGName -Location $ShortRegion}

# 3.2.2.1 Create Firewall Policy Collections and Rules
Write-Host "    Creating Firewall Policy Rule Collection"
$HubVMIP = (Get-AzNetworkInterface -ResourceGroupName $RGName -Name $VMName'-nic' -ErrorAction Stop).IpConfigurations[0].PrivateIpAddress

# Create App Rule collection and Rule
$fwAppRCGroup = New-AzFirewallPolicyRuleCollectionGroup -Name HubFWAppRCGroup -Priority 100 -FirewallPolicyObject $fwPolicy
$fwAppRule = New-AzFirewallPolicyApplicationRule -Name "Allow-storage" -SourceIpGroup $TenantSubnets -Protocol "https:443" -TargetFqdn "vdcworkshop.blob.core.windows.net" -Description "Allow Tenant subnet VM access to Script Storage blob"
$fwAppColl = New-AzFirewallPolicyFilterRuleCollection -Name "HubFWApp-coll" -Priority 100 -Rule $fwAppRule -ActionType "Allow"
Set-AzFirewallPolicyRuleCollectionGroup -Name $fwAppRCGroup.Name -Priority 100 -RuleCollection $fwAppColl -FirewallPolicyObject $fwPolicy

# Create Network Rule collection and Rules
$fwNetRCGroup = New-AzFirewallPolicyRuleCollectionGroup -Name HubFWAppRCGroup -Priority 100 -FirewallPolicyObject $fwPolicy
$fwNetRuleRDP = New-AzFirewallPolicyNetworkRule -Name "Allow-RDP" -SourceAddress $RDPRules -DestinationAddress $RDPRules -DestinationPort 3389 -Protocol TCP -Description "Allow RDP inside the private network for all Azure VMs"
$fwNetRuleWeb = New-AzFirewallPolicyNetworkRule -Name "Allow-Web" -SourceAddress * -DestinationAddress $HubVMIP -DestinationPort 80 -Protocol TCP -Description "Allow access to the web site on the hub VM"
$fwNetColl = New-AzFirewallPolicyFilterRuleCollection -Name "HubFWNet-coll" -Priority 100 -Rule $fwNetRuleRDP, $fwNetRuleWeb -ActionType "Allow"
Set-AzFirewallPolicyRuleCollectionGroup -Name $fwNetRCGroup.Name -Priority 100 -RuleCollection $fwNetColl -FirewallPolicyObject $fwPolicy

# Create NAT Rule collection and Rules
$fwNATRCGroup = New-AzFirewallPolicyRuleCollectionGroup -Name HubFWNATRCGroup -Priority 100 -FirewallPolicyObject $fwPolicy
$fwNATRuleWeb = New-AzFirewallPolicyNatRule -Name "NAT-Hub-Web-Site" -SourceAddress * -DestinationAddress $fwIP -DestinationPort 80 -Protocol TCP -Description "Translation for the Hub Web site" -TranslatedAddress $HubVMIP -TranslatedPort 80
$fwNATColl = New-AzFirewallPolicyFilterRuleCollection -Name "HubFWNAT-coll" -Priority 100 -Rule $fwNATRuleWeb -ActionType "Allow"
Set-AzFirewallPolicyRuleCollectionGroup -Name $fwNATRCGroup.Name -Priority 100 -RuleCollection $fwNATColl -FirewallPolicyObject $fwPolicy

Write-Host "***************  Ending!!! ******************"
Return

# 3.2.3 Create Firewall
Write-Host "  Creating Firewall"
Try {$firewall = Get-AzFirewall -ResourceGroupName $RGName -Name $FWName -ErrorAction Stop
     Write-Host "    Firewall exists, skipping"}
Catch {$firewall = New-AzFirewall -Name $FWName -ResourceGroupName $RGName -Location $ShortRegion -VirtualNetworkName $vnet.Name -PublicIpName $pipFW.Name -SkuTier Premium -SkuName AZ -FirewallPolicyId $fwPolicy.Id}

# 3.2.4 Create and assign UDR
# Create UDR Tables
$fwIP = $firewall.IpConfigurations[0].PrivateIPAddress
$gwRouteTable = $null
$fwRouteTable = $null
$RouteTablesUpdated = $false
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Gateway UDR Table" -ForegroundColor Cyan
Try {$gwRouteTable = Get-AzRouteTable -Name $VNetName'-rt-gw' -ResourceGroupName $RGName -ErrorAction Stop
     Write-Host "  Gateway UDR Table exists, skipping"}
Catch {$gwRouteTableName = $VNetName + '-rt-gw'
       $gwRoute = @()
       ForEach ($GatewayUDR in $TenantSubnets) {
                $gwRouteName = 'Gateway-Route' + ($TenantSubnets.IndexOf($GatewayUDR) + 1).ToString("00")
                $gwRoute += New-AzRouteConfig -Name $gwRouteName -AddressPrefix $GatewayUDR -NextHopType VirtualAppliance -NextHopIpAddress $fwIP}
       $gwRouteTable = New-AzRouteTable -Name $gwRouteTableName -ResourceGroupName $RGName -location $ShortRegion -Route $gwRoute}

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Tenant UDR Table" -ForegroundColor Cyan
Try {$fwRouteTable = Get-AzRouteTable -Name $VNetName'-rt-fw' -ResourceGroupName $RGName -ErrorAction Stop
     Write-Host "  Tenant UDR Table exists, skipping"}
Catch {$fwRouteName = 'Default-Route'
       $fwRouteTableName = $VNetName + '-rt-fw'
       $fwRoute = New-AzRouteConfig -Name $fwRouteName -AddressPrefix "0.0.0.0/0" -NextHopType VirtualAppliance -NextHopIpAddress $fwIP
       $fwRouteTable = New-AzRouteTable -Name $fwRouteTableName -ResourceGroupName $RGName -location $ShortRegion -Route $fwRoute -DisableBgpRoutePropagation}
       
# Assign the UDR tables to the subnets
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Associating UDR Table to Hub Gateway subnet" -ForegroundColor Cyan
If ($null -eq $snGateway.RouteTable) {$snGateway.RouteTable = $gwRouteTable
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

# 3.3 Add Log Analystics Workspace
# 3.3.1 Create Log Analytics Workspace
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Log Analytics Workspace for monitoring collection" -ForegroundColor Cyan
$firewall = Get-AzFirewall -ResourceGroupName $RGName -Name $FWName -ErrorAction Stop
Try {$logWorkspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $RGName -Name $RGName'-logs' -ErrorAction Stop | Out-Null
     Write-Host "  Workspace already exists, skipping"}
Catch {$logWorkspace = New-AzOperationalInsightsWorkspace -ResourceGroupName $RGName -Name $RGName'-logs' -Location $ShortRegion -Sku pernode | Out-Null}

# 3.3.2 Create Diagnotic Rules on Firewall
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating diagnostic setting on Firewall" -ForegroundColor Cyan
Try {Get-AzDiagnosticSetting -Name FW-Diagnostics -ResourceId $firewall.Id
     Write-Host "  Diagnostic setting already exists, skipping"}
Catch {Set-AzDiagnosticSetting -Name FW-Diagnostics -ResourceId $firewall.Id -Category AuditEvent -MetricCategory AllMetrics -Enabled $true -WorkspaceId $logWorkspace.Id}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 3 completed successfully" -ForegroundColor Green
Write-Host "  Review your VM and it's components in the Azure Portal"
Write-Host "  RDP to your new Azure VM using the Public IP"
Write-Host "  The VM Public IP is " -NoNewline
Write-Host (Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $VMName'-pip').IpAddress -ForegroundColor Yellow
Write-Host
