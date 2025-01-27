#
# ExpressRoute Resiliency Workshop Part 2
#
# Use your corporate credentials to login (your @microsoft.com account) to Azure
#
#
# Step 1 Create an ExpressRoute circuit and ER Gateway
# Step 2 Bring up ExpressRoute Private Peering
# Step 3 Create the connection between the ER Gateway and the ER Circuit
# Step 4 Delete old peering and connection (no script)
# 

# Step 3 Create the connection between the ER Gateway and the ER Circuit
#  3.1 Validate and Initialize
#  3.2 Create the connection between the ER Gateway and the ER Circuit

# 3.1 Validate and Initialize
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
$CircuitName = $RGName + "-er"
$AzureVMIP = "10.17." + $CompanyID + ".4"
$OnPremVMIP = "10.3." + $CompanyID + ".10"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 5, estimated total time 5 minutes" -ForegroundColor Cyan

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

# Get Circuit Info
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Pulling circuit information' -ForegroundColor Cyan
Try {$ckt = Get-AzExpressRouteCircuit -ResourceGroupName $RGName -Name $CircuitName -ErrorAction Stop}
Catch {Write-Warning "The circuit wasn't found, please ensure step three is successful before running this script."
       Return}

# Ensure Private Peering is enabled, then create connection objects
Try {Get-AzExpressRouteCircuitPeeringConfig -ExpressRouteCircuit $ckt -Name AzurePrivatePeering -ErrorAction Stop | Out-Null}
Catch {Write-Warning "Private Peering isn't enabled on the ExpressRoute circuit. Please ensure private peering is enable successfully (step 4)."
       Return}

#  3.2 Create the connection between the ER Gateway and the ER Circuit
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Connecting Gateway to ExpressRoute in $($ckt.ServiceProviderProperties.PeeringLocation)" -ForegroundColor Cyan
Try {Get-AzVirtualNetworkGatewayConnection -Name $VNetName"-gw-conn" -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
    Write-Host '  connection exists, skipping'}
Catch {$gw = Get-AzVirtualNetworkGateway -Name $VNetName"-gw" -ResourceGroupName $RGName
       $NeedSpace = $False
       $i=0
       If ($gw.ProvisioningState -eq 'Updating') {Write-Host '  waiting for ER gateway to finish provisioning: ' -NoNewline
                                                  $NeedSpace=$True
                                                  Sleep 10}
       While ($gw.ProvisioningState -eq 'Updating') {
              $i++
              If ($i%6) {Write-Host '*' -NoNewline}
              Else {Write-Host "$($i/6)" -NoNewline}
              Sleep 10
              $gw = Get-AzVirtualNetworkGateway -Name $VNetName-gw -ResourceGroupName $RGName}
       If ($gw.ProvisioningState -eq 'Succeeded') {
           If ($NeedSpace) {Write-Host}
           Write-Host '  Gateway is provisioned'
           Write-Host '  Connecting to ExpressRoute'
           New-AzVirtualNetworkGatewayConnection -Name $VNetName"-gw-conn" -ResourceGroupName $RGName -Location $ShortRegion `
                                                 -VirtualNetworkGateway1 $gw -PeerId $ckt.Id -ConnectionType ExpressRoute | Out-Null}
       Else {Write-Warning 'An issue occured with ER gateway provisioning.'
             Write-Host 'Current Gateway Provisioning State' -NoNewLine
             Write-Host $gw.ProvisioningState
             Return}
}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 5 completed successfully" -ForegroundColor Green
Write-Host "  Review your route table on the Private Peering again."
Write-Host "  You should now see your VNet routes from Azure."
Write-Host "  Now try pinging the Azure VM ($AzureVMIP) from the on-prem VM ($OnPremVMIP)"
Write-Host
