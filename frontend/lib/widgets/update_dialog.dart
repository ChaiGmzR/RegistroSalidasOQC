import 'package:flutter/material.dart';
import '../models/update_info.dart';
import '../services/update_service.dart';
import '../config/update_config.dart';

/// Diálogo para mostrar información de actualización disponible
class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  /// Muestra el diálogo de actualización
  static Future<void> show(BuildContext context, UpdateInfo updateInfo) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => UpdateDialog(updateInfo: updateInfo),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.system_update,
                color: Colors.blue.shade600, size: 28),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '¡Nueva versión disponible!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información de versiones
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Versión actual',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('v${UpdateConfig.currentVersion}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward, color: Colors.grey),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Nueva versión',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('v${widget.updateInfo.version}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Notas de versión
            const Text('Notas de la versión:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  widget.updateInfo.releaseNotes,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Tamaño del archivo
            Text(
              'Tamaño: ${widget.updateInfo.formattedSize}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),

            // Barra de progreso (visible durante descarga)
            if (_isDownloading) ...[
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Descargando... ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _downloadProgress,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                ],
              ),
            ],

            // Mensaje de error
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style:
                            TextStyle(color: Colors.red.shade700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        // Botón para abrir en navegador
        TextButton.icon(
          onPressed:
              _isDownloading ? null : () => UpdateService.openReleasesPage(),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Ver en GitHub'),
        ),
        const SizedBox(width: 8),

        // Botón de recordar más tarde
        TextButton(
          onPressed: _isDownloading ? null : () => Navigator.of(context).pop(),
          child: const Text('Más tarde'),
        ),

        // Botón de actualizar
        FilledButton.icon(
          onPressed: _isDownloading ? null : _startDownload,
          icon: _isDownloading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.download, size: 18),
          label: Text(_isDownloading ? 'Descargando...' : 'Actualizar ahora'),
        ),
      ],
    );
  }

  Future<void> _startDownload() async {
    if (!widget.updateInfo.hasValidDownload) {
      setState(() {
        _errorMessage =
            'URL de descarga no disponible. Descarga manualmente desde GitHub.';
      });
      return;
    }

    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });

    try {
      final zipPath = await UpdateService.downloadUpdate(
        widget.updateInfo,
        (progress) {
          if (mounted) {
            setState(() => _downloadProgress = progress);
          }
        },
      );

      if (zipPath != null) {
        // Mostrar confirmación antes de instalar
        if (mounted) {
          final confirm = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Instalar actualización'),
              content: const Text(
                'La descarga ha finalizado. La aplicación se cerrará para completar la actualización.\n\n'
                '¿Desea continuar?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Instalar y reiniciar'),
                ),
              ],
            ),
          );

          if (confirm == true) {
            await UpdateService.installUpdate(zipPath);
          } else {
            setState(() {
              _isDownloading = false;
              _downloadProgress = 0;
            });
          }
        }
      } else {
        throw Exception('Error al descargar el archivo');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Error: $e';
        });
      }
    }
  }
}
