const pool = require('../config/database');
const BoxScanModel = require('./boxScan.model');

class OqcRejectionModel {
  static normalizeStatus(status) {
    const statusMap = {
      pending: 'rejected',
      in_review: 'rejected',
      corrected: 'approved',
      returned: 'released',
    };
    return statusMap[status] || status;
  }

  static parseBoxCodes(boxCodes) {
    if (!boxCodes) return [];

    const boxes = [];
    const regex = /([^,:\n]+?)\s*:\s*(\d+)\s*pzas?/gi;
    let match;

    while ((match = regex.exec(boxCodes.toString())) !== null) {
      const boxCode = match[1].trim();
      const quantity = Number.parseInt(match[2], 10);
      if (boxCode && Number.isFinite(quantity)) {
        boxes.push({ boxCode, quantity });
      }
    }

    return boxes;
  }

  static normalizeBoxes(data) {
    const sourceBoxes = Array.isArray(data.boxes) && data.boxes.length > 0
      ? data.boxes
      : this.parseBoxCodes(data.box_codes);

    return sourceBoxes
      .map((box) => ({
        boxCode: (box.boxCode || box.box_code || '').toString().trim(),
        quantity: Number.parseInt(box.quantity || 0, 10) || 0,
      }))
      .filter((box) => box.boxCode);
  }

  // Generar folio de rechazo (REJ-YYYYMMDD-XXX)
  static async generateFolio(queryable = pool) {
    const [timeRows] = await queryable.query("SELECT DATE_FORMAT(NOW(), '%Y%m%d') as dateStr");
    const dateStr = timeRows[0].dateStr;
    const prefix = `REJ-${dateStr}`;

    const [rows] = await queryable.query(
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

  static baseSelect() {
    return `
      SELECT r.*,
             pn.part_number, pn.model, pn.description as part_description,
             op.name as operator_name, op.employee_id,
             cop.name as corrected_by_name,
             er.folio as exit_folio,
             COALESCE(ic.item_count, 0) as item_count,
             COALESCE(ic.rejected_count, 0) as rejected_count,
             COALESCE(ic.approved_count, 0) as approved_count,
             COALESCE(ic.released_count, 0) as released_count
      FROM oqc_rejections r
      LEFT JOIN part_numbers pn ON r.part_number_id = pn.id
      LEFT JOIN operators op ON r.operator_id = op.id
      LEFT JOIN operators cop ON r.corrected_by = cop.id
      LEFT JOIN exit_records er ON r.exit_record_id = er.id
      LEFT JOIN (
        SELECT
          rejection_id,
          COUNT(*) as item_count,
          SUM(CASE WHEN status = 'rejected' THEN 1 ELSE 0 END) as rejected_count,
          SUM(CASE WHEN status = 'approved' THEN 1 ELSE 0 END) as approved_count,
          SUM(CASE WHEN status = 'released' THEN 1 ELSE 0 END) as released_count
        FROM oqc_rejection_items
        GROUP BY rejection_id
      ) ic ON ic.rejection_id = r.id
    `;
  }

  static async getAll(filters = {}) {
    let query = `${this.baseSelect()} WHERE 1=1`;
    const params = [];

    if (filters.status) {
      query += ' AND r.status = ?';
      params.push(this.normalizeStatus(filters.status));
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

  static async getById(id, queryable = pool) {
    const [rows] = await queryable.query(
      `${this.baseSelect()} WHERE r.id = ?`,
      [id]
    );
    return rows[0];
  }

  static async getByFolio(folio) {
    const [rows] = await pool.query(
      `${this.baseSelect()} WHERE r.rejection_folio = ?`,
      [folio]
    );
    return rows[0];
  }

  static async create(data) {
    const connection = await pool.getConnection();

    try {
      await connection.beginTransaction();

      const folio = await this.generateFolio(connection);
      const {
        exit_record_id,
        part_number_id,
        operator_id,
        expected_quantity,
        rejection_reason,
        box_codes,
      } = data;

      const boxes = this.normalizeBoxes(data);
      const boxCodeList = boxes.map((box) => box.boxCode);
      const serials = await BoxScanModel.getSerialsByBoxCodes(boxCodeList, connection);
      const actualQuantity = serials.length > 0
        ? serials.length
        : Number.parseInt(data.actual_quantity || 0, 10) || 0;
      const expectedQuantity = Number.parseInt(expected_quantity || 0, 10) || 0;
      const quantityDifference = actualQuantity - expectedQuantity;
      const exitRecordIdValue = exit_record_id && exit_record_id !== 0 ? exit_record_id : null;

      const [operatorRows] = await connection.query(
        'SELECT employee_id FROM operators WHERE id = ?',
        [operator_id]
      );
      const employeeId = operatorRows.length > 0 ? operatorRows[0].employee_id : null;

      const [result] = await connection.query(
        `INSERT INTO oqc_rejections
         (rejection_folio, exit_record_id, part_number_id, operator_id, employee_id,
          expected_quantity, actual_quantity, quantity_difference,
          rejection_reason, box_codes, rejection_date, status)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), 'rejected')`,
        [
          folio,
          exitRecordIdValue,
          part_number_id,
          operator_id,
          employeeId,
          expectedQuantity,
          actualQuantity,
          quantityDifference,
          rejection_reason,
          box_codes,
        ]
      );

      for (const item of serials) {
        await connection.query(
          `INSERT IGNORE INTO oqc_rejection_items
           (rejection_id, serial, original_box_code, part_number, status)
           VALUES (?, ?, ?, ?, 'rejected')`,
          [result.insertId, item.serial, item.box_code, item.part_number]
        );
      }

      await connection.commit();
      return { id: result.insertId, folio };
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  static async getDetails(id) {
    const rejection = await this.getById(id);
    if (!rejection) return null;

    const [items] = await pool.query(
      `SELECT i.*, op.name as approved_by_name
       FROM oqc_rejection_items i
       LEFT JOIN operators op ON i.approved_by = op.id
       WHERE i.rejection_id = ?
       ORDER BY i.original_box_code, i.serial`,
      [id]
    );

    const boxes = items.reduce((acc, item) => {
      if (!acc[item.original_box_code]) {
        acc[item.original_box_code] = [];
      }
      acc[item.original_box_code].push(item);
      return acc;
    }, {});

    return {
      rejection,
      items,
      boxes,
      counts: {
        total: items.length,
        rejected: items.filter((item) => item.status === 'rejected').length,
        approved: items.filter((item) => item.status === 'approved').length,
        released: items.filter((item) => item.status === 'released').length,
      },
    };
  }

  static async approve(id, supervisorPin, approvedSerials = []) {
    const normalizedSerials = [...new Set((approvedSerials || [])
      .map((serial) => (serial || '').toString().trim())
      .filter(Boolean))];

    if (!supervisorPin) {
      const error = new Error('Se requiere PIN de supervisor');
      error.code = 'SUPERVISOR_PIN_REQUIRED';
      throw error;
    }

    if (normalizedSerials.length === 0) {
      const error = new Error('Seleccione al menos una pieza para aprobar');
      error.code = 'NO_SERIALS_SELECTED';
      throw error;
    }

    const connection = await pool.getConnection();

    try {
      await connection.beginTransaction();

      const [supervisorRows] = await connection.query(
        'SELECT id, employee_id, name FROM operators WHERE pin = ? AND is_supervisor = TRUE AND active = TRUE',
        [supervisorPin]
      );

      if (supervisorRows.length === 0) {
        const error = new Error('PIN de supervisor incorrecto');
        error.code = 'INVALID_SUPERVISOR_PIN';
        throw error;
      }

      const supervisor = supervisorRows[0];
      const placeholders = normalizedSerials.map(() => '?').join(', ');
      const [updateResult] = await connection.query(
        `UPDATE oqc_rejection_items
         SET status = 'approved', approved_by = ?, approved_at = NOW()
         WHERE rejection_id = ?
           AND serial IN (${placeholders})
           AND status != 'released'`,
        [supervisor.id, id, ...normalizedSerials]
      );

      if (updateResult.affectedRows === 0) {
        const error = new Error('No se encontraron piezas válidas para aprobar');
        error.code = 'NO_VALID_SERIALS';
        throw error;
      }

      await this.refreshHeaderStatus(id, connection);
      const rejection = await this.getById(id, connection);

      await connection.commit();
      return { rejection, supervisor };
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  static async refreshHeaderStatus(id, queryable = pool) {
    const [rows] = await queryable.query(
      `SELECT
         COUNT(*) as total,
         SUM(CASE WHEN status = 'rejected' THEN 1 ELSE 0 END) as rejected,
         SUM(CASE WHEN status = 'approved' THEN 1 ELSE 0 END) as approved,
         SUM(CASE WHEN status = 'released' THEN 1 ELSE 0 END) as released
       FROM oqc_rejection_items
       WHERE rejection_id = ?`,
      [id]
    );

    const counts = rows[0] || {};
    const total = Number(counts.total || 0);
    const rejected = Number(counts.rejected || 0);
    const approved = Number(counts.approved || 0);
    const released = Number(counts.released || 0);

    if (total === 0) return;

    let status = 'rejected';
    if (released === total) {
      status = 'released';
    } else if (rejected === 0 && approved + released === total) {
      status = 'approved';
    } else if (approved + released > 0) {
      status = 'partial_approved';
    }

    await queryable.query(
      'UPDATE oqc_rejections SET status = ? WHERE id = ?',
      [status, id]
    );
  }

  static async validateBoxesForRelease(queryable, boxes = []) {
    const boxCodes = this.normalizeBoxes({ boxes }).map((box) => box.boxCode);
    if (boxCodes.length === 0) return { serials: [], matches: [] };

    const serials = await BoxScanModel.getSerialsByBoxCodes(boxCodes, queryable);
    if (serials.length === 0) return { serials, matches: [] };

    const serialValues = serials.map((item) => item.serial);
    const placeholders = serialValues.map(() => '?').join(', ');
    const [matches] = await queryable.query(
      `SELECT i.*, r.rejection_folio, r.status as rejection_status
       FROM oqc_rejection_items i
       JOIN oqc_rejections r ON r.id = i.rejection_id
       WHERE i.serial IN (${placeholders})
         AND i.status IN ('rejected', 'approved', 'released')
         AND r.status IN ('rejected', 'approved', 'partial_approved', 'released')`,
      serialValues
    );

    const serialToCurrentBox = new Map(
      serials.map((item) => [item.serial, item.box_code])
    );

    const blocked = [];
    for (const match of matches) {
      const currentBoxCode = serialToCurrentBox.get(match.serial) || '';
      let reason = null;

      if (match.status === 'released' || match.rejection_status === 'released') {
        reason = 'La pieza ya fue liberada previamente';
      } else if (match.status === 'rejected' || match.rejection_status === 'rejected') {
        reason = 'La pieza pertenece a un rechazo sin aprobar';
      } else if (
        match.rejection_status === 'partial_approved' &&
        currentBoxCode === match.original_box_code
      ) {
        reason = 'La aprobación parcial requiere liberar en un box ID diferente';
      }

      if (reason) {
        blocked.push({
          serial: match.serial,
          box_id_actual: currentBoxCode,
          box_id_rechazo_original: match.original_box_code,
          folio_rechazo: match.rejection_folio,
          reason,
        });
      }
    }

    if (blocked.length > 0) {
      const error = new Error(
        blocked
          .map((item) => `${item.box_id_actual}: ${item.serial} en ${item.folio_rechazo} (${item.reason})`)
          .join('; ')
      );
      error.code = 'REJECTED_SERIALS_BLOCKED';
      error.details = blocked;
      throw error;
    }

    return { serials, matches };
  }

  static async markReleasedForBoxes(queryable, boxes = [], releaseFolio) {
    const { matches } = await this.validateBoxesForRelease(queryable, boxes);
    const releasableMatches = matches.filter((match) => match.status === 'approved');
    if (releasableMatches.length === 0) return 0;

    const ids = releasableMatches.map((match) => match.id);
    const placeholders = ids.map(() => '?').join(', ');
    await queryable.query(
      `UPDATE oqc_rejection_items
       SET status = 'released', released_at = NOW(), release_folio = ?
       WHERE id IN (${placeholders})`,
      [releaseFolio, ...ids]
    );

    const rejectionIds = [...new Set(releasableMatches.map((match) => match.rejection_id))];
    for (const rejectionId of rejectionIds) {
      await this.refreshHeaderStatus(rejectionId, queryable);
    }

    return releasableMatches.length;
  }

  static async updateStatus(id, status, correctedBy = null, correctionNotes = null) {
    const normalizedStatus = this.normalizeStatus(status);
    await pool.query(
      'UPDATE oqc_rejections SET status = ?, corrected_by = ?, correction_notes = ? WHERE id = ?',
      [normalizedStatus, correctedBy, correctionNotes, id]
    );
    return true;
  }

  static async linkReturnFolio(id, returnFolio) {
    await pool.query(
      'UPDATE oqc_rejections SET return_folio = ?, status = ? WHERE id = ?',
      [returnFolio, 'released', id]
    );
    return true;
  }

  static async getPendingCount() {
    const [rows] = await pool.query(
      'SELECT COUNT(*) as count FROM oqc_rejections WHERE status IN ("rejected", "partial_approved")'
    );
    return rows[0].count;
  }

  static async getStatsByDateRange(startDate, endDate) {
    const [rows] = await pool.query(
      `SELECT
         COUNT(*) as total_rejections,
         SUM(actual_quantity) as total_quantity,
         COUNT(CASE WHEN status = 'rejected' THEN 1 END) as rejected,
         COUNT(CASE WHEN status = 'approved' THEN 1 END) as approved,
         COUNT(CASE WHEN status = 'partial_approved' THEN 1 END) as partial_approved,
         COUNT(CASE WHEN status = 'released' THEN 1 END) as released
       FROM oqc_rejections
       WHERE DATE(rejection_date) BETWEEN ? AND ?`,
      [startDate, endDate]
    );
    return rows[0];
  }
}

module.exports = OqcRejectionModel;
