-- Limpieza controlada de duplicados en box_scans.
-- Primero ejecuta el bloque de diagnostico y revisa los resultados.
-- Ajusta @target_folder_date antes de insertar respaldos o eliminar filas.

SET @target_folder_date = '2026-04-30';

-- Diagnostico: cajas donde el conteo de filas no coincide con seriales unicos.
SELECT
  box_code,
  folder_date,
  COUNT(*) AS total_rows,
  COUNT(DISTINCT serial) AS unique_serials,
  COUNT(*) - COUNT(DISTINCT serial) AS extra_rows
FROM box_scans FORCE INDEX (idx_folder_date)
WHERE folder_date = @target_folder_date
GROUP BY box_code, folder_date
HAVING extra_rows > 0
ORDER BY extra_rows DESC, box_code;

-- Diagnostico: filas repetidas exactas contra la llave logica actual.
SELECT
  box_code,
  serial,
  first_scan,
  COUNT(*) AS duplicated_rows,
  GROUP_CONCAT(id ORDER BY id) AS ids
FROM box_scans FORCE INDEX (idx_folder_date)
WHERE folder_date = @target_folder_date
GROUP BY box_code, serial, first_scan
HAVING duplicated_rows > 1
ORDER BY box_code, serial, first_scan;

-- Respaldo de las filas que se van a eliminar.
CREATE TABLE IF NOT EXISTS box_scans_duplicate_backup LIKE box_scans;

INSERT INTO box_scans_duplicate_backup
SELECT bs.*
FROM box_scans bs
JOIN (
  SELECT DISTINCT duplicate_id
  FROM (
    SELECT
      b2.id AS duplicate_id
    FROM box_scans b1
    JOIN box_scans b2
      ON b1.serial = b2.serial
     AND b1.box_code = b2.box_code
     AND b1.first_scan = b2.first_scan
     AND b1.id < b2.id
    WHERE b1.folder_date = @target_folder_date
      AND b2.folder_date = @target_folder_date
  ) duplicates
) d ON d.duplicate_id = bs.id
LEFT JOIN box_scans_duplicate_backup bak ON bak.id = bs.id
WHERE bak.id IS NULL;

-- Eliminacion: conserva el id menor de cada duplicado exacto.
-- Ejecutar solo despues de validar el respaldo anterior.
DELETE bs
FROM box_scans bs
JOIN (
  SELECT DISTINCT duplicate_id
  FROM (
    SELECT
      b2.id AS duplicate_id
    FROM box_scans b1
    JOIN box_scans b2
      ON b1.serial = b2.serial
     AND b1.box_code = b2.box_code
     AND b1.first_scan = b2.first_scan
     AND b1.id < b2.id
    WHERE b1.folder_date = @target_folder_date
      AND b2.folder_date = @target_folder_date
  ) duplicates
) d ON d.duplicate_id = bs.id;
