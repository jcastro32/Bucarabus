import express from 'express'
import busesService from '../services/buses.service.js'

const router = express.Router()

/**
 * @route   GET /api/buses
 * @desc    Obtener todos los buses
 * @query   active - true/false para filtrar solo activos
 */
router.get('/', async (req, res) => {
  try {
    const onlyActive = req.query.active === 'true';
    const result = await busesService.getAllBuses(onlyActive);
    res.json(result);
  } catch (error) {
    console.error('Error en GET /buses:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener buses',
      error: error.message
    });
  }
});

/**
 * @route   GET /api/buses/available
 * @desc    Obtener buses disponibles (activos y sin conductor)
 */
router.get('/available', async (req, res) => {
  try {
    const result = await busesService.getAvailableBuses();
    res.json(result);
  } catch (error) {
    console.error('Error en GET /buses/available:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener buses disponibles',
      error: error.message
    });
  }
});

/**
 * @route   GET /api/buses/stats
 * @desc    Obtener estadísticas de buses
 */
router.get('/stats', async (req, res) => {
  try {
    const result = await busesService.getBusStats();
    res.json(result);
  } catch (error) {
    console.error('Error en GET /buses/stats:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener estadísticas',
      error: error.message
    });
  }
});

/**
 * @route   GET /api/buses/expiring
 * @desc    Obtener buses con documentos próximos a vencer
 * @query   days - Número de días (default: 30)
 */
router.get('/expiring', async (req, res) => {
  try {
    const days = parseInt(req.query.days) || 30;
    const result = await busesService.getBusesWithExpiringDocs(days);
    res.json(result);
  } catch (error) {
    console.error('Error en GET /buses/expiring:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener buses con documentos por vencer',
      error: error.message
    });
  }
});

/**
 * @route   GET /api/buses/:plate
 * @desc    Obtener bus por placa
 */
router.get('/:plate', async (req, res) => {
  try {
    const { plate } = req.params;
    const result = await busesService.getBusByPlate(plate);
    
    if (!result.success) {
      return res.status(404).json(result);
    }
    
    res.json(result);
  } catch (error) {
    console.error('Error en GET /buses/:plate:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener bus',
      error: error.message
    });
  }
});

/**
 * @route   POST /api/buses
 * @desc    Crear nuevo bus
 * @body    { plate_number, amb_code, id_company, capacity, photo_url?, soat_exp, techno_exp, rcc_exp, rce_exp, id_card_owner, name_owner, user_create? }
 */
router.post('/', async (req, res) => {
  try {
    const result = await busesService.createBus(req.body);
    
    if (!result.success) {
      return res.status(400).json(result);
    }
    
    res.status(201).json(result);
  } catch (error) {
    console.error('Error en POST /buses:', error);
    res.status(500).json({
      success: false,
      message: 'Error al crear bus',
      error: error.message
    });
  }
});

/**
 * @route   PUT /api/buses/:plate
 * @desc    Actualizar bus
 * @body    { amb_code, id_company, capacity, photo_url?, soat_exp, techno_exp, rcc_exp, rce_exp, id_card_owner, name_owner, is_active?, user_update? }
 */
router.put('/:plate', async (req, res) => {
  try {
    const { plate } = req.params;
    const result = await busesService.updateBus(plate, req.body);
    
    if (!result.success) {
      return res.status(400).json(result);
    }
    
    res.json(result);
  } catch (error) {
    console.error('Error en PUT /buses/:plate:', error);
    res.status(500).json({
      success: false,
      message: 'Error al actualizar bus',
      error: error.message
    });
  }
});

/**
 * @route   PATCH /api/buses/:plate/status
 * @desc    Cambiar estado del bus (activar/desactivar)
 * @body    { is_active: boolean, user_update?: string }
 */
router.patch('/:plate/status', async (req, res) => {
  try {
    const { plate } = req.params;
    const { is_active, user_update } = req.body;
    
    if (typeof is_active !== 'boolean') {
      return res.status(400).json({
        success: false,
        message: 'El campo is_active es requerido y debe ser boolean'
      });
    }
    
    const result = await busesService.toggleBusStatus(plate, is_active, user_update);
    
    if (!result.success) {
      return res.status(400).json(result);
    }
    
    res.json(result);
  } catch (error) {
    console.error('Error en PATCH /buses/:plate/status:', error);
    res.status(500).json({
      success: false,
      message: 'Error al cambiar estado del bus',
      error: error.message
    });
  }
});

/**
 * @route   DELETE /api/buses/:plate
 * @desc    Eliminar bus (soft delete)
 * @body    { user_update?: string }
 */
router.delete('/:plate', async (req, res) => {
  try {
    const { plate } = req.params;
    const { user_update } = req.body;
    const result = await busesService.deleteBus(plate, user_update);
    
    if (!result.success) {
      return res.status(400).json(result);
    }
    
    res.json(result);
  } catch (error) {
    console.error('Error en DELETE /buses/:plate:', error);
    res.status(500).json({
      success: false,
      message: 'Error al eliminar bus',
      error: error.message
    });
  }
});

export default router;
