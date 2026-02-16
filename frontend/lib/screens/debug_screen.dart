import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/logger_service.dart';
import '../theme/app_theme.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final LoggerService _logger = LoggerService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  LogLevel? _selectedLevel;
  String? _selectedSource;
  String _searchQuery = '';
  bool _autoScroll = true;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _logger.addListener(_onLogsChanged);
  }

  @override
  void dispose() {
    _logger.removeListener(_onLogsChanged);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onLogsChanged() {
    if (mounted) {
      setState(() {});
      if (_autoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  List<LogEntry> get _filteredLogs {
    List<LogEntry> logs = _logger.logs;

    if (_selectedLevel != null) {
      logs = logs.where((l) => l.level == _selectedLevel).toList();
    }

    if (_selectedSource != null) {
      logs = logs.where((l) => l.source == _selectedSource).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      logs = logs.where((l) {
        return l.message.toLowerCase().contains(q) ||
            l.source.toLowerCase().contains(q) ||
            (l.details?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return logs;
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return AppTheme.accentBlue;
      case LogLevel.warning:
        return AppTheme.accentOrange;
      case LogLevel.error:
        return AppTheme.accentRed;
    }
  }

  IconData _getLevelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Icons.bug_report;
      case LogLevel.info:
        return Icons.info_outline;
      case LogLevel.warning:
        return Icons.warning_amber;
      case LogLevel.error:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _filteredLogs;
    final sources = _logger.sources.toList()..sort();

    return Container(
      color: AppTheme.contentBackground,
      child: Column(
        children: [
          // Header
          _buildHeader(filteredLogs.length),

          // Filters
          if (_showFilters) _buildFilters(sources),

          // Log list
          Expanded(
            child: filteredLogs.isEmpty
                ? _buildEmptyState()
                : _buildLogList(filteredLogs),
          ),

          // Footer / Status bar
          _buildStatusBar(filteredLogs.length),
        ],
      ),
    );
  }

  Widget _buildHeader(int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bug_report,
                  color: AppTheme.accentOrange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Consola de Debug',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Debug mode toggle
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _logger.debugMode
                                ? AppTheme.accentGreenLight.withOpacity(0.2)
                                : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _logger.debugMode
                                  ? AppTheme.accentGreenLight
                                  : Colors.grey,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _logger.debugMode
                                      ? AppTheme.accentGreenLight
                                      : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _logger.debugMode ? 'ACTIVO' : 'INACTIVO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _logger.debugMode
                                      ? AppTheme.accentGreenLight
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Revisa los logs de la aplicación para diagnosticar problemas',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Toggle debug mode
              _buildActionButton(
                icon: _logger.debugMode
                    ? Icons.toggle_on
                    : Icons.toggle_off,
                label: _logger.debugMode ? 'Desactivar' : 'Activar',
                color: _logger.debugMode
                    ? AppTheme.accentGreenLight
                    : Colors.grey,
                onTap: () => _logger.toggleDebugMode(),
              ),
              const SizedBox(width: 8),
              // Filter toggle
              _buildActionButton(
                icon: Icons.filter_list,
                label: 'Filtros',
                color: _showFilters
                    ? AppTheme.accentBlue
                    : AppTheme.textMuted,
                onTap: () => setState(() => _showFilters = !_showFilters),
              ),
              const SizedBox(width: 8),
              // Export
              PopupMenuButton<String>(
                onSelected: _handleExportAction,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'copy',
                    child: ListTile(
                      leading: Icon(Icons.copy, size: 20),
                      title: Text('Copiar al portapapeles'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'save',
                    child: ListTile(
                      leading: Icon(Icons.save, size: 20),
                      title: Text('Guardar en archivo'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.accentBlue.withOpacity(0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download, size: 18, color: AppTheme.accentBlue),
                      SizedBox(width: 6),
                      Text(
                        'Exportar',
                        style: TextStyle(
                          color: AppTheme.accentBlue,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Clear
              _buildActionButton(
                icon: Icons.delete_sweep,
                label: 'Limpiar',
                color: AppTheme.accentRed,
                onTap: () => _confirmClearLogs(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search bar
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Buscar en los logs...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.contentBackground,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.lightBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.lightBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.accentBlue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(List<String> sources) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border(
          bottom: BorderSide(color: AppTheme.lightBorder),
        ),
      ),
      child: Row(
        children: [
          // Filtro por nivel
          const Text('Nivel: ', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Todos',
            selected: _selectedLevel == null,
            onTap: () => setState(() => _selectedLevel = null),
          ),
          ...LogLevel.values.map((level) => Padding(
                padding: const EdgeInsets.only(left: 4),
                child: _buildFilterChip(
                  label: level.label,
                  selected: _selectedLevel == level,
                  color: _getLevelColor(level),
                  onTap: () => setState(() {
                    _selectedLevel = _selectedLevel == level ? null : level;
                  }),
                ),
              )),
          const SizedBox(width: 20),
          // Filtro por fuente
          const Text('Fuente: ', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildFilterChip(
                    label: 'Todas',
                    selected: _selectedSource == null,
                    onTap: () => setState(() => _selectedSource = null),
                  ),
                  ...sources.map((source) => Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: _buildFilterChip(
                          label: source,
                          selected: _selectedSource == source,
                          onTap: () => setState(() {
                            _selectedSource =
                                _selectedSource == source ? null : source;
                          }),
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    Color? color,
    required VoidCallback onTap,
  }) {
    final chipColor = color ?? AppTheme.accentBlue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? chipColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? chipColor : AppTheme.lightBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? chipColor : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _logger.debugMode ? Icons.hourglass_empty : Icons.bug_report,
            size: 64,
            color: AppTheme.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _logger.debugMode
                ? 'No hay logs que mostrar'
                : 'El modo debug está desactivado',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _logger.debugMode
                ? 'Los logs aparecerán aquí conforme se generen'
                : 'Activa el modo debug para capturar logs detallados',
            style: TextStyle(
              color: AppTheme.textMuted.withOpacity(0.7),
            ),
          ),
          if (!_logger.debugMode) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _logger.setDebugMode(true),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Activar modo debug'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentOrange,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogList(List<LogEntry> logs) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return _buildLogEntry(log);
      },
    );
  }

  Widget _buildLogEntry(LogEntry log) {
    final color = _getLevelColor(log.level);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      child: InkWell(
        onTap: log.details != null
            ? () => _showLogDetails(log)
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: log.level == LogLevel.error
                ? color.withOpacity(0.05)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: color,
                width: 3,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timestamp
              SizedBox(
                width: 95,
                child: Text(
                  log.formattedTime,
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 12,
                    color: AppTheme.textMuted.withOpacity(0.8),
                  ),
                ),
              ),
              // Level icon
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  _getLevelIcon(log.level),
                  size: 16,
                  color: color,
                ),
              ),
              // Level label
              SizedBox(
                width: 50,
                child: Text(
                  log.level.label,
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              // Source
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  log.source,
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 11,
                    color: AppTheme.accentBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.message,
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 12,
                        color: AppTheme.textDark.withOpacity(0.9),
                      ),
                    ),
                    if (log.details != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          log.details!,
                          style: TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: 11,
                            color: AppTheme.textMuted.withOpacity(0.7),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              // Indicators
              if (log.details != null)
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppTheme.textMuted.withOpacity(0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar(int count) {
    final totalLogs = _logger.logs.length;
    final errors = _logger.errorCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border(
          top: BorderSide(color: AppTheme.lightBorder),
        ),
      ),
      child: Row(
        children: [
          // Total de logs
          Text(
            'Mostrando $count de $totalLogs logs',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          if (errors > 0) ...[
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error, size: 14, color: AppTheme.accentRed),
                  const SizedBox(width: 4),
                  Text(
                    '$errors errores',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.accentRed,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          // Auto-scroll toggle
          InkWell(
            onTap: () => setState(() => _autoScroll = !_autoScroll),
            borderRadius: BorderRadius.circular(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _autoScroll
                      ? Icons.vertical_align_bottom
                      : Icons.vertical_align_center,
                  size: 14,
                  color: _autoScroll
                      ? AppTheme.accentBlue
                      : AppTheme.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  'Auto-scroll ${_autoScroll ? 'ON' : 'OFF'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _autoScroll
                        ? AppTheme.accentBlue
                        : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogDetails(LogEntry log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getLevelIcon(log.level),
                color: _getLevelColor(log.level), size: 24),
            const SizedBox(width: 8),
            Text('Detalle del Log - ${log.level.label}'),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Fecha/Hora', log.formattedDate),
                _buildDetailRow('Nivel', log.level.label),
                _buildDetailRow('Fuente', log.source),
                _buildDetailRow('Mensaje', log.message),
                if (log.details != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Detalles:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.lightBorder),
                    ),
                    child: SelectableText(
                      log.details!,
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: log.toString()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Log copiado al portapapeles'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Copiar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
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
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(color: AppTheme.textDark),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar logs'),
        content:
            const Text('¿Estás seguro de que quieres eliminar todos los logs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              _logger.clearLogs();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.accentRed),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExportAction(String action) async {
    switch (action) {
      case 'copy':
        final text = _logger.exportAsText();
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logs copiados al portapapeles'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        break;
      case 'save':
        final path = await _logger.saveLogsToFile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(path != null
                  ? 'Logs guardados en: $path'
                  : 'Error al guardar los logs'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        break;
    }
  }
}
