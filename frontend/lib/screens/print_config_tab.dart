import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/print_service.dart';
import 'package:printing/printing.dart';

class PrintConfigTab extends StatefulWidget {
  const PrintConfigTab({super.key});

  @override
  State<PrintConfigTab> createState() => _PrintConfigTabState();
}

class _PrintConfigTabState extends State<PrintConfigTab> {
  List<Printer> _printers = [];
  bool _loadingPrinters = true;
  late PrintConfig _config;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _config = PrintConfig(
      printerName: PrintService.config.printerName,
      orientation: PrintService.config.orientation,
      paperSize: PrintService.config.paperSize,
      marginTop: PrintService.config.marginTop,
      marginBottom: PrintService.config.marginBottom,
      marginLeft: PrintService.config.marginLeft,
      marginRight: PrintService.config.marginRight,
    );
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    setState(() => _loadingPrinters = true);
    try {
      final printers = await PrintService.getAvailablePrinters();
      setState(() {
        _printers = printers;
        _loadingPrinters = false;
      });
    } catch (e) {
      setState(() => _loadingPrinters = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar impresoras: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _saveConfig() async {
    await PrintService.saveConfig(_config);
    setState(() => _hasChanges = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración guardada correctamente'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Future<void> _printTestPage() async {
    // Save config first
    await PrintService.saveConfig(_config);

    // Generar 15 cajas de prueba con fechas LQC
    final testBoxesData = List.generate(15, (index) {
      final boxNum = (index + 1).toString().padLeft(3, '0');
      final hour = 8 + (index % 8);
      final minute = (index * 7) % 60;
      return {
        'boxCode': 'BOX$boxNum',
        'lqcDate':
            '2026-01-09T${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00.000Z',
      };
    });

    // Print test rejection ticket
    final success = await PrintService.printRejectionTicket(
      rejectionFolio: 'TEST-001',
      exitFolio: 'OQC260108TEST',
      partNumber: 'PN-TEST-12345',
      partDescription: 'Producto de prueba para verificar impresión',
      quantity: 100,
      operatorName: 'Usuario de Prueba',
      operatorId: 'EMP001',
      observations:
          'Esta es una impresión de prueba para verificar la configuración de impresora, márgenes y tamaño de papel.',
      boxesData: testBoxesData,
      rejectionDate: DateTime.now(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(success ? 'Página de prueba enviada' : 'Error al imprimir'),
          backgroundColor:
              success ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header con botón de guardar
        if (_hasChanges)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.cardBackground,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.warningColor),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Tienes cambios sin guardar',
                    style: TextStyle(color: AppTheme.textDark),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _saveConfig,
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar cambios'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                  ),
                ),
              ],
            ),
          ),

        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Primera fila: Impresora y Tamaño de Papel
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Printer Selection Section
                      Expanded(
                        child: _buildSection(
                          title: 'Impresora',
                          icon: Icons.print,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Selecciona la impresora predeterminada',
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              if (_loadingPrinters)
                                const Center(child: CircularProgressIndicator())
                              else
                                Column(
                                  children: [
                                    DropdownButtonFormField<String>(
                                      initialValue: _printers.any((p) =>
                                              p.name == _config.printerName)
                                          ? _config.printerName
                                          : null,
                                      decoration: InputDecoration(
                                        labelText: 'Impresora',
                                        prefixIcon: const Icon(Icons.print),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      dropdownColor: AppTheme.cardBackground,
                                      isExpanded: true,
                                      items: [
                                        const DropdownMenuItem(
                                          value: null,
                                          child: Text(
                                              'Mostrar diálogo de impresión'),
                                        ),
                                        ..._printers.map((printer) =>
                                            DropdownMenuItem(
                                              value: printer.name,
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    printer.isDefault
                                                        ? Icons.star
                                                        : Icons.print_outlined,
                                                    size: 16,
                                                    color: printer.isDefault
                                                        ? AppTheme.warningColor
                                                        : AppTheme.textMuted,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                      child: Text(printer.name,
                                                          overflow: TextOverflow
                                                              .ellipsis)),
                                                  if (printer.isDefault)
                                                    const Text(
                                                      '(Pred.)',
                                                      style: TextStyle(
                                                          color: AppTheme
                                                              .textMuted,
                                                          fontSize: 11),
                                                    ),
                                                ],
                                              ),
                                            )),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _config.printerName = value;
                                          _hasChanges = true;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: _loadPrinters,
                                        icon:
                                            const Icon(Icons.refresh, size: 18),
                                        label: const Text('Actualizar lista'),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Paper Size Section
                      Expanded(
                        child: _buildSection(
                          title: 'Tamaño de Papel',
                          icon: Icons.description,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Selecciona el tamaño del papel',
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<PaperSize>(
                                initialValue: _config.paperSize,
                                decoration: InputDecoration(
                                  labelText: 'Tamaño de papel',
                                  prefixIcon: const Icon(Icons.straighten),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                dropdownColor: AppTheme.cardBackground,
                                items: PaperSize.values
                                    .where((s) => s != PaperSize.custom)
                                    .map((size) => DropdownMenuItem(
                                          value: size,
                                          child: Text(size.displayName),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _config.paperSize = value;
                                      _hasChanges = true;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: AppTheme.accentBlue, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Orientación: Vertical (fija)',
                                      style: TextStyle(
                                          color: AppTheme.textDark,
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Segunda fila: Márgenes y Vista Previa
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Margins Section
                      Expanded(
                        child: _buildSection(
                          title: 'Márgenes',
                          icon: Icons.border_style,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Configura los márgenes en milímetros',
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMarginField(
                                      label: 'Superior',
                                      value: _config.marginTop,
                                      onChanged: (v) => setState(() {
                                        _config.marginTop = v;
                                        _hasChanges = true;
                                      }),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildMarginField(
                                      label: 'Inferior',
                                      value: _config.marginBottom,
                                      onChanged: (v) => setState(() {
                                        _config.marginBottom = v;
                                        _hasChanges = true;
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMarginField(
                                      label: 'Izquierdo',
                                      value: _config.marginLeft,
                                      onChanged: (v) => setState(() {
                                        _config.marginLeft = v;
                                        _hasChanges = true;
                                      }),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildMarginField(
                                      label: 'Derecho',
                                      value: _config.marginRight,
                                      onChanged: (v) => setState(() {
                                        _config.marginRight = v;
                                        _hasChanges = true;
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Preview Section
                      Expanded(
                        child: _buildSection(
                          title: 'Prueba de Impresión',
                          icon: Icons.preview,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Imprime una página de prueba',
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  // Paper preview
                                  Container(
                                    width: 80,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                          color: AppTheme.borderColor),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 4,
                                          offset: const Offset(1, 1),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.qr_code,
                                              color: Colors.grey.shade400,
                                              size: 24),
                                          const SizedBox(height: 4),
                                          Container(
                                              width: 50,
                                              height: 3,
                                              color: Colors.grey.shade300),
                                          const SizedBox(height: 2),
                                          Container(
                                              width: 40,
                                              height: 3,
                                              color: Colors.grey.shade200),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _config.paperSize.displayName,
                                          style: const TextStyle(
                                              color: AppTheme.textDark,
                                              fontWeight: FontWeight.w500),
                                        ),
                                        Text(
                                          'Márgenes: ${_config.marginTop.toInt()}/${_config.marginBottom.toInt()}/${_config.marginLeft.toInt()}/${_config.marginRight.toInt()} mm',
                                          style: const TextStyle(
                                              color: AppTheme.textMuted,
                                              fontSize: 12),
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: _printTestPage,
                                            icon: const Icon(Icons.print,
                                                size: 18),
                                            label:
                                                const Text('Imprimir prueba'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppTheme.accentBlue,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.accentBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildMarginField({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return TextFormField(
      initialValue: value.toStringAsFixed(0),
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'mm',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      keyboardType: TextInputType.number,
      onChanged: (v) {
        final parsed = double.tryParse(v);
        if (parsed != null && parsed >= 0) {
          onChanged(parsed);
        }
      },
    );
  }
}
