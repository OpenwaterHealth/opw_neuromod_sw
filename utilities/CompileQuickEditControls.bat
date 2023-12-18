REM QuickEditOff.bat
REM This file compiles QuickEditOff.vb to QuickEditOff.exe
REM This file compiles QuickEditOn.vb to QuickEditOn.exe
REM QuickEditOff.exe turns off Quick Edit mode in the command prompt.
REM QuickEditOn.exe turns on Quick Edit mode in the command prompt.
"C:\Windows\Microsoft.NET\Framework\v4.0.30319\vbc.exe" /target:exe /out:"%~dp0\QuickEditOff.exe" "%~dp0\QuickEditOff.vb" 
"C:\Windows\Microsoft.NET\Framework\v4.0.30319\vbc.exe" /target:exe /out:"%~dp0\QuickEditOn.exe" "%~dp0\QuickEditOn.vb" 
pause