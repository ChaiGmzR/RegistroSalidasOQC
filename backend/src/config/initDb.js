const pool = require('./database');
const OqcReleaseBoxModel = require('../models/oqcReleaseBox.model');
const BoxScanModel = require('../models/boxScan.model');

const initDatabase = async () => {
  try {
    const connection = await pool.getConnection();

    // Configurar timezone de la sesión
    const tz = process.env.DB_TIMEZONE || '-06:00';
    await connection.query(`SET time_zone = '${tz}'`);
    console.log(`🕐 Timezone de sesión MySQL configurada: ${tz}`);

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
        folio VARCHAR(20) NOT NULL,
        box_code VARCHAR(100),
        part_number_id INT NOT NULL,
        esd_box_id INT NOT NULL,
        operator_id INT NOT NULL,
        quantity INT NOT NULL,
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
        FOREIGN KEY (operator_id) REFERENCES operators(id),
        INDEX idx_folio (folio),
        INDEX idx_box_code (box_code)
      )
    `);

    // Migración: Eliminar columnas obsoletas si existen
    try {
      const [cols] = await connection.query(`
        SELECT COLUMN_NAME 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = DATABASE() 
          AND TABLE_NAME = 'exit_records' 
          AND COLUMN_NAME IN ('lot_number', 'serial_start', 'serial_end')
      `);

      const columnNames = cols.map(c => c.COLUMN_NAME);

      if (columnNames.includes('lot_number')) {
        await connection.query(`ALTER TABLE exit_records DROP COLUMN lot_number`);
        console.log('✅ Columna lot_number eliminada');
      }
      if (columnNames.includes('serial_start')) {
        await connection.query(`ALTER TABLE exit_records DROP COLUMN serial_start`);
        console.log('✅ Columna serial_start eliminada');
      }
      if (columnNames.includes('serial_end')) {
        await connection.query(`ALTER TABLE exit_records DROP COLUMN serial_end`);
        console.log('✅ Columna serial_end eliminada');
      }
    } catch (err) {
      // Ignorar errores de migración de columnas obsoletas
    }

    // Migración: Agregar columna box_code si no existe
    try {
      const [boxCodeCol] = await connection.query(`
        SELECT COLUMN_NAME 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = DATABASE() 
          AND TABLE_NAME = 'exit_records' 
          AND COLUMN_NAME = 'box_code'
      `);

      if (boxCodeCol.length === 0) {
        await connection.query(`ALTER TABLE exit_records ADD COLUMN box_code VARCHAR(100) AFTER folio`);
        await connection.query(`CREATE INDEX idx_box_code ON exit_records(box_code)`);
        console.log('✅ Columna box_code agregada a exit_records');
      }
    } catch (err) {
      console.log('ℹ️ Columna box_code ya existe o error:', err.message);
    }

    // Migración: Quitar constraint UNIQUE de folio si existe
    try {
      const [indexes] = await connection.query(`
        SHOW INDEX FROM exit_records WHERE Column_name = 'folio' AND Non_unique = 0
      `);

      if (indexes.length > 0) {
        await connection.query(`ALTER TABLE exit_records DROP INDEX folio`);
        await connection.query(`CREATE INDEX idx_folio ON exit_records(folio)`);
        console.log('✅ Constraint UNIQUE de folio eliminado');
      }
    } catch (err) {
      // Ignorar si ya no existe
    }

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
        exit_record_id INT NULL,
        rejection_folio VARCHAR(20) NOT NULL UNIQUE,
        part_number_id INT NOT NULL,
        operator_id INT NOT NULL,
        expected_quantity INT NOT NULL,
        actual_quantity INT NOT NULL,
        quantity_difference INT NOT NULL,
        rejection_reason TEXT NOT NULL,
        box_codes TEXT,
        rejection_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        status ENUM('rejected', 'approved', 'partial_approved', 'released') DEFAULT 'rejected',
        corrected_by INT,
        corrected_at TIMESTAMP NULL,
        correction_notes TEXT,
        return_folio VARCHAR(20),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
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

    // Migración: Permitir NULL en exit_record_id para rechazos independientes
    try {
      await connection.query(`
        ALTER TABLE oqc_rejections MODIFY COLUMN exit_record_id INT NULL
      `);
      console.log('✅ Migración aplicada: exit_record_id ahora permite NULL');
    } catch (migrationError) {
      // Ignorar si la columna ya está modificada o no existe
      if (!migrationError.message.includes('Unknown column')) {
        console.log('ℹ️ Columna exit_record_id ya permite NULL o tabla no existe aún');
      }
    }

    // Migración: Agregar columna employee_id a exit_records
    try {
      const [exitRecordCols] = await connection.query(`
        SELECT COLUMN_NAME 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = DATABASE() 
          AND TABLE_NAME = 'exit_records' 
          AND COLUMN_NAME = 'employee_id'
      `);

      if (exitRecordCols.length === 0) {
        await connection.query(`
          ALTER TABLE exit_records ADD COLUMN employee_id VARCHAR(20) AFTER operator_id
        `);
        console.log('✅ Columna employee_id agregada a exit_records');

        // Actualizar registros existentes con el employee_id del operador
        await connection.query(`
          UPDATE exit_records er
          JOIN operators op ON er.operator_id = op.id
          SET er.employee_id = op.employee_id
          WHERE er.employee_id IS NULL
        `);
        console.log('✅ Registros existentes actualizados con employee_id');
      } else {
        console.log('ℹ️ Columna employee_id ya existe en exit_records');
      }
    } catch (err) {
      console.log('⚠️ Error en migración employee_id para exit_records:', err.message);
    }

    // Migración: Agregar columna employee_id a oqc_rejections
    try {
      const [rejectionCols] = await connection.query(`
        SELECT COLUMN_NAME 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = DATABASE() 
          AND TABLE_NAME = 'oqc_rejections' 
          AND COLUMN_NAME = 'employee_id'
      `);

      if (rejectionCols.length === 0) {
        await connection.query(`
          ALTER TABLE oqc_rejections ADD COLUMN employee_id VARCHAR(20) AFTER operator_id
        `);
        console.log('✅ Columna employee_id agregada a oqc_rejections');

        // Actualizar registros existentes con el employee_id del operador
        await connection.query(`
          UPDATE oqc_rejections r
          JOIN operators op ON r.operator_id = op.id
          SET r.employee_id = op.employee_id
          WHERE r.employee_id IS NULL
        `);
        console.log('✅ Registros de rechazos actualizados con employee_id');
      } else {
        console.log('ℹ️ Columna employee_id ya existe en oqc_rejections');
      }
    } catch (err) {
      console.log('⚠️ Error en migración employee_id para oqc_rejections:', err.message);
    }

    // Tabla normalizada de cajas liberadas por OQC hacia almacén/embarques.
    // exit_records se mantiene como encabezado del folio; esta tabla conserva el detalle por caja.
    await connection.query(`
      CREATE TABLE IF NOT EXISTS oqc_release_boxes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        exit_record_id INT NOT NULL,
        oqc_folio VARCHAR(20) NOT NULL,
        box_code VARCHAR(100) NOT NULL,
        part_number_id INT NOT NULL,
        part_number VARCHAR(50),
        quantity INT NOT NULL DEFAULT 0,
        destination VARCHAR(100) DEFAULT 'Almacen',
        qc_passed BOOLEAN DEFAULT TRUE,
        status ENUM('released', 'received_shipping', 'cancelled', 'rejected', 'exception') DEFAULT 'released',
        source ENUM('batch', 'migration', 'manual') DEFAULT 'batch',
        released_by INT NOT NULL,
        employee_id VARCHAR(20),
        released_at TIMESTAMP NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (exit_record_id) REFERENCES exit_records(id) ON DELETE CASCADE,
        FOREIGN KEY (part_number_id) REFERENCES part_numbers(id),
        FOREIGN KEY (released_by) REFERENCES operators(id),
        UNIQUE KEY uq_oqc_release_exit_box (exit_record_id, box_code),
        INDEX idx_oqc_release_box_code (box_code),
        INDEX idx_oqc_release_folio (oqc_folio),
        INDEX idx_oqc_release_part_number (part_number),
        INDEX idx_oqc_release_status (status),
        INDEX idx_oqc_release_released_at (released_at)
      )
    `);

    // Migración de estados legacy de rechazos hacia el nuevo flujo.
    try {
      await connection.query(`
        ALTER TABLE oqc_rejections
        MODIFY COLUMN status ENUM(
          'pending', 'in_review', 'corrected', 'returned',
          'rejected', 'approved', 'partial_approved', 'released'
        ) DEFAULT 'rejected'
      `);
      await connection.query(`
        UPDATE oqc_rejections
        SET status = CASE
          WHEN status IN ('pending', 'in_review') THEN 'rejected'
          WHEN status = 'corrected' THEN 'approved'
          WHEN status = 'returned' THEN 'released'
          ELSE status
        END
      `);
      await connection.query(`
        ALTER TABLE oqc_rejections
        MODIFY COLUMN status ENUM('rejected', 'approved', 'partial_approved', 'released') DEFAULT 'rejected'
      `);
      console.log('✅ Estados de oqc_rejections migrados al nuevo flujo');
    } catch (err) {
      console.log('⚠️ Error migrando estados de oqc_rejections:', err.message);
    }

    // Detalle normalizado por pieza/serial para aprobación y liberación de rechazos.
    await connection.query(`
      CREATE TABLE IF NOT EXISTS oqc_rejection_items (
        id INT AUTO_INCREMENT PRIMARY KEY,
        rejection_id INT NOT NULL,
        serial VARCHAR(255) NOT NULL,
        original_box_code VARCHAR(100) NOT NULL,
        part_number VARCHAR(50),
        status ENUM('rejected', 'approved', 'released') DEFAULT 'rejected',
        approved_by INT,
        approved_at TIMESTAMP NULL,
        released_at TIMESTAMP NULL,
        release_folio VARCHAR(20),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (rejection_id) REFERENCES oqc_rejections(id) ON DELETE CASCADE,
        FOREIGN KEY (approved_by) REFERENCES operators(id),
        UNIQUE KEY uq_oqc_rejection_item (rejection_id, serial),
        INDEX idx_oqc_rejection_item_serial (serial),
        INDEX idx_oqc_rejection_item_box (original_box_code),
        INDEX idx_oqc_rejection_item_status (status)
      )
    `);

    // Backfill de piezas para rechazos históricos con box_codes parseables.
    try {
      const [legacyRejections] = await connection.query(`
        SELECT r.id, r.box_codes
        FROM oqc_rejections r
        LEFT JOIN oqc_rejection_items i ON i.rejection_id = r.id
        WHERE r.box_codes IS NOT NULL
          AND r.box_codes <> ''
        GROUP BY r.id, r.box_codes
        HAVING COUNT(i.id) = 0
      `);

      let backfilledItems = 0;
      const boxRegex = /([^,:\n]+?)\s*:\s*\d+\s*pzas?/gi;
      for (const rejection of legacyRejections) {
        const boxCodes = [];
        let match;
        while ((match = boxRegex.exec(rejection.box_codes)) !== null) {
          const boxCode = match[1].trim();
          if (boxCode && !boxCodes.includes(boxCode)) {
            boxCodes.push(boxCode);
          }
        }

        if (boxCodes.length === 0) continue;

        const serials = await BoxScanModel.getSerialsByBoxCodes(boxCodes, connection);
        for (const item of serials) {
          await connection.query(
            `INSERT IGNORE INTO oqc_rejection_items
             (rejection_id, serial, original_box_code, part_number, status)
             VALUES (?, ?, ?, ?, 'rejected')`,
            [rejection.id, item.serial, item.box_code, item.part_number]
          );
          backfilledItems += 1;
        }
      }
      console.log(`✅ Backfill oqc_rejection_items: ${backfilledItems} piezas procesadas`);
    } catch (err) {
      console.log('⚠️ Error migrando piezas históricas de rechazo:', err.message);
    }

    try {
      const migrationSummary = await OqcReleaseBoxModel.migrateFromExitRecords(connection);
      console.log(
        `✅ Migración oqc_release_boxes: ${migrationSummary.boxesMigrated} cajas procesadas ` +
        `desde ${migrationSummary.recordsWithBoxes} folios históricos`
      );

      const employeeBackfill = await OqcReleaseBoxModel.backfillEmployeeIds(connection);
      console.log(
        `✅ Employee ID OQC actualizado: ${employeeBackfill.exitRecordsUpdated} registros OQC, ` +
        `${employeeBackfill.releaseBoxesUpdated} cajas liberadas`
      );
    } catch (err) {
      console.log('⚠️ Error migrando cajas históricas de OQC:', err.message);
    }

    connection.release();
    console.log('✅ Base de datos inicializada correctamente');
    return true;
  } catch (error) {
    console.error('❌ Error inicializando la base de datos:', error);
    throw error;
  }
};

module.exports = initDatabase;
