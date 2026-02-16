-- =============================================
-- BucaraBUS - Función: Actualizar Usuario
-- =============================================
-- Versión: 2.0
-- Fecha: Febrero 2025
-- Descripción: Actualiza datos básicos de un usuario (nombre, avatar)
-- Nota: Email y password requieren funciones específicas por seguridad
-- =============================================

-- Eliminar versiones anteriores
DROP FUNCTION IF EXISTS fun_update_user(INTEGER, VARCHAR, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS fun_update_user(INTEGER, VARCHAR, VARCHAR, INTEGER);

-- =============================================
-- Función: fun_update_user v2.0
-- =============================================
CREATE OR REPLACE FUNCTION fun_update_user(
    -- Identificador del usuario a actualizar
    wid_user        tab_users.id_user%TYPE,
    
    -- Auditoría
    wuser_update    tab_users.user_update%TYPE,
    
    -- Datos opcionales (NULL = mantener valor actual)
    wfull_name      tab_users.full_name%TYPE DEFAULT NULL,
    wavatar_url     tab_users.avatar_url%TYPE DEFAULT NULL,
    
    -- Parámetros de salida
    OUT success     BOOLEAN,
    OUT msg         VARCHAR,
    OUT error_code  VARCHAR,
    OUT id_user     INTEGER
)
LANGUAGE plpgsql AS $$

DECLARE
    v_updater_exists    BOOLEAN;
    v_user_exists       BOOLEAN;
    v_user_active       BOOLEAN;
    v_current_name      VARCHAR(100);
    v_current_avatar    VARCHAR(500);
    v_name_clean        VARCHAR(100);
    v_avatar_clean      VARCHAR(500);
    v_has_changes       BOOLEAN := FALSE;
    v_rows_affected     INTEGER;
    
BEGIN
    -- ====================================
    -- 1. INICIALIZACIÓN
    -- ====================================
    success := FALSE;
    msg := '';
    error_code := NULL;
    id_user := NULL;

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

    RAISE NOTICE '[fun_update_user] Usuario actualizador validado: %', wuser_update;

    -- ====================================
    -- 3. VALIDACIÓN DEL USUARIO A ACTUALIZAR
    -- ====================================
    IF wid_user IS NULL OR wid_user <= 0 THEN
        msg := 'El ID del usuario es obligatorio y debe ser mayor que 0';
        error_code := 'USER_ID_INVALID';
        RETURN;
    END IF;

    -- Obtener datos actuales del usuario
    SELECT 
        EXISTS(SELECT 1 FROM tab_users WHERE tab_users.id_user = wid_user),
        is_active,
        full_name,
        avatar_url
    INTO 
        v_user_exists,
        v_user_active,
        v_current_name,
        v_current_avatar
    FROM tab_users
    WHERE tab_users.id_user = wid_user;

    IF NOT v_user_exists OR v_current_name IS NULL THEN
        msg := 'El usuario con ID ' || wid_user || ' no existe';
        error_code := 'USER_NOT_FOUND';
        RETURN;
    END IF;

    -- Validar que el usuario está activo
    IF NOT v_user_active THEN
        msg := 'No se puede actualizar un usuario inactivo (ID: ' || wid_user || ')';
        error_code := 'USER_INACTIVE';
        RETURN;
    END IF;

    RAISE NOTICE '[fun_update_user] Usuario validado: % (Nombre actual: "%")', wid_user, v_current_name;

    -- ====================================
    -- 4. VALIDACIONES Y NORMALIZACIÓN DE NOMBRE
    -- ====================================
    v_name_clean := NULL;
    
    IF wfull_name IS NOT NULL AND TRIM(wfull_name) != '' THEN
        -- Limpiar espacios extras
        v_name_clean := TRIM(REGEXP_REPLACE(wfull_name, '\s+', ' ', 'g'));
        
        -- Validar longitud mínima
        IF LENGTH(v_name_clean) < 2 THEN
            msg := 'El nombre debe tener al menos 2 caracteres';
            error_code := 'NAME_TOO_SHORT';
            RETURN;
        END IF;
        
        -- Validar longitud máxima (schema: VARCHAR(100))
        IF LENGTH(v_name_clean) > 100 THEN
            msg := 'El nombre excede la longitud máxima permitida (100 caracteres). Recibido: ' || LENGTH(v_name_clean) || ' caracteres';
            error_code := 'NAME_TOO_LONG';
            RETURN;
        END IF;
        
        -- Validar caracteres permitidos (letras, espacios, guiones, apóstrofes, acentos)
        -- Permite: José María O'Connor-García
        IF v_name_clean !~ '^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ'' -]+$' THEN
            msg := 'El nombre contiene caracteres no permitidos. Solo se permiten letras, espacios, guiones y apóstrofes';
            error_code := 'NAME_INVALID_CHARS';
            RETURN;
        END IF;
        
        -- Validar que tenga al menos una letra
        IF v_name_clean !~ '[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ]' THEN
            msg := 'El nombre debe contener al menos una letra';
            error_code := 'NAME_NO_LETTERS';
            RETURN;
        END IF;
        
        -- Marcar cambio si es diferente
        IF v_name_clean != v_current_name THEN
            v_has_changes := TRUE;
        ELSE
            -- Nombre no cambió, no actualizar
            v_name_clean := NULL;
        END IF;
    END IF;

    -- ====================================
    -- 5. VALIDACIONES Y NORMALIZACIÓN DE AVATAR
    -- ====================================
    v_avatar_clean := NULL;
    
    IF wavatar_url IS NOT NULL THEN
        -- String vacío = limpiar avatar (establecer NULL)
        IF TRIM(wavatar_url) = '' THEN
            v_avatar_clean := NULL;
            v_has_changes := TRUE;
        ELSE
            v_avatar_clean := TRIM(wavatar_url);
            
            -- Validar longitud máxima (schema: VARCHAR(500))
            IF LENGTH(v_avatar_clean) > 500 THEN
                msg := 'La URL del avatar excede la longitud máxima permitida (500 caracteres). Recibido: ' || LENGTH(v_avatar_clean) || ' caracteres';
                error_code := 'AVATAR_TOO_LONG';
                RETURN;
            END IF;
            
            -- Validar formato URL (debe comenzar con http:// o https://)
            IF v_avatar_clean !~ '^https?://' THEN
                msg := 'La URL del avatar debe comenzar con http:// o https://';
                error_code := 'AVATAR_INVALID_PROTOCOL';
                RETURN;
            END IF;
            
            -- Marcar cambio si es diferente (o si el actual es NULL)
            IF v_avatar_clean != v_current_avatar OR (v_current_avatar IS NULL AND v_avatar_clean IS NOT NULL) THEN
                v_has_changes := TRUE;
            ELSE
                -- Avatar no cambió, no actualizar
                v_avatar_clean := NULL;
            END IF;
        END IF;
    END IF;

    -- ====================================
    -- 6. VERIFICAR QUE HAY CAMBIOS
    -- ====================================
    IF NOT v_has_changes THEN
        msg := 'No hay cambios para aplicar. Proporcione al menos un campo para actualizar (nombre o avatar)';
        error_code := 'NO_CHANGES';
        RETURN;
    END IF;

    RAISE NOTICE '[fun_update_user] Cambios a aplicar - Nombre: %, Avatar: %',
        CASE WHEN v_name_clean IS NOT NULL THEN 'SÍ' ELSE 'NO' END,
        CASE WHEN wavatar_url IS NOT NULL THEN 'SÍ' ELSE 'NO' END;

    -- ====================================
    -- 7. ACTUALIZAR USUARIO
    -- ====================================
    BEGIN
        UPDATE tab_users
        SET 
            full_name = COALESCE(v_name_clean, full_name),
            avatar_url = CASE 
                WHEN wavatar_url IS NOT NULL AND TRIM(wavatar_url) = '' THEN NULL
                WHEN v_avatar_clean IS NOT NULL THEN v_avatar_clean
                ELSE avatar_url
            END,
            updated_at = NOW(),
            user_update = wuser_update
        WHERE tab_users.id_user = wid_user
          AND is_active = TRUE;
        
        GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
        
        IF v_rows_affected = 0 THEN
            msg := 'No se pudo actualizar el usuario (ID: ' || wid_user || ')';
            error_code := 'USER_UPDATE_FAILED';
            RETURN;
        END IF;
        
        RAISE NOTICE '[fun_update_user] Usuario actualizado: % (% fila afectada)', wid_user, v_rows_affected;
        
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
    -- 8. ÉXITO - RETORNAR DATOS
    -- ====================================
    success := TRUE;
    id_user := wid_user;
    
    -- Construir mensaje descriptivo
    msg := 'Usuario actualizado exitosamente';
    
    IF v_name_clean IS NOT NULL THEN
        msg := msg || '. Nuevo nombre: "' || v_name_clean || '"';
    END IF;
    
    IF wavatar_url IS NOT NULL THEN
        IF TRIM(wavatar_url) = '' THEN
            msg := msg || '. Avatar: ELIMINADO';
        ELSE
            msg := msg || '. Avatar: ACTUALIZADO';
        END IF;
    END IF;
    
    error_code := NULL;
    
    RAISE NOTICE '[fun_update_user] Éxito: Usuario % actualizado', wid_user;
    RETURN;

END;
$$;

-- =============================================
-- DOCUMENTACIÓN
-- =============================================

COMMENT ON FUNCTION fun_update_user IS 'Actualiza datos básicos de un usuario (full_name, avatar_url). Email y password requieren funciones específicas. Versión 2.0 con validaciones completas y manejo estructurado de errores.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================

/*
-- ==========================
-- Ejemplo 1: Actualizar solo nombre
-- ==========================
SELECT * FROM fun_update_user(
    1735689650,                     -- wid_user
    'Juan Carlos Pérez López',      -- wfull_name (actualizar)
    NULL,                            -- wavatar_url (no cambiar)
    1735689600                       -- wuser_update
);
-- Resultado: success=TRUE, msg='Usuario actualizado exitosamente. Nuevo nombre: "Juan Carlos Pérez López"'

-- ==========================
-- Ejemplo 2: Actualizar solo avatar
-- ==========================
SELECT * FROM fun_update_user(
    1735689650,
    NULL,                                               -- wfull_name (no cambiar)
    'https://example.com/avatars/new-photo.jpg',       -- wavatar_url (actualizar)
    1735689600
);
-- Resultado: success=TRUE, msg='Usuario actualizado exitosamente. Avatar: ACTUALIZADO'

-- ==========================
-- Ejemplo 3: Actualizar ambos campos
-- ==========================
SELECT * FROM fun_update_user(
    1735689650,
    'María García Rodríguez',
    'https://example.com/avatars/maria.jpg',
    1735689600
);
-- Resultado: actualiza nombre y avatar

-- ==========================
-- Ejemplo 4: Eliminar avatar (establecer NULL)
-- ==========================
SELECT * FROM fun_update_user(
    1735689650,
    NULL,                            -- No cambiar nombre
    '',                              -- String vacío = eliminar avatar
    1735689600
);
-- Resultado: success=TRUE, msg='Usuario actualizado exitosamente. Avatar: ELIMINADO'

-- ==========================
-- Ejemplo 5: Error - Usuario no existe
-- ==========================
SELECT * FROM fun_update_user(
    9999999,                         -- ID inexistente
    'Nombre',
    NULL,
    1735689600
);
-- Resultado: success=FALSE, error_code='USER_NOT_FOUND'

-- ==========================
-- Ejemplo 6: Error - Usuario actualizador inexistente
-- ==========================
SELECT * FROM fun_update_user(
    1735689650,
    'Nombre',
    NULL,
    9999999                          -- Usuario inexistente
);
-- Resultado: success=FALSE, error_code='USER_UPDATE_NOT_FOUND'

-- ==========================
-- Ejemplo 7: Error - Usuario inactivo
-- ==========================
-- (Primero desactivar un usuario)
UPDATE tab_users SET is_active = FALSE WHERE id_user = 1735689650;
SELECT * FROM fun_update_user(
    1735689650,
    'Nuevo nombre',
    NULL,
    1735689600
);
-- Resultado: success=FALSE, error_code='USER_INACTIVE'

-- ==========================
-- Ejemplo 8: Error - Nombre demasiado corto
-- ==========================
SELECT * FROM fun_update_user(
    1735689650,
    'A',                             -- Solo 1 carácter
    NULL,
    1735689600
);
-- Resultado: success=FALSE, error_code='NAME_TOO_SHORT'

-- ==========================
-- Ejemplo 9: Error - Nombre con caracteres inválidos
-- ==========================
SELECT * FROM fun_update_user(
    1735689650,
    'User@123#',                     -- Contiene @, #
    NULL,
    1735689600
);
-- Resultado: success=FALSE, error_code='NAME_INVALID_CHARS'

-- ==========================
-- Ejemplo 10: Error - Avatar URL sin protocolo
-- ==========================
SELECT * FROM fun_update_user(
    1735689650,
    NULL,
    'example.com/avatar.jpg',        -- Falta http:// o https://
    1735689600
);
-- Resultado: success=FALSE, error_code='AVATAR_INVALID_PROTOCOL'

-- ==========================
-- Ejemplo 11: Error - No hay cambios
-- ==========================
SELECT * FROM fun_update_user(
    1735689650,
    NULL,                            -- Todos NULL = sin cambios
    NULL,
    1735689600
);
-- Resultado: success=FALSE, error_code='NO_CHANGES'

-- ==========================
-- Ejemplo 12: Nombre con acentos y apóstrofes (válido)
-- ==========================
SELECT * FROM fun_update_user(
    1735689650,
    'José María O''Connor-García',  -- Válido: acentos, apóstrofe, guion
    NULL,
    1735689600
);
-- Resultado: success=TRUE

-- ==========================
-- NOTAS IMPORTANTES
-- ==========================

-- 1. EMAIL NO SE PUEDE CAMBIAR AQUÍ
--    Usar fun_change_email (requiere verificación por seguridad)

-- 2. PASSWORD NO SE PUEDE CAMBIAR AQUÍ
--    Usar fun_change_password (requiere hash bcrypt)

-- 3. is_active NO SE CAMBIA AQUÍ
--    Usar fun_activate_user / fun_deactivate_user

-- 4. last_login SOLO SE ACTUALIZA EN LOGIN
--    No se puede modificar manualmente

-- 5. Para limpiar avatar, pasar string vacío ''
--    NULL = mantener valor actual
--    '' = establecer avatar_url como NULL

-- 6. updated_at se actualiza automáticamente a NOW()

-- 7. Solo se pueden actualizar usuarios activos (is_active = TRUE)

-- 8. Requiere que el usuario actualizador exista y esté activo
*/
