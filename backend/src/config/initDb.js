const pool = require('./database');

const initDatabase = async () => {
  try {
    const connection = await pool.getConnection();

    // Tabla de números de parte (Part Numbers)
    await connection.query(`
      CREATE TABLE IF NOT EXISTS part_numbers (
        id INT AUTO_INCREMENT PRIMARY KEY,
        part_number VARCHAR(50) NOT NULL UNIQUE,
        description VARCHAR(255),
        standard_pack INT NOT NULL DEFAULT 10,
        model VARCHAR(100),
        customer VARCHAR(100) DEFAULT 'LG',
        active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    `);

    // Tabla de cajas ESD
    await connection.query(`
      CREATE TABLE IF NOT EXISTS esd_boxes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        box_code VARCHAR(50) NOT NULL UNIQUE,
        capacity INT NOT NULL,
        description VARCHAR(255),
        active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Tabla de operadores/usuarios
    await connection.query(`
      CREATE TABLE IF NOT EXISTS operators (
        id INT AUTO_INCREMENT PRIMARY KEY,
        employee_id VARCHAR(20) NOT NULL UNIQUE,
        name VARCHAR(100) NOT NULL,
        pin VARCHAR(6) NOT NULL DEFAULT '0000',
        is_supervisor BOOLEAN DEFAULT FALSE,
        department VARCHAR(50) DEFAULT 'OQC',
        active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Migraciones: Agregar columnas faltantes a operators (para tablas creadas previamente)
    const columnsToAdd = [
      { name: 'pin', definition: "VARCHAR(6) NOT NULL DEFAULT '0000' AFTER name" },
      { name: 'is_supervisor', definition: "BOOLEAN DEFAULT FALSE AFTER pin" },
      { name: 'department', definition: "VARCHAR(50) DEFAULT 'OQC' AFTER is_supervisor" },
      { name: 'active', definition: "BOOLEAN DEFAULT TRUE AFTER department" }
    ];

    for (const col of columnsToAdd) {
      try {
        await connection.query(`ALTER TABLE operators ADD COLUMN ${col.name} ${col.definition}`);
        console.log(`✅ Columna ${col.name} agregada a operators`);
      } catch (alterError) {
        // Ignorar si la columna ya existe
        if (alterError.code === 'ER_DUP_FIELDNAME') {
          console.log(`ℹ️ Columna ${col.name} ya existe en operators`);
        }
      }
    }

    // Tabla principal de registros de salida
    await connection.query(`
      CREATE TABLE IF NOT EXISTS exit_records (
        id INT AUTO_INCREMENT PRIMARY KEY,
        folio VARCHAR(20) NOT NULL UNIQUE,
        part_number_id INT NOT NULL,
        esd_box_id INT NOT NULL,
        operator_id INT NOT NULL,
        quantity INT NOT NULL,
        lot_number VARCHAR(50),
        serial_start VARCHAR(50),
        serial_end VARCHAR(50),
        inspection_date DATE NOT NULL,
        exit_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        destination VARCHAR(100) DEFAULT 'Almacen',
        status ENUM('pending', 'released', 'shipped', 'cancelled') DEFAULT 'pending',
        observations TEXT,
        qc_passed BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (part_number_id) REFERENCES part_numbers(id),
        FOREIGN KEY (esd_box_id) REFERENCES esd_boxes(id),
        FOREIGN KEY (operator_id) REFERENCES operators(id)
      )
    `);

    // Tabla de detalles de inspección
    await connection.query(`
      CREATE TABLE IF NOT EXISTS inspection_details (
        id INT AUTO_INCREMENT PRIMARY KEY,
        exit_record_id INT NOT NULL,
        inspection_type VARCHAR(50) NOT NULL,
        result ENUM('pass', 'fail', 'na') NOT NULL,
        notes TEXT,
        inspected_by INT,
        inspected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (exit_record_id) REFERENCES exit_records(id) ON DELETE CASCADE,
        FOREIGN KEY (inspected_by) REFERENCES operators(id)
      )
    `);

    // Tabla de rechazos OQC
    await connection.query(`
      CREATE TABLE IF NOT EXISTS oqc_rejections (
        id INT AUTO_INCREMENT PRIMARY KEY,
        exit_record_id INT NOT NULL,
        rejection_folio VARCHAR(20) NOT NULL UNIQUE,
        part_number_id INT NOT NULL,
        operator_id INT NOT NULL,
        expected_quantity INT NOT NULL,
        actual_quantity INT NOT NULL,
        quantity_difference INT NOT NULL,
        rejection_reason TEXT NOT NULL,
        box_codes TEXT,
        rejection_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        status ENUM('pending', 'in_review', 'corrected', 'returned') DEFAULT 'pending',
        corrected_by INT,
        corrected_at TIMESTAMP NULL,
        correction_notes TEXT,
        return_folio VARCHAR(20),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (exit_record_id) REFERENCES exit_records(id),
        FOREIGN KEY (part_number_id) REFERENCES part_numbers(id),
        FOREIGN KEY (operator_id) REFERENCES operators(id),
        FOREIGN KEY (corrected_by) REFERENCES operators(id)
      )
    `);

    // Insertar datos iniciales de cajas ESD
    await connection.query(`
      INSERT IGNORE INTO esd_boxes (box_code, capacity, description) VALUES
      ('ESD-10', 10, 'Caja ESD Standard Pack 10'),
      ('ESD-20', 20, 'Caja ESD Standard Pack 20'),
      ('ESD-40', 40, 'Caja ESD Standard Pack 40'),
      ('ESD-80', 80, 'Caja ESD Standard Pack 80'),
      ('ESD-100', 100, 'Caja ESD Standard Pack 100')
    `);

    // Insertar operador supervisor por defecto
    await connection.query(`
      INSERT IGNORE INTO operators (employee_id, name, pin, is_supervisor, department) VALUES
      ('OQC001', 'Supervisor OQC', '1234', TRUE, 'OQC')
    `);

    connection.release();
    console.log('✅ Base de datos inicializada correctamente');
    return true;
  } catch (error) {
    console.error('❌ Error inicializando la base de datos:', error);
    throw error;
  }
};

module.exports = initDatabase;
