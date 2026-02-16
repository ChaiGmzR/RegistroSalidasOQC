# Guía de Publicación de Actualizaciones - GitHub Releases

## Configuración Inicial del Repositorio

### 1. Inicializar Git (si no está inicializado)
```bash
cd c:\Users\jesus\OneDrive\Documents\Desarrollo\OQC\RegistroSalidasOQC
git init
git add .
git commit -m "Initial commit"
```

### 2. Crear Repositorio en GitHub
1. Ve a [github.com/new](https://github.com/new)
2. Nombre del repositorio: `RegistroSalidasOQC`
3. Puede ser público o privado
4. **NO** inicialices con README, .gitignore o licencia

### 3. Conectar con GitHub
```bash
git remote add origin https://github.com/ChaiGmzR/RegistroSalidasOQC.git
git branch -M main
git push -u origin main
```

---

## Proceso de Publicación de Nueva Versión

### Paso 1: Actualizar Número de Versión

Editar **TRES** archivos con la nueva versión:

1. **frontend/pubspec.yaml** (línea 4):
```yaml
version: 1.1.0+N
```
> `+N` es el número de build incremental (ej: si la anterior fue `+9`, usar `+10`)

2. **frontend/lib/config/update_config.dart** (línea 9):
```dart
static const String currentVersion = '1.1.0';
```

3. **frontend/installer.iss** (línea 5):
```iss
#define MyAppVersion "1.1.0"
```

### Paso 2: Compilar la Aplicación Flutter
```bash
cd frontend
flutter build windows --release
```

### Paso 3: Compilar el Instalador con Inno Setup

> **⚠️ IMPORTANTE:** El release en GitHub debe contener un archivo **`.exe`** (instalador), **NO un `.zip`**.
> La app busca un asset que termine en `.exe` en el release de GitHub (`assetFilePattern = '.exe'` en `update_config.dart`).
> Si subes un `.zip` en lugar de un `.exe`, el sistema de auto-actualización **NO funcionará**.

```bash
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" "frontend\installer.iss"
```

Esto genera el instalador en: `installers\OQC_Registro_Salidas_Setup_X.X.X.exe`

### Paso 4: Commit y Tag de Git
```bash
# Excluir binarios del repo (ZIPs, .exe del instalador)
git add .
git restore --staged installers/
git restore --staged *.zip
git commit -m "Release v1.1.0 - Descripción de cambios"
git tag v1.1.0
git push origin main --tags
```

### Paso 5: Crear Release en GitHub

**Opción A: Con GitHub CLI (recomendado)**
```bash
gh release create v1.1.0 "installers/OQC_Registro_Salidas_Setup_1.1.0.exe" \
  --title "Versión 1.1.0 - Título descriptivo" \
  --notes "Descripción de cambios"
```

**Opción B: Desde la web**
1. Ve a: https://github.com/ChaiGmzR/RegistroSalidasOQC/releases/new
2. Selecciona el tag: `v1.1.0`
3. Título: `Versión 1.1.0 - Título descriptivo`
4. Descripción: Lista de cambios (Release Notes)
5. Arrastra el archivo **`OQC_Registro_Salidas_Setup_1.1.0.exe`** a la sección de assets
6. Click en **Publish release**

---

## Cómo funciona la auto-actualización

1. La app consulta la API de GitHub para el último release
2. Busca un asset cuyo nombre termine en **`.exe`** (`assetFilePattern` en `update_config.dart`)
3. Si encuentra una versión más nueva, muestra un diálogo al usuario
4. El usuario descarga el `.exe` (instalador Inno Setup) y lo ejecuta
5. El instalador cierra la app, reemplaza los archivos y la reinicia

**Si el asset subido no es `.exe`, la app no encontrará la descarga y mostrará "URL de descarga no disponible".**

---

## Estructura del Instalador

El archivo `.iss` (Inno Setup) empaqueta:

```
OQC_Registro_Salidas_Setup_X.X.X.exe  (instalador generado)
  Incluye:
  ├── Frontend (Flutter)
  │   ├── oqc_registro_salidas.exe
  │   ├── flutter_windows.dll
  │   ├── pdfium.dll
  │   ├── printing_plugin.dll
  │   ├── screen_retriever_plugin.dll
  │   ├── window_manager_plugin.dll
  │   └── data/ (flutter_assets, icudtl.dat, etc.)
  └── Backend (Node.js)
      ├── oqc-backend.exe
      └── .env
```

---

## Checklist Pre-Release

- [ ] Versión actualizada en `pubspec.yaml`
- [ ] Versión actualizada en `update_config.dart`
- [ ] Versión actualizada en `installer.iss`
- [ ] Compilación Flutter exitosa (`flutter build windows --release`)
- [ ] Instalador compilado con Inno Setup (genera `.exe` en `installers/`)
- [ ] Tag de Git creado
- [ ] Release publicado en GitHub con el **`.exe` del instalador** adjunto (NO un `.zip`)

---

## Verificación

La app verificará actualizaciones automáticamente al iniciar.

Para forzar verificación: Puedes usar el botón en Configuración o llamar a:
```dart
final update = await UpdateService.checkForUpdate(forceCheck: true);
```

Para diagnosticar problemas con actualizaciones, activa el **Modo Debug** desde
Configuración > Modo Debug / Logs y revisa los logs de la fuente "API" y "Updates".

---

## Errores Comunes

| Error | Causa | Solución |
|-------|-------|----------|
| "URL de descarga no disponible" | El release no tiene un asset `.exe` | Subir el instalador `.exe`, no un `.zip` |
| La app no detecta la actualización | Versión no actualizada en `update_config.dart` | Verificar que `currentVersion` coincida |
| Instalador no se genera | Inno Setup no instalado o `installer.iss` desactualizado | Instalar Inno Setup 6 y verificar rutas en el `.iss` |

---

## Notas Importantes

1. **Versionado Semántico**: Usa formato `MAJOR.MINOR.PATCH` (ej: 1.2.3)
2. **Tags de Git**: Siempre con prefijo `v` (ej: v1.2.3)
3. **Asset del Release**: **Siempre debe ser un `.exe`** (instalador Inno Setup)
4. **Backward Compatibility**: Usuarios con versiones antiguas pueden actualizar a cualquier versión nueva
5. **Rollback**: Si hay problemas, crea un nuevo release con versión superior que contenga la versión anterior
6. **No subir binarios al repo**: Excluir `.zip` e instaladores `.exe` del commit con `git restore --staged`
