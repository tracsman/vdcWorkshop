<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 1&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >>

# ExpressRoute Resiliency Workshop Part 2 - Create a metro peered ExpressRoute circuit (Step 1)

## Abstract

In this step we change to the Scripts directory and execute the Step 1 PowerShell Script.

The Step 1 Script will create an ExpressRoute circuit with a metro peering location.

## Observations

Once you're done with this step, you'll see a second ER Circuit in your resrouce group in the "Z" deployment. Review this circuit, especially it's peering location. Compare with the other Europe West circuit.

## Deployment

1. Change to the Scripts folder

    ```powershell
    cd ./Scripts/
    ```

2. (Optional) on the GitHub web site you can review the [Step 1][Step1] script before running.
3. Run workshop script 1 with the following:

    ```powershell
    ./ER2WorkshopStep1.ps1
    ```

## Validation

Once the script is complete, you'll see a new ER circuit named "Cxxz-ER-m" where xx is your company number. The "-m" denotes the metro peered circuit versus the standard, single peering location Circuit without that suffix.

## Application Diagram After this Step is Complete

[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 1&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >>

<!--Link References-->
[Prev]: ./ERRes2Step0.md
[Next]: ./ERRes2Step2.md
[Step1]: https://github.com/tracsman/vdcWorkshop/blob/main/ERResilience/Scripts/ER2WorkshopStep1.ps1

<!--Image References-->
[1]: ./Media/ERRes2Step1.svg "As built diagram of the environment after step 1"
