<template>
  <div class="passenger-app">
    <!-- Header -->
    <header class="app-header">
      <div class="header-left">
        <span class="logo">🚌</span>
        <h1>BucaraBus</h1>
        <div class="connection-indicator" :class="{ connected: isConnected }">
          <span class="status-dot"></span>
        </div>
      </div>
      <button @click="centerOnUser" class="btn-locate" :disabled="!userLocation">
        📍
      </button>
    </header>

    <!-- Destination Search -->
    <div class="destination-search">
      <div class="search-input-wrapper">
        <span class="search-icon">📍</span>
        <input 
          v-model="searchQuery"
          @input="searchDestination"
          @focus="showSearchResults = searchResults.length > 0"
          type="text" 
          placeholder="¿A dónde vas?"
          class="search-input"
        />
        <button 
          v-if="selectedDestination"
          @click="clearDestination"
          class="btn-clear-dest"
          title="Limpiar destino"
        >
          ✕
        </button>
      </div>
      
      <!-- Search Results Dropdown -->
      <div v-if="showSearchResults && searchResults.length > 0" class="search-results-dropdown">
        <div 
          v-for="(result, idx) in searchResults.slice(0, 5)" 
          :key="idx"
          class="search-result-item"
          @click="selectDestination(result)"
        >
          <span class="result-icon">📍</span>
          <div class="result-info">
            <div class="result-name">{{ result.name }}</div>
            <div class="result-address" v-if="result.address">{{ result.address }}</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Map Container -->
    <div class="map-container">
      <div ref="mapRef" class="map"></div>
      
      <!-- Loading Overlay -->
      <div v-if="isLoading" class="loading-overlay">
        <div class="spinner"></div>
        <p>Cargando buses...</p>
      </div>
    </div>

    <!-- Bottom Panel Container -->
    <div class="bottom-panel-container" :class="{ 'panel-is-hidden': panelHidden, expanded: panelExpanded }">
      <!-- Handle siempre visible -->
      <div class="panel-handle" @click="togglePanel">
        <div class="handle-arrow" :class="{ hidden: panelHidden }">
          {{ panelHidden ? '▲' : '▼' }}
        </div>
        <div class="handle-bar"></div>
      </div>

      <!-- Panel content -->
      <div v-show="!panelHidden" class="bottom-panel-content">
      <!-- Bus Selected Info -->
      <div v-if="selectedBus" class="selected-bus-info">
        <div class="bus-header">
          <div 
            class="bus-icon-large"
            :style="{ background: selectedBus.routeColor }"
          >
            🚌
          </div>
          <div class="bus-details">
            <h3>{{ selectedBus.plate }}</h3>
            <p class="route-name" :style="{ color: selectedBus.routeColor }">
              {{ selectedBus.routeName }}
            </p>
          </div>
          <button @click="selectedBus = null" class="btn-close">✕</button>
        </div>
        
        <div class="bus-stats">
          <div class="stat">
            <span class="stat-icon">🚗</span>
            <span class="stat-value">{{ Math.round(selectedBus.speed || 0) }} km/h</span>
            <span class="stat-label">Velocidad</span>
          </div>
          <div class="stat">
            <span class="stat-icon">📍</span>
            <span class="stat-value">{{ selectedBus.distance || '---' }}</span>
            <span class="stat-label">Distancia</span>
          </div>
          <div class="stat">
            <span class="stat-icon">⏱️</span>
            <span class="stat-value">{{ selectedBus.eta || '---' }}</span>
            <span class="stat-label">Llegada</span>
          </div>
        </div>
      </div>

      <!-- Suggested Routes (when destination is selected) -->
      <div v-else-if="selectedDestination && suggestedRoutes.length > 0" class="suggested-routes">
        <div class="suggested-routes-header">
          <h3>
            <span>🎯</span> Rutas sugeridas para tu destino
          </h3>
        </div>
        
        <div class="routes-suggestions-list">
          <div 
            v-for="suggestion in suggestedRoutes" 
            :key="suggestion.route.id"
            class="route-suggestion-item"
            :class="{ active: selectedSuggestedRoute?.route.id === suggestion.route.id }"
            @click="showRouteOnMap(suggestion)"
          >
            <div class="suggestion-rank" :style="{ background: suggestion.route.color }">
              #{{ suggestion.rank }}
            </div>
            <div class="suggestion-info">
              <div class="suggestion-route-name" :style="{ color: suggestion.route.color }">
                {{ suggestion.route.name }}
                <span v-if="suggestion.direction" class="route-direction">{{ suggestion.direction }}</span>
              </div>
              <div class="suggestion-details">
                <span class="detail-item">
                  🚶 {{ formatDistance(suggestion.walkToPickup) }} al paradero
                </span>
                <span class="detail-item">
                  🚌 {{ formatDistance(suggestion.busDistance) }} en bus
                </span>
                <span class="detail-item" v-if="suggestion.busesOnRoute > 0">
                  🚌 {{ suggestion.busesOnRoute }} bus{{ suggestion.busesOnRoute > 1 ? 'es' : '' }} activo{{ suggestion.busesOnRoute > 1 ? 's' : '' }}
                </span>
              </div>
            </div>
            <div class="suggestion-eta">
              <div class="eta-time">{{ suggestion.totalTime }}</div>
              <div class="eta-label">tiempo estimado</div>
            </div>
          </div>
        </div>
        
        <!-- Active Buses on Selected Route -->
        <div v-if="selectedSuggestedRoute && activeBusesOnSelectedRoute.length > 0" class="active-buses-section">
          <h4 class="active-buses-title">
            <span>🚌</span> Buses activos en esta ruta
          </h4>
          <div class="active-buses-list">
            <div 
              v-for="bus in activeBusesOnSelectedRoute" 
              :key="bus.busId"
              class="active-bus-card"
              @click="selectBusFromRoute(bus)"
            >
              <div class="bus-card-icon" :style="{ background: bus.routeColor }">
                🚌
              </div>
              <div class="bus-card-info">
                <div class="bus-card-plate">{{ bus.plate }}</div>
                <div class="bus-card-stats">
                  <span class="bus-stat">{{ Math.round(bus.speed || 0) }} km/h</span>
                  <span class="bus-stat-separator">•</span>
                  <span class="bus-stat">{{ bus.distanceToPickup }}</span>
                </div>
              </div>
              <div class="bus-card-eta">
                <div class="eta-badge">{{ bus.etaToPickup }}</div>
              </div>
            </div>
          </div>
        </div>
        
        <div v-else-if="selectedSuggestedRoute && activeBusesOnSelectedRoute.length === 0" class="no-active-buses">
          <p>⏸️ No hay buses activos en esta ruta en este momento</p>
        </div>
      </div>
      
      <!-- No routes found -->
      <div v-else-if="selectedDestination && suggestedRoutes.length === 0" class="no-routes-found">
        <h3>
          <span>😔</span> No encontramos rutas
        </h3>
        <p>No hay rutas disponibles que conecten tu ubicación con este destino.</p>
        <p class="hint">Intenta buscar otro destino más cercano.</p>
      </div>

      <!-- Nearby Stops -->
      <div v-else class="nearby-stops">
        <h3>
          <span>📍</span> 
          {{ userLocation ? 'Buses cercanos' : 'Activa tu ubicación' }}
        </h3>
        
        <div v-if="!userLocation" class="enable-location">
          <p>Para ver buses cercanos, activa tu ubicación</p>
          <button @click="requestLocation" class="btn-enable-location">
            Activar ubicación
          </button>
        </div>

        <div v-else-if="nearbyBuses.length === 0" class="no-buses">
          <p>No hay buses cercanos en este momento</p>
        </div>

        <div v-else class="buses-list">
          <div 
            v-for="bus in nearbyBuses" 
            :key="bus.id"
            class="bus-item"
            @click="selectBus(bus)"
          >
            <div 
              class="bus-color-indicator"
              :style="{ background: bus.routeColor }"
            ></div>
            <div class="bus-item-info">
              <span class="bus-plate">{{ bus.plate }}</span>
              <span class="bus-route">{{ bus.routeName }}</span>
            </div>
            <div class="bus-item-eta">
              <span class="eta-value">{{ bus.eta }}</span>
              <span class="eta-label">{{ bus.distance }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { io } from 'socket.io-client'
import L from 'leaflet'

// ============================================
// CONFIG
// ============================================
const getApiUrl = () => {
  const hostname = window.location.hostname
  if (hostname.includes('devtunnels.ms')) {
    return 'https://r7433m7d-3001.use.devtunnels.ms'
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

// ============================================
// STATE
// ============================================
const mapRef = ref(null)
const isLoading = ref(true)
const isConnected = ref(false)
const panelExpanded = ref(false)

// Routes
const routes = ref([])

// Buses
const activeBuses = ref({})
const selectedBus = ref(null)

// User location
const userLocation = ref(null)
const watchId = ref(null)

// WebSocket
const socket = ref(null)

// Panel visibility
const panelHidden = ref(false)

// Destination search
const searchQuery = ref('')
const searchResults = ref([])
const showSearchResults = ref(false)
const selectedDestination = ref(null)
const destMarker = ref(null)
let searchTimeout = null

// Route suggestions
const suggestedRoutes = ref([])
const selectedSuggestedRoute = ref(null)
const pickupMarker = ref(null)
const dropoffMarker = ref(null)

// Map objects
let leafletMap = null
let busMarkers = {}
let userMarker = null
let routePolylines = {}

// ============================================
// COMPUTED
// ============================================
const filteredBuses = computed(() => {
  return Object.values(activeBuses.value)
})

const nearbyBuses = computed(() => {
  if (!userLocation.value) return []
  
  return filteredBuses.value
    .map(bus => ({
      ...bus,
      distanceMeters: calculateDistance(
        userLocation.value.lat,
        userLocation.value.lng,
        bus.lat,
        bus.lng
      )
    }))
    .filter(bus => bus.distanceMeters < 5000) // Menos de 5km
    .sort((a, b) => a.distanceMeters - b.distanceMeters)
    .slice(0, 10)
    .map(bus => ({
      ...bus,
      distance: formatDistance(bus.distanceMeters),
      eta: calculateETA(bus.distanceMeters, bus.speed || 20)
    }))
})

const activeBusesOnSelectedRoute = computed(() => {
  if (!selectedSuggestedRoute.value || !userLocation.value) {
    console.log('🚫 No hay ruta seleccionada o ubicación de usuario')
    return []
  }
  
  const routeId = selectedSuggestedRoute.value.route.id
  const pickupPoint = selectedSuggestedRoute.value.pickupPoint
  
  console.log('🔍 Buscando buses activos para ruta:', {
    routeId,
    routeName: selectedSuggestedRoute.value.route.name,
    totalActiveBuses: Object.keys(activeBuses.value).length
  })
  
  // Mostrar todos los buses activos y sus routeIds
  Object.values(activeBuses.value).forEach(bus => {
    console.log(`  🚌 Bus ${bus.plate}: routeId=${bus.routeId} (tipo: ${typeof bus.routeId}), lat=${bus.lat}, lng=${bus.lng}`)
  })
  
  // Normalizar route ID (eliminar prefijo 'RUTA_' si existe)
  const normalizeRouteId = (id) => {
    const str = String(id)
    return Number(str.replace(/^RUTA_/i, ''))
  }
  
  const normalizedRouteId = normalizeRouteId(routeId)
  console.log(`🔧 Route ID normalizado: ${routeId} → ${normalizedRouteId}`)
  
  const filtered = Object.values(activeBuses.value)
    .filter(bus => {
      const normalizedBusRouteId = normalizeRouteId(bus.routeId)
      const match = normalizedBusRouteId === normalizedRouteId
      if (!match) {
        console.log(`  ❌ Bus ${bus.plate} no coincide: ${bus.routeId} (${normalizedBusRouteId}) !== ${routeId} (${normalizedRouteId})`)
      } else {
        console.log(`  ✅ Bus ${bus.plate} coincide!`)
      }
      return match
    })
  
  console.log(`✨ Buses filtrados: ${filtered.length}`)
  
  return filtered
    .map(bus => {
      const distanceToPickup = calculateDistance(
        bus.lat,
        bus.lng,
        pickupPoint.lat,
        pickupPoint.lng
      )
      
      console.log(`  📏 Bus ${bus.plate}: ${formatDistance(distanceToPickup)} al punto de abordaje`)
      
      return {
        ...bus,
        distanceToPickup: formatDistance(distanceToPickup),
        etaToPickup: calculateETA(distanceToPickup, bus.speed || 20)
      }
    })
    .sort((a, b) => {
      // Ordenar por distancia al punto de abordaje
      const distA = calculateDistance(a.lat, a.lng, pickupPoint.lat, pickupPoint.lng)
      const distB = calculateDistance(b.lat, b.lng, pickupPoint.lat, pickupPoint.lng)
      return distA - distB
    })
})

// ============================================
// HELPERS
// ============================================
const calculateDistance = (lat1, lon1, lat2, lon2) => {
  const R = 6371000 // Radio de la tierra en metros
  const dLat = (lat2 - lat1) * Math.PI / 180
  const dLon = (lon2 - lon1) * Math.PI / 180
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon/2) * Math.sin(dLon/2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
  return R * c
}

const formatDistance = (meters) => {
  if (meters < 1000) return `${Math.round(meters)} m`
  return `${(meters / 1000).toFixed(1)} km`
}

const calculateETA = (meters, speedKmh) => {
  if (!speedKmh || speedKmh < 5) speedKmh = 20 // Velocidad promedio
  const hours = meters / 1000 / speedKmh
  const minutes = Math.round(hours * 60)
  if (minutes < 1) return '< 1 min'
  if (minutes === 1) return '1 min'
  return `${minutes} min`
}

// ============================================
// ROUTE FINDING ALGORITHM
// ============================================
const findClosestPointOnRoute = (point, routePath) => {
  let minDistance = Infinity
  let closestPoint = null
  let closestIndex = 0
  let fraction = 0
  
  for (let i = 0; i < routePath.length - 1; i++) {
    const segmentStart = routePath[i]
    const segmentEnd = routePath[i + 1]
    
    // Proyectar punto en el segmento
    const projection = projectPointOnSegment(point, segmentStart, segmentEnd)
    const distance = calculateDistance(point.lat, point.lng, projection.lat, projection.lng)
    
    if (distance < minDistance) {
      minDistance = distance
      closestPoint = projection
      closestIndex = i
      
      // Calcular fracción en la ruta (0-1)
      const segmentLength = calculateDistance(segmentStart[0], segmentStart[1], segmentEnd[0], segmentEnd[1])
      const pointToStartLength = calculateDistance(segmentStart[0], segmentStart[1], projection.lat, projection.lng)
      
      // Calcular fracción total considerando todos los segmentos anteriores
      let totalLength = 0
      for (let j = 0; j < routePath.length - 1; j++) {
        totalLength += calculateDistance(routePath[j][0], routePath[j][1], routePath[j + 1][0], routePath[j + 1][1])
      }
      
      let lengthToPoint = 0
      for (let j = 0; j < i; j++) {
        lengthToPoint += calculateDistance(routePath[j][0], routePath[j][1], routePath[j + 1][0], routePath[j + 1][1])
      }
      lengthToPoint += pointToStartLength
      
      fraction = lengthToPoint / totalLength
    }
  }
  
  return { point: closestPoint, distance: minDistance, index: closestIndex, fraction }
}

const projectPointOnSegment = (point, segmentStart, segmentEnd) => {
  const [lat1, lng1] = segmentStart
  const [lat2, lng2] = segmentEnd
  
  const A = point.lat - lat1
  const B = point.lng - lng1
  const C = lat2 - lat1
  const D = lng2 - lng1
  
  const dot = A * C + B * D
  const lenSq = C * C + D * D
  let param = -1
  
  if (lenSq !== 0) param = dot / lenSq
  
  let projLat, projLng
  
  if (param < 0) {
    projLat = lat1
    projLng = lng1
  } else if (param > 1) {
    projLat = lat2
    projLng = lng2
  } else {
    projLat = lat1 + param * C
    projLng = lng1 + param * D
  }
  
  return { lat: projLat, lng: projLng }
}

const findBestRoutes = () => {
  if (!userLocation.value || !selectedDestination.value || routes.value.length === 0) {
    suggestedRoutes.value = []
    return
  }
  
  console.log('🔍 Buscando rutas...')
  console.log('📍 Usuario:', userLocation.value)
  console.log('🎯 Destino:', selectedDestination.value)
  console.log('🗺️ Rutas disponibles:', routes.value.length)
  
  const candidates = []
  const MAX_WALK_DISTANCE = 1500 // Aumentado a 1.5km
  
  routes.value.forEach(route => {
    if (!route.path || route.path.length < 2) {
      console.log(`⏭️ Ruta ${route.name}: Sin path o path muy corto`)
      return
    }
    
    // Evaluar ruta en AMBAS direcciones (ida y vuelta)
    for (let direction = 0; direction < 2; direction++) {
      const routePath = direction === 0 ? route.path : [...route.path].reverse()
      const directionLabel = direction === 0 ? 'IDA' : 'VUELTA'
      
      // Encontrar puntos más cercanos
      const pickupInfo = findClosestPointOnRoute(userLocation.value, routePath)
      const dropoffInfo = findClosestPointOnRoute(selectedDestination.value, routePath)
      
      console.log(`📊 Ruta ${route.name} (${directionLabel}):`, {
        pickupDistance: formatDistance(pickupInfo.distance),
        dropoffDistance: formatDistance(dropoffInfo.distance),
        pickupFraction: pickupInfo.fraction.toFixed(3),
        dropoffFraction: dropoffInfo.fraction.toFixed(3),
        orderOK: pickupInfo.fraction < dropoffInfo.fraction
      })
      
      // Validar que el orden sea correcto (pickup antes que dropoff)
      if (pickupInfo.fraction >= dropoffInfo.fraction) {
        console.log(`❌ Ruta ${route.name} (${directionLabel}): Orden incorrecto (pickup >= dropoff)`)
        continue
      }
      
      // Distancia máxima de caminata
      if (pickupInfo.distance > MAX_WALK_DISTANCE) {
        console.log(`❌ Ruta ${route.name} (${directionLabel}): Muy lejos del usuario (${formatDistance(pickupInfo.distance)})`)
        continue
      }
      
      if (dropoffInfo.distance > MAX_WALK_DISTANCE) {
        console.log(`❌ Ruta ${route.name} (${directionLabel}): Muy lejos del destino (${formatDistance(dropoffInfo.distance)})`)
        continue
      }
      
      // Calcular distancia en bus
      const busDistance = Math.abs(dropoffInfo.fraction - pickupInfo.fraction) * 
        routePath.reduce((sum, point, i) => {
          if (i === 0) return 0
          return sum + calculateDistance(routePath[i-1][0], routePath[i-1][1], point[0], point[1])
        }, 0)
      
      // Contar buses activos en esta ruta
      const normalizeRouteId = (id) => {
        const str = String(id)
        return Number(str.replace(/^RUTA_/i, ''))
      }
      const busesOnRoute = Object.values(activeBuses.value).filter(bus => 
        normalizeRouteId(bus.routeId) === normalizeRouteId(route.id)
      ).length
      
      // Scoring inteligente
      const walkToPickup = pickupInfo.distance
      const walkFromDropoff = dropoffInfo.distance
      const totalWalkDistance = walkToPickup + walkFromDropoff
      
      // Score: menor es mejor
      const score = (
        totalWalkDistance * 2.0 +        // Penalizar caminata (peso alto)
        busDistance * 0.3 -               // Penalizar un poco viajes largos
        (busesOnRoute * 1000)             // Bonus grande si hay buses
      )
      
      console.log(`✅ Ruta ${route.name} (${directionLabel}): Candidato válido (score: ${score.toFixed(0)})`)
      
      candidates.push({
        route,
        direction: directionLabel,
        pickupPoint: pickupInfo.point,
        dropoffPoint: dropoffInfo.point,
        walkToPickup,
        walkFromDropoff,
        totalWalkDistance,
        busDistance,
        busesOnRoute,
        score,
        totalTime: calculateETA(totalWalkDistance + busDistance, 20)
      })
    }
  })
  
  console.log(`🎯 Total candidatos: ${candidates.length}`)
  
  // Ordenar por score y tomar top 3
  suggestedRoutes.value = candidates
    .sort((a, b) => a.score - b.score)
    .slice(0, 3)
    .map((candidate, index) => ({
      ...candidate,
      rank: index + 1
    }))
  
  console.log('✨ Rutas sugeridas:', suggestedRoutes.value)
}

// ============================================
// MAP
// ============================================
const initMap = () => {
  if (!mapRef.value || leafletMap) return

  // Centrar en Bucaramanga
  leafletMap = L.map(mapRef.value, {
    zoomControl: false
  }).setView([7.1254, -73.1198], 13)

  L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', {
    attribution: '© OpenStreetMap'
  }).addTo(leafletMap)

  // Control de zoom en esquina
  L.control.zoom({ position: 'topright' }).addTo(leafletMap)
}

const updateBusMarker = (bus) => {
  const { busId, lat, lng, plate, routeColor, routeName, speed } = bus
  
  if (!lat || !lng) return

  if (busMarkers[busId]) {
    // Solo actualizar posición del marcador existente
    busMarkers[busId].setLatLng([lat, lng])
    
    // Actualizar popup con nueva info
    busMarkers[busId].setPopupContent(`
      <div style="text-align: center">
        <strong>${plate}</strong><br>
        <span style="color: ${routeColor}">${routeName}</span><br>
        <small>${speed ? Math.round(speed) + ' km/h' : 'En movimiento'}</small>
      </div>
    `)
  } else {
    // Crear nuevo marcador solo si no existe
    const busIcon = L.divIcon({
      className: 'bus-marker',
      html: `
        <div class="bus-marker-inner" style="background: ${routeColor || '#667eea'}">
          <span>🚌</span>
        </div>
      `,
      iconSize: [36, 36],
      iconAnchor: [18, 18]
    })

    busMarkers[busId] = L.marker([lat, lng], { icon: busIcon })
      .addTo(leafletMap)
      .bindPopup(`
        <div style="text-align: center">
          <strong>${plate}</strong><br>
          <span style="color: ${routeColor}">${routeName}</span><br>
          <small>${speed ? Math.round(speed) + ' km/h' : 'En movimiento'}</small>
        </div>
      `)
      .on('click', () => selectBus(bus))
  }
}

const removeBusMarker = (busId) => {
  if (busMarkers[busId]) {
    leafletMap.removeLayer(busMarkers[busId])
    delete busMarkers[busId]
  }
}

const updateUserMarker = () => {
  if (!userLocation.value || !leafletMap) return

  const userIcon = L.divIcon({
    className: 'user-marker',
    html: `<div class="user-marker-inner">📍</div>`,
    iconSize: [32, 32],
    iconAnchor: [16, 32]
  })

  if (userMarker) {
    userMarker.setLatLng([userLocation.value.lat, userLocation.value.lng])
  } else {
    userMarker = L.marker(
      [userLocation.value.lat, userLocation.value.lng],
      { icon: userIcon }
    ).addTo(leafletMap)
      .bindPopup('Tu ubicación')
  }
}

const centerOnUser = () => {
  if (userLocation.value && leafletMap) {
    leafletMap.setView([userLocation.value.lat, userLocation.value.lng], 15)
  }
}

const selectBus = (bus) => {
  selectedBus.value = {
    ...bus,
    distance: userLocation.value 
      ? formatDistance(calculateDistance(
          userLocation.value.lat,
          userLocation.value.lng,
          bus.lat,
          bus.lng
        ))
      : '---',
    eta: userLocation.value
      ? calculateETA(
          calculateDistance(
            userLocation.value.lat,
            userLocation.value.lng,
            bus.lat,
            bus.lng
          ),
          bus.speed
        )
      : '---'
  }
  panelExpanded.value = true
  panelHidden.value = false
  
  if (leafletMap && bus.lat && bus.lng) {
    leafletMap.setView([bus.lat, bus.lng], 16)
  }
}

const togglePanel = () => {
  if (panelHidden.value) {
    // Si está oculto, mostrarlo
    panelHidden.value = false
  } else {
    // Si está visible, ocultarlo completamente
    panelHidden.value = true
  }
}

const drawRoutePath = (route) => {
  if (!route.path || !leafletMap) return
  
  if (routePolylines[route.id]) {
    leafletMap.removeLayer(routePolylines[route.id])
  }

  // Las coordenadas vienen como [lat, lng] - Leaflet espera [lat, lng]
  // Verificamos el formato: si el primer valor es ~7 es lat, si es ~-73 es lng
  const coords = route.path.map(p => {
    if (Math.abs(p[0]) < 20) {
      // Formato [lat, lng] - correcto para Leaflet
      return [p[0], p[1]]
    } else {
      // Formato [lng, lat] - necesitamos invertir
      return [p[1], p[0]]
    }
  })
  
  console.log(`Dibujando ruta ${route.name}:`, coords)
  
  routePolylines[route.id] = L.polyline(coords, {
    color: route.color || '#667eea',
    weight: 4,
    opacity: 0.7
  }).addTo(leafletMap)
}

// ============================================
// LOCATION
// ============================================
const requestLocation = () => {
  if (!navigator.geolocation) {
    alert('Tu navegador no soporta geolocalización')
    return
  }

  navigator.geolocation.getCurrentPosition(
    (position) => {
      userLocation.value = {
        lat: position.coords.latitude,
        lng: position.coords.longitude
      }
      updateUserMarker()
      centerOnUser()
      startWatchingLocation()
    },
    (error) => {
      console.error('Error GPS:', error)
      alert('No pudimos obtener tu ubicación. Verifica los permisos.')
    },
    { enableHighAccuracy: true }
  )
}

const startWatchingLocation = () => {
  if (watchId.value) return

  watchId.value = navigator.geolocation.watchPosition(
    (position) => {
      userLocation.value = {
        lat: position.coords.latitude,
        lng: position.coords.longitude
      }
      updateUserMarker()
    },
    (error) => console.error('Error watching location:', error),
    { enableHighAccuracy: true, maximumAge: 5000 }
  )
}

// ============================================
// API & WEBSOCKET
// ============================================
const loadRoutes = async () => {
  try {
    const response = await fetch(`${API_URL}/api/routes`)
    const data = await response.json()
    
    if (data.success) {
      routes.value = data.data.map(r => ({
        id: r.id || r.id_route,
        name: r.name || r.name_route || `Ruta ${r.id || r.id_route}`,
        color: r.color || r.color_route || '#667eea',
        path: r.path || r.path_route?.coordinates || []
      }))

      console.log('Rutas cargadas:', routes.value)

      // Dibujar rutas en el mapa
      routes.value.forEach(route => {
        if (route.path && route.path.length > 0) {
          drawRoutePath(route)
        }
      })
    }
  } catch (error) {
    console.error('Error loading routes:', error)
  }
}

const loadActiveShifts = async () => {
  try {
    const response = await fetch(`${API_URL}/api/shifts`)
    const data = await response.json()
    
    if (data.success && data.data) {
      console.log('Turnos cargados:', data.data)
      
      // Inicializar buses activos desde turnos
      data.data.forEach(shift => {
        let lat = shift.current_lat
        let lng = shift.current_lng
        
        // Si no tiene GPS, usar coordenadas del path_geojson
        if (!lat || !lng) {
          try {
            if (shift.path_geojson) {
              const geojson = JSON.parse(shift.path_geojson)
              if (geojson.coordinates && geojson.coordinates.length > 0) {
                const firstPoint = geojson.coordinates[0]
                // GeoJSON es [lng, lat], necesitamos [lat, lng]
                lat = firstPoint[0]  
                lng = firstPoint[1]
                // Si lat es muy grande (como -73), están invertidos
                if (Math.abs(lat) > 20) {
                  lat = firstPoint[1]
                  lng = firstPoint[0]
                }
              }
            }
          } catch (e) {
            console.error('Error parsing path_geojson:', e)
          }
        }
        
        console.log(`Bus ${shift.plate_number}: lat=${lat}, lng=${lng}`)
        
        if (lat && lng) {
          activeBuses.value[shift.id_bus || shift.plate_number] = {
            busId: shift.id_bus || shift.plate_number,
            plate: shift.plate_number,
            driverId: shift.id_user,
            driverName: shift.name_driver,
            routeId: shift.id_route,
            routeName: shift.name_route || 'Ruta',
            routeColor: shift.color_route || '#667eea',
            lat: lat,
            lng: lng,
            speed: shift.current_speed || 0,
            lastUpdate: new Date(),
            hasGPS: !!(shift.current_lat && shift.current_lng)
          }
        }
      })

      // Actualizar marcadores
      Object.values(activeBuses.value).forEach(updateBusMarker)
    }
  } catch (error) {
    console.error('Error loading shifts:', error)
  } finally {
    isLoading.value = false
  }
}

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

  // Recibir actualizaciones de ubicación
  socket.value.on('bus-location-update', (data) => {
    const route = routes.value.find(r => r.id === data.routeId)
    
    const busData = {
      busId: data.busId,
      plate: data.plate || activeBuses.value[data.busId]?.plate || 'Bus',
      driverId: data.driverId,
      routeId: data.routeId,
      routeName: route?.name || data.routeName || 'Ruta',
      routeColor: route?.color || data.routeColor || '#667eea',
      lat: data.latitude,
      lng: data.longitude,
      speed: data.speed || 0,
      lastUpdate: new Date()
    }

    activeBuses.value[data.busId] = busData
    updateBusMarker(busData)

    // Actualizar bus seleccionado si es el mismo
    if (selectedBus.value?.busId === data.busId) {
      selectBus(busData)
    }
  })

  // Turno terminado
  socket.value.on('shift-ended', (data) => {
    delete activeBuses.value[data.busId]
    removeBusMarker(data.busId)
    
    if (selectedBus.value?.busId === data.busId) {
      selectedBus.value = null
    }
  })
}

// ============================================
// DESTINATION SEARCH (NOMINATIM)
// ============================================
const searchDestination = async () => {
  if (!searchQuery.value || searchQuery.value.length < 2) {
    searchResults.value = []
    return
  }

  // Debounce: wait 500ms after user stops typing
  clearTimeout(searchTimeout)
  searchTimeout = setTimeout(async () => {
    try {
      const query = encodeURIComponent(searchQuery.value)
      const response = await fetch(
        `${API_URL}/api/geocoding/search?q=${query}`
      )
      
      if (!response.ok) throw new Error('Search request failed')
      
      const data = await response.json()
      
      if (data.success) {
        searchResults.value = data.data
        showSearchResults.value = true
        console.log('Search results:', searchResults.value)
      } else {
        searchResults.value = []
        console.error('Search error:', data.error)
      }
    } catch (error) {
      console.error('Error searching:', error)
      searchResults.value = []
    }
  }, 500)
}

const selectDestination = (destination) => {
  selectedDestination.value = destination
  searchQuery.value = destination.name
  showSearchResults.value = false
  
  // Remove old marker if exists
  if (destMarker.value) {
    leafletMap.removeLayer(destMarker.value)
  }
  
  // Add new destination marker
  const marker = L.marker([destination.lat, destination.lng], {
    icon: L.divIcon({
      className: 'dest-marker',
      html: `<div style="background: #ff6b6b; width: 30px; height: 30px; border-radius: 50%; display: flex; align-items: center; justify-content: center; color: white; font-weight: bold; border: 3px solid white; box-shadow: 0 2px 4px rgba(0,0,0,0.3);">📍</div>`,
      iconSize: [30, 30],
      iconAnchor: [15, 15],
      popupAnchor: [0, -15]
    })
  })
  
  marker.bindPopup(`<strong>Destino:</strong><br>${destination.name}`)
  marker.addTo(leafletMap)
  marker.openPopup()
  destMarker.value = marker
  
  // Center map on destination
  leafletMap.setView([destination.lat, destination.lng], 16)
  
  console.log('Destination selected:', destination)
  
  // Buscar mejores rutas
  findBestRoutes()
}

const showRouteOnMap = (suggestion) => {
  if (!leafletMap) return
  
  // Toggle: si es la misma ruta, ocultarla
  if (selectedSuggestedRoute.value?.route.id === suggestion.route.id) {
    console.log('🗺️ Ocultando ruta seleccionada')
    selectedSuggestedRoute.value = null
    
    // Limpiar marcadores
    if (pickupMarker.value) {
      leafletMap.removeLayer(pickupMarker.value)
      pickupMarker.value = null
    }
    if (dropoffMarker.value) {
      leafletMap.removeLayer(dropoffMarker.value)
      dropoffMarker.value = null
    }
    
    // Restaurar opacidad de rutas
    Object.values(routePolylines).forEach(polyline => {
      polyline.setStyle({ weight: 4, opacity: 0.7 })
    })
    
    return
  }
  
  console.log('🗺️ Mostrando ruta en mapa:', {
    routeId: suggestion.route.id,
    routeName: suggestion.route.name,
    direction: suggestion.direction
  })
  
  selectedSuggestedRoute.value = suggestion
  panelExpanded.value = true
  panelHidden.value = false
  
  // Limpiar marcadores anteriores
  if (pickupMarker.value) {
    leafletMap.removeLayer(pickupMarker.value)
  }
  if (dropoffMarker.value) {
    leafletMap.removeLayer(dropoffMarker.value)
  }
  
  // Marcador de punto de abordaje (verde)
  pickupMarker.value = L.marker(
    [suggestion.pickupPoint.lat, suggestion.pickupPoint.lng],
    {
      icon: L.divIcon({
        className: 'pickup-marker',
        html: `<div style="background: #10b981; width: 32px; height: 32px; border-radius: 50%; display: flex; align-items: center; justify-content: center; color: white; font-weight: bold; border: 3px solid white; box-shadow: 0 2px 4px rgba(0,0,0,0.3); font-size: 18px;">🚏</div>`,
        iconSize: [32, 32],
        iconAnchor: [16, 16]
      })
    }
  ).addTo(leafletMap)
    .bindPopup(`<strong>Punto de abordaje</strong><br>${formatDistance(suggestion.walkToPickup)} de distancia`)
  
  // Marcador de punto de bajada (azul)
  dropoffMarker.value = L.marker(
    [suggestion.dropoffPoint.lat, suggestion.dropoffPoint.lng],
    {
      icon: L.divIcon({
        className: 'dropoff-marker',
        html: `<div style="background: #3b82f6; width: 32px; height: 32px; border-radius: 50%; display: flex; align-items: center; justify-content: center; color: white; font-weight: bold; border: 3px solid white; box-shadow: 0 2px 4px rgba(0,0,0,0.3); font-size: 18px;">⬇️</div>`,
        iconSize: [32, 32],
        iconAnchor: [16, 16]
      })
    }
  ).addTo(leafletMap)
    .bindPopup(`<strong>Punto de bajada</strong><br>${formatDistance(suggestion.walkFromDropoff)} de distancia`)
  
  // Resaltar la ruta
  Object.keys(routePolylines).forEach(routeId => {
    const polyline = routePolylines[routeId]
    if (Number(routeId) === Number(suggestion.route.id)) {
      polyline.setStyle({ weight: 6, opacity: 1 })
      polyline.bringToFront()
    } else {
      polyline.setStyle({ weight: 4, opacity: 0.3 })
    }
  })
  
  // Ajustar vista del mapa
  const bounds = L.latLngBounds([
    [userLocation.value.lat, userLocation.value.lng],
    [suggestion.pickupPoint.lat, suggestion.pickupPoint.lng],
    [suggestion.dropoffPoint.lat, suggestion.dropoffPoint.lng],
    [selectedDestination.value.lat, selectedDestination.value.lng]
  ])
  leafletMap.fitBounds(bounds, { padding: [50, 50] })
}

const selectBusFromRoute = (bus) => {
  selectedBus.value = {
    ...bus,
    distance: userLocation.value 
      ? formatDistance(calculateDistance(
          userLocation.value.lat,
          userLocation.value.lng,
          bus.lat,
          bus.lng
        ))
      : '---',
    eta: userLocation.value
      ? calculateETA(
          calculateDistance(
            userLocation.value.lat,
            userLocation.value.lng,
            bus.lat,
            bus.lng
          ),
          bus.speed
        )
      : '---'
  }
  
  if (leafletMap && bus.lat && bus.lng) {
    leafletMap.setView([bus.lat, bus.lng], 16)
  }
}

const clearDestination = () => {
  searchQuery.value = ''
  selectedDestination.value = null
  searchResults.value = []
  showSearchResults.value = false
  suggestedRoutes.value = []
  selectedSuggestedRoute.value = null
  panelHidden.value = false
  
  if (destMarker.value) {
    leafletMap.removeLayer(destMarker.value)
    destMarker.value = null
  }
  
  if (pickupMarker.value) {
    leafletMap.removeLayer(pickupMarker.value)
    pickupMarker.value = null
  }
  
  if (dropoffMarker.value) {
    leafletMap.removeLayer(dropoffMarker.value)
    dropoffMarker.value = null
  }
  
  // Restaurar opacidad de rutas
  Object.values(routePolylines).forEach(polyline => {
    polyline.setStyle({ weight: 4, opacity: 0.7 })
  })
}

// ============================================
// WATCHERS
// ============================================
// Recalcular rutas sugeridas cuando cambia ubicación o hay nuevos buses
watch([userLocation, activeBuses, routes], () => {
  if (selectedDestination.value) {
    findBestRoutes()
  }
}, { deep: true })

// ============================================
// LIFECYCLE
// ============================================
onMounted(async () => {
  initMap()
  await loadRoutes()
  await loadActiveShifts()
  connectWebSocket()
  requestLocation()
})

onUnmounted(() => {
  if (socket.value) {
    socket.value.disconnect()
  }
  if (watchId.value) {
    navigator.geolocation.clearWatch(watchId.value)
  }
  if (leafletMap) {
    leafletMap.remove()
    leafletMap = null
  }
})
</script>

<style scoped>
/* ============================================
   GENERAL
   ============================================ */
.passenger-app {
  height: 100vh;
  height: 100dvh;
  display: flex;
  flex-direction: column;
  background: #f5f7fa;
  position: relative;
  overflow: hidden;
}

/* ============================================
   HEADER
   ============================================ */
.app-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  z-index: 1000;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 10px;
}

.logo {
  font-size: 1.5rem;
}

.app-header h1 {
  font-size: 1.2rem;
  font-weight: 600;
  margin: 0;
}

.connection-indicator {
  display: flex;
  align-items: center;
  margin-left: 8px;
}

.connection-indicator .status-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: #f44336;
}

.connection-indicator.connected .status-dot {
  background: #4caf50;
  animation: pulse 2s infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

.btn-locate {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  border: none;
  background: rgba(255,255,255,0.2);
  color: white;
  font-size: 1.2rem;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
}

.btn-locate:disabled {
  opacity: 0.5;
}

/* ============================================
   MAP
   ============================================ */
.map-container {
  flex: 1;
  position: relative;
}

.map {
  width: 100%;
  height: 100%;
}

.loading-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(255,255,255,0.9);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  z-index: 500;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 3px solid #e0e0e0;
  border-top-color: #667eea;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* ============================================
   BOTTOM PANEL
   ============================================ */
/* Bottom panel container - envuelve handle + contenido */
.bottom-panel-container {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  z-index: 1000;
  display: flex;
  flex-direction: column;
  align-items: center;
  max-height: 45%;
  transition: all 0.3s ease;
  pointer-events: none;
}

.bottom-panel-container.expanded {
  max-height: 65%;
}

.bottom-panel-container.panel-is-hidden {
  max-height: none;
  justify-content: flex-end;
  padding-bottom: 16px;
}

/* Handle - siempre visible */
.panel-handle {
  pointer-events: auto;
  padding: 8px 24px;
  background: white;
  border-radius: 20px 20px 0 0;
  box-shadow: 0 -4px 12px rgba(0,0,0,0.1);
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  cursor: pointer;
  transition: all 0.3s ease;
  flex-shrink: 0;
  gap: 4px;
}

.panel-is-hidden .panel-handle {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 16px;
  box-shadow: 0 4px 16px rgba(102, 126, 234, 0.5);
  padding: 10px 28px;
}

.panel-handle:hover {
  transform: scale(1.05);
}

.handle-bar {
  width: 36px;
  height: 4px;
  border-radius: 2px;
  background: #ccc;
}

.panel-is-hidden .handle-bar {
  background: rgba(255, 255, 255, 0.4);
}

.handle-arrow {
  font-size: 0.75rem;
  color: #667eea;
  font-weight: bold;
  line-height: 1;
  transition: all 0.3s ease;
  user-select: none;
}

.handle-arrow.hidden {
  font-size: 0.85rem;
  color: white;
  text-shadow: 0 1px 3px rgba(0,0,0,0.2);
}

.panel-handle:hover .handle-arrow {
  transform: scale(1.2);
}

@keyframes bounce {
  0%, 100% {
    transform: translateY(0);
  }
  50% {
    transform: translateY(-6px);
  }
}

/* Panel content */
.bottom-panel-content {
  pointer-events: auto;
  background: white;
  width: 100%;
  overflow-y: auto;
  box-shadow: 0 -4px 20px rgba(0,0,0,0.1);
  flex: 1;
  min-height: 0;
}

/* Selected Bus Info */
.selected-bus-info {
  padding: 0 16px 16px;
}

.bus-header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 16px;
}

.bus-icon-large {
  width: 50px;
  height: 50px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.5rem;
}

.bus-details {
  flex: 1;
}

.bus-details h3 {
  margin: 0;
  font-size: 1.1rem;
}

.route-name {
  margin: 4px 0 0;
  font-weight: 500;
}

.btn-close {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  border: none;
  background: #f0f0f0;
  cursor: pointer;
  font-size: 1rem;
}

.bus-stats {
  display: flex;
  gap: 12px;
}

.stat {
  flex: 1;
  background: #f8f9fa;
  padding: 12px;
  border-radius: 12px;
  text-align: center;
}

.stat-icon {
  font-size: 1.2rem;
  display: block;
  margin-bottom: 4px;
}

.stat-value {
  font-size: 1.1rem;
  font-weight: 600;
  display: block;
}

.stat-label {
  font-size: 0.75rem;
  color: #666;
}

/* Nearby Stops */
.nearby-stops {
  padding: 0 16px 16px;
}

.nearby-stops h3 {
  margin: 0 0 12px;
  font-size: 1rem;
  display: flex;
  align-items: center;
  gap: 8px;
}

.enable-location {
  text-align: center;
  padding: 20px;
}

.enable-location p {
  color: #666;
  margin-bottom: 12px;
}

.btn-enable-location {
  padding: 12px 24px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border: none;
  border-radius: 25px;
  font-size: 1rem;
  cursor: pointer;
}

.no-buses {
  text-align: center;
  padding: 20px;
  color: #666;
}

.buses-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  max-height: 200px;
  overflow-y: auto;
}

.bus-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  background: #f8f9fa;
  border-radius: 12px;
  cursor: pointer;
  transition: background 0.2s;
}

.bus-item:hover {
  background: #f0f0f0;
}

.bus-color-indicator {
  width: 4px;
  height: 40px;
  border-radius: 2px;
}

.bus-item-info {
  flex: 1;
}

.bus-plate {
  font-weight: 600;
  display: block;
}

.bus-route {
  font-size: 0.85rem;
  color: #666;
}

.bus-item-eta {
  text-align: right;
}

.eta-value {
  font-weight: 600;
  color: #667eea;
  display: block;
}

.eta-label {
  font-size: 0.75rem;
  color: #999;
}

/* ============================================
   BUS MARKERS (Global styles needed)
   ============================================ */
:deep(.bus-marker) {
  background: transparent !important;
  border: none !important;
}

:deep(.bus-marker-inner) {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.2rem;
  box-shadow: 0 2px 8px rgba(0,0,0,0.3);
  border: 2px solid white;
}

:deep(.user-marker) {
  background: transparent !important;
  border: none !important;
}

:deep(.user-marker-inner) {
  font-size: 2rem;
  filter: drop-shadow(0 2px 4px rgba(0,0,0,0.3));
}

/* ============================================
   DESTINATION SEARCH BAR
   ============================================ */
.destination-search {
  position: absolute;
  top: 85px;
  left: 12px;
  right: 70px;
  z-index: 800;
}

.search-input-wrapper {
  display: flex;
  align-items: center;
  background: white;
  border-radius: 25px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  overflow: hidden;
  
}

.search-icon {
  padding: 8px;
  font-size: 1.2rem;
}

.search-input {
  flex: 1;
  border: none;
  outline: none;
  padding: 8px 4px;
  font-size: 16px;
  background: transparent;
}

.search-input::placeholder {
  color: #999;
}

.btn-clear-dest {
  background: none;
  border: none;
  color: #999;
  font-size: 1.2rem;
  cursor: pointer;
  padding: 8px 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 32px;
  height: 32px;
  flex-shrink: 0;
}

.btn-clear-dest:hover {
  color: #333;
}

.search-results-dropdown {
  background: white;
  border-radius: 12px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  margin-top: 8px;
  overflow: hidden;
  max-height: 250px;
  overflow-y: auto;
}

.search-result-item {
  padding: 12px;
  border-bottom: 1px solid #f0f0f0;
  cursor: pointer;
  transition: background 0.2s;
  display: flex;
  align-items: center;
  gap: 12px;
}

.search-result-item:last-child {
  border-bottom: none;
}

.search-result-item:hover {
  background: #f8f9fa;
}

.search-result-icon {
  font-size: 1.2rem;
}

.search-result-text {
  flex: 1;
}

.search-result-name {
  font-weight: 500;
  color: #333;
}

.search-result-address {
  font-size: 0.8rem;
  color: #999;
  margin-top: 2px;
}

/* ============================================
   SUGGESTED ROUTES
   ============================================ */
.suggested-routes {
  padding: 0 16px 16px;
}

.suggested-routes-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
  gap: 12px;
}

.suggested-routes h3 {
  margin: 0;
  font-size: 1rem;
  display: flex;
  align-items: center;
  gap: 8px;
  flex: 1;
}

.btn-toggle-panel {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  border: none;
  background: #667eea;
  color: white;
  font-size: 1rem;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
  flex-shrink: 0;
}

.btn-toggle-panel:hover {
  background: #5568d3;
  transform: scale(1.1);
}

.btn-toggle-panel:active {
  transform: scale(0.95);
}

.btn-hide-panel {
  background: #ff6b6b;
}

.btn-hide-panel:hover {
  background: #ee5a5a;
}

.routes-suggestions-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
  max-height: 300px;
  overflow-y: auto;
}

.route-suggestion-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px;
  background: #f8f9fa;
  border-radius: 12px;
  cursor: pointer;
  transition: all 0.2s;
  border: 2px solid transparent;
}

.route-suggestion-item:hover {
  background: #f0f0f0;
  transform: translateY(-2px);
  box-shadow: 0 4px 8px rgba(0,0,0,0.1);
}

.route-suggestion-item.active {
  border-color: #667eea;
  background: #f0f4ff;
}

.suggestion-rank {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-weight: 700;
  font-size: 0.9rem;
  flex-shrink: 0;
}

.suggestion-info {
  flex: 1;
}

.suggestion-route-name {
  font-weight: 600;
  font-size: 0.95rem;
  margin-bottom: 4px;
  display: flex;
  align-items: center;
  gap: 6px;
}

.route-direction {
  font-size: 0.7rem;
  font-weight: 500;
  background: rgba(0, 0, 0, 0.1);
  padding: 2px 6px;
  border-radius: 4px;
  text-transform: uppercase;
}

.suggestion-details {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.detail-item {
  font-size: 0.75rem;
  color: #666;
}

.suggestion-eta {
  text-align: right;
  flex-shrink: 0;
}

.eta-time {
  font-weight: 600;
  color: #667eea;
  font-size: 1rem;
}

.eta-label {
  font-size: 0.65rem;
  color: #999;
  text-transform: uppercase;
}

.no-routes-found {
  padding: 20px 16px;
  text-align: center;
}

.no-routes-found h3 {
  margin: 0 0 12px;
  font-size: 1rem;
  display: flex;
  align-items: center;
  gap: 8px;
  justify-content: center;
}

.no-routes-found p {
  color: #666;
  margin: 8px 0;
  font-size: 0.9rem;
}

.no-routes-found .hint {
  font-size: 0.85rem;
  color: #999;
  font-style: italic;
}

/* ============================================
   ACTIVE BUSES ON ROUTE
   ============================================ */
.active-buses-section {
  margin-top: 16px;
  padding-top: 16px;
  border-top: 1px solid #e0e0e0;
}

.active-buses-title {
  margin: 0 0 12px;
  font-size: 0.9rem;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 6px;
  color: #333;
}

.active-buses-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.active-bus-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px;
  background: white;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
}

.active-bus-card:hover {
  background: #f8f9fa;
  border-color: #667eea;
  transform: translateX(2px);
}

.bus-card-icon {
  width: 36px;
  height: 36px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.2rem;
  flex-shrink: 0;
}

.bus-card-info {
  flex: 1;
}

.bus-card-plate {
  font-weight: 600;
  font-size: 0.9rem;
  color: #333;
}

.bus-card-stats {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 2px;
}

.bus-stat {
  font-size: 0.75rem;
  color: #666;
}

.bus-stat-separator {
  font-size: 0.7rem;
  color: #ccc;
}

.bus-card-eta {
  flex-shrink: 0;
}

.eta-badge {
  background: #667eea;
  color: white;
  padding: 4px 10px;
  border-radius: 12px;
  font-size: 0.75rem;
  font-weight: 600;
}

.no-active-buses {
  margin-top: 12px;
  padding: 12px;
  background: #f8f9fa;
  border-radius: 8px;
  text-align: center;
}

.no-active-buses p {
  margin: 0;
  font-size: 0.85rem;
  color: #666;
}

/* ============================================
   RESPONSIVE
   ============================================ */
@media (min-width: 768px) {
  .passenger-app {
    max-width: 500px;
    margin: 0 auto;
    box-shadow: 0 0 30px rgba(0,0,0,0.1);
  }
}
</style>
