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

# Step 1
# Create a VNet (Hub01-VNet01)
# Description: In this script we will create a VNet in your resource group and add two additional subnets

# Notes:
# IP Octects follow this standard:
#   First octet is 10 for private IP address space
#   Second octet for this workshop represents location; 10 = East US, 40 = West Europe
#   Third octet is based on the Company number formatted like 1xx where xx is the CompanyID padded with a leading zero (if needed)
#   e.g. Address space for Company 1 in East US would be 10.10.101.0/25

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
$SubID = 'e4a176ec-f695-407c-8eeb-185fb94076b8'
$ResourceGroup = "Company" + $CompanyID.PadLeft(2,"0")
$VNetName = "Hub01-VNet01"
$IPSecondOctet = "10" # 10 is for East US
$IPThirdOctet = "1" + $CompanyID.PadLeft(2,"0")
$AddressSpace  = "10.$IPSecondOctet.$IPThirdOctet.0/25"
$TenantSpace   = "10.$IPSecondOctet.$IPThirdOctet.0/28"
$FirewallSpace = "10.$IPSecondOctet.$IPThirdOctet.16/28"
$GatewaySpace  = "10.$IPSecondOctet.$IPThirdOctet.96/27"

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

# Create Virtual Network
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Virtual Network" -ForegroundColor Cyan
Try {$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $rg.ResourceGroupName -Name $VNetName -ErrorAction Stop
        Write-Host "  resource exists, skipping"}
Catch {$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $rg.ResourceGroupName -Name $VNetName -AddressPrefix $AddressSpace -Location $rg.Location  -WarningAction SilentlyContinue
        # Add Subnets
        Write-Host (Get-Date)' - ' -NoNewline
        Write-Host "Adding subnets" -ForegroundColor Cyan
        Add-AzureRmVirtualNetworkSubnetConfig -Name "Tenant" -VirtualNetwork $vnet -AddressPrefix $TenantSpace | Out-Null
        Add-AzureRmVirtualNetworkSubnetConfig -Name "Firewall" -VirtualNetwork $vnet -AddressPrefix $FirewallSpace | Out-Null
        Add-AzureRmVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet -AddressPrefix $GatewaySpace | Out-Null
        Set-AzureRmVirtualNetwork -VirtualNetwork $vnet | Out-Null
}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 1 completed successfully" -ForegroundColor Green
Write-Host
