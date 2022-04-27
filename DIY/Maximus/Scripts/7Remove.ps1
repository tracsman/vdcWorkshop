$RGName   = "MaxLab"
$kvName   = $kvName = (Get-AzKeyVault -ResourceGroupName $RGName | Select-Object -First 1).VaultName
$HubName  = "Hub-VNet"
$OPName   = "OnPrem-VNet"
$OPVMName = "OnPrem-VM01"
$CSVMName = "CoffeeShop-PC"
$S1Name = "Spoke01-VNet"
$S2Name = "Spoke02-Vnet"

Write-Host "Killing GW Connections"
try {Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $RGName -Name $HubName-gw-op-conn -ErrorAction Stop | Out-Null
     Remove-AzVirtualNetworkGatewayConnection -ResourceGroupName $RGName -Name $HubName-gw-op-conn -Force}
catch {Write-Host "  It's not there"}

Write-Host "Killing GW"
try {Get-AzVirtualNetworkGateway -ResourceGroupName $RGName -Name $HubName-gw -ErrorAction Stop | Out-Null
     Remove-AzVirtualNetworkGateway -ResourceGroupName $RGName -Name $HubName-gw -Force -AsJob}
catch {Write-Host "  It's not there"}

#$vmOP = Get-AzVM -ResourceGroupName $RGName -Name $OPVMName
#Remove-AzKeyVaultAccessPolicy -ResourceGroupName $RGName -VaultName $kvName -ObjectId $vmOP.Identity.PrincipalId

#Write-Host "  Assigning Resource Group Contributor role"
#$role = Get-AzRoleAssignment -ObjectId $vmOP.Identity.PrincipalId -ResourceGroupName $RGName -RoleDefinitionName "Contributor"
#If ($null -ne $role) {Write-Host "    role already assigned, skipping"}
#Else {New-AzRoleAssignment -ObjectId $vmOP.Identity.PrincipalId -RoleDefinitionName "Contributor" -ResourceGroupName $RGName | Out-Null}


$VMNames = @()
$VMNames += $CSVMName
$VMNames += $OPVMName
$VMNames += $OPName + '-Router01'
foreach ($VMName in $VMNames) {
    Write-Host "Killing $VMName"
    try {Get-AzVM -ResourceGroupName $RGName -Name $VMName -ErrorAction Stop | Out-Null
         Remove-AzVM -ResourceGroupName $RGName -Name $VMName -Force -AsJob}
    catch {Write-Host "  It's not there"}    
}

$SecretNames = @()
$SecretNames += "OnPremNVArsa"
$SecretNames += "S2SPSK"
$SecretNames += "P2SRoot"
$SecretNames += "P2SCertPwd"
foreach ($SecretName in $SecretNames) {
    Write-Host "Deleting Key Vault Secret $SecretName"
    $kvs = Get-AzKeyVaultSecret -VaultName $kvName -Name $SecretName
    if ($null -eq $kvs) {Write-Host "  It's not there"}
    Else {Remove-AzKeyVaultSecret -VaultName $kvName -Name $SecretName -Force}        
}
Start-Sleep -Seconds 5
foreach ($SecretName in $SecretNames) {
    Write-Host "Purging Key Vault Secret $SecretName"
    $kvs = Get-AzKeyVaultSecret -VaultName $kvName -Name $SecretName -InRemovedState
    if ($null -eq $kvs) {Write-Host "  It's not there"}
    Else {Remove-AzKeyVaultSecret -VaultName $kvName -Name $SecretName -InRemovedState -Force}
}

Write-Host "Killing Local S2S GW"
try {Get-AzLocalNetworkGateway -Name $OPName'-lgw' -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
     Remove-AzLocalNetworkGateway -Name $OPName'-lgw' -ResourceGroupName $RGName -Force -AsJob}
catch {Write-Host "  It's not there"}

Write-Host "Resetting Spoke VNets peering"
$peeringS1 = Get-AzVirtualNetworkPeering -ResourceGroupName $RGName -VirtualNetworkName $S1Name -Name "Spoke01ToHub"
$peeringS2 = Get-AzVirtualNetworkPeering -ResourceGroupName $RGName -VirtualNetworkName $S2Name -Name "Spoke02ToHub"
if ($peeringS1.UseRemoteGateways -or $peeringS1.AllowForwardedTraffic) {
    $peeringS1.UseRemoteGateways = $false
    $peeringS1.AllowForwardedTraffic = $false
    Set-AzVirtualNetworkPeering -VirtualNetworkPeering $peeringS1}
else {Write-Host "  Spoke01 already reset"}
if ($peeringS2.UseRemoteGateways -or $peeringS1.AllowForwardedTraffic) {
    $peeringS2.UseRemoteGateways = $false
    $peeringS2.AllowForwardedTraffic = $false
    Set-AzVirtualNetworkPeering -VirtualNetworkPeering $peeringS2}
else {Write-Host "  Spoke02 already reset"}

Write-Host "Waiting for VMs to delete"
Get-Job -Command "Remove-AzVM" | Wait-Job -Timeout 600 | Out-Null

foreach ($VMName in $VMNames) {
    Write-Host "Killing $VMName Disk"
    try {$Disk = Get-AzDisk -ResourceGroupName $RGName -Name $VMName"*" -ErrorAction Stop
         Remove-AzDisk -ResourceGroupName $RGName -Name $Disk.Name -Force -AsJob}
    catch {Write-Host "  It's not there"}    
}

foreach ($VMName in $VMNames) {
    Write-Host "Killing $VMName NIC"
    try {Get-AzNetworkInterface -ResourceGroupName $RGName -Name $VMName"-nic" -ErrorAction Stop | Out-Null
         Remove-AzNetworkInterface -ResourceGroupName $RGName -Name $VMName"-nic" -Force -AsJob}
    catch {Write-Host "  It's not there"}    
}

Write-Host "Waiting for NICs to delete"
Get-Job -Command "Remove-AzNetworkInterface" | Wait-Job -Timeout 600 | Out-Null

Write-Host "Killing $VMName PIP"
try {Get-AzPublicIPAddress -ResourceGroupName $RGName -Name $VMName"-pip" -ErrorAction Stop | Out-Null
     Remove-AzPublicIPAddress -ResourceGroupName $RGName -Name $VMName"-pip" -Force -AsJob}
catch {Write-Host "  It's not there"}    

Write-Host "Killing GW PIP"
try {Get-AzPublicIPAddress -ResourceGroupName $RGName -Name $HubName"-gw-pip" -ErrorAction Stop | Out-Null
     Remove-AzPublicIPAddress -ResourceGroupName $RGName -Name $HubName"-gw-pip" -Force -AsJob}
catch {Write-Host "  It's not there"}    

