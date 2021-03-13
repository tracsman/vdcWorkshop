# Creating a Virtual Data Center - Self Service Labs
## A network perspective

> **WARNING**: This DIY folder and all sub-folders are currently in developement and SHOULD NOT be used. I'll remove this warning when I get the first workshop, Firewall, complete.

This GitHub repo is based on some of the topics mentioned in the [Azure Virtual Data Center paper][Paper]. The goal is to provide example of some of the key network technologies available in Azure in a very hands-on and informative way.

Your uses cases will be much more complex than the examples provided herein, but hopefully these environment patterns that will be the foundation for your use case. 

The files and documents in the folders of this repository will help walk you through many network features that you can bring together to create application patterns and flows.

Each top level folder is a independent lab (except for "ServerSideScripts", more on that one in a minute). The labs are described below, but each lab has a similar structure. The second level directories in each lab are:

* "Documents" - In this directory you'll find a Word documents, PowerPoints, and/or PDF files showing the steps of the workshops and what you're building.
* "Scripts" - Under this directory you'll find a PowerShell directory with the scripts to perform each step of the lab. Some labs also have JSON templates and CLI to create the workshop steps.

> **NOTE**: In both the template and PowerShell scripts there is an INIT.TXT file that must be set to an assigned Company number. If you're running this outside of the class, any company number can be used. Default is 10. This number will be used to create resource groups and in the Azure object names.

## Available Workshop Examples

> **IMPORTANT**: These workshop came from instructor-led events, and have been modified to allow you to run them in your own subscription.

* [Firewall][Firewall] - This is a Firewall focused lab. It starts with an ExpressRoute circuit up to a hub VNet with an internet connected VM. We then add an Azure firewall, and then a spoke VNet running a web site. Policies are added to advertise the web site to the Internet via the firewall and all internal traffic to route through the firewall for allow/deny policies.

    [![1]][1]

## Server Side Scripts

Also contained in the repo is a Scripts directory called "[ServerSideScripts][Server]", this contains scripts that are pushed to the newly build Azure VMs and run as a part of some of the deployments. You can use these as model for deploying your applications or settings. For more complex deployments Chef, Puppet, Ansible, etc can be used.

<!--Link References-->
[Paper]: https://docs.microsoft.com/azure/architecture/vdc/networking-virtual-datacenter
[AFD]: ./AFDLab/
[Firewall]: ./Firewall/
[HubSpoke]: ./HubSpokeLab/
[vWAN]: ./vWanLab/
[Server]: ./Scripts/ServerSideScripts

<!--Image References-->
[0]: ./AFDLab/Documents/AFD.png "AFD Image"
[1]: ./Firewall/Documents/Firewall.png "Firewall Image" 
[2]: ./HubSpokeLab/Documents/HubSpoke.png "Hub and Spoke Image"
[3]: ./vWanLab/Documents/vWAN.png "Virtual WAN Image"
