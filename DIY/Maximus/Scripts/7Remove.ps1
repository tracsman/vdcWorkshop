$KillGateway  = $false  # Remove things related to the gateway
$KillOPVM     = $true   # Remove things related to the OnPrem VM
$KillOPNVA    = $true   # Remove things related to the OnPrem Router
$KillCSVM     = $false  # Remove things related to the Coffee Shop VM
$KillAll      = $false  # Remove all of the above, plus secrets and files
$KillComplete = $false  # Removes everything created in Mod 7, even VNets and Bastion servers

if ($KillAll -or $KillComplete) {
    $KillGateway = $true
    $KillOPVM    = $true
    $KillOPNVA   = $true
    $KillCSVM    = $true
    $KillAll     = $true
}

$RGName   = "MaxLab"
$kvName   = (Get-AzKeyVault -ResourceGroupName $RGName | Select-Object -First 1).VaultName
$SAName   = (Get-AzStorageAccount -ResourceGroupName $RGName | Select-Object -First 1).StorageAccountName
$HubName  = "Hub-VNet"
$OPName   = "OnPrem-VNet"
$OPVMName = "OnPrem-VM01"
$CSVMName = "CoffeeShop-PC"
$S1Name   = "Spoke01-VNet"
$S2Name   = "Spoke02-Vnet"

if ($KillGateway) {
    Write-Host "Killing GW Connection"
    try {Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $RGName -Name $HubName-gw-op-conn -ErrorAction Stop | Out-Null
         Remove-AzVirtualNetworkGatewayConnection -ResourceGroupName $RGName -Name $HubName-gw-op-conn -Force}
    catch {Write-Host "  It's not there"}
    
    Write-Host "Killing GW"
    try {Get-AzVirtualNetworkGateway -ResourceGroupName $RGName -Name $HubName-gw -ErrorAction Stop | Out-Null
         Remove-AzVirtualNetworkGateway -ResourceGroupName $RGName -Name $HubName-gw -Force -AsJob}
    catch {Write-Host "  It's not there"}
}

if ($KillOPVM) {
    try {$vmOP = Get-AzVM -ResourceGroupName $RGName -Name $OPVMName -ErrorAction Stop
        Write-Host "  Removing Key Vault access policy"
        Remove-AzKeyVaultAccessPolicy -ResourceGroupName $RGName -VaultName $kvName -ObjectId $vmOP.Identity.PrincipalId
        
        Write-Host "  Unassigning Resource Group Contributor role"
        $role = Get-AzRoleAssignment -ObjectId $vmOP.Identity.PrincipalId -ResourceGroupName $RGName -RoleDefinitionName "Contributor"
        If ($null -eq $role) {Write-Host "  It's not there"}
        Else {Remove-AzRoleAssignment -ObjectId $vmOP.Identity.PrincipalId -ResourceGroupName $RGName  -RoleDefinitionName "Contributor"}
    }
    catch {Write-Host "VM doesn't exist, skipping access policy and resource group permission removal"}
}

$VMNames = @()
if ($KillCSVM) {$VMNames += $CSVMName}
if ($KillOPVM) {$VMNames += $OPVMName}
if ($KillOPNVA) {$VMNames += $OPName + '-Router01'}
foreach ($VMName in $VMNames) {
    Write-Host "Killing $VMName"
    try {Get-AzVM -ResourceGroupName $RGName -Name $VMName -ErrorAction Stop | Out-Null
         Remove-AzVM -ResourceGroupName $RGName -Name $VMName -Force -AsJob}
    catch {Write-Host "  It's not there"}
}

if ($KillComplete) {
    $Bastions = @()
    $Bastions += $OPName + '-bas'
    $Bastions += $CSName + '-bas'
    foreach ($Bastion in $Bastions) {
        Write-Host "Killing $Bastion"
        try {Get-AzBastion -ResourceGroupName $RGName -Name $Bastion -ErrorAction Stop | Remove-AzBastion -Force -AsJob}
        catch {Write-Host "  It's not there"}
    }
}

If ($KillOPVM){
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
    Start-Sleep -Seconds 10
    foreach ($SecretName in $SecretNames) {
        Write-Host "Purging Key Vault Secret $SecretName"
        $kvs = Get-AzKeyVaultSecret -VaultName $kvName -Name $SecretName -InRemovedState
        if ($null -eq $kvs) {Write-Host "  It's not there"}
        Else {Remove-AzKeyVaultSecret -VaultName $kvName -Name $SecretName -InRemovedState -Force}
    }

    Write-Host "Killing Client.pfx from Storage"
    $sa = Get-AzStorageAccount -ResourceGroupName $RGName -Name $SAName -ErrorAction Stop
    try {Get-AzStorageBlob -Container '$web' -Blob "Client.pfx" -Context $sa.Context -ErrorAction Stop| Remove-AzStorageBlob -Force}
    catch {Write-Host "  It's not there"}

    Write-Host "Killing config container from Storage"
    try {Get-AzStorageContainer -Container "config" -Context $sa.Context -ErrorAction Stop| Remove-AzStorageContainer -Force}
    catch {Write-Host "  It's not there"}
}

if ($KillAll) {
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
        Set-AzVirtualNetworkPeering -VirtualNetworkPeering $peeringS1 -AsJob}
    else {Write-Host "  Spoke01 already reset"}
    if ($peeringS2.UseRemoteGateways -or $peeringS1.AllowForwardedTraffic) {
        $peeringS2.UseRemoteGateways = $false
        $peeringS2.AllowForwardedTraffic = $false
        Set-AzVirtualNetworkPeering -VirtualNetworkPeering $peeringS2 -AsJob}
    else {Write-Host "  Spoke02 already reset"}
}

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

if ($KillComplete) {
    Write-Host "Waiting for the Bastions to delete"
    Get-Job -Command "Remove-AzBastion" | Wait-Job -Timeout 600 | Out-Null
    foreach ($Bastion in $Bastions) {
        Write-Host "Killing $Bastion PIP"
        try {Get-AzPublicIPAddress -ResourceGroupName $RGName -Name $Bastion"-pip" -ErrorAction Stop | Remove-AzPublicIPAddress -Force -AsJob}
        catch {Write-Host "  It's not there"}
    }    
}

if ($KillOPNVA) {
    Write-Host "Killing $VMName PIP"
    try {Get-AzPublicIPAddress -ResourceGroupName $RGName -Name $VMName"-pip" -ErrorAction Stop | Out-Null
         Remove-AzPublicIPAddress -ResourceGroupName $RGName -Name $VMName"-pip" -Force -AsJob}
    catch {Write-Host "  It's not there"}
}

If ($KillGateway) {
    Write-Host "Waiting for GW to delete"
    Get-Job -Command "Remove-AzVirtualNetworkGateway" | Wait-Job -Timeout 600 | Out-Null

    Write-Host "Killing GW PIP"
    try {Get-AzPublicIPAddress -ResourceGroupName $RGName -Name $HubName"-gw-pip" -ErrorAction Stop | Out-Null
        Remove-AzPublicIPAddress -ResourceGroupName $RGName -Name $HubName"-gw-pip" -Force -AsJob}
    catch {Write-Host "  It's not there"}
}

if ($KillComplete) {
    $VNetNames = @()
    $VNetNames += "OnPrem-VNet"
    $VNetNames += "CoffeeShop-VNet"
    foreach ($VNetName in $VNetNames) {
        Write-Host "Killing $VNetName"
        try {Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop | Remove-AzVirtualNetwork -Force -AsJob}
        catch {Write-Host "  It's not there"}
    }
    foreach ($VNetName in $VNetNames) {
        Write-Host "Killing $VNetName-nsg"
        try {Get-AzNetworkSecurityGroup -Name $VNetName'-nsg' -ResourceGroupName $RGName -ErrorAction Stop | Remove-AzNetworkSecurityGroup -Force -AsJob}
        catch {Write-Host "  It's not there"}
    }

    Write-Host "Waiting for VNets to delete"
    Get-Job -Command "Remove-AzVirtualNetwork" | Wait-Job -Timeout 600 | Out-Null

    Write-Host "Killing OnPrem Route Table"
    try {Get-AzRouteTable -ResourceGroupName $RGName -Name $OPName'-rt' -ErrorAction Stop | Remove-AzRouteTable -Force}
    catch {Write-Host "  It's not there"}
}

Write-Host "Waiting for All Jobs to complete"
Get-Job  | Wait-Job -Timeout 600 | Out-Null
Write-Host "All Done!" -ForegroundColor Green
