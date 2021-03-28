<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 5&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

# DIY Firewall Workshop - Step 5

## Abstract
In this final step, a new "spoke" VNet is created and peered with the hub. A VM is created in that spoke VNet. NAT, Application, and Network Rules are applied to the Firewall. IIS and a simple web site is installed in the new VM. UDR rules are added and a log analytics workspace is created.

## Observations
Once you're done with this step, 

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

4. (optional challenge) Add a Firewall rule to allow RDP to the Jump box. Then RDP to the Jump VM and hit the private IP of the IIS server (the firewall network rules should allow the page to be visible)

## Application Diagram After this Step is Complete
[![1]][1]


<!--Link References-->
[Prev]: ./WorkshopStep4.md
[Next]: ./WorkshopStep5Challenge.md

<!--Image References-->
[1]: ./Media/Step5.svg "As built diagram for step 5" 