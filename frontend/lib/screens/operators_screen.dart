import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/operator.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class OperatorsScreen extends StatefulWidget {
  const OperatorsScreen({super.key});

  @override
  State<OperatorsScreen> createState() => _OperatorsScreenState();
}

class _OperatorsScreenState extends State<OperatorsScreen> {
  final _searchController = TextEditingController();
  List<Operator> _filteredList = [];
  bool _isAuthorized = false;
  String? _supervisorName;

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
        _filteredList = provider.operators;
      } else {
        _filteredList = provider.operators.where((op) {
          return op.name.toLowerCase().contains(query) ||
              op.employeeId.toLowerCase().contains(query) ||
              op.department.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _showSupervisorPinDialog() async {
    final pinController = TextEditingController();
    bool isValidating = false;
    String? errorMessage;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Autorización de Supervisor'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ingrese el PIN de supervisor para acceder a la gestión de operadores.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'PIN de Supervisor',
                  prefixIcon: const Icon(Icons.lock),
                  errorText: errorMessage,
                  counterText: '',
                ),
                autofocus: true,
                onSubmitted: (_) async {
                  if (pinController.text.length >= 4) {
                    setDialogState(() {
                      isValidating = true;
                      errorMessage = null;
                    });
                    try {
                      final supervisor = await ApiService.validateSupervisorPin(
                          pinController.text);
                      if (supervisor != null) {
                        Navigator.pop(context, true);
                        setState(() {
                          _supervisorName = supervisor.name;
                        });
                      } else {
                        setDialogState(() {
                          errorMessage = 'PIN incorrecto';
                          isValidating = false;
                        });
                      }
                    } catch (e) {
                      setDialogState(() {
                        errorMessage = 'Error de conexión';
                        isValidating = false;
                      });
                    }
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isValidating
                  ? null
                  : () async {
                      if (pinController.text.length >= 4) {
                        setDialogState(() {
                          isValidating = true;
                          errorMessage = null;
                        });
                        try {
                          final supervisor = await ApiService.validateSupervisorPin(
                              pinController.text);
                          if (supervisor != null) {
                            Navigator.pop(context, true);
                            setState(() {
                              _supervisorName = supervisor.name;
                            });
                          } else {
                            setDialogState(() {
                              errorMessage = 'PIN incorrecto';
                              isValidating = false;
                            });
                          }
                        } catch (e) {
                          setDialogState(() {
                            errorMessage = 'Error de conexión';
                            isValidating = false;
                          });
                        }
                      } else {
                        setDialogState(() {
                          errorMessage = 'Ingrese al menos 4 dígitos';
                        });
                      }
                    },
              child: isValidating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verificar'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      setState(() {
        _isAuthorized = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bienvenido, $_supervisorName'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    }
  }

  void _showOperatorDialog([Operator? operator]) {
    if (!_isAuthorized) {
      _showSupervisorPinDialog().then((_) {
        if (_isAuthorized) {
          _showOperatorDialog(operator);
        }
      });
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => _OperatorDialog(
        operator: operator,
        onSave: (op) async {
          final provider = context.read<AppProvider>();
          bool success;
          if (op.id != null) {
            success = await provider.updateOperator(op);
          } else {
            success = await provider.createOperator(op);
          }
          if (success && mounted) {
            Navigator.pop(dialogContext);
            _updateFilteredList();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(op.id != null
                    ? 'Operador actualizado exitosamente'
                    : 'Operador registrado exitosamente'),
                backgroundColor: AppTheme.successColor,
              ),
            );
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(provider.errorMessage ?? 'Error al guardar'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _deleteOperator(Operator operator) async {
    if (!_isAuthorized) {
      await _showSupervisorPinDialog();
      if (!_isAuthorized) return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Está seguro de eliminar al operador ${operator.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final provider = context.read<AppProvider>();
      final success = await provider.deleteOperator(operator.id!);
      if (success && mounted) {
        _updateFilteredList();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Operador eliminado'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        if (_filteredList.isEmpty && _searchController.text.isEmpty) {
          _filteredList = provider.operators;
        }

        return Scaffold(
          body: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people, color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Gestión de Operadores',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_isAuthorized)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.verified_user,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _supervisorName ?? 'Supervisor',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          TextButton.icon(
                            onPressed: _showSupervisorPinDialog,
                            icon: const Icon(Icons.lock_open, color: Colors.white),
                            label: const Text(
                              'Autorizar',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: () {
                            provider.loadOperators();
                            _updateFilteredList();
                          },
                          tooltip: 'Actualizar',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Búsqueda
                    TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, ID o departamento...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white),
                                onPressed: () {
                                  _searchController.clear();
                                  _updateFilteredList();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) => _updateFilteredList(),
                    ),
                  ],
                ),
              ),

              // Lista
              Expanded(
                child: _filteredList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No hay operadores registrados'
                                  : 'No se encontraron resultados',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _filteredList.length,
                        itemBuilder: (context, index) {
                          final op = _filteredList[index];
                          return _OperatorCard(
                            operator: op,
                            isAuthorized: _isAuthorized,
                            onEdit: () => _showOperatorDialog(op),
                            onDelete: () => _deleteOperator(op),
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
                      'Total: ${_filteredList.length} operadores',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showOperatorDialog(),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Nuevo Operador'),
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

class _OperatorCard extends StatelessWidget {
  final Operator operator;
  final bool isAuthorized;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _OperatorCard({
    required this.operator,
    required this.isAuthorized,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: operator.isSupervisor
            ? const BorderSide(color: AppTheme.primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: operator.isSupervisor
                  ? AppTheme.primaryColor
                  : AppTheme.primaryColor.withOpacity(0.1),
              child: Text(
                operator.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: operator.isSupervisor ? Colors.white : AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          operator.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (operator.isSupervisor)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Supervisor',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.badge,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        operator.employeeId,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.business,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        operator.department,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isAuthorized)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: onEdit,
                    tooltip: 'Editar',
                    color: AppTheme.primaryColor,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    onPressed: onDelete,
                    tooltip: 'Eliminar',
                    color: AppTheme.errorColor,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _OperatorDialog extends StatefulWidget {
  final Operator? operator;
  final Function(Operator) onSave;

  const _OperatorDialog({
    this.operator,
    required this.onSave,
  });

  @override
  State<_OperatorDialog> createState() => _OperatorDialogState();
}

class _OperatorDialogState extends State<_OperatorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _employeeIdController;
  late final TextEditingController _nameController;
  late final TextEditingController _departmentController;
  late final TextEditingController _pinController;
  late bool _isSupervisor;

  @override
  void initState() {
    super.initState();
    _employeeIdController =
        TextEditingController(text: widget.operator?.employeeId ?? '');
    _nameController =
        TextEditingController(text: widget.operator?.name ?? '');
    _departmentController =
        TextEditingController(text: widget.operator?.department ?? 'OQC');
    _pinController =
        TextEditingController(text: widget.operator?.pin ?? '');
    _isSupervisor = widget.operator?.isSupervisor ?? false;
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _nameController.dispose();
    _departmentController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.operator == null ? Icons.person_add : Icons.edit,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.operator == null
                        ? 'Nuevo Operador'
                        : 'Editar Operador',
                    style: AppTheme.headerStyle.copyWith(fontSize: 20),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _employeeIdController,
                decoration: const InputDecoration(
                  labelText: 'ID de Empleado *',
                  prefixIcon: Icon(Icons.badge),
                  hintText: 'Ej: OQC002',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingrese el ID del empleado';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre Completo *',
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingrese el nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _departmentController,
                decoration: const InputDecoration(
                  labelText: 'Departamento',
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pinController,
                decoration: const InputDecoration(
                  labelText: 'PIN (4-6 dígitos) *',
                  prefixIcon: Icon(Icons.lock),
                  hintText: 'PIN para identificación',
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.length < 4) {
                    return 'El PIN debe tener al menos 4 dígitos';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Es Supervisor'),
                subtitle: const Text(
                  'Los supervisores pueden gestionar operadores',
                  style: TextStyle(fontSize: 12),
                ),
                value: _isSupervisor,
                onChanged: (value) {
                  setState(() {
                    _isSupervisor = value;
                  });
                },
                activeThumbColor: AppTheme.primaryColor,
                contentPadding: EdgeInsets.zero,
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
                        final op = Operator(
                          id: widget.operator?.id,
                          employeeId:
                              _employeeIdController.text.toUpperCase(),
                          name: _nameController.text,
                          department: _departmentController.text.isEmpty
                              ? 'OQC'
                              : _departmentController.text,
                          active: true,
                          pin: _pinController.text,
                          isSupervisor: _isSupervisor,
                        );
                        widget.onSave(op);
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar'),
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
