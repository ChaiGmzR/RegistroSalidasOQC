# Sistema de Actualización Automática - OQC Registro de Salidas

## Descripción General

Este documento describe el proceso completo para publicar nuevas versiones de la aplicación OQC Registro de Salidas. El sistema utiliza GitHub Releases para distribuir actualizaciones automáticas.

---

## Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────────┐
│                    APLICACIÓN INSTALADA                         │
│                                                                 │
│  ┌─────────────────┐    ┌──────────────────────────────────┐   │
│  │ UpdateService   │───>│ GitHub API                       │   │
│  │ checkForUpdate()│    │ /repos/{user}/{repo}/releases/   │   │
│  └────────┬────────┘    │ latest                           │   │
│           │             └──────────────────────────────────┘   │
│           v                                                     │
│  ┌─────────────────┐    Compara versiones:                     │
│  │ UpdateConfig    │    - currentVersion (local)               │
│  │ currentVersion  │    - tag_name (remoto)                    │
│  └─────────────────┘                                           │
│           │                                                     │
│           v                                                     │
│  ┌─────────────────┐    Busca asset que termine en .exe        │
│  │ UpdateInfo      │    Descarga browser_download_url          │
│  │ downloadUrl     │                                           │
│  └────────┬────────┘                                           │
│           │                                                     │
│           v                                                     │
│  ┌─────────────────┐    Ejecuta instalador y cierra app        │
│  │ installUpdate() │                                           │
│  └─────────────────┘                                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Archivos Clave

| Archivo | Propósito |
|---------|-----------|
| `frontend/lib/config/update_config.dart` | Configuración: versión actual, usuario GitHub, repo |
| `frontend/lib/services/update_service.dart` | Lógica de verificación, descarga e instalación |
| `frontend/lib/models/update_info.dart` | Modelo de datos del release de GitHub |
| `frontend/lib/widgets/update_dialog.dart` | Diálogo de actualización mostrado al usuario |
| `frontend/installer.iss` | Script de Inno Setup para generar instalador |
| `frontend/pubspec.yaml` | Versión del proyecto Flutter |

---

## Proceso de Publicación de Nueva Versión

### Requisitos Previos
- Inno Setup 6 instalado (`C:\Program Files (x86)\Inno Setup 6\`)
- GitHub CLI (`gh`) instalado y autenticado
- Backend compilado en `backend/dist/oqc-backend.exe`

### Paso 1: Actualizar Números de Versión

Actualizar **AMBOS** archivos con la nueva versión:

```powershell
# Ejemplo: Actualizar de 1.0.7 a 1.0.8
```

**`frontend/pubspec.yaml` (línea 4):**
```yaml
version: 1.0.8+9  # formato: MAJOR.MINOR.PATCH+BUILD
```

**`frontend/lib/config/update_config.dart` (línea 10):**
```dart
static const String currentVersion = '1.0.8';
```

**`frontend/installer.iss` (línea 5):**
```innosetup
#define MyAppVersion "1.0.8"
```

> ⚠️ **IMPORTANTE:** Si estas versiones no coinciden, el sistema de actualización no funcionará correctamente.

### Paso 2: Compilar la Aplicación

```powershell
cd frontend
flutter build windows --release
```

El ejecutable se genera en:
```
frontend/build/windows/x64/runner/Release/
```

### Paso 3: Compilar el Instalador

```powershell
cd frontend
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
```

El instalador se genera en:
```
installers/OQC_Registro_Salidas_Setup_X.Y.Z.exe
```

### Paso 4: Commit y Tag

```powershell
cd ..  # raíz del proyecto
git add -A
git commit -m "Release vX.Y.Z - Descripción de cambios"
git tag -a vX.Y.Z -m "Version X.Y.Z - Descripción"
git push origin main --tags
```

> ⚠️ **IMPORTANTE:** El tag DEBE usar el formato `vX.Y.Z` (con "v" minúscula al inicio).

### Paso 5: Crear Release en GitHub

**Opción A: Usando GitHub CLI (recomendado)**
```powershell
gh release create vX.Y.Z "installers/OQC_Registro_Salidas_Setup_X.Y.Z.exe" `
  --title "Release vX.Y.Z" `
  --notes "## Cambios en vX.Y.Z`n`n- Cambio 1`n- Cambio 2"
```

**Opción B: Desde la web**
1. Ir a https://github.com/ChaiGmzR/RegistroSalidasOQC/releases/new
2. Seleccionar el tag `vX.Y.Z`
3. Título: `Release vX.Y.Z`
4. Adjuntar el archivo `.exe` del instalador
5. Escribir notas de la versión
6. Publicar

---

## Cómo Funciona la Detección

### 1. Llamada a la API de GitHub
```dart
// update_service.dart
final response = await http.get(
  Uri.parse('https://api.github.com/repos/ChaiGmzR/RegistroSalidasOQC/releases/latest'),
  headers: {
    'Accept': 'application/vnd.github.v3+json',
    'User-Agent': 'OQC-RegistroSalidas-App',
  },
);
```

### 2. Respuesta de GitHub (ejemplo)
```json
{
  "tag_name": "v1.0.8",
  "name": "Release v1.0.8",
  "body": "Notas de la versión...",
  "assets": [
    {
      "name": "OQC_Registro_Salidas_Setup_1.0.8.exe",
      "browser_download_url": "https://github.com/.../releases/download/v1.0.8/OQC_...exe",
      "size": 54000000
    }
  ]
}
```

### 3. Extracción de Versión
```dart
// update_info.dart - Quita el prefijo "v"
static String _parseVersion(String tagName) {
  return tagName.replaceFirst(RegExp(r'^v'), '');  // "v1.0.8" → "1.0.8"
}
```

### 4. Comparación Semántica
```dart
// update_service.dart
_isNewerVersion("1.0.8", "1.0.7")  // true = hay actualización disponible
```

### 5. Búsqueda del Asset
```dart
// update_info.dart - Busca archivo que termine en ".exe"
for (var asset in assets) {
  if (asset['name'].toLowerCase().endsWith('.exe')) {
    matchingAsset = asset;
    break;
  }
}
```

---

## Configuración (`update_config.dart`)

```dart
class UpdateConfig {
  // Usuario/Organización de GitHub
  static const String githubUser = 'ChaiGmzR';
  
  // Nombre del repositorio
  static const String repoName = 'RegistroSalidasOQC';
  
  // Versión actual (DEBE coincidir con pubspec.yaml)
  static const String currentVersion = '1.0.7';
  
  // Patrón de búsqueda del asset (busca archivos que terminen así)
  static const String assetFilePattern = '.exe';
  
  // Verificar al iniciar
  static const bool checkOnStartup = true;
  
  // Intervalo mínimo entre verificaciones (0 = siempre)
  static const int checkIntervalHours = 0;
}
```

---

## Troubleshooting

### "No hay actualizaciones disponibles" cuando sí debería haber

1. **Verificar versión local:**
   - Revisar `update_config.dart` → `currentVersion`
   - Debe ser MENOR que el tag en GitHub

2. **Verificar tag en GitHub:**
   - El tag debe tener formato `vX.Y.Z` (ej: `v1.0.8`)
   - El release debe estar publicado (no como draft)

3. **Verificar asset:**
   - El release debe tener un archivo `.exe` adjunto
   - El nombre del archivo debe terminar en `.exe`

### La descarga falla

1. **Verificar conexión a internet**
2. **Rate limiting de GitHub:** 60 requests/hora para IPs no autenticadas
3. **Firewall:** Permitir conexiones a `api.github.com` y `github.com`

### El instalador no se encuentra

1. **Verificar que el asset existe en el release:**
   ```powershell
   gh release view vX.Y.Z
   ```

2. **Verificar patrón de búsqueda:**
   - El sistema busca archivos que terminen en `.exe`
   - Si subes un `.zip`, no será encontrado

---

## Checklist de Publicación

```
[ ] 1. Actualizar version en pubspec.yaml
[ ] 2. Actualizar currentVersion en update_config.dart
[ ] 3. Actualizar MyAppVersion en installer.iss
[ ] 4. flutter build windows --release
[ ] 5. Compilar instalador con ISCC.exe
[ ] 6. git add -A && git commit -m "Release vX.Y.Z"
[ ] 7. git tag -a vX.Y.Z -m "Descripción"
[ ] 8. git push origin main --tags
[ ] 9. gh release create vX.Y.Z archivo.exe --title "Release vX.Y.Z"
[ ] 10. Probar detección en versión anterior instalada
```

---

## Historial de Releases

| Versión | Fecha | Cambios Principales |
|---------|-------|---------------------|
| v1.0.7 | 2026-02-06 | Mejoras tabla rechazos, exportar CSV, DataMatrix en reportes |
| v1.0.6 | 2026-02-05 | Versión inicial con sistema de actualización |

---

*Documento actualizado: 2026-02-06*
