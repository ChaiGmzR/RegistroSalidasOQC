const pool = require('../config/database');

class OperatorModel {
  static async getAll() {
    const [rows] = await pool.query(
      'SELECT id, employee_id, name, is_supervisor, department, active, created_at FROM operators WHERE active = TRUE ORDER BY name'
    );
    return rows;
  }

  static async getById(id) {
    const [rows] = await pool.query(
      'SELECT id, employee_id, name, pin, is_supervisor, department, active, created_at FROM operators WHERE id = ?',
      [id]
    );
    return rows[0];
  }

  static async getByEmployeeId(employeeId) {
    const [rows] = await pool.query(
      'SELECT id, employee_id, name, pin, is_supervisor, department, active, created_at FROM operators WHERE employee_id = ?',
      [employeeId]
    );
    return rows[0];
  }

  static async validatePin(employeeId, pin) {
    const [rows] = await pool.query(
      'SELECT id, employee_id, name, is_supervisor, department FROM operators WHERE employee_id = ? AND pin = ? AND active = TRUE',
      [employeeId, pin]
    );
    return rows[0];
  }

  static async validateSupervisorPin(pin) {
    const [rows] = await pool.query(
      'SELECT id, employee_id, name FROM operators WHERE pin = ? AND is_supervisor = TRUE AND active = TRUE',
      [pin]
    );
    return rows[0];
  }

  static async create(data) {
    const { employee_id, name, pin, is_supervisor, department } = data;
    const [result] = await pool.query(
      'INSERT INTO operators (employee_id, name, pin, is_supervisor, department) VALUES (?, ?, ?, ?, ?)',
      [employee_id, name, pin || '0000', is_supervisor || false, department || 'OQC']
    );
    return result.insertId;
  }

  static async update(id, data) {
    const { employee_id, name, pin, is_supervisor, department, active } = data;
    await pool.query(
      'UPDATE operators SET employee_id = ?, name = ?, pin = ?, is_supervisor = ?, department = ?, active = ? WHERE id = ?',
      [employee_id, name, pin, is_supervisor, department, active, id]
    );
    return true;
  }

  static async updatePin(id, pin) {
    await pool.query('UPDATE operators SET pin = ? WHERE id = ?', [pin, id]);
    return true;
  }

  static async delete(id) {
    await pool.query('UPDATE operators SET active = FALSE WHERE id = ?', [id]);
    return true;
  }
}

module.exports = OperatorModel;
