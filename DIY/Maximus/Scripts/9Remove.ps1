$KillRS  = $false  # Remove things related to the Route Server
$KillNVA = $false  # Remove things related to the Hub Router
$KillAll = $true   # Removes everything created in Mod 9

if ($KillAll) {
    $KillRS  = $true    
    $KillNVA = $true
}

$RGName  = "MaxLab"
$SAName  = (Get-AzStorageAccount -ResourceGroupName $RGName | Select-Object -First 1).StorageAccountName
$HubName = "Hub-VNet"
$NVAName  = $HubName + "-Router"

if ($KillRS){
    Write-Host "Killing Route Server"
    Remove-AzRouteServer -ResourceGroupName $RGName -RouteServerName $HubName-rs -Force -AsJob
}

if ($KillNVA) {
    Write-Host "Killing $NVAName"
    try {Get-AzVM -ResourceGroupName $RGName -Name $NVAName -ErrorAction Stop | Out-Null
         Remove-AzVM -ResourceGroupName $RGName -Name $NVAName -Force -AsJob}
    catch {Write-Host "  It's not there"}

    Write-Host "Deleting Router config files from Storage"
    $sa = Get-AzStorageAccount -ResourceGroupName $RGName -Name $SAName -ErrorAction Stop
    try {Get-AzStorageBlob -Container 'config' -Blob "HubRouter.txt" -Context $sa.Context -ErrorAction Stop| Remove-AzStorageBlob -Force}
    catch {Write-Host "  HubRouter.txt isn't there"}
    try {Get-AzStorageBlob -Container 'config' -Blob "OPDelta.txt" -Context $sa.Context -ErrorAction Stop| Remove-AzStorageBlob -Force}
    catch {Write-Host "  OPDelta.txt isn't there"}

    Write-Host "Waiting for NVA to delete"
    Get-Job -Command "Remove-AzVM" | Wait-Job -Timeout 600 | Out-Null

    Write-Host "Killing $NVAName Disk"
    try {$Disk = Get-AzDisk -ResourceGroupName $RGName -Name $NVAName"*" -ErrorAction Stop
         Remove-AzDisk -ResourceGroupName $RGName -Name $Disk.Name -Force -AsJob}
    catch {Write-Host "  It's not there"}
    Write-Host "Killing $NVAName NIC"
    try {Get-AzNetworkInterface -ResourceGroupName $RGName -Name $NVAName"-nic" -ErrorAction Stop | Out-Null
         Remove-AzNetworkInterface -ResourceGroupName $RGName -Name $NVAName"-nic" -Force -AsJob}
    catch {Write-Host "  It's not there"}

    Write-Host "Waiting for NICs to delete"
    Get-Job -Command "Remove-AzNetworkInterface" | Wait-Job -Timeout 600 | Out-Null

    Write-Host "Killing $NVAName PIP"
    try {Get-AzPublicIPAddress -ResourceGroupName $RGName -Name $NVAName"-pip" -ErrorAction Stop | Out-Null
         Remove-AzPublicIPAddress -ResourceGroupName $RGName -Name $NVAName"-pip" -Force -AsJob}
    catch {Write-Host "  It's not there"}
}

If ($KillRS) {
    Write-Host "Waiting for Route Server to delete"
    Get-Job -Command "Remove-AzRouteServer" | Wait-Job -Timeout 600 | Out-Null

    Write-Host "Killing Route Server PIP"
    try {Get-AzPublicIPAddress -ResourceGroupName $RGName -Name $HubName"-rs-pip" -ErrorAction Stop | Out-Null
        Remove-AzPublicIPAddress -ResourceGroupName $RGName -Name $HubName"-rs-pip" -Force -AsJob}
    catch {Write-Host "  It's not there"}
}

Write-Host "Waiting for All Jobs to complete"
Get-Job  | Wait-Job -Timeout 600 | Out-Null
Write-Host "All Done!" -ForegroundColor Green
