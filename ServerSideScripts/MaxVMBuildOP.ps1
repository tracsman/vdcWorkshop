# On-Prem VM Post-Deploy Build Script
#
# Configures VM, then downloads and send router config to router
#
# 1. Open Firewall for ICMP
# 2. Add additional local Admin accounts
# 3. Test/Create Folders
# 4. Install the PowerShell SDK
# 5. Create and push P2S Root cert and pfx
# 6. Pull Config File
# 7. Pull Cert and write to mulitple locations
# 8. Push Router Config
# 9. Create and set login job to copy rsa key to .ssh 
#

Param(
[Parameter()]
[string]$User1,
[string]$User2,
[string]$Pass2,
[string]$User3,
[string]$Pass3,
[string]$PassP2SCert)

Start-Transcript -Path "C:\Workshop\log-MaxVMBuildOP.txt"

# 1. Open Firewall for ICMP
Write-Host "Opening ICMPv4 Port"
Try {Get-NetFirewallRule -Name Allow_ICMPv4_in -ErrorAction Stop | Out-Null
     Write-Host "  Port already open"}
Catch {New-NetFirewallRule -DisplayName "Allow ICMPv4" -Name Allow_ICMPv4_in -Action Allow -Enabled True -Profile Any -Protocol ICMPv4 | Out-Null
       Write-Host "  Port opened"}

# 2. Add additional local Admin accounts
$userList = @{
     $User2 = $Pass2
     $User3 = $Pass3
     }
foreach ($User in $userList.Keys) {
     Write-Host "Adding $User"
     $secPass = ConvertTo-SecureString $userList[$User] -AsPlainText -Force
     try {Get-LocalUser -Name $User -ErrorAction Stop | Out-Null
          Write-Host "  $User exists, skipping"}
     catch {New-LocalUser -Name $User -Password $secPass -FullName $User -AccountNeverExpires -PasswordNeverExpires | Out-Null
            Write-Host "  $User created"}
     try {Get-LocalGroupMember -Group 'Administrators' -Member $User -ErrorAction Stop | Out-Null
          Write-Host "  $User already an admin, skipping"}
     catch {Add-LocalGroupMember -Group 'Administrators' -Member $User | Out-Null
            Write-Host "  $User added the Administrators group"}
}

# 3. Test/Create Folders
Write-Host "Creating required folders"
$Dirs = @()
$Dirs += "C:\Workshop\"
$Dirs += "C:\Windows\System32\config\systemprofile\.ssh\"
foreach ($Dir in $Dirs) {
     If (-not (Test-Path -Path $Dir)) {New-Item $Dir -ItemType Directory | Out-Null}
}

# 4. Install the PowerShell SDK
Write-Host "Installing Azure PS SDK"
try {Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction Stop | Out-Null
     Write-Host "  NuGet already registered, skipping"}
catch {Install-PackageProvider -Name NuGet -Scope AllUsers -MinimumVersion 2.8.5.201 -Force | Out-Null
       Write-Host "  NuGet registered"}
if ($null -ne (Get-Module Az.Network -ListAvailable)) {
    Write-Host "  Azure SDK already installed, skipping"}
else {Install-Module Az -Scope AllUsers -Force | Out-Null
      Write-Host "  Azure SDK installed"}

# Connect with the VM's managed identity
Write-Host "Connecting using the VM Managed Identity"
$i = 0
try {$ctx = Connect-AzAccount -Identity -ErrorAction Stop
     If ($null -eq $ctx.Subscription.Id) {
          Do {Start-Sleep -Seconds 2
              $ctx = Connect-AzAccount -Identity -ErrorAction Stop}
          Until ($i -gt 10 -or $null -ne $ctx.Subscription.Id)
     }
     Write-Host "  Identity connected"
}
catch{Write-Output "  There is no system-assigned user identity. Aborting."; exit 1}
If ($i -gt 10) {Write-Output "  There is no system-assigned user identity. Aborting."; exit 1}

# 5. Create and push P2S Root cert and pfx
# Create root cert
Write-Host "Creating P2S root cert"
$certRoot = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object {$_.Subject -eq 'CN=PathLabRootCert'}
If ($null -eq $certRoot){
     $certRoot = New-SelfSignedCertificate -Type Custom -KeySpec Signature -Subject "CN=PathLabRootCert" `
                                           -KeyExportPolicy Exportable -HashAlgorithm sha256 -KeyLength 2048 `
                                           -CertStoreLocation "Cert:\CurrentUser\My" `
                                           -KeyUsageProperty Sign -KeyUsage CertSign
     Write-Host "  P2S root cert created"
} Else {Write-Host "  P2S root cert exists, skipping"}

# Create client cert
Write-Host "Creating P2S Client cert"
$certClient = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object {$_.Subject -eq 'CN=PathLabClientCert'}
If ($null -eq $certClient){
    $certClient = New-SelfSignedCertificate -Type Custom -DnsName "PathLabClientCert" -KeySpec Signature `
                      -KeyExportPolicy Exportable -Subject "CN=PathLabClientCert" `
                      -HashAlgorithm sha256 -KeyLength 2048 `
                      -CertStoreLocation "Cert:\CurrentUser\My"-Signer $certRoot `
                      -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")
     Write-Host "  P2S Client cert created"
} Else {Write-Host "  P2S Client cert exists, skipping"}

# Save root to file
Write-Host "Saving root cert cert file"
$FileCert = "C:\Workshop\P2SRoot.cert"
If (-not (Test-Path -Path $FileCert)) {
     Export-Certificate -Cert $certRoot -FilePath $FileCert | Out-Null
     Write-Host "  root cert cert file saved"
} Else {Write-Host "  root cert cert file exists, skipping"}

# Convert to Base64 cer file
Write-Host "Creating root cer file"
$FileCer = "C:\Workshop\P2SRoot.cer"
If (-not (Test-Path -Path $FileCer)) {
     certutil -encode $FileCert $FileCer | Out-Null
     Write-Host "  Created root cer file"
} Else {Write-Host "  Root cer file exists, skipping"}

# Upload to Key Vault
Write-Host "Uploading root cer file data to Key Vault"
$kvName = (Get-AzKeyVault | Select-Object -First 1).VaultName
if ($null -eq (Get-AzKeyVaultSecret -VaultName $kvName -Name "P2SRoot")) {
     $cerKey = Get-Content "C:\Workshop\P2SRoot.cer"
     $certSec = ConvertTo-SecureString $($cerKey[1..($cerKey.IndexOf("-----END CERTIFICATE-----") - 1)] -join('')) -AsPlainText -Force
     Set-AzKeyVaultSecret -VaultName $kvName -Name "P2SRoot" -SecretValue $certSec | Out-Null
     Write-Host "  Root cer file data saved to Key Vault"
} else {Write-Host "  Root data already exists in Key Vault, skipping"}

# Save Client to file
Write-Host "Exporting client cert to pfx file"
$FilePfx = "C:\Workshop\Client.pfx"
If (-not (Test-Path -Path $FilePfx)) {
     $pwdSec = ConvertTo-SecureString $PassP2SCert -AsPlainText -Force
     Export-PfxCertificate -Cert $certClient -FilePath $FilePfx  -Password $pwdSec | Out-Null
     Write-Host "  Client cert pfx file created"
} Else {Write-Host "  Client pfx file exists, skipping"}

# Upload Client to Storage Account (as a static web file)
Write-Host 'Uploading Client.pfx to storage account $web container'
$sa = (Get-AzStorageAccount | Select-Object -First 1)
$saFiles = Get-AzStorageBlob -Container '$web' -Context $sa.context
if ($null -ne ($saFiles | Where-Object -Property Name -eq "Client.pfx")) {
    Write-Host "  Client cert exists in Storage Account, skipping"}
else {Set-AzStorageBlobContent -Context $sa.context -Container '$web' -File "C:\Workshop\Client.pfx" -Properties @{"ContentType" = "application/x-pkcs12"} -ErrorAction Stop | Out-Null
      Write-Host "  Client.pfx saved to Storage Account"}

# 6. Pull Config File
# Get sa and download blob (router config file)
Write-Host "Downloading Router config file from the Storage Account"
Try {Get-AzStorageBlobContent -Container "config" -Blob 'router.txt' -Context $sa.Context -Destination "C:\Workshop\router.txt" -Force -ErrorAction Stop | Out-Null
     $RouterConfigDownloadError = $false
     Write-Host "  Config file downloaded"
     #[IO.File]::WriteAllText("C:\Workshop\router.txt", ([IO.File]::ReadAllText("C:\Workshop\router.txt") -replace "`r`n", "`n"))
     #Write-Host "  Line endings converted to Unix style"
}
Catch {$RouterConfigDownloadError = $true
       Write-Host "  Config file download failed!!"}

# 7. Pull Cert and write to mulitple locations
If (-Not $RouterConfigDownloadError) {
     Write-Host "Pulling RSA Key from Key Vault"
     $kvs = Get-AzKeyVaultSecret -VaultName $kvName -Name "OnPremNVArsa"
     $ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kvs.SecretValue)
     try {$PrivateKey = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)}
     finally {[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)}
     Write-Host "Writing RSA key to required directories"
     $Files = @()
     $Files += "C:\Windows\System32\config\systemprofile\.ssh\id_rsa"
     $Files += "C:\Workshop\id_rsa"
     foreach ($File in $Files) {
          If (-not (Test-Path -Path $File)) {
               "-----BEGIN OPENSSH PRIVATE KEY-----`n" + $PrivateKey + "`n-----END OPENSSH PRIVATE KEY-----" | Out-File -Encoding ascii -FilePath $File
               Write-Host "  Wrote $File"}
          Else {Write-Host "  $File already exists, skipping"}
     }

     # 8. Push Router Config to router
     Write-Host "Sending config to router"
     $LocalIP = (Get-NetIPConfiguration).IPv4Address.IPAddress | Select-Object -First 1
     $RouterIP = $LocalIP.Split(".")[0] + "." + $LocalIP.Split(".")[1] + "." + $LocalIP.Split(".")[2] + "." + ($LocalIP.Split(".")[3] - 1)
     Get-Content -Path "C:\Workshop\Router.txt" | ssh -o "StrictHostKeyChecking no" $User1@$RouterIP -E C:\Workshop.err > C:\Workshop\Router.log
     Write-Host "  Config sent to router, hopefully successfully"
}

# 9. Create and set login job to copy rsa key to .ssh
# Create the logon script, and save to file
$File = "C:\Workshop\Logon.ps1"
If (-not (Test-Path -Path $File)) {
     $textScript = @'
$Dir = "$($env:USERPROFILE)\.ssh\"
If (-not (Test-Path -Path $Dir)) {New-Item $Dir -ItemType Directory | Out-Null}
$File = "$($env:USERPROFILE)\.ssh\id_rsa"
If (-not (Test-Path -Path $File)) {Copy-Item -Path "C:\Workshop\id_rsa" -Destination $File -Force}
'@
     $textScript | Out-File -FilePath $File -Encoding ascii
}
# Set to run on login
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "C:\Workshop\Logon.ps1"
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -Action $action -Trigger $trigger -User "User01" -TaskName "Copy RSA Key" | Out-Null

# End Nicely
Write-Host "On-Prem VM Build Script Complete"
Stop-Transcript