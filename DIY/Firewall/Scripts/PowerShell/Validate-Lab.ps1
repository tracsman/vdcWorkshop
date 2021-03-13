# Validate Environment

$FileName = @()
$FileName += 'WorkshopStep1.ps1'
$FileName += 'WorkshopStep2.ps1'
$FileName += 'WorkshopStep3.ps1'
$FileName += 'WorkshopStep4.ps1'
$FileName += 'WorkshopStep5.ps1'
$ErrorBit=$False

Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Validating environment:" -ForegroundColor Cyan
Write-Host "  Checking Script Files....." -NoNewline
Try {
    ForEach ($File in $FileName) {
        Test-Path .\$File -ErrorAction Stop | Out-Null
    }
}
Catch {
    Write-Host "One or more script files Not Found" -ForegroundColor Red
    Write-Host "                            Rerun the intial script"
    $ErrorBit=$true
}
If (-Not $ErrorBit) {Write-Host "All present" -ForegroundColor Green}
$ErrorBit=$False

Write-Host "  Checking Init File........" -NoNewline
If (-Not (Test-Path $ScriptPath\init.txt)){
    Write-Host "File Not Found" -ForegroundColor Red
    Write-Host "                            Rerun the intial script"
    Return
} Else {
    Write-Host "Good" -ForegroundColor Green
}

Write-Host "  Validating File Variables:"
If (Test-Path -Path $ScriptPath\init.txt) {
        Get-Content $ScriptPath\init.txt | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}}}

Write-Host "    Checking SubID.........." -NoNewline
Try {$Sub = (Set-AzContext -Subscription $SubID -ErrorAction Stop).Subscription}
Catch {
    Write-Host "SubID not valid or unauthorized" -ForegroundColor Red
    Write-Host "                            Update SubID in the init.txt file"
    $ErrorBit=$true
}
If (-Not $ErrorBit) {Write-Host "Valid, Context: $($Sub.Name)" -ForegroundColor Green}
$ErrorBit=$False

Write-Host "    Checking Region........." -NoNewline
If ($null -eq (Get-AzLocation | Where-Object Location -eq $ShortRegion)) {
    Write-Host "ShortRegion not valid or unauthorized" -ForegroundColor Red
    Write-Host "                            Update ShortRegion in the init.txt file"
} Else {
    Write-Host "Valid" -ForegroundColor Green
}

Write-Host "    Checking RG Name........" -NoNewline
If ($RGName.Length -le 3) {"Bad short or don't exist"}
ElseIf ($RGName -contains " ") {"Bad Space"}
Write-Host "Valid" -ForegroundColor Green



# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Environment initialization completed successfully" -ForegroundColor Green
Write-Host
