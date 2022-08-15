<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 2&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

# DIY Workshop Maximus - Module 2

## Abstract
This module creates a Network Security Group (NSG), a Bastion Host, and a NAT Gateway in the Hub VNet.

## Observations
Once you're done with this step, you will know how to deploy a Bastion host and NAT Gateway, and also use Bastion to securely connect to VMs.

## Deployment
1. While in the Scripts folder run
   ```powershell
   ./Module02.ps1
   ```
   > **NOTE**: You may see “warnings” from PowerShell about upcoming changes in the Azure PowerShell SDK. These warnings do not affect running of the scripts.

2. (Optional) in the editor pane you can select and view the script before running

## Validation
1. Navigate to your Resource Group in the Portal. You should now see addional resources - an NSG, a Bastion Host, and a NAT Gateway - in the Hub VNet. You should also see a public IP resource for the Bastion Host and an IP Prefix resource for NAT. 
2. Check the security rules in the NSG. Confirm that these are the default security rules.
3. Review the NAT Gateway, its IP Prefix and the subnet it is associated with.
4. Review the settings of the Bastion host.
5. Connect to the VM via Bastion using the credentials in the Key Vault. Note any active sessions on the Bastion once connect to your VM.
6. Launch a browser on the VM and connect to the web service on the local IIS server - http to the VM's private IP (e.g. http://10.0.1.4) to see the local web site.


 
## Application Diagram After this Step is Complete
[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 2&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

<!--Link References-->
[Prev]: ./Module01.md
[Next]: ./Module03.md

<!--Image References-->
[1]: ./Media/Step2.svg "As built diagram for step 2" 