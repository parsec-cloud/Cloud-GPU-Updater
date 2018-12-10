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

1. Right click "GPU Updater Tool.ps1" and "Save Link As" to your Desktop 
2. On your desktop, right click "GPU Updater Tool.ps1" and select "Run with Powershell"


Q&A - Will the P100 be supported by this tool?

As soon as NVIDIA Releases publically available drivers for this GPU, it will be added.

Q&A - Why aren't Windows 10, 8.1, Server 2012 or 2019 supported

Windows 8.1 and Server 2012
There is no need currently

Windows 10 and Server 2019
When they're generally available on cloud platforms, we will investigate.
