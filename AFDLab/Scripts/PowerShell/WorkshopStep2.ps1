#
# Azure Front Door / Global Reach Workshop
# Microsoft READY 2019 - Azure Networking Pre-day
#
# Use your corporate credentials to login (your @microsoft.com account) to Azure
#
#
# Step 1 Create two ExpressRoute Circuits, one in Seattle, one in Washington, DC
# Step 2 Establish ExpressRoute Global Peering between the two circuits
# Step 3 Create two VNets each with an ER Gateway, Public IP, and IIS server running a simple web site
# Step 4 Create an Azure Front Door to geo-load balance across the two sites
#

# Step 2
# Establish ExpressRoute Global Peering between the two circuits
# Description: In this script we will peer the two circuits created to allow on-prem to on-prem communication

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
$SubID = 'e4a176ec-f695-407c-8eeb-185fb94076b8'
$ResourceGroup = "Company" + $CompanyID.PadLeft(2,"0")
$ERCircuitNameASH = $ResourceGroup + "-ASH-er"
$ERCircuitNameSEA = $ResourceGroup + "-SEA-er"
$ASNASH = "65021"
$ASNSEA = "65020"
$VLANTag = "20" + $CompanyID.PadLeft(2,"0")
$ERPvtPrimaryASH = "192.168." + $CompanyID + ".208/30"
$ERPvtSecondaryASH = "192.168." + $CompanyID + ".212/30"
$ERPvtPrimarySEA = "192.168." + $CompanyID + ".216/30"
$ERPvtSecondarySEA = "192.168." + $CompanyID + ".220/30"
$GlobalReachP2P = "192.168." + $CompanyID + ".224/29"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 2, estimated total time 10 minutes" -ForegroundColor Cyan

# Login and permissions check
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Checking login and permissions" -ForegroundColor Cyan
Try {$rg = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction Stop}
Catch {# Login and set subscription for ARM
        Write-Host "Logging in to ARM"
        Try {$Sub = (Set-AzContext -Subscription $subID -ErrorAction Stop).Subscription}
        Catch {Connect-AzAccount | Out-Null
                $Sub = (Set-AzContext -Subscription $subID -ErrorAction Stop).Subscription}
        Write-Host "Current Sub:",$Sub.Name,"(",$Sub.Id,")"
        Try {$rg = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction Stop}
        Catch {Write-Warning "Permission check failed, ensure company id is set correctly!"
               Return}
}

# Get Circuit Info
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Pulling circuit information' -ForegroundColor Cyan
Try {$cktASH = Get-AzExpressRouteCircuit -ResourceGroupName $rg.ResourceGroupName -Name $ERCircuitNameASH -ErrorAction Stop | Out-Null
     $cktSEA = Get-AzExpressRouteCircuit -ResourceGroupName $rg.ResourceGroupName -Name $ERCircuitNameSEA -ErrorAction Stop | Out-Null}
Catch {Write-Warning "One or both circuits weren't found, please ensure step one is successful before running this script."
       Return}

# Ensure both circuits are provisioned and ready to go, then start Private Peering session
If ($cktASH.ServiceProviderProvisioningState -eq "Provisioned" -and $cktSEA.ServiceProviderProvisioningState -eq "Provisioned") {
    Write-Host (Get-Date)' - ' -NoNewline
    Write-Host 'Creating ASH Private Peering' -ForegroundColor Cyan
    Try {Get-AzExpressRouteCircuitPeeringConfig -Name AzurePrivatePeering -ExpressRouteCircuit $cktASH -ErrorAction Stop | Out-Null
         Write-Host '  resource exists, skipping'}
    Catch {Add-AzExpressRouteCircuitPeeringConfig -Name AzurePrivatePeering -ExpressRouteCircuit $cktASH `
                                                       -PrimaryPeerAddressPrefix $ERPvtPrimaryASH -SecondaryPeerAddressPrefix $ERPvtSecondaryASH `
                                                       -PeeringType AzurePrivatePeering -PeerASN $ASNASH -VlanId $VLANTag}
    Try {Set-AzExpressRouteCircuit -ExpressRouteCircuit $cktASH -ErrorAction Stop | Out-Null}
    Catch {Write-Warning '  saving the changes to the Ashburn circuit failed. Use the Azure Portal to manually verify and correct.'}

    Write-Host (Get-Date)' - ' -NoNewline
    Write-Host 'Creating SEA Private Peering' -ForegroundColor Cyan
    Try {Get-AzExpressRouteCircuitPeeringConfig -Name AzurePrivatePeering -ExpressRouteCircuit $cktSEA -ErrorAction Stop | Out-Null
         Write-Host '  resource exists, skipping'}
    Catch {Add-AzExpressRouteCircuitPeeringConfig -Name AzurePrivatePeering -ExpressRouteCircuit $cktSEA `
                                                       -PrimaryPeerAddressPrefix $ERPvtPrimarySEA -SecondaryPeerAddressPrefix $ERPvtSecondarySEA `
                                                       -PeeringType AzurePrivatePeering -PeerASN $ASNSEA -VlanId $VLANTag}
    Try {Set-AzExpressRouteCircuit -ExpressRouteCircuit $cktSEA -ErrorAction Stop | Out-Null}
    Catch {Write-Warning '  saving the changes to the Seattle circuit failed. Use the Azure Portal to manually verify and correct.'}
}
Else {Write-Warning "One or both circuits aren't in the provisioned state. Please ensure your proctor has provisioned both circuits before running this script."
      Return
}

# Ensure Private Peering is enabled, then enbale Global Reach
Try {Get-AzExpressRouteCircuitPeeringConfig -ExpressRouteCircuit $cktASH -Name AzurePrivatePeering -ErrorAction Stop | Out-Null
     Get-AzExpressRouteCircuitPeeringConfig -ExpressRouteCircuit $cktSEA -Name AzurePrivatePeering -ErrorAction Stop | Out-Null}
Catch {Write-Warning "Private Peering isn't enabled on one or both circuits. Please ensure private peering is enable successfully."
       Return}
Finally {Add-AzExpressRouteCircuitConnectionConfig -Name 'ASHtoSEA' -ExpressRouteCircuit $cktASH -PeerExpressRouteCircuitPeering $cktSEA.Peerings[0].Id -AddressPrefix $GlobalReachP2P}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 2 completed successfully" -ForegroundColor Green
Write-Host "Please proceed with the step 2 validation"
Write-Host
