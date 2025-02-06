<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 2&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >>

# ExpressRoute Resiliency Workshop Part 2 - Enable ExpressRoute Private Peering (Step 2)

## Abstract

This step will bring up ExpressRoute Private Peering enabling BGP between on-prem and the MSEEs in Amsterdam. Note that because this is a "metro peering", one leg of the ER circuit is landing in the Amerstrdam peering location, and the other leg in the Amsterdam 2 peering location.

## Observations

Once you're done with this step, you'll be able to see the on-prem route in your new circuits route table. (e.g. 10.3.x.0/25)

## Deployment

> **NOTE**
> To make finding resrouces easier, you can add "xxz" to the resource group filter field (e.g. 10z for company 10)

    > **IMPORTANT**
    > Your metro circuit must be provisioned before proceeding with this step!
    >
    > Please ensure the instructor as started the provisioning, and that your circuit's "Provider Status" is "Provisioned"

1. (Optional) on the GitHub web site you can review the [Step 2][Step2] script before running.
2. Run workshop script 2 with the following:

    ```powershell
    ./ER2WorkshopStep2.ps1
    ```

## Validation

Look at the metro peered circuit in the Portal. You'll now see configuration in place for Private Peering. If you look at the Route Table for Private Peering you'll see a single route in the table. 10.3.x.0/25. This is the on-prem in Seattle.

## Application Diagram After this Step is Complete

[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 2&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >>

<!--Link References-->
[Prev]: ./ERRes2Step1.md
[Next]: ./ERRes2Step3.md
[Step2]: https://github.com/tracsman/vdcWorkshop/blob/main/ERResilience/Scripts/ER2WorkshopStep2.ps1

<!--Image References-->
[1]: ./Media/ERRes2Step2.svg "As built diagram of the environment after step 2"
