$nvidiaarg = "--query-gpu=gpu_bus_id --format=csv,noheader"
$nvidiasmi = "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi"
$bus_id = Invoke-Expression "& `"$nvidiasmi`" $nvidiaarg"
if ($bus_id -eq "TCC") {
$outputarg1 = "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi"
$outputarg2 = "-g $bus_id -dm 0"
Invoke-Expression "& `"$outputarg1`" $outputarg2"
Restart-Computer
}
Else {Exit}