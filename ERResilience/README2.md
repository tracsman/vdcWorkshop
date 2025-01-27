# Hands-On ExpressRoute Resiliency Workshop (Part 2)

## Abstract

This lab will walk through the steps needed to implement a metro ExpressRoute circuit and migrate from a standard circuit to a metro peered circuit with minimal downtime. There are pre-created resources to allow us to get to the heart of the operations without delaying for resources to be built.

## Workshop Prerequisites

The following prerequisites must be completed before you start this workshop:

* You must be connected to the internet.

* Use either Edge or Chrome when executing the labs, Internet Explorer may have issues.

* You should have received a pre-assigned workshop number (10 - 50) that you will use to access your resource group. 

## Workshop Proposed Agenda

* Review the existing deployment, understand what and where the resources are
* Discuss the ExpressRoute resiliency options: Standard, High, and Maximum
* Create a new metro peered ER circuit and get it provisioned
* Create the connection and migrate traffic over to the new circuit
* Delete the old connection and then the old circuit

The individual steps for this lab are located on GitHub, follow this link to access them: https://github.com/tracsman/vdcWorkshop/tree/main/DIY/ERResilience

Activity | Duration
-------- | ---------
[Cloud Shell Initialization and Updates][Step0] | 15 minutes
[Step 1: Create new metro ER circuit][Step1] | 10 minutes
[Step 2: Provision and bring up ExpressRoute Private Peering][Step2] | 30 minutes
[Step 3: Create the connection between the Gateway and the Circuit][Step3] | 10 minutes
[Step 4: Delete old peering and connection][Step4] | 10 minutes

[![1]][1]

> **IMPORTANT**
> Some concepts presented in this course can be quite complex and you may need to seek more information from different sources to compliment your understanding of the areas covered.

To get started, proceed to the Initialization step (Step 0) where you initialize your Cloud Shell, download the workshop files to your Cloud Shell and configure the workshop for your subscription. These instructions can be found here: [Cloud Shell Initialization and Updates][Step0]

<!--Link References-->
[PayGo]: https://azure.microsoft.com/pricing/purchase-options/pay-as-you-go/
[Step0]: ./ERRes2Step0.md
[Step1]: ./ERRes2Step1.md
[Step2]: ./ERRes2Step2.md
[Step3]: ./ERRes2Step3.md
[Step4]: ./ERRes2Step4.md

<!--Image References-->
[1]: ./Media/ERRes2Step4.svg "Workshop final as-built diagram"
