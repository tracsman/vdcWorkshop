<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 1&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

# DIY Workshop Maximus - Module 1

## Abstract
In this step we change to the Scripts directory and execute the Step 1 PowerShell Script. This establishes the pattern for all future steps in this workshop.

The Step 1 Script will create a Resource Group in the subscription you added in the init.txt in the last step. It will then create a Key Vault resource and add three secrets that represent usernames and passwords that will be added to all VMs created in the workshop.


## Observations
Once you're done with this step, you will see a Resource Group in Azure to which you can now deploy resources, and a Key Vault with secrets.

## Deployment
1. Change to the Scripts folder
    ```powershell
    cd Scripts
    ```
2. (Optional) in the editor pane you can select and view the script before running
3. Run workshop script 1 with the following:
    ```powershell
    ./WorkshopStep1.ps1
    ```
## Validation
1. Browse to your Resource Group in the Portal
2. You should see a Key Vault resource
3. Explore the Key Vault, and the secrets therein

## Application Diagram After this Step is Complete
[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 1&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

<!--Link References-->
[Prev]: ./Module00.md
[Next]: ./Module02.md

<!--Image References-->
[1]: ./Media/Step1.svg "As built diagram for step 1" 