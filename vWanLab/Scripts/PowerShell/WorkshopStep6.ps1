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
# 6.3 Create a connect from the Hub to Site 01 (neither the tunnel nor BGP will come up until step 6.4 is completed)
# 6.4 Create a Blob Storage Account
# 6.5 Copy vWAN config to storage
# 6.6 Configure the Cisco device
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
$site02BGPIP = "10.17." + $CompanyID +".165"
$SARGName = "Company" + $CompanyID
$SAName = "company" + $CompanyID + "vwanconfig"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 4, estimated total time 5 minutes" -ForegroundColor Cyan

# Login and permissions check
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Checking login and permissions" -ForegroundColor Cyan
Try {Get-AzResourceGroup -Name $RGName -ErrorAction Stop | Out-Null}
Catch {# Login and set subscription for ARM
       Write-Host "Logging in to ARM"
       Try {$Sub = (Set-AzContext -Subscription $SubID -ErrorAction Stop).Subscription}
       Catch {Connect-AzAccount | Out-Null
              $Sub = (Set-AzContext -Subscription $SubID -ErrorAction Stop).Subscription}
       Write-Host "Current Sub:",$Sub.Name,"(",$Sub.Id,")"
       Try {Get-AzResourceGroup -Name $RGName -ErrorAction Stop | Out-Null}
       Catch {Write-Warning "Permission check failed, ensure company id is set correctly!"
              Return}
}

# Initialize vWAN Hub and VNet02 variables
Try {$hub=Get-AzVirtualHub -ResourceGroupName $hubRGName -Name $hubName -ErrorAction Stop}
Catch {Write-Warning "vWAN Hub wasn't found, please run step 1 before running this script"
       Return}

Try {$vnet02=Get-AzVirtualNetwork -ResourceGroupName $site02RGName -Name $site02VNetName -ErrorAction Stop}
Catch {Write-Warning "Site 2 wasn't found, please run step 0 before running this script"
       Return}

# 6.2 Create Site 02 in the Hub
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Site 02 object in the vWAN hub" -ForegroundColor Cyan
$ipRemotePeerSite2=(Get-AzPublicIpAddress -ResourceGroupName $site02RGName -Name $site02NameStub'-Router01-pip').IpAddress

Try {$vpnSite2=Get-AzVpnSite -ResourceGroupName $hubRGName -Name $vnet02NameStub'-vpn'  -ErrorAction Stop 
     Write-Host "  Site 02 exists, skipping"}
Catch {$vpnSite2=New-AzVpnSite -ResourceGroupName $hubRGName -Name $site02NameStub'-vpn' -Location $ShortRegion `
                 -AddressSpace $vnet02.AddressSpace.AddressPrefixes -VirtualWanResourceGroupName $hubRGName `
                 -VirtualWanName $hubNameStub -IpAddress $ipRemotePeerSite2 -BgpAsn $site02BGPASN `
                 -BgpPeeringAddress $site02BGPIP -BgpPeeringWeight 0}

# 6.3 Create a connect from the Hub to Site 02 (neither the tunnel nor BGP will come up until step 6.4 is completed)
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating connection object between Site 02 and the vWAN hub" -ForegroundColor Cyan
Try {Get-AzVirtualHubVnetConnection -ResourceGroupName $hubRGName -Name $hubName'-conn-vpn-Site02' -ErrorAction Stop | Out-Null
     Write-Host "  Site 01 connection exists, skipping"}
Catch {New-AzVirtualHubVnetConnection -Name $hubName'-conn-vpn-Site02' -ParentObject $hub -RemoteVirtualNetwork $vnet02}

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
$sasURI = $container.CloudBlobContainer.Uri.AbsoluteUri +"/"+ 'vWANConfig.json' + $sasToken
$vpnSites = Get-AzVpnSite -ResourceGroupName $RGName

# 6.5 Copy vWAN config to storage
Get-AzVirtualWanVpnConfiguration -VirtualWan $wan -StorageSasUrl $sasURI -VpnSite $vpnSites

# 6.6 Configure the Cisco device
# Create a new alias to access the clipboard
New-Alias Out-Clipboard $env:SystemRoot\System32\Clip.exe -ErrorAction SilentlyContinue

# Get vWAN VPN Settings
$URI = 'https://company' + $CompanyID + 'vwanconfig.blob.core.windows.net/config/vWANConfig.json'
$vWANConfig = Invoke-RestMethod $URI

# 6.7 Provide configuration instructions
$MyOutput = @"
Here is stuff you need to know.
Public IP 1: $($results.vpnSiteConnections.gatewayConfiguration.IpAddresses.Instance0)
Public IP 2: $($results.vpnSiteConnections.gatewayConfiguration.IpAddresses.Instance1)
VPN PSK:     $($results.vpnSiteConnections.connectionConfiguration.PSK)
BGP ASN:     $($results.vpnSiteConnections.gatewayConfiguration.BgpSetting.Asn)
BGP IP:      $($results.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance0)
BGP IP:      $($results.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance1)

To get the Cisco CSR Config, run the Get-CiscoConfig.ps1 script.
When you have that script, use PuTTY to SSH to the Cisco device and configure the VPN tunnels.

Not sure what else there is.
Probably the Site 2 device IP address $ipRemotePeerSite2
Maybe other stuff too, not really sure yet.
"@
$MyOutput | Out-Clipboard

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 6 completed successfully" -ForegroundColor Green
Write-Host "  The instructions to configure the Cisco device have been copied to the clipboard, open Notepad and paste the instructions to configure the device. If you need the instructions again, rerun this script and the instructions will be reloaded to the clipboard."
Write-Host
