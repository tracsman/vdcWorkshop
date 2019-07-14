# Creating a Virtual Data Center
## A network perspective

This GitHub repo is based on some of the topics mentioned in the [Azure Virtual Data Center paper][Paper]. The goal is to provide example of some of the key network technologies available in Azure in a very hands-on and informative way.

Your uses cases will be much more complex than the examples provided herein, but hopefully these environment patterns that will be the foundation for your use case. 

The files and documents in the folders of this repository will help walk you through many network features that you can bring together to create application patterns and flows.

Each top level folder is a independent lab (except for "ServerSideScripts", more on that one in a minute). The labs are described below, but each lab has a similar structure. The second level directories in each lab are:

* "Documents" - In this directory you'll find a Word documents, PowerPoints, and/or PDF files showing the steps of the workshops and what you're building.
* "Scripts" - Under this directory you'll find a PowerShell directory with the scripts to perform each step of the lab. Some labs also have JSON templates and CLI to create the workshop steps.

> **NOTE**: In both the template and PowerShell scripts there is an INIT.TXT file that must be set to an assigned Company number. If you're running this outside of the class, any company number can be used. Default is 10. This number will be used to create resource groups and in the Azure object names.

## Available Workshop Examples

> **IMPORTANT**: These workshop came from instructor-led events, and require pre-built initial resources, so at this time, you CAN NOT run these scripts without these base resources. I am working on "Step 0" scripts to create these base environments to make these labs self-server, but at this time they don't exist.

* [AFDLab][AFD] - This is an Azure Front door lab. It starts with two ExpressRoute circuits connected via Global Reach, and then connected to two VNets (one in East US and one in West US) each running an identical web site. Finally an Azure Front Door is deployed to geo-load balance between the two web sites.

    [![0]][0]

* [Firewall][Firewall] - This is a Firewall focused lab. It starts with an ExpressRoute circuit up to a hub VNet with an internet connected VM. We then add an Azure firewall, and then a spoke VNet running a web site. Policies are add to advertise the web site to the Internet via the firewall and all internal traffic to route through the firewall for allow/deny policies.

    [![1]][1]

* [HubSpokeLab][HubSpoke] - This is an ExpressRoute and Hub and Spoke lab. It starts with an ExpressRoute circuit from on-premises to an Azure VNet. We then build a spoke VNet with a VM Scale Set running a file server, then another spoke VNet with an Application Gateway load balancing a three-instance VM web farm. Finally a Linux VM is deployed in the hub acting as a firewall (running IPTables to forward traffic between the spokes, this lab was built before Azure Firewall was released, so we simulated an third-party appliance firewall). 

    [![2]][2]

* [vWanLab][vWAN] - This is a Virtual WAN lab. Is starts by deploying a Virtual WAN, Hub, and VPN Gateway. We then deploy a NetFoundry virtual appliance and then a Cisco CSR 1000v virtual appliance. Once the virtual "hardware" is deployed, we connect two Azure VNets to the vWAN hub, then connect the two "on-premises" devices.

    [![3]][3]

* More to come...

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
