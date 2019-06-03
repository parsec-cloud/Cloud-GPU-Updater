#version=1

function M60Resolutuions {

$DEVICE_ID = ((Get-ChildItem -Path HKLM:\System\CurrentControlSet\Enum\DISPLAY\NVD0000).Name).split('\')[6]

$EDID = @"
00,ff,ff,ff,ff,ff,ff,00,3a,c4,00,00,00,00,00,00,02,1a,01,04,b5,46
,28,78,06,92,b0,a3,54,4c,99,26,0f,50,54,00,00,00,95,00,01,01,01,01,01,01,01
,01,01,01,01,01,01,01,e2,59,00,60,a3,38,28,40,a0,10,3a,10,80,0e,21,00,00,1c
,0c,a4,70,e0,d4,a0,35,50,00,70,3a,50,5c,68,31,00,00,1c,9d,2c,dc,70,51,e8,13
,30,28,90,3a,00,77,fa,10,00,00,1c,22,63,d0,d0,72,dc,37,50,90,d8,34,00,f4,77
,11,00,00,1c,01,b6
"@

$EDID_OVERRIDE_0 = @"
00,ff,ff,ff,ff,ff,ff,00,3a,c4,00,00,00,00,00,00,02,1a,01,04,b5,46,28
,78,06,92,b0,a3,54,4c,99,26,0f,50,54,00,00,00,95,00,01,01,01,01,01,01,01,01
,01,01,01,01,01,01,e2,59,00,60,a3,38,28,40,a0,10,3a,10,80,0e,21,00,00,1c,0c
,a4,70,e0,d4,a0,35,50,00,70,3a,50,5c,68,31,00,00,1c,9d,2c,dc,70,51,e8,13,30
,28,90,3a,00,77,fa,10,00,00,1c,22,63,d0,d0,72,dc,37,50,90,d8,34,00,f4,77,11
,00,00,1c,01,b6
"@

$EDID_OVERRIDE_1 = @'
70,12,5c,00,00,03,00,14,07,e8,00,04,ff,0e,2f,02,af,80,57,00,6f,08,59
,00,07,80,09,00,03,00,14,d1,d7,00,00,ff,0f,7f,00,1f,80,1f,00,6f,08,12,00,02
,80,02,00,03,00,14,be,ac,00,00,3f,0b,2f,04,df,00,37,01,07,07,40,00,02,80,05
,00,03,00,14,29,88,00,00,ff,09,af,03,bf,00,17,01,3f,06,39,00,02,80,05,00,05
,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
,00,00,00,00,90
'@



$FULL_PATH_EDID = "HKLM:\system\CurrentControlSet\Enum\DISPLAY\NVD0000\" + $DEVICE_ID + "\Device Parameters"
$FULL_PATH_EDID_OVERRIDE = "HKLM:\system\CurrentControlSet\Enum\DISPLAY\NVD0000\" + $DEVICE_ID + "\Device Parameters\EDID_OVERRIDE"

$EDID_NAME  = "EDID"
$EDID_OVERRIDE_NAME_0 = "0"
$EDID_OVERRIDE_NAME_1 = "1"

$EDID_HEX = ($EDID.Split(',') | % { "0x$_"}).trim() -ne "" 
$EDID_OVERRIDE_HEX_0 = ($EDID_OVERRIDE_0.Split(',') | % { "0x$_"}).trim() -ne "" 
$EDID_OVERRIDE_HEX_1 = ($EDID_OVERRIDE_1.Split(',') | % { "0x$_"}).trim() -ne "" 

New-Item -Path $FULL_PATH_EDID -Name "EDID_OVERRIDE" | Out-Null
New-ItemProperty -Path $FULL_PATH_EDID_OVERRIDE -Name "Default" -Value '@="NVIDIA VGX "' | Out-Null
Set-ItemProperty -Path $FULL_PATH_EDID -Name $EDID_NAME -Value ([byte[]]$EDID_HEX) | Out-Null
New-ItemProperty -Path $FULL_PATH_EDID_OVERRIDE -Name $EDID_OVERRIDE_NAME_0 -PropertyType Binary -Value ([byte[]]$EDID_OVERRIDE_HEX_0) | Out-Null
New-ItemProperty -Path $FULL_PATH_EDID_OVERRIDE -Name $EDID_OVERRIDE_NAME_1 -PropertyType Binary -Value ([byte[]]$EDID_OVERRIDE_HEX_1) | Out-Null

}