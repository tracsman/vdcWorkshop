<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 2&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

# DIY Workshop Maximus - Module 6

## Abstract
This module extends user connectivity via the App Gateway to a storage acount over Private Link. To accomplish this, you will set up a private endpoint in Spoke 2 along with a Private DNS zone and associate a storage account with the private endpoint.

## Observations
Once you're done with this step, you will know how to retrieve contents from a storage account over Private Link.

## Deployment
1. While in the Scripts folder run
   ```powershell
   ./Module06.ps1
   ```
   > **NOTE**: You may see “warnings” from PowerShell about upcoming changes in the Azure PowerShell SDK. These warnings do not affect running of the scripts.

2. (Optional) in the editor pane you can select and view the script before running

## Validation
1. Navigate to your Resource Group in the Portal. You should now see storage account, a private endpoint with a associate NIC and a private DNS zone. 
2. Check the settings of the Private Endoint.
6. Navigate to the App Gateway IP again from the browser and notice that the web page now displays contents from the storge account via the Private Endpoint



## Application Diagram After this Step is Complete
[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 2&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

<!--Link References-->
[Prev]: ./Module05.md
[Next]: ./Module07.md

<!--Image References-->
[1]: ./Media/Step2.svg "As built diagram for step 2" 