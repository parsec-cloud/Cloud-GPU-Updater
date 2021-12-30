 #version=001
 #sets invoke-webrequest to use TLS1.2 by default
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$host.ui.RawUI.WindowTitle = "Cloud GPU Updater"

# Self-elevate the script if required
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
 if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
  $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
  Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
  Exit
 }
}

function installedGPUID {
    #queries WMI to get DeviceID of the installed NVIDIA GPU
    Try {
        (get-wmiobject -query "select DeviceID from Win32_PNPEntity Where (deviceid Like '%PCI\\VEN_10DE%') and (PNPClass = 'Display' or Name = '3D Video Controller')"  | Select-Object DeviceID -ExpandProperty DeviceID).substring(13,8)
        }
    Catch {
        }
    Try {
        (get-wmiobject -query "select DeviceID from Win32_PNPEntity Where (deviceid Like '%PCI\\VEN_1002%')"  | Select-Object DeviceID -ExpandProperty DeviceID).substring(13,8)
        }
    Catch {
        }
}

function driverVersion {
    #Queries WMI to request the driver version, and formats it to match that of a NVIDIA Driver version number (NNN.NN) 
    if ($GPU.Device_ID -ne "DEV_7362") {
        Try {
            (Get-WmiObject Win32_PnPSignedDriver | where {($_.DeviceName -like "*nvidia*") -and $_.DeviceClass -like "Display"} | Select-Object -ExpandProperty DriverVersion).substring(7,6).replace('.','').Insert(3,'.')
            }
        Catch {
            }
        }
    }

function osVersion {
    #Requests Windows OS Friendly Name
    (Get-WmiObject -class Win32_OperatingSystem).Caption
    }

Function AWSUseSavedCreds {
    Param (
    $ProfileName
    )
    If ($system.AWSCredentialCheckAlreadyRan -eq $null) {
        if ((Get-AWSCredential -ProfileName $ProfileName) -ne $null) {
            Write-Host "Found saved AWS Access Key for AWS Driver"
            Write-Host "Use saved credentials?"
            $ReadHost = Read-Host "(Y/N)"
            Switch ($ReadHost) 
               {
                   Y {
                        }
                   N {
                        Remove-AWSCredentialProfile -ProfileName $ProfileName -Confirm:$False
                        }
               }
           
           }
    }
    $system.AWSCredentialCheckAlreadyRan = 1
}

Function AWSPrivatedriver {
    param (
    $profileName,
    $GPU    
    )
    if ((Get-AWSCredential -ProfileName $profileName) -ne $null) {
        }
    Else {
        Write-host "The AWS instance requires a non-public driver, you will need to create or use an existing Access key found here, or create an IAM with permissions to read nvidia-gaming.s3.amazonaws.com"
        Write-host "https://console.aws.amazon.com/iam/home?/security_credentials#/security_credentials" -BackgroundColor Green -ForegroundColor Black
        $accesskey = Read-Host "Enter your AWS Access key"
        $secretkey = Read-Host "Enter your AWS Secret Key"
        Set-AWSCredentials -AccessKey $accesskey -SecretKey $secretkey -StoreAs $ProfileName
        Write-Host "Save AWS Access Key? - DO NOT do this if you intend to let others access this machine, or create an AMI that others will be able to create instances from" -BackgroundColor Red -ForegroundColor Black
        $ReadHost = Read-Host "(Y/N)"
            Switch ($ReadHost) 
               {
                   Y {
                        }
                   N {
                        $System.DoNotSaveAWSCredential = 1
                        }
               }
        }
    if ($GPU -eq "G4dn") {
        $Bucket = "nvidia-gaming"
        $KeyPrefix = "windows/latest"
        $S3Objects = Get-S3Object -BucketName $Bucket -KeyPrefix $KeyPrefix -Region us-east-1 -ProfileName $profileName
        $S3Objects.key | select-string -Pattern '.zip' 
        }
    elseif ($GPU -eq "G4ad") {
        $Bucket = "ec2-amd-windows-drivers"
        $KeyPrefix = "latest"
        $S3Objects = Get-S3Object -BucketName $Bucket -KeyPrefix $KeyPrefix -Region us-east-1 -ProfileName $profileName
        $S3Objects.key | select-string -Pattern '.zip'
    }
    }

Function ClearG4DNCredentials {
    param (
    $ProfileName
    )
    if ($System.DoNotSaveAWSCredential -eq 1) {
        Remove-AWSCredentialProfile -ProfileName $ProfileName -Confirm:$False
        }
    }

function RequiresReboot {
    #Queries if system needs a reboot after driver installs
    param (
    $RebootRequiredReason
    )
    $System = @{}
    If ($RebootRequiredReason -eq "Script") {
        $System.OS_Reboot_Reason = "This script requires the machine to reboot"
        Return $True
        }
    elseIf ($gpu.Current_Mode -eq "TCC") {
        $System.OS_Reboot_Reason = "Your NVIDIA GPU requires this machine to reboot in order correctly set the display mode"
        Return $True
        } 
    elseIf (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) {
        $System.OS_Reboot_Reason = "Your system requires a reboot to complete updates"
        Return $True
            }
    elseIf (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) {
        $System.OS_Reboot_Reason = "Your system requires a reboot to complete updates"
        Return $True
            }
    elseIf (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { 
        $System.OS_Reboot_Reason = "Your system requires a reboot to complete updates"
        Return $True
            }
    else {
        try { 
            $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
            $status = $util.DetermineIfRebootPending()
            if(($status -ne $null) -and $status.RebootPending){
                $System.OS_Reboot_Reason = "Your system requires a reboot to complete driver updates"
                Return $True
                }
            }
        catch {
              }
        
        Return $False
        $System.OS_Reboot_Reason = "Your system does not require a reboot and is ready to use"
         }
    }

function Reboot {
    param (
    $message)
    ClearG4DNCredentials -profilename ParsecGPUUpdate 
    if (RequiresReboot){
        clean-registry-g4dn
        $message
        "Reboot System?"
        $ReadHost = Read-Host "(Y/N)"
        Switch ($ReadHost) 
           {
               Y {
                    Restart-Computer -Force
                    }
               N {
                    }
           }
        }
    Else {
        $message
        }
    }

function cloudprovider { 
    #finds the cloud provider that this VM is hosted by
    $gcp = $(
                try {
                    (Invoke-WebRequest -uri http://metadata.google.internal/computeMetadata/v1/ -Method GET -header @{'metadata-flavor'='Google'} -TimeoutSec 5)
                    }
                catch {
                    }
             )

    $aws = $(
                Try {
                    (Invoke-WebRequest -uri http://169.254.169.254/latest/meta-data/ -TimeoutSec 5)
                    }
                catch {
                    }
             )

    $paperspace = $(
                        Try {
                            (Invoke-WebRequest -uri http://metadata.paperspace.com/meta-data/machine -TimeoutSec 5)
                            }
                        catch {
                            }
                    )

    $azure = $(
                  Try {(Invoke-WebRequest -Uri "http://169.254.169.254/metadata/instance?api-version=2018-10-01" -Headers @{Metadata="true"} -TimeoutSec 5)}
                  catch {}              
               )


    if ($GCP.StatusCode -eq 200) {
        "Google"
        } 
    Elseif ($AWS.StatusCode -eq 200) {
        "AWS"
        } 
    Elseif ($paperspace.StatusCode -eq 200) {
        "Paperspace"
        }
    Elseif ($azure.StatusCode -eq 200) {
        "Azure"
        }
    Else {
        "Generic"
        }
}


function validDriver {
    #checks an important nvidia driver folder to see if it exits
    if ($gpu.Device_ID -ne "DEV_7362") {
        test-path -Path "C:\Program Files\NVIDIA Corporation\NVSMI"
        }
    Elseif ($gpu.Device_ID -eq "DEV_7362"){
        $true
        }
    }

Function webDriver { 
    #checks the latest available graphics driver from nvidia.com
    if (($gpu.supported -eq "No") -eq $true) {"Sorry, this GPU (" + $gpu.name + ") is not yet supported by this tool."
        Exit
        }
    Elseif((($gpu.Supported -eq "yes") -and ($gpu.cloudprovider -eq "aws") -and ($gpu.Device_ID -ne "DEV_118A") -and ($gpu.Device_ID -ne "DEV_1EB8")) -eq $true){
        $s3path = $(([xml](invoke-webrequest -uri https://ec2-windows-nvidia-drivers.s3.amazonaws.com).content).listbucketresult.contents.key -like  "latest/*server2016*") 
        $s3path.split('_')[0].split('/')[1]
        }
    Elseif((($gpu.Supported -eq "unOfficial") -and ($gpu.cloudprovider -eq "aws") -and ($gpu.Device_ID -eq "DEV_1EB8")) -eq $true){
        AWSUseSavedCreds ParsecGPUUpdate
        AWSPrivatedriver -profileName ParsecGPUUpdate -GPU "G4dn"| Out-Null
        $G4WebDriver = AWSPrivatedriver -profileName ParsecGPUUpdate -GPU "G4dn"
        $G4WebDriver.tostring().split('-')[1]
        }
    Elseif((($gpu.Supported -eq "unOfficial") -and ($gpu.cloudprovider -eq "aws") -and ($gpu.Device_ID -eq "DEV_7362")) -eq $true){
        AWSUseSavedCreds ParsecGPUUpdate
        AWSPrivatedriver -profileName ParsecGPUUpdate -GPU "G4ad"| Out-Null
        $G4WebDriver = AWSPrivatedriver -profileName ParsecGPUUpdate -GPU "G4ad"
        $G4WebDriver.tostring().split('/')[1].split('-')[0]
        }
    Elseif ((($gpu.supported -eq "UnOfficial")  -and ($gpu.cloudprovider -eq "Google"))-eq $true) {
        $googlestoragedriver =([xml](invoke-webrequest -uri https://storage.googleapis.com/nvidia-drivers-us-public).content).listbucketresult.contents.key  -like  "*GRID1*server2016*.exe" | select -Last 1
        $googlestoragedriver.split('/')[2].split('_')[0]
        }
    Elseif((($gpu.Supported -eq "yes") -and ($gpu.cloudprovider -eq "azure")) -eq $true){
        $azuresupportpage = (Invoke-WebRequest -Uri https://docs.microsoft.com/en-us/azure/virtual-machines/windows/n-series-driver-setup -UseBasicParsing).links.outerhtml -like "*GRID*"
        $azuresupportpage.split('(')[1].split(')')[0]
        }
    Else { 
        $gpu.URL = "https://www.nvidia.com/Download/processFind.aspx?psid=" + $gpu.psid + "&pfid=" + $gpu.pfid + "&osid=" + $gpu.osid + "&lid=1&whql=1&lang=en-us&ctk=0"
        $link = Invoke-WebRequest -Uri $gpu.URL -Method GET -UseBasicParsing
        $link -match '<td class="gridItem">([^<]+?)</td>' | Out-Null
        if (($matches[1] -like "*(*") -eq $true) {
            $matches[1].split('(')[1].split(')')[0]
            }
        Else {
            $matches[1]
            }
        }
    }

function GPUCurrentMode {
    #returns if the GPU is running in TCC or WDDM mode
    $nvidiaarg = "-i 0 --query-gpu=driver_model.current --format=csv,noheader"
    $nvidiasmi = "c:\program files\nvidia corporation\nvsmi\nvidia-smi" 
    try {
        Invoke-Expression "& `"$nvidiasmi`" $nvidiaarg"
        }
    catch {
        }
}

function queryOS {
    #sets OS support
    if (($system.OS_Version -like "*Windows 10*") -eq $true) {$gpu.OSID = '57' ; $system.OS_Supported = $false}
    elseif (($system.OS_Version -like "*Windows 8.1*") -eq $true) {$gpu.OSID = "41"; $system.OS_Supported = $false}
    elseif (($system.OS_Version -like "*Server 2016*") -eq $true) {$gpu.OSID = "74"; $system.OS_Supported = $true}
    elseif (($system.OS_Version -like "*Server 2019*") -eq $true) {$gpu.OSID = "119"; $system.OS_Supported = $true}
    elseif (($system.OS_Version -like "*Server 2022*") -eq $true) {$gpu.OSID = "134"; $system.OS_Supported = $true}
    Else {$system.OS_Supported = $false}
}

Function GPUUpdateAvailableMessage {
    if ($gpu.Device_ID -eq "DEV_7362") {
        "Not possible to check if the G4AD driver is up to date, the driver version available online is $($gpu.Web_Driver)"
        }
    Else {
        "Checked Now " + $system.date + " - An update is available (" + $gpu.Driver_Version + " -> " + $gpu.Web_Driver + ")" 
        }
    }

function appmessage {
    #sets most of the CLI messages
    $app.FailOS = "Sorry, this Operating system (" + $system.OS_version + ") is not yet supported by this tool."
    $app.FailGPU = "Sorry, this GPU (" + $gpu.name + ") is not yet supported by this tool."
    $app.UnOfficialGPU = "This GPU (" + $gpu.name + ") requires a private driver downloaded from the $($gpu.cloudprovider) Support Site"
    $app.NoDriver = "We detected your system does not have a valid NVIDIA Driver installed"
    $app.UpToDate = "Your PC already has the latest NVIDIA GPU Driver (" + $gpu.Web_Driver + ") available from nvidia.com."
    $app.Success = GPUUpdateAvailableMessage
    $app.ConfirmCharge = 
@"
Installing GPU Drivers may require 2 reboots in order to install correctly.  
This means you may incur some charges from your cloud provider
Type Y to continue, or N to exit.
"@                                     
}

function webName {
    #Gets the unknown GPU name from a csv based on a deviceID found in the installedgpuid function
    (New-Object System.Net.WebClient).DownloadFile("https://raw.githubusercontent.com/parsec-cloud/Cloud-GPU-Updater/master/Additional%20Files/GPUID.csv", $($system.Path + "\GPUID.CSV")) 
    Import-Csv "$($system.path)\GPUID.csv" -Delimiter ',' | Where-Object DeviceID -like *$($gpu.Device_ID)* | Select-Object -ExpandProperty GPUName
}

function queryGPU {
    #sets details about current gpu
    if($gpu.Device_ID -eq "DEV_13F2") {$gpu.Name = 'NVIDIA Tesla M60'; $gpu.PSID = '75'; $gpu.PFID = '783'; $gpu.NV_GRID = $true; $gpu.Driver_Version = driverversion; $gpu.Web_Driver = webdriver; $gpu.Update_Available = ($gpu.Web_Driver -gt $gpu.Driver_Version); $gpu.Current_Mode = GPUCurrentMode; $gpu.Supported = "Yes"; $gpu.cloudProvider = cloudprovider} 
    ElseIF($gpu.Device_ID -eq "DEV_118A") {$gpu.Name = 'NVIDIA GRID K520'; $gpu.PSID = '94'; $gpu.PFID = '704'; $gpu.NV_GRID = $true; $gpu.Driver_Version = driverversion; $gpu.Web_Driver = webdriver; $gpu.Update_Available = ($gpu.Web_Driver -gt $gpu.Driver_Version); $gpu.Current_Mode = GPUCurrentMode; $gpu.Supported = "Yes"; $gpu.cloudProvider = cloudprovider} 
    ElseIF($gpu.Device_ID -eq "DEV_1BB1") {$gpu.Name = 'NVIDIA Quadro P4000'; $gpu.PSID = '73'; $gpu.PFID = '840'; $gpu.NV_GRID = $false; $gpu.Driver_Version = driverversion; $gpu.Web_Driver = webdriver; $gpu.Update_Available = ($gpu.Web_Driver -gt $gpu.Driver_Version); $gpu.Current_Mode = GPUCurrentMode; $gpu.Supported = "Yes"; $gpu.cloudProvider = cloudprovider} 
    Elseif($gpu.Device_ID -eq "DEV_1BB0") {$gpu.Name = 'NVIDIA Quadro P5000'; $gpu.PSID = '73'; $gpu.PFID = '823'; $gpu.NV_GRID = $false; $gpu.Driver_Version = driverversion; $gpu.Web_Driver = webdriver; $gpu.Update_Available = ($gpu.Web_Driver -gt $gpu.Driver_Version); $gpu.Current_Mode = GPUCurrentMode; $gpu.Supported = "Yes"; $gpu.cloudProvider = cloudprovider}
    Elseif($gpu.Device_ID -eq "DEV_15F8") {$gpu.Name = 'NVIDIA Tesla P100'; $gpu.PSID = '103'; $gpu.PFID = '822'; $gpu.NV_GRID = $true; $gpu.Driver_Version = driverversion; $gpu.Web_Driver = webdriver; $gpu.Update_Available = ($gpu.Web_Driver -gt $gpu.Driver_Version); $gpu.Current_Mode = GPUCurrentMode; $gpu.Supported = "UnOfficial"; $gpu.cloudProvider = cloudprovider}
    Elseif($gpu.Device_ID -eq "DEV_1BB3") {$gpu.Name = 'NVIDIA Tesla P4'; $gpu.PSID = '103'; $gpu.PFID = '831'; $gpu.NV_GRID = $true; $gpu.Driver_Version = driverversion; $gpu.Web_Driver = webdriver; $gpu.Update_Available = ($gpu.Web_Driver -gt $gpu.Driver_Version); $gpu.Current_Mode = GPUCurrentMode; $gpu.Supported = "UnOfficial"; $gpu.cloudProvider = cloudprovider}
    Elseif($gpu.Device_ID -eq "DEV_1EB8") {$gpu.Name = 'NVIDIA Tesla T4'; $gpu.PSID = '110'; $gpu.PFID = '883'; $gpu.NV_GRID = $true; $gpu.Driver_Version = driverversion; $gpu.Web_Driver = webdriver; $gpu.Update_Available = ($gpu.Web_Driver -gt $gpu.Driver_Version); $gpu.Current_Mode = GPUCurrentMode; $gpu.Supported = "UnOfficial"; $gpu.cloudProvider = cloudprovider}
    ElseIf($gpu.Device_ID -eq "DEV_7362") {$gpu.Name = 'AMD Radeon Pro V520'; $gpu.Driver_Version = driverversion; $gpu.Web_Driver = webdriver; $gpu.Update_Available = ($gpu.Web_Driver -gt $gpu.Driver_Version); ; $gpu.Current_Mode = GPUCurrentMode; $gpu.Supported = "UnOfficial"; $gpu.cloudProvider = cloudprovider} 
    Elseif($gpu.Device_ID -eq $null) {$gpu.Supported = "No"; $gpu.Name = "No Device Found"}
    else{$gpu.Supported = "No"; $gpu.Name = webName} 
}

function checkOSSupport {
    #quits if OS isn't supported
    If ($system.OS_Supported -eq $false) {$app.FailOS
        Read-Host "Press any key to exit..."
        Exit
        }
    Else {
        }
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
    Else{
        }
}

function checkDriverInstalled {
    #Tells user if no GPU driver is installed
    if ($system.Valid_NVIDIA_Driver -eq $False) {
        $app.NoDriver
        }
    Else{
        }
}

function confirmcharges {
    #requests user approve potential cloud run time charges for using the tool
    $app.confirmcharge
    $ReadHost = Read-Host "(Y/N)"
        Switch ($ReadHost) 
           {
           Y {
               }
           N {
               ClearG4DNCredentials ParsecGPUUpdate
               Write-Output "The upgrade script will now exit"
               Exit
               }
           }
}

function prepareEnvironment {
    #prepares working directory
    $test = Test-Path -Path $system.path 
    if ($test -eq $true) {
        Remove-Item -path $system.Path -Recurse -Force | Out-Null
        New-Item -ItemType Directory -Force -Path $system.path | Out-Null
        }
    Else {
        New-Item -ItemType Directory -Force -Path $system.path | Out-Null
        }
}

function checkUpdates {
    queryGPU
    #starts update if required
    if ($gpu.Update_Available -eq $true) {
        $app.success
        startUpdate
        }
    Else {
        $app.UpToDate
        ClearG4DNCredentials ParsecGPUUpdate
        Read-Host "Press any key to exit..."
        Exit
    }
}

function startUpdate { 
#Gives user an option to start the update, and sends messages to the user
Write-output "Update now?"
$ReadHost = Read-Host "(Y/N)"
    Switch ($ReadHost) 
     { 
       Y {
           Write-Output `n "Downloading Driver"
           prepareEnvironment
           downloaddriver
           Write-Output  "Success!"
           Write-Output `n "Installing Driver, this may take up to 10 minutes and will automatically reboot if required"
           InstallDriver

           Write-Output "Success - Driver Installed"
           Write-Host "If this is your first time running this script, please make sure you sign into Parsec BEFORE rebooting" -BackgroundColor RED
           Write-Output "Checking if a reboot is required..."
           rebootlogic
       } 
       N {
           Write-output "Exiting Scipt"
           exit
           } 
     } 
}

function clean-registry-g4dn {
if ($($gpu.Device_ID -eq "DEV_1EB8") -or $($gpu.Device_ID -eq "DEV_15F8") -or $($gpu.Device_ID -eq "DEV_1BB3") -or $($gpu.Device_ID -eq "DEV_7362")) {
 $Configpaths  = (dir HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Configuration).pspath 
 $connectivitypaths = (dir HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Connectivity).pspath 
 foreach ($path in $Configpaths) {
  remove-item -Path $path -Recurse
  }
 foreach ($path in $connectivitypaths){
  remove-item -Path $path -Recurse
  }
 }
}

function DownloadDriver {
    if((($gpu.Supported -eq "UnOfficial") -and ($gpu.cloudprovider -eq "aws") -and ($gpu.Device_ID -eq "DEV_1EB8")) -eq $true){
        $S3Path = AWSPrivatedriver -profileName ParsecGPUUpdate -GPU "G4dn"
        (New-Object System.Net.WebClient).DownloadFile($("https://nvidia-gaming.s3.amazonaws.com/" + $s3path), $($system.Path) + "\NVIDIA_" + $($gpu.web_driver) + ".zip")
        Expand-Archive -Path ($($system.Path) + "\NVIDIA_" + $($gpu.web_driver) + ".zip") -DestinationPath "$($system.Path)\ExtractedGPUDriver\"
        $extractedpath = Get-ChildItem -Path "$($system.Path)\ExtractedGPUDriver\Windows\" | Where-Object name -like '*win10*' | % name
        Rename-Item -Path "$($system.Path)\ExtractedGPUDriver\Windows\$extractedpath" -NewName "NVIDIA_$($gpu.web_driver).exe"
        Move-Item -Path "$($system.Path)\ExtractedGPUDriver\Windows\NVIDIA_$($gpu.web_driver).exe" -Destination $system.Path
        remove-item "$($system.Path)\NVIDIA_$($gpu.web_driver).zip"
        remove-item "$($system.Path)\ExtractedGPUDriver" -Recurse
        (New-Object System.Net.WebClient).DownloadFile("https://nvidia-gaming.s3.amazonaws.com/GridSwCert-Archive/GridSwCert-Windows_2020_04.cert", "C:\Users\Public\Documents\GridSwCert.txt")
        ClearG4DNCredentials ParsecGPUUpdate
    }
    Elseif((($gpu.Supported -eq "UnOfficial") -and ($gpu.cloudprovider -eq "aws") -and ($gpu.Device_ID -eq "DEV_7362")) -eq $true){
        $S3Path = AWSPrivatedriver -profileName ParsecGPUUpdate -GPU "G4ad"
        (New-Object System.Net.WebClient).DownloadFile($("https://ec2-amd-windows-drivers.s3.amazonaws.com/" + $s3path), $($system.Path) + "\AMD_" + $($gpu.web_driver) + ".zip")
        Expand-Archive -Path ($($system.Path) + "\AMD_" + $($gpu.web_driver) + ".zip") -DestinationPath "$($system.Path)\ExtractedGPUDriver\"
        $GPU.AMDExtractedPath = Get-ChildItem -Path "$($system.Path)\ExtractedGPUDriver\" -recurse -Directory | Where-Object name -like '*WT6A_INF*' | % FullName
    }
    Elseif ((($gpu.supported -eq "UnOfficial")  -and ($gpu.cloudprovider -eq "Google"))-eq $true) {
        $googlestoragedriver =([xml](invoke-webrequest -uri https://storage.googleapis.com/nvidia-drivers-us-public).content).listbucketresult.contents.key  -like  "*GRID1*server2016*.exe" | select -last 1
        (New-Object System.Net.WebClient).DownloadFile($("https://storage.googleapis.com/nvidia-drivers-us-public/" + $googlestoragedriver), "C:\ParsecTemp\Drivers\GoogleGRID.exe")
        }
    Elseif((($gpu.Supported -eq "yes") -and ($gpu.cloudprovider -eq "aws") -and ($gpu.Device_ID -ne "DEV_118A") -and ($gpu.Device_ID -ne "DEV_1EB8")) -eq $true) {
        $s3path = $(([xml](invoke-webrequest -uri https://ec2-windows-nvidia-drivers.s3.amazonaws.com).content).listbucketresult.contents.key -like  "latest/*server2016*") 
        (New-Object System.Net.WebClient).DownloadFile($("https://ec2-windows-nvidia-drivers.s3.amazonaws.com/" + $s3path), $($system.Path) + "\NVIDIA_" + $($gpu.web_driver) + ".exe")
        }
    Elseif((($gpu.Supported -eq "yes") -and ($gpu.cloudprovider -eq "azure")) -eq $true){
        $azuresupportpage = (Invoke-WebRequest -Uri https://docs.microsoft.com/en-us/azure/virtual-machines/windows/n-series-driver-setup -UseBasicParsing).links.outerhtml -like "*GRID*"
        (New-Object System.Net.WebClient).DownloadFile($($azuresupportpage[0].split('"')[1]), $($system.Path) + "\NVIDIA_" + $($gpu.web_driver) + ".exe")
        }
    Else {
        #downloads driver from nvidia.com
        $Download.Link = Invoke-WebRequest -Uri $gpu.url -Method Get -UseBasicParsing | select @{N='Latest';E={$($_.links.href -match"www.nvidia.com/download/driverResults.aspx*")[0].substring(2)}}
        $download.Direct = Invoke-WebRequest -Uri $download.link.latest -Method Get -UseBasicParsing | select @{N= 'Download'; E={"http://us.download.nvidia.com" + $($_.links.href -match "/content/driverdownload*").split('=')[1].split('&')[0]}}
        (New-Object System.Net.WebClient).DownloadFile($($download.direct.download), $($system.Path) + "\NVIDIA_" + $($gpu.web_driver) + ".exe")
        }
}

function Test-RegistryValue {
    # https://www.jonathanmedd.net/2014/02/testing-for-the-presence-of-a-registry-key-and-value.html
    param (

     [parameter(Mandatory=$true)]
     [ValidateNotNullOrEmpty()]$Path,

    [parameter(Mandatory=$true)]
     [ValidateNotNullOrEmpty()]$Value
    )
    try {
        Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $Value -ErrorAction Stop | Out-Null
        return $true
        }
    catch {
        return $false
        }

}

function DisableSecondMonitor {
    #downloads script to set GPU to WDDM if required
    (New-Object System.Net.WebClient).DownloadFile("https://raw.githubusercontent.com/parsec-cloud/Cloud-GPU-Updater/master/Additional%20Files/DisableSecondMonitor.ps1", $($system.Path) + "\DisableSecondMonitor.ps1") 
    Unblock-File -Path "$($system.Path)\DisableSecondMonitor.ps1"
}

function DisableSecondMonitor-shortcut{
    #creates startup shortcut that will start the script downloaded in setnvsmi
    #Write-Output "Generic Non PNP Monitor"
    $Shell = New-Object -ComObject ("WScript.Shell")
    $ShortCut = $Shell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\DisableSecondMonitor.lnk")
    $ShortCut.TargetPath="powershell.exe"
    $ShortCut.Arguments='-WindowStyle hidden -ExecutionPolicy Bypass -File "C:\ParsecTemp\Drivers\DisableSecondMonitor.ps1"'
    $ShortCut.WorkingDirectory = "C:\ParsecTemp\Drivers";
    $ShortCut.WindowStyle = 0;
    $ShortCut.Description = "DisableSecondMonitor";
    $ShortCut.Save()
}


function installDriver {
    #installs driver silently with /s /n arguments provided by NVIDIA
    if ($gpu.Device_ID -ne "DEV_7362") {
        $DLpath = Get-ChildItem -Path $system.path -Include *exe* -Recurse | Select-Object -ExpandProperty Name
        Start-Process -FilePath "$($system.Path)\$dlpath" -ArgumentList "/s /n" -Wait 
        if((($gpu.Supported -eq "unOfficial") -and ($gpu.cloudprovider -eq "aws") -and ($gpu.Device_ID -eq "DEV_1EB8")) -eq $true) {
            if((Test-RegistryValue -path 'HKLM:\SOFTWARE\NVIDIA Corporation\Global' -value 'vGamingMarketplace') -eq $true) {
                Set-itemproperty -path 'HKLM:\SOFTWARE\NVIDIA Corporation\Global' -Name "vGamingMarketplace" -Value "2" | Out-Null
                } 
            else {
                new-itemproperty -path 'HKLM:\SOFTWARE\NVIDIA Corporation\Global' -Name "vGamingMarketplace" -Value "2" -PropertyType DWORD | Out-Null
                }
        DisableSecondMonitor
        DisableSecondMonitor-shortcut
        }
        Else {
        }
    }
    Else {
    pnputil /add-driver $($GPU.AMDExtractedPath+ "\*inf") /install | out-null
    DisableSecondMonitor
    DisableSecondMonitor-shortcut
    RequiresReboot -RebootRequiredReason "Script" | Out-Null
    $system.os_reboot_reason = "AMD Drivers require a reboot after installation"
    }
}

#setting up arrays below
$url = @{}
$download = @{}
$app = @{}
$gpu = @{Device_ID = installedGPUID}
$system = @{Valid_NVIDIA_Driver = ValidDriver; OS_Version = osVersion ; OS_Reboot_Required = RequiresReboot; Date = get-date; Path = "C:\ParsecTemp\Drivers"}
#OS_Reboot_Reason = "No Reboot Required"


$app.Parsec = Write-Host -foregroundcolor red "
                                                           
                   ((//////                                
                 #######//////                             
                 ##########(/////.                         
                 #############(/////,                      
                 #################/////*                   
                 #######/############////.                 
                 #######/// ##########////                 
                 #######///    /#######///                 
                 #######///     #######///                 
                 #######///     #######///                 
                 #######////    #######///                 
                 ########////// #######///                 
                 ###########////#######///                 
                   ####################///                 
                       ################///                 
                         *#############///                 
                             ##########///                 
                                ######(*                   
                                                           
                  ~Parsec GPU Updater~
" 

function rebootLogic {
    #checks if machine needs to be rebooted, and sets a startup item to set GPU mode to WDDM if required
    if ($GPU.Device_ID -eq "DEV_7362") {
        $system.OS_Reboot_Required = requiresReboot -RebootRequiredReason Script
        Reboot -message $System.OS_Reboot_Reason
        }
    Else {$system.OS_Reboot_Required = requiresReboot}
    $gpu.Current_Mode = GPUCurrentMode
    if ($system.OS_Reboot_Required -eq $true) {
        if ($GPU.NV_GRID -eq $false) {
            Reboot -message $System.OS_Reboot_Reason
            } 
        ElseIf ($GPU.NV_GRID -eq $true) {
            if ($gpu.Current_Mode -eq "TCC") {
                setnvsmi
                setnvsmi-shortcut
                }
            Reboot -message $System.OS_Reboot_Reason
            }
        Else {
            }
    }
    Else {
        if ($gpu.NV_GRID -eq $true) {
            if ($gpu.Current_Mode -eq "TCC") {
                setnvsmi
                setnvsmi-shortcut
                }
            Reboot -message $System.OS_Reboot_Reason
        }
        ElseIf ($gpu.NV_GRID -eq $false) {
            Reboot -message $System.OS_Reboot_Reason
            }
        Else{
            }
    }
}

function setnvsmi {
    #downloads script to set GPU to WDDM if required
    (New-Object System.Net.WebClient).DownloadFile("https://raw.githubusercontent.com/parsec-cloud/Cloud-GPU-Updater/master/Additional%20Files/NVSMI.ps1", $($system.Path) + "\NVSMI.ps1") 
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
$app.Parsec
"Loading..."
prepareEnvironment
queryOS
querygpu
querygpu
appmessage
checkOSSupport
checkGPUSupport
querygpu
checkDriverInstalled
ConfirmCharges
checkUpdates
 
