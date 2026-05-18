const pool = require('../config/database');

const ACTIVE_RELEASE_STATUSES = ['released', 'received_shipping', 'exception'];

class OqcReleaseBoxModel {
  static normalizeBoxCode(boxCode) {
    return (boxCode || '').toString().trim().toUpperCase();
  }

  static normalizeQuantity(quantity) {
    const parsed = Number.parseInt(quantity, 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
  }

  static mapStatus(exitRecord = {}) {
    if (exitRecord.status === 'cancelled') return 'cancelled';
    if (exitRecord.qc_passed === false || exitRecord.qc_passed === 0) {
      return 'rejected';
    }
    return 'released';
  }

  static parseBoxesFromObservations(observations) {
    if (!observations) return [];

    const normalized = observations.toString().replace(/\r/g, '\n');
    const boxesStart = normalized.search(/cajas\s*:/i);
    if (boxesStart === -1) return [];

    const boxesLine = normalized
      .slice(boxesStart)
      .split('\n')[0]
      .replace(/^.*?cajas\s*:\s*/i, '');

    const boxes = [];
    const regex = /([^,:\n]+?)\s*:\s*(\d+)\s*pzas?/gi;
    let match;

    while ((match = regex.exec(boxesLine)) !== null) {
      const boxCode = this.normalizeBoxCode(match[1]);
      const quantity = this.normalizeQuantity(match[2]);

      if (boxCode && quantity > 0) {
        boxes.push({ boxCode, quantity });
      }
    }

    return boxes;
  }

  static async findActiveByBoxCode(boxCode) {
    const normalizedBoxCode = this.normalizeBoxCode(boxCode);
    if (!normalizedBoxCode) return null;

    const placeholders = ACTIVE_RELEASE_STATUSES.map(() => '?').join(', ');
    const [rows] = await pool.query(
      `SELECT rb.*, er.folio, er.destination, er.status as exit_status,
              er.qc_passed, er.exit_date, er.observations
       FROM oqc_release_boxes rb
       JOIN exit_records er ON rb.exit_record_id = er.id
       WHERE rb.box_code = ?
         AND rb.status IN (${placeholders})
       ORDER BY rb.released_at DESC, rb.id DESC
       LIMIT 1`,
      [normalizedBoxCode, ...ACTIVE_RELEASE_STATUSES]
    );

    return rows[0] || null;
  }

  static async getByBoxCode(boxCode) {
    const normalizedBoxCode = this.normalizeBoxCode(boxCode);
    if (!normalizedBoxCode) return null;

    const [rows] = await pool.query(
      `SELECT rb.*, op.name as released_by_name
       FROM oqc_release_boxes rb
       LEFT JOIN operators op ON rb.released_by = op.id
       WHERE rb.box_code = ?
       ORDER BY rb.released_at DESC, rb.id DESC`,
      [normalizedBoxCode]
    );

    return rows;
  }

  static async getAll(filters = {}) {
    let query = `
      SELECT rb.*, op.name as released_by_name
      FROM oqc_release_boxes rb
      LEFT JOIN operators op ON rb.released_by = op.id
      WHERE 1=1
    `;
    const params = [];

    if (filters.status) {
      query += ' AND rb.status = ?';
      params.push(filters.status);
    }

    if (filters.folio) {
      query += ' AND rb.oqc_folio = ?';
      params.push(filters.folio);
    }

    if (filters.partNumber) {
      query += ' AND rb.part_number LIKE ?';
      params.push(`%${filters.partNumber}%`);
    }

    if (filters.boxCode) {
      query += ' AND rb.box_code LIKE ?';
      params.push(`%${this.normalizeBoxCode(filters.boxCode)}%`);
    }

    if (filters.startDate) {
      query += ' AND DATE(rb.released_at) >= ?';
      params.push(filters.startDate);
    }

    if (filters.endDate) {
      query += ' AND DATE(rb.released_at) <= ?';
      params.push(filters.endDate);
    }

    query += ' ORDER BY rb.released_at DESC, rb.id DESC';

    const limit = Math.min(Number.parseInt(filters.limit || 200, 10), 1000);
    query += ' LIMIT ?';
    params.push(limit);

    const [rows] = await pool.query(query, params);
    return rows;
  }

  static async createManyForExitRecord(queryable, exitRecord, boxes, options = {}) {
    const normalizedBoxes = (boxes || [])
      .map((box) => ({
        boxCode: this.normalizeBoxCode(box.boxCode || box.box_code),
        quantity: this.normalizeQuantity(box.quantity),
      }))
      .filter((box) => box.boxCode && box.quantity > 0);

    if (normalizedBoxes.length === 0) return 0;

    const source = options.source || 'batch';
    const status = options.status || this.mapStatus(exitRecord);
    const releasedAt = exitRecord.exit_date || new Date();
    let partNumber = exitRecord.part_number || null;

    if (source !== 'migration') {
      const repeatedBox = normalizedBoxes.find((box, index) =>
        normalizedBoxes.findIndex((candidate) => candidate.boxCode === box.boxCode) !== index
      );
      if (repeatedBox) {
        const error = new Error(`La caja ${repeatedBox.boxCode} está repetida en el mismo folio`);
        error.code = 'BOX_DUPLICATED_IN_BATCH';
        throw error;
      }
    }

    if (!partNumber && exitRecord.part_number_id) {
      const [partRows] = await queryable.query(
        'SELECT part_number FROM part_numbers WHERE id = ? LIMIT 1',
        [exitRecord.part_number_id]
      );
      partNumber = partRows[0]?.part_number || null;
    }

    if (source !== 'migration') {
      const boxCodes = normalizedBoxes.map((box) => box.boxCode);
      const boxPlaceholders = boxCodes.map(() => '?').join(', ');
      const statusPlaceholders = ACTIVE_RELEASE_STATUSES.map(() => '?').join(', ');
      const [existingRows] = await queryable.query(
        `SELECT box_code, oqc_folio
         FROM oqc_release_boxes
         WHERE box_code IN (${boxPlaceholders})
           AND status IN (${statusPlaceholders})
           AND exit_record_id <> ?`,
        [...boxCodes, ...ACTIVE_RELEASE_STATUSES, exitRecord.id || 0]
      );

      if (existingRows.length > 0) {
        const first = existingRows[0];
        const error = new Error(
          `La caja ${first.box_code} ya fue liberada en el folio ${first.oqc_folio}`
        );
        error.code = 'BOX_ALREADY_RELEASED';
        throw error;
      }
    }

    const values = normalizedBoxes.map((box) => [
      exitRecord.id,
      exitRecord.folio,
      box.boxCode,
      exitRecord.part_number_id,
      partNumber,
      box.quantity,
      exitRecord.destination || 'Almacen',
      exitRecord.qc_passed !== false && exitRecord.qc_passed !== 0,
      status,
      source,
      exitRecord.operator_id,
      exitRecord.employee_id || null,
      releasedAt,
    ]);

    const placeholders = values
      .map(() => '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)')
      .join(', ');

    const duplicateClause = source === 'migration'
      ? 'ON DUPLICATE KEY UPDATE id = id'
      : `ON DUPLICATE KEY UPDATE
         quantity = VALUES(quantity),
         part_number_id = VALUES(part_number_id),
         part_number = VALUES(part_number),
         destination = VALUES(destination),
         qc_passed = VALUES(qc_passed),
         status = VALUES(status),
         source = VALUES(source),
         released_by = VALUES(released_by),
         employee_id = VALUES(employee_id),
         released_at = VALUES(released_at)`;

    const [result] = await queryable.query(
      `INSERT INTO oqc_release_boxes
       (exit_record_id, oqc_folio, box_code, part_number_id, part_number,
        quantity, destination, qc_passed, status, source, released_by,
        employee_id, released_at)
       VALUES ${placeholders}
       ${duplicateClause}`,
      values.flat()
    );

    return result.affectedRows;
  }

  static async migrateFromExitRecords(queryable) {
    const [records] = await queryable.query(
      `SELECT er.id, er.folio, er.part_number_id, pn.part_number,
              er.operator_id, er.employee_id, er.quantity, er.destination,
              er.status, er.qc_passed, er.exit_date, er.observations
       FROM exit_records er
       JOIN part_numbers pn ON er.part_number_id = pn.id
       WHERE er.observations LIKE '%Cajas:%'`
    );

    let recordsWithBoxes = 0;
    let boxesMigrated = 0;

    for (const record of records) {
      const boxes = this.parseBoxesFromObservations(record.observations);
      if (boxes.length === 0) continue;

      recordsWithBoxes += 1;
      await this.createManyForExitRecord(queryable, record, boxes, {
        source: 'migration',
      });
      boxesMigrated += boxes.length;
    }

    return { recordsWithBoxes, boxesMigrated };
  }
}

module.exports = OqcReleaseBoxModel;
