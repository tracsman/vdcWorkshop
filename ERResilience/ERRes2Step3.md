<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 3&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >>

# ExpressRoute Resiliency Workshop Part 2 - Create ExpressRoute Connection (Step 3)

## Abstract

Create a connection between the ER Gateway and the metro peered ER Circuit in Europe West.

## Observations

Now that the circuit is provisioned and BGP is up with On-prem, we can connect it to the VNet. Once you're done with this step, you'll see both the on-prem (10.3.x.0) and Azure VNet prefix (10.27.x.0) in the metro circuit route table.

## Deployment

> **NOTE**
> To make finding resrouces easier, you can add "xxz" to the resource group filter field (e.g. 10z for company 10)

1. (Optional) on the GitHub web site you can review the [Step 3][Step3] script before running.
3. Run workshop script 3 with the following:

    ```powershell
    ./ER2WorkshopStep3.ps1
    ```
4. Once the script completes, you may close the CloudShell if you wish, the remainder of this lab will be completed in the Azure Portal section.

## Validation

Go to the route table for Private Peering on your metro peered ER Circuit. You'll see routes for both on-prem and your Azure VNet.

## Application Diagram After this Step is Complete

[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 3&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >>

<!--Link References-->
[Prev]: ./ERRes2Step2.md
[Next]: ./ERRes2Step4.md
[Step3]: https://github.com/tracsman/vdcWorkshop/blob/main/ERResilience/Scripts/ER2WorkshopStep3.ps1

<!--Image References-->
[1]: ./Media/ERRes2Step3.svg "As built diagram of the environment after step 3"
