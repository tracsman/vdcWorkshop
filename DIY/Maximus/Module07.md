<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 7&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

# DIY Workshop Maximus - Module 7

## Abstract
In this module, we will simulate on-prem and remote user connectivity over VPN. We will create an "on-prem" VNet and connect it to a VPN gateway in the hub over Site-to-Site VPN. We will also create a "coffee shop" VNet (remote user) and connect it to the same VPN gateway in the hub over Point-to-Site VPN. 

## Observations
Once you're done with this step, you would have learnt to deploy Site-to-Site and Point-to-Site VPN connectivity.

## Deployment
1. While in the Scripts folder run
   ```powershell
   ./Module07.ps1
   ```
   > **NOTE**: You may see “warnings” from PowerShell about upcoming changes in the Azure PowerShell SDK. These warnings do not affect running of the scripts.

2. (Optional) in the editor pane you can select and view the script before running

## Validation
1. Go to your resource group in the Azure Portal and check the newly added resources.
2. You should see a VPN gateway in the hub VNet along with other associated resources. You should also see several on-prem and coffee shop resources.
3. Go to the hub VPN gateway and check out its settings. Notice the status of the Site-to-Site connection (it should show 'Connected').
4. Go to the on-prem local network gateway and check out its settings. The on-prem local network gateway represents the on-prem VPN router. Notice the same Site-to-Site connection and its status (it should show 'Connected').
5. Connect to the on-prem VM via Bastion. 
   1. Verify that you have reachability (over S2S VPN) from the on-prem VM to the hub. You can run a ping to the Test VM (10.0.1.4) or to the Firewall (10.0.3.4) in the hub.
   2. Also navigate to the App Gateway IP again from the browser to access the web page. Make sure it displays contents from the IIS server in Spoke01, VMSS file server in Spoke02, and PaaS storage account via the Private Endpoint.
6. To validate the P2S connection, you'll need to RDP (via Bastion) to the          Coffee Shop VM and then manually connect the VPN connection named "AzureHub". When uou hit the "Connect" button, the P2S connection will use a local certificate and the connection should be successful.
   1.  1. Verify that you have reachability (over P2S VPN) from the coffee shop VM to the hub. You can run a ping to the Test VM (10.0.1.4) or to the Firewall (10.0.3.4) in the hub.
   2. Also navigate to the App Gateway IP again from the browser to access the web page. Make sure it displays contents from the IIS server in Spoke01, VMSS file server in Spoke02, and PaaS storage account via the Private Endpoint.                                              
  certificate and the connection should be successful.    




## Application Diagram After this Step is Complete
[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 7&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

<!--Link References-->
[Prev]: ./Module06.md
[Next]: ./Module08.md

<!--Image References-->
[1]: ./Media/Step7.svg "As built diagram for step 7" 