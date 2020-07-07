$PSScriptRoot
$installedversion = (Get-Content  -Path '.\GPU Updater Tool.ps1')[0].Split('=')[1]
$onlineversion = (Invoke-WebRequest -uri "https://raw.githubusercontent.com/parsec-cloud/Cloud-GPU-Updater/master/GPU%20Updater%20Tool.ps1").Content.Substring(10,3)
if ($onlineversion -gt $installedversion){"Update"} Else {"No Update"}
#https://github.com/jamesstringerparsec/Cloud-GPU-Updater/archive/dev.zip