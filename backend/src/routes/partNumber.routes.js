const express = require('express');
const router = express.Router();
const PartNumberModel = require('../models/partNumber.model');

// Obtener todos los números de parte
router.get('/', async (req, res) => {
  try {
    const partNumbers = await PartNumberModel.getAll();
    res.json({ success: true, data: partNumbers });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Buscar números de parte
router.get('/search', async (req, res) => {
  try {
    const { q } = req.query;
    const partNumbers = await PartNumberModel.search(q || '');
    res.json({ success: true, data: partNumbers });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Obtener un número de parte por ID
router.get('/:id', async (req, res) => {
  try {
    const partNumber = await PartNumberModel.getById(req.params.id);
    if (!partNumber) {
      return res.status(404).json({ success: false, error: 'Número de parte no encontrado' });
    }
    res.json({ success: true, data: partNumber });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Crear número de parte
router.post('/', async (req, res) => {
  try {
    const id = await PartNumberModel.create(req.body);
    const partNumber = await PartNumberModel.getById(id);
    res.status(201).json({ success: true, data: partNumber });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(400).json({ success: false, error: 'El número de parte ya existe' });
    }
    res.status(500).json({ success: false, error: error.message });
  }
});

// Actualizar número de parte
router.put('/:id', async (req, res) => {
  try {
    await PartNumberModel.update(req.params.id, req.body);
    const partNumber = await PartNumberModel.getById(req.params.id);
    res.json({ success: true, data: partNumber });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Eliminar número de parte (soft delete)
router.delete('/:id', async (req, res) => {
  try {
    await PartNumberModel.delete(req.params.id);
    res.json({ success: true, message: 'Número de parte eliminado' });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Carga masiva de números de parte
router.post('/bulk', async (req, res) => {
  try {
    const { records } = req.body;
    if (!records || !Array.isArray(records)) {
      return res.status(400).json({ success: false, error: 'Se requiere un array de registros' });
    }
    const count = await PartNumberModel.bulkCreate(records);
    res.json({ success: true, message: `${count} registros cargados exitosamente` });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
