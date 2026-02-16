/**
 * 🔌 WebSocket Server para BucaraBus
 * 
 * Este archivo configura Socket.io para comunicación en tiempo real.
 * Se usa para:
 * - Transmitir ubicaciones GPS de buses
 * - Notificar cambios de estado
 * - Actualizar el monitor en vivo
 */

const { Server } = require('socket.io')

// Almacenar ubicaciones de buses en memoria
const busLocations = new Map()

// Almacenar clientes conectados
const connectedClients = new Set()

/**
 * Inicializar WebSocket Server
 * @param {Object} httpServer - Servidor HTTP de Express
 * @returns {Object} io - Instancia de Socket.io
 */
function initWebSocket(httpServer) {
  // Crear servidor Socket.io
  const io = new Server(httpServer, {
    cors: {
      origin: ['http://localhost:5173', 'http://localhost:3000'], // URLs permitidas
      methods: ['GET', 'POST'],
      credentials: true
    },
    // Opciones de conexión
    pingTimeout: 60000,     // Tiempo antes de considerar desconectado
    pingInterval: 25000     // Intervalo de ping para mantener conexión
  })

  console.log('🔌 WebSocket Server inicializado')

  // ============================================
  // EVENTOS DE CONEXIÓN
  // ============================================
  
  io.on('connection', (socket) => {
    console.log(`✅ Cliente conectado: ${socket.id}`)
    connectedClients.add(socket.id)
    
    // Enviar estado actual al nuevo cliente
    socket.emit('welcome', {
      message: 'Conectado al servidor de BucaraBus',
      timestamp: new Date().toISOString(),
      totalBuses: busLocations.size,
      connectedClients: connectedClients.size
    })

    // Enviar todas las ubicaciones actuales
    socket.emit('all-locations', Array.from(busLocations.values()))

    // ============================================
    // EVENTO: Bus envía su ubicación GPS
    // ============================================
    socket.on('bus-location', (data) => {
      /**
       * data esperado:
       * {
       *   plateNumber: 'ABC123',
       *   lat: 7.1234,
       *   lng: -73.5678,
       *   speed: 35,           // km/h
       *   heading: 180,        // dirección en grados
       *   routeId: 1,
       *   driverName: 'Juan',
       *   timestamp: '2026-01-29T10:30:00Z'
       * }
       */
      
      console.log(`📍 Ubicación recibida de bus ${data.plateNumber}:`, data.lat, data.lng)
      
      // Guardar/actualizar ubicación
      const locationData = {
        ...data,
        lastUpdate: new Date().toISOString(),
        socketId: socket.id
      }
      busLocations.set(data.plateNumber, locationData)
      
      // 🔴 BROADCAST: Enviar a TODOS los clientes conectados (excepto al que envió)
      socket.broadcast.emit('bus-moved', locationData)
      
      // También enviar al mismo bus como confirmación
      socket.emit('location-received', { 
        success: true, 
        plateNumber: data.plateNumber 
      })
    })

    // ============================================
    // EVENTO: Solicitar ubicación de un bus específico
    // ============================================
    socket.on('get-bus-location', (plateNumber) => {
      const location = busLocations.get(plateNumber)
      socket.emit('bus-location-response', {
        plateNumber,
        found: !!location,
        location: location || null
      })
    })

    // ============================================
    // EVENTO: Solicitar todas las ubicaciones
    // ============================================
    socket.on('get-all-locations', () => {
      socket.emit('all-locations', Array.from(busLocations.values()))
    })

    // ============================================
    // EVENTO: Bus inicia turno
    // ============================================
    socket.on('bus-start-shift', (data) => {
      console.log(`🚌 Bus ${data.plateNumber} inició turno en ruta ${data.routeId}`)
      
      // Notificar a todos los monitores
      io.emit('shift-started', {
        plateNumber: data.plateNumber,
        routeId: data.routeId,
        driverName: data.driverName,
        startTime: new Date().toISOString()
      })
    })

    // ============================================
    // EVENTO: Bus finaliza turno
    // ============================================
    socket.on('bus-end-shift', (data) => {
      console.log(`🏁 Bus ${data.plateNumber} finalizó turno`)
      
      // Remover ubicación
      busLocations.delete(data.plateNumber)
      
      // Notificar a todos
      io.emit('shift-ended', {
        plateNumber: data.plateNumber,
        endTime: new Date().toISOString()
      })
    })

    // ============================================
    // EVENTO: Desconexión
    // ============================================
    socket.on('disconnect', (reason) => {
      console.log(`❌ Cliente desconectado: ${socket.id} - Razón: ${reason}`)
      connectedClients.delete(socket.id)
      
      // Buscar si era un bus y remover su ubicación
      for (const [plateNumber, data] of busLocations.entries()) {
        if (data.socketId === socket.id) {
          console.log(`🚌 Bus ${plateNumber} se desconectó`)
          busLocations.delete(plateNumber)
          
          // Notificar a los monitores
          io.emit('bus-disconnected', { plateNumber })
          break
        }
      }
    })

    // ============================================
    // EVENTO: Error
    // ============================================
    socket.on('error', (error) => {
      console.error(`❌ Error en socket ${socket.id}:`, error)
    })
  })

  // ============================================
  // FUNCIONES AUXILIARES (para usar desde otras partes)
  // ============================================

  /**
   * Enviar mensaje a todos los clientes
   */
  io.broadcastToAll = (event, data) => {
    io.emit(event, data)
  }

  /**
   * Enviar mensaje a un cliente específico
   */
  io.sendToClient = (socketId, event, data) => {
    io.to(socketId).emit(event, data)
  }

  /**
   * Obtener estadísticas
   */
  io.getStats = () => ({
    connectedClients: connectedClients.size,
    activeBuses: busLocations.size,
    busLocations: Array.from(busLocations.values())
  })

  return io
}

module.exports = { initWebSocket }
