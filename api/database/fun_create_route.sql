-- =============================================
-- BucaraBUS - Función: Crear Nueva Ruta
-- =============================================
-- Versión: 2.0
-- Fecha: Febrero 2025
-- Descripción: Crea una nueva ruta con geometría PostGIS
-- =============================================

-- Eliminar versiones anteriores
DROP FUNCTION IF EXISTS fun_create_route(VARCHAR, TEXT, TEXT, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS fun_create_route(VARCHAR(200), TEXT, TEXT, VARCHAR(7), INTEGER);

-- =============================================
-- Función: fun_create_route v2.0
-- =============================================
CREATE OR REPLACE FUNCTION fun_create_route(
    wname_route         tab_routes.name_route%TYPE,
    wpath_coordinates   TEXT,
    wuser_create        tab_routes.user_create%TYPE,
    wdescrip_route      tab_routes.descrip_route%TYPE DEFAULT NULL,
    wcolor_route        tab_routes.color_route%TYPE DEFAULT NULL,
    OUT success         BOOLEAN,
    OUT msg             VARCHAR,
    OUT id_route        INTEGER,
    OUT route_data      JSON,
    OUT error_code      VARCHAR
)
LANGUAGE plpgsql AS $$

DECLARE
    v_user_exists       BOOLEAN;
    v_name_exists       BOOLEAN;
    v_new_id            INTEGER;
    v_geometry          GEOMETRY;
    v_point_count       INTEGER;
    v_distance_km       NUMERIC;
    v_name_clean        VARCHAR(200);
    v_descrip_clean     TEXT;
    v_selected_color    VARCHAR(7);
    v_route_count       INTEGER;
    
    -- Paleta de colores predefinida
    v_color_palette     TEXT[] := ARRAY[
        '#ef4444',  -- Rojo
        '#3b82f6',  -- Azul
        '#10b981',  -- Verde
        '#f59e0b',  -- Naranja
        '#8b5cf6',  -- Púrpura
        '#ec4899',  -- Rosa
        '#14b8a6',  -- Turquesa
        '#f97316',  -- Naranja oscuro
        '#6366f1',  -- Índigo
        '#84cc16',  -- Lima
        '#06b6d4',  -- Cian
        '#f43f5e'   -- Rosa fuerte
    ];
    
BEGIN
    -- ====================================
    -- 1. INICIALIZACIÓN
    -- ====================================
    success := FALSE;
    msg := '';
    id_route := NULL;
    route_data := NULL;
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
    -- 3. VALIDACIONES DE NOMBRE
    -- ====================================
    IF wname_route IS NULL OR TRIM(wname_route) = '' THEN
        msg := 'El nombre de la ruta es obligatorio';
        error_code := 'NAME_NULL_EMPTY';
        RETURN;
    END IF;

    v_name_clean := TRIM(wname_route);
    
    IF LENGTH(v_name_clean) < 3 THEN
        msg := 'El nombre debe tener al menos 3 caracteres';
        error_code := 'NAME_TOO_SHORT';
        RETURN;
    END IF;

    IF LENGTH(v_name_clean) > 200 THEN
        msg := 'El nombre no puede exceder 200 caracteres';
        error_code := 'NAME_TOO_LONG';
        RETURN;
    END IF;

    -- Validar nombre duplicado
    SELECT EXISTS(
        SELECT 1 FROM tab_routes 
        WHERE LOWER(name_route) = LOWER(v_name_clean)
          AND status_route = TRUE
    ) INTO v_name_exists;
    
    IF v_name_exists THEN
        msg := 'Ya existe una ruta activa con el nombre "' || v_name_clean || '"';
        error_code := 'NAME_DUPLICATE';
        RETURN;
    END IF;

    -- ====================================
    -- 4. VALIDACIONES DE DESCRIPCIÓN
    -- ====================================
    IF wdescrip_route IS NOT NULL THEN
        v_descrip_clean := TRIM(wdescrip_route);
        IF v_descrip_clean = '' THEN
            v_descrip_clean := NULL;
        END IF;
    ELSE
        v_descrip_clean := NULL;
    END IF;

    -- ====================================
    -- 5. VALIDACIONES DE COORDENADAS
    -- ====================================
    IF wpath_coordinates IS NULL OR TRIM(wpath_coordinates) = '' THEN
        msg := 'Las coordenadas de la ruta son obligatorias';
        error_code := 'COORDINATES_NULL_EMPTY';
        RETURN;
    END IF;

    -- Validar formato WKT LINESTRING
    IF wpath_coordinates !~ '^LINESTRING\s*\(' THEN
        msg := 'Las coordenadas deben estar en formato WKT LINESTRING (ej: LINESTRING(-73.1 7.1, -73.2 7.2))';
        error_code := 'COORDINATES_INVALID_FORMAT';
        RETURN;
    END IF;

    -- ====================================
    -- 6. PROCESAR GEOMETRÍA
    -- ====================================
    BEGIN
        v_geometry := ST_GeomFromText(wpath_coordinates, 4326);
        
        IF v_geometry IS NULL THEN
            msg := 'No se pudo crear la geometría desde las coordenadas proporcionadas';
            error_code := 'GEOMETRY_NULL';
            RETURN;
        END IF;
        
        -- Validar que la geometría es válida
        IF NOT ST_IsValid(v_geometry) THEN
            msg := 'La geometría de la ruta no es válida. Verifique que no hay auto-intersecciones';
            error_code := 'GEOMETRY_INVALID';
            RETURN;
        END IF;
        
        -- Contar puntos en la línea
        v_point_count := ST_NPoints(v_geometry);
        
        -- Validar mínimo de puntos
        IF v_point_count < 2 THEN
            msg := 'La ruta debe tener al menos 2 puntos (tiene ' || v_point_count || ')';
            error_code := 'GEOMETRY_INSUFFICIENT_POINTS';
            RETURN;
        END IF;
        
        -- Calcular distancia en kilómetros
        v_distance_km := ROUND((ST_Length(v_geometry::geography) / 1000)::NUMERIC, 2);
        
        -- Validar distancia mínima (ej: 100 metros)
        IF v_distance_km < 0.1 THEN
            msg := 'La ruta es demasiado corta (' || v_distance_km || ' km). Mínimo: 0.1 km';
            error_code := 'GEOMETRY_TOO_SHORT';
            RETURN;
        END IF;
        
        RAISE NOTICE 'Geometría válida: % puntos, %.2f km', v_point_count, v_distance_km;
        
    EXCEPTION
        WHEN OTHERS THEN
            msg := 'Error al procesar las coordenadas: ' || SQLERRM;
            error_code := 'GEOMETRY_PARSE_ERROR';
            RETURN;
    END;

    -- ====================================
    -- 7. SELECCIÓN DE COLOR
    -- ====================================
    IF wcolor_route IS NULL OR TRIM(wcolor_route) = '' THEN
        -- Color automático desde la paleta
        SELECT COUNT(*) INTO v_route_count 
        FROM tab_routes 
        WHERE status_route = TRUE;
        
        -- Usar módulo para rotar la paleta
        v_selected_color := v_color_palette[(v_route_count % array_length(v_color_palette, 1)) + 1];
        
        RAISE NOTICE 'Color automático seleccionado: % (ruta #%)', v_selected_color, v_route_count + 1;
    ELSE
        v_selected_color := TRIM(wcolor_route);
        
        -- Validar formato hexadecimal
        IF v_selected_color !~ '^#[0-9A-Fa-f]{6}$' THEN
            msg := 'El color debe ser un código hexadecimal válido (#RRGGBB, ej: #3b82f6)';
            error_code := 'COLOR_INVALID_FORMAT';
            RETURN;
        END IF;
        
        RAISE NOTICE 'Color personalizado: %', v_selected_color;
    END IF;

    -- ====================================
    -- 8. OBTENER PRÓXIMO ID
    -- ====================================
    SELECT COALESCE(MAX(tab_routes.id_route), 0) + 1 
    INTO v_new_id 
    FROM tab_routes;

    -- ====================================
    -- 9. INSERTAR RUTA
    -- ====================================
    BEGIN
        INSERT INTO tab_routes (
            id_route,
            name_route,
            path_route,
            descrip_route,
            color_route,
            user_create,
            status_route
        ) VALUES (
            v_new_id,
            v_name_clean,
            v_geometry,
            v_descrip_clean,
            v_selected_color,
            wuser_create,
            TRUE
        );
        
        -- Construir JSON con datos de la ruta creada
        SELECT json_build_object(
            'id_route', v_new_id,
            'name_route', v_name_clean,
            'path_route', ST_AsGeoJSON(v_geometry)::JSON,
            'descrip_route', COALESCE(v_descrip_clean, ''),
            'color_route', v_selected_color,
            'status_route', TRUE,
            'distance_km', v_distance_km,
            'point_count', v_point_count,
            'created_at', NOW()
        ) INTO route_data;
        
        success := TRUE;
        msg := 'Ruta creada exitosamente: ' || v_name_clean || ' (' || v_distance_km || ' km, ' || v_point_count || ' puntos)';
        id_route := v_new_id;
        error_code := NULL;
        
        RAISE NOTICE 'Ruta creada: ID=%, Nombre=%, Distancia=% km, Puntos=%', 
                     v_new_id, v_name_clean, v_distance_km, v_point_count;
        
    EXCEPTION
        WHEN unique_violation THEN
            msg := 'Ya existe una ruta con ese ID o nombre';
            error_code := 'ROUTE_INSERT_UNIQUE_VIOLATION';
            RETURN;
            
        WHEN not_null_violation THEN
            msg := 'Campos obligatorios faltantes en la creación de la ruta: ' || SQLERRM;
            error_code := 'ROUTE_INSERT_NOT_NULL_VIOLATION';
            RETURN;
            
        WHEN foreign_key_violation THEN
            msg := 'Error de clave foránea: usuario creador inválido';
            error_code := 'ROUTE_INSERT_FK_VIOLATION';
            RETURN;
            
        WHEN check_violation THEN
            msg := 'Violación de restricción CHECK: ' || SQLERRM;
            error_code := 'ROUTE_INSERT_CHECK_VIOLATION';
            RETURN;
            
        WHEN OTHERS THEN
            msg := 'Error inesperado al crear la ruta: ' || SQLERRM;
            error_code := 'ROUTE_INSERT_ERROR';
            RETURN;
    END;

END;
$$;