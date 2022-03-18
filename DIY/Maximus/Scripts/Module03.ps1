#
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
# 3.2.3 Create Firewall
# 3.2.4 Create Firewall Policy Collections and Rules
# 3.2.5 Create and assign UDR
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
$TenantSubnets = "10.0.1.0/24", "10.1.1.0/24", "10.2.1.0/24", "10.3.1.0/24"
$RDPRules      = ("10.0.1.0/24"), ("10.1.1.0/24"), ("10.2.1.0/24"), ("10.3.1.0/24"), ("10.10.1.0/24"), ("10.10.2.0/24")

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting Module 3, estimated total time 20 minutes" -ForegroundColor Cyan

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
try {$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop}
catch {Write-Warning "The Hub VNet was not found, please run Module 1 to ensure this critical resource is created."; Return}
$snTenant = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "Tenant"
$snGateway = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "GatewaySubnet"
try {$HubVMIP = (Get-AzNetworkInterface -ResourceGroupName $RGName -Name $VMName'-nic' -ErrorAction Stop).IpConfigurations[0].PrivateIpAddress}
catch {Write-Warning "The Hub VM was not found, please run Module 1 to ensure this critical resource is created."; Return}

# 3.2 Create Firewall
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating the firewall" -ForegroundColor Cyan

# 3.2.1 Create Public IP
Write-Host "  Creating Firewall Public IP"
Try {$pipFW = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $FWName'-pip' -ErrorAction Stop
     Write-Host "    Public IP exists, skipping"}
Catch {$pipFW = New-AzPublicIpAddress -ResourceGroupName $RGName -Name $FWName'-pip' -Location $ShortRegion -AllocationMethod Static -Sku Standard -Zone 1, 2, 3}

# 3.2.2 Create Firewall Policy
Write-Host "  Creating Firewall Policy"
Try {$fwPolicy = Get-AzFirewallPolicy -Name $FWName-pol -ResourceGroupName $RGName -ErrorAction Stop
    Write-Host "    Firewall exists, skipping"}
Catch {$fwPolicy = New-AzFirewallPolicy -Name $FWName-pol -ResourceGroupName $RGName -Location $ShortRegion}

# 3.2.3 Create Firewall
Write-Host "  Creating Firewall"
Try {$firewall = Get-AzFirewall -ResourceGroupName $RGName -Name $FWName -ErrorAction Stop
     Write-Host "    Firewall exists, skipping"}
Catch {$firewall = New-AzFirewall -Name $FWName -ResourceGroupName $RGName -Location $ShortRegion -VirtualNetwork $vnet -PublicIpAddress $pipFW -SkuTier Premium -FirewallPolicyId $fwPolicy.Id}
$fwIP = $firewall.IpConfigurations[0].PrivateIPAddress

# 3.2.4 Create Firewall Policy Collections and Rules
# Create FW IP Group
Write-Host "    Creating IP Group for Tenant Subnets"
try {$ipGrpTenants = Get-AzIpGroup -Name $FWName-ipgroup -ResourceGroupName $RGName -ErrorAction Stop
     Write-Host "      IP Group exists, skipping"}
catch {$ipGrpTenants = New-AzIpGroup -Name $FWName-ipgroup -ResourceGroupName $RGName -Location $ShortRegion -IpAddress $TenantSubnets}

# Create App Rule collection and Rule
$fwPolicy = Get-AzFirewallPolicy -Name $FWName-pol -ResourceGroupName $RGName -ErrorAction Stop
$UpdateFWPolicyObject = $false
Write-Host "    Creating Firewall App Rule Collection"
try {$fwAppRCGroup = Get-AzFirewallPolicyRuleCollectionGroup -Name HubFWAppRCGroup -AzureFirewallPolicy $fwPolicy -ErrorAction Stop
     Write-Host "      Firewall App Rule Collection exists, skipping"}
catch {$fwAppRCGroup = New-AzFirewallPolicyRuleCollectionGroup -Name HubFWAppRCGroup -Priority 100 -FirewallPolicyObject $fwPolicy
       $UpdateFWPolicyObject = $true}
Write-Host "    Creating Firewall App Rule Collection Filter"
if ($fwAppRCGroup.Properties.RuleCollection.Name -contains "HubFWApp-coll") {
     Write-Host "      Firewall App Rule Collection Filter exists, skipping"} 
else {$UpdateFWPolicyObject = $true}
Write-Host "    Creating Firewall App Rule for Storage Access"
$fwAppRuleStorage = New-AzFirewallPolicyApplicationRule -Name "Allow-storage" -SourceIpGroup $ipGrpTenants.Id -Protocol "https:443" `
                         -TargetFqdn "vdcworkshop.blob.core.windows.net" -Description "Allow Tenant subnet VM access to Script Storage blob"
if ($fwAppRCGroup.Properties.RuleCollection.Rules.Name -contains "Allow-storage") {
    Write-Host "      Firewall App Rule for Storage Access exists, skipping"}
else {$UpdateFWPolicyObject = $true}
Write-Host "    Creating Firewall App Rule for Windows Update Access"
$fwAppRuleWU = New-AzFirewallPolicyApplicationRule -Name "Allow-WU" -SourceIpGroup $ipGrpTenants.Id -Protocol "https:443" `
                         -FqdnTag "WindowsUpdate" -WebCategory * -Description "Allow Tenant subnet VM access to Windows Update"
$fwAppRuleWU.WebCategories = $null
if ($fwAppRCGroup.Properties.RuleCollection.Rules.Name -contains "Allow-WU") {
    Write-Host "      Firewall App Rule for Windows Update Access exists, skipping"}
else {$UpdateFWPolicyObject = $true}
if ($UpdateFWPolicyObject) {
     Write-Host "    Adding Firewall App Rule Collection to Firewall Policy Object"
     $fwAppColl = New-AzFirewallPolicyFilterRuleCollection -Name "HubFWApp-coll" -Priority 100 -Rule $fwAppRuleStorage, $fwAppRuleWU -ActionType "Allow"
     Set-AzFirewallPolicyRuleCollectionGroup -Name $fwAppRCGroup.Name -Priority 100 -RuleCollection $fwAppColl -FirewallPolicyObject $fwPolicy}

# Create Network Rule collection and Rules
$fwPolicy = Get-AzFirewallPolicy -Name $FWName-pol -ResourceGroupName $RGName -ErrorAction Stop
$UpdateFWPolicyObject = $false
Write-Host "    Creating Firewall Policy Net Rule Collection"
try {$fwNetRCGroup = Get-AzFirewallPolicyRuleCollectionGroup -Name HubFWNetRCGroup -AzureFirewallPolicy $fwPolicy -ErrorAction Stop
     Write-Host "      Firewall Policy Net Rule Collection exists, skipping"}
catch {$fwNetRCGroup = New-AzFirewallPolicyRuleCollectionGroup -Name HubFWNetRCGroup -Priority 200 -FirewallPolicyObject $fwPolicy
       $UpdateFWPolicyObject = $true}
Write-Host "    Creating Firewall Net Rule Collection Filter"
if ($fwNetRCGroup.Properties.RuleCollection.Name -contains "HubFWNet-coll") {
     Write-Host "      Firewall Net Rule Collection Filter exists, skipping"} 
else {$UpdateFWPolicyObject = $true}
Write-Host "    Creating Firewall RDP Network Rule"
$fwNetRuleRDP = New-AzFirewallPolicyNetworkRule -Name "Allow-RDP" -SourceAddress $RDPRules `
                    -DestinationAddress $RDPRules -DestinationPort 3389 -Protocol TCP `
                    -Description "Allow RDP inside the private network for all Azure VMs"
if ($fwNetRCGroup.Properties.RuleCollection.Rules.Name -contains "Allow-RDP") {
     Write-Host "      Firewall RDP Network Rule exists, skipping"}
 else {$UpdateFWPolicyObject = $true}
Write-Host "    Creating Firewall Web Network Rule"
$fwNetRuleWeb = New-AzFirewallPolicyNetworkRule -Name "Allow-Web" -SourceAddress * `
                    -DestinationAddress $HubVMIP -DestinationPort 80 -Protocol TCP `
                    -Description "Allow access to the web site on the hub VM"
if ($fwNetRCGroup.Properties.RuleCollection.Rules.Name -contains "Allow-Web") {
    Write-Host "      Firewall Web Network Rule exists, skipping"}
else {$UpdateFWPolicyObject = $true}
$fwNetRuleSMB = New-AzFirewallPolicyNetworkRule -Name "Allow-SMB" -SourceAddress $RDPRules `
                    -DestinationAddress $RDPRules -DestinationPort 445, 137, 139 -Protocol Any `
                    -Description "Allow SMB inside the private network for all Azure VMs"
if ($fwNetRCGroup.Properties.RuleCollection.Rules.Name -contains "Allow-SMB") {
     Write-Host "      Firewall SMB Network Rule exists, skipping"}
 else {$UpdateFWPolicyObject = $true}
if ($UpdateFWPolicyObject) {
     Write-Host "    Adding Firewall Net Rule Collection to Firewall Policy object"
     $fwNetColl = New-AzFirewallPolicyFilterRuleCollection -Name "HubFWNet-coll" -Priority 100 -ActionType "Allow" -Rule $fwNetRuleRDP, $fwNetRuleWeb, $fwNetRuleSMB
     Set-AzFirewallPolicyRuleCollectionGroup -Name $fwNetRCGroup.Name -Priority 200 -RuleCollection $fwNetColl -FirewallPolicyObject $fwPolicy}

# Create NAT Rule collection and Rules
$fwPolicy = Get-AzFirewallPolicy -Name $FWName-pol -ResourceGroupName $RGName -ErrorAction Stop
$UpdateFWPolicyObject = $false
Write-Host "    Creating Firewall NAT Rule Collection"
try {$fwNATRCGroup = Get-AzFirewallPolicyRuleCollectionGroup -Name HubFWNATRCGroup -AzureFirewallPolicy $fwPolicy -ErrorAction Stop
     Write-Host "      Firewall NAT Rule Collection exists, skipping"}
catch {$fwNATRCGroup = New-AzFirewallPolicyRuleCollectionGroup -Name HubFWNATRCGroup -Priority 300 -FirewallPolicyObject $fwPolicy
       $UpdateFWPolicyObject = $true}
Write-Host "    Creating Firewall NAT Rule Collection Filter"
if ($fwNATRCGroup.Properties.RuleCollection.Name -contains "HubFWNAT-coll") {
    $fwNATColl = $fwNATRCGroup.Properties.RuleCollection | Where-Object {$_.Name -eq "HubFWNAT-coll"}
    Write-Host "      Firewall NAT Rule Collection Filter exists, skipping"} 
else {$UpdateFWPolicyObject = $true}
Write-Host "    Creating Firewall NAT Rule"
$fwNATRuleWeb = New-AzFirewallPolicyNatRule -Name "NAT-Hub-Web-Site" -SourceAddress * `
                         -DestinationAddress $pipFW.IpAddress -DestinationPort 80 -Protocol TCP `
                         -TranslatedAddress $HubVMIP -TranslatedPort 80 `
                         -Description "Translation for the Hub Web site"
if ($fwNATRCGroup.Properties.RuleCollection.Rules.Name -contains "NAT-Hub-Web-Site") {
     Write-Host "      Firewall NAT Rule exists, skipping"}
else {$UpdateFWPolicyObject = $true}
if ($UpdateFWPolicyObject) {
     Write-Host "    Adding Firewall NAT Rule collection to the Firewall Policy Object"
     $fwNATColl = New-AzFirewallPolicyNATRuleCollection -Name "HubFWNAT-coll" -Priority 100 -ActionType "Dnat" -Rule $fwNATRuleWeb
     Set-AzFirewallPolicyRuleCollectionGroup -Name $fwNATRCGroup.Name -Priority 300 -RuleCollection $fwNATColl -FirewallPolicyObject $fwPolicy}

# 3.2.5 Create and assign UDR
# Create UDR Tables
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
Try {$logWorkspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $RGName -Name $RGName'-logs' -ErrorAction Stop
     Write-Host "  Workspace already exists, skipping"}
Catch {# Ok, this is strange but let me explain... Log Analystics Workspaces are softdeleted, so if you create a "new"
       # Workspace within 14 days of deleting one with the same name, a new one won't be created, you'll just restore
       # the old one with old data and old diagnostic settings. So we need to create, force delete, then create again
       # to ensure we get a new, "clean" workspace with no diagnostic settings.
       New-AzOperationalInsightsWorkspace -ResourceGroupName $RGName -Name $RGName'-logs' -Location $ShortRegion -Sku pernode | Out-Null
       Remove-AzOperationalInsightsWorkspace -ResourceGroupName $RGName -Name $RGName'-logs' -ForceDelete -Force | Out-Null
       $logWorkspace = New-AzOperationalInsightsWorkspace -ResourceGroupName $RGName -Name $RGName'-logs' -Location $ShortRegion -Sku pernode}

# 3.3.2 Create Diagnotic Rules on Firewall
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating diagnostic setting on Firewall" -ForegroundColor Cyan
Try {Get-AzDiagnosticSetting -Name FW-Diagnostics -ResourceId $firewall.Id -ErrorAction Stop | Out-Null
     Write-Host "  Diagnostic setting already exists, skipping"}
Catch {Set-AzDiagnosticSetting -Name FW-Diagnostics -ResourceId $firewall.Id -Enabled $true -WorkspaceId $logWorkspace.ResourceId | Out-Null}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Module 3 completed successfully" -ForegroundColor Green
Write-Host
Write-Host "  Checkout your Firewall and policy in the Azure portal."
Write-Host "  Be sure to check out the Application rule collection for RDP traffic."
Write-Host "  Also, checkout the Route Table and it's association to the subnet"
Write-Host
Write-Host "  Also, use a browser to see your new Web Site served via the FIrewall IP address."
Write-Host "  The IIS Server (via NAT) is at" -NoNewline
Write-Host "  HTTP://$($pipFW.IpAddress)" -ForegroundColor Yellow
Write-Host
Write-Host "  For extra credit, try adding Application rules to the firewall to surf to specific web sites from your Azure VMs"
Write-Host
Write-Host
