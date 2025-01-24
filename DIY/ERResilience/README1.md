# Hands-On ExpressRoute Resiliency Workshop (Part 1)

## Abstract

This lab will walk through the steps needed to setup a maximum resiliency configuration for two pre-existing hub and spoke. There are pre-created resources to allow us to get to the heart of the operations without delaying for resources to be built.

## Workshop Prerequisites

The following prerequisites must be completed before you start this workshop:

* You must be connected to the internet.

* Use either Edge or Chrome when executing the labs, Internet Explorer may have issues.

* You should have received a pre-assigned workshop number (10 - 50) that you will use to access your resource group. 

## Workshop Proposed Agenda

* Review the existing deployment, understand what and where the resources are
* Discuss the ExpressRoute resiliency options: Standard, High, and Maximum
* Add connections to your deployment to reach "Max" Resiliency on ExpressRoute
* Use a new feature to "fail" your ExpressRoute in Seattle, and watch the traffic failover to DC and maintain connectivity.

The individual steps for this lab are located on GitHub, follow this link to access them: https://github.com/tracsman/vdcWorkshop/tree/main/DIY/ERResilience

Activity | Duration
-------- | ---------
[Cloud Shell Initialization and Updates][Step0] | 10 minutes
[Step 1: Create bowtie East-West ER connections][Step1] | 15 minutes
[Step 2: Discussion configuration and Fail Seattle ER][Step2] | 60 minutes

> **IMPORTANT**
> Some concepts presented in this course can be quite complex and you may need to seek more information from different sources to compliment your understanding of the areas covered.

To get started, proceed to the Initialization step (Step 0) where you initialize your Cloud Shell, download the workshop files to your Cloud Shell and configure the workshop for your subscription. These instructions can be found here: [Cloud Shell Initialization and Updates][Step0]

<!--Link References-->
[PayGo]: https://azure.microsoft.com/pricing/purchase-options/pay-as-you-go/
[Step0]: ./BaseNetStep0.md
[Step1]: ./BaseNetStep1.md
[Step2]: ./BaseNetStep2.md

<!--Image References-->
[1]: ./Media/BaseNet.svg "Workshop final as-built diagram"
