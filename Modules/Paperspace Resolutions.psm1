#version=001

function PaperspaceResolutions {

$objWMi = get-wmiobject -namespace root\WMI -computername localhost -Query "Select * from WmiMonitorID"

foreach ($obj in $objWmi)
{
$DEVICE_ID = ($obj.InstanceName.split('\')[1, 2] -join '\').split('_')[0]

$EDID = @"
00,ff,ff,ff,ff,ff,ff,00,40,30,01,00,01,00,00,00,0d,19,01,04,a5,3c
,22,78,3a,28,95,a7,55,4e,a3,26,0f,50,54,25,4b,00,d1,00,d1,c0,b3,00,a9,40,81
,80,81,00,71,4f,95,00,d4,46,00,a0,a0,38,1f,40,30,20,3a,00,80,0e,21,00,00,1a
,f6,7c,70,a0,d0,a0,29,50,30,20,3a,00,5c,68,31,00,00,1a,f5,83,40,a0,b0,08,34
,70,30,20,36,00,d0,c2,21,00,00,1a,1e,4e,d0,a0,70,dc,2b,50,30,20,34,00,f4,77
,11,00,00,1a,01,df
"@

$EDID_OVERRIDE_0 = @"
00,ff,ff,ff,ff,ff,ff,00,40,30,01,00,01,00,00,00,0d,19,01,04,a5,3c,22
,78,3a,28,95,a7,55,4e,a3,26,0f,50,54,25,4b,00,d1,00,d1,c0,b3,00,a9,40,81,80
,81,00,71,4f,95,00,d4,46,00,a0,a0,38,1f,40,30,20,3a,00,80,0e,21,00,00,1a,f6
,7c,70,a0,d0,a0,29,50,30,20,3a,00,5c,68,31,00,00,1a,f5,83,40,a0,b0,08,34,70
,30,20,36,00,d0,c2,21,00,00,1a,1e,4e,d0,a0,70,dc,2b,50,30,20,34,00,f4,77,11
,00,00,1a,01,df
"@

$EDID_OVERRIDE_1 = @'
02,03,15,00,50,10,1f,20,05,14,04,13,12,11,03,02,16,15,07,06,01,4d,d0
,00,a0,f0,70,3e,80,30,20,35,00,c0,1c,32,00,00,1e,56,5e,00,a0,a0,a0,29,50,30
,20,35,00,80,68,21,00,00,1e,09,28,dc,a0,50,e8,1d,30,30,20,3a,00,77,fa,10,00
,00,1a,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
,00,00,00,00,1a
'@



$FULL_PATH_EDID = "HKLM:\system\CurrentControlSet\Enum\DISPLAY\" + $DEVICE_ID + "\Device Parameters"
$FULL_PATH_EDID_OVERRIDE = "HKLM:\system\CurrentControlSet\Enum\DISPLAY\" + $DEVICE_ID + "\Device Parameters\EDID_OVERRIDE"

$EDID_NAME  = "EDID"
$EDID_OVERRIDE_NAME_0 = "0"
$EDID_OVERRIDE_NAME_1 = "1"

$EDID_HEX = ($EDID.Split(',') | % { "0x$_"}).trim() -ne "" 
$EDID_OVERRIDE_HEX_0 = ($EDID_OVERRIDE_0.Split(',') | % { "0x$_"}).trim() -ne "" 
$EDID_OVERRIDE_HEX_1 = ($EDID_OVERRIDE_1.Split(',') | % { "0x$_"}).trim() -ne "" 

New-Item -Path $FULL_PATH_EDID -Name "EDID_OVERRIDE" | Out-Null
New-ItemProperty -Path $FULL_PATH_EDID_OVERRIDE -Name "Default" -Value '@="Paperspace"' | Out-Null
Set-ItemProperty -Path $FULL_PATH_EDID -Name $EDID_NAME -Value ([byte[]]$EDID_HEX) | Out-Null
New-ItemProperty -Path $FULL_PATH_EDID_OVERRIDE -Name $EDID_OVERRIDE_NAME_0 -PropertyType Binary -Value ([byte[]]$EDID_OVERRIDE_HEX_0) | Out-Null
New-ItemProperty -Path $FULL_PATH_EDID_OVERRIDE -Name $EDID_OVERRIDE_NAME_1 -PropertyType Binary -Value ([byte[]]$EDID_OVERRIDE_HEX_1) | Out-Null
}

}