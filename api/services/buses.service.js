import pool from '../config/database.js'

class BusesService {
  /**
   * Obtener todos los buses
   * @param {boolean} onlyActive - Si true, solo retorna buses activos
   */
  async getAllBuses(onlyActive = false) {
    try {
      let query = `
        SELECT 
          b.plate_number,
          b.amb_code,
          b.id_user,
          b.id_company,
          b.capacity::INTEGER as capacity,
          b.photo_url,
          b.soat_exp,
          b.techno_exp,
          b.rcc_exp,
          b.rce_exp,
          b.id_card_owner,
          b.name_owner,
          b.is_active,
          b.created_at,
          b.updated_at,
          b.user_create,
          b.user_update,
          a.assigned_at as assignment_date
        FROM tab_buses b
        LEFT JOIN tab_bus_assignments a 
          ON b.plate_number = a.plate_number 
          AND a.unassigned_at IS NULL
      `;
      
      if (onlyActive) {
        query += ' WHERE b.is_active = TRUE';
      }
      
      query += ' ORDER BY b.plate_number';
      
      const result = await pool.query(query);
      
      return {
        success: true,
        data: result.rows
      };
    } catch (error) {
      console.error('Error en getAllBuses:', error);
      throw error;
    }
  }

  /**
   * Obtener bus por placa
   * @param {string} plateNumber - Placa del bus
   */
  async getBusByPlate(plateNumber) {
    try {
      const result = await pool.query(
        `SELECT 
          plate_number,
          amb_code,
          id_user,
          id_company,
          capacity::INTEGER as capacity,
          photo_url,
          soat_exp,
          techno_exp,
          rcc_exp,
          rce_exp,
          id_card_owner,
          name_owner,
          is_active,
          created_at,
          updated_at,
          user_create,
          user_update
        FROM tab_buses 
        WHERE plate_number = $1`,
        [plateNumber.toUpperCase()]
      );
      
      if (result.rows.length === 0) {
        return {
          success: false,
          message: 'Bus no encontrado'
        };
      }

      return {
        success: true,
        data: result.rows[0]
      };
    } catch (error) {
      console.error('Error en getBusByPlate:', error);
      throw error;
    }
  }

  /**
   * Obtener buses disponibles (activos y sin conductor asignado)
   */
  async getAvailableBuses() {
    try {
      const result = await pool.query(
        `SELECT 
          plate_number,
          amb_code,
          id_user,
          id_company,
          capacity::INTEGER as capacity,
          photo_url,
          soat_exp,
          techno_exp,
          rcc_exp,
          rce_exp,
          id_card_owner,
          name_owner,
          is_active,
          created_at,
          updated_at,
          user_create,
          user_update
        FROM tab_buses 
         WHERE is_active = TRUE 
         AND id_user IS NULL 
         ORDER BY plate_number`
      );
      
      return {
        success: true,
        data: result.rows
      };
    } catch (error) {
      console.error('Error en getAvailableBuses:', error);
      throw error;
    }
  }

  /**
   * Crear nuevo bus
   */
  async createBus(busData) {
    try {
      const {
        plate_number,
        amb_code,
        id_company,
        capacity,
        photo_url = null,
        soat_exp,
        techno_exp,
        rcc_exp,
        rce_exp,
        id_card_owner,
        name_owner,
        user_create = 'system'
      } = busData;

      const result = await pool.query(
        `SELECT * FROM fun_create_bus($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
        [
          plate_number,
          amb_code,
          id_company,
          capacity,
          photo_url,
          soat_exp,
          techno_exp,
          rcc_exp,
          rce_exp,
          id_card_owner,
          name_owner,
          user_create
        ]
      );

      const response = result.rows[0];
      
      // Si fue exitoso, obtener el bus recién creado
      if (response.success) {
        const busResult = await this.getBusByPlate(plate_number);
        return {
          success: true,
          message: response.msg,
          data: busResult.data
        };
      }
      
      return {
        success: response.success,
        message: response.msg,
        error_code: response.error_code
      };
    } catch (error) {
      console.error('Error en createBus:', error);
      return {
        success: false,
        message: 'Error interno al crear bus: ' + error.message,
        error_code: 'INTERNAL_ERROR'
      };
    }
  }

  /**
   * Actualizar bus existente
   */
  async updateBus(plateNumber, busData) {
    try {
      const {
        amb_code,
        id_company,
        capacity,
        photo_url = null,
        soat_exp,
        techno_exp,
        rcc_exp,
        rce_exp,
        id_card_owner,
        name_owner,
        is_active = true,
        user_update = 'system'
      } = busData;

      const result = await pool.query(
        `SELECT * FROM fun_update_bus($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)`,
        [
          plateNumber.toUpperCase(),
          amb_code,
          id_company,
          capacity,
          photo_url,
          soat_exp,
          techno_exp,
          rcc_exp,
          rce_exp,
          id_card_owner,
          name_owner,
          is_active,
          user_update
        ]
      );

      const response = result.rows[0];
      
      // Si fue exitoso, obtener el bus actualizado
      if (response.success) {
        const busResult = await this.getBusByPlate(plateNumber);
        return {
          success: true,
          message: response.msg,
          data: busResult.data
        };
      }
      
      return {
        success: response.success,
        message: response.msg,
        error_code: response.error_code
      };
    } catch (error) {
      console.error('Error en updateBus:', error);
      return {
        success: false,
        message: 'Error interno al actualizar bus: ' + error.message,
        error_code: 'INTERNAL_ERROR'
      };
    }
  }

  /**
   * Cambiar estado del bus (activar/desactivar)
   */
  async toggleBusStatus(plateNumber, isActive, userUpdate = 'system') {
    try {
      const result = await pool.query(
        `SELECT * FROM fun_toggle_bus_status($1, $2, $3)`,
        [plateNumber.toUpperCase(), isActive, userUpdate]
      );

      const response = result.rows[0];
      
      // Si fue exitoso, obtener el bus actualizado
      if (response.success) {
        const busResult = await this.getBusByPlate(plateNumber);
        return {
          success: true,
          message: response.msg,
          data: busResult.data
        };
      }
      
      return {
        success: response.success,
        message: response.msg,
        error_code: response.error_code
      };
    } catch (error) {
      console.error('Error en toggleBusStatus:', error);
      return {
        success: false,
        message: 'Error interno al cambiar estado del bus: ' + error.message,
        error_code: 'INTERNAL_ERROR'
      };
    }
  }

  /**
   * Eliminar bus (soft delete - desactivar)
   */
  async deleteBus(plateNumber, userUpdate = 'system') {
    return this.toggleBusStatus(plateNumber, false, userUpdate);
  }

  /**
   * Obtener buses con documentos próximos a vencer
   * @param {number} days - Número de días para considerar "próximo a vencer"
   */
  async getBusesWithExpiringDocs(days = 30) {
    try {
      const result = await pool.query(
        `SELECT 
          plate_number,
          amb_code,
          id_user,
          id_company,
          capacity::INTEGER as capacity,
          photo_url,
          soat_exp,
          techno_exp,
          rcc_exp,
          rce_exp,
          id_card_owner,
          name_owner,
          is_active,
          created_at,
          updated_at,
          user_create,
          user_update
        FROM tab_buses 
         WHERE is_active = TRUE 
         AND (
           soat_exp <= CURRENT_DATE + INTERVAL '${days} days' OR
           techno_exp <= CURRENT_DATE + INTERVAL '${days} days' OR
           rcc_exp <= CURRENT_DATE + INTERVAL '${days} days' OR
           rce_exp <= CURRENT_DATE + INTERVAL '${days} days'
         )
         ORDER BY LEAST(soat_exp, techno_exp, rcc_exp, rce_exp)`
      );
      
      return {
        success: true,
        data: result.rows
      };
    } catch (error) {
      console.error('Error en getBusesWithExpiringDocs:', error);
      throw error;
    }
  }

  /**
   * Obtener estadísticas de buses
   */
  async getBusStats() {
    try {
      const result = await pool.query(`
        SELECT 
          COUNT(*) as total,
          COUNT(*) FILTER (WHERE is_active = TRUE) as active,
          COUNT(*) FILTER (WHERE is_active = FALSE) as inactive,
          COUNT(*) FILTER (WHERE is_active = TRUE AND id_user IS NULL) as available,
          COALESCE(SUM(capacity) FILTER (WHERE is_active = TRUE), 0) as total_capacity
        FROM tab_buses
      `);
      
      return {
        success: true,
        data: result.rows[0]
      };
    } catch (error) {
      console.error('Error en getBusStats:', error);
      throw error;
    }
  }
}

export default new BusesService();
