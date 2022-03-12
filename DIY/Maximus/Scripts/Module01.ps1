#
# DIY Workshop Maximus
#
#
# Module 1 - Hub - Create resource group, key vault and secret, Hub VNet, VM, and deploy website
# Module 2 - Access - Create NSG, Public IP, IP Prefix, Bastion, VNet NAT
# Module 3 - Secure - Create Firewall, Firewall Policy, Log Analytics, UDR
# Module 4 - Web Tier - Create Spoke1 VNet, VNet Peering, 3xVM with Web Site, App Gateway
# Module 5 - Data Tier - Create Spoke2 VNet, Load Balancer, VMSS configured as a File Server
# 

# Module 1 - Hub
# 1.1 Validate and Initialize
# 1.2 Create resource group
# 1.3 Create key vault
# 1.4 Set Key Vault Access Policy
# 1.5 Create Secrets
# 1.6 Create VNet and subnets
# 1.6.1 Create Tenant Subnet NSG
# 1.7 Create the VM
# 1.7.1 Create NIC
# 1.7.2 Build VM
# 1.8 Run post deploy job
#

# 1.1 Validate and Initialize
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
$HubAddress  = "10.0.0.0/16"
$snTenant    = "10.0.1.0/24"
$snBastion   = "10.0.2.0/24"
$snFirewall  = "10.0.3.0/24"
$snGateway   = "10.0.4.0/24"
$snRtSvr     = "10.0.5.0/24"
$VNetName    = "Hub-VNet"
$VMName      = "Hub-VM01"
$VMSize      = "Standard_B2S"
$UserName01  = "User01"
$UserName02  = "User02"
$UserName03  = "User03"

# Define Password pattern match RegEx
$RegEx='^(?=\P{Ll}*\p{Ll})(?=\P{Lu}*\p{Lu})(?=\P{N}*\p{N})(?=[\p{L}\p{N}]*[^\p{L}\p{N}])[\s\S]{12,}$'

# Set VM User 1
$User01Name = "User01"
Do {$User01Pass = ([char[]](Get-Random -Input $(40..44 + 46..59 + 63..91 + 97..122) -Count 20)) -join ""}
While ($User01Pass -cnotmatch $RegEx)
$User01SecPass = ConvertTo-SecureString $User01Pass -AsPlainText -Force

# Set VM User 2
$User02Name = "User02"
Do {$User02Pass = ([char[]](Get-Random -Input $(40..44 + 46..59 + 63..91 + 97..122) -Count 20)) -join ""}
While ($User02Pass -cnotmatch $RegEx)
$User02SecPass = ConvertTo-SecureString $User02Pass -AsPlainText -Force

# Set VM User 3
$User03Name = "User03"
Do {$User03Pass = ([char[]](Get-Random -Input $(40..44 + 46..59 + 63..91 + 97..122) -Count 20)) -join ""}
While ($User03Pass -cnotmatch $RegEx)
$User03SecPass = ConvertTo-SecureString $User03Pass -AsPlainText -Force

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 1, estimated total time < 1 minute" -ForegroundColor Cyan

# Set Subscription and Login
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Setting Subscription Context" -ForegroundColor Cyan
Try {$myContext = Set-AzContext -Subscription $SubID -ErrorAction Stop}
Catch {Write-Warning "Permission check failed, ensure Sub ID is set correctly!"
        Return}
Write-Host "  Current Sub:",$myContext.Subscription.Name,"(",$myContext.Subscription.Id,")"

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "  Checking Login" -ForegroundColor Cyan
$RegEx = '^([\w-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([\w-]+\.)+))([a-zA-Z]{2,5}|[0-9]{1,3})(\]?)$'
If ($myContext.Account.Id -notmatch $RegEx) {
        Write-Host "Fatal Error: You are logged in with a Managed Service bearer token" -ForegroundColor Red
        Write-Host "To correct this, you'll need to login using your Azure credentials."
        Write-Host "To do this, at the command prompt, enter: " -NoNewline
        Write-Host "Connect-AzAccount -UseDeviceAuthentication" -ForegroundColor Yellow
        Write-Host "This command will show a URL and Code. Open a new browser tab and navigate to that URL, enter the code, and login with your Azure credentials"
        Write-Host
        Return
}
Write-Host "  Current User: ",$myContext.Account.Id

# 1.2 Create resource group
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Resource Group $RGName" -ForegroundColor Cyan
Try {Get-AzResourceGroup -Name $RGName -ErrorAction Stop | Out-Null
        Write-Host "  Resource group exists, skipping"}
Catch {New-AzResourceGroup -Name $RGName -Location $ShortRegion | Out-Null}

# 1.3 Create key vault
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Key Vault and Secrets" -ForegroundColor Cyan

# Get/Create key vault name
# Check if there already is a key vault in this resource group and get the name, if not make up a KV name
$kvName = $null
$kv = $null
$kvName = (Get-AzKeyVault -ResourceGroupName $RGName | Select-Object -First 1).VaultName

# If found, ensure this Key Vault isn't in removed state
if ($null -ne $kvName) {$kv = Get-AzKeyVault -VaultName $kvName -Location $ShortRegion -InRemovedState}
If ($null -eq $kvName -or $null -ne $kv) {
   Do {$kvRandom = Get-Random
       $kvName = $RGName + '-kv' + "-$kvRandom"
       $kv = Get-AzKeyVault -VaultName $kvName -Location $ShortRegion -InRemovedState
       }
   While ($null -ne $kv)    
}

# Get the key vault, create if it doesn't exist
$kv = Get-AzKeyVault -VaultName $kvName -ResourceGroupName $RGName
If ($null -eq $kv) {$kv = New-AzKeyVault -VaultName $kvName -ResourceGroupName $RGName -Location $ShortRegion
                    Start-Sleep -Seconds 10}
Else {Write-Host "  Key Vault exists, skipping"}

# 1.4 Set Key Vault Access Policy
Write-Host "  Setting Key Vault Access Policy"
$UserID = (Get-AzAdUser -UserPrincipalName $myContext.Account.Id).Id
If ($kv.AccessPolicies.ObjectId -contains $UserID) {
    Write-Host "    Policy exists, skipping"
}Else {
    Set-AzKeyVaultAccessPolicy -VaultName $kvName -ResourceGroupName $RGName -ObjectId $UserID -PermissionsToSecrets get,list,set,delete 
    Write-Host "    Policy added"
}

# 1.5 Create Secrets
# Add VM User 1 secret
$kvs = Get-AzKeyVaultSecret -VaultName $kvName -Name $User01Name -ErrorAction Stop 
If ($null -eq $kvs) {Try {$kvs = Set-AzKeyVaultSecret -VaultName $kvName -Name $User01Name -SecretValue $User01SecPass -ErrorAction Stop}
                    Catch {Write-host "Vault not found, waiting 10 seconds and trying again."
                            Start-Sleep -Seconds 10
                            $kvs = Set-AzKeyVaultSecret -VaultName $kvName -Name $User01Name -SecretValue $User01SecPass -ErrorAction Stop}}
Else {Write-Host "  $User01Name exists, skipping"}
# Add VM User 2 secret
$kvs = Get-AzKeyVaultSecret -VaultName $kvName -Name $User02Name -ErrorAction Stop 
If ($null -eq $kvs) {$kvs = Set-AzKeyVaultSecret -VaultName $kvName -Name $User02Name -SecretValue $User02SecPass -ErrorAction Stop}
Else {Write-Host "  $User02Name exists, skipping"}
# Add VM User 3 secret
$kvs = Get-AzKeyVaultSecret -VaultName $kvName -Name $User03Name -ErrorAction Stop 
If ($null -eq $kvs) {$kvs = Set-AzKeyVaultSecret -VaultName $kvName -Name $User03Name -SecretValue $User03SecPass -ErrorAction Stop}
Else {Write-Host "  $User03Name exists, skipping"}

# 1.6 Create VNet and subnets
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Virtual Network" -ForegroundColor Cyan
Try {$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
     Write-Host "  resource exists, skipping"}
Catch {$vnet = New-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -AddressPrefix $HubAddress -Location $ShortRegion  
       Write-Host (Get-Date)' - ' -NoNewline
       Write-Host "Adding subnets" -ForegroundColor Cyan
       Add-AzVirtualNetworkSubnetConfig -Name "Tenant" -VirtualNetwork $vnet -AddressPrefix $snTenant | Out-Null
       Add-AzVirtualNetworkSubnetConfig -Name "AzureBastionSubnet" -VirtualNetwork $vnet -AddressPrefix $snBastion | Out-Null
       Add-AzVirtualNetworkSubnetConfig -Name "AzureFirewallSubnet" -VirtualNetwork $vnet -AddressPrefix $snFirewall | Out-Null
       Add-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet -AddressPrefix $snGateway | Out-Null
       Add-AzVirtualNetworkSubnetConfig -Name "RouteServerSubnet" -VirtualNetwork $vnet -AddressPrefix $snRtSvr | Out-Null
       Set-AzVirtualNetwork -VirtualNetwork $vnet | Out-Null
       }

# 1.7 Create VM
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating VM" -ForegroundColor Cyan
Write-Host "  Pulling Key Vault Secrets"
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

# 1.7.1 Create NIC
Write-Host "  Creating NIC"
$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName
$sn =  Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "Tenant"
Try {$nic = Get-AzNetworkInterface -ResourceGroupName $RGName -Name $VMName'-nic' -ErrorAction Stop
     Write-Host "    NIC exists, skipping"}
Catch {$nic = New-AzNetworkInterface -ResourceGroupName $RGName -Name $VMName'-nic' -Location $ShortRegion -Subnet $sn}

# 1.7.1 Build VM
Write-Host "  Creating VM"
Try {Get-AzVM -ResourceGroupName $RGName -Name $VMName -ErrorAction Stop | Out-Null
          Write-Host "    VM exists, skipping"}
Catch {$vmConfig = New-AzVMConfig -VMName $VMName -VMSize $VMSize -ErrorAction Stop
       $vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $VMName -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
       #$vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2019-Datacenter -Version latest
       #$vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName MicrosoftWindowsDesktop -Offer windows-11 -Skus win11-21h2-pro -Version latest
       $vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2022-Datacenter -Version latest
       $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id
       $vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Disable
       Write-Host "      queuing VM build job"
       New-AzVM -ResourceGroupName $RGName -Location $ShortRegion -VM $vmConfig -AsJob | Out-Null}

# 1.8 Run post deploy job
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Waiting for the VM to deploy, this script will continue after 10 minutes or when the VM is built, whichever comes first." -ForegroundColor Cyan
Get-Job -Command "New-AzVM" | wait-job -Timeout 600 | Out-Null

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Running post VM deploy build script" -ForegroundColor Cyan
$ScriptStorageAccount = "vdcworkshop"
$ScriptName = "MaxIISBuild.ps1"
$ExtensionName = 'MaxIISBuild'
$timestamp = (Get-Date).Ticks
$ScriptLocation = "https://$ScriptStorageAccount.blob.core.windows.net/scripts/" + $ScriptName
$ScriptExe = "(.\$ScriptName -User2 '$UserName02' -Pass2 '" + $kvs02 + "' -User3 '$UserName03' -Pass3 '" + $kvs03 + "')"
$PublicConfiguration = @{"fileUris" = [Object[]]"$ScriptLocation";"timestamp" = "$timestamp";"commandToExecute" = "powershell.exe -ExecutionPolicy Unrestricted -Command $ScriptExe"}

Try {Get-AzVMExtension -ResourceGroupName $RGName -VMName $VMName -Name $ExtensionName -ErrorAction Stop | Out-Null
     Write-Host "  extension exists, skipping"}
Catch {Write-Host "  queuing build job."
       Set-AzVMExtension -ResourceGroupName $RGName -VMName $VMName -Location $ShortRegion -Name $ExtensionName `
                         -Publisher 'Microsoft.Compute' -ExtensionType 'CustomScriptExtension' -TypeHandlerVersion '1.9' `
                         -Settings $PublicConfiguration -AsJob -ErrorAction Stop | Out-Null}

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Module 1 deployed successfully" -ForegroundColor Green
Write-Host "  Explore your new Resource Group and Key Vault in the Azure Portal."
Write-Host


#TODO: Create AppGW listener for https://showmetherealheaders.azure.jackstromberg.com
#TODO: Create AppGW Customer rule to block Australia
#TODO: Send AppGW WAF logs to Log Analytics
#TODO: Rename MaxBuildIIS script to MaxBuildSimpleIIS (for hub VM)
#TODO: Update MaxBuildIIS script to contain web page with javascript to pull from File Server and Private Endpoint, display nice message if data sources aren't available
#TODO: Ensure Hub VM can reach Windows Update
#TODO: Spoke02 Load Balancer, upgrade to Standard IP, update VMSS to be zonal
