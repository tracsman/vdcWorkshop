# IIS Server Post Build Config Script

Param(
[Parameter()]
[string]$theAdmin,
[string]$theSecret)

$Decode = [System.Web.HttpUtility]::UrlDecode($theSecret)

Write-Host "Here is comes"
Write-Host $theSecret
Write-Host $Decode
Write-Host "There is was"

# Set App Pool to Clasic Pipeline to remote file access will work easier
Write-Host "Updaing IIS Settings" -ForegroundColor Cyan
c:\windows\system32\inetsrv\appcmd.exe set config "Default Web Site/" /section:system.webServer/security/authentication/anonymousAuthentication  /userName:"$theAdmin" /password:"$Decode" /commit:apphost

# Make sure the IIS settings take
Write-Host "Restarting the W3SVC" -ForegroundColor Cyan
Restart-Service -Name W3SVC

