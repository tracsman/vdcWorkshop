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
$ERCircuit2Name = $ResourceGroup + "-SEA-er"
$GlobalReachP2P = "192.168." + $CompanyID ".224/29"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 1, estimated total time 5 minutes" -ForegroundColor Cyan

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

# Get Circuit Info
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Pulling circuit information' -ForegroundColor Cyan
Try {$ckt1 = Get-AzureRmExpressRouteCircuit -ResourceGroupName $rg.ResourceGroupName -Name $ERCircuit1Name -ErrorAction Stop | Out-Null
     $ckt2 = Get-AzureRmExpressRouteCircuit -ResourceGroupName $rg.ResourceGroupName -Name $ERCircuit2Name -ErrorAction Stop | Out-Null}
Catch {Write-Warning "One or both circuits weren't found, please ensure step one is successful before running this script."
       Return}

# Ensure both circuits are provisioned and ready to go
If ($ckt.provisioned -eq "Provisioned" -and $ckt.Provisioned -eq "Provisioned") {
    Add-AzureRmExpressRouteCircuitConnectionConfig -Name 'SEAtoASH' -ExpressRouteCircuit $ckt1 -PeerExpressRouteCircuitPeering $ckt2.Peerings[0].Id -AddressPrefix $GlobalReachP2P
}
Else {Write-Warning "One or both circuits aren't in the provisioned state. Please ensure your proctor has provisioned both circuits before running this script."
      Return
}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 2 completed successfully" -ForegroundColor Green
Write-Host "Please proceed with the step 2 validation"
Write-Host
