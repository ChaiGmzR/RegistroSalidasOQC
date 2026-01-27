const express = require('express');
const router = express.Router();
const EsdBoxModel = require('../models/esdBox.model');

// Obtener todas las cajas ESD
router.get('/', async (req, res) => {
  try {
    const boxes = await EsdBoxModel.getAll();
    res.json({ success: true, data: boxes });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Obtener una caja por ID
router.get('/:id', async (req, res) => {
  try {
    const box = await EsdBoxModel.getById(req.params.id);
    if (!box) {
      return res.status(404).json({ success: false, error: 'Caja ESD no encontrada' });
    }
    res.json({ success: true, data: box });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Crear caja ESD
router.post('/', async (req, res) => {
  try {
    const id = await EsdBoxModel.create(req.body);
    const box = await EsdBoxModel.getById(id);
    res.status(201).json({ success: true, data: box });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(400).json({ success: false, error: 'El código de caja ya existe' });
    }
    res.status(500).json({ success: false, error: error.message });
  }
});

// Actualizar caja ESD
router.put('/:id', async (req, res) => {
  try {
    await EsdBoxModel.update(req.params.id, req.body);
    const box = await EsdBoxModel.getById(req.params.id);
    res.json({ success: true, data: box });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
