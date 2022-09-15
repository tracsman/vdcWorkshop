<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 6&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

# DIY Workshop Maximus - Module 6

## Abstract
This module extends user connectivity from the App Gateway to a storage account (PaaS instance). To accomplish this, you will set up a private endpoint in Spoke02 along with a Private DNS zone and associate the storage account with the private endpoint.

## Observations
Once you're done with this step, you will know how to retrieve contents from a storage account via a private endpoint.

## Deployment
1. While in the Scripts folder run
   ```powershell
   ./Module06.ps1
   ```
   > **NOTE**: You may see “warnings” from PowerShell about upcoming changes in the Azure PowerShell SDK. These warnings do not affect running of the scripts.

2. (Optional) in the editor pane you can select and view the script before running

## Validation
1. Navigate to your Resource Group in the Portal. You should now see storage account, a private endpoint with an associated NIC and a private DNS zone. 
2. Check the settings of the Private Endoint.
3. Navigate to the App Gateway IP again from the browser and notice that the web page now displays contents from the storage account via the Private Endpoint.
4. (Optional) Pull up the FQDNs of the private and public endpoints from the Portal. Use a browser to directly access each of the endpoints from a) the Internet and b) from CorpNet (if remote, connect with Corp VPN). You will notice that you can access the Storage Account with both FQDNs from the Internet but not from CorpNet. This is because access from the Internet uses the public DNS server managed by Azure. Access from CorpNet uses the CorpNet DNS server managed by Corp IT. If you want to access from CorpNet, you will need to setup a DNS record in the Corp DNS server via the Self-Service DNS interface (https://namesweb/dnsselfservice/). For details, refer to http://aka.ms/privatelinkforinternaluse. 



## Application Diagram After this Step is Complete
[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 6&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

<!--Link References-->
[Prev]: ./Module05.md
[Next]: ./Module07.md

<!--Image References-->
[1]: ./Media/Step6.svg "As built diagram for step 6" 