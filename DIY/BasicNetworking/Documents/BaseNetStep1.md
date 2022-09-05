<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 1&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

# Basic Routing Environment - Step 1

## Abstract

In this step we change to the Scripts directory and execute the Step 1 PowerShell Script.

The Step 1 Script will create a Resource Group in the subscription you added in the init.txt in the last step. It will then create a Key Vault resource and add three secrets that represent usernames and passwords that will be added to the routers created. Then two routers will be deployed.

## Observations

Once you're done with this step, you will see a Resource Group in Azure with two Cisco routers and a Key Vault with secrets to access those routers.

## Deployment

1. Change to the Scripts folder

    ```powershell
    cd Scripts
    ```

2. (Optional) in the editor pane you can select and view the script before running
3. Run workshop script 1 with the following:

    ```powershell
    ./BaseNetworkStep1.ps1
    ```

## Validation

1. Browse to your Resource Group in the Portal
2. You should see a Key Vault resource
3. Explore the Key Vault, and the secrets therein

## Application Diagram After this Step is Complete

[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 1&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

<!--Link References-->
[Prev]: ./BaseNetStep0.md
[Next]: ./BaseNetStep2.md

<!--Image References-->
[1]: ./Media/BaseNet.svg "As built diagram of the environment" 