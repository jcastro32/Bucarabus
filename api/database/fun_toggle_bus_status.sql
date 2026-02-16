-- =============================================
-- FUNCIÓN: fun_toggle_bus_status v2.0
-- =============================================
-- Descripción: Activa o desactiva un bus en el sistema
--              Cambia is_active entre TRUE/FALSE
--              Al desactivar, verifica que no tenga asignaciones activas
-- 
-- Parámetros IN:
--   wplate_number  - Placa del bus (VARCHAR 6)
--   wis_active     - Nuevo estado (TRUE = activar, FALSE = desactivar)
--   wuser_update   - ID del usuario que hace el cambio (INTEGER)
--
-- Parámetros OUT:
--   success        - TRUE si el cambio se realizó exitosamente
--   msg            - Mensaje descriptivo del resultado
--   error_code     - Código de error (NULL si success = TRUE)
--
-- Uso:
--   SELECT * FROM fun_toggle_bus_status('ABC123', FALSE, 1);  -- Desactivar
--   SELECT * FROM fun_toggle_bus_status('ABC123', TRUE, 1);   -- Activar
--
-- Retorna: (success, msg, error_code)
--
-- Versión: 2.0
-- Fecha: 2026-02-16
-- =============================================

-- Eliminar funciones anteriores (diferentes firmas)
DROP FUNCTION IF EXISTS fun_toggle_bus_status(VARCHAR, BOOLEAN, INTEGER);
DROP FUNCTION IF EXISTS fun_toggle_bus_status(tab_buses.plate_number%TYPE, BOOLEAN, tab_buses.user_update%TYPE);

CREATE OR REPLACE FUNCTION fun_toggle_bus_status(
  wplate_number  tab_buses.plate_number%TYPE,
  wis_active     BOOLEAN,
  wuser_update   tab_buses.user_update%TYPE,
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
  v_updater_exists   BOOLEAN;
  v_bus_exists       BOOLEAN;
  v_current_status   BOOLEAN;
  v_has_active_assignment BOOLEAN;
  
  -- Variables para información del bus
  v_plate_clean      tab_buses.plate_number%TYPE;
  v_amb_code         tab_buses.amb_code%TYPE;
  v_assigned_driver  tab_users.id_user%TYPE;
  v_driver_name      tab_users.full_name%TYPE;
  
  -- Variables para UPDATE
  v_rows_affected    INTEGER;

BEGIN
  -- ==========================================
  -- 2. INICIALIZACIÓN
  -- ==========================================
  
  success := FALSE;
  msg := '';
  error_code := NULL;
  
  -- Normalizar placa una sola vez
  v_plate_clean := UPPER(TRIM(wplate_number));
  
  RAISE NOTICE '[fun_toggle_bus_status] Iniciando cambio de estado: Placa=%, Nuevo estado=%', 
               v_plate_clean, wis_active;
  
  -- ==========================================
  -- 3. VALIDAR USUARIO QUE HACE LA ACTUALIZACIÓN
  -- ==========================================
  
  SELECT EXISTS(
    SELECT 1 FROM tab_users 
    WHERE id_user = wuser_update AND is_active = TRUE
  ) INTO v_updater_exists;
  
  IF NOT v_updater_exists THEN
    msg := 'El usuario que intenta actualizar no existe o está inactivo (ID: ' || wuser_update || ')';
    error_code := 'USER_UPDATE_NOT_FOUND';
    RAISE NOTICE '[fun_toggle_bus_status] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 4. VALIDAR FORMATO DE PLACA
  -- ==========================================
  
  IF v_plate_clean !~ '^[A-Z]{3}[0-9]{3}$' THEN
    msg := 'Formato de placa inválido: "' || v_plate_clean || '". Debe ser 3 letras + 3 números (ej: ABC123)';
    error_code := 'PLATE_INVALID_FORMAT';
    RAISE NOTICE '[fun_toggle_bus_status] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 5. VALIDAR QUE EL BUS EXISTE
  -- ==========================================
  
  SELECT 
    is_active,
    amb_code
  INTO 
    v_current_status,
    v_amb_code
  FROM tab_buses 
  WHERE plate_number = v_plate_clean;
  
  IF NOT FOUND THEN
    msg := 'El bus con placa ' || v_plate_clean || ' no existe';
    error_code := 'BUS_NOT_FOUND';
    RAISE NOTICE '[fun_toggle_bus_status] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 6. VALIDAR QUE EL ESTADO SEA DIFERENTE
  -- ==========================================
  
  IF v_current_status = wis_active THEN
    msg := 'El bus ' || v_plate_clean || ' (' || v_amb_code || ') ya está ' || 
           CASE WHEN wis_active THEN 'activo' ELSE 'inactivo' END;
    error_code := 'BUS_SAME_STATUS';
    RAISE NOTICE '[fun_toggle_bus_status] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 7. VALIDAR ASIGNACIONES ACTIVAS (solo al DESACTIVAR)
  -- ==========================================
  
  IF wis_active = FALSE THEN
    -- Verificar si tiene conductor asignado actualmente
    SELECT EXISTS(
      SELECT 1 FROM tab_bus_assignments
      WHERE plate_number = v_plate_clean 
        AND unassigned_at IS NULL  -- Asignación activa
    ), 
    (SELECT id_user FROM tab_bus_assignments 
     WHERE plate_number = v_plate_clean AND unassigned_at IS NULL LIMIT 1)
    INTO v_has_active_assignment, v_assigned_driver;
    
    IF v_has_active_assignment THEN
      -- Obtener nombre del conductor
      SELECT full_name INTO v_driver_name
      FROM tab_users
      WHERE id_user = v_assigned_driver;
      
      msg := 'No se puede desactivar el bus ' || v_plate_clean || ' (' || v_amb_code || '). ' ||
             'Tiene un conductor asignado activamente: ' || v_driver_name || ' (ID: ' || v_assigned_driver || '). ' ||
             'Debe desasignar el conductor primero';
      error_code := 'BUS_HAS_ACTIVE_ASSIGNMENT';
      RAISE NOTICE '[fun_toggle_bus_status] ERROR: %', msg;
      RETURN;
    END IF;
  END IF;
  
  -- ==========================================
  -- 8. ACTUALIZAR ESTADO DEL BUS
  -- ==========================================
  
  BEGIN
    UPDATE tab_buses 
    SET is_active = wis_active,
        updated_at = NOW(),
        user_update = wuser_update
    WHERE plate_number = v_plate_clean;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    IF v_rows_affected = 0 THEN
      msg := 'No se pudo actualizar el estado del bus (Placa: ' || v_plate_clean || ')';
      error_code := 'BUS_UPDATE_FAILED';
      RAISE NOTICE '[fun_toggle_bus_status] ERROR: %', msg;
      RETURN;
    END IF;
    
    RAISE NOTICE '[fun_toggle_bus_status] Bus actualizado: Placa=%, Estado=%', v_plate_clean, wis_active;
    
  EXCEPTION
    WHEN foreign_key_violation THEN
      msg := 'Error: Violación de clave foránea al actualizar el bus (user_update inválido: ' || 
             wuser_update || ')';
      error_code := 'BUS_UPDATE_FK_VIOLATION';
      RAISE NOTICE '[fun_toggle_bus_status] ERROR: %', msg;
      RETURN;
      
    WHEN check_violation THEN
      msg := 'Error: Violación de restricción CHECK al actualizar el bus';
      error_code := 'BUS_UPDATE_CHECK_VIOLATION';
      RAISE NOTICE '[fun_toggle_bus_status] ERROR: %', msg;
      RETURN;
      
    WHEN OTHERS THEN
      msg := 'Error inesperado al actualizar el bus: ' || SQLERRM;
      error_code := 'BUS_UPDATE_ERROR';
      RAISE NOTICE '[fun_toggle_bus_status] ERROR: %', msg;
      RETURN;
  END;
  
  -- ==========================================
  -- 9. RETORNO EXITOSO
  -- ==========================================
  
  success := TRUE;
  msg := 'Bus ' || CASE WHEN wis_active THEN 'activado' ELSE 'desactivado' END || 
         ' exitosamente: ' || v_plate_clean || ' (' || v_amb_code || ')';
  error_code := NULL;
  
  RAISE NOTICE '[fun_toggle_bus_status] Éxito: Bus % cambiado a estado % por usuario %', 
               v_plate_clean, wis_active, wuser_update;
  
END;
$$;

-- =============================================
-- COMENTARIOS FINALES
-- =============================================

COMMENT ON FUNCTION fun_toggle_bus_status IS 
'v2.0 - Activa o desactiva un bus en el sistema. Cambia is_active entre TRUE/FALSE.
Validaciones: usuario que actualiza existe y activo, bus existe, formato de placa válido, 
estado diferente al actual, no tiene asignaciones activas (al desactivar).
Retorna: success (BOOLEAN), msg (VARCHAR), error_code (VARCHAR).
Códigos de error: USER_UPDATE_NOT_FOUND, PLATE_INVALID_FORMAT, BUS_NOT_FOUND, BUS_SAME_STATUS, 
BUS_HAS_ACTIVE_ASSIGNMENT, BUS_UPDATE_FAILED, BUS_UPDATE_FK_VIOLATION, BUS_UPDATE_CHECK_VIOLATION, 
BUS_UPDATE_ERROR.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================

/*
-- Ejemplo 1: Desactivar un bus (sin asignaciones activas)
SELECT * FROM fun_toggle_bus_status(
  'ABC123',  -- Placa del bus
  FALSE,     -- Desactivar
  1          -- ID del usuario admin
);

-- Resultado exitoso:
-- success | msg                                     | error_code
-- TRUE    | Bus desactivado exitosamente: ABC12...  | NULL


-- Ejemplo 2: Activar un bus
SELECT * FROM fun_toggle_bus_status(
  'ABC123',
  TRUE,      -- Activar
  1
);

-- Resultado exitoso:
-- success | msg                                     | error_code
-- TRUE    | Bus activado exitosamente: ABC123 (...  | NULL


-- Ejemplo 3: ERROR - El bus ya está en ese estado
SELECT * FROM fun_toggle_bus_status(
  'ABC123',
  TRUE,      -- Pero ya está activo
  1
);

-- Resultado:
-- success | msg                                  | error_code
-- FALSE   | El bus ABC123 (AMB-0001) ya está ... | BUS_SAME_STATUS


-- Ejemplo 4: ERROR - Desactivar bus con conductor asignado
SELECT * FROM fun_toggle_bus_status(
  'XYZ789',  -- Bus con conductor asignado
  FALSE,     -- Intentar desactivar
  1
);

-- Resultado:
-- success | msg                                     | error_code
-- FALSE   | No se puede desactivar el bus XYZ78...  | BUS_HAS_ACTIVE_ASSIGNMENT


-- Ejemplo 5: ERROR - Formato de placa inválido
SELECT * FROM fun_toggle_bus_status(
  'ABC12',   -- Falta un dígito
  FALSE,
  1
);

-- Resultado:
-- success | msg                                  | error_code
-- FALSE   | Formato de placa inválido: "ABC1...  | PLATE_INVALID_FORMAT


-- Ejemplo 6: ERROR - Bus no existe
SELECT * FROM fun_toggle_bus_status(
  'ZZZ999',  -- Bus inexistente
  FALSE,
  1
);

-- Resultado:
-- success | msg                              | error_code
-- FALSE   | El bus con placa ZZZ999 no ex... | BUS_NOT_FOUND


-- Ejemplo 7: ERROR - Usuario que actualiza no existe
SELECT * FROM fun_toggle_bus_status(
  'ABC123',
  FALSE,
  999999     -- Usuario inexistente
);

-- Resultado:
-- success | msg                                  | error_code
-- FALSE   | El usuario que intenta actualiza...  | USER_UPDATE_NOT_FOUND


-- Ejemplo 8: Verificar el cambio de estado
SELECT 
  plate_number,
  amb_code,
  is_active,
  updated_at,
  user_update
FROM tab_buses
WHERE plate_number = 'ABC123';

-- Resultado:
-- plate_number | amb_code  | is_active | updated_at          | user_update
-- ABC123       | AMB-0001  | FALSE     | 2026-02-16 10:30:00 | 1


-- Ejemplo 9: Ver buses activos
SELECT 
  plate_number,
  amb_code,
  is_active,
  id_user  -- Conductor asignado (si tiene)
FROM tab_buses
WHERE is_active = TRUE
ORDER BY plate_number;


-- Ejemplo 10: Ver buses con asignaciones activas (no se pueden desactivar)
SELECT 
  b.plate_number,
  b.amb_code,
  b.is_active,
  ba.id_user AS driver_id,
  u.full_name AS driver_name
FROM tab_buses b
JOIN tab_bus_assignments ba ON b.plate_number = ba.plate_number
JOIN tab_users u ON ba.id_user = u.id_user
WHERE ba.unassigned_at IS NULL  -- Asignación activa
ORDER BY b.plate_number;

*/

-- =============================================
-- FIN DE LA FUNCIÓN fun_toggle_bus_status v2.0
-- =============================================