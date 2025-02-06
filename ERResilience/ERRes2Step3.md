<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 3&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >>

# ExpressRoute Resiliency Workshop Part 2 - Create ExpressRoute Connection (Step 3)

## Abstract

Create the connection between the ER Gateway and the metro peered ER Circuit

## Observations

Now that the circuit is provisioned and BGP is up with On-prem, we can connect it to the VNet. Once you're done with this step, you'll both the on-prem and Azure prefixes in the metro circuit route table.

## Deployment

1. (Optional) on the GitHub web site you can review the [Step 3][Step3] script before running.
3. Run workshop script 3 with the following:

    ```powershell
    ./ER2WorkshopStep3.ps1
    ```

## Validation

Go to the route table for Private Peering on your metro peered ER Circuit. You'll 

## Application Diagram After this Step is Complete

[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 3&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >>

<!--Link References-->
[Prev]: ./ERRes2Step2.md
[Next]: ./ERRes2Step4.md
[Step3]: https://github.com/tracsman/vdcWorkshop/blob/main/ERResilience/Scripts/ER2WorkshopStep3.ps1

<!--Image References-->
[1]: ./Media/ERRes2Step3.svg "As built diagram of the environment after step 3"
