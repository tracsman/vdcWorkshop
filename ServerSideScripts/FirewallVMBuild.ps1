# Firewall VM Post-Deploy Build Script

Param(
[Parameter()]
[string]$User2,
[string]$Pass2,
[string]$User3,
[string]$Pass3)

$secPass2 = ConvertTo-SecureString $Pass2 -AsPlainText -Force
$secPass3 = ConvertTo-SecureString $Pass3 -AsPlainText -Force

# Turn On ICMPv4
Write-Host "Opening ICMPv4 Port"
Try {Get-NetFirewallRule -Name Allow_ICMPv4_in -ErrorAction Stop | Out-Null
     Write-Host "Port already open"}
Catch {New-NetFirewallRule -DisplayName "Allow ICMPv4" -Name Allow_ICMPv4_in -Action Allow -Enabled True -Profile Any -Protocol ICMPv4 | Out-Null
       Write-Host "Port opened"}

# Add additional local Admin accounts
New-LocalUser -Name $User2 -Password $secPass2 -FullName $User2 -AccountNeverExpires -PasswordNeverExpires
Add-LocalGroupMember -Group 'Administrators' -Member $User2
New-LocalUser -Name $User3 -Password $secPass3 -FullName $User3 -AccountNeverExpires -PasswordNeverExpires
Add-LocalGroupMember -Group 'Administrators' -Member $User3
Write-Host "Additional Local Accounts added" -ForegroundColor Cyan

