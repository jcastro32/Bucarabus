import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import * as tripsApi from '../api/trips'

export const useTripsStore = defineStore('trips', () => {
  // Estado
  const trips = ref([])
  const loading = ref(false)
  const error = ref(null)

  // Cache para evitar múltiples llamadas - REACTIVO
  const tripsCache = ref({}) // Objeto reactivo en lugar de Map
  
  // Contador para forzar reactividad en computed que dependen del caché
  const cacheVersion = ref(0)

  // Getters computados
  const tripsCount = computed(() => trips.value.length)
  
  const tripsByDate = computed(() => {
    const grouped = {}
    trips.value.forEach(trip => {
      const date = trip.trip_date
      if (!grouped[date]) {
        grouped[date] = []
      }
      grouped[date].push(trip)
    })
    return grouped
  })

  const tripsByRoute = computed(() => {
    const grouped = {}
    trips.value.forEach(trip => {
      const routeId = trip.id_route
      if (!grouped[routeId]) {
        grouped[routeId] = []
      }
      grouped[routeId].push(trip)
    })
    return grouped
  })

  // Acciones

  /**
   * Obtener trips por ruta y fecha
   */
  const fetchTripsByRouteAndDate = async (routeId, date) => {
    const cacheKey = `${routeId}-${date}`
    
    // Verificar caché primero
    if (tripsCache.value[cacheKey]) {
      console.log(`📦 Usando caché para ruta ${routeId} - ${date}`)
      return tripsCache.value[cacheKey]
    }

    try {
      const result = await tripsApi.getTripsByRouteAndDate(routeId, date)
      
      // Guardar en caché
      tripsCache.value[cacheKey] = result
      cacheVersion.value++ // Incrementar para forzar reactividad
      
      // Actualizar estado global (opcional)
      updateTripsInState(result)
      
      console.log(`✅ ${result.length} trips cargados para ruta ${routeId} - ${date}`)
      return result
    } catch (err) {
      // Si es 404, significa que no hay trips para esa ruta/fecha
      if (err.response?.status === 404) {
        tripsCache.value[cacheKey] = []
        cacheVersion.value++
        console.log(`ℹ️ No hay trips para ruta ${routeId} - ${date}`)
        return []
      }
      
      // Para otros errores, registrar pero no guardar en caché
      console.error(`❌ Error cargando trips ruta ${routeId} - ${date}:`, err.message)
      throw err
    }
  }

  /**
   * Cargar trips para múltiples rutas y fechas
   */
  const fetchTripsForWeek = async (routes, dates) => {
    loading.value = true
    error.value = null
    let totalTrips = 0

    try {
      console.log(`🔄 Cargando trips para ${routes.length} rutas x ${dates.length} días...`)
      
      for (const route of routes) {
        for (const date of dates) {
          try {
            // Usar id (numérico) para consultas a la API
            const routeId = route.id
            const trips = await fetchTripsByRouteAndDate(routeId, date)
            totalTrips += trips.length
          } catch (err) {
            // Continuar con la siguiente ruta/fecha si hay error
            console.warn(`⚠️ Error en ruta ${route.name} (${route.id}) - ${date}:`, err.message)
          }
        }
      }

      console.log(`✅ ${totalTrips} trips totales cargados`)
      return totalTrips
    } catch (err) {
      error.value = err.message
      console.error('❌ Error cargando trips para la semana:', err)
      throw err
    } finally {
      loading.value = false
    }
  }

  /**
   * Crear un trip individual
   */
  const createTrip = async (tripData) => {
    try {
      loading.value = true
      error.value = null
      
      const result = await tripsApi.createTrip(tripData)
      
      if (result.success) {
        // Invalidar caché para esa ruta/fecha
        const cacheKey = `${tripData.id_route}-${tripData.trip_date}`
        delete tripsCache.value[cacheKey]
        cacheVersion.value++
        
        console.log('✅ Trip creado:', result.data)
        return result
      } else {
        throw new Error(result.msg || 'Error creando trip')
      }
    } catch (err) {
      error.value = err.message
      console.error('❌ Error creando trip:', err)
      throw err
    } finally {
      loading.value = false
    }
  }

  /**
   * Crear múltiples trips (batch)
   */
  const createTripsBatch = async (batchData) => {
    try {
      loading.value = true
      error.value = null
      
      console.log('📤 Creando batch de trips:', {
        route: batchData.id_route,
        date: batchData.trip_date,
        count: batchData.trips?.length
      })
      
      const result = await tripsApi.createTripsBatch(batchData)
      
      if (result.success) {
        // Invalidar caché para esa ruta/fecha
        const cacheKey = `${batchData.id_route}-${batchData.trip_date}`
        delete tripsCache.value[cacheKey]
        cacheVersion.value++
        
        console.log('✅ Batch de trips creado:', result.trips_created, 'trips')
        return result
      } else {
        throw new Error(result.msg || 'Error creando trips en batch')
      }
    } catch (err) {
      error.value = err.message
      console.error('❌ Error creando batch de trips:', err)
      throw err
    } finally {
      loading.value = false
    }
  }

  /**
   * Asignar/desasignar bus a un trip
   */
  const assignBus = async (tripId, plateNumber, userUpdate) => {
    try {
      loading.value = true
      error.value = null
      
      const result = await tripsApi.setTripBus(tripId, plateNumber, userUpdate)
      
      if (result.success) {
        // Invalidar todo el caché (o ser más específico si sabemos ruta/fecha)
        tripsCache.value = {}
        cacheVersion.value++
        
        console.log('✅ Bus asignado al trip')
        return result
      } else {
        throw new Error(result.msg || 'Error asignando bus')
      }
    } catch (err) {
      error.value = err.message
      console.error('❌ Error asignando bus:', err)
      throw err
    } finally {
      loading.value = false
    }
  }

  /**
   * Eliminar trips por ruta/fecha
   */
  const deleteTripsByDate = async (routeId, date) => {
    try {
      loading.value = true
      error.value = null
      
      const result = await tripsApi.deleteTripsByDate(routeId, date)
      
      if (result.success) {
        // Invalidar caché
        const cacheKey = `${routeId}-${date}`
        delete tripsCache.value[cacheKey]
        cacheVersion.value++
        
        console.log('✅ Trips eliminados')
        return result
      } else {
        throw new Error(result.msg || 'Error eliminando trips')
      }
    } catch (err) {
      error.value = err.message
      console.error('❌ Error eliminando trips:', err)
      throw err
    } finally {
      loading.value = false
    }
  }

  /**
   * Actualizar estado global de trips (helper)
   */
  const updateTripsInState = (newTrips) => {
    // Agregar o actualizar trips en el estado global
    newTrips.forEach(newTrip => {
      const index = trips.value.findIndex(t => t.id_trip === newTrip.id_trip)
      if (index >= 0) {
        trips.value[index] = newTrip
      } else {
        trips.value.push(newTrip)
      }
    })
  }

  /**
   * Limpiar caché (útil para refrescar datos)
   */
  const clearCache = () => {
    tripsCache.value = {}
    cacheVersion.value++
    console.log('🗑️ Caché de trips limpiado')
  }

  /**
   * Invalidar caché para una ruta y fecha específica
   */
  const invalidateCache = (routeId, date) => {
    const cacheKey = `${routeId}-${date}`
    if (tripsCache.value[cacheKey]) {
      delete tripsCache.value[cacheKey]
      cacheVersion.value++
      console.log(`🗑️ Caché invalidado para ruta ${routeId} - ${date}`)
    }
  }

  /**
   * Obtener estadísticas agregadas de trips
   */
  const getStatsForWeek = (routes, dates) => {
    // Usar cacheVersion para forzar reactividad
    const _ = cacheVersion.value
    
    const stats = {
      total: 0,
      assigned: 0,
      pending: 0,
      byRoute: {}
    }

    console.log(`📊 getStatsForWeek: Calculando stats para ${routes.length} rutas x ${dates.length} días`)
    console.log('🗂️ Caché actual:', Object.keys(tripsCache.value).length, 'entradas')

    routes.forEach(route => {
      // Usar id (numérico) para buscar en caché
      const routeId = route.id
      
      stats.byRoute[routeId] = {
        routeName: route.name,
        total: 0,
        assigned: 0,
        byDate: {}
      }

      dates.forEach(date => {
        const cacheKey = `${routeId}-${date}`
        const trips = tripsCache.value[cacheKey] || []
        
        if (trips.length > 0) {
          console.log(`  ✓ ${route.name} (${routeId}) ${date}: ${trips.length} trips`)
        }
        
        const assigned = trips.filter(t => t.plate_number).length
        
        stats.total += trips.length
        stats.assigned += assigned
        stats.byRoute[routeId].total += trips.length
        stats.byRoute[routeId].assigned += assigned
        stats.byRoute[routeId].byDate[date] = {
          total: trips.length,
          assigned: assigned
        }
      })
    })

    stats.pending = stats.total - stats.assigned
    
    console.log(`📈 Stats totales: ${stats.total} trips, ${stats.assigned} asignados, ${stats.pending} pendientes`)
    
    return stats
  }

  return {
    // Estado
    trips,
    loading,
    error,
    
    // Getters
    tripsCount,
    tripsByDate,
    tripsByRoute,
    
    // Acciones
    fetchTripsByRouteAndDate,
    fetchTripsForWeek,
    createTrip,
    createTripsBatch,
    assignBus,
    deleteTripsByDate,
    clearCache,
    invalidateCache,
    getStatsForWeek
  }
})
