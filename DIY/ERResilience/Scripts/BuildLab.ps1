#
# DIY Basic Network Environment
#
# Azure Environment Deployment
# 1. Validate and Initialize
# 2. Create Resource Group
# 3. Create Key Vault and Secret
# 4. Create VNet and subnets
# 5. Create NVAs (AsJob)
#     5.1 Create Public IP
#     5.2 Create NIC
#     5.3 Build VM
#

# 1. Validate and Initialize
# Setup and Start Logging
$LogDir = "$env:HOME/Scripts/Logs"
If (-Not (Test-Path -Path $LogDir)) {New-Item $LogDir -ItemType Directory | Out-Null}
Start-Transcript -Path "$LogDir/BuildLab.log"

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
# Non-configurable Variable Initialization (ie don't modify these)
$VNetName = "VNet"
$VNetSpace = "10.10.0.0/16"
  $sn1Name   = "Network01"
  $sn2Name   = "Network02"
  $sn3Name   = "Network03"
  $sn1Space  = "10.10.1.0/24"
  $sn2Space  = "10.10.2.0/24"
  $sn3Space  = "10.10.3.0/24"

$VMPrefix  = "Router"
$VMSize    = "Standard_B2s"
$UserName  = "LabUser"
# RegEx for a valid password pattern
$RegEx='^(?=\P{Ll}*\p{Ll})(?=\P{Lu}*\p{Lu})(?=\P{N}*\p{N})(?=[\p{L}\p{N}]*[^\p{L}\p{N}])[\s\S]{12,}$'
# Loop until a good (pattern match) password is found
Do {$clearPassword = ([char[]](Get-Random -Input $(40..44 + 46..59 + 63..91 + 97..122) -Count 20)) -join ""}
While ($clearPassword -cnotmatch $RegEx)
$secPassword = ConvertTo-SecureString $clearPassword -AsPlainText -Force
$clearPassword = $null

# Start nicely
Write-Host
Write-Host (Get-Date)'- ' -NoNewline
Write-Host "Starting deplyment, estimated total time 10 minutes" -ForegroundColor Cyan

# Set Subscription and Login
Write-Host (Get-Date)'- ' -NoNewline
Write-Host "Setting Subscription Context" -ForegroundColor Cyan
Try {$myContext = Set-AzContext -Subscription $SubID -ErrorAction Stop}
Catch {Write-Warning "Permission check failed, ensure Sub ID is set correctly!"
       Return}
Write-Host "  Current Sub:",$myContext.Subscription.Name,"(",$myContext.Subscription.Id,")"

Write-Host (Get-Date)'- ' -NoNewline
Write-Host "Checking Login" -ForegroundColor Cyan
$RegEx = '^([\w-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([\w-]+\.)+))([a-zA-Z]{2,5}|[0-9]{1,3})(\]?)$'
If ($myContext.Account.Id -notmatch $RegEx) {
    Write-Host "Fatal Error: You are logged in with a Managed Service bearer token" -ForegroundColor Red
    Write-Host "To correct this, you'll need to login using your Azure credentials."
    Write-Host "To do this, at the command prompt, enter: " -NoNewline
    Write-Host "Connect-AzAccount -UseDeviceAuthentication" -ForegroundColor Yellow
    Write-Host "This command will show a URL and Code. Open a new browser tab and navigate to that URL, enter the code, and login with your Azure credentials"
    Write-Host
    Write-Host "Script Ending, BuildLab.ps1, Failure Code 1"
    Exit 1
}
Write-Host "  Current User: ",$myContext.Account.Id

# 2. Create Resource Group
Write-Host (Get-Date)'- ' -NoNewline
Write-Host "Creating Resource Group $RGName" -ForegroundColor Cyan
Try {Get-AzResourceGroup -Name $RGName -ErrorAction Stop | Out-Null
        Write-Host "  Resource group exists, skipping"}
Catch {New-AzResourceGroup -Name $RGName -Location $ShortRegion | Out-Null}

# 3. Create Key Vault and Secret
Write-Host (Get-Date)'- ' -NoNewline
Write-Host "Creating Key Vault and Secret" -ForegroundColor Cyan

# Get/Create key vault name
# Check if there already is a key vault in this resource group and get the name, if not make up a KV name
$kvName = $null
$kv = $null
$kvName = (Get-AzKeyVault -ResourceGroupName $RGName | Select-Object -First 1).VaultName

# If found, ensure this Key Vault isn't in removed state
if ($null -ne $kvName) {$kv = Get-AzKeyVault -VaultName $kvName -Location $ShortRegion -InRemovedState}
If ($null -eq $kvName -or $null -ne $kv) {
   Do {$kvRandom = Get-Random
       $kvName = 'KeyVault-' + $kvRandom
       $kv = Get-AzKeyVault -VaultName $kvName -Location $ShortRegion -InRemovedState}
   While ($null -ne $kv)
}

# Get the key vault, create if it doesn't exist
# Check if there already is a key vault in this resource group and get the name, if not make up a KV name
$kvName = $null
$kv = $null
$kvName = (Get-AzKeyVault -ResourceGroupName $RGName | Select-Object -First 1).VaultName

# If found, ensure this Key Vault isn't in removed state
if ($null -ne $kvName) {$kv = Get-AzKeyVault -VaultName $kvName -Location $ShortRegion -InRemovedState}
If ($null -eq $kvName -or $null -ne $kv) {
   Do {$kvRandom = Get-Random
       $kvName = $RGName + '-kv' + "-$kvRandom"
       $kv = Get-AzKeyVault -VaultName $kvName -Location $ShortRegion -InRemovedState}
   While ($null -ne $kv)
}

$kv = Get-AzKeyVault -VaultName $kvName -ResourceGroupName $RGName
If ($null -eq $kv) {$kv = New-AzKeyVault -VaultName $kvName -ResourceGroupName $RGName -Location $ShortRegion
                    Start-Sleep -Seconds 10}
Else {Write-Host "  Key Vault exists, skipping"}

# Set Key Vault Access Policy
Write-Host "  Setting Key Vault Access Policy"
$UserID = (Get-AzAdUser -UserPrincipalName $myContext.Account.Id).Id
If ($kv.AccessPolicies.ObjectId -contains $UserID) {
    Write-Host "    Policy exists, skipping"
} Else {
    Set-AzKeyVaultAccessPolicy -VaultName $kvName -ResourceGroupName $RGName -ObjectId $UserID -PermissionsToSecrets get,list,set,delete 
    Write-Host "    Policy added"
}

# Create Secret
$kvs = Get-AzKeyVaultSecret -VaultName $kvName -Name $UserName -ErrorAction Stop 
If ($null -eq $kvs) {Try {$kvs = Set-AzKeyVaultSecret -VaultName $kvName -Name $UserName -SecretValue $secPassword -ErrorAction Stop}
                    Catch {Write-host "Vault not found, waiting 10 seconds and trying again."
                            Start-Sleep -Seconds 10
                            $kvs = Set-AzKeyVaultSecret -VaultName $kvName -Name $UserName -SecretValue $secPassword -ErrorAction Stop}}
Else {Write-Host "  $UserName exists, skipping"}

# 4. Create VNet and subnets
Write-Host (Get-Date)'- ' -NoNewline
Write-Host "Creating Virtual Network" -ForegroundColor Cyan

# Create an inbound network security group rule for the admin port
Write-Host '  creating NSG and Admin rule'
Try {$nsg = Get-AzNetworkSecurityGroup -Name $VNetName'-nsg' -ResourceGroupName $RGName -ErrorAction Stop
     Write-Host '    NSG exists, skipping'}
Catch {$nsgRule1 = New-AzNetworkSecurityRuleConfig -Name AllowSSH -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
       $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $RGName -Location $ShortRegion -Name $VNetName'-nsg' -SecurityRules $nsgRule1}
        
Try {$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
     Write-Host "  VNet exists, skipping"}
Catch {$vnet = New-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -AddressPrefix $VNetSpace -Location $ShortRegion
       Write-Host (Get-Date)' - ' -NoNewline
       Write-Host "  Adding subnets" -ForegroundColor Cyan
       Add-AzVirtualNetworkSubnetConfig -Name $sn1Name -VirtualNetwork $vnet -AddressPrefix $sn1Space -NetworkSecurityGroup $nsg | Out-Null
       Add-AzVirtualNetworkSubnetConfig -Name $sn2Name -VirtualNetwork $vnet -AddressPrefix $sn2Space -NetworkSecurityGroup $nsg | Out-Null
       Add-AzVirtualNetworkSubnetConfig -Name $sn3Name -VirtualNetwork $vnet -AddressPrefix $sn3Space -NetworkSecurityGroup $nsg | Out-Null
       Set-AzVirtualNetwork -VirtualNetwork $vnet | Out-Null}
$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
$sn1 = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "Network01"
$sn2 = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "Network02"
$sn3 = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "Network03"

# 5. Create VNet NVAs
# Accept Marketplace Terms for the NVA
##  To install a marketplace image you need to accept the vendor terms. This is done one time for each
##  vendor product type in the target Azure subscription and persists thereafter.
##  Note: Using marketplace images isn't an option for certain subscription. If this is the case, this
##        lab can not be performed.
$MPTermsAccepted = (Get-AzMarketplaceTerms -Publisher "cisco" -Product "cisco-csr-1000v" -Name "csr-azure-byol" -OfferType 'virtualmachine').Accepted
if (-Not $MPTermsAccepted) {Get-AzMarketplaceTerms -Publisher "cisco" -Product "cisco-csr-1000v" -Name "csr-azure-byol" -OfferType 'virtualmachine' | Set-AzMarketplaceTerms -Accept}
$MPTermsAccepted = (Get-AzMarketplaceTerms -Publisher "cisco" -Product "cisco-csr-1000v" -Name "csr-azure-byol" -OfferType 'virtualmachine').Accepted
if (-Not $MPTermsAccepted) {Write-Host "MarketPlace terms for the required image could not be accepted. This is required for this working." -ForegroundColor Red;Return}

# Loop through NVA Creation
For ($i=1; $i -le 2; $i++) {
    $VMName = $VMPrefix + $i.ToString("00")
    Write-Host (Get-Date)' - ' -NoNewline
    Write-Host "Creating $VMName" -ForegroundColor Cyan
    if ($i -eq 1) {$snMain = $sn1} else {$snMain = $sn3}

    # 5.1 Create Public IP
    Try {$pipNVA = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $VMName'-pip' -ErrorAction Stop
            Write-Host "  Public IP exists, skipping"}
    Catch {$pipNVA = New-AzPublicIpAddress -ResourceGroupName $RGName -Name $VMName'-pip' -Location $ShortRegion `
                                           -AllocationMethod Static -Sku Standard -IpAddressVersion IPv4}
    # 5.2 Create NICs
    Try {$nic1 = Get-AzNetworkInterface -ResourceGroupName $RGName -Name $VMName'-nic1' -ErrorAction Stop
            Write-Host "  NIC1 exists, skipping"}
    Catch {$nic1 = New-AzNetworkInterface -ResourceGroupName $RGName -Name $VMName'-nic1' -Location $ShortRegion `
                                          -Subnet $snMain -PublicIpAddress $pipNVA -EnableIPForwarding}
    Try {$nic2 = Get-AzNetworkInterface -ResourceGroupName $RGName -Name $VMName'-nic2' -ErrorAction Stop
            Write-Host "  NIC2 exists, skipping"}
    Catch {$nic2 = New-AzNetworkInterface -ResourceGroupName $RGName -Name $VMName'-nic2' -Location $ShortRegion `
                                          -Subnet $sn2 -EnableIPForwarding}
    # 5.3 Build NVA
    # Get-AzVMImage -Location westus2 -Offer cisco-csr-1000v -PublisherName cisco -Skus csr-azure-byol -Version latest
    Try {Get-AzVM -ResourceGroupName $RGName -Name $VMName -ErrorAction Stop | Out-Null
            Write-Host "  $VMName exists, skipping"}
    Catch {$kvs = Get-AzKeyVaultSecret -VaultName $KVName -Name $UserName -ErrorAction Stop
           $cred = New-Object System.Management.Automation.PSCredential ($kvs.Name, $kvs.SecretValue)
           $latestsku = Get-AzVMImageSku -Location $ShortRegion -Offer cisco-csr-1000v -PublisherName cisco | Sort-Object Skus | Where-Object {$_.skus -match 'byol'} | Select-Object Skus -First 1 | ForEach-Object {$_.Skus}
           $VMConfig = New-AzVMConfig -VMName $VMName -VMSize $VMSize
           Set-AzVMPlan -VM $VMConfig -Publisher "cisco" -Product "cisco-csr-1000v" -Name $latestsku | Out-Null
           $VMConfig = Set-AzVMOperatingSystem -VM $VMConfig -Linux -ComputerName $VMName -Credential $cred
           $VMConfig = Set-AzVMOSDisk -VM $VMConfig -CreateOption FromImage -Name $VMName'-disk-os' -Linux -StorageAccountType Premium_LRS -DiskSizeInGB 30
           $VMConfig = Set-AzVMSourceImage -VM $VMConfig -PublisherName "cisco" -Offer "cisco-csr-1000v" -Skus $latestsku -Version latest
           #$VMConfig = Add-AzVMSshPublicKey -VM $VMConfig -KeyData $PublicKey -Path "/home/User01/.ssh/authorized_keys"
           $VMConfig = Add-AzVMNetworkInterface -VM $VMConfig -Id $nic1.Id -Primary
           $VMConfig = Add-AzVMNetworkInterface -VM $VMConfig -id $nic2.Id
           $VMConfig = Set-AzVMBootDiagnostic -VM $VMConfig -Disable
           New-AzVM -ResourceGroupName $RGName -Location $ShortRegion -VM $VMConfig -AsJob | Out-Null
    }
}

# Wait for the jobs to complete
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Waiting for the NVAs to deploy, this script will continue after 10 minutes or when the VMs are built, whichever comes first." -ForegroundColor Cyan
Get-Job -Command "New-AzVM" | wait-job -Timeout 600 | Out-Null

# End Nicely
Write-Host (Get-Date)'- ' -NoNewline
Write-Host "Deployment completed successfully" -ForegroundColor Green
Write-Host
Write-Host "  All environment components are built, time to play!" -ForegroundColor Green
Write-Host
Write-Host

Stop-Transcript
