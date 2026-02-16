import pool from '../config/database.js';

/**
 * Obtener todos los turnos activos con información de bus, conductor y ruta
 */
async function getActiveShifts() {
    const query = `
        SELECT 
            t.id_trip,
            t.plate_number,
            t.id_route,
            t.start_time as started_at,
            t.status_trip,
            t.trip_date,
            b.amb_code,
            b.capacity,
            b.id_user,
            u.full_name AS name_driver,
            dd.cel as driver_phone,
            r.name_route,
            r.color_route,
            ST_AsGeoJSON(r.path_route) as path_geojson
        FROM tab_trips t
        JOIN tab_buses b ON t.plate_number = b.plate_number
        LEFT JOIN tab_driver_details dd ON b.id_user = dd.id_user
        LEFT JOIN tab_users u ON dd.id_user = u.id_user
        JOIN tab_routes r ON t.id_route = r.id_route
        WHERE t.status_trip = 'active'
        AND t.trip_date = CURRENT_DATE
        ORDER BY t.start_time DESC
    `;
    
    const result = await pool.query(query);
    return result.rows.map(row => ({
        ...row,
        path_route: row.path_geojson ? JSON.parse(row.path_geojson) : null
    }));
}

/**
 * Obtener un turno activo por placa
 */
async function getActiveShiftByPlate(plateNumber) {
    const query = `
        SELECT 
            t.id_trip,
            t.plate_number,
            t.id_route,
            t.start_time as started_at,
            t.end_time,
            t.status_trip,
            t.trip_date,
            b.amb_code,
            b.capacity,
            b.id_user,
            u.full_name AS name_driver,
            r.name_route,
            r.color_route,
            ST_AsGeoJSON(r.path_route) as path_geojson
        FROM tab_trips t
        JOIN tab_buses b ON t.plate_number = b.plate_number
        LEFT JOIN tab_driver_details dd ON b.id_user = dd.id_user
        LEFT JOIN tab_users u ON dd.id_user = u.id_user
        JOIN tab_routes r ON t.id_route = r.id_route
        WHERE t.plate_number = $1
        AND t.status_trip = 'active'
        AND t.trip_date = CURRENT_DATE
    `;
    
    const result = await pool.query(query, [plateNumber]);
    if (result.rows.length === 0) return null;
    
    const row = result.rows[0];
    return {
        ...row,
        path_route: row.path_geojson ? JSON.parse(row.path_geojson) : null
    };
}

/**
 * Iniciar un turno (cambiar status de trip a 'active')
 */
async function startShift(data) {
    const { plate_number, id_trip } = data;
    
    // Verificar si el bus ya tiene un turno activo
    const existing = await pool.query(
        'SELECT id_trip FROM tab_trips WHERE plate_number = $1 AND status_trip = \'active\' AND trip_date = CURRENT_DATE',
        [plate_number]
    );
    
    if (existing.rows.length > 0) {
        throw new Error('El bus ya tiene un turno activo');
    }
    
    const query = `
        UPDATE tab_trips 
        SET status_trip = 'active'
        WHERE id_trip = $1
        RETURNING *
    `;
    
    const result = await pool.query(query, [id_trip]);
    return result.rows[0];
}

/**
 * Finalizar un turno (cambiar status a 'completed')
 */
async function endShift(plateNumber) {
    const query = `
        UPDATE tab_trips 
        SET status_trip = 'completed'
        WHERE plate_number = $1 
        AND status_trip = 'active'
        AND trip_date = CURRENT_DATE
        RETURNING *
    `;
    
    const result = await pool.query(query, [plateNumber]);
    return result.rows[0];
}

/**
 * Actualizar progreso del turno (ahora solo actualiza el status)
 */
async function updateProgress(plateNumber, statusTrip) {
    const query = `
        UPDATE tab_trips 
        SET status_trip = $2
        WHERE plate_number = $1
        AND trip_date = CURRENT_DATE
        RETURNING *
    `;
    
    const result = await pool.query(query, [plateNumber, statusTrip]);
    return result.rows[0];
}

/**
 * Obtener buses disponibles (sin turno activo)
 */
async function getAvailableBuses() {
    const query = `
        SELECT b.*, u.full_name AS name_driver
        FROM tab_buses b
        LEFT JOIN tab_driver_details dd ON b.id_user = dd.id_user
        LEFT JOIN tab_users u ON dd.id_user = u.id_user
        WHERE b.is_active = true
        AND b.plate_number NOT IN (
            SELECT plate_number FROM tab_trips 
            WHERE status_trip = 'active' 
            AND trip_date = CURRENT_DATE
        )
        ORDER BY b.amb_code
    `;
    
    const result = await pool.query(query);
    return result.rows;
}

export {
    getActiveShifts,
    getActiveShiftByPlate,
    startShift,
    endShift,
    updateProgress,
    getAvailableBuses
};
