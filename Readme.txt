This script is made to run on Paperspace P4000, P5000, AWS G3.4xLarge and Azure NV6 machines.

This script checks NVIDIA.com for updates, and will download and install graphics drivers including
setting NVIDIA-SMI to the correct value on required GPUs.

Supported Operating Systems

Windows Server 2016

Supported GPUs

Quadro P5000
Quadro P4000
Tesla M60
GRID K520

Instructions: 
1. Download https://github.com/jamesstringerparsec/Cloud-GPU-Updater/archive/master.zip
2. Extract the folder, right click "GPU Updater Tool.ps1" and run with Powershell - if the script immediately closes, right click and click edit, then the green play button in the Powershell ISE toolbar.

Q&A - Will Google and Azure machines using the P100 be supported by this tool?

As soon as NVIDIA Releases publically available WDDM drivers for this GPU, it will be added.  The only drivers that currently work have to be downloaded through a paid enterprise portal.

Q&A - Why aren't Windows 10, 8.1, Server 2012 or 2019 supported

Windows 8.1 and Server 2012
There is no need currently.

Windows 10 and Server 2019
When they're generally available on cloud platforms, we will investigate.
