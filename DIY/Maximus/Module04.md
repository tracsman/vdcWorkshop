<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 4&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

# DIY Workshop Maximus - Module 4

## Abstract
In this step you will create your first spoke VNet (Spoke01) and peer it with the hub VNet you worked on in the previous steps. You will deploy a web farm using the Azure App Gateway (Application Load Balancer) service in the spoke VNet. The web farm will comprise of 3 identical IIS servers (running on 3 VMs) and will serve a web page for external access. 

## Observations
Once you're done with this step, you would have learned how to setup VNet peering and use an application load balancer to distribute traffic across backend web servers. 

## Deployment
1. While in the Scripts folder run
   ```powershell
   ./Module04.ps1
   ```
2. (Optional) in the editor pane you can select and view the script before running

## Validation
1. In the portal, review the settings of the spoke VNet and its peering with the hub VNet.
2. Review the 3 spoke VMs and the effective routes on each VM's NIC.
3. Check the App Gateway settings for your new web farm in the default backend pool. 
4. Note the public IP of the App Gateway (AppGatewayPIP) and  navigate to it from an external browser. Note the web page contents across different sections including the VM instance that is serving the contents. Contents that are unreachable will surface in subsequent modules.  
5. Also note the App Gateway settings for another backend pool on a remote site.
6. Navigate to http://<AppGatewayPIP>/headers to have the App Gateway redirect to this backend pool on the remote site.
7. Note the UDR in the Spoke1-Tenant subnet with the default route pointing to the Firewall as the next hop. 
8. Check out the WAF Policy on the App Gateway. Note the Managed Rules for threat protection. Also note the Custom Rule that blocks traffic originating from Australia region. You can try https://geopeeker.com/fetch/?url=<AppGatewayPIP> to see the effect of this rule. 

## Application Diagram After this Step is Complete
[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 4&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

<!--Link References-->
[Prev]: ./Module03.md
[Next]: ./Module05.md

<!--Image References-->
[1]: ./Media/Step4.svg "As built diagram for step 4" 