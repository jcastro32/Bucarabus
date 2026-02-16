import pool from '../config/database.js'

class AssignmentsService {
  /**
   * Asignar conductor a bus
   * @param {string} plateNumber - Placa del bus
   * @param {number} idUser - ID del usuario conductor (id_user) o NULL para desasignar
   * @param {string} user - Usuario que realiza la acción
   */
  async assignDriver(plateNumber, idUser, user) {
    try {
      const result = await pool.query(
        `SELECT * FROM fun_assign_driver($1, $2, $3)`,
        [plateNumber.toUpperCase(), idUser, user]
      );
      const response = result.rows[0];
      return {
        success: response.success,
        message: response.msg,
        error_code: response.error_code
      };
    } catch (error) {
      console.error('Error en assignDriver:', error);
      return {
        success: false,
        message: 'Error interno: ' + error.message,
        error_code: 'INTERNAL_ERROR'
      };
    }
  }

  /**
   * Desasignar conductor de bus (pasar null como idUser)
   */
  async unassignDriver(plateNumber, user) {
    return this.assignDriver(plateNumber, null, user);
  }

  /**
   * Obtener historial de asignaciones de un bus
   */
  async getBusHistory(plateNumber) {
    try {
      const result = await pool.query(`
        SELECT 
          a.id_assignment,
          a.plate_number,
          a.id_user,
          u.full_name AS name_driver,
          dd.id_card,
          a.assigned_at,
          a.unassigned_at,
          a.assigned_by,
          a.unassigned_by
        FROM tab_bus_assignments a
        LEFT JOIN tab_driver_details dd ON a.id_user = dd.id_user
        LEFT JOIN tab_users u ON dd.id_user = u.id_user
        WHERE a.plate_number = $1
        ORDER BY a.assigned_at DESC
      `, [plateNumber.toUpperCase()]);
      
      return { success: true, data: result.rows };
    } catch (error) {
      console.error('Error en getBusHistory:', error);
      return { success: false, message: error.message };
    }
  }
}

export default new AssignmentsService();
