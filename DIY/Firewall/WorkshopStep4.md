<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 4&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

# DIY Firewall Workshop - Step 4

## Abstract
In this step we'll create and configure the basic Azure Firewall and add a single network rule as well as add a User Defined Route (UDR) to change the flow of traffic to force it to the Firewall.

## Observations
Once you're done with this step, you will have just protected your resources from the Internet by cutting connectivity from the VM's Public IP to the VM.

## Deployment
1. While in the Scripts folder run
   ```powershell
   ./WorkshopStep4.ps1
   ```
2. (Optional) in the editor pane you can select and view the script before running

## Validation
1. In the portal, pull up the Firewall
2. Review the Firewall properties, especially the Rules section.
3. (optional) Try RDPing to your Azure VMs public IP, because we don’t have a rule for that, it will fail.

## Application Diagram After this Step is Complete
[![1]][1]


<!--Link References-->
[Prev]: ./WorkshopStep3.md
[Next]: ./WorkshopStep5.md

<!--Image References-->
[1]: ./Media/Step4.svg "As built diagram for step 4" 