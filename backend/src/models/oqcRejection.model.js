const pool = require('../config/database');

class OqcRejectionModel {
  // Generar folio de rechazo (REJ-YYYYMMDD-XXX)
  static async generateFolio() {
    // Obtener fecha/hora del servidor MySQL (ya configurado con timezone correcta)
    const [timeRows] = await pool.query("SELECT DATE_FORMAT(NOW(), '%Y%m%d') as dateStr");
    const dateStr = timeRows[0].dateStr;
    const prefix = `REJ-${dateStr}`;

    const [rows] = await pool.query(
      `SELECT rejection_folio FROM oqc_rejections 
       WHERE rejection_folio LIKE ? 
       ORDER BY rejection_folio DESC LIMIT 1`,
      [`${prefix}%`]
    );

    let sequence = 1;
    if (rows.length > 0) {
      const lastFolio = rows[0].rejection_folio;
      const lastSequence = parseInt(lastFolio.split('-')[2], 10);
      sequence = lastSequence + 1;
    }

    return `${prefix}-${sequence.toString().padStart(3, '0')}`;
  }

  static async getAll(filters = {}) {
    let query = `
      SELECT r.*, 
             pn.part_number, pn.model, pn.description as part_description,
             op.name as operator_name, op.employee_id,
             cop.name as corrected_by_name,
             er.folio as exit_folio
      FROM oqc_rejections r
      LEFT JOIN part_numbers pn ON r.part_number_id = pn.id
      LEFT JOIN operators op ON r.operator_id = op.id
      LEFT JOIN operators cop ON r.corrected_by = cop.id
      LEFT JOIN exit_records er ON r.exit_record_id = er.id
      WHERE 1=1
    `;
    const params = [];

    if (filters.status) {
      query += ' AND r.status = ?';
      params.push(filters.status);
    }

    if (filters.partNumberId) {
      query += ' AND r.part_number_id = ?';
      params.push(filters.partNumberId);
    }

    if (filters.partNumber) {
      query += ' AND pn.part_number LIKE ?';
      params.push(`%${filters.partNumber}%`);
    }

    if (filters.startDate) {
      query += ' AND DATE(r.rejection_date) >= ?';
      params.push(filters.startDate);
    }

    if (filters.endDate) {
      query += ' AND DATE(r.rejection_date) <= ?';
      params.push(filters.endDate);
    }

    query += ' ORDER BY r.rejection_date DESC';

    const [rows] = await pool.query(query, params);
    return rows;
  }

  static async getById(id) {
    const [rows] = await pool.query(
      `SELECT r.*, 
              pn.part_number, pn.model, pn.description as part_description,
              op.name as operator_name, op.employee_id,
              cop.name as corrected_by_name,
              er.folio as exit_folio
       FROM oqc_rejections r
       LEFT JOIN part_numbers pn ON r.part_number_id = pn.id
       LEFT JOIN operators op ON r.operator_id = op.id
       LEFT JOIN operators cop ON r.corrected_by = cop.id
       LEFT JOIN exit_records er ON r.exit_record_id = er.id
       WHERE r.id = ?`,
      [id]
    );
    return rows[0];
  }

  static async getByFolio(folio) {
    const [rows] = await pool.query(
      `SELECT r.*, 
              pn.part_number, pn.model, pn.description as part_description,
              op.name as operator_name, op.employee_id,
              cop.name as corrected_by_name,
              er.folio as exit_folio
       FROM oqc_rejections r
       LEFT JOIN part_numbers pn ON r.part_number_id = pn.id
       LEFT JOIN operators op ON r.operator_id = op.id
       LEFT JOIN operators cop ON r.corrected_by = cop.id
       LEFT JOIN exit_records er ON r.exit_record_id = er.id
       WHERE r.rejection_folio = ?`,
      [folio]
    );
    return rows[0];
  }

  static async create(data) {
    const folio = await this.generateFolio();
    const {
      exit_record_id,
      part_number_id,
      operator_id,
      expected_quantity,
      actual_quantity,
      rejection_reason,
      box_codes
    } = data;

    const quantity_difference = actual_quantity - expected_quantity;

    // Convertir 0 a null para evitar errores de FK
    const exitRecordIdValue = exit_record_id && exit_record_id !== 0 ? exit_record_id : null;

    // Obtener el employee_id del operador
    const [operatorRows] = await pool.query(
      'SELECT employee_id FROM operators WHERE id = ?',
      [operator_id]
    );
    const employeeId = operatorRows.length > 0 ? operatorRows[0].employee_id : null;

    const [result] = await pool.query(
      `INSERT INTO oqc_rejections 
       (rejection_folio, exit_record_id, part_number_id, operator_id, employee_id,
        expected_quantity, actual_quantity, quantity_difference, 
        rejection_reason, box_codes, rejection_date)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
      [folio, exitRecordIdValue, part_number_id, operator_id, employeeId,
        expected_quantity, actual_quantity, quantity_difference,
        rejection_reason, box_codes]
    );

    return { id: result.insertId, folio };
  }

  static async updateStatus(id, status, correctedBy = null, correctionNotes = null) {
    let query = 'UPDATE oqc_rejections SET status = ?';
    const params = [status];

    if (status === 'corrected' && correctedBy) {
      query += ', corrected_by = ?, corrected_at = NOW(), correction_notes = ?';
      params.push(correctedBy, correctionNotes);
    }

    query += ' WHERE id = ?';
    params.push(id);

    await pool.query(query, params);
    return true;
  }

  static async linkReturnFolio(id, returnFolio) {
    await pool.query(
      'UPDATE oqc_rejections SET return_folio = ?, status = ? WHERE id = ?',
      [returnFolio, 'returned', id]
    );
    return true;
  }

  static async getPendingCount() {
    const [rows] = await pool.query(
      'SELECT COUNT(*) as count FROM oqc_rejections WHERE status IN ("pending", "in_review")'
    );
    return rows[0].count;
  }

  static async getStatsByDateRange(startDate, endDate) {
    const [rows] = await pool.query(
      `SELECT 
         COUNT(*) as total_rejections,
         SUM(ABS(quantity_difference)) as total_difference,
         COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending,
         COUNT(CASE WHEN status = 'in_review' THEN 1 END) as in_review,
         COUNT(CASE WHEN status = 'corrected' THEN 1 END) as corrected,
         COUNT(CASE WHEN status = 'returned' THEN 1 END) as returned
       FROM oqc_rejections
       WHERE DATE(rejection_date) BETWEEN ? AND ?`,
      [startDate, endDate]
    );
    return rows[0];
  }
}

module.exports = OqcRejectionModel;
