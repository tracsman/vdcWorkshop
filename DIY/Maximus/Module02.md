<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 2&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

# DIY Workshop Maximus - Module 2

## Abstract
This module creates an NSG, a public IP for Bastion, an IP Prefix for NAT, a NAT Gateway, and a Bastion host.

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
1. Navigate to your Resource Group in the Portal. You should now see an NSG, a public IP for Bastion, an IP Prefix for NAT, a NAT Gateway, and a Bastion host. 
2. Check the security rules in the NSG.
3. Review the NAT Gateway, its IP Prefix and the subnet it is associated with.
4. Review the Bastion host and note any active sessions once you use it to connect to your VM.
5. Connect to the VM via Bastion using the credentials in the Key Valut.



## Application Diagram After this Step is Complete
[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 2&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

<!--Link References-->
[Prev]: ./Module01.md
[Next]: ./Module03.md

<!--Image References-->
[1]: ./Media/Step2.svg "As built diagram for step 2" 