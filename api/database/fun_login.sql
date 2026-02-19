-- =============================================
-- BucaraBUS - Función: Autenticación de Usuario
-- =============================================
-- Versión: 1.0
-- Fecha: Febrero 2026
-- Descripción: Valida credenciales y retorna datos del usuario
-- =============================================

DROP FUNCTION IF EXISTS fun_login(VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION fun_login(
    wemail          VARCHAR,
    wpassword_hash  VARCHAR,
    OUT success     BOOLEAN,
    OUT msg         VARCHAR,
    OUT error_code  VARCHAR,
    OUT user_data   JSON
)
LANGUAGE plpgsql AS $$
DECLARE
    v_user_exists   BOOLEAN;
    v_user_active   BOOLEAN;
    v_user_id       INTEGER;
    v_stored_hash   VARCHAR(60);
    v_user_info     JSON;
BEGIN
    success := FALSE;
    msg := '';
    error_code := NULL;
    user_data := NULL;
    
    -- Validar email obligatorio
    IF wemail IS NULL OR TRIM(wemail) = '' THEN
        msg := 'El email es obligatorio';
        error_code := 'EMAIL_REQUIRED';
        RETURN;
    END IF;
    
    -- Buscar usuario por email
    SELECT EXISTS(
        SELECT 1 FROM tab_users WHERE LOWER(email) = LOWER(TRIM(wemail))
    ) INTO v_user_exists;
    
    IF NOT v_user_exists THEN
        msg := 'Usuario no encontrado';
        error_code := 'USER_NOT_FOUND';
        RETURN;
    END IF;
    
    -- Obtener datos del usuario
    SELECT 
        id_user,
        password_hash,
        is_active
    INTO 
        v_user_id,
        v_stored_hash,
        v_user_active
    FROM tab_users
    WHERE LOWER(email) = LOWER(TRIM(wemail));
    
    -- Verificar si el usuario está activo
    IF NOT v_user_active THEN
        msg := 'Usuario desactivado. Contacta al administrador';
        error_code := 'USER_INACTIVE';
        RETURN;
    END IF;
    
    -- Nota: La validación de password se hace en el backend con bcrypt.compare()
    -- Esta función solo verifica que el usuario existe y está activo
    
    -- Construir JSON con datos del usuario incluyendo roles
    SELECT json_build_object(
        'id_user', u.id_user,
        'email', u.email,
        'full_name', u.full_name,
        'avatar_url', u.avatar_url,
        'is_active', u.is_active,
        'created_at', u.created_at,
        'last_login', u.last_login,
        'roles', (
            SELECT json_agg(
                json_build_object(
                    'id_role', r.id_role,
                    'role_name', r.role_name,
                    'description', r.description
                )
            )
            FROM tab_user_roles ur
            INNER JOIN tab_roles r ON ur.id_role = r.id_role
            WHERE ur.id_user = u.id_user 
              AND ur.is_active = TRUE
              AND r.is_active = TRUE
        )
    ) INTO user_data
    FROM tab_users u
    WHERE u.id_user = v_user_id;
    
    -- Actualizar último login
    UPDATE tab_users 
    SET last_login = NOW() 
    WHERE id_user = v_user_id;
    
    success := TRUE;
    msg := 'Autenticación exitosa';
    error_code := NULL;
    
    RETURN;
END;
$$;

COMMENT ON FUNCTION fun_login IS 'Valida credenciales de usuario y retorna sus datos con roles. La validación del password hash se hace en el backend con bcrypt.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================

/*
-- Ejemplo 1: Login exitoso
SELECT * FROM fun_login('admin@gmail.com', 'hash_de_bcrypt_aqui');
-- Resultado: success=TRUE, user_data contiene JSON con datos y roles

-- Ejemplo 2: Usuario no encontrado
SELECT * FROM fun_login('noexiste@example.com', 'cualquier_hash');
-- Resultado: success=FALSE, error_code='USER_NOT_FOUND'

-- Ejemplo 3: Usuario inactivo
SELECT * FROM fun_login('usuario_inactivo@example.com', 'hash');
-- Resultado: success=FALSE, error_code='USER_INACTIVE'
*/
