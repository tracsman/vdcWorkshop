# Do-It-Yourself (DIY) Firewall Lab

## Abstract

This is a Firewall focused lab. It starts with a hub VNet with an internet connected VM. We then add an Azure firewall, and then a spoke VNet running a web site. Policies are added to advertise the web site to the Internet via the firewall and all internal traffic to route through the firewall for allow/deny policies. The workshop is deployed using pre-written PowerShell scripts that are commented for your exploration. Each step builds on the prior script. After each script runs you should explore the resources and available attributes in the Azure Portal to gain further insights into each component and how they work as a part of the larger design.

## Workshop Prerequisites
The following prerequisites must be completed before you start this workshop:

* You must be connected to the internet.

* Use either Edge or Chrome when executing the labs, Internet Explorer may have issues.

* You should have a Pay-As-You-Go Azure account with administrator- or contributor-level access to your subscription. If you don’t have an account, you can sign up for an account following the instructions here: [Pay As You Go][PayGo].

    > **IMPORTANT**
    > * Azure free subscriptions may have quota restrictions that prevent the workshop resources from being deployed successfully. Please use a Pay-As-You-Go subscription instead.
    > * When you deploy the lab resources in your own subscription you are responsible for the charges related to the use of the services provisioned.

* Some steps have the option to open a Remote Desktop Connection (RDP) to Azure Virtual Machines. If you are using a Mac, please ensure you have the latest version of the Microsoft Remote Desktop software installed: [Remote Desktop from the Apple Store][MacRDP]

## Workshop Proposed Agenda
The workshop can be completed at your own pace depending on your previous experience with the Azure Portal and PowerShell. Timing below is based purely on average Azure deployment times, you should plan to spend at least 15 minutes reviewing the resources created in the Azure Portal after the completion of each step and at least an hour at the end of the workshop reviewing:
- The end-to-end build-out
- How the components connect and relate to each other
- Adding and removing firewall policy and how that affects traffic
- Exploring the metrics and log output available for Azure Firewall in Log Analytics

#### Slides: [DIY Firewall Deck][FWDeck]

> **NOTE**: The deck contains all the steps below, plus an overview of many other Azure network features that you can review while waiting for the scripts to complete. Using the deck is the recommended way to deploy this workshop for richer learning about Azure Network features and services. However, using the individual step pages below will be the fastest way to completely deploy the workshop resources. Choose your own adventure!

Activity | Duration
-------- | ---------
[Cloud Shell Initialization and Updates][Step0] | 15 minutes
[Step 1: Create resource group, key vault, and secret][Step1] | 2 minutes
[Step 2: Create Virtual Network][Step2] | 2 minutes
[Step 3: Create an internet facing VM][Step3] | 10 minutes
[Step 4: Create and configure the Azure Firewall][Step4] | 75 minutes
[Step 5: Create Spoke VNet with IIS Server and firewall rules to allow traffic][Step5] | 25 minutes

[![1]][1]

> **IMPORTANT** 
> * The reference architecture proposed in this workshop aims to explain just enough of the role of each of the components. This workshop does not replace the need of in-depth training on each Azure service covered.
> * The services covered in this course are only a subset of a much larger family of Azure services. Similar outcomes can be achieved by leveraging other services and/or features not covered by this workshop. Specific business requirements may require the use of different services or features not included in this workshop.
> * Some concepts presented in this course can be quite complex and you may need to seek more information from different sources to compliment your understanding of the Azure services covered.

## Lab Guide

Throughout a series of 5 scripts you will progressively implement a hub and spoke network design running an IIS based web site protected by an Azure Firewall. 

All building scripts will be run in a Cloud Shell PowerShell session, this way you all SDK and PowerShell settings are done for you, making getting started much faster and focusing on the build out of the workshop resources not getting started with PowerShell.

By the end of the workshop you will have implemented the lab architecture referenced in the diagram above.

To get started, proceed to the Initialization step where you initialize your Cloud Shell, download the workshop files to your Cloud Shell and configure the workshop for your subscription. These instructions can be found here: [Cloud Shell Initialization and Updates][Step0]

<!--Link References-->
[PayGo]: https://azure.microsoft.com/pricing/purchase-options/pay-as-you-go/
[MacRDP]:  https://apps.apple.com/us/app/microsoft-remote-desktop-10/id1295203466?mt=12
[FWDeck]: ./Documents/Firewall%20Workshop.pptx
[Step0]: ./WorkshopStep0.md
[Step1]: ./WorkshopStep1.md
[Step2]: ./WorkshopStep2.md
[Step3]: ./WorkshopStep3.md
[Step4]: ./WorkshopStep4.md
[Step5]: ./WorkshopStep5.md

[Paper]: https://docs.microsoft.com/azure/architecture/vdc/networking-virtual-datacenter
[Server]: ./Scripts/ServerSideScripts



<!--Image References-->
[1]: ./Documents/Firewall.png "Firewall Image" 

