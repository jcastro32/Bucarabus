-- =============================================
-- BucaraBUS - Función: Crear Nuevo Viaje/Turno
-- =============================================
-- Versión: 2.0
-- Fecha: Febrero 2025
-- Descripción: Crea un viaje/turno para una ruta en fecha y hora específicas
-- =============================================

-- Eliminar versiones anteriores
DROP FUNCTION IF EXISTS fun_create_trip(
    INTEGER, DATE, TIME, TIME, INTEGER, VARCHAR(6), VARCHAR(20)
);

-- =============================================
-- Función: fun_create_trip v2.0
-- =============================================
CREATE OR REPLACE FUNCTION fun_create_trip(
    wid_route        tab_trips.id_route%TYPE,
    wtrip_date       tab_trips.trip_date%TYPE,
    wstart_time      tab_trips.start_time%TYPE,
    wend_time        tab_trips.end_time%TYPE,
    wuser_create     tab_trips.user_create%TYPE,
    wplate_number    tab_trips.plate_number%TYPE DEFAULT NULL,
    wstatus_trip     tab_trips.status_trip%TYPE DEFAULT 'pending',
    OUT success      BOOLEAN,
    OUT msg          VARCHAR,
    OUT id_trip      BIGINT,
    OUT error_code   VARCHAR
)
LANGUAGE plpgsql AS $$

DECLARE
    v_user_exists       BOOLEAN;
    v_route_exists      BOOLEAN;
    v_route_active      BOOLEAN;
    v_bus_exists        BOOLEAN;
    v_bus_active        BOOLEAN;
    v_trip_exists       BOOLEAN;
    v_plate_normalized  VARCHAR(6);
    v_new_id            BIGINT;
    
BEGIN
    -- ====================================
    -- 1. INICIALIZACIÓN
    -- ====================================
    success := FALSE;
    msg := '';
    id_trip := NULL;
    error_code := NULL;

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
    -- 3. VALIDACIONES DE CAMPOS OBLIGATORIOS
    -- ====================================
    IF wid_route IS NULL THEN
        msg := 'El ID de ruta es obligatorio';
        error_code := 'ROUTE_ID_NULL';
        RETURN;
    END IF;

    IF wtrip_date IS NULL THEN
        msg := 'La fecha del viaje es obligatoria';
        error_code := 'TRIP_DATE_NULL';
        RETURN;
    END IF;

    IF wstart_time IS NULL THEN
        msg := 'La hora de inicio es obligatoria';
        error_code := 'START_TIME_NULL';
        RETURN;
    END IF;

    IF wend_time IS NULL THEN
        msg := 'La hora de fin es obligatoria';
        error_code := 'END_TIME_NULL';
        RETURN;
    END IF;

    -- ====================================
    -- 4. VALIDACIONES DE LÓGICA DE NEGOCIO
    -- ====================================
    
    -- Validar que hora fin > hora inicio
    IF wend_time <= wstart_time THEN
        msg := 'La hora de fin (' || wend_time || ') debe ser posterior a la hora de inicio (' || wstart_time || ')';
        error_code := 'INVALID_TIME_RANGE';
        RETURN;
    END IF;

    -- Validar fecha (no muy antigua según CHECK en schema)
    IF wtrip_date < CURRENT_DATE - INTERVAL '7 days' THEN
        msg := 'La fecha del viaje no puede ser anterior a ' || (CURRENT_DATE - INTERVAL '7 days')::DATE;
        error_code := 'TRIP_DATE_TOO_OLD';
        RETURN;
    END IF;

    -- Validar estado del viaje
    IF wstatus_trip NOT IN ('pending', 'assigned', 'active', 'completed', 'cancelled') THEN
        msg := 'Estado inválido "' || wstatus_trip || '". Debe ser: pending, assigned, active, completed o cancelled';
        error_code := 'STATUS_INVALID';
        RETURN;
    END IF;

    -- ====================================
    -- 5. VALIDAR EXISTENCIA Y ESTADO DE RUTA
    -- ====================================
    SELECT 
        EXISTS(SELECT 1 FROM tab_routes WHERE id_route = wid_route),
        COALESCE((SELECT status_route FROM tab_routes WHERE id_route = wid_route), FALSE)
    INTO v_route_exists, v_route_active;

    IF NOT v_route_exists THEN
        msg := 'La ruta con ID ' || wid_route || ' no existe';
        error_code := 'ROUTE_NOT_FOUND';
        RETURN;
    END IF;

    IF NOT v_route_active THEN
        msg := 'La ruta con ID ' || wid_route || ' está inactiva (status_route = FALSE)';
        error_code := 'ROUTE_INACTIVE';
        RETURN;
    END IF;

    -- ====================================
    -- 6. VALIDAR BUS (SI SE PROPORCIONA)
    -- ====================================
    IF wplate_number IS NOT NULL AND TRIM(wplate_number) != '' THEN
        v_plate_normalized := UPPER(TRIM(wplate_number));
        
        -- Validar formato de placa
        IF v_plate_normalized !~ '^[A-Z]{3}[0-9]{3}$' THEN
            msg := 'Formato de placa inválido "' || v_plate_normalized || '". Debe ser 3 letras + 3 números (ej: ABC123)';
            error_code := 'PLATE_INVALID_FORMAT';
            RETURN;
        END IF;
        
        SELECT 
            EXISTS(SELECT 1 FROM tab_buses WHERE plate_number = v_plate_normalized),
            COALESCE((SELECT is_active FROM tab_buses WHERE plate_number = v_plate_normalized), FALSE)
        INTO v_bus_exists, v_bus_active;

        IF NOT v_bus_exists THEN
            msg := 'El bus con placa ' || v_plate_normalized || ' no existe';
            error_code := 'BUS_NOT_FOUND';
            RETURN;
        END IF;

        IF NOT v_bus_active THEN
            msg := 'El bus con placa ' || v_plate_normalized || ' está inactivo (is_active = FALSE)';
            error_code := 'BUS_INACTIVE';
            RETURN;
        END IF;
    ELSE
        v_plate_normalized := NULL;
    END IF;

    -- ====================================
    -- 7. VALIDAR DUPLICADOS (UNIQUE CONSTRAINT)
    -- ====================================
    SELECT EXISTS(
        SELECT 1 FROM tab_trips 
        WHERE id_route = wid_route 
          AND trip_date = wtrip_date 
          AND start_time = wstart_time
    ) INTO v_trip_exists;

    IF v_trip_exists THEN
        msg := 'Ya existe un viaje para la ruta ' || wid_route || 
               ' en fecha ' || wtrip_date || 
               ' a las ' || wstart_time;
        error_code := 'TRIP_DUPLICATE';
        RETURN;
    END IF;

    -- ====================================
    -- 8. INSERTAR VIAJE
    -- ====================================
    BEGIN
        INSERT INTO tab_trips (
            id_route,
            trip_date,
            start_time,
            end_time,
            plate_number,
            status_trip,
            user_create
        ) VALUES (
            wid_route,
            wtrip_date,
            wstart_time,
            wend_time,
            v_plate_normalized,
            wstatus_trip,
            wuser_create
        )
        RETURNING tab_trips.id_trip INTO v_new_id;

        success := TRUE;
        id_trip := v_new_id;
        msg := 'Viaje creado exitosamente con ID: ' || v_new_id || ' para ruta ' || wid_route;
        error_code := NULL;

        RAISE NOTICE 'Viaje creado: ID=%, Ruta=%, Fecha=%, Hora=%', 
                     v_new_id, wid_route, wtrip_date, wstart_time;

    EXCEPTION
        WHEN unique_violation THEN
            msg := 'Ya existe un viaje con esa combinación de ruta, fecha y hora de inicio';
            error_code := 'TRIP_INSERT_UNIQUE_VIOLATION';
            RETURN;

        WHEN foreign_key_violation THEN
            msg := 'Error de clave foránea: ruta, bus o usuario inválido - ' || SQLERRM;
            error_code := 'TRIP_INSERT_FK_VIOLATION';
            RETURN;

        WHEN check_violation THEN
            msg := 'Violación de restricción CHECK: ' || SQLERRM;
            error_code := 'TRIP_INSERT_CHECK_VIOLATION';
            RETURN;

        WHEN OTHERS THEN
            msg := 'Error inesperado al insertar viaje: ' || SQLERRM;
            error_code := 'TRIP_INSERT_ERROR';
            RETURN;
    END;

END;
$$;

-- =============================================
-- Función: fun_create_trips_batch v2.0
-- Descripción: Crea múltiples viajes en lote para una ruta y fecha
-- =============================================

-- Eliminar versiones anteriores
DROP FUNCTION IF EXISTS fun_create_trips_batch(
    DECIMAL(3,0), DATE, JSONB, VARCHAR
);

CREATE OR REPLACE FUNCTION fun_create_trips_batch(
    wid_route        tab_trips.id_route%TYPE,
    wtrip_date       tab_trips.trip_date%TYPE,
    wtrips           JSONB,
    wuser_create     tab_trips.user_create%TYPE,
    OUT success      BOOLEAN,
    OUT msg          VARCHAR,
    OUT trips_created INTEGER,
    OUT trips_failed  INTEGER,
    OUT trip_ids     BIGINT[],
    OUT error_code   VARCHAR
)
LANGUAGE plpgsql AS $$

DECLARE
    v_user_exists       BOOLEAN;
    v_route_exists      BOOLEAN;
    v_route_active      BOOLEAN;
    v_trip              JSONB;
    v_start_time        TIME;
    v_end_time          TIME;
    v_plate_number      VARCHAR(6);
    v_status_trip       VARCHAR(20);
    v_plate_normalized  VARCHAR(6);
    v_new_id            BIGINT;
    v_created_count     INTEGER := 0;
    v_failed_count      INTEGER := 0;
    v_ids               BIGINT[] := ARRAY[]::BIGINT[];
    v_error_details     TEXT := '';
    
BEGIN
    -- ====================================
    -- 1. INICIALIZACIÓN
    -- ====================================
    success := FALSE;
    msg := '';
    trips_created := 0;
    trips_failed := 0;
    trip_ids := ARRAY[]::BIGINT[];
    error_code := NULL;

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
    -- 3. VALIDACIONES DE PARÁMETROS
    -- ====================================
    IF wid_route IS NULL THEN
        msg := 'El ID de ruta es obligatorio';
        error_code := 'ROUTE_ID_NULL';
        RETURN;
    END IF;

    IF wtrip_date IS NULL THEN
        msg := 'La fecha es obligatoria';
        error_code := 'TRIP_DATE_NULL';
        RETURN;
    END IF;

    IF wtrips IS NULL OR jsonb_array_length(wtrips) = 0 THEN
        msg := 'Debe proporcionar al menos un viaje en el array JSONB';
        error_code := 'TRIPS_ARRAY_EMPTY';
        RETURN;
    END IF;

    -- Validar fecha (no muy antigua)
    IF wtrip_date < CURRENT_DATE - INTERVAL '7 days' THEN
        msg := 'La fecha del viaje no puede ser anterior a ' || (CURRENT_DATE - INTERVAL '7 days')::DATE;
        error_code := 'TRIP_DATE_TOO_OLD';
        RETURN;
    END IF;

    -- ====================================
    -- 4. VALIDAR RUTA
    -- ====================================
    SELECT 
        EXISTS(SELECT 1 FROM tab_routes WHERE id_route = wid_route),
        COALESCE((SELECT status_route FROM tab_routes WHERE id_route = wid_route), FALSE)
    INTO v_route_exists, v_route_active;

    IF NOT v_route_exists THEN
        msg := 'La ruta con ID ' || wid_route || ' no existe';
        error_code := 'ROUTE_NOT_FOUND';
        RETURN;
    END IF;

    IF NOT v_route_active THEN
        msg := 'La ruta con ID ' || wid_route || ' está inactiva';
        error_code := 'ROUTE_INACTIVE';
        RETURN;
    END IF;

    -- ====================================
    -- 5. ITERAR Y CREAR VIAJES
    -- ====================================
    FOR v_trip IN SELECT * FROM jsonb_array_elements(wtrips)
    LOOP
        BEGIN
            -- Extraer campos del JSON
            v_start_time := (v_trip->>'start_time')::TIME;
            v_end_time := (v_trip->>'end_time')::TIME;
            v_plate_number := v_trip->>'plate_number';
            v_status_trip := COALESCE(v_trip->>'status_trip', 'pending');

            -- Validar horarios
            IF v_start_time IS NULL THEN
                RAISE EXCEPTION 'start_time es obligatorio';
            END IF;

            IF v_end_time IS NULL THEN
                RAISE EXCEPTION 'end_time es obligatorio';
            END IF;

            IF v_end_time <= v_start_time THEN
                RAISE EXCEPTION 'end_time debe ser posterior a start_time';
            END IF;

            -- Validar estado
            IF v_status_trip NOT IN ('pending', 'assigned', 'active', 'completed', 'cancelled') THEN
                RAISE EXCEPTION 'Estado inválido: %', v_status_trip;
            END IF;

            -- Normalizar placa si existe
            IF v_plate_number IS NOT NULL AND TRIM(v_plate_number) != '' THEN
                v_plate_normalized := UPPER(TRIM(v_plate_number));

                -- Validar formato
                IF v_plate_normalized !~ '^[A-Z]{3}[0-9]{3}$' THEN
                    RAISE EXCEPTION 'Formato de placa inválido: %', v_plate_normalized;
                END IF;

                -- Validar que existe y está activo
                IF NOT EXISTS(
                    SELECT 1 FROM tab_buses 
                    WHERE plate_number = v_plate_normalized 
                      AND is_active = TRUE
                ) THEN
                    RAISE EXCEPTION 'Bus % no existe o está inactivo', v_plate_normalized;
                END IF;
            ELSE
                v_plate_normalized := NULL;
            END IF;

            -- Insertar viaje
            INSERT INTO tab_trips (
                id_route,
                trip_date,
                start_time,
                end_time,
                plate_number,
                status_trip,
                user_create
            ) VALUES (
                wid_route,
                wtrip_date,
                v_start_time,
                v_end_time,
                v_plate_normalized,
                v_status_trip,
                wuser_create
            )
            RETURNING tab_trips.id_trip INTO v_new_id;

            v_ids := array_append(v_ids, v_new_id);
            v_created_count := v_created_count + 1;

            RAISE NOTICE 'Viaje % creado: ID=%, Hora=%', v_created_count, v_new_id, v_start_time;

        EXCEPTION
            WHEN OTHERS THEN
                v_failed_count := v_failed_count + 1;
                v_error_details := v_error_details || 
                                   'Viaje ' || v_start_time || ': ' || SQLERRM || '; ';
                RAISE NOTICE 'Error creando viaje %: %', v_start_time, SQLERRM;
        END;
    END LOOP;

    -- ====================================
    -- 6. RETORNAR RESULTADOS
    -- ====================================
    trips_created := v_created_count;
    trips_failed := v_failed_count;
    trip_ids := v_ids;

    IF v_created_count > 0 THEN
        success := TRUE;
        msg := 'Se crearon ' || v_created_count || ' viajes exitosamente';
        IF v_failed_count > 0 THEN
            msg := msg || ' (' || v_failed_count || ' fallaron)';
        END IF;
        error_code := NULL;
    ELSE
        success := FALSE;
        msg := 'No se pudo crear ningún viaje. Errores: ' || v_error_details;
        error_code := 'ALL_TRIPS_FAILED';
    END IF;

END;
$$;
