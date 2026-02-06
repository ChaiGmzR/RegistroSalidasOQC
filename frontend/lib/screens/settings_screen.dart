import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'print_config_tab.dart';
import 'part_numbers_tab.dart';

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
              ],
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
