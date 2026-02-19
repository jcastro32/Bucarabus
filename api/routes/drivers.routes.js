import express from 'express'
import driversService from '../services/drivers.service.js'

const SYSTEM_USER_ID = 1;
const router = express.Router()

/**
 * @route   GET /api/drivers
 * @desc    Obtener todos los conductores
 * @query   active - true/false para filtrar solo activos
 */
router.get('/', async (req, res) => {
  try {
    const onlyActive = req.query.active === 'true';
    const result = await driversService.getAllDrivers(onlyActive);
    res.json(result);
  } catch (error) {
    console.error('Error en GET /drivers:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener conductores',
      error: error.message
    });
  }
});

/**
 * @route   GET /api/drivers/available
 * @desc    Obtener conductores disponibles
 */
router.get('/available', async (req, res) => {
  try {
    const result = await driversService.getAvailableDrivers();
    res.json(result);
  } catch (error) {
    console.error('Error en GET /drivers/available:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener conductores disponibles',
      error: error.message
    });
  }
});

/**
 * @route   GET /api/drivers/:id
 * @desc    Obtener conductor por ID
 */
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await driversService.getDriverById(id);
    
    if (!result.success) {
      return res.status(404).json(result);
    }
    
    res.json(result);
  } catch (error) {
    console.error('Error en GET /drivers/:id:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener conductor',
      error: error.message
    });
  }
});

/**
 * @route   POST /api/drivers
 * @desc    Crear nuevo conductor
 * @body    { name_driver, id_card, cel, email, password, license_cat, license_exp, address_driver?, photo_driver?, user_create? }
 */
router.post('/', async (req, res) => {
  try {
    const {
      email,
      password,
      name_driver,
      id_card,
      cel,
      license_cat,
      license_exp,
      address_driver,
      photo_driver,
      user
    } = req.body;

    // Validaciones básicas
    if (!email || !password || !name_driver || !id_card || !cel || !license_cat || !license_exp) {
      return res.status(400).json({
        success: false,
        message: 'Faltan campos obligatorios: email, password, nombre, cédula, teléfono, licencia'
      });
    }

    // Mapear campos del frontend a lo que espera el servicio
    const result = await driversService.createDriver({
      email,
      password,
      full_name: name_driver,        // frontend: name_driver -> backend: full_name
      id_card,
      cel,
      license_cat,
      license_exp,
      avatar_url: photo_driver || null,
      address_driver: address_driver || null,
      user_create: user || SYSTEM_USER_ID
    });
    
    if (!result.success) {
      return res.status(400).json(result);
    }
    
    res.status(201).json(result);
  } catch (error) {
    console.error('Error en POST /drivers:', error);
    res.status(500).json({
      success: false,
      message: 'Error al crear conductor',
      error: error.message
    });
  }
});

/**
 * @route   PUT /api/drivers/:id
 * @desc    Actualizar conductor
 * @body    { name_driver, id_card, cel, email, license_cat, license_exp, address_driver?, photo_driver?, user? }
 */
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { user } = req.body;
    
    const result = await driversService.updateDriver(id, {
      ...req.body,
      user_update: user || SYSTEM_USER_ID
    });
    
    if (!result.success) {
      return res.status(400).json(result);
    }
    
    res.json(result);
  } catch (error) {
    console.error('Error en PUT /drivers/:id:', error);
    res.status(500).json({
      success: false,
      message: 'Error al actualizar conductor',
      error: error.message
    });
  }
});

/**
 * @route   PATCH /api/drivers/:id/availability
 * @desc    Cambiar disponibilidad del conductor
 * @body    { available: boolean, user_update? }
 */
router.patch('/:id/availability', async (req, res) => {
  try {
    const { id } = req.params;
    const { available, user_update } = req.body;
    
    if (typeof available !== 'boolean') {
      return res.status(400).json({
        success: false,
        message: 'El campo "available" es requerido y debe ser boolean'
      });
    }
    
    const result = await driversService.toggleAvailability(id, available, user_update);
    
    if (!result.success) {
      return res.status(400).json(result);
    }
    
    res.json(result);
  } catch (error) {
    console.error('Error en PATCH /drivers/:id/availability:', error);
    res.status(500).json({
      success: false,
      message: 'Error al cambiar disponibilidad',
      error: error.message
    });
  }
});

/**
 * @route   PATCH /api/drivers/:id/status
 * @desc    Activar/Inactivar conductor
 * @body    { status: boolean, user_update? }
 */
router.patch('/:id/status', async (req, res) => {
  try {
    const { id } = req.params;
    const { status, user_update } = req.body;
    
    if (typeof status !== 'boolean') {
      return res.status(400).json({
        success: false,
        message: 'El campo "status" es requerido y debe ser boolean'
      });
    }
    
    const result = await driversService.toggleStatus(id, status, user_update);
    
    if (!result.success) {
      return res.status(400).json(result);
    }
    
    res.json(result);
  } catch (error) {
    console.error('Error en PATCH /drivers/:id/status:', error);
    res.status(500).json({
      success: false,
      message: 'Error al cambiar estado',
      error: error.message
    });
  }
});

/**
 * @route   DELETE /api/drivers/:id
 * @desc    Eliminar conductor (hard delete)
 */
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await driversService.deleteDriver(id);
    
    if (!result.success) {
      return res.status(400).json(result);
    }
    
    res.json(result);
  } catch (error) {
    console.error('Error en DELETE /drivers/:id:', error);
    res.status(500).json({
      success: false,
      message: 'Error al eliminar conductor',
      error: error.message
    });
  }
})

export default router
