-- =============================================
-- DEPLOY: fun_create_driver v3.0 - IDs Secuenciales
-- =============================================
-- Este script despliega la versión 3.0 de fun_create_driver
-- que genera IDs de forma secuencial (MAX + 1)
--
-- Ejecutar en: PostgreSQL 12+
-- Base de datos: db_bucarabus
-- Usuario: dlastre (o bucarabus_user)
-- =============================================

-- Copiar el contenido de fun_create_driver.sql
\i fun_create_driver.sql

-- Verificar que la función fue creada
\df fun_create_driver

-- =============================================
-- COMENTARIO DE LA FUNCIÓN
-- =============================================

COMMENT ON FUNCTION fun_create_driver IS 
'v3.0 - Crea conductor con ID secuencial (MAX+1). Valida email, nombre, password hash bcrypt, cédula, teléfono, licencia. Asigna rol Conductor automáticamente.';

-- =============================================
-- FIN DEL DEPLOY
-- =============================================
