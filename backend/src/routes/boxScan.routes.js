const express = require('express');
const router = express.Router();
const BoxScanModel = require('../models/boxScan.model');

// Obtener cantidad de piezas por código de caja
router.get('/quantity/:boxCode', async (req, res) => {
  try {
    const { boxCode } = req.params;
    
    if (!boxCode || boxCode.trim() === '') {
      return res.status(400).json({ 
        success: false, 
        error: 'Código de caja requerido' 
      });
    }

    const boxInfo = await BoxScanModel.getQuantityByBoxCode(boxCode.trim());
    
    if (!boxInfo) {
      return res.status(404).json({ 
        success: false, 
        error: 'Código de caja no encontrado en registros LQC',
        boxCode: boxCode
      });
    }

    // Formatear fechas como strings sin conversión de zona horaria
    const formatDateLocal = (date) => {
      if (!date) return null;
      if (typeof date === 'string') return date;
      // Si es objeto Date, formatearlo manualmente sin conversión UTC
      const d = new Date(date);
      const year = d.getFullYear();
      const month = String(d.getMonth() + 1).padStart(2, '0');
      const day = String(d.getDate()).padStart(2, '0');
      const hours = String(d.getHours()).padStart(2, '0');
      const minutes = String(d.getMinutes()).padStart(2, '0');
      const seconds = String(d.getSeconds()).padStart(2, '0');
      return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
    };

    res.json({ 
      success: true, 
      data: {
        boxCode: boxInfo.box_code,
        quantity: boxInfo.quantity,
        firstScan: formatDateLocal(boxInfo.first_scan),
        lastScan: formatDateLocal(boxInfo.last_scan),
        folderDate: boxInfo.folder_date,
        partNumber: boxInfo.part_number
      }
    });
  } catch (error) {
    console.error('Error al consultar box_scans:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Verificar si existe un código de caja
router.get('/exists/:boxCode', async (req, res) => {
  try {
    const { boxCode } = req.params;
    const exists = await BoxScanModel.exists(boxCode);
    res.json({ success: true, exists });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Obtener información de múltiples cajas
router.post('/multiple', async (req, res) => {
  try {
    const { boxCodes } = req.body;
    
    if (!boxCodes || !Array.isArray(boxCodes)) {
      return res.status(400).json({ 
        success: false, 
        error: 'Se requiere un array de códigos de caja' 
      });
    }

    const boxes = await BoxScanModel.getMultipleBoxes(boxCodes);
    res.json({ success: true, data: boxes });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
