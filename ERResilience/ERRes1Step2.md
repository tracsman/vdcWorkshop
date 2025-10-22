<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 2&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Main Page][Next]

# ExpressRoute Resiliency Workshop Part 1 - Fail Seattle Traffic (Step 2)

## Abstract

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
    > [![2]][2]

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

[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 2&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Main Page][Next]

<!--Link References-->
[Prev]: ./ERRes1Step1.md
[Next]: ./README.md

<!--Image References-->
[1]: ./Media/ERRes1Step2.svg "As built diagram of the environment after step 2"
[2]: ./Media/ConsoleError.png "Active Serial Console message"
