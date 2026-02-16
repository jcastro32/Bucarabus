-- =============================================
-- 5️⃣ Eliminar ruta (soft delete)
-- =============================================

DROP FUNCTION IF EXISTS fun_delete_route(NUMERIC, VARCHAR);

CREATE OR REPLACE FUNCTION fun_delete_route(
    wid_route           tab_routes.id_route%TYPE,
    wuser_update        tab_routes.user_update%TYPE,
    OUT success         BOOLEAN,
    OUT msg             VARCHAR,
    OUT error_code      VARCHAR,
    OUT warning         VARCHAR
) AS $$

DECLARE
    v_route_name        VARCHAR;
    v_active_trips      INTEGER := 0;
    v_pending_trips     INTEGER := 0;
BEGIN
    -- Inicializar valores de salida
    success := FALSE;
    msg := '';
    error_code := NULL;
    warning := NULL;

    -- ====================================
    -- 1. VALIDAR QUE LA RUTA EXISTE Y ESTÁ ACTIVA
    -- ====================================
    
    SELECT name_route INTO v_route_name
    FROM tab_routes
    WHERE id_route = wid_route AND status_route = TRUE;
    
    IF v_route_name IS NULL THEN
        msg := 'Ruta no encontrada o ya fue eliminada';
        error_code := 'ROUTE_NOT_FOUND';
        RETURN;
    END IF;

    -- ====================================
    -- 2. VERIFICAR VIAJES ACTIVOS
    -- ====================================
    
    -- Contar viajes activos (en curso)
    SELECT COUNT(*) INTO v_active_trips
    FROM tab_trips
    WHERE id_route = wid_route 
    AND status_trip = 'active';
    
    -- Contar viajes pendientes (programados)
    SELECT COUNT(*) INTO v_pending_trips
    FROM tab_trips
    WHERE id_route = wid_route 
    AND status_trip IN ('pending', 'assigned')
    AND trip_date >= CURRENT_DATE;
    
    -- BLOQUEAR si hay viajes activos
    IF v_active_trips > 0 THEN
        msg := 'No se puede eliminar la ruta porque tiene ' || v_active_trips || ' viaje(s) activo(s) en curso';
        error_code := 'ROUTE_HAS_ACTIVE_TRIPS';
        RETURN;
    END IF;
    
    -- ADVERTIR si hay viajes pendientes (pero permitir eliminación)
    IF v_pending_trips > 0 THEN
        warning := 'La ruta tiene ' || v_pending_trips || ' viaje(s) pendiente(s) programado(s). Estos viajes quedarán sin ruta.';
        RAISE NOTICE '%', warning;
    END IF;

    -- ====================================
    -- 3. REALIZAR SOFT DELETE
    -- ====================================
    
    BEGIN
        UPDATE tab_routes
        SET
            status_route = FALSE,
            updated_at = NOW(),
            user_update = wuser_update
        WHERE id_route = wid_route;
        
        success := TRUE;
        msg := 'Ruta "' || v_route_name || '" eliminada exitosamente (soft delete)';
        
        IF v_pending_trips > 0 THEN
            msg := msg || '. ADVERTENCIA: ' || v_pending_trips || ' viaje(s) pendiente(s) afectado(s)';
        END IF;
        
        RAISE NOTICE 'Ruta eliminada: ID=%, Nombre=%, Viajes pendientes=%', 
            wid_route, 
            v_route_name,
            v_pending_trips;
        
    EXCEPTION
        WHEN OTHERS THEN
            success := FALSE;
            msg := 'Error inesperado al eliminar la ruta: ' || SQLERRM;
            error_code := 'SQLSTATE_' || SQLSTATE;
    END;

END;

$$ LANGUAGE plpgsql;