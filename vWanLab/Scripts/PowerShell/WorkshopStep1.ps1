#
# Azure Virtual WAN Workshop
#
# Use your corporate credentials to login (your @microsoft.com account) to Azure
#
#
# Step 1 Create a vWAN, a vWAN Hub, and vWAN VPN Gateway
# Step 2 Create a NetFoundry Virtual Appliance
# Step 3 Create a Cisco CSR Virtual Appliance
# Step 4 Connect the two Azure VNets to the vWAN Hub
# Step 5 Configure and Connect Site 1 (NetFoundry) using the partner experience
# Step 6 Configure and Connect Site 2 (Cisco) using manual VPN provisioning
# (Not included) Step 7 Configure and Connect Client01, a Point-to-Site manual VPN connection
# (Not included) Step 8 Configure and Connect ExpressRoute to vWAN Hub
# 

# Step 1 - Create a vWAN, a vWAN Hub, and vWAN VPN Gateway
# 1.1 Validate and Initialize
# 1.2 Create a vWAN
# 1.3 Create a vWAN Hub
# 1.4 Create a vWAN VPN Gateway
#

# 1.1 Validate and Initialize
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
$RGName = "Company" + $CompanyID + "-Hub01"
$vWANName = "C" + $CompanyID + "-vWAN01"
$HubPrefix = "172.16." + $CompanyID + ".0/24"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 1, estimated total time 30 - 50 minutes" -ForegroundColor Cyan

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

# 1.2 Create a vWAN
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating vWAN" -ForegroundColor Cyan
Try {$wan = Get-AzVirtualWan -ResourceGroupName $RGName -Name $vWANName -ErrorAction Stop
     Write-Host "  vWAN exists, skipping"}
Catch {$wan = New-AzVirtualWan -ResourceGroupName $RGName -Name $vWANName -Location $ShortRegion -AllowBranchToBranchTraffic -AllowVNetToVNetTraffic}

# Add the NetFoundry Service Principal to allow access to the vWAN to pull config
$RoleExists = $Null
$RoleExists = Get-AzRoleAssignment -ObjectId abf6f2a4-d951-438e-8ff7-4f9360d8973b -RoleDefinitionName "Contributor" -ResourceGroupName $RGName -ResourceName $vWANName -ResourceType Microsoft.Network/virtualWans
If ($null -eq $RoleExists) {New-AzRoleAssignment -ObjectId abf6f2a4-d951-438e-8ff7-4f9360d8973b -RoleDefinitionName "Contributor" -ResourceGroupName $RGName -ResourceName $vWANName -ResourceType Microsoft.Network/virtualWans | Out-Null}
Else {Write-Host "  role assingment exists, skipping"}

# 1.3 Create a vWAN Hub
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating vWAN Hub" -ForegroundColor Cyan
$hub = Get-AzVirtualHub -ResourceGroupName $RGName -Name $vWANName'-Hub01' -ErrorAction Stop
If ($null -eq $hub) {$hub = New-AzVirtualHub -ResourceGroupName $RGName -Name $vWANName'-Hub01' -Location $ShortRegion -VirtualWan $wan -AddressPrefix $HubPrefix}
Else {Write-Host "  vWAN Hub exists, skipping"}

# 1.4 Create a vWAN VPN Gateway
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Hub VPN Gateway" -ForegroundColor Cyan
Try {Get-AzVpnGateway -ResourceGroupName $RGName -Name $vWANName'-Hub01-gw-vpn' -ErrorAction Stop | Out-Null
     Write-Host "  Hub VPN Gateway exists, skipping"}
Catch {New-AzVpnGateway -ResourceGroupName $RGName -Name $vWANName'-Hub01-gw-vpn' -VpnGatewayScaleUnit 1 -VirtualHub $hub | Out-Null}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 1 completed successfully" -ForegroundColor Green
Write-Host "  Explore your new vWAN, Hub, and Gateway in the Azure Portal."
Write-Host
