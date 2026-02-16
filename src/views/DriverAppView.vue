<template>
  <div class="driver-app" :class="{ 'shift-active': shiftActive }">
    <!-- Login Screen -->
    <div v-if="!isLoggedIn" class="login-screen">
      <div class="login-container">
        <div class="login-header">
          <div class="logo">🚌</div>
          <h1>BucaraBus</h1>
          <p>App Conductor</p>
        </div>
        
        <form @submit.prevent="handleLogin" class="login-form">
          <div class="form-group">
            <label>Cédula</label>
            <input 
              v-model="loginForm.cedula" 
              type="text" 
              placeholder="Ingresa tu cédula"
              required
              inputmode="numeric"
            />
          </div>
          
          <div class="form-group">
            <label>PIN</label>
            <input 
              v-model="loginForm.pin" 
              type="password" 
              placeholder="****"
              maxlength="4"
              required
              inputmode="numeric"
            />
          </div>
          
          <button type="submit" class="btn-login" :disabled="isLoggingIn">
            <span v-if="isLoggingIn">Verificando...</span>
            <span v-else>Ingresar</span>
          </button>
          
          <p v-if="loginError" class="login-error">{{ loginError }}</p>
        </form>
      </div>
    </div>

    <!-- Main App Screen -->
    <div v-else class="main-screen">
      <!-- Header -->
      <header class="app-header">
        <div class="driver-info">
          <span class="driver-avatar">👨‍✈️</span>
          <div class="driver-details">
            <span class="driver-name">{{ driver.name }}</span>
            <span class="driver-bus">🚌 {{ driver.busPlate }}</span>
          </div>
        </div>
        <button @click="handleLogout" class="btn-logout">
          Salir
        </button>
      </header>

      <!-- Connection Status -->
      <div class="connection-status" :class="{ connected: isConnected }">
        <span class="status-dot"></span>
        <span>{{ isConnected ? 'Conectado' : 'Sin conexión' }}</span>
      </div>

      <!-- No Trips Message -->
      <div v-if="!currentTrip && assignedTrips.length === 0" class="no-trips-message">
        <div class="no-trips-icon">📋</div>
        <h3>Sin viajes asignados</h3>
        <p>No tienes viajes programados para hoy. Contacta al supervisor.</p>
      </div>

      <!-- Route Info -->
      <div v-if="currentTrip" class="route-info-card" :class="{ expanded: isRoutesExpanded }">
        <!-- Current Trip Header (Always Visible) -->
        <div class="route-header" @click="toggleRoutesExpansion">
          <div 
            class="route-color-bar" 
            :style="{ background: currentTrip.color }"
          ></div>
          <div class="route-details">
            <div class="route-main-info">
              <h3>{{ currentTrip.name }} <span class="route-id">#{{ currentTrip.id_route }}</span></h3>
              <p class="route-time">
                {{ formatTripTime(currentTrip.start_time) }} - {{ formatTripTime(currentTrip.end_time) }}
              </p>
            </div>
            <div class="route-status-badge" :class="getTripStatusClass(currentTrip)">
              {{ getTripStatusLabel(currentTrip) }}
            </div>
          </div>
          <div class="expand-icon" :class="{ rotated: isRoutesExpanded }">
            ▼
          </div>
        </div>

        <!-- All Trips Timeline (Expandable) -->
        <transition name="slide-down">
          <div v-if="isRoutesExpanded" class="trips-timeline">
            <div class="timeline-header">
              <span>Viajes del día</span>
              <span class="trip-count">{{ assignedTrips.length }} viajes</span>
            </div>
            
            <div class="timeline-items">
              <div 
                v-for="trip in assignedTrips" 
                :key="trip.id_trip"
                class="timeline-item"
                :class="{ 
                  'is-current': trip.id_trip === currentTrip?.id_trip,
                  'is-completed': trip.status_trip === 'completed',
                  'is-active': trip.status_trip === 'active'
                }"
                @click="selectTrip(trip)"
              >
                <div class="timeline-dot" :style="{ background: trip.color }"></div>
                <div class="timeline-content">
                  <div class="timeline-main">
                    <span class="timeline-route-name">{{ trip.name }} <span class="route-id-small">#{{ trip.id_route }}</span></span>
                    <span class="timeline-time">{{ formatTripTime(trip.start_time) }}</span>
                  </div>
                  <div class="timeline-status">
                    <span class="status-indicator" :class="getTripStatusClass(trip)">
                      {{ getTripStatusLabel(trip) }}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </transition>
      </div>

      <!-- Map Container -->
      <div class="map-container">
        <div id="driver-map" class="driver-map"></div>
        
        <!-- GPS Accuracy Indicator -->
        <div v-if="shiftActive && currentLocation" class="gps-accuracy">
          <span class="accuracy-icon">📡</span>
          <span>Precisión: {{ Math.round(currentLocation.accuracy || 0) }}m</span>
        </div>
      </div>

      <!-- Shift Controls -->
      <div class="shift-controls">
        <div v-if="!shiftActive" class="shift-start">
          <button @click="startShift" class="btn-start-shift" :disabled="!isConnected">
            <span class="btn-icon">▶️</span>
            <span class="btn-text">Iniciar Turno</span>
          </button>
          <p class="shift-hint">Activa el GPS para iniciar tu turno</p>
        </div>

        <div v-else class="shift-running">
          <div class="shift-stats">
            <div class="stat">
              <span class="stat-value">{{ formatTime(shiftDuration) }}</span>
              <span class="stat-label">Tiempo</span>
            </div>
            <div class="stat">
              <span class="stat-value">{{ tripsCompleted }}</span>
              <span class="stat-label">Viajes</span>
            </div>
            <div class="stat">
              <span class="stat-value">{{ Math.round(currentSpeed) }}</span>
              <span class="stat-label">km/h</span>
            </div>
          </div>

          <div class="progress-section">
            <div class="progress-label">
              <span>Progreso de ruta</span>
              <span>{{ routeProgress }}%</span>
            </div>
            <div class="progress-bar">
              <div 
                class="progress-fill" 
                :style="{ width: routeProgress + '%', background: currentTrip?.color || '#667eea' }"
              ></div>
            </div>
          </div>

          <button @click="endShift" class="btn-end-shift">
            <span class="btn-icon">⏹️</span>
            <span class="btn-text">Terminar Turno</span>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { io } from 'socket.io-client'
import L from 'leaflet'

// ============================================
// STATE
// ============================================
// Detectar si estamos en red local, localhost o túnel Azure
const getApiUrl = () => {
  const hostname = window.location.hostname
  
  // Si es túnel Azure Dev Tunnels, usar el túnel del API
  if (hostname.includes('devtunnels.ms')) {
    // Intentar derivar la URL del API reemplazando el puerto del frontend (5173) por el del backend (3001)
    if (hostname.includes('-5173')) {
      return `https://${hostname.replace('-5173', '-3001')}`
    }
    return 'https://2flptzc8-3001.use2.devtunnels.ms'
  }
  
  // Usar variable de entorno si está disponible
  if (import.meta.env.VITE_WS_URL) {
    return import.meta.env.VITE_WS_URL
  }
  // Si no es localhost, usar la misma IP para el API
  if (hostname !== 'localhost' && hostname !== '127.0.0.1') {
    return `http://${hostname}:3001`
  }
  return import.meta.env.VITE_API_URL?.replace(/\/api$/, '') || 'http://localhost:3001'
}
const API_URL = getApiUrl()

// Auth
const isLoggedIn = ref(false)
const isLoggingIn = ref(false)
const loginError = ref('')
const loginForm = ref({
  cedula: '',
  pin: ''
})

// Driver data
const driver = ref({
  id: null,
  name: '',
  cedula: '',
  busId: null,
  busPlate: '',
  routeId: null
})

// Trips & Routes
const assignedTrips = ref([]) // Todos los viajes del día
const currentTrip = ref(null) // Viaje actual basado en hora
const isRoutesExpanded = ref(false)

// Shift
const shiftActive = ref(false)
const shiftStartTime = ref(null)
const shiftDuration = ref(0)
const tripsCompleted = ref(0)
const routeProgress = ref(0)

// Location
const currentLocation = ref(null)
const currentSpeed = ref(0)
const watchId = ref(null)

// WebSocket
const socket = ref(null)
const isConnected = ref(false)

// Map
let leafletMap = null
let routePolyline = null
let driverMarker = null

// ============================================
// LOGIN
// ============================================
const handleLogin = async () => {
  isLoggingIn.value = true
  loginError.value = ''
  
  try {
    // Buscar conductor por cédula
    const response = await fetch(`${API_URL}/api/drivers`)
    const data = await response.json()
    
    if (data.success) {
      const foundDriver = data.data.find(d => 
        d.id_user.toString() === loginForm.value.cedula || 
        d.cedula_driver === loginForm.value.cedula
      )
      
      if (foundDriver) {
        // En producción verificar PIN real
        // Por ahora aceptamos cualquier PIN de 4 dígitos
        if (loginForm.value.pin.length === 4) {
          driver.value = {
            id: foundDriver.id_user,
            name: foundDriver.name_driver,
            cedula: foundDriver.cedula_driver,
            busId: null,
            busPlate: '',
            routeId: null
          }
          
          // Buscar turno activo del conductor
          await loadActiveShift()
          
          isLoggedIn.value = true
          
          // Inicializar mapa después del login
          nextTick(() => {
            initMap()
            connectWebSocket()
          })
        } else {
          loginError.value = 'PIN debe tener 4 dígitos'
        }
      } else {
        loginError.value = 'Conductor no encontrado'
      }
    }
  } catch (error) {
    console.error('Error login:', error)
    loginError.value = 'Error de conexión'
  } finally {
    isLoggingIn.value = false
  }
}

const loadActiveShift = async () => {
  try {
    console.log('🔍 Cargando turno para conductor ID:', driver.value.id)
    
    // Primero obtener el bus asignado al conductor
    const busResponse = await fetch(`${API_URL}/api/buses`)
    const busData = await busResponse.json()
    console.log('📦 Buses obtenidos:', busData)
    
    if (busData.success) {
      const assignedBus = busData.data.find(b => b.id_user === driver.value.id && b.is_active)
      console.log('🚌 Bus asignado encontrado:', assignedBus)
      
      if (assignedBus) {
        driver.value.busId = assignedBus.plate_number
        driver.value.busPlate = assignedBus.plate_number
      } else {
        console.warn('⚠️ No hay bus asignado al conductor')
        return
      }
    }
    
    // Obtener fecha actual en formato YYYY-MM-DD (local, no UTC)
    const now = new Date()
    const year = now.getFullYear()
    const month = String(now.getMonth() + 1).padStart(2, '0')
    const day = String(now.getDate()).padStart(2, '0')
    const today = `${year}-${month}-${day}`
    console.log('📅 Buscando viajes para fecha:', today, 'bus:', driver.value.busPlate)
    
    // Cargar todos los viajes asignados al bus para hoy
    const tripUrl = `${API_URL}/api/trips?plate_number=${driver.value.busPlate}&trip_date=${today}`
    console.log('🌐 URL de consulta:', tripUrl)
    const tripsResponse = await fetch(tripUrl)
    const tripsData = await tripsResponse.json()
    console.log('📋 Viajes recibidos:', tripsData)
    
    // Intentar obtener todas las rutas de una vez como fallback
    let allRoutes = {}
    try {
      console.log('🔄 Obteniendo todas las rutas como fallback...')
      const allRoutesResponse = await fetch(`${API_URL}/api/routes`)
      if (allRoutesResponse.ok) {
        const routesData = await allRoutesResponse.json()
        console.log('️📍 Todas las rutas obtenidas:', routesData)
        
        // Mostrar estructura de la primera ruta para debugging
        if (Array.isArray(routesData) && routesData.length > 0) {
          console.log('🔎 Estructura de primera ruta:', routesData[0])
          console.log('🔎 Keys de primera ruta:', Object.keys(routesData[0]))
        } else if (routesData.data && Array.isArray(routesData.data) && routesData.data.length > 0) {
          console.log('🔎 Estructura de primera ruta (en data):', routesData.data[0])
          console.log('🔎 Keys de primera ruta (en data):', Object.keys(routesData.data[0]))
        }
        
        // Crear un mapa de rutas por ID para acceso rápido
        if (Array.isArray(routesData)) {
          routesData.forEach(route => {
            allRoutes[route.id_route] = route
          })
        } else if (routesData.data && Array.isArray(routesData.data)) {
          routesData.data.forEach(route => {
            allRoutes[route.id_route] = route
          })
        }
        console.log('✅ Rutas en caché:', Object.keys(allRoutes))
      }
    } catch (error) {
      console.warn('⚠️ No se pudo obtener todas las rutas:', error.message)
    }
    
    if (Array.isArray(tripsData) && tripsData.length > 0) {
      console.log('📝 Estructura de primer trip:', tripsData[0])
      
      // Mapear viajes con información de ruta
      assignedTrips.value = await Promise.all(
        tripsData.map(async (trip) => {
          let routePath = []
          
          // Intenta obtener path de diferentes propiedades posibles del trip PRIMERO
          if (trip.path_route?.coordinates) {
            console.log(`✅ Path encontrado en trip.path_route.coordinates para ruta ${trip.id_route}`)
            routePath = trip.path_route.coordinates.map(c => [c[1], c[0]])
          } else if (typeof trip.path_route === 'string') {
            try {
              const parsed = JSON.parse(trip.path_route)
              if (parsed.coordinates) {
                routePath = parsed.coordinates.map(c => [c[1], c[0]])
                console.log(`✅ Path parseado desde string JSON para ruta ${trip.id_route}`)
              }
            } catch (e) {
              console.warn(`⚠️ No se pudo parsear path_route como JSON`)
            }
          } else if (trip.geometry?.coordinates) {
            console.log(`✅ Path encontrado en trip.geometry.coordinates para ruta ${trip.id_route}`)
            routePath = trip.geometry.coordinates.map(c => [c[1], c[0]])
          }
          
          // Si no encontró en el trip, intenta desde la caché de rutas
          if (routePath.length === 0 && allRoutes[trip.id_route]) {
            const cachedRoute = allRoutes[trip.id_route]
            console.log(`🔍 Usando ruta en caché para ${trip.id_route}:`, cachedRoute)
            console.log(`🔍 Keys en cachedRoute:`, Object.keys(cachedRoute))
            
            // Intentar todas las propiedades posibles
            if (cachedRoute.path_route?.coordinates) {
              routePath = cachedRoute.path_route.coordinates.map(c => [c[1], c[0]])
              console.log(`✅ Path de caché (path_route.coordinates): ${routePath.length} puntos`)
            } else if (cachedRoute.path?.length > 0) {
              routePath = Array.isArray(cachedRoute.path) ? cachedRoute.path : []
              console.log(`✅ Path de caché (path): ${routePath.length} puntos`)
            } else if (cachedRoute.geometry?.coordinates) {
              routePath = cachedRoute.geometry.coordinates.map(c => [c[1], c[0]])
              console.log(`✅ Path de caché (geometry.coordinates): ${routePath.length} puntos`)
            } else if (typeof cachedRoute.path_route === 'string') {
              try {
                const parsed = JSON.parse(cachedRoute.path_route)
                if (parsed.coordinates) {
                  routePath = parsed.coordinates.map(c => [c[1], c[0]])
                  console.log(`✅ Path de caché (JSON parseado): ${routePath.length} puntos`)
                }
              } catch (e) {}
            } else {
              console.warn(`⚠️ Ruta ${trip.id_route} en caché pero sin coordenadas válidas`)
            }
          }
          
          // Si aún no hay path, intenta obtenerlo individualmente
          if (routePath.length === 0) {
            console.log(`📡 Intentando obtener ruta individual ${trip.id_route}...`)
            try {
              const routeRes = await fetch(`${API_URL}/api/routes/${trip.id_route}`)
              
              if (routeRes.ok) {
                const routeData = await routeRes.json()
                console.log(`📦 Respuesta de /api/routes/${trip.id_route}:`, routeData)
                
                let coordinates = null
                if (routeData.data?.path_route?.coordinates) {
                  coordinates = routeData.data.path_route.coordinates
                } else if (routeData.data?.geometry?.coordinates) {
                  coordinates = routeData.data.geometry.coordinates
                } else if (routeData.path_route?.coordinates) {
                  coordinates = routeData.path_route.coordinates
                } else if (routeData.geometry?.coordinates) {
                  coordinates = routeData.geometry.coordinates
                }
                
                if (coordinates && coordinates.length > 0) {
                  routePath = coordinates.map(c => [c[1], c[0]])
                  console.log(`✅ Path obtenido: ${routePath.length} puntos`)
                }
              }
            } catch (error) {
              console.warn(`⚠️ Error obteniendo ruta ${trip.id_route}:`, error.message)
            }
          }
          
          if (routePath.length === 0) {
            console.warn(`⚠️ No se pudo obtener path para ruta ${trip.id_route}`)
          }
          
          return {
            id_trip: trip.id_trip,
            id_route: trip.id_route,
            name: trip.name_route || `Ruta ${trip.id_route}`,
            color: trip.color_route || '#667eea',
            start_time: trip.start_time,
            end_time: trip.end_time,
            status_trip: trip.status_trip,
            trip_date: trip.trip_date,
            path: routePath
          }
        })
      )
      
      // Ordenar por hora de inicio
      assignedTrips.value.sort((a, b) => a.start_time.localeCompare(b.start_time))
      console.log('✅ Total de viajes cargados:', assignedTrips.value.length)
      console.log('📊 Viajes con rutas:', assignedTrips.value.map(t => ({
        name: t.name,
        id_route: t.id_route,
        pathLength: t.path?.length || 0
      })))
      
      // Determinar viaje actual basado en la hora
      updateCurrentTrip()
      console.log('🎯 Viaje actual seleccionado:', currentTrip.value?.name || 'ninguno')
      console.log('🗺️ Path del viaje actual:', currentTrip.value?.path?.length || 0, 'puntos')
      
      // Auto-actualizar cada minuto
      setInterval(updateCurrentTrip, 60000)
      
    } else {
      console.warn('⚠️ No hay viajes asignados para hoy. Datos recibidos:', tripsData)
    }
  } catch (error) {
    console.error('Error loading trips:', error)
  }
}

const updateCurrentTrip = () => {
  if (assignedTrips.value.length === 0) return
  
  const now = new Date()
  const currentTime = now.toTimeString().slice(0, 8) // HH:MM:SS
  
  // Buscar el viaje activo o el próximo viaje
  let foundTrip = null
  
  // 1. Buscar viaje actualmente en progreso
  foundTrip = assignedTrips.value.find(t => 
    t.status_trip === 'active' ||
    (t.start_time <= currentTime && t.end_time >= currentTime)
  )
  
  // 2. Si no hay activo, buscar el próximo viaje
  if (!foundTrip) {
    foundTrip = assignedTrips.value.find(t => 
      t.start_time > currentTime && t.status_trip === 'pending'
    )
  }
  
  // 3. Si todos pasaron, mostrar el último
  if (!foundTrip) {
    foundTrip = assignedTrips.value[assignedTrips.value.length - 1]
  }
  
  // Solo actualizar si cambió
  if (foundTrip && foundTrip.id_trip !== currentTrip.value?.id_trip) {
    currentTrip.value = foundTrip
    driver.value.routeId = foundTrip.id_route
    
    console.log(`🔄 Cambio automático a: ${foundTrip.name} (${foundTrip.start_time})`)    
    console.log(`🗺️ Path disponible: ${foundTrip.path?.length || 0} puntos`)
    // El watch se encargará de dibujar la ruta cuando el mapa esté listo
  } else if (!currentTrip.value && foundTrip) {
    currentTrip.value = foundTrip
    driver.value.routeId = foundTrip.id_route
    
    console.log(`✅ Viaje inicial seleccionado: ${foundTrip.name}`)
    console.log(`🗺️ Path disponible: ${foundTrip.path?.length || 0} puntos`)
    // El watch se encargará de dibujar la ruta cuando el mapa esté listo
  }
}

const handleLogout = () => {
  if (shiftActive.value) {
    if (!confirm('¿Terminar turno y salir?')) return
    endShift()
  }
  
  disconnectWebSocket()
  isLoggedIn.value = false
  driver.value = { id: null, name: '', cedula: '', busId: null, busPlate: '', routeId: null }
  loginForm.value = { cedula: '', pin: '' }
}

// ============================================
// WEBSOCKET
// ============================================
const connectWebSocket = () => {
  socket.value = io(API_URL, {
    transports: ['websocket', 'polling'],
    reconnection: true,
    reconnectionAttempts: 10,
    reconnectionDelay: 1000
  })
  
  socket.value.on('connect', () => {
    console.log('✅ WebSocket conectado')
    isConnected.value = true
  })
  
  socket.value.on('disconnect', () => {
    console.log('❌ WebSocket desconectado')
    isConnected.value = false
  })
  
  socket.value.on('welcome', (data) => {
    console.log('👋 Bienvenida:', data.message)
  })
}

const disconnectWebSocket = () => {
  if (socket.value) {
    socket.value.disconnect()
    socket.value = null
  }
}

const sendLocation = (location) => {
  if (!socket.value || !isConnected.value || !shiftActive.value) return
  
  const locationData = {
    plateNumber: driver.value.busPlate,
    busId: driver.value.busId,
    driverId: driver.value.id,
    driverName: driver.value.name,
    routeId: driver.value.routeId,
    lat: location.lat,
    lng: location.lng,
    speed: location.speed || 0,
    accuracy: location.accuracy,
    heading: location.heading,
    timestamp: new Date().toISOString()
  }
  
  socket.value.emit('bus-location', locationData)
  console.log(`📍 Enviando GPS: ${location.lat.toFixed(5)}, ${location.lng.toFixed(5)}`)
}

// ============================================
// GPS / GEOLOCATION
// ============================================
const startGPSTracking = () => {
  if (!navigator.geolocation) {
    alert('Tu navegador no soporta GPS')
    return false
  }
  
  const options = {
    enableHighAccuracy: true,
    timeout: 10000,
    maximumAge: 0
  }
  
  watchId.value = navigator.geolocation.watchPosition(
    (position) => {
      const { latitude, longitude, accuracy, speed, heading } = position.coords
      
      currentLocation.value = {
        lat: latitude,
        lng: longitude,
        accuracy,
        speed: speed ? speed * 3.6 : 0, // m/s to km/h
        heading
      }
      
      currentSpeed.value = currentLocation.value.speed
      
      // Actualizar marcador en mapa
      updateDriverMarker(latitude, longitude)
      
      // Enviar por WebSocket cada 5 segundos
      sendLocation(currentLocation.value)
    },
    (error) => {
      console.error('Error GPS:', error)
      if (error.code === 1) {
        alert('Permiso de ubicación denegado. Por favor habilita el GPS.')
      }
    },
    options
  )
  
  return true
}

const stopGPSTracking = () => {
  if (watchId.value) {
    navigator.geolocation.clearWatch(watchId.value)
    watchId.value = null
  }
}

// ============================================
// MAP
// ============================================
const initMap = () => {
  if (leafletMap) return
  
  // Centro de Bucaramanga
  const center = [7.1193, -73.1227]
  
  leafletMap = L.map('driver-map', {
    center,
    zoom: 14,
    zoomControl: false
  })
  
  L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', {
    attribution: '© OpenStreetMap'
  }).addTo(leafletMap)
  
  // Dibujar ruta asignada si existe
  if (currentTrip.value?.path?.length > 0) {
    console.log(`🎨 Mapa inicializado, dibujando ruta con ${currentTrip.value.path.length} puntos`)
    drawRoute(currentTrip.value.path, currentTrip.value.color)
  } else {
    console.warn(`⚠️ Mapa inicializado pero currentTrip.value.path está vacío o no existe`)
    console.log(`   currentTrip.value:`, currentTrip.value)
  }
}

const drawRoute = (path, color) => {
  console.log('🎨 drawRoute llamado con:', { pathLength: path?.length, color, hasMap: !!leafletMap })
  
  if (!leafletMap) {
    console.warn('⚠️ No hay mapa inicializado')
    return
  }
  
  if (!path || path.length < 2) {
    console.warn('⚠️ Path inválido o muy corto:', path?.length)
    return
  }
  
  // Remover polyline anterior si existe
  if (routePolyline) {
    leafletMap.removeLayer(routePolyline)
    console.log('🗑️ Polyline anterior removido')
  }
  
  // Dibujar nueva ruta
  routePolyline = L.polyline(path, {
    color: color || '#667eea',
    weight: 6,
    opacity: 0.8
  }).addTo(leafletMap)
  
  console.log('✅ Ruta dibujada en el mapa')
  
  // Ajustar vista del mapa a la ruta
  leafletMap.fitBounds(routePolyline.getBounds(), { padding: [50, 50] })
  console.log('📐 Vista del mapa ajustada')
}

const updateDriverMarker = (lat, lng) => {
  if (!leafletMap) return
  
  if (driverMarker) {
    driverMarker.setLatLng([lat, lng])
  } else {
    const icon = L.divIcon({
      className: 'driver-marker',
      html: `
        <div class="driver-marker-inner">
          <div class="driver-marker-pulse"></div>
          <div class="driver-marker-icon">🚌</div>
        </div>
      `,
      iconSize: [50, 50],
      iconAnchor: [25, 25]
    })
    
    driverMarker = L.marker([lat, lng], { icon }).addTo(leafletMap)
  }
  
  // Centrar mapa en posición actual
  leafletMap.setView([lat, lng], leafletMap.getZoom())
}

// ============================================
// SHIFT MANAGEMENT
// ============================================
let shiftTimer = null

const startShift = async () => {
  if (!currentTrip.value) {
    alert('No tienes viajes asignados. Contacta al supervisor.')
    return
  }
  
  // Iniciar GPS
  const gpsStarted = startGPSTracking()
  if (!gpsStarted) return
  
  shiftActive.value = true
  shiftStartTime.value = Date.now()
  
  // Actualizar estado del viaje a 'active'
  try {
    await fetch(`${API_URL}/api/trips/${currentTrip.value.id_trip}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status_trip: 'active' })
    })
    currentTrip.value.status_trip = 'active'
  } catch (error) {
    console.error('Error actualizando estado del viaje:', error)
  }
  
  // Timer para duración del turno
  shiftTimer = setInterval(() => {
    shiftDuration.value = Math.floor((Date.now() - shiftStartTime.value) / 1000)
  }, 1000)
  
  // Notificar al servidor
  if (socket.value) {
    socket.value.emit('bus-start-shift', {
      plateNumber: driver.value.busPlate,
      busId: driver.value.busId,
      driverId: driver.value.id,
      driverName: driver.value.name,
      routeId: driver.value.routeId,
      tripId: currentTrip.value.id_trip
    })
  }
  
  console.log(`🚌 Turno iniciado - Viaje: ${currentTrip.value.name}`)
}

const endShift = async () => {
  // Detener GPS
  stopGPSTracking()
  
  // Detener timer
  if (shiftTimer) {
    clearInterval(shiftTimer)
    shiftTimer = null
  }
  
  // Marcar viaje actual como completado
  if (currentTrip.value) {
    try {
      await fetch(`${API_URL}/api/trips/${currentTrip.value.id_trip}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status_trip: 'completed' })
      })
      currentTrip.value.status_trip = 'completed'
      tripsCompleted.value++
    } catch (error) {
      console.error('Error actualizando estado del viaje:', error)
    }
  }
  
  // Notificar al servidor
  if (socket.value) {
    socket.value.emit('bus-end-shift', {
      plateNumber: driver.value.busPlate,
      busId: driver.value.busId,
      driverId: driver.value.id,
      tripId: currentTrip.value?.id_trip,
      duration: shiftDuration.value,
      tripsCompleted: tripsCompleted.value
    })
  }
  
  shiftActive.value = false
  shiftDuration.value = 0
  
  // Auto-cambiar al siguiente viaje si existe
  updateCurrentTrip()
  
  console.log('🏁 Turno terminado')
}

// ============================================
// HELPERS
// ============================================
const formatTime = (seconds) => {
  const hrs = Math.floor(seconds / 3600)
  const mins = Math.floor((seconds % 3600) / 60)
  const secs = seconds % 60
  
  if (hrs > 0) {
    return `${hrs}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
  }
  return `${mins}:${secs.toString().padStart(2, '0')}`
}

const formatTripTime = (timeString) => {
  // timeString viene como "HH:MM:SS", queremos "HH:MM"
  if (!timeString) return ''
  return timeString.slice(0, 5)
}

const toggleRoutesExpansion = () => {
  isRoutesExpanded.value = !isRoutesExpanded.value
}

const selectTrip = (trip) => {
  if (trip.status_trip === 'completed') {
    return // No permitir seleccionar viajes completados
  }
  
  currentTrip.value = trip
  driver.value.routeId = trip.id_route
  
  // Redibujar ruta
  if (trip.path.length > 0) {
    drawRoute(trip.path, trip.color)
  }
  
  // Colapsar después de seleccionar
  isRoutesExpanded.value = false
  
  console.log(`✅ Viaje seleccionado manualmente: ${trip.name}`)
}

const getTripStatusClass = (trip) => {
  if (!trip) return ''
  
  const now = new Date().toTimeString().slice(0, 8)
  
  if (trip.status_trip === 'completed') return 'status-completed'
  if (trip.status_trip === 'active') return 'status-active'
  if (trip.start_time > now) return 'status-upcoming'
  if (trip.end_time < now) return 'status-past'
  
  return 'status-pending'
}

const getTripStatusLabel = (trip) => {
  if (!trip) return ''
  
  const now = new Date().toTimeString().slice(0, 8)
  
  if (trip.status_trip === 'completed') return 'Completado'
  if (trip.status_trip === 'active') return 'En progreso'
  if (trip.start_time > now) return 'Próximo'
  if (trip.end_time < now) return 'Retrasado'
  
  return 'Pendiente'
}

// ============================================
// WATCHERS
// ============================================
watch(() => currentTrip.value?.id_trip, (newTripId, oldTripId) => {
  if (newTripId && leafletMap && currentTrip.value?.path?.length > 0) {
    console.log(`🔔 Watch: currentTrip cambió, dibujando ruta...`)
    console.log(`📍 Path length: ${currentTrip.value.path.length}`)
    drawRoute(currentTrip.value.path, currentTrip.value.color)
  }
}, { flush: 'post' })

// ============================================
// LIFECYCLE
// ============================================
onMounted(() => {
  // Prevenir que el celular se bloquee
  if ('wakeLock' in navigator) {
    navigator.wakeLock.request('screen').catch(console.error)
  }
})

onUnmounted(() => {
  stopGPSTracking()
  disconnectWebSocket()
  if (shiftTimer) clearInterval(shiftTimer)
  if (leafletMap) {
    leafletMap.remove()
    leafletMap = null
  }
})
</script>

<style scoped>
/* ============================================
   DRIVER APP STYLES
   ============================================ */

.driver-app {
  min-height: 100vh;
  min-height: 100dvh;
  background: #0f172a;
  color: white;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

/* ============================================
   LOGIN SCREEN
   ============================================ */

.login-screen {
  min-height: 100vh;
  min-height: 100dvh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
  background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
}

.login-container {
  width: 100%;
  max-width: 360px;
}

.login-header {
  text-align: center;
  margin-bottom: 32px;
}

.logo {
  font-size: 64px;
  margin-bottom: 16px;
  animation: bounce 2s infinite;
}

@keyframes bounce {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-10px); }
}

.login-header h1 {
  font-size: 28px;
  font-weight: 700;
  margin: 0;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.login-header p {
  color: #94a3b8;
  margin-top: 4px;
}

.login-form {
  background: #1e293b;
  border-radius: 16px;
  padding: 24px;
  box-shadow: 0 10px 40px rgba(0,0,0,0.3);
}

.form-group {
  margin-bottom: 20px;
}

.form-group label {
  display: block;
  font-size: 14px;
  font-weight: 500;
  color: #94a3b8;
  margin-bottom: 8px;
}

.form-group input {
  width: 100%;
  padding: 14px 16px;
  font-size: 16px;
  background: #0f172a;
  border: 2px solid #334155;
  border-radius: 10px;
  color: white;
  transition: all 0.3s;
}

.form-group input:focus {
  outline: none;
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.2);
}

.btn-login {
  width: 100%;
  padding: 16px;
  font-size: 16px;
  font-weight: 600;
  color: white;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border: none;
  border-radius: 10px;
  cursor: pointer;
  transition: all 0.3s;
}

.btn-login:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(102, 126, 234, 0.4);
}

.btn-login:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.login-error {
  color: #f87171;
  text-align: center;
  margin-top: 16px;
  font-size: 14px;
}

/* ============================================
   MAIN SCREEN
   ============================================ */

.main-screen {
  display: flex;
  flex-direction: column;
  min-height: 100vh;
  min-height: 100dvh;
}

.app-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 16px;
  background: #1e293b;
  border-bottom: 1px solid #334155;
}

.driver-info {
  display: flex;
  align-items: center;
  gap: 12px;
}

.driver-avatar {
  font-size: 32px;
}

.driver-details {
  display: flex;
  flex-direction: column;
}

.driver-name {
  font-weight: 600;
  font-size: 14px;
}

.driver-bus {
  font-size: 12px;
  color: #94a3b8;
}

.btn-logout {
  padding: 8px 16px;
  font-size: 12px;
  color: #f87171;
  background: rgba(248, 113, 113, 0.1);
  border: 1px solid rgba(248, 113, 113, 0.3);
  border-radius: 8px;
  cursor: pointer;
}

/* Connection Status */
.connection-status {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 8px;
  background: rgba(248, 113, 113, 0.1);
  color: #f87171;
  font-size: 12px;
  font-weight: 500;
}

.connection-status.connected {
  background: rgba(34, 197, 94, 0.1);
  color: #22c55e;
}

.status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: currentColor;
  animation: pulse 2s infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

/* No Trips Message */
.no-trips-message {
  margin: 20px;
  padding: 40px 20px;
  text-align: center;
  background: #1e293b;
  border-radius: 12px;
  border: 2px dashed #334155;
}

.no-trips-icon {
  font-size: 64px;
  margin-bottom: 16px;
  opacity: 0.5;
}

.no-trips-message h3 {
  margin: 0 0 8px 0;
  font-size: 18px;
  color: #f1f5f9;
}

.no-trips-message p {
  margin: 0;
  font-size: 14px;
  color: #64748b;
}

/* Route Info Card */
.route-info-card {
  margin: 12px;
  background: #1e293b;
  border-radius: 12px;
  overflow: hidden;
  transition: all 0.3s ease;
}

.route-info-card.expanded {
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
}

.route-header {
  display: flex;
  align-items: center;
  cursor: pointer;
  transition: background 0.2s;
}

.route-header:hover {
  background: rgba(255, 255, 255, 0.02);
}

.route-color-bar {
  width: 6px;
  min-height: 60px;
}

.route-details {
  flex: 1;
  padding: 12px 16px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.route-main-info {
  flex: 1;
}

.route-details h3 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
}

.route-id {
  font-size: 13px;
  font-weight: 500;
  color: #94a3b8;
  opacity: 0.8;
}

.route-id-small {
  font-size: 11px;
  font-weight: 500;
  color: #64748b;
  opacity: 0.7;
}

.route-time {
  margin: 4px 0 0;
  font-size: 13px;
  color: #94a3b8;
  font-weight: 500;
}

.route-status-badge {
  padding: 4px 12px;
  border-radius: 20px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.status-active {
  background: rgba(34, 197, 94, 0.15);
  color: #22c55e;
}

.status-upcoming {
  background: rgba(59, 130, 246, 0.15);
  color: #3b82f6;
}

.status-pending {
  background: rgba(251, 191, 36, 0.15);
  color: #fbbf24;
}

.status-completed {
  background: rgba(100, 116, 139, 0.15);
  color: #64748b;
}

.status-past {
  background: rgba(239, 68, 68, 0.15);
  color: #ef4444;
}

.expand-icon {
  padding: 0 16px;
  font-size: 12px;
  color: #64748b;
  transition: transform 0.3s;
}

.expand-icon.rotated {
  transform: rotate(180deg);
}

/* Trips Timeline */
.trips-timeline {
  border-top: 1px solid #334155;
  padding: 16px;
  background: rgba(15, 23, 42, 0.5);
}

.timeline-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
  font-size: 13px;
  color: #94a3b8;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.trip-count {
  font-size: 11px;
  padding: 4px 10px;
  background: rgba(102, 126, 234, 0.15);
  color: #667eea;
  border-radius: 12px;
}

.timeline-items {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.timeline-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  background: #1e293b;
  border: 2px solid transparent;
  border-radius: 10px;
  cursor: pointer;
  transition: all 0.2s;
}

.timeline-item:hover:not(.is-completed) {
  background: #334155;
  border-color: rgba(102, 126, 234, 0.3);
}

.timeline-item.is-current {
  border-color: #667eea;
  background: rgba(102, 126, 234, 0.1);
}

.timeline-item.is-active {
  border-color: #22c55e;
  background: rgba(34, 197, 94, 0.1);
}

.timeline-item.is-completed {
  opacity: 0.5;
  cursor: default;
}

.timeline-dot {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  flex-shrink: 0;
}

.timeline-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.timeline-main {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.timeline-route-name {
  font-weight: 600;
  font-size: 14px;
}

.timeline-time {
  font-size: 13px;
  color: #94a3b8;
  font-weight: 500;
}

.timeline-status {
  display: flex;
  align-items: center;
}

.status-indicator {
  font-size: 10px;
  padding: 2px 8px;
  border-radius: 10px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

/* Slide Down Animation */
.slide-down-enter-active,
.slide-down-leave-active {
  transition: all 0.3s ease;
  max-height: 500px;
}

.slide-down-enter-from,
.slide-down-leave-to {
  max-height: 0;
  opacity: 0;
  padding-top: 0;
  padding-bottom: 0;
}

/* Map Container */
.map-container {
  flex: 1;
  position: relative;
  min-height: 250px;
}

.driver-map {
  width: 100%;
  height: 100%;
  min-height: 250px;
}

.gps-accuracy {
  position: absolute;
  top: 12px;
  left: 12px;
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 12px;
  background: rgba(15, 23, 42, 0.9);
  border-radius: 20px;
  font-size: 12px;
  color: #94a3b8;
  z-index: 1000;
}

/* Shift Controls */
.shift-controls {
  padding: 16px;
  background: #1e293b;
  border-top: 1px solid #334155;
}

.shift-start {
  text-align: center;
}

.btn-start-shift {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  width: 100%;
  padding: 20px;
  font-size: 18px;
  font-weight: 600;
  color: white;
  background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
  border: none;
  border-radius: 12px;
  cursor: pointer;
  transition: all 0.3s;
}

.btn-start-shift:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(34, 197, 94, 0.4);
}

.btn-start-shift:disabled {
  background: #334155;
  cursor: not-allowed;
}

.shift-hint {
  margin-top: 12px;
  font-size: 12px;
  color: #64748b;
}

/* Shift Running */
.shift-stats {
  display: flex;
  justify-content: space-around;
  margin-bottom: 16px;
}

.stat {
  text-align: center;
}

.stat-value {
  display: block;
  font-size: 24px;
  font-weight: 700;
  color: #22c55e;
}

.stat-label {
  font-size: 11px;
  color: #64748b;
  text-transform: uppercase;
}

.progress-section {
  margin-bottom: 16px;
}

.progress-label {
  display: flex;
  justify-content: space-between;
  font-size: 12px;
  color: #94a3b8;
  margin-bottom: 8px;
}

.progress-bar {
  height: 8px;
  background: #334155;
  border-radius: 4px;
  overflow: hidden;
}

.progress-fill {
  height: 100%;
  border-radius: 4px;
  transition: width 0.5s ease;
}

.btn-end-shift {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  width: 100%;
  padding: 16px;
  font-size: 16px;
  font-weight: 600;
  color: white;
  background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
  border: none;
  border-radius: 12px;
  cursor: pointer;
  transition: all 0.3s;
}

.btn-end-shift:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(239, 68, 68, 0.4);
}

/* Driver Marker Styles (for Leaflet) */
:deep(.driver-marker) {
  background: transparent;
  border: none;
}

:deep(.driver-marker-inner) {
  position: relative;
  width: 50px;
  height: 50px;
}

:deep(.driver-marker-pulse) {
  position: absolute;
  width: 50px;
  height: 50px;
  border-radius: 50%;
  background: rgba(34, 197, 94, 0.3);
  animation: markerPulse 2s infinite;
}

@keyframes markerPulse {
  0% { transform: scale(0.8); opacity: 1; }
  100% { transform: scale(1.5); opacity: 0; }
}

:deep(.driver-marker-icon) {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 36px;
  height: 36px;
  background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.3);
  border: 3px solid white;
}

/* Shift Active State */
.shift-active .app-header {
  background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
}

.shift-active .connection-status.connected {
  background: rgba(255, 255, 255, 0.1);
  color: white;
}
</style>
