import express from 'express';
import * as tripsService from '../services/trips.service.js';

const router = express.Router();

/**
 * GET /api/trips?plate_number=XXX&trip_date=YYYY-MM-DD
 * Obtener viajes por bus y fecha (para app conductor)
 */
router.get('/', async (req, res) => {
  try {
    const { plate_number, trip_date } = req.query;
    
    console.log('🔍 GET /api/trips - Parámetros recibidos:', { plate_number, trip_date });
    
    if (!plate_number || !trip_date) {
      return res.status(400).json({ 
        error: 'Se requieren los parámetros plate_number y trip_date' 
      });
    }
    
    const trips = await tripsService.getTripsByBusAndDate(plate_number, trip_date);
    console.log('📋 Viajes encontrados:', trips.length);
    
    res.json(trips);
  } catch (error) {
    console.error('❌ Error obteniendo viajes por bus:', error);
    res.status(500).json({ 
      error: 'Error al obtener viajes'
    });
  }
});

/**
 * GET /api/trips/:routeId/:date
 * Obtener viajes por ruta y fecha
 */
router.get('/:routeId/:date', async (req, res) => {
  try {
    const { routeId, date } = req.params;
    const trips = await tripsService.getTripsByRouteAndDate(routeId, date);
    res.json(trips);
  } catch (error) {
    console.error('Error obteniendo viajes:', error);
    res.status(500).json({ error: 'Error al obtener viajes' });
  }
});

/**
 * GET /api/trips/single/:id
 * Obtener un viaje por ID
 */
router.get('/single/:id', async (req, res) => {
  try {
    const trip = await tripsService.getTripById(req.params.id);
    if (!trip) {
      return res.status(404).json({ error: 'Viaje no encontrado' });
    }
    res.json(trip);
  } catch (error) {
    console.error('Error obteniendo viaje:', error);
    res.status(500).json({ error: 'Error al obtener viaje' });
  }
});

/**
 * POST /api/trips
 * Crear un viaje individual
 */
router.post('/', async (req, res) => {
  try {
    const result = await tripsService.createTrip(req.body);
    
    if (result.success) {
      res.status(201).json(result);
    } else {
      res.status(400).json(result);
    }
  } catch (error) {
    console.error('Error creando viaje:', error);
    res.status(500).json({ success: false, msg: 'Error interno del servidor', error_code: 'SERVER_ERROR' });
  }
});

/**
 * POST /api/trips/batch
 * Crear múltiples viajes
 */
router.post('/batch', async (req, res) => {
  try {
    // DEBUG: Log de los datos recibidos
    console.log('📥 /api/trips/batch - Datos recibidos:');
    console.log('  id_route:', req.body.id_route, typeof req.body.id_route);
    console.log('  trip_date:', req.body.trip_date);
    console.log('  trips count:', req.body.trips?.length);
    console.log('  user_create:', req.body.user_create);
    if (req.body.trips?.length > 0) {
      console.log('  Primer trip:', JSON.stringify(req.body.trips[0]));
    }
    
    const result = await tripsService.createTripsBatch(req.body);
    
    console.log('📤 Resultado:', result);
    
    if (result.success) {
      res.status(201).json(result);
    } else {
      res.status(400).json(result);
    }
  } catch (error) {
    console.error('❌ Error creando viajes batch:', error);
    res.status(500).json({ success: false, msg: 'Error interno del servidor: ' + error.message, error_code: 'SERVER_ERROR' });
  }
});

/**
 * PUT /api/trips/:id
 * Actualizar viaje
 */
router.put('/:id', async (req, res) => {
  try {
    const result = await tripsService.updateTrip(req.params.id, req.body);
    
    if (result.success) {
      res.json(result);
    } else {
      res.status(400).json(result);
    }
  } catch (error) {
    console.error('Error actualizando viaje:', error);
    res.status(500).json({ success: false, msg: 'Error interno del servidor', error_code: 'SERVER_ERROR' });
  }
});

/**
 * PATCH /api/trips/:id/bus
 * Asignar o desasignar bus
 */
router.patch('/:id/bus', async (req, res) => {
  try {
    const { plate_number, user_update } = req.body;
    const result = await tripsService.setTripBus(req.params.id, plate_number, user_update);
    
    if (result.success) {
      res.json(result);
    } else {
      res.status(400).json(result);
    }
  } catch (error) {
    console.error('Error asignando bus:', error);
    res.status(500).json({ success: false, msg: 'Error interno del servidor', error_code: 'SERVER_ERROR' });
  }
});

/**
 * DELETE /api/trips/:id
 * Eliminar viaje
 */
router.delete('/:id', async (req, res) => {
  try {
    const result = await tripsService.deleteTrip(req.params.id);
    
    if (result.success) {
      res.json(result);
    } else {
      res.status(400).json(result);
    }
  } catch (error) {
    console.error('Error eliminando viaje:', error);
    res.status(500).json({ success: false, msg: 'Error interno del servidor', error_code: 'SERVER_ERROR' });
  }
});

/**
 * DELETE /api/trips/by-date/:routeId/:date
 * Eliminar todos los viajes de una ruta/fecha
 */
router.delete('/by-date/:routeId/:date', async (req, res) => {
  try {
    const { routeId, date } = req.params;
    const result = await tripsService.deleteTripsByDate(routeId, date);
    
    if (result.success) {
      res.json(result);
    } else {
      res.status(400).json(result);
    }
  } catch (error) {
    console.error('Error eliminando viajes:', error);
    res.status(500).json({ success: false, msg: 'Error interno del servidor', error_code: 'SERVER_ERROR' });
  }
});

/**
 * PATCH /api/trips/:id/cancel
 * Cancelar viaje (soft delete)
 */
router.patch('/:id/cancel', async (req, res) => {
  try {
    const { user_update } = req.body;
    const result = await tripsService.cancelTrip(req.params.id, user_update);
    
    if (result.success) {
      res.json(result);
    } else {
      res.status(400).json(result);
    }
  } catch (error) {
    console.error('Error cancelando viaje:', error);
    res.status(500).json({ success: false, msg: 'Error interno del servidor', error_code: 'SERVER_ERROR' });
  }
});

export default router;
