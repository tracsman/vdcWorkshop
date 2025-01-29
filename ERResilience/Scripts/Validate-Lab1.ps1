# Validate Environment - For Workshop ExpressRoute Resiliency Part 1

$FileName = @()
$FileName += 'Validate-Lab1.ps1'
$FileName += 'ER1WorkshopStep1.ps1'
$FileName += 'ER2WorkshopStep1.ps1'
$FileName += 'ER2WorkshopStep2.ps1'
$FileName += 'ER2WorkshopStep3.ps1'
$ErrorBit=$False
$ScriptPath = "$env:HOME/Scripts"
$SubID = $null
$RGName = $null

Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Validating environment:" -ForegroundColor Cyan

# Validate Script Files
Write-Host "  Checking Script Files....." -NoNewline
ForEach ($File in $FileName) {
    If (-Not (Test-Path $ScriptPath/$File)) {
        Write-Host "One or more script files Not Found" -ForegroundColor Red
        Write-Host "                            Rerun the initial script"
        $ErrorBit=$true
        break
    }
}
If (-Not $ErrorBit) {Write-Host "All present" -ForegroundColor Green}
$ErrorBit=$False

# Check Init File
Write-Host "  Checking Init File........" -NoNewline
If (-Not (Test-Path $ScriptPath/init.txt)){
    Write-Host "File Not Found" -ForegroundColor Red
    Write-Host "                            Rerun the initial script"
    Return
} Else {
    Write-Host "Good" -ForegroundColor Green
}

# Load Init file into variables
Write-Host "  Validating File Variables:"
If (Test-Path -Path $ScriptPath/init.txt) {
        Get-Content $ScriptPath/init.txt | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}}}

# Validate SubID Guid
Write-Host "    Checking SubID.........." -NoNewline
Try {$Sub = (Set-AzContext -Subscription $SubID -ErrorAction Stop).Subscription}
Catch {
    Write-Host "SubID not valid or unauthorized" -ForegroundColor Red
    Write-Host "                            Update SubID in the init.txt file"
    $ErrorBit=$true
}
If (-Not $ErrorBit) {
    Write-Host "Valid" -ForegroundColor Green -NoNewline
    Write-Host ", Context: " -NoNewline
    Write-Host "$($Sub.Name)" -ForegroundColor Cyan
}
$ErrorBit=$False

# Validate Resource Group Name
Write-Host "    Checking RG Name........" -NoNewline
If ($RGName.Length -le 3) {
    Write-Host "RGName is either too short or doesn't exist" -ForegroundColor Red
    Write-Host "                            Update RGName in the init.txt file"
    }
ElseIf ($RGName.Length -gt 10) {
    Write-Host "RGName is too long" -ForegroundColor Red
    Write-Host "                            Update RGName in the init.txt file to 10 characters or less"
    }
ElseIf ($RGName -match " ") {
    Write-Host "RGName can not contain spaces" -ForegroundColor Red
    Write-Host "                            Remove spaces in RGName in the init.txt file"
    }
Else {
    Write-Host "Valid" -ForegroundColor Green -NoNewline
    Write-Host ", RG Name: " -NoNewline
    Write-Host $RGName -ForegroundColor Cyan
}