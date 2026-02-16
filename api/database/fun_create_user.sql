-- =============================================
-- FUNCIÓN: fun_create_user v2.0
-- =============================================
-- Descripción: Crea un nuevo usuario con validaciones completas
--              y asigna automáticamente el rol de Pasajero (id_role = 1)
-- 
-- Parámetros IN:
--   wemail         - Email del usuario (VARCHAR 320)
--   wpassword_hash - Hash bcrypt de la contraseña (VARCHAR 60)
--   wfull_name     - Nombre completo del usuario (VARCHAR 100)
--   wavatar_url    - URL del avatar (VARCHAR 500, opcional)
--   wuser_create   - ID del usuario administrador que crea el usuario (INTEGER)
--
-- Parámetros OUT:
--   success        - TRUE si el usuario se creó exitosamente
--   msg            - Mensaje descriptivo del resultado
--   error_code     - Código de error (NULL si success = TRUE)
--   id_user        - ID del usuario creado (NULL si falla)
--
-- Uso:
--   SELECT * FROM fun_create_user(
--     'juan@example.com',
--     '$2b$10$abc...',
--     'Juan Pérez',
--     NULL,
--     1
--   );
--
-- Retorna: (success, msg, error_code, id_user)
--
-- Versión: 2.0
-- Fecha: 2026-02-16
-- =============================================

-- Eliminar función anterior (diferentes firmas)
DROP FUNCTION IF EXISTS fun_create_user(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS fun_create_user(VARCHAR, VARCHAR, VARCHAR, VARCHAR, INTEGER);
DROP FUNCTION IF EXISTS fun_create_user(tab_users.email%TYPE, tab_users.password_hash%TYPE, tab_users.full_name%TYPE, tab_users.avatar_url%TYPE, tab_users.user_create%TYPE);

CREATE OR REPLACE FUNCTION fun_create_user(
  wemail         tab_users.email%TYPE,
  wpassword_hash tab_users.password_hash%TYPE,
  wfull_name     tab_users.full_name%TYPE,
  wuser_create   tab_users.user_create%TYPE,
  wavatar_url    tab_users.avatar_url%TYPE DEFAULT NULL,
  OUT success    BOOLEAN,
  OUT msg        VARCHAR,
  OUT error_code VARCHAR,
  OUT id_user    tab_users.id_user%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  -- ==========================================
  -- 1. SECCIÓN DE VARIABLES
  -- ==========================================
  
  -- Constantes
  v_epoch_2025   CONSTANT INTEGER := 1735689600;  -- 2025-01-01 00:00:00 UTC
  
  -- Variables de validación
  v_user_exists  BOOLEAN;
  v_email_exists BOOLEAN;
  v_email_clean  tab_users.email%TYPE;
  v_name_clean   tab_users.full_name%TYPE;
  
  -- Variables para generación de ID
  v_generated_id tab_users.id_user%TYPE;
  v_random       INTEGER;
  v_last_id      tab_users.id_user%TYPE;
  
  -- Variable para rol
  v_role_exists  BOOLEAN;

BEGIN
  -- ==========================================
  -- 2. INICIALIZACIÓN
  -- ==========================================
  
  success := FALSE;
  msg := '';
  error_code := NULL;
  id_user := NULL;
  
  RAISE NOTICE '[fun_create_user] Iniciando creación de usuario: %', wemail;
  
  -- ==========================================
  -- 3. VALIDAR USUARIO CREADOR
  -- ==========================================
  
  SELECT EXISTS(
    SELECT 1 FROM tab_users 
    WHERE id_user = wuser_create AND is_active = TRUE
  ) INTO v_user_exists;
  
  IF NOT v_user_exists THEN
    msg := 'El usuario creador no existe o está inactivo (ID: ' || wuser_create || ')';
    error_code := 'USER_CREATE_NOT_FOUND';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 4. VALIDAR NOMBRE COMPLETO
  -- ==========================================
  
  -- 4.1. Validar NULL/vacío
  IF wfull_name IS NULL OR TRIM(wfull_name) = '' THEN
    msg := 'El nombre completo no puede estar vacío';
    error_code := 'NAME_NULL_EMPTY';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- 4.2. Limpiar espacios extras
  v_name_clean := TRIM(REGEXP_REPLACE(wfull_name, '\s+', ' ', 'g'));
  
  -- 4.3. Validar longitud mínima
  IF LENGTH(v_name_clean) < 2 THEN
    msg := 'El nombre debe tener al menos 2 caracteres. Recibido: "' || v_name_clean || '"';
    error_code := 'NAME_TOO_SHORT';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- 4.4. Validar longitud máxima (según esquema: VARCHAR(100))
  IF LENGTH(v_name_clean) > 100 THEN
    msg := 'El nombre no puede exceder 100 caracteres. Recibido: ' || LENGTH(v_name_clean) || ' caracteres';
    error_code := 'NAME_TOO_LONG';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- 4.5. Validar caracteres permitidos (letras, espacios, guiones, apóstrofes, acentos)
  -- Permite: José María O'Connor-García
  IF v_name_clean !~ '^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ'' -]+$' THEN
    msg := 'El nombre contiene caracteres no permitidos. Solo se permiten letras, espacios, guiones y apóstrofes';
    error_code := 'NAME_INVALID_CHARS';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- 4.6. Validar que tenga al menos una letra
  IF v_name_clean !~ '[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ]' THEN
    msg := 'El nombre debe contener al menos una letra';
    error_code := 'NAME_NO_LETTERS';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 5. VALIDAR EMAIL
  -- ==========================================
  
  -- 5.1. Validar NULL/vacío
  IF wemail IS NULL OR TRIM(wemail) = '' THEN
    msg := 'El email no puede estar vacío';
    error_code := 'EMAIL_NULL_EMPTY';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- 5.2. Limpiar y normalizar (lowercase)
  v_email_clean := LOWER(TRIM(wemail));
  
  -- 5.3. Validar longitud (según RFC 5321: local 64 + @ + domain 255 = 320 máx)
  IF LENGTH(v_email_clean) < 5 OR LENGTH(v_email_clean) > 320 THEN
    msg := 'El email debe tener entre 5 y 320 caracteres. Recibido: ' || LENGTH(v_email_clean) || ' caracteres';
    error_code := 'EMAIL_INVALID_LENGTH';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- 5.4. Validar formato (según esquema: '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
  IF v_email_clean !~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$' THEN
    msg := 'El email tiene formato inválido. Debe ser usuario@dominio.com';
    error_code := 'EMAIL_INVALID_FORMAT';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- 5.5. Validar email NO duplicado (UNIQUE constraint)
  SELECT EXISTS(
    SELECT 1 FROM tab_users 
    WHERE email = v_email_clean
  ) INTO v_email_exists;
  
  IF v_email_exists THEN
    msg := 'El email ya está registrado: ' || v_email_clean;
    error_code := 'EMAIL_DUPLICATE';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 6. VALIDAR PASSWORD HASH
  -- ==========================================
  
  -- 6.1. Validar NULL/vacío
  IF wpassword_hash IS NULL OR TRIM(wpassword_hash) = '' THEN
    msg := 'El password hash no puede estar vacío';
    error_code := 'PASSWORD_HASH_NULL_EMPTY';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- 6.2. Validar longitud (bcrypt hash debe ser exactamente 60 caracteres)
  IF LENGTH(wpassword_hash) != 60 THEN
    msg := 'El password hash debe tener exactamente 60 caracteres (bcrypt). Recibido: ' || LENGTH(wpassword_hash) || ' caracteres';
    error_code := 'PASSWORD_HASH_INVALID_LENGTH';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- 6.3. Validar formato bcrypt ($2a$, $2b$, $2y$ + 2 dígitos + $ + 53 caracteres)
  IF wpassword_hash !~ '^\$2[ayb]\$[0-9]{2}\$[A-Za-z0-9./]{53}$' THEN
    msg := 'El password hash debe tener formato bcrypt válido ($2a$/$2b$/$2y$ + rounds + salt + hash)';
    error_code := 'PASSWORD_HASH_INVALID_FORMAT';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 7. VALIDAR AVATAR URL (OPCIONAL)
  -- ==========================================
  
  IF wavatar_url IS NOT NULL THEN
    -- 7.1. Validar longitud (según esquema: VARCHAR(500))
    IF LENGTH(wavatar_url) > 500 THEN
      msg := 'La URL del avatar no puede exceder 500 caracteres. Recibido: ' || LENGTH(wavatar_url) || ' caracteres';
      error_code := 'AVATAR_URL_TOO_LONG';
      RAISE NOTICE '[fun_create_user] ERROR: %', msg;
      RETURN;
    END IF;
    
    -- 7.2. Validar formato URL básico (http:// o https://)
    IF wavatar_url !~ '^https?://' THEN
      msg := 'La URL del avatar debe comenzar con http:// o https://';
      error_code := 'AVATAR_URL_INVALID_FORMAT';
      RAISE NOTICE '[fun_create_user] ERROR: %', msg;
      RETURN;
    END IF;
  END IF;
  
  -- ==========================================
  -- 8. GENERAR ID DE USUARIO
  -- ==========================================
  
  -- 8.1. Generar componente random (0-99)
  v_random := FLOOR(RANDOM() * 100)::INTEGER;
  
  -- 8.2. Calcular ID = (segundos_desde_2025 * 10) + random
  -- Epoch personalizado: 2025-01-01 para números más pequeños
  -- Precisión: 0.1 segundos (décimas de segundo)
  v_generated_id := ((EXTRACT(EPOCH FROM NOW()) - v_epoch_2025) * 10)::INTEGER + v_random;
  
  -- 8.3. Validar que el ID sea mayor al último (prevenir colisiones por reloj desincronizado)
  SELECT COALESCE(MAX(id_user), 0) INTO v_last_id FROM tab_users;
  
  IF v_generated_id <= v_last_id THEN
    msg := 'Error crítico: El reloj del servidor no está sincronizado. ID generado (' || v_generated_id || 
           ') no es mayor al último ID (' || v_last_id || '). Verificar sincronización NTP.';
    error_code := 'CLOCK_SYNC_ERROR';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  RAISE NOTICE '[fun_create_user] ID generado: %', v_generated_id;
  
  -- ==========================================
  -- 9. VALIDAR ROL PASAJERO EXISTE
  -- ==========================================
  
  SELECT EXISTS(
    SELECT 1 FROM tab_roles 
    WHERE id_role = 1 AND is_active = TRUE
  ) INTO v_role_exists;
  
  IF NOT v_role_exists THEN
    msg := 'Error: El rol de Pasajero (id_role = 1) no existe o está inactivo';
    error_code := 'ROLE_PASSENGER_NOT_FOUND';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 10. INSERTAR USUARIO EN TAB_USERS
  -- ==========================================
  
  BEGIN
    INSERT INTO tab_users (
      id_user,
      email,
      password_hash,
      full_name,
      avatar_url,
      user_create
    )
    VALUES (
      v_generated_id,
      v_email_clean,
      wpassword_hash,
      v_name_clean,
      wavatar_url,
      wuser_create
    );
    
    RAISE NOTICE '[fun_create_user] Usuario insertado en tab_users: %', v_generated_id;
    
  EXCEPTION
    WHEN unique_violation THEN
      msg := 'Error: El email ya está registrado (violación UNIQUE): ' || v_email_clean;
      error_code := 'USER_INSERT_UNIQUE_VIOLATION';
      RAISE NOTICE '[fun_create_user] ERROR: %', msg;
      RETURN;
      
    WHEN not_null_violation THEN
      msg := 'Error: Falta un campo obligatorio al crear el usuario';
      error_code := 'USER_INSERT_NOT_NULL_VIOLATION';
      RAISE NOTICE '[fun_create_user] ERROR: %', msg;
      RETURN;
      
    WHEN foreign_key_violation THEN
      msg := 'Error: Violación de clave foránea al crear el usuario (user_create inválido: ' || wuser_create || ')';
      error_code := 'USER_INSERT_FK_VIOLATION';
      RAISE NOTICE '[fun_create_user] ERROR: %', msg;
      RETURN;
      
    WHEN check_violation THEN
      msg := 'Error: Violación de restricción CHECK al crear el usuario (email format)';
      error_code := 'USER_INSERT_CHECK_VIOLATION';
      RAISE NOTICE '[fun_create_user] ERROR: %', msg;
      RETURN;
      
    WHEN OTHERS THEN
      msg := 'Error inesperado al insertar usuario: ' || SQLERRM;
      error_code := 'USER_INSERT_ERROR';
      RAISE NOTICE '[fun_create_user] ERROR: %', msg;
      RETURN;
  END;
  
  -- ==========================================
  -- 11. ASIGNAR ROL PASAJERO AUTOMÁTICAMENTE
  -- ==========================================
  
  BEGIN
    INSERT INTO tab_user_roles (
      id_user,
      id_role,
      assigned_by
    )
    VALUES (
      v_generated_id,
      1,  -- Rol Pasajero
      wuser_create
    );
    
    RAISE NOTICE '[fun_create_user] Rol Pasajero asignado al usuario: %', v_generated_id;
    
  EXCEPTION
    WHEN unique_violation THEN
      msg := 'Error: Violación UNIQUE al asignar rol (usuario ya tiene el rol)';
      error_code := 'USER_ROLE_INSERT_UNIQUE_VIOLATION';
      RAISE NOTICE '[fun_create_user] ERROR: %', msg;
      RETURN;
      
    WHEN foreign_key_violation THEN
      msg := 'Error: Violación FK al asignar rol (usuario o rol no existe)';
      error_code := 'USER_ROLE_INSERT_FK_VIOLATION';
      RAISE NOTICE '[fun_create_user] ERROR: %', msg;
      RETURN;
      
    WHEN OTHERS THEN
      msg := 'Error inesperado al asignar rol: ' || SQLERRM;
      error_code := 'USER_ROLE_INSERT_ERROR';
      RAISE NOTICE '[fun_create_user] ERROR: %', msg;
      RETURN;
  END;
  
  -- ==========================================
  -- 12. RETORNO EXITOSO
  -- ==========================================
  
  success := TRUE;
  msg := 'Usuario creado exitosamente con rol Pasajero';
  error_code := NULL;
  id_user := v_generated_id;
  
  RAISE NOTICE '[fun_create_user] Éxito: Usuario % creado con ID %', v_email_clean, v_generated_id;
  
END;
$$;

-- =============================================
-- COMENTARIOS FINALES
-- =============================================

COMMENT ON FUNCTION fun_create_user IS 
'v2.0 - Crea un nuevo usuario con validaciones completas y asigna automáticamente el rol de Pasajero.
Genera ID automáticamente usando timestamp de PostgreSQL + random.
Inserta en tab_users y tab_user_roles en una transacción atómica.
Valida: usuario creador, email (formato y unicidad), nombre (longitud y caracteres), password hash (formato bcrypt), avatar URL.
Retorna: success (BOOLEAN), msg (VARCHAR), error_code (VARCHAR), id_user (INTEGER).
Códigos de error: USER_CREATE_NOT_FOUND, NAME_NULL_EMPTY, NAME_TOO_SHORT, NAME_TOO_LONG, NAME_INVALID_CHARS, 
NAME_NO_LETTERS, EMAIL_NULL_EMPTY, EMAIL_INVALID_LENGTH, EMAIL_INVALID_FORMAT, EMAIL_DUPLICATE, 
PASSWORD_HASH_NULL_EMPTY, PASSWORD_HASH_INVALID_LENGTH, PASSWORD_HASH_INVALID_FORMAT, AVATAR_URL_TOO_LONG, 
AVATAR_URL_INVALID_FORMAT, CLOCK_SYNC_ERROR, ROLE_PASSENGER_NOT_FOUND, USER_INSERT_UNIQUE_VIOLATION, 
USER_INSERT_NOT_NULL_VIOLATION, USER_INSERT_FK_VIOLATION, USER_INSERT_CHECK_VIOLATION, USER_INSERT_ERROR, 
USER_ROLE_INSERT_UNIQUE_VIOLATION, USER_ROLE_INSERT_FK_VIOLATION, USER_ROLE_INSERT_ERROR.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================

/*
-- Ejemplo 1: Crear usuario básico (admin con ID 1)
SELECT * FROM fun_create_user(
  'juan@example.com',
  '$2b$10$abc123...',  -- Hash bcrypt real (60 caracteres)
  'Juan Pérez',
  NULL,                 -- Sin avatar
  1                     -- user_create (administrador)
);

-- Resultado exitoso:
-- success | msg                                     | error_code | id_user
-- TRUE    | Usuario creado exitosamente con rol... | NULL       | 36592847


-- Ejemplo 2: Crear usuario con avatar
SELECT * FROM fun_create_user(
  'maria.garcia@example.com',
  '$2b$10$xyz789...',
  'María García',
  'https://example.com/avatars/maria.jpg',
  1735689600  -- Sistema
);


-- Ejemplo 3: ERROR - Email duplicado
SELECT * FROM fun_create_user(
  'juan@example.com',  -- Ya existe
  '$2b$10$abc...',
  'Otro Usuario',
  NULL,
  1
);

-- Resultado:
-- success | msg                                  | error_code     | id_user
-- FALSE   | El email ya está registrado: juan... | EMAIL_DUPLICATE | NULL


-- Ejemplo 4: ERROR - Nombre con caracteres inválidos
SELECT * FROM fun_create_user(
  'test@example.com',
  '$2b$10$abc...',
  'User@123#',  -- Contiene @ y #
  NULL,
  1
);

-- Resultado:
-- success | msg                                     | error_code          | id_user
-- FALSE   | El nombre contiene caracteres no per... | NAME_INVALID_CHARS  | NULL


-- Ejemplo 5: ERROR - Email inválido
SELECT * FROM fun_create_user(
  'email_sin_arroba.com',  -- Falta @
  '$2b$10$abc...',
  'Test User',
  NULL,
  1
);

-- Resultado:
-- success | msg                        | error_code           | id_user
-- FALSE   | El email tiene formato ... | EMAIL_INVALID_FORMAT | NULL


-- Ejemplo 6: ERROR - Password hash inválido
SELECT * FROM fun_create_user(
  'test@example.com',
  'password123',  -- No es hash bcrypt (muy corto)
  'Test User',
  NULL,
  1
);

-- Resultado:
-- success | msg                                     | error_code                      | id_user
-- FALSE   | El password hash debe tener exacta... | PASSWORD_HASH_INVALID_LENGTH    | NULL


-- Ejemplo 7: ERROR - Usuario creador no existe
SELECT * FROM fun_create_user(
  'test@example.com',
  '$2b$10$abc...',
  'Test User',
  NULL,
  999999  -- Usuario inexistente
);

-- Resultado:
-- success | msg                                  | error_code              | id_user
-- FALSE   | El usuario creador no existe o es... | USER_CREATE_NOT_FOUND   | NULL


-- Ejemplo 8: Crear con nombre con acentos y apóstrofes (válido)
SELECT * FROM fun_create_user(
  'jose.oconnor@example.com',
  '$2b$10$abc...',
  'José María O''Connor-García',  -- Válido: acentos, apóstrofe, guion
  NULL,
  1
);

-- Resultado:
-- success | msg                                     | error_code | id_user
-- TRUE    | Usuario creado exitosamente con rol... | NULL       | 36592999


-- Ejemplo 9: ERROR - Avatar URL sin https://
SELECT * FROM fun_create_user(
  'test@example.com',
  '$2b$10$abc...',
  'Test User',
  'example.com/avatar.jpg',  -- Falta protocolo
  1
);

-- Resultado:
-- success | msg                                  | error_code                 | id_user
-- FALSE   | La URL del avatar debe comenzar ... | AVATAR_URL_INVALID_FORMAT  | NULL


-- Ejemplo 10: Verificar usuario creado (con JOIN a roles)
SELECT 
  u.id_user,
  u.email,
  u.full_name,
  u.avatar_url,
  r.role_name,
  u.created_at,
  u.is_active
FROM tab_users u
JOIN tab_user_roles ur ON u.id_user = ur.id_user
JOIN tab_roles r ON ur.id_role = r.id_role
WHERE u.email = 'juan@example.com';

*/

-- =============================================
-- FIN DE LA FUNCIÓN fun_create_user v2.0
-- =============================================
