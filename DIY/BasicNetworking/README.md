# Do-It-Yourself (DIY) Basic Routing Environment

## Abstract

This is a traditional networking focused lab. It starts with a VNet and then deploys two Cisco routers with minimal config. This environment is useful for getting started with networking and is a good companion for any use along side formal network training. This environment will give you the hands-on experience of configuring and using two Cisco routers to set up communication between them. If desired, you can add VMs to either side to set an actual host-to-host connectivity, but that is more complex and outside of the scope of this basic setup.

## Workshop Prerequisites

The following prerequisites must be completed before you start this workshop:

* You must be connected to the internet.

* Use either Edge or Chrome when executing the labs, Internet Explorer may have issues.

* You should have a Pay-As-You-Go Azure account with administrator- or contributor-level access to your subscription. If you don’t have an account, you can sign up for an account following the instructions here: [Pay As You Go][PayGo].

    > **IMPORTANT**
    > * Azure free subscriptions may have quota restrictions that prevent the workshop resources from being deployed successfully. Please use a Pay-As-You-Go subscription instead.
    > * When you deploy the lab resources in your own subscription you are responsible for the charges related to the use of the services provisioned.

## Workshop Proposed Agenda

The workshop can be completed at your own pace depending on your previous experience with the Azure Portal and PowerShell. Timing below is based purely on average Azure deployment times, you should plan to spend at least 15 minutes reviewing the resources created in the Azure Portal after the completion of each step and at least an hour at the end of the workshop reviewing:

* The end-to-end build-out
* How the components connect and relate to each other
* Basic router configuration
* Basic router inter-operation

Activity | Duration
-------- | ---------
[Cloud Shell Initialization and Updates][Step0] | 10 minutes
[Step 1: Create resource group, key vault, and routers][Step1] | 15 minutes
[Step 2: Discussion basic configuration][Step2] | 60 minutes

[![1]][1]

> **IMPORTANT**
> Some concepts presented in this course can be quite complex and you may need to seek more information from different sources to compliment your understanding of the areas covered.

## Lab Guide

Via a PowerShell script you will implement a VNet with two Cisco routers. Then at your own pace explore and configure these routers to communicate.

All building scripts will be run in a Cloud Shell PowerShell session, this way all SDK and PowerShell settings are done for you, making getting started much faster and focusing on the build out of the resources not getting started with PowerShell.

At the end of the script you will have implemented the lab architecture referenced in the diagram above.

To get started, proceed to the Initialization step where you initialize your Cloud Shell, download the workshop files to your Cloud Shell and configure the workshop for your subscription. These instructions can be found here: [Cloud Shell Initialization and Updates][Step0]

<!--Link References-->
[PayGo]: https://azure.microsoft.com/pricing/purchase-options/pay-as-you-go/
[Step0]: ./BaseNetStep0.md
[Step1]: ./BaseNetStep1.md
[Step2]: ./BaseNetStep2.md

<!--Image References-->
[1]: ./Media/BaseNet.svg "Workshop final as-built diagram"
