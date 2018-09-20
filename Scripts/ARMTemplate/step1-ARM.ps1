# Load Initialization Variables
Get-Content init.txt | Foreach-Object{
   $var = $_.Split('=')
   New-Variable -Name $var[0] -Value $var[1] -ErrorAction Continue
}


# Non-configurable Variable Initialization (ie don't modify these)
$SubID             = 'e4a176ec-f695-407c-8eeb-185fb94076b8'
$ResourceGroup     = "Company" + $CompanyID.PadLeft(2,"0")
$armTemplateFile   = "step1.json"
$Templateparameters= @{ CompanyID = $CompanyID}
$pathFiles         = Split-Path -Parent $PSCommandPath
$templateFile      = "$pathFiles\$armTemplateFile"


# Start nicely
Write-Host
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Starting step 1, estimated total time less than 1 minute" -ForegroundColor Cyan

# Login and permissions check
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Checking login and permissions" -ForegroundColor Cyan
Try {$rg = Get-AzureRmResourceGroup -Name $ResourceGroup -ErrorAction Stop}
Catch {# Login and set subscription for ARM
       Write-Host "Logging in to ARM"
       Try {$Sub = (Set-AzureRmContext -Subscription $subID -ErrorAction Stop).Subscription}
       Catch {Login-AzureRmAccount | Out-Null
              $Sub = (Set-AzureRmContext -Subscription $subID -ErrorAction Stop).Subscription}
       Write-Host "Current Sub:",$Sub.Name,"(",$Sub.Id,")"
           Try {$rg = Get-AzureRmResourceGroup -Name $ResourceGroup -ErrorAction Stop}
           Catch {Write-Warning "Permission check failed, ensure company id is set correctly!"
                  Return}
}


# Create Virtual Network
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Virtual Network by template:"$templateFile -ForegroundColor Cyan

New-AzureRmResourceGroupDeployment  -Name "step1" `
                            -ResourceGroupName $ResourceGroup `
                            -TemplateFile $templateFile -TemplateParameterObject $Templateparameters

# End nicely
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Step 1 completed successfully" -ForegroundColor Green
Write-Host
