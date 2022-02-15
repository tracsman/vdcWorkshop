﻿#
# DIY Azure Firewall Workshop
#
#
# Step 1 Create resource group, key vault, and secret
# Step 2 Create Virtual Network
# Step 3 Create an internet facing VM
# Step 4 Create and configure the Azure Firewall
# Step 5 Create Spoke VNet with IIS Server and a firewall rule to allow traffic
# 

# Step 1 Create resource group, key vault, and secret
# 1.1 Validate and Initialize
# 1.2 Create resource group
# 1.3 Create key vault
# 1.4 Set Key Vault Access Policy
# 1.5 Create Secrets
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

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 1 completed successfully" -ForegroundColor Green
Write-Host "  Explore your new Resource Group and Key Vault in the Azure Portal."
Write-Host
