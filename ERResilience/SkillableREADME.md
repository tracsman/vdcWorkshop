@lab.Title

## Disclaimer

Please be advised that the live lab environment may be impacted by ongoing product/feature updates. This may result in discrepancies between lab instructions and the interface.

## Abstract

This lab will walk through the steps needed to setup a maximum resiliency configuration for two pre-existing hub and spoke. There are pre-created resources to allow us to get to the heart of the operations without delaying for resources to be built. We'll then explore new ExpressRoute functionality to get insight into our resiliency and then actually test out a real fail over.

## Workshop Prerequisites

You must log into the Skillable VM presented in the left pane of this browser window.
The "Resources" Tab of this instruction pane, contains the accounts and URL to get started.

Logging in:

- Click the "Resources" tab
- In the Win11-Pro-Base frame, click the little keyboard icon next to your password. This will auto-type the password into the VM Password prompt
- Click the -> or press enter to log in to the VM.
- If a PC Set up warning pops when the desktop appears, click "remind me in 3 days" on the PC setup windows
- Open Edge Browser
- Click "Confirm" to set as default browser
- Maximize the browser full screen
- Enter the Azure Portal URL in the Browser, make sure you're in the VMs browser and not your local machine's browser to bring up the Azure Portal.
- When asked to log in to the Azure Portal user the @LODSPRODMCA username (click the field to auto-type it), and click next
- The second screen is for a TAP (Temp Access Pass), not a password, use the TAP value in the Resources Tab. again, just click the TAP to autotype it in the browser.
- Click "Sign-in"
- If asked to stay signed in, click Yes, but this isn't really important.
- You can now continue with the next page of this workshop.

## Workshop Proposed Agenda

- Review the existing deployment, understand what and where the resources are
- Discuss the ExpressRoute resiliency options: Standard, High, and Maximum
- Add connections to your deployment to reach "Max" Resiliency on ExpressRoute
- Use a new feature to "fail" your ExpressRoute in Seattle, and watch the traffic failover to DC and maintain connectivity.

The individual scripts and steps for this lab are located on GitHub, follow this link to access them: [https://github.com/tracsman/vdcWorkshop/tree/main/ERResilience](https://github.com/tracsman/vdcWorkshop/blob/main/ERResilience/README1.md)

To begin the lab, click the "next >" button at the bottom right corner of these instructions.

===

# Step 0 - Cloud Shell Initialization

## Cloud Shell Abstract

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

    !IMAGE[CloudShellPrompt.png](instructions313701/CloudShellIcon.png)
1. If prompted, select PowerShell, or if the window says "Switch to PowerShell" do so.

    !IMAGE[CloudShellPrompt.png](instructions313701/CloudShellPrompt.png)
1. If prompted to select a Storage Account, ensure "No storage account required" is selected, and that you pick the "Tech Connect 2025 ExpressRoute subscription" from the subscription dropdown and then click "Apply"

    !IMAGE[CloudShellStorage.png](instructions313701/CloudShellStorage.png)
1. In Cloud Shell run the following to download the workshop files

    ```powershell
    (IWR aka.ms/1).Content | IEX
    ```

    > **NOTE**
    > Use the "Type" button above the PowerShell line to auto-type this line into your cloud shell in the VM.

1. Now you can run the validation script, ensuring no errors and that the initialization variables are set as intended.

    ```powershell
    ./Scripts/Validate-Lab.ps1
    ```

1. In the portal above the CloudShell window, navigate to your Company## Resource Group (## was discovered above). You'll see the initial resources pre-configured for your lab.

## Application Diagram After this Step is Complete

![ERRes1Step0.svg](instructions313701/ERRes1Step0.svg)

<!--Link References-->
[CloudShell]: https://docs.microsoft.com/azure/cloud-shell/overview

===

# Step 1 - Create Meshed ER Connections

## Step 1 Abstract

In this step we change to the Scripts directory and execute the Step 1 PowerShell Script.

The Step 1 Script will create a "bow tie" of connections between the East and West ExpressRoute gateways and Seattle and Ashburn ExpressRoute circuits. By "meshing" (connecting all circuits and gateways together) we'll have a max resiliency configuration. In this config, a failure of either circuit or peering location (e.g. the physical building) will not take down connectivity to either Azure region, although latency will likely increase due to the increased physical path distance.

## Observations

Once you're done with this step, you will see your Resource Group with an east and west hub and spoke configuration, now with the addition of two new connection objects, West US to Ashburn, and East US to Seattle.

## Deployment

1. In your CloudShell PowerShell prompt, change to the Scripts folder

    ```powershell
    cd ./Scripts/
    ```

2. (Optional) on the GitHub web site you can review the [Step 1][Step1] script before running.
3. Run workshop script 1 with the following:

    ```powershell
    ./ER1WorkshopStep1.ps1
    ```

4. Once the script completes, you may close the CloudShell if you wish, the remainder of this lab will be completed in the Azure Portal section.

## Validation

1. Browse to your Resource Group in the Portal
2. You should see two new connection objects (C10e-VNetHub-gw-er-conn-SEA and C10w-VNetHub-gw-er-conn-DC)
3. Explore the route table of each ExpressRoute circuit, ensure you have the address prefixes for both Azure Region VNets in both ER Circuits. You can also use the resource visualizer to see the new connections "meshing" the Gateways and Circuits together.

    ### West Circuit Route Table

    | VNet       | IP Address Range |
    |------------|------------------|
    | On-premise | 10.3.xx.0.25     |
    | West Hub   | 10.17.xx.0/24    |
    | West Spoke | 10.18.xx.0/24    |
    | East Hub   | 10.10.xx.0/24    |
    | East Spoke | 10.11.xx.0/24    |

    This shows that we now have reachability across country if either edge site fails. A similar route table can be seen on the East Circuit Route Table.

## Application Diagram After this Step is Complete

![ERRes1Step1.svg](instructions313701/ERRes1Step1.svg)

<!--Link References-->
[Step1]: https://github.com/tracsman/vdcWorkshop/blob/main/ERResilience/Scripts/ER1WorkshopStep1.ps1

===

# Step 2 - Fail Seattle Traffic

## Step 2 Abstract

Review routes and resiliency status in "Resilience Insights", then use "Resiliency Validation" to fail the Seattle ER circuit and validate traffic flows through Ashburn. This step is all performed in the portal, no scripts are used in this step.

## Observations

1. Initially, you'll see latency around 6ms
1. You'll notice in "Resiliency Insights" a route mismatch in the DC Circuit. Clicking on Route Set-1, you'll see the on-prem route healthy coming from both circuits. But Route Set-2 shows some routes that are only coming from the DC Circuit.
1. Once the "Resiliency Validation" test is started, failing the Seattle circuit, you'll see traffic switch to the DC circuit, this will be indicated by the increased latency.

## Deployment

> **NOTE**
> To make finding resources easier, you can add "xxe" or "xxw" to the resource group filter field (e.g. 10w for company 10 in the West US 2 region)

1. Open two browser tabs, both pointing to your Company Resource Group
1. In the first tab, navigate to the User01 password in the secrets store in your company Key Vault.
1. In the second tab, navigate to your West Spoke VM, named Cxxw-VNetSpoke1-VM01, where xx = your company number.
1. In the left nav for the VM, select Help, then Serial Console
    > **NOTE**
    > You may get a couple of information warnings, just click on the "enable Azure Serial Console" message to enable it
    > !IMAGE[ConsoleError.png](instructions313701/ConsoleError.png)

1. Use the username "User01" and the password from the Key Vault to log in
1. Once at the Linux command line ping your Seattle On-Prem VM (replace the "x" with your Company number)

    ```bash
    ping 10.3.x.10
    ```

1. This will run a constant ping, make note of the latency as this will change when we fail the Seattle Circuit
1. In the other Azure Portal Tab, navigate to the West US 2 ExpressRoute Gateway (cXXw-VNetHub-gw-er)
1. On the left nav, Click into "Resiliency Insights". Review the data presented.
1. To test resiliency, on the left nav, click "Resiliency Validation".
1. On the row for the Seattle circuit, click "Configure New Test", note the data presented for confirmation. Seeing the "Route Redundancy" section is green says when we fail over, the traffic should continue to work.

> **NOTE**
> This will STOP THE DATA PATH for the Seattle circuit, this isn't a simulation, it will really stop, so three warnings are needed to be acknowledged to ensure you don't inadvertently take down production traffic.

12. Read and acknowledge both warnings (ie check both  boxes) and enter the full name of the gateway in the text box. Click the "Start Simulation."
1. Change back to the other browser tab and watch the ping latency, after about a minute, the circuit will be down and latency should jump significantly.
1. Shortly both legs of the Seattle circuit will not longer have BGP running, this simulates a total outage of the Seattle edge site. Back at the Linux VM you should now see the ping successful but with a much larger latency as traffic is now going from West US 2 to Washington DC and then back to Seattle on-prem (via the CompanyXX WAN outside of Azure)

### Optional Steps

1. On the Resiliency Validation tab, click stop simulation.
1. Watch the VM latency go back up after about a minute.
1. Return to the "Resiliency Insights" blade, and note the failover readiness now has a completed readiness test for one of the two circuits.

## Validation

Once the circuit is disabled in Seattle, latency should increase significantly as the traffic is now going cross country and back to get to the on-prem in Seattle.

## Application Diagram After this Step is Complete

![ERRes1Step2.svg](instructions313701/ERRes1Step2.svg)

===

> [!Alert] **IMPORTANT:** These labs are hosted on the Skillable platform. Completion data is collected and then exported to Success Factors every Monday. SF require another 1-3 days to process that data. The status for this lab will be visible in Viva and Learning Path next week.

Be sure to select "**Submit**" in the bottom right corner to get credit for completing this lab.

@lab.ActivityGroup(completionsurvey)

> [!Alert] After answering the survey questions, select **submit** to complete and end the lab. **This is required in order to receive credit for lab completion**.
