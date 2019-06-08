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

# Step 4 Connect the two Azure VNets to the vWAN Hub
# 4.1 Validate and Initialize
# 4.2 Connect Azure Site 01
# 4.3 Connect Azure Site 01
#

# 4.1 Validate and Initialize
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
$hubRGName = "Company" + $CompanyID + "-Hub01"
$Az01RGName = "Company" + $CompanyID + "-Azure01"
$Az02RGName = "Company" + $CompanyID + "-Azure02"
$hubName = "C" + $CompanyID + "-vWAN01-Hub01"
$Az01VNetName = "C" + $CompanyID + "-Az01-VNet01"
$Az02VNetName = "C" + $CompanyID + "-Az02-VNet01"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 4, estimated total time 5 minutes" -ForegroundColor Cyan

# Login and permissions check
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Checking login and permissions" -ForegroundColor Cyan
Try {Get-AzResourceGroup -Name $hubRGName -ErrorAction Stop | Out-Null}
Catch {# Login and set subscription for ARM
       Write-Host "Logging in to ARM"
       Try {$Sub = (Set-AzContext -Subscription $SubID -ErrorAction Stop).Subscription}
       Catch {Connect-AzAccount | Out-Null
              $Sub = (Set-AzContext -Subscription $SubID -ErrorAction Stop).Subscription}
       Write-Host "Current Sub:",$Sub.Name,"(",$Sub.Id,")"
       Try {Get-AzResourceGroup -Name $hubRGName -ErrorAction Stop | Out-Null}
       Catch {Write-Warning "Permission check failed, ensure company id is set correctly!"
              Return}
}

# Initialize vWAN Hub, VNet01, and VNet02 variables
Try {$hub=Get-AzVirtualHub -ResourceGroupName $hubRGName -Name $hubName -ErrorAction Stop}
Catch {Write-Warning "vWAN Hub wasn't found, please run step 1 before running this script"
       Return}

Try {$Az01VNet=Get-AzVirtualNetwork -ResourceGroupName $Az01RGName -Name $Az01VNetName -ErrorAction Stop}
Catch {Write-Warning "Azure Site 1 Virtual Network wasn't found, please run step 0 before running this script"
       Return}

Try {$Az02VNet=Get-AzVirtualNetwork -ResourceGroupName $Az02RGName -Name $Az02VNetName -ErrorAction Stop}
Catch {Write-Warning "Azure Site 2 Virtual Network wasn't found, please run step 0 before running this script"
       Return}

# 4.2 Connect Azure 01 VNet
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Connecting Azure 01 VNet to the vWAN hub" -ForegroundColor Cyan
Try {Get-AzVirtualHubVnetConnection -ParentObject $hub -Name 'Hub01-conn-Az01' -ErrorAction Stop | Out-Null
     Write-Host "  Azure 01 VNet connection exists, skipping"}
Catch {New-AzVirtualHubVnetConnection -Name 'Hub01-conn-Az01' -ParentObject $hub -RemoteVirtualNetwork $Az01VNet | Out-Null}

# 4.3 Connect Azure 01 VNet
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Connecting Azure 02 VNet to the vWAN hub" -ForegroundColor Cyan
Try {Get-AzVirtualHubVnetConnection -ParentObject $hub -Name 'Hub01-conn-Az02' -ErrorAction Stop | Out-Null
     Write-Host "  Azure 02 VNet connection exists, skipping"}
Catch {New-AzVirtualHubVnetConnection -Name 'Hub01-conn-Az02' -ParentObject $hub -RemoteVirtualNetwork $Az02VNet | Out-Null}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 4 completed successfully" -ForegroundColor Green
Write-Host "  Checkout the new connections in the vWAN Hub in the Azure portal."
Write-Host
