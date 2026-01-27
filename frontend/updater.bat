@echo off
REM Script de actualización para OQC Registro de Salidas
REM Uso: updater.bat <ruta_zip> <directorio_app>

setlocal enabledelayedexpansion

set "ZIP_PATH=%~1"
set "APP_DIR=%~2"
set "BACKUP_DIR=%APP_DIR%\backup"
set "TEMP_EXTRACT=%TEMP%\oqc_update_extract"
set "LOG_FILE=%APP_DIR%\update_log.txt"

echo ========================================= >> "%LOG_FILE%"
echo Inicio de actualizacion: %date% %time% >> "%LOG_FILE%"
echo ZIP: %ZIP_PATH% >> "%LOG_FILE%"
echo Directorio: %APP_DIR% >> "%LOG_FILE%"
echo ========================================= >> "%LOG_FILE%"

REM Esperar a que la aplicación cierre
echo Esperando que la aplicacion se cierre...
timeout /t 3 /nobreak > nul

REM Verificar que el ZIP existe
if not exist "%ZIP_PATH%" (
    echo ERROR: No se encontro el archivo ZIP >> "%LOG_FILE%"
    echo ERROR: No se encontro el archivo de actualizacion.
    pause
    exit /b 1
)

REM Crear directorio de backup
echo Creando respaldo...
if exist "%BACKUP_DIR%" rmdir /s /q "%BACKUP_DIR%"
mkdir "%BACKUP_DIR%"

REM Respaldar archivos importantes
copy "%APP_DIR%\*.exe" "%BACKUP_DIR%\" > nul 2>&1
copy "%APP_DIR%\*.dll" "%BACKUP_DIR%\" > nul 2>&1
xcopy "%APP_DIR%\data" "%BACKUP_DIR%\data\" /s /e /q /i > nul 2>&1

echo Respaldo creado en: %BACKUP_DIR% >> "%LOG_FILE%"

REM Extraer nueva versión
echo Extrayendo nueva version...
if exist "%TEMP_EXTRACT%" rmdir /s /q "%TEMP_EXTRACT%"
mkdir "%TEMP_EXTRACT%"

REM Usar PowerShell para extraer (Windows 10+)
powershell -Command "Expand-Archive -Path '%ZIP_PATH%' -DestinationPath '%TEMP_EXTRACT%' -Force" >> "%LOG_FILE%" 2>&1

if errorlevel 1 (
    echo ERROR: No se pudo extraer el archivo ZIP >> "%LOG_FILE%"
    echo ERROR: Fallo al extraer archivos. Restaurando...
    goto :restore
)

echo Extraccion completada >> "%LOG_FILE%"

REM Copiar archivos nuevos
echo Instalando actualizacion...

REM Buscar el directorio con el ejecutable (puede estar en subdirectorio)
for /r "%TEMP_EXTRACT%" %%f in (*.exe) do (
    set "SOURCE_DIR=%%~dpf"
    goto :found_source
)

:found_source
echo Origen encontrado: %SOURCE_DIR% >> "%LOG_FILE%"

REM Copiar todos los archivos al directorio de la app
xcopy "%SOURCE_DIR%*" "%APP_DIR%\" /s /e /y /q >> "%LOG_FILE%" 2>&1

if errorlevel 1 (
    echo ERROR: No se pudieron copiar los archivos >> "%LOG_FILE%"
    echo ERROR: Fallo al copiar archivos. Restaurando...
    goto :restore
)

echo Archivos copiados exitosamente >> "%LOG_FILE%"

REM Limpiar archivos temporales
echo Limpiando archivos temporales...
rmdir /s /q "%TEMP_EXTRACT%" > nul 2>&1
del "%ZIP_PATH%" > nul 2>&1

echo Actualizacion completada: %date% %time% >> "%LOG_FILE%"

REM Iniciar la aplicación actualizada
echo Iniciando aplicacion actualizada...

REM Buscar el ejecutable principal
for %%f in ("%APP_DIR%\*.exe") do (
    if not "%%~nxf"=="updater.exe" (
        start "" "%%f"
        goto :end
    )
)

:end
echo Proceso de actualizacion finalizado.
exit /b 0

:restore
echo Restaurando desde respaldo... >> "%LOG_FILE%"
xcopy "%BACKUP_DIR%\*" "%APP_DIR%\" /s /e /y /q > nul 2>&1
echo Respaldo restaurado >> "%LOG_FILE%"
echo Se ha restaurado la version anterior.
pause
exit /b 1
