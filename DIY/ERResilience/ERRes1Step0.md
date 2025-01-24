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
5. In the cloud shell run

   ```powershell
   Connect-AzAccount -UseDeviceAuthentication
   ```

   and follow the instructions. Login using your Azure Portal credentials
6. In Cloud Shell run the following to download the workshop files

    ```powershell
    (IWR aka.ms/1).Content | IEX
    ```

    > **NOTE**
    > A warning about the subscription ID will be shown, we’ll fix this next

7. Open the Cloud Shell editor (red circled icon)

    [![3]][3]
8. Navigate to init.txt (red boxed item in file hierarchy in the image above)
9. In the right-hand pane, verify the Subscription ID matches the one provided by your instructor and update the RGName to use the resource group name provided by your instructor. It should be something like Company10, where 10 is your assigned number.
    > **IMPORTANT**
    >
    > The script in this workshop pulls critical information from the init.txt file, so it’s important to update this file to reflect the resource group name and subscription you’ll be using for this deployment of the workshop.  
10. Once updated, press CTRL+S to save the init.txt file.
11. Rerun the validation script, ensuring no errors and that the File Variables displayed are as intended.

    ```powershell
    ./Scripts/Validate-Lab.ps1
    ```

[Main Page][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 0&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >>

<!--Link References-->
[Prev]: ./README1.md
[Next]: ./ERRes1Step1.md
[CloudShell]: https://docs.microsoft.com/azure/cloud-shell/overview

<!--Image References-->
[1]: ./Media/CloudShellLaunch.svg "Launch Cloud Shell Icon"
[2]: ./Media/CloudShellPowerShell.svg "Set Cloud Shell to PowerShell"
[3]: ./Media/CloudShellEditor.svg "Open Cloud Shell file editor"
