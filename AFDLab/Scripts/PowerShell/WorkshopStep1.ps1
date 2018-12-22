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

# Step 1
# Create two ExpressRoute Circuits, one in Seattle, one in Washington, DC (incl provisioning)
# Description: In this script we will create an ExpressRoute circuit in your resource group

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
$ERCircuit1Name = $ResourceGroup + "-ASH-er"
$ERCircuit1Location = 'Washington DC'
$ERCircuit2Name = $ResourceGroup + "-SEA-er"
$ERCircuit2Location = 'Seattle'

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 1, estimated total time 6 minutes" -ForegroundColor Cyan

# Login and permissions check
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Checking login and permissions" -ForegroundColor Cyan
Try {$rg = Get-AzureRmResourceGroup -Name $ResourceGroup -ErrorAction Stop}
Catch {# Login and set subscription for ARM
        Write-Host "Logging in to ARM"
        Try {$Sub = (Set-AzureRmContext -Subscription $subID -ErrorAction Stop).Subscription}
        Catch {Login-AzureRmAccount | Out-Null
                $Sub = (Set-AzureRmContext -Subscription $subID -ErrorAction Stop).Subscription}
        Write-Host "Current Sub:",$Sub.Name,"(",$Sub.Id,")"
        Try {$rg = Get-AzureRmResourceGroup -Name $ResourceGroup -ErrorAction Stop}
        Catch {Write-Warning "Permission check failed, ensure company id is set correctly!"
                Return}
}

# Create ExpressRoute Circuit 1
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Creating ExpressRoute Circuit in Washington DC' -ForegroundColor Cyan
Try {Get-AzureRmExpressRouteCircuit -ResourceGroupName $rg.ResourceGroupName -Name $ERCircuit1Name -ErrorAction Stop | Out-Null
        Write-Host '  resource exists, skipping'}
Catch {New-AzureRmExpressRouteCircuit -ResourceGroupName $rg.ResourceGroupName -Name $ERCircuit1Name -Location $rg.Location `
                                      -ServiceProviderName Equinix -PeeringLocation $ERCircuit1Location `
                                      -BandwidthInMbps 50 -SkuFamily MeteredData -SkuTier Standard | Out-Null
}

# Create ExpressRoute Circuit 2
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Creating ExpressRoute Circuit in Seattle' -ForegroundColor Cyan
Try {Get-AzureRmExpressRouteCircuit -ResourceGroupName $rg.ResourceGroupName -Name $ERCircuit2Name -ErrorAction Stop
        Write-Host '  resource exists, skipping'}
Catch {New-AzureRmExpressRouteCircuit -ResourceGroupName $rg.ResourceGroupName -Name $ERCircuit2Name -Location $rg.Location `
                                        -ServiceProviderName Equinix -PeeringLocation $ERCircuit2Location `
                                        -BandwidthInMbps 50 -SkuFamily MeteredData -SkuTier Standard | Out-Null
}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 1 completed successfully" -ForegroundColor Green
Write-Host "Wait for the proctor to notify you that your ExpressRoute circuits have been provisioned by the Service Provider before continuing."
Write-Host
