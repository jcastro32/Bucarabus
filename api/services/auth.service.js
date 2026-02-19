import pool from '../config/database.js'
import bcrypt from 'bcrypt'

class AuthService {
  /**
   * Autenticar usuario con email y contraseña
   * @param {string} email - Email del usuario
   * @param {string} password - Contraseña en texto plano
   * @returns {Promise<Object>} Resultado de autenticación
   */
  async login(email, password) {
    try {
      console.log('🔐 Intentando login:', email)
      
      // 1. Obtener usuario de la base de datos
      const result = await pool.query(
        `SELECT 
          id_user,
          email,
          password_hash,
          full_name,
          avatar_url,
          is_active,
          last_login
        FROM tab_users
        WHERE LOWER(email) = LOWER($1)`,
        [email]
      )
      
      if (result.rows.length === 0) {
        console.log('❌ Usuario no encontrado:', email)
        return {
          success: false,
          message: 'Usuario no encontrado',
          error_code: 'USER_NOT_FOUND'
        }
      }
      
      const user = result.rows[0]
      
      // 2. Verificar si el usuario está activo
      if (!user.is_active) {
        console.log('❌ Usuario inactivo:', email)
        return {
          success: false,
          message: 'Usuario desactivado. Contacta al administrador',
          error_code: 'USER_INACTIVE'
        }
      }
      
      // 3. Comparar contraseña con bcrypt
      const passwordMatch = await bcrypt.compare(password, user.password_hash)
      
      if (!passwordMatch) {
        console.log('❌ Contraseña incorrecta para:', email)
        return {
          success: false,
          message: 'Contraseña incorrecta',
          error_code: 'INVALID_PASSWORD'
        }
      }
      
      // 4. Obtener roles del usuario
      const rolesResult = await pool.query(
        `SELECT 
          r.id_role,
          r.role_name,
          r.description
        FROM tab_user_roles ur
        INNER JOIN tab_roles r ON ur.id_role = r.id_role
        WHERE ur.id_user = $1 
          AND ur.is_active = TRUE
          AND r.is_active = TRUE`,
        [user.id_user]
      )
      
      // 5. Actualizar último login
      await pool.query(
        `UPDATE tab_users SET last_login = NOW() WHERE id_user = $1`,
        [user.id_user]
      )
      
      // 6. Construir datos del usuario (sin password_hash)
      const userData = {
        id_user: user.id_user,
        email: user.email,
        full_name: user.full_name,
        avatar_url: user.avatar_url,
        is_active: user.is_active,
        last_login: user.last_login,
        roles: rolesResult.rows
      }
      
      console.log('✅ Login exitoso:', email, '- Roles:', rolesResult.rows.map(r => r.role_name).join(', '))
      
      return {
        success: true,
        message: 'Autenticación exitosa',
        data: userData
      }
      
    } catch (error) {
      console.error('❌ Error en login:', error)
      return {
        success: false,
        message: 'Error del servidor al autenticar',
        error_code: 'SERVER_ERROR'
      }
    }
  }
  
  /**
   * Verificar si un email existe en la base de datos
   * @param {string} email - Email a verificar
   * @returns {Promise<boolean>} true si existe, false si no
   */
  async emailExists(email) {
    try {
      const result = await pool.query(
        `SELECT EXISTS(SELECT 1 FROM tab_users WHERE LOWER(email) = LOWER($1))`,
        [email]
      )
      return result.rows[0].exists
    } catch (error) {
      console.error('Error verificando email:', error)
      return false
    }
  }
}

export default new AuthService()
