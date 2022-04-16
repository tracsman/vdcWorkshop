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
     Write-Host "Port already open"}
Catch {New-NetFirewallRule -DisplayName "Allow ICMPv4" -Name Allow_ICMPv4_in -Action Allow -Enabled True -Profile Any -Protocol ICMPv4 | Out-Null
       Write-Host "Port opened"}

# 2. Add additional local Admin accounts
$userList = @{
     $User2 = $Pass2
     $User3 = $Pass3
     }
foreach ($User in $userList.Keys) {
     Write-Host "Adding $User"
     $secPass = ConvertTo-SecureString $userList[$User] -AsPlainText -Force
     try {Get-LocalUser -Name $User
          Write-Host "$User exists, skipping"}
     catch {New-LocalUser -Name $User -Password $secPass -FullName $User -AccountNeverExpires -PasswordNeverExpires
          Write-Host "$User created"}
     try {Get-LocalGroupMember -Group 'Administrators' -Member $User -ErrorAction Stop | Out-Null
          Write-Host "$User already an admin, skipping"}
     catch {Add-LocalGroupMember -Group 'Administrators' -Member $User
            Write-Host "$User added the Administrators group"}
}

# 3. Test/Create Folders
Write-Host "Creating workshop folder"
$Dir = "C:\Workshop\"
If (-not (Test-Path -Path $Dir)) {New-Item $Dir -ItemType Directory | Out-Null}

# 4. Get Client cert (if available)
Write-Host "Downloading Client Cert"
$File = "C:\Workshop\Client.pfx"
$FatalCertIssue = $false
If (-not (Test-Path -Path $File)) {
    Try {$response = Invoke-WebRequest -Uri $urlCert -ErrorAction Stop}
    Catch {$response = $null}
    If ($response.StatusCode -ne 200) {
         $FatalCertIssue = $true
         Write-Host "Client cert download failed"}
    Else {Invoke-WebRequest -Uri $urlCert -OutFile $File
          Write-Host "Client cert downloaded"}
} else {Write-Host "Client cert exists, no download needed"}

# 5. Install Client Cert
Write-Host "Installing Client Cert"
$pwdSec = ConvertTo-SecureString $P2SCertPwd -AsPlainText -Force
$certClient = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object {$_.Subject -eq 'CN=PathLabClientCert'}
If ($null -eq $certClient -and -not $FatalCertIssue) {
     Import-PfxCertificate -CertStoreLocation "cert:CurrentUser\My" -Password $pwdSec -FilePath $File | Out-Null
     Write-Host "Client Cert Installed"}
ElseIf ($FatalCertIssue) {
     Write-Warning 'A fatal issue occurred retrieving  the Client cert from the storage account $web container'
     Write-Host "The P2S connection won't connect until this cert is downloaded and installed (default locations)"
     Write-Host 'on this VM. The password for the cert is in the key vault, secret name "P2SCertPwd"'}

# 6. Configure and Create the P2S VPN Connection
Write-Host "Creating P2S VPN"
[xml]$xmlEAPString = @'
<EapHostConfig xmlns="http://www.microsoft.com/provisioning/EapHostConfig">
 <EapMethod>
  <Type xmlns="http://www.microsoft.com/provisioning/EapCommon">13</Type>
  <VendorId xmlns="http://www.microsoft.com/provisioning/EapCommon">0</VendorId>
  <VendorType xmlns="http://www.microsoft.com/provisioning/EapCommon">0</VendorType>
  <AuthorId xmlns="http://www.microsoft.com/provisioning/EapCommon">0</AuthorId>
 </EapMethod>
 <Config xmlns="http://www.microsoft.com/provisioning/EapHostConfig">
  <Eap xmlns="http://www.microsoft.com/provisioning/BaseEapConnectionPropertiesV1">
   <Type>13</Type>
   <EapType xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV1">
    <CredentialsSource><CertificateStore><SimpleCertSelection>true</SimpleCertSelection></CertificateStore></CredentialsSource>
    <ServerValidation><DisableUserPromptForServerValidation>false</DisableUserPromptForServerValidation><ServerNames></ServerNames></ServerValidation>
    <DifferentUsername>false</DifferentUsername>
    <PerformServerValidation xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV2">false</PerformServerValidation>
    <AcceptServerName xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV2">false</AcceptServerName>
   </EapType>
  </Eap>
 </Config>
</EapHostConfig>
'@

$vpnConnection = Get-VpnConnection -Name "AzureHub" -AllUserConnection
if ($null -eq $vpnConnection) {
     Add-VpnConnection -Name "AzureHub" -ServerAddress $urlAzGW -AllUserConnection -AuthenticationMethod Eap -SplitTunneling -TunnelType Ikev2 -EapConfigXmlStream $xmlEAPString
     Write-Host "VPN Connection created"}
else {Write-Host "AzureHub vpn found, skipping"}

# End Nicely
Write-Host "Coffee Shop VM Build Script Complete"