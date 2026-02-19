import pool from '../config/database.js';

const SYSTEM_USER_ID = 1;

/**
 * Crear un viaje individual
 */
export async function createTrip(tripData) {
  const { id_route, trip_date, start_time, end_time, user_create, plate_number, status_trip } = tripData;
  
  const result = await pool.query(
    `SELECT * FROM fun_create_trip($1, $2, $3, $4, $5, $6, $7)`,
    [id_route, trip_date, start_time, end_time, user_create, plate_number || null, status_trip || 'assigned']
  );
  
  return result.rows[0];
}

/**
 * Crear múltiples viajes (batch)
 */
export async function createTripsBatch(batchData) {
  const { id_route, trip_date, trips, user_create } = batchData;
  
  const result = await pool.query(
    `SELECT * FROM fun_create_trips_batch($1, $2, $3::jsonb, $4)`,
    [id_route, trip_date, JSON.stringify(trips), user_create]
  );
  
  return result.rows[0];
}

/**
 * Obtener viajes por ruta y fecha
 */
export async function getTripsByRouteAndDate(id_route, trip_date) {
  const result = await pool.query(
    `SELECT 
       id_trip,
       id_route,
       trip_date,
       start_time,
       end_time,
       plate_number,
       status_trip,
       created_at,
       user_create
     FROM tab_trips
     WHERE id_route = $1 
       AND trip_date = $2
       AND status_trip != 'cancelled'
     ORDER BY start_time`,
    [id_route, trip_date]
  );
  
  return result.rows;
}

/**
 * Obtener viajes por bus y fecha (para app conductor)
 */
export async function getTripsByBusAndDate(plate_number, trip_date) {
  const result = await pool.query(
    `SELECT 
       t.id_trip,
       t.id_route,
       t.trip_date,
       t.start_time,
       t.end_time,
       t.plate_number,
       t.status_trip,
       t.created_at,
       t.user_create,
       r.name_route,
       r.color_route
     FROM tab_trips t
     LEFT JOIN tab_routes r ON t.id_route = r.id_route
     WHERE t.plate_number = $1 AND t.trip_date = $2
     ORDER BY t.start_time`,
    [plate_number, trip_date]
  );
  
  return result.rows;
}

/**
 * Obtener un viaje por ID
 */
export async function getTripById(id_trip) {
  const result = await pool.query(
    `SELECT * FROM tab_trips WHERE id_trip = $1`,
    [id_trip]
  );
  
  return result.rows[0] || null;
}

/**
 * Actualizar viaje
 */
export async function updateTrip(id_trip, updateData) {
  const { user_update, start_time, end_time, plate_number, status_trip } = updateData;
  
  const result = await pool.query(
    `SELECT * FROM fun_update_trip($1, $2, $3, $4, $5, $6)`,
    [id_trip, user_update, start_time || null, end_time || null, plate_number, status_trip || null]
  );
  
  return result.rows[0];
}

/**
 * Asignar o desasignar bus
 */
export async function setTripBus(id_trip, plate_number, user_update) {
  const result = await pool.query(
    `SELECT * FROM fun_set_trip_bus($1, $2, $3)`,
    [id_trip, plate_number, user_update]
  );
  
  return result.rows[0];
}

/**
 * Eliminar viaje
 */
export async function deleteTrip(id_trip, user_delete = SYSTEM_USER_ID) {
  const result = await pool.query(
    `SELECT * FROM fun_delete_trip($1, $2)`,
    [id_trip, user_delete]
  );
  
  return result.rows[0];
}

/**
 * Eliminar viajes por ruta y fecha
 */
export async function deleteTripsByDate(id_route, trip_date) {
  const result = await pool.query(
    `SELECT * FROM fun_delete_trips_by_date($1, $2)`,
    [id_route, trip_date]
  );
  
  return result.rows[0];
}

/**
 * Cancelar viaje (soft delete)
 */
export async function cancelTrip(id_trip, user_update) {
  const result = await pool.query(
    `SELECT * FROM fun_cancel_trip($1, $2)`,
    [id_trip, user_update]
  );
  
  return result.rows[0];
}
