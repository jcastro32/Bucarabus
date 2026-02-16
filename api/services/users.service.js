import pool from '../config/database.js'
import bcrypt from 'bcrypt'

const SALT_ROUNDS = 10

/**
 * Servicio para gestión de usuarios
 * Conecta con las funciones almacenadas: fun_create_user, fun_update_user
 */

/**
 * Obtener todos los usuarios (con sus roles)
 * @param {Object} filters - Filtros opcionales
 * @param {number} filters.role - ID del rol para filtrar
 * @param {boolean} filters.active - Estado activo/inactivo
 * @returns {Promise<Object>} - { success, data, message }
 */
async function getAllUsers(filters = {}) {
  try {
    let query = `
      SELECT 
        u.id_user,
        u.email,
        u.full_name,
        u.avatar_url,
        u.created_at,
        u.updated_at,
        u.last_login,
        u.is_active,
        json_agg(
          json_build_object(
            'id_role', ur.id_role,
            'role_name', r.role_name,
            'assigned_at', ur.assigned_at
          ) ORDER BY ur.id_role
        ) FILTER (WHERE ur.id_role IS NOT NULL) as roles
      FROM tab_users u
      LEFT JOIN tab_user_roles ur ON u.id_user = ur.id_user AND ur.is_active = true
      LEFT JOIN tab_roles r ON ur.id_role = r.id_role
    `

    const conditions = []
    const params = []

    if (filters.role) {
      conditions.push(`u.id_user IN (
        SELECT user_id FROM tab_user_roles 
        WHERE id_role = $${params.length + 1} AND is_active = true
      )`)
      params.push(filters.role)
    }

    if (filters.active !== undefined) {
      conditions.push(`u.is_active = $${params.length + 1}`)
      params.push(filters.active)
    }

    if (conditions.length > 0) {
      query += ' WHERE ' + conditions.join(' AND ')
    }

    query += ' GROUP BY u.id_user ORDER BY u.created_at DESC'

    const result = await pool.query(query, params)

    return {
      success: true,
      data: result.rows,
      count: result.rows.length
    }
  } catch (error) {
    console.error('Error en getAllUsers:', error)
    return {
      success: false,
      message: 'Error al obtener usuarios',
      error: error.message
    }
  }
}

/**
 * Obtener usuario por ID (con sus roles)
 * @param {number} userId - ID del usuario
 * @returns {Promise<Object>} - { success, data, message }
 */
async function getUserById(userId) {
  try {
    const query = `
      SELECT 
        u.id_user,
        u.email,
        u.full_name,
        u.avatar_url,
        u.created_at,
        u.updated_at,
        u.last_login,
        u.is_active,
        json_agg(
          json_build_object(
            'id_role', ur.id_role,
            'role_name', r.role_name,
            'assigned_at', ur.assigned_at
          ) ORDER BY ur.id_role
        ) FILTER (WHERE ur.id_role IS NOT NULL) as roles
      FROM tab_users u
      LEFT JOIN tab_user_roles ur ON u.id_user = ur.id_user AND ur.is_active = true
      LEFT JOIN tab_roles r ON ur.id_role = r.id_role
      WHERE u.id_user = $1
      GROUP BY u.id_user
    `

    const result = await pool.query(query, [userId])

    if (result.rows.length === 0) {
      return {
        success: false,
        message: `Usuario con ID ${userId} no encontrado`
      }
    }

    return {
      success: true,
      data: result.rows[0]
    }
  } catch (error) {
    console.error('Error en getUserById:', error)
    return {
      success: false,
      message: 'Error al obtener usuario',
      error: error.message
    }
  }
}

/**
 * Crear nuevo usuario
 * Conecta con fun_create_user que:
 * - Valida email, nombre, password hash
 * - Genera ID automáticamente
 * - Asigna rol inicial (Pasajero por defecto)
 * 
 * @param {Object} userData - Datos del usuario
 * @param {string} userData.email - Email (único)
 * @param {string} userData.password - Contraseña en texto plano (se hasheará)
 * @param {string} userData.full_name - Nombre completo
 * @param {string} userData.avatar_url - URL del avatar (opcional)
 * @param {number} userData.initial_role - Rol inicial (1=Pasajero por defecto)
 * @returns {Promise<Object>} - { success, data, message }
 */
async function createUser(userData) {
  const client = await pool.connect()
  
  try {
    const { email, password, full_name, avatar_url, initial_role = 1, user_create = 'system' } = userData

    console.log('📝 createUser - Datos recibidos:', { email, full_name, avatar_url, initial_role, user_create, passwordLength: password?.length })

    // Validaciones básicas
    if (!email || !password || !full_name) {
      console.log('❌ Validación falló: campos requeridos faltantes')
      return {
        success: false,
        message: 'Email, contraseña y nombre completo son requeridos'
      }
    }

    if (password.length < 8) {
      console.log('❌ Validación falló: contraseña muy corta')
      return {
        success: false,
        message: 'La contraseña debe tener al menos 8 caracteres'
      }
    }

    // Hashear contraseña con bcrypt
    console.log('🔐 Hasheando contraseña...')
    const password_hash = await bcrypt.hash(password, SALT_ROUNDS)
    console.log('✅ Contraseña hasheada correctamente, longitud:', password_hash.length)

    // Llamar a la función almacenada
    const query = `
      SELECT * FROM fun_create_user($1, $2, $3, $4, $5)
    `

    console.log('📞 Llamando a fun_create_user con:', { email, full_name, avatar_url, user_create })
    const result = await client.query(query, [
      email,
      password_hash,
      full_name,
      avatar_url || null,
      user_create
    ])

    console.log('✅ fun_create_user ejecutada, filas retornadas:', result.rows.length)

    if (result.rows.length === 0) {
      throw new Error('No se pudo crear el usuario')
    }

    const newUser = result.rows[0]
    console.log('👤 Usuario creado con ID:', newUser.id_user)

    // Si se especificó un rol diferente a Pasajero (1), agregarlo
    if (initial_role && initial_role !== 1) {
      console.log(`➕ Agregando rol adicional: ${initial_role}`)
      await client.query(
        'INSERT INTO tab_user_roles (id_user, id_role) VALUES ($1, $2) ON CONFLICT (id_user, id_role) DO NOTHING',
        [newUser.id_user, initial_role]
      )
    }

    // Obtener usuario completo con todos sus roles
    console.log('🔍 Obteniendo usuario completo con roles...')
    const userResult = await getUserById(newUser.id_user)

    console.log('✅ Usuario creado exitosamente')
    return {
      success: true,
      data: userResult.data,
      message: 'Usuario creado exitosamente'
    }
  } catch (error) {
    console.error('❌ Error en createUser:')
    console.error('   Mensaje:', error.message)
    console.error('   Stack:', error.stack)
    
    // Errores específicos de la función SQL
    if (error.message.includes('Email ya está registrado')) {
      return {
        success: false,
        message: 'El email ya está registrado'
      }
    }

    if (error.message.includes('Email tiene formato inválido')) {
      return {
        success: false,
        message: 'El email tiene un formato inválido'
      }
    }

    if (error.message.includes('Nombre')) {
      return {
        success: false,
        message: error.message
      }
    }

    return {
      success: false,
      message: 'Error al crear usuario',
      error: error.message
    }
  } finally {
    client.release()
  }
}

/**
 * Actualizar usuario (nombre y avatar)
 * Conecta con fun_update_user
 * 
 * @param {number} userId - ID del usuario
 * @param {Object} updates - Campos a actualizar
 * @param {string} updates.full_name - Nuevo nombre (opcional)
 * @param {string} updates.avatar_url - Nueva URL avatar (opcional)
 * @returns {Promise<Object>} - { success, data, message }
 */
async function updateUser(userId, updates) {
  try {
    const { full_name, avatar_url, user_update = 'system' } = updates

    // Llamar a la función almacenada
    const query = `
      SELECT * FROM fun_update_user($1, $2, $3, $4)
    `

    const result = await pool.query(query, [
      userId,
      full_name || null,
      avatar_url !== undefined ? avatar_url : null,
      user_update
    ])

    if (result.rows.length === 0) {
      return {
        success: false,
        message: `Usuario con ID ${userId} no encontrado`
      }
    }

    return {
      success: true,
      data: result.rows[0],
      message: 'Usuario actualizado exitosamente'
    }
  } catch (error) {
    console.error('Error en updateUser:', error)

    if (error.message.includes('no existe')) {
      return {
        success: false,
        message: `Usuario con ID ${userId} no encontrado`
      }
    }

    if (error.message.includes('Nombre')) {
      return {
        success: false,
        message: error.message
      }
    }

    return {
      success: false,
      message: 'Error al actualizar usuario',
      error: error.message
    }
  }
}

/**
 * Cambiar contraseña de usuario
 * @param {number} userId - ID del usuario
 * @param {string} newPassword - Nueva contraseña en texto plano
 * @returns {Promise<Object>} - { success, message }
 */
async function changePassword(userId, newPassword) {
  try {
    if (!newPassword || newPassword.length < 8) {
      return {
        success: false,
        message: 'La contraseña debe tener al menos 8 caracteres'
      }
    }

    // Verificar que el usuario existe
    const userExists = await pool.query(
      'SELECT id_user FROM tab_users WHERE id_user = $1',
      [userId]
    )

    if (userExists.rows.length === 0) {
      return {
        success: false,
        message: `Usuario con ID ${userId} no encontrado`
      }
    }

    // Hashear nueva contraseña
    const password_hash = await bcrypt.hash(newPassword, SALT_ROUNDS)

    // Actualizar contraseña
    await pool.query(
      'UPDATE tab_users SET password_hash = $1, updated_at = NOW() WHERE id_user = $2',
      [password_hash, userId]
    )

    return {
      success: true,
      message: 'Contraseña actualizada exitosamente'
    }
  } catch (error) {
    console.error('Error en changePassword:', error)
    return {
      success: false,
      message: 'Error al cambiar contraseña',
      error: error.message
    }
  }
}

/**
 * Activar/Desactivar usuario
 * @param {number} userId - ID del usuario
 * @param {boolean} isActive - Estado activo (true/false)
 * @returns {Promise<Object>} - { success, message }
 */
async function toggleUserStatus(userId, isActive) {
  try {
    const result = await pool.query(
      `UPDATE tab_users 
       SET is_active = $1, updated_at = NOW() 
       WHERE id_user = $2 
       RETURNING id_user, is_active`,
      [isActive, userId]
    )

    if (result.rows.length === 0) {
      return {
        success: false,
        message: `Usuario con ID ${userId} no encontrado`
      }
    }

    return {
      success: true,
      data: result.rows[0],
      message: `Usuario ${isActive ? 'activado' : 'desactivado'} exitosamente`
    }
  } catch (error) {
    console.error('Error en toggleUserStatus:', error)
    return {
      success: false,
      message: 'Error al cambiar estado del usuario',
      error: error.message
    }
  }
}

/**
 * Obtener roles de un usuario
 * @param {number} userId - ID del usuario
 * @returns {Promise<Object>} - { success, data }
 */
async function getUserRoles(userId) {
  try {
    const query = `
      SELECT 
        r.id_role,
        r.role_name,
        ur.assigned_at,
        ur.is_active
      FROM tab_user_roles ur
      JOIN tab_roles r ON ur.id_role = r.id_role
      WHERE ur.id_user = $1 AND ur.is_active = true
      ORDER BY r.id_role
    `

    const result = await pool.query(query, [userId])

    return {
      success: true,
      data: result.rows
    }
  } catch (error) {
    console.error('Error en getUserRoles:', error)
    return {
      success: false,
      message: 'Error al obtener roles del usuario',
      error: error.message
    }
  }
}

/**
 * Asignar rol a usuario
 * @param {number} userId - ID del usuario
 * @param {number} roleId - ID del rol (1=Pasajero, 2=Conductor, 3=Supervisor, 4=Admin)
 * @param {number} assignedBy - ID del usuario que asigna el rol
 * @returns {Promise<Object>} - { success, message }
 */
async function assignRole(userId, roleId, assignedBy = null) {
  try {
    // Verificar que el usuario existe
    const userExists = await pool.query(
      'SELECT id_user FROM tab_users WHERE id_user = $1',
      [userId]
    )

    if (userExists.rows.length === 0) {
      return {
        success: false,
        message: `Usuario con ID ${userId} no encontrado`
      }
    }

    // Verificar que el rol existe
    const roleExists = await pool.query(
      'SELECT id_role FROM tab_roles WHERE id_role = $1 AND is_active = true',
      [roleId]
    )

    if (roleExists.rows.length === 0) {
      return {
        success: false,
        message: `Rol con ID ${roleId} no encontrado o inactivo`
      }
    }

    // Insertar rol (o reactivar si ya existe)
    await pool.query(
      `INSERT INTO tab_user_roles (id_user, id_role, assigned_by, is_active)
       VALUES ($1, $2, $3, true)
       ON CONFLICT (id_user, id_role) 
       DO UPDATE SET is_active = true, assigned_at = NOW(), assigned_by = $3`,
      [userId, roleId, assignedBy]
    )

    return {
      success: true,
      message: 'Rol asignado exitosamente'
    }
  } catch (error) {
    console.error('Error en assignRole:', error)
    return {
      success: false,
      message: 'Error al asignar rol',
      error: error.message
    }
  }
}

/**
 * Quitar rol de usuario
 * @param {number} userId - ID del usuario
 * @param {number} roleId - ID del rol a quitar
 * @returns {Promise<Object>} - { success, message }
 */
async function removeRole(userId, roleId) {
  const client = await pool.connect()
  
  try {
    await client.query('BEGIN')

    // Verificar que el usuario tiene más de un rol activo
    const rolesCount = await client.query(
      'SELECT COUNT(*) as count FROM tab_user_roles WHERE id_user = $1 AND is_active = true',
      [userId]
    )

    if (parseInt(rolesCount.rows[0].count) <= 1) {
      await client.query('ROLLBACK')
      return {
        success: false,
        message: 'No se puede quitar el único rol del usuario'
      }
    }

    // Desactivar el rol (soft delete)
    await client.query(
      'UPDATE tab_user_roles SET is_active = false WHERE id_user = $1 AND id_role = $2',
      [userId, roleId]
    )

    await client.query('COMMIT')

    return {
      success: true,
      message: 'Rol quitado exitosamente'
    }
  } catch (error) {
    await client.query('ROLLBACK')
    console.error('Error en removeRole:', error)
    return {
      success: false,
      message: 'Error al quitar rol',
      error: error.message
    }
  } finally {
    client.release()
  }
}

export default {
  getAllUsers,
  getUserById,
  createUser,
  updateUser,
  changePassword,
  toggleUserStatus,
  getUserRoles,
  assignRole,
  removeRole
}
