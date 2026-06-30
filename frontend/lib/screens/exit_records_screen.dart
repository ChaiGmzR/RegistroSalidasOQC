import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../providers/app_provider.dart';
import '../models/exit_record.dart';
import '../models/oqc_rejection.dart';
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
  bool _isLoadingLiberacion = true;
  bool _isLoadingRechazos = false;

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

  Future<void> _loadLiberacionRecords() async {
    final provider = context.read<AppProvider>();
    if (mounted) {
      setState(() => _isLoadingLiberacion = true);
    }

    try {
      await provider.loadExitRecords(
        startDate: _liberacionStartDate?.toIso8601String().split('T')[0],
        endDate: _liberacionEndDate?.toIso8601String().split('T')[0],
        partNumber: _liberacionSearchController.text.isEmpty
            ? null
            : _liberacionSearchController.text,
        qcPassed: true, // Solo registros aprobados
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingLiberacion = false);
      }
    }
  }

  Future<void> _loadRechazosRecords() async {
    final provider = context.read<AppProvider>();
    if (mounted) {
      setState(() => _isLoadingRechazos = true);
    }

    try {
      await provider.loadOqcRejections(
        status: _rechazosStatusFilter == 'all' ? null : _rechazosStatusFilter,
        partNumber: _rechazosSearchController.text.isEmpty
            ? null
            : _rechazosSearchController.text,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingRechazos = false);
      }
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
    final liberacionRecords = _isLoadingLiberacion
        ? <ExitRecord>[]
        : provider.exitRecords.where((r) => r.qcPassed).toList();

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
          child: _isLoadingLiberacion
              ? const Center(child: CircularProgressIndicator())
              : liberacionRecords.isEmpty
                  ? _buildEmptyState('No hay registros de liberación')
                  : _buildDataTable(liberacionRecords, showStatusColumn: false),
        ),
      ],
    );
  }

  Widget _buildRechazosTab(AppProvider provider) {
    final rechazosRecords =
        _isLoadingRechazos ? <OqcRejection>[] : provider.oqcRejections;

    // Filtrar localmente por búsqueda si hay texto
    final filteredRecords = _rechazosSearchController.text.isEmpty
        ? rechazosRecords
        : rechazosRecords.where((r) {
            final search = _rechazosSearchController.text.toLowerCase();
            return (r.partNumber?.toLowerCase().contains(search) ?? false) ||
                (r.rejectionFolio?.toLowerCase().contains(search) ?? false) ||
                (r.exitFolio?.toLowerCase().contains(search) ?? false);
          }).toList();

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
                  initialValue: _rechazosStatusFilter,
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
                      value: 'rejected',
                      child: Text('Rechazado'),
                    ),
                    DropdownMenuItem(
                      value: 'approved',
                      child: Text('Aprobado'),
                    ),
                    DropdownMenuItem(
                      value: 'partial_approved',
                      child: Text('Aprobado Parcial'),
                    ),
                    DropdownMenuItem(
                      value: 'released',
                      child: Text('Liberado'),
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

              // Exportar a Excel
              OutlinedButton.icon(
                onPressed: filteredRecords.isNotEmpty
                    ? () => _exportRechazosToExcel(filteredRecords)
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
          child: _isLoadingRechazos
              ? const Center(child: CircularProgressIndicator())
              : filteredRecords.isEmpty
                  ? _buildEmptyState('No hay registros de rechazos')
                  : _buildRechazosDataTable(filteredRecords),
        ),
      ],
    );
  }

  Future<void> _exportRechazosToExcel(List<OqcRejection> records) async {
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay rechazos para exportar')),
      );
      return;
    }

    try {
      final StringBuffer csv = StringBuffer();
      csv.writeln(
          'Folio Rechazo,No. Parte,Modelo,Cantidad,Operador,Fecha,Estado,Razón,Cajas');

      for (final record in records) {
        final fecha = record.rejectionDate != null
            ? DateFormat('dd/MM/yyyy HH:mm').format(record.rejectionDate!)
            : '';
        final razon =
            record.rejectionReason.replaceAll(',', ';').replaceAll('\n', ' ');
        final cajas = (record.boxCodes ?? '').replaceAll(',', ';');

        csv.writeln('${record.rejectionFolio ?? ""},'
            '${record.partNumber ?? ""},'
            '${record.model ?? ""},'
            '${record.displayQuantity},'
            '${record.operatorName ?? ""},'
            '$fecha,'
            '${record.statusLabel},'
            '$razon,'
            '$cajas');
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Rechazos_$timestamp.csv';
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

  void _showRejectionDetails(OqcRejection rejection) {
    showDialog(
      context: context,
      builder: (context) => _RejectionDetailsDialog(rejection: rejection),
    );
  }

  void _showRejectionApproval(OqcRejection rejection) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RejectionApprovalDialog(
        rejection: rejection,
        onApproved: _loadRechazosRecords,
      ),
    );
  }

  Widget _buildRechazosDataTable(List<OqcRejection> records) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: DataTable2(
          dataRowHeight: 56,
          headingRowHeight: 56,
          columnSpacing: 12,
          horizontalMargin: 12,
          minWidth: 980,
          border: TableBorder(
            verticalInside: BorderSide(color: Colors.grey.shade200, width: 0.5),
            horizontalInside:
                BorderSide(color: Colors.grey.shade200, width: 0.5),
            bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
          headingRowColor: WidgetStateProperty.all(
            const Color(0xFFC62828),
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
              label: Text('Cantidad'),
              size: ColumnSize.S,
              numeric: true,
            ),
            DataColumn2(
              label: Text('Operador'),
              size: ColumnSize.M,
            ),
            DataColumn2(
              label: Text('Fecha'),
              size: ColumnSize.M,
            ),
            DataColumn2(
              label: Text('Estado'),
              size: ColumnSize.S,
            ),
            DataColumn2(
              label: Text('Acciones'),
              size: ColumnSize.S,
            ),
          ],
          rows: records.map((record) {
            return DataRow2(
              onTap: () => _showRejectionDetails(record),
              cells: [
                DataCell(
                  Text(
                    record.rejectionFolio ?? '-',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.partNumber ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (record.model != null)
                        Text(
                          record.model!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                DataCell(
                  Text(NumberFormat('#,###').format(record.displayQuantity)),
                ),
                DataCell(Text(record.operatorName ?? '-')),
                DataCell(
                  Text(
                    record.rejectionDate != null
                        ? DateFormat('dd/MM/yy HH:mm')
                            .format(record.rejectionDate!)
                        : '-',
                  ),
                ),
                DataCell(
                  _RejectionStatusBadge(status: record.status),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility, size: 20),
                        onPressed: () => _showRejectionDetails(record),
                        tooltip: 'Ver detalles',
                      ),
                      if (record.canApprove)
                        IconButton(
                          icon: const Icon(Icons.verified_user, size: 20),
                          onPressed: () => _showRejectionApproval(record),
                          tooltip: 'Aprobar rechazo',
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
        clipBehavior: Clip.antiAlias,
        child: DataTable2(
          dataRowHeight: 56,
          headingRowHeight: 56,
          columnSpacing: 12,
          horizontalMargin: 12,
          minWidth: showStatusColumn ? 1000 : 900,
          border: TableBorder(
            verticalInside: BorderSide(color: Colors.grey.shade200, width: 0.5),
            horizontalInside:
                BorderSide(color: Colors.grey.shade200, width: 0.5),
            bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
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
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.partNumber ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (record.model != null)
                        Text(
                          record.model!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
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
        text = 'En Contención';
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
        break;
      case 'cancelled':
        color = AppTheme.errorColor;
        text = 'Cancelado';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
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
      ),
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
                              verticalInside: BorderSide(
                                  color: Colors.grey[200]!, width: 0.5),
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

class _RejectionStatusBadge extends StatelessWidget {
  final String status;

  const _RejectionStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    IconData? icon;

    switch (status) {
      case 'rejected':
      case 'pending':
        color = AppTheme.warningColor;
        text = 'Rechazado';
        icon = Icons.hourglass_empty;
        break;
      case 'approved':
      case 'corrected':
        color = AppTheme.successColor;
        text = 'Aprobado';
        icon = Icons.check_circle_outline;
        break;
      case 'partial_approved':
        color = Colors.blue;
        text = 'Aprobado Parcial';
        icon = Icons.rule;
        break;
      case 'released':
      case 'returned':
        color = AppTheme.accentColor;
        text = 'Liberado';
        icon = Icons.undo;
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
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
      ),
    );
  }
}

class _RejectionApprovalDialog extends StatefulWidget {
  final OqcRejection rejection;
  final VoidCallback onApproved;

  const _RejectionApprovalDialog({
    required this.rejection,
    required this.onApproved,
  });

  @override
  State<_RejectionApprovalDialog> createState() =>
      _RejectionApprovalDialogState();
}

class _RejectionApprovalDialogState extends State<_RejectionApprovalDialog> {
  final _pinController = TextEditingController();
  OqcRejectionDetails? _details;
  final Set<String> _selectedSerials = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    try {
      final details = await ApiService.getOqcRejectionDetails(
        widget.rejection.id!,
      );
      setState(() {
        _details = details;
        _selectedSerials
          ..clear()
          ..addAll(details.items
              .where((item) => item.status == 'approved')
              .map((item) => item.serial));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _approve() async {
    if (_details == null || _pinController.text.trim().isEmpty) {
      setState(() => _error = 'Ingrese el PIN del supervisor');
      return;
    }

    if (_selectedSerials.isEmpty) {
      setState(() => _error = 'Seleccione al menos una pieza');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ApiService.approveOqcRejection(
        id: widget.rejection.id!,
        supervisorPin: _pinController.text.trim(),
        approvedSerials: _selectedSerials.toList(),
      );

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      widget.onApproved();
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Rechazo aprobado correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;

    return Dialog(
      child: SizedBox(
        width: 820,
        height: 700,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Aprobar ${widget.rejection.rejectionFolio}',
                      style: AppTheme.headerStyle.copyWith(fontSize: 20),
                    ),
                  ),
                  _RejectionStatusBadge(status: widget.rejection.status),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null && details == null)
              Expanded(child: Center(child: Text(_error!)))
            else if (details == null || details.items.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('Este rechazo no tiene piezas serializadas.'),
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _DetailRow(
                              'No. Parte', details.rejection.partNumber ?? '-'),
                          _DetailRow('Operador',
                              details.rejection.operatorName ?? '-'),
                          _DetailRow(
                              'Razón', details.rejection.rejectionReason),
                          _DetailRow(
                            'Piezas',
                            '${details.items.length} rechazadas | '
                                '${details.approvedCount} aprobadas | '
                                '${details.releasedCount} liberadas | '
                                '${_selectedSerials.length} seleccionadas',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: details.groupedByBox.entries.map((entry) {
                          final approvableItems = entry.value
                              .where((item) => item.status == 'rejected')
                              .toList();
                          final selectedCount = approvableItems
                              .where((item) =>
                                  _selectedSerials.contains(item.serial))
                              .length;
                          final bool? boxValue = approvableItems.isEmpty
                              ? false
                              : selectedCount == approvableItems.length
                                  ? true
                                  : selectedCount == 0
                                      ? false
                                      : null;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ExpansionTile(
                              initiallyExpanded: true,
                              title: Row(
                                children: [
                                  Checkbox(
                                    tristate: true,
                                    value: boxValue,
                                    onChanged: approvableItems.isEmpty
                                        ? null
                                        : (value) {
                                            setState(() {
                                              if (value == true ||
                                                  boxValue == null) {
                                                _selectedSerials.addAll(
                                                  approvableItems.map(
                                                      (item) => item.serial),
                                                );
                                              } else {
                                                for (final item
                                                    in approvableItems) {
                                                  _selectedSerials
                                                      .remove(item.serial);
                                                }
                                              }
                                            });
                                          },
                                  ),
                                  Expanded(child: Text('Box ID: ${entry.key}')),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(left: 48),
                                child: Text(
                                  '${entry.value.length} pieza(s) | $selectedCount seleccionada(s)',
                                ),
                              ),
                              children: entry.value.map((item) {
                                final isReleased = item.status == 'released';
                                final isApproved = item.status == 'approved';
                                return CheckboxListTile(
                                  dense: true,
                                  value: _selectedSerials.contains(item.serial),
                                  onChanged: isReleased || isApproved
                                      ? null
                                      : (value) {
                                          setState(() {
                                            if (value == true) {
                                              _selectedSerials.add(item.serial);
                                            } else {
                                              _selectedSerials
                                                  .remove(item.serial);
                                            }
                                          });
                                        },
                                  title: Text(item.serial),
                                  subtitle: Text(item.statusLabel),
                                  secondary: Text(item.partNumber ?? ''),
                                );
                              }).toList(),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          TextField(
                            controller: _pinController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'PIN de supervisor',
                              prefixIcon: Icon(Icons.lock),
                            ),
                            onSubmitted: (_) => _approve(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: AppTheme.errorColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting || _isLoading ? null : _approve,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_user),
                    label: const Text('Aprobar selección'),
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

class _RejectionDetailsDialog extends StatelessWidget {
  final OqcRejection rejection;

  const _RejectionDetailsDialog({required this.rejection});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 550,
        constraints: const BoxConstraints(maxHeight: 650),
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
                    'Rechazo: ${rejection.rejectionFolio}',
                    style: AppTheme.headerStyle.copyWith(fontSize: 20),
                  ),
                  _RejectionStatusBadge(status: rejection.status),
                ],
              ),
            ),

            // Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: Colors.red.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.red[700], size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Registro de Rechazo OQC',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[800],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow('Número de Parte', rejection.partNumber ?? '-'),
                    _DetailRow('Descripción', rejection.partDescription ?? '-'),
                    _DetailRow('Modelo', rejection.model ?? '-'),
                    _DetailRow(
                      'Cantidad rechazada',
                      '${rejection.displayQuantity} piezas',
                    ),
                    _DetailRow('Piezas aprobadas',
                        '${rejection.approvedCount} piezas'),
                    _DetailRow('Piezas liberadas',
                        '${rejection.releasedCount} piezas'),
                    _DetailRow('Operador', rejection.operatorName ?? '-'),
                    _DetailRow('No. Empleado', rejection.employeeId ?? '-'),
                    _DetailRow(
                      'Fecha de Rechazo',
                      rejection.rejectionDate != null
                          ? DateFormat('dd/MM/yyyy HH:mm')
                              .format(rejection.rejectionDate!)
                          : '-',
                    ),
                    _DetailRow('Razón del Rechazo', rejection.rejectionReason),
                    if (rejection.exitFolio != null)
                      _DetailRow('Folio de Salida', rejection.exitFolio!),
                    if (rejection.returnFolio != null)
                      _DetailRow('Folio de Retorno', rejection.returnFolio!),
                    if (rejection.correctedByName != null)
                      _DetailRow('Corregido por', rejection.correctedByName!),
                    if (rejection.correctedAt != null)
                      _DetailRow(
                        'Fecha de Corrección',
                        DateFormat('dd/MM/yyyy HH:mm')
                            .format(rejection.correctedAt!),
                      ),
                    if (rejection.correctionNotes != null)
                      _DetailRow(
                          'Notas de Corrección', rejection.correctionNotes!),

                    const SizedBox(height: 16),

                    // Box codes
                    if (rejection.boxCodes != null &&
                        rejection.boxCodes!.isNotEmpty) ...[
                      const Text(
                        'Cajas Registradas',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          rejection.boxCodes!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // Close button
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
