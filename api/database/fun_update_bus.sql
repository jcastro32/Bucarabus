-- =============================================
-- FUNCIÓN: fun_update_bus v2.0
-- =============================================
-- Descripción: Actualiza la información de un bus existente en el sistema
--              Permite actualizar campos editables (no la placa que es PK)
-- 
-- Parámetros IN:
--   wplate_number  - Placa del bus a actualizar (VARCHAR 6) - NO SE MODIFICA
--   wamb_code      - Nuevo código AMB (VARCHAR 8)
--   wid_company    - Nueva compañía (SMALLINT 1-99)
--   wcapacity      - Nueva capacidad (SMALLINT 10-999)
--   wphoto_url     - Nueva URL de foto (VARCHAR 500, opcional)
--   wsoat_exp      - Nueva fecha exp. SOAT (DATE)
--   wtechno_exp    - Nueva fecha exp. Tecnomecánica (DATE)
--   wrcc_exp       - Nueva fecha exp. RCC (DATE)
--   wrce_exp       - Nueva fecha exp. RCE (DATE)
--   wid_card_owner - Nueva cédula propietario (DECIMAL 12,0)
--   wname_owner    - Nuevo nombre propietario (VARCHAR 100)
--   wis_active     - Nuevo estado activo/inactivo (BOOLEAN)
--   wuser_update   - ID del usuario que hace la actualización (INTEGER)
--
-- Parámetros OUT:
--   success        - TRUE si el bus se actualizó exitosamente
--   msg            - Mensaje descriptivo del resultado
--   error_code     - Código de error (NULL si success = TRUE)
--
-- Uso:
--   SELECT * FROM fun_update_bus('ABC123', 'AMB-0001', 1, 50, NULL, 
--                                 '2027-01-01', '2027-01-01', '2027-01-01', '2027-01-01',
--                                 123456789, 'Juan Pérez', TRUE, 1);
--
-- Retorna: (success, msg, error_code)
--
-- Versión: 2.0
-- Fecha: 2026-02-16
-- =============================================

-- Eliminar funciones anteriores (diferentes firmas)
DROP FUNCTION IF EXISTS fun_update_bus(VARCHAR, VARCHAR, SMALLINT, SMALLINT, VARCHAR, DATE, DATE, DATE, DATE, DECIMAL, VARCHAR, BOOLEAN, INTEGER);
DROP FUNCTION IF EXISTS fun_update_bus(tab_buses.plate_number%TYPE, tab_buses.amb_code%TYPE, tab_buses.id_company%TYPE, 
                                       tab_buses.capacity%TYPE, tab_buses.photo_url%TYPE, tab_buses.soat_exp%TYPE, 
                                       tab_buses.techno_exp%TYPE, tab_buses.rcc_exp%TYPE, tab_buses.rce_exp%TYPE, 
                                       tab_buses.id_card_owner%TYPE, tab_buses.name_owner%TYPE, tab_buses.is_active%TYPE, 
                                       tab_buses.user_update%TYPE);

CREATE OR REPLACE FUNCTION fun_update_bus(
  wplate_number  tab_buses.plate_number%TYPE,
  wamb_code      tab_buses.amb_code%TYPE,
  wid_company    tab_buses.id_company%TYPE,
  wcapacity      tab_buses.capacity%TYPE,
  wphoto_url     tab_buses.photo_url%TYPE,
  wsoat_exp      tab_buses.soat_exp%TYPE,
  wtechno_exp    tab_buses.techno_exp%TYPE,
  wrcc_exp       tab_buses.rcc_exp%TYPE,
  wrce_exp       tab_buses.rce_exp%TYPE,
  wid_card_owner tab_buses.id_card_owner%TYPE,
  wname_owner    tab_buses.name_owner%TYPE,
  wis_active     tab_buses.is_active%TYPE,
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
  v_amb_duplicate    BOOLEAN;
  
  -- Variables para normalización
  v_plate_clean      tab_buses.plate_number%TYPE;
  v_amb_clean        tab_buses.amb_code%TYPE;
  v_name_clean       tab_buses.name_owner%TYPE;
  v_photo_clean      tab_buses.photo_url%TYPE;
  
  -- Variables para información del bus
  v_current_amb      tab_buses.amb_code%TYPE;
  v_current_status   tab_buses.is_active%TYPE;
  
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
  
  RAISE NOTICE '[fun_update_bus] Iniciando actualización: Placa=%', v_plate_clean;
  
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
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 4. VALIDAR FORMATO DE PLACA
  -- ==========================================
  
  IF v_plate_clean !~ '^[A-Z]{3}[0-9]{3}$' THEN
    msg := 'Formato de placa inválido: "' || v_plate_clean || '". Debe ser 3 letras + 3 números (ej: ABC123)';
    error_code := 'PLATE_INVALID_FORMAT';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 5. VALIDAR QUE EL BUS EXISTE
  -- ==========================================
  
  SELECT 
    amb_code,
    is_active
  INTO 
    v_current_amb,
    v_current_status
  FROM tab_buses 
  WHERE plate_number = v_plate_clean;
  
  IF NOT FOUND THEN
    msg := 'El bus con placa ' || v_plate_clean || ' no existe';
    error_code := 'BUS_NOT_FOUND';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- NOTA: Se permite actualizar buses inactivos (a diferencia de la versión anterior)
  -- Esto es útil para reactivar buses o actualizar información histórica
  
  -- ==========================================
  -- 6. VALIDAR CÓDIGO AMB
  -- ==========================================
  
  -- 6.1. Validar NULL/vacío
  IF wamb_code IS NULL OR TRIM(wamb_code) = '' THEN
    msg := 'El código AMB es obligatorio';
    error_code := 'AMB_CODE_NULL_EMPTY';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- 6.2. Normalizar
  v_amb_clean := UPPER(TRIM(wamb_code));
  
  -- 6.3. Validar formato (AMB-#### exactamente 4 dígitos)
  IF v_amb_clean !~ '^AMB-[0-9]{4}$' THEN
    msg := 'Formato de código AMB inválido: "' || v_amb_clean || '". Debe ser AMB-#### con exactamente 4 dígitos (ej: AMB-0001)';
    error_code := 'AMB_CODE_INVALID_FORMAT';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- 6.4. Validar que no esté duplicado (excepto para el mismo bus)
  SELECT EXISTS(
    SELECT 1 FROM tab_buses 
    WHERE amb_code = v_amb_clean 
      AND plate_number != v_plate_clean
  ) INTO v_amb_duplicate;
  
  IF v_amb_duplicate THEN
    msg := 'El código AMB ' || v_amb_clean || ' ya está en uso por otro bus';
    error_code := 'AMB_CODE_DUPLICATE';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 7. VALIDAR COMPAÑÍA
  -- ==========================================
  
  IF wid_company IS NULL THEN
    msg := 'El ID de compañía es obligatorio';
    error_code := 'COMPANY_NULL';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- Validar rango 1-99 (según esquema actualizado)
  IF wid_company < 1 OR wid_company > 99 THEN
    msg := 'Compañía inválida: ' || wid_company || '. Debe estar entre 1 y 99';
    error_code := 'COMPANY_INVALID_RANGE';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 8. VALIDAR CAPACIDAD
  -- ==========================================
  
  IF wcapacity IS NULL THEN
    msg := 'La capacidad es obligatoria';
    error_code := 'CAPACITY_NULL';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  IF wcapacity < 10 OR wcapacity > 999 THEN
    msg := 'La capacidad debe estar entre 10 y 999 pasajeros. Recibido: ' || wcapacity;
    error_code := 'CAPACITY_OUT_OF_RANGE';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 9. VALIDAR FECHAS DE EXPIRACIÓN
  -- ==========================================
  
  -- 9.1. SOAT
  IF wsoat_exp IS NULL THEN
    msg := 'La fecha de expiración del SOAT es obligatoria';
    error_code := 'SOAT_EXP_NULL';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  IF wsoat_exp <= CURRENT_DATE THEN
    msg := 'La fecha de expiración del SOAT debe ser posterior a hoy. Recibido: ' || wsoat_exp;
    error_code := 'SOAT_EXP_PAST';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- 9.2. Tecnomecánica
  IF wtechno_exp IS NULL THEN
    msg := 'La fecha de expiración de la Tecnomecánica es obligatoria';
    error_code := 'TECHNO_EXP_NULL';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  IF wtechno_exp <= CURRENT_DATE THEN
    msg := 'La fecha de expiración de la Tecnomecánica debe ser posterior a hoy. Recibido: ' || wtechno_exp;
    error_code := 'TECHNO_EXP_PAST';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- 9.3. RCC
  IF wrcc_exp IS NULL THEN
    msg := 'La fecha de expiración del RCC es obligatoria';
    error_code := 'RCC_EXP_NULL';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  IF wrcc_exp <= CURRENT_DATE THEN
    msg := 'La fecha de expiración del RCC debe ser posterior a hoy. Recibido: ' || wrcc_exp;
    error_code := 'RCC_EXP_PAST';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- 9.4. RCE
  IF wrce_exp IS NULL THEN
    msg := 'La fecha de expiración del RCE es obligatoria';
    error_code := 'RCE_EXP_NULL';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  IF wrce_exp <= CURRENT_DATE THEN
    msg := 'La fecha de expiración del RCE debe ser posterior a hoy. Recibido: ' || wrce_exp;
    error_code := 'RCE_EXP_PAST';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 10. VALIDAR PROPIETARIO
  -- ==========================================
  
  -- 10.1. ID de cédula
  IF wid_card_owner IS NULL THEN
    msg := 'La cédula del propietario es obligatoria';
    error_code := 'OWNER_ID_NULL';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  IF wid_card_owner <= 0 THEN
    msg := 'La cédula del propietario debe ser mayor a cero. Recibido: ' || wid_card_owner;
    error_code := 'OWNER_ID_INVALID';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- 10.2. Nombre del propietario
  IF wname_owner IS NULL OR TRIM(wname_owner) = '' THEN
    msg := 'El nombre del propietario es obligatorio';
    error_code := 'OWNER_NAME_NULL_EMPTY';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  v_name_clean := TRIM(wname_owner);
  
  IF LENGTH(v_name_clean) < 3 THEN
    msg := 'El nombre del propietario debe tener al menos 3 caracteres. Recibido: "' || v_name_clean || '"';
    error_code := 'OWNER_NAME_TOO_SHORT';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  IF LENGTH(v_name_clean) > 100 THEN
    msg := 'El nombre del propietario no puede exceder 100 caracteres. Recibido: ' || LENGTH(v_name_clean) || ' caracteres';
    error_code := 'OWNER_NAME_TOO_LONG';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 11. VALIDAR Y NORMALIZAR PHOTO_URL (OPCIONAL)
  -- ==========================================
  
  IF wphoto_url IS NOT NULL AND TRIM(wphoto_url) != '' THEN
    v_photo_clean := TRIM(wphoto_url);
    
    IF LENGTH(v_photo_clean) > 500 THEN
      msg := 'La URL de la foto no puede exceder 500 caracteres. Recibido: ' || LENGTH(v_photo_clean) || ' caracteres';
      error_code := 'PHOTO_URL_TOO_LONG';
      RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
      RETURN;
    END IF;
  ELSE
    v_photo_clean := NULL;
  END IF;
  
  -- ==========================================
  -- 12. VALIDAR ESTADO (is_active)
  -- ==========================================
  
  IF wis_active IS NULL THEN
    msg := 'El estado activo/inactivo es obligatorio';
    error_code := 'IS_ACTIVE_NULL';
    RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 13. ACTUALIZAR BUS
  -- ==========================================
  
  BEGIN
    UPDATE tab_buses 
    SET amb_code = v_amb_clean,
        id_company = wid_company,
        capacity = wcapacity,
        photo_url = v_photo_clean,
        soat_exp = wsoat_exp,
        techno_exp = wtechno_exp,
        rcc_exp = wrcc_exp,
        rce_exp = wrce_exp,
        id_card_owner = wid_card_owner,
        name_owner = v_name_clean,
        is_active = wis_active,
        updated_at = NOW(),
        user_update = wuser_update
    WHERE plate_number = v_plate_clean;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    IF v_rows_affected = 0 THEN
      msg := 'No se pudo actualizar el bus (Placa: ' || v_plate_clean || ')';
      error_code := 'BUS_UPDATE_FAILED';
      RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
      RETURN;
    END IF;
    
    RAISE NOTICE '[fun_update_bus] Bus actualizado: Placa=%', v_plate_clean;
    
  EXCEPTION
    WHEN unique_violation THEN
      msg := 'Error: Código AMB duplicado. El código ' || v_amb_clean || ' ya está en uso';
      error_code := 'BUS_UPDATE_UNIQUE_VIOLATION';
      RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
      RETURN;
      
    WHEN not_null_violation THEN
      msg := 'Error: Falta un campo obligatorio al actualizar el bus';
      error_code := 'BUS_UPDATE_NOT_NULL_VIOLATION';
      RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
      RETURN;
      
    WHEN foreign_key_violation THEN
      msg := 'Error: Violación de clave foránea (user_update inválido: ' || wuser_update || ')';
      error_code := 'BUS_UPDATE_FK_VIOLATION';
      RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
      RETURN;
      
    WHEN check_violation THEN
      msg := 'Error: Violación de restricción CHECK (formato de placa/AMB, rango de compañía/capacidad, o fechas)';
      error_code := 'BUS_UPDATE_CHECK_VIOLATION';
      RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
      RETURN;
      
    WHEN OTHERS THEN
      msg := 'Error inesperado al actualizar el bus: ' || SQLERRM;
      error_code := 'BUS_UPDATE_ERROR';
      RAISE NOTICE '[fun_update_bus] ERROR: %', msg;
      RETURN;
  END;
  
  -- ==========================================
  -- 14. RETORNO EXITOSO
  -- ==========================================
  
  success := TRUE;
  msg := 'Bus actualizado exitosamente: ' || v_plate_clean || ' (' || v_amb_clean || ')';
  
  -- Agregar información adicional si cambió el estado
  IF v_current_status != wis_active THEN
    msg := msg || '. Estado cambiado a: ' || CASE WHEN wis_active THEN 'ACTIVO' ELSE 'INACTIVO' END;
  END IF;
  
  error_code := NULL;
  
  RAISE NOTICE '[fun_update_bus] Éxito: Bus % actualizado por usuario %', v_plate_clean, wuser_update;
  
END;
$$;

-- =============================================
-- COMENTARIOS FINALES
-- =============================================

COMMENT ON FUNCTION fun_update_bus IS 
'v2.0 - Actualiza la información de un bus existente. Permite modificar todos los campos excepto la placa (PK).
Validaciones: usuario que actualiza existe y activo, bus existe, formato placa/AMB válidos, 
código AMB no duplicado, compañía 1-99, capacidad 10-999, fechas futuras, propietario válido.
Retorna: success (BOOLEAN), msg (VARCHAR), error_code (VARCHAR).
Códigos de error: USER_UPDATE_NOT_FOUND, PLATE_INVALID_FORMAT, BUS_NOT_FOUND, AMB_CODE_NULL_EMPTY, 
AMB_CODE_INVALID_FORMAT, AMB_CODE_DUPLICATE, COMPANY_NULL, COMPANY_INVALID_RANGE, CAPACITY_NULL, 
CAPACITY_OUT_OF_RANGE, SOAT_EXP_NULL, SOAT_EXP_PAST, TECHNO_EXP_NULL, TECHNO_EXP_PAST, RCC_EXP_NULL, 
RCC_EXP_PAST, RCE_EXP_NULL, RCE_EXP_PAST, OWNER_ID_NULL, OWNER_ID_INVALID, OWNER_NAME_NULL_EMPTY, 
OWNER_NAME_TOO_SHORT, OWNER_NAME_TOO_LONG, PHOTO_URL_TOO_LONG, IS_ACTIVE_NULL, BUS_UPDATE_FAILED, 
BUS_UPDATE_UNIQUE_VIOLATION, BUS_UPDATE_NOT_NULL_VIOLATION, BUS_UPDATE_FK_VIOLATION, 
BUS_UPDATE_CHECK_VIOLATION, BUS_UPDATE_ERROR.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================

/*
-- Ejemplo 1: Actualizar bus completo
SELECT * FROM fun_update_bus(
  'ABC123',          -- plate_number (NO se modifica, es identificador)
  'AMB-0999',        -- Nuevo código AMB
  2,                 -- Nueva compañía
  45,                -- Nueva capacidad
  'https://example.com/bus_abc123_new.jpg',  -- Nueva foto
  '2027-06-01',      -- Nueva exp. SOAT
  '2027-07-01',      -- Nueva exp. Tecnomecánica
  '2027-08-01',      -- Nueva exp. RCC
  '2027-09-01',      -- Nueva exp. RCE
  987654321,         -- Nueva cédula propietario
  'María García',    -- Nuevo nombre propietario
  TRUE,              -- Estado activo
  1                  -- ID usuario que actualiza
);

-- Resultado exitoso:
-- success | msg                                     | error_code
-- TRUE    | Bus actualizado exitosamente: ABC12...  | NULL


-- Ejemplo 2: ERROR - Código AMB duplicado
SELECT * FROM fun_update_bus(
  'ABC123',
  'AMB-0001',  -- Código ya usado por otro bus
  1, 50, NULL,
  '2027-01-01', '2027-01-01', '2027-01-01', '2027-01-01',
  123456789, 'Juan Pérez', TRUE, 1
);

-- Resultado:
-- success | msg                                  | error_code
-- FALSE   | El código AMB AMB-0001 ya está en... | AMB_CODE_DUPLICATE


-- Ejemplo 3: ERROR - Formato AMB inválido
SELECT * FROM fun_update_bus(
  'ABC123',
  'AMB-12',    -- Solo 2 dígitos, debe ser 4
  1, 50, NULL,
  '2027-01-01', '2027-01-01', '2027-01-01', '2027-01-01',
  123456789, 'Juan Pérez', TRUE, 1
);

-- Resultado:
-- success | msg                                  | error_code
-- FALSE   | Formato de código AMB inválido: ...  | AMB_CODE_INVALID_FORMAT


-- Ejemplo 4: ERROR - Compañía fuera de rango
SELECT * FROM fun_update_bus(
  'ABC123',
  'AMB-0999',
  100,         -- Fuera del rango 1-99
  50, NULL,
  '2027-01-01', '2027-01-01', '2027-01-01', '2027-01-01',
  123456789, 'Juan Pérez', TRUE, 1
);

-- Resultado:
-- success | msg                                  | error_code
-- FALSE   | Compañía inválida: 100. Debe est...  | COMPANY_INVALID_RANGE


-- Ejemplo 5: ERROR - Fecha de SOAT vencida
SELECT * FROM fun_update_bus(
  'ABC123',
  'AMB-0999',
  1, 50, NULL,
  '2020-01-01',  -- Fecha pasada
  '2027-01-01', '2027-01-01', '2027-01-01',
  123456789, 'Juan Pérez', TRUE, 1
);

-- Resultado:
-- success | msg                                  | error_code
-- FALSE   | La fecha de expiración del SOAT d... | SOAT_EXP_PAST


-- Ejemplo 6: Desactivar un bus
SELECT * FROM fun_update_bus(
  'ABC123',
  'AMB-0999',
  1, 50, NULL,
  '2027-01-01', '2027-01-01', '2027-01-01', '2027-01-01',
  123456789, 'Juan Pérez',
  FALSE,         -- Desactivar bus
  1
);

-- Resultado exitoso:
-- success | msg                                     | error_code
-- TRUE    | Bus actualizado exitosamente: ABC12...  | NULL
--           Estado cambiado a: INACTIVO


-- Ejemplo 7: ERROR - Usuario que actualiza no existe
SELECT * FROM fun_update_bus(
  'ABC123',
  'AMB-0999',
  1, 50, NULL,
  '2027-01-01', '2027-01-01', '2027-01-01', '2027-01-01',
  123456789, 'Juan Pérez', TRUE,
  999999     -- Usuario inexistente
);

-- Resultado:
-- success | msg                                  | error_code
-- FALSE   | El usuario que intenta actualizar... | USER_UPDATE_NOT_FOUND


-- Ejemplo 8: Verificar la actualización
SELECT 
  plate_number,
  amb_code,
  id_company,
  capacity,
  is_active,
  name_owner,
  updated_at,
  user_update
FROM tab_buses
WHERE plate_number = 'ABC123';

-- Resultado:
-- plate_number | amb_code  | id_company | capacity | is_active | name_owner    | updated_at          | user_update
-- ABC123       | AMB-0999  | 2          | 45       | TRUE      | María García  | 2026-02-16 10:30:00 | 1

*/

-- =============================================
-- FIN DE LA FUNCIÓN fun_update_bus v2.0
-- =============================================
