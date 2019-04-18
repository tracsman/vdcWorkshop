#
# Azure Virtual WAN Workshop
#
# Use your corporate credentials to login (your @microsoft.com account) to Azure
#
#
# Step 1 Create a vWAN, a vWAN Hub, and vWAN VPN Gateway
# Step 2 Create a NetFoundry Virtual Appliance
# Step 3 Create a Cisco CSR Virtual Appliance
# Step 4 Connect the two Azure VNets to the vWAN Hub
# Step 5 Configure and Connect Site 1 (NetFoundry) using the partner experience
# Step 6 Configure and Connect Site 2 (Cisco) using manual VPN provisioning
# (Not included in workshop) Step 7 Configure and Connect Client01, a Point-to-Site manual VPN connection
# (Not included in workshop) Step 8 Configure and Connect ExpressRoute to vWAN Hub
# 

# Step 6 Configure and Connect Site 2 (Cisco) using manual VPN provisioning
# 6.1 Validate and Initialize
# 6.2 Create Site 02 in the Hub
# 6.3 Associate Site 02 to the vWAN hub (neither the tunnel nor BGP will come up until step 6.4 is completed)
# 6.4 Create a Blob Storage Account
# 6.5 Copy vWAN config to storage
# 6.6 Pull vWAN details
# 6.7 Provide configuration instructions
#

# 6.1 Validate and Initialize
# Az Module Test
$ModCheck = Get-Module Az.Network -ListAvailable
If ($Null -eq $ModCheck) {
    Write-Warning "The Az PowerShell module was not found. This script uses the Az modules for PowerShell"
    Write-Warning "See the blob post for more information at: https://azure.microsoft.com/blog/how-to-migrate-from-azurerm-to-az-in-azure-powershell/"
    Return
    }

# Load Initialization Variables
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
If (Test-Path -Path $ScriptDir\init.txt) {
        Get-Content $ScriptDir\init.txt | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}}}
Else {Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}

# Non-configurable Variable Initialization (ie don't modify these)
$ShortRegion = "westus2"
$hubRGName = "Company" + $CompanyID + "-Hub01"
$hubNameStub = "C" + $CompanyID + "-vWAN01"
$hubName = $hubNameStub + "-Hub01"
$site02RGName = "Company" + $CompanyID + "-Site02"
$site02NameStub = "C" + $CompanyID + "-Site02"
$site02VNetName = $site02NameStub + "-VNet01"
$site02BGPASN = "65002"
$site02BGPIP = "10.17." + $CompanyID +".252"
$site02Key = 'Th3$ecret'
$site02PSK = ConvertTo-SecureString -String $site02Key -AsPlainText -Force
$SARGName = "Company" + $CompanyID
$SAName = "company" + $CompanyID + "vwanconfig"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 6, estimated total time 5 minutes" -ForegroundColor Cyan

# Login and permissions check
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Checking login and permissions" -ForegroundColor Cyan
Try {Get-AzResourceGroup -Name $hubRGName -ErrorAction Stop | Out-Null}
Catch {# Login and set subscription for ARM
       Write-Host "Logging in to ARM"
       Try {$Sub = (Set-AzContext -Subscription $SubID -ErrorAction Stop).Subscription}
       Catch {Connect-AzAccount | Out-Null
              $Sub = (Set-AzContext -Subscription $SubID -ErrorAction Stop).Subscription}
       Write-Host "Current Sub:",$Sub.Name,"(",$Sub.Id,")"
       Try {Get-AzResourceGroup -Name $hubRGName -ErrorAction Stop | Out-Null}
       Catch {Write-Warning "Permission check failed, ensure company id is set correctly!"
              Return}
}

# Initialize vWAN, Hub gateway, and VNet02 variables
Try {$wan=Get-AzVirtualWan -ResourceGroupName $hubRGName -Name $hubNameStub}
Catch {Write-Warning "vWAN wasn't found, please run step 1 before running this script"
       Return}

Try {$hubgw=Get-AzVpnGateway -ResourceGroupName $hubRGName -Name $hubName'-gw-vpn' -ErrorAction Stop}
Catch {Write-Warning "Hub gateway wasn't found, please run step 1 before running this script"
       Return}

Try {$vnet02=Get-AzVirtualNetwork -ResourceGroupName $site02RGName -Name $site02VNetName -ErrorAction Stop}
Catch {Write-Warning "Site 2 wasn't found, please run step 0 before running this script"
       Return}

Try {$ipRemotePeerSite2=(Get-AzPublicIpAddress -ResourceGroupName $site02RGName -Name $site02NameStub'-Router01-pip' -ErrorAction Stop).IpAddress}
Catch {Write-Warning "Site 2 Router IP wasn't found, please run step 3 before running this script"
       Return}

# 6.2 Create Site 02 in the Hub
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Site 02 object in the vWAN hub" -ForegroundColor Cyan


Try {$vpnSite2 = Get-AzVpnSite -ResourceGroupName $hubRGName -Name $site02NameStub'-vpn' -ErrorAction Stop 
     Write-Host "  Site 02 exists, skipping"}
Catch {$vpnSite2 = New-AzVpnSite -ResourceGroupName $hubRGName -Name $site02NameStub'-vpn' -Location $ShortRegion `
                   -AddressSpace $vnet02.AddressSpace.AddressPrefixes -VirtualWanResourceGroupName $hubRGName `
                   -VirtualWanName $hubNameStub -IpAddress $ipRemotePeerSite2 -BgpAsn $site02BGPASN `
                   -BgpPeeringAddress $site02BGPIP -BgpPeeringWeight 0}

# 6.3 Associate Site 02 to the vWAN hub (neither the tunnel nor BGP will come up until step 6.4 is completed)
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Associating Site 02 to the vWAN hub" -ForegroundColor Cyan
Try {Get-AzVpnConnection -ParentObject $hubgw -Name $hubName'-conn-vpn-Site02' -ErrorAction Stop | Out-Null
     Write-Host "  Site 02 association exists, skipping"}
Catch {New-AzVpnConnection -ParentObject $hubgw -Name $hubName'-conn-vpn-Site02' -VpnSite $vpnSite2 `
                           -SharedKey $site02PSK -EnableBgp -VpnConnectionProtocolType IKEv2 | Out-Null}

# 6.4 Create a Blob Storage Account
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Storage Account" -ForegroundColor Cyan
Try {$sa = Get-AzStorageAccount -ResourceGroupName $SARGName –StorageAccountName $SAName -ErrorAction Stop
     Write-Host "  Storage account exists, skipping"}
Catch {$sa =New-AzStorageAccount -ResourceGroupName $SARGName –StorageAccountName $SAName -Location $ShortRegion -Type 'Standard_LRS'}
$ctx=$sa.Context

Try {$container = Get-AzStorageContainer -Name 'config' -Context $ctx -ErrorAction Stop
Write-Host "  Container exists, skipping"}
Catch {$container = New-AzStorageContainer -Name 'config' -Context $ctx -Permission Blob}

Try {Get-AzStorageContainerStoredAccessPolicy -Container 'config' -Policy 'vWANConfig' -Context $ctx -ErrorAction Stop | Out-Null}
Catch {$expiryTime = (Get-Date).AddDays(2)
       New-AzStorageContainerStoredAccessPolicy -Container 'config' -Policy 'vWANConfig' -Permission rw -ExpiryTime $expiryTime -Context $ctx | Out-Null}
$sasToken = New-AzStorageContainerSASToken -Name 'config' -Policy 'vWANConfig' -Context $ctx

#$time=(Get-Date -format yyyyMMddHHmmss).ToString()
$blobName ="vWANConfig.json"

$sasURI = $container.CloudBlobContainer.Uri.AbsoluteUri +"/"+ $blobName + $sasToken
$vpnSites = Get-AzVpnSite -ResourceGroupName $hubRGName

# 6.5 Copy vWAN config to storage
Get-AzVirtualWanVpnConfiguration -InputObject $wan -StorageSasUrl $sasURI -VpnSite $vpnSites -ErrorAction Stop | Out-Null

# 6.6 Pull vWAN details
# Get vWAN VPN Settings
$URI = 'https://company' + $CompanyID + 'vwanconfig.blob.core.windows.net/config/vWANConfig.json'
$vWANConfig = Invoke-RestMethod $URI
$myvWanConfig = ""
foreach ($vWanConfig in $vWANConfigs) {
    if ($vWANConfig.vpnSiteConfiguration.Name -eq ("C" + $CompanyID + "-Site02-vpn")) {$myvWanConfig = $vWANConfig}
}
if ($myvWanConfig = "") {Write-Warning "vWAN Config for Site02 was not found, run Step 5";Return}

# 6.7 Provide configuration instructions
."$ScriptDir\Get-CiscoConfig.ps1"

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Cisco Configuration Instructions" -ForegroundColor Cyan
Write-Host
Write-Host "Here is stuff you need to know!" -ForegroundColor Green
$MyOutput = @"
  vWAN IPs and Details
  Public IP 1: $(myvWanConfig.vpnSiteConnections.gatewayConfiguration.IpAddresses.Instance0)
  Public IP 2: $(myvWanConfig.vpnSiteConnections.gatewayConfiguration.IpAddresses.Instance1)
  VPN PSK:     $(myvWanConfig.vpnSiteConnections.connectionConfiguration.PSK)
  BGP ASN:     $(myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.Asn)
  BGP IP:      $(myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance0)
  BGP IP:      $(myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance1)

  Site 02 IPs and Details
  Public IP: $($ipRemotePeerSite2)
  VPN PSK:   $(myvWanConfig.vpnSiteConnections.connectionConfiguration.PSK)
  BGP ASN:   $($site02BGPASN)
  BGP IP:    $($site02BGPIP)

  You now need to SSH to the Cisco device and configure the VPN tunnels.
  1. Open an SSH session to the Cisco router:
     - Open a PowerShell console window (ie NOT ISE!)
     - Type: ssh User01@$ipRemotePeerSite2 (no quotes) and hit enter
     - You're now in the Cisco router and should see a prompt similar to ""
  2. Enter Cisco VPN Config
     - Get into edit mode by typing "configure terminal" (again no quotes)
     - Right-click to paste in the config from the script above (if the clipboard doesn't have rerun the Get-CiscoConfig)
  3. Review the pasted config for any errors, warnings are ok, if you see errors contact the instructor
  4. Leave edit mode by typing "end"
  5. Save your config by typing "wr"
  6. Leave the router by typing "Exit", this will take you back to the PowerShell prompt
  7. Close your PowerShell prompt by typing "Exit"

"@
$MyOutput

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 6 completed successfully" -ForegroundColor Green
Write-Host "  Use the instructions above to configure the Cisco device have been copied to the clipboard, open Notepad and paste the instructions to configure the device. If you need the instructions again, rerun this script and the instructions will be reloaded to the clipboard."
Write-Host
