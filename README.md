# Creating a Virtual Datacenter
## A network perspective

The files and documents in the below folders will help walk you through many network features that you can bring together to create application patterns and flows.

In the [Documents][Docs] directory you'll find a Word document showing screen shots of how to do much of the lab. You'll also find the PowerPoint from the Ignite 2018 Pre-Day Workshop (PRE24)

Although the Azure Portal is an easy way to create resources it is advised that for most builds deployed to Azure you use [ARM Templates][ARM]. [PowerShell][PS] is also an effective way to deploy, however this requires PowerShell scripting knowledge and can be more error prone than templates.

In the Scripts directory you'll find the ARM Templates with the associated PowerShell laucher that will deploy the ARM Temaplate for that step.

> NOTE: In both the template and PowerShell scripts there is an INIT.TXT file that must be set to your assigned Company number. If you're running this outside of the class, any company number can be used. Default is 1.

To deploy [ARM Templates][ARM, example for Step 1:

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

Also contained in the Script directory is a "ServerSideScripts" folder, this contains that server side scripts that are run as a part of some of the deployements here. You can use those a model for deploying your applications or settings. For more complex deployments Chef, Puppet, Ansible, etc can be used.

<!--Link References-->
[Docs]: ./Documents/
[Scripts]: ./Scripts/
[ARM]: ./Scripts/ARMTemplates
[PS]: ./Scripts/PowerShell
[Server]: ./Scripts/ServerSideScripts