<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 1&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >>

# ExpressRoute Resiliency Workshop Part 1 - Create Meshed ER Connections (Step 1)

## Abstract

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

    ###   West Circuit Route Table
    | VNet       | IP Address Range |
    |------------|------------------|
    | On-premise | 10.3.xx.0.25     |
    | West Hub   | 10.17.xx.0/24    |
    | West Spoke | 10.18.xx.0/24    |
    | East Hub   | 10.10.xx.0/24    |
    | East Spoke | 10.11.xx.0/24    |

    This shows that we now have reachability across country if either edge site fails. A similar route table can be seen on the East Circuit Route Table.

## Application Diagram After this Step is Complete

[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 1&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >>

<!--Link References-->
[Prev]: ./ERRes1Step0.md
[Next]: ./ERRes1Step2.md
[Step1]: https://github.com/tracsman/vdcWorkshop/blob/main/ERResilience/Scripts/ER1WorkshopStep1.ps1

<!--Image References-->
[1]: ./Media/ERRes1Step1.svg "As built diagram of the environment after step 1"
