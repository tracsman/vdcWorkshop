# Use your student credentials to login
# Visual Studio Workshop
# Step 1 Create a VNet
# Step 2 Create an ExpressRoute (incl provisioning)
# Step 3 Create an ExpressRoute Gateway and VNet connection
# Step 4 Create a VM on the VNet (ie NIC and accelerated networking, container is a stretch goal)
# Step 5 Enable VNet Peering, hub and spoke, SLB, and VMSS
# Step 6 Deploy App Gateway, Public IPs
# Step 7 Deploy NVA, Firewall, NSGs, and UDR in Hub vnet
# Step 8 Create Remote VNet connected back to ER

# Step 7 Deploy NVA, Firewall, NSGs, and UDR in Hub vnet
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

# Step 8
# Create Remote VNet connected back to ER
# Description: In this script we will create a new VNet in Erupoe with a VM connected to your ExpressRoute circuit in Washington, DC
# Detailed Steps:
#  1. Create Virtual Network
#  2. Create the ExpressRoute Gateway (AsJob)
#  3. Create an inbound NSG
#  4. Create a public IP
#  5. Create a NIC, associate the NSG and IP
#  6. Get secrets from KeyVault
#  7. Create a VM config
#  8. Create the VM (AsJob)
#  9. Wait for Gateway and VM jobs to complete
# 10. Post installation config
# 11. Create the connection object connecting the Gateway and the Circuit 

# Load Initialization Variables
Get-Content init.txt | Foreach-Object{
   $var = $_.Split('=')
   New-Variable -Name $var[0] -Value $var[1] -Force -ErrorAction Continue
}

# Non-configurable Variable Initialization (ie don't modify these)
$SubID             = 'e4a176ec-f695-407c-8eeb-185fb94076b8'
$ResourceGroup     = "Company" + $CompanyID.PadLeft(2,"0")
$armTemplateFile   = "step8.json"
$Templateparameters= @{ CompanyID = $CompanyID}
$pathFiles         = Split-Path -Parent $PSCommandPath
$templateFile      = "$pathFiles\$armTemplateFile"


# Non-configurable Variable Initialization (ie don't modify these)
$SubID = 'e4a176ec-f695-407c-8eeb-185fb94076b8'
$ResourceGroup = "Company" + $CompanyID.PadLeft(2,"0")
$VMUserName = "Company" + $CompanyID.PadLeft(2,"0") + "User"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 4, estimated total time 10 minutes" -ForegroundColor Cyan

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


# 1. Get secrets from KeyVault
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Obtaining secrets from Key Vault" -ForegroundColor Cyan
$VMUserName = "Company" + $CompanyID.PadLeft(2,"0") + "User"
$kvName = $rg.ResourceGroupName + '-kv'
$kvs = Get-AzureKeyVaultSecret -VaultName $kvName -Name $VMUserName -ErrorAction Stop
$cred = $kvs.SecretValue

# Add the secret value to the Hash table
$Templateparameters.Add('VMPassword',$cred);
foreach ($i in $Templateparameters.GetEnumerator()) {
    write-host -foregrou Cyan "keys: "$i.Key "| values: "$i.Value 
}

##
## 1. Create Spoke VNet
## 2. Enable VNet Peering to the hub, with remote gateway
## 3. Create AppGateway
## 4. Loop: Create VMs
## 5. Do post deploy build

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating:"  -ForegroundColor Cyan
Write-Host "   Spoke Virtual Network, Peering Hub to Spoke, Peering Spoke to Hub, App Gateway, VMs in spoke VNet" -ForegroundColor Cyan
New-AzureRmResourceGroupDeployment  -Name "step7" `
                            -ResourceGroupName $ResourceGroup `
                            -TemplateFile $templateFile -TemplateParameterObject $Templateparameters

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 7 completed successfully" -ForegroundColor Green
Write-Host