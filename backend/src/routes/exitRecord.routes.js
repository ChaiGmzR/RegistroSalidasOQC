const express = require('express');
const router = express.Router();
const ExitRecordModel = require('../models/exitRecord.model');

// Validar si un boxCode ya fue registrado
router.get('/validate-box/:boxCode', async (req, res) => {
  try {
    const { boxCode } = req.params;
    const result = await ExitRecordModel.validateBoxCode(boxCode);
    res.json({ success: true, data: result });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Validar múltiples boxCodes
router.post('/validate-boxes', async (req, res) => {
  try {
    const { boxCodes } = req.body;
    if (!boxCodes || !Array.isArray(boxCodes)) {
      return res.status(400).json({ success: false, error: 'boxCodes debe ser un array' });
    }
    const results = await ExitRecordModel.validateMultipleBoxCodes(boxCodes);
    res.json({ success: true, data: results });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Obtener todos los registros con filtros
router.get('/', async (req, res) => {
  try {
    const filters = {
      status: req.query.status,
      startDate: req.query.startDate,
      endDate: req.query.endDate,
      partNumber: req.query.partNumber,
      qcPassed: req.query.qcPassed,
      limit: req.query.limit
    };
    const records = await ExitRecordModel.getAll(filters);
    res.json({ success: true, data: records });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Obtener estadísticas
router.get('/stats', async (req, res) => {
  try {
    const { startDate, endDate } = req.query;
    const today = new Date().toISOString().split('T')[0];
    const stats = await ExitRecordModel.getStats(
      startDate || today,
      endDate || today
    );
    res.json({ success: true, data: stats });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Obtener estadísticas por número de parte
router.get('/stats/by-part', async (req, res) => {
  try {
    const { startDate, endDate } = req.query;
    const today = new Date().toISOString().split('T')[0];
    const stats = await ExitRecordModel.getStatsByPartNumber(
      startDate || today,
      endDate || today
    );
    res.json({ success: true, data: stats });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Obtener registro por folio
router.get('/folio/:folio', async (req, res) => {
  try {
    const record = await ExitRecordModel.getByFolio(req.params.folio);
    if (!record) {
      return res.status(404).json({ success: false, error: 'Registro no encontrado' });
    }
    res.json({ success: true, data: record });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Obtener un registro por ID
router.get('/:id', async (req, res) => {
  try {
    const record = await ExitRecordModel.getById(req.params.id);
    if (!record) {
      return res.status(404).json({ success: false, error: 'Registro no encontrado' });
    }
    res.json({ success: true, data: record });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Crear registro de salida
router.post('/', async (req, res) => {
  try {
    const { id, folio } = await ExitRecordModel.create(req.body);
    const record = await ExitRecordModel.getById(id);
    res.status(201).json({ success: true, data: record, folio });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Crear múltiples registros de salida (uno por caja) con un folio compartido
router.post('/batch', async (req, res) => {
  try {
    const { part_number_id, esd_box_id, operator_id, inspection_date, exit_date, destination, observations, qc_passed, boxes } = req.body;

    if (!boxes || !Array.isArray(boxes) || boxes.length === 0) {
      return res.status(400).json({ success: false, error: 'Se requiere al menos una caja' });
    }

    const folio = await ExitRecordModel.generateFolio();
    const boxDetails = boxes.map(b => `${b.boxCode}: ${b.quantity} pzas`).join(', ');
    const totalQuantity = boxes.reduce((sum, b) => sum + (b.quantity || 0), 0);
    const fullObservations = `Cajas: ${boxDetails}${observations ? '\n' + observations : ''}`;

    const { id } = await ExitRecordModel.createWithFolio(folio, {
      part_number_id,
      esd_box_id,
      operator_id,
      quantity: totalQuantity,
      inspection_date,
      exit_date,
      destination,
      observations: fullObservations,
      qc_passed,
    });

    res.status(201).json({
      success: true,
      folio,
      recordsCreated: boxes.length,
      recordId: id,
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Actualizar registro
router.put('/:id', async (req, res) => {
  try {
    await ExitRecordModel.update(req.params.id, req.body);
    const record = await ExitRecordModel.getById(req.params.id);
    res.json({ success: true, data: record });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Actualizar solo el estado
router.patch('/:id/status', async (req, res) => {
  try {
    const { status } = req.body;
    await ExitRecordModel.updateStatus(req.params.id, status);
    const record = await ExitRecordModel.getById(req.params.id);
    res.json({ success: true, data: record });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Eliminar registro (cancelar)
router.delete('/:id', async (req, res) => {
  try {
    await ExitRecordModel.delete(req.params.id);
    res.json({ success: true, message: 'Registro cancelado' });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
