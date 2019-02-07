function installedGPUID {
#queries WMI to get DeviceID of the installed NVIDIA GPU
Try {(get-wmiobject -query "select DeviceID from Win32_PNPEntity Where (deviceid Like '%PCI\\VEN_10DE%') and (PNPClass = 'Display' or Name = '3D Video Controller')"  | Select-Object DeviceID -ExpandProperty DeviceID).substring(13,8)}
Catch {return $null}
}

function driverVersion {
#Queries WMI to request the driver version, and formats it to match that of a NVIDIA Driver version number (NNN.NN) 
Try {(Get-WmiObject Win32_PnPSignedDriver | where {$_.DeviceName -like "*nvidia*" -and $_.DeviceClass -like "Display"} | Select-Object -ExpandProperty DriverVersion).substring(7,6).replace('.','').Insert(3,'.')}
Catch {return $null}
}

function osVersion {
#Requests Windows OS Friendly Name
(Get-WmiObject -class Win32_OperatingSystem).Caption
}

function requiresReboot{
#Queries if system needs a reboot after driver installs
if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { return $true }
if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { return $true }
if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { return $true }
 try { 
   $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
   $status = $util.DetermineIfRebootPending()
   if(($status -ne $null) -and $status.RebootPending){
     return $true
   }
 }catch{}
 
 return $false
}

function validDriver {
#checks an important nvidia driver folder to see if it exits
test-path -Path "C:\Program Files\NVIDIA Corporation\NVSMI"
}

Function webDriver { 
#checks the latest available graphics driver from nvidia.com
if (($gpu.supported -eq "No") -eq $true) {"Sorry, this GPU (" + $gpu.name + ") is not yet supported by this tool."
Exit
}
Elseif (($gpu.Supported -eq "UnOfficial") -eq $true) {
$AzureGRIDDriver = Invoke-WebRequest -uri https://docs.microsoft.com/en-us/azure/virtual-machines/windows/n-series-driver-setup -UseBasicParsing  
$($AzureGRIDDriver.Links.OuterHtml -like "*GRID*")[0].Split('(')[1].split(")")[0]
}
Else { 
$gpu.URL = "https://www.nvidia.com/Download/processFind.aspx?psid=" + $gpu.psid + "&pfid=" + $gpu.pfid + "&osid=" + $gpu.osid + "&lid=1&whql=1&lang=en-us&ctk=0"
$link = Invoke-WebRequest -Uri $gpu.URL -Method GET -UseBasicParsing
$link -match '<td class="gridItem">([^<]+?)</td>' | Out-Null
if (($matches[1] -like "*(*") -eq $true) {$matches[1].split('(')[1].split(')')[0]}
Else {$matches[1]}
}
}

function GPUCurrentMode {
#returns if the GPU is running in TCC or WDDM mode
$nvidiaarg = "-i 0 --query-gpu=driver_model.current --format=csv,noheader"
$nvidiasmi = "c:\program files\nvidia corporation\nvsmi\nvidia-smi" 
try {Invoke-Expression "& `"$nvidiasmi`" $nvidiaarg"}
catch {$null}
}

function queryOS {
#sets OS support
if (($system.OS_Version -like "*Windows 10*") -eq $true) {$gpu.OSID = '57' ; $system.OS_Supported = $false}
elseif (($system.OS_Version -like "*Windows 8.1*") -eq $true) {$gpu.OSID = "41"; $system.OS_Supported = $false}
elseif (($system.OS_Version -like "*Server 2016*") -eq $true) {$gpu.OSID = "74"; $system.OS_Supported = $true}
Else {$system.OS_Supported = $false}
}

function appmessage {
#sets most of the CLI messages
$app.Parsec = Write-Host -foregroundcolor cyan "
                                 #############                                 
                                 #############                                 
                                                                               
                           .#####   ###/  #########                            
                                                                               
                          ###########################                          
                          ###########################                          
                                                                               
                           .#########  /###   #####                            
                                                                               
                                 #############                                 
                                 #############                                 
                                       
                              ~Parsec GPU Updater~
" 
$app.FailOS = "Sorry, this Operating system (" + $system.OS_version + ") is not yet supported by this tool."
$app.FailGPU = "Sorry, this GPU (" + $gpu.name + ") is not yet supported by this tool."
$app.UnOfficialGPU = "This GPU (" + $gpu.name + ") requires a GRID driver downloaded from the Azure Support Site"
$app.NoDriver = "We detected your system does not have a valid NVIDIA Driver installed"
$app.UpToDate = "Your PC already has the latest NVIDIA GPU Driver (" + $gpu.Web_Driver + ") available from nvidia.com."
$app.Success = "Checked Now " + $system.date + " - An update is available (" + $gpu.Driver_Version + " > " + $gpu.Web_Driver + ")" 
$app.ConfirmCharge = "Installing NVIDIA Drivers may require 2 reboots in order to install correctly.  
This means you may lose some play time for completing this driver upgrade.  
Type Y to continue, or N to exit."                                     
}

function webName {
#Gets the unknown GPU name from a csv based on a deviceID found in the installedgpuid function
(New-Object System.Net.WebClient).DownloadFile("https://raw.githubusercontent.com/jamesstringerparsec/Cloud-GPU-Updater/master/Additional%20Files/GPUID.csv", $($system.Path + "\GPUID.CSV")) 
Import-Csv "$($system.path)\GPUID.csv" -Delimiter ',' | Where-Object DeviceID -like *$($gpu.Device_ID)* | Select-Object -ExpandProperty GPUName
}

function queryGPU {
#sets details about current gpu
if($gpu.Device_ID -eq "DEV_13F2") {$gpu.Name = 'NVIDIA Tesla M60'; $gpu.PSID = '75'; $gpu.PFID = '783'; $gpu.NV_GRID = $true; $gpu.Driver_Version = driverversion; $gpu.Web_Driver = webdriver; $gpu.Update_Available = ($gpu.Web_Driver -gt $gpu.Driver_Version); $gpu.Current_Mode = GPUCurrentMode; $gpu.Supported = "Yes"} 
ElseIF($gpu.Device_ID -eq "DEV_118A") {$gpu.Name = 'NVIDIA GRID K520'; $gpu.PSID = '94'; $gpu.PFID = '704'; $gpu.NV_GRID = $true; $gpu.Driver_Version = driverversion; $gpu.Web_Driver = webdriver; $gpu.Update_Available = ($gpu.Web_Driver -gt $gpu.Driver_Version); $gpu.Current_Mode = GPUCurrentMode; $gpu.Supported = "Yes"} 
ElseIF($gpu.Device_ID -eq "DEV_1BB1") {$gpu.Name = 'NVIDIA Quadro P4000'; $gpu.PSID = '73'; $gpu.PFID = '840'; $gpu.NV_GRID = $false; $gpu.Driver_Version = driverversion; $gpu.Web_Driver = webdriver; $gpu.Update_Available = ($gpu.Web_Driver -gt $gpu.Driver_Version); $gpu.Current_Mode = GPUCurrentMode; $gpu.Supported = "Yes"} 
Elseif($gpu.Device_ID -eq "DEV_1BB0") {$gpu.Name = 'NVIDIA Quadro P5000'; $gpu.PSID = '73'; $gpu.PFID = '823'; $gpu.NV_GRID = $false; $gpu.Driver_Version = driverversion; $gpu.Web_Driver = webdriver; $gpu.Update_Available = ($gpu.Web_Driver -gt $gpu.Driver_Version); $gpu.Current_Mode = GPUCurrentMode; $gpu.Supported = "Yes"}
Elseif($gpu.Device_ID -eq "DEV_15F8") {$gpu.Name = 'NVIDIA Tesla P100'; $gpu.PSID = '103'; $gpu.PFID = '822'; $gpu.NV_GRID = $true; $gpu.Driver_Version = driverversion; $gpu.Web_Driver = webdriver; $gpu.Update_Available = ($gpu.Web_Driver -gt $gpu.Driver_Version); $gpu.Current_Mode = GPUCurrentMode; $gpu.Supported = "UnOfficial"}
Elseif($gpu.Device_ID -eq $null) {$gpu.Supported = "No"; $gpu.Name = "No Device Found"}
else{$gpu.Supported = "No"; $gpu.Name = webName}
}

function checkOSSupport {
#quits if OS isn't supported
If ($system.OS_Supported -eq $false) {$app.FailOS
Read-Host "Press any key to exit..."
Exit
}
Else {}
}

function checkGPUSupport{
#quits if GPU isn't supported
If ($gpu.Supported -eq "No") {
$app.FailGPU
Read-Host "Press any key to exit..."
Exit
}
ElseIf ($gpu.Supported -eq "UnOfficial") {
$app.UnOfficialGPU
}
Else{}
}

function checkDriverInstalled {
#Tells user if no GPU driver is installed
if ($system.Valid_NVIDIA_Driver -eq $False) {
$app.NoDriver
}
Else{}
}

function confirmcharges {
#requests user approve potential cloud run time charges for using the tool
$app.confirmcharge
$ReadHost = Read-Host "(Y/N)"
    Switch ($ReadHost) 
       {
       Y {}
       N{
       Write-Output "The upgrade script will now exit"
       Exit}
       }
}

function prepareEnvironment {
#prepares working directory
$test = Test-Path -Path $system.path 
if ($test -eq $true) {
Remove-Item -path $system.Path -Recurse -Force | Out-Null
New-Item -ItemType Directory -Force -Path $system.path | Out-Null}
Else {
New-Item -ItemType Directory -Force -Path $system.path | Out-Null
}
}

function checkUpdates {
#starts update if required
if ($gpu.Update_Available -eq $true) {$app.success
startUpdate}
Else {
$app.UpToDate
Read-Host "Press any key to exit..."
Exit
}
}

function startUpdate { 
#Gives user an option to start the update, and sends messages to the user
Write-output "Update now? - (!) Machine will automatically reboot if required (!)"
$ReadHost = Read-Host "(Y/N)"
    Switch ($ReadHost) 
     { 
       Y {Write-Output `n "Downloading Driver"
       prepareEnvironment
       downloaddriver
       Write-Output  "Success!"
       Write-Output `n "Installing Driver, this may take up to 10 minutes and will automatically reboot if required"
       InstallDriver
       Write-Output "Success - Driver Installed - Checking if reboot is required"
       rebootlogic
       } 
       N {Write-output "Exiting Scipt"
       exit} 
     } 
}

function DownloadDriver {
if (($gpu.supported -eq "UnOfficial") -eq $true) {
$AzureGRID = Invoke-WebRequest -uri https://docs.microsoft.com/en-us/azure/virtual-machines/windows/n-series-driver-setup -UseBasicParsing  
(New-Object System.Net.WebClient).DownloadFile($($AzureGRID.Links.OuterHtml -like "*GRID*")[0].Split('"')[1].split("'")[0], "C:\ParsecTemp\Drivers\AzureGRID.exe")
}
Else {
#downloads driver from nvidia.com
$Download.Link = Invoke-WebRequest -Uri $gpu.url -Method Get -UseBasicParsing | select @{N='Latest';E={$($_.links.href -match"www.nvidia.com/download/driverResults.aspx*")[0].substring(2)}}
$download.Direct = Invoke-WebRequest -Uri $download.link.latest -Method Get -UseBasicParsing | select @{N= 'Download'; E={"http://us.download.nvidia.com" + $($_.links.href -match "/content/driverdownload*").split('=')[1].split('&')[0]}}
(New-Object System.Net.WebClient).DownloadFile($($download.direct.download), $($system.Path) + "\NVIDIA_" + $($gpu.web_driver) + ".exe")
}
}

function installDriver {
#installs driver silently with /s /n arguments provided by NVIDIA
$DLpath = Get-ChildItem -Path $system.path -Include *exe* -Recurse | Select-Object -ExpandProperty Name
Start-Process -FilePath "$($system.Path)\$dlpath" -ArgumentList "/s /n" -Wait }

#setting up arrays below
$download = @{}
$app = @{}
$gpu = @{Device_ID = installedGPUID}
$system = @{Valid_NVIDIA_Driver = ValidDriver; OS_Version = osVersion; OS_Reboot_Required = RequiresReboot; Date = get-date; Path = "C:\ParsecTemp\Drivers"}

function rebootLogic {
#checks if machine needs to be rebooted, and sets a startup item to set GPU mode to WDDM if required
if ($system.OS_Reboot_Required -eq $true) {
    if ($GPU.NV_GRID -eq $false)
    {Write-Output "This computer needs to reboot in order to finish installing your driver Driver, and will reboot in 10 seconds"
    start-sleep -s 10
    Restart-Computer -Force} 
    ElseIf ($GPU.NV_GRID -eq $true) {
    Write-Output "This computer needs to reboot twice in order to correctly install the driver and set WDDM Mode"
    setnvsmi
    setnvsmi-shortcut
    start-sleep -s 10
    Restart-Computer -Force}
    Else{}
}
Else {
    if ($gpu.NV_GRID -eq $true) {
    Write-Output "This computer needs to reboot twice in order to correctly install the driver and set WDDM Mode"
    setnvsmi
    setnvsmi-shortcut
    start-sleep -s 10
    Restart-Computer -Force}
    ElseIf ($gpu.NV_GRID -eq $false) {
    write-output "Your computer is ready to go and does not require a reboot :)"
    }
    Else{}
}
}

function setnvsmi {
#downloads script to set GPU to WDDM if required
(New-Object System.Net.WebClient).DownloadFile("https://raw.githubusercontent.com/jamesstringerparsec/Cloud-GPU-Updater/master/Additional%20Files/NVSMI.ps1", $($system.Path) + "\NVSMI.ps1") 
Unblock-File -Path "$($system.Path)\NVSMI.ps1"
}

function setnvsmi-shortcut{
#creates startup shortcut that will start the script downloaded in setnvsmi
Write-Output "Create NVSMI shortcut"
$Shell = New-Object -ComObject ("WScript.Shell")
$ShortCut = $Shell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\NVSMI.lnk")
$ShortCut.TargetPath="powershell.exe"
$ShortCut.Arguments='-WindowStyle hidden -ExecutionPolicy Bypass -File "C:\ParsecTemp\Drivers\NVSMI.ps1"'
$ShortCut.WorkingDirectory = "C:\ParsecTemp\Drivers";
$ShortCut.WindowStyle = 0;
$ShortCut.Description = "Create NVSMI shortcut";
$ShortCut.Save()
}

#starts 
prepareEnvironment
queryOS
querygpu
appmessage
$app.Parsec
checkOSSupport
checkGPUSupport
querygpu
checkDriverInstalled
ConfirmCharges
checkUpdates
