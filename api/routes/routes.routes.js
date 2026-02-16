import express from 'express'
import routesService from '../services/routes.service.js'

const router = express.Router()

/**
 * GET /api/routes
 * Obtener todas las rutas
 */
router.get('/', async (req, res) => {
  try {
    const routes = await routesService.getAllRoutes()
    res.json({
      success: true,
      data: routes,
      count: routes.length
    })
  } catch (error) {
    console.error('Error en GET /api/routes:', error)
    res.status(500).json({
      success: false,
      error: 'Error obteniendo rutas',
      message: error.message
    })
  }
})

/**
 * GET /api/routes/search?q=centro
 * Buscar rutas por nombre
 */
router.get('/search', async (req, res) => {
  try {
    const { q } = req.query
    
    if (!q) {
      return res.status(400).json({
        success: false,
        error: 'Parámetro de búsqueda "q" es requerido'
      })
    }
    
    const routes = await routesService.searchRoutes(q)
    res.json({
      success: true,
      data: routes,
      count: routes.length
    })
  } catch (error) {
    console.error('Error en GET /api/routes/search:', error)
    res.status(500).json({
      success: false,
      error: 'Error buscando rutas',
      message: error.message
    })
  }
})

/**
 * GET /api/routes/:id
 * Obtener ruta específica con paradas
 */
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params
    const route = await routesService.getRouteById(id)
    
    if (!route) {
      return res.status(404).json({
        success: false,
        error: 'Ruta no encontrada'
      })
    }
    
    res.json({
      success: true,
      data: route
    })
  } catch (error) {
    console.error('Error en GET /api/routes/:id:', error)
    res.status(500).json({
      success: false,
      error: 'Error obteniendo ruta',
      message: error.message
    })
  }
})

/**
 * POST /api/routes
 * Crear nueva ruta
 */
router.post('/', async (req, res) => {
  try {
    const routeData = req.body
    
    console.log('📥 POST /api/routes - Datos recibidos:', JSON.stringify(routeData, null, 2))
    
    // Validaciones básicas - solo nombre es requerido, ID se genera automáticamente
    if (!routeData.name) {
      console.log('❌ Validación falló: nombre faltante')
      return res.status(400).json({
        success: false,
        error: 'El nombre de la ruta es requerido',
        received: { name: routeData.name }
      })
    }
    
    if (!routeData.path || routeData.path.length < 2) {
      console.log('❌ Validación falló: Path insuficiente')
      return res.status(400).json({
        success: false,
        error: 'Se requieren al menos 2 puntos para la ruta',
        received: { pathLength: routeData.path?.length }
      })
    }
    
    console.log('✅ Validaciones pasadas, creando ruta...')
    const newRoute = await routesService.createRoute(routeData)
    console.log('✅ Ruta creada exitosamente:', newRoute.id)
    
    res.status(201).json({
      success: true,
      data: newRoute,
      message: `Ruta ${newRoute.name} creada exitosamente`
    })
  } catch (error) {
    console.error('❌ Error en POST /api/routes:', error)
    console.error('Stack:', error.stack)
    
    if (error.message.includes('Ya existe')) {
      return res.status(409).json({
        success: false,
        error: error.message
      })
    }
    
    res.status(500).json({
      success: false,
      error: 'Error creando ruta',
      message: error.message
    })
  }
})

/**
 * PUT /api/routes/:id
 * Actualizar ruta existente
 */
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params
    const routeData = req.body
    
    const updatedRoute = await routesService.updateRoute(id, routeData)
    
    if (!updatedRoute) {
      return res.status(404).json({
        success: false,
        error: 'Ruta no encontrada'
      })
    }
    
    res.json({
      success: true,
      data: updatedRoute,
      message: `Ruta ${updatedRoute.name} actualizada exitosamente`
    })
  } catch (error) {
    console.error('Error en PUT /api/routes/:id:', error)
    res.status(500).json({
      success: false,
      error: 'Error actualizando ruta',
      message: error.message
    })
  }
})

/**
 * DELETE /api/routes/:id
 * Eliminar ruta
 */
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params
    const response = await routesService.deleteRoute(id)
    
    // El servicio ya retorna success, message, warning
    res.json(response)
  } catch (error) {
    console.error('Error en DELETE /api/routes/:id:', error)
    
    // Manejar códigos de error específicos
    let statusCode = 500
    
    if (error.code === 'ROUTE_NOT_FOUND') {
      statusCode = 404
    } else if (error.code === 'ROUTE_HAS_ACTIVE_TRIPS') {
      statusCode = 409 // Conflict
    }
    
    res.status(statusCode).json({
      success: false,
      error: error.message || 'Error eliminando ruta',
      code: error.code
    })
  }
})

/**
 * PATCH /api/routes/:id/visibility
 * Alternar visibilidad de ruta
 */
router.patch('/:id/visibility', async (req, res) => {
  try {
    const { id } = req.params
    const result = await routesService.toggleVisibility(id)
    
    if (!result) {
      return res.status(404).json({
        success: false,
        error: 'Ruta no encontrada'
      })
    }
    
    res.json({
      success: true,
      data: result,
      message: `Visibilidad de ruta ${id} actualizada`
    })
  } catch (error) {
    console.error('Error en PATCH /api/routes/:id/visibility:', error)
    res.status(500).json({
      success: false,
      error: 'Error actualizando visibilidad',
      message: error.message
    })
  }
})

/**
 * GET /api/routes/:id/distance
 * Obtener distancia de ruta en km
 */
router.get('/:id/distance', async (req, res) => {
  try {
    const { id } = req.params
    const result = await routesService.getRouteDistance(id)
    
    if (!result) {
      return res.status(404).json({
        success: false,
        error: 'Ruta no encontrada'
      })
    }
    
    res.json({
      success: true,
      data: result
    })
  } catch (error) {
    console.error('Error en GET /api/routes/:id/distance:', error)
    res.status(500).json({
      success: false,
      error: 'Error calculando distancia',
      message: error.message
    })
  }
})

/**
 * POST /api/routes/:id/stops
 * Agregar parada a ruta
 */
router.post('/:id/stops', async (req, res) => {
  try {
    const { id } = req.params
    const stopData = req.body
    
    const newStop = await routesService.addStop(id, stopData)
    
    res.status(201).json({
      success: true,
      data: newStop,
      message: 'Parada agregada exitosamente'
    })
  } catch (error) {
    console.error('Error en POST /api/routes/:id/stops:', error)
    res.status(500).json({
      success: false,
      error: 'Error agregando parada',
      message: error.message
    })
  }
})

/**
 * POST /api/routes/:id/buses
 * Asignar bus a ruta
 */
router.post('/:id/buses', async (req, res) => {
  try {
    const { id } = req.params
    const { busId } = req.body
    
    if (!busId) {
      return res.status(400).json({
        success: false,
        error: 'busId es requerido'
      })
    }
    
    const result = await routesService.assignBus(id, busId)
    
    res.status(201).json({
      success: true,
      data: result,
      message: 'Bus asignado exitosamente'
    })
  } catch (error) {
    console.error('Error en POST /api/routes/:id/buses:', error)
    res.status(500).json({
      success: false,
      error: 'Error asignando bus',
      message: error.message
    })
  }
})

export default router
