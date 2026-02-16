-- =============================================
-- BucaraBUS - Función: Actualizar Conductor
-- =============================================
-- Versión: 2.0
-- Fecha: Febrero 2025
-- Descripción: Actualiza datos de un conductor (usuario + detalles)
-- Arquitectura: tab_users + tab_driver_details
-- =============================================

-- Eliminar versiones anteriores
DROP FUNCTION IF EXISTS fun_update_driver(INTEGER, VARCHAR, VARCHAR, VARCHAR, BOOLEAN, VARCHAR, DATE, TEXT, VARCHAR, BOOLEAN, VARCHAR);
DROP FUNCTION IF EXISTS fun_update_driver(INTEGER, VARCHAR, VARCHAR, VARCHAR, DATE, TEXT, VARCHAR, BOOLEAN, INTEGER);

-- =============================================
-- Función: fun_update_driver v2.0
-- =============================================
CREATE OR REPLACE FUNCTION fun_update_driver(
    -- Identificador del conductor a actualizar
    wid_user            tab_users.id_user%TYPE,
    
    -- Auditoría
    wuser_update        tab_users.user_update%TYPE,
    
    -- Datos del usuario (opcionales)
    wfull_name          tab_users.full_name%TYPE DEFAULT NULL,
    wavatar_url         tab_users.avatar_url%TYPE DEFAULT NULL,
    
    -- Datos del conductor (opcionales)
    wcel                tab_driver_details.cel%TYPE DEFAULT NULL,
    wlicense_cat        tab_driver_details.license_cat%TYPE DEFAULT NULL,
    wlicense_exp        tab_driver_details.license_exp%TYPE DEFAULT NULL,
    waddress_driver     tab_driver_details.address_driver%TYPE DEFAULT NULL,
    wavailable          tab_driver_details.available%TYPE DEFAULT NULL,
    
    -- Parámetros de salida
    OUT success         BOOLEAN,
    OUT msg             VARCHAR,
    OUT error_code      VARCHAR,
    OUT id_user         INTEGER,
    OUT id_card         DECIMAL
)
LANGUAGE plpgsql AS $$

DECLARE
    v_name_clean        VARCHAR(100);
    v_cel_clean         VARCHAR(15);
    v_license_clean     VARCHAR(2);
    v_avatar_clean      VARCHAR(500);
    v_address_clean     TEXT;
    v_updater_exists    BOOLEAN;
    v_driver_exists     BOOLEAN;
    v_is_driver         BOOLEAN;
    v_driver_active     BOOLEAN;
    v_driver_card       DECIMAL(12,0);
    v_rows_affected     INTEGER;
    v_available_status  BOOLEAN;
    
BEGIN
    -- ====================================
    -- 1. INICIALIZACIÓN
    -- ====================================
    success := FALSE;
    msg := '';
    error_code := NULL;
    id_user := NULL;
    id_card := NULL;

    -- ====================================
    -- 2. VALIDACIÓN DEL USUARIO ACTUALIZADOR
    -- ====================================
    SELECT EXISTS(
        SELECT 1 
        FROM tab_users 
        WHERE tab_users.id_user = wuser_update 
          AND is_active = TRUE
    ) INTO v_updater_exists;
    
    IF NOT v_updater_exists THEN
        msg := 'El usuario actualizador no existe o está inactivo (ID: ' || wuser_update || ')';
        error_code := 'USER_UPDATE_NOT_FOUND';
        RETURN;
    END IF;

    RAISE NOTICE '[fun_update_driver] Usuario actualizador validado: %', wuser_update;

    -- ====================================
    -- 3. VALIDACIÓN DEL CONDUCTOR A ACTUALIZAR
    -- ====================================
    IF wid_user IS NULL OR wid_user <= 0 THEN
        msg := 'El ID del conductor es obligatorio y debe ser mayor que 0';
        error_code := 'DRIVER_ID_INVALID';
        RETURN;
    END IF;

    -- Verificar que el conductor existe
    SELECT EXISTS(
        SELECT 1 FROM tab_users WHERE tab_users.id_user = wid_user
    ) INTO v_driver_exists;
    
    IF NOT v_driver_exists THEN
        msg := 'El conductor con ID ' || wid_user || ' no existe';
        error_code := 'DRIVER_NOT_FOUND';
        RETURN;
    END IF;

    -- Verificar que tiene rol de conductor activo
    SELECT EXISTS(
        SELECT 1 FROM tab_user_roles 
        WHERE id_user = wid_user 
          AND id_role = 2 
          AND is_active = TRUE
    ) INTO v_is_driver;
    
    IF NOT v_is_driver THEN
        msg := 'El usuario con ID ' || wid_user || ' no es un conductor activo';
        error_code := 'NOT_A_DRIVER';
        RETURN;
    END IF;

    -- Verificar que el conductor está activo en tab_users
    SELECT is_active INTO v_driver_active
    FROM tab_users
    WHERE tab_users.id_user = wid_user;
    
    IF NOT v_driver_active THEN
        msg := 'El conductor está inactivo en el sistema (ID: ' || wid_user || ')';
        error_code := 'DRIVER_USER_INACTIVE';
        RETURN;
    END IF;

    -- Obtener cédula del conductor para retorno
    SELECT tab_driver_details.id_card INTO v_driver_card
    FROM tab_driver_details
    WHERE tab_driver_details.id_user = wid_user;
    
    IF v_driver_card IS NULL THEN
        msg := 'No se encontraron detalles del conductor para ID: ' || wid_user;
        error_code := 'DRIVER_DETAILS_NOT_FOUND';
        RETURN;
    END IF;

    RAISE NOTICE '[fun_update_driver] Conductor validado: % (Cédula: %)', wid_user, v_driver_card;

    -- ====================================
    -- 4. VALIDACIONES DE NOMBRE
    -- ====================================
    IF wfull_name IS NULL OR TRIM(wfull_name) = '' THEN
        msg := 'El nombre completo es obligatorio';
        error_code := 'NAME_NULL_EMPTY';
        RETURN;
    END IF;
    
    v_name_clean := TRIM(wfull_name);
    
    IF LENGTH(v_name_clean) < 3 THEN
        msg := 'El nombre debe tener al menos 3 caracteres';
        error_code := 'NAME_TOO_SHORT';
        RETURN;
    END IF;
    
    IF LENGTH(v_name_clean) > 100 THEN
        msg := 'El nombre excede la longitud máxima permitida (100 caracteres)';
        error_code := 'NAME_TOO_LONG';
        RETURN;
    END IF;
    
    IF v_name_clean ~ '[0-9$^&*()_+=\[\]{};:"\\|<>?]' THEN
        msg := 'El nombre contiene caracteres no permitidos';
        error_code := 'NAME_INVALID_CHARS';
        RETURN;
    END IF;

    -- ====================================
    -- 5. VALIDACIONES DE AVATAR (OPCIONAL)
    -- ====================================
    v_avatar_clean := NULL;
    
    IF wavatar_url IS NOT NULL AND TRIM(wavatar_url) != '' THEN
        v_avatar_clean := TRIM(wavatar_url);
        
        IF v_avatar_clean !~ '^https?://' THEN
            msg := 'La URL del avatar debe comenzar con http:// o https://';
            error_code := 'AVATAR_INVALID_PROTOCOL';
            RETURN;
        END IF;
        
        IF LENGTH(v_avatar_clean) > 500 THEN
            msg := 'La URL del avatar excede la longitud máxima (500 caracteres)';
            error_code := 'AVATAR_TOO_LONG';
            RETURN;
        END IF;
    END IF;

    -- ====================================
    -- 6. VALIDACIONES DE TELÉFONO
    -- ====================================
    IF wcel IS NULL OR TRIM(wcel) = '' THEN
        msg := 'El teléfono es obligatorio';
        error_code := 'PHONE_NULL_EMPTY';
        RETURN;
    END IF;
    
    v_cel_clean := TRIM(wcel);
    
    IF v_cel_clean !~ '^[0-9]{7,15}$' THEN
        msg := 'El teléfono debe contener entre 7 y 15 dígitos numéricos';
        error_code := 'PHONE_INVALID_FORMAT';
        RETURN;
    END IF;

    -- ====================================
    -- 7. VALIDACIONES DE LICENCIA
    -- ====================================
    IF wlicense_cat IS NULL OR TRIM(wlicense_cat) = '' THEN
        msg := 'La categoría de licencia es obligatoria';
        error_code := 'LICENSE_CAT_NULL';
        RETURN;
    END IF;
    
    v_license_clean := UPPER(TRIM(wlicense_cat));
    
    IF v_license_clean NOT IN ('C1', 'C2', 'C3') THEN
        msg := 'Categoría de licencia inválida "' || v_license_clean || '". Debe ser: C1, C2 o C3';
        error_code := 'LICENSE_CAT_INVALID';
        RETURN;
    END IF;
    
    IF wlicense_exp IS NULL THEN
        msg := 'La fecha de expiración de la licencia es obligatoria';
        error_code := 'LICENSE_EXP_NULL';
        RETURN;
    END IF;
    
    IF wlicense_exp <= CURRENT_DATE THEN
        msg := 'La licencia está vencida o expira hoy. Debe ser una fecha futura (después de ' || CURRENT_DATE || ')';
        error_code := 'LICENSE_EXPIRED';
        RETURN;
    END IF;

    -- ====================================
    -- 8. VALIDACIONES DE DIRECCIÓN (OPCIONAL)
    -- ====================================
    v_address_clean := NULL;
    
    IF waddress_driver IS NOT NULL AND TRIM(waddress_driver) != '' THEN
        v_address_clean := TRIM(waddress_driver);
        
        IF LENGTH(v_address_clean) > 500 THEN
            msg := 'La dirección excede la longitud máxima permitida (500 caracteres)';
            error_code := 'ADDRESS_TOO_LONG';
            RETURN;
        END IF;
    END IF;

    -- ====================================
    -- 9. VALIDACIONES DE DISPONIBILIDAD
    -- ====================================
    -- Si no se proporciona, mantener el valor actual
    IF wavailable IS NULL THEN
        SELECT available INTO v_available_status
        FROM tab_driver_details
        WHERE id_user = wid_user;
        
        IF v_available_status IS NULL THEN
            v_available_status := TRUE; -- Default si no existe
        END IF;
    ELSE
        v_available_status := wavailable;
    END IF;

    RAISE NOTICE '[fun_update_driver] Validaciones completadas para conductor: %', wid_user;

    -- ====================================
    -- 10. ACTUALIZAR DATOS DE USUARIO
    -- ====================================
    BEGIN
        UPDATE tab_users 
        SET full_name = v_name_clean,
            avatar_url = v_avatar_clean,
            updated_at = NOW(),
            user_update = wuser_update
        WHERE tab_users.id_user = wid_user;
        
        GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
        
        IF v_rows_affected = 0 THEN
            msg := 'No se pudo actualizar el usuario (ID: ' || wid_user || ')';
            error_code := 'USER_UPDATE_FAILED';
            RETURN;
        END IF;
        
        RAISE NOTICE '[fun_update_driver] Usuario actualizado: % (% fila afectada)', wid_user, v_rows_affected;
        
    EXCEPTION
        WHEN not_null_violation THEN
            msg := 'Error de campo obligatorio al actualizar usuario: ' || SQLERRM;
            error_code := 'USER_UPDATE_NOT_NULL_VIOLATION';
            RETURN;
        WHEN check_violation THEN
            msg := 'Error de restricción al actualizar usuario: ' || SQLERRM;
            error_code := 'USER_UPDATE_CHECK_VIOLATION';
            RETURN;
        WHEN OTHERS THEN
            msg := 'Error inesperado al actualizar usuario: ' || SQLERRM;
            error_code := 'USER_UPDATE_ERROR';
            RETURN;
    END;

    -- ====================================
    -- 11. ACTUALIZAR DETALLES DEL CONDUCTOR
    -- ====================================
    BEGIN
        UPDATE tab_driver_details 
        SET cel = v_cel_clean,
            license_cat = v_license_clean,
            license_exp = wlicense_exp,
            address_driver = v_address_clean,
            available = v_available_status,
            updated_at = NOW(),
            user_update = wuser_update
        WHERE id_user = wid_user;
        
        GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
        
        IF v_rows_affected = 0 THEN
            msg := 'No se pudieron actualizar los detalles del conductor (ID: ' || wid_user || ')';
            error_code := 'DRIVER_DETAILS_UPDATE_FAILED';
            RETURN;
        END IF;
        
        RAISE NOTICE '[fun_update_driver] Detalles actualizados: % (% fila afectada)', wid_user, v_rows_affected;
        
    EXCEPTION
        WHEN not_null_violation THEN
            msg := 'Error de campo obligatorio al actualizar detalles: ' || SQLERRM;
            error_code := 'DRIVER_UPDATE_NOT_NULL_VIOLATION';
            RETURN;
        WHEN check_violation THEN
            msg := 'Error de restricción al actualizar detalles: ' || SQLERRM;
            error_code := 'DRIVER_UPDATE_CHECK_VIOLATION';
            RETURN;
        WHEN OTHERS THEN
            msg := 'Error inesperado al actualizar detalles: ' || SQLERRM;
            error_code := 'DRIVER_UPDATE_ERROR';
            RETURN;
    END;

    -- ====================================
    -- 12. ÉXITO - RETORNAR DATOS
    -- ====================================
    success := TRUE;
    msg := 'Conductor actualizado exitosamente: ' || v_name_clean;
    
    IF NOT v_available_status THEN
        msg := msg || ' (Disponibilidad: NO DISPONIBLE)';
    ELSE
        msg := msg || ' (Disponibilidad: DISPONIBLE)';
    END IF;
    
    error_code := NULL;
    id_user := wid_user;
    id_card := v_driver_card;
    
    RAISE NOTICE '[fun_update_driver] Éxito: Conductor % actualizado', wid_user;
    RETURN;

END;
$$;

-- =============================================
-- DOCUMENTACIÓN
-- =============================================

COMMENT ON FUNCTION fun_update_driver IS 'Actualiza los datos de un conductor existente (usuario + detalles). Versión 2.0 con validaciones completas y manejo estructurado de errores.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================

/*
-- ==========================
-- Ejemplo 1: Actualización básica de conductor
-- ==========================
SELECT * FROM fun_update_driver(
    1735689650,                          -- wid_user (ID del conductor)
    'Juan Carlos Pérez Actualizado',    -- wfull_name
    'https://example.com/avatar2.jpg',   -- wavatar_url
    '3001234567',                        -- wcel
    'C2',                                -- wlicense_cat
    '2026-12-31',                        -- wlicense_exp
    'Calle 45 #23-10, Bucaramanga',     -- waddress_driver
    TRUE,                                -- wavailable
    1735689600                           -- wuser_update (usuario que actualiza)
);
-- Resultado esperado: success=TRUE, msg='Conductor actualizado exitosamente...'

-- ==========================
-- Ejemplo 2: Marcar conductor como no disponible
-- ==========================
SELECT * FROM fun_update_driver(
    1735689650,
    'Juan Pérez',
    NULL,                                -- wavatar_url (no cambiar)
    '3001234567',
    'C2',
    '2026-12-31',
    NULL,                                -- waddress_driver (no cambiar)
    FALSE,                               -- wavailable = NO DISPONIBLE
    1735689600
);
-- Resultado: msg incluye '(Disponibilidad: NO DISPONIBLE)'

-- ==========================
-- Ejemplo 3: Actualizar solo datos básicos (mantener disponibilidad)
-- ==========================
SELECT * FROM fun_update_driver(
    1735689650,
    'Juan Carlos Pérez',
    'https://example.com/new-avatar.jpg',
    '3009876543',                        -- Nuevo teléfono
    'C3',                                -- Nueva categoría de licencia
    '2027-06-30',                        -- Nueva fecha de expiración
    NULL,
    NULL,                                -- wavailable = NULL (mantener valor actual)
    1735689600
);
-- Mantiene la disponibilidad actual del conductor

-- ==========================
-- Ejemplo 4: Error - Conductor no existe
-- ==========================
SELECT * FROM fun_update_driver(
    9999999,                             -- ID inexistente
    'Nombre',
    NULL,
    '3001234567',
    'C1',
    '2026-12-31',
    NULL,
    TRUE,
    1735689600
);
-- Resultado: success=FALSE, error_code='DRIVER_NOT_FOUND'

-- ==========================
-- Ejemplo 5: Error - Usuario actualizador inexistente
-- ==========================
SELECT * FROM fun_update_driver(
    1735689650,
    'Juan Pérez',
    NULL,
    '3001234567',
    'C2',
    '2026-12-31',
    NULL,
    TRUE,
    9999999                              -- Usuario inexistente
);
-- Resultado: success=FALSE, error_code='USER_UPDATE_NOT_FOUND'

-- ==========================
-- Ejemplo 6: Error - Licencia vencida
-- ==========================
SELECT * FROM fun_update_driver(
    1735689650,
    'Juan Pérez',
    NULL,
    '3001234567',
    'C2',
    '2024-01-01',                        -- Fecha en el pasado
    NULL,
    TRUE,
    1735689600
);
-- Resultado: success=FALSE, error_code='LICENSE_EXPIRED'

-- ==========================
-- Ejemplo 7: Error - Categoría de licencia inválida
-- ==========================
SELECT * FROM fun_update_driver(
    1735689650,
    'Juan Pérez',
    NULL,
    '3001234567',
    'B2',                                -- Categoría inválida
    '2026-12-31',
    NULL,
    TRUE,
    1735689600
);
-- Resultado: success=FALSE, error_code='LICENSE_CAT_INVALID'

-- ==========================
-- Ejemplo 8: Error - Teléfono formato inválido
-- ==========================
SELECT * FROM fun_update_driver(
    1735689650,
    'Juan Pérez',
    NULL,
    '123',                               -- Menos de 7 dígitos
    'C2',
    '2026-12-31',
    NULL,
    TRUE,
    1735689600
);
-- Resultado: success=FALSE, error_code='PHONE_INVALID_FORMAT'

-- ==========================
-- Ejemplo 9: Error - Nombre demasiado corto
-- ==========================
SELECT * FROM fun_update_driver(
    1735689650,
    'Ab',                                -- Solo 2 caracteres
    NULL,
    '3001234567',
    'C2',
    '2026-12-31',
    NULL,
    TRUE,
    1735689600
);
-- Resultado: success=FALSE, error_code='NAME_TOO_SHORT'

-- ==========================
-- Ejemplo 10: Error - Avatar URL protocolo inválido
-- ==========================
SELECT * FROM fun_update_driver(
    1735689650,
    'Juan Pérez',
    'ftp://example.com/avatar.jpg',      -- Protocolo no permitido
    '3001234567',
    'C2',
    '2026-12-31',
    NULL,
    TRUE,
    1735689600
);
-- Resultado: success=FALSE, error_code='AVATAR_INVALID_PROTOCOL'

-- ==========================
-- Ejemplo 11: Error - Usuario no es conductor
-- ==========================
-- (Intentar actualizar un usuario que no tiene rol de conductor)
SELECT * FROM fun_update_driver(
    1735689600,                          -- Usuario sistema (no es conductor)
    'Sistema',
    NULL,
    '3001234567',
    'C2',
    '2026-12-31',
    NULL,
    TRUE,
    1735689600
);
-- Resultado: success=FALSE, error_code='NOT_A_DRIVER'
*/
