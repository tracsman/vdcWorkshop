<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 2&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

# DIY Firewall Workshop - Step 2

## Abstract
In this step a VNet is deployed, it's the most basic resource into which other Azure IaaS resources (and VNet enabled PaaS services) are deployed.

## Observations
Once you're done with this step, you will see a network in Azure to which you can now deploy resources with three subnets.

## Deployment
1. While in the Scripts folder run
   ```powershell
   ./WorkshopStep2.ps1
   ```
   > **NOTE**: You may see “warnings” from PowerShell about upcoming changes in the Azure PowerShell SDK. These warnings do not affect running of the scripts.

2. (Optional) in the editor pane you can select and view the script before running

## Validation
1. Navigate to the VNet in the Portal
2. Review the subnets
3. You should see three subnets

   >**NOTE** The subnet address ranges are "carved out" from the Address Space range. When this VNet is connected to services where the IP addresses are shared, like ExpressRoute, VPN, or VNet Peering the Address Range is what is shared not the individual subnets.

## Application Diagram After this Step is Complete
[![1]][1]


<!--Link References-->
[Prev]: ./WorkshopStep1.md
[Next]: ./WorkshopStep3.md

<!--Image References-->
[1]: ./Media/Step2.svg "As built diagram for step 2" 