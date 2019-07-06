#
# Virtual Data Center Workshop
# Ignite 2018 - PRE24
#
# Use your student credentials to login (StudentNNN@azlab.xyz)
#
# Step 1 Create a VNet (Hub01-VNet01)
# Step 2 Create an ExpressRoute circuit (incl provisioning)
# Step 3 Create an ExpressRoute Gateway and VNet connection
# Step 4 Create a VM on the VNet
# Step 5 Create Spoke (Spoke01-VNet01): Enable VNet Peering to hub, deploy load balancer, VMSS, build file server
# Step 6 Create Spoke (Spoke02-VNet01): Enable VNet Peering to hub, deploy load balancer, App Gateway, build IIS farm
# Step 7 In Hub, deploy load balancer, NVA Firewall, NSGs, and UDR, build firewall
# Step 8 Create Remote VNet (Remote-VNet01) connected back to ER

# Step 2
# Create an ExpressRoute circuit (incl provisioning)
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
$RGName = "Company" + $CompanyID
$ShortRegion = "eastus"
$ERCircuitName = $RGName + "-er"
$ERCircuitLocation = 'Washington DC'

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 2, estimated total time 4 minutes" -ForegroundColor Cyan

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

# Create ExpressRoute Circuit
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Creating ExpressRoute Circuit' -ForegroundColor Cyan
Try {$circuit = Get-AzExpressRouteCircuit -ResourceGroupName $RGName -Name $ERCircuitName -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {$circuit = New-AzExpressRouteCircuit -ResourceGroupName $RGName -Name $ERCircuitName -Location $ShortRegion `
                                            -ServiceProviderName Equinix -PeeringLocation $ERCircuitLocation `
                                            -BandwidthInMbps 50 -SkuFamily MeteredData -SkuTier Premium
}

# Set a new alias to access the clipboard, and copy the ER service key to the clipboard
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Copying Service Key to Clipboard' -ForegroundColor Cyan
New-Alias Out-Clipboard $env:SystemRoot\System32\Clip.exe -ErrorAction SilentlyContinue
$circuit.ServiceKey | Out-Clipboard

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 2 completed successfully" -ForegroundColor Green
Write-Host "Navigate to http://aka.ms/WorkshopSP to get your ExpressRoute circuit provisioned by the Service Provider."
Write-Host
