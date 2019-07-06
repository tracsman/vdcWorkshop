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
$VNetName = "Hub01-VNet01"
$VMName = "Hub01-VM01"
$VMUserName = "User01"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 4, estimated total time 10 minutes" -ForegroundColor Cyan

# Login and permissions check
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Checking login and permissions" -ForegroundColor Cyan
Try {Get-AzResourceGroup -Name $RGName -ErrorAction Stop | Out-Null}
Catch {# Login and set subscription for ARM
        Write-Host "Logging in to ARM"
        Try {$Sub = (Set-AzContext -Subscription $subID -ErrorAction Stop).Subscription}
        Catch {Connect-AzAccount | Out-Null
                $Sub = (Set-AzContext -Subscription $subID -ErrorAction Stop).Subscription}
        Write-Host "Current Sub:",$Sub.Name,"(",$Sub.Id,")"
        Try {Get-AzResourceGroup -Name $RGName -ErrorAction Stop | Out-Null}
        Catch {Write-Warning "Permission check failed, ensure company id is set correctly!"
               Return}
}

# 1. Create an inbound network security group rule for port 3389
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating NSG and RDP rule" -ForegroundColor Cyan
Try {$nsg = Get-AzNetworkSecurityGroup -Name $VMName"-nic-nsg" -ResourceGroupName $RGName -ErrorAction Stop
        Write-Host "  resource exists, skipping"}
Catch {
       # Create a network security group rule
       $nsgRuleRDP = New-AzNetworkSecurityRuleConfig -Name myNSGRuleRDP -Protocol Tcp -Direction Inbound `
                                                          -Priority 1000 -SourceAddressPrefix * -SourcePortRange * `
                                                          -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
       # Create a network security group
       $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $RGName -Location $ShortRegion -Name $VMName"-nic-nsg" -SecurityRules $nsgRuleRDP
}

# 2. Create a public IP address
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Public IP address" -ForegroundColor Cyan
Try {$pip = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $VMName'-nic-pip' -ErrorAction Stop
        Write-Host "  resource exists, skipping"}
Catch {$pip = New-AzPublicIpAddress -ResourceGroupName $RGName -Location $ShortRegion -AllocationMethod Dynamic -Name $VMName'-nic-pip'}

# 3. Create a virtual network card and associate with public IP address and NSG
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating NIC" -ForegroundColor Cyan
Try {$nic = Get-AzNetworkInterface -Name $VMName'-nic' -ResourceGroupName $RGName -ErrorAction Stop
        Write-Host "  resource exists, skipping"}
Catch {$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName
       $nic = New-AzNetworkInterface -Name $VMName'-nic' -ResourceGroupName $RGName -Location $ShortRegion `
                                          -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id -ErrorAction Stop}
# 4. Get secrets from KeyVault
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Obtaining secrets from Key Vault" -ForegroundColor Cyan
$kvName = $RGName + '-kv'
$kvs = Get-AzKeyVaultSecret -VaultName $kvName -Name $VMUserName -ErrorAction Stop
$cred = New-Object System.Management.Automation.PSCredential ($kvs.Name, $kvs.SecretValue) -ErrorAction Stop

# 5. Create a virtual machine configuration
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating VM" -ForegroundColor Cyan
$vmConfig = New-AzVMConfig -VMName $VMName -VMSize Standard_A4_v2 -ErrorAction Stop| `
        Set-AzVMOperatingSystem -Windows -ComputerName $VMName -Credential $cred -EnableAutoUpdate -ProvisionVMAgent | `
        Set-AzVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer `
        -Skus 2019-Datacenter -Version latest | Add-AzVMNetworkInterface -Id $nic.Id | Set-AzVMBootDiagnostic -Disable

# 6. Create the VM
Try {Get-AzVM -ResourceGroupName $RGName -Name $VMName -ErrorAction Stop | Out-Null
     Write-Host "  resource exists, skipping"}
Catch {New-AzVM -ResourceGroupName $RGName -Location $ShortRegion -VM $vmConfig -ErrorAction Stop | Out-Null}

# 7. Post installation config
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Running post-deployment script on VM" -ForegroundColor Cyan
Try {Get-AzVMExtension -Name AllowICMP -ResourceGroupName $RGName -VMName $VMName -ErrorAction Stop
     Write-Host "Extension already deployed, skipping"}
Catch {
    $ScriptStorageAccount = "vdcworkshop"
    $ScriptName = "AllowICMPv4.ps1"
    $ExtensionName = 'AllowICMP'
    $timestamp = (Get-Date).Ticks

    $ScriptLocation = "https://$ScriptStorageAccount.blob.core.windows.net/scripts/" + $ScriptName
    $ScriptExe = ".\$ScriptName"
 
    $PublicConfiguration = @{"fileUris" = [Object[]]"$ScriptLocation";"timestamp" = "$timestamp";"commandToExecute" = "powershell.exe -ExecutionPolicy Unrestricted -Command $ScriptExe"}
 
    Set-AzVMExtension -ResourceGroupName $RGName -VMName $VMName -Location $ShortRegion `
    -Name $ExtensionName -Publisher 'Microsoft.Compute' -ExtensionType 'CustomScriptExtension' -TypeHandlerVersion '1.9' `
    -Settings $PublicConfiguration -ErrorAction Stop | Out-Null
}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 4 completed successfully" -ForegroundColor Green
Write-Host
