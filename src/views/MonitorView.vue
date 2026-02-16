<template>
  <div class="monitor-widget" :class="{ collapsed: isCollapsed }">
    <div class="widget-card">
      <!-- Header compacto (siempre visible) -->
      <div class="widget-header" @click="toggleCollapse">
        <div class="header-left">
          <h3>📍 Monitor</h3>
          <!-- Stats mini cuando está colapsado -->
          <div v-if="isCollapsed" class="mini-stats">
            <span class="mini-stat">🚌 {{ activeRoutesData.reduce((sum, r) => sum + r.busesActivos, 0) }}</span>
            <span class="mini-stat">🚦 {{ activeRoutesData.length }}</span>
            <span class="mini-stat">✅ {{ getTotalTripsCompleted() }}</span>
          </div>
          <!-- Botón ver todas las rutas -->
          <button 
            v-if="!isCollapsed && activeRoutesData.length > 0"
            class="show-all-btn"
            @click.stop="toggleAllRoutes"
            :title="allRoutesVisible ? 'Ocultar todas las rutas' : 'Mostrar todas las rutas'"
          >
            {{ allRoutesVisible ? '👁️ Ocultar' : '👁️ Ver todas' }}
          </button>
        </div>
        <div class="header-indicators">
          <span 
            class="ws-indicator" 
            :class="{ connected: isConnected, disconnected: !isConnected }"
            :title="isConnected ? 'WebSocket conectado' : 'WebSocket desconectado'"
          >
            {{ isConnected ? '🟢' : '🔴' }}
          </span>
          <span v-if="!isCollapsed" class="live-indicator">🔴 EN VIVO</span>
          <button class="collapse-btn" :title="isCollapsed ? 'Expandir' : 'Minimizar'">
            {{ isCollapsed ? '▼' : '▲' }}
          </button>
        </div>
      </div>

      <!-- Contenido expandible -->
      <div v-show="!isCollapsed" class="widget-body">
        <div class="monitor-stats-grid">
          <div class="monitor-stat-card">
            <div class="stat-label">Buses Activos</div>
            <div class="stat-number">
              {{ activeRoutesData.reduce((sum, r) => sum + r.busesActivos, 0) }}
            </div>
          </div>
          <div class="monitor-stat-card">
            <div class="stat-label">Rutas Activas</div>
            <div class="stat-number">{{ activeRoutesData.length }}</div>
          </div>
          <div class="monitor-stat-card">
            <div class="stat-label">Viajes Completados</div>
            <div class="stat-number">
              {{ getTotalTripsCompleted() }}
            </div>
          </div>
        </div>

        <!-- Vista de Cards -->
        <div class="active-routes-cards">
          <div class="section-title">
            <h4>🚦 Rutas en Línea</h4>
            <span class="refresh-btn" @click.stop="loadActiveRoutes">🔄</span>
          </div>

          <!-- Barra de búsqueda -->
          <div class="search-container" @click.stop>
            <div class="search-input-wrapper">
              <span class="search-icon">🔍</span>
              <input 
                type="text"
                v-model="searchQuery"
                placeholder="Buscar por ruta, placa o conductor..."
                class="search-input"
                @input="handleSearch"
              >
              <button 
                v-if="searchQuery"
                class="clear-search"
                @click="clearSearch"
                title="Limpiar búsqueda"
              >
                ✕
              </button>
            </div>
            <div v-if="searchQuery" class="search-results-info">
              {{ filteredRoutes.length }} {{ filteredRoutes.length === 1 ? 'resultado' : 'resultados' }}
            </div>
          </div>

          <div class="cards-grid" @click.stop>
            <div 
              v-for="route in filteredRoutes" 
              :key="route.storeId"
              class="route-card"
              :style="{ borderLeftColor: route.color }"
            >
              <div class="card-header">
                <div class="card-header-left">
                  <h5 v-html="highlightText(route.name)"></h5>
                  <button 
                    class="toggle-route-visibility"
                    :class="{ 'route-visible': isRouteVisible(route.storeId) }"
                    @click="toggleRouteVisibility(route)"
                    :title="isRouteVisible(route.storeId) ? 'Ocultar ruta en el mapa' : 'Mostrar ruta en el mapa'"
                  >
                    {{ isRouteVisible(route.storeId) ? '👁️' : '👁️‍🗨️' }}
                  </button>
                </div>
                <span class="status-badge online">EN LÍNEA</span>
              </div>

              <div class="card-stats">
                <div class="stat-item">
                  <span class="stat-icon">🚌</span>
                  <div class="stat-detail">
                    <span class="stat-value">{{ route.busesActivos }}</span>
                    <span class="stat-label">Buses</span>
                  </div>
                </div>
                <div class="stat-item">
                  <span class="stat-icon">🔄</span>
                  <div class="stat-detail">
                    <span class="stat-value">{{ route.tripsActivos }}</span>
                    <span class="stat-label">Viajes</span>
                  </div>
                </div>
                <div class="stat-item">
                  <span class="stat-icon">✅</span>
                  <div class="stat-detail">
                    <span class="stat-value">{{ getRouteTripsCompleted(route) }}</span>
                    <span class="stat-label">OK</span>
                  </div>
                </div>
              </div>

              <div class="buses-list">
                <div 
                  v-for="bus in getFilteredBuses(route).slice(0, 3)" 
                  :key="bus.id_bus"
                  class="bus-item"
                >
                  <div class="bus-header">
                    <span class="bus-icon">🚌</span>
                    <div class="bus-info">
                      <span class="bus-plate" v-html="highlightText(bus.placa)"></span>
                      <span class="bus-driver" v-if="bus.conductor" v-html="highlightText('👨‍✈️ ' + bus.conductor)"></span>
                    </div>
                    <div class="bus-stats">
                      <span class="trip-count" :title="`${bus.viajes_completados} viajes completados hoy`">
                        🎯 {{ bus.viajes_completados }}
                      </span>
                    </div>
                  </div>
                  
                  <div class="bus-progress">
                    <div class="bus-progress-bar">
                      <div 
                        class="bus-progress-fill" 
                        :style="{ 
                          width: bus.progreso_ruta + '%',
                          backgroundColor: getProgressColor(bus.progreso_ruta)
                        }"
                      ></div>
                    </div>
                    <span class="bus-progress-text">{{ bus.progreso_ruta }}%</span>
                  </div>
                </div>
                
                <div v-if="getFilteredBuses(route).length > 3" class="more-buses">
                  +{{ getFilteredBuses(route).length - 3 }} buses más
                </div>
              </div>

              <div class="card-actions">
                <button class="card-action-btn" @click="focusRoute(route.storeId, route.path, route.color, route.name)">
                  📍 Ver en Mapa
                </button>
                <button class="card-action-btn" @click="viewRouteDetails(route.storeId)">
                  📊 Detalles
                </button>
              </div>
            </div>

            <div v-if="filteredRoutes.length === 0 && searchQuery" class="empty-state-card">
              <div class="empty-icon">🔍</div>
              <p>No se encontraron resultados</p>
              <small>Intenta con otro término de búsqueda</small>
              <button class="clear-search-btn" @click="clearSearch">Limpiar búsqueda</button>
            </div>

            <div v-else-if="activeRoutesData.length === 0" class="empty-state-card">
              <div class="empty-icon">🚫</div>
              <p>No hay rutas activas</p>
              <small>Inicia un viaje para ver rutas en línea</small>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useAppStore } from '../stores/app'
import { useBusesStore } from '../stores/buses'
import { useRoutesStore } from '../stores/routes'
import { useWebSocket } from '../composables/useWebSocket'
import { getActiveShifts } from '../api/shifts'

const appStore = useAppStore()
const busesStore = useBusesStore()
const routesStore = useRoutesStore()

// 🆕 WebSocket
const { 
  connect, 
  disconnect, 
  isConnected, 
  busLocations: wsLocations,
  connectionError,
  requestAllLocations 
} = useWebSocket()

const activeRoutesData = ref([])
const searchQuery = ref('')
const isCollapsed = ref(false) // Estado colapsado
const allRoutesVisible = ref(false) // Todas las rutas visibles
let refreshInterval = null

// Toggle colapsar/expandir
const toggleCollapse = () => {
  isCollapsed.value = !isCollapsed.value
}

// Función auxiliar para convertir id numérico a formato RUTA_XX
const formatRouteId = (numericId) => {
  return `RUTA_${String(numericId).padStart(2, '0')}`
}

// Mostrar/ocultar todas las rutas activas
const toggleAllRoutes = () => {
  if (allRoutesVisible.value) {
    // Ocultar todas
    activeRoutesData.value.forEach(route => {
      routesStore.deactivateRoute(route.storeId)
    })
    allRoutesVisible.value = false
    console.log('👁️ Todas las rutas ocultas')
  } else {
    // Mostrar todas
    showAllActiveRoutes()
  }
}

// Mostrar todas las rutas activas en el mapa
const showAllActiveRoutes = () => {
  activeRoutesData.value.forEach(route => {
    // Activar ruta en el store usando el ID formateado
    routesStore.activateRoute(route.storeId)
    
    // Si la ruta no existe en el store, agregarla temporalmente con su path
    if (!routesStore.routes[route.storeId] && route.path) {
      routesStore.routes[route.storeId] = {
        id: route.storeId,
        name: route.name,
        color: route.color,
        path: route.path,
        visible: true,
        description: '',
        stops: [],
        buses: []
      }
    }
  })
  allRoutesVisible.value = true
  console.log('👁️ Mostrando todas las rutas activas:', activeRoutesData.value.length)
}

// Computed properties
const activeBusesCount = computed(() => busesStore.activeBuses.length)
const totalRoutesCount = computed(() => routesStore.routesCount)

// 🆕 Filtrar rutas según búsqueda
const filteredRoutes = computed(() => {
  if (!searchQuery.value.trim()) {
    return activeRoutesData.value
  }

  const query = searchQuery.value.toLowerCase().trim()

  return activeRoutesData.value.filter(route => {
    // Buscar en nombre de ruta
    if (route.name.toLowerCase().includes(query)) {
      return true
    }

    // Buscar en buses (placa o conductor)
    return route.buses.some(bus => 
      bus.placa?.toLowerCase().includes(query) ||
      bus.conductor?.toLowerCase().includes(query)
    )
  })
})

// 🆕 Obtener buses filtrados de una ruta
const getFilteredBuses = (route) => {
  if (!searchQuery.value.trim()) {
    return route.buses
  }

  const query = searchQuery.value.toLowerCase().trim()

  // Si la búsqueda coincide con el nombre de la ruta, mostrar todos los buses
  if (route.name.toLowerCase().includes(query)) {
    return route.buses
  }

  // Si no, mostrar solo buses que coincidan
  return route.buses.filter(bus =>
    bus.placa?.toLowerCase().includes(query) ||
    bus.conductor?.toLowerCase().includes(query)
  )
}

// 🆕 Resaltar texto coincidente
const highlightText = (text) => {
  if (!searchQuery.value.trim() || !text) {
    return text
  }

  const query = searchQuery.value.trim()
  const regex = new RegExp(`(${query})`, 'gi')
  return text.replace(regex, '<mark class="highlight">$1</mark>')
}

// 🆕 Manejar búsqueda
const handleSearch = () => {
  console.log('🔍 Buscando:', searchQuery.value)
}

// 🆕 Limpiar búsqueda
const clearSearch = () => {
  searchQuery.value = ''
}

// Obtener total de viajes completados de una ruta
const getRouteTripsCompleted = (route) => {
  if (!route.buses || route.buses.length === 0) return 0
  return route.buses.reduce((sum, bus) => sum + (bus.viajes_completados || 0), 0)
}

// Obtener total de viajes completados de todas las rutas
const getTotalTripsCompleted = () => {
  return activeRoutesData.value.reduce((sum, route) => 
    sum + getRouteTripsCompleted(route), 0
  )
}

// Color según progreso (verde al inicio, amarillo a la mitad, azul al final)
const getProgressColor = (percentage) => {
  if (percentage < 33) return '#10b981'   // Verde - Inicio
  if (percentage < 66) return '#f59e0b'   // Amarillo - Medio
  return '#3b82f6'                        // Azul - Final/Completando
}

// Métodos existentes
const openBusModal = () => {
  appStore.openModal('bus')
}

const openRouteModal = () => {
  appStore.openModal('route')
}

const viewAllRoutes = () => {
  routesStore.clearActiveRoutes()
  Object.keys(routesStore.routes).forEach(routeId => {
    routesStore.activateRoute(routeId)
  })
}

const focusRoute = (routeId, path, color, name) => {
  console.log('📍 Enfocando ruta:', routeId)
  
  // Agregar ruta al store si no existe
  if (!routesStore.routes[routeId] && path) {
    routesStore.routes[routeId] = {
      id: routeId,
      name: name,
      color: color,
      path: path,
      visible: true,
      description: '',
      stops: [],
      buses: []
    }
  }
  
  routesStore.activateRoute(routeId)
}

const viewRouteDetails = (routeId) => {
  console.log('📊 Ver detalles de ruta:', routeId)
  appStore.openModal('route', { id: routeId })
}

// Verificar si una ruta está visible en el mapa
const isRouteVisible = (routeId) => {
  // Verificar si está en activeRoutes del store
  return routesStore.activeRoutes.has(routeId)
}

// Toggle visibilidad de ruta en el mapa
const toggleRouteVisibility = (route) => {
  const routeId = route.storeId
  
  // Agregar al store si no existe
  if (!routesStore.routes[routeId] && route.path) {
    routesStore.routes[routeId] = {
      id: routeId,
      name: route.name,
      color: route.color,
      path: route.path,
      visible: true,
      description: '',
      stops: [],
      buses: []
    }
  }
  
  if (routesStore.activeRoutes.has(routeId)) {
    routesStore.deactivateRoute(routeId)
    console.log(`👁️ Ruta ${routeId} oculta en el mapa`)
  } else {
    routesStore.activateRoute(routeId)
    console.log(`👁️ Ruta ${routeId} visible en el mapa`)
  }
}

// Cargar rutas activas desde API de turnos
const loadActiveRoutes = async () => {
  try {
    console.log('📡 Cargando turnos activos desde API...')
    
    // Obtener turnos activos desde la API
    const shifts = await getActiveShifts()
    console.log('📦 Turnos recibidos:', shifts.length)
    
    // Agrupar turnos por ruta
    const routesMap = new Map()
    
    shifts.forEach(shift => {
      const routeId = Number(shift.id_route)
      const storeId = formatRouteId(routeId)
      
      if (!routesMap.has(routeId)) {
        // Parsear el path de GeoJSON a formato Leaflet [lat, lng]
        let pathCoords = []
        if (shift.path_route && shift.path_route.coordinates) {
          // GeoJSON usa [lng, lat], Leaflet usa [lat, lng]
          pathCoords = shift.path_route.coordinates.map(coord => [coord[0], coord[1]])
        }
        
        routesMap.set(routeId, {
          id: routeId,
          storeId: storeId,  // ID formateado para el store
          name: shift.name_route,
          color: shift.color_route || '#667eea',
          path: pathCoords,  // Path para dibujar en el mapa
          busesActivos: 0,
          tripsActivos: 0,
          buses: []
        })
      }
      
      const route = routesMap.get(routeId)
      route.busesActivos++
      route.tripsActivos++
      route.buses.push({
        id_bus: shift.plate_number,
        placa: shift.amb_code || shift.plate_number,
        conductor: shift.name_driver || 'Sin asignar',
        progreso_ruta: shift.progress_percentage || 0,
        viajes_completados: shift.trips_completed || 0,
        lat: shift.current_lat,
        lng: shift.current_lng
      })
    })
    
    activeRoutesData.value = Array.from(routesMap.values())
    console.log('✅ Rutas activas procesadas:', activeRoutesData.value.length)
    
    // Auto-mostrar rutas activas en el mapa (solo la primera vez)
    if (activeRoutesData.value.length > 0 && !allRoutesVisible.value) {
      showAllActiveRoutes()
    }
  } catch (error) {
    console.error('❌ Error cargando turnos activos:', error)
    // Mantener datos anteriores en caso de error temporal
    if (activeRoutesData.value.length === 0) {
      activeRoutesData.value = []
    }
  }
}

// Lifecycle
onMounted(() => {
  console.log('🚀 MonitorView montado')
  
  // 🆕 Conectar WebSocket (usa variable de entorno o fallback a localhost)
  const wsUrl = import.meta.env.VITE_WS_URL || 'http://localhost:3001'
  connect(wsUrl)
  
  loadActiveRoutes()
  refreshInterval = setInterval(loadActiveRoutes, 5000) // Refrescar cada 5s
})

onUnmounted(() => {
  if (refreshInterval) {
    clearInterval(refreshInterval)
  }
  // 🆕 Desconectar WebSocket
  disconnect()
  console.log('⏹️ MonitorView desmontado')
})

// 🆕 Watch para actualizaciones de ubicación en tiempo real
watch(wsLocations, (newLocations) => {
  if (newLocations.length > 0) {
    console.log('📍 Actualización de ubicaciones:', newLocations.length)
    // Aquí podrías actualizar los marcadores en el mapa
  }
}, { deep: true })
</script>

<style scoped>
.monitor-widget {
  max-width: 400px;
  transition: all 0.3s ease;
}

.monitor-widget.collapsed {
  max-width: 320px;
}

.widget-card {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10px);
  border-radius: 16px;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.15);
  overflow: hidden;
  border: 1px solid rgba(255, 255, 255, 0.3);
}

.widget-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 12px 16px;
  color: white;
  display: flex;
  justify-content: space-between;
  align-items: center;
  cursor: pointer;
  user-select: none;
  transition: padding 0.3s ease;
}

.monitor-widget.collapsed .widget-header {
  padding: 10px 14px;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 12px;
  flex: 1;
}

.widget-header h3 {
  margin: 0;
  font-size: 15px;
  font-weight: 600;
  white-space: nowrap;
}

/* Mini stats cuando está colapsado */
.mini-stats {
  display: flex;
  gap: 10px;
  animation: fadeIn 0.3s ease;
}

.mini-stat {
  font-size: 12px;
  font-weight: 600;
  background: rgba(255, 255, 255, 0.2);
  padding: 3px 8px;
  border-radius: 10px;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateX(-10px); }
  to { opacity: 1; transform: translateX(0); }
}

/* Botón mostrar todas las rutas */
.show-all-btn {
  background: rgba(255, 255, 255, 0.25);
  border: 1px solid rgba(255, 255, 255, 0.4);
  color: white;
  padding: 4px 10px;
  border-radius: 8px;
  font-size: 11px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  white-space: nowrap;
}

.show-all-btn:hover {
  background: rgba(255, 255, 255, 0.4);
  transform: scale(1.05);
}

.show-all-btn:active {
  transform: scale(0.95);
}

.header-indicators {
  display: flex;
  align-items: center;
  gap: 8px;
}

.collapse-btn {
  background: rgba(255, 255, 255, 0.2);
  border: none;
  color: white;
  width: 28px;
  height: 28px;
  border-radius: 8px;
  cursor: pointer;
  font-size: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
}

.collapse-btn:hover {
  background: rgba(255, 255, 255, 0.3);
  transform: scale(1.1);
}

/* Indicador de WebSocket */
.ws-indicator {
  padding: 4px 8px;
  border-radius: 10px;
  font-size: 12px;
  font-weight: 600;
}

.ws-indicator.connected {
  background: rgba(16, 185, 129, 0.3);
}

.ws-indicator.disconnected {
  background: rgba(239, 68, 68, 0.3);
}

.live-indicator {
  padding: 4px 10px;
  background: rgba(239, 68, 68, 0.2);
  color: white;
  border-radius: 12px;
  font-size: 10px;
  font-weight: 600;
  animation: pulse 2s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.7; }
}

/* Transición de deslizamiento */
.slide-enter-active,
.slide-leave-active {
  transition: all 0.3s ease;
  max-height: 600px;
  overflow: hidden;
}

.slide-enter-from,
.slide-leave-to {
  max-height: 0;
  opacity: 0;
}

/* Widget body */
.widget-body {
  overflow: hidden;
}

.monitor-stats-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0;
  border-bottom: 1px solid #e2e8f0;
}

.monitor-stat-card {
  padding: 20px 16px;
  text-align: center;
  border-right: 1px solid #e2e8f0;
  transition: all 0.2s ease;
}

.monitor-stat-card:last-child {
  border-right: none;
}

.monitor-stat-card:hover {
  background: #f8fafc;
}

.stat-label {
  font-size: 11px;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 8px;
  font-weight: 500;
}

.stat-number {
  font-size: 28px;
  font-weight: 700;
  color: #667eea;
  line-height: 1;
}

.active-routes-cards {
  padding: 20px;
  background: #f8fafc;
}

.section-title {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}

.section-title h4 {
  margin: 0;
  font-size: 14px;
  font-weight: 600;
  color: #334155;
}

.refresh-btn {
  cursor: pointer;
  font-size: 18px;
  transition: transform 0.3s;
}

.refresh-btn:hover {
  transform: rotate(180deg);
}

/* 🆕 Estilos de búsqueda */
.search-container {
  margin-bottom: 16px;
}

.search-input-wrapper {
  position: relative;
  display: flex;
  align-items: center;
}

.search-icon {
  position: absolute;
  left: 12px;
  font-size: 16px;
  pointer-events: none;
}

.search-input {
  width: 100%;
  padding: 10px 40px 10px 40px;
  border: 2px solid #e2e8f0;
  border-radius: 10px;
  font-size: 13px;
  transition: all 0.3s;
  background: white;
}

.search-input:focus {
  outline: none;
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.clear-search {
  position: absolute;
  right: 8px;
  width: 24px;
  height: 24px;
  border: none;
  background: #e2e8f0;
  color: #64748b;
  border-radius: 50%;
  cursor: pointer;
  font-size: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
}

.clear-search:hover {
  background: #cbd5e1;
  color: #334155;
}

.search-results-info {
  margin-top: 8px;
  font-size: 12px;
  color: #64748b;
  text-align: center;
}

/* Resaltado de texto */
:deep(.highlight) {
  background: #fef08a;
  color: #854d0e;
  padding: 2px 4px;
  border-radius: 3px;
  font-weight: 600;
}

.clear-search-btn {
  margin-top: 16px;
  padding: 8px 16px;
  border: none;
  background: #667eea;
  color: white;
  border-radius: 8px;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.clear-search-btn:hover {
  background: #5a67d8;
  transform: translateY(-1px);
}

.cards-grid {
  display: grid;
  gap: 16px;
  max-height: 500px;
  overflow-y: auto;
}

.route-card {
  background: white;
  border-radius: 12px;
  border-left: 4px solid #667eea;
  padding: 16px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  transition: all 0.3s;
  animation: slideIn 0.5s ease-out;
}

@keyframes slideIn {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.route-card:hover {
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12);
  transform: translateY(-2px);
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
}

.card-header-left {
  display: flex;
  align-items: center;
  gap: 10px;
  flex: 1;
}

.card-header h5 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
  color: #1e293b;
}

.toggle-route-visibility {
  background: #f1f5f9;
  border: none;
  border-radius: 8px;
  padding: 6px 10px;
  font-size: 16px;
  cursor: pointer;
  transition: all 0.3s;
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 36px;
  height: 36px;
}

.toggle-route-visibility:hover {
  background: #667eea;
  transform: scale(1.1);
}

.toggle-route-visibility:active {
  transform: scale(0.95);
}

.toggle-route-visibility.route-visible {
  background: #d1fae5;
  color: #065f46;
}

.toggle-route-visibility.route-visible:hover {
  background: #10b981;
}

.status-badge {
  padding: 4px 10px;
  border-radius: 12px;
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.status-badge.online {
  background: #d1fae5;
  color: #065f46;
}

.card-stats {
  display: flex;
  gap: 12px;
  margin-bottom: 16px;
}

.stat-item {
  display: flex;
  align-items: center;
  gap: 6px;
  flex: 1;
}

.stat-icon {
  font-size: 18px;
}

.stat-detail {
  display: flex;
  flex-direction: column;
}

.stat-value {
  font-size: 16px;
  font-weight: 700;
  color: #667eea;
  line-height: 1;
}

.stat-label {
  font-size: 9px;
  color: #64748b;
  text-transform: uppercase;
}

/* Lista de buses */
.buses-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-bottom: 12px;
}

.bus-item {
  background: #f8fafc;
  border-radius: 8px;
  padding: 10px;
}

.bus-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}

.bus-icon {
  font-size: 16px;
}

.bus-info {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.bus-plate {
  font-size: 13px;
  font-weight: 600;
  color: #334155;
}

.bus-driver {
  font-size: 11px;
  color: #64748b;
}

.bus-stats {
  display: flex;
  gap: 8px;
}

.trip-count {
  font-size: 12px;
  font-weight: 600;
  color: #667eea;
  background: #e0e7ff;
  padding: 3px 8px;
  border-radius: 10px;
}

/* Progreso individual del bus */
.bus-progress {
  display: flex;
  align-items: center;
  gap: 8px;
}

.bus-progress-bar {
  flex: 1;
  height: 6px;
  background: #e2e8f0;
  border-radius: 3px;
  overflow: hidden;
}

.bus-progress-fill {
  height: 100%;
  transition: width 0.5s ease-in-out, background-color 0.3s;
}

.bus-progress-text {
  font-size: 11px;
  font-weight: 600;
  color: #64748b;
  min-width: 35px;
  text-align: right;
}

.more-buses {
  text-align: center;
  font-size: 11px;
  color: #64748b;
  padding: 8px;
  background: white;
  border-radius: 6px;
  border: 1px dashed #cbd5e1;
}

.card-actions {
  display: flex;
  gap: 8px;
  padding-top: 12px;
  border-top: 1px solid #e2e8f0;
}

.card-action-btn {
  flex: 1;
  padding: 8px;
  border: none;
  background: #f1f5f9;
  color: #475569;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.card-action-btn:hover {
  background: #667eea;
  color: white;
}

.empty-state-card {
  text-align: center;
  padding: 60px 20px;
  background: white;
  border-radius: 12px;
  border: 2px dashed #e2e8f0;
}

.empty-icon {
  font-size: 48px;
  margin-bottom: 12px;
}

.empty-state-card p {
  margin: 0 0 8px 0;
  font-size: 16px;
  font-weight: 600;
  color: #334155;
}

.empty-state-card small {
  color: #64748b;
  display: block;
  margin-bottom: 16px;
}

.cards-grid::-webkit-scrollbar {
  width: 8px;
}

.cards-grid::-webkit-scrollbar-track {
  background: #f1f5f9;
  border-radius: 10px;
  margin: 8px 0;
}

.cards-grid::-webkit-scrollbar-thumb {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 10px;
}

.cards-grid::-webkit-scrollbar-thumb:hover {
  background: linear-gradient(135deg, #5a67d8 0%, #6b46a1 100%);
}

@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}
</style>