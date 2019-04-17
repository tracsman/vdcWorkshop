# vWAN VM Post-Deploy Build Script

Param(
[Parameter()]
[string]$User1,
[string]$Pass1,
[string]$User2,
[string]$Pass2,
[string]$User3,
[string]$Pass3)

$secPass1 = ConvertTo-SecureString $Pass1 -AsPlainText -Force
$secPass2 = ConvertTo-SecureString $Pass2 -AsPlainText -Force
$secPass3 = ConvertTo-SecureString $Pass3 -AsPlainText -Force

# Turn On ICMPv4
Write-Host "Opening ICMPv4 Port"
Try {Get-NetFirewallRule -Name Allow_ICMPv4_in -ErrorAction Stop | Out-Null
     Write-Host "Port already open"}
Catch {New-NetFirewallRule -DisplayName "Allow ICMPv4" -Name Allow_ICMPv4_in -Action Allow -Enabled True -Profile Any -Protocol ICMPv4 | Out-Null
       Write-Host "Port opened"}

# Add additional local Admin accounts
New-LocalUser -Name $User1 -Password $secPass1 -FullName $User1 -AccountNeverExpires -PasswordNeverExpires
Add-LocalGroupMember -Group 'Administrators' -Member $User1
New-LocalUser -Name $User2 -Password $secPass2 -FullName $User2 -AccountNeverExpires -PasswordNeverExpires
Add-LocalGroupMember -Group 'Administrators' -Member $User2
New-LocalUser -Name $User3 -Password $secPass3 -FullName $User3 -AccountNeverExpires -PasswordNeverExpires
Add-LocalGroupMember -Group 'Administrators' -Member $User3
Write-Host "Additional Local Accounts added" -ForegroundColor Cyan

# Update Init.txt with Company Number
$CompanyID = (((Get-NetIPAddress -AddressFamily IPv4 -AddressState Preferred -PrefixOrigin Dhcp).IPAddress).split("."))[2]
$FileContent = "SubID=e4a176ec-f695-407c-8eeb-185fb94076b8`nCompanyID=$CompanyID"
Out-File -FilePath "C:\vdcWorkshop\Scripts\Init.txt" -Encoding ascii -InputObject $FileContent -Force

# Update lab files
$ToolPath = "C:\vdcWorkshop\Scripts\"
$FileName = @()
$FileName += 'WorkshopStep1.ps1'
$FileName += 'WorkshopStep2.ps1'
$FileName += 'WorkshopStep3.ps1'
$FileName += 'WorkshopStep4.ps1'
$FileName += 'WorkshopStep5.ps1'
$FileName += 'WorkshopStep6.ps1'
$FileName += 'Get-CiscoConfig.ps1'
$uri = 'https://raw.githubusercontent.com/tracsman/vdcWorkshop/master/vWanLab/Scripts/PowerShell/'
ForEach ($File in $FileName) {
    $webClient = new-object System.Net.WebClient
    $webClient.DownloadFile( $uri + $File, $ToolPath + $File )
}
Write-Host "Workshop files copied" -ForegroundColor Cyan
