-- =============================================
-- Función: fun_create_bus
-- Descripción: Crear nuevo bus en el sistema
-- =============================================
-- Version: 2.0 (Actualizada para bd_bucarabus v2.0)
-- Cambios:
-- - Validación de compañías 1-99 (antes 1-4)
-- - Validación de formato AMB (AMB-#### exactamente 4 dígitos)
-- - Validación de usuario creador
-- - Campos de auditoría INTEGER (FK a tab_users)
-- - Normalización de photo_url
-- - Tipos de datos actualizados (SMALLINT)
-- =============================================

CREATE OR REPLACE FUNCTION fun_create_bus(
    wplate_number      tab_buses.plate_number%TYPE,
    wamb_code          tab_buses.amb_code%TYPE,
    wid_company        tab_buses.id_company%TYPE,
    wcapacity          tab_buses.capacity%TYPE,
    wphoto_url         tab_buses.photo_url%TYPE,
    wsoat_exp          tab_buses.soat_exp%TYPE,
    wtechno_exp        tab_buses.techno_exp%TYPE,
    wrcc_exp           tab_buses.rcc_exp%TYPE,
    wrce_exp           tab_buses.rce_exp%TYPE,
    wid_card_owner     tab_buses.id_card_owner%TYPE,
    wname_owner        tab_buses.name_owner%TYPE,
    wuser_create       tab_buses.user_create%TYPE,
    OUT success        BOOLEAN,
    OUT msg            VARCHAR,
    OUT error_code     VARCHAR
) AS $$

DECLARE
  wexists_plate      BOOLEAN;
  wexists_amb        BOOLEAN;
  wexists_user       BOOLEAN;
  v_normalized_plate VARCHAR(6);
  v_normalized_amb   VARCHAR(8);
  v_normalized_name  VARCHAR(100);
  v_normalized_photo VARCHAR(500);
BEGIN
    -- Inicializar valores de salida
    success := FALSE;
    msg := '';
    error_code := NULL;

    -- ====================================
    -- 1. VALIDACIONES DE CAMPOS OBLIGATORIOS
    -- ====================================

    -- Placa
    IF wplate_number IS NULL OR TRIM(wplate_number) = '' THEN
        msg := 'La placa es obligatoria';
        error_code := 'INVALID_PLATE';
        RETURN;
    END IF;

    v_normalized_plate := UPPER(TRIM(wplate_number));

    -- Validar formato de placa (ABC123)
    IF v_normalized_plate !~ '^[A-Z]{3}[0-9]{3}$' THEN
        msg := 'Formato de placa inválido. Debe ser 3 letras mayúsculas + 3 números (ej: ABC123)';
        error_code := 'INVALID_PLATE_FORMAT';
        RETURN;
    END IF;

    -- Código AMB
    IF wamb_code IS NULL OR TRIM(wamb_code) = '' THEN
        msg := 'El código AMB es obligatorio';
        error_code := 'INVALID_AMB_CODE';
        RETURN;
    END IF;

    v_normalized_amb := UPPER(TRIM(wamb_code));

    -- ✅ NUEVO: Validar formato AMB (AMB-#### exactamente 4 dígitos)
    IF v_normalized_amb !~ '^AMB-[0-9]{4}$' THEN
        msg := 'Formato de código AMB inválido. Debe ser AMB-#### con exactamente 4 dígitos (ej: AMB-0001, AMB-0379)';
        error_code := 'INVALID_AMB_FORMAT';
        RETURN;
    END IF;

    -- Compañía (actualizado a rango 1-99)
    IF wid_company IS NULL THEN
        msg := 'El ID de compañía es obligatorio';
        error_code := 'INVALID_COMPANY';
        RETURN;
    END IF;

    -- ✅ CORREGIDO: Validar rango 1-99 (antes era solo 1-4)
    IF wid_company < 1 OR wid_company > 99 THEN
        msg := 'Compañía inválida. Debe estar entre 1 y 99';
        error_code := 'INVALID_COMPANY_RANGE';
        RETURN;
    END IF;

    -- Capacidad
    IF wcapacity IS NULL OR wcapacity < 10 OR wcapacity > 999 THEN
        msg := 'La capacidad debe estar entre 10 y 999 pasajeros';
        error_code := 'INVALID_CAPACITY';
        RETURN;
    END IF;

    -- Validar fechas de expiración (deben ser futuras)
    IF wsoat_exp IS NULL OR wsoat_exp <= CURRENT_DATE THEN
        msg := 'La fecha de expiración del SOAT debe ser posterior a hoy';
        error_code := 'INVALID_SOAT_EXP';
        RETURN;
    END IF;

    IF wtechno_exp IS NULL OR wtechno_exp <= CURRENT_DATE THEN
        msg := 'La fecha de expiración de la Tecnomecánica debe ser posterior a hoy';
        error_code := 'INVALID_TECHNO_EXP';
        RETURN;
    END IF;

    IF wrcc_exp IS NULL OR wrcc_exp <= CURRENT_DATE THEN
        msg := 'La fecha de expiración del RCC debe ser posterior a hoy';
        error_code := 'INVALID_RCC_EXP';
        RETURN;
    END IF;

    IF wrce_exp IS NULL OR wrce_exp <= CURRENT_DATE THEN
        msg := 'La fecha de expiración del RCE debe ser posterior a hoy';
        error_code := 'INVALID_RCE_EXP';
        RETURN;
    END IF;

    -- Propietario
    IF wid_card_owner IS NULL OR wid_card_owner <= 0 THEN
        msg := 'La cédula del propietario es obligatoria y debe ser mayor a cero';
        error_code := 'INVALID_OWNER_ID';
        RETURN;
    END IF;

    IF wname_owner IS NULL OR TRIM(wname_owner) = '' THEN
        msg := 'El nombre del propietario es obligatorio';
        error_code := 'INVALID_OWNER_NAME';
        RETURN;
    END IF;

    v_normalized_name := TRIM(wname_owner);

    IF LENGTH(v_normalized_name) < 3 THEN
        msg := 'El nombre del propietario debe tener al menos 3 caracteres';
        error_code := 'INVALID_OWNER_NAME_LENGTH';
        RETURN;
    END IF;

    -- ✅ NUEVO: Validar longitud máxima
    IF LENGTH(v_normalized_name) > 100 THEN
        msg := 'El nombre del propietario no puede exceder 100 caracteres';
        error_code := 'INVALID_OWNER_NAME_TOO_LONG';
        RETURN;
    END IF;

    -- ✅ NUEVO: Validar usuario creador
    IF wuser_create IS NULL THEN
        msg := 'El usuario creador es obligatorio';
        error_code := 'INVALID_USER_CREATE';
        RETURN;
    END IF;

    SELECT EXISTS(SELECT 1 FROM tab_users WHERE id_user = wuser_create AND is_active = TRUE)
    INTO wexists_user;

    IF NOT wexists_user THEN
        msg := 'El usuario creador no existe o está inactivo (ID: ' || wuser_create || ')';
        error_code := 'USER_CREATE_NOT_FOUND';
        RETURN;
    END IF;

    -- Normalizar photo_url (puede ser NULL)
    IF wphoto_url IS NOT NULL THEN
        v_normalized_photo := TRIM(wphoto_url);
        IF v_normalized_photo = '' THEN
            v_normalized_photo := NULL;
        END IF;
    ELSE
        v_normalized_photo := NULL;
    END IF;

    -- ====================================
    -- 2. VALIDAR DUPLICADOS
    -- ====================================
    SELECT EXISTS(SELECT 1 FROM tab_buses WHERE plate_number = v_normalized_plate) 
    INTO wexists_plate;
    
    IF wexists_plate THEN
        msg := 'La placa ' || v_normalized_plate || ' ya está registrada';
        error_code := 'DUPLICATE_PLATE';
        RETURN;
    END IF;
    
    SELECT EXISTS(SELECT 1 FROM tab_buses WHERE amb_code = v_normalized_amb) 
    INTO wexists_amb;
    
    IF wexists_amb THEN
        msg := 'El código AMB ' || v_normalized_amb || ' ya está registrado';
        error_code := 'DUPLICATE_AMB_CODE';
        RETURN;
    END IF;

    -- ====================================
    -- 3. INSERTAR BUS
    -- ====================================
    BEGIN
        -- ✅ MEJORADO: INSERT simplificado, usa DEFAULT para campos de auditoría
        INSERT INTO tab_buses (
            plate_number,
            amb_code,
            id_user,        -- Conductor (NULL al crear)
            id_company,
            capacity,
            photo_url,
            soat_exp,
            techno_exp,
            rcc_exp,
            rce_exp,
            id_card_owner,
            name_owner,
            user_create     -- Resto usa DEFAULT
        ) VALUES (
            v_normalized_plate,
            v_normalized_amb,
            NULL,           -- Sin conductor asignado inicialmente
            wid_company,
            wcapacity,
            v_normalized_photo,
            wsoat_exp,
            wtechno_exp,
            wrcc_exp,
            wrce_exp,
            wid_card_owner,
            v_normalized_name,
            wuser_create
        );
        
        success := TRUE;
        msg := 'Bus creado exitosamente: ' || v_normalized_plate || ' (AMB: ' || v_normalized_amb || ')';
        error_code := NULL;
        
        RAISE NOTICE 'Bus creado por usuario %: Placa=%, AMB=%, Compañía=%', 
                     wuser_create, v_normalized_plate, v_normalized_amb, wid_company;
 
    EXCEPTION
        WHEN unique_violation THEN
            success := FALSE;
            msg := 'Violación de unicidad: la placa o código AMB ya existe';
            error_code := 'DUPLICATE_ENTRY';
            
        WHEN not_null_violation THEN
            success := FALSE;
            msg := 'Error: falta un campo obligatorio';
            error_code := 'MISSING_REQUIRED_FIELD';
            
        WHEN check_violation THEN
            success := FALSE;
            msg := 'Error: restricción violada (formato, rango o validación)';
            error_code := 'CONSTRAINT_VIOLATION';
            
        WHEN foreign_key_violation THEN
            success := FALSE;
            msg := 'Error: el usuario creador no existe en la base de datos';
            error_code := 'FOREIGN_KEY_VIOLATION';
            
        WHEN OTHERS THEN
            success := FALSE;
            msg := 'Error inesperado: ' || SQLERRM;
            error_code := 'UNEXPECTED_ERROR';
            RAISE WARNING 'Error en fun_create_bus: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
    END;

END;

$$ LANGUAGE plpgsql;
