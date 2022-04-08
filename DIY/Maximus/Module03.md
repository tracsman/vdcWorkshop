<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 3&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

# DIY Workshop Maximus - Module 3

## Abstract
In this step we'll create and configure the Azure Firewall. We will define a firewall policy with DNAT, Network, and Application rules. We will also add a User Defined Route (UDR) to force traffic to flow via the Firewall. We will also create a log analytics workspace to capture the firewall logs.

## Observations
Once you're done with this step, you will have protected your resources from the Internet by directing traffic via the Firewall.

## Deployment
1. While in the Scripts folder run
   ```powershell
   ./Module03.ps1
   ```
2. (Optional) in the editor pane you can select and view the script before running

## Validation
1. In the portal, pull up the Firewall and review the configuration including its SKU, public and private IP.
2. Review the firewall policy rules (DNAT, Network, and Application rules).
3. From a browser on an external machine, go to the public IP of the firewall and confirm that you are able to view the web site. Note that the firewall's DNAT rule is translating http traffic destined to the firewall's public IP to your VM's private IP. 
4. Note the UDR in the VM subnet with the default route pointing to the Firewall as the next hop.
4. Check the effective routes on the VM NIC. 
5. (Optional) Add Application rules to the firewall to surf to specific web sites from your VM.


## Application Diagram After this Step is Complete
[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 3&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

<!--Link References-->
[Prev]: ./Module02.md
[Next]: ./Module04.md

<!--Image References-->
[1]: ./Media/Step3.svg "As built diagram for step 3" 