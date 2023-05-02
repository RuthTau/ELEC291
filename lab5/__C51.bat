@echo off
::This file was created automatically by CrossIDE to compile with C51.
C:
cd "\Users\tauya\Downloads\ELEC 291\Lab5\"
"C:\CrossIDE\Call51\Bin\c51.exe" --use-stdout  "C:\Users\tauya\Downloads\ELEC 291\Lab5\lab506.c"
if not exist hex2mif.exe goto done
if exist lab506.ihx hex2mif lab506.ihx
if exist lab506.hex hex2mif lab506.hex
:done
echo done
echo Crosside_Action Set_Hex_File C:\Users\tauya\Downloads\ELEC 291\Lab5\lab506.hex
