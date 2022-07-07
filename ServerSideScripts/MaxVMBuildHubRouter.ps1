# Hub VM NVA Build Script
#
# Send router config to router
#
# 1. Test/Create Folders
# 2. Install the PowerShell SDK
# 3. Pull Config File
# 4. Pull Cert and write to mulitple locations
# 5. Push Router Config
# 6. Create and set login job to copy rsa key to .ssh 
#

Start-Transcript -Path "C:\Workshop\MaxVMBuildHubRouter.log"

# 1. Test/Create Folders
Write-Host "Creating required folders"
$Dirs = @()
$Dirs += "C:\Workshop\"
$Dirs += "C:\Windows\System32\config\systemprofile\.ssh\"
foreach ($Dir in $Dirs) {
     If (-not (Test-Path -Path $Dir)) {New-Item $Dir -ItemType Directory | Out-Null}
}

# 2. Install the PowerShell SDK
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
Connect-AzAccount -Identity
$ctx = Get-AzContext
If ($null -eq $ctx.Subscription.Id) {
     Do {Write-Host "*"
         Start-Sleep -Seconds 2
         Connect-AzAccount -Identity
         $ctx = Get-AzContext}
     Until ($i -gt 15 -or $null -ne $ctx.Subscription.Id)
}
If ($null -eq $ctx.Subscription.Id) {Write-Output "  There is no system-assigned user identity. Aborting."; exit 1}
Else {Write-Host "  Identity connected"}

# 3. Pull Config File
# Get sa and download blob (router config file)
$sa = (Get-AzStorageAccount | Select-Object -First 1)
Write-Host "Downloading Router config file from the Storage Account"
Try {Get-AzStorageBlobContent -Container "config" -Blob 'HubRouter.txt' -Context $sa.Context -Destination "C:\Workshop\HubRouter.txt" -Force -ErrorAction Stop | Out-Null
     $RouterConfigDownloadError = $false
     Write-Host "  Config file downloaded"
}
Catch {$RouterConfigDownloadError = $true
       Write-Host "  Config file download failed!!"}

# 4. Pull Cert and write to mulitple locations
If (-Not $RouterConfigDownloadError) {
     Write-Host "Pulling RSA Key from Key Vault"
     $kvName = (Get-AzKeyVault | Select-Object -First 1).VaultName
     Write-Host "kvName: $kvName"
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

     # 5. Push Router Config to router
     Write-Host "Sending config to router"
     $LocalIP = (Get-NetIPConfiguration).IPv4Address.IPAddress | Select-Object -First 1
     $RouterIP = $LocalIP.Split(".")[0] + "." + $LocalIP.Split(".")[1] + "." + $LocalIP.Split(".")[2] + "." + ($LocalIP.Split(".")[3] + 1)
     Get-Content -Path "C:\Workshop\HubRouter.txt" | ssh -o "StrictHostKeyChecking no" $User1@$RouterIP -E C:\Workshop\Router.err > C:\Workshop\Router.log
     Write-Host "  Config sent to router, hopefully successfully"
}

# 6. Create and set login job to copy rsa key to .ssh
# Create the logon script, and save to file
Write-Host "Creating logon task to move RSA key for router login"
$File = "C:\Workshop\Logon.ps1"
If (-not (Test-Path -Path $File)) {
     $textScript = @'
Start-Transcript -Path "C:\Workshop\Logon.log"
$Dir = "$($env:USERPROFILE)\.ssh\"
If (-not (Test-Path -Path $Dir)) {
     New-Item $Dir -ItemType Directory | Out-Null
     Write-Host "Dir created"}
Else {Write-Host "Dir exists, skipping"}
$File = "$($env:USERPROFILE)\.ssh\id_rsa"
If (-not (Test-Path -Path $File)) {
     Copy-Item -Path "C:\Workshop\id_rsa" -Destination $File -Force
     Write-Host "File copied"}
Else {Write-Host "File exists, skipping"}
Stop-Transcript
'@
     $textScript | Out-File -FilePath $File -Encoding ascii
}
# Set to run on login
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoLogo -WindowStyle Hidden -File C:\Workshop\Logon.ps1"
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -Action $action -Trigger $trigger -User "User01" -TaskName "User01 Copy RSA Key" | Out-Null
Register-ScheduledTask -Action $action -Trigger $trigger -User "User02" -TaskName "User02 Copy RSA Key" | Out-Null
Register-ScheduledTask -Action $action -Trigger $trigger -User "User03" -TaskName "User03 Copy RSA Key" | Out-Null

# End Nicely
Write-Host "Hub VM NVA Build Script Complete"
Stop-Transcript