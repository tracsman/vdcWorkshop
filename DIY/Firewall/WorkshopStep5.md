<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 5&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

# DIY Firewall Workshop - Step 5

## Abstract
In this final step, a new "spoke" VNet is created and peered with the hub. A VM is created in that spoke VNet. NAT, Application, and Network Rules are applied to the Firewall. IIS and a simple web site is installed in the new VM. UDR rules are added and a log analytics workspace is created.

## Observations
Once you're done with this step, you'll have accomplished the basic goal of this workshop, getting a web site online behind an Azure firewall.

An important understanding to take away from this step is how the UDR rules are affecting traffic.
[![2]][2]

The simplest UDR rule is the UDR table for the Tenant subnets. 0.0.0.0/0 to the firewall and stop BGP propagation.
0.0.0.0/0 this is the most generic IP rule, saying if nothing more specific is found in the local route table for the NIC, this is the route "of last resort".
If BGP is allowed to flow to the subnet, you'll have more specific rules in the route table, then the 0.0.0.0/0 rule wouldn't be used. Turning of BGP ensures no other routes become "local" and the traffic is always sent to the firewall.

On the gateway subnet, the rules aren't that simple. If this environment had VPN or ExpressRoute enabled, this subnet would need to be the gateway to other networks. If we used the 0.0.0.0 rule here, the VPN Gateway would form a routing loop with the firewall, never sending anything to on-premises because the 0.0.0.0 rules says *always* send to the firewall. So the rule for the gateway subnet has to be tailored for your cloud network. There are two address prefixes (10.11.12.0/25 and 10.11.12.128/25), basically saying anything coming into this subnet going to a cloud resource should be sent to the firewall for evaluation first, however anything heading to on-prem (an address that doesn't match any addresses in the UDR table) would be allowed to travel normally. For our lab, all traffic come to the gateway subnet should be coming from the firewall as the 0.0.0.0 rule on the other subnets would never send traffic directly to the gateway subnet.

On the Firewall subnet, you'll see there are no UDRs. The firewall holds the policy for the entire network, and needs access to all subnets and so we don't apply any special routing for our deployment today.

## Deployment
1. While in the Scripts folder run
   ```powershell
   ./WorkshopStep5.ps1
   ```
2. (Optional) in the editor pane you can select and view the script before running

## Validation
1. In the portal, pull up the Firewall
2. Review the Rules section
3. From a browser hit the public IP of the firewall (it will NAT to the IIS server and provide a web page)
   > **NOTE** When browsing today be sure to use HTTP, not HTTPS. I’m too lazy to create certs. :)

4. (optional challenge) Access your web page via the web server private IP
   - Add a Firewall rule to allow RDP to the Jump box
   - RDP to the Jump VM
   - Use the browser to hit the private IP of the IIS server (the firewall network rules should allow the page to be visible)

## Application Diagram After this Step is Complete
[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 5&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

<!--Link References-->
[Prev]: ./WorkshopStep4.md
[Next]: ./WorkshopStep5Challenge.md

<!--Image References-->
[1]: ./Media/Step5.svg "As built diagram for step 5"
[2]: ./Media/UDR.svg "View of UDR assignments to the subnets" 