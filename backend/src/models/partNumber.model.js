const pool = require('../config/database');

class PartNumberModel {
  static async getAll() {
    const [rows] = await pool.query(
      'SELECT * FROM part_numbers WHERE active = TRUE ORDER BY part_number'
    );
    return rows;
  }

  static async getById(id) {
    const [rows] = await pool.query(
      'SELECT * FROM part_numbers WHERE id = ?',
      [id]
    );
    return rows[0];
  }

  static async create(data) {
    const { part_number, description, standard_pack, model, customer } = data;
    const [result] = await pool.query(
      `INSERT INTO part_numbers (part_number, description, standard_pack, model, customer) 
       VALUES (?, ?, ?, ?, ?)`,
      [part_number, description, standard_pack, model, customer || 'LG']
    );
    return result.insertId;
  }

  static async update(id, data) {
    const { part_number, description, standard_pack, model, customer, active } = data;
    await pool.query(
      `UPDATE part_numbers SET part_number = ?, description = ?, standard_pack = ?, 
       model = ?, customer = ?, active = ? WHERE id = ?`,
      [part_number, description, standard_pack, model, customer, active, id]
    );
    return true;
  }

  static async delete(id) {
    await pool.query('UPDATE part_numbers SET active = FALSE WHERE id = ?', [id]);
    return true;
  }

  static async search(query) {
    const [rows] = await pool.query(
      `SELECT * FROM part_numbers WHERE active = TRUE AND 
       (part_number LIKE ? OR description LIKE ? OR model LIKE ?)`,
      [`%${query}%`, `%${query}%`, `%${query}%`]
    );
    return rows;
  }

  static async bulkCreate(records) {
    // Desactivar verificación de claves foráneas
    await pool.query('SET FOREIGN_KEY_CHECKS = 0');
    
    try {
      // Primero eliminar todos los registros existentes
      await pool.query('DELETE FROM part_numbers');
      
      // Insertar todos los nuevos registros
      const values = records.map(r => [
        r.part_number,
        r.description || null,
        r.standard_pack || 1,
        r.model || null,
        r.customer || 'LG',
        r.active !== undefined ? r.active : true
      ]);
      
      const placeholders = records.map(() => '(?, ?, ?, ?, ?, ?)').join(', ');
      const flatValues = values.flat();
      
      const [result] = await pool.query(
        `INSERT INTO part_numbers (part_number, description, standard_pack, model, customer, active) 
         VALUES ${placeholders}`,
        flatValues
      );
      
      return result.affectedRows;
    } finally {
      // Reactivar verificación de claves foráneas
      await pool.query('SET FOREIGN_KEY_CHECKS = 1');
    }
  }
}

module.exports = PartNumberModel;
