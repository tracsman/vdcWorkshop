[Main Page][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 0&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >>

# ExpressRoute Resiliency Workshop Part 1 - Cloud Shell Initialization (Step 0)

## Abstract

[Azure Cloud Shell][CloudShell] is an interactive, authenticated, browser-accessible shell for managing Azure resources. It provides the flexibility of choosing the shell experience that best suits the way you work, either Bash or PowerShell. We'll be using the Cloud Shell for the deployment of PowerShell scripts to build today's environment. Using the Cloud Shell provides a unified foundation to interact with Azure with all the PowerShell settings and Azure SDKs loaded, so you can start the shell and immediately begin interacting with Azure.

This initialization step (step 0) of the workshop has you start the Cloud Shell, ensure you're using the PowerShell experience, and download the Workshop files.

## Observations

Once you're done with this step, you'll know more about the Azure Cloud Shell and how to get started with it.

## Deployment

1. Connect to the internet
1. Login to <https://portal.azure.com> using the @LODSPRODMCA account and password in the Resource section of workshop portal.
1. In the "Search Resources" search box, search and select "Resource Groups".
1. You should see a Resource Group entitled CompanyXX (where XX is a two digit number between 12 and 32). Remember this number, it's used many times in many places throughout this workshop!
1. Start Cloud Shell (select or create a storage account if prompted)

    ![1]
1. If prompted, select PowerShell, or if the window says "Switch to PowerShell" do so.

    ![2]
1. If prompted to select a Storage Account, ensure "No storage account required" is selected, and that you pick the "Tech Connect 2025 ExpressRoute subscription" from the subscription dropdown and then click "Apply"

    ![3]
1. In Cloud Shell run the following to download the workshop files

    ```powershell
    (IWR aka.ms/1).Content | IEX
    ```

    > **NOTE**
    > A warning about the subscription ID will be shown, we’ll fix this next

1. You will be prompted for a two digit "Company Number", this is the number discovered in Step 3 above.
1. Now you can run the validation script, ensuring no errors and that the initialization variables are set as intended.

    ```powershell
    ./Scripts/Validate-Lab.ps1
    ```

1. In the portal above the CloudShell window, navigate to your Company## (## was discovered in Step 3 above). You'll see the initial resources configured before hand for your lab.

## Application Diagram After this Step is Complete

[![4]][4]

[Main Page][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 0&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >>

<!--Link References-->
[Prev]: ./README1.md
[Next]: ./ERRes1Step1.md
[CloudShell]: https://docs.microsoft.com/azure/cloud-shell/overview

<!--Image References-->
[1]: ./Media/CloudShellIcon.png "Launch Cloud Shell Icon"
[2]: ./Media/CloudShellPrompt.png "Set Cloud Shell to PowerShell"
[3]: ./Media/CloudShellStorage.png "Cloud Shell Storage Prompt"
[4]: ./Media/ERRes1Step0.svg "The initial As built resource group, two hub/spoke in two regions with local ER Circuits"
