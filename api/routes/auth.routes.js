import express from 'express'
import authService from '../services/auth.service.js'

const router = express.Router()

/**
 * @route   POST /api/auth/login
 * @desc    Autenticar usuario
 * @body    { email, password }
 */
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body
    
    console.log('🔵 POST /api/auth/login')
    console.log('   Email:', email)
    
    // Validar campos requeridos
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email y contraseña son requeridos',
        error_code: 'MISSING_CREDENTIALS'
      })
    }
    
    // Llamar al servicio de autenticación
    const result = await authService.login(email, password)
    
    if (result.success) {
      return res.json(result)
    } else {
      // Retornar 401 para credenciales inválidas
      return res.status(401).json(result)
    }
    
  } catch (error) {
    console.error('❌ Error en POST /api/auth/login:', error)
    res.status(500).json({
      success: false,
      message: 'Error del servidor',
      error: error.message
    })
  }
})

/**
 * @route   POST /api/auth/check-email
 * @desc    Verificar si un email existe
 * @body    { email }
 */
router.post('/check-email', async (req, res) => {
  try {
    const { email } = req.body
    
    if (!email) {
      return res.status(400).json({
        success: false,
        message: 'Email es requerido'
      })
    }
    
    const exists = await authService.emailExists(email)
    
    res.json({
      success: true,
      exists
    })
    
  } catch (error) {
    console.error('Error en POST /api/auth/check-email:', error)
    res.status(500).json({
      success: false,
      message: 'Error del servidor',
      error: error.message
    })
  }
})

export default router
