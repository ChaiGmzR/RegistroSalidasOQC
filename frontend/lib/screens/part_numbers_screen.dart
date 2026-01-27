import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/part_number.dart';
import '../theme/app_theme.dart';

class PartNumbersScreen extends StatefulWidget {
  const PartNumbersScreen({super.key});

  @override
  State<PartNumbersScreen> createState() => _PartNumbersScreenState();
}

class _PartNumbersScreenState extends State<PartNumbersScreen> {
  final _searchController = TextEditingController();
  List<PartNumber> _filteredList = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateFilteredList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateFilteredList() {
    final provider = context.read<AppProvider>();
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredList = provider.partNumbers;
      } else {
        _filteredList = provider.partNumbers.where((pn) {
          return pn.partNumber.toLowerCase().contains(query) ||
              (pn.description?.toLowerCase().contains(query) ?? false) ||
              (pn.model?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
    });
  }

  void _showPartNumberDialog([PartNumber? partNumber]) {
    showDialog(
      context: context,
      builder: (context) => _PartNumberDialog(
        partNumber: partNumber,
        onSave: (pn) async {
          final provider = context.read<AppProvider>();
          bool success;
          if (partNumber == null) {
            success = await provider.createPartNumber(pn);
          } else {
            success = await provider.updatePartNumber(pn);
          }
          if (success && mounted) {
            Navigator.pop(context);
            _updateFilteredList();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  partNumber == null
                      ? 'Número de parte creado'
                      : 'Número de parte actualizado',
                ),
                backgroundColor: AppTheme.successColor,
              ),
            );
          }
        },
      ),
    );
  }

  void _confirmDelete(PartNumber partNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
          '¿Está seguro de eliminar el número de parte "${partNumber.partNumber}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await context
                  .read<AppProvider>()
                  .deletePartNumber(partNumber.id!);
              if (success && mounted) {
                _updateFilteredList();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Número de parte eliminado'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        if (_filteredList.isEmpty && _searchController.text.isEmpty) {
          _filteredList = provider.partNumbers;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Números de Parte'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  provider.loadPartNumbers();
                  _updateFilteredList();
                },
                tooltip: 'Actualizar',
              ),
              const SizedBox(width: 16),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showPartNumberDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Nuevo'),
          ),
          body: Column(
            children: [
              // Búsqueda
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por número de parte, modelo o descripción...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _updateFilteredList();
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => _updateFilteredList(),
                ),
              ),
              const Divider(height: 1),

              // Lista
              Expanded(
                child: _filteredList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No hay números de parte registrados'
                                  : 'No se encontraron resultados',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredList.length,
                        itemBuilder: (context, index) {
                          final pn = _filteredList[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.memory,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              title: Text(
                                pn.partNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (pn.description != null)
                                    Text(pn.description!),
                                  Row(
                                    children: [
                                      _InfoChip(
                                        label: 'Modelo: ${pn.model ?? "N/A"}',
                                      ),
                                      const SizedBox(width: 8),
                                      _InfoChip(
                                        label: 'Std Pack: ${pn.standardPack}',
                                      ),
                                      const SizedBox(width: 8),
                                      _InfoChip(
                                        label: pn.customer,
                                        color: AppTheme.accentColor,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _showPartNumberDialog(pn),
                                    tooltip: 'Editar',
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: AppTheme.errorColor,
                                    ),
                                    onPressed: () => _confirmDelete(pn),
                                    tooltip: 'Eliminar',
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total: ${_filteredList.length} números de parte',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoChip({
    required this.label,
    this.color = AppTheme.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }
}

class _PartNumberDialog extends StatefulWidget {
  final PartNumber? partNumber;
  final Function(PartNumber) onSave;

  const _PartNumberDialog({
    this.partNumber,
    required this.onSave,
  });

  @override
  State<_PartNumberDialog> createState() => _PartNumberDialogState();
}

class _PartNumberDialogState extends State<_PartNumberDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _partNumberController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _modelController;
  late final TextEditingController _customerController;
  late int _standardPack;

  final List<int> _standardPackOptions = [10, 20, 40, 80, 100];

  @override
  void initState() {
    super.initState();
    _partNumberController =
        TextEditingController(text: widget.partNumber?.partNumber ?? '');
    _descriptionController =
        TextEditingController(text: widget.partNumber?.description ?? '');
    _modelController =
        TextEditingController(text: widget.partNumber?.model ?? '');
    _customerController =
        TextEditingController(text: widget.partNumber?.customer ?? 'LG');
    _standardPack = widget.partNumber?.standardPack ?? 10;
  }

  @override
  void dispose() {
    _partNumberController.dispose();
    _descriptionController.dispose();
    _modelController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.partNumber != null;

    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Editar Número de Parte' : 'Nuevo Número de Parte',
                style: AppTheme.headerStyle.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _partNumberController,
                decoration: const InputDecoration(
                  labelText: 'Número de Parte *',
                  prefixIcon: Icon(Icons.tag),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingrese el número de parte';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  prefixIcon: Icon(Icons.devices),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _standardPack,
                      decoration: const InputDecoration(
                        labelText: 'Standard Pack *',
                        prefixIcon: Icon(Icons.inventory),
                      ),
                      items: _standardPackOptions.map((pack) {
                        return DropdownMenuItem(
                          value: pack,
                          child: Text('$pack piezas'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _standardPack = value;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _customerController,
                      decoration: const InputDecoration(
                        labelText: 'Cliente',
                        prefixIcon: Icon(Icons.business),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final pn = PartNumber(
                          id: widget.partNumber?.id,
                          partNumber: _partNumberController.text.toUpperCase(),
                          description: _descriptionController.text.isEmpty
                              ? null
                              : _descriptionController.text,
                          model: _modelController.text.isEmpty
                              ? null
                              : _modelController.text,
                          standardPack: _standardPack,
                          customer: _customerController.text.isEmpty
                              ? 'LG'
                              : _customerController.text,
                          active: true,
                        );
                        widget.onSave(pn);
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: Text(isEditing ? 'Actualizar' : 'Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
