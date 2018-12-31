#
# Azure Front Door / Global Reach Workshop
# Microsoft READY 2019 - Azure Networking Pre-day
#
# Use your corporate credentials to login (your @microsoft.com account) to Azure
#
#
# Step 1 Create two ExpressRoute Circuits, one in Seattle, one in Washington, DC
# Step 2 Establish ExpressRoute Global Peering between the two circuits
# Step 3 Create two VNets each with an ER Gateway, Public IP, and IIS server running a simple web site
# Step 4 Create an Azure Front Door to geo-load balance across the two sites
#

# Step 4
# Create an Azure Front Door to accelerate and geo-load balance across the two sites
# Description: Create the associated objects and then the actual Front Door object
# 4.1 Create Front End
# 4.2 Create Back End
# 4.3 Create Load Balancing Rule
# 4.4 Create Front Door

# Az Module Test
$ModCheck = Get-Module Az.FrontDoor -ListAvailable
If ($Null -eq $ModCheck) {
    Write-Warning "The Az.FrontDoor PowerShell module was not found. This script uses the Az modules for PowerShell"
    Write-Warning "See the blob post for more information at: https://azure.microsoft.com/blog/how-to-migrate-from-azurerm-to-az-in-azure-powershell/"
    Write-Warning "The Front Door module must be installed in addition to the main Az module. This can be done in an admin PowerShell prompt:"
    Write-Host "           Install-Module Az.FrontDoor -AllowClobber" -ForegroundColor Yellow
    Return
    }

# Load Initialization Variables
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
If (Test-Path -Path $ScriptDir\init.txt) {
        Get-Content $ScriptDir\init.txt | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}}}
Else {Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}

# Initialize
$ResourceGroup = "Company" + $CompanyID.PadLeft(2,"0")
$VNetNameASH = "ASH-VNet01"
$VNetNameSEA = "SEA-VNet01"
$fdFEName = $ResourceGroup + "-fd.azurefd.net"

# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 4, estimated total time 3 minutes" -ForegroundColor Cyan

# Create Front Door
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Creating Front Door' -ForegroundColor Cyan

Try {Get-AzFrontDoor -ResourceGroupName $ResourceGroup -Name $ResourceGroup"-fd" -ErrorAction Stop | Out-Null
     Write-Host '  resource exists, skipping'}
Catch {
    # 4.1 Create Front End Endpoint
    $fdFE = New-AzFrontDoorFrontendEndpointObject -Name $ResourceGroup'-fd-fe' -HostName $fdFEName

    # 4.2 Create Back End
    # 4.2.1 Create Backend Objects
    $pipASH = Get-AzPublicIpAddress -Name 'ASH-VM01-pip' -ResourceGroupName $ResourceGroup
    $pipSEA = Get-AzPublicIpAddress -Name 'SEA-VM01-pip' -ResourceGroupName $ResourceGroup
    $fdBEASH = New-AzFrontDoorBackendObject -Address $pipASH.IpAddress
    $fdBESEA = New-AzFrontDoorBackendObject -Address $pipSEA.IpAddress

    # 4.2.2 Create Health Probe
    $fdHP = New-AzFrontDoorHealthProbeSettingObject -Name $ResourceGroup"-fd-probe" -Path "/" -Protocol Http

    # 4.2.3 Create Load Balance Settings
    $fdLB = New-AzFrontDoorLoadBalancingSettingObject -Name $ResourceGroup"-fd-lb" -SampleSize 4 -SuccessfulSamplesRequired 2

    # 4.2.4 Create Backend Pool
    $fdBEPool = New-AzFrontDoorBackendPoolObject -ResourceGroupName $ResourceGroup -Name $ResourceGroup"-fd-pool" -FrontDoorName $ResourceGroup"-fd" -Backend $fdBEASH, $fdBESEA -HealthProbeSettingsName $fdHP.Name -LoadBalancingSettingsName $fdLB.Name

    # 4.3 Create Load Balancing Rule
    # Set rule to accept both http and https, but forward to the back as http (the IIS server is only serving on port 80)
    $fdRR = New-AzFrontDoorRoutingRuleObject -ResourceGroupName $ResourceGroup -Name $ResourceGroup"-fd-rule" -FrontDoorName $ResourceGroup"-fd" -FrontendEndpointName $fdFE.Name -BackendPoolName $fdBEPool.Name -AcceptedProtocol Http, Https -PatternToMatch "/*" -ForwardingProtocol HttpOnly

    # 4.4 Create Front Door
    New-AzFrontDoor -ResourceGroupName $ResourceGroup -Name $ResourceGroup"-fd" -BackendPool $fdBEPool -FrontendEndpoint $fdFE -HealthProbeSetting $fdHP -LoadBalancingSetting $fdLB -RoutingRule $fdRR
    }

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 4 completed successfully" -ForegroundColor Green
Write-Host "  Please proceed with the step 4 validation"
Write-Host
