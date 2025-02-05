<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 2&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Main Page][Next]

# ExpressRoute Resiliency Workshop Part 1 - Fail Seattle Traffic (Step 2)

## Abstract

Fail Seattle ER circuit and validate traffic flows through Ashburn

## Observations

You'll see latency around 6ms, after failing the circuit you see traffic switch to the DC circuit, this will be indicated by the increased latency.

## Deployment

1. Open two browser tabs, both pointing to your Company Resource Group
1. In the first tab, navigate to the User01 password in the secrets store in your company Key Vault.
1. In the second tab, navigate to your West Spoke VM, named Cxxw-VNetSpoke1-VM01, where xx = your company number.
1. In the left nav for the VM, select Help, then Serial Console
    > **NOTE**
    > You may get a couple infomation warnings, just click on the enable Azure Serial Console message to enable it
    > [![2]][2]
    
1. Use the username "User01" and the password from the Key Vault to log in
1. Once at the Linux command line ping your Seattle On-Prem VM (replace the "x" with your Company number)
    ```bash
    ping 10.3.x.10
    ```
1. This will run a constant ping, make note of the latency as this will change when we fail the Seattle Circuit
1. In the other Azure Portal Tab, navigate to the Seattle ER Circuit (cXXw-ER)
1. Click into Private Peering
1. Uncheck the "Enable IPv4 Peering" check box, and click the "Save" button.
1. Shortly both legs of the Seattle circuit will not longer have BGP running, this simulates a total outage of the Seattle edge site. Back at the Linux VM you should now see the ping successful but with a much larger latency as traffic is now going from West US 2 to Washington DC and then back to Seattle on-prem (via the CompanyXX WAN outside of Azure)

## Validation

Once the peerings are disabled in Seattle, latency should increase significantly as the traffic is now going cross country and back to get to the on-prem in Seattle.

## Application Diagram After this Step is Complete

[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 2&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Main Page][Next]

<!--Link References-->
[Prev]: ./BaseNetStep1.md
[Next]: ./README.md

<!--Image References-->
[1]: ./Media/ERRes1Step2.svg "As built diagram of the environment after step 2"
[2]: ./Media/ConsoleError.png "Active Serial Console message"