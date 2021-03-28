<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 3&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

# DIY Firewall Workshop - Step 3

## Abstract
In this step a VM, NIC, and Public IP are deployed to your VNet.

## Observations
Once you're done with this step, you will know how to deploy a simple, publicly accessible VM into a VNet in Azure.

## Deployment
1. While in the Scripts folder run
   ```powershell
   ./WorkshopStep3.ps1
   ```
2. (Optional) in the editor pane you can select and view the script before running

## Validation
1. Review the VM components
2. (optional) RDP to the VM’s Public IP using the User01 password from the Key Vault secret


## Application Diagram After this Step is Complete
[![1]][1]


<!--Link References-->
[Prev]: ./WorkshopStep2.md
[Next]: ./WorkshopStep4.md

<!--Image References-->
[1]: ./Media/Step3.svg "As built diagram for step 3" 