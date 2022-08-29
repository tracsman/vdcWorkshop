<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 8&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

# DIY Workshop Maximus - Module 8

## Abstract
In this module, you will create a new spoke, Spoke03 in a different region (US West 3). You will deploy a private endpoint in this spoke and a new application instance in this region using App Service. You will deploy Azure Front Door (AFD) and enable private link for a private connection to the App service instance. You will configure AFD to route global web requests to the web server in one of the two regions, US West 2 or US West 3. [WIP]

## Observations
Once you're done with this step, you would have learnt to retrieve web contents from App Service using AFD over private link.

## Deployment
1. While in the Scripts folder run
   ```powershell
   ./Module08.ps1
   ```
   > **NOTE**: You may see “warnings” from PowerShell about upcoming changes in the Azure PowerShell SDK. These warnings do not affect running of the scripts.

2. (Optional) in the editor pane you can select and view the script before running

## Validation
1. Go to your resource group in the Azure Portal and check the newly added resources.
2. You now have an Azure Front Door and a new application instance in West US 3 region. 
3. Try the following to check out your new resources:                       
    1. Check out the new App Service at http://Spoke03569304946-app.azurewebsites.net  
    2. Because this App Service is behind a private link service you should get a 403 - Forbidden error message when accessing via the internet
    3. Go to your Front Door at https://MaxLab04569304946-fd-fe-e2f7gvbub6e2e2g4.z01.azurefd.net (it may take up to 10 minutes for AFD to deploy around the world)
    4. Notice which spoke is serving the content in your AFD, the new instance is also available from your Front Door if you are closer to westus3. (note: if you're further away, you can disable the closer origin in the Front Door origin group to force AFD to the new location.)             



## Application Diagram After this Step is Complete
[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 8&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

<!--Link References-->
[Prev]: ./Module07.md
[Next]: ./Module09.md

<!--Image References-->
[1]: ./Media/Step8.svg "As built diagram for step 8" 