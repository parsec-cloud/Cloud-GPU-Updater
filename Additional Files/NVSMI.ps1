function GPUCurrentMode {
$nvidiaarg = "-i 0 --query-gpu=driver_model.current --format=csv,noheader"
$nvidiasmi = "c:\program files\nvidia corporation\nvsmi\nvidia-smi" 
Invoke-Expression "& `"$nvidiasmi`" $nvidiaarg"}

$nvidiaarg = "--query-gpu=gpu_bus_id --format=csv,noheader"
$nvidiasmi = "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi"
$bus_id = Invoke-Expression "& `"$nvidiasmi`" $nvidiaarg"

if ((GPUCurrentMode -like "TCC") -eq $true) {
$outputarg1 = "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi"
$outputarg2 = "-g $bus_id -dm 0"
Invoke-Expression "& `"$outputarg1`" $outputarg2"
Start-Sleep -s 10
Restart-Computer
}
Else {Exit}