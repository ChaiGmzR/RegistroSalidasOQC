-- Migración: Permitir NULL en exit_record_id para rechazos independientes
-- Ejecutar este script en la base de datos remota

-- Primero eliminar la foreign key si existe
SET FOREIGN_KEY_CHECKS=0;

-- Modificar la columna para permitir NULL
ALTER TABLE oqc_rejections MODIFY COLUMN exit_record_id INT NULL;

-- Eliminar el FK constraint de exit_record_id
ALTER TABLE oqc_rejections DROP FOREIGN KEY IF EXISTS oqc_rejections_ibfk_1;

SET FOREIGN_KEY_CHECKS=1;

-- Verificar la estructura
DESCRIBE oqc_rejections;
