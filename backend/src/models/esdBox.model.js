const pool = require('../config/database');

class EsdBoxModel {
  static async getAll() {
    const [rows] = await pool.query(
      'SELECT * FROM esd_boxes WHERE active = TRUE ORDER BY capacity'
    );
    return rows;
  }

  static async getById(id) {
    const [rows] = await pool.query(
      'SELECT * FROM esd_boxes WHERE id = ?',
      [id]
    );
    return rows[0];
  }

  static async create(data) {
    const { box_code, capacity, description } = data;
    const [result] = await pool.query(
      'INSERT INTO esd_boxes (box_code, capacity, description) VALUES (?, ?, ?)',
      [box_code, capacity, description]
    );
    return result.insertId;
  }

  static async update(id, data) {
    const { box_code, capacity, description, active } = data;
    await pool.query(
      'UPDATE esd_boxes SET box_code = ?, capacity = ?, description = ?, active = ? WHERE id = ?',
      [box_code, capacity, description, active, id]
    );
    return true;
  }
}

module.exports = EsdBoxModel;
