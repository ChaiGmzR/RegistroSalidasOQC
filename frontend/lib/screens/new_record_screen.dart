import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';

import '../models/part_number.dart';
import '../models/operator.dart';
import '../services/api_service.dart';
import '../services/print_service.dart';
import '../theme/app_theme.dart';

// Modelo para caja escaneada
class ScannedBox {
  final String boxCode;
  final int quantity;
  final String? folderDate;
  final String? lastScan; // Fecha/hora de liberación LQC
  final String? partNumber; // Número de parte extraído del código de caja
  final bool
      wasInAlmacen; // Si la caja ya fue registrada previamente en almacén
  final String? previousFolio; // Folio del registro previo si existe

  ScannedBox({
    required this.boxCode,
    required this.quantity,
    this.folderDate,
    this.lastScan,
    this.partNumber,
    this.wasInAlmacen = false,
    this.previousFolio,
  });
}

class NewRecordScreen extends StatefulWidget {
  const NewRecordScreen({super.key});

  @override
  State<NewRecordScreen> createState() => _NewRecordScreenState();
}

class _NewRecordScreenState extends State<NewRecordScreen> {
  final _formKey = GlobalKey<FormState>();

  PartNumber? _selectedPartNumber;
  String?
      _extractedPartNumber; // Número de parte extraído del QR (sin validar en BD)
  Operator? _selectedOperator;

  final _operatorController = TextEditingController();
  final _partNumberController = TextEditingController();
  final _expectedQuantityController = TextEditingController();
  final _observationsController = TextEditingController();
  final _scanController = TextEditingController();

  // FocusNodes para flujo de captura
  final _operatorFocusNode = FocusNode();
  final _partNumberFocusNode = FocusNode();
  final _quantityFocusNode = FocusNode();
  final _scanFocusNode = FocusNode();

  // Lista de cajas escaneadas
  final List<ScannedBox> _scannedBoxes = [];
  bool _isScanning = false;
  String? _scanError;

  DateTime _inspectionDate = DateTime.now();
  bool _qcPassed = true;
  bool _isSubmitting = false;

  int get _totalQuantity {
    int total = 0;
    for (var box in _scannedBoxes) {
      total += box.quantity;
    }
    return total;
  }

  @override
  void dispose() {
    _operatorController.dispose();
    _partNumberController.dispose();
    _expectedQuantityController.dispose();
    _observationsController.dispose();
    _scanController.dispose();
    _operatorFocusNode.dispose();
    _partNumberFocusNode.dispose();
    _quantityFocusNode.dispose();
    _scanFocusNode.dispose();
    super.dispose();
  }

  /// Extrae el número de parte de un código QR escaneado
  /// Formato 1: EBR30299301922601070001 -> EBR30299301 (primeros 11 chars)
  /// Formato 2: I20260106-0011-1142;MAIN;EBR80757422;1; -> EBR80757422 (tercer elemento)
  String? _extractPartNumberFromQR(String qrCode) {
    final trimmed = qrCode.trim();
    final upperTrimmed = trimmed.toUpperCase();

    // Formato 2: Contiene punto y coma (;) o ñ (usado por algunos scanners)
    if (trimmed.contains(';') || trimmed.contains('ñ')) {
      // Reemplazar ñ por ; para normalizar
      final normalized = trimmed.replaceAll('ñ', ';');
      final parts = normalized.split(';');
      if (parts.length >= 3) {
        // El número de parte está en la posición 2 (índice 2)
        final partNumber = parts[2].trim().toUpperCase();
        if (partNumber.isNotEmpty && partNumber.startsWith('EBR')) {
          return partNumber;
        }
      }
      return null;
    }

    // Formato 1: Código largo que empieza con EBR (case-insensitive)
    if (upperTrimmed.startsWith('EBR') && trimmed.length >= 11) {
      return upperTrimmed.substring(0, 11);
    }

    // Si ya es un número de parte corto (11 chars)
    if (trimmed.length == 11 && upperTrimmed.startsWith('EBR')) {
      return upperTrimmed;
    }

    // Devolver como está si no coincide con ningún formato
    return trimmed.isNotEmpty ? trimmed : null;
  }

  Future<void> _onScanSubmit(String value) async {
    final boxCode = value.trim();
    if (boxCode.isEmpty) return;

    // Verificar si ya está escaneada
    if (_scannedBoxes.any((box) => box.boxCode == boxCode)) {
      setState(() {
        _scanError = 'Esta caja ya fue escaneada';
      });
      _scanController.clear();
      _scanFocusNode.requestFocus();
      return;
    }

    setState(() {
      _isScanning = true;
      _scanError = null;
    });

    try {
      // Primero validar si el boxCode ya fue registrado previamente
      final validation = await ApiService.validateBoxCode(boxCode);

      if (validation['exists'] == true) {
        final prevDestination = validation['destination'] as String?;
        final prevStatus = validation['status'] as String?;
        final prevFolio = validation['folio'] as String?;
        final prevQcPassed = validation['qcPassed'] as bool? ?? true;

        // Caso 1: Ya registrado como salida a almacén
        if (prevQcPassed && prevDestination == 'Almacen') {
          // Si estamos en modo QC Aprobado (almacén), no permitir
          if (_qcPassed) {
            setState(() {
              _scanError =
                  'Esta caja ya fue registrada como salida a almacén (Folio: $prevFolio)';
            });
            _scanController.clear();
            _scanFocusNode.requestFocus();
            return;
          }
          // Si estamos en modo rechazo, permitir pero marcar como "rechazo de almacén"
          // Este boxCode no podrá ser liberado después
        }

        // Caso 2: Ya registrado como contención y aún pendiente
        if (!prevQcPassed && prevStatus == 'pending') {
          setState(() {
            _scanError =
                'Esta caja está en contención pendiente de liberar (Folio: $prevFolio)';
          });
          _scanController.clear();
          _scanFocusNode.requestFocus();
          return;
        }

        // Caso 3: Ya registrado como contención (mismo destino que intentamos)
        if (!prevQcPassed && !_qcPassed) {
          setState(() {
            _scanError =
                'Esta caja ya fue registrada como rechazo (Folio: $prevFolio)';
          });
          _scanController.clear();
          _scanFocusNode.requestFocus();
          return;
        }
      }

      // Obtener información de la caja desde LQC
      final result = await ApiService.getBoxQuantity(boxCode);

      if (result['success'] == true) {
        // El part number viene extraído del serial en el backend
        final boxPartNumber = result['partNumber'] as String?;

        // Determinar si es un rechazo de almacén (previamente registrado en almacén)
        final wasInAlmacen = validation['exists'] == true &&
            (validation['qcPassed'] as bool? ?? true) &&
            validation['destination'] == 'Almacen';

        setState(() {
          _scannedBoxes.add(ScannedBox(
            boxCode: result['boxCode'],
            quantity: result['quantity'],
            folderDate: result['folderDate'],
            lastScan: result['lastScan'],
            partNumber: boxPartNumber,
            wasInAlmacen: wasInAlmacen,
            previousFolio: wasInAlmacen ? validation['folio'] : null,
          ));
          _scanError = null;
        });

        // Mostrar advertencia si es rechazo de almacén
        if (wasInAlmacen && !_qcPassed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '⚠️ Esta caja fue liberada previamente a almacén (${validation['folio']}). Es un rechazo de almacén y deberá volver a escanearse.'),
              backgroundColor: AppTheme.warningColor,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        setState(() {
          _scanError = result['error'] ?? 'Código no encontrado';
        });
      }
    } catch (e) {
      setState(() {
        _scanError = 'Error de conexión al validar caja';
      });
    } finally {
      setState(() => _isScanning = false);
      _scanController.clear();

      // Regresar focus al campo de escaneo después de un pequeño delay
      // para asegurar que el setState se complete primero
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _scanFocusNode.requestFocus();
        }
      });
    }
  }

  void _removeScannedBox(int index) {
    setState(() {
      _scannedBoxes.removeAt(index);
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _inspectionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _inspectionDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_extractedPartNumber == null || _selectedOperator == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor complete todos los campos requeridos'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_scannedBoxes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escanee al menos una caja'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // PUNTO 1: Validar observaciones obligatorias SIEMPRE en rechazos
    if (!_qcPassed && _observationsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Las observaciones son obligatorias al registrar un rechazo'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Validar que el PN de las cajas coincida con el PN del formulario (case-insensitive)
    final mismatchedBoxes = _scannedBoxes
        .where((box) =>
            box.partNumber != null &&
            box.partNumber!.toLowerCase() !=
                _extractedPartNumber?.toLowerCase())
        .toList();

    if (mismatchedBoxes.isNotEmpty) {
      // Si QC está aprobado, no permitir el registro con PN diferentes
      if (_qcPassed) {
        _showPartNumberMismatchDialog(mismatchedBoxes);
        return;
      }
    }

    // Validar que la cantidad esperada coincida con el total escaneado
    final expectedQty = int.tryParse(_expectedQuantityController.text) ?? 0;
    if (expectedQty != _totalQuantity) {
      // Si QC está aprobado, no permitir el registro con cantidades diferentes
      if (_qcPassed) {
        _showQuantityMismatchDialog(expectedQty);
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      // Verificar que el número de parte exista en la BD para poder registrar
      if (_selectedPartNumber == null || _selectedPartNumber!.id == null) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'El número de parte $_extractedPartNumber no está registrado en el sistema. Contacte al administrador.'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      // Preparar array de cajas para enviar al backend (cada caja = un registro)
      final boxes = _scannedBoxes
          .map((box) => {
                'boxCode': box.boxCode,
                'quantity': box.quantity,
              })
          .toList();

      // Generar string con detalle de cajas escaneadas
      final boxDetails = _scannedBoxes
          .map((box) => '${box.boxCode}: ${box.quantity} pzas')
          .join(', ');

      // Identificar cajas que son rechazos de almacén
      final almacenRejections = _scannedBoxes
          .where((box) => box.wasInAlmacen)
          .map((box) =>
              '${box.boxCode} (Rechazo Almacén - ${box.previousFolio})')
          .toList();

      // Construir observaciones con información adicional
      String observations = _observationsController.text;
      if (almacenRejections.isNotEmpty) {
        observations +=
            '\n[RECHAZO DE ALMACÉN: ${almacenRejections.join(", ")}]';
      }

      // Variables para el resultado
      String? folio;
      String? rejectionFolio;
      int recordsCreated = 0;

      if (_qcPassed) {
        // APROBACIÓN: Crear registros en exit_records
        final result = await ApiService.createExitRecordWithBoxes(
          partNumberId: _selectedPartNumber!.id!,
          esdBoxId: 1, // Default box
          operatorId: _selectedOperator!.id!,
          inspectionDate: _inspectionDate,
          destination: 'Almacen',
          observations: observations,
          qcPassed: true,
          boxes: boxes,
        );

        if (result['success'] == true) {
          folio = result['folio'] as String;
          recordsCreated = result['recordsCreated'] as int;
        } else {
          throw Exception('Error al crear registro de salida');
        }
      } else {
        // RECHAZO: Crear registro SOLO en oqc_rejections
        String rejectionReason = _observationsController.text;
        if (almacenRejections.isNotEmpty) {
          rejectionReason +=
              ' [RECHAZO DE ALMACÉN - Material debe volver a escanearse]';
        }

        final rejectionResult = await ApiService.createOqcRejection(
          exitRecordId: 0, // No asociado a exit_record
          partNumberId: _selectedPartNumber!.id!,
          operatorId: _selectedOperator!.id!,
          expectedQuantity: expectedQty,
          actualQuantity: _totalQuantity,
          rejectionReason: rejectionReason,
          boxCodes: boxDetails,
        );

        if (rejectionResult['success'] == true) {
          rejectionFolio = rejectionResult['data']['rejection_folio'];
          folio =
              rejectionFolio; // Usar el folio de rechazo como identificador principal
          recordsCreated = _scannedBoxes.length;
        } else {
          throw Exception('Error al crear rechazo OQC');
        }
      }

      if (mounted && folio != null) {
        // Capturar datos para impresión ANTES de resetear el formulario
        final printData = {
          'scannedBoxes': _scannedBoxes
              .map((b) => {
                    'boxCode': b.boxCode,
                    'lqcDate': b.lastScan ?? '',
                    'quantity': b.quantity.toString(),
                    'partNumber':
                        b.partNumber ?? _selectedPartNumber?.partNumber ?? '',
                  })
              .toList(),
          'partNumber':
              _selectedPartNumber?.partNumber ?? _extractedPartNumber ?? '',
          'partDescription': _selectedPartNumber?.description ?? '',
          'operatorName': _selectedOperator?.name ?? '',
          'operatorId': _selectedOperator?.employeeId ?? '',
          'observations': _observationsController.text,
        };

        // Recargar registros
        context.read<AppProvider>().loadExitRecords();
        context.read<AppProvider>().loadStats();

        _showSuccessDialogWithFolio(folio, recordsCreated,
            rejectionFolio: rejectionFolio, printData: printData);
        _resetForm();

        // PUNTO 3: Focus regresa al campo de operador después de registro exitoso
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _operatorFocusNode.requestFocus();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Mostrar diálogo de éxito usando folio y conteo de registros (para nuevo método de creación)
  void _showSuccessDialogWithFolio(String folio, int recordsCreated,
      {String? rejectionFolio, Map<String, dynamic>? printData}) {
    final isRejected = !_qcPassed;
    final destination = _qcPassed ? 'Almacén' : 'Contención';

    // Para liberaciones, cerrar automáticamente después de 3 segundos
    if (!isRejected) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          // Auto-cerrar después de 3 segundos
          Future.delayed(const Duration(seconds: 3), () {
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
          });

          return AlertDialog(
            icon: const Icon(
              Icons.check_circle,
              color: AppTheme.successColor,
              size: 64,
            ),
            title: const Text('Registro Creado'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Folio: $folio',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text('$recordsCreated caja(s) registrada(s)'),
                Text('Cantidad total: $_totalQuantity piezas'),
                Text('Número de Parte: ${printData?['partNumber'] ?? ''}'),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Destino: $destination',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Este mensaje se cerrará automáticamente...',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          );
        },
      );
      return;
    }

    // Para rechazos, mostrar diálogo con botón de imprimir
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppTheme.warningColor,
          size: 64,
        ),
        title: const Text('Material Rechazado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Folio: $folio',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            if (rejectionFolio != null) ...[
              const SizedBox(height: 4),
              Text(
                'Rechazo: $rejectionFolio',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.errorColor,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('$recordsCreated caja(s) registrada(s)'),
            Text('Cantidad total: $_totalQuantity piezas'),
            Text('Número de Parte: ${printData?['partNumber'] ?? ''}'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Destino: $destination',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.errorColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'El material será enviado al área de contención para revisión.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          if (printData != null)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _printRejectionTicketWithFolio(
                    folio, rejectionFolio, printData);
              },
              icon: const Icon(Icons.print),
              label: const Text('Imprimir'),
            ),
        ],
      ),
    );
  }

  /// Imprimir ticket de rechazo usando folio directamente (para nuevo método de creación)
  Future<void> _printRejectionTicketWithFolio(
    String folio,
    String? rejectionFolio,
    Map<String, dynamic> printData,
  ) async {
    if (rejectionFolio == null) return;

    // Convertir a List<Map<String, String>> para compatibilidad con PrintService
    final boxesData = (printData['scannedBoxes'] as List)
        .map((box) => {
              'boxCode': (box['boxCode'] ?? '').toString(),
              'lqcDate': (box['lqcDate'] ?? '').toString(),
              'quantity': (box['quantity'] ?? '').toString(),
              'partNumber': (box['partNumber'] ?? printData['partNumber'] ?? '')
                  .toString(),
            })
        .toList()
        .cast<Map<String, String>>();

    await PrintService.printRejectionTicket(
      rejectionFolio: rejectionFolio,
      exitFolio: folio,
      partNumber: printData['partNumber'] ?? '',
      partDescription: printData['partDescription'] ?? '',
      quantity: _totalQuantity,
      operatorName: printData['operatorName'] ?? '',
      operatorId: printData['operatorId'] ?? '',
      observations: printData['observations'] ?? '',
      boxesData: boxesData,
      rejectionDate: DateTime.now(),
    );
  }

  void _showQuantityMismatchDialog(int expectedQty) {
    final difference = _totalQuantity - expectedQty;
    final diffText = difference > 0
        ? '+$difference piezas de más'
        : '${difference.abs()} piezas de menos';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.error_outline,
          color: AppTheme.errorColor,
          size: 64,
        ),
        title: const Text('Las cantidades no coinciden'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hay una diferencia entre la cantidad ingresada y el total de las cajas escaneadas.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            _buildMismatchRow('Cantidad ingresada:', '$expectedQty pzas'),
            _buildMismatchRow('Total escaneado:', '$_totalQuantity pzas'),
            const Divider(),
            _buildMismatchRow('Diferencia:', diffText, isError: true),
            const SizedBox(height: 16),
            const Text(
              'Posibles causas:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Error al escribir la cantidad'),
            const Text('• Caja mal capturada en sistema'),
            const Text('• Piezas faltantes o sobrantes'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Revisar'),
          ),
        ],
      ),
    );
  }

  void _showPartNumberMismatchDialog(List<ScannedBox> mismatchedBoxes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppTheme.warningColor,
          size: 64,
        ),
        title: const Text('Número de parte no coincide'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Las siguientes cajas tienen un número de parte diferente al indicado ($_extractedPartNumber):',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: mismatchedBoxes.length,
                  itemBuilder: (context, index) {
                    final box = mismatchedBoxes[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.inventory_2,
                          color: AppTheme.errorColor),
                      title: Text(
                        box.boxCode,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      subtitle: Text(
                        'PN de caja: ${box.partNumber ?? "No identificado"}',
                        style: const TextStyle(color: AppTheme.errorColor),
                      ),
                      trailing: Text('${box.quantity} pzas'),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warningColor),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Para registrar como rechazo:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. Cierre este mensaje'),
                    Text('2. Desmarque la casilla "QC Aprobado"'),
                    Text('3. Escriba una observación explicando el problema'),
                    Text('4. Presione "Registrar Salida"'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'O bien:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                  '• Verifique que el número de parte escaneado sea el correcto'),
              const Text('• Elimine las cajas que no correspondan al lote'),
              const Text('• Contacte a LQC si hay inconsistencias'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Revisar'),
          ),
        ],
      ),
    );
  }

  Widget _buildMismatchRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isError ? AppTheme.errorColor : null,
            ),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _selectedOperator = null;
      _selectedPartNumber = null;
      _extractedPartNumber = null;
      _operatorController.clear();
      _partNumberController.clear();
      _expectedQuantityController.clear();
      _observationsController.clear();
      _scanController.clear();
      _scannedBoxes.clear();
      _scanError = null;
      _inspectionDate = DateTime.now();
      _qcPassed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Nuevo Registro de Salida'),
            actions: [
              TextButton.icon(
                onPressed: _resetForm,
                icon: const Icon(Icons.clear_all, color: Colors.white70),
                label: const Text(
                  'Limpiar',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Formulario principal
                  Expanded(
                    flex: 2,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Información del Registro',
                              style: AppTheme.subHeaderStyle,
                            ),
                            const SizedBox(height: 16),

                            // Operador y Número de parte en fila
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _operatorController,
                                    focusNode: _operatorFocusNode,
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      labelText: 'Operador *',
                                      prefixIcon: const Icon(Icons.badge),
                                      isDense: true,
                                      hintText: 'Escanear gafete',
                                      suffixIcon: _selectedOperator != null
                                          ? Tooltip(
                                              message: _selectedOperator!.name,
                                              child: const Icon(
                                                  Icons.check_circle,
                                                  color: AppTheme.successColor,
                                                  size: 20),
                                            )
                                          : null,
                                    ),
                                    onChanged: (value) {
                                      // Buscar operador por employeeId
                                      final op = provider.operators.firstWhere(
                                        (o) => o.employeeId == value.trim(),
                                        orElse: () => Operator(
                                            id: null, employeeId: '', name: ''),
                                      );
                                      setState(() {
                                        _selectedOperator =
                                            op.id != null ? op : null;
                                      });
                                    },
                                    onFieldSubmitted: (_) {
                                      // Al presionar Enter, ir al campo Número de Parte
                                      _partNumberFocusNode.requestFocus();
                                    },
                                    textInputAction: TextInputAction.next,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Ingrese el ID del operador';
                                      }
                                      if (_selectedOperator == null) {
                                        return 'Operador no encontrado';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _partNumberController,
                                    focusNode: _partNumberFocusNode,
                                    decoration: InputDecoration(
                                      labelText: 'Número de Parte *',
                                      prefixIcon: const Icon(Icons.qr_code),
                                      isDense: true,
                                      hintText: 'Escanear QR de pieza',
                                      suffixIcon: _extractedPartNumber != null
                                          ? const Tooltip(
                                              message:
                                                  'Número de parte extraído',
                                              child: Icon(Icons.check_circle,
                                                  color: AppTheme.successColor,
                                                  size: 20),
                                            )
                                          : null,
                                    ),
                                    onChanged: (value) {
                                      // Solo limpiar el estado mientras se escribe
                                      setState(() {
                                        _extractedPartNumber = null;
                                        _selectedPartNumber = null;
                                      });
                                    },
                                    onFieldSubmitted: (value) {
                                      // Extraer número de parte del QR escaneado
                                      final extractedPN =
                                          _extractPartNumberFromQR(value);

                                      if (extractedPN != null) {
                                        // Actualizar el campo con el PN extraído (en mayúsculas)
                                        final upperPN =
                                            extractedPN.toUpperCase();
                                        _partNumberController.text = upperPN;

                                        // Guardar el PN extraído
                                        setState(() {
                                          _extractedPartNumber = upperPN;

                                          // Buscar en BD solo para obtener el modelo (no es obligatorio que exista)
                                          // Comparación case-insensitive
                                          final pn =
                                              provider.partNumbers.firstWhere(
                                            (p) =>
                                                p.partNumber.toLowerCase() ==
                                                upperPN.toLowerCase(),
                                            orElse: () => PartNumber(
                                              id: null,
                                              partNumber: upperPN,
                                              standardPack: 0,
                                            ),
                                          );
                                          _selectedPartNumber = pn;
                                        });
                                      } else {
                                        // Si no se pudo extraer, usar el valor como está
                                        final upperValue =
                                            value.trim().toUpperCase();
                                        _partNumberController.text = upperValue;

                                        setState(() {
                                          _extractedPartNumber =
                                              upperValue.isNotEmpty
                                                  ? upperValue
                                                  : null;

                                          final pn =
                                              provider.partNumbers.firstWhere(
                                            (p) =>
                                                p.partNumber.toLowerCase() ==
                                                upperValue.toLowerCase(),
                                            orElse: () => PartNumber(
                                              id: null,
                                              partNumber: upperValue,
                                              standardPack: 0,
                                            ),
                                          );
                                          _selectedPartNumber = pn;
                                        });
                                      }

                                      // Ir al campo Cantidad
                                      _quantityFocusNode.requestFocus();
                                    },
                                    textInputAction: TextInputAction.next,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Ingrese el número de parte';
                                      }
                                      if (_extractedPartNumber == null) {
                                        return 'Número de parte inválido';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Cantidad y Fecha en fila
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _expectedQuantityController,
                                    focusNode: _quantityFocusNode,
                                    decoration: const InputDecoration(
                                      labelText: 'Cantidad a liberar *',
                                      prefixIcon: Icon(Icons.numbers),
                                      hintText: 'Ingrese cantidad total',
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    onFieldSubmitted: (_) {
                                      // Al presionar Enter, ir al campo de escaneo de cajas
                                      _scanFocusNode.requestFocus();
                                    },
                                    textInputAction: TextInputAction.next,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Ingrese la cantidad';
                                      }
                                      final qty = int.tryParse(value);
                                      if (qty == null || qty <= 0) {
                                        return 'Cantidad inválida';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: InkWell(
                                    onTap: _selectDate,
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Fecha de Inspección *',
                                        prefixIcon: Icon(Icons.calendar_today),
                                        isDense: true,
                                      ),
                                      child: Text(
                                        DateFormat('dd/MM/yyyy')
                                            .format(_inspectionDate),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Sección de Escaneo de Cajas
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.qr_code_scanner,
                                                color: AppTheme.primaryColor,
                                                size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              'Escaneo de Cajas',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (_scannedBoxes.isNotEmpty)
                                          TextButton.icon(
                                            onPressed: () {
                                              setState(() {
                                                _scannedBoxes.clear();
                                              });
                                            },
                                            icon: const Icon(Icons.clear_all,
                                                size: 16),
                                            label: const Text('Limpiar',
                                                style: TextStyle(fontSize: 12)),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  AppTheme.errorColor,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Campo de escaneo
                                    TextField(
                                      controller: _scanController,
                                      focusNode: _scanFocusNode,
                                      decoration: InputDecoration(
                                        labelText: 'Escanear código de caja',
                                        hintText: 'Ej: LGB922501026566',
                                        isDense: true,
                                        prefixIcon: _isScanning
                                            ? const Padding(
                                                padding: EdgeInsets.all(10),
                                                child: SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2),
                                                ),
                                              )
                                            : const Icon(Icons.qr_code,
                                                size: 20),
                                        errorText: _scanError,
                                        suffixIcon: IconButton(
                                          icon: const Icon(
                                              Icons.keyboard_return,
                                              size: 20),
                                          onPressed: () => _onScanSubmit(
                                              _scanController.text),
                                          tooltip: 'Agregar caja',
                                        ),
                                      ),
                                      enabled: !_isScanning,
                                      onSubmitted: _onScanSubmit,
                                      autofocus: false,
                                    ),
                                    const SizedBox(height: 10),

                                    // Lista de cajas escaneadas con tabla
                                    Expanded(
                                      child: _scannedBoxes.isEmpty
                                          ? Container(
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.inbox_outlined,
                                                        size: 36,
                                                        color: Colors
                                                            .grey.shade400),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      'Escanee códigos de cajas',
                                                      style: TextStyle(
                                                          color: Colors
                                                              .grey.shade600,
                                                          fontSize: 13),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : Column(
                                              children: [
                                                // Encabezado de tabla
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 6),
                                                  decoration: const BoxDecoration(
                                                    color: AppTheme.darkHeader,
                                                    borderRadius:
                                                        BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(8),
                                                      topRight:
                                                          Radius.circular(8),
                                                    ),
                                                  ),
                                                  child: const Row(
                                                    children: [
                                                      SizedBox(
                                                          width:
                                                              36), // Espacio para número
                                                      Expanded(
                                                        flex: 3,
                                                        child: Text(
                                                          'Código',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          'Fecha LQC',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 70,
                                                        child: Text(
                                                          'Piezas',
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(
                                                          width:
                                                              32), // Espacio para botón eliminar
                                                    ],
                                                  ),
                                                ),
                                                // Contenido de la tabla (scrollable)
                                                Expanded(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                        color: Colors
                                                            .grey.shade300,
                                                      ),
                                                    ),
                                                    child: ListView.builder(
                                                      itemCount:
                                                          _scannedBoxes.length,
                                                      itemBuilder:
                                                          (context, index) {
                                                        final box =
                                                            _scannedBoxes[
                                                                index];
                                                        // Verificar si el PN coincide
                                                        final hasError = _extractedPartNumber !=
                                                                null &&
                                                            box.partNumber !=
                                                                null &&
                                                            box.partNumber!
                                                                    .toLowerCase() !=
                                                                _extractedPartNumber!
                                                                    .toLowerCase();

                                                        // Formatear fecha
                                                        String formattedDate =
                                                            'N/A';
                                                        if (box.lastScan !=
                                                            null) {
                                                          try {
                                                            final dateStr = box
                                                                .lastScan!
                                                                .replaceAll(
                                                                    'T', ' ')
                                                                .replaceAll(
                                                                    'Z', '');
                                                            final parts =
                                                                dateStr
                                                                    .split(' ');
                                                            if (parts.length >=
                                                                2) {
                                                              final dateParts =
                                                                  parts[0]
                                                                      .split(
                                                                          '-');
                                                              final timeParts =
                                                                  parts[1]
                                                                      .split(
                                                                          ':');
                                                              if (dateParts
                                                                          .length >=
                                                                      3 &&
                                                                  timeParts
                                                                          .length >=
                                                                      2) {
                                                                formattedDate =
                                                                    '${dateParts[2]}/${dateParts[1]}/${dateParts[0]} ${timeParts[0]}:${timeParts[1]}';
                                                              }
                                                            }
                                                          } catch (_) {
                                                            formattedDate =
                                                                box.lastScan!;
                                                          }
                                                        }

                                                        return Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 6),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: hasError
                                                                ? AppTheme
                                                                    .errorColor
                                                                    .withOpacity(
                                                                        0.05)
                                                                : (index.isEven
                                                                    ? Colors
                                                                        .grey
                                                                        .shade50
                                                                    : Colors
                                                                        .white),
                                                            border: Border(
                                                              bottom:
                                                                  BorderSide(
                                                                color: Colors
                                                                    .grey
                                                                    .shade200,
                                                              ),
                                                            ),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              // Número
                                                              SizedBox(
                                                                width: 36,
                                                                child:
                                                                    CircleAvatar(
                                                                  radius: 12,
                                                                  backgroundColor: hasError
                                                                      ? AppTheme
                                                                          .errorColor
                                                                          .withOpacity(
                                                                              0.1)
                                                                      : AppTheme
                                                                          .successColor
                                                                          .withOpacity(
                                                                              0.1),
                                                                  child: Text(
                                                                    '${index + 1}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color: hasError
                                                                          ? AppTheme
                                                                              .errorColor
                                                                          : AppTheme
                                                                              .successColor,
                                                                      fontSize:
                                                                          11,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              // Código
                                                              Expanded(
                                                                flex: 3,
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Text(
                                                                      box.boxCode,
                                                                      style:
                                                                          const TextStyle(
                                                                        fontFamily:
                                                                            'monospace',
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                        fontSize:
                                                                            12,
                                                                      ),
                                                                    ),
                                                                    if (hasError)
                                                                      Row(
                                                                        children: [
                                                                          const Icon(
                                                                              Icons.error,
                                                                              size: 10,
                                                                              color: AppTheme.errorColor),
                                                                          const SizedBox(
                                                                              width: 2),
                                                                          Text(
                                                                            box.partNumber ??
                                                                                "PN: ?",
                                                                            style:
                                                                                const TextStyle(
                                                                              fontSize: 10,
                                                                              color: AppTheme.errorColor,
                                                                              fontWeight: FontWeight.bold,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                  ],
                                                                ),
                                                              ),
                                                              // Fecha
                                                              Expanded(
                                                                flex: 2,
                                                                child: Text(
                                                                  formattedDate,
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    color: Colors
                                                                        .grey
                                                                        .shade700,
                                                                  ),
                                                                ),
                                                              ),
                                                              // Piezas
                                                              SizedBox(
                                                                width: 70,
                                                                child:
                                                                    Container(
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          3),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: AppTheme
                                                                        .primaryColor,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            10),
                                                                  ),
                                                                  child: Text(
                                                                    '${box.quantity}',
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                    style:
                                                                        const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          11,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              // Botón eliminar
                                                              SizedBox(
                                                                width: 32,
                                                                child:
                                                                    IconButton(
                                                                  icon: const Icon(
                                                                      Icons
                                                                          .close,
                                                                      size: 16),
                                                                  onPressed: () =>
                                                                      _removeScannedBox(
                                                                          index),
                                                                  color: AppTheme
                                                                      .errorColor,
                                                                  padding:
                                                                      EdgeInsets
                                                                          .zero,
                                                                  constraints:
                                                                      const BoxConstraints(
                                                                    minWidth:
                                                                        28,
                                                                    minHeight:
                                                                        28,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                // Footer fijo con total
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primaryColor
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                      bottomLeft:
                                                          Radius.circular(8),
                                                      bottomRight:
                                                          Radius.circular(8),
                                                    ),
                                                    border: Border.all(
                                                      color: AppTheme
                                                          .primaryColor
                                                          .withOpacity(0.3),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        '${_scannedBoxes.length} caja(s)',
                                                        style: TextStyle(
                                                          color: Colors
                                                              .grey.shade700,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 12,
                                                          vertical: 4,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: AppTheme
                                                              .primaryColor,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(16),
                                                        ),
                                                        child: Text(
                                                          'Total: $_totalQuantity pzas',
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.white,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Observaciones y QC en fila
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _observationsController,
                                    decoration: const InputDecoration(
                                      labelText: 'Observaciones',
                                      prefixIcon: Icon(Icons.notes),
                                      isDense: true,
                                    ),
                                    maxLines: 2,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: CheckboxListTile(
                                    title: const Text(
                                      'Aprobado por QC',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      _qcPassed
                                          ? 'El material cumple con los estándares'
                                          : 'El material NO cumple con los estándares',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _qcPassed
                                            ? Colors.grey.shade600
                                            : AppTheme.errorColor,
                                      ),
                                    ),
                                    value: _qcPassed,
                                    activeColor: AppTheme.successColor,
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    onChanged: (value) {
                                      setState(() {
                                        _qcPassed = value ?? true;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Panel lateral - Resumen
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Resumen',
                                  style: AppTheme.subHeaderStyle,
                                ),
                                const Divider(),
                                const SizedBox(height: 16),
                                _SummaryRow(
                                  label: 'Operador',
                                  value: _selectedOperator?.name ?? '-',
                                ),
                                _SummaryRow(
                                  label: 'No. Parte',
                                  value: _extractedPartNumber ?? '-',
                                ),
                                _SummaryRow(
                                  label: 'Modelo',
                                  value: _selectedPartNumber?.model ??
                                      (_extractedPartNumber != null
                                          ? '(No registrado)'
                                          : '-'),
                                ),
                                _SummaryRow(
                                  label: 'Cajas',
                                  value: '${_scannedBoxes.length}',
                                ),
                                _SummaryRow(
                                  label: 'Cantidad',
                                  value: _totalQuantity > 0
                                      ? '$_totalQuantity pzas'
                                      : '-',
                                  isHighlighted: true,
                                ),
                                _SummaryRow(
                                  label: 'Fecha',
                                  value: DateFormat('dd/MM/yyyy')
                                      .format(_inspectionDate),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _qcPassed
                                        ? AppTheme.successColor.withOpacity(0.1)
                                        : AppTheme.errorColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _qcPassed
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        color: _qcPassed
                                            ? AppTheme.successColor
                                            : AppTheme.errorColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _qcPassed
                                            ? 'QC APROBADO'
                                            : 'QC RECHAZADO',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _qcPassed
                                              ? AppTheme.successColor
                                              : AppTheme.errorColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _submitForm,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(
                              _isSubmitting
                                  ? 'Guardando...'
                                  : 'Registrar Salida',
                              style: const TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlighted;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isHighlighted ? AppTheme.primaryColor : AppTheme.textMuted,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isHighlighted ? 18 : 14,
                color:
                    isHighlighted ? AppTheme.primaryColor : AppTheme.textDark,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
