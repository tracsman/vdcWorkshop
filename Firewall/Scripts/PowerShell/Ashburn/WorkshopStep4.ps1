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

# Step 4 Bring up ExpressRoute Private Peering
#  4.1 Validate and Initialize
#  4.2 Bring up ExpressRoute Private Peering

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
$RGName = "AComp" + $CompanyID
$CircuitName = $RGName + "-er"
$PrimaryPrefix = "192.168." + $CompanyID + ".216/30"
$SecondaryPrefix = "192.168." + $CompanyID + ".2220/30"
$ASN = "65021"
$VLANTag = "20" + $CompanyID

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 4, estimated total time 5 minutes" -ForegroundColor Cyan

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

#  4.2 Bring up ExpressRoute Private Peering
If ($ckt.ServiceProviderProvisioningState -eq "Provisioned") {
       Write-Host (Get-Date)' - ' -NoNewline
       Write-Host 'Bringing up Private Peering' -ForegroundColor Cyan
       Try {Get-AzExpressRouteCircuitPeeringConfig -Name AzurePrivatePeering -ExpressRouteCircuit $ckt -ErrorAction Stop | Out-Null
            Write-Host '  peering exists, skipping'}
       Catch {Add-AzExpressRouteCircuitPeeringConfig -Name AzurePrivatePeering -ExpressRouteCircuit $ckt `
                                                     -PrimaryPeerAddressPrefix $PrimaryPrefix -SecondaryPeerAddressPrefix $SecondaryPrefix `
                                                     -PeeringType AzurePrivatePeering -PeerASN $ASN -VlanId $VLANTag -ErrorAction Stop | Out-Null                                            
              Try {Set-AzExpressRouteCircuit -ExpressRouteCircuit $ckt -ErrorAction Stop | Out-Null}
              Catch {Write-Warning 'Saving the changes to the circuit failed. Use the Azure Portal to manually verify and correct.'
                     Return}                                                       
       }
    }
Else {Write-Warning "Your circuit isn't the provisioned state. Please ensure your proctor has provisioned the circuit before running this script."
      Return
      }

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 4 completed successfully" -ForegroundColor Green
Write-Host "  Checkout the Private Peering in the Azure portal."
Write-Host "  Be sure to check out the routing table and view your on-prem routes."
Write-Host
