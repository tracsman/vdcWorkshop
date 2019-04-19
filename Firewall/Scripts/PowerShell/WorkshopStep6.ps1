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
# 6.2.1 Create Public IP
Write-Host "  Creating Public IP"
Try {$pip = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $RGName'-firewall-pip' -ErrorAction Stop
     Write-Host "    Public IP exists, skipping"}
Catch {$pip = New-AzPublicIpAddress -ResourceGroupName $RGName -Name $RGName'-firewall-pip' -Location $ShortRegion -AllocationMethod Dynamic}

# 6.2.2 Create Firewall
$firewall = New-AzFirewall -Name $RGName'-Firewall' -ResourceGroupName $RGName -Location $ShortRegion -VirtualNetworkName $vnet.Name -PublicIpName $pip.Name

#  6.3 Configure the Azure Firewall
$Azfw = Get-AzFirewall -ResourceGroupName $RG
$Rule = New-AzFirewallApplicationRule -Name R1 -Protocol "http:80","https:443" -TargetFqdn "*microsoft.com"
$RuleCollection = New-AzFirewallApplicationRuleCollection -Name RC1 -Priority 100 -Rule $Rule -ActionType "Allow"
$Azfw.ApplicationRuleCollections = $RuleCollection
Set-AzFirewall -AzureFirewall $Azfw

#Create UDR rule
$Azfw = Get-AzFirewall -ResourceGroupName $RG
$AzfwRouteName = $RG + "AzfwRoute"
$AzfwRouteTableName = $RG + "AzfwRouteTable"
$IlbCA = $Azfw.IpConfigurations[0].PrivateIPAddress
$AzfwRoute = New-AzRouteConfig -Name $AzfwRouteName -AddressPrefix 0.0.0.0/0 -NextHopType VirtualAppliance -NextHopIpAddress $IlbCA
$AzfwRouteTable = New-AzRouteTable -Name $AzfwRouteTableName -ResourceGroupName $RG -location $Location -Route $AzfwRoute

#associate to Servers Subnet
$vnet.Subnets[2].RouteTable = $AzfwRouteTable
Set-AzVirtualNetwork -VirtualNetwork $vnet

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 6 completed successfully" -ForegroundColor Green
Write-Host "  The instructions to configure the Cisco device have been copied to the clipboard, open Notepad and paste the instructions to configure the device. If you need the instructions again, rerun this script and the instructions will be reloaded to the clipboard."
Write-Host
