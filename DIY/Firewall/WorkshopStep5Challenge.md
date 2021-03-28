<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 5 (cont)&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Main Page][Next] 

# DIY Firewall Workshop - Step 5 - Optional Challenge

## Abstract
In this optional challenge step, you can take your Firewall investigation deeper and review the logs and output from the Firewall protecting your web site.

In this step you'll hook up your Firewall output to your Log Analytics workspace and review the logged output.

## Deployment
### Turn on and review monitoring
1. In the portal open the firewall
1. Click the “Diagnostic settings” tab
1. Click the “Turn on diagnostic” link
1. Name your setting “Firewall-Logs”
1. Check “Send to Log Analytics”
1. Select your Company’s workspace
1. Check both log types and save
   > **NOTE** It may take up to 10 minutes for logs to begin flowing into the log workspace. Thereafter logs should show up, near real-time, in about 1 minute after the event.

## Validation
1. In the portal, pull up the Firewall
2. Review the Rules section
3. From a browser hit the public IP of the firewall (it will NAT to the IIS server and provide a web page)
   > **NOTE** When browsing today be sure to use HTTP, not HTTPS. I’m too lazy to create certs. :)

4. (optional challenge) Add a Firewall rule to allow RDP to the Jump box. Then RDP to the Jump VM and hit the private IP of the IIS server (the firewall network rules should allow the page to be visible)

## Application Diagram After this Step is Complete
[![1]][1]


<!--Link References-->
[Prev]: ./WorkshopStep5.md
[Next]: ./README.md

<!--Image References-->
[1]: ./Media/Step5.svg "As built diagram for step 5" 