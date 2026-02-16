import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { routesApi } from '../api/routes'

export const useRoutesStore = defineStore('routes', () => {
  // Estado - Inicia vacío, se carga desde la base de datos
  const routes = ref({})

  // Estado de rutas activas en el mapa
  const activeRoutes = ref(new Set())
  const routePolylines = ref(new Map())

  // Getters computados
  const routesList = computed(() => Object.values(routes.value))
  const routesCount = computed(() => Object.keys(routes.value).length)
  const totalDistance = computed(() => {
    // Calcular distancia total aproximada
    return routesList.value.reduce((total, route) => {
      if (route.path && route.path.length > 1) {
        // Distancia aproximada en km
        return total + (route.path.length * 0.5)
      }
      return total
    }, 0)
  })

  // Acciones

  /**
   * Cargar rutas desde la base de datos
   */
  const loadRoutes = async () => {
    try {
      const response = await routesApi.getAll()
      
      if (response.success) {
        // Limpiar rutas actuales
        routes.value = {}
        
        // Agregar rutas desde la BD
        response.data.forEach(route => {
          routes.value[route.id] = {
            ...route,
            stops: route.stops || [],
            buses: route.buses || []
          }
        })
        
        console.log(`✅ ${response.count} rutas cargadas desde PostgreSQL`)
        return true
      }
    } catch (error) {
      console.error('❌ Error cargando rutas:', error)
      return false
    }
  }

  /**
   * Agregar ruta (con persistencia en BD)
   */
  const addRoute = async (routeData) => {
    try {
      const response = await routesApi.create(routeData)
      
      if (response.success) {
        const newRoute = response.data
        
        // Agregar al store local
        routes.value[newRoute.id] = {
          ...newRoute,
          stops: newRoute.stops || [],
          buses: newRoute.buses || []
        }
        
        console.log(`✅ Ruta ${newRoute.name} guardada en PostgreSQL`)
        return newRoute
      } else {
        throw new Error(response.error || 'Error creando ruta')
      }
    } catch (error) {
      console.error('❌ Error agregando ruta:', error)
      throw error
    }
  }

  /**
   * Actualizar ruta (con persistencia en BD)
   */
  const updateRoute = async (id, routeData) => {
    try {
      const response = await routesApi.update(id, routeData)
      
      if (response.success) {
        const updatedRoute = response.data
        
        // Actualizar en el store local
        if (routes.value[id]) {
          routes.value[id] = {
            ...routes.value[id],
            ...updatedRoute
          }
        }
        
        console.log(`✅ Ruta ${id} actualizada en PostgreSQL`)
        return routes.value[id]
      } else {
        throw new Error(response.error || 'Error actualizando ruta')
      }
    } catch (error) {
      console.error('❌ Error actualizando ruta:', error)
      throw error
    }
  }

  /**
   * Eliminar ruta
   */
  const deleteRoute = async (id) => {
    try {
      // Llamar a la API para eliminar en la BD
      const response = await routesApi.delete(id)
      
      // Eliminar del estado local
      delete routes.value[id]
      
      console.log(`✅ Ruta ${id} eliminada`)
      
      // Retornar la respuesta completa (incluye warning si existe)
      return response
    } catch (error) {
      console.error('❌ Error eliminando ruta:', error)
      throw error
    }
  }

  const getRouteById = (id) => {
    return routes.value[id]
  }

  const searchRoutes = (query) => {
    if (!query) return routesList.value

    const lowerQuery = query.toLowerCase()
    return routesList.value.filter(route =>
      route.name.toLowerCase().includes(lowerQuery) ||
      route.id.toLowerCase().includes(lowerQuery) ||
      (route.description && route.description.toLowerCase().includes(lowerQuery))
    )
  }

  // Gestión de rutas activas en el mapa
  const activateRoute = (id) => {
    activeRoutes.value.add(id)
  }

  const deactivateRoute = (id) => {
    activeRoutes.value.delete(id)
  }

  const toggleRoute = (id) => {
    if (activeRoutes.value.has(id)) {
      deactivateRoute(id)
    } else {
      activateRoute(id)
    }
  }

  const clearActiveRoutes = () => {
    activeRoutes.value.clear()
  }

  const setRoutePolyline = (id, polyline) => {
    routePolylines.value.set(id, polyline)
  }

  const getRoutePolyline = (id) => {
    return routePolylines.value.get(id)
  }

  const removeRoutePolyline = (id) => {
    const polyline = routePolylines.value.get(id)
    if (polyline) {
      routePolylines.value.delete(id)
      return polyline
    }
    return null
  }

  /**
   * Alternar visibilidad de ruta (solo frontend)
   */
  const toggleRouteVisibility = (id) => {
    if (routes.value[id]) {
      // Alternar visibilidad local
      routes.value[id].visible = !routes.value[id].visible
      
      // Actualizar rutas activas en el mapa
      if (routes.value[id].visible) {
        activateRoute(id)
      } else {
        deactivateRoute(id)
      }
      
      console.log(`👁️ Visibilidad de ruta ${id}: ${routes.value[id].visible}`)
    }
  }

  // Obtener buses asignados a una ruta
  const getBusesForRoute = (routeId) => {
    const route = routes.value[routeId]
    if (!route) return []
    
    // Retornar los buses asignados a la ruta desde la BD
    // En el futuro, esto debería venir de una tabla de asignaciones
    return route.buses || []
  }

// Función para mostrar todas las rutas en el mapa
const showAllRoutes = () => {
  routesList.value.forEach(route => {
    if (route.id && routes.value[route.id]) {
      routes.value[route.id].visible = true
      activateRoute(route.id)
    }
  })
  console.log('👁️ Mostrando todas las rutas en el mapa')
}

/**
 * Ocultar todas las rutas del mapa
 */
const hideAllRoutes = () => {
  routesList.value.forEach(route => {
    if (route.id && routes.value[route.id]) {
      routes.value[route.id].visible = false
      deactivateRoute(route.id)
    }
  })
  console.log('👁️‍🗨️ Ocultando todas las rutas del mapa')
}

  return {
    // Estado
    routes,
    activeRoutes,
    routePolylines,

    // Getters
    routesList,
    routesCount,
    totalDistance,

    // Acciones
    addRoute,
    updateRoute,
    deleteRoute,
    getRouteById,
    searchRoutes,
    activateRoute,
    deactivateRoute,
    toggleRoute,
    clearActiveRoutes,
    setRoutePolyline,
    getRoutePolyline,
    removeRoutePolyline,
    toggleRouteVisibility,
    showAllRoutes,
    hideAllRoutes,
    loadRoutes,
    getBusesForRoute
  }
})