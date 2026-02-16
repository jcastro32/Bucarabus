-- =============================================
-- FUNCIÓN: fun_delete_driver v2.0
-- =============================================
-- Descripción: Elimina (inactiva) un conductor mediante soft delete
--              Inactiva: tab_users.is_active, tab_user_roles.is_active,
--                        tab_driver_details.status_driver y available
-- Arquitectura: tab_users + tab_user_roles + tab_driver_details
-- 
-- Parámetros IN:
--   wid_user       - ID del usuario conductor a eliminar (INTEGER)
--   wuser_delete   - ID del usuario administrador que hace la eliminación (INTEGER)
--
-- Parámetros OUT:
--   success        - TRUE si el conductor se eliminó exitosamente
--   msg            - Mensaje descriptivo del resultado
--   error_code     - Código de error (NULL si success = TRUE)
--
-- Uso:
--   SELECT * FROM fun_delete_driver(123, 1);
--
-- Retorna: (success, msg, error_code)
--
-- Versión: 2.0
-- Fecha: 2026-02-16
-- =============================================

-- Eliminar funciones anteriores (diferentes firmas)
DROP FUNCTION IF EXISTS fun_delete_driver(INTEGER, VARCHAR);
DROP FUNCTION IF EXISTS fun_delete_driver(INTEGER);
DROP FUNCTION IF EXISTS fun_delete_driver(tab_users.id_user%TYPE, tab_users.user_update%TYPE);

CREATE OR REPLACE FUNCTION fun_delete_driver(
  wid_user       tab_users.id_user%TYPE,
  wuser_delete   tab_users.user_update%TYPE,
  OUT success    BOOLEAN,
  OUT msg        VARCHAR,
  OUT error_code VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
  -- ==========================================
  -- 1. SECCIÓN DE VARIABLES
  -- ==========================================
  
  -- Variables de validación
  v_deleter_exists   BOOLEAN;
  v_user_exists      BOOLEAN;
  v_user_active      BOOLEAN;
  v_is_driver        BOOLEAN;
  v_driver_active    BOOLEAN;
  v_has_active_bus   BOOLEAN;
  
  -- Variables para información del conductor
  v_driver_name      tab_users.full_name%TYPE;
  v_driver_email     tab_users.email%TYPE;
  v_assigned_plate   tab_buses.plate_number%TYPE;
  
  -- Variables para UPDATE
  v_rows_affected    INTEGER;

BEGIN
  -- ==========================================
  -- 2. INICIALIZACIÓN
  -- ==========================================
  
  success := FALSE;
  msg := '';
  error_code := NULL;
  
  RAISE NOTICE '[fun_delete_driver] Iniciando eliminación de conductor: ID=%', wid_user;
  
  -- ==========================================
  -- 3. VALIDAR USUARIO QUE HACE LA ELIMINACIÓN
  -- ==========================================
  
  SELECT EXISTS(
    SELECT 1 FROM tab_users 
    WHERE id_user = wuser_delete AND is_active = TRUE
  ) INTO v_deleter_exists;
  
  IF NOT v_deleter_exists THEN
    msg := 'El usuario que intenta eliminar no existe o está inactivo (ID: ' || wuser_delete || ')';
    error_code := 'USER_DELETE_NOT_FOUND';
    RAISE NOTICE '[fun_delete_driver] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 4. VALIDAR QUE EL USUARIO CONDUCTOR EXISTE
  -- ==========================================
  
  SELECT EXISTS(
    SELECT 1 FROM tab_users 
    WHERE id_user = wid_user
  ) INTO v_user_exists;
  
  IF NOT v_user_exists THEN
    msg := 'El usuario con ID ' || wid_user || ' no existe';
    error_code := 'USER_NOT_FOUND';
    RAISE NOTICE '[fun_delete_driver] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 5. VALIDAR QUE EL USUARIO ESTÁ ACTIVO
  -- ==========================================
  
  SELECT is_active INTO v_user_active
  FROM tab_users 
  WHERE id_user = wid_user;
  
  IF NOT v_user_active THEN
    msg := 'El usuario con ID ' || wid_user || ' ya está inactivo';
    error_code := 'USER_ALREADY_INACTIVE';
    RAISE NOTICE '[fun_delete_driver] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 6. VALIDAR QUE ES UN CONDUCTOR
  -- ==========================================
  
  SELECT EXISTS(
    SELECT 1 FROM tab_user_roles 
    WHERE id_user = wid_user AND id_role = 2  -- 2 = Conductor
  ) INTO v_is_driver;
  
  IF NOT v_is_driver THEN
    msg := 'El usuario con ID ' || wid_user || ' no es un conductor (no tiene rol id_role = 2)';
    error_code := 'NOT_A_DRIVER';
    RAISE NOTICE '[fun_delete_driver] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 7. VALIDAR QUE EL ROL DE CONDUCTOR ESTÁ ACTIVO
  -- ==========================================
  
  SELECT is_active INTO v_driver_active
  FROM tab_user_roles 
  WHERE id_user = wid_user AND id_role = 2;
  
  IF NOT v_driver_active THEN
    msg := 'El rol de conductor para el usuario ' || wid_user || ' ya está inactivo';
    error_code := 'DRIVER_ROLE_ALREADY_INACTIVE';
    RAISE NOTICE '[fun_delete_driver] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 8. OBTENER INFORMACIÓN DEL CONDUCTOR
  -- ==========================================
  
  SELECT full_name, email 
  INTO v_driver_name, v_driver_email
  FROM tab_users 
  WHERE id_user = wid_user;
  
  -- ==========================================
  -- 9. VALIDAR ASIGNACIONES ACTIVAS DE BUS
  -- ==========================================
  
  SELECT EXISTS(
    SELECT 1 FROM tab_bus_assignments
    WHERE id_user = wid_user 
      AND unassigned_at IS NULL  -- Asignación activa
  ) INTO v_has_active_bus;
  
  IF v_has_active_bus THEN
    -- Obtener la placa del bus asignado
    SELECT plate_number INTO v_assigned_plate
    FROM tab_bus_assignments
    WHERE id_user = wid_user 
      AND unassigned_at IS NULL
    LIMIT 1;
    
    msg := 'El conductor tiene un bus asignado activamente (Placa: ' || v_assigned_plate || 
           '). Debe desasignar el bus primero antes de eliminar el conductor';
    error_code := 'DRIVER_HAS_ACTIVE_BUS_ASSIGNMENT';
    RAISE NOTICE '[fun_delete_driver] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 10. SOFT DELETE - INACTIVAR EN TAB_USERS
  -- ==========================================
  
  BEGIN
    UPDATE tab_users 
    SET is_active = FALSE,
        updated_at = NOW(),
        user_update = wuser_delete
    WHERE id_user = wid_user;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    IF v_rows_affected = 0 THEN
      msg := 'No se pudo inactivar el usuario en tab_users (ID: ' || wid_user || ')';
      error_code := 'USER_UPDATE_FAILED';
      RAISE NOTICE '[fun_delete_driver] ERROR: %', msg;
      RETURN;
    END IF;
    
    RAISE NOTICE '[fun_delete_driver] Usuario inactivado en tab_users: ID=%', wid_user;
    
  EXCEPTION
    WHEN foreign_key_violation THEN
      msg := 'Error: Violación de clave foránea al actualizar tab_users (user_update inválido)';
      error_code := 'USER_UPDATE_FK_VIOLATION';
      RAISE NOTICE '[fun_delete_driver] ERROR: %', msg;
      RETURN;
      
    WHEN OTHERS THEN
      msg := 'Error inesperado al actualizar tab_users: ' || SQLERRM;
      error_code := 'USER_UPDATE_ERROR';
      RAISE NOTICE '[fun_delete_driver] ERROR: %', msg;
      RETURN;
  END;
  
  -- ==========================================
  -- 11. INACTIVAR ROL DE CONDUCTOR
  -- ==========================================
  
  BEGIN
    UPDATE tab_user_roles 
    SET is_active = FALSE
    WHERE id_user = wid_user 
      AND id_role = 2;  -- 2 = Conductor
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    IF v_rows_affected = 0 THEN
      msg := 'No se pudo inactivar el rol de conductor en tab_user_roles (ID: ' || wid_user || ')';
      error_code := 'USER_ROLE_UPDATE_FAILED';
      RAISE NOTICE '[fun_delete_driver] ERROR: %', msg;
      RETURN;
    END IF;
    
    RAISE NOTICE '[fun_delete_driver] Rol de conductor inactivado: ID=%', wid_user;
    
  EXCEPTION
    WHEN OTHERS THEN
      msg := 'Error inesperado al actualizar tab_user_roles: ' || SQLERRM;
      error_code := 'USER_ROLE_UPDATE_ERROR';
      RAISE NOTICE '[fun_delete_driver] ERROR: %', msg;
      RETURN;
  END;
  
  -- ==========================================
  -- 12. INACTIVAR EN TAB_DRIVER_DETAILS
  -- ==========================================
  
  BEGIN
    UPDATE tab_driver_details 
    SET available = FALSE,
        status_driver = FALSE,
        updated_at = NOW(),
        user_update = wuser_delete
    WHERE id_user = wid_user;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    IF v_rows_affected = 0 THEN
      msg := 'No se pudo inactivar el conductor en tab_driver_details (ID: ' || wid_user || ')';
      error_code := 'DRIVER_DETAILS_UPDATE_FAILED';
      RAISE NOTICE '[fun_delete_driver] ERROR: %', msg;
      RETURN;
    END IF;
    
    RAISE NOTICE '[fun_delete_driver] Detalles de conductor inactivados: ID=%', wid_user;
    
  EXCEPTION
    WHEN foreign_key_violation THEN
      msg := 'Error: Violación de clave foránea al actualizar tab_driver_details';
      error_code := 'DRIVER_DETAILS_UPDATE_FK_VIOLATION';
      RAISE NOTICE '[fun_delete_driver] ERROR: %', msg;
      RETURN;
      
    WHEN OTHERS THEN
      msg := 'Error inesperado al actualizar tab_driver_details: ' || SQLERRM;
      error_code := 'DRIVER_DETAILS_UPDATE_ERROR';
      RAISE NOTICE '[fun_delete_driver] ERROR: %', msg;
      RETURN;
  END;
  
  -- ==========================================
  -- 13. RETORNO EXITOSO
  -- ==========================================
  
  success := TRUE;
  msg := 'Conductor eliminado exitosamente (soft delete): ' || v_driver_name || 
         ' (' || v_driver_email || ')';
  error_code := NULL;
  
  RAISE NOTICE '[fun_delete_driver] Éxito: Conductor % (ID %) eliminado por usuario %', 
               v_driver_name, wid_user, wuser_delete;
  
END;
$$;

-- =============================================
-- COMENTARIOS FINALES
-- =============================================

COMMENT ON FUNCTION fun_delete_driver IS 
'v2.0 - Elimina (inactiva) un conductor mediante soft delete en tab_users, tab_user_roles y tab_driver_details.
Validaciones: usuario que elimina existe y activo, conductor existe y activo, es conductor, 
no tiene asignaciones de bus activas.
Actualiza: is_active=FALSE en tab_users y tab_user_roles, status_driver=FALSE y available=FALSE en tab_driver_details.
Registra auditoría: user_update con ID de quien hace la eliminación.
Retorna: success (BOOLEAN), msg (VARCHAR), error_code (VARCHAR).
Códigos de error: USER_DELETE_NOT_FOUND, USER_NOT_FOUND, USER_ALREADY_INACTIVE, NOT_A_DRIVER, 
DRIVER_ROLE_ALREADY_INACTIVE, DRIVER_HAS_ACTIVE_BUS_ASSIGNMENT, USER_UPDATE_FAILED, USER_UPDATE_FK_VIOLATION, 
USER_UPDATE_ERROR, USER_ROLE_UPDATE_FAILED, USER_ROLE_UPDATE_ERROR, DRIVER_DETAILS_UPDATE_FAILED, 
DRIVER_DETAILS_UPDATE_FK_VIOLATION, DRIVER_DETAILS_UPDATE_ERROR.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================

/*
-- Ejemplo 1: Eliminar conductor (usuario admin con ID 1)
SELECT * FROM fun_delete_driver(
  123,  -- ID del conductor
  1     -- ID del usuario admin que hace la eliminación
);

-- Resultado exitoso:
-- success | msg                                     | error_code
-- TRUE    | Conductor eliminado exitosamente (s... | NULL


-- Ejemplo 2: ERROR - Usuario que elimina no existe
SELECT * FROM fun_delete_driver(
  123,
  999999  -- Usuario inexistente
);

-- Resultado:
-- success | msg                                  | error_code
-- FALSE   | El usuario que intenta eliminar n... | USER_DELETE_NOT_FOUND


-- Ejemplo 3: ERROR - Usuario conductor no existe
SELECT * FROM fun_delete_driver(
  999999,  -- ID inexistente
  1
);

-- Resultado:
-- success | msg                              | error_code
-- FALSE   | El usuario con ID 999999 no e... | USER_NOT_FOUND


-- Ejemplo 4: ERROR - Usuario ya está inactivo
SELECT * FROM fun_delete_driver(
  123,  -- Ya eliminado previamente
  1
);

-- Resultado:
-- success | msg                                  | error_code
-- FALSE   | El usuario con ID 123 ya está in... | USER_ALREADY_INACTIVE


-- Ejemplo 5: ERROR - Usuario no es conductor
SELECT * FROM fun_delete_driver(
  456,  -- Usuario pasajero
  1
);

-- Resultado:
-- success | msg                                  | error_code
-- FALSE   | El usuario con ID 456 no es un c... | NOT_A_DRIVER


-- Ejemplo 6: ERROR - Conductor tiene bus asignado
SELECT * FROM fun_delete_driver(
  123,  -- Tiene bus ABC123 asignado
  1
);

-- Resultado:
-- success | msg                                     | error_code
-- FALSE   | El conductor tiene un bus asignado a... | DRIVER_HAS_ACTIVE_BUS_ASSIGNMENT


-- Ejemplo 7: Verificar que el conductor está inactivo después de eliminarlo
SELECT 
  u.id_user,
  u.email,
  u.full_name,
  u.is_active AS user_active,
  ur.is_active AS role_active,
  dd.status_driver,
  dd.available
FROM tab_users u
LEFT JOIN tab_user_roles ur ON u.id_user = ur.id_user AND ur.id_role = 2
LEFT JOIN tab_driver_details dd ON u.id_user = dd.id_user
WHERE u.id_user = 123;

-- Resultado:
-- id_user | email           | full_name   | user_active | role_active | status_driver | available
-- 123     | juan@email.com  | Juan Pérez  | FALSE       | FALSE       | FALSE         | FALSE


-- Ejemplo 8: Verificar auditoría
SELECT 
  id_user,
  email,
  updated_at,
  user_update
FROM tab_users
WHERE id_user = 123;

-- Resultado:
-- id_user | email          | updated_at           | user_update
-- 123     | juan@email.com | 2026-02-16 10:30:00  | 1    (admin que eliminó)

*/

-- =============================================
-- FIN DE LA FUNCIÓN fun_delete_driver v2.0
-- =============================================
