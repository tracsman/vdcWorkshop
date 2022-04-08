$Dirs = @()
$Dirs += "C:\Workshop\"
$Dirs += "C:\Windows\System32\config\systemprofile\.ssh\"
$Dirs += "C:\Users\User01\.ssh\"
foreach ($Dir in $Dirs) {
     If (-not (Test-Path -Path $Dir)) {New-Item $Dir -ItemType Directory | Out-Null}
}
try {$AzureContext = (Connect-AzAccount -Identity).context}
catch{Write-Output "There is no system-assigned user identity. Aborting."; exit}
#$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext
$sa = (Get-AzStorageAccount | Select-Object -First 1)
Get-AzStorageBlobContent -Container "config" -Blob 'router.txt' -Context $sa.Context -Destination "C:\Workshop\router.txt" -Force
$LocalIP = (Get-NetIPConfiguration).IPv4Address.IPAddress | Select-Object -First 1
$RouterIP = $LocalIP.Split(".")[0] + "." + $LocalIP.Split(".")[1] + "." + $LocalIP.Split(".")[2] + "." + ($LocalIP.Split(".")[3] - 1)

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

Get-Content -Path "C:\Workshop\Test.txt" | ssh -o "StrictHostKeyChecking no" User01@$RouterIP

Write-Host "Well, something happend"
