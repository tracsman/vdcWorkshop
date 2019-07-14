# Creating a Virtual Datacenter
## A network perspective

The files and documents in the below folders will help walk you through many network features that you can bring together to create application patterns and flows.

Each top level folder is a independent lab (except for "ServerSideScripts", more on that one in a minute). The labs are described below, but each lab has a similar structure. The second level directories in each lab are:

* "Documents" - in this directory you'll find a Word documents, PowerPoints, and/or PDF files showing the steps of the workshops and what you're building.
* "Scripts" - Under this directory you'll find a PowerShell directory with the scripts to perform each step of the lab. Some labs also have JSON templates and CLI to create the workshop steps.

> NOTE: In both the template and PowerShell scripts there is an INIT.TXT file that must be set to an assigned Company number. If you're running this outside of the class, any company number can be used. Default is 10.

To deploy [ARM Templates][ARM], example for Step 1:

```` PowerShell
    # Navigate to the directory where the scripts are stored, only run
    # the scripts from that directory!!!
    #
    # Please set the INIT.TXT file before running the first script!
    #
    .\step1-ARM.ps1

````

To deploy from [PowerShell Scripts][PS], example for Step 1:
```` PowerShell
    # Navigate to the directory where the scripts are stored, only run
    # the scripts from that directory!!!
    #
    # Please set the INIT.TXT file before running the first script!
    #
    .\WorkshopStep1.ps1

````

Also contained in the Scripts directory is a "[ServerSideScripts][Server]" folder, this contains scripts that are push to the newly build Azure VMs and run as a part of some of the deployments. You can use these as model for deploying your applications or settings. For more complex deployments Chef, Puppet, Ansible, etc can be used.

<!--Link References-->
[Docs]: ./Documents/
[Scripts]: ./Scripts/
[ARM]: ./Scripts/ARMTemplates
[PS]: ./Scripts/PowerShell
[Server]: ./Scripts/ServerSideScripts