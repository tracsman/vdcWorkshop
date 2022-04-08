<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 4&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

# DIY Workshop Maximus - Module 4

## Abstract
In this step we'll create a web farm using the Azure App Gateway service. The web farm will comprise of IIS servers running on 3 VMs in a spoke VNet (spoke01). This spoke VNet will peer with the hub VNet you worked on in the previous steps.

## Observations
Once you're done with this step, you would have learned how to setup VNet peering and use an application load balancer to distribute traffic across backend web servers. 

## Deployment
1. While in the Scripts folder run
   ```powershell
   ./Module04.ps1
   ```
2. (Optional) in the editor pane you can select and view the script before running

## Validation
1. In the portal, review the settings of the Spoke VNet (Spoke01) and its peering with the hub VNet.
2. Review the 3 spoke VMs and the effective routes on each VM's NIC.
3. Check the settings of your new web farm by going to your App Gateway. Note the public IP of the App Gateway (AppGatewayPIP).
4. Navigate to http://AppGatewayPIP/headers to have App Gateway redirect to another backend pool on a remote site.
5. Also review the WAF Rules and UDR settings on the Spoke01 vnet.

## Application Diagram After this Step is Complete
[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 4&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

<!--Link References-->
[Prev]: ./Module03.md
[Next]: ./Module05.md

<!--Image References-->
[1]: ./Media/Step4.svg "As built diagram for step 4" 