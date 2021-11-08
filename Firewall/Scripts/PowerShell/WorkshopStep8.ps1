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

# Step 8 create a private endpoint for a storage account in spoke vnet
# 8.1 Validate and Initialize
# 8.2 Configure Firewall Network Rules
# 8.3 Configure Firewall Application Rules to access in http and https, from the spoke vnet to internet 
# 8.4 in the spoke vnet in the subnet 'Cluster', disable the private endpoint network policy  
# 8.5 Create a storage account 
# 8.6 Create a Private Endpoint for the storage account in your Virtual Network
# 8.7 Configure the Private DNS Zone
# 8.8 Create DNS configuration zone
# 8.9 if autoregistration is disabled, add the A record manually in the private DNS zone 

# 8.1 Validate and Initialize
# Az Module Test
$ModCheck = Get-Module Az.Network -ListAvailable
If ($Null -eq $ModCheck) {
    Write-Warning "The Az PowerShell module was not found. This script uses the Az modules for PowerShell"
    Write-Warning "See the blog post for more information at: https://azure.microsoft.com/blog/how-to-migrate-from-azurerm-to-az-in-azure-powershell/"
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
$VNetName = "C" + $CompanyID + "-Spoke-VNet"
$VNetAddress = "10.17." + $CompanyID + ".128/25"
$snCluster = "10.17." + $CompanyID + ".128/26"
$subnetName = 'Cluster'
$snTenant = "10.17." + $CompanyID + ".192/26"
$HubVNetName = "C" + $CompanyID + "-VNet"
$onpremAddress ="10.3." + $CompanyID + ".0/25"
#
$storageAccountType = 'Standard_LRS'                            # type of storage account
$privateEndpointName = 'privEP-storage'+ $CompanyID             # name private endpoint
$autoregistration = $false                                      # boolean value: $true or $false
$privLinkServiceConnectionName= 'linkServiceConn'+ $CompanyID   # name of the private link connection
$privDNSVNetLinkName ='dnsLink'+ $CompanyID                     # name of the private DNS VNet link
$privDNSZoneGroupName = 'dnsZoneGRP'+ $CompanyID                # name of the private DNS VNet link


# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 8, estimated total time XX minutes" -ForegroundColor Cyan

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

# Initialize spoke VNet variable
$firewall = Get-AzFirewall -ResourceGroupName $RGName -Name $RGName'-Firewall' -ErrorAction Stop
$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop


# 8.2 Configure Firewall Network Rules
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Configuring Firewall Network Rules" -ForegroundColor Cyan
If ($firewall.NetworkRuleCollections.Rules.Name -contains 'Allow-onprem-to-spoke') {
     Write-Host "  Firewall already configured, skipping"}
Else {
      $RuleOnPrem = New-AzFirewallNetworkRule -Name "Allow-onprem-to-spoke" -SourceAddress $onpremAddress -DestinationAddress $VNetAddress -DestinationPort * -Protocol Any
      $RuleCollection = New-AzFirewallNetworkRuleCollection -Name "FWNetRules2" -Priority 200 -Rule $RuleOnPrem -ActionType "Allow"
      $firewall.NetworkRuleCollections.Add($RuleCollection)
      Set-AzFirewall -AzureFirewall $firewall | Out-Null
      $firewall = Get-AzFirewall -ResourceGroupName $RGName -Name $RGName'-Firewall'}

# 8.3 Configure Firewall Application Rules to access in http and https, from the spoke vnet to internet 
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Configuring Firewall Application Rules" -ForegroundColor Cyan
If ($firewall.ApplicationRuleCollections.Rules.Name -contains 'spoke-to-internet') {
     Write-Host "  Firewall already configured, skipping"}
Else {
      $RuleSA = New-AzFirewallApplicationRule -Name 'spoke-to-internet' -SourceAddress $VNetAddress -TargetFqdn "*" -Protocol "http:80","https:443"
      $RuleCollection = New-AzFirewallApplicationRuleCollection -Name "FWAppRules2" -Priority 200 -Rule $RuleSA -ActionType "Allow"
      $firewall.ApplicationRuleCollections.Add($RuleCollection)
      Set-AzFirewall -AzureFirewall $firewall | Out-Null
      $firewall = Get-AzFirewall -ResourceGroupName $RGName -Name $RGName'-Firewall'}

# 8.4 in the spoke vnet in the subnet 'Cluster', disable the private endpoint network policy  
($vnet | Select -ExpandProperty subnets | Where-Object {$_.Name -eq $subnetName}).PrivateEndpointNetworkPolicies = "Disabled"
Set-AzVirtualNetwork -VirtualNetwork $vnet | Out-Null


# 8.5 Create a storage account 
# generate a unique name for the storage account
$tail=([guid]::NewGuid().tostring()).replace("-","").Substring(0,12)
$storageAccountName = 'strg'+ $CompanyID + $tail

### check the existance of a storage account in the resource group
$s = Get-AzStorageAccount -ResourceGroupName $RGName

# check if $s has $null as value
if (!$s) { 
   # create a new storage account
   try {
       # Create a new storage account.
       $storageAccount = New-AzStorageAccount -ResourceGroupName $RGName –StorageAccountName $storageAccountName -Location $ShortRegion -Type $storageAccountType -ErrorAction Stop 
       Write-Host "$(Get-Date) - Created a new storage account: "$storageAccount.StorageAccountName  -ForegroundColor Cyan
   } 
   catch{
       Write-Host "$(Get-Date) - Error to create the storage account: "$storageAccount.StorageAccountName  -ForegroundColor White -BackgroundColor Red
   }
} 
else {
  $storageAccount = $s[0]
  Write-Host "$(Get-Date) - getting the storage account: "$storageAccount.StorageAccountName
}

# 8.6 Create a Private Endpoint for the storage account in your Virtual Network
try {
    Write-Host "$(Get-Date) - getting the private service endpoint: $privateEndpointName" -ForegroundColor Cyan
    $privEndpoint = Get-AzPrivateEndpoint -ResourceGroupName $RGName -Name $privateEndpointName -ErrorAction Stop
    Write-Host "... skipping, private service endpoint: "$privateEndpointName " exists" -ForegroundColor Green
    }
catch{
    Write-Host "$(Get-Date) - create a new private link service connection" -ForegroundColor Cyan
    # the private link service connection object is created in memory. 
    # it is a private link service connection configuration.
    $privateEndpointConnection = New-AzPrivateLinkServiceConnection -Name $privLinkServiceConnectionName `
       -PrivateLinkServiceId $storageAccount.Id `
       -GroupId 'blob'
  
    $vnet = Get-AzVirtualNetwork -ResourceGroupName  $RGName -Name $VNetName -ErrorAction Stop
    # select the subnet named 'Cluster' in spoke VNet
    $subnet = $vnet | Select-Object -ExpandProperty subnets | Where-Object  {$_.Name -eq $subnetName }  
   
    Write-Host "$(Get-Date) - create a new private service endpoint: $privateEndpointName" -ForegroundColor Cyan
    $privateEndpoint = New-AzPrivateEndpoint -ResourceGroupName $RGName `
       -Name $privateEndpointName `
       -Location $ShortRegion `
       -Subnet  $subnet `
       -PrivateLinkServiceConnection $privateEndpointConnection
}

# 8.7 Configure the Private DNS Zone
try{
    Write-Host "$(Get-Date) - Get the private DNS zone: privatelink.blob.core.windows.net" -ForegroundColor Cyan
    $zone = Get-AzPrivateDnsZone -ResourceGroupName $RGName -Name 'privatelink.blob.core.windows.net' -ErrorAction Stop
    Write-Host "... skipping, the private DNS zone: privatelink.blob.core.windows.net already exists" -ForegroundColor Green
}
catch {
   Write-Host "$(Get-Date) - Creating the private DNS zone: privatelink.blob.core.windows.net" -ForegroundColor Cyan
   $zone = New-AzPrivateDnsZone -ResourceGroupName $RGName -Name 'privatelink.blob.core.windows.net'
}

$vnet = Get-AzVirtualNetwork -ResourceGroupName  $RGName -Name $VNetName -ErrorAction Stop 

try {
        Write-Host "$(Get-Date) - Checking the private DNS VNEt link: "$privDNSVNetLinkName -ForegroundColor Cyan
        $link = Get-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $RGName -ZoneName 'privatelink.blob.core.windows.net' -Name $privDNSVNetLinkName -ErrorAction Stop 
    }
catch {
        if ($autoregistration)
        {
           $link  = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $RGName `
              -ZoneName 'privatelink.blob.core.windows.net' `
              -Name $privDNSVNetLinkName `
              -VirtualNetworkId $vnet.Id -EnableRegistration
        } 
        else {
            $link  = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $RGName `
              -ZoneName 'privatelink.blob.core.windows.net' `
              -Name $privDNSVNetLinkName `
              -VirtualNetworkId $vnet.Id
        }
    }


# 8.8 Create DNS configuration zone
$config = New-AzPrivateDnsZoneConfig -Name 'privatelink.blob.core.windows.net' -PrivateDnsZoneId $zone.ResourceId 

try {
    Write-Host "$(Get-Date) - get the private DNS zone group" -ForegroundColor Cyan
    $zoneGrp = Get-AzPrivateDnsZoneGroup -Name $privDNSZoneGroupName -ResourceGroupName $RGName -PrivateEndpointName $privateEndpointName -ErrorAction Stop 
    if (!$zoneGrp.PrivateDnsZoneConfigs.PrivateDnsZoneId)
    {
        Write-Host "$(Get-Date) - Set the private DNS zone config in DNS Zone Group: "$privDNSZoneGroupName -ForegroundColor Green
        Set-AzPrivateDnsZoneGroup -Name $privDNSZoneGroupName -ResourceGroupName $RGName -PrivateEndpointName $privateEndpointName -PrivateDnsZoneConfig $config | Out-Null
    }
}
catch {
    Write-Host "$(Get-Date) - Create a new private DNS zone group" -ForegroundColor Cyan
    ## Create DNS zone group. ##
    $zoneGrp = New-AzPrivateDnsZoneGroup -Name $privDNSZoneGroupName -ResourceGroupName $RGName -PrivateEndpointName $privateEndpointName -PrivateDnsZoneConfig $config
}

$zoneGrp = Get-AzPrivateDnsZoneGroup -Name $privDNSZoneGroupName -ResourceGroupName $RGName -PrivateEndpointName $privateEndpointName
Write-Host "$(Get-Date) - private DNS Zone - record set FQDN: "$zoneGrp.PrivateDnsZoneConfigs.RecordSets.Fqdn -ForegroundColor Cyan

# 8.9 if autoregistration is disabled, add the A record manually in the private DNS zone 
if (!$autoregistration)
{
   Write-Host "$(Get-Date) - Manual Registration of private link in private DNS zone - creation A record" -ForegroundColor Cyan
   # get the nic associated with the private endpoint
   $nic = Get-AzResource -ResourceId $privateEndpoint.NetworkInterfaces[0].Id -ApiVersion "2020-11-01" 
   foreach ($ipconfig in $nic.properties.ipConfigurations) { 
        foreach ($fqdn in $ipconfig.properties.privateLinkConnectionProperties.fqdns) { 
           Write-Host "$(Get-Date) - Registration priv IP Addr: $($ipconfig.properties.privateIPAddress) $($fqdn)" -ForegroundColor Cyan
           $recordName = $fqdn.split('.',2)[0] 
           $dnsZone = $fqdn.split('.',2)[1] 
           New-AzPrivateDnsRecordSet -Name $recordName -RecordType A -ZoneName "privatelink.blob.core.windows.net"  `
             -ResourceGroupName $RGName -Ttl 10 `
             -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $ipconfig.properties.privateIPAddress)  -ErrorAction SilentlyContinue 
        } 
    }
}

# End Nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 8 completed successfully" -ForegroundColor Green
Write-Host "  All environment components are built, time to play!" -ForegroundColor Green
Write-Host ""
Write-Host "  1. download and install the Azure storage explorer in the in spoke VM and in lab VM and "
Write-Host "  2. in the on-premises Windows VM add to the file: "
Write-Host "     C:\Windows\System32\drivers\etc\hosts          "
Write-Host "     the entry:                                     "
Write-Host "     private-IP-endpoint    storage account URL     " 
Write-Host "     to traslate the storage URL into the private endpoint"
Write-Host "  3. Connect by storage explorer to the storage account" 
Write-Host ""