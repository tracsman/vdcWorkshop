################# Input parameters #################
$subscriptionName      = "Virtual Data Center Workshop"
$location              = "eastus"
$destResourceGrp       = "Test-Firewall7"
$resourceGrpDeployment = "deploy-az-firewall"
$armTemplateFile       = "azFW.json"
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"


$subscr=Get-AzureRmSubscription -SubscriptionName $subscriptionName
Select-AzureRmSubscription -SubscriptionId $subscr.Id

$runTime=Measure-Command {
New-AzureRmResourceGroup -Name $destResourceGrp -Location $location
write-host $templateFile
New-AzureRmResourceGroupDeployment  -Name $resourceGrpDeployment -ResourceGroupName $destResourceGrp -TemplateFile $templateFile -Verbose
}

write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()