const express = require('express');
const router = express.Router();
const OperatorModel = require('../models/operator.model');

// Obtener todos los operadores
router.get('/', async (req, res) => {
  try {
    const operators = await OperatorModel.getAll();
    res.json({ success: true, data: operators });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Validar PIN de operador
router.post('/validate-pin', async (req, res) => {
  try {
    const { employee_id, pin } = req.body;
    const operator = await OperatorModel.validatePin(employee_id, pin);
    if (!operator) {
      return res.status(401).json({ success: false, error: 'PIN o ID de empleado incorrecto' });
    }
    res.json({ success: true, data: operator });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Validar PIN de supervisor
router.post('/validate-supervisor', async (req, res) => {
  try {
    const { pin } = req.body;
    const supervisor = await OperatorModel.validateSupervisorPin(pin);
    if (!supervisor) {
      return res.status(401).json({ success: false, error: 'PIN de supervisor incorrecto' });
    }
    res.json({ success: true, data: supervisor });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Obtener operador por ID de empleado
router.get('/employee/:employeeId', async (req, res) => {
  try {
    const operator = await OperatorModel.getByEmployeeId(req.params.employeeId);
    if (!operator) {
      return res.status(404).json({ success: false, error: 'Operador no encontrado' });
    }
    res.json({ success: true, data: operator });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Obtener un operador por ID
router.get('/:id', async (req, res) => {
  try {
    const operator = await OperatorModel.getById(req.params.id);
    if (!operator) {
      return res.status(404).json({ success: false, error: 'Operador no encontrado' });
    }
    res.json({ success: true, data: operator });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Crear operador
router.post('/', async (req, res) => {
  try {
    const id = await OperatorModel.create(req.body);
    const operator = await OperatorModel.getById(id);
    res.status(201).json({ success: true, data: operator });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(400).json({ success: false, error: 'El ID de empleado ya existe' });
    }
    res.status(500).json({ success: false, error: error.message });
  }
});

// Actualizar operador
router.put('/:id', async (req, res) => {
  try {
    await OperatorModel.update(req.params.id, req.body);
    const operator = await OperatorModel.getById(req.params.id);
    res.json({ success: true, data: operator });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Actualizar PIN de operador
router.put('/:id/pin', async (req, res) => {
  try {
    const { pin } = req.body;
    await OperatorModel.updatePin(req.params.id, pin);
    res.json({ success: true, message: 'PIN actualizado' });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Eliminar operador (soft delete)
router.delete('/:id', async (req, res) => {
  try {
    await OperatorModel.delete(req.params.id);
    res.json({ success: true, message: 'Operador eliminado' });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
