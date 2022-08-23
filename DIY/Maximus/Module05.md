<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 5&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

# DIY Workshop Maximus - Step 5

## Abstract
In this step, a second spoke VNet (Spoke02) is created and peered with the hub. A VM Scale Set comprising of 2 VM instances is deployed behind a network load balancer in the spoke VNet.

## Observations
Once you're done with this step, you would have learned how to configure a network load balancer with a backend pool of VMs in a VM Scale Set.



## Deployment
1. While in the Scripts folder run
   ```powershell
   ./Module05.ps1
   ```
2. (Optional) in the editor pane you can select and view the script before running

## Validation
1. In the portal, review the settings of the new spoke VNet (Spoke02) and its peering with the hub VNet.
2. Review the settings of the Network Load Balancer and the VM Scale Set (VMSS) including the VM instances.
3. From a browser hit the public IP of the App Gateway again and notice the contents of a file served by a file server running on one of the VM instances in the VMSS. It is important to understand that the web service in Spoke01 utilizes the VNet peering via the Hub to fetch the file contents from the file server in Spoke02. The Firewall in the Hub VNet acts as the person-in-the-middle. 
 

## Application Diagram After this Step is Complete
[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 5&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

<!--Link References-->
[Prev]: ./Module04.md
[Next]: ./Module06.md

<!--Image References-->
[1]: ./Media/Step5.svg "As built diagram for step 5"
[2]: ./Media/UDR.svg "View of UDR assignments to the subnets" 