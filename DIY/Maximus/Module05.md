<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 5&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

# DIY Workshop Maximus - Step 5

## Abstract
In this step, a new spoke VNet (Spoke02-VNet) is created and peered with the hub. VM Scale Set with 2 instances is deployed behind a network load balancer in the spoke VNet.

## Observations
Once you're done with this step, you would have learned how to scale VM instances using VM Scale Sets.



## Deployment
1. While in the Scripts folder run
   ```powershell
   ./Module05.ps1
   ```
2. (Optional) in the editor pane you can select and view the script before running

## Validation
1. In the portal, review the settings of the new spoke VNet and its peering with the hub VNet.
2. Review the settings of the Load Balancer and the VM Scale Set including the VM instances.
3. From a browser hit the public IP of the App Gateway and notice the contents from one of the VM instances in the VMSS. 
 

## Application Diagram After this Step is Complete
[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 5&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

<!--Link References-->
[Prev]: ./Module04.md
[Next]: ./Module06.md

<!--Image References-->
[1]: ./Media/Step5.svg "As built diagram for step 5"
[2]: ./Media/UDR.svg "View of UDR assignments to the subnets" 