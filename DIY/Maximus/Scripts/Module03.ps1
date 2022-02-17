#
# DIY Azure Firewall Workshop
#
#
# Step 1 Create resource group, key vault, and secret
# Step 2 Create Virtual Network
# Step 3 Create an internet facing VM
# Step 4 Create and configure the Azure Firewall
# Step 5 Create Spoke VNet with IIS Server and a firewall rule to allow traffic
# 

# Step 3 Create an internet facing VM
# 3.1 Validate and Initialize
# 3.2 Create the VM
# 3.2.1 Create Public IP
# 3.2.2 Create NSG
# 3.2.3 Create NIC
# 3.2.4 Build VM
# 3.3 Run post deploy job

# 3.1 Validate and Initialize
# Load Initialization Variables
$ScriptDir = "$env:HOME/Scripts"
If (Test-Path -Path $ScriptDir/init.txt) {
        Get-Content $ScriptDir/init.txt | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}}}
Else {Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}

# Variable Initialization
# $SubID     = defined in and pulled from the init.txt file above
# $ShortRegion defined in and pulled from the init.txt file above
# $RGName    = defined in and pulled from the init.txt file above
$VNetName    = "Hub01-VNet01"
$VMName      = "Hub01-VM01"
$VMSize      = "Standard_A4_v2"
$UserName01  = "User01"
$UserName02  = "User02"
$UserName03  = "User03"
$kvName      = (Get-AzKeyVault -ResourceGroupName $RGName | Select-Object -First 1).VaultName

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 3, estimated total time 15 minutes" -ForegroundColor Cyan

# Set Subscription and Login
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Setting Subscription Context" -ForegroundColor Cyan
Try {$myContext = Set-AzContext -Subscription $SubID -ErrorAction Stop}
Catch {Write-Warning "Permission check failed, ensure Sub ID is set correctly!"
        Return}
Write-Host "  Current Sub:",$myContext.Subscription.Name,"(",$myContext.Subscription.Id,")"

# 3.2 Create
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating VM" -ForegroundColor Cyan
Write-Host "  Pulling KeyVault Secret"
$kvs01 = Get-AzKeyVaultSecret -VaultName $kvName -Name $UserName01 -ErrorAction Stop
$kvs02 = Get-AzKeyVaultSecret -VaultName $kvName -Name $UserName02 -ErrorAction Stop
$kvs03 = Get-AzKeyVaultSecret -VaultName $kvName -Name $UserName03 -ErrorAction Stop 
$cred = New-Object System.Management.Automation.PSCredential ($kvs01.Name, $kvs01.SecretValue)
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kvs02.SecretValue)
try {
    $kvs02 = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
} finally {
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
}
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kvs03.SecretValue)
try {
    $kvs03 = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
} finally {
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
}

# 3.2.1 Create Public IP
Write-Host "  Creating Public IP"
Try {$pip = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $VMName'-pip' -ErrorAction Stop
     Write-Host "    Public IP exists, skipping"}
Catch {$pip = New-AzPublicIpAddress -ResourceGroupName $RGName -Name $VMName'-pip' -Location $ShortRegion -AllocationMethod Dynamic}

# 3.2.2 Create NSG
Write-Host "  Creating NSG"
$nsgRuleRDP = New-AzNetworkSecurityRuleConfig -Name myNSGRuleRDP -Protocol Tcp -Direction Inbound -Priority 1000 `
              -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
Try {$nsg = Get-AzNetworkSecurityGroup -Name $VMName'-nic-nsg' -ResourceGroupName $RGName -ErrorAction Stop
Write-Host "    NSG exists, skipping"}
Catch {$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $RGName -Location $ShortRegion -Name $VMName'-nic-nsg' -SecurityRules $nsgRuleRDP}

# 3.2.3 Create NIC
Write-Host "  Creating NIC"
$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName
$sn =  Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "Tenant"
Try {$nic = Get-AzNetworkInterface -ResourceGroupName $RGName -Name $VMName'-nic' -ErrorAction Stop
     Write-Host "    NIC exists, skipping"}
Catch {$nic = New-AzNetworkInterface -ResourceGroupName $RGName -Name $VMName'-nic' -Location $ShortRegion -Subnet $sn -PublicIpAddress $pip -NetworkSecurityGroup $nsg}

# 3.2.4 Build VM
Write-Host "  Creating VM"
Try {Get-AzVM -ResourceGroupName $RGName -Name $VMName -ErrorAction Stop | Out-Null
          Write-Host "    VM exists, skipping"}
Catch {$vmConfig = New-AzVMConfig -VMName $VMName -VMSize $VMSize -ErrorAction Stop
       $vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $VMName -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
       $vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2019-Datacenter -Version latest
       $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id
       $vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Disable
       Write-Host "      queuing VM build job"
       New-AzVM -ResourceGroupName $RGName -Location $ShortRegion -VM $vmConfig -AsJob | Out-Null}

# 3.3 Run post deploy job
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
$ScriptExe = "(.\$ScriptName -User2 '$UserName02' -Pass2 '" + $kvs02 + "' -User3 '$UserName03' -Pass3 '" + $kvs03 + "')"
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
Write-Host "Step 3 completed successfully" -ForegroundColor Green
Write-Host "  Review your VM and it's components in the Azure Portal"
Write-Host "  RDP to your new Azure VM using the Public IP"
Write-Host "  The VM Public IP is " -NoNewline
Write-Host (Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $VMName'-pip').IpAddress -ForegroundColor Yellow
Write-Host
