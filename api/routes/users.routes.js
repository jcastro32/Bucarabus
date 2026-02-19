import express from 'express'
import usersService from '../services/users.service.js'

const SYSTEM_USER_ID = 1;
const router = express.Router()

/**
 * GET /api/users
 * Obtener todos los usuarios (con filtros opcionales)
 * Query params:
 * - role: ID del rol para filtrar
 * - active: true/false para filtrar por estado
 */
router.get('/', async (req, res) => {
  try {
    const filters = {}
    
    if (req.query.role) {
      filters.role = parseInt(req.query.role)
    }
    
    if (req.query.active !== undefined) {
      filters.active = req.query.active === 'true'
    }

    const result = await usersService.getAllUsers(filters)

    if (!result.success) {
      return res.status(500).json({
        success: false,
        message: result.message,
        error: result.error
      })
    }

    res.json({
      success: true,
      data: result.data,
      count: result.count
    })
  } catch (error) {
    console.error('Error en GET /api/users:', error)
    res.status(500).json({
      success: false,
      message: 'Error al obtener usuarios',
      error: error.message
    })
  }
})

/**
 * GET /api/users/:id
 * Obtener usuario por ID (con sus roles)
 */
router.get('/:id', async (req, res) => {
  try {
    const userId = parseInt(req.params.id)

    if (isNaN(userId)) {
      return res.status(400).json({
        success: false,
        message: 'ID de usuario inválido'
      })
    }

    const result = await usersService.getUserById(userId)

    if (!result.success) {
      return res.status(404).json({
        success: false,
        message: result.message
      })
    }

    res.json({
      success: true,
      data: result.data
    })
  } catch (error) {
    console.error('Error en GET /api/users/:id:', error)
    res.status(500).json({
      success: false,
      message: 'Error al obtener usuario',
      error: error.message
    })
  }
})

/**
 * POST /api/users
 * Crear nuevo usuario
 * Body:
 * - email (required)
 * - password (required, min 8 chars)
 * - full_name (required)
 * - avatar_url (optional)
 * - initial_role (optional, 1=Pasajero por defecto)
 */
router.post('/', async (req, res) => {
  try {
    console.log('🔵 POST /api/users - Petición recibida')
    console.log('   URL completa:', req.originalUrl)
    console.log('   Método:', req.method)
    console.log('   Path:', req.path)
    console.log('   BaseURL:', req.baseUrl)
    
    const { email, password, full_name, avatar_url, initial_role, user } = req.body

    console.log('📨 POST /api/users - Body recibido:', { 
      email, 
      full_name, 
      avatar_url, 
      initial_role,
      user,
      hasPassword: !!password,
      passwordLength: password?.length
    })

    // Validaciones básicas
    if (!email || !password || !full_name) {
      console.log('❌ Validación falló en ruta')
      return res.status(400).json({
        success: false,
        message: 'Email, contraseña y nombre completo son requeridos'
      })
    }

    console.log('✅ Validación pasada, llamando a servicio...')
    const result = await usersService.createUser({
      email,
      password,
      full_name,
      avatar_url,
      initial_role,
      user_create: user || SYSTEM_USER_ID
    })

    console.log('📤 Resultado del servicio:', { success: result.success, message: result.message })

    if (!result.success) {
      return res.status(400).json({
        success: false,
        message: result.message
      })
    }

    res.status(201).json({
      success: true,
      data: result.data,
      message: result.message
    })
  } catch (error) {
    console.error('❌ Error en POST /api/users:', error)
    res.status(500).json({
      success: false,
      message: 'Error al crear usuario',
      error: error.message
    })
  }
})

/**
 * PUT /api/users/:id
 * Actualizar usuario (nombre y avatar)
 * Body:
 * - full_name (optional)
 * - avatar_url (optional)
 */
router.put('/:id', async (req, res) => {
  try {
    const userId = parseInt(req.params.id)

    if (isNaN(userId)) {
      return res.status(400).json({
        success: false,
        message: 'ID de usuario inválido'
      })
    }

    const { full_name, avatar_url, user } = req.body

    if (!full_name && avatar_url === undefined) {
      return res.status(400).json({
        success: false,
        message: 'Debe proporcionar al menos un campo para actualizar (full_name o avatar_url)'
      })
    }

    const result = await usersService.updateUser(userId, {
      full_name,
      avatar_url,
      user_update: user || SYSTEM_USER_ID
    })

    if (!result.success) {
      return res.status(404).json({
        success: false,
        message: result.message
      })
    }

    res.json({
      success: true,
      data: result.data,
      message: result.message
    })
  } catch (error) {
    console.error('Error en PUT /api/users/:id:', error)
    res.status(500).json({
      success: false,
      message: 'Error al actualizar usuario',
      error: error.message
    })
  }
})

/**
 * PUT /api/users/:id/password
 * Cambiar contraseña de usuario
 * Body:
 * - newPassword (required, min 8 chars)
 */
router.put('/:id/password', async (req, res) => {
  try {
    const userId = parseInt(req.params.id)

    if (isNaN(userId)) {
      return res.status(400).json({
        success: false,
        message: 'ID de usuario inválido'
      })
    }

    const { newPassword } = req.body

    if (!newPassword) {
      return res.status(400).json({
        success: false,
        message: 'Nueva contraseña es requerida'
      })
    }

    const result = await usersService.changePassword(userId, newPassword)

    if (!result.success) {
      return res.status(400).json({
        success: false,
        message: result.message
      })
    }

    res.json({
      success: true,
      message: result.message
    })
  } catch (error) {
    console.error('Error en PUT /api/users/:id/password:', error)
    res.status(500).json({
      success: false,
      message: 'Error al cambiar contraseña',
      error: error.message
    })
  }
})

/**
 * PUT /api/users/:id/status
 * Activar/Desactivar usuario
 * Body:
 * - isActive (required, boolean)
 */
router.put('/:id/status', async (req, res) => {
  try {
    const userId = parseInt(req.params.id)

    if (isNaN(userId)) {
      return res.status(400).json({
        success: false,
        message: 'ID de usuario inválido'
      })
    }

    const { isActive } = req.body

    if (typeof isActive !== 'boolean') {
      return res.status(400).json({
        success: false,
        message: 'isActive debe ser un valor booleano'
      })
    }

    const result = await usersService.toggleUserStatus(userId, isActive)

    if (!result.success) {
      return res.status(404).json({
        success: false,
        message: result.message
      })
    }

    res.json({
      success: true,
      data: result.data,
      message: result.message
    })
  } catch (error) {
    console.error('Error en PUT /api/users/:id/status:', error)
    res.status(500).json({
      success: false,
      message: 'Error al cambiar estado del usuario',
      error: error.message
    })
  }
})

/**
 * GET /api/users/:id/roles
 * Obtener roles de un usuario
 */
router.get('/:id/roles', async (req, res) => {
  try {
    const userId = parseInt(req.params.id)

    if (isNaN(userId)) {
      return res.status(400).json({
        success: false,
        message: 'ID de usuario inválido'
      })
    }

    const result = await usersService.getUserRoles(userId)

    if (!result.success) {
      return res.status(500).json({
        success: false,
        message: result.message
      })
    }

    res.json({
      success: true,
      data: result.data
    })
  } catch (error) {
    console.error('Error en GET /api/users/:id/roles:', error)
    res.status(500).json({
      success: false,
      message: 'Error al obtener roles del usuario',
      error: error.message
    })
  }
})

/**
 * POST /api/users/:id/roles
 * Asignar rol a usuario
 * Body:
 * - roleId (required, 1=Pasajero, 2=Conductor, 3=Supervisor, 4=Admin)
 * - assignedBy (optional, ID del usuario que asigna)
 */
router.post('/:id/roles', async (req, res) => {
  try {
    const userId = parseInt(req.params.id)

    if (isNaN(userId)) {
      return res.status(400).json({
        success: false,
        message: 'ID de usuario inválido'
      })
    }

    const { roleId, assignedBy } = req.body

    if (!roleId) {
      return res.status(400).json({
        success: false,
        message: 'roleId es requerido'
      })
    }

    const result = await usersService.assignRole(userId, roleId, assignedBy)

    if (!result.success) {
      return res.status(400).json({
        success: false,
        message: result.message
      })
    }

    res.status(201).json({
      success: true,
      message: result.message
    })
  } catch (error) {
    console.error('Error en POST /api/users/:id/roles:', error)
    res.status(500).json({
      success: false,
      message: 'Error al asignar rol',
      error: error.message
    })
  }
})

/**
 * DELETE /api/users/:id/roles/:roleId
 * Quitar rol de usuario
 */
router.delete('/:id/roles/:roleId', async (req, res) => {
  try {
    const userId = parseInt(req.params.id)
    const roleId = parseInt(req.params.roleId)

    if (isNaN(userId) || isNaN(roleId)) {
      return res.status(400).json({
        success: false,
        message: 'ID de usuario o rol inválido'
      })
    }

    const result = await usersService.removeRole(userId, roleId)

    if (!result.success) {
      return res.status(400).json({
        success: false,
        message: result.message
      })
    }

    res.json({
      success: true,
      message: result.message
    })
  } catch (error) {
    console.error('Error en DELETE /api/users/:id/roles/:roleId:', error)
    res.status(500).json({
      success: false,
      message: 'Error al quitar rol',
      error: error.message
    })
  }
})

export default router
