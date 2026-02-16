const express = require('express');
const router = express.Router();
const OqcRejectionModel = require('../models/oqcRejection.model');

// Obtener todos los rechazos (con filtros opcionales)
router.get('/', async (req, res) => {
  try {
    const filters = {
      status: req.query.status,
      partNumberId: req.query.partNumberId,
      partNumber: req.query.partNumber,
      startDate: req.query.startDate,
      endDate: req.query.endDate
    };
    const rejections = await OqcRejectionModel.getAll(filters);
    res.json({ success: true, data: rejections });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Obtener conteo de rechazos pendientes
router.get('/pending-count', async (req, res) => {
  try {
    const count = await OqcRejectionModel.getPendingCount();
    res.json({ success: true, count });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Obtener estadísticas por rango de fecha
router.get('/stats', async (req, res) => {
  try {
    const { startDate, endDate } = req.query;
    if (!startDate || !endDate) {
      return res.status(400).json({
        success: false,
        error: 'Se requieren startDate y endDate'
      });
    }
    const stats = await OqcRejectionModel.getStatsByDateRange(startDate, endDate);
    res.json({ success: true, data: stats });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Obtener rechazo por ID
router.get('/:id', async (req, res) => {
  try {
    const rejection = await OqcRejectionModel.getById(req.params.id);
    if (!rejection) {
      return res.status(404).json({ success: false, error: 'Rechazo no encontrado' });
    }
    res.json({ success: true, data: rejection });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Obtener rechazo por folio
router.get('/folio/:folio', async (req, res) => {
  try {
    const rejection = await OqcRejectionModel.getByFolio(req.params.folio);
    if (!rejection) {
      return res.status(404).json({ success: false, error: 'Rechazo no encontrado' });
    }
    res.json({ success: true, data: rejection });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Crear nuevo rechazo
router.post('/', async (req, res) => {
  try {
    const {
      exit_record_id,
      part_number_id,
      operator_id,
      expected_quantity,
      actual_quantity,
      rejection_reason,
      box_codes
    } = req.body;

    if (!part_number_id || !operator_id || !rejection_reason) {
      return res.status(400).json({
        success: false,
        error: 'Faltan campos requeridos'
      });
    }

    const result = await OqcRejectionModel.create(req.body);
    const rejection = await OqcRejectionModel.getById(result.id);

    res.status(201).json({ success: true, data: rejection });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Actualizar estado del rechazo
router.patch('/:id/status', async (req, res) => {
  try {
    const { status, corrected_by, correction_notes } = req.body;

    const validStatuses = ['pending', 'in_review', 'corrected', 'returned'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        error: 'Estado inválido'
      });
    }

    await OqcRejectionModel.updateStatus(
      req.params.id,
      status,
      corrected_by,
      correction_notes
    );

    const rejection = await OqcRejectionModel.getById(req.params.id);
    res.json({ success: true, data: rejection });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Vincular folio de retorno cuando el material es liberado después de corrección
router.patch('/:id/return', async (req, res) => {
  try {
    const { return_folio } = req.body;

    if (!return_folio) {
      return res.status(400).json({
        success: false,
        error: 'Se requiere el folio de retorno'
      });
    }

    await OqcRejectionModel.linkReturnFolio(req.params.id, return_folio);
    const rejection = await OqcRejectionModel.getById(req.params.id);
    res.json({ success: true, data: rejection });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
