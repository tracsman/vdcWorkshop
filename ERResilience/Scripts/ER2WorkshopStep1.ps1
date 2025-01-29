#
# ExpressRoute Resiliency Workshop Part 2
#
# Use your corporate credentials to login (your @microsoft.com account) to Azure
#
#
# Step 1 Create a metro peered ExpressRoute circuit
# Step 2 Bring up ExpressRoute Private Peering
# Step 3 Create the connection between the ER Gateway and the ER Circuit
# Step 4 Delete old peering and connection (no script)
# 

# Step 1 Create an ExpressRoute circuit and ER Gateway
#  1.1 Validate and Initialize
#  1.2 Create ExpressRoute Circuit

# 1.1 Validate and Initialize
# Az Module Test
$ModCheck = Get-Module Az.Network -ListAvailable
If ($Null -eq $ModCheck) {
    Write-Warning "The Az PowerShell module was not found. This script uses the Az modules for PowerShell"
    Write-Warning "See the blob post for more information at: https://azure.microsoft.com/blog/how-to-migrate-from-azurerm-to-az-in-azure-powershell/"
    Return
    }

# Load Initialization Variables
$ScriptDir = "$env:HOME/Scripts"
If (Test-Path -Path $ScriptDir/init.txt) {
        Get-Content $ScriptDir/init.txt | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}}}
Else {Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}

# Non-configurable Variable Initialization (ie don't modify these)
$ShortRegionEU = "westeurope"
$RGName = "Company" + $CompanyID
$VNetNameEU = "C" + $CompanyID + "z-VNet"
$CircuitNameEU = "C" + $CompanyID + "z-ER-m"
$CircuitLocationEU = 'Amsterdam Metro'

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 1, estimated total time 4 minutes" -ForegroundColor Cyan

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

#  1.2 Create ExpressRoute Circuit
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating ExpressRoute Circuit in $CircuitLocationEU" -ForegroundColor Cyan
Try {Get-AzExpressRouteCircuit -ResourceGroupName $RGName -Name $CircuitNameEU -ErrorAction Stop | Out-Null
        Write-Host '  resource exists, skipping'}
Catch {New-AzExpressRouteCircuit -ResourceGroupName $RGName -Name $CircuitNameEU -Location $ShortRegionEU `
                                      -ServiceProviderName Equinix -PeeringLocation $CircuitLocationEU `
                                      -BandwidthInMbps 50 -SkuFamily MeteredData -SkuTier Standard | Out-Null
}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 1 completed successfully" -ForegroundColor Green
Write-Host "  Review your circuit in the Azure Portal, especially note the 'Provider status'"
Write-Host "  The instructor will now contact the service provider to provision your circuit"
Write-Host
