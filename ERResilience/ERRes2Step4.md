<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 4&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Main Page][Next]

# ExpressRoute Resiliency Workshop Part 2 - Delete Standard ER Connection (Step 4)

## Abstract

Delete connection the connectin object to the orginal standard circuit so that traffic only flows across the metro peered circuit (no script)

## Observations

Once you're done with this step, you'll see a blip of connectivity but no change in latency as traffic moves from the standard circuit to the metro circuit.

## Deployment

> **NOTE**
> To make finding resrouces easier, you can add "xxz" to the resource group filter field (e.g. 10z for company 10)

1. Open two browser tabs, both pointing to your Company Resource Group
1. In the first tab, navigate to the User01 password in the secrets store in your company Key Vault.
1. In the second tab, navigate to your West Europe Spoke VM, named Cxxz-VNetSpoke1-VM01, where xx = your company number.
1. In the left nav for the VM, select Help, then Serial Console
    > **NOTE**
    > You may get a couple infomation warnings, just click on the enable Azure Serial Console message to enable it
    > [![2]][2]
    
1. Use the username "User01" and the password from the Key Vault to log in
1. Once at the Linux command line ping your Seattle On-Prem VM (replace the "x" with your Company number)
    ```bash
    ping 10.3.x.10
    ```
1. This will run a constant ping, make note of the latency
1. In the other Azure Portal Tab, navigate to the connection object connecting the EU circuit to the EU gateway (Cxxz-VNet-gw-er-conn-AMS) where xx is your company number. Ensure that the circuit is the one *without* the "-m" suffix to ensure you're deleting the correct connection object.
1. Delete this connection object which will leave only the metro connection for connectivity. (say "yes" to the delete warning)
1. Once the delete completes, check out the ping back on the VM console tab, you may see up to 30 seconds of connectivity loss, usually much less.

## Validation
Once the connection object to the standard circuit is deleted, the circuit is now protected from peering site failure!

## Application Diagram After this Step is Complete

[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 4&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Main Page][Next]

<!--Link References-->
[Prev]: ./ERRes2Step3.md
[Next]: ./README2.md
[CloudShell]: https://docs.microsoft.com/azure/cloud-shell/overview

<!--Image References-->
[1]: ./Media/ERRes2Step4.svg "As built diagram of the environment after step 4"
[2]: ./Media/ConsoleError.png "Active Serial Console message"