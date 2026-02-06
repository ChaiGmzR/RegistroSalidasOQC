import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../providers/app_provider.dart';
import '../models/exit_record.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ExitRecordsScreen extends StatefulWidget {
  const ExitRecordsScreen({super.key});

  @override
  State<ExitRecordsScreen> createState() => _ExitRecordsScreenState();
}

class _ExitRecordsScreenState extends State<ExitRecordsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Filtros para pestaña Liberación
  DateTime? _liberacionStartDate;
  DateTime? _liberacionEndDate;
  final _liberacionSearchController = TextEditingController();

  // Filtros para pestaña Rechazos
  String _rechazosStatusFilter = 'all'; // 'all', 'pending', 'released'
  final _rechazosSearchController = TextEditingController();

  // Lista de rechazos de oqc_rejections
  List<Map<String, dynamic>> _oqcRejections = [];
  bool _loadingRejections = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Por defecto, Liberación muestra registros de hoy
    final today = DateTime.now();
    _liberacionStartDate = DateTime(today.year, today.month, today.day);
    _liberacionEndDate =
        DateTime(today.year, today.month, today.day, 23, 59, 59);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLiberacionRecords();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _liberacionSearchController.dispose();
    _rechazosSearchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;

    if (_tabController.index == 0) {
      _loadLiberacionRecords();
    } else {
      _loadRechazosRecords();
    }
  }

  void _loadLiberacionRecords() {
    final provider = context.read<AppProvider>();
    provider.loadExitRecords(
      startDate: _liberacionStartDate?.toIso8601String().split('T')[0],
      endDate: _liberacionEndDate?.toIso8601String().split('T')[0],
      partNumber: _liberacionSearchController.text.isEmpty
          ? null
          : _liberacionSearchController.text,
      qcPassed: true, // Solo registros aprobados
    );
  }

  void _loadRechazosRecords() async {
    setState(() {
      _loadingRejections = true;
    });

    try {
      final status =
          _rechazosStatusFilter == 'all' ? null : _rechazosStatusFilter;
      final rejections = await ApiService.getOqcRejections(status: status);

      // Filtrar por búsqueda si hay texto
      final searchText = _rechazosSearchController.text.toLowerCase();
      if (searchText.isNotEmpty) {
        setState(() {
          _oqcRejections = rejections.where((r) {
            final partNumber =
                (r['part_number'] ?? '').toString().toLowerCase();
            final folio = (r['rejection_folio'] ?? '').toString().toLowerCase();
            return partNumber.contains(searchText) ||
                folio.contains(searchText);
          }).toList();
        });
      } else {
        setState(() {
          _oqcRejections = rejections;
        });
      }
    } catch (e) {
      print('Error loading rejections: $e');
    } finally {
      setState(() {
        _loadingRejections = false;
      });
    }
  }

  void _clearLiberacionFilters() {
    final today = DateTime.now();
    setState(() {
      _liberacionStartDate = DateTime(today.year, today.month, today.day);
      _liberacionEndDate =
          DateTime(today.year, today.month, today.day, 23, 59, 59);
      _liberacionSearchController.clear();
    });
    _loadLiberacionRecords();
  }

  void _clearRechazosFilters() {
    setState(() {
      _rechazosStatusFilter = 'all';
      _rechazosSearchController.clear();
    });
    _loadRechazosRecords();
  }

  Future<void> _exportRejectionsToExcel() async {
    if (_oqcRejections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros para exportar')),
      );
      return;
    }

    try {
      final StringBuffer csv = StringBuffer();
      csv.writeln(
          'Folio Rechazo,No. Parte,Cant. Esperada,Cant. Real,Operador,Fecha,Estado,Cajas,Observaciones');

      for (final r in _oqcRejections) {
        final fecha = r['rejection_date'] != null
            ? DateFormat('dd/MM/yyyy HH:mm')
                .format(DateTime.parse(r['rejection_date'].toString()))
            : '';
        final estado = r['status'] == 'pending'
            ? 'En Contención'
            : r['status'] == 'released'
                ? 'Liberado'
                : r['status'];
        final observaciones = (r['rejection_reason'] ?? '')
            .toString()
            .replaceAll(',', ';')
            .replaceAll('\n', ' ');
        final cajas = (r['box_codes'] ?? '-').toString().split(',').length;

        csv.writeln('${r['rejection_folio'] ?? ""},'
            '${r['part_number'] ?? ""},'
            '${r['expected_quantity'] ?? 0},'
            '${r['actual_quantity'] ?? 0},'
            '${r['operator_name'] ?? ""},'
            '$fecha,'
            '$estado,'
            '$cajas,'
            '$observaciones');
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'rechazos_$timestamp.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csv.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Archivo exportado: ${file.path}'),
            action: SnackBarAction(
              label: 'Abrir carpeta',
              onPressed: () {
                Process.run('explorer', [directory.path]);
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    }
  }

  void _showRejectionDetails(Map<String, dynamic> rejection) {
    final rejectionDate = rejection['rejection_date'] != null
        ? DateTime.tryParse(rejection['rejection_date'].toString())
        : null;
    final boxCodes = (rejection['box_codes'] ?? '').toString().split(',');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Rechazo ${rejection['rejection_folio']}'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                  'No. Parte:', rejection['part_number']?.toString() ?? '-'),
              _buildDetailRow(
                  'Cant. Esperada:', '${rejection['expected_quantity'] ?? 0}'),
              _buildDetailRow(
                  'Cant. Real:', '${rejection['actual_quantity'] ?? 0}'),
              _buildDetailRow(
                  'Operador:', rejection['operator_name']?.toString() ?? '-'),
              _buildDetailRow(
                  'Fecha:',
                  rejectionDate != null
                      ? DateFormat('dd/MM/yyyy HH:mm').format(rejectionDate)
                      : '-'),
              _buildDetailRow(
                  'Estado:',
                  rejection['status'] == 'pending'
                      ? 'En Contención'
                      : 'Liberado'),
              const SizedBox(height: 16),
              const Text('Observaciones:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(rejection['rejection_reason']?.toString() ??
                  'Sin observaciones'),
              const SizedBox(height: 16),
              const Text('Cajas:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...boxCodes.map((code) => Text('• $code')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showReleaseConfirmation(Map<String, dynamic> rejection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Liberar Rechazo'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '¿Confirma liberar el rechazo ${rejection['rejection_folio']}?'),
            const SizedBox(height: 8),
            Text('No. Parte: ${rejection['part_number']}'),
            Text('Cantidad: ${rejection['actual_quantity']} piezas'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Función de liberación pendiente de implementar en el backend')),
              );
              _loadRechazosRecords();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Liberar'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectLiberacionDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange:
          _liberacionStartDate != null && _liberacionEndDate != null
              ? DateTimeRange(
                  start: _liberacionStartDate!, end: _liberacionEndDate!)
              : null,
    );
    if (picked != null) {
      setState(() {
        _liberacionStartDate = picked.start;
        _liberacionEndDate = picked.end;
      });
      _loadLiberacionRecords();
    }
  }

  void _showRecordDetails(ExitRecord record) {
    showDialog(
      context: context,
      builder: (context) => _RecordDetailsDialog(record: record),
    );
  }

  Future<void> _exportToExcel(List<ExitRecord> records, String type) async {
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros para exportar')),
      );
      return;
    }

    try {
      // Crear contenido CSV (compatible con Excel)
      final StringBuffer csv = StringBuffer();

      // Encabezados
      csv.writeln(
          'Folio,Número de Parte,Modelo,Cantidad,Caja ESD,Lote,Operador,Fecha,${type == 'rechazos' ? 'Estado,' : ''}Observaciones');

      // Datos
      for (final record in records) {
        final fecha = record.exitDate != null
            ? DateFormat('dd/MM/yyyy HH:mm').format(record.exitDate!)
            : '';
        final observaciones = (record.observations ?? '')
            .replaceAll(',', ';')
            .replaceAll('\n', ' ');
        final estado = record.status == 'pending'
            ? 'En Contención'
            : record.status == 'released'
                ? 'Liberado'
                : record.status;

        csv.writeln('${record.folio ?? ""},'
            '${record.partNumber ?? ""},'
            '${record.model ?? ""},'
            '${record.quantity},'
            '${record.boxCode ?? ""},'
            '${record.lotNumber ?? ""},'
            '${record.operatorName ?? ""},'
            '$fecha,'
            '${type == 'rechazos' ? '$estado,' : ''}'
            '$observaciones');
      }

      // Guardar archivo
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = '${type}_$timestamp.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csv.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Archivo exportado: ${file.path}'),
            action: SnackBarAction(
              label: 'Abrir carpeta',
              onPressed: () {
                Process.run('explorer', [directory.path]);
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    }
  }

  void _showStatusChangeDialog(ExitRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar Estado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Folio: ${record.folio}'),
            const SizedBox(height: 16),
            const Text('Seleccione el nuevo estado:'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          if (record.status == 'pending')
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await context
                    .read<AppProvider>()
                    .updateExitRecordStatus(record.id!, 'released');
                // Recargar la pestaña actual
                if (_tabController.index == 1) {
                  _loadRechazosRecords();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
              ),
              child: const Text('Liberar'),
            ),
          if (record.status == 'released')
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await context
                    .read<AppProvider>()
                    .updateExitRecordStatus(record.id!, 'shipped');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
              ),
              child: const Text('Marcar Enviado'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Registros de Salida'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  if (_tabController.index == 0) {
                    _loadLiberacionRecords();
                  } else {
                    _loadRechazosRecords();
                  }
                },
                tooltip: 'Actualizar',
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: Column(
            children: [
              // Pestañas alineadas a la izquierda
              Container(
                color: const Color(
                    0xFFE8E8E8), // Fondo gris claro para área de pestañas
                child: Row(
                  children: [
                    // Las pestañas ocupan 1/5 del ancho
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.20,
                      child: Row(
                        children: [
                          // Pestaña Liberación
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _tabController.animateTo(0),
                              child: AnimatedBuilder(
                                animation: _tabController,
                                builder: (context, _) {
                                  final isSelected = _tabController.index == 0;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(
                                              0xFFF5F5F5) // Mismo color que contenido
                                          : const Color(
                                              0xFFE0E0E0), // Más oscuro
                                      border: Border(
                                        bottom: BorderSide(
                                          color: isSelected
                                              ? AppTheme.primaryColor
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'Liberación',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppTheme.textDark,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          // Pestaña Rechazos
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _tabController.animateTo(1),
                              child: AnimatedBuilder(
                                animation: _tabController,
                                builder: (context, _) {
                                  final isSelected = _tabController.index == 1;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFF5F5F5)
                                          : const Color(0xFFE0E0E0),
                                      border: Border(
                                        bottom: BorderSide(
                                          color: isSelected
                                              ? AppTheme.primaryColor
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'Rechazos',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppTheme.textDark,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Espacio restante
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ),
              // Contenido de pestañas
              Expanded(
                child: Container(
                  color: const Color(0xFFF5F5F5),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLiberacionTab(provider),
                      _buildRechazosTab(provider),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiberacionTab(AppProvider provider) {
    // Filtrar solo registros con qc_passed = true
    final liberacionRecords =
        provider.exitRecords.where((r) => r.qcPassed).toList();

    return Column(
      children: [
        // Filtros de Liberación
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              // Búsqueda
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _liberacionSearchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por número de parte o folio...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _liberacionSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _liberacionSearchController.clear();
                              _loadLiberacionRecords();
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onSubmitted: (_) => _loadLiberacionRecords(),
                ),
              ),
              const SizedBox(width: 16),

              // Rango de fechas
              OutlinedButton.icon(
                onPressed: _selectLiberacionDateRange,
                icon: const Icon(Icons.date_range),
                label: Text(
                  _liberacionStartDate != null && _liberacionEndDate != null
                      ? '${DateFormat('dd/MM').format(_liberacionStartDate!)} - ${DateFormat('dd/MM').format(_liberacionEndDate!)}'
                      : 'Rango de fechas',
                ),
              ),
              const SizedBox(width: 8),

              // Limpiar filtros
              if (_liberacionSearchController.text.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearLiberacionFilters,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Limpiar'),
                ),
              const SizedBox(width: 8),

              // Exportar a Excel
              OutlinedButton.icon(
                onPressed: liberacionRecords.isNotEmpty
                    ? () => _exportToExcel(liberacionRecords, 'Liberacion')
                    : null,
                icon: const Icon(Icons.download),
                label: const Text('Exportar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green[700],
                  side: BorderSide(color: Colors.green[300]!),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Tabla de liberación
        Expanded(
          child: liberacionRecords.isEmpty
              ? _buildEmptyState('No hay registros de liberación')
              : _buildDataTable(liberacionRecords, showStatusColumn: false),
        ),
      ],
    );
  }

  Widget _buildRechazosTab(AppProvider provider) {
    return Column(
      children: [
        // Filtros de Rechazos
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              // Búsqueda
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _rechazosSearchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por número de parte o folio...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _rechazosSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _rechazosSearchController.clear();
                              _loadRechazosRecords();
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onSubmitted: (_) => _loadRechazosRecords(),
                ),
              ),
              const SizedBox(width: 16),

              // Filtro de estado
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _rechazosStatusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('Todos'),
                    ),
                    DropdownMenuItem(
                      value: 'pending',
                      child: Text('En Contención'),
                    ),
                    DropdownMenuItem(
                      value: 'released',
                      child: Text('Liberados'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _rechazosStatusFilter = value ?? 'all';
                    });
                    _loadRechazosRecords();
                  },
                ),
              ),
              const SizedBox(width: 16),

              // Limpiar filtros
              if (_rechazosStatusFilter != 'all' ||
                  _rechazosSearchController.text.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearRechazosFilters,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Limpiar'),
                ),
              const SizedBox(width: 8),

              // Exportar a CSV
              OutlinedButton.icon(
                onPressed: _oqcRejections.isNotEmpty
                    ? () => _exportRejectionsToExcel()
                    : null,
                icon: const Icon(Icons.download),
                label: const Text('Exportar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green[700],
                  side: BorderSide(color: Colors.green[300]!),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Tabla de rechazos
        Expanded(
          child: _loadingRejections
              ? const Center(child: CircularProgressIndicator())
              : _oqcRejections.isEmpty
                  ? _buildEmptyState('No hay registros de rechazos')
                  : _buildRejectionsTable(),
        ),
      ],
    );
  }

  Widget _buildRejectionsTable() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        child: DataTable2(
          columnSpacing: 12,
          horizontalMargin: 12,
          minWidth: 1200,
          border: TableBorder.all(
            color: Colors.grey.shade200,
            width: 0.5,
            borderRadius: BorderRadius.circular(8),
          ),
          headingRowColor: WidgetStateProperty.all(
            const Color(0xFF1565C0),
          ),
          headingTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          columns: const [
            DataColumn2(
              label: Text('Folio Rechazo'),
              size: ColumnSize.M,
            ),
            DataColumn2(
              label: Text('No. Parte'),
              size: ColumnSize.L,
            ),
            DataColumn2(
              label: Center(child: Text('Cant. Esp.')),
              size: ColumnSize.S,
              numeric: true,
            ),
            DataColumn2(
              label: Center(child: Text('Cant. Real')),
              size: ColumnSize.S,
              numeric: true,
            ),
            DataColumn2(
              label: Text('Operador'),
              size: ColumnSize.M,
            ),
            DataColumn2(
              label: Center(child: Text('Fecha')),
              size: ColumnSize.M,
            ),
            DataColumn2(
              label: Text('Estado'),
              size: ColumnSize.S,
            ),
            DataColumn2(
              label: Center(child: Text('Cajas')),
              size: ColumnSize.S,
              numeric: true,
            ),
            DataColumn2(
              label: Text('Acciones'),
              size: ColumnSize.S,
              fixedWidth: 100,
            ),
          ],
          rows: _oqcRejections.map((rejection) {
            final rejectionDate = rejection['rejection_date'] != null
                ? DateTime.tryParse(rejection['rejection_date'].toString())
                : null;

            return DataRow2(
              cells: [
                DataCell(
                  Text(
                    rejection['rejection_folio']?.toString() ?? '-',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataCell(
                  Text(rejection['part_number']?.toString() ?? '-'),
                ),
                DataCell(
                  Center(
                    child: Text(NumberFormat('#,###')
                        .format(rejection['expected_quantity'] ?? 0)),
                  ),
                ),
                DataCell(
                  Center(
                    child: Text(NumberFormat('#,###')
                        .format(rejection['actual_quantity'] ?? 0)),
                  ),
                ),
                DataCell(Text(rejection['operator_name']?.toString() ?? '-')),
                DataCell(
                  Center(
                    child: Text(
                      rejectionDate != null
                          ? DateFormat('dd/MM/yy HH:mm').format(rejectionDate)
                          : '-',
                    ),
                  ),
                ),
                DataCell(
                  _StatusBadge(
                      status: rejection['status']?.toString() ?? 'pending'),
                ),
                DataCell(
                  Center(
                    child: Text((rejection['box_codes'] ?? '-')
                        .toString()
                        .split(',')
                        .length
                        .toString()),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility, size: 18),
                        onPressed: () => _showRejectionDetails(rejection),
                        tooltip: 'Ver detalles',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      if (rejection['status'] == 'pending')
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline,
                              size: 18, color: Colors.green),
                          onPressed: () => _showReleaseConfirmation(rejection),
                          tooltip: 'Liberar',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(List<ExitRecord> records,
      {required bool showStatusColumn}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: DataTable2(
          columnSpacing: 12,
          horizontalMargin: 12,
          minWidth: showStatusColumn ? 1000 : 900,
          headingRowColor: WidgetStateProperty.all(
            const Color(0xFF1565C0),
          ),
          headingTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          columns: [
            const DataColumn2(
              label: Text('Folio'),
              size: ColumnSize.M,
            ),
            const DataColumn2(
              label: Text('No. Parte'),
              size: ColumnSize.L,
            ),
            const DataColumn2(
              label: Text('Cantidad'),
              size: ColumnSize.S,
              numeric: true,
            ),
            const DataColumn2(
              label: Text('Caja ESD'),
              size: ColumnSize.S,
            ),
            const DataColumn2(
              label: Text('Lote'),
              size: ColumnSize.M,
            ),
            const DataColumn2(
              label: Text('Operador'),
              size: ColumnSize.M,
            ),
            const DataColumn2(
              label: Text('Fecha'),
              size: ColumnSize.M,
            ),
            if (showStatusColumn)
              const DataColumn2(
                label: Text('Estado'),
                size: ColumnSize.S,
              ),
            const DataColumn2(
              label: Text('Acciones'),
              size: ColumnSize.S,
            ),
          ],
          rows: records.map((record) {
            return DataRow2(
              onTap: () => _showRecordDetails(record),
              cells: [
                DataCell(
                  Text(
                    record.folio ?? '-',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.partNumber ?? '-'),
                      if (record.model != null)
                        Text(
                          record.model!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                DataCell(
                  Text(
                    NumberFormat('#,###').format(record.quantity),
                  ),
                ),
                DataCell(Text(record.boxCode ?? '-')),
                DataCell(Text(record.lotNumber ?? '-')),
                DataCell(Text(record.operatorName ?? '-')),
                DataCell(
                  Text(
                    record.exitDate != null
                        ? DateFormat('dd/MM/yy HH:mm').format(record.exitDate!)
                        : '-',
                  ),
                ),
                if (showStatusColumn)
                  DataCell(
                    _StatusBadge(status: record.status),
                  ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () => _showRecordDetails(record),
                        tooltip: 'Ver detalles',
                      ),
                      if (showStatusColumn &&
                          record.status != 'cancelled' &&
                          record.status != 'shipped')
                        IconButton(
                          icon: const Icon(
                            Icons.edit_note,
                            size: 20,
                          ),
                          onPressed: () => _showStatusChangeDialog(record),
                          tooltip: 'Cambiar estado',
                        ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    IconData? icon;

    switch (status) {
      case 'pending':
        color = AppTheme.warningColor;
        text = 'Contención';
        icon = Icons.warning_amber;
        break;
      case 'released':
        color = AppTheme.successColor;
        text = 'Liberado';
        icon = Icons.check_circle_outline;
        break;
      case 'shipped':
        color = AppTheme.accentColor;
        text = 'Enviado';
        icon = Icons.local_shipping_outlined;
        break;
      case 'cancelled':
        color = AppTheme.errorColor;
        text = 'Cancelado';
        icon = Icons.cancel_outlined;
        break;
      default:
        color = Colors.grey;
        text = status;
        icon = null;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RecordDetailsDialog extends StatelessWidget {
  final ExitRecord record;

  const _RecordDetailsDialog({required this.record});

  List<String> _extractBoxCodes() {
    if (record.observations == null || record.observations!.isEmpty) {
      return [];
    }

    final regex = RegExp(r'BoxCodes:\s*\[([^\]]*)\]');
    final match = regex.firstMatch(record.observations!);

    if (match != null && match.group(1) != null) {
      final codesString = match.group(1)!;
      return codesString
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return [];
  }

  String _getCleanObservations() {
    if (record.observations == null || record.observations!.isEmpty) {
      return '-';
    }

    String clean = record.observations!
        .replaceAll(RegExp(r'BoxCodes:\s*\[[^\]]*\]\s*'), '')
        .replaceAll(
            RegExp(r'\[Rechazo de Almacén - Folio anterior: [^\]]+\]\s*'), '')
        .trim();

    return clean.isEmpty ? '-' : clean;
  }

  @override
  Widget build(BuildContext context) {
    final boxCodes = _extractBoxCodes();
    final cleanObservations = _getCleanObservations();

    return Dialog(
      child: Container(
        width: 550,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Folio: ${record.folio}',
                    style: AppTheme.headerStyle.copyWith(fontSize: 20),
                  ),
                  if (!record.qcPassed) _StatusBadge(status: record.status),
                ],
              ),
            ),

            // Banner informativo según tipo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: record.qcPassed
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(
                    record.qcPassed ? Icons.check_circle : Icons.warning_amber,
                    color: record.qcPassed
                        ? Colors.green[700]
                        : Colors.orange[700],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    record.qcPassed
                        ? 'Registro de Liberación'
                        : 'Registro de Rechazo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: record.qcPassed
                          ? Colors.green[800]
                          : Colors.orange[800],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Contenido scrolleable
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow('Número de Parte', record.partNumber ?? '-'),
                    _DetailRow('Descripción', record.partDescription ?? '-'),
                    _DetailRow('Modelo', record.model ?? '-'),
                    _DetailRow('Cantidad', '${record.quantity} piezas'),
                    _DetailRow('Operador', record.operatorName ?? '-'),
                    _DetailRow(
                      'Fecha de Inspección',
                      DateFormat('dd/MM/yyyy HH:mm')
                          .format(record.inspectionDate),
                    ),
                    _DetailRow('Destino', record.destination),
                    _DetailRow('Observaciones', cleanObservations),

                    const SizedBox(height: 16),

                    // Tabla de Box Codes
                    if (boxCodes.isNotEmpty) ...[
                      const Text(
                        'Cajas Registradas',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          child: Table(
                            border: TableBorder(
                              horizontalInside:
                                  BorderSide(color: Colors.grey[200]!),
                            ),
                            columnWidths: const {
                              0: FixedColumnWidth(50),
                              1: FlexColumnWidth(),
                            },
                            children: [
                              TableRow(
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(7),
                                  ),
                                ),
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Text(
                                      '#',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Text(
                                      'Box Code',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              ...boxCodes.asMap().entries.map((entry) {
                                return TableRow(
                                  decoration: BoxDecoration(
                                    color: entry.key.isEven
                                        ? Colors.white
                                        : Colors.grey[50],
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Text('${entry.key + 1}'),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Text(
                                        entry.value,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ] else
                      const _DetailRow('Cajas', 'Sin cajas registradas'),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // Botón cerrar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
