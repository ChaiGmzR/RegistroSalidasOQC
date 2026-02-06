import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/part_number.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class PartNumbersTab extends StatefulWidget {
  const PartNumbersTab({super.key});

  @override
  State<PartNumbersTab> createState() => _PartNumbersTabState();
}

class _PartNumbersTabState extends State<PartNumbersTab> {
  List<PartNumber> _partNumbers = [];
  List<PartNumber> _filteredPartNumbers = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  bool _showInactiveOnly = false;

  @override
  void initState() {
    super.initState();
    _loadPartNumbers();
    _searchController.addListener(_filterPartNumbers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPartNumbers() async {
    setState(() => _isLoading = true);
    try {
      final partNumbers = await ApiService.getPartNumbers();
      setState(() {
        _partNumbers = partNumbers;
        _filterPartNumbers();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar números de parte: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _filterPartNumbers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPartNumbers = _partNumbers.where((pn) {
        final matchesSearch = query.isEmpty ||
            pn.partNumber.toLowerCase().contains(query) ||
            (pn.description?.toLowerCase().contains(query) ?? false) ||
            (pn.model?.toLowerCase().contains(query) ?? false);

        final matchesActiveFilter = _showInactiveOnly ? !pn.active : pn.active;

        return matchesSearch && matchesActiveFilter;
      }).toList();
    });
  }

  Future<void> _showPartNumberDialog({PartNumber? partNumber}) async {
    final isEditing = partNumber != null;
    final formKey = GlobalKey<FormState>();

    final partNumberController =
        TextEditingController(text: partNumber?.partNumber ?? '');
    final descriptionController =
        TextEditingController(text: partNumber?.description ?? '');
    final standardPackController = TextEditingController(
      text: partNumber?.standardPack.toString() ?? '10',
    );
    final modelController =
        TextEditingController(text: partNumber?.model ?? '');
    final customerController =
        TextEditingController(text: partNumber?.customer ?? 'LG');
    bool active = partNumber?.active ?? true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
              isEditing ? 'Editar Número de Parte' : 'Nuevo Número de Parte'),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: partNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Número de Parte *',
                        prefixIcon: Icon(Icons.tag),
                        hintText: 'Ej: EBR12345678',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El número de parte es requerido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: standardPackController,
                            decoration: const InputDecoration(
                              labelText: 'Empaque Estándar *',
                              prefixIcon: Icon(Icons.inventory_2),
                              suffixText: 'pzas',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Requerido';
                              }
                              final num = int.tryParse(value);
                              if (num == null || num <= 0) {
                                return 'Debe ser mayor a 0';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: modelController,
                            decoration: const InputDecoration(
                              labelText: 'Modelo',
                              prefixIcon: Icon(Icons.devices),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: customerController,
                      decoration: const InputDecoration(
                        labelText: 'Cliente *',
                        prefixIcon: Icon(Icons.business),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El cliente es requerido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Activo'),
                      subtitle: const Text('Disponible para nuevos registros'),
                      value: active,
                      onChanged: (value) {
                        setDialogState(() => active = value ?? true);
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                try {
                  final newPartNumber = PartNumber(
                    id: partNumber?.id,
                    partNumber: partNumberController.text.trim().toUpperCase(),
                    description: descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                    standardPack: int.parse(standardPackController.text),
                    model: modelController.text.trim().isEmpty
                        ? null
                        : modelController.text.trim(),
                    customer: customerController.text.trim(),
                    active: active,
                  );

                  if (isEditing) {
                    await ApiService.updatePartNumber(newPartNumber);
                  } else {
                    await ApiService.createPartNumber(newPartNumber);
                  }

                  if (context.mounted) {
                    Navigator.pop(context, true);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                }
              },
              child: Text(isEditing ? 'Actualizar' : 'Crear'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadPartNumbers();
      // Actualizar el provider para refrescar otras pantallas
      if (mounted) {
        context.read<AppProvider>().loadPartNumbers();
      }
    }
  }

  Future<void> _deletePartNumber(PartNumber partNumber) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
          '¿Estás seguro de que deseas eliminar el número de parte "${partNumber.partNumber}"?\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && partNumber.id != null) {
      try {
        await ApiService.deletePartNumber(partNumber.id!);
        _loadPartNumbers();
        if (mounted) {
          context.read<AppProvider>().loadPartNumbers();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Número de parte eliminado'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header con búsqueda y acciones
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
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText:
                        'Buscar por número de parte, descripción o modelo...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: AppTheme.contentBackground,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              FilterChip(
                label: Text(_showInactiveOnly ? 'Inactivos' : 'Activos'),
                selected: _showInactiveOnly,
                onSelected: (value) {
                  setState(() {
                    _showInactiveOnly = value;
                    _filterPartNumbers();
                  });
                },
                avatar: Icon(
                  _showInactiveOnly ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showPartNumberDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                ),
              ),
            ],
          ),
        ),

        // Lista de números de parte
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredPartNumbers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                                ? 'No hay números de parte registrados'
                                : 'No se encontraron resultados',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredPartNumbers.length,
                      itemBuilder: (context, index) {
                        final partNumber = _filteredPartNumbers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: partNumber.active
                                    ? AppTheme.successColor.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.inventory_2,
                                color: partNumber.active
                                    ? AppTheme.successColor
                                    : Colors.grey,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  partNumber.partNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (!partNumber.active)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'INACTIVO',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (partNumber.description != null)
                                  Text(partNumber.description!),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.business,
                                        size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(partNumber.customer),
                                    const SizedBox(width: 16),
                                    Icon(Icons.inventory_2,
                                        size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text('${partNumber.standardPack} pzas'),
                                    if (partNumber.model != null) ...[
                                      const SizedBox(width: 16),
                                      Icon(Icons.devices,
                                          size: 14,
                                          color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(partNumber.model!),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showPartNumberDialog(
                                      partNumber: partNumber),
                                  tooltip: 'Editar',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  color: AppTheme.errorColor,
                                  onPressed: () =>
                                      _deletePartNumber(partNumber),
                                  tooltip: 'Eliminar',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
