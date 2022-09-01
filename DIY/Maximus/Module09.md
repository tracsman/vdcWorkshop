<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 9

# DIY Workshop Maximus - Module 9

## Abstract
In this final module, we will deploy a Route Server and an NVA (Network Virtual Appliance) in the Hub VNet to enable dynamic exchange of routes between them. The Hub NVA will be a Cisco VPN router that will establish a S2S VPN connection with the existing on-prem NVA (also a Cisco VPN router). 

## Observations
Once you're done with this step, you would have learnt how to use a Route Server to enable network virtual appliances to exchange routes dynamically with virtual networks in Azure. 

## Deployment
1. While in the Scripts folder run
   ```powershell
   ./Module09.ps1
   ```
   > **NOTE**: You may see “warnings” from PowerShell about upcoming changes in the Azure PowerShell SDK. These warnings do not affect running of the scripts.

2. (Optional) in the editor pane you can select and view the script before running

## Validation
1. Go to your resource group in the Azure Portal and check the newly added resources. You should see the Route Server and the VPN NVA along with associated resources in the Hub VNet.
2. Check out the Route Server settings. Make sure you see the Hub VPN NVA as a peer (the Provisioning State should show Succeeded).
3. Verify that the Route Server can see the on-prem routes via the VPN NVA. You can do this by looking at the PowerShell output from the Route Server. In your Cloud Shell, run the below command to confirm the route server is seeing on-prem prefixes from the Hub NVA. This indicates the Hub NVA is recieving routes from the on-prem NVA and all is working. 
  
    **Get-AzRouteServerPeerLearnedRoute -ResourceGroupName MaxLab02 -RouteServerName Hub-VNet-rs -PeerName HubNVA**
  
Look for two entries one to each instance of Route Server for the on-prem prefix (the Network field in the PS output) which is: 10.10.1.0/25





## Application Diagram After this Step is Complete
[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 9 

<!--Link References-->
[Prev]: ./Module08.md


<!--Image References-->
[1]: ./Media/Step9.svg "As built diagram for step 9" 