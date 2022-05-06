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
if ($ShortRegion -eq "westeurope") {$ShortRegion = "westus2"}
else {$ShortRegion = "westeurope"}
 
$SpokeName    = "Spoke03"
$VNetName     = $SpokeName + "-VNet"
$AddressSpace = "10.3.0.0/16"
$TenantSpace  = "10.3.1.0/24"
$HubName      = "Hub-VNet"

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
try {$fwRouteTable = Get-AzRouteTable -Name $HubName'-rt-fw' -ResourceGroupName $RGName -ErrorAction Stop}
catch {Write-Warning "The $($HubName+'-rt-fw') Route Table was not found, please run Module 3 to ensure this critical resource is created."; Return}
Try {$hubvnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $HubName -ErrorAction Stop}
Catch {Write-Warning "The Hub VNet was not found, please run Module 1 to ensure this critical resource is created."; Return}
$kvs = Get-AzKeyVaultSecret -VaultName $kvName -Name "UniversalKey"
If ($null -eq $kvs) {Write-Warning "The Universal Key was not found in the Key Vault secrets, please run Module 1 to ensure this critical resource is created."; Return}
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kvs.SecretValue)
try {$keyUniversal = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)}
finally {[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)}
$WebAppName=$SpokeName + 'Web' + $keyUniversal
$PEPName = $RGName.ToLower() + "sa" + $keyUniversal

# 8.2 Create Spoke VNet, NSG, apply UDR, and DNS
# Create Tenant Subnet NSG
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Spoke03 NSG" -ForegroundColor Cyan
Try {$nsg = Get-AzNetworkSecurityGroup -Name $VNetName'-nsg' -ResourceGroupName $RGName -ErrorAction Stop
Write-Host "  NSG exists, skipping"}
Catch {$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $RGName -Location $ShortRegion -Name $VNetName'-nsg'}

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
       Set-AzVirtualNetwork -VirtualNetwork $vnet | Out-Null
       $vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
}

# Enable VNet Peering to the hub
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Peering Hub to Spoke" -ForegroundColor Cyan
Try {Get-AzVirtualNetworkPeering -Name HubToSpoke03 -VirtualNetworkName $hubvnet.Name -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
     Write-Host "  peering exists, skipping" }
Catch {Try {Add-AzVirtualNetworkPeering -Name HubToSpoke03 -VirtualNetwork $hubvnet -RemoteVirtualNetworkId $vnet.Id -AllowGatewayTransit -ErrorAction Stop | Out-Null}
       Catch {Write-Warning "Error creating VNet Peering"; Return}}

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
    testSocket.ConnectAsync(ipVMSS, 445)
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
      Dim FILENAME As String = "\\" & ipVMSS & "\WebShare\Rand.txt"
      Dim objStreamReader As StreamReader = File.OpenText(FILENAME)
      Dim contents As String = objStreamReader.ReadToEnd()
      lblVMSS.Text = contents
      objStreamReader.Close()
    Else
      lblVMSS.Text = "<font color=red>Content not reachable, this resource is created in Module 5.</font>"
    End If

    '' Get Private Endpoint File Server File
    If IsEndPointReady Then
      Dim objHttp = CreateObject("WinHttp.WinHttpRequest.5.1")
      objHttp.Open("GET", "http://' + $PEPName + '.privatelink.web.core.windows.net", False)
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
    <identity impersonate="true" />
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

# Create an App Service plan
try {Get-AzAppServicePlan -Name $WebAppName-plan -ResourceGroupName $RGName -ErrorAction Stop | Out-Null
     Write-Host "  App Service Plan exists, skipping"}
catch {New-AzAppServicePlan -ResourceGroupName $RGName -Location $ShortRegion -Name $WebAppName-plan -Tier Free | Out-Null}

# Create a web app
try {Get-AzWebApp -ResourceGroupName $RGName -Name $WebAppName -ErrorAction Stop | Out-Null
     Write-Host "  App Service exists, skipping"}
catch {New-AzWebApp -ResourceGroupName $RGName -Location $ShortRegion -Name $WebAppName -AppServicePlan $WebAppName-plan -}

# Publish the web app
Publish-AzWebApp -ResourceGroupName $RGName -Name $WebAppName -ArchivePath $WebDir/wwwroot.zip -Force | Out-Null

# 8.5 Tie Web App to the network
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Connecting Web App to VNet" -ForegroundColor Cyan
# https://docs.microsoft.com/en-us/azure/app-service/configure-vnet-integration-enable
$vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName -ErrorAction Stop
$subnet = Get-AzVirtualNetworkSubnetConfig -Name 'Tenant' -VirtualNetwork $vnetHub
$webApp = Get-AzResource -ResourceType Microsoft.Web/sites -ResourceGroupName $RGName -ResourceName $WebAppName
if ($null -eq $webApp.Properties.virtualNetworkSubnetId) {
     $webApp.Properties.virtualNetworkSubnetId = $subnet.Id
     $webApp | Set-AzResource -Force}
else {Write-Host "  App Service already connected to VNet, skipping"}

# 8.6 Create the Azure Front Door
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Azure Front Door" -ForegroundColor Cyan
Write-Host "  skipping cause I aint be codded yet!"

# End Nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Module 5 completed successfully" -ForegroundColor Green
Write-Host "  All environment components are built, time to play!" -ForegroundColor Green
Write-Host
Write-Host "  Try going to your AppGW IP again, notice you now have data from the VMSS File Server!"
Write-Host
