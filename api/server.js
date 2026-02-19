import express from 'express'
import cors from 'cors'
import dotenv from 'dotenv'
import { createServer } from 'http'  // 🆕 Para WebSocket
import { Server } from 'socket.io'   // 🆕 Socket.io
import authRouter from './routes/auth.routes.js'          // 🆕 Autenticación
import routesRouter from './routes/routes.routes.js'
import driversRouter from './routes/drivers.routes.js'
import busesRouter from './routes/buses.routes.js'
import assignmentsRouter from './routes/assignments.routes.js'
import shiftsRouter from './routes/shifts.routes.js'  // 🆕 Turnos activos
import tripsRouter from './routes/trips.routes.js'    // 🆕 Viajes/programación
import gpsRouter from './routes/gps.routes.js'        // 🆕 GPS histórico
import geocodingRouter from './routes/geocoding.routes.js' // 🆕 Búsqueda de lugares
import usersRouter from './routes/users.routes.js'        // 🆕 Usuarios y roles

// Cargar variables de entorno
dotenv.config()

const app = express()
const httpServer = createServer(app)  // 🆕 Crear servidor HTTP
const PORT = process.env.PORT || 3001

// ============================================
// 🔌 CONFIGURAR WEBSOCKET (Socket.io)
// ============================================
const io = new Server(httpServer, {
  cors: {
    origin: [
      'http://localhost:5173',  // Vite dev server
      'http://localhost:3000',
      'http://localhost:3001',
      'http://localhost:3002',
      /\.ngrok.*\.io$/,         // ngrok URLs para pruebas móviles
      /\.ngrok-free\.app$/      // ngrok free tier
    ],
    methods: ['GET', 'POST'],
    credentials: true
  },
  pingTimeout: 60000,
  pingInterval: 25000
})

// Almacenar ubicaciones de buses en memoria
const busLocations = new Map()
const connectedClients = new Set()

// Eventos de Socket.io
io.on('connection', (socket) => {
  console.log(`✅ WebSocket: Cliente conectado - ${socket.id}`)
  connectedClients.add(socket.id)
  
  // Enviar bienvenida
  socket.emit('welcome', {
    message: 'Conectado a BucaraBus en tiempo real',
    timestamp: new Date().toISOString(),
    activeBuses: busLocations.size
  })

  // Enviar todas las ubicaciones actuales
  socket.emit('all-locations', Array.from(busLocations.values()))

  // 📍 Recibir ubicación de un bus
  socket.on('bus-location', async (data) => {
    console.log(`📍 GPS Bus ${data.plateNumber}: ${data.lat}, ${data.lng}`)
    
    const locationData = {
      ...data,
      lastUpdate: new Date().toISOString(),
      socketId: socket.id
    }
    busLocations.set(data.plateNumber, locationData)
    
    // Nota: Las ubicaciones GPS en tiempo real se manejan solo en memoria vía WebSocket
    // No se persisten en BD para mantener el rendimiento alto
    
    // Emitir a TODOS los clientes (incluyendo app pasajeros)
    io.emit('bus-location-update', {
      busId: data.plateNumber,
      plate: data.plateNumber,
      latitude: data.lat,
      longitude: data.lng,
      speed: data.speed || 0,
      routeId: data.routeId,
      routeName: data.routeName,
      routeColor: data.routeColor,
      driverId: data.driverId,
      timestamp: new Date().toISOString()
    })
    
    // También emitir el evento antiguo para compatibilidad
    socket.broadcast.emit('bus-moved', locationData)
  })

  // 📡 Solicitar todas las ubicaciones
  socket.on('get-all-locations', () => {
    socket.emit('all-locations', Array.from(busLocations.values()))
  })

  // 🚌 Bus inicia turno
  socket.on('bus-start-shift', (data) => {
    console.log(`🚌 Bus ${data.plateNumber} inició turno`)
    io.emit('shift-started', { ...data, startTime: new Date().toISOString() })
  })

  // 🏁 Bus termina turno
  socket.on('bus-end-shift', (data) => {
    console.log(`🏁 Bus ${data.plateNumber} terminó turno`)
    busLocations.delete(data.plateNumber)
    io.emit('shift-ended', { ...data, endTime: new Date().toISOString() })
  })

  // ❌ Desconexión
  socket.on('disconnect', (reason) => {
    console.log(`❌ WebSocket: Cliente desconectado - ${socket.id} (${reason})`)
    connectedClients.delete(socket.id)
    
    // Buscar si era un bus
    for (const [plateNumber, data] of busLocations.entries()) {
      if (data.socketId === socket.id) {
        busLocations.delete(plateNumber)
        io.emit('bus-disconnected', { plateNumber })
        break
      }
    }
  })
})

// Hacer io disponible para otros módulos
app.set('io', io)
app.set('busLocations', busLocations)

// Middleware - CORS abierto para desarrollo
app.use(cors({
  origin: true,  // Permitir cualquier origen en desarrollo
  credentials: true
}))
app.use(express.json())
app.use(express.urlencoded({ extended: true }))

// Logger middleware
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`)
  console.log(`   Headers:`, req.headers['content-type'])
  if (req.method === 'POST') {
    console.log(`   Body:`, JSON.stringify(req.body, null, 2))
  }
  next()
})

// Welcome route
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: '🚌 BucaraBus API Server',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    endpoints: {
      health: '/health',
      routes: '/api/routes',
      drivers: '/api/drivers',
      buses: '/api/buses',
      assignments: '/api/assignments',
      shifts: '/api/shifts',  // 🆕 Turnos activos
      users: '/api/users',    // 🆕 Usuarios y roles
      documentation: 'Ver README.md para más información'
    }
  })
})

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    service: 'BucaraBus API',
    version: '1.0.0',
    websocket: {
      connectedClients: connectedClients.size,
      activeBuses: busLocations.size
    }
  })
})

// API Routes
app.use('/api/auth', authRouter)      // 🆕 Autenticación
app.use('/api/routes', routesRouter)
app.use('/api/drivers', driversRouter)
app.use('/api/buses', busesRouter)
app.use('/api/assignments', assignmentsRouter)
app.use('/api/shifts', shiftsRouter)  // 🆕 Turnos activos
app.use('/api/trips', tripsRouter)    // 🆕 Viajes/programación
app.use('/api/gps', gpsRouter)        // 🆕 GPS histórico
app.use('/api/geocoding', geocodingRouter) // 🆕 Búsqueda de lugares
app.use('/api/users', usersRouter)    // 🆕 Usuarios y roles

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint no encontrado',
    path: req.path
  })
})

// Error handler
app.use((error, req, res, next) => {
  console.error('❌ Error:', error)
  res.status(500).json({
    success: false,
    error: 'Error interno del servidor',
    message: process.env.NODE_ENV === 'development' ? error.message : undefined
  })
})

// Iniciar servidor HTTP (no app.listen, porque usamos httpServer para WebSocket)
httpServer.listen(PORT, '0.0.0.0', () => {
  console.log(`
╔════════════════════════════════════════╗
║   🚌 BucaraBus API Server              ║
║   🌐 http://localhost:${PORT}            ║
║   🌐 Network: http://0.0.0.0:${PORT}     ║
║   🔌 WebSocket: Activo                 ║
║   📊 Environment: ${process.env.NODE_ENV || 'development'}       ║
║   🗄️  Database: PostgreSQL + PostGIS   ║
╚════════════════════════════════════════╝
  `)
})

export default app
