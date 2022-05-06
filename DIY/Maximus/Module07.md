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
2. You should see a VPN Gateway in the hub along with other associated resources. You should also see several on-prem and coffee shop resources.
3. Go to the hub VPN Gateway and check out its settings. Notice the status of the Site-to-Site connection (it should show 'Connected').
4. Go to the on-prem network Gateway and check out its settings. Notice the status of the same Site-to-Site connection (it should show 'Connected').
5. Connect to the on-prem VM via Bastion.
6. Verify that you have reachability (over VPN) to the hub. You can run a ping to the Firewall IP (10.0.3.4) in the hub.



## Application Diagram After this Step is Complete
[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 7&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

<!--Link References-->
[Prev]: ./Module06.md
[Next]: ./Module08.md

<!--Image References-->
[1]: ./Media/Step7.svg "As built diagram for step 6" 