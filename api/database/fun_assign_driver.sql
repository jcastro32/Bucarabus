-- =============================================
-- Función: fun_assign_driver
-- Descripción: Asignar o desasignar conductor a un bus
-- =============================================
-- Version: 2.0 (Actualizada para bd_bucarabus v2.0)
-- Cambios:
-- - wuser_assign ahora es INTEGER (FK a tab_users)
-- - Validación de usuario asignador
-- - Normalización de placa
-- - Agregado user_create en INSERT de assignments
-- - Verificación de conductor ya asignado a otro bus
-- - Mejoras en manejo de errores y mensajes
-- =============================================

-- Eliminar versiones anteriores de la función
DROP FUNCTION IF EXISTS fun_assign_driver(VARCHAR, DECIMAL, VARCHAR);
DROP FUNCTION IF EXISTS fun_assign_driver(VARCHAR(6), DECIMAL(12,0), VARCHAR(50));
DROP FUNCTION IF EXISTS fun_assign_driver(VARCHAR, INTEGER, VARCHAR);
DROP FUNCTION IF EXISTS fun_assign_driver(VARCHAR(6), INTEGER, VARCHAR(50));
DROP FUNCTION IF EXISTS fun_assign_driver(VARCHAR(6), INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION fun_assign_driver(
    wplate_number      VARCHAR(6),
    wid_user           INTEGER,          -- ID del usuario conductor (id_user) o NULL para desasignar
    wuser_assign       INTEGER,          -- ID del usuario que hace la asignación
    OUT success        BOOLEAN,
    OUT msg            VARCHAR,
    OUT error_code     VARCHAR
) AS $$

DECLARE
    v_normalized_plate VARCHAR(6);
    v_bus_active       BOOLEAN;
    v_driver_active    BOOLEAN;
    v_driver_available BOOLEAN;
    v_current_driver   INTEGER;
    v_is_driver        BOOLEAN;
    v_user_exists      BOOLEAN;
    v_assigned_bus     VARCHAR(6);
BEGIN
    success := FALSE;
    msg := '';
    error_code := NULL;

    -- ====================================
    -- 1. VALIDACIONES INICIALES
    -- ====================================

    -- Validar parámetros obligatorios
    IF wplate_number IS NULL OR TRIM(wplate_number) = '' THEN
        msg := 'La placa del bus es obligatoria';
        error_code := 'INVALID_PLATE';
        RETURN;
    END IF;

    IF wuser_assign IS NULL THEN
        msg := 'El usuario que realiza la asignación es obligatorio';
        error_code := 'INVALID_USER_ASSIGN';
        RETURN;
    END IF;

    -- Normalizar placa
    v_normalized_plate := UPPER(TRIM(wplate_number));

    -- ✅ NUEVO: Validar que el usuario asignador existe y está activo
    SELECT EXISTS(SELECT 1 FROM tab_users WHERE id_user = wuser_assign AND is_active = TRUE)
    INTO v_user_exists;

    IF NOT v_user_exists THEN
        msg := 'El usuario que intenta realizar la asignación no existe o está inactivo (ID: ' || wuser_assign || ')';
        error_code := 'USER_ASSIGN_NOT_FOUND';
        RETURN;
    END IF;

    -- ====================================
    -- 2. VALIDAR BUS
    -- ====================================

    SELECT is_active, id_user 
    INTO v_bus_active, v_current_driver
    FROM tab_buses 
    WHERE plate_number = v_normalized_plate;
    
    IF NOT FOUND THEN
        msg := 'El bus con placa ' || v_normalized_plate || ' no existe';
        error_code := 'BUS_NOT_FOUND';
        RETURN;
    END IF;

    IF NOT v_bus_active THEN
        msg := 'El bus ' || v_normalized_plate || ' está inactivo';
        error_code := 'BUS_INACTIVE';
        RETURN;
    END IF;

    -- ====================================
    -- 3. VALIDAR NUEVO CONDUCTOR (si no es NULL)
    -- ====================================

    IF wid_user IS NOT NULL THEN
        -- Verificar que el usuario existe, es conductor y está activo
        SELECT 
            u.is_active,
            EXISTS(
                SELECT 1 
                FROM tab_user_roles ur 
                WHERE ur.id_user = wid_user 
                  AND ur.id_role = 2 
                  AND ur.is_active = TRUE
            )
        INTO v_driver_active, v_is_driver
        FROM tab_users u
        WHERE u.id_user = wid_user;

        IF NOT FOUND THEN
            msg := 'El conductor con ID ' || wid_user || ' no existe';
            error_code := 'DRIVER_NOT_FOUND';
            RETURN;
        END IF;

        IF NOT v_is_driver THEN
            msg := 'El usuario no tiene rol de conductor (ID: ' || wid_user || ')';
            error_code := 'NOT_A_DRIVER';
            RETURN;
        END IF;

        IF NOT v_driver_active THEN
            msg := 'El conductor está inactivo (ID: ' || wid_user || ')';
            error_code := 'DRIVER_INACTIVE';
            RETURN;
        END IF;

        -- Verificar que existe en tab_driver_details
        SELECT dd.available 
        INTO v_driver_available
        FROM tab_driver_details dd
        WHERE dd.id_user = wid_user;

        IF NOT FOUND THEN
            msg := 'No se encontraron detalles del conductor (ID: ' || wid_user || ')';
            error_code := 'DRIVER_DETAILS_NOT_FOUND';
            RETURN;
        END IF;

        -- ✅ MEJORADO: Verificar si ya está asignado a otro bus
        IF NOT v_driver_available THEN
            -- Buscar a qué bus está asignado
            SELECT plate_number INTO v_assigned_bus
            FROM tab_buses
            WHERE id_user = wid_user
              AND is_active = TRUE
            LIMIT 1;

            IF v_assigned_bus IS NOT NULL THEN
                msg := 'El conductor ya está asignado al bus ' || v_assigned_bus;
                error_code := 'DRIVER_ALREADY_ASSIGNED';
            ELSE
                msg := 'El conductor no está disponible';
                error_code := 'DRIVER_NOT_AVAILABLE';
            END IF;
            RETURN;
        END IF;
    END IF;

    -- ====================================
    -- 4. REALIZAR ASIGNACIÓN/DESASIGNACIÓN
    -- ====================================

    BEGIN
        -- 4.1. Actualizar el bus (asignar o desasignar conductor)
        UPDATE tab_buses SET
            id_user = wid_user,
            user_update = wuser_assign
        WHERE plate_number = v_normalized_plate;

        -- 4.2. Liberar conductor anterior (si existe Y es diferente al nuevo)
        IF v_current_driver IS NOT NULL AND (wid_user IS NULL OR v_current_driver != wid_user) THEN
            -- Cerrar asignación anterior
            UPDATE tab_bus_assignments SET
                unassigned_at = NOW(),
                unassigned_by = wuser_assign,
                user_update = wuser_assign
            WHERE plate_number = v_normalized_plate 
              AND id_user = v_current_driver
              AND unassigned_at IS NULL;

            -- Marcar conductor anterior como disponible
            UPDATE tab_driver_details SET
                available = TRUE
            WHERE id_user = v_current_driver;

            RAISE NOTICE 'Conductor anterior (ID: %) liberado del bus %', v_current_driver, v_normalized_plate;
        END IF;

        -- 4.3. Si hay nuevo conductor, registrar y marcar no disponible
        IF wid_user IS NOT NULL THEN
            -- ✅ CORREGIDO: Ahora incluye user_create
            INSERT INTO tab_bus_assignments (
                plate_number, 
                id_user, 
                assigned_by,
                user_create
            ) VALUES (
                v_normalized_plate, 
                wid_user, 
                wuser_assign,
                wuser_assign
            );

            -- Marcar conductor como no disponible
            UPDATE tab_driver_details SET
                available = FALSE
            WHERE id_user = wid_user;

            msg := 'Conductor (ID: ' || wid_user || ') asignado exitosamente al bus ' || v_normalized_plate;
            RAISE NOTICE 'Asignación creada: Bus=%, Conductor=%, AsignadoPor=%', 
                         v_normalized_plate, wid_user, wuser_assign;
        ELSE
            msg := 'Conductor removido del bus ' || v_normalized_plate;
            RAISE NOTICE 'Conductor desasignado del bus % por usuario %', v_normalized_plate, wuser_assign;
        END IF;

        success := TRUE;

    EXCEPTION
        WHEN unique_violation THEN
            success := FALSE;
            msg := 'Error: Ya existe una asignación activa para este bus y conductor';
            error_code := 'DUPLICATE_ASSIGNMENT';
            
        WHEN foreign_key_violation THEN
            success := FALSE;
            msg := 'Error: Referencia inválida (usuario o bus no existe)';
            error_code := 'FOREIGN_KEY_VIOLATION';
            
        WHEN OTHERS THEN
            success := FALSE;
            msg := 'Error inesperado: ' || SQLERRM;
            error_code := 'UNEXPECTED_ERROR';
            RAISE WARNING 'Error en fun_assign_driver: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
    END;

END;
$$ LANGUAGE plpgsql;

-- =============================================
-- Trigger: trg_check_driver_available
-- Descripción: Proteger consistencia del campo available
-- Evita que un conductor asignado sea marcado como disponible
-- =============================================

CREATE OR REPLACE FUNCTION trg_check_driver_available()
RETURNS TRIGGER AS $$
DECLARE
    v_assigned_bus VARCHAR(6);
BEGIN
    -- Si intentan cambiar available de FALSE a TRUE
    IF NEW.available = TRUE AND OLD.available = FALSE THEN
        -- Verificar si está asignado a algún bus
        SELECT plate_number INTO v_assigned_bus
        FROM tab_buses 
        WHERE id_user = NEW.id_user
          AND is_active = TRUE
        LIMIT 1;
        
        IF v_assigned_bus IS NOT NULL THEN
            RAISE EXCEPTION 'No se puede marcar como disponible: el conductor está asignado al bus % (ID conductor: %)', 
                            v_assigned_bus, NEW.id_user;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Eliminar triggers anteriores si existen
DROP TRIGGER IF EXISTS trg_drivers_available_check ON tab_drivers;
DROP TRIGGER IF EXISTS trg_driver_details_available_check ON tab_driver_details;

-- Crear trigger en tab_driver_details
CREATE TRIGGER trg_driver_details_available_check
BEFORE UPDATE OF available ON tab_driver_details
FOR EACH ROW 
WHEN (NEW.available IS DISTINCT FROM OLD.available)
EXECUTE FUNCTION trg_check_driver_available();

