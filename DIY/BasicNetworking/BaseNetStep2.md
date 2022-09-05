<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 1&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Main Page] 

# Basic Routing Environment - Step 2

## Abstract

In this step you will configure the two routers to enable connectivity and enable BGP between them.

## Observations

Once you're done with this step, you know the basic steps to configure a Cisco router and how to enable BGP.

## Connecting to the Routers

>[!CAUTION]
>If your subscription has access restrictions that prevent SSH connections from internet based resources see the special instructions towards the end of this document.

>NOTE: The user name used is **LabUser**, this is case sensitive, please ensure you use proper case!!

To access the routers, we'll use the built-in SSH client in Windows, MAC, or Linux. To access this, open a PowerShell prompt on Windows, a Terminal session on MAC, or the command line on Linux. You'll first need the public IP address for both routers, find these in the Azure Portal.

1. Navigate to the Key Vault in your resource group, go to the Secrets blade in the Key Vault. You should see the secret "LabUser" which is the username added to both routers. Click "LabUser" and then the "Current Version" to see the attributes of this secret. At the bottom of the page is the "Secret Value", use the copy icon to copy the password to your clipboard.
2. Open two PowerShell windows (or Terminal, CLI, etc), one for each router
3. In the first window SSH to the first router (where x.x.x.x is the public IP address):
    ```powershell
    ssh LabUser@x.x.x.x
    ```
    On certain Windows versions a negotiation error may occur, you'll need to specify the Key Exchange method.
    ```powershell
    ssh -oKexAlgorithms=+diffie-hellman-group-exchange-sha1 LabUser@20.3.209.230
    ```
4. The first time you connect you'll be prompted to accept the RSA Fingerprint of the router, enter yes to accept and continue.
5. You should now be prompted for a password. If the password is in your clipboard you can right-click in your terminal window to paste in the password (no text or stars will be visible when you right-click) then press enter to continue.
6. You should now be logged in and see a prompt similar to
   ```
   Router01#
   ```
7. Repeat steps 3 thru 6 in the second window with the second router public IP to access the other router
8. You should now be connected to both routers

## Router Configuration Basics
### A word about Cisco commands
You only need to enter enough characters for the command to be unique to be successful. For instance if you to see the running configuration on the current router would you enter ```show running-config``` but you can also enter the much shorter ```sho run``` to get the same result. You can also use tab to complete the command. So you could enter ```show run``` then press tab to fill out the rest of the command to ```show running-config```.

Also the question mark is a very handy helper on the Cisco CLI. Try typing ```s``` then press ? and you'll instantly see commands that start with "s", you can also find additional commands as you type words, try this by typing "```show ```" (note the space after show) then press ?. You'll see all the things you can "show" in the Cisco IOS (the operating system), this technique is especially helpful as you type longer and longer commands some with as many as eight or nine keywords and IP addresses.

### Common Cisco Commands
| Function | Full Command | Short Hand |
|----------|--------------|------------|
| Show the running configuration | ```show running-config``` | ```sh run``` |
| Ping | ```ping x.x.x.x``` | |
| Show Interface Summary | ```show interfaces summary``` | ```sh int sum``` |
| Show Route Table | ```show ip route``` | ```sh ip route``` |
| Show BGP Summary | ```show ip bgp summary``` | ```sh ip bgp sum``` |
| Enter config edit mode | ```configure terminal``` | ```conf t``` |
| Undo a statement (must be in edit mode) | add ```no``` as a prefix to the config you wish to remove |
| Exit configuration mode | ```end``` | |
| Write unsaved changes to memory | ```copy running-config startup-config``` | ```wr``` |
| Exit the router session, i.e. log off the router | ```exit``` | |
||

## Configuring the Routers
>NOTE: before applying the config to the newly built routers, run the pre-config validation steps below to get a feel for the before and after results on the routers.

Find the private IP addresses (e.g. 10.x.x.x) for NIC1 and NIC2 of both routers in the Azure Portal, they should be the same as in the table below but depending on the deployment timing the IPs could be slightly different. It is often helpful to create a table or diagram to help visualize the addresses as they can be easy to confuse or mistype. Something like:

| Router | NIC1 | NIC2 |
|:--|:--:|:--:|
| ```Router01```| 10.10.1.4 | 10.10.2.4 |
| ```Router02```| 10.10.3.4 | 10.10.2.5 |
||

The interfaces currently have the IPs assigned from DHCP, so refer to the above table to keep them straight.

To make configuration easier, you can copy the config and right-click in the command window to paste the config in your clipboard.

In the config below:
* First we'll enter configuration mode.
* Then add the BGP settings and create the neighbor statements to let each router know about it's neighbor.
* Finally we'll get out of config mode and save our configuration.
 
With Cisco routers as soon as the statement is entered, it takes effect but the next time the router is rebooted those changes will be lost unless they are saved to the routers storage (which is why the save command is copying the "running-config" to the "startup-config")

#### Router01
``` Cisco
conf t
router bgp 65001
  address-family ipv4
   network 10.10.1.0 mask 255.255.255.0
   neighbor 10.10.2.5 remote-as 65002
   neighbor 10.10.2.5 activate
   neighbor 10.10.2.5 next-hop-self
end
wr
```

#### Router02
``` Cisco
conf t
router bgp 65002
  address-family ipv4
   network 10.10.3.0 mask 255.255.255.0
   neighbor 10.10.2.4 remote-as 65001
   neighbor 10.10.2.4 activate
   neighbor 10.10.2.4 next-hop-self
end
wr
```

## Validation
#### Before config is applied
With just the default router config, the GigabitEthernet2 interface (shorthand G2) on both routers are on the same network (10.10.2.0/24). Therefor ping should work
1. On the command line for Router01 use the ping command to ping Router02's G2 interface (10.10.2.5)
   * It may take a second for ARP to resolve, but you should eventually see a successful ping response.
2. Now run the command to see the Interface Summary on Router01.
   * You should see all zeros in the Transmit (TXBS) and Receive (RXBS) columns for Interfaces G1 and G2.
3. Run the command to see the Router01 route table.
   * You should see only local networks (ignore the 168. and 169. networks added by Azure).
   * Note the default gateway for the router (0.0.0.0/0)
   * The networks the router knows about have an "C" connected designation
   * The IP addresses are prefaced with "L" to indicate they are locally connected directly to the interface

#### After config is applied
1. On Router01 enter the command to see the BGP summary state
   * You should see the same route table with one new addition, 10.10.3.0/24 should be visible as a "B", BGP, learned route.
   * You can also see that this new prefix was learned via 10.10.2.5 which is the neighbor (Router02) on interface G2.

#### Additional Validation
You can add VMs on subnet 1 and 3, with the two routers and BGP they should be able to talk to each other (i.e. ping) through the two routers.

For this communication to work, you'll need to add UDRs or a Route Server for the traffic to flow properly. Both of these are beyond the scope of this lab, but these are both very good topics to self-study and implement if you want to get deeper into Azure networking with NVAs!

## Special Instructions for Internet Restricted Subscriptions
Some companies put additional restrictions on inbound internet traffic that can block the SSH port and prohibit accessing the NVAs on the SSH port (22).

There are often two ways around this restriction, using your corporate VPN and routing SSH via that path, or using an Azure Bastion Host. You'll need to investigate which option is best for your situation. 

>NOTE: For Microsoft employees both options work, with the VPN option being the easier option. If you're in the office you should have direct access to the Azure Public IPs without needing to add either option. However, if you are working from home you'll need one of the two following options.

**Routing via VPN**
Find the two public IPs for the NVAs.
Using the following PowerShell snippet to route traffic to those public IPs via your VPN connection.
1. Connect to your corporate VPN
2. Open an elevated PowerShell prompt (i.e. run as admin)
3. Run this command to load a variable with your VPN IP ```$VPNIP = (Get-NetIPAddress -AddressFamily IPv4 | Where {$_.InterfaceAlias -match "VPN"}).IPv4Address```
4. This command will load a variable with the first and second target IP address (the public IP of Router01 and 02) ```$TargetIP = "1.1.1.1", "2.2.2.2"``` (Where 1.1.1.1 and 2.2.2.2 are the actual public IPs of the routers)
5. Run these two commands to add the static routes to your local machine to send the public IPs to Azure via the VPN connection:
   ``` PowerShell
   route add $TargetIP[0] MASK 255.255.255.255 $VPNIP
   route add $TargetIP[1] MASK 255.255.255.255 $VPNIP
   ```

**Access via Azure Bastion Host**
1. Open the Azure Portal, navigate to your Resource Group.
3. Go to Router01, on the top button bar is a "Connect" drop-down button, click it and select the Bastion option.
4. 10.10.4.0/26 should be the next select address range for the Bastion prefix, accept whatever is there. Leave the NSG option as "none", click "Create Subnet" button.
5. In Step 3, keep all the default options and click the "Create Azure Bastion using defaults" button to start the creation process.
6. Creating the bastion host will take 10 - 15 minutes.
7. When complete, return to the connect button on the Router and select Bastion again. You should now be able to SSH (in your browser) to the router.
8. You can do the same to Router02 (once the Bastion is created it will work for all VMs and NVAs in your VNet) which will open in a new tab.

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 1&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Main Page] 

<!--Link References-->
[Prev]: ./BaseNetStep1.md
[Next]: ./README.md

<!--Image References-->
[1]: ./Media/BaseNetStep1.svg "As built diagram for step 1" 
