<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 8&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

# DIY Workshop Maximus - Module 8

## Abstract
In this module, we will add Azure Front Door (AFD) service and deploy App Service to create another instance of our web server in a different region USWest3). You will configure AFD to ensure web contents can be retrieved from the nearest web server in one of the two regions (USWest2 or USWest3). You will also deploy another private endpoint in a new spoke VNet, Spoke03 in the new region. You will enable private link service for a private connection between AFD and the App service instance.

## Observations
Once you're done with this step, you would have learnt how to use AFD to route global web requests to web servers in different regions. You would have also learnt to use App Service to serve web contents via AFD over private link.

## Deployment
1. While in the Scripts folder run
   ```powershell
   ./Module08.ps1
   ```
   > **NOTE**: You may see “warnings” from PowerShell about upcoming changes in the Azure PowerShell SDK. These warnings do not affect running of the scripts.

2. (Optional) in the editor pane you can select and view the script before running.

## Validation
1. Go to your resource group in the Azure Portal and check the newly added resources. 
2. You should now see a new spoke (Spoke03) with another private endpoint (privatelink.azurewebsites.net). You should also have Azure Front Door and a new application instance (App Service/Web App) in WestUS3 region. Note that it may take up to 10 minutes for AFD to deploy around the world.
3. Try the following to check out your new resources:                       
    1. Bring up the App Service resource (Spoke03xxx-app) in your resource group and note the URL in the Overview blade. Navigate to this URL via the Internet.  
    2. Because this App Service is behind a private link service you should get a 403 - Forbidden error message when accessing via the Internet.
    3. Now bring up your Front Door resource (xxx-fd) in the portal and note the endpoint hostname (xxx.azurefd.net). This is the frontend address of your AFD. Open a browser session and navigate to this address. Your request will automatically get routed to the nearest server from the specified servers in the origin group. 
    4. Notice which spoke (Spoke01 or Spoke03) is serving the content via your AFD. The new instance is available from your Front Door if you are closer to WestUS3. Note: if you're further away, you can disable the closer origin in the Front Door origin group to force AFD to the new location.           



## Application Diagram After this Step is Complete
[![1]][1]

<< [Previous Step][Prev]&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;Step 8&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;[Next Step][Next] >> 

<!--Link References-->
[Prev]: ./Module07.md
[Next]: ./Module09.md

<!--Image References-->
[1]: ./Media/Step8.svg "As built diagram for step 8" 