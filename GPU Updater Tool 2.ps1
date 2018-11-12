### Written by James Stringer for Parsec Cloud Inc ###
### http://parsecgaming.com ###
$TempPath = "C:\ParsecTemp\Drivers"
New-Item -ItemType Directory -Force -Path $TempPath | Out-Null
#functions for setup
function installedDriver {
$nvidiaarg = "-i 0 --query-gpu=driver_version --format=csv,noheader"
$nvidiasmi = "c:\program files\nvidia corporation\nvsmi\nvidia-smi" 
Invoke-Expression "& `"$nvidiasmi`" $nvidiaarg"
}
function installedGPU {
$nvidiaarg = "-i 0 --query-gpu=name --format=csv,noheader"
$nvidiasmi = "c:\program files\nvidia corporation\nvsmi\nvidia-smi" 
Invoke-Expression "& `"$nvidiasmi`" $nvidiaarg"
} 
function getPSID {
if ($InstalledGPU.Contains("P4000") -eq $True) {"73"}
elseif ($InstalledGPU.Contains("P5000") -eq $True) {"73"}
elseif ($InstalledGPU.Contains("M4000") -eq $True) {"73"}
elseif ($InstalledGPU.contains("M60") -eq $True) {"75"}
elseif ($installedGPU.contains("K520") -eq $True) {"94"}
else {}
}
function getPFID {
if ($InstalledGPU.Contains("P4000") -eq $True) {"840"}
elseif ($InstalledGPU.Contains("P5000") -eq $True) {"823"}
elseif ($InstalledGPU.Contains("M4000") -eq $True) {"781"}
elseif ($InstalledGPU.contains("M60") -eq $true) {"783"}
elseif ($InstalledGPU.contains("K520") -eq $True) {"704"}
else {}
}
function checkModel {
$nvidiaarg = "-i 0 --query-gpu=driver_model.current --format=csv,noheader"
$nvidiasmi = "c:\program files\nvidia corporation\nvsmi\nvidia-smi" 
Invoke-Expression "& `"$nvidiasmi`" $nvidiaarg"
}
function isWDDM {
if ($DriverModel.Contains("WDDM") -eq $True ){write-output "True"}
else{Write-Output "False - your driver mode will need to be changed to WDDM "} 
}
function getRequireNVSMI {
if ($InstalledGPU.Contains("M60") -eq $true) {write-output "This machine will require an NVIDIA-SMI change after reboot"}
else{write-output "This GPU does not require a change to WDDM post reboot - Driver will install normally"} 
}
function setNVSMI {
$nvidiaarg = "--query-gpu=gpu_bus_id --format=csv,noheader"
$nvidiasmi = "c:\program files\nvidia corporation\nvsmi\nvidia-smi" 
$bus_id = Invoke-Expression "& `"$nvidiasmi`" $nvidiaarg"
$output1 = 'cd C:\Program Files\NVIDIA Corporation\NVSMI'
$output2 = "nvidia-smi -g $bus_id -dm 0
shutdown /r -t 10"
"$output1 
$output2" | Out-File -Encoding ASCII -FilePath "C:\ParsecTemp\Drivers\nvidiasmi.bat"
}
function setStartup {
New-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion" -name RunOnce | Out-Null -ErrorAction SilentlyContinue
New-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -name SetSMI -Value "C:\ParsecTemp\Drivers\nvidiasmi.bat" | Out-Null
}
function test-PendingReboot{
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
function rebootLogic {
if (Test-PendingReboot -eq $true) {
    if ($InstalledGPU.contains("M60") -eq $false)
    {Write-Output "This computer needs to reboot in order to finish installing your driver Driver, and will reboot in 10 seconds"
    start-sleep -s 10
    Restart-Computer -Force} 
    ElseIf ($InstalledGPU.contains("M60") -eq $true) {
    Write-Output "This computer needs to reboot twice in order to correctly install the driver and set WDDM Mode"
    setnvsmi
    setstartup
    start-sleep -s 10
    Restart-Computer -Force}
    Else{}
}
Else {
    if ($InstalledGPU.contains("M60") -eq $true) {
    Write-Output "This computer needs to reboot twice in order to correctly install the driver and set WDDM Mode"
    setnvsmi
    setstartup
    start-sleep -s 10
    Restart-Computer -Force}
    ElseIf ($InstalledGPU.Contains("M60") -eq $false) {
    write-output "Your computer is ready to go and does not require a reboot :)"
    }
    Else{}
}
}
Function getLatestVersion { 
if ($psid -eq $null) {Write-Output "This GPU ($InstalledGPU) is not compatible with this tool"
Exit}
Else { 
$url = "https://www.nvidia.com/Download/processFind.aspx?psid=" + $psid + "&pfid=" + $pfid + "&osid=74&lid=1&whql=1&lang=en-us&ctk=0"
$link = Invoke-WebRequest -Uri $url -Method GET -UseBasicParsing
$link -match '<td class="gridItem">([^<]+?)</td>' | Out-Null
$Parseversion = $matches[1]
$Parseversion
}
}
function downloadDriver {
$NVIDIADriverList = Invoke-WebRequest -Uri "https://www.nvidia.com/Download/processFind.aspx?psid=""$psid""&pfid=""$pfid""&osid=74&lid=1&whql=1&lang=en-us&ctk=0" -Method GET -UseBasicParsing
$GetFirstLink = $NVIDIADriverList.Links.Href -match "www.nvidia.com/download/driverResults.aspx*"
$DownloadURL =$GetFirstLink[0].Substring(2)
$DownloadPage = Invoke-WebRequest -Uri $DownloadURL -Method GET -UseBasicParsing
$GetDownloadLink = $DownloadPage.Links.Href -like "/content/driverdownload*"
$ParsedDLURL = $GetDownloadLink.split('=')[1].split('&')[0]
$DriverDownloadURL = "http://us.download.nvidia.com" + $ParsedDLURL
Start-BitsTransfer -Source $DriverDownloadURL -Destination $TempPath
}
function installDriver {
$DLpath = Get-ChildItem -Path $temppath -Include *exe* -Recurse | Select-Object -ExpandProperty Name
$fullpath = "$temppath" + '\' + "$dlpath"
Start-Process -FilePath $fullpath -ArgumentList "/s /n" -Wait }
function startUpdate { Write-output "Update now? - (!) Machine will automatically reboot if required (!)"
$ReadHost = Read-Host "(Y/N)"
    Switch ($ReadHost) 
     { 
       Y {Write-Output `n "Downloading Driver"
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
function confirmcharges {
Write-Output "Installing NVIDIA Drivers may require 2 reboots in order to install correctly.  
This means you may lose some play time for completing this driver upgrade.  
Type Y to continue, or N to exit."
$ReadHost = Read-Host "(Y/N)"
    Switch ($ReadHost) 
       {
       Y {}
       N{
       Write-Output "The upgrade script will now exit"
       Exit}
       }
}
function run {
$global:date = Get-Date
$global:successmessage = "Checked Now - An update is available ($InstalledDriver > $LatestVersion)" 
$global:NeedUpdate = if ($InstalledDriver -lt $latestversion) {Write-Output $successmessage `n}
Else {Write-Output "Your PC already has the latest NVIDIA GPU Driver ($LatestVersion) available from nvidia.com."}
}
$InstalledDriver = InstalledDriver
$InstalledGPU = InstalledGPU
$psid = getpsid
$pfid = getpfid
$DriverModel = CheckModel
$IsWDDM = isWDDM
$requireNVSMI = GetRequireNvsmi
$LatestVersion = GetLatestVersion
$host.PrivateData.ErrorForegroundColor = "Cyan"
Write-Host -foregroundcolor cyan -BackgroundColor White "
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
confirmcharges
run
If ((test-path -Path "C:\Program Files\NVIDIA Corporation\NVSMI") -eq $true) {}
Else {Write-Output "There is no GPU driver installed"
Write-Output "Script will close in 10 seconds"
Start-Sleep -s 10
Exit
} 
Write-output "Installed GPU:"$InstalledGPU`n "Installed GPU Driver" $InstalledDriver`n "Latest GPU driver available from nvidia.com:"$latestversion`n "Currently Running in WDDM:" $IsWDDM`n
Write-Output $requireNVSMI `n
write-output "Checking For Updates Available @ $date :"  
$NeedUpdate
if ($NeedUpdate.Contains("$successmessage") -eq $true) {
startupdate
}
else{}




