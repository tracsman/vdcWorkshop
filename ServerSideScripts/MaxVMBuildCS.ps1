# Coffee Shop VM Post-Deploy Build Script
#
# 1. Open Firewall for ICMP
# 2. Add additional local Admin accounts
# 3. Test/Create Folders
# 4. Get Client cert (if available)
# 5. Install Client Cert
# 6. Configure and Create the P2S VPN Connection
#

Param(
[Parameter()]
[string]$User2,
[string]$Pass2,
[string]$User3,
[string]$Pass3,
[string]$urlCert,
[string]$urlAzGW,
[string]$P2SCertPwd
)

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

# 3. Test/Create Folder
Write-Host "Creating workshop folder"
$Dir = "C:\Workshop\"
If (-not (Test-Path -Path $Dir)) {New-Item $Dir -ItemType Directory | Out-Null}

# 4. Get Client cert (if available)
Write-Host "Downloading Client Cert"
$File = "C:\Workshop\Client.pfx"
$FatalCertIssue = $false
If (-not (Test-Path -Path $File)) {
    Try {$response = Invoke-WebRequest -UseBasicParsing -Uri $urlCert -ErrorAction Stop}
    Catch {$response = $null}
    If ($response.StatusCode -ne 200) {
        $FatalCertIssue = $true
        Write-Host "  Client cert download failed"}
    Else {Invoke-WebRequest -Uri $urlCert -OutFile $File
          Write-Host "  Client cert downloaded"}
} else {Write-Host "  Client cert exists, no download needed"}

# 5. Install Client Cert
Write-Host "Installing Client Cert"
$pwdSec = ConvertTo-SecureString $P2SCertPwd -AsPlainText -Force
$certClient = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -eq 'CN=PathLabClientCert'}
If ($null -eq $certClient -and -not $FatalCertIssue) {
     Import-PfxCertificate -CertStoreLocation "cert:LocalMachine\My" -Password $pwdSec -FilePath $File | Out-Null
     Write-Host "  Client Cert Installed"}
ElseIf ($FatalCertIssue) {
     Write-Warning 'A critical issue occurred retrieving the Client cert from the storage account $web container'
     Write-Host "The P2S connection won't connect until this cert is downloaded and installed (default locations)"
     Write-Host 'on this VM. The password for the cert is in the key vault, secret name "P2SCertPwd"'}

# Move Root Cert from CA to Root store
Write-Host "  moving root cer from CA to Root store"
$caRoot = Get-ChildItem -Path Cert:\LocalMachine\CA | Where-Object {$_.Subject -eq 'CN=PathLabRootCert'}
if ($null -ne $caRoot){Move-Item -Path $caRoot.PSPath -Destination "Cert:\LocalMachine\Root"}
if ($null -eq (Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object {$_.Subject -eq 'CN=PathLabRootCert'})) {
     Write-Warning 'A critical issue occurred moving the root CA for the P2S Certificate to the Local Machine Trusted Store'
     Write-Host "The P2S connection won't connect until this the root is moved."
     Write-Host 'The easiest solution may be to delete the VM and re-run the module 7 script.' }

# 6. Configure and Create the P2S VPN Connection
Write-Host "Creating P2S VPN"
$vpnConnection = Get-VpnConnection -Name "AzureHub" -AllUserConnection -ErrorAction SilentlyContinue
if ($null -eq $vpnConnection) {
     Try {Add-VpnConnection -Name "AzureHub" -ServerAddress $urlAzGW -AllUserConnection -AuthenticationMethod MachineCertificate -SplitTunneling -TunnelType Ikev2 -ErrorAction Stop
          Add-VpnConnectionRoute -ConnectionName "AzureHub" -DestinationPrefix "10.0.0.0/16"
          Add-VpnConnectionRoute -ConnectionName "AzureHub" -DestinationPrefix "10.1.0.0/16"
          Add-VpnConnectionRoute -ConnectionName "AzureHub" -DestinationPrefix "10.2.0.0/16"
          Add-VpnConnectionRoute -ConnectionName "AzureHub" -DestinationPrefix "10.3.0.0/16"
          Add-VpnConnectionRoute -ConnectionName "AzureHub" -DestinationPrefix "10.10.2.0/24"
     }
     Catch {Write-Warning 'A fatal issue occurred adding the VPN Connection'
            Write-Host "From the Azure Portal, on the Coffee Shop VM, go to the ""Extension"" blade"
            Write-Host "and uninstall the 'MaxVMBuildCS' extension, then rerun the Module 7 script"
            Write-Host "to re-install this extension on this VM."
            Write-Host "Coffee Shop VM Build Script Failed"
            Write-Host "Script Ending, MaxVMBuildCS Script, Failure Code 1"
            Exit 1}}
else {Write-Host "  AzureHub vpn found, skipping"}

# End Nicely
Write-Host "Coffee Shop VM Build Script Complete"
