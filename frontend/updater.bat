@echo off
REM Script de actualizacion para OQC Registro de Salidas
REM Uso: updater.bat <ruta_zip> <directorio_app>

setlocal enabledelayedexpansion

set "ZIP_PATH=%~1"
set "APP_DIR=%~2"

REM Limpiar la ruta del directorio (quitar barra final si existe)
if "%APP_DIR:~-1%"=="\" set "APP_DIR=%APP_DIR:~0,-1%"

set "BACKUP_DIR=%APP_DIR%\backup"
set "TEMP_EXTRACT=%TEMP%\oqc_update_extract_%RANDOM%"
set "LOG_FILE=%APP_DIR%\update_log.txt"

echo ========================================= > "%LOG_FILE%"
echo Inicio de actualizacion: %date% %time% >> "%LOG_FILE%"
echo ZIP: %ZIP_PATH% >> "%LOG_FILE%"
echo Directorio APP: %APP_DIR% >> "%LOG_FILE%"
echo Temp Extract: %TEMP_EXTRACT% >> "%LOG_FILE%"
echo ========================================= >> "%LOG_FILE%"

echo.
echo =============================================
echo   OQC - Actualizador de Aplicacion
echo =============================================
echo.
echo Esperando que la aplicacion se cierre...
timeout /t 3 /nobreak > nul

REM Verificar que el ZIP existe
if not exist "%ZIP_PATH%" (
    echo ERROR: No se encontro el archivo ZIP >> "%LOG_FILE%"
    echo.
    echo [ERROR] No se encontro el archivo de actualizacion.
    echo Ruta: %ZIP_PATH%
    echo.
    pause
    exit /b 1
)

echo [OK] ZIP encontrado >> "%LOG_FILE%"
echo [1/5] Archivo ZIP verificado...

REM Crear directorio de backup
echo [2/5] Creando respaldo de seguridad...
if exist "%BACKUP_DIR%" rmdir /s /q "%BACKUP_DIR%" 2>nul
mkdir "%BACKUP_DIR%" 2>nul
copy "%APP_DIR%\*.exe" "%BACKUP_DIR%\" >nul 2>&1
copy "%APP_DIR%\*.dll" "%BACKUP_DIR%\" >nul 2>&1
echo [OK] Respaldo creado >> "%LOG_FILE%"

REM Limpiar y crear directorio temporal
echo [3/5] Extrayendo actualizacion...
if exist "%TEMP_EXTRACT%" rmdir /s /q "%TEMP_EXTRACT%" 2>nul
mkdir "%TEMP_EXTRACT%" 2>nul

REM Extraer usando PowerShell con sintaxis simplificada
echo Extrayendo con PowerShell... >> "%LOG_FILE%"
powershell.exe -NoProfile -Command "Expand-Archive -LiteralPath '%ZIP_PATH%' -DestinationPath '%TEMP_EXTRACT%' -Force" 2>>"%LOG_FILE%"

if not exist "%TEMP_EXTRACT%\oqc_registro_salidas.exe" (
    REM Buscar en subdirectorios
    for /r "%TEMP_EXTRACT%" %%f in (oqc_registro_salidas.exe) do (
        set "SOURCE_DIR=%%~dpf"
        goto :found
    )
    echo [ERROR] No se encontro el ejecutable en el ZIP >> "%LOG_FILE%"
    echo.
    echo [ERROR] El archivo ZIP no contiene la aplicacion.
    goto :restore
)
set "SOURCE_DIR=%TEMP_EXTRACT%\"

:found
echo [OK] Ejecutable encontrado en: %SOURCE_DIR% >> "%LOG_FILE%"
echo [4/5] Instalando nueva version...

REM Copiar archivos nuevos
xcopy "%SOURCE_DIR%*" "%APP_DIR%\" /s /e /y /q >>"%LOG_FILE%" 2>&1

if errorlevel 1 (
    echo [ERROR] Fallo al copiar archivos >> "%LOG_FILE%"
    echo.
    echo [ERROR] No se pudieron copiar los archivos.
    goto :restore
)

echo [OK] Archivos copiados >> "%LOG_FILE%"

REM Limpiar temporales
echo [5/5] Limpiando archivos temporales...
rmdir /s /q "%TEMP_EXTRACT%" >nul 2>&1
del "%ZIP_PATH%" >nul 2>&1

echo =============================================
echo   Actualizacion completada exitosamente!
echo =============================================
echo [OK] Actualizacion completada: %date% %time% >> "%LOG_FILE%"
echo.
echo Iniciando la aplicacion actualizada...
timeout /t 2 /nobreak >nul

REM Iniciar la nueva aplicacion
start "" "%APP_DIR%\oqc_registro_salidas.exe"
exit /b 0

:restore
echo.
echo Restaurando version anterior...
echo [RESTORE] Restaurando respaldo >> "%LOG_FILE%"
xcopy "%BACKUP_DIR%\*" "%APP_DIR%\" /s /e /y /q >nul 2>&1
echo Se ha restaurado la version anterior.
echo.
pause
exit /b 1
