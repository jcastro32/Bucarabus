<template>
  <div class="map-wrapper">
    <div id="map" class="leaflet-map"></div>

    <!-- Map Controls -->
    <div class="map-controls">
      <button id="fullscreen-map" class="map-control-btn" @click="toggleFullscreen" title="Pantalla completa">
        ⛶
      </button>
      <button id="center-map" class="map-control-btn" @click="centerMap" title="Centrar mapa">
        🎯
      </button>
      <button id="layers-control" class="map-control-btn" @click="toggleLayers" title="Capas">
        🗂️
      </button>
    </div>

    <!-- Active Buses Widget -->
    <div id="active-buses-widget" class="floating-widget">
      <div class="widget-header">
        <span class="widget-title">🚌 Buses en Vivo</span>
        <div class="widget-header-right">
          <!-- Indicador de conexión WebSocket -->
          <span 
            class="ws-indicator" 
            :class="{ connected: isConnected }"
            :title="isConnected ? 'GPS Conectado' : 'GPS Desconectado'"
          >
            {{ isConnected ? '🛰️' : '📡' }}
          </span>
          <button class="widget-toggle" @click="toggleWidget">−</button>
        </div>
      </div>
      <div class="widget-content" :class="{ collapsed: widgetCollapsed }">
        <!-- GPS en tiempo real -->
        <div v-if="busLocationsArray && busLocationsArray.length > 0" class="gps-buses-section">
          <div class="section-label">
            <span class="pulse-dot"></span>
            GPS en tiempo real ({{ busLocationsArray.length }})
          </div>
          <div class="gps-bus-list">
            <div 
              v-for="bus in busLocationsArray" 
              :key="bus.busId" 
              class="gps-bus-item"
            >
              <div class="gps-bus-info">
                <span class="gps-bus-id">🚌 Bus #{{ bus.busId }}</span>
                <span class="gps-speed">{{ Math.round(bus.speed) }} km/h</span>
              </div>
              <div class="gps-coords">
                📍 {{ bus.lat.toFixed(4) }}, {{ bus.lng.toFixed(4) }}
              </div>
            </div>
          </div>
        </div>
        
        <!-- Leyenda de rutas -->
        <div v-if="activeRoutesLegend.length > 0" class="routes-legend">
          <div 
            v-for="route in activeRoutesLegend" 
            :key="route.id"
            class="legend-item"
          >
            <div 
              class="legend-color" 
              :style="{ background: route.color }"
            ></div>
            <span class="legend-name">{{ route.name }}</span>
            <span class="legend-count">{{ route.busCount }}</span>
          </div>
        </div>
        <div id="live-buses-list">
          <div v-for="bus in activeBusesWithRoutes" :key="bus.id_bus" class="live-bus-item">
            <div class="bus-info">
              <div class="bus-plate-with-color">
                <div 
                  class="bus-color-indicator" 
                  :style="{ background: getRouteColor(bus.ruta_actual) }"
                ></div>
                <span class="bus-plate">{{ bus.placa }}</span>
              </div>
              <span class="bus-status" :class="bus.status_bus ? 'active' : 'inactive'">
                {{ bus.status_bus ? '🟢' : '🔴' }}
              </span>
            </div>
            <div class="bus-route-info">
              <small v-if="bus.ruta_actual">
                📍 {{ getRouteName(bus.ruta_actual) }}
              </small>
              <small v-else>Sin ruta asignada</small>
            </div>
            <div v-if="bus.ruta_actual" class="bus-progress-mini">
              <div class="progress-bar-mini">
                <div 
                  class="progress-fill-mini" 
                  :style="{ 
                    width: (bus.progreso_ruta || 0) + '%',
                    background: getRouteColor(bus.ruta_actual)
                  }"
                ></div>
              </div>
              <span class="progress-text-mini">{{ bus.progreso_ruta || 0 }}%</span>
            </div>
          </div>
          <div v-if="activeBusesWithRoutes.length === 0" class="no-buses">
            No hay buses en rutas activas
          </div>
        </div>
      </div>
    </div>

    <!-- Route Drawing Instructions -->
    <div v-if="isDrawingRoute" id="drawing-instructions" class="drawing-instructions">
      <div>
        <h4>🗺️ Dibujando Nueva Ruta</h4>
        <p>• Haz clic en el mapa para agregar puntos</p>
        <p>• Mínimo 2 puntos requeridos</p>
        <p>• Puntos actuales: <span id="point-counter">{{ currentRoutePoints.length }}</span></p>
        <div class="drawing-actions">
          <button 
            @click="undoLastPoint" 
            class="btn-undo"
            :disabled="currentRoutePoints.length === 0"
            title="Deshacer último punto"
          >
            ↶ Deshacer
          </button>
          <button @click="finishRouteDrawing" class="btn-finish">Finalizar</button>
          <button @click="cancelRouteDrawing" class="btn-cancel">Cancelar</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, computed, watch, nextTick } from 'vue'
import { useAppStore } from '../stores/app'
import { useBusesStore } from '../stores/buses'
import { useRoutesStore } from '../stores/routes'
import { useWebSocket } from '../composables/useWebSocket'
import { getActiveShifts } from '../api/shifts'
import L from 'leaflet'

const appStore = useAppStore()
const busesStore = useBusesStore()
const routesStore = useRoutesStore()

// WebSocket para GPS en tiempo real
const { 
  isConnected, 
  busLocations, 
  busLocationsArray, 
  connect: connectWebSocket, 
  disconnect: disconnectWebSocket 
} = useWebSocket()

// Estado local
const map = ref(null)
const widgetCollapsed = ref(false)
let leafletMap = null
let currentPolyline = null
let routeMarkers = []
let busMarkers = new Map() // Mapa de marcadores de buses { busId: marker }
let shiftBusMarkers = new Map() // Marcadores de buses de turnos activos
let shiftBusesInterval = null // Intervalo para actualizar buses de turnos

// Computed properties
const isDrawingRoute = computed(() => appStore.isDrawingRoute)
const currentRoutePoints = computed(() => appStore.currentRoutePoints)
const activeBuses = computed(() => busesStore.activeBuses)
const activeBusesWithRoutes = computed(() => 
  busesStore.buses.filter(bus => bus.status_bus && bus.ruta_actual)
)

// Leyenda de rutas activas con conteo de buses
const activeRoutesLegend = computed(() => {
  const routesMap = new Map()
  
  activeBusesWithRoutes.value.forEach(bus => {
    if (bus.ruta_actual) {
      const route = routesStore.getRouteById(bus.ruta_actual)
      if (route) {
        if (routesMap.has(route.id)) {
          routesMap.get(route.id).busCount++
        } else {
          routesMap.set(route.id, {
            id: route.id,
            name: route.name,
            color: route.color || '#667eea',
            busCount: 1
          })
        }
      }
    }
  })
  
  return Array.from(routesMap.values()).sort((a, b) => b.busCount - a.busCount)
})

// Métodos del mapa
const initializeMap = () => {
  if (leafletMap) return

  // Wait for the map container to be available
  const mapContainer = document.getElementById('map')
  if (!mapContainer) {
    console.warn('Map container not found, retrying in 100ms...')
    setTimeout(initializeMap, 100)
    return
  }

  console.log('Map container found:', mapContainer)
  console.log('Map container dimensions:', mapContainer.offsetWidth, 'x', mapContainer.offsetHeight)

  try {
    leafletMap = L.map('map').setView([7.1193, -73.1227], 13)

    L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', {
      attribution: '© OpenStreetMap © CartoDB',
      subdomains: 'abcd',
      maxZoom: 19
    }).addTo(leafletMap)

    // Configurar eventos del mapa
    leafletMap.on('click', handleMapClick)

    // Guardar referencia en el store
    appStore.setMapInstance(leafletMap)

    console.log('Mapa inicializado correctamente')
  } catch (error) {
    console.error('Error initializing map:', error)
  }
}

const handleMapClick = (e) => {
  if (isDrawingRoute.value) {
    addRoutePoint(e.latlng)
  }
}

const addRoutePoint = (latlng) => {
  const point = [latlng.lat, latlng.lng]
  appStore.addRoutePoint(point)

  // Crear marcador para el punto
  const marker = L.marker(latlng, {
    icon: L.divIcon({
      className: 'route-point-marker',
      html: `<div style="background: #ef4444; color: white; border-radius: 50%; width: 20px; height: 20px; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: bold;">${currentRoutePoints.value.length}</div>`,
      iconSize: [20, 20],
      iconAnchor: [10, 10]
    })
  }).addTo(leafletMap)

  routeMarkers.push(marker)

  // Dibujar línea si hay más de un punto
  if (currentRoutePoints.value.length > 1) {
    if (currentPolyline) {
      leafletMap.removeLayer(currentPolyline)
    }

    currentPolyline = L.polyline(currentRoutePoints.value, {
      color: '#ef4444',
      weight: 4,
      opacity: 0.8
    }).addTo(leafletMap)
  }
}

const undoLastPoint = () => {
  if (currentRoutePoints.value.length === 0) return

  // Remover el último punto del store
  appStore.removeLastRoutePoint()

  // Remover el último marcador del mapa
  if (routeMarkers.length > 0) {
    const lastMarker = routeMarkers.pop()
    leafletMap.removeLayer(lastMarker)
  }

  // Redibujar la polilínea con los puntos restantes
  if (currentPolyline) {
    leafletMap.removeLayer(currentPolyline)
    currentPolyline = null
  }

  if (currentRoutePoints.value.length > 1) {
    currentPolyline = L.polyline(currentRoutePoints.value, {
      color: '#ef4444',
      weight: 4,
      opacity: 0.8
    }).addTo(leafletMap)
  }
}

const finishRouteDrawing = () => {
  if (currentRoutePoints.value.length < 2) {
    alert('Necesitas al menos 2 puntos para crear una ruta')
    return
  }

  // Abrir modal para completar la información de la nueva ruta
  appStore.openModal('route', {
    path: [...currentRoutePoints.value]
  })
}

const cancelRouteDrawing = () => {
  // Limpiar marcadores
  routeMarkers.forEach(marker => leafletMap.removeLayer(marker))
  routeMarkers = []

  // Limpiar línea
  if (currentPolyline) {
    leafletMap.removeLayer(currentPolyline)
    currentPolyline = null
  }

  // Resetear estado
  appStore.stopRouteDrawing()
  appStore.clearRoutePoints()
}

const toggleFullscreen = () => {
  const mapContainer = document.getElementById('map-container')
  if (!document.fullscreenElement) {
    mapContainer.requestFullscreen()
  } else {
    document.exitFullscreen()
  }
}

const centerMap = () => {
  if (leafletMap) {
    leafletMap.setView([7.1193, -73.1227], 13)
  }
}

const toggleLayers = () => {
  // Implementar toggle de capas del mapa
  console.log('Toggle layers')
}

const toggleWidget = () => {
  widgetCollapsed.value = !widgetCollapsed.value
}

// Obtener nombre de ruta
const getRouteName = (routeId) => {
  const route = routesStore.getRouteById(routeId)
  return route ? route.name : 'Ruta desconocida'
}

// Obtener color de ruta
const getRouteColor = (routeId) => {
  const route = routesStore.getRouteById(routeId)
  return route ? route.color : '#667eea'
}

// Generar contenido del popup del bus
const getBusPopupContent = (bus, route) => {
  const lastUpdate = bus.ultima_actualizacion 
    ? new Date(bus.ultima_actualizacion).toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
    : 'Sin actualizar'

  return `
    <div style="font-family: sans-serif; min-width: 220px;">
      <h4 style="margin: 0 0 8px 0; color: ${route ? route.color : '#666'}; display: flex; align-items: center; gap: 6px;">
        🚌 ${bus.placa}
        ${bus.status_bus ? '<span style="font-size: 10px; background: #d1fae5; color: #065f46; padding: 2px 6px; border-radius: 8px;">ACTIVO</span>' : ''}
      </h4>
      
      <div style="border-bottom: 1px solid #e2e8f0; margin: 8px 0;"></div>
      
      <p style="margin: 4px 0; font-size: 12px; color: #64748b;">
        👨‍✈️ <strong>Conductor:</strong> ${bus.conductor_nombre || 'Sin asignar'}
      </p>
      
      ${route ? `
        <p style="margin: 4px 0; font-size: 12px; color: #64748b;">
          📍 <strong>Ruta:</strong> <span style="color: ${route.color}; font-weight: 600;">${route.name}</span>
        </p>
        <p style="margin: 4px 0; font-size: 12px; color: #64748b;">
          📊 <strong>Progreso:</strong> ${bus.progreso_ruta || 0}%
        </p>
        <div style="width: 100%; height: 6px; background: #e2e8f0; border-radius: 3px; margin: 6px 0; overflow: hidden;">
          <div style="width: ${bus.progreso_ruta || 0}%; height: 100%; background: ${route.color}; transition: width 0.3s;"></div>
        </div>
      ` : ''}
      
      ${bus.latitud && bus.longitud ? `
        <div style="border-bottom: 1px solid #e2e8f0; margin: 8px 0;"></div>
        <p style="margin: 4px 0; font-size: 11px; color: #94a3b8; font-family: monospace;">
          🌍 GPS: ${bus.latitud.toFixed(6)}, ${bus.longitud.toFixed(6)}
        </p>
        <p style="margin: 4px 0; font-size: 12px; color: #64748b;">
          🚗 <strong>Velocidad:</strong> ${bus.velocidad || 0} km/h
        </p>
        <p style="margin: 4px 0; font-size: 11px; color: #94a3b8;">
          🕐 Actualizado: ${lastUpdate}
        </p>
      ` : ''}
      
      <div style="border-bottom: 1px solid #e2e8f0; margin: 8px 0;"></div>
      
      <p style="margin: 4px 0; font-size: 12px; color: #64748b;">
        ✅ <strong>Viajes hoy:</strong> ${bus.viajes_completados || 0}
      </p>
    </div>
  `
}

// Mostrar rutas en el mapa
const displayRoutes = () => {
  if (!leafletMap) {
    console.log('⚠️ displayRoutes: Mapa no inicializado')
    return
  }

  console.log('🗺️ displayRoutes: Mostrando rutas activas:', [...routesStore.activeRoutes])

  // Limpiar rutas existentes
  clearRoutesFromMap()

  // Mostrar cada ruta activa
  routesStore.activeRoutes.forEach(routeId => {
    const route = routesStore.getRouteById(routeId)
    console.log(`  📍 Ruta ${routeId}:`, route ? `path=${route.path?.length} puntos` : 'NO ENCONTRADA')
    
    if (route && route.path && route.path.length > 1) {
      const polyline = L.polyline(route.path, {
        color: route.color || '#666',
        weight: 4,
        opacity: 0.8
      }).addTo(leafletMap)

      // Agregar popup
      polyline.bindPopup(`
        <div style="font-family: sans-serif;">
          <h4 style="margin: 0 0 8px 0; color: ${route.color || '#666'}">${route.name}</h4>
          <p style="margin: 4px 0; font-size: 12px;"><strong>ID:</strong> ${route.id}</p>
          ${route.fare ? `<p style="margin: 4px 0; font-size: 12px;"><strong>Tarifa:</strong> $${route.fare} COP</p>` : ''}
          <p style="margin: 4px 0; font-size: 12px;"><strong>Puntos:</strong> ${route.path.length}</p>
        </div>
      `)

      routesStore.setRoutePolyline(routeId, polyline)
      console.log(`  ✅ Ruta ${routeId} dibujada en el mapa`)
      
      // Centrar el mapa en la primera ruta
      if ([...routesStore.activeRoutes][0] === routeId) {
        leafletMap.fitBounds(polyline.getBounds(), { padding: [50, 50] })
      }
    }
  })
}

const clearRoutesFromMap = () => {
  if (!leafletMap) return

  leafletMap.eachLayer((layer) => {
    if (layer instanceof L.Polyline && layer !== currentPolyline) {
      leafletMap.removeLayer(layer)
    }
  })
}

// ═══════════════════════════════════════════════════════════════════
// 🚌 MOSTRAR BUSES DE TURNOS ACTIVOS EN EL MAPA
// ═══════════════════════════════════════════════════════════════════

// Animar suavemente un marcador de una posición a otra
const animateMarker = (marker, targetPosition, duration = 1000) => {
  const start = marker.getLatLng()
  const startLat = start.lat
  const startLng = start.lng
  const targetLat = targetPosition[0]
  const targetLng = targetPosition[1]
  
  // Si la distancia es muy pequeña, no animar
  const distance = Math.sqrt(
    Math.pow(targetLat - startLat, 2) + Math.pow(targetLng - startLng, 2)
  )
  if (distance < 0.00001) return
  
  const startTime = performance.now()
  
  const animate = (currentTime) => {
    const elapsed = currentTime - startTime
    const progress = Math.min(elapsed / duration, 1)
    
    // Easing function (ease-out-cubic) para movimiento más natural
    const easeProgress = 1 - Math.pow(1 - progress, 3)
    
    const currentLat = startLat + (targetLat - startLat) * easeProgress
    const currentLng = startLng + (targetLng - startLng) * easeProgress
    
    marker.setLatLng([currentLat, currentLng])
    
    if (progress < 1) {
      requestAnimationFrame(animate)
    }
  }
  
  requestAnimationFrame(animate)
}

// Calcular posición del bus en una ruta según el porcentaje de progreso
const getPositionOnRoute = (path, progressPercent) => {
  if (!path || path.length < 2) return null
  
  // Calcular la longitud total de la ruta
  let totalLength = 0
  const segments = []
  
  for (let i = 0; i < path.length - 1; i++) {
    const [lat1, lng1] = path[i]
    const [lat2, lng2] = path[i + 1]
    const length = Math.sqrt(Math.pow(lat2 - lat1, 2) + Math.pow(lng2 - lng1, 2))
    segments.push({ start: path[i], end: path[i + 1], length })
    totalLength += length
  }
  
  // Calcular la distancia objetivo según el progreso
  const targetDistance = (progressPercent / 100) * totalLength
  
  // Encontrar el segmento donde está el bus
  let accumulatedLength = 0
  for (const segment of segments) {
    if (accumulatedLength + segment.length >= targetDistance) {
      // El bus está en este segmento
      const segmentProgress = (targetDistance - accumulatedLength) / segment.length
      const lat = segment.start[0] + (segment.end[0] - segment.start[0]) * segmentProgress
      const lng = segment.start[1] + (segment.end[1] - segment.start[1]) * segmentProgress
      return [lat, lng]
    }
    accumulatedLength += segment.length
  }
  
  // Si llegó al final, retornar el último punto
  return path[path.length - 1]
}

// Crear icono de bus para turnos activos
const createShiftBusIcon = (bus, routeColor) => {
  const color = routeColor || '#667eea'
  
  return L.divIcon({
    className: 'shift-bus-marker',
    html: `
      <div style="
        position: relative;
        width: 40px;
        height: 40px;
        display: flex;
        align-items: center;
        justify-content: center;
      ">
        <div style="
          position: absolute;
          width: 40px;
          height: 40px;
          background: ${color}30;
          border-radius: 50%;
          animation: pulse-ring 2s ease-out infinite;
        "></div>
        <div style="
          width: 32px;
          height: 32px;
          background: linear-gradient(135deg, ${color} 0%, ${color}dd 100%);
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 16px;
          box-shadow: 0 4px 12px ${color}50;
          border: 3px solid white;
          z-index: 10;
        ">🚌</div>
      </div>
    `,
    iconSize: [40, 40],
    iconAnchor: [20, 20],
    popupAnchor: [0, -20]
  })
}

// Generar popup para bus de turno activo
const getShiftBusPopup = (bus, routeName, routeColor) => {
  return `
    <div style="font-family: sans-serif; min-width: 200px;">
      <h4 style="margin: 0 0 8px 0; color: ${routeColor}; display: flex; align-items: center; gap: 6px;">
        🚌 ${bus.placa}
        <span style="font-size: 10px; background: #d1fae5; color: #065f46; padding: 2px 6px; border-radius: 8px;">EN RUTA</span>
      </h4>
      
      <div style="border-bottom: 1px solid #e2e8f0; margin: 8px 0;"></div>
      
      <p style="margin: 4px 0; font-size: 12px; color: #64748b;">
        👨‍✈️ <strong>Conductor:</strong> ${bus.conductor || 'Sin asignar'}
      </p>
      
      <p style="margin: 4px 0; font-size: 12px; color: #64748b;">
        📍 <strong>Ruta:</strong> <span style="color: ${routeColor}; font-weight: 600;">${routeName}</span>
      </p>
      
      <p style="margin: 4px 0; font-size: 12px; color: #64748b;">
        📊 <strong>Progreso:</strong> ${bus.progreso_ruta}%
      </p>
      <div style="width: 100%; height: 8px; background: #e2e8f0; border-radius: 4px; margin: 6px 0; overflow: hidden;">
        <div style="width: ${bus.progreso_ruta}%; height: 100%; background: ${routeColor}; transition: width 0.5s;"></div>
      </div>
      
      <div style="border-bottom: 1px solid #e2e8f0; margin: 8px 0;"></div>
      
      <p style="margin: 4px 0; font-size: 12px; color: #64748b;">
        ✅ <strong>Viajes completados:</strong> ${bus.viajes_completados || 0}
      </p>
    </div>
  `
}

// Mostrar buses de turnos activos en el mapa
const displayShiftBuses = async () => {
  if (!leafletMap) {
    console.log('⚠️ displayShiftBuses: Mapa no inicializado')
    return
  }
  
  try {
    console.log('🚌 Cargando buses de turnos activos...')
    const shifts = await getActiveShifts()
    
    // Set para trackear cuáles buses existen en los turnos actuales
    const currentBusIds = new Set()
    
    shifts.forEach(shift => {
      const busId = shift.plate_number
      
      // 🆕 VERIFICAR SI EL BUS YA TIENE GPS ACTIVO
      // Si tiene GPS activo, NO mostrar marcador de turno (solo mostrar el GPS)
      if (busLocations.value.has(busId)) {
        console.log(`⏭️ Bus ${busId} tiene GPS activo - saltando marcador de turno`)
        // Eliminar marcador de turno si existía
        if (shiftBusMarkers.has(busId)) {
          leafletMap.removeLayer(shiftBusMarkers.get(busId))
          shiftBusMarkers.delete(busId)
          console.log(`🗑️ Marcador de turno eliminado para ${busId} (ahora usando GPS)`)
        }
        return
      }
      
      currentBusIds.add(busId)
      
      // Obtener la ruta del store o parsear del shift
      let routePath = null
      const storeRoute = routesStore.routes[shift.id_route]
      
      if (storeRoute && storeRoute.path) {
        routePath = storeRoute.path
      } else if (shift.path_route && shift.path_route.coordinates) {
        // Parsear de GeoJSON
        routePath = shift.path_route.coordinates.map(coord => [coord[0], coord[1]])
      }
      
      if (!routePath || routePath.length < 2) {
        console.log(`⚠️ Bus ${busId}: Sin path de ruta`)
        return
      }
      
      // Calcular posición según progreso
      const position = getPositionOnRoute(routePath, shift.progress_percentage || 0)
      if (!position) {
        console.log(`⚠️ Bus ${busId}: No se pudo calcular posición`)
        return
      }
      
      const busData = {
        id: busId,
        placa: shift.amb_code || shift.plate_number,
        conductor: shift.name_driver || 'Sin asignar',
        progreso_ruta: shift.progress_percentage || 0,
        viajes_completados: shift.trips_completed || 0
      }
      
      const routeColor = shift.color_route || '#667eea'
      const routeName = shift.name_route || 'Ruta'
      
      // Verificar si el marcador ya existe
      if (shiftBusMarkers.has(busId)) {
        // Actualizar posición del marcador existente con animación suave
        const marker = shiftBusMarkers.get(busId)
        animateMarker(marker, position, 1800) // Animar en 1.8 segundos
        marker.setPopupContent(getShiftBusPopup(busData, routeName, routeColor))
      } else {
        // Crear nuevo marcador
        const icon = createShiftBusIcon(busData, routeColor)
        const marker = L.marker(position, { icon })
          .bindPopup(getShiftBusPopup(busData, routeName, routeColor))
          .addTo(leafletMap)
        
        shiftBusMarkers.set(busId, marker)
        console.log(`✅ Marcador creado: ${busData.placa} en ruta ${routeName}`)
      }
    })
    
    // Eliminar marcadores de buses que ya no están activos
    shiftBusMarkers.forEach((marker, busId) => {
      if (!currentBusIds.has(busId)) {
        leafletMap.removeLayer(marker)
        shiftBusMarkers.delete(busId)
        console.log(`🗑️ Marcador eliminado: ${busId}`)
      }
    })
    
    console.log(`🚌 Total buses en mapa (sin GPS): ${shiftBusMarkers.size}`)
    
  } catch (error) {
    console.error('❌ Error mostrando buses de turnos:', error)
  }
}

// Limpiar marcadores de buses de turnos
const clearShiftBusMarkers = () => {
  shiftBusMarkers.forEach((marker) => {
    if (leafletMap) leafletMap.removeLayer(marker)
  })
  shiftBusMarkers.clear()
}

// Obtener ubicación actual del bus (usa coordenadas GPS si están disponibles)
const getBusLocation = (bus) => {
  // Si el bus tiene coordenadas GPS actualizadas, usarlas
  if (bus.latitud !== null && bus.longitud !== null) {
    const route = bus.ruta_actual ? routesStore.getRouteById(bus.ruta_actual) : null
    return { 
      lat: bus.latitud, 
      lng: bus.longitud, 
      route: route 
    }
  }
  
  // Si tiene ruta pero no coordenadas, calcularlas del store
  if (bus.ruta_actual) {
    const location = busesStore.calculateBusLocation(bus)
    if (location.lat !== null && location.lng !== null) {
      const route = routesStore.getRouteById(bus.ruta_actual)
      return { 
        lat: location.lat, 
        lng: location.lng, 
        route: route 
      }
    }
  }
  
  // Si no tiene ruta ni coordenadas, posición por defecto (centro de Bucaramanga)
  return { lat: 7.1193, lng: -73.1227, route: null }
}

// Crear icono personalizado para bus
const createBusIcon = (bus, route) => {
  const color = route ? route.color : '#94a3b8'
  const statusColor = bus.status_bus ? '#10b981' : '#ef4444'
  
  // Obtener las últimas 3 caracteres de la placa o ID para identificar el bus
  const busLabel = bus.placa ? bus.placa.slice(-3) : bus.id_bus.toString()
  
  return L.divIcon({
    className: 'bus-marker',
    html: `
      <div class="bus-marker-container" style="position: relative;">
        <div class="bus-marker-icon" style="
          background: ${color};
          width: 36px;
          height: 36px;
          border-radius: 50%;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          border: 2px solid white;
          box-shadow: 0 2px 8px rgba(0,0,0,0.3);
          position: relative;
          z-index: 2;
        ">
          <div style="font-size: 16px; line-height: 1;">🚌</div>
          <div style="
            font-size: 8px; 
            font-weight: bold; 
            color: white; 
            margin-top: -1px;
            text-shadow: 0 1px 2px rgba(0,0,0,0.5);
            letter-spacing: 0.3px;
          ">${busLabel}</div>
        </div>
        <div class="bus-status-dot" style="
          position: absolute;
          top: -1px;
          right: -1px;
          width: 12px;
          height: 12px;
          background: ${statusColor};
          border: 2px solid white;
          border-radius: 50%;
          z-index: 3;
          box-shadow: 0 1px 3px rgba(0,0,0,0.3);
        "></div>
      </div>
    `,
    iconSize: [36, 36],
    iconAnchor: [18, 18],
    popupAnchor: [0, -18]
  })
}

// Mostrar buses en el mapa
const displayBuses = () => {
  if (!leafletMap) return

  // Obtener buses activos asignados a rutas
  const activeBusesWithRoutes = busesStore.buses.filter(
    bus => bus.status_bus && bus.ruta_actual
  )

  // Limpiar marcadores de buses que ya no están activos
  busMarkers.forEach((marker, busId) => {
    const busExists = activeBusesWithRoutes.find(b => b.id_bus === busId)
    if (!busExists) {
      leafletMap.removeLayer(marker)
      busMarkers.delete(busId)
    }
  })

  // Crear o actualizar marcadores de buses activos
  activeBusesWithRoutes.forEach(bus => {
    const location = getBusLocation(bus)
    const route = location.route

    // Si ya existe el marcador, actualizar posición con animación
    if (busMarkers.has(bus.id_bus)) {
      const marker = busMarkers.get(bus.id_bus)
      const currentLatLng = marker.getLatLng()
      const newLatLng = L.latLng(location.lat, location.lng)
      
      // Animación suave de movimiento
      const duration = 1500 // 1.5 segundos
      const startTime = Date.now()
      
      const animate = () => {
        const elapsed = Date.now() - startTime
        const progress = Math.min(elapsed / duration, 1)
        
        // Interpolación lineal entre posición actual y nueva
        const lat = currentLatLng.lat + (newLatLng.lat - currentLatLng.lat) * progress
        const lng = currentLatLng.lng + (newLatLng.lng - currentLatLng.lng) * progress
        
        marker.setLatLng([lat, lng])
        
        if (progress < 1) {
          requestAnimationFrame(animate)
        }
      }
      
      animate()
      
      // Actualizar popup con información completa
      marker.setPopupContent(getBusPopupContent(bus, route))
    } else {
      // Crear nuevo marcador con información completa
      const icon = createBusIcon(bus, route)
      const marker = L.marker([location.lat, location.lng], { icon })
        .addTo(leafletMap)
        .bindPopup(getBusPopupContent(bus, route))

      busMarkers.set(bus.id_bus, marker)
    }
  })
}

// ═══════════════════════════════════════════════════════════════
// GPS EN TIEMPO REAL VIA WEBSOCKET
// ═══════════════════════════════════════════════════════════════

let gpsMarkers = new Map() // Marcadores de GPS en tiempo real { busId: marker }

// Crear icono para bus con GPS en tiempo real
const createGpsIcon = (busData) => {
  const color = busData.routeColor || '#3b82f6'
  const heading = busData.heading || 0
  
  return L.divIcon({
    className: 'gps-bus-marker',
    html: `
      <div class="gps-marker-container" style="position: relative;">
        <div class="gps-marker-icon" style="
          background: linear-gradient(135deg, ${color} 0%, ${color}dd 100%);
          width: 42px;
          height: 42px;
          border-radius: 50%;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          border: 3px solid white;
          box-shadow: 0 4px 12px rgba(0,0,0,0.4);
          position: relative;
          z-index: 1000;
          transform: rotate(${heading}deg);
        ">
          <div style="font-size: 20px; line-height: 1; transform: rotate(-${heading}deg);">🚌</div>
        </div>
        <div class="gps-pulse" style="
          position: absolute;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%);
          width: 60px;
          height: 60px;
          border-radius: 50%;
          background: ${color}40;
          animation: gps-pulse 2s ease-out infinite;
          z-index: 0;
        "></div>
        <div class="gps-speed-badge" style="
          position: absolute;
          bottom: -8px;
          left: 50%;
          transform: translateX(-50%);
          background: #1f2937;
          color: white;
          font-size: 10px;
          font-weight: bold;
          padding: 2px 6px;
          border-radius: 8px;
          white-space: nowrap;
          z-index: 1001;
        ">${Math.round(busData.speed || 0)} km/h</div>
      </div>
    `,
    iconSize: [42, 42],
    iconAnchor: [21, 21],
    popupAnchor: [0, -25]
  })
}

// Popup para bus GPS
const getGpsPopupContent = (busData) => {
  const lastUpdate = busData.timestamp 
    ? new Date(busData.timestamp).toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
    : 'Ahora'

  return `
    <div style="font-family: 'Segoe UI', sans-serif; min-width: 240px; padding: 4px;">
      <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 12px;">
        <div style="
          background: ${busData.routeColor || '#3b82f6'};
          color: white;
          font-size: 24px;
          width: 48px;
          height: 48px;
          border-radius: 12px;
          display: flex;
          align-items: center;
          justify-content: center;
          box-shadow: 0 2px 8px rgba(0,0,0,0.2);
        ">🚌</div>
        <div>
          <h4 style="margin: 0; font-size: 16px; color: #1f2937;">Bus #${busData.busId}</h4>
          <span style="
            font-size: 11px;
            background: #10b981;
            color: white;
            padding: 2px 8px;
            border-radius: 10px;
            font-weight: 500;
          ">📡 GPS ACTIVO</span>
        </div>
      </div>
      
      <div style="background: #f8fafc; border-radius: 8px; padding: 10px; margin-bottom: 8px;">
        <div style="display: flex; justify-content: space-between; margin-bottom: 6px;">
          <span style="color: #64748b; font-size: 12px;">🚗 Velocidad</span>
          <span style="font-weight: 600; color: #1f2937; font-size: 14px;">${Math.round(busData.speed || 0)} km/h</span>
        </div>
        <div style="display: flex; justify-content: space-between; margin-bottom: 6px;">
          <span style="color: #64748b; font-size: 12px;">🧭 Dirección</span>
          <span style="font-weight: 600; color: #1f2937; font-size: 14px;">${Math.round(busData.heading || 0)}°</span>
        </div>
        <div style="display: flex; justify-content: space-between;">
          <span style="color: #64748b; font-size: 12px;">📍 Coordenadas</span>
          <span style="font-family: monospace; font-size: 11px; color: #6366f1;">
            ${busData.lat.toFixed(5)}, ${busData.lng.toFixed(5)}
          </span>
        </div>
      </div>
      
      <div style="text-align: center; color: #94a3b8; font-size: 11px;">
        🕐 Actualizado: ${lastUpdate}
      </div>
    </div>
  `
}

// Mostrar/actualizar marcadores GPS en tiempo real
const displayGpsBuses = () => {
  if (!leafletMap) return
  
  const currentGpsBuses = busLocations.value
  
  // Eliminar marcadores de buses que ya no envían GPS
  gpsMarkers.forEach((marker, busId) => {
    if (!currentGpsBuses.has(busId)) {
      leafletMap.removeLayer(marker)
      gpsMarkers.delete(busId)
    }
  })
  
  // Actualizar o crear marcadores
  currentGpsBuses.forEach((busData, busId) => {
    if (gpsMarkers.has(busId)) {
      // Actualizar posición existente con animación suave
      const marker = gpsMarkers.get(busId)
      const currentLatLng = marker.getLatLng()
      const newLatLng = L.latLng(busData.lat, busData.lng)
      
      // Animación suave
      const duration = 1000
      const startTime = Date.now()
      
      const animateGps = () => {
        const elapsed = Date.now() - startTime
        const progress = Math.min(elapsed / duration, 1)
        
        // Easing function para movimiento más natural
        const easeProgress = 1 - Math.pow(1 - progress, 3)
        
        const lat = currentLatLng.lat + (newLatLng.lat - currentLatLng.lat) * easeProgress
        const lng = currentLatLng.lng + (newLatLng.lng - currentLatLng.lng) * easeProgress
        
        marker.setLatLng([lat, lng])
        
        if (progress < 1) {
          requestAnimationFrame(animateGps)
        }
      }
      
      animateGps()
      
      // Actualizar icono y popup
      marker.setIcon(createGpsIcon(busData))
      marker.setPopupContent(getGpsPopupContent(busData))
      
    } else {
      // Crear nuevo marcador GPS
      const icon = createGpsIcon(busData)
      const marker = L.marker([busData.lat, busData.lng], { 
        icon,
        zIndexOffset: 1000 // Asegurar que esté por encima de otros elementos
      })
        .addTo(leafletMap)
        .bindPopup(getGpsPopupContent(busData))
      
      gpsMarkers.set(busId, marker)
      
      console.log(`🚌 Nuevo bus GPS detectado: ${busId}`)
    }
  })
}

// Watcher para actualizar marcadores cuando llegan datos GPS
watch(
  () => busLocationsArray.value,
  () => {
    displayGpsBuses()
  },
  { deep: true }
)

// Watchers
watch(
  () => [...routesStore.activeRoutes], // Convertir Set a Array para que el watcher detecte cambios
  (newRoutes, oldRoutes) => {
    console.log('🔄 Rutas activas cambiaron:', newRoutes.length, 'rutas')
    displayRoutes()
  },
  { deep: true }
)
watch(() => busesStore.buses, displayBuses, { deep: true })

// Intervalo para actualizar posiciones de buses
let busUpdateInterval = null
let busMovementInterval = null

// Lifecycle
onMounted(() => {
  nextTick(() => {
    initializeMap()
    displayRoutes()
    displayBuses()
    
    // ═══════════════════════════════════════════════════════════
    // CONECTAR WEBSOCKET PARA GPS EN TIEMPO REAL
    // ═══════════════════════════════════════════════════════════
    connectWebSocket()
    console.log('🛰️ WebSocket GPS iniciando conexión...')
    
    // ═══════════════════════════════════════════════════════════
    // MOSTRAR BUSES DE TURNOS ACTIVOS
    // ═══════════════════════════════════════════════════════════
    displayShiftBuses()
    // Actualizar buses de turnos cada 3 segundos
    shiftBusesInterval = setInterval(displayShiftBuses, 3000)
    console.log('🚌 Intervalo de buses de turnos iniciado')
    
    // Simular movimiento de buses cada 3 segundos (actualizar progreso)
    busMovementInterval = setInterval(() => {
      busesStore.simulateBusMovement()
    }, 3000)
    
    // Actualizar visualización de buses cada 2 segundos
    busUpdateInterval = setInterval(() => {
      displayBuses()
    }, 2000)
  })
})

onUnmounted(() => {
  if (busUpdateInterval) {
    clearInterval(busUpdateInterval)
  }
  
  if (busMovementInterval) {
    clearInterval(busMovementInterval)
  }
  
  // Limpiar intervalo de buses de turnos
  if (shiftBusesInterval) {
    clearInterval(shiftBusesInterval)
    console.log('🚌 Intervalo de buses de turnos detenido')
  }
  
  // ═══════════════════════════════════════════════════════════
  // DESCONECTAR WEBSOCKET
  // ═══════════════════════════════════════════════════════════
  disconnectWebSocket()
  console.log('🛰️ WebSocket GPS desconectado')
  
  // Limpiar marcadores de buses
  busMarkers.forEach(marker => {
    if (leafletMap) {
      leafletMap.removeLayer(marker)
    }
  })
  busMarkers.clear()
  
  // Limpiar marcadores GPS
  gpsMarkers.forEach(marker => {
    if (leafletMap) {
      leafletMap.removeLayer(marker)
    }
  })
  gpsMarkers.clear()
  
  // Limpiar marcadores de buses de turnos
  clearShiftBusMarkers()
  
  if (leafletMap) {
    leafletMap.remove()
    leafletMap = null
  }
})
</script>

<style scoped>
/* Map container */
.map-wrapper {
  height: 100%;
  width: 100%;
  position: relative;
}

#map {
  height: 100%;
  width: 100%;
  z-index: 1;
}

.leaflet-map {
  height: 100% !important;
  width: 100% !important;
}

/* Map controls */
.map-controls {
  position: absolute;
  top: 20px;
  right: 20px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  z-index: 800;
}

.map-control-btn {
  width: 45px;
  height: 45px;
  background: white;
  border: none;
  border-radius: 10px;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  cursor: pointer;
  font-size: 16px;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
}

.map-control-btn:hover {
  background: #667eea;
  color: white;
  transform: scale(1.05);
}

/* Floating widget */
.floating-widget {
  position: absolute;
  top: 20px;
  left: 20px;
  width: 300px;
  background: white;
  border-radius: 12px;
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
  z-index: 800;
  overflow: hidden;
  backdrop-filter: blur(10px);
  border: 1px solid #e2e8f0;
}

.widget-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: 15px 20px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.widget-header-right {
  display: flex;
  align-items: center;
  gap: 8px;
}

.ws-indicator {
  font-size: 16px;
  opacity: 0.5;
  transition: all 0.3s ease;
}

.ws-indicator.connected {
  opacity: 1;
  animation: wsGlow 2s ease-in-out infinite;
}

@keyframes wsGlow {
  0%, 100% { filter: drop-shadow(0 0 4px rgba(255,255,255,0.3)); }
  50% { filter: drop-shadow(0 0 8px rgba(255,255,255,0.8)); }
}

.widget-title {
  font-weight: 600;
  font-size: 14px;
}

/* Sección de buses GPS */
.gps-buses-section {
  padding: 12px;
  background: linear-gradient(135deg, #ecfdf5 0%, #d1fae5 100%);
  border-bottom: 1px solid #a7f3d0;
}

.section-label {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 11px;
  font-weight: 600;
  color: #065f46;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 8px;
}

.pulse-dot {
  width: 8px;
  height: 8px;
  background: #10b981;
  border-radius: 50%;
  animation: pulseDot 1.5s ease-in-out infinite;
}

@keyframes pulseDot {
  0%, 100% { transform: scale(1); opacity: 1; }
  50% { transform: scale(1.2); opacity: 0.7; }
}

.gps-bus-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.gps-bus-item {
  background: white;
  padding: 8px 10px;
  border-radius: 8px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
}

.gps-bus-info {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 4px;
}

.gps-bus-id {
  font-weight: 600;
  font-size: 12px;
  color: #1f2937;
}

.gps-speed {
  font-size: 11px;
  font-weight: 600;
  color: #059669;
  background: #d1fae5;
  padding: 2px 6px;
  border-radius: 4px;
}

.gps-coords {
  font-size: 10px;
  color: #6b7280;
  font-family: monospace;
}

.widget-toggle {
  background: none;
  border: none;
  color: white;
  font-size: 18px;
  cursor: pointer;
  width: 24px;
  height: 24px;
  border-radius: 4px;
  transition: all 0.2s ease;
}

.widget-toggle:hover {
  background: rgba(255, 255, 255, 0.2);
}

.widget-content {
  padding: 15px;
  max-height: 300px;
  overflow-y: auto;
  transition: all 0.3s ease;
}

.widget-content.collapsed {
  max-height: 0;
  padding: 0 15px;
}

/* Routes Legend */
.routes-legend {
  margin-bottom: 12px;
  padding-bottom: 12px;
  border-bottom: 2px solid #f1f5f9;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 0;
}

.legend-color {
  width: 20px;
  height: 20px;
  border-radius: 50%;
  border: 2px solid white;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
  flex-shrink: 0;
}

.legend-name {
  flex: 1;
  font-size: 12px;
  font-weight: 500;
  color: #334155;
}

.legend-count {
  background: #f1f5f9;
  color: #64748b;
  font-size: 11px;
  font-weight: 600;
  padding: 2px 8px;
  border-radius: 10px;
  min-width: 24px;
  text-align: center;
}

/* Live buses list */
.live-bus-item {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 12px 0;
  border-bottom: 1px solid #f1f5f9;
}

.live-bus-item:last-child {
  border-bottom: none;
}

.bus-info {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.bus-plate-with-color {
  display: flex;
  align-items: center;
  gap: 8px;
}

.bus-color-indicator {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  border: 2px solid white;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.2);
  flex-shrink: 0;
}

.bus-plate {
  font-weight: 600;
  color: #1e293b;
  font-size: 14px;
}

.bus-status {
  font-size: 12px;
}

.bus-route-info {
  font-size: 12px;
  color: #64748b;
}

.bus-route-info small {
  display: block;
}

.bus-progress-mini {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 4px;
}

.progress-bar-mini {
  flex: 1;
  height: 4px;
  background: #e2e8f0;
  border-radius: 2px;
  overflow: hidden;
}

.progress-fill-mini {
  height: 100%;
  transition: width 0.5s ease;
  border-radius: 2px;
}

.progress-text-mini {
  font-size: 10px;
  font-weight: 600;
  color: #64748b;
  min-width: 32px;
  text-align: right;
}

.no-buses {
  text-align: center;
  color: #64748b;
  font-style: italic;
  padding: 20px 0;
}

/* Drawing instructions */
.drawing-instructions {
  position: fixed;
  top: 100px;
  right: 20px;
  background: white;
  padding: 20px;
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  z-index: 1000;
  max-width: 300px;
}

.drawing-instructions h4 {
  margin: 0 0 10px 0;
  color: #ef4444;
  font-size: 16px;
}

.drawing-instructions p {
  margin: 8px 0;
  font-size: 14px;
  color: #64748b;
}

.drawing-actions {
  margin-top: 15px;
  display: flex;
  gap: 8px;
}

.btn-finish,
.btn-cancel,
.btn-undo {
  flex: 1;
  padding: 8px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 12px;
  font-weight: 500;
  transition: all 0.2s ease;
}

.btn-undo {
  background: #f97316;
  color: white;
}

.btn-undo:hover:not(:disabled) {
  background: #ea580c;
}

.btn-undo:disabled {
  background: #d1d5db;
  color: #9ca3af;
  cursor: not-allowed;
  opacity: 0.6;
}

.btn-finish {
  background: #10b981;
  color: white;
}

.btn-finish:hover {
  background: #059669;
}

.btn-cancel {
  background: #ef4444;
  color: white;
}

.btn-cancel:hover {
  background: #dc2626;
}

/* Route point markers */
.route-point-marker {
  border: 2px solid white !important;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.3) !important;
  cursor: pointer;
}

/* Bus markers */
:deep(.bus-marker) {
  background: transparent !important;
  border: none !important;
}

:deep(.bus-marker-container) {
  cursor: pointer;
  transition: transform 0.3s ease;
  filter: drop-shadow(0 4px 6px rgba(0, 0, 0, 0.3));
}

:deep(.bus-marker-container:hover) {
  transform: scale(1.2);
  filter: drop-shadow(0 6px 10px rgba(0, 0, 0, 0.4));
}

:deep(.bus-marker-icon) {
  animation: busFloat 3s ease-in-out infinite;
}

@keyframes busFloat {
  0%, 100% {
    transform: translateY(0px);
  }
  50% {
    transform: translateY(-4px);
  }
}

:deep(.bus-status-dot) {
  animation: statusPulse 2s ease-in-out infinite;
}

@keyframes statusPulse {
  0%, 100% {
    opacity: 1;
    transform: scale(1);
  }
  50% {
    opacity: 0.7;
    transform: scale(0.9);
  }
}

/* ═══════════════════════════════════════════════════════════════
   ESTILOS PARA MARCADORES GPS EN TIEMPO REAL
   ═══════════════════════════════════════════════════════════════ */

:deep(.gps-bus-marker) {
  background: transparent;
  border: none;
}

:deep(.gps-marker-container) {
  position: relative;
}

:deep(.gps-marker-icon) {
  transition: transform 0.3s ease;
}

@keyframes gps-pulse {
  0% {
    transform: translate(-50%, -50%) scale(0.5);
    opacity: 1;
  }
  100% {
    transform: translate(-50%, -50%) scale(1.5);
    opacity: 0;
  }
}

:deep(.gps-pulse) {
  animation: gps-pulse 2s ease-out infinite !important;
}

:deep(.gps-speed-badge) {
  box-shadow: 0 2px 4px rgba(0,0,0,0.3);
}

/* Responsive */
@media (max-width: 768px) {
  .floating-widget {
    position: relative;
    top: 10px;
    left: 10px;
    width: calc(100% - 20px);
    max-width: 300px;
  }

  .map-controls {
    top: 10px;
    right: 10px;
  }

  .drawing-instructions {
    position: fixed;
    top: 80px;
    left: 10px;
    right: 10px;
    max-width: none;
  }

  .drawing-actions {
    flex-direction: column;
  }

  .btn-finish,
  .btn-cancel {
    padding: 10px;
    font-size: 14px;
  }
}

/* Animación de pulso para marcadores de buses */
@keyframes pulse-ring {
  0% {
    transform: scale(0.8);
    opacity: 1;
  }
  100% {
    transform: scale(2);
    opacity: 0;
  }
}

/* Estilos para marcadores de buses de turnos */
:deep(.shift-bus-marker) {
  background: transparent !important;
  border: none !important;
}
</style>