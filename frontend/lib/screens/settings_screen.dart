import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/logger_service.dart';
import 'print_config_tab.dart';
import 'part_numbers_tab.dart';
import 'debug_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Widget? _selectedScreen;

  @override
  Widget build(BuildContext context) {
    // Si hay una pantalla seleccionada, mostrarla
    if (_selectedScreen != null) {
      return _selectedScreen!;
    }

    // Mostrar lista de opciones de configuración
    return Container(
      color: AppTheme.contentBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppTheme.cardBackground,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.settings,
                    color: AppTheme.accentBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configuración',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    Text(
                      'Administra la configuración del sistema',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lista de opciones de configuración
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildSettingOption(
                  icon: Icons.print,
                  title: 'Opciones de Impresión',
                  description:
                      'Impresora, tamaño de papel, márgenes y prueba de impresión',
                  onTap: () {
                    setState(() {
                      _selectedScreen = _PrintConfigScreen(
                        onBack: () => setState(() => _selectedScreen = null),
                      );
                    });
                  },
                ),
                const SizedBox(height: 12),
                _buildSettingOption(
                  icon: Icons.inventory_2,
                  title: 'Catalogo de Números de Parte',
                  description:
                      'Gestiona los números de parte, descripciones y empaques estándar',
                  onTap: () {
                    setState(() {
                      _selectedScreen = _PartNumbersScreen(
                        onBack: () => setState(() => _selectedScreen = null),
                      );
                    });
                  },
                ),
                const SizedBox(height: 12),
                _buildSettingOption(
                  icon: Icons.bug_report,
                  title: 'Modo Debug / Logs',
                  description:
                      'Activa el modo debug para revisar logs y diagnosticar problemas',
                  trailing: _buildDebugIndicator(),
                  onTap: () {
                    setState(() {
                      _selectedScreen = _DebugScreenWrapper(
                        onBack: () => setState(() => _selectedScreen = null),
                      );
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugIndicator() {
    final logger = LoggerService();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: logger.debugMode
            ? AppTheme.accentGreenLight.withOpacity(0.2)
            : Colors.grey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: logger.debugMode ? AppTheme.accentGreenLight : Colors.grey.shade400,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: logger.debugMode ? AppTheme.accentGreenLight : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            logger.debugMode ? 'Activo' : 'Inactivo',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: logger.debugMode ? AppTheme.accentGreenLight : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingOption({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Material(
      color: AppTheme.cardBackground,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.accentBlue,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[  
                const SizedBox(width: 12),
                trailing,
              ],
              const Icon(
                Icons.chevron_right,
                color: AppTheme.textMuted,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Wrapper para la pantalla de configuración de impresión con botón de regreso
class _PrintConfigScreen extends StatelessWidget {
  final VoidCallback onBack;

  const _PrintConfigScreen({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.contentBackground,
      child: Column(
        children: [
          // Header con botón de regreso
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppTheme.cardBackground,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack,
                  tooltip: 'Volver',
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.print,
                    color: AppTheme.accentBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configuración de Impresión',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    Text(
                      'Configura la impresora y formato de impresión',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Expanded(child: PrintConfigTab()),
        ],
      ),
    );
  }
}

// Wrapper para la pantalla de números de parte con botón de regreso
class _PartNumbersScreen extends StatelessWidget {
  final VoidCallback onBack;

  const _PartNumbersScreen({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.contentBackground,
      child: Column(
        children: [
          // Header con botón de regreso
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppTheme.cardBackground,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack,
                  tooltip: 'Volver',
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2,
                    color: AppTheme.accentBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Números de Parte',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    Text(
                      'Gestiona los números de parte del sistema',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Expanded(child: PartNumbersTab()),
        ],
      ),
    );
  }
}

// Wrapper para la pantalla de debug con botón de regreso
class _DebugScreenWrapper extends StatelessWidget {
  final VoidCallback onBack;

  const _DebugScreenWrapper({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.contentBackground,
      child: Column(
        children: [
          // Header con botón de regreso
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppTheme.cardBackground,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack,
                  tooltip: 'Volver a Configuración',
                ),
              ],
            ),
          ),
          const Expanded(child: DebugScreen()),
        ],
      ),
    );
  }
}
