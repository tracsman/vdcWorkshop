#
# Azure Firewall Workshop
#
# Use your corporate credentials to login (your @microsoft.com account) to Azure
#
#
# Step 1 Create Virtual Network
# Step 2 Create an internet facing VM
# Step 3 Create an ExpressRoute circuit and ER Gateway
# Step 4 Bring up ExpressRoute Private Peering
# Step 5 Create the connection between the ER Gateway and the ER Circuit
# Step 6 Create and configure the Azure Firewall
# Step 7 Create Spoke VNet with IIS Server and a firewall rule to allow traffic
# 

# Step 2 Create an internet facing VM
# 2.1 Validate and Initialize
# 2.2 Create the VM
# 2.2.1 Create Public IP
# 2.2.2 Create NSG
# 2.2.3 Create NIC
# 2.2.4 Build VM
# 2.3 Run post deploy job

# 2.1 Validate and Initialize
# Az Module Test
$ModCheck = Get-Module Az.Network -ListAvailable
If ($Null -eq $ModCheck) {
    Write-Warning "The Az PowerShell module was not found. This script uses the Az modules for PowerShell"
    Write-Warning "See the blog post for more information at: https://azure.microsoft.com/blog/how-to-migrate-from-azurerm-to-az-in-azure-powershell/"
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
$ShortRegion = "westus2"
$RGName = "Company" + $CompanyID
$VNetName = "C" + $CompanyID + "-VNet"
$VMName = "C" + $CompanyID + "-VM01"
$VMSize = "Standard_A4_v2"
$UserName01 = "User01"
$UserName02 = "User02"
$UserName03 = "User03"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 2, estimated total time 15 minutes" -ForegroundColor Cyan

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

# 2.2 Create the VM
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating VM" -ForegroundColor Cyan
Write-Host "  Pulling KeyVault Secret"
$kvs01 = Get-AzKeyVaultSecret -VaultName $RGName"-kv" -Name $UserName01 -ErrorAction Stop
$kvs02 = Get-AzKeyVaultSecret -VaultName $RGName"-kv" -Name $UserName02 -ErrorAction Stop 
$kvs03 = Get-AzKeyVaultSecret -VaultName $RGName"-kv" -Name $UserName03 -ErrorAction Stop 
$cred = New-Object System.Management.Automation.PSCredential ($kvs01.Name, $kvs01.SecretValue)

# 2.2.1 Create Public IP
Write-Host "  Creating Public IP"
Try {$pip = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $VMName'-pip' -ErrorAction Stop
     Write-Host "    Public IP exists, skipping"}
Catch {$pip = New-AzPublicIpAddress -ResourceGroupName $RGName -Name $VMName'-pip' -Location $ShortRegion -AllocationMethod Dynamic}

# 2.2.2 Create NSG
Write-Host "  Creating NSG"
$nsgRuleRDP = New-AzNetworkSecurityRuleConfig -Name myNSGRuleRDP -Protocol Tcp -Direction Inbound -Priority 1000 `
              -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
Try {$nsg = Get-AzNetworkSecurityGroup -Name $VMName'-nic-nsg' -ResourceGroupName $RGName -ErrorAction Stop
Write-Host "    NSG exists, skipping"}
Catch {$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $RGName -Location $ShortRegion -Name $VMName'-nic-nsg' -SecurityRules $nsgRuleRDP}

# 2.2.3 Create NIC
Write-Host "  Creating NIC"
$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName
$sn =  Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "Tenant"
Try {$nic = Get-AzNetworkInterface -ResourceGroupName $RGName -Name $VMName'-nic' -ErrorAction Stop
     Write-Host "    NIC exists, skipping"}
Catch {$nic = New-AzNetworkInterface -ResourceGroupName $RGName -Name $VMName'-nic' -Location $ShortRegion -Subnet $sn -PublicIpAddress $pip -NetworkSecurityGroup $nsg}

# 2.2.4 Build VM
Write-Host "  Creating VM"
Try {Get-AzVM -ResourceGroupName $RGName -Name $VMName -ErrorAction Stop | Out-Null
          Write-Host "    VM exists, skipping"}
Catch {$vmConfig = New-AzVMConfig -VMName $VMName -VMSize $VMSize -ErrorAction Stop
       $vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $VMName -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
       #$vmConfig = Set-AzVMOSDisk -VM $VMConfig -CreateOption FromImage -Name $VMName'-disk-os' -Windows -StorageAccountType Premium_LRS -DiskSizeInGB 30
       $vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2019-Datacenter -Version latest
       $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id
       $vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Disable
       Write-Host "      queuing VM build job"
       New-AzVM -ResourceGroupName $RGName -Location $ShortRegion -VM $vmConfig -AsJob | Out-Null}

# 2.3 Run post deploy job
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Waiting for the VM to deploy, this script will continue after 10 minutes or when the VM is built, whichever comes first." -ForegroundColor Cyan
Get-Job -Command "New-AzVM" | wait-job -Timeout 600 | Out-Null

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Running post VM deploy build script" -ForegroundColor Cyan
$ScriptStorageAccount = "vdcworkshop"
$ScriptName = "FirewallVMBuild.ps1"
$ExtensionName = 'FWBuildVM'
$timestamp = (Get-Date).Ticks
$ScriptLocation = "https://$ScriptStorageAccount.blob.core.windows.net/scripts/" + $ScriptName
$ScriptExe = "(.\$ScriptName -User2 '$UserName02' -Pass2 '" + $kvs02.SecretValueText + "' -User3 '$UserName03' -Pass3 '" + $kvs03.SecretValueText + "')"
$PublicConfiguration = @{"fileUris" = [Object[]]"$ScriptLocation";"timestamp" = "$timestamp";"commandToExecute" = "powershell.exe -ExecutionPolicy Unrestricted -Command $ScriptExe"}

Try {Get-AzVMExtension -ResourceGroupName $RGName -VMName $VMName -Name $ExtensionName -ErrorAction Stop | Out-Null
     Remove-AzVMExtension -ResourceGroupName $RGName -VMName $VMName -Name $ExtensionName -Force -ErrorAction Stop | Out-Null
     Write-Host "  extension found and removed."}
Catch {}

Try {Get-AzVMExtension -ResourceGroupName $RGName -VMName $VMName -Name $ExtensionName -ErrorAction Stop | Out-Null
     Write-Warning "Extension still exists, ending script"
     Return}
Catch {Write-Host "  queuing build job."
       Set-AzVMExtension -ResourceGroupName $RGName -VMName $VMName -Location $ShortRegion -Name $ExtensionName `
                         -Publisher 'Microsoft.Compute' -ExtensionType 'CustomScriptExtension' -TypeHandlerVersion '1.9' `
                         -Settings $PublicConfiguration -AsJob -ErrorAction Stop | Out-Null}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 2 completed successfully" -ForegroundColor Green
Write-Host "  Review your VM and it's components in the Azure Portal"
Write-Host "  RDP to your new Azure VM using the Public IP"
Write-Host "  The VM Public IP is " -NoNewline
Write-Host (Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $VMName'-pip').IpAddress -ForegroundColor Yellow
Write-Host
