const express = require('express');
const router = express.Router();
const OqcReleaseBoxModel = require('../models/oqcReleaseBox.model');

// Consultar cajas liberadas por OQC con filtros simples.
router.get('/', async (req, res) => {
  try {
    const rows = await OqcReleaseBoxModel.getAll({
      status: req.query.status,
      folio: req.query.folio,
      partNumber: req.query.partNumber,
      boxCode: req.query.boxCode,
      startDate: req.query.startDate,
      endDate: req.query.endDate,
      limit: req.query.limit,
    });

    res.json({ success: true, data: rows });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Consultar historial de liberación de una caja específica.
router.get('/:boxCode', async (req, res) => {
  try {
    const rows = await OqcReleaseBoxModel.getByBoxCode(req.params.boxCode);
    if (!rows || rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Caja no encontrada en liberaciones OQC',
      });
    }

    res.json({ success: true, data: rows });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
