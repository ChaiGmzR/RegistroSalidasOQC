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

Editar **DOS** archivos con la nueva versión:

1. **frontend/pubspec.yaml** (línea 4):
```yaml
version: 1.1.0+2
```

2. **frontend/lib/config/update_config.dart** (línea 9):
```dart
static const String currentVersion = '1.1.0';
```

### Paso 2: Compilar la Aplicación
```bash
cd frontend
flutter build windows --release
```

### Paso 3: Crear Archivo ZIP
1. Navega a: `frontend\build\windows\x64\runner\Release\`
2. Selecciona **TODO** el contenido de la carpeta (no la carpeta en sí)
3. Crea un ZIP con nombre: `oqc_v1.1.0.zip`

### Paso 4: Commit y Tag de Git
```bash
git add .
git commit -m "Release v1.1.0 - Descripción de cambios"
git tag v1.1.0
git push origin main --tags
```

### Paso 5: Crear Release en GitHub
1. Ve a: https://github.com/ChaiGmzR/RegistroSalidasOQC/releases/new
2. Selecciona el tag: `v1.1.0`
3. Título: `Versión 1.1.0 - Título descriptivo`
4. Descripción: Lista de cambios (Release Notes)
5. Arrastra el archivo `oqc_v1.1.0.zip` a la sección de assets
6. Click en **Publish release**

---

## Estructura del ZIP de Release

```
oqc_v1.1.0.zip
├── oqc_registro_salidas.exe
├── flutter_windows.dll
├── url_launcher_windows_plugin.dll
├── window_manager_plugin.dll
├── printing_plugin.dll
├── updater.bat              ← ¡IMPORTANTE! Incluir este archivo
└── data/
    ├── flutter_assets/
    ├── icudtl.dat
    └── ...
```

**IMPORTANTE:** Asegúrate de incluir `updater.bat` en el ZIP. Este archivo debe copiarse desde `frontend/updater.bat` al directorio Release antes de crear el ZIP.

---

## Checklist Pre-Release

- [ ] Versión actualizada en `pubspec.yaml`
- [ ] Versión actualizada en `update_config.dart`
- [ ] Compilación exitosa (`flutter build windows --release`)
- [ ] ZIP creado con formato correcto (`oqc_vX.X.X.zip`)
- [ ] `updater.bat` incluido en el ZIP
- [ ] Tag de Git creado
- [ ] Release publicado en GitHub con ZIP adjunto

---

## Verificación

La app verificará actualizaciones automáticamente al iniciar (cada 24 horas máximo).

Para forzar verificación: Puedes agregar un botón en Configuración que llame a:
```dart
final update = await UpdateService.checkForUpdate(forceCheck: true);
```

---

## Notas Importantes

1. **Versionado Semántico**: Usa formato `MAJOR.MINOR.PATCH` (ej: 1.2.3)
2. **Tags de Git**: Siempre con prefijo `v` (ej: v1.2.3)
3. **Backward Compatibility**: Usuarios con versiones antiguas pueden actualizar a cualquier versión nueva
4. **Rollback**: Si hay problemas, crea un nuevo release con versión superior que contenga la versión anterior
