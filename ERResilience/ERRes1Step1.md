<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 1&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >>

# ExpressRoute Resiliency Workshop Part 1 - Create Meshed ER Connections (Step 1)

## Abstract

In this step we change to the Scripts directory and execute the Step 1 PowerShell Script.

The Step 1 Script will create a "bow tie" of connections between the East and West ExpressRoute gateways and Seattle and Ashburn ExpressRoute circuits. By "meshing" (connecting all circuits and gateways together) we'll have a max resiliency configuration. In this config, a failure of either circuit or peering location (e.g. the physical building) will not take down connectivity to either Azure region, although latency will likely increase due to the increased physical path distance.

## Observations

Once you're done with this step, you will see your Resource Group with an east and west hub and spoke configuration, now with the addition of two new connection objects, West US to Ashburn, and East US to Seattle.

## Deployment

1. Change to the Scripts folder

    ```powershell
    cd Scripts
    ```

2. (Optional) in the editor pane you can select and view the script before running
3. Run workshop script 1 with the following:

    ```powershell
    ./ER1WorkshopStep1.ps1
    ```

## Validation

1. Browse to your Resource Group in the Portal
2. You should see two new connection objects
3. Explore the route table of each ExpressRoute circuit, ensure you have the address prefixes for both Azure Region VNets in both ER Circuits.

## Application Diagram After this Step is Complete

[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 1&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >>

<!--Link References-->
[Prev]: ./ERRes1Step0.md
[Next]: ./ERRes1Step2.md

<!--Image References-->
[1]: ./Media/ERRes1Step1.svg "As built diagram of the environment after step 1"
