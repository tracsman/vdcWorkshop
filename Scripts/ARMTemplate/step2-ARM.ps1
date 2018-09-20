# Use your student credentials to login
# Visual Studio Workshop
# Step 1 Create a VNet
# Step 2 Create an ExpressRoute (incl provisioning)
# Step 3 Create an ExpressRoute Gateway and VNet connection
# Step 4 Create a VM on the VNet (ie NIC and accelerated networking, container is a stretch goal)
# Step 5 Enable VNet Peering, hub and spoke, SLB
# Step 6 Deploye App Gateway, Public IPs
# Step 7 Deploy NVA, Firewall, NSGs, and UDR
# Step 8 Create Remote VNet connected back to ER

# Step 2
# Create an ExpressRoute circuit
# Description: In this script we will create an ExpressRoute circuit in your resource group

# Load Initialization Variables
Get-Content init.txt | Foreach-Object{
   $var = $_.Split('=')
   New-Variable -Name $var[0] -Value $var[1] -Force -ErrorAction Continue 
}


# Non-configurable Variable Initialization (ie don't modify these)
$SubID             = 'e4a176ec-f695-407c-8eeb-185fb94076b8'
$ResourceGroup     = "Company" + $CompanyID.PadLeft(2,"0")
$armTemplateFile   = "step2.json"
$Templateparameters= @{ CompanyID = $CompanyID}
$pathFiles         = Split-Path -Parent $PSCommandPath
$templateFile      = "$pathFiles\$armTemplateFile"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 1, estimated total time less than 1 minute" -ForegroundColor Cyan

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

# Create ExpressRoute Circuit
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Creating ExpressRoute Circuit' -ForegroundColor Cyan

New-AzureRmResourceGroupDeployment  -Name "step1" `
                            -ResourceGroupName $ResourceGroup `
                            -TemplateFile $templateFile -TemplateParameterObject $Templateparameters

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 2 completed successfully" -ForegroundColor Green
Write-Host "Navigate to http://aka.ms/WorkshopSP to get your ExpressRoute circuit provisioned by the Service Provider."
Write-Host