#
# DIY Workshop Maximus
#
#
# Module 1 - Hub - Create resource group, key vault and secret, Hub VNet, VM, and deploy website
# Module 2 - Access - Create NSG, Public IPs, IP Prefix, Bastion, VNet NAT
# Module 3 - Secure - Create Firewall, Firewall Policy, Log Analytics, UDR
# Module 4 - Web Tier - Create Spoke1 VNet, VNet Peering, 3xVM with Web Site, App Gateway
# Module 5 - Data Tier - Create Spoke2 VNet, Load Balancer, VMSS configured as a File Server
# Module 6 - PaaS - Create DNS, Storage Account, Private Endpoint
# Module 7 - VPN - Create On-prem and Coffee Shop, VPN Gateway, NVA and VMs 
# Module 8 - Geo Load Balance - Create Spoke3 VNet, Web App, AFD
# Module 9 - Route Server and Logging
#

# Module 8 - Geo Load Balance - Create Spoke3 VNet, Web App, AFD
# 8.1 Validate and Initialize
# 8.2 Create Spoke VNet, NSG, apply UDR, and DNS
# 8.3 Enable VNet Peering to the hub using remote gateway
# 8.4 Create Web App and compress
# 8.5 Create App Service
# 8.6 Tie Web App to the network
# 8.7 Create the Azure Front Door with WAF
# 8.8 Approve the AFD Private Link Service request to AppSvc

# 8.1 Validate and Initialize
# Setup and Start Logging
$LogDir = "$env:HOME/Logs"
If (-Not (Test-Path -Path $LogDir)) {New-Item $LogDir -ItemType Directory | Out-Null}
Start-Transcript -Path "$LogDir/Module08.log"

# Load Initialization Variables
$ScriptDir = "$env:HOME/Scripts"
If (Test-Path -Path $ScriptDir/init.txt) {
        Get-Content $ScriptDir/init.txt | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}}}
Else {Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}

# Variable Initialization
# $SubID     = defined in and pulled from the init.txt file above
# $ShortRegion defined in and pulled from the init.txt file above
# $RGName    = defined in and pulled from the init.txt file above
# Non-configurable Variable Initialization (ie don't modify these)

# Override Init.txt value to push deployment to a different region
if ($ShortRegion -eq "westus3") {$ShortRegion = "westus2"}
else {$ShortRegion = "westus3"}

$SpokeName    = "Spoke03"
$VNetName     = $SpokeName + "-VNet"
$AddressSpace = "10.3.0.0/16"
$TenantSpace  = "10.3.1.0/24"
$PrivEPSpace  = "10.3.2.0/24"
$HubName      = "Hub-VNet"
$FWName       = "Hub-FW"
$S1Name       = "Spoke01"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting Module 8, estimated total time 25 minutes" -ForegroundColor Cyan

# Set Subscription and Login
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Setting Subscription Context" -ForegroundColor Cyan
Try {$myContext = Set-AzContext -Subscription $SubID -ErrorAction Stop}
Catch {Write-Warning "Permission check failed, ensure Sub ID is set correctly!"
        Return}
Write-Host "  Current Sub:",$myContext.Subscription.Name,"(",$myContext.Subscription.Id,")"

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "  Checking Login" -ForegroundColor Cyan
$RegEx = '^([\w-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([\w-]+\.)+))([a-zA-Z]{2,5}|[0-9]{1,3})(\]?)$'
If ($myContext.Account.Id -notmatch $RegEx) {
        Write-Host "Fatal Error: You are logged in with a Managed Service bearer token" -ForegroundColor Red
        Write-Host "To correct this, you'll need to login using your Azure credentials."
        Write-Host "To do this, at the command prompt, enter: " -NoNewline
        Write-Host "Connect-AzAccount -UseDeviceAuthentication" -ForegroundColor Yellow
        Write-Host "This command will show a URL and Code. Open a new browser tab and navigate to that URL, enter the code, and login with your Azure credentials"
        Write-Host
        Write-Host "Script Ending, Module 8, Failure Code 1"
        Exit 1
}
Write-Host "  Current User: ",$myContext.Account.Id

# Pulling required components
$kvName  = (Get-AzKeyVault -ResourceGroupName $RGName | Select-Object -First 1).VaultName
if ($null -eq $kvName) {Write-Warning "The Key Vault was not found, please run Module 1 to ensure this critical resource is created."; Return}
Try {$hubvnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $HubName -ErrorAction Stop}
Catch {Write-Warning "The Hub VNet was not found, please run Module 1 to ensure this critical resource is created."; Return}
Try {$firewall = Get-AzFirewall -ResourceGroupName $RGName -Name $FWName -ErrorAction Stop}
Catch {Write-Warning "The Hub Firewall was not found, please run Module 3 to ensure this critical resource is created."; Return}
try {Get-AzPrivateDnsZone -ResourceGroupName $RGName -Name privatelink.web.core.windows.net -ErrorAction Stop | Out-Null}
Catch {Write-Warning "The Private DNS Zone was not found, please run Module 6 to ensure this critical resource is created."; Return}
$kvs = Get-AzKeyVaultSecret -VaultName $kvName -Name "UniversalKey"
If ($null -eq $kvs) {Write-Warning "The Universal Key was not found in the Key Vault secrets, please run Module 1 to ensure this critical resource is created."; Return}
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kvs.SecretValue)
try {$keyUniversal = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)}
finally {[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)}

$fwIP = $firewall.IpConfigurations[0].PrivateIPAddress
$WebAppName=$SpokeName + $keyUniversal + '-app'
$PEPName = $RGName.ToLower() + "sa" + $keyUniversal
$fdName = "aa-" + $RGName + $keyUniversal + "-fd"

# 8.2 Create Spoke VNet, NSG, apply UDR, and DNS
# Create Tenant Subnet NSG
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Spoke03 NSG" -ForegroundColor Cyan
Try {$nsg = Get-AzNetworkSecurityGroup -Name $VNetName'-nsg' -ResourceGroupName $RGName -ErrorAction Stop
Write-Host "  NSG exists, skipping"}
Catch {$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $RGName -Location $ShortRegion -Name $VNetName'-nsg'}

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Tenant UDR Table" -ForegroundColor Cyan
Try {$fwRouteTable = Get-AzRouteTable -Name $VNetName'-rt-fw' -ResourceGroupName $RGName -ErrorAction Stop
     Write-Host "  Tenant UDR Table exists, skipping"}
Catch {$fwRouteName = 'Default-Route'
       $fwRouteTableName = $VNetName + '-rt-fw'
       $fwRoute = New-AzRouteConfig -Name $fwRouteName -AddressPrefix "0.0.0.0/0" -NextHopType VirtualAppliance -NextHopIpAddress $fwIP
       $fwRouteTable = New-AzRouteTable -Name $fwRouteTableName -ResourceGroupName $RGName -location $ShortRegion -Route $fwRoute -DisableBgpRoutePropagation}

# Create Virtual Network, apply NSG and UDR
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Virtual Network" -ForegroundColor Cyan
Try {$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
     Write-Host "  resource exists, skipping"}
Catch {$vnet = New-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -AddressPrefix $AddressSpace -Location $ShortRegion
       # Add Subnets
       Write-Host (Get-Date)' - ' -NoNewline
       Write-Host "Adding subnets" -ForegroundColor Cyan
       Add-AzVirtualNetworkSubnetConfig -Name "Tenant" -VirtualNetwork $vnet -AddressPrefix $TenantSpace -NetworkSecurityGroup $nsg -RouteTable $fwRouteTable | Out-Null
       Add-AzVirtualNetworkSubnetConfig -Name "LinkSvc" -VirtualNetwork $vnet -AddressPrefix $PrivEPSpace -NetworkSecurityGroup $nsg -PrivateEndpointNetworkPoliciesFlag Disabled | Out-Null
       Set-AzVirtualNetwork -VirtualNetwork $vnet | Out-Null
       $vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
}

# Get/Link Private DNS Zone to Spoke03 VNet
Write-Host "  linking Private DNS zone to tenant subnet"
try {Get-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $RGName -ZoneName privatelink.web.core.windows.net -Name linkSpoke03 -ErrorAction Stop | Out-Null
     Write-Host "    DNS link to Spoke03 already exists, skipping"}
catch {New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $RGName -ZoneName privatelink.web.core.windows.net -Name linkSpoke03 -VirtualNetworkId $vnet.Id -EnableRegistration | Out-Null}

# 8.3 Enable VNet Peering to the hub using remote gateway
# Enable VNet Peering to the spoke
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Peering Hub to Spoke" -ForegroundColor Cyan
Try {Get-AzVirtualNetworkPeering -Name HubToSpoke03 -VirtualNetworkName $hubvnet.Name -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
     Write-Host "  peering exists, skipping" }
Catch {Try {Add-AzVirtualNetworkPeering -Name HubToSpoke03 -VirtualNetwork $hubvnet -RemoteVirtualNetworkId $vnet.Id -AllowGatewayTransit -ErrorAction Stop | Out-Null}
       Catch {Write-Warning "Error creating VNet Peering"; Return}}

# Enable VNet Peering to the hub
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Peering Spoke to Hub" -ForegroundColor Cyan
Try {Get-AzVirtualNetworkPeering -Name Spoke03ToHub -VirtualNetworkName $vnet.Name -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
     Write-Host "  peering exists, skipping" }
Catch {Try {Add-AzVirtualNetworkPeering -Name Spoke03ToHub -VirtualNetwork $vnet -RemoteVirtualNetworkId $hubvnet.Id -AllowForwardedTraffic -UseRemoteGateways -ErrorAction Stop | Out-Null}
       Catch {Write-Warning "Error creating VNet Peering"; Return}}

# 8.4 Create Web App and compress
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Web page and Web.Config file" -ForegroundColor Cyan
$WebDir = "$env:HOME/wwwroot"
If (-Not (Test-Path -Path $WebDir)) {New-Item $WebDir -ItemType Directory | Out-Null}

# Create Web App Pages
$MainPage = '<%@ Page Language="vb" AutoEventWireup="false" %>
<%@ Import Namespace="System.IO" %>
<script language="vb" runat="server">
  Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
  '' Test Endpoints (VMSS and Private EP)
    Dim ipVMSS as String = "10.2.1.254"
    Dim urlPvEP as String = "' + $PEPName + '.privatelink.web.core.windows.net"
    Dim IsVMSSReady as Boolean = False
    Dim IsEndPointReady as Boolean = False

    '' Test VMSS
    Dim testSocket as New System.Net.Sockets.TcpClient()
    testSocket.ConnectAsync(ipVMSS, 80)
    Dim i as Integer
    Do While Not testSocket.Connected
      Threading.Thread.Sleep(250)
      i=i+1
      If i >= 12 Then Exit Do '' Wait 3 seconds and exit
    Loop
    IsVMSSReady = testSocket.Connected.ToString()
    testSocket.Close

    '' Test Private Endpoint
    testSocket = New System.Net.Sockets.TcpClient()
    testSocket.ConnectAsync(urlPvEP, 80)
    Do While Not testSocket.Connected
      Threading.Thread.Sleep(250)
      i=i+1
      If i >= 12 Then Exit Do '' Wait 3 seconds and exit
    Loop
    IsEndPointReady = testSocket.Connected.ToString()
    testSocket.Close

    '' Get VMSS File Server File
    If IsVMSSReady Then
      Dim objHttp = CreateObject("WinHttp.WinHttpRequest.5.1")
      objHttp.Open("GET", "http://" + ipVMSS, False)
      objHttp.Send
      lblVMSS.Text = objHttp.ResponseText
      objHttp = Nothing
    Else
      lblVMSS.Text = "<font color=red>Content not reachable, this resource is created in Module 5.</font>"
    End If

    '' Get Private Endpoint File Server File
    If IsEndPointReady Then
      Dim objHttp = CreateObject("WinHttp.WinHttpRequest.5.1")
      objHttp.Open("GET", "http://" + urlPvEP, False)
      objHttp.Send
      lblEndPoint.Text = objHttp.ResponseText
      objHttp = Nothing
    Else
      lblEndPoint.Text = "<font color=red>Content not reachable, this resource is created in Module 6.</font>"
    End if

    '' Add Server Name and Time
    lblName.Text = "' + $WebAppName + '"
    lblTime.Text = Now()
  End Sub
</script>

<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
  <title>Maximus Workshop App Gateway Site</title>
</head>
<body style="font-family: Optima,Segoe,Segoe UI,Candara,Calibri,Arial,sans-serif;">
  <form id="frmMain" runat="server">
    <div>
      <h1>Looks like you made it!</h1>
      This is a page from the inside (a web server on a private network),<br />
      and it is making its way to the outside! (If you are viewing this from the internet)<br />
      <br />
      The following sections show:
      <ul style="margin-top: 0px;">
        <li> Local Server Time - Shows if this page is or isnt cached anywhere</li>
        <li> File Output - Shows that the web server is reaching Spoke1 VMSS File Server on the backend subnet and successfully returning content</li>
        <li> VMSS File Server - Retrieves contents of a file on the VMSS File Server in Spoke02 (created in Module 5)</li>
        <li> Private Endpoint - Retrieves contents of a file in the storage account behind the Private Endpoint created in Module 6</li>
        <li> Image from the Internet - Doesn''t really show anything, but it makes me happy to see this when everything works</li>
      </ul>
      <div style="border: 2px solid #8AC007; border-radius: 25px; padding: 20px; margin: 10px; width: 650px;">
        <b>Serving from Server</b>: <asp:Label runat="server" ID="lblName" /></div>
      <div style="border: 2px solid #8AC007; border-radius: 25px; padding: 20px; margin: 10px; width: 650px;">
        <b>Local Web Server Time</b>: <asp:Label runat="server" ID="lblTime" /></div>
      <div style="border: 2px solid #8AC007; border-radius: 25px; padding: 20px; margin: 10px; width: 650px;">
        <b>VMSS File Server</b>: <asp:Label runat="server" ID="lblVMSS" /></div>
      <div style="border: 2px solid #8AC007; border-radius: 25px; padding: 20px; margin: 10px; width: 650px;">
        <b>Private Endpoint</b>: <asp:Label runat="server" ID="lblEndPoint" /></div>
      <div style="border: 2px solid #8AC007; border-radius: 25px; padding: 20px; margin: 10px; width: 650px;">
        <b>Image File Linked from the Internet</b>:<br />
        <br />
        <img src="http://sd.keepcalm-o-matic.co.uk/i/keep-calm-you-made-it-7.png" alt="You made it!" width="150" length="175"/></div>
    </div>
  </form>
</body>
</html>'

$WebConfig ='<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.web>
    <compilation debug="true" strict="false" explicit="true" targetFramework="4.8" />
    <httpRuntime targetFramework="4.8" />
    <customErrors mode="Off"/>
  </system.web>
</configuration>'

$MainPage | Out-File -FilePath "$WebDir\default.aspx" -Encoding ascii
$WebConfig | Out-File -FilePath "$WebDir\web.config" -Encoding ascii

# Compress files for upload to App Service
Compress-Archive -Path $WebDir/* -DestinationPath $WebDir/wwwroot.zip -Force

# 8.5 Create App Service
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating App Service" -ForegroundColor Cyan
# https://docs.microsoft.com/en-us/azure/app-service/scripts/powershell-deploy-github?toc=/powershell/module/toc.json#sample-script

# Create a web app
try {Get-AzWebApp -ResourceGroupName $RGName -Name $WebAppName -ErrorAction Stop | Out-Null
     Write-Host "  App Service exists, skipping"}
catch {New-AzWebApp -ResourceGroupName $RGName -Location $ShortRegion -Name $WebAppName -AppServicePlan $WebAppName-plan -ErrorAction Stop | Out-Null}

# Publish the web app
try {Publish-AzWebApp -ResourceGroupName $RGName -Name $WebAppName -ArchivePath "$WebDir/wwwroot.zip" -Force -ErrorAction Stop | Out-Null}
catch {if ($error[0] -notmatch "Forbidden") {$error[0];Return}}

# 8.5 Tie Web App to the network
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Connecting Web App to VNet" -ForegroundColor Cyan
# https://docs.microsoft.com/en-us/azure/app-service/configure-vnet-integration-enable
$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
$subnet = Get-AzVirtualNetworkSubnetConfig -Name 'Tenant' -VirtualNetwork $vnet
$webApp = Get-AzResource -ResourceType Microsoft.Web/sites -ResourceGroupName $RGName -ResourceName $WebAppName
if ($null -eq $webApp.Properties.virtualNetworkSubnetId) {
     $subnet = Add-AzDelegation -Name "myDelegation" -ServiceName "Microsoft.Web/serverfarms" -Subnet $subnet
     $subnet.PrivateEndpointNetworkPolicies = "Enabled"
     Set-AzVirtualNetwork -VirtualNetwork $vnet | Out-Null
     $webApp.Properties.virtualNetworkSubnetId = $subnet.Id
     $webApp | Set-AzResource -Force | Out-Null}
else {Write-Host "  App Service already connected to VNet, skipping"}

# Create App Service Private Endpoint
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Private Endpoint" -ForegroundColor Cyan
$peConn = New-AzPrivateLinkServiceConnection -Name $WebAppName"-pe-conn" -PrivateLinkServiceId $webApp.Id -GroupId sites
$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
$snLinkSvc = Get-AzVirtualNetworkSubnetConfig -Name "LinkSvc" -VirtualNetwork $vnet -ErrorAction Stop
try {$privateEP = Get-AzPrivateEndpoint -ResourceGroupName $RGName -Name $WebAppName"-pe" -ErrorAction Stop
     Write-Host "  Endpoint already exists, skipping"}
catch {$privateEP = New-AzPrivateEndpoint -ResourceGroupName $RGName -Location $ShortRegion -Name $WebAppName"-pe" -Subnet $snLinkSvc -PrivateLinkServiceConnection $peConn}

# Configure PE DNS
$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
# Get/Create DNS Zone
Write-Host "  creating DNS Zone"
try {Get-AzPrivateDnsZone -ResourceGroupName $RGName -Name privatelink.azurewebsites.net -ErrorAction Stop | Out-Null
     Write-Host "    DNS Zone already exists, skipping"}
catch {New-AzPrivateDnsZone -ResourceGroupName $RGName -Name privatelink.azurewebsites.net | Out-Null}

# Get/Link Zone to Spoke03 VNet
Write-Host "  linking zone to spoke03 vnet"
try {Get-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $RGName -ZoneName privatelink.azurewebsites.net -Name linkAppSvc -ErrorAction Stop | Out-Null
     Write-Host "    DNS link to Spoke02 already exists, skipping"}
catch {New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $RGName -ZoneName privatelink.azurewebsites.net -Name linkAppSvc -VirtualNetworkId $vnet.Id | Out-Null}

# Add the A Record for the Endpoint to the DNS Zone
Write-Host "  create DNS A Record for the Private Endpoint"
$peIP = New-AzPrivateDnsRecordConfig  -IPv4Address $privateEP.CustomDnsConfigs[0].IpAddresses[0]
try {Get-AzPrivateDnsRecordSet -ResourceGroupName $RGName -Name $WebAppName -ZoneName privatelink.azurewebsites.net -RecordType A -ErrorAction Stop | Out-Null
    Write-Host "    DNS A Record already exists, skipping"}
catch {New-AzPrivateDnsRecordSet -ResourceGroupName $RGName -Name $WebAppName -ZoneName privatelink.azurewebsites.net -RecordType A -Ttl 3600 -PrivateDnsRecord $peIP | Out-Null}

# 8.6 Create the Azure Front Door
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Azure Front Door" -ForegroundColor Cyan
Write-Host "  creating AFD Profile"
try {Get-AzFrontDoorCdnProfile -ResourceGroupName $RGName -ProfileName $fdName -ErrorAction Stop | Out-Null
     Write-Host "    AFD Profile exists, skipping"}
catch {New-AzFrontDoorCdnProfile -ResourceGroupName $RGName -ProfileName $fdName -SkuName Premium_AzureFrontDoor -Location Global -ErrorAction Stop | Out-Null}

Write-Host "  creating AFD Endpoint"
try {$fdFE = Get-AzFrontDoorCdnEndpoint -ResourceGroupName $RGName -EndpointName $fdName'-fe' -ProfileName $fdName -ErrorAction Stop
     Write-Host "    AFD Endpoint exists, skipping"}
catch {$fdFE = New-AzFrontDoorCdnEndpoint -ResourceGroupName $RGName -ProfileName $fdName -EndpointName $fdName'-fe' -Location Global}

$fdHP = New-AzFrontDoorCdnOriginGroupHealthProbeSettingObject -ProbeIntervalInSecond 60 -ProbePath "/" -ProbeRequestType GET -ProbeProtocol Http
$fdLB = New-AzFrontDoorCdnOriginGroupLoadBalancingSettingObject -AdditionalLatencyInMillisecond 50 -SampleSize 4 -SuccessfulSamplesRequired 2

Write-Host "  creating Origin Group"
try {$fdOG = Get-AzFrontDoorCdnOriginGroup -OriginGroupName $fdName'-og' -ProfileName $fdName -ResourceGroupName $RGName -ErrorAction Stop
     Write-Host "    AFD Origin Group exists, skipping"}
catch {$fdOG = New-AzFrontDoorCdnOriginGroup -OriginGroupName $fdName'-og' -ProfileName $fdName -ResourceGroupName $RGName -HealthProbeSetting $fdHP -LoadBalancingSetting $fdLB}

$pipSpoke01 = Get-AzPublicIpAddress -Name $S1Name-AppGw-pip -ResourceGroupName $RGname
$urlSpoke03 = $webapp.Properties.defaultHostName
Write-Host "    adding Origin 1"
try {Get-AzFrontDoorCdnOrigin -OriginGroupName $fdName'-og' -OriginName $fdName'-og-o1' -ProfileName $fdName -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
     Write-Host "      AFD Origin 1 exists, skipping"}
catch {New-AzFrontDoorCdnOrigin -OriginGroupName $fdName'-og' -OriginName $fdName'-og-o1' -ProfileName $fdName -ResourceGroupName $RGName `
                                -HostName $pipSpoke01.IpAddress -HttpPort 80 -Priority 1 -Weight 1000 | Out-Null}

Write-Host "    adding Origin 2"
try {Get-AzFrontDoorCdnOrigin -OriginGroupName $fdName'-og' -OriginName $fdName'-og-o2' -ProfileName $fdName -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
      Write-Host "      AFD Origin 2 exists, skipping"}
catch {New-AzFrontDoorCdnOrigin -OriginGroupName $fdName'-og' -OriginName $fdName'-og-o2' -ProfileName $fdName -ResourceGroupName $RGName `
                                -HostName $urlSpoke03 -OriginHostHeader $urlSpoke03 -HttpPort 80 -Priority 1 -Weight 1000 `
                                -PrivateLinkId $webApp.Id  -SharedPrivateLinkResourceGroupId sites `
                                -SharedPrivateLinkResourcePrivateLinkLocation westus3 `
                                -SharedPrivateLinkResourceRequestMessage "App Svc Pvt Link" `
                                | Out-Null}

Write-Host "  creating AFD Route"
try {Get-AzFrontDoorCdnRoute -EndpointName $fdFE.Name -Name $fdName'-route' -ProfileName $fdName -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
     Write-Host "    AFD Route exists, skipping"}
catch {New-AzFrontDoorCdnRoute -EndpointName $fdFE.Name -Name $fdName'-route' -ProfileName $fdName -ResourceGroupName $RGName `
                               -ForwardingProtocol 'HttpOnly' -HttpsRedirect Enabled -LinkToDefaultDomain Enabled `
                               -OriginGroupId $fdOG.Id -SupportedProtocol Http,Https | Out-Null}

# 8.8 Approve the AFD Private Link Service request to AppSvc
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Approving the AFD Private Link request to App Service" -ForegroundColor Cyan
# Dev's haven't (forgot to?) created a PowerShell command to approve the request, so we need to hit the API directly
# https://docs.microsoft.com/en-us/rest/api/appservice/web-apps/approve-or-reject-private-endpoint-connection?tabs=HTTP
$webApp = Get-AzResource -ResourceType Microsoft.Web/sites -ResourceGroupName $RGName -ResourceName $WebAppName
$token = (Get-AzAccessToken -Resource "https://management.azure.com").Token
$headers = @{ Authorization = "Bearer $token" }
$body = '{"properties":{"privateLinkServiceConnectionState": {"status": "Approved","description": "Approved by ' + (Get-AzContext).Account.Id + '.","actionsRequired": "}}}'
$uri = "https://management.azure.com/subscriptions/$SubID/resourceGroups/$RGName/providers/Microsoft.Web/sites/$WebAppName/privateEndpointConnections/$($webApp.Properties.privateEndpointConnections[1].name)?api-version=2022-03-01"
$SetFailed = $false
try {Invoke-WebRequest -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $body -ErrorAction Stop | Out-Null}
catch {$SetFailed = $true}

$i = 0
if (-Not $SetFailed) {
  Do {
    $webApp = Get-AzResource -ResourceType Microsoft.Web/sites -ResourceGroupName $RGName -ResourceName $WebAppName
    $PLSRequestStatus = $webApp.Properties.privateEndpointConnections[1].properties.privateLinkServiceConnectionState.status
    if ($PLSRequestStatus -ne "Approved" ) {
      if ($i -eq 0) {Write-Host "  Waiting for the approval to be set: " -NoNewline}
      $i++
      Start-Sleep 5
      Write-Host "*" -NoNewline
    }      
  } while ($PLSRequestStatus -ne "Approved" -and $i -lt 20)
  if ($PLSRequestStatus -ne "Approved") {$SetFailed = $true}
  if ($i -gt 0) {Write-Host}
} 

if ($SetFailed) {
  Write-Warning "The Private Link Service request was not approved in the App Service Web app."
  Write-Host
  Write-Host "You will need to manualy approve this, instructions can be found here:"
  Write-Host "https://docs.microsoft.com/en-us/azure/frontdoor/standard-premium/how-to-enable-private-link-web-app#approve-azure-front-door-premium-private-endpoint-connection-from-app-service"
  Write-Host ""
}

# End Nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Module 8 completed successfully" -ForegroundColor Green
Write-Host "  All environment components are built, time to play!" -ForegroundColor Green
Write-Host
Write-Host "  You now have an Azure Front Door and a new application instance in $ShortRegion!"
Write-Host "  Try the following to check out your new resources:"
Write-Host "    1. Check out the new App Service at http://$WebAppName.azurewebsites.net"
Write-Host "       Because this App Service is behind a private link service you should get"
Write-Host "       a 403 - Forbidden error message when accessing via the internet."
Write-Host "    2. Go to your Front Door at https://$($fdFE.Hostname)"
Write-Host "       (it may take up to 10 minutes for AFD to deploy around the world)"
Write-Host "    3. Notice which spoke is serving the content in your AFD, the new instance"
Write-Host "       is also available from your Front Door if you are closer to $ShortRegion."
Write-Host "       (note: if you're further away, you can disable the closer origin in the"
Write-Host "              Front Door origin group to force AFD to the new location.)"
Write-Host
Stop-Transcript
