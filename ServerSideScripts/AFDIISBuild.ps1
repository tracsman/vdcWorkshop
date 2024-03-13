# IIS Server Post Build Config Script

Param(
[Parameter()]
[string]$theAdmin,
[string]$theSecret,
[string]$User2,
[string]$Pass2,
[string]$User3,
[string]$Pass3)

$Pass2 = ConvertTo-SecureString $Pass2 -AsPlainText -Force
$Pass3 = ConvertTo-SecureString $Pass3 -AsPlainText -Force

# Turn On ICMPv4
Write-Host "Opening ICMPv4 Port"
Try {Get-NetFirewallRule -Name Allow_ICMPv4_in -ErrorAction Stop | Out-Null
     Write-Host "Port already open"}
Catch {New-NetFirewallRule -DisplayName "Allow ICMPv4" -Name Allow_ICMPv4_in -Action Allow -Enabled True -Profile Any -Protocol ICMPv4 | Out-Null
       Write-Host "Port opened"}

# Install IIS
Write-Host "Installing IIS and .Net 4.5" -ForegroundColor Cyan
add-windowsfeature Web-Server, Web-WebServer, Web-Common-Http, Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-Static-Content, Web-Health, Web-Http-Logging, Web-Performance, Web-Stat-Compression, Web-Security, Web-Filtering, Web-App-Dev, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Net-Ext, Web-Net-Ext45, Web-Asp-Net45, Web-Mgmt-Tools, Web-Mgmt-Console

# Create Web App PagesWeb
Write-Host "Creating Web page and Web.Config file" -ForegroundColor Cyan
$AddressArrary = ((Get-NetIPAddress -AddressFamily IPv4 -AddressState Preferred -PrefixOrigin Dhcp).IPAddress).split(".")
$FileServerIP = "10.3."+$AddressArrary[2]+".10"
$ServerName = "$env:COMPUTERNAME"
$MainPage = '<%@ Page Language="vb" AutoEventWireup="false" %>
<%@ Import Namespace="System.IO" %>
<script language="vb" runat="server">
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        Dim FILENAME As String = "\\' + $FileServerIP + '\WebShare\Rand.txt"
        Dim objStreamReader As StreamReader
        objStreamReader = File.OpenText(FILENAME)
        Dim contents As String = objStreamReader.ReadToEnd()
        lblOutput.Text = contents
        objStreamReader.Close()
        lblTime.Text = Now()
        lblName.Text = "' + $ServerName + '"
    End Sub
</script>

<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>DMZ Example App</title>
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
        <li> Serving Server - Shows server name, indicating location of the actual server</li>
        <li> Local Server Time - Shows if this page is or isnt cached anywhere</li>
        <li> File Output - Shows that the web server is reaching the on-prem server in Seattle and successfully returning content</li>
        <li> Image from the Internet - Doesn''t really show anything, but it made me happy to see this when the app worked</li>
      </ul>
      <div style="border: 2px solid #8AC007; border-radius: 25px; padding: 20px; margin: 10px; width: 650px;">
        <b>Serving from Server</b>: <asp:Label runat="server" ID="lblName" /></div>
      <div style="border: 2px solid #8AC007; border-radius: 25px; padding: 20px; margin: 10px; width: 650px;">
        <b>Local Web Server Time</b>: <asp:Label runat="server" ID="lblTime" /></div>
      <div style="border: 2px solid #8AC007; border-radius: 25px; padding: 20px; margin: 10px; width: 650px;">
        <b>File Output from Spoke01VM Scale Set</b>: <asp:Label runat="server" ID="lblOutput" /></div>
      <div style="border: 2px solid #8AC007; border-radius: 25px; padding: 20px; margin: 10px; width: 650px;">
        <b>Image File Linked from the Internet</b>:<br />
        <br />
        <img src="https://3.bp.blogspot.com/-eZsaDgbzJuE/VXM0BE4m4RI/AAAAAAAAC-E/rHAKa41QBZo/s1600/keep-calm-and-carry-on-vector-logo.png" alt="You made it!" width="150" length="175"/></div>
    </div>
  </form>
</body>
</html>'

$WebConfig ='<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.web>
    <compilation debug="true" strict="false" explicit="true" targetFramework="4.5" />
    <httpRuntime targetFramework="4.5" />
    <identity impersonate="true" />
    <customErrors mode="Off"/>
  </system.web>
  <system.webServer>
    <defaultDocument>
      <files>
        <add value="Home.aspx" />
      </files>
    </defaultDocument>
  </system.webServer>
</configuration>'

$MainPage | Out-File -FilePath "C:\inetpub\wwwroot\Home.aspx" -Encoding ascii
$WebConfig | Out-File -FilePath "C:\inetpub\wwwroot\Web.config" -Encoding ascii

# Set App Pool to Clasic Pipeline to remote file access will work easier
Write-Host "Updaing IIS Settings" -ForegroundColor Cyan
c:\windows\system32\inetsrv\appcmd.exe set app "Default Web Site/" /applicationPool:".NET v4.5 Classic"
c:\windows\system32\inetsrv\appcmd.exe set config "Default Web Site/" /section:system.webServer/security/authentication/anonymousAuthentication  /userName:$theAdmin /password:$theSecret /commit:apphost

# Make sure the IIS settings take
Write-Host "Restarting the W3SVC" -ForegroundColor Cyan
Restart-Service -Name W3SVC

# Add additional local Admin accounts
New-LocalUser -Name $User2 -Password $Pass2 -FullName $User2 -AccountNeverExpires -PasswordNeverExpires
Add-LocalGroupMember -Group 'Administrators' -Member $User2
New-LocalUser -Name $User3 -Password $Pass3 -FullName $User3 -AccountNeverExpires -PasswordNeverExpires
Add-LocalGroupMember -Group 'Administrators' -Member $User3
Write-Host "Additional Local Accounts added" -ForegroundColor Cyan

Write-Host
Write-Host "Web App Creation Successfull!" -ForegroundColor Green
Write-Host
