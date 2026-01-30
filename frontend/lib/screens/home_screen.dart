import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import '../config/update_config.dart';
import 'dashboard_screen.dart';
import 'exit_records_screen.dart';
import 'new_record_screen.dart';
import 'operators_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isExpanded = true;

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.add_box_outlined,
      selectedIcon: Icons.add_box,
      label: 'Nuevo Registro',
    ),
    NavigationItem(
      icon: Icons.list_alt_outlined,
      selectedIcon: Icons.list_alt,
      label: 'Registros',
    ),
    NavigationItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
    ),
    NavigationItem(
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      label: 'Operadores',
    ),
    NavigationItem(
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
      label: 'Reportes',
    ),
    NavigationItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Configuración',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().initialize();
      // Verificar actualizaciones al iniciar
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    if (!UpdateConfig.checkOnStartup) return;

    try {
      debugPrint('🔍 Verificando actualizaciones...');
      debugPrint('📌 Versión actual: ${UpdateConfig.currentVersion}');

      // Verificar actualizaciones normalmente
      final updateInfo = await UpdateService.checkForUpdate();

      if (updateInfo != null) {
        debugPrint('✅ Nueva versión encontrada: ${updateInfo.version}');
        if (mounted) {
          UpdateDialog.show(context, updateInfo);
        }
      } else {
        debugPrint('ℹ️ No hay actualizaciones disponibles');
      }
    } catch (e) {
      debugPrint('❌ Error al verificar actualizaciones: $e');
    }
  }

  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return const NewRecordScreen();
      case 1:
        return const ExitRecordsScreen();
      case 2:
        return const DashboardScreen();
      case 3:
        return const OperatorsScreen();
      case 4:
        return const ReportsScreen();
      case 5:
        return const SettingsScreen();
      default:
        return const NewRecordScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isExpanded ? 250 : 70,
            child: ClipRect(
              child: Container(
                color: AppTheme.darkTertiary,
                child: Column(
                  children: [
                    // Header
                    Container(
                      height: 80,
                      padding: EdgeInsets.symmetric(
                          horizontal: _isExpanded ? 16 : 15),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.accentBlue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                'OQC',
                                style: TextStyle(
                                  color: AppTheme.textLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          if (_isExpanded) ...[
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ilsan Electronics',
                                    style: TextStyle(
                                      color: AppTheme.textLight,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'Registro Salidas',
                                    style: TextStyle(
                                      color: AppTheme.textGray,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Divider(
                        color: AppTheme.borderColor.withOpacity(0.5),
                        height: 1),

                    // Navigation Items
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _navigationItems.length,
                        itemBuilder: (context, index) {
                          final item = _navigationItems[index];
                          final isSelected = _selectedIndex == index;

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedIndex = index;
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.accentBlue.withOpacity(0.2)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected
                                        ? Border.all(
                                            color: AppTheme.accentBlue
                                                .withOpacity(0.5))
                                        : null,
                                  ),
                                  child: _isExpanded
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isSelected
                                                    ? item.selectedIcon
                                                    : item.icon,
                                                color: isSelected
                                                    ? AppTheme.accentBlue
                                                    : AppTheme.textGray,
                                                size: 22,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  item.label,
                                                  style: TextStyle(
                                                    color: isSelected
                                                        ? AppTheme.textLight
                                                        : AppTheme.textGray,
                                                    fontWeight: isSelected
                                                        ? FontWeight.w600
                                                        : FontWeight.normal,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : Center(
                                          child: Icon(
                                            isSelected
                                                ? item.selectedIcon
                                                : item.icon,
                                            color: isSelected
                                                ? AppTheme.accentBlue
                                                : AppTheme.textGray,
                                            size: 20,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Toggle Button
                    Divider(
                        color: AppTheme.borderColor.withOpacity(0.5),
                        height: 1),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                        child: Container(
                          height: 48,
                          alignment: Alignment.center,
                          child: Icon(
                            _isExpanded
                                ? Icons.chevron_left
                                : Icons.chevron_right,
                            color: AppTheme.textGray,
                          ),
                        ),
                      ),
                    ),

                    // Version Display
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: _isExpanded ? 16 : 8,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: _isExpanded
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppTheme.textGray.withAlpha(150),
                            size: 14,
                          ),
                          if (_isExpanded) ...[
                            const SizedBox(width: 8),
                            Text(
                              'v${UpdateConfig.currentVersion}',
                              style: TextStyle(
                                color: AppTheme.textGray.withAlpha(150),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Connection Status
                    Consumer<AppProvider>(
                      builder: (context, provider, _) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: _isExpanded
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: provider.isConnected
                                      ? AppTheme.accentGreenLight
                                      : AppTheme.accentRed,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              if (_isExpanded) ...[
                                const SizedBox(width: 8),
                                Text(
                                  provider.isConnected
                                      ? 'Conectado'
                                      : 'Desconectado',
                                  style: const TextStyle(
                                    color: AppTheme.textGray,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          Expanded(
            child: Consumer<AppProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && !provider.isConnected) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Conectando con el servidor...'),
                      ],
                    ),
                  );
                }

                if (!provider.isConnected && provider.errorMessage != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_off,
                          size: 64,
                          color: AppTheme.accentRed,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No se pudo conectar al servidor',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textLight,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Asegúrate de que el servidor esté ejecutándose',
                          style: TextStyle(color: AppTheme.textGray),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => provider.initialize(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }

                return _getScreen(_selectedIndex);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
