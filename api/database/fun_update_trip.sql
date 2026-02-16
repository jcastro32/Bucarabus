-- =============================================
-- BucaraBUS - Función: Actualizar Viaje/Turno
-- =============================================
-- Versión: 2.0
-- Fecha: Febrero 2025
-- Descripción: Actualiza datos de un viaje existente (horarios, bus, estado)
-- =============================================

-- Eliminar versiones anteriores
DROP FUNCTION IF EXISTS fun_update_trip(BIGINT, INTEGER, TIME, TIME, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS fun_set_trip_bus(BIGINT, VARCHAR, INTEGER);

-- =============================================
-- Función: fun_update_trip v2.0
-- =============================================
CREATE OR REPLACE FUNCTION fun_update_trip(
    -- Identificador del viaje a actualizar
    wid_trip         tab_trips.id_trip%TYPE,
    
    -- Auditoría
    wuser_update     tab_trips.user_update%TYPE,
    
    -- Datos opcionales (NULL = mantener valor actual)
    wnew_start_time  tab_trips.start_time%TYPE DEFAULT NULL,
    wnew_end_time    tab_trips.end_time%TYPE DEFAULT NULL,
    wnew_plate       tab_trips.plate_number%TYPE DEFAULT NULL,
    wnew_status      tab_trips.status_trip%TYPE DEFAULT NULL,
    
    -- Parámetros de salida
    OUT success      BOOLEAN,
    OUT msg          VARCHAR,
    OUT error_code   VARCHAR,
    OUT id_trip      BIGINT
)
LANGUAGE plpgsql AS $$

DECLARE
    v_updater_exists    BOOLEAN;
    v_trip_exists       BOOLEAN;
    v_route_active      BOOLEAN;
    v_current_start     TIME;
    v_current_end       TIME;
    v_current_plate     VARCHAR(6);
    v_current_status    VARCHAR(20);
    v_current_route     INTEGER;
    v_final_start       TIME;
    v_final_end         TIME;
    v_plate_clean       VARCHAR(6);
    v_bus_exists        BOOLEAN;
    v_bus_active        BOOLEAN;
    v_rows_affected     INTEGER;
    v_status_clean      VARCHAR(20);
    v_has_changes       BOOLEAN := FALSE;
    
BEGIN
    -- ====================================
    -- 1. INICIALIZACIÓN
    -- ====================================
    success := FALSE;
    msg := '';
    error_code := NULL;
    id_trip := NULL;

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

    RAISE NOTICE '[fun_update_trip] Usuario actualizador validado: %', wuser_update;

    -- ====================================
    -- 3. VALIDACIÓN DEL VIAJE A ACTUALIZAR
    -- ====================================
    IF wid_trip IS NULL OR wid_trip <= 0 THEN
        msg := 'El ID del viaje es obligatorio y debe ser mayor que 0';
        error_code := 'TRIP_ID_INVALID';
        RETURN;
    END IF;

    -- Obtener datos actuales del viaje
    SELECT 
        EXISTS(SELECT 1 FROM tab_trips WHERE tab_trips.id_trip = wid_trip),
        start_time,
        end_time,
        plate_number,
        status_trip,
        id_route
    INTO 
        v_trip_exists,
        v_current_start,
        v_current_end,
        v_current_plate,
        v_current_status,
        v_current_route
    FROM tab_trips
    WHERE tab_trips.id_trip = wid_trip;

    IF NOT v_trip_exists OR v_current_start IS NULL THEN
        msg := 'El viaje con ID ' || wid_trip || ' no existe';
        error_code := 'TRIP_NOT_FOUND';
        RETURN;
    END IF;

    -- Verificar que la ruta del viaje está activa
    SELECT status_route INTO v_route_active
    FROM tab_routes
    WHERE id_route = v_current_route;
    
    IF NOT v_route_active THEN
        msg := 'No se puede actualizar el viaje porque la ruta (ID: ' || v_current_route || ') está inactiva';
        error_code := 'TRIP_ROUTE_INACTIVE';
        RETURN;
    END IF;

    RAISE NOTICE '[fun_update_trip] Viaje validado: % (Estado actual: %, Ruta: %)', 
        wid_trip, v_current_status, v_current_route;

    -- ====================================
    -- 4. VALIDACIONES Y NORMALIZACIÓN DE HORARIOS
    -- ====================================
    
    -- Calcular horarios finales
    v_final_start := COALESCE(wnew_start_time, v_current_start);
    v_final_end := COALESCE(wnew_end_time, v_current_end);
    
    -- Validar que hora fin > hora inicio
    IF v_final_end <= v_final_start THEN
        msg := 'La hora de fin (' || v_final_end || ') debe ser posterior a la hora de inicio (' || v_final_start || ')';
        error_code := 'INVALID_TIME_RANGE';
        RETURN;
    END IF;
    
    -- Marcar si hay cambios
    IF wnew_start_time IS NOT NULL AND wnew_start_time != v_current_start THEN
        v_has_changes := TRUE;
    END IF;
    
    IF wnew_end_time IS NOT NULL AND wnew_end_time != v_current_end THEN
        v_has_changes := TRUE;
    END IF;

    -- ====================================
    -- 5. VALIDACIONES Y NORMALIZACIÓN DE PLACA
    -- ====================================
    v_plate_clean := NULL;
    
    IF wnew_plate IS NOT NULL THEN
        -- String vacío = desasignar bus
        IF TRIM(wnew_plate) = '' THEN
            v_plate_clean := NULL;
            v_has_changes := TRUE;
        ELSE
            v_plate_clean := UPPER(TRIM(wnew_plate));
            
            -- Validar formato de placa
            IF v_plate_clean !~ '^[A-Z]{3}[0-9]{3}$' THEN
                msg := 'Formato de placa inválido "' || v_plate_clean || '". Debe ser 3 letras + 3 números (ej: ABC123)';
                error_code := 'PLATE_INVALID_FORMAT';
                RETURN;
            END IF;
            
            -- Validar que el bus existe
            SELECT 
                EXISTS(SELECT 1 FROM tab_buses WHERE plate_number = v_plate_clean),
                COALESCE((SELECT is_active FROM tab_buses WHERE plate_number = v_plate_clean), FALSE)
            INTO v_bus_exists, v_bus_active;
            
            IF NOT v_bus_exists THEN
                msg := 'El bus con placa ' || v_plate_clean || ' no existe';
                error_code := 'BUS_NOT_FOUND';
                RETURN;
            END IF;
            
            IF NOT v_bus_active THEN
                msg := 'El bus con placa ' || v_plate_clean || ' está inactivo (is_active = FALSE)';
                error_code := 'BUS_INACTIVE';
                RETURN;
            END IF;
            
            -- Marcar cambio si es diferente
            IF v_plate_clean != v_current_plate OR (v_current_plate IS NULL AND v_plate_clean IS NOT NULL) THEN
                v_has_changes := TRUE;
            END IF;
        END IF;
    END IF;

    -- ====================================
    -- 6. VALIDACIONES Y NORMALIZACIÓN DE ESTADO
    -- ====================================
    v_status_clean := NULL;
    
    IF wnew_status IS NOT NULL AND TRIM(wnew_status) != '' THEN
        v_status_clean := LOWER(TRIM(wnew_status));
        
        -- Validar estado
        IF v_status_clean NOT IN ('pending', 'assigned', 'active', 'completed', 'cancelled') THEN
            msg := 'Estado inválido "' || v_status_clean || '". Debe ser: pending, assigned, active, completed o cancelled';
            error_code := 'STATUS_INVALID';
            RETURN;
        END IF;
        
        -- Validar transiciones de estado
        -- No se puede volver de 'completed' o 'cancelled' a otros estados
        IF v_current_status IN ('completed', 'cancelled') AND v_status_clean NOT IN ('completed', 'cancelled') THEN
            msg := 'No se puede cambiar un viaje ' || v_current_status || ' a estado ' || v_status_clean;
            error_code := 'INVALID_STATUS_TRANSITION';
            RETURN;
        END IF;
        
        -- Si se asigna bus, estado debe ser 'assigned' o superior
        IF v_plate_clean IS NOT NULL AND v_status_clean = 'pending' THEN
            msg := 'No se puede asignar un bus a un viaje con estado "pending". Cambie el estado a "assigned"';
            error_code := 'STATUS_INCONSISTENT_WITH_BUS';
            RETURN;
        END IF;
        
        -- Si se quita bus, estado debe volver a 'pending'
        IF wnew_plate IS NOT NULL AND TRIM(wnew_plate) = '' AND v_status_clean != 'pending' THEN
            msg := 'Al desasignar el bus, el estado debe cambiar a "pending"';
            error_code := 'STATUS_MUST_BE_PENDING';
            RETURN;
        END IF;
        
        -- Marcar cambio si es diferente
        IF v_status_clean != v_current_status THEN
            v_has_changes := TRUE;
        END IF;
    END IF;

    -- ====================================
    -- 7. VERIFICAR QUE HAY CAMBIOS
    -- ====================================
    IF NOT v_has_changes THEN
        msg := 'No hay cambios para aplicar. Proporcione al menos un campo para actualizar (horarios, bus o estado)';
        error_code := 'NO_CHANGES';
        RETURN;
    END IF;

    RAISE NOTICE '[fun_update_trip] Cambios a aplicar - Horarios: %, Bus: %, Estado: %',
        CASE WHEN wnew_start_time IS NOT NULL OR wnew_end_time IS NOT NULL THEN 'SÍ' ELSE 'NO' END,
        CASE WHEN wnew_plate IS NOT NULL THEN 'SÍ' ELSE 'NO' END,
        CASE WHEN wnew_status IS NOT NULL THEN 'SÍ' ELSE 'NO' END;

    -- ====================================
    -- 8. ACTUALIZAR VIAJE
    -- ====================================
    BEGIN
        UPDATE tab_trips
        SET 
            start_time = COALESCE(wnew_start_time, start_time),
            end_time = COALESCE(wnew_end_time, end_time),
            plate_number = CASE 
                WHEN wnew_plate IS NOT NULL AND TRIM(wnew_plate) = '' THEN NULL
                WHEN v_plate_clean IS NOT NULL THEN v_plate_clean
                ELSE plate_number
            END,
            status_trip = COALESCE(v_status_clean, status_trip),
            updated_at = NOW(),
            user_update = wuser_update
        WHERE tab_trips.id_trip = wid_trip;
        
        GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
        
        IF v_rows_affected = 0 THEN
            msg := 'No se pudo actualizar el viaje (ID: ' || wid_trip || ')';
            error_code := 'TRIP_UPDATE_FAILED';
            RETURN;
        END IF;
        
        RAISE NOTICE '[fun_update_trip] Viaje actualizado: % (% fila afectada)', wid_trip, v_rows_affected;
        
    EXCEPTION
        WHEN unique_violation THEN
            msg := 'Error: Ya existe otro viaje con esa combinación de ruta, fecha y hora de inicio';
            error_code := 'TRIP_UPDATE_UNIQUE_VIOLATION';
            RETURN;
        WHEN foreign_key_violation THEN
            msg := 'Error de clave foránea al actualizar viaje: ' || SQLERRM;
            error_code := 'TRIP_UPDATE_FK_VIOLATION';
            RETURN;
        WHEN check_violation THEN
            msg := 'Error de restricción al actualizar viaje: ' || SQLERRM;
            error_code := 'TRIP_UPDATE_CHECK_VIOLATION';
            RETURN;
        WHEN OTHERS THEN
            msg := 'Error inesperado al actualizar viaje: ' || SQLERRM;
            error_code := 'TRIP_UPDATE_ERROR';
            RETURN;
    END;

    -- ====================================
    -- 9. ÉXITO - RETORNAR DATOS
    -- ====================================
    success := TRUE;
    id_trip := wid_trip;
    
    -- Construir mensaje descriptivo
    msg := 'Viaje ' || wid_trip || ' actualizado exitosamente';
    
    IF wnew_start_time IS NOT NULL OR wnew_end_time IS NOT NULL THEN
        msg := msg || '. Horario: ' || v_final_start || ' - ' || v_final_end;
    END IF;
    
    IF wnew_plate IS NOT NULL THEN
        IF TRIM(wnew_plate) = '' THEN
            msg := msg || '. Bus: DESASIGNADO';
        ELSE
            msg := msg || '. Bus: ' || v_plate_clean;
        END IF;
    END IF;
    
    IF wnew_status IS NOT NULL THEN
        msg := msg || '. Estado: ' || UPPER(v_status_clean);
    END IF;
    
    error_code := NULL;
    
    RAISE NOTICE '[fun_update_trip] Éxito: Viaje % actualizado', wid_trip;
    RETURN;

END;
$$;

-- =============================================
-- Función: fun_set_trip_bus v2.0
-- =============================================
-- Descripción: Asigna o desasigna un bus de un viaje
-- Si wplate_number = NULL o '' → desasigna
-- Si wplate_number = valor    → asigna
-- =============================================

CREATE OR REPLACE FUNCTION fun_set_trip_bus(
    -- Identificador del viaje
    wid_trip         tab_trips.id_trip%TYPE,
    
    -- Placa del bus (NULL o '' = desasignar)
    wplate_number    tab_trips.plate_number%TYPE,
    
    -- Auditoría
    wuser_update     tab_trips.user_update%TYPE,
    
    -- Parámetros de salida
    OUT success      BOOLEAN,
    OUT msg          VARCHAR,
    OUT error_code   VARCHAR,
    OUT id_trip      BIGINT
)
LANGUAGE plpgsql AS $$

DECLARE
    v_updater_exists    BOOLEAN;
    v_trip_exists       BOOLEAN;
    v_current_plate     VARCHAR(6);
    v_current_status    VARCHAR(20);
    v_route_active      BOOLEAN;
    v_current_route     INTEGER;
    v_plate_clean       VARCHAR(6);
    v_bus_exists        BOOLEAN;
    v_bus_active        BOOLEAN;
    v_new_status        VARCHAR(20);
    v_rows_affected     INTEGER;
    
BEGIN
    -- ====================================
    -- 1. INICIALIZACIÓN
    -- ====================================
    success := FALSE;
    msg := '';
    error_code := NULL;
    id_trip := NULL;

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

    -- ====================================
    -- 3. VALIDACIÓN DEL VIAJE
    -- ====================================
    IF wid_trip IS NULL OR wid_trip <= 0 THEN
        msg := 'El ID del viaje es obligatorio y debe ser mayor que 0';
        error_code := 'TRIP_ID_INVALID';
        RETURN;
    END IF;

    -- Obtener datos actuales del viaje
    SELECT 
        plate_number, 
        status_trip,
        id_route
    INTO v_current_plate, v_current_status, v_current_route
    FROM tab_trips
    WHERE tab_trips.id_trip = wid_trip;

    IF v_current_status IS NULL THEN
        msg := 'El viaje con ID ' || wid_trip || ' no existe';
        error_code := 'TRIP_NOT_FOUND';
        RETURN;
    END IF;

    -- Verificar que la ruta está activa
    SELECT status_route INTO v_route_active
    FROM tab_routes
    WHERE id_route = v_current_route;
    
    IF NOT v_route_active THEN
        msg := 'No se puede modificar el viaje porque la ruta (ID: ' || v_current_route || ') está inactiva';
        error_code := 'TRIP_ROUTE_INACTIVE';
        RETURN;
    END IF;

    -- Validar que el viaje no esté completado o cancelado
    IF v_current_status IN ('completed', 'cancelled') THEN
        msg := 'No se puede modificar el bus de un viaje con estado "' || v_current_status || '"';
        error_code := 'TRIP_ALREADY_FINALIZED';
        RETURN;
    END IF;

    -- ====================================
    -- 4. DESASIGNAR BUS (plate NULL o vacío)
    -- ====================================
    IF wplate_number IS NULL OR TRIM(wplate_number) = '' THEN
        IF v_current_plate IS NULL THEN
            msg := 'El viaje no tiene bus asignado actualmente';
            error_code := 'NO_BUS_ASSIGNED';
            RETURN;
        END IF;

        BEGIN
            UPDATE tab_trips
            SET plate_number = NULL,
                status_trip = 'pending',
                updated_at = NOW(),
                user_update = wuser_update
            WHERE tab_trips.id_trip = wid_trip;
            
            GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
            
            IF v_rows_affected = 0 THEN
                msg := 'No se pudo desasignar el bus del viaje (ID: ' || wid_trip || ')';
                error_code := 'TRIP_UPDATE_FAILED';
                RETURN;
            END IF;
            
        EXCEPTION
            WHEN OTHERS THEN
                msg := 'Error al desasignar bus: ' || SQLERRM;
                error_code := 'TRIP_UNASSIGN_ERROR';
                RETURN;
        END;

        success := TRUE;
        id_trip := wid_trip;
        msg := 'Bus ' || v_current_plate || ' desasignado del viaje ' || wid_trip || '. Estado: PENDING';
        error_code := NULL;
        RETURN;
    END IF;

    -- ====================================
    -- 5. ASIGNAR BUS (plate tiene valor)
    -- ====================================
    v_plate_clean := UPPER(TRIM(wplate_number));
    
    -- Validar formato de placa
    IF v_plate_clean !~ '^[A-Z]{3}[0-9]{3}$' THEN
        msg := 'Formato de placa inválido "' || v_plate_clean || '". Debe ser 3 letras + 3 números (ej: ABC123)';
        error_code := 'PLATE_INVALID_FORMAT';
        RETURN;
    END IF;
    
    -- Validar que el bus existe y está activo
    SELECT 
        EXISTS(SELECT 1 FROM tab_buses WHERE plate_number = v_plate_clean),
        COALESCE((SELECT is_active FROM tab_buses WHERE plate_number = v_plate_clean), FALSE)
    INTO v_bus_exists, v_bus_active;

    IF NOT v_bus_exists THEN
        msg := 'El bus con placa ' || v_plate_clean || ' no existe';
        error_code := 'BUS_NOT_FOUND';
        RETURN;
    END IF;

    IF NOT v_bus_active THEN
        msg := 'El bus con placa ' || v_plate_clean || ' está inactivo (is_active = FALSE)';
        error_code := 'BUS_INACTIVE';
        RETURN;
    END IF;

    -- Verificar si ya tiene el mismo bus
    IF v_current_plate = v_plate_clean THEN
        msg := 'El viaje ya tiene asignado el bus ' || v_plate_clean;
        error_code := 'SAME_BUS_ASSIGNED';
        RETURN;
    END IF;

    -- Asignar bus y cambiar estado a 'assigned'
    BEGIN
        UPDATE tab_trips
        SET plate_number = v_plate_clean,
            status_trip = 'assigned',
            updated_at = NOW(),
            user_update = wuser_update
        WHERE tab_trips.id_trip = wid_trip;
        
        GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
        
        IF v_rows_affected = 0 THEN
            msg := 'No se pudo asignar el bus al viaje (ID: ' || wid_trip || ')';
            error_code := 'TRIP_UPDATE_FAILED';
            RETURN;
        END IF;
        
    EXCEPTION
        WHEN unique_violation THEN
            msg := 'Error: Conflicto con otra asignación de bus';
            error_code := 'TRIP_ASSIGN_UNIQUE_VIOLATION';
            RETURN;
        WHEN OTHERS THEN
            msg := 'Error al asignar bus: ' || SQLERRM;
            error_code := 'TRIP_ASSIGN_ERROR';
            RETURN;
    END;

    success := TRUE;
    id_trip := wid_trip;
    error_code := NULL;
    
    IF v_current_plate IS NOT NULL THEN
        msg := 'Bus cambiado de ' || v_current_plate || ' a ' || v_plate_clean || ' en viaje ' || wid_trip || '. Estado: ASSIGNED';
    ELSE
        msg := 'Bus ' || v_plate_clean || ' asignado al viaje ' || wid_trip || '. Estado: ASSIGNED';
    END IF;
    
    RAISE NOTICE '[fun_set_trip_bus] Éxito: Bus % asignado a viaje %', v_plate_clean, wid_trip;
    RETURN;

END;
$$;

-- =============================================
-- DOCUMENTACIÓN
-- =============================================

COMMENT ON FUNCTION fun_update_trip IS 'Actualiza datos de un viaje existente (horarios, bus, estado). Versión 2.0 con validaciones completas y manejo estructurado de errores.';

COMMENT ON FUNCTION fun_set_trip_bus IS 'Asigna o desasigna un bus de un viaje. Si plate_number es NULL o vacío, desasigna el bus y cambia estado a "pending". Si tiene valor, asigna el bus y cambia estado a "assigned". Versión 2.0.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================

/*
-- ==========================
-- fun_update_trip - Ejemplo 1: Actualizar horarios
-- ==========================
SELECT * FROM fun_update_trip(
    1,                          -- wid_trip
    '08:00:00'::TIME,          -- wnew_start_time
    '10:00:00'::TIME,          -- wnew_end_time
    NULL,                       -- wnew_plate (no cambiar)
    NULL,                       -- wnew_status (no cambiar)
    1735689600                  -- wuser_update
);
-- Resultado: success=TRUE, msg incluye horarios actualizados

-- ==========================
-- fun_update_trip - Ejemplo 2: Asignar bus
-- ==========================
SELECT * FROM fun_update_trip(
    1,
    NULL,                       -- No cambiar horario
    NULL,
    'ABC123',                   -- wnew_plate (asignar bus)
    'assigned',                 -- wnew_status (cambiar a assigned)
    1735689600
);
-- Resultado: bus asignado, estado cambiado

-- ==========================
-- fun_update_trip - Ejemplo 3: Desasignar bus
-- ==========================
SELECT * FROM fun_update_trip(
    1,
    NULL,
    NULL,
    '',                         -- String vacío = desasignar
    'pending',                  -- Volver a pending
    1735689600
);
-- Resultado: bus desasignado

-- ==========================
-- fun_update_trip - Ejemplo 4: Error - No hay cambios
-- ==========================
SELECT * FROM fun_update_trip(
    1,
    NULL,                       -- Todos NULL
    NULL,
    NULL,
    NULL,
    1735689600
);
-- Resultado: success=FALSE, error_code='NO_CHANGES'

-- ==========================
-- fun_update_trip - Ejemplo 5: Error - Transición inválida
-- ==========================
-- (Intentar cambiar viaje completado a pending)
SELECT * FROM fun_update_trip(
    1,
    NULL,
    NULL,
    NULL,
    'pending',                  -- Viaje está 'completed'
    1735689600
);
-- Resultado: success=FALSE, error_code='INVALID_STATUS_TRANSITION'

-- ==========================
-- fun_update_trip - Ejemplo 6: Error - Bus inactivo
-- ==========================
SELECT * FROM fun_update_trip(
    1,
    NULL,
    NULL,
    'XYZ999',                   -- Bus inactivo
    'assigned',
    1735689600
);
-- Resultado: success=FALSE, error_code='BUS_INACTIVE'

-- ==========================
-- fun_set_trip_bus - Ejemplo 1: Asignar bus
-- ==========================
SELECT * FROM fun_set_trip_bus(
    1,                          -- wid_trip
    'ABC123',                   -- wplate_number (asignar)
    1735689600                  -- wuser_update
);
-- Resultado: success=TRUE, msg='Bus ABC123 asignado al viaje 1. Estado: ASSIGNED'

-- ==========================
-- fun_set_trip_bus - Ejemplo 2: Desasignar bus
-- ==========================
SELECT * FROM fun_set_trip_bus(
    1,
    NULL,                       -- NULL = desasignar
    1735689600
);
-- Resultado: success=TRUE, msg='Bus ABC123 desasignado del viaje 1. Estado: PENDING'

-- ==========================
-- fun_set_trip_bus - Ejemplo 3: Error - Mismo bus
-- ==========================
SELECT * FROM fun_set_trip_bus(
    1,
    'ABC123',                   -- Ya tiene este bus asignado
    1735689600
);
-- Resultado: success=FALSE, error_code='SAME_BUS_ASSIGNED'

-- ==========================
-- fun_set_trip_bus - Ejemplo 4: Error - No tiene bus
-- ==========================
SELECT * FROM fun_set_trip_bus(
    1,
    '',                         -- Intentar desasignar pero no tiene bus
    1735689600
);
-- Resultado: success=FALSE, error_code='NO_BUS_ASSIGNED'
*/
