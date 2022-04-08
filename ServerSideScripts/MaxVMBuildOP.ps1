# On-Prem VM Post-Deploy Build Script
#
# Configures VM, then downloads and send router config to router
#
# 1. Open Firewall for ICMP
# 2. Add additional local Admin accounts
# 3. Test/Create Folders
# 3. Pull Config File
# 4. Pull Cert
# 5. Push Router Config

Param(
[Parameter()]
[string]$User1,
[string]$User2,
[string]$Pass2,
[string]$User3,
[string]$Pass3)

# 1. Open Firewall for ICMP
Write-Host "Opening ICMPv4 Port"
Try {Get-NetFirewallRule -Name Allow_ICMPv4_in -ErrorAction Stop | Out-Null
     Write-Host "Port already open"}
Catch {New-NetFirewallRule -DisplayName "Allow ICMPv4" -Name Allow_ICMPv4_in -Action Allow -Enabled True -Profile Any -Protocol ICMPv4 | Out-Null
       Write-Host "Port opened"}

# 2. Add additional local Admin accounts
Write-Host "Adding User 2"
$secPass2 = ConvertTo-SecureString $Pass2 -AsPlainText -Force
try {Get-LocalUser -Name $User2
     Write-Host "User 2 exists, skipping"}
catch {New-LocalUser -Name $User2 -Password $secPass2 -FullName $User2 -AccountNeverExpires -PasswordNeverExpires
       Write-Host "User 2 created"}
try {Get-LocalGroupMember -Group 'Administrators' -Member $User2 -ErrorAction Stop | Out-Null
     Write-Host "$User2 already an admin, skipping"}
catch {Add-LocalGroupMember -Group 'Administrators' -Member $User2}

Write-Host "Adding User 3"
$secPass3 = ConvertTo-SecureString $Pass3 -AsPlainText -Force
try {Get-LocalUser -Name $User3
     Write-Host "User 3 exists, skipping"}
catch {New-LocalUser -Name $User3 -Password $secPass3 -FullName $User3 -AccountNeverExpires -PasswordNeverExpires
       Write-Host "User 3 created"}
try {Get-LocalGroupMember -Group 'Administrators' -Member $User3 -ErrorAction Stop | Out-Null
     Write-Host "$User3 already an admin, skipping"}
catch {Add-LocalGroupMember -Group 'Administrators' -Member $User3}

# 3. Test/Create Folders
$Dirs = @()
$Dirs += "C:\Workshop\"
$Dirs += "C:\Windows\System32\config\systemprofile\.ssh\"
$Dirs += "C:\Users\User01\.ssh\"
foreach ($Dir in $Dirs) {
     If (-not (Test-Path -Path $Dir)) {New-Item $Dir -ItemType Directory | Out-Null}
}

# 4. Pull Config File
# Add PowerShell SDK
try {Get-PackageProvider -Name NuGet -ErrorAction Stop | Out-Null
     Write-Host "NuGet already registered, skipping"}
catch {Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
       Write-Host "NuGet registered"}
if ($null -eq (Get-Module Az.Network -ListAvailable)) {
    Write-Host "Azure SDK already installed, skipping"}
else {Install-Module Az -Force | Out-Null
      Write-Host "Azure SDK installed"}

# Connect with the VM's managed identity
try {Connect-AzAccount -Identity -ErrorAction Stop | Out-Null}
catch{Write-Output "There is no system-assigned user identity. Aborting."; exit 1}

# Get sa and download blob (router config file)
$sa = (Get-AzStorageAccount | Select-Object -First 1)
Get-AzStorageBlobContent -Container "config" -Blob 'Router.txt' -Context $sa.Context -Destination "C:\Workshop\router.txt" -Force

# 5. Pull Cert and write to mulitple locations
$kvName = (Get-AzKeyVault | Select-Object -First 1).VaultName
$kvs = Get-AzKeyVaultSecret -VaultName $kvName -Name "OnPremNVArsa"
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kvs.SecretValue)
try {$PrivateKey = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)}
finally {[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)}
$Files = @()
$Files += "C:\Windows\System32\config\systemprofile\.ssh\id_rsa"
$Files += "C:\Users\User01\.ssh\id_rsa"
foreach ($File in $Files) {
     If (-not (Test-Path -Path $File)) {
          #$PrivateKey | Out-File -Encoding ascii -FilePath $File
          "-----BEGIN OPENSSH PRIVATE KEY-----`n" + $PrivateKey.Substring(36, 1752).Replace(" ", "`n") + "`n-----END OPENSSH PRIVATE KEY-----" | Out-File -Encoding ascii -FilePath $File
          Write-Host "Wrote $File"}
}

# 6. Push Router Config to router
$LocalIP = (Get-NetIPConfiguration).IPv4Address.IPAddress | Select-Object -First 1
$RouterIP = $LocalIP.Split(".")[0] + "." + $LocalIP.Split(".")[1] + "." + $LocalIP.Split(".")[2] + "." + ($LocalIP.Split(".")[3] - 1)
Get-Content -Path "C:\Workshop\Router.txt" | ssh -o "StrictHostKeyChecking no" $User01@$RouterIP

# End Nicely
Write-Host "I think we're good!"
