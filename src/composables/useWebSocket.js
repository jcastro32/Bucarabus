/**
 * 🔌 Composable para WebSocket en Vue
 * 
 * Uso:
 * const { connect, busLocations, isConnected, sendLocation } = useWebSocket()
 */

import { ref, onMounted, onUnmounted, readonly } from 'vue'
import { io } from 'socket.io-client'

// Estado global (singleton)
let socket = null
const isConnected = ref(false)
const busLocations = ref(new Map())
const connectionError = ref(null)
const serverStats = ref({ activeBuses: 0, connectedClients: 0 })

// Convertir Map a Array reactivo para Vue
const busLocationsArray = ref([])

export function useWebSocket() {
  /**
   * Conectar al servidor WebSocket
   */
  const connect = (url = import.meta.env.VITE_WS_URL || 'http://localhost:3001') => {
    if (socket?.connected) {
      console.log('🔌 Ya estás conectado')
      return
    }

    console.log(`🔌 Conectando a WebSocket: ${url}`)
    
    socket = io(url, {
      transports: ['websocket', 'polling'],
      reconnection: true,
      reconnectionAttempts: 5,
      reconnectionDelay: 1000
    })

    // ============================================
    // EVENTOS DE CONEXIÓN
    // ============================================

    socket.on('connect', () => {
      console.log('✅ WebSocket conectado:', socket.id)
      isConnected.value = true
      connectionError.value = null
    })

    socket.on('disconnect', (reason) => {
      console.log('❌ WebSocket desconectado:', reason)
      isConnected.value = false
    })

    socket.on('connect_error', (error) => {
      console.error('❌ Error de conexión:', error.message)
      connectionError.value = error.message
      isConnected.value = false
    })

    // ============================================
    // EVENTOS DE DATOS
    // ============================================

    // Normalizar datos del bus para uso consistente
    const normalizeBusData = (data) => ({
      ...data,
      busId: data.plateNumber || data.busId, // Usar plateNumber como ID
      lat: data.lat,
      lng: data.lng,
      speed: data.speed || 0,
      heading: data.heading || 0,
      routeColor: data.routeColor || '#3b82f6',
      timestamp: data.timestamp || data.lastUpdate || new Date().toISOString()
    })

    // Mensaje de bienvenida
    socket.on('welcome', (data) => {
      console.log('👋 Bienvenida del servidor:', data)
      serverStats.value.activeBuses = data.activeBuses || 0
    })

    // Recibir todas las ubicaciones
    socket.on('all-locations', (locations) => {
      console.log(`📍 Recibidas ${locations.length} ubicaciones`)
      busLocations.value.clear()
      locations.forEach(loc => {
        const normalized = normalizeBusData(loc)
        busLocations.value.set(normalized.busId, normalized)
      })
      updateLocationsArray()
    })

    // Un bus se movió
    socket.on('bus-moved', (data) => {
      const normalized = normalizeBusData(data)
      console.log(`🚌 Bus ${normalized.busId} se movió a:`, normalized.lat, normalized.lng)
      busLocations.value.set(normalized.busId, normalized)
      updateLocationsArray()
    })

    // Un bus se desconectó
    socket.on('bus-disconnected', (data) => {
      const busId = data.plateNumber || data.busId
      console.log(`🚌 Bus ${busId} desconectado`)
      busLocations.value.delete(busId)
      updateLocationsArray()
    })

    // Un bus inició turno
    socket.on('shift-started', (data) => {
      console.log(`🚌 Bus ${data.plateNumber} inició turno en ruta ${data.routeId}`)
    })

    // Un bus terminó turno
    socket.on('shift-ended', (data) => {
      console.log(`🏁 Bus ${data.plateNumber} terminó turno`)
      busLocations.value.delete(data.plateNumber)
      updateLocationsArray()
    })
  }

  /**
   * Desconectar
   */
  const disconnect = () => {
    if (socket) {
      socket.disconnect()
      socket = null
      isConnected.value = false
      console.log('🔌 Desconectado manualmente')
    }
  }

  /**
   * Actualizar array reactivo de ubicaciones
   */
  const updateLocationsArray = () => {
    busLocationsArray.value = Array.from(busLocations.value.values())
  }

  /**
   * Enviar ubicación del bus (para app del conductor)
   */
  const sendLocation = (plateNumber, lat, lng, extraData = {}) => {
    if (!socket?.connected) {
      console.error('❌ No conectado al servidor')
      return false
    }

    socket.emit('bus-location', {
      plateNumber,
      lat,
      lng,
      timestamp: new Date().toISOString(),
      ...extraData
    })
    return true
  }

  /**
   * Iniciar turno (para app del conductor)
   */
  const startShift = (plateNumber, routeId, driverName) => {
    if (!socket?.connected) return false
    
    socket.emit('bus-start-shift', {
      plateNumber,
      routeId,
      driverName
    })
    return true
  }

  /**
   * Terminar turno (para app del conductor)
   */
  const endShift = (plateNumber) => {
    if (!socket?.connected) return false
    
    socket.emit('bus-end-shift', { plateNumber })
    return true
  }

  /**
   * Solicitar todas las ubicaciones
   */
  const requestAllLocations = () => {
    if (socket?.connected) {
      socket.emit('get-all-locations')
    }
  }

  /**
   * Obtener ubicación de un bus específico
   */
  const getBusLocation = (plateNumber) => {
    return busLocations.value.get(plateNumber) || null
  }

  return {
    // Estado (readonly para evitar modificaciones accidentales)
    isConnected: readonly(isConnected),
    connectionError: readonly(connectionError),
    busLocations: busLocations,              // Map original
    busLocationsArray: busLocationsArray,    // Array para iteración en Vue
    serverStats: readonly(serverStats),
    
    // Métodos
    connect,
    disconnect,
    sendLocation,
    startShift,
    endShift,
    requestAllLocations,
    getBusLocation
  }
}
