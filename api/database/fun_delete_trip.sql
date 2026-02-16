-- =============================================
-- FUNCIÓN: fun_delete_trip v2.0
-- =============================================
-- Descripción: Elimina (cancela) un viaje mediante soft delete
--              Cambia status_trip a 'cancelled' y libera el bus asignado
-- 
-- Parámetros IN:
--   wid_trip       - ID del viaje a eliminar (BIGINT)
--   wuser_delete   - ID del usuario que hace la eliminación (INTEGER)
--
-- Parámetros OUT:
--   success        - TRUE si el viaje se eliminó exitosamente
--   msg            - Mensaje descriptivo del resultado
--   error_code     - Código de error (NULL si success = TRUE)
--
-- Uso:
--   SELECT * FROM fun_delete_trip(123, 1);
--
-- Retorna: (success, msg, error_code)
--
-- Versión: 2.0
-- Fecha: 2026-02-16
-- =============================================

-- Eliminar funciones anteriores (diferentes firmas)
DROP FUNCTION IF EXISTS fun_delete_trip(BIGINT);
DROP FUNCTION IF EXISTS fun_delete_trip(tab_trips.id_trip%TYPE, tab_trips.user_update%TYPE);

CREATE OR REPLACE FUNCTION fun_delete_trip(
  wid_trip       tab_trips.id_trip%TYPE,
  wuser_delete   tab_trips.user_update%TYPE,
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
  v_deleter_exists BOOLEAN;
  v_trip_exists    BOOLEAN;
  v_trip_status    tab_trips.status_trip%TYPE;
  
  -- Variables para información del viaje
  v_route_id       tab_trips.id_route%TYPE;
  v_trip_date      tab_trips.trip_date%TYPE;
  v_start_time     tab_trips.start_time%TYPE;
  v_assigned_plate tab_trips.plate_number%TYPE;
  
  -- Variables para UPDATE
  v_rows_affected  INTEGER;

BEGIN
  -- ==========================================
  -- 2. INICIALIZACIÓN
  -- ==========================================
  
  success := FALSE;
  msg := '';
  error_code := NULL;
  
  RAISE NOTICE '[fun_delete_trip] Iniciando eliminación de viaje: ID=%', wid_trip;
  
  -- ==========================================
  -- 3. VALIDAR USUARIO QUE HACE LA ELIMINACIÓN
  -- ==========================================
  
  SELECT EXISTS(
    SELECT 1 FROM tab_users 
    WHERE id_user = wuser_delete AND is_active = TRUE
  ) INTO v_deleter_exists;
  
  IF NOT v_deleter_exists THEN
    msg := 'El usuario que intenta eliminar no existe o está inactivo (ID: ' || wuser_delete || ')';
    error_code := 'USER_DELETE_NOT_FOUND';
    RAISE NOTICE '[fun_delete_trip] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 4. VALIDAR QUE EL VIAJE EXISTE
  -- ==========================================
  
  SELECT 
    status_trip,
    id_route,
    trip_date,
    start_time,
    plate_number
  INTO 
    v_trip_status,
    v_route_id,
    v_trip_date,
    v_start_time,
    v_assigned_plate
  FROM tab_trips
  WHERE id_trip = wid_trip;
  
  IF NOT FOUND THEN
    msg := 'No existe el viaje con ID: ' || wid_trip;
    error_code := 'TRIP_NOT_FOUND';
    RAISE NOTICE '[fun_delete_trip] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 5. VALIDAR ESTADO DEL VIAJE
  -- ==========================================
  
  -- 5.1. Validar que no esté activo
  IF v_trip_status = 'active' THEN
    msg := 'No se puede eliminar un viaje en curso (status: active). ID: ' || wid_trip;
    error_code := 'TRIP_ACTIVE_CANNOT_DELETE';
    RAISE NOTICE '[fun_delete_trip] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- 5.2. Validar que no esté ya cancelado
  IF v_trip_status = 'cancelled' THEN
    msg := 'El viaje con ID ' || wid_trip || ' ya está cancelado';
    error_code := 'TRIP_ALREADY_CANCELLED';
    RAISE NOTICE '[fun_delete_trip] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- 5.3. Permitir eliminar: pending, assigned, completed
  -- Los viajes completados se pueden cancelar para correcciones
  
  -- ==========================================
  -- 6. SOFT DELETE - CANCELAR VIAJE
  -- ==========================================
  
  BEGIN
    UPDATE tab_trips
    SET status_trip = 'cancelled',
        plate_number = NULL,  -- Liberar bus asignado
        updated_at = NOW(),
        user_update = wuser_delete
    WHERE id_trip = wid_trip;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    IF v_rows_affected = 0 THEN
      msg := 'No se pudo cancelar el viaje (ID: ' || wid_trip || ')';
      error_code := 'TRIP_UPDATE_FAILED';
      RAISE NOTICE '[fun_delete_trip] ERROR: %', msg;
      RETURN;
    END IF;
    
    RAISE NOTICE '[fun_delete_trip] Viaje cancelado: ID=%', wid_trip;
    
  EXCEPTION
    WHEN foreign_key_violation THEN
      msg := 'Error: Violación de clave foránea al cancelar el viaje (user_update inválido)';
      error_code := 'TRIP_UPDATE_FK_VIOLATION';
      RAISE NOTICE '[fun_delete_trip] ERROR: %', msg;
      RETURN;
      
    WHEN check_violation THEN
      msg := 'Error: Violación de restricción CHECK al cancelar el viaje';
      error_code := 'TRIP_UPDATE_CHECK_VIOLATION';
      RAISE NOTICE '[fun_delete_trip] ERROR: %', msg;
      RETURN;
      
    WHEN OTHERS THEN
      msg := 'Error inesperado al cancelar el viaje: ' || SQLERRM;
      error_code := 'TRIP_UPDATE_ERROR';
      RAISE NOTICE '[fun_delete_trip] ERROR: %', msg;
      RETURN;
  END;
  
  -- ==========================================
  -- 7. RETORNO EXITOSO
  -- ==========================================
  
  success := TRUE;
  msg := 'Viaje eliminado exitosamente (cancelado): Ruta ' || v_route_id || 
         ', Fecha ' || v_trip_date || ', Hora ' || v_start_time;
  IF v_assigned_plate IS NOT NULL THEN
    msg := msg || ', Bus ' || v_assigned_plate || ' liberado';
  END IF;
  error_code := NULL;
  
  RAISE NOTICE '[fun_delete_trip] Éxito: Viaje % cancelado por usuario %', wid_trip, wuser_delete;
  
END;
$$;


-- =============================================
-- FUNCIÓN: fun_delete_trips_by_date v2.0
-- =============================================
-- Descripción: Elimina (cancela) todos los viajes de una ruta en una fecha específica
--              mediante soft delete. Cambia status_trip a 'cancelled'
-- 
-- Parámetros IN:
--   wid_route      - ID de la ruta (INTEGER)
--   wtrip_date     - Fecha de los viajes (DATE)
--   wuser_delete   - ID del usuario que hace la eliminación (INTEGER)
--
-- Parámetros OUT:
--   success        - TRUE si los viajes se eliminaron exitosamente
--   msg            - Mensaje descriptivo del resultado
--   error_code     - Código de error (NULL si success = TRUE)
--   trips_deleted  - Número de viajes cancelados
--
-- Uso:
--   SELECT * FROM fun_delete_trips_by_date(1, '2026-02-20', 1);
--
-- Retorna: (success, msg, error_code, trips_deleted)
--
-- Versión: 2.0
-- Fecha: 2026-02-16
-- =============================================

-- Eliminar funciones anteriores (diferentes firmas)
DROP FUNCTION IF EXISTS fun_delete_trips_by_date(INTEGER, DATE);
DROP FUNCTION IF EXISTS fun_delete_trips_by_date(tab_trips.id_route%TYPE, tab_trips.trip_date%TYPE, tab_trips.user_update%TYPE);

CREATE OR REPLACE FUNCTION fun_delete_trips_by_date(
  wid_route      tab_trips.id_route%TYPE,
  wtrip_date     tab_trips.trip_date%TYPE,
  wuser_delete   tab_trips.user_update%TYPE,
  OUT success    BOOLEAN,
  OUT msg        VARCHAR,
  OUT error_code VARCHAR,
  OUT trips_deleted INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
  -- ==========================================
  -- 1. SECCIÓN DE VARIABLES
  -- ==========================================
  
  -- Variables de validación
  v_deleter_exists BOOLEAN;
  v_route_exists   BOOLEAN;
  v_route_active   BOOLEAN;
  
  -- Variables para conteo
  v_count_total    INTEGER;
  v_count_active   INTEGER;
  v_count_cancelled INTEGER;
  v_count_pending  INTEGER;
  v_count_assigned INTEGER;
  v_count_completed INTEGER;
  
  -- Variables para UPDATE
  v_rows_affected  INTEGER;

BEGIN
  -- ==========================================
  -- 2. INICIALIZACIÓN
  -- ==========================================
  
  success := FALSE;
  msg := '';
  error_code := NULL;
  trips_deleted := 0;
  
  RAISE NOTICE '[fun_delete_trips_by_date] Iniciando eliminación masiva: Ruta=%, Fecha=%', wid_route, wtrip_date;
  
  -- ==========================================
  -- 3. VALIDAR USUARIO QUE HACE LA ELIMINACIÓN
  -- ==========================================
  
  SELECT EXISTS(
    SELECT 1 FROM tab_users 
    WHERE id_user = wuser_delete AND is_active = TRUE
  ) INTO v_deleter_exists;
  
  IF NOT v_deleter_exists THEN
    msg := 'El usuario que intenta eliminar no existe o está inactivo (ID: ' || wuser_delete || ')';
    error_code := 'USER_DELETE_NOT_FOUND';
    RAISE NOTICE '[fun_delete_trips_by_date] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 4. VALIDAR PARÁMETROS
  -- ==========================================
  
  -- 4.1. Validar id_route
  IF wid_route IS NULL THEN
    msg := 'El ID de ruta es obligatorio';
    error_code := 'ROUTE_ID_NULL';
    RAISE NOTICE '[fun_delete_trips_by_date] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- 4.2. Validar trip_date
  IF wtrip_date IS NULL THEN
    msg := 'La fecha del viaje es obligatoria';
    error_code := 'TRIP_DATE_NULL';
    RAISE NOTICE '[fun_delete_trips_by_date] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 5. VALIDAR QUE LA RUTA EXISTE
  -- ==========================================
  
  SELECT EXISTS(
    SELECT 1 FROM tab_routes 
    WHERE id_route = wid_route
  ), COALESCE(
    (SELECT status_route FROM tab_routes WHERE id_route = wid_route), 
    FALSE
  )
  INTO v_route_exists, v_route_active;
  
  IF NOT v_route_exists THEN
    msg := 'No existe la ruta con ID: ' || wid_route;
    error_code := 'ROUTE_NOT_FOUND';
    RAISE NOTICE '[fun_delete_trips_by_date] ERROR: %', msg;
    RETURN;
  END IF;
  
  IF NOT v_route_active THEN
    msg := 'La ruta con ID ' || wid_route || ' está inactiva';
    error_code := 'ROUTE_INACTIVE';
    RAISE NOTICE '[fun_delete_trips_by_date] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 6. CONTAR VIAJES POR ESTADO
  -- ==========================================
  
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE status_trip = 'active'),
    COUNT(*) FILTER (WHERE status_trip = 'cancelled'),
    COUNT(*) FILTER (WHERE status_trip = 'pending'),
    COUNT(*) FILTER (WHERE status_trip = 'assigned'),
    COUNT(*) FILTER (WHERE status_trip = 'completed')
  INTO 
    v_count_total,
    v_count_active,
    v_count_cancelled,
    v_count_pending,
    v_count_assigned,
    v_count_completed
  FROM tab_trips
  WHERE id_route = wid_route
    AND trip_date = wtrip_date;
  
  -- ==========================================
  -- 7. VALIDAR QUE HAY VIAJES
  -- ==========================================
  
  IF v_count_total = 0 THEN
    msg := 'No hay viajes para la ruta ' || wid_route || ' en la fecha ' || wtrip_date;
    error_code := 'NO_TRIPS_FOUND';
    RAISE NOTICE '[fun_delete_trips_by_date] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 8. VALIDAR QUE NO HAY VIAJES ACTIVOS
  -- ==========================================
  
  IF v_count_active > 0 THEN
    msg := 'No se pueden eliminar: hay ' || v_count_active || ' viaje(s) activo(s) en curso. ' ||
           'Los viajes activos no se pueden cancelar';
    error_code := 'HAS_ACTIVE_TRIPS';
    RAISE NOTICE '[fun_delete_trips_by_date] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 9. VALIDAR SI YA ESTÁN TODOS CANCELADOS
  -- ==========================================
  
  IF v_count_cancelled = v_count_total THEN
    msg := 'Todos los viajes (' || v_count_total || ') ya están cancelados para la ruta ' || 
           wid_route || ' en la fecha ' || wtrip_date;
    error_code := 'ALL_TRIPS_ALREADY_CANCELLED';
    RAISE NOTICE '[fun_delete_trips_by_date] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 10. SOFT DELETE - CANCELAR VIAJES
  -- ==========================================
  
  BEGIN
    UPDATE tab_trips
    SET status_trip = 'cancelled',
        plate_number = NULL,  -- Liberar buses asignados
        updated_at = NOW(),
        user_update = wuser_delete
    WHERE id_route = wid_route
      AND trip_date = wtrip_date
      AND status_trip != 'cancelled'  -- No actualizar los ya cancelados
      AND status_trip != 'active';    -- No cancelar activos (ya validado)
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    trips_deleted := v_rows_affected;
    
    IF v_rows_affected = 0 THEN
      msg := 'No se pudo cancelar ningún viaje';
      error_code := 'TRIPS_UPDATE_FAILED';
      RAISE NOTICE '[fun_delete_trips_by_date] ERROR: %', msg;
      RETURN;
    END IF;
    
    RAISE NOTICE '[fun_delete_trips_by_date] % viajes cancelados', v_rows_affected;
    
  EXCEPTION
    WHEN foreign_key_violation THEN
      msg := 'Error: Violación de clave foránea al cancelar viajes';
      error_code := 'TRIPS_UPDATE_FK_VIOLATION';
      RAISE NOTICE '[fun_delete_trips_by_date] ERROR: %', msg;
      RETURN;
      
    WHEN check_violation THEN
      msg := 'Error: Violación de restricción CHECK al cancelar viajes';
      error_code := 'TRIPS_UPDATE_CHECK_VIOLATION';
      RAISE NOTICE '[fun_delete_trips_by_date] ERROR: %', msg;
      RETURN;
      
    WHEN OTHERS THEN
      msg := 'Error inesperado al cancelar viajes: ' || SQLERRM;
      error_code := 'TRIPS_UPDATE_ERROR';
      RAISE NOTICE '[fun_delete_trips_by_date] ERROR: %', msg;
      RETURN;
  END;
  
  -- ==========================================
  -- 11. RETORNO EXITOSO
  -- ==========================================
  
  success := TRUE;
  msg := 'Se cancelaron ' || trips_deleted || ' viaje(s) de la ruta ' || wid_route || 
         ' para el ' || wtrip_date;
  
  -- Agregar estadísticas al mensaje
  IF v_count_cancelled > 0 THEN
    msg := msg || '. (' || v_count_cancelled || ' ya estaban cancelados)';
  END IF;
  
  IF v_count_completed > 0 THEN
    msg := msg || '. (' || v_count_completed || ' completados también fueron cancelados)';
  END IF;
  
  error_code := NULL;
  
  RAISE NOTICE '[fun_delete_trips_by_date] Éxito: % viajes cancelados por usuario %', 
               trips_deleted, wuser_delete;
  
END;
$$;


-- =============================================
-- FUNCIÓN: fun_cancel_trip v2.0
-- =============================================
-- Descripción: Cancela un viaje específico mediante soft delete
--              Cambia status_trip a 'cancelled' y libera el bus asignado
--              (Esta función es similar a fun_delete_trip pero con nombre más descriptivo)
-- 
-- Parámetros IN:
--   wid_trip       - ID del viaje a cancelar (BIGINT)
--   wuser_cancel   - ID del usuario que hace la cancelación (INTEGER)
--
-- Parámetros OUT:
--   success        - TRUE si el viaje se canceló exitosamente
--   msg            - Mensaje descriptivo del resultado
--   error_code     - Código de error (NULL si success = TRUE)
--
-- Uso:
--   SELECT * FROM fun_cancel_trip(123, 1);
--
-- Retorna: (success, msg, error_code)
--
-- Versión: 2.0
-- Fecha: 2026-02-16
-- =============================================

-- Eliminar funciones anteriores (diferentes firmas)
DROP FUNCTION IF EXISTS fun_cancel_trip(BIGINT, INTEGER);
DROP FUNCTION IF EXISTS fun_cancel_trip(tab_trips.id_trip%TYPE, tab_trips.user_update%TYPE);

CREATE OR REPLACE FUNCTION fun_cancel_trip(
  wid_trip       tab_trips.id_trip%TYPE,
  wuser_cancel   tab_trips.user_update%TYPE,
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
  v_canceller_exists BOOLEAN;
  v_trip_exists      BOOLEAN;
  v_trip_status      tab_trips.status_trip%TYPE;
  
  -- Variables para información del viaje
  v_route_id         tab_trips.id_route%TYPE;
  v_trip_date        tab_trips.trip_date%TYPE;
  v_start_time       tab_trips.start_time%TYPE;
  v_end_time         tab_trips.end_time%TYPE;
  v_assigned_plate   tab_trips.plate_number%TYPE;
  
  -- Variables para UPDATE
  v_rows_affected    INTEGER;

BEGIN
  -- ==========================================
  -- 2. INICIALIZACIÓN
  -- ==========================================
  
  success := FALSE;
  msg := '';
  error_code := NULL;
  
  RAISE NOTICE '[fun_cancel_trip] Iniciando cancelación de viaje: ID=%', wid_trip;
  
  -- ==========================================
  -- 3. VALIDAR USUARIO QUE HACE LA CANCELACIÓN
  -- ==========================================
  
  SELECT EXISTS(
    SELECT 1 FROM tab_users 
    WHERE id_user = wuser_cancel AND is_active = TRUE
  ) INTO v_canceller_exists;
  
  IF NOT v_canceller_exists THEN
    msg := 'El usuario que intenta cancelar no existe o está inactivo (ID: ' || wuser_cancel || ')';
    error_code := 'USER_CANCEL_NOT_FOUND';
    RAISE NOTICE '[fun_cancel_trip] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 4. VALIDAR QUE EL VIAJE EXISTE Y OBTENER DATOS
  -- ==========================================
  
  SELECT 
    status_trip,
    id_route,
    trip_date,
    start_time,
    end_time,
    plate_number
  INTO 
    v_trip_status,
    v_route_id,
    v_trip_date,
    v_start_time,
    v_end_time,
    v_assigned_plate
  FROM tab_trips
  WHERE id_trip = wid_trip;
  
  IF NOT FOUND THEN
    msg := 'Viaje no encontrado: ID ' || wid_trip;
    error_code := 'TRIP_NOT_FOUND';
    RAISE NOTICE '[fun_cancel_trip] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- ==========================================
  -- 5. VALIDAR ESTADO DEL VIAJE
  -- ==========================================
  
  -- 5.1. Validar que no esté en curso (activo)
  IF v_trip_status = 'active' THEN
    msg := 'No se puede cancelar un viaje en curso (status: active). ' ||
           'Debe finalizar el viaje primero. ID: ' || wid_trip;
    error_code := 'TRIP_ACTIVE_CANNOT_CANCEL';
    RAISE NOTICE '[fun_cancel_trip] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- 5.2. Validar que no esté ya cancelado
  IF v_trip_status = 'cancelled' THEN
    msg := 'El viaje con ID ' || wid_trip || ' ya está cancelado';
    error_code := 'TRIP_ALREADY_CANCELLED';
    RAISE NOTICE '[fun_cancel_trip] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- 5.3. Permitir cancelar: pending, assigned, completed
  -- Los viajes completados se pueden cancelar para correcciones administrativas
  
  -- ==========================================
  -- 6. SOFT DELETE - CANCELAR VIAJE
  -- ==========================================
  
  BEGIN
    UPDATE tab_trips
    SET status_trip = 'cancelled',
        plate_number = NULL,  -- Liberar bus asignado
        updated_at = NOW(),
        user_update = wuser_cancel
    WHERE id_trip = wid_trip
      AND status_trip != 'cancelled';  -- Doble verificación
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    IF v_rows_affected = 0 THEN
      msg := 'No se pudo cancelar el viaje (ID: ' || wid_trip || '). ' ||
             'Es posible que ya esté cancelado o haya sido eliminado';
      error_code := 'TRIP_UPDATE_FAILED';
      RAISE NOTICE '[fun_cancel_trip] ERROR: %', msg;
      RETURN;
    END IF;
    
    RAISE NOTICE '[fun_cancel_trip] Viaje cancelado: ID=%', wid_trip;
    
  EXCEPTION
    WHEN foreign_key_violation THEN
      msg := 'Error: Violación de clave foránea al cancelar el viaje (user_update inválido: ' || 
             wuser_cancel || ')';
      error_code := 'TRIP_UPDATE_FK_VIOLATION';
      RAISE NOTICE '[fun_cancel_trip] ERROR: %', msg;
      RETURN;
      
    WHEN check_violation THEN
      msg := 'Error: Violación de restricción CHECK al cancelar el viaje';
      error_code := 'TRIP_UPDATE_CHECK_VIOLATION';
      RAISE NOTICE '[fun_cancel_trip] ERROR: %', msg;
      RETURN;
      
    WHEN OTHERS THEN
      msg := 'Error inesperado al cancelar el viaje: ' || SQLERRM;
      error_code := 'TRIP_UPDATE_ERROR';
      RAISE NOTICE '[fun_cancel_trip] ERROR: %', msg;
      RETURN;
  END;
  
  -- ==========================================
  -- 7. RETORNO EXITOSO
  -- ==========================================
  
  success := TRUE;
  msg := 'Viaje ' || wid_trip || ' cancelado exitosamente. ' ||
         'Ruta: ' || v_route_id || ', Fecha: ' || v_trip_date || 
         ', Horario: ' || v_start_time || ' - ' || v_end_time;
  
  IF v_assigned_plate IS NOT NULL THEN
    msg := msg || ', Bus ' || v_assigned_plate || ' liberado';
  END IF;
  
  error_code := NULL;
  
  RAISE NOTICE '[fun_cancel_trip] Éxito: Viaje % cancelado por usuario %', wid_trip, wuser_cancel;
  
END;
$$;

-- =============================================
-- COMENTARIOS FINALES
-- =============================================

COMMENT ON FUNCTION fun_delete_trip IS 
'v2.0 - Elimina (cancela) un viaje mediante soft delete. Cambia status_trip a cancelled y libera bus.
Validaciones: usuario que elimina existe y activo, viaje existe, no está activo, no está ya cancelado.
Retorna: success (BOOLEAN), msg (VARCHAR), error_code (VARCHAR).
Códigos de error: USER_DELETE_NOT_FOUND, TRIP_NOT_FOUND, TRIP_ACTIVE_CANNOT_DELETE, TRIP_ALREADY_CANCELLED, 
TRIP_UPDATE_FAILED, TRIP_UPDATE_FK_VIOLATION, TRIP_UPDATE_CHECK_VIOLATION, TRIP_UPDATE_ERROR.';

COMMENT ON FUNCTION fun_delete_trips_by_date IS 
'v2.0 - Elimina (cancela) todos los viajes de una ruta en una fecha mediante soft delete.
Validaciones: usuario que elimina existe y activo, ruta existe y activa, no hay viajes activos en curso.
Retorna: success (BOOLEAN), msg (VARCHAR), error_code (VARCHAR), trips_deleted (INTEGER).
Códigos de error: USER_DELETE_NOT_FOUND, ROUTE_ID_NULL, TRIP_DATE_NULL, ROUTE_NOT_FOUND, ROUTE_INACTIVE, 
NO_TRIPS_FOUND, HAS_ACTIVE_TRIPS, ALL_TRIPS_ALREADY_CANCELLED, TRIPS_UPDATE_FAILED, TRIPS_UPDATE_FK_VIOLATION, 
TRIPS_UPDATE_CHECK_VIOLATION, TRIPS_UPDATE_ERROR.';

COMMENT ON FUNCTION fun_cancel_trip IS 
'v2.0 - Cancela un viaje específico mediante soft delete. Cambia status_trip a cancelled y libera bus.
Validaciones: usuario que cancela existe y activo, viaje existe, no está activo, no está ya cancelado.
Retorna: success (BOOLEAN), msg (VARCHAR), error_code (VARCHAR).
Códigos de error: USER_CANCEL_NOT_FOUND, TRIP_NOT_FOUND, TRIP_ACTIVE_CANNOT_CANCEL, TRIP_ALREADY_CANCELLED, 
TRIP_UPDATE_FAILED, TRIP_UPDATE_FK_VIOLATION, TRIP_UPDATE_CHECK_VIOLATION, TRIP_UPDATE_ERROR.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================

/*
-- ==============================================
-- EJEMPLOS - fun_delete_trip
-- ==============================================

-- Ejemplo 1: Eliminar (cancelar) un viaje pendiente
SELECT * FROM fun_delete_trip(
  123,  -- ID del viaje
  1     -- ID del usuario admin que elimina
);

-- Resultado exitoso:
-- success | msg                                     | error_code
-- TRUE    | Viaje eliminado exitosamente (cancel... | NULL


-- Ejemplo 2: ERROR - Viaje activo no se puede eliminar
SELECT * FROM fun_delete_trip(
  456,  -- Viaje con status = 'active'
  1
);

-- Resultado:
-- success | msg                                  | error_code
-- FALSE   | No se puede eliminar un viaje en ... | TRIP_ACTIVE_CANNOT_DELETE


-- Ejemplo 3: ERROR - Viaje ya cancelado
SELECT * FROM fun_delete_trip(
  789,  -- Viaje ya cancelado
  1
);

-- Resultado:
-- success | msg                              | error_code
-- FALSE   | El viaje con ID 789 ya está c... | TRIP_ALREADY_CANCELLED


-- ==============================================
-- EJEMPLOS - fun_delete_trips_by_date
-- ==============================================

-- Ejemplo 4: Eliminar todos los viajes de una ruta en una fecha
SELECT * FROM fun_delete_trips_by_date(
  1,             -- ID de la ruta
  '2026-02-20',  -- Fecha
  1              -- ID del usuario admin
);

-- Resultado exitoso:
-- success | msg                                     | error_code | trips_deleted
-- TRUE    | Se cancelaron 5 viaje(s) de la rut...  | NULL       | 5


-- Ejemplo 5: ERROR - Hay viajes activos en curso
SELECT * FROM fun_delete_trips_by_date(
  1,             -- Ruta con viajes activos
  '2026-02-16',
  1
);

-- Resultado:
-- success | msg                                  | error_code        | trips_deleted
-- FALSE   | No se pueden eliminar: hay 2 via...  | HAS_ACTIVE_TRIPS  | 0


-- Ejemplo 6: ERROR - Ruta no existe
SELECT * FROM fun_delete_trips_by_date(
  999,           -- Ruta inexistente
  '2026-02-20',
  1
);

-- Resultado:
-- success | msg                          | error_code         | trips_deleted
-- FALSE   | No existe la ruta con ID...  | ROUTE_NOT_FOUND    | 0


-- ==============================================
-- EJEMPLOS - fun_cancel_trip
-- ==============================================

-- Ejemplo 7: Cancelar un viaje asignado
SELECT * FROM fun_cancel_trip(
  123,  -- ID del viaje
  1     -- ID del usuario admin que cancela
);

-- Resultado exitoso:
-- success | msg                                     | error_code
-- TRUE    | Viaje 123 cancelado exitosamente. R...  | NULL


-- Ejemplo 8: Cancelar un viaje completado (corrección administrativa)
SELECT * FROM fun_cancel_trip(
  456,  -- Viaje con status = 'completed'
  1
);

-- Resultado exitoso (se permite):
-- success | msg                                     | error_code
-- TRUE    | Viaje 456 cancelado exitosamente. R...  | NULL


-- Ejemplo 9: ERROR - Usuario que cancela no existe
SELECT * FROM fun_cancel_trip(
  123,
  999999  -- Usuario inexistente
);

-- Resultado:
-- success | msg                                  | error_code
-- FALSE   | El usuario que intenta cancelar n... | USER_CANCEL_NOT_FOUND


-- ==============================================
-- VERIFICACIONES POST-CANCELACIÓN
-- ==============================================

-- Ejemplo 10: Verificar que el viaje está cancelado
SELECT 
  id_trip,
  id_route,
  trip_date,
  start_time,
  status_trip,
  plate_number,
  updated_at,
  user_update
FROM tab_trips
WHERE id_trip = 123;

-- Resultado:
-- id_trip | id_route | trip_date  | start_time | status_trip | plate_number | updated_at          | user_update
-- 123     | 1        | 2026-02-20 | 08:00:00   | cancelled   | NULL         | 2026-02-16 10:30:00 | 1


-- Ejemplo 11: Ver todos los viajes cancelados de una ruta/fecha
SELECT 
  id_trip,
  start_time,
  end_time,
  status_trip,
  user_update,
  updated_at
FROM tab_trips
WHERE id_route = 1 
  AND trip_date = '2026-02-20'
  AND status_trip = 'cancelled'
ORDER BY start_time;

*/

-- =============================================
-- FIN DE LAS FUNCIONES fun_delete_trip v2.0
-- =============================================
