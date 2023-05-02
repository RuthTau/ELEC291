@echo off
::This file was created automatically by CrossIDE to compile with C51.
C:
cd "\Users\tauya\Downloads\ELEC 291\lab4\"
"C:\CrossIDE\Call51\Bin\c51.exe" --use-stdout  "C:\Users\tauya\Downloads\ELEC 291\lab4\EFM8HelloWorld.c"
if not exist hex2mif.exe goto done
if exist EFM8HelloWorld.ihx hex2mif EFM8HelloWorld.ihx
if exist EFM8HelloWorld.hex hex2mif EFM8HelloWorld.hex
:done
echo done
echo Crosside_Action Set_Hex_File C:\Users\tauya\Downloads\ELEC 291\lab4\EFM8HelloWorld.hex
