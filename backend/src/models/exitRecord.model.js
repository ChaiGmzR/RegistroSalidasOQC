const pool = require('../config/database');

class ExitRecordModel {
  /**
   * Validar si un boxCode ya fue registrado
   * Retorna información sobre el estado del boxCode si existe
   */
  static async validateBoxCode(boxCode) {
    // Buscar en exit_records donde el boxCode aparezca en observations
    // El formato es: "Cajas: BOX1: 10 pzas, BOX2: 10 pzas" o similar
    const [rows] = await pool.query(
      `SELECT er.id, er.folio, er.destination, er.status, er.qc_passed, 
              er.exit_date, er.observations
       FROM exit_records er
       WHERE er.observations LIKE ?
         AND er.status != 'cancelled'
       ORDER BY er.exit_date DESC
       LIMIT 1`,
      [`%${boxCode}%`]
    );

    if (rows.length === 0) {
      return { exists: false };
    }

    const record = rows[0];
    return {
      exists: true,
      folio: record.folio,
      destination: record.destination,
      status: record.status,
      qcPassed: record.qc_passed === 1,
      exitDate: record.exit_date,
      // Determinar tipo de registro
      type: record.qc_passed === 1 ? 'almacen' : 'contencion'
    };
  }

  /**
   * Validar múltiples boxCodes a la vez
   */
  static async validateMultipleBoxCodes(boxCodes) {
    const results = {};
    for (const boxCode of boxCodes) {
      results[boxCode] = await this.validateBoxCode(boxCode);
    }
    return results;
  }

  // Generar folio único
  static async generateFolio() {
    // Usar fecha del servidor MySQL con timezone correcta
    const [timeRows] = await pool.query("SELECT DATE_FORMAT(NOW(), '%y') as yr, DATE_FORMAT(NOW(), '%m') as mo, DATE_FORMAT(NOW(), '%d') as dy");
    const { yr, mo, dy } = timeRows[0];
    const prefix = `OQC${yr}${mo}${dy}`;
    
    const [rows] = await pool.query(
      `SELECT folio FROM exit_records WHERE folio LIKE ? ORDER BY folio DESC LIMIT 1`,
      [`${prefix}%`]
    );
    
    let sequence = 1;
    if (rows.length > 0) {
      const lastFolio = rows[0].folio;
      const lastSequence = parseInt(lastFolio.slice(-4));
      sequence = lastSequence + 1;
    }
    
    return `${prefix}${sequence.toString().padStart(4, '0')}`;
  }

  static async getAll(filters = {}) {
    let query = `
      SELECT er.*, 
             pn.part_number, pn.description as part_description, pn.model,
             eb.box_code, eb.capacity,
             op.employee_id, op.name as operator_name
      FROM exit_records er
      JOIN part_numbers pn ON er.part_number_id = pn.id
      JOIN esd_boxes eb ON er.esd_box_id = eb.id
      JOIN operators op ON er.operator_id = op.id
      WHERE 1=1
    `;
    const params = [];

    if (filters.status) {
      query += ' AND er.status = ?';
      params.push(filters.status);
    }

    // Filtro por qcPassed (true = liberación, false = rechazos)
    if (filters.qcPassed !== undefined && filters.qcPassed !== null && filters.qcPassed !== '') {
      const qcPassedValue = filters.qcPassed === 'true' || filters.qcPassed === true ? 1 : 0;
      query += ' AND er.qc_passed = ?';
      params.push(qcPassedValue);
    }

    if (filters.startDate) {
      query += ' AND DATE(er.exit_date) >= ?';
      params.push(filters.startDate);
    }

    if (filters.endDate) {
      query += ' AND DATE(er.exit_date) <= ?';
      params.push(filters.endDate);
    }

    if (filters.partNumber) {
      query += ' AND pn.part_number LIKE ?';
      params.push(`%${filters.partNumber}%`);
    }

    query += ' ORDER BY er.created_at DESC';

    if (filters.limit) {
      query += ' LIMIT ?';
      params.push(parseInt(filters.limit));
    }

    const [rows] = await pool.query(query, params);
    return rows;
  }

  static async getById(id) {
    const [rows] = await pool.query(
      `SELECT er.*, 
              pn.part_number, pn.description as part_description, pn.model, pn.standard_pack,
              eb.box_code, eb.capacity,
              op.employee_id, op.name as operator_name
       FROM exit_records er
       JOIN part_numbers pn ON er.part_number_id = pn.id
       JOIN esd_boxes eb ON er.esd_box_id = eb.id
       JOIN operators op ON er.operator_id = op.id
       WHERE er.id = ?`,
      [id]
    );
    return rows[0];
  }

  static async getByFolio(folio) {
    const [rows] = await pool.query(
      `SELECT er.*, 
              pn.part_number, pn.description as part_description, pn.model,
              eb.box_code, eb.capacity,
              op.employee_id, op.name as operator_name
       FROM exit_records er
       JOIN part_numbers pn ON er.part_number_id = pn.id
       JOIN esd_boxes eb ON er.esd_box_id = eb.id
       JOIN operators op ON er.operator_id = op.id
       WHERE er.folio = ?`,
      [folio]
    );
    return rows[0];
  }

  static async create(data) {
    const folio = await this.generateFolio();
    const {
      part_number_id,
      esd_box_id,
      operator_id,
      quantity,
      inspection_date,
      exit_date,
      destination,
      observations,
      qc_passed
    } = data;

    const [result] = await pool.query(
      `INSERT INTO exit_records 
       (folio, part_number_id, esd_box_id, operator_id, quantity,
        inspection_date, exit_date, destination, observations, qc_passed)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [folio, part_number_id, esd_box_id, operator_id, quantity,
       inspection_date, exit_date || new Date(), destination || 'Almacen', 
       observations, qc_passed !== false]
    );

    return { id: result.insertId, folio };
  }

  /**
   * Crear un registro con un folio ya generado (para batch)
   */
  static async createWithFolio(folio, data) {
    const {
      part_number_id,
      esd_box_id,
      operator_id,
      quantity,
      inspection_date,
      exit_date,
      destination,
      observations,
      qc_passed
    } = data;

    const [result] = await pool.query(
      `INSERT INTO exit_records 
       (folio, part_number_id, esd_box_id, operator_id, quantity,
        inspection_date, exit_date, destination, observations, qc_passed)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [folio, part_number_id, esd_box_id, operator_id, quantity,
       inspection_date, exit_date || new Date(), destination || 'Almacen', 
       observations, qc_passed !== false]
    );

    return { id: result.insertId, folio };
  }

  static async update(id, data) {
    const {
      part_number_id,
      esd_box_id,
      operator_id,
      quantity,
      inspection_date,
      destination,
      status,
      observations,
      qc_passed
    } = data;

    await pool.query(
      `UPDATE exit_records SET 
       part_number_id = ?, esd_box_id = ?, operator_id = ?, quantity = ?,
       inspection_date = ?, destination = ?, status = ?, observations = ?, qc_passed = ?
       WHERE id = ?`,
      [part_number_id, esd_box_id, operator_id, quantity,
       inspection_date, destination, status,
       observations, qc_passed, id]
    );

    return true;
  }

  static async updateStatus(id, status) {
    await pool.query(
      'UPDATE exit_records SET status = ? WHERE id = ?',
      [status, id]
    );
    return true;
  }

  static async delete(id) {
    await pool.query(
      'UPDATE exit_records SET status = "cancelled" WHERE id = ?',
      [id]
    );
    return true;
  }

  // Estadísticas
  static async getStats(startDate, endDate) {
    const [rows] = await pool.query(
      `SELECT 
         COUNT(*) as total_records,
         SUM(quantity) as total_quantity,
         COUNT(DISTINCT part_number_id) as unique_parts,
         SUM(CASE WHEN status = 'released' THEN 1 ELSE 0 END) as released,
         SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending,
         SUM(CASE WHEN status = 'shipped' THEN 1 ELSE 0 END) as shipped
       FROM exit_records
       WHERE DATE(exit_date) BETWEEN ? AND ?
         AND status != 'cancelled'`,
      [startDate, endDate]
    );
    return rows[0];
  }

  static async getStatsByPartNumber(startDate, endDate) {
    const [rows] = await pool.query(
      `SELECT 
         pn.part_number,
         pn.description,
         COUNT(*) as record_count,
         SUM(er.quantity) as total_quantity
       FROM exit_records er
       JOIN part_numbers pn ON er.part_number_id = pn.id
       WHERE DATE(er.exit_date) BETWEEN ? AND ?
         AND er.status != 'cancelled'
       GROUP BY pn.id
       ORDER BY total_quantity DESC`,
      [startDate, endDate]
    );
    return rows;
  }
}

module.exports = ExitRecordModel;
