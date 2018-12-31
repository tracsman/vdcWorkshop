# Initialize
[string]$CompanyID = "10"
$ResourceGroup = "Company" + $CompanyID.PadLeft(2,"0")
$VNetNameASH = "ASH-VNet01"
$VNetNameSEA = "SEA-VNet01"
$fdFEName = "afd" + $ResourceGroup + ".azurefd.net"
$pipASH = Get-AzPublicIpAddress -Name 'ASH-VM01-pip' -ResourceGroupName $ResourceGroup
$pipSEA = Get-AzPublicIpAddress -Name 'SEA-VM01-pip' -ResourceGroupName $ResourceGroup

# Create AFD Public IP
#Try {$pipFD = Get-AzPublicIpAddress -Name $ResourceGroup'-fd-pip'  -ResourceGroupName $ResourceGroup -ErrorAction Stop}
#Catch {$pipFD = New-AzPublicIpAddress -Name $ResourceGroup'-fd-pip' -ResourceGroupName $ResourceGroup -Location $EastRegion -AllocationMethod Dynamic}

# Create AFD Frontend Endpoint
$fdFE = New-AzFrontDoorFrontendEndpointObject -Name $ResourceGroup'-fd-fe' -HostName $fdFEName

# Create Backend Objects
$fdBEASH = New-AzFrontDoorBackendObject -Address $pipASH.IpAddress
$fdBESEA = New-AzFrontDoorBackendObject -Address $pipSEA.IpAddress

# Create Health Probe
$fdHP = New-AzFrontDoorHealthProbeSettingObject -Name $ResourceGroup"-fd-probe" -Path "/" -Protocol Http

# Create Load Balance Settings
$fdLB = New-AzFrontDoorLoadBalancingSettingObject -Name $ResourceGroup"-fd-lb" -SampleSize 4 -SuccessfulSamplesRequired 2

# Create Backend Pool
$fdBEPool = New-AzFrontDoorBackendPoolObject -ResourceGroupName $ResourceGroup -Name $ResourceGroup"-fd-pool" -FrontDoorName $ResourceGroup"-fd" -Backend $fdBEASH -HealthProbeSettingsName $fdHP -LoadBalancingSettingsName $fdLB

# Create Routing Rule
$fdRR = New-AzFrontDoorRoutingRuleObject -ResourceGroupName $ResourceGroup -Name $ResourceGroup"-fd-rule" -FrontDoorName $ResourceGroup"-fd" -FrontendEndpointName $fdFE.Name -BackendPoolName $fdBEPool.Name -AcceptedProtocol Http -PatternToMatch "/*"



# Create Front Door
New-AzFrontDoor -ResourceGroupName $ResourceGroup -Name $ResourceGroup"-fd" -BackendPool $fdBEPool -FrontendEndpoint $fdFE -HealthProbeSetting $fdHP -LoadBalancingSetting $fdLB -RoutingRule $fdRR
#Get-AzFrontDoor