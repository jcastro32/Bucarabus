-- =============================================
-- BucaraBUS - Función: Actualizar Ruta
-- =============================================
-- Versión: 2.0
-- Fecha: Febrero 2025
-- Descripción: Actualiza metadatos de una ruta (nombre, descripción, color)
-- Nota: NO modifica la geometría (path_route) - para eso usar fun_update_route_path
-- =============================================

-- Eliminar versiones anteriores
DROP FUNCTION IF EXISTS fun_update_route(NUMERIC, VARCHAR, TEXT, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS fun_update_route(INTEGER, VARCHAR, TEXT, VARCHAR, INTEGER);

-- =============================================
-- Función: fun_update_route v2.0
-- =============================================
CREATE OR REPLACE FUNCTION fun_update_route(
    -- Identificador de la ruta a actualizar
    wid_route           tab_routes.id_route%TYPE,
    
    -- Auditoría
    wuser_update        tab_routes.user_update%TYPE,
    
    -- Datos opcionales (NULL = mantener valor actual)
    wname_route         tab_routes.name_route%TYPE DEFAULT NULL,
    wdescrip_route      tab_routes.descrip_route%TYPE DEFAULT NULL,
    wcolor_route        tab_routes.color_route%TYPE DEFAULT NULL,
    
    -- Parámetros de salida
    OUT success         BOOLEAN,
    OUT msg             VARCHAR,
    OUT error_code      VARCHAR,
    OUT id_route        INTEGER,
    OUT route_data      JSON
)
LANGUAGE plpgsql AS $$

DECLARE
    v_updater_exists    BOOLEAN;
    v_route_exists      BOOLEAN;
    v_route_active      BOOLEAN;
    v_current_name      VARCHAR(200);
    v_current_color     VARCHAR(7);
    v_name_clean        VARCHAR(200);
    v_descrip_clean     TEXT;
    v_color_clean       VARCHAR(7);
    v_name_duplicate    BOOLEAN;
    v_rows_affected     INTEGER;
    v_distance_km       NUMERIC;
    v_point_count       INTEGER;
    
BEGIN
    -- ====================================
    -- 1. INICIALIZACIÓN
    -- ====================================
    success := FALSE;
    msg := '';
    error_code := NULL;
    id_route := NULL;
    route_data := NULL;

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

    RAISE NOTICE '[fun_update_route] Usuario actualizador validado: %', wuser_update;

    -- ====================================
    -- 3. VALIDACIÓN DE LA RUTA A ACTUALIZAR
    -- ====================================
    IF wid_route IS NULL OR wid_route <= 0 THEN
        msg := 'El ID de la ruta es obligatorio y debe ser mayor que 0';
        error_code := 'ROUTE_ID_INVALID';
        RETURN;
    END IF;

    -- Verificar que la ruta existe
    SELECT EXISTS(
        SELECT 1 FROM tab_routes WHERE tab_routes.id_route = wid_route
    ) INTO v_route_exists;
    
    IF NOT v_route_exists THEN
        msg := 'La ruta con ID ' || wid_route || ' no existe';
        error_code := 'ROUTE_NOT_FOUND';
        RETURN;
    END IF;

    -- Verificar que la ruta está activa
    SELECT status_route, name_route, color_route 
    INTO v_route_active, v_current_name, v_current_color
    FROM tab_routes
    WHERE tab_routes.id_route = wid_route;
    
    IF NOT v_route_active THEN
        msg := 'No se puede actualizar una ruta inactiva (ID: ' || wid_route || '). Primero debe reactivarla';
        error_code := 'ROUTE_INACTIVE';
        RETURN;
    END IF;

    RAISE NOTICE '[fun_update_route] Ruta validada: % (Nombre actual: "%")', wid_route, v_current_name;

    -- ====================================
    -- 4. VALIDACIONES Y NORMALIZACIÓN DE NOMBRE
    -- ====================================
    v_name_clean := NULL;
    
    IF wname_route IS NOT NULL AND TRIM(wname_route) != '' THEN
        v_name_clean := TRIM(wname_route);
        
        -- Validar longitud mínima
        IF LENGTH(v_name_clean) < 3 THEN
            msg := 'El nombre debe tener al menos 3 caracteres';
            error_code := 'NAME_TOO_SHORT';
            RETURN;
        END IF;
        
        -- Validar longitud máxima (schema: VARCHAR(200))
        IF LENGTH(v_name_clean) > 200 THEN
            msg := 'El nombre excede la longitud máxima permitida (200 caracteres)';
            error_code := 'NAME_TOO_LONG';
            RETURN;
        END IF;
        
        -- Verificar duplicados solo si el nombre cambió
        IF LOWER(v_name_clean) != LOWER(v_current_name) THEN
            SELECT EXISTS(
                SELECT 1 
                FROM tab_routes 
                WHERE LOWER(name_route) = LOWER(v_name_clean)
                  AND tab_routes.id_route != wid_route
                  AND status_route = TRUE
            ) INTO v_name_duplicate;
            
            IF v_name_duplicate THEN
                msg := 'Ya existe otra ruta activa con el nombre "' || v_name_clean || '"';
                error_code := 'NAME_DUPLICATE';
                RETURN;
            END IF;
        ELSE
            -- Nombre no cambió, mantener el actual
            v_name_clean := NULL;
        END IF;
    END IF;

    -- ====================================
    -- 5. VALIDACIONES Y NORMALIZACIÓN DE DESCRIPCIÓN
    -- ====================================
    v_descrip_clean := NULL;
    
    IF wdescrip_route IS NOT NULL THEN
        v_descrip_clean := TRIM(wdescrip_route);
        
        -- Si es string vacío después de TRIM, usar NULL
        IF v_descrip_clean = '' THEN
            v_descrip_clean := NULL;
        END IF;
        
        -- Validar longitud razonable (max 2000 caracteres para TEXT)
        IF v_descrip_clean IS NOT NULL AND LENGTH(v_descrip_clean) > 2000 THEN
            msg := 'La descripción excede la longitud máxima recomendada (2000 caracteres)';
            error_code := 'DESCRIPTION_TOO_LONG';
            RETURN;
        END IF;
    END IF;

    -- ====================================
    -- 6. VALIDACIONES Y NORMALIZACIÓN DE COLOR
    -- ====================================
    v_color_clean := NULL;
    
    IF wcolor_route IS NOT NULL AND TRIM(wcolor_route) != '' THEN
        v_color_clean := TRIM(wcolor_route);
        
        -- Validar formato hexadecimal (#RRGGBB)
        IF v_color_clean !~ '^#[0-9A-Fa-f]{6}$' THEN
            msg := 'El color debe ser un código hexadecimal válido (#RRGGBB, ej: #3b82f6)';
            error_code := 'COLOR_INVALID_FORMAT';
            RETURN;
        END IF;
        
        -- Normalizar a minúsculas para consistencia
        v_color_clean := LOWER(v_color_clean);
        
        -- Si el color no cambió, no actualizar
        IF v_color_clean = v_current_color THEN
            v_color_clean := NULL;
        END IF;
    END IF;

    -- ====================================
    -- 7. VERIFICAR QUE HAY ALGO QUE ACTUALIZAR
    -- ====================================
    IF v_name_clean IS NULL AND v_descrip_clean IS NULL AND v_color_clean IS NULL THEN
        msg := 'No hay cambios para aplicar. Proporcione al menos un campo para actualizar (nombre, descripción o color)';
        error_code := 'NO_CHANGES';
        RETURN;
    END IF;

    RAISE NOTICE '[fun_update_route] Cambios a aplicar - Nombre: %, Descripción: %, Color: %', 
        CASE WHEN v_name_clean IS NOT NULL THEN 'SÍ' ELSE 'NO' END,
        CASE WHEN v_descrip_clean IS NOT NULL THEN 'SÍ' ELSE 'NO' END,
        CASE WHEN v_color_clean IS NOT NULL THEN 'SÍ' ELSE 'NO' END;

    -- ====================================
    -- 8. ACTUALIZAR LA RUTA
    -- ====================================
    BEGIN
        UPDATE tab_routes
        SET name_route = COALESCE(v_name_clean, name_route),
            descrip_route = CASE 
                WHEN v_descrip_clean IS NOT NULL OR (wdescrip_route IS NOT NULL AND TRIM(wdescrip_route) = '') 
                THEN v_descrip_clean 
                ELSE descrip_route 
            END,
            color_route = COALESCE(v_color_clean, color_route),
            updated_at = NOW(),
            user_update = wuser_update
        WHERE tab_routes.id_route = wid_route
          AND status_route = TRUE;
        
        GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
        
        IF v_rows_affected = 0 THEN
            msg := 'No se pudo actualizar la ruta (ID: ' || wid_route || '). Verifique que la ruta existe y está activa';
            error_code := 'ROUTE_UPDATE_FAILED';
            RETURN;
        END IF;
        
        RAISE NOTICE '[fun_update_route] Ruta actualizada: % (% fila afectada)', wid_route, v_rows_affected;
        
    EXCEPTION
        WHEN unique_violation THEN
            msg := 'Error de unicidad al actualizar la ruta: ' || SQLERRM;
            error_code := 'ROUTE_UPDATE_UNIQUE_VIOLATION';
            RETURN;
        WHEN not_null_violation THEN
            msg := 'Error de campo obligatorio al actualizar la ruta: ' || SQLERRM;
            error_code := 'ROUTE_UPDATE_NOT_NULL_VIOLATION';
            RETURN;
        WHEN check_violation THEN
            msg := 'Error de restricción al actualizar la ruta: ' || SQLERRM;
            error_code := 'ROUTE_UPDATE_CHECK_VIOLATION';
            RETURN;
        WHEN OTHERS THEN
            msg := 'Error inesperado al actualizar la ruta: ' || SQLERRM;
            error_code := 'ROUTE_UPDATE_ERROR';
            RETURN;
    END;

    -- ====================================
    -- 9. OBTENER DATOS ACTUALIZADOS Y CALCULAR MÉTRICAS
    -- ====================================
    BEGIN
        SELECT 
            ROUND((ST_Length(path_route::geography) / 1000)::NUMERIC, 2),
            ST_NPoints(path_route)
        INTO v_distance_km, v_point_count
        FROM tab_routes
        WHERE tab_routes.id_route = wid_route;
        
        SELECT json_build_object(
            'id_route', tab_routes.id_route,
            'name_route', name_route,
            'path_route', ST_AsGeoJSON(path_route)::JSON,
            'descrip_route', COALESCE(descrip_route, ''),
            'color_route', color_route,
            'status_route', status_route,
            'distance_km', v_distance_km,
            'point_count', v_point_count,
            'created_at', created_at,
            'updated_at', updated_at,
            'user_update', user_update
        )
        INTO route_data
        FROM tab_routes
        WHERE tab_routes.id_route = wid_route;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '[fun_update_route] Advertencia al obtener datos: %', SQLERRM;
            -- No fallar, solo continuar sin route_data
    END;

    -- ====================================
    -- 10. ÉXITO - RETORNAR DATOS
    -- ====================================
    success := TRUE;
    id_route := wid_route;
    
    -- Construir mensaje descriptivo
    msg := 'Ruta actualizada exitosamente: ';
    
    IF v_name_clean IS NOT NULL THEN
        msg := msg || 'Nuevo nombre: "' || v_name_clean || '"';
    ELSE
        msg := msg || 'Nombre: "' || v_current_name || '"';
    END IF;
    
    IF v_color_clean IS NOT NULL THEN
        msg := msg || '. Color cambiado a: ' || v_color_clean;
    END IF;
    
    IF v_distance_km IS NOT NULL THEN
        msg := msg || ' (' || v_distance_km || ' km, ' || v_point_count || ' puntos)';
    END IF;
    
    error_code := NULL;
    
    RAISE NOTICE '[fun_update_route] Éxito: Ruta % actualizada', wid_route;
    RETURN;

END;
$$;

-- =============================================
-- DOCUMENTACIÓN
-- =============================================

COMMENT ON FUNCTION fun_update_route IS 'Actualiza metadatos de una ruta existente (nombre, descripción, color). NO modifica la geometría. Versión 2.0 con validaciones completas y manejo estructurado de errores.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================

/*
-- ==========================
-- Ejemplo 1: Actualizar solo el nombre
-- ==========================
SELECT * FROM fun_update_route(
    1,                                  -- wid_route
    'Ruta Norte Actualizada',          -- wname_route (nuevo nombre)
    NULL,                               -- wdescrip_route (no cambiar)
    NULL,                               -- wcolor_route (no cambiar)
    1735689600                          -- wuser_update
);
-- Resultado: success=TRUE, msg incluye el nuevo nombre

-- ==========================
-- Ejemplo 2: Actualizar color y descripción
-- ==========================
SELECT * FROM fun_update_route(
    1,
    NULL,                               -- wname_route (no cambiar)
    'Nueva descripción de la ruta Norte con estaciones actualizadas',
    '#10b981',                          -- wcolor_route (verde)
    1735689600
);
-- Resultado: actualiza solo descripción y color

-- ==========================
-- Ejemplo 3: Actualizar todos los campos
-- ==========================
SELECT * FROM fun_update_route(
    1,
    'Ruta Norte - Centro',
    'Ruta que conecta el norte de la ciudad con el centro histórico',
    '#ef4444',                          -- Rojo
    1735689600
);
-- Resultado: actualiza nombre, descripción y color

-- ==========================
-- Ejemplo 4: Limpiar descripción (dejarla NULL)
-- ==========================
SELECT * FROM fun_update_route(
    1,
    NULL,                               -- No cambiar nombre
    '',                                 -- String vacío = NULL después de TRIM
    NULL,                               -- No cambiar color
    1735689600
);
-- Resultado: descrip_route queda NULL

-- ==========================
-- Ejemplo 5: Error - Ruta no existe
-- ==========================
SELECT * FROM fun_update_route(
    9999,                               -- ID inexistente
    'Nombre',
    NULL,
    NULL,
    1735689600
);
-- Resultado: success=FALSE, error_code='ROUTE_NOT_FOUND'

-- ==========================
-- Ejemplo 6: Error - Usuario actualizador inexistente
-- ==========================
SELECT * FROM fun_update_route(
    1,
    'Ruta Norte',
    NULL,
    NULL,
    9999999                             -- Usuario inexistente
);
-- Resultado: success=FALSE, error_code='USER_UPDATE_NOT_FOUND'

-- ==========================
-- Ejemplo 7: Error - Nombre duplicado
-- ==========================
SELECT * FROM fun_update_route(
    1,
    'Ruta Sur',                         -- Ya existe otra ruta con este nombre
    NULL,
    NULL,
    1735689600
);
-- Resultado: success=FALSE, error_code='NAME_DUPLICATE'

-- ==========================
-- Ejemplo 8: Error - Nombre demasiado corto
-- ==========================
SELECT * FROM fun_update_route(
    1,
    'Ab',                               -- Solo 2 caracteres
    NULL,
    NULL,
    1735689600
);
-- Resultado: success=FALSE, error_code='NAME_TOO_SHORT'

-- ==========================
-- Ejemplo 9: Error - Color formato inválido
-- ==========================
SELECT * FROM fun_update_route(
    1,
    NULL,
    NULL,
    'rojo',                             -- No es formato hexadecimal
    1735689600
);
-- Resultado: success=FALSE, error_code='COLOR_INVALID_FORMAT'

-- ==========================
-- Ejemplo 10: Error - No hay cambios
-- ==========================
SELECT * FROM fun_update_route(
    1,
    NULL,                               -- Todos NULL = no hay cambios
    NULL,
    NULL,
    1735689600
);
-- Resultado: success=FALSE, error_code='NO_CHANGES'

-- ==========================
-- Ejemplo 11: Error - Ruta inactiva
-- ==========================
-- (Primero desactivar una ruta)
UPDATE tab_routes SET status_route = FALSE WHERE id_route = 1;
SELECT * FROM fun_update_route(
    1,
    'Nuevo nombre',
    NULL,
    NULL,
    1735689600
);
-- Resultado: success=FALSE, error_code='ROUTE_INACTIVE'
*/
