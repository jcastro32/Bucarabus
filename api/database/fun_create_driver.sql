-- =============================================
-- BucaraBUS - Función: Crear Nuevo Conductor
-- =============================================
-- Versión: 3.0
-- Fecha: Febrero 2026
-- Descripción: Crea un usuario con rol de conductor y sus detalles
-- Arquitectura: tab_users + tab_user_roles + tab_driver_details
-- Generación de ID: Secuencial (MAX + 1)
-- =============================================

-- Eliminar versiones anteriores
DROP FUNCTION IF EXISTS fun_create_driver(
    VARCHAR, VARCHAR, VARCHAR, DECIMAL, VARCHAR, VARCHAR, DATE, VARCHAR, TEXT, VARCHAR
);
DROP FUNCTION IF EXISTS fun_create_driver(
    VARCHAR(320), VARCHAR(60), VARCHAR(100), DECIMAL(12,0), VARCHAR(15), VARCHAR(2), DATE, VARCHAR(500), TEXT, INTEGER
);
DROP TYPE IF EXISTS driver_created_type CASCADE;

-- =============================================
-- Función: fun_create_driver v3.0
-- =============================================
CREATE OR REPLACE FUNCTION fun_create_driver(
    -- Datos del usuario
    wuser_email         tab_users.email%TYPE,
    wpassword_hash      tab_users.password_hash%TYPE,
    wfull_name          tab_users.full_name%TYPE,
    
    -- Datos del conductor
    wid_card            tab_driver_details.id_card%TYPE,
    wcel                tab_driver_details.cel%TYPE,
    wlicense_cat        tab_driver_details.license_cat%TYPE,
    wlicense_exp        tab_driver_details.license_exp%TYPE,
    
    -- Auditoría
    wuser_create        tab_users.user_create%TYPE,
    
    -- Datos opcionales
    wavatar_url         tab_users.avatar_url%TYPE DEFAULT NULL,
    waddress_driver     tab_driver_details.address_driver%TYPE DEFAULT NULL,
    
    -- Parámetros de salida
    OUT success         BOOLEAN,
    OUT msg             VARCHAR,
    OUT error_code      VARCHAR,
    OUT id_user         INTEGER,
    OUT id_card         DECIMAL
)
LANGUAGE plpgsql AS $$

DECLARE
    v_new_id            INTEGER;
    v_email_clean       VARCHAR(320);
    v_name_clean        VARCHAR(100);
    v_cel_clean         VARCHAR(15);
    v_license_clean     VARCHAR(2);
    v_user_exists       BOOLEAN;
    v_email_exists      BOOLEAN;
    v_card_exists       BOOLEAN;
    
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
    -- 2. VALIDACIÓN DEL USUARIO CREADOR
    -- ====================================
    SELECT EXISTS(
        SELECT 1 
        FROM tab_users 
        WHERE tab_users.id_user = wuser_create 
          AND is_active = TRUE
    ) INTO v_user_exists;
    
    IF NOT v_user_exists THEN
        msg := 'El usuario creador no existe o está inactivo (ID: ' || wuser_create || ')';
        error_code := 'USER_CREATE_NOT_FOUND';
        RETURN;
    END IF;

    -- ====================================
    -- 3. VALIDACIONES DE EMAIL
    -- ====================================
    IF wuser_email IS NULL OR TRIM(wuser_email) = '' THEN
        msg := 'El email es obligatorio';
        error_code := 'EMAIL_NULL_EMPTY';
        RETURN;
    END IF;
    
    v_email_clean := LOWER(TRIM(wuser_email));
    
    IF v_email_clean !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        msg := 'El email "' || v_email_clean || '" no tiene un formato válido';
        error_code := 'EMAIL_INVALID_FORMAT';
        RETURN;
    END IF;
    
    IF LENGTH(v_email_clean) > 320 THEN
        msg := 'El email excede la longitud máxima permitida (320 caracteres)';
        error_code := 'EMAIL_TOO_LONG';
        RETURN;
    END IF;
    
    -- Verificar email duplicado
    SELECT EXISTS(
        SELECT 1 FROM tab_users WHERE email = v_email_clean
    ) INTO v_email_exists;
    
    IF v_email_exists THEN
        msg := 'El email "' || v_email_clean || '" ya está registrado en el sistema';
        error_code := 'EMAIL_DUPLICATE';
        RETURN;
    END IF;

    -- ====================================
    -- 4. VALIDACIONES DE PASSWORD
    -- ====================================
    IF wpassword_hash IS NULL OR LENGTH(wpassword_hash) != 60 THEN
        msg := 'El hash de contraseña debe tener exactamente 60 caracteres (bcrypt)';
        error_code := 'PASSWORD_INVALID_LENGTH';
        RETURN;
    END IF;
    
    IF wpassword_hash !~ '^\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{53}$' THEN
        msg := 'El hash de contraseña no tiene formato bcrypt válido';
        error_code := 'PASSWORD_INVALID_FORMAT';
        RETURN;
    END IF;

    -- ====================================
    -- 5. VALIDACIONES DE NOMBRE
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
    -- 6. VALIDACIONES DE AVATAR (OPCIONAL)
    -- ====================================
    IF wavatar_url IS NOT NULL AND TRIM(wavatar_url) != '' THEN
        IF wavatar_url !~ '^https?://' THEN
            msg := 'La URL del avatar debe comenzar con http:// o https://';
            error_code := 'AVATAR_INVALID_PROTOCOL';
            RETURN;
        END IF;
        
        IF LENGTH(wavatar_url) > 500 THEN
            msg := 'La URL del avatar excede la longitud máxima (500 caracteres)';
            error_code := 'AVATAR_TOO_LONG';
            RETURN;
        END IF;
    END IF;

    -- ====================================
    -- 7. VALIDACIONES DE CÉDULA
    -- ====================================
    IF wid_card IS NULL OR wid_card <= 0 THEN
        msg := 'La cédula es obligatoria y debe ser un número positivo';
        error_code := 'ID_CARD_INVALID';
        RETURN;
    END IF;
    
    IF wid_card > 999999999999 THEN -- Max 12 dígitos (DECIMAL(12,0))
        msg := 'La cédula excede el máximo permitido (12 dígitos)';
        error_code := 'ID_CARD_TOO_LARGE';
        RETURN;
    END IF;
    
    -- Verificar cédula duplicada
    SELECT EXISTS(
        SELECT 1 FROM tab_driver_details WHERE tab_driver_details.id_card = wid_card
    ) INTO v_card_exists;
    
    IF v_card_exists THEN
        msg := 'La cédula ' || wid_card || ' ya está registrada como conductor';
        error_code := 'ID_CARD_DUPLICATE';
        RETURN;
    END IF;

    -- ====================================
    -- 8. VALIDACIONES DE TELÉFONO
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
    -- 9. VALIDACIONES DE LICENCIA
    -- ====================================
    IF wlicense_cat IS NULL THEN
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
    -- 10. GENERAR ID DE USUARIO (SECUENCIAL)
    -- ====================================
    
    -- Generar ID secuencial: MAX(id_user) + 1
    SELECT COALESCE(MAX(tab_users.id_user), 0) + 1 INTO v_new_id 
    FROM tab_users;
    
    RAISE NOTICE '[fun_create_driver] ID generado (secuencial): %', v_new_id;

    -- ====================================
    -- 11. INSERTAR USUARIO EN tab_users
    -- ====================================
    BEGIN
        INSERT INTO tab_users (
            id_user,
            email,
            password_hash,
            full_name,
            avatar_url,
            user_create,
            is_active
        ) VALUES (
            v_new_id,
            v_email_clean,
            wpassword_hash,
            v_name_clean,
            NULLIF(TRIM(wavatar_url), ''),
            wuser_create,
            TRUE
        );
        
        RAISE NOTICE 'Usuario creado con ID: %', v_new_id;
        
    EXCEPTION
        WHEN unique_violation THEN
            msg := 'Error de unicidad al insertar usuario: ' || SQLERRM;
            error_code := 'USER_INSERT_UNIQUE_VIOLATION';
            RETURN;
        WHEN foreign_key_violation THEN
            msg := 'Error de clave foránea al insertar usuario: ' || SQLERRM;
            error_code := 'USER_INSERT_FK_VIOLATION';
            RETURN;
        WHEN OTHERS THEN
            msg := 'Error inesperado al insertar usuario: ' || SQLERRM;
            error_code := 'USER_INSERT_ERROR';
            RETURN;
    END;

    -- ====================================
    -- 12. ASIGNAR ROL CONDUCTOR (id_role = 2)
    -- ====================================
    BEGIN
        INSERT INTO tab_user_roles (
            id_user,
            id_role,
            assigned_by,
            is_active
        ) VALUES (
            v_new_id,
            2,  -- Rol: Conductor (según bd_bucarabus.sql)
            wuser_create,
            TRUE
        );
        
        RAISE NOTICE 'Rol Conductor asignado al usuario %', v_new_id;
        
    EXCEPTION
        WHEN foreign_key_violation THEN
            msg := 'Error al asignar rol: ' || SQLERRM;
            error_code := 'ROLE_ASSIGN_FK_VIOLATION';
            RETURN;
        WHEN OTHERS THEN
            msg := 'Error inesperado al asignar rol: ' || SQLERRM;
            error_code := 'ROLE_ASSIGN_ERROR';
            RETURN;
    END;

    -- ====================================
    -- 13. CREAR DETALLES DEL CONDUCTOR
    -- ====================================
    BEGIN
        INSERT INTO tab_driver_details (
            id_card,
            id_user,
            cel,
            license_cat,
            license_exp,
            address_driver,
            available,
            status_driver,
            user_create
        ) VALUES (
            wid_card,
            v_new_id,
            v_cel_clean,
            v_license_clean,
            wlicense_exp,
            NULLIF(TRIM(waddress_driver), ''),
            TRUE,
            TRUE,
            wuser_create
        );
        
        RAISE NOTICE 'Detalles de conductor creados para cédula: %', wid_card;
        
    EXCEPTION
        WHEN unique_violation THEN
            msg := 'Error de unicidad al insertar detalles: ' || SQLERRM;
            error_code := 'DRIVER_INSERT_UNIQUE_VIOLATION';
            RETURN;
        WHEN foreign_key_violation THEN
            msg := 'Error de clave foránea al insertar detalles: ' || SQLERRM;
            error_code := 'DRIVER_INSERT_FK_VIOLATION';
            RETURN;
        WHEN check_violation THEN
            msg := 'Error de restricción al insertar detalles: ' || SQLERRM;
            error_code := 'DRIVER_INSERT_CHECK_VIOLATION';
            RETURN;
        WHEN OTHERS THEN
            msg := 'Error inesperado al insertar detalles: ' || SQLERRM;
            error_code := 'DRIVER_INSERT_ERROR';
            RETURN;
    END;

    -- ====================================
    -- 14. ÉXITO - RETORNAR DATOS
    -- ====================================
    success := TRUE;
    msg := 'Conductor creado exitosamente: ' || v_name_clean || ' (' || v_email_clean || ')';
    error_code := NULL;
    id_user := v_new_id;
    id_card := wid_card;
    
    RETURN;

END;
$$;

