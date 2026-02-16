import express from 'express'
import { pool } from '../config/database.js'
import driversService from '../services/drivers.service.js'

const router = express.Router()

// =============================================
// GET /api/drivers - Obtener todos los conductores
// =============================================
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        u.id_user,
        u.email,
        u.full_name AS name_driver,
        u.avatar_url AS photo_driver,
        u.is_active AS status_driver,
        u.created_at,
        u.updated_at,
        dd.id_card,
        dd.cel,
        dd.license_cat,
        dd.license_exp,
        dd.address_driver,
        dd.available,
        dd.date_entry
      FROM tab_users u
      INNER JOIN tab_user_roles ur ON u.id_user = ur.id_user
      INNER JOIN tab_driver_details dd ON u.id_user = dd.id_user
      WHERE ur.id_role = 2 
        AND ur.is_active = true
        AND u.is_active = true
      ORDER BY u.created_at DESC
    `)

    res.json(result.rows)
  } catch (error) {
    console.error('Error al obtener conductores:', error)
    res.status(500).json({ 
      success: false, 
      message: 'Error al obtener conductores',
      error: error.message 
    })
  }
})

// =============================================
// GET /api/drivers/:id - Obtener un conductor
// =============================================
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params

    const result = await pool.query(`
      SELECT 
        u.id_user,
        u.email,
        u.full_name AS name_driver,
        u.avatar_url AS photo_driver,
        u.is_active AS status_driver,
        u.created_at,
        u.updated_at,
        dd.id_card,
        dd.cel,
        dd.license_cat,
        dd.license_exp,
        dd.address_driver,
        dd.available,
        dd.date_entry
      FROM tab_users u
      INNER JOIN tab_user_roles ur ON u.id_user = ur.id_user
      INNER JOIN tab_driver_details dd ON u.id_user = dd.id_user
      WHERE u.id_user = $1
        AND ur.id_role = 2 
        AND ur.is_active = true
    `, [id])

    if (result.rows.length === 0) {
      return res.status(404).json({ 
        success: false, 
        message: 'Conductor no encontrado' 
      })
    }

    res.json(result.rows[0])
  } catch (error) {
    console.error('Error al obtener conductor:', error)
    res.status(500).json({ 
      success: false, 
      message: 'Error al obtener conductor',
      error: error.message 
    })
  }
})

// =============================================
// POST /api/drivers - Crear nuevo conductor
// =============================================
router.post('/', async (req, res) => {
  try {
    console.log('📨 POST /api/drivers - Recibiendo datos:', req.body)

    const {
      email,
      password,
      name_driver,      // frontend envía name_driver
      id_card,
      cel,
      license_cat,
      license_exp,
      address_driver,
      photo_driver      // frontend envía photo_driver
    } = req.body

    // Validaciones básicas
    if (!email || !password || !name_driver || !id_card || !cel || !license_cat || !license_exp) {
      return res.status(400).json({
        success: false,
        message: 'Faltan campos obligatorios: email, password, nombre, cédula, teléfono, licencia'
      })
    }

    // Llamar al servicio con el mapeo correcto
    const result = await driversService.createDriver({
      email,
      password,
      full_name: name_driver,        // Mapear name_driver -> full_name
      id_card,
      cel,
      license_cat,
      license_exp,
      avatar_url: photo_driver || null,
      address_driver: address_driver || null
    })

    console.log('📝 Resultado del servicio:', result)

    if (!result.success) {
      return res.status(400).json({
        success: false,
        message: result.message
      })
    }

    res.status(201).json({
      success: true,
      message: result.message,
      data: result.data
    })
  } catch (error) {
    console.error('❌ Error al crear conductor:', error)
    res.status(500).json({ 
      success: false, 
      message: 'Error al crear conductor',
      error: error.message 
    })
  }
})

// =============================================
// PUT /api/drivers/:id - Actualizar conductor
// =============================================
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params
    const {
      wname_driver,
      wcel,
      wemail,
      wavailable,
      wlicense_cat,
      wlicense_exp,
      waddress_driver,
      wphoto_driver,
      wdate_entry,
      wstatus_driver,
      wuser_update
    } = req.body

    // Llamar a función de actualización (necesitas crearla)
    const result = await pool.query(`
      SELECT * FROM fun_update_driver(
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12
      )
    `, [
      id,
      wname_driver,
      wcel,
      wemail,
      wavailable,
      wlicense_cat,
      wlicense_exp,
      waddress_driver,
      wphoto_driver,
      wdate_entry,
      wstatus_driver,
      wuser_update
    ])

    const response = result.rows[0]

    res.json({
      success: response.success,
      msg: response.msg
    })
  } catch (error) {
    console.error('Error al actualizar conductor:', error)
    res.status(500).json({ 
      success: false, 
      message: 'Error al actualizar conductor',
      error: error.message 
    })
  }
})

// =============================================
// PATCH /api/drivers/:id/availability - Cambiar disponibilidad
// =============================================
router.patch('/:id/availability', async (req, res) => {
  try {
    const idUser = parseInt(req.params.id)
    const { available } = req.body

    if (isNaN(idUser)) {
      return res.status(400).json({ 
        success: false, 
        message: 'ID de usuario inválido' 
      })
    }

    if (typeof available !== 'boolean') {
      return res.status(400).json({ 
        success: false, 
        message: 'El campo available debe ser un booleano' 
      })
    }

    // Usar el servicio para actualizar disponibilidad
    await driversService.toggleAvailability(idUser, available)

    // Obtener los datos actualizados del conductor
    const result = await pool.query(`
      SELECT 
        u.id_user,
        u.email,
        u.full_name AS name_driver,
        dd.available,
        dd.cel,
        dd.license_cat
      FROM tab_users u
      INNER JOIN tab_driver_details dd ON u.id_user = dd.id_user
      WHERE u.id_user = $1
    `, [idUser])

    if (result.rows.length === 0) {
      return res.status(404).json({ 
        success: false, 
        message: 'Conductor no encontrado' 
      })
    }

    res.json({
      success: true,
      msg: `Conductor ${available ? 'disponible' : 'no disponible'}`,
      driver: result.rows[0]
    })
  } catch (error) {
    console.error('Error al cambiar disponibilidad:', error)
    res.status(500).json({ 
      success: false, 
      message: 'Error al cambiar disponibilidad',
      error: error.message 
    })
  }
})

// =============================================
// DELETE /api/drivers/:id - Eliminar conductor (soft delete)
// =============================================
router.delete('/:id', async (req, res) => {
  try {
    const idUser = parseInt(req.params.id)

    if (isNaN(idUser)) {
      return res.status(400).json({ 
        success: false, 
        message: 'ID de usuario inválido' 
      })
    }

    // Llamar al servicio para eliminar el conductor
    const result = await driversService.deleteDriver(idUser)

    res.json({
      success: true,
      msg: 'Conductor eliminado correctamente',
      data: result.data
    })
  } catch (error) {
    console.error('Error al eliminar conductor:', error)
    
    // Manejar errores específicos
    if (error.message?.includes('no existe')) {
      return res.status(404).json({ 
        success: false, 
        message: 'Conductor no encontrado' 
      })
    }
    if (error.message?.includes('no es conductor')) {
      return res.status(400).json({ 
        success: false, 
        message: 'El usuario especificado no es un conductor' 
      })
    }
    
    res.status(500).json({ 
      success: false, 
      message: 'Error al eliminar conductor',
      error: error.message 
    })
  }
})

export default router