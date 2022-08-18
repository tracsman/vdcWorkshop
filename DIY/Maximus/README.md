# Azure Networking Do-It-Yourself (DIY) Lab

## Abstract

This DIY lab is enriched with cross-networking features. You will enjoy deploying and using a wide range of features across all Azure Networking Services with the exception of ExpressRoute, CDN, and VWAN. The lab starts with a hub VNet containing a private VM along with a Bastion host and NAT Gateway that enable external (public) connectivity. We then add an Azure firewall in the hub with various policy rules to control the flow of traffic. Then we deploy 3 spoke VNets and peer them with the hub. The first spoke hosts a web service behind an App Gateway. The second spoke runs a VM Scale Set behind a Network Load Balancer. This spoke also includes a Private Endpoint for private and secure connectivity to Azure Storage service (PaaS). The third spoke is added in a different region to provide access via Azure Front Door (for Geo load balancing) over Private Link Service to App Service (Web App). The lab also includes S2S VPN to simulate "On-Prem" connectivity and P2S VPN to simulate "Coffee Shop" connectivity to Azure. You will deploy VPN NVAs with Route Server and get to play with Azure Service Log Analytics. All along, you will have fun with UDRs and NSGs.

The workshop is deployed using pre-written PowerShell scripts that are commented for your exploration. Each step builds on the prior script. After each script runs you should explore the resources and available attributes in the Azure Portal to gain further insights into each component and how they work as a part of the larger design.

## Workshop Prerequisites
The following prerequisites must be completed before you start this workshop:

* You must be connected to the Internet.

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

#### Slides: [Azure Networking DIY Deck][Deck] [To be updated]

> **NOTE**: The deck contains all the steps below, plus an overview of many other Azure network features that you can review while waiting for the scripts to complete. Using the deck is the recommended way to deploy this workshop for richer learning about Azure Network features and services. However, using the individual step pages below will be the fastest way to completely deploy the workshop resources. Choose your own adventure!

Activity | Duration
-------- | ---------
[Cloud Shell Initialization and Updates][Module0] | 15 minutes
[Step 1: Create resource group, key vault with secrets, Hub VNet, and VM][Module1] | 5 minutes
[Step 2: Create NSG, NAT Gateway, and Basion Host in Hub VNet][Module2] | 8 minutes
[Step 3: Create Firewall, Policy Rules, UDR, and Log Analytics Workspace][Module3] | 20 minutes
[Step 4: Create first spoke VNet with App Gateway and Web Farm][Module4] | 12 minutes
[Step 5: Create second spoke VNet with VM Scale Set behind Load Balancer][Module5] | 8 minutes
[Step 6: Deploy Private Endpoint in second Spoke VNet to access Azure Storage (PaaS)][Module6] | 10 minutes
[Step 7: Deploy S2S and P2S VPNs for "On-prem" and "Remote user" connectivity][Module7] | 60 minutes
[Step 8: Deploy third spoke, set up Azure Front Door, and create App Service with Private Link Service][Module8] | 25 minutes
[Step 9: Deploy Route Server in hub and VPN NVAs in hub and on-prem VNets][Module9] | 25 minutes


[![1]][1]

> **IMPORTANT** 
> * The reference architecture proposed in this workshop aims to explain just enough of the role of each of the components. This workshop does not replace the need of in-depth training on each Azure service covered.
> * The services covered in this course are only a subset of a much larger family of Azure services. Similar outcomes can be achieved by leveraging other services and/or features not covered by this workshop. Specific business requirements may require the use of different services or features not included in this workshop.
> * Some concepts presented in this course can be quite complex and you may need to seek more information from different sources to compliment your understanding of the Azure services covered.

## Lab Guide

Through a series of 9 scripts you will progressively implement a hub and spoke network design running an IIS based web site protected by an Azure Firewall. 

All building scripts will be run in a Cloud Shell PowerShell session, this way all SDK and PowerShell settings are done for you, making getting started much faster and focusing on the build out of the workshop resources not getting started with PowerShell.

By the end of the workshop you will have implemented the lab architecture referenced in the diagram above.

To get started, proceed to the Initialization step where you initialize your Cloud Shell, download the workshop files to your Cloud Shell and configure the workshop for your subscription. These instructions can be found here: [Cloud Shell Initialization and Updates][Step0]

<!--Link References-->
[PayGo]: https://azure.microsoft.com/pricing/purchase-options/pay-as-you-go/
[MacRDP]:  https://apps.apple.com/us/app/microsoft-remote-desktop-10/id1295203466?mt=12
[Deck]: ./Documents/Firewall%20Workshop.pptx
[Module0]: ./Module00.md
[Module1]: ./Module01.md
[Module2]: ./Module02.md
[Module3]: ./Module03.md
[Module4]: ./Module04.md
[Module5]: ./Module05.md
[Module6]: ./Module06.md
[Module7]: ./Module07.md
[Module8]: ./Module08.md
[Module9]: ./Module09.md
[Paper]: https://docs.microsoft.com/azure/architecture/vdc/networking-virtual-datacenter
[Server]: ./Scripts/ServerSideScripts



<!--Image References-->
[1]: ./Media/Step9.svg "Workshop final as-built diagram" 

