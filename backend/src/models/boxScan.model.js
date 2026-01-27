const pool = require('../config/database');

class BoxScanModel {
  /**
   * Extrae el número de parte de un serial
   * Formato 1: EBR30299301922601070001 -> EBR30299301 (primeros 11 chars si empieza con prefijo conocido)
   * Formato 2: I20260106-0011-1142;MAIN;EBR80757422;1; -> EBR80757422 (tercer elemento)
   */
  static extractPartNumberFromSerial(serial) {
    if (!serial) return null;
    const trimmed = serial.trim();
    
    // Formato 2: Contiene punto y coma (;)
    if (trimmed.includes(';')) {
      const parts = trimmed.split(';');
      if (parts.length >= 3) {
        const partNumber = parts[2].trim();
        if (partNumber.length === 11) {
          return partNumber;
        }
      }
      return null;
    }
    
    // Formato 1: Código largo - extraer primeros 11 caracteres
    // Prefijos conocidos: EBR, ABQ, ACQ, LGB, etc.
    if (trimmed.length >= 11) {
      return trimmed.substring(0, 11);
    }
    
    // Si ya es un número de parte corto (11 chars)
    if (trimmed.length === 11) {
      return trimmed;
    }
    
    return null;
  }

  /**
   * Obtener cantidad de piezas por código de caja
   * Cuenta las veces que aparece el box_code en la tabla box_scans
   * También obtiene un serial de muestra para extraer el part number
   */
  static async getQuantityByBoxCode(boxCode) {
    const [rows] = await pool.query(
      `SELECT 
        box_code,
        COUNT(*) as quantity,
        MIN(first_scan) as first_scan,
        MAX(last_scan) as last_scan,
        folder_date,
        (SELECT serial FROM box_scans WHERE box_code = ? LIMIT 1) as sample_serial
      FROM box_scans 
      WHERE box_code = ?
      GROUP BY box_code, folder_date`,
      [boxCode, boxCode]
    );
    
    if (rows[0]) {
      // Extraer part number del serial de muestra
      rows[0].part_number = this.extractPartNumberFromSerial(rows[0].sample_serial);
    }
    
    return rows[0] || null;
  }

  /**
   * Verificar si existe el código de caja
   */
  static async exists(boxCode) {
    const [rows] = await pool.query(
      'SELECT COUNT(*) as count FROM box_scans WHERE box_code = ?',
      [boxCode]
    );
    return rows[0].count > 0;
  }

  /**
   * Obtener información detallada de múltiples cajas
   */
  static async getMultipleBoxes(boxCodes) {
    if (!boxCodes || boxCodes.length === 0) return [];
    
    const placeholders = boxCodes.map(() => '?').join(',');
    const [rows] = await pool.query(
      `SELECT 
        box_code,
        COUNT(*) as quantity,
        MIN(first_scan) as first_scan,
        MAX(last_scan) as last_scan,
        folder_date
      FROM box_scans 
      WHERE box_code IN (${placeholders})
      GROUP BY box_code, folder_date`,
      boxCodes
    );
    return rows;
  }
}

module.exports = BoxScanModel;
