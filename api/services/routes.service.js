import pool from '../config/database.js'

const SYSTEM_USER_ID = 1;

/**
 * 🗺️ Servicio de Rutas - Usa Procedimientos Almacenados
 * El backend solo hace llamadas a los SPs de PostgreSQL
 */
class RoutesService {
  
  /**
   * Obtener todas las rutas
   */
  async getAllRoutes() {
    try {
      const result = await pool.query(`
        SELECT 
          id_route,
          name_route,
          ST_AsGeoJSON(path_route)::json as path_route,
          descrip_route,
          color_route,
          status_route,
          start_area,
          end_area,
          created_at,
          updated_at,
          user_create,
          user_update
        FROM tab_routes 
        WHERE status_route = TRUE 
        ORDER BY id_route
      `)
      
      // Transformar al formato del frontend
      return result.rows.map(row => ({
        id: row.id_route,  // ID numérico único
        code: `RUTA_${String(row.id_route).padStart(2, '0')}`,  // Código para display
        name: row.name_route,
        path: row.path_route?.coordinates || [],
        description: row.descrip_route || '',
        color: row.color_route || '#ef4444',
        status: row.status_route,
        visible: true,
        stops: [],
        buses: [],
        startArea: row.start_area,
        endArea: row.end_area,
        created_at: row.created_at,
        updated_at: row.updated_at,
        user_create: row.user_create,
        user_update: row.user_update
      }))
    } catch (error) {
      console.error('❌ Error obteniendo rutas:', error)
      throw error
    }
  }

  /**
   * Obtener ruta por ID
   */
  async getRouteById(id) {
    const routeId = Number(id)  // ID ya es numérico, solo asegurar tipo
    
    try {
      const result = await pool.query(`
        SELECT 
          id_route,
          name_route,
          ST_AsGeoJSON(path_route)::json as path_route,
          descrip_route,
          color_route,
          status_route,
          start_area,
          end_area,
          created_at,
          updated_at,
          user_create,
          user_update
        FROM tab_routes 
        WHERE id_route = $1 AND status_route = TRUE
      `, [routeId])
      
      if (result.rows.length === 0) {
        return null
      }
      
      const row = result.rows[0]
      
      return {
        id: row.id_route,
        code: `RUTA_${String(row.id_route).padStart(2, '0')}`,
        name: row.name_route,
        path: row.path_route?.coordinates || [],
        description: row.descrip_route || '',
        color: row.color_route || '#ef4444',
        status: row.status_route,
        visible: true,
        startArea: row.start_area,
        endArea: row.end_area,
        trips: [],
        stops: [],
        buses: [],
        created_at: row.created_at,
        updated_at: row.updated_at,
        user_create: row.user_create,
        user_update: row.user_update
      }
    } catch (error) {
      console.error('❌ Error obteniendo ruta por ID:', error)
      throw error
    }
  }

  /**
   * Crear nueva ruta
   */
  async createRoute(routeData) {
    const { name, color, description, path, user } = routeData
    
    // Validaciones básicas en el backend
    if (!name) {
      throw new Error('Nombre es requerido')
    }
    
    if (!path || path.length < 2) {
      throw new Error('Se requieren al menos 2 puntos para crear la ruta')
    }
    
    // Convertir array de coordenadas a WKT
    const lineStringWKT = `LINESTRING(${path.map(p => `${p[0]} ${p[1]}`).join(', ')})`
    
    try {
      const result = await pool.query(
        'SELECT * FROM fun_create_route($1, $2, $3, $4, $5)',
        [
          name,
          lineStringWKT,
          user || SYSTEM_USER_ID,
          description || '',
          color || null  // Enviar null para que use color automático de la paleta
        ]
      )
      
      const response = result.rows[0]
      
      // Verificar si la operación fue exitosa
      if (!response.success) {
        const error = new Error(response.msg)
        error.code = response.error_code
        throw error
      }
      
      // Parsear route_data que viene como JSON
      const routeDetails = response.route_data
      
      return {
        id: response.route_id,
        code: `RUTA_${String(response.route_id).padStart(2, '0')}`,
        name: routeDetails.name_route,
        path: routeDetails.path_route?.coordinates || [],
        description: routeDetails.descrip_route || '',
        color: routeDetails.color_route,
        status: routeDetails.status_route,
        visible: true,
        stops: [],
        buses: [],
        distance_km: routeDetails.distance_km,
        point_count: routeDetails.point_count,
        created_at: routeDetails.created_at,
        user_create: routeDetails.user_create,
        message: response.msg
      }
    } catch (error) {
      console.error('❌ Error creando ruta:', error.message)
      if (error.code) {
        console.error('   Código de error:', error.code)
      }
      throw error
    }
  }

   /**
   * Actualizar ruta existente (solo metadatos: nombre, color, descripción)
   */
  async updateRoute(id, routeData) {
    const routeId = Number(id)
    const { name, color, description, user } = routeData
    
    try {
      const result = await pool.query(
        'SELECT * FROM fun_update_route($1, $2, $3, $4, $5)',
        [
          routeId,
          user || SYSTEM_USER_ID,
          name || null,
          description || null,
          color || null
        ]
      )
      
      const response = result.rows[0]
      
      // Verificar si la operación fue exitosa
      if (!response.success) {
        const error = new Error(response.msg)
        error.code = response.error_code
        throw error
      }
      
      // Parsear route_data que viene como JSON
      const routeDetails = response.route_data
      
      return {
        id: routeDetails.id_route,
        code: `RUTA_${String(routeDetails.id_route).padStart(2, '0')}`,
        name: routeDetails.name_route,
        path: routeDetails.path_route?.coordinates || [],
        description: routeDetails.descrip_route || '',
        color: routeDetails.color_route,
        status: routeDetails.status_route,
        visible: true,
        stops: [],
        buses: [],
        distance_km: routeDetails.distance_km,
        point_count: routeDetails.point_count,
        updated_at: routeDetails.updated_at,
        user_update: routeDetails.user_update,
        message: response.msg
      }
    } catch (error) {
      console.error('❌ Error actualizando ruta:', error.message)
      if (error.code) {
        console.error('   Código de error:', error.code)
      }
      throw error
    }
  }


  /**
   * Eliminar ruta (soft delete)
   */
  async deleteRoute(id, user) {
    const routeId = Number(id)
    
    try {
      const result = await pool.query(
        'SELECT * FROM fun_delete_route($1, $2)',
        [routeId, user || SYSTEM_USER_ID]
      )
      
      const response = result.rows[0]
      
      // Si no fue exitoso, lanzar error con código específico
      if (!response.success) {
        const error = new Error(response.msg)
        error.code = response.error_code
        throw error
      }
      
      // Retornar éxito con advertencia si existe
      return {
        success: true,
        message: response.msg,
        warning: response.warning || null
      }
    } catch (error) {
      console.error('❌ Error eliminando ruta:', error.message)
      if (error.code) {
        console.error('   Código de error:', error.code)
      }
      throw error
    }
  }

  /**
   * Buscar rutas por nombre
   */
  async searchRoutes(searchTerm) {
    try {
      const result = await pool.query(`
        SELECT 
          id_route,
          name_route,
          ST_AsGeoJSON(path_route)::json as path_route,
          descrip_route,
          color_route,
          status_route
        FROM tab_routes 
        WHERE status_route = TRUE 
          AND (name_route ILIKE $1 OR descrip_route ILIKE $1)
        ORDER BY name_route
      `, [`%${searchTerm}%`])
      
      return result.rows.map(row => ({
        id: row.id_route,
        code: `RUTA_${String(row.id_route).padStart(2, '0')}`,
        name: row.name_route,
        path: row.path_route?.coordinates || [],
        description: row.descrip_route || '',
        color: row.color_route,
        status: row.status_route,
        visible: true,
        stops: [],
        buses: []
      }))
    } catch (error) {
      console.error('❌ Error buscando rutas:', error)
      throw error
    }
  }

  /**
   * Calcular distancia de ruta
   */
  async getRouteDistance(id) {
    const routeId = Number(id)
    
    try {
      const result = await pool.query(`
        SELECT 
          id_route,
          name_route,
          ROUND(ST_Length(path_route::geography) / 1000, 2) as distance_km
        FROM tab_routes 
        WHERE id_route = $1 AND status_route = TRUE
      `, [routeId])
      
      if (result.rows.length === 0) {
        return null
      }
      
      return {
        id: result.rows[0].id_route,
        code: `RUTA_${String(result.rows[0].id_route).padStart(2, '0')}`,
        name: result.rows[0].name_route,
        distance_km: result.rows[0].distance_km
      }
    } catch (error) {
      console.error('❌ Error calculando distancia:', error)
      throw error
    }
  }

  /**
   * Obtener viajes de una ruta
   */
  async getRouteTrips(id) {
    const routeId = Number(id)
    
    try {
      const result = await pool.query(`
        SELECT 
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
        ORDER BY trip_date DESC, start_time ASC
      `, [routeId])
      
      return result.rows
    } catch (error) {
      console.error('❌ Error obteniendo viajes:', error)
      throw error
    }
  }

  /**
   * Obtener estadísticas de una ruta
   */
  async getRouteStats(id) {
    const routeId = Number(id)
    
    try {
      const result = await pool.query(`
        SELECT 
          r.id_route,
          r.name_route,
          ROUND(ST_Length(r.path_route::geography) / 1000, 2) as distance_km,
          COUNT(DISTINCT t.id_trip) as total_trips,
          COUNT(DISTINCT t.plate_number) as assigned_buses,
          COUNT(DISTINCT CASE WHEN t.status_trip = 'active' THEN t.id_trip END) as active_trips
        FROM tab_routes r
        LEFT JOIN tab_trips t ON r.id_route = t.id_route
        WHERE r.id_route = $1 AND r.status_route = TRUE
        GROUP BY r.id_route, r.name_route, r.path_route
      `, [routeId])
      
      if (result.rows.length === 0) {
        return null
      }
      
      const row = result.rows[0]
      
      return {
        id: row.id_route,
        code: `RUTA_${String(row.id_route).padStart(2, '0')}`,
        name: row.name_route,
        distance_km: parseFloat(row.distance_km) || 0,
        total_trips: parseInt(row.total_trips) || 0,
        assigned_buses: parseInt(row.assigned_buses) || 0,
        active_trips: parseInt(row.active_trips) || 0
      }
    } catch (error) {
      console.error('❌ Error obteniendo estadísticas:', error)
      throw error
    }
  }

  /**
   * Alternar visibilidad (solo frontend, no BD)
   */
  async toggleVisibility(id) {
    const routeId = Number(id)
    
    try {
      const result = await pool.query(
        'SELECT id_route FROM tab_routes WHERE id_route = $1 AND status_route = TRUE',
        [routeId]
      )
      
      if (result.rows.length === 0) {
        return null
      }
      
      return {
        id: result.rows[0].id_route,
        code: `RUTA_${String(result.rows[0].id_route).padStart(2, '0')}`,
        visible: true
      }
    } catch (error) {
      console.error('❌ Error alternando visibilidad:', error)
      throw error
    }
  }
}

export default new RoutesService()
