import pool from '../config/database.js';
import bcrypt from 'bcrypt';

const SALT_ROUNDS = 10;
const SYSTEM_USER_ID = 1;

class DriversService {
  /**
   * Obtener todos los conductores
   * @param {boolean} onlyActive - Si true, solo retorna conductores activos
   */
  async getAllDrivers(onlyActive = false) {
    try {
      let query = `
        SELECT 
          u.id_user,
          u.email,
          u.full_name AS name_driver,
          u.avatar_url AS photo_driver,
          u.is_active AS status_driver,
          dd.id_card,
          dd.cel,
          dd.license_cat,
          dd.license_exp,
          dd.address_driver,
          dd.available
        FROM tab_users u
        INNER JOIN tab_user_roles ur ON u.id_user = ur.id_user
        INNER JOIN tab_driver_details dd ON u.id_user = dd.id_user
        WHERE ur.id_role = 2 AND ur.is_active = true
      `;
      
      if (onlyActive) {
        query += ' AND u.is_active = TRUE';
      }
      
      query += ' ORDER BY u.full_name';
      
      const result = await pool.query(query);
      
      return {
        success: true,
        data: result.rows
      };
    } catch (error) {
      console.error('Error en getAllDrivers:', error);
      throw error;
    }
  }

  /**
   * Obtener conductor por ID
   * @param {number} idUser - ID del usuario conductor
   */
  async getDriverById(idUser) {
    try {
      const result = await pool.query(
        `SELECT 
          u.id_user,
          u.email,
          u.full_name AS name_driver,
          u.avatar_url AS photo_driver,
          u.is_active AS status_driver,
          dd.id_card,
          dd.cel,
          dd.license_cat,
          dd.license_exp,
          dd.address_driver,
          dd.available
        FROM tab_users u
        INNER JOIN tab_user_roles ur ON u.id_user = ur.id_user
        INNER JOIN tab_driver_details dd ON u.id_user = dd.id_user
        WHERE u.id_user = $1 AND ur.id_role = 2`,
        [idUser]
      );
      
      if (result.rows.length === 0) {
        return {
          success: false,
          message: 'Conductor no encontrado'
        };
      }

      return {
        success: true,
        data: result.rows[0]
      };
    } catch (error) {
      console.error('Error en getDriverById:', error);
      throw error;
    }
  }

  /**
   * Crear nuevo conductor (nueva arquitectura: usuario + detalles)
   */
  async createDriver(driverData) {
    try {
      console.log('🔍 createDriver recibió:', JSON.stringify(driverData, null, 2));

      const {
        email,
        password,
        full_name,
        id_card,
        cel,
        license_cat,
        license_exp,
        avatar_url = null,
        address_driver = null,
        user_create = SYSTEM_USER_ID
      } = driverData;

      console.log('📋 Valores extraídos:');
      console.log('  - email:', email);
      console.log('  - password:', password ? '***' : 'VACÍO');
      console.log('  - full_name:', full_name);
      console.log('  - id_card:', id_card);
      console.log('  - cel:', cel);
      console.log('  - license_cat:', license_cat);
      console.log('  - license_exp:', license_exp);

      // 1. Hashear password con bcrypt
      const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

      // 2. Llamar a fun_create_driver con nueva firma
      const result = await pool.query(
        `SELECT * FROM fun_create_driver($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
        [
          email,
          passwordHash,
          full_name,
          id_card,
          cel,
          license_cat,
          license_exp,
          user_create,
          avatar_url,
          address_driver
        ]
      );

      // 3. El resultado es un tipo personalizado
      if (result.rows.length === 0) {
        throw new Error('No se recibió respuesta de la función');
      }

      const functionResult = result.rows[0];
      console.log('📥 Resultado de fun_create_driver:', functionResult);

      // 3.1 Verificar si la función reportó error
      if (!functionResult.success) {
        throw new Error(functionResult.msg || 'Error al crear conductor');
      }

      // 4. Verificar el usuario creado
      const userCheck = await pool.query(
        'SELECT id_user, email, full_name FROM tab_users WHERE email = $1',
        [email]
      );

      if (userCheck.rows.length === 0) {
        console.error('❌ Usuario NO encontrado después de fun_create_driver');
        console.error('   Email buscado:', email);
        console.error('   Resultado de función:', functionResult);
        throw new Error('Usuario no creado correctamente');
      }

      const createdUser = userCheck.rows[0];

      return {
        success: true,
        message: `Conductor creado exitosamente: ${full_name}`,
        data: {
          id_user: createdUser.id_user,
          email: createdUser.email,
          full_name: createdUser.full_name,
          id_card: id_card
        }
      };

    } catch (error) {
      console.error('❌ Error en createDriver:', error);
      
      // Manejar errores específicos de PostgreSQL
      if (error.message) {
        // Errores de la función (RAISE EXCEPTION)
        if (error.message.includes('ya está registrado')) {
          return {
            success: false,
            message: error.message
          };
        }
        
        if (error.message.includes('duplicado') || error.message.includes('duplicate')) {
          return {
            success: false,
            message: 'El email o cédula ya están registrados'
          };
        }
      }
      
      if (error.code === '23505') { // Unique violation
        return {
          success: false,
          message: 'El email o cédula ya están registrados'
        };
      }
      
      return {
        success: false,
        message: error.message || 'Error al crear conductor'
      };
    }
  }

  /**
   * Actualizar conductor (nueva arquitectura: usuario + detalles)
   */
  async updateDriver(idUser, driverData) {
    try {
      const {
        name_driver,     // full_name
        cel,
        license_cat,
        license_exp,
        address_driver = null,
        photo_driver = null,  // avatar_url
        available = true,
        user_update = SYSTEM_USER_ID
      } = driverData;

      console.log('📤 Actualizando conductor ID:', idUser, 'con datos:', driverData);

      const result = await pool.query(
        `SELECT * FROM fun_update_driver($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
        [
          idUser,
          user_update,
          name_driver,      // full_name
          photo_driver,     // avatar_url
          cel,
          license_cat,
          license_exp,
          address_driver,
          available
        ]
      );

      if (result.rows.length === 0) {
        throw new Error('No se recibió respuesta de la función');
      }

      const updatedDriver = result.rows[0];
      
      console.log('📥 Conductor actualizado:', updatedDriver);
      
      return {
        success: true,
        message: `Conductor actualizado exitosamente: ${updatedDriver.full_name}`,
        data: updatedDriver
      };

    } catch (error) {
      console.error('❌ Error en updateDriver:', error);
      
      // Manejar errores específicos
      if (error.message) {
        if (error.message.includes('no existe')) {
          return {
            success: false,
            message: error.message
          };
        }
        
        if (error.message.includes('vencida') || error.message.includes('expira')) {
          return {
            success: false,
            message: 'La licencia debe tener una fecha de vencimiento futura'
          };
        }
      }
      
      return {
        success: false,
        message: error.message || 'Error al actualizar conductor'
      };
    }
  }

  /**
   * Cambiar disponibilidad del conductor (nueva arquitectura)
   */
  async toggleAvailability(idUser, available) {
    try {
      const result = await pool.query(
        `UPDATE tab_driver_details 
         SET available = $1, updated_at = NOW() 
         WHERE id_user = $2 
         RETURNING id_user, available`,
        [available, idUser]
      );

      if (result.rows.length === 0) {
        return {
          success: false,
          message: 'Conductor no encontrado'
        };
      }
      
      return {
        success: true,
        message: 'Disponibilidad actualizada correctamente',
        data: result.rows[0]
      };
    } catch (error) {
      console.error('❌ Error en toggleAvailability:', error);
      return {
        success: false,
        message: error.message || 'Error al actualizar disponibilidad'
      };
    }
  }

  /**
   * Activar/Inactivar conductor (actualiza tab_users y tab_driver_details)
   */
  async toggleStatus(idUser, status) {
    try {
      // Actualizar is_active en tab_users
      await pool.query(
        `UPDATE tab_users 
         SET is_active = $1, updated_at = NOW() 
         WHERE id_user = $2`,
        [status, idUser]
      );

      // Actualizar is_active en tab_user_roles para el rol de conductor
      await pool.query(
        `UPDATE tab_user_roles 
         SET is_active = $1 
         WHERE id_user = $2 AND id_role = 2`,
        [status, idUser]
      );

      // Si se inactiva, también marcar como no disponible
      if (!status) {
        await pool.query(
          `UPDATE tab_driver_details 
           SET available = FALSE, status_driver = FALSE 
           WHERE id_user = $1`,
          [idUser]
        );
      }
      
      return {
        success: true,
        message: status ? 'Conductor activado correctamente' : 'Conductor inactivado correctamente'
      };
    } catch (error) {
      console.error('Error en toggleStatus:', error);
      throw error;
    }
  }

  /**
   * Obtener conductores disponibles (consulta directa)
   */
  async getAvailableDrivers() {
    try {
      const result = await pool.query(
        `SELECT 
          u.id_user,
          u.full_name AS name_driver,
          dd.id_card,
          dd.cel,
          u.email,
          dd.license_cat,
          dd.license_exp
         FROM tab_users u
         INNER JOIN tab_user_roles ur ON u.id_user = ur.id_user
         INNER JOIN tab_driver_details dd ON u.id_user = dd.id_user
         WHERE ur.id_role = 2
           AND u.is_active = TRUE
           AND ur.is_active = TRUE 
           AND dd.available = TRUE 
           AND dd.license_exp > CURRENT_DATE
         ORDER BY u.full_name`
      );
      
      return {
        success: true,
        data: result.rows
      };
    } catch (error) {
      console.error('Error en getAvailableDrivers:', error);
      throw error;
    }
  }

  /**
   * Eliminar conductor (soft delete - inactivar en tab_users, tab_user_roles, tab_driver_details)
   */
  async deleteDriver(idUser) {
    try {
      const result = await pool.query(
        'SELECT * FROM fun_delete_driver($1)',
        [idUser]
      );

      if (result.rows.length === 0) {
        throw new Error('Conductor no encontrado o no pudo ser eliminado');
      }

      const deletedDriver = result.rows[0];
      
      return {
        success: true,
        message: 'Conductor eliminado exitosamente',
        data: deletedDriver
      };
    } catch (error) {
      console.error('Error en deleteDriver:', error);
      
      // Manejar errores específicos de la función PostgreSQL
      if (error.message?.includes('no existe')) {
        throw new Error('El conductor especificado no existe');
      }
      if (error.message?.includes('no es conductor')) {
        throw new Error('El usuario especificado no es un conductor');
      }
      
      throw error;
    }
  }
}

export default new DriversService()
