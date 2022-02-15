﻿#
# DIY Azure Firewall Workshop
#
#
# Step 1 Create resource group, key vault, and secret
# Step 2 Create Virtual Network
# Step 3 Create an internet facing VM
# Step 4 Create and configure the Azure Firewall
# Step 5 Create Spoke VNet with IIS Server and a firewall rule to allow traffic
# 

# Step 5 Create Spoke VNet with IIS Server and a firewall rule to allow traffic
# 5.1 Validate and Initialize
# 5.2 Create VNet
# 5.3 Create the VM
# 5.3.1 Create NSG
# 5.3.2 Create NIC
# 5.3.3 Build VM
# 5.4 Configure Firewall Application Rules
# 5.5 Configure Firewall Network Rules
# 5.6 Add SNAT rule to Firewall
# 5.7 Run post deploy job (Install IIS)
# 5.8 Peer VNets
# 5.9 Assign Firewall UDR to subnet
# 5.10 Create Log Analytics workspace
# 5.11 Wait for IIS installation to finish

# 5.1 Validate and Initialize
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
$VNetName    = "Spoke01-VNet"
$VNetAddress = "10.11.12.128/25"
$snCluster   = "10.11.12.128/26"
$snTenant    = "10.11.12.192/26"
$HubVNetName = "Hub01-VNet01"
$HubVMName   = "Hub01-VM01"
$FWName      = "Hub01-FW01"
$VMName      = "Spoke01-VM01"
$VMSize      = "Standard_A4_v2"
$UserName01  = "User01"
$UserName02  = "User02"
$UserName03  = "User03"
$RDPRules    = ("10.11.12.0/27"), ("10.11.12.128/25"), ("10.3.12.0/25")
$kvName     = (Get-AzKeyVault -ResourceGroupName $RGName | Select-Object -First 1).VaultName

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 5, estimated total time 25 minutes" -ForegroundColor Cyan

# Set Subscription
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Setting Subscription Context" -ForegroundColor Cyan
Try {$myContext = Set-AzContext -Subscription $SubID -ErrorAction Stop}
Catch {Write-Warning "Permission check failed, ensure Sub ID is set correctly!"
        Return}
Write-Host "  Current Sub:",$myContext.Subscription.Name,"(",$myContext.Subscription.Id,")"

# Initialize Hub VNet variable
$hubvnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $HubVNetName -ErrorAction Stop
$HubVMIP = (Get-AzNetworkInterface -ResourceGroupName $RGName -Name $HubVMName'-nic' -ErrorAction Stop).IpConfigurations[0].PrivateIpAddress
$firewall = Get-AzFirewall -ResourceGroupName $RGName -Name $FWName -ErrorAction Stop

# 5.2 Create VNet
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Virtual Network" -ForegroundColor Cyan
Try {$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
     Write-Host "  resource exists, skipping"}
Catch {$vnet = New-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -AddressPrefix $VNetAddress -Location $ShortRegion  
       Write-Host (Get-Date)' - ' -NoNewline
       Write-Host "Adding subnets" -ForegroundColor Cyan
       Add-AzVirtualNetworkSubnetConfig -Name "Cluster" -VirtualNetwork $vnet -AddressPrefix $snCluster | Out-Null
       Add-AzVirtualNetworkSubnetConfig -Name "Tenant" -VirtualNetwork $vnet -AddressPrefix $snTenant | Out-Null
       Set-AzVirtualNetwork -VirtualNetwork $vnet | Out-Null}

# 5.3 Create the VM
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating VM" -ForegroundColor Cyan
Write-Host "  Pulling KeyVault Secret"
$kvs01 = Get-AzKeyVaultSecret -VaultName $kvName -Name $UserName01 -ErrorAction Stop
$kvs02 = Get-AzKeyVaultSecret -VaultName $kvName -Name $UserName02 -ErrorAction Stop 
$kvs03 = Get-AzKeyVaultSecret -VaultName $kvName -Name $UserName03 -ErrorAction Stop 
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

# 5.3.1 Create NSG
Write-Host "  Creating NSG"
Try {$nsg = Get-AzNetworkSecurityGroup -Name $VMName'-nic-nsg' -ResourceGroupName $RGName -ErrorAction Stop
Write-Host "    NSG exists, skipping"}
Catch {$nsgRuleRDP = New-AzNetworkSecurityRuleConfig -Name "myNSGRuleRDP" -Protocol Tcp -Direction Inbound -Priority 1000 `
                     -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
       $nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name "myNSGRuleHTTP" -Protocol Tcp -Direction Inbound -Priority 1020 `
                      -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80 -Access Allow
       $nsgRuleHTTPS = New-AzNetworkSecurityRuleConfig -Name "myNSGRuleHTTPS" -Protocol Tcp -Direction Inbound -Priority 1030 `
                       -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 443 -Access Allow
       $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $RGName -Location $ShortRegion -Name $VMName'-nic-nsg' -SecurityRules $nsgRuleRDP, $nsgRuleHTTP, $nsgRuleHTTPS}

# 5.3.3 Create NIC
Write-Host "  Creating NIC"
$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName
$sn = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "Tenant"
Try {$nic = Get-AzNetworkInterface -ResourceGroupName $RGName -Name $VMName'-nic' -ErrorAction Stop
     Write-Host "    NIC exists, skipping"}
Catch {$nic = New-AzNetworkInterface -ResourceGroupName $RGName -Name $VMName'-nic' -Location $ShortRegion -Subnet $sn -NetworkSecurityGroup $nsg}

# 5.3.4 Build VM
Write-Host "  Creating VM"
Try {Get-AzVM -ResourceGroupName $RGName -Name $VMName -ErrorAction Stop | Out-Null
          Write-Host "    VM exists, skipping"}
Catch {$vmConfig = New-AzVMConfig -VMName $VMName -VMSize $VMSize -ErrorAction Stop
       $vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $VMName -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
       $vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2019-Datacenter -Version latest
       $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id
       $vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Disable
       Write-Host "    queuing VM build job"
       New-AzVM -ResourceGroupName $RGName -Location $ShortRegion -VM $vmConfig -AsJob | Out-Null}

# 5.4 Configure Firewall Application Rules
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Configuring Firewall Application Rules" -ForegroundColor Cyan
If ($firewall.ApplicationRuleCollections.Name -contains 'FWAppRules') {
     Write-Host "  Firewall already configured, skipping"}
Else {$RuleSA = New-AzFirewallApplicationRule -Name 'StorageURLAllow' -SourceAddress * -TargetFqdn "vdcworkshop.blob.core.windows.net" -Protocol "Https:443"
      $RuleCollection = New-AzFirewallApplicationRuleCollection -Name "FWAppRules" -Priority 100 -Rule $RuleSA -ActionType "Allow"
      $firewall.ApplicationRuleCollections = $RuleCollection
      Set-AzFirewall -AzureFirewall $firewall | Out-Null
      $firewall = Get-AzFirewall -ResourceGroupName $RGName -Name $FWName}

# 5.5 Configure Firewall Network Rules
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Configuring Firewall Network Rules" -ForegroundColor Cyan
If ($firewall.NetworkRuleCollections.Rules.Name -contains 'WebAllow') {
     Write-Host "  Firewall already configured, skipping"}
Else {$RuleWeb = New-AzFirewallNetworkRule -Name "WebAllow" -SourceAddress * -DestinationAddress $($nic.IpConfigurations[0].PrivateIpAddress) -DestinationPort 80, 443 -Protocol TCP
      $RuleRDP = New-AzFirewallNetworkRule -Name "RDPAllow" -SourceAddress $RDPRules -DestinationAddress $($nic.IpConfigurations[0].PrivateIpAddress), $HubVMIP -DestinationPort 3389 -Protocol TCP
      $RuleCollection = New-AzFirewallNetworkRuleCollection -Name "FWNetRules" -Priority 100 -Rule $RuleWeb, $RuleRDP -ActionType "Allow"
      $firewall.NetworkRuleCollections = $RuleCollection
      Set-AzFirewall -AzureFirewall $firewall | Out-Null
      $firewall = Get-AzFirewall -ResourceGroupName $RGName -Name $FWName}

# 5.6 Add SNAT rule to Firewall
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Configuring Firewall NAT Rules" -ForegroundColor Cyan
$fwIP = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $FWName'-pip' -ErrorAction Stop
If ($firewall.NatRuleCollections.Name -contains 'FWNATRules') {
    Write-Host "  Firewall already configured, skipping"}
Else {$NATRule80 = New-AzFirewallNatRule -Name "Web80NAT" -Protocol TCP -SourceAddress * -DestinationAddress $fwIP.IpAddress -DestinationPort 80 -TranslatedAddress $nic.IpConfigurations[0].PrivateIpAddress -TranslatedPort 80
      $NATRule443 = New-AzFirewallNatRule -Name "Web443NAT" -Protocol TCP -SourceAddress * -DestinationAddress $fwIP.IpAddress -DestinationPort 443 -TranslatedAddress $nic.IpConfigurations[0].PrivateIpAddress -TranslatedPort 443
      $NATRuleCollection = New-AzFirewallNatRuleCollection -Name "FWNATRules" -Priority 100 -Rule $NATRule80, $NATRule443
      $firewall.NatRuleCollections = $NATRuleCollection
      Set-AzFirewall -AzureFirewall $firewall | Out-Null
      $firewall = Get-AzFirewall -ResourceGroupName $RGName -Name $FWName}

# 5.7 Run post deploy job (Install IIS)
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Waiting for the VM to deploy, this script will continue after 10 minutes or when the VM is built, whichever comes first." -ForegroundColor Cyan
Get-Job -Command "New-AzVM" | Wait-Job -Timeout 600 | Out-Null

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Running post VM deploy build script" -ForegroundColor Cyan
$ScriptStorageAccount = "vdcworkshop"
$ScriptName = "FirewallIISBuild.ps1"
$ExtensionName = 'FWBuildIIS'
$timestamp = (Get-Date).Ticks
$ScriptLocation = "https://$ScriptStorageAccount.blob.core.windows.net/scripts/" + $ScriptName
$ScriptExe = "(.\$ScriptName -User2 '$UserName02' -Pass2 '" + $kvs02 + "' -User3 '$UserName03' -Pass3 '" + $kvs03 + "')"
$PublicConfiguration = @{"fileUris" = [Object[]]"$ScriptLocation";"timestamp" = "$timestamp";"commandToExecute" = "powershell.exe -ExecutionPolicy Unrestricted -Command $ScriptExe"}

Try {Get-AzVMExtension -ResourceGroupName $RGName -VMName $VMName -Name $ExtensionName -ErrorAction Stop | Out-Null
     Write-Host "  Extension was previously deployed, skipping."}
Catch {Write-Host "  queuing build job."
       Set-AzVMExtension -ResourceGroupName $RGName -VMName $VMName -Location $ShortRegion -Name $ExtensionName `
                         -Publisher 'Microsoft.Compute' -ExtensionType 'CustomScriptExtension' -TypeHandlerVersion '1.9' `
                         -Settings $PublicConfiguration -AsJob -ErrorAction Stop | Out-Null}

# 5.8 Peer VNets
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Peering Hub to Spoke" -ForegroundColor Cyan
Try {Get-AzVirtualNetworkPeering -Name "HubtoSpoke" -VirtualNetworkName $HubVNetName -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
     Write-Host "  peering exists, skipping" }
Catch {Try {Add-AzVirtualNetworkPeering -Name "HubtoSpoke" -VirtualNetwork $hubvnet -RemoteVirtualNetworkId $vnet.Id -ErrorAction Stop | Out-Null}
	   Catch {Write-Warning "Error creating VNet Peering"; Return}}

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Peering Spoke to Hub" -ForegroundColor Cyan
Try {Get-AzVirtualNetworkPeering -Name "SpoketoHub" -VirtualNetworkName $VNetName -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
     Write-Host "  peering exists, skipping" }
Catch {Try {Add-AzVirtualNetworkPeering -Name "SpoketoHub" -VirtualNetwork $vnet -RemoteVirtualNetwork $hubvnet.Id -ErrorAction Stop | Out-Null}
	   Catch {Write-Warning "Error creating VNet Peering"; Return}}

# 5.9 Assign Firewall UDR to subnet
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Associating UDR Table to Spoke Tenant subnet" -ForegroundColor Cyan
$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
$sn = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "Tenant" -ErrorAction Stop
$fwRouteTable = Get-AzRouteTable -Name $HubVNetName'-rt-fw' -ResourceGroupName $RGName -ErrorAction Stop
If ($null -eq $sn.RouteTable) {$sn.RouteTable = $fwRouteTable
                               Set-AzVirtualNetwork -VirtualNetwork $vnet | Out-Null}
Else {Write-Host "  A Route Table is already assigned to the subnet, skipping"}

# 5.10 Create Log Analytics workspace
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Log Analytics Workspace for monitoring collection" -ForegroundColor Cyan
Try {Get-AzOperationalInsightsWorkspace -ResourceGroupName $RGName -Name $RGName'-logs' -ErrorAction Stop | Out-Null
     Write-Host "  Workspace already exists, skipping"}
Catch {New-AzOperationalInsightsWorkspace -ResourceGroupName $RGName -Name $RGName'-logs' -Location westus2 -Sku pernode | Out-Null}

# 5.11 Wait for IIS installation to finish
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Waiting for IIS installation to finish, script will continue after 5 minutes or when the installation finishes, whichever is first." -ForegroundColor Cyan
Get-Job -Command "Set-AzVMExtension" | Wait-Job -Timeout 300 | Out-Null

# End Nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 5 completed successfully" -ForegroundColor Green
Write-Host "  All environment components are built, time to play!" -ForegroundColor Green
Write-Host
Write-Host "  Review your new Spoke and it's components in the Azure Portal"
Write-Host "  Also, use a browser to see your new Web Site"
Write-Host "  The IIS Server (via NAT) is at" -NoNewline
Write-Host "  HTTP://$($fwIP.IpAddress)" -ForegroundColor Yellow
Write-Host
Write-Host "  You can also enable monitoring on the firewall and watch the logs."
Write-Host "  Useful log queries can be found at:"
Write-Host "  https://docs.microsoft.com/en-us/azure/firewall/log-analytics-samples#network-rules-log-data-query" -ForegroundColor Yellow
Write-Host
Write-Host "  For extra credit, try adding Application rules to the firewall to surf to specific web sites from your Azure VMs"
Write-Host