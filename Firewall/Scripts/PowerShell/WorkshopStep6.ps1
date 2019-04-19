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
#  6.4 Create the UDR table
#  6.5 Assign the UDR table to the Tenant subnet

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

# 6.2 Create the Azure Firewall
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating the firewall" -ForegroundColor Cyan
# 6.2.1 Create Public IP
Write-Host "  Creating Public IP"
Try {$pip = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $RGName'-firewall-pip' -ErrorAction Stop
     Write-Host "    Public IP exists, skipping"}
Catch {$pip = New-AzPublicIpAddress -ResourceGroupName $RGName -Name $RGName'-firewall-pip' -Location $ShortRegion -AllocationMethod Dynamic}

# 6.2.2 Create Firewall
Try {$firewall = Get-AzFirewall -ResourceGroupName $RGName -Name $RGName'-Firewall'
     Write-Host "  Firewall exists, skipping"}
Catch {$firewall = New-AzFirewall -Name $RGName'-Firewall' -ResourceGroupName $RGName -Location $ShortRegion -VirtualNetworkName $vnet.Name -PublicIpName $pip.Name}

# 6.3 Configure the Azure Firewall
If ($firewall.ApplicationRuleCollections[0].Name -eq 'FWRuleCollection') {Write-Host "  Firewall rules exists, skipping"}
Else {$Rule = New-AzFirewallApplicationRule -Name "Allow_Web" -Protocol "http:80","https:443" -TargetFqdn "*microsoft.com"
      $RuleCollection = New-AzFirewallApplicationRuleCollection -Name "FWRuleCollection" -Priority 100 -Rule $Rule -ActionType "Allow"
      $firewall.ApplicationRuleCollections = $RuleCollection
      Set-AzFirewall -AzureFirewall $firewall | Out-Null
      $firewall = Get-AzFirewall -ResourceGroupName $RGName -Name $RGName'-Firewall'}

# Create UDR rule
$fwRouteName = 'Firewall-Route'
$fwRouteTableName = $RGName'-Firewall-rt'
$fwIP = $firewall.IpConfigurations[0].PrivateIPAddress
$fwRoute = New-AzRouteConfig -Name $fwRouteName -AddressPrefix 0.0.0.0/0 -NextHopType VirtualAppliance -NextHopIpAddress $fwIP
$fwRouteTable = New-AzRouteTable -Name $fwRouteTableName -ResourceGroupName $RGName -location $ShortRegion -Route $fwRoute

#-=-=-=-=-=-=-=-=-=-=-=-=-
Try {$Spoke2RT = Get-AzureRmRouteTable -Name $Spoke2Name'-rt' -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop
     Write-Host "  $Spoke2Name route table exists, skipping"}
Catch {$Spoke2RT = New-AzureRmRouteTable -Name $Spoke2Name'-rt' -ResourceGroupName $rg.ResourceGroupName -location $rg.Location
       Get-AzureRmRouteTable -ResourceGroupName $rg.ResourceGroupName -Name $Spoke2Name'-rt' | `
                Add-AzureRmRouteConfig -Name "Spoke02ToFS" -AddressPrefix $Spoke1VNet.Subnets[0].AddressPrefix[0] -NextHopType "VirtualAppliance" -NextHopIpAddress $HubLBIP | `
                Set-AzureRmRouteTable | Out-Null}
#-=-=-==-=-=-=-=-=-=-=-=-

# Associate to Servers Subnet
$sn = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "Tenant"
$vnet.Subnets[2].RouteTable = $AzfwRouteTable
Set-AzVirtualNetwork -VirtualNetwork $vnet

Try {Set-AzureRmVirtualNetworkSubnetConfig -Name $Spoke1VNet.Subnets[0].Name -VirtualNetwork $Spoke1VNet -AddressPrefix $Spoke1VNet.Subnets[0].AddressPrefix `
       -RouteTable $Spoke1RT | Set-AzureRmVirtualNetwork | Out-Null
Set-AzureRmVirtualNetworkSubnetConfig -Name $Spoke2VNet.Subnets[0].Name -VirtualNetwork $Spoke2VNet -AddressPrefix $Spoke2VNet.Subnets[0].AddressPrefix `
       -RouteTable $Spoke2RT | Set-AzureRmVirtualNetwork | Out-Null
}
Catch {
Write-Warning 'Assigning route tables to subnets failed. Please review or contact the proctor for more assistance'
Return
}


# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 6 completed successfully" -ForegroundColor Green
Write-Host "  The instructions to configure the Cisco device have been copied to the clipboard, open Notepad and paste the instructions to configure the device. If you need the instructions again, rerun this script and the instructions will be reloaded to the clipboard."
Write-Host
