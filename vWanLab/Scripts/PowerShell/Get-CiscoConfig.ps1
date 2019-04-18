#
# Azure Virtual WAN Workshop
#
# This script generates Cisco CSR Router VPN config for vWAN workshop
#

# Load Initialization Variables
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
If (Test-Path -Path $ScriptDir\init.txt) {
        Get-Content $ScriptDir\init.txt | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}}}
Else {Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}

# Non-configurable Variable Initialization (ie don't modify these)
$site02BGPASN = "65002"
$site02BGPIP = "10.17." + $CompanyID +".252"
$site02Tunnel0IP = "10.17." + $CompanyID +".250"
$site02Tunnel1IP = "10.17." + $CompanyID +".251"
$site02Prefix = "10.17." + $CompanyID +".160"
$site02Subnet = "255.255.255.224" # = CIDR /27
$site02DfGate = "10.17." + $CompanyID +".161"

# Get vWAN VPN Settings
$URI = 'https://company' + $CompanyID + 'vwanconfig.blob.core.windows.net/config/vWANConfig.json'
$vWANConfig = Invoke-RestMethod $URI
$myvWanConfig = ""
foreach ($vWanConfig in $vWANConfigs) {
    if ($vWANConfig.vpnSiteConfiguration.Name -eq ("C" + $CompanyID + "-Site02-vpn")) {$myvWanConfig = $vWANConfig}
}
if ($myvWanConfig = "") {Write-Warning "vWAN Config for Site02 was not found, run Step 5";Return}

# 6.7 Provide configuration instructions
$MyOutput = @"
####
# Cisco CSR VPN Script
####

interface Loopback0
ip address $site02BGPIP 255.255.255.255
no shut

crypto ikev2 proposal az-PROPOSAL
encryption aes-cbc-256 aes-cbc-128 3des
integrity sha1
group 2

crypto ikev2 policy az-POLICY
proposal az-PROPOSAL

crypto ikev2 keyring key-peer1
peer azvpn1
 address $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.IpAddresses.Instance0)
 pre-shared-key $($myvWanConfig.vpnSiteConnections.connectionConfiguration.PSK)

crypto ikev2 keyring key-peer2
peer azvpn2
 address $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.IpAddresses.Instance1)
 pre-shared-key $($myvWanConfig.vpnSiteConnections.connectionConfiguration.PSK)

crypto ikev2 profile az-PROFILE1
match address local interface GigabitEthernet1
match identity remote address $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.IpAddresses.Instance0) 255.255.255.255
authentication remote pre-share
authentication local pre-share
keyring local key-peer1

crypto ikev2 profile az-PROFILE2
match address local interface GigabitEthernet1
match identity remote address $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.IpAddresses.Instance1) 255.255.255.255
authentication remote pre-share
authentication local pre-share
keyring local key-peer2

crypto ipsec transform-set az-IPSEC-PROPOSAL-SET esp-aes 256 esp-sha-hmac
mode tunnel

crypto ipsec profile az-VTI1
set transform-set az-IPSEC-PROPOSAL-SET
set ikev2-profile az-PROFILE1

crypto ipsec profile az-VTI2
set transform-set az-IPSEC-PROPOSAL-SET
set ikev2-profile az-PROFILE2

interface Tunnel0
ip address $site02Tunnel0IP 255.255.255.255
ip tcp adjust-mss 1350
tunnel source GigabitEthernet1
tunnel mode ipsec ipv4
tunnel destination $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.IpAddresses.Instance0)
tunnel protection ipsec profile az-VTI1

interface Tunnel1
ip address $site02Tunnel1IP 255.255.255.255
ip tcp adjust-mss 1350
tunnel source GigabitEthernet1
tunnel mode ipsec ipv4
tunnel destination $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.IpAddresses.Instance1)
tunnel protection ipsec profile az-VTI2

router bgp $site02BGPASN
bgp router-id interface Loopback0
bgp log-neighbor-changes
neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance0) remote-as 65515
neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance0) ebgp-multihop 5
neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance0) update-source Loopback0
neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance1) remote-as 65515
neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance1) ebgp-multihop 5
neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance1) update-source Loopback0

address-family ipv4
 network $site02Prefix mask $site02Subnet
 neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance0) activate
 neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance0) next-hop-self
 neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance0) soft-reconfiguration inbound
 neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance1) activate
 neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance1) next-hop-self
 neighbor $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance1) soft-reconfiguration inbound
 maximum-paths eibgp 2

ip route 0.0.0.0 0.0.0.0 $site02DfGate

ip route $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance0) 255.255.255.255 Tunnel0
ip route $($myvWanConfig.vpnSiteConnections.gatewayConfiguration.BgpSetting.BgpPeeringAddresses.Instance1) 255.255.255.255 Tunnel1

"@

# Create a new alias to access the clipboard and copy output
New-Alias Out-Clipboard $env:SystemRoot\System32\Clip.exe -ErrorAction SilentlyContinue
$MyOutput | Out-Clipboard

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Cisco config copied to the clipboard." -ForegroundColor Cyan
Write-Host "  If you need the instructions again, run Get-CiscoConfig and the instructions will be reloaded to the clipboard."
