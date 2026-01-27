import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final provider = context.read<AppProvider>();
    provider.loadStats(
      startDate: _startDate.toIso8601String().split('T')[0],
      endDate: _endDate.toIso8601String().split('T')[0],
    );
    provider.loadExitRecords(
      startDate: _startDate.toIso8601String().split('T')[0],
      endDate: _endDate.toIso8601String().split('T')[0],
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final stats = provider.stats;
        final records = provider.exitRecords;

        // Agrupar registros por estado
        final statusCounts = <String, int>{
          'pending': 0,
          'released': 0,
          'shipped': 0,
          'cancelled': 0,
        };
        for (final record in records) {
          statusCounts[record.status] = (statusCounts[record.status] ?? 0) + 1;
        }

        // Agrupar por número de parte
        final partCounts = <String, int>{};
        for (final record in records) {
          final pn = record.partNumber ?? 'Sin asignar';
          partCounts[pn] = (partCounts[pn] ?? 0) + record.quantity;
        }
        final sortedParts = partCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topParts = sortedParts.take(5).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Reportes y Estadísticas'),
            actions: [
              OutlinedButton.icon(
                onPressed: _selectDateRange,
                icon: const Icon(Icons.date_range, color: Colors.white70),
                label: Text(
                  '${DateFormat('dd/MM/yy').format(_startDate)} - ${DateFormat('dd/MM/yy').format(_endDate)}',
                  style: const TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white38),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
                tooltip: 'Actualizar',
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título del período
                Row(
                  children: [
                    const Icon(Icons.analytics, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Período: ${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                      style: AppTheme.subHeaderStyle,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Tarjetas de resumen
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Total Registros',
                        value: stats.totalRecords.toString(),
                        icon: Icons.receipt_long,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Total PCBs',
                        value: NumberFormat('#,###').format(stats.totalQuantity),
                        icon: Icons.memory,
                        color: AppTheme.accentColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Partes Únicas',
                        value: stats.uniqueParts.toString(),
                        icon: Icons.inventory_2,
                        color: AppTheme.warningColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Tasa Liberación',
                        value: stats.totalRecords > 0
                            ? '${((stats.released / stats.totalRecords) * 100).toStringAsFixed(1)}%'
                            : '0%',
                        icon: Icons.check_circle,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Gráficos
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gráfico de estados
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Distribución por Estado',
                                style: AppTheme.subHeaderStyle,
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 250,
                                child: stats.totalRecords > 0
                                    ? PieChart(
                                        PieChartData(
                                          sections: [
                                            PieChartSectionData(
                                              value: stats.pending.toDouble(),
                                              title: 'Pendiente\n${stats.pending}',
                                              color: AppTheme.warningColor,
                                              radius: 80,
                                              titleStyle: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            PieChartSectionData(
                                              value: stats.released.toDouble(),
                                              title: 'Liberado\n${stats.released}',
                                              color: AppTheme.successColor,
                                              radius: 80,
                                              titleStyle: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            PieChartSectionData(
                                              value: stats.shipped.toDouble(),
                                              title: 'Enviado\n${stats.shipped}',
                                              color: AppTheme.accentColor,
                                              radius: 80,
                                              titleStyle: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                          sectionsSpace: 2,
                                          centerSpaceRadius: 40,
                                        ),
                                      )
                                    : const Center(
                                        child: Text('Sin datos'),
                                      ),
                              ),
                              const SizedBox(height: 16),
                              // Leyenda
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _LegendItem(
                                    color: AppTheme.warningColor,
                                    label: 'Pendiente',
                                  ),
                                  SizedBox(width: 16),
                                  _LegendItem(
                                    color: AppTheme.successColor,
                                    label: 'Liberado',
                                  ),
                                  SizedBox(width: 16),
                                  _LegendItem(
                                    color: AppTheme.accentColor,
                                    label: 'Enviado',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Top números de parte
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Top 5 Números de Parte',
                                style: AppTheme.subHeaderStyle,
                              ),
                              const SizedBox(height: 24),
                              if (topParts.isEmpty)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32),
                                    child: Text('Sin datos'),
                                  ),
                                )
                              else
                                ...topParts.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final part = entry.value;
                                  final maxValue = topParts.first.value;
                                  final percentage = part.value / maxValue;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    color: _getPartColor(index),
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      '${index + 1}',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  part.key,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              '${NumberFormat('#,###').format(part.value)} pzas',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        LinearProgressIndicator(
                                          value: percentage,
                                          backgroundColor: Colors.grey[200],
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            _getPartColor(index),
                                          ),
                                          minHeight: 8,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Tabla de resumen detallado
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Resumen Detallado',
                              style: AppTheme.subHeaderStyle,
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                // Implementar exportación
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Función de exportación próximamente disponible',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.download),
                              label: const Text('Exportar'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Table(
                          border: TableBorder.all(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            1: FlexColumnWidth(1),
                            2: FlexColumnWidth(1),
                            3: FlexColumnWidth(1),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                              ),
                              children: const [
                                _TableHeader('Métrica'),
                                _TableHeader('Cantidad'),
                                _TableHeader('Porcentaje'),
                                _TableHeader('Piezas'),
                              ],
                            ),
                            _buildTableRow(
                              'Registros Pendientes',
                              stats.pending,
                              stats.totalRecords,
                              records
                                  .where((r) => r.status == 'pending')
                                  .fold(0, (sum, r) => sum + r.quantity),
                            ),
                            _buildTableRow(
                              'Registros Liberados',
                              stats.released,
                              stats.totalRecords,
                              records
                                  .where((r) => r.status == 'released')
                                  .fold(0, (sum, r) => sum + r.quantity),
                            ),
                            _buildTableRow(
                              'Registros Enviados',
                              stats.shipped,
                              stats.totalRecords,
                              records
                                  .where((r) => r.status == 'shipped')
                                  .fold(0, (sum, r) => sum + r.quantity),
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
        );
      },
    );
  }

  Color _getPartColor(int index) {
    final colors = [
      AppTheme.primaryColor,
      AppTheme.accentColor,
      AppTheme.successColor,
      AppTheme.warningColor,
      Colors.purple,
    ];
    return colors[index % colors.length];
  }

  TableRow _buildTableRow(
      String label, int count, int total, int pieces) {
    final percentage =
        total > 0 ? ((count / total) * 100).toStringAsFixed(1) : '0.0';
    return TableRow(
      children: [
        _TableCell(label),
        _TableCell(count.toString()),
        _TableCell('$percentage%'),
        _TableCell(NumberFormat('#,###').format(pieces)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(title, style: AppTheme.captionStyle),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;

  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;

  const _TableCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(text, textAlign: TextAlign.center),
    );
  }
}
