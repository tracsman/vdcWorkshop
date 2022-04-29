# Run script harness
$VMName = "OnPrem-VM01"
$ScriptName = "MaxTest"
#$ScriptName = "MaxVMBuildOP"
$ShortRegion = "westus2"
$RGName = "MaxLab"


Write-Host "  running $VMName VM build script" -ForegroundColor Cyan
$uriScript = "https://raw.githubusercontent.com/tracsman/vdcWorkshop/ModularDIY/ServerSideScripts/$ScriptName.ps1"
Set-AzVMCustomScriptExtension -ResourceGroupName $RGName -VMName $VMName -Name $ScriptName -FileUri $uriScript -Run "$ScriptName.ps1" -Location $ShortRegion
