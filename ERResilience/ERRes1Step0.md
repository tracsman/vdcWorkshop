[Main Page][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 0&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >>

# ExpressRoute Resiliency Workshop Part 1 - Cloud Shell Initialization (Step 0)

## Abstract

[Azure Cloud Shell][CloudShell] is an interactive, authenticated, browser-accessible shell for managing Azure resources. It provides the flexibility of choosing the shell experience that best suits the way you work, either Bash or PowerShell. We'll be using the Cloud Shell for the deployment of PowerShell scripts to build today's environment. Using the Cloud Shell provides a unified foundation to interact with Azure with all the PowerShell settings and Azure SDKs loaded, so you can start the shell and immediately begin interacting with Azure.

This initialization step (step 0) of the workshop has you start the Cloud Shell, ensure you're using the PowerShell experience, and download the Workshop files.

## Observations

Once you're done with this step, you'll know more about the Azure Cloud Shell and how to get started with it.

## Deployment

1. Connect to the internet
2. Login to https://portal.azure.com
3. Start Cloud Shell (select or create a storage account if prompted)

    [![1]][1]
4. Ensure Cloud Shell is set to PowerShell

    [![2]][2]
5. In Cloud Shell run the following to download the workshop files

    ```powershell
    (IWR aka.ms/1).Content | IEX
    ```

    > **NOTE**
    > A warning about the subscription ID will be shown, we’ll fix this next

6. You will be prompted for a two digit "Company Number", this will be provided by your instructor.
7. Now you can run the validation script, ensuring no errors and that the initialization variables are set as intended.

    ```powershell
    ./Scripts/Validate-Lab.ps1
    ```

8. In the portal above the CloudShell window, navigate to your Company## (## was be suplied by your intstructor). You'll see the initial resources configured before hand for your lab.

## Application Diagram After this Step is Complete

[![4]][4]

[Main Page][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 0&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >>

<!--Link References-->
[Prev]: ./README1.md
[Next]: ./ERRes1Step1.md
[CloudShell]: https://docs.microsoft.com/azure/cloud-shell/overview

<!--Image References-->
[1]: ./Media/CloudShellLaunch.svg "Launch Cloud Shell Icon"
[2]: ./Media/CloudShellPowerShell.svg "Set Cloud Shell to PowerShell"
[3]: ./Media/CloudShellNano.png "Cloud Shell Nano file editor"
[4]: ./Media/ERRes1Step0.svg "The initial As built resource group, two hub/spoke in two regions with local ER Circuits"
