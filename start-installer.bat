@echo off
setlocal
title Instalador PWA YouTube Mobile  (cierra esta ventana para detener el servidor)

rem Puerto por defecto 8787; se puede pasar otro como argumento: start-installer.bat 9000
set "PORT=%~1"
if "%PORT%"=="" set "PORT=8787"

rem El servidor vive dentro de este proceso de consola: al cerrar la ventana se detiene por completo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1" -Port %PORT% -Root "%~dp0."

echo.
echo Servidor detenido.
pause
endlocal
