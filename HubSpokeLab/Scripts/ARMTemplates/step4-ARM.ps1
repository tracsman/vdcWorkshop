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

# Step 4
# Create a VM on the VNet
# Description: In this script we will create a VM on your ExpressRoute enabled VNet
# Detailed Steps:
# 1. Create an inbound NSG
# 2. Create a public IP
# 3. Create a NIC, associate the NSG and IP
# 4. Get secrets from KeyVault
# 5. Create a VM config
# 6. Create the VM
# 7. Post installation config

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
$armTemplateFile   = "step4.json"
$Templateparameters= @{ CompanyID = $CompanyID}
$pathFiles         = Split-Path -Parent $PSCommandPath
$templateFile      = "$pathFiles\$armTemplateFile"


# Non-configurable Variable Initialization (ie don't modify these)
$SubID = 'e4a176ec-f695-407c-8eeb-185fb94076b8'
$ResourceGroup = "Company" + $CompanyID.PadLeft(2,"0")
$VNetName = "Hub01-VNet01"
$VMName = "Hub01-VM01"
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
write-host -foregrou Cyan "keys:"$Templateparameters.Keys 
write-host -foregrou Cyan "values:"$Templateparameters.Values


# 2. Create an inbound network security group rule for port 3389
# 3. Create a public IP address
# 4. Create a virtual network card and associate with public IP address and NSG
# 5. Create the VM
# 6. Post-deploy installation tools and kick-off iPerf if requested
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating NSG, public IP, NIC, VM, post installation tool" -ForegroundColor Cyan
New-AzureRmResourceGroupDeployment  -Name "step4" `
                            -ResourceGroupName $ResourceGroup `
                            -TemplateFile $templateFile -TemplateParameterObject $Templateparameters

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 4 completed successfully" -ForegroundColor Green
Write-Host