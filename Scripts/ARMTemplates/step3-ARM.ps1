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

# Step 3
# Create an ExpressRoute Gateway and VNet connection
# Description: In this script we will create an ExpressRoute gateway in your VNet (from Step 1) and connect to the ExpressRoute circuit (from Step 2)
# Detailed Steps
# 1. Create the ExpressRoute Gateway
# 2. Ensure the circuit has been provisioned
# 3. Enable Private Peering on the circuit
# 4. Create the connection object connecting the Gateway and the Circuit 

# Notes:
# P2P are 192.168.1xx.0/29 where xx is Company ID
# VLAN Tag is lab standard of third octet plus a trailing zero
# e.g. Company 1 would be 3rd octet 101, and VLAN 1010


# Load Initialization Variables
If (Test-Path -Path .\init.txt) {
    Get-Content init.txt | Foreach-Object{
    $var = $_.Split('=')
    New-Variable -Name $var[0] -Value $var[1]
    }
}
Else {$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
      Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present."
      Return
}

# Non-configurable Variable Initialization (ie don't modify these)
$SubID             = 'e4a176ec-f695-407c-8eeb-185fb94076b8'
$ResourceGroup     = "Company" + $CompanyID.PadLeft(2,"0")
$armTemplateFile   = "step3.json"
$Templateparameters= @{ CompanyID = $CompanyID}
$pathFiles         = Split-Path -Parent $PSCommandPath
$templateFile      = "$pathFiles\$armTemplateFile"


# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 3, estimated total time 20 minutes" -ForegroundColor Cyan

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

# 1. Create the ExpressRoute Gateway
Write-Host 'Creating Gateway' -ForegroundColor Cyan
New-AzureRmResourceGroupDeployment  -Name "step3" `
                            -ResourceGroupName $ResourceGroup `
                            -TemplateFile $templateFile -TemplateParameterObject $Templateparameters

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 3 completed successfully" -ForegroundColor Green
Write-Host
