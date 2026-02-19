<template>
  <div v-if="isOpen" class="modal-overlay" @click="closeModal">
    <div class="modal-container shifts-modal" @click.stop>
      <!-- Header del Modal -->
      <div class="modal-header">
        <div class="header-content">
          <h3>📅 Generador de Horarios</h3>
          <p class="header-subtitle">Asigna buses a los viajes arrastrándolos</p>
        </div>
        <button class="close-btn" @click="closeModal">✕</button>
      </div>

      <!-- Contenido Principal -->
      <div class="modal-body">
        <div class="shifts-layout">
          <!-- Panel Lateral: Buses Disponibles -->
          <aside class="available-buses-panel">
            <h4 class="panel-title">🚌 Buses Disponibles</h4>
            <div class="buses-list">
              <div
                v-for="bus in availableBuses"
                :key="bus.plate_number"
                class="bus-card"
                draggable="true"
                @dragstart="handleDragStart($event, bus)"
              >
                <div class="bus-info">
                  <p class="bus-id">{{ bus.amb_code }}</p>
                  <p class="bus-plate">Placa: {{ bus.plate_number }}</p>
                  <p class="bus-driver">Conductor: {{ getDriverName(bus.id_user) }}</p>
                  <span class="bus-status" :class="bus.is_active ? 'active' : 'inactive'">
                    {{ bus.is_active ? 'Disponible' : 'Ocupado' }}
                  </span>
                </div>
              </div>
              <div v-if="availableBuses.length === 0" class="no-buses">
                No hay buses disponibles
              </div>
            </div>
          </aside>

          <!-- Área Principal -->
          <main class="main-content">
            <!-- Controles -->
            <div class="route-controls">
              <div class="controls-row">
                <!-- Ruta Info -->
                <div class="control-group">
                  <label>Ruta</label>
                  <div class="info-badge route-badge">
                    <span class="badge-icon">🛣️</span>
                    <span class="badge-text">{{ selectedRouteName }}</span>
                  </div>
                </div>

                <!-- Fecha Info -->
                <div class="control-group">
                  <label>Fecha</label>
                  <div class="info-badge date-badge">
                    <span class="badge-icon">📅</span>
                    <span class="badge-text">{{ formattedSelectedDate }}</span>
                  </div>
                </div>

                <!-- Botones de acción -->
                <div class="control-group actions-group">
                  <label>&nbsp;</label>
                  <div class="action-buttons">
                    <button
                      @click="generateSchedule"
                      class="generate-btn"
                    >
                      ✨ Generar
                    </button>
                    <button @click="clearSchedule" class="clear-btn" title="Limpiar Horario">
                      🗑️
                    </button>
                  </div>
                </div>
              </div>
            </div>

            <!-- Lista de Viajes -->
            <div class="trips-container">
              <div class="trips-header">
                <div class="header-cell">ID</div>
                <div class="header-cell">VEHÍCULO</div>
                <div class="header-cell">HORA INICIO</div>
                <div class="header-cell">FRECUENCIA</div>
                <div class="header-cell">HORA FIN</div>
                <div class="header-cell">DURACIÓN</div>
                <div class="header-cell">ESTADO</div>
              </div>

              <div class="trips-list">
                <!-- Iterar por viajes filtrados -->
                <div
                  v-for="trip in filteredTrips"
                  :key="trip.id"
                  class="trip-row"
                  :class="{ 'assigned': trip.busId, 'drag-over': trip.isDragOver }"
                  :style="{ backgroundColor: trip.batchColor }"
                  @dragover="handleDragOver($event, trip)"
                  @dragleave="handleDragLeave($event, trip)"
                  @drop="handleDrop($event, trip)"
                >
                    <div class="trip-cell id-cell">
                      <div class="id-container">
                        <span class="trip-id">{{ trip.tripNumber }}</span>
                        <span v-if="trip.fromDatabase" class="db-id">#{{ trip.id }}</span>
                        <span v-else class="new-badge">NUEVO</span>
                      </div>
                    </div>
                    <div class="trip-cell vehicle-cell">
                      <template v-if="trip.busId">
                        <button
                          @click="unassignBus(trip)"
                          class="unassign-btn"
                          title="Quitar asignación"
                        >
                          ✕
                        </button>
                        <div class="assigned-bus">
                          <span class="bus-plate-text">{{ getBusPlate(trip.busId) }}</span>
                          <span class="driver-name">({{ getDriverNameForBus(trip.busId) }})</span>
                        </div>
                      </template>
                      <template v-else>
                        <span class="drop-placeholder">Arrastra un bus aquí...</span>
                      </template>
                    </div>
                    <div class="trip-cell" @dblclick="startEditingTime(trip, 'start')">
                      <template v-if="isEditingTrip(trip.id, 'start')">
                        <input
                          v-model="editingValue"
                          type="time"
                          class="time-input"
                          @blur="onTimeInputBlur"
                          @keyup.enter="finishEditingTime(trip)"
                          @keyup.escape="cancelEditingTime"
                        />
                      </template>
                      <template v-else>
                        {{ trip.startTime }}
                      </template>
                    </div>
                    <div class="trip-cell frequency-cell">
                      <span class="frequency-badge">{{ getFrequencyFromPrevious(trip) }}</span>
                    </div>
                    <div class="trip-cell" @dblclick="startEditingTime(trip, 'end')">
                      <template v-if="isEditingTrip(trip.id, 'end')">
                        <input
                          v-model="editingValue"
                          type="time"
                          class="time-input"
                          @blur="onTimeInputBlur"
                          @keyup.enter="finishEditingTime(trip)"
                          @keyup.escape="cancelEditingTime"
                        />
                      </template>
                      <template v-else>
                        {{ trip.endTime }}
                      </template>
                    </div>
                    <div class="trip-cell duration-cell">
                      <span class="duration-badge">{{ trip.duration }} min</span>
                    </div>
                    <div class="trip-cell status-cell">
                      <span class="status-badge" :class="trip.busId ? 'assigned' : 'unassigned'">
                        {{ trip.busId ? 'Asignado' : 'No Asignado' }}
                      </span>
                    </div>
                    <!-- Botones flotantes para insertar y borrar viaje -->
                    <button
                      @click="insertTripAfter(trip)"
                      class="insert-trip-btn"
                      title="Insertar viaje después"
                    >
                      +
                    </button>
                    <button
                      @click="deleteTrip(trip)"
                      class="delete-trip-btn"
                      title="Eliminar viaje"
                    >
                      🗑️
                    </button>
                  </div>

                <!-- Empty state -->
                <div v-if="filteredTrips.length === 0" class="no-trips">
                  <p>No hay viajes generados para esta ruta.</p>
                  <p>Selecciona una ruta y haz clic en "Generar" para crear el horario.</p>
                </div>

                <!-- Espaciador al final -->
                <div v-if="filteredTrips.length > 0" class="trips-list-spacer"></div>
              </div>
            </div>
          </main>
        </div>
      </div>



      <!-- Footer del Modal -->
      <div class="modal-footer">
        <div class="footer-stats">
          <span class="stat-item">
            <strong>{{ filteredTrips.length }}</strong> viajes
          </span>
          <span class="stat-item">
            <strong>{{ assignedTripsCount }}</strong> asignados
          </span>
        </div>
        <div class="footer-actions">
          <button class="btn btn-secondary" @click="closeModal" :disabled="isSaving">Cerrar</button>
          <button 
            class="btn btn-primary" 
            @click="saveSchedule"
            :disabled="filteredTrips.length === 0 || isSaving"
          >
            <span v-if="isSaving">⏳ Guardando...</span>
            <span v-else>💾 Guardar Horario</span>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, nextTick } from 'vue'
import { useDriversStore } from '../../stores/drivers'
import { useBusesStore } from '../../stores/buses'
import { useRoutesStore } from '../../stores/routes'
import { useTripsStore } from '../../stores/trips'
import { updateTrip, deleteTrip as deleteTripAPI } from '../../api/trips'
import { SYSTEM_USER_ID } from '../../constants/system'

const props = defineProps({
  isOpen: {
    type: Boolean,
    default: false
  },
  initialRouteId: {
    type: String,
    default: ''
  },
  initialDate: {
    type: [Date, String],
    default: null
  }
})

const emit = defineEmits(['close', 'save'])

const driversStore = useDriversStore()
const busesStore = useBusesStore()
const routesStore = useRoutesStore()
const tripsStore = useTripsStore()

// Estado reactivo
const trips = ref([])
const deletedTripIds = ref([])  // IDs de viajes eliminados (de BD)
const isSaving = ref(false)
const saveError = ref(null)
let draggedBusId = null

// Estado para edición de horas
const editingTripId = ref(null)
const editingField = ref(null)
const editingValue = ref('')
const timeInputRef = ref(null)

// Colores para lotes de viajes
const batchColors = [
  { color: '#dbeafe', icon: '🔵' },
  { color: '#fef3c7', icon: '🟡' },
  { color: '#d1fae5', icon: '🟢' },
  { color: '#fce7f3', icon: '🔴' },
  { color: '#e0e7ff', icon: '🟣' },
  { color: '#fed7aa', icon: '🟠' },
  { color: '#e9d5ff', icon: '🟣' },
  { color: '#ccfbf1', icon: '🔷' },
]

// Watch para cargar datos cuando se abre el modal
watch(() => props.isOpen, async (newVal) => {
  if (newVal) {
    // Limpiar viajes anteriores al abrir el modal
    trips.value = []
    deletedTripIds.value = []  // Limpiar IDs de viajes eliminados
    // No esperar a loadData para no bloquear la renderización del modal
    loadData().catch(error => {
      console.error('Error en loadData:', error)
    })
  }
}, { immediate: true })

// Watch para limpiar viajes cuando cambia la ruta o fecha
watch([() => props.initialRouteId, () => props.initialDate], async ([newRouteId, newDate], [oldRouteId, oldDate]) => {
  // Solo actuar si el modal está abierto y realmente cambió algo
  if (props.isOpen && (newRouteId !== oldRouteId || String(newDate) !== String(oldDate))) {
    console.log('📅 Ruta o fecha cambió, recargando viajes...')
    trips.value = []
    
    // Cargar viajes existentes de la BD para la nueva combinación
    if (newRouteId && newDate) {
      await loadExistingTrips()
    }
  }
})

// Cargar datos
const loadData = async () => {
  try {
    // Usar Promise.race para evitar esperas infinitas
    const timeout = new Promise((_, reject) => 
      setTimeout(() => reject(new Error('Timeout cargando datos')), 8000)
    )
    
    await Promise.race([
      Promise.all([
        busesStore.fetchBuses(),
        driversStore.fetchDrivers(),
        routesStore.loadRoutes()
      ]),
      timeout
    ])
    
    // Cargar viajes existentes de la BD si hay ruta y fecha
    if (props.initialRouteId && props.initialDate) {
      await loadExistingTrips()
    }
  } catch (error) {
    console.error('Error cargando datos:', error)
    // Continuar sin bloquear aunque falle
  }
}

// Cargar viajes existentes de la base de datos
const loadExistingTrips = async () => {
  try {
    const tripDate = typeof props.initialDate === 'string' 
      ? props.initialDate.split('T')[0]
      : props.initialDate.toISOString().split('T')[0]
    
    // initialRouteId ahora es numérico, usarlo directamente
    const numericRouteId = props.initialRouteId
    
    if (!numericRouteId) {
      console.log('⚠️ No se recibió ID de ruta:', props.initialRouteId)
      return
    }
    
    console.log(`🔍 Buscando viajes para ruta ${numericRouteId} en fecha ${tripDate}`)
    
    const existingTrips = await tripsStore.fetchTripsByRouteAndDate(numericRouteId, tripDate)
    
    console.log('🔍 Viajes recibidos de BD:', existingTrips)
    
    if (existingTrips.length > 0) {
      // Convertir formato BD a formato frontend
      const convertedTrips = existingTrips.map((trip, index) => {
        console.log(`  Viaje ${index}: id_trip=${trip.id_trip}, start=${trip.start_time}`)
        return {
          id: trip.id_trip,
          tripNumber: index + 1,
          routeId: props.initialRouteId,  // ID numérico de la ruta
          busId: trip.plate_number || null,
          startTime: trip.start_time.substring(0, 5),  // "08:30:00" -> "08:30"
          endTime: trip.end_time.substring(0, 5),
          duration: calculateDuration(trip.start_time, trip.end_time),
          status: trip.plate_number ? 'Asignado' : 'No Asignado',
          isDragOver: false,
          batch: 'LOTE 1',  // TODO: calcular desde horarios
          batchColor: batchColors[0].color,
          batchIcon: batchColors[0].icon,
          batchNumber: 1,
          isEditing: false,
          editingField: null,
          tempStartTime: null,
          tempEndTime: null,
          // Indicador de que viene de BD
          fromDatabase: true,
          modified: false  // No modificado inicialmente
        }
      })
      
      trips.value = convertedTrips
      console.log(`✅ Cargados ${existingTrips.length} viajes existentes de la BD`)
    } else {
      console.log('📭 No hay viajes existentes para esta ruta/fecha')
    }
  } catch (error) {
    console.error('Error cargando viajes existentes:', error)
  }
}

// Cerrar modal
const closeModal = () => {
  emit('close')
}

// Computed para mostrar datos del modal (read-only desde props)
const selectedDate = computed(() => {
  if (props.initialDate) {
    if (props.initialDate instanceof Date) {
      return props.initialDate
    }
    if (typeof props.initialDate === 'string') {
      const parsed = new Date(props.initialDate + 'T00:00:00')
      return isNaN(parsed.getTime()) ? new Date() : parsed
    }
  }
  return new Date()
})

const selectedRouteId = computed(() => props.initialRouteId)

const selectedRouteName = computed(() => {
  const route = routesList.value.find(r => r.id === selectedRouteId.value)
  return route ? route.name : 'Sin seleccionar'
})

const formattedSelectedDate = computed(() => {
  const days = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado']
  const d = selectedDate.value
  if (!(d instanceof Date) || isNaN(d.getTime())) {
    return 'Fecha no válida'
  }
  return `${days[d.getDay()]}, ${d.getDate()}/${d.getMonth() + 1}/${d.getFullYear()}`
})



// Computed properties
const routesList = computed(() => routesStore.routesList)
const availableBuses = computed(() => busesStore.buses.filter(bus => bus.is_active && !isBusAssigned(bus.plate_number)))
const filteredTrips = computed(() => {
  if (!selectedRouteId.value) return []
  return trips.value.filter(trip => trip.routeId === selectedRouteId.value)
})

const assignedTripsCount = computed(() => {
  return filteredTrips.value.filter(trip => trip.busId).length
})

// Agrupar viajes por recorrido
const groupedTrips = computed(() => {
  const grouped = {}
  filteredTrips.value.forEach(trip => {
    if (!grouped[trip.batchNumber]) {
      grouped[trip.batchNumber] = []
    }
    grouped[trip.batchNumber].push(trip)
  })
  return grouped
})

// Métodos auxiliares
const isBusAssigned = (plateNumber) => {
  return trips.value.some(trip => trip.busId === plateNumber)
}

const getBusPlate = (plateNumber) => {
  return plateNumber || 'N/A'
}

const getDriverName = (driverId) => {
  if (!driverId) return 'Sin asignar'
  const driver = driversStore.drivers.find(d => d.id_user === driverId)
  return driver ? driver.name_driver : 'Desconocido'
}

const getDriverNameForBus = (plateNumber) => {
  const bus = busesStore.buses.find(b => b.plate_number === plateNumber)
  return bus ? getDriverName(bus.id_user) : 'N/A'
}

const setBusAvailability = (plateNumber, isAvailable) => {
  const bus = busesStore.buses.find(b => b.plate_number === plateNumber)
  if (bus) {
    bus.is_active = isAvailable
  }
}

// Drag and Drop
const handleDragStart = (event, bus) => {
  draggedBusId = bus.plate_number
  event.target.classList.add('dragging')
}

const handleDragOver = (event, trip) => {
  event.preventDefault()
  if (!trip.busId) {
    trip.isDragOver = true
  }
}

const handleDragLeave = (event, trip) => {
  event.preventDefault()
  trip.isDragOver = false
}

const handleDrop = (event, trip) => {
  event.preventDefault()
  trip.isDragOver = false

  console.log('🎯 handleDrop - trip recibido:', { id: trip.id, tripNumber: trip.tripNumber, fromDatabase: trip.fromDatabase })

  if (draggedBusId && !trip.busId) {
    // Buscar el viaje original en trips.value para asegurar la referencia correcta
    const originalTrip = trips.value.find(t => t.id === trip.id)
    if (originalTrip) {
      console.log('🎯 originalTrip encontrado:', { id: originalTrip.id, tripNumber: originalTrip.tripNumber, fromDatabase: originalTrip.fromDatabase })
      originalTrip.busId = draggedBusId
      originalTrip.status = 'Asignado'
      // Marcar como modificado si viene de BD
      if (originalTrip.fromDatabase) {
        originalTrip.modified = true
        console.log(`✅ Viaje ${originalTrip.id} marcado como modificado`)
      }
      setBusAvailability(draggedBusId, false)
      checkBatchCompletion(originalTrip.batchNumber)
    }
  }

  draggedBusId = null
  document.querySelectorAll('.bus-card.dragging').forEach(card => {
    card.classList.remove('dragging')
  })
}

const checkBatchCompletion = (batchNumber) => {
  const batchTrips = trips.value.filter(trip => trip.batchNumber === batchNumber)
  const allAssigned = batchTrips.every(trip => trip.busId)

  if (allAssigned && batchTrips.length > 0) {
    const batchName = batchTrips[0].batch
    console.log(`✅ ${batchName} completado - Liberando buses...`)
    batchTrips.forEach(trip => {
      setBusAvailability(trip.busId, true)
    })
  }
}

// Generación de horarios
const generateSchedule = () => {
  if (!selectedRouteId.value) {
    alert('Por favor, selecciona una ruta primero.')
    return
  }

  const route = routesList.value.find(r => r.id === selectedRouteId.value)
  
  if (!route) {
    alert('No se encontró la ruta seleccionada.')
    return
  }

  const defaultDuration = 60
  const defaultFrequency = 15

  const startTimeStr = prompt("Hora de inicio (HH:mm):", "06:00")
  if (!startTimeStr) return

  // ✅ VALIDACIÓN: Comparar con el último viaje de la ruta
  const routeTrips = trips.value.filter(trip => trip.routeId === selectedRouteId.value)
  if (routeTrips.length > 0) {
    // Encontrar el viaje con la hora de inicio más tardía
    const lastTripStartTime = routeTrips.reduce((latest, current) => {
      return timeToMinutes(current.startTime) > timeToMinutes(latest.startTime) ? current : latest
    }).startTime
    
    const newStartMinutes = timeToMinutes(startTimeStr)
    const lastStartMinutes = timeToMinutes(lastTripStartTime)
    
    if (newStartMinutes <= lastStartMinutes) {
      alert(`❌ La hora de inicio del nuevo lote (${startTimeStr}) debe ser superior a la del último viaje (${lastTripStartTime}).\n\nDebe ser mayor que: ${lastTripStartTime}`)
      return
    }
  }

  const endTimeStr = prompt("Hora de fin (HH:mm):", "08:00")
  if (!endTimeStr) return

  const frequency = parseInt(prompt("Frecuencia (minutos):", defaultFrequency.toString()))
  if (!frequency || frequency <= 0) {
    alert('La frecuencia debe ser un número positivo.')
    return
  }

  const duration = parseInt(prompt("Duración del viaje (minutos):", defaultDuration.toString()))
  if (!duration || duration <= 0) {
    alert('La duración debe ser un número positivo.')
    return
  }

  const nextBatchNumber = getNextBatchNumber(selectedRouteId.value)
  generateTrips(selectedRouteId.value, startTimeStr, endTimeStr, frequency, duration, nextBatchNumber)
}

const getNextBatchNumber = (routeId) => {
  const existingBatches = trips.value
    .filter(trip => trip.routeId === routeId)
    .map(trip => trip.batchNumber)
  
  if (existingBatches.length === 0) {
    return 1
  }
  
  return Math.max(...existingBatches) + 1
}

const generateTrips = (routeId, startTimeStr, endTimeStr, frequency, duration, batchNumber) => {
  const timeRegex = /^([0-1]?[0-9]|2[0-3]):([0-5][0-9])$/
  if (!timeRegex.test(startTimeStr) || !timeRegex.test(endTimeStr)) {
    alert('Formato de hora inválido. Usa HH:mm (ejemplo: 08:30)')
    return
  }

  const [startH, startM] = startTimeStr.split(':').map(Number)
  const [endH, endM] = endTimeStr.split(':').map(Number)

  let currentTime = new Date()
  currentTime.setHours(startH, startM, 0, 0)

  const operationEndTime = new Date()
  operationEndTime.setHours(endH, endM, 0, 0)

  if (operationEndTime <= currentTime) {
    alert('La hora de fin debe ser posterior a la hora de inicio.')
    return
  }

  const newTrips = []
  
  // Encontrar el ID más alto actual para continuar la secuencia
  const maxId = trips.value.length > 0 
    ? Math.max(...trips.value.map(trip => trip.id)) 
    : 0
  let tripCount = maxId

  const colorIndex = (batchNumber - 1) % batchColors.length
  const batchColor = batchColors[colorIndex]

  while (currentTime <= operationEndTime) {
    const tripStartTime = new Date(currentTime)
    const tripEndTime = new Date(tripStartTime.getTime() + duration * 60000)
    
    // Número secuencial que continúa desde el lote anterior
    tripCount++
    const sequentialNumber = tripCount

    newTrips.push({
      id: sequentialNumber,
      tripNumber: sequentialNumber,
      routeId: routeId,
      busId: null,
      startTime: tripStartTime.toLocaleTimeString('es-CO', {hour: '2-digit', minute:'2-digit', hour12: false}),
      endTime: tripEndTime.toLocaleTimeString('es-CO', {hour: '2-digit', minute:'2-digit', hour12: false}),
      duration: duration,
      status: 'No Asignado',
      isDragOver: false,
      batch: `LOTE ${batchNumber}`,
      batchColor: batchColor.color,
      batchIcon: batchColor.icon,
      batchNumber: batchNumber,
      // Propiedades para edición inline
      isEditing: false,
      editingField: null,
      tempStartTime: null,
      tempEndTime: null,
      // Indicar que es nuevo (no viene de BD)
      fromDatabase: false,
      modified: false
    })

    currentTime.setMinutes(currentTime.getMinutes() + frequency)
  }

  const tripCountGenerated = newTrips.length
  trips.value = [...trips.value, ...newTrips]
  alert(`Se creó el Lote ${batchNumber} con ${tripCountGenerated} viajes.`)
}

const clearSchedule = () => {
  if (!selectedRouteId.value) {
    alert('Selecciona una ruta primero.')
    return
  }

  const tripsToDelete = trips.value.filter(trip => trip.routeId === selectedRouteId.value)
  
  if (tripsToDelete.length === 0) {
    alert('No hay viajes para eliminar en esta ruta.')
    return
  }

  if (confirm(`¿Estás seguro de que quieres borrar ${tripsToDelete.length} viajes para esta ruta?`)) {
    tripsToDelete
      .filter(trip => trip.busId)
      .forEach(trip => {
        setBusAvailability(trip.busId, true)
      })

    trips.value = trips.value.filter(trip => trip.routeId !== selectedRouteId.value)
    alert('Viajes eliminados correctamente.')
  }
}

const unassignBus = (trip) => {
  console.log('🔍 unassignBus llamado con:', { tripId: trip.id, busId: trip.busId })
  
  // Buscar el viaje original en trips.value
  const originalTrip = trips.value.find(t => t.id === trip.id)
  console.log('🔍 Viaje original encontrado:', originalTrip ? { id: originalTrip.id, busId: originalTrip.busId } : 'NO ENCONTRADO')
  
  if (originalTrip && originalTrip.busId) {
    const oldBusId = originalTrip.busId
    setBusAvailability(oldBusId, true)
    originalTrip.busId = null
    originalTrip.status = 'No Asignado'
    // Marcar como modificado si viene de BD
    if (originalTrip.fromDatabase) {
      originalTrip.modified = true
    }
    console.log(`🚌 Bus ${oldBusId} desasignado del viaje ${trip.id}. Nuevo busId:`, originalTrip.busId)
  } else {
    console.log('⚠️ No se pudo desasignar: originalTrip o busId no existe')
  }
}

// Edición de horas
const startEditingTime = async (trip, field) => {
  // Si ya estamos editando, cancelar primero
  if (editingTripId.value !== null) {
    cancelEditingTime()
  }
  
  editingTripId.value = trip.id
  editingField.value = field
  editingValue.value = field === 'start' ? trip.startTime : trip.endTime
  console.log(`📝 Editando ${field} del viaje ${trip.id}: ${editingValue.value}`)
  
  // Esperar al siguiente tick para que el input se renderice
  await nextTick()
  
  // Enfocar el input
  const input = document.querySelector('.time-input')
  if (input) {
    input.focus()
    input.select()
  }
}

// Verificar si un viaje está en modo edición
const isEditingTrip = (tripId, field) => {
  return editingTripId.value === tripId && editingField.value === field
}

// Handler para blur del input
const onTimeInputBlur = () => {
  // Pequeño delay para permitir que se procese el click en otro lugar
  setTimeout(() => {
    if (editingTripId.value !== null) {
      finishEditingTimeById()
    }
  }, 150)
}

// Terminar edición usando el ID guardado
const finishEditingTimeById = () => {
  if (!editingTripId.value) return
  
  const timeRegex = /^([0-1]?[0-9]|2[0-3]):([0-5][0-9])$/
  const newTime = editingValue.value
  
  console.log(`💾 Guardando ${editingField.value}: ${newTime}`)
  
  if (!timeRegex.test(newTime)) {
    alert('❌ Formato de hora inválido. Usa HH:mm')
    cancelEditingTime()
    return
  }
  
  // Buscar el viaje en el array original
  const tripIndex = trips.value.findIndex(t => t.id === editingTripId.value)
  if (tripIndex === -1) {
    console.error('❌ No se encontró el viaje')
    cancelEditingTime()
    return
  }
  
  // Validaciones de orden para hora inicio
  if (editingField.value === 'start') {
    const currentTrips = filteredTrips.value
    const filteredIndex = currentTrips.findIndex(t => t.id === editingTripId.value)
    const newStartMinutes = timeToMinutes(newTime)
    
    // Validar con el viaje anterior
    if (filteredIndex > 0) {
      const prevTrip = currentTrips[filteredIndex - 1]
      if (newStartMinutes <= timeToMinutes(prevTrip.startTime)) {
        alert(`❌ La hora inicial debe ser mayor a la del viaje anterior (${prevTrip.startTime})`)
        cancelEditingTime()
        return
      }
    }
    
    // Validar con el viaje siguiente
    if (filteredIndex < currentTrips.length - 1) {
      const nextTrip = currentTrips[filteredIndex + 1]
      if (newStartMinutes >= timeToMinutes(nextTrip.startTime)) {
        alert(`❌ La hora inicial debe ser menor a la del viaje siguiente (${nextTrip.startTime})`)
        cancelEditingTime()
        return
      }
    }
    
    // Validar que hora inicio sea menor que hora fin actual
    const currentEndTime = trips.value[tripIndex].endTime
    const endMinutes = timeToMinutes(currentEndTime)
    if (newStartMinutes >= endMinutes) {
      alert(`❌ La hora de inicio (${newTime}) debe ser menor que la hora de fin (${currentEndTime})`)
      cancelEditingTime()
      return
    }
    
    // Actualizar
    trips.value[tripIndex].startTime = newTime
    trips.value[tripIndex].duration = calculateDuration(newTime, trips.value[tripIndex].endTime)
    if (trips.value[tripIndex].fromDatabase) {
      trips.value[tripIndex].modified = true
    }
    console.log(`✅ Hora inicio actualizada: ${newTime}`)
    
  } else if (editingField.value === 'end') {
    // Validar que hora fin sea mayor que hora inicio
    const currentStartTime = trips.value[tripIndex].startTime
    const newEndMinutes = timeToMinutes(newTime)
    const startMinutes = timeToMinutes(currentStartTime)
    
    if (newEndMinutes <= startMinutes) {
      alert(`❌ La hora de fin (${newTime}) debe ser mayor que la hora de inicio (${currentStartTime})`)
      cancelEditingTime()
      return
    }
    
    // Actualizar hora fin
    trips.value[tripIndex].endTime = newTime
    trips.value[tripIndex].duration = calculateDuration(trips.value[tripIndex].startTime, newTime)
    if (trips.value[tripIndex].fromDatabase) {
      trips.value[tripIndex].modified = true
    }
    console.log(`✅ Hora fin actualizada: ${newTime}`)
  }
  
  cancelEditingTime()
}

// Calcular duración entre dos horas
const calculateDuration = (startTime, endTime) => {
  if (!startTime || !endTime) return 0
  
  const [startH, startM] = startTime.split(':').map(Number)
  const [endH, endM] = endTime.split(':').map(Number)
  
  const startMinutes = startH * 60 + startM
  const endMinutes = endH * 60 + endM
  
  let duration = endMinutes - startMinutes
  
  // Si la hora de fin es menor que la de inicio, asumir que es el día siguiente
  if (duration < 0) {
    duration += 24 * 60
  }
  
  return Math.round(duration)
}

// Método para terminar la edición (usado por Enter)
const finishEditingTime = (trip) => {
  finishEditingTimeById()
}

const cancelEditingTime = () => {
  editingTripId.value = null
  editingField.value = null
  editingValue.value = ''
}

// Renumerar los tripNumber para mantener secuencia visual continua
// IMPORTANTE: NO tocar trip.id - ese es el ID de la BD
const renumberTrips = () => {
  trips.value.forEach((trip, index) => {
    trip.tripNumber = index + 1  // Solo renumerar el número visual
    // NUNCA modificar trip.id - es el ID de la BD
  })
}

// Obtener frecuencia respecto al viaje anterior
const getFrequencyFromPrevious = (trip) => {
  const tripIndex = filteredTrips.value.findIndex(t => t.id === trip.id)
  if (tripIndex <= 0) {
    return '-'
  }
  const prevTrip = filteredTrips.value[tripIndex - 1]
  const currentMinutes = timeToMinutes(trip.startTime)
  const prevMinutes = timeToMinutes(prevTrip.startTime)
  const frequency = currentMinutes - prevMinutes
  return `${frequency > 0 ? '+' : ''}${frequency} min`
}

// Convertir tiempo HH:mm a minutos
const timeToMinutes = (timeStr) => {
  const [h, m] = timeStr.split(':').map(Number)
  return h * 60 + m
}

// Convertir minutos a formato HH:mm
const minutesToTime = (minutes) => {
  const h = Math.floor(minutes / 60)
  const m = minutes % 60
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`
}

// Insertar viajes
const insertTripBefore = (referenceTrip) => {
  const referenceIndex = trips.value.findIndex(t => t.id === referenceTrip.id)
  const previousTrip = referenceIndex > 0 ? trips.value[referenceIndex - 1] : null
  
  const newTrip = createNewTrip(referenceTrip, previousTrip, referenceTrip, 'before')
  if (referenceIndex !== -1) {
    trips.value.splice(referenceIndex, 0, newTrip)
    renumberTrips()
  }
}

const insertTripAfter = (referenceTrip) => {
  const referenceIndex = trips.value.findIndex(t => t.id === referenceTrip.id)
  const nextTrip = referenceIndex < trips.value.length - 1 ? trips.value[referenceIndex + 1] : null
  
  // Validar franja mínima entre hora inicial actual y siguiente
  if (nextTrip) {
    const currentStartMinutes = timeToMinutes(referenceTrip.startTime)
    const nextStartMinutes = timeToMinutes(nextTrip.startTime)
    const newStartMinutes = currentStartMinutes + 1
    
    if (newStartMinutes >= nextStartMinutes) {
      alert(`❌ No hay espacio suficiente.\n\nHora actual: ${referenceTrip.startTime}\nNueva hora: ${minutesToTime(newStartMinutes)}\nHora siguiente: ${nextTrip.startTime}\n\nNecesita al menos 1 minuto entre las horas iniciales.`)
      return
    }
  }
  
  const newTrip = createNewTrip(referenceTrip, referenceTrip, nextTrip, 'after')
  if (referenceIndex !== -1) {
    trips.value.splice(referenceIndex + 1, 0, newTrip)
    renumberTrips()
  }
}

const createNewTrip = (templateTrip, previousTrip = null, nextTrip = null, position = 'after') => {
  const maxId = trips.value.length > 0 
    ? Math.max(...trips.value.map(trip => trip.id)) 
    : 0
  const nextId = maxId + 1
  
  let newStartTime, newEndTime, newDuration = templateTrip.duration
  
  if (position === 'after' && previousTrip) {
    // Hora inicial = inicio del anterior + 1 minuto
    const prevStartMinutes = timeToMinutes(previousTrip.startTime)
    let newStartMinutes = prevStartMinutes + 1
    let newEndMinutes = newStartMinutes + templateTrip.duration
    
    newStartTime = minutesToTime(newStartMinutes)
    newEndTime = minutesToTime(newEndMinutes)
  } else if (position === 'before' && nextTrip) {
    // Hora inicial debe ser menor a la del siguiente
    const nextStartMinutes = timeToMinutes(nextTrip.startTime)
    let newStartMinutes = nextStartMinutes - templateTrip.duration - 1
    let newEndMinutes = newStartMinutes + templateTrip.duration
    
    // Validar que no se solape con el anterior
    if (previousTrip) {
      const prevEndMinutes = timeToMinutes(previousTrip.endTime)
      if (newStartMinutes < prevEndMinutes + 1) {
        // Ajustar: hora inicial = fin del anterior + 1 minuto
        newStartMinutes = prevEndMinutes + 1
        newDuration = Math.max(15, nextStartMinutes - newStartMinutes - 1)
        newEndMinutes = newStartMinutes + newDuration
      }
    }
    
    newStartTime = minutesToTime(newStartMinutes)
    newEndTime = minutesToTime(newEndMinutes)
  } else {
    // Fallback: usar 1 minuto después del viaje anterior (o 30 min si no hay referencia)
    if (previousTrip) {
      const prevEndMinutes = timeToMinutes(previousTrip.endTime)
      const newStartMinutes = prevEndMinutes + 1
      const newEndMinutes = newStartMinutes + templateTrip.duration
      newStartTime = minutesToTime(newStartMinutes)
      newEndTime = minutesToTime(newEndMinutes)
    } else {
      const [startH, startM] = templateTrip.startTime.split(':').map(Number)
      const newDate = new Date()
      newDate.setHours(startH, startM + 30, 0, 0)
      newStartTime = newDate.toLocaleTimeString('es-CO', {hour: '2-digit', minute:'2-digit', hour12: false})
      
      const newDate2 = new Date()
      newDate2.setHours(startH, startM + 30 + templateTrip.duration, 0, 0)
      newEndTime = newDate2.toLocaleTimeString('es-CO', {hour: '2-digit', minute:'2-digit', hour12: false})
    }
  }
  
  return {
    id: nextId,
    tripNumber: nextId,  // Se recalculará después con renumberTrips()
    routeId: templateTrip.routeId,
    busId: null,
    startTime: newStartTime,
    endTime: newEndTime,
    duration: calculateDuration(newStartTime, newEndTime),
    status: 'No Asignado',
    isDragOver: false,
    batch: templateTrip.batch,
    batchColor: templateTrip.batchColor,
    batchIcon: templateTrip.batchIcon,
    batchNumber: templateTrip.batchNumber,
    isEditing: false,
    editingField: null,
    tempStartTime: null,
    tempEndTime: null,
    // Indicar que es nuevo (no viene de BD)
    fromDatabase: false,
    modified: false
  }
}

const deleteTrip = (trip) => {
  const index = trips.value.findIndex(t => t.id === trip.id)
  if (index !== -1) {
    // Si el viaje vino de la BD, agregarlo a la lista de eliminados
    if (trip.fromDatabase && trip.id) {
      deletedTripIds.value.push(trip.id)
      console.log(`🗑️ Viaje ${trip.id} marcado para eliminación`)
    }
    
    if (trip.busId) {
      setBusAvailability(trip.busId, true)
    }
    trips.value.splice(index, 1)
    renumberTrips()
  }
}

// Guardar horario en base de datos
const saveSchedule = async () => {
  if (filteredTrips.value.length === 0) {
    alert('No hay viajes para guardar.')
    return
  }

  // Validar que hay ruta seleccionada
  const routeId = selectedRouteId.value || props.initialRouteId
  if (!routeId) {
    alert('❌ Error: No hay ruta seleccionada.')
    return
  }

  isSaving.value = true
  saveError.value = null

  try {
    // Formatear fecha como YYYY-MM-DD de forma segura
    let tripDate
    
    if (typeof props.initialDate === 'string' && props.initialDate) {
      tripDate = props.initialDate.split('T')[0]
    } else if (props.initialDate instanceof Date && !isNaN(props.initialDate.getTime())) {
      tripDate = props.initialDate.toISOString().split('T')[0]
    } else {
      tripDate = new Date().toISOString().split('T')[0]
    }
    
    // El routeId ahora es directamente numérico
    const numericRouteId = routeId
    
    if (!numericRouteId) {
      alert(`❌ Error: No se recibió ID de ruta válido.`)
      isSaving.value = false
      return
    }
    
    // Separar viajes: modificados de BD vs nuevos vs eliminados
    const modifiedTrips = filteredTrips.value.filter(trip => trip.fromDatabase && trip.modified)
    const newTrips = filteredTrips.value.filter(trip => !trip.fromDatabase)
    const deletedIds = deletedTripIds.value
    
    console.log(`📤 Guardando: ${modifiedTrips.length} modificados, ${newTrips.length} nuevos, ${deletedIds.length} eliminados`)
    
    let updatedCount = 0
    let createdCount = 0
    let deletedCount = 0
    let errors = []
    
    // 1. Actualizar solo viajes que fueron modificados
    if (modifiedTrips.length > 0) {
      console.log('🔄 Actualizando viajes modificados...')
      
      for (const trip of modifiedTrips) {
        try {
          // Usar updateTrip para actualizar hora inicio, hora fin y bus
          // NOTA: Para desasignar bus, enviar '' (string vacío), no null
          // porque el stored procedure interpreta null como "no cambiar"
          const updateData = {
            user_update: SYSTEM_USER_ID,
            start_time: trip.startTime + ':00',
            end_time: trip.endTime + ':00',
            plate_number: trip.busId || ''  // String vacío para desasignar
          }
          
          console.log(`📤 Actualizando viaje ${trip.id}:`, updateData)
          
          const result = await updateTrip(trip.id, updateData)
          
          if (result.success) {
            updatedCount++
            console.log(`✅ Viaje ${trip.id} actualizado`)
          } else {
            console.warn(`⚠️ Viaje ${trip.id}: ${result.msg}`)
            errors.push(`Viaje ${trip.tripNumber}: ${result.msg}`)
          }
        } catch (error) {
          // Capturar el mensaje de respuesta del servidor
          const errorMsg = error.response?.data?.msg || error.message
          console.error(`Error actualizando viaje ${trip.id}:`, error.response?.data || error)
          errors.push(`Viaje ${trip.tripNumber}: ${errorMsg}`)
        }
      }
    }
    
    // 2. Eliminar viajes marcados para eliminación
    if (deletedIds.length > 0) {
      console.log('🗑️ Eliminando viajes...')
      
      for (const tripId of deletedIds) {
        try {
          const result = await deleteTripAPI(tripId)
          if (result.success) {
            deletedCount++
            console.log(`✅ Viaje ${tripId} eliminado`)
          } else {
            console.warn(`⚠️ No se pudo eliminar viaje ${tripId}: ${result.msg}`)
            errors.push(`Eliminación de viaje ${tripId}: ${result.msg}`)
          }
        } catch (error) {
          const errorMsg = error.response?.data?.msg || error.message
          console.error(`Error eliminando viaje ${tripId}:`, error.response?.data || error)
          errors.push(`Error eliminando viaje ${tripId}: ${errorMsg}`)
        }
      }
      
      // Limpiar array de eliminados después de procesarlos
      deletedTripIds.value = []
    }
    
    // 3. Crear viajes nuevos
    if (newTrips.length > 0) {
      console.log('➕ Creando viajes nuevos...')
      
      const tripsToCreate = newTrips.map(trip => ({
        start_time: trip.startTime + ':00',
        end_time: trip.endTime + ':00',
        plate_number: trip.busId || null
      }))

      const result = await tripsStore.createTripsBatch({
        id_route: numericRouteId,
        trip_date: tripDate,
        trips: tripsToCreate,
        user_create: SYSTEM_USER_ID
      })

      if (result.success) {
        createdCount = result.trips_created || newTrips.length
      } else {
        errors.push(result.msg)
      }
    }
    
    // Mostrar resultado
    if (errors.length === 0) {
      let msg = '✅ Horario guardado exitosamente\n'
      if (updatedCount > 0) msg += `• ${updatedCount} viajes actualizados\n`
      if (deletedCount > 0) msg += `• ${deletedCount} viajes eliminados\n`
      if (createdCount > 0) msg += `• ${createdCount} viajes creados`
      
      // Invalidar caché para que se recarguen los datos actualizados
      tripsStore.invalidateCache(numericRouteId, tripDate)
      
      alert(msg)
      emit('save', { date: tripDate, routeId: selectedRouteId.value })
      closeModal()
    } else {
      // Invalidar caché también en caso de errores parciales
      // porque algunos cambios sí se aplicaron
      tripsStore.invalidateCache(numericRouteId, tripDate)
      
      alert(`⚠️ Guardado parcial:\n• ${updatedCount} actualizados\n• ${deletedCount} eliminados\n• ${createdCount} creados\n\nErrores:\n${errors.join('\n')}`)
    }
    
  } catch (error) {
    console.error('Error guardando horario:', error)
    saveError.value = error.response?.data?.msg || error.message
    alert(`❌ Error al guardar: ${saveError.value}`)
  } finally {
    isSaving.value = false
  }
}

// Cleanup — no global listeners to remove
</script>

<style scoped>
/* ========================================
   MODAL BASE STYLES
   ======================================== */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 20px;
  backdrop-filter: blur(4px);
}

.modal-container.shifts-modal {
  background: white;
  border-radius: 16px;
  width: 95vw;
  max-width: 1400px;
  height: 90vh;
  max-height: 900px;
  display: flex;
  flex-direction: column;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
  overflow: hidden;
}

/* Modal Header */
.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 20px 24px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
}

.header-content h3 {
  margin: 0;
  font-size: 22px;
  font-weight: 700;
}

.header-subtitle {
  margin: 4px 0 0;
  font-size: 14px;
  opacity: 0.9;
}

.close-btn {
  background: rgba(255, 255, 255, 0.2);
  border: none;
  color: white;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  font-size: 18px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.close-btn:hover {
  background: rgba(255, 255, 255, 0.3);
  transform: scale(1.1);
}

/* Modal Body */
.modal-body {
  flex: 1;
  overflow: hidden;
  display: flex;
}

.shifts-layout {
  display: flex;
  width: 100%;
  height: 100%;
}

/* Panel Lateral: Buses Disponibles */
.available-buses-panel {
  width: 280px;
  background: #f8fafc;
  padding: 20px;
  border-right: 1px solid #e2e8f0;
  display: flex;
  flex-direction: column;
  flex-shrink: 0;
}

.panel-title {
  font-size: 16px;
  font-weight: 700;
  color: #1e293b;
  margin: 0 0 16px 0;
}

.buses-list {
  flex: 1;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding-right: 8px;
}

.bus-card {
  background: white;
  padding: 14px;
  border-radius: 10px;
  cursor: grab;
  border: 2px solid transparent;
  transition: all 0.2s ease;
  user-select: none;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.bus-card:hover {
  border-color: #667eea;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.bus-card.dragging {
  opacity: 0.5;
  transform: rotate(3deg) scale(1.05);
  background: #dbeafe;
}

.bus-info p {
  margin: 0 0 4px 0;
  font-size: 13px;
  color: #374151;
}

.bus-id {
  font-weight: 700;
  color: #1e293b;
  font-size: 14px;
}

.bus-plate {
  font-size: 12px;
  color: #64748b;
}

.bus-driver {
  font-size: 12px;
  color: #6b7280;
}

.bus-status {
  display: inline-block;
  font-size: 11px;
  font-weight: 600;
  padding: 3px 8px;
  border-radius: 10px;
  text-transform: uppercase;
  margin-top: 6px;
}

.bus-status.active {
  background: rgba(16, 185, 129, 0.1);
  color: #10b981;
}

.bus-status.inactive {
  background: rgba(239, 68, 68, 0.1);
  color: #ef4444;
}

.no-buses {
  text-align: center;
  color: #9ca3af;
  font-style: italic;
  padding: 30px 10px;
  font-size: 13px;
}

/* Contenido Principal */
.main-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  min-width: 0;
}

/* Controles de Ruta */
.route-controls {
  background: white;
  border-bottom: 1px solid #e2e8f0;
  padding: 16px 20px;
  flex-shrink: 0;
}

.controls-row {
  display: flex;
  gap: 20px;
  align-items: flex-end;
  flex-wrap: wrap;
}

.control-group {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.control-group label {
  font-weight: 600;
  color: #374151;
  font-size: 13px;
}

.info-badge {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  background: #f1f5f9;
  border: 2px solid #e5e7eb;
  border-radius: 8px;
  font-size: 14px;
  color: #1e293b;
  min-width: 200px;
  font-weight: 500;
}

.info-badge .badge-icon {
  font-size: 16px;
}

.info-badge .badge-text {
  flex: 1;
}

.route-badge {
  border-color: #dbeafe;
  background: rgba(219, 234, 254, 0.5);
}

.date-badge {
  border-color: #fce7f3;
  background: rgba(252, 231, 243, 0.5);
}

.route-select {
  padding: 10px 14px;
  border: 2px solid #e5e7eb;
  border-radius: 8px;
  font-size: 14px;
  background: white;
  min-width: 200px;
  transition: all 0.2s ease;
}

.route-select:focus {
  outline: none;
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.action-buttons {
  display: flex;
  gap: 8px;
}

.generate-btn,
.clear-btn {
  padding: 10px 16px;
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  gap: 6px;
}

.generate-btn {
  background: #667eea;
  color: white;
}

.generate-btn:hover:not(:disabled) {
  background: #5a67d8;
  transform: translateY(-1px);
}

.generate-btn:disabled {
  background: #d1d5db;
  cursor: not-allowed;
}

.clear-btn {
  background: #ef4444;
  color: white;
}

.clear-btn:hover {
  background: #dc2626;
}

/* Lista de Viajes */
.trips-container {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  --trips-grid: 0.8fr 2fr 1fr 0.8fr 1fr 0.8fr 1.5fr;
}

.trips-header {
  display: grid;
  grid-template-columns: var(--trips-grid);
  gap: 16px;
  padding: 12px 20px;
  background: #f1f5f9;
  border-bottom: 2px solid #e2e8f0;
  font-weight: 600;
  font-size: 11px;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  flex-shrink: 0;
}

.trips-list {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
}

.trip-row {
  display: grid;
  grid-template-columns: var(--trips-grid);
  gap: 16px;
  padding: 14px 20px;
  border-bottom: 1px solid #f1f5f9;
  transition: all 0.2s ease;
  align-items: center;
  position: relative;
}

.trip-row.assigned {
  background: rgba(16, 185, 129, 0.03);
}

.trip-row.drag-over {
  border-color: #3b82f6;
  background: #eff6ff !important;
  transform: scale(1.01);
}

.trip-row:hover {
  filter: brightness(0.97);
}

.trip-cell {
  font-size: 14px;
  color: #374151;
}

.id-cell {
  display: flex;
  align-items: center;
  justify-content: center;
}

.id-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
}

.trip-id {
  font-weight: 700;
  color: #667eea;
  font-size: 13px;
  padding: 4px 8px;
  background: rgba(102, 126, 234, 0.1);
  border-radius: 4px;
}

.db-id {
  font-size: 9px;
  color: #9ca3af;
  font-weight: 400;
}

.new-badge {
  font-size: 8px;
  color: #10b981;
  background: rgba(16, 185, 129, 0.1);
  padding: 1px 4px;
  border-radius: 3px;
  font-weight: 600;
}

.vehicle-cell {
  font-weight: 500;
  display: flex;
  align-items: center;
  gap: 8px;
}

.duration-cell {
  display: flex;
  align-items: center;
  justify-content: center;
}

.duration-badge {
  padding: 5px 10px;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 600;
  background: rgba(59, 130, 246, 0.1);
  color: #3b82f6;
}

.frequency-cell {
  display: flex;
  align-items: center;
  justify-content: center;
}

.frequency-badge {
  padding: 5px 10px;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 600;
  background: rgba(168, 85, 247, 0.1);
  color: #a855f7;
}

.assigned-bus {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.bus-plate-text {
  font-weight: 700;
  color: #1e293b;
  font-size: 14px;
}

.driver-name {
  font-size: 12px;
  color: #6b7280;
}

.drop-placeholder {
  color: #9ca3af;
  font-style: italic;
  font-size: 13px;
}

.status-cell {
  display: flex;
  align-items: center;
  justify-content: flex-start;
  gap: 8px;
}

.status-badge {
  padding: 5px 10px;
  border-radius: 16px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
}

.status-badge.assigned {
  background: rgba(16, 185, 129, 0.1);
  color: #10b981;
}

.status-badge.unassigned {
  background: rgba(156, 163, 175, 0.1);
  color: #6b7280;
}

.unassign-btn {
  background: #ef4444;
  color: white;
  border: none;
  border-radius: 50%;
  width: 22px;
  height: 22px;
  cursor: pointer;
  font-size: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s ease;
  opacity: 1;
  pointer-events: auto;
}

.trip-row:hover .unassign-btn {
  opacity: 1;
  pointer-events: auto;
}

.unassign-btn:hover {
  background: #dc2626;
  transform: scale(1.1);
}

.no-trips {
  text-align: center;
  padding: 50px 20px;
  color: #9ca3af;
}

.no-trips p {
  margin: 0 0 6px 0;
  font-size: 14px;
}

/* Botón Flotante para Insertar Viaje */
.insert-trip-btn {
  position: absolute;
  right: 60px;
  top: 50%;
  transform: translateY(-50%) scale(0);
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: linear-gradient(135deg, #667eea, #764ba2);
  color: white;
  border: none;
  font-size: 16px;
  font-weight: bold;
  cursor: pointer;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0;
  z-index: 20;
}

.trip-row:hover .insert-trip-btn {
  opacity: 1;
  transform: translateY(-50%) scale(1);
}

.insert-trip-btn:hover {
  transform: translateY(-50%) scale(1.15);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
}

/* Botón Flotante para Eliminar Viaje */
.delete-trip-btn {
  position: absolute;
  right: 25px;
  top: 50%;
  transform: translateY(-50%) scale(0);
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: linear-gradient(135deg, #ef4444, #dc2626);
  color: white;
  border: none;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0;
  z-index: 20;
}

.trip-row:hover .delete-trip-btn {
  opacity: 1;
  transform: translateY(-50%) scale(1);
}

.delete-trip-btn:hover {
  transform: translateY(-50%) scale(1.15);
  box-shadow: 0 4px 12px rgba(239, 68, 68, 0.4);
}


.trips-list-spacer {
  height: 100px;
}

/* Modal Footer */
.modal-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 24px;
  background: #f8fafc;
  border-top: 1px solid #e2e8f0;
}

.footer-stats {
  display: flex;
  gap: 20px;
}

.stat-item {
  font-size: 14px;
  color: #64748b;
}

.stat-item strong {
  color: #1e293b;
}

.footer-actions {
  display: flex;
  gap: 12px;
}

.btn {
  padding: 10px 20px;
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
}

.btn-secondary {
  background: #e2e8f0;
  color: #475569;
}

.btn-secondary:hover {
  background: #cbd5e1;
}

.btn-primary {
  background: #667eea;
  color: white;
}

.btn-primary:hover:not(:disabled) {
  background: #5a67d8;
}

.btn-primary:disabled {
  background: #d1d5db;
  cursor: not-allowed;
}

/* Scrollbar */
.buses-list::-webkit-scrollbar,
.trips-list::-webkit-scrollbar {
  width: 8px;
}

.buses-list::-webkit-scrollbar-track,
.trips-list::-webkit-scrollbar-track {
  background: #f1f5f9;
  border-radius: 4px;
}

.buses-list::-webkit-scrollbar-thumb,
.trips-list::-webkit-scrollbar-thumb {
  background: #cbd5e1;
  border-radius: 4px;
}

.buses-list::-webkit-scrollbar-thumb:hover,
.trips-list::-webkit-scrollbar-thumb:hover {
  background: #94a3b8;
}

/* Time Input Styling */
.time-input {
  width: 100%;
  padding: 6px 8px;
  border: 2px solid #667eea;
  border-radius: 6px;
  font-size: 14px;
  font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
  color: #1e293b;
  background: white;
  transition: all 0.2s ease;
  text-align: center;
}

.time-input:focus {
  outline: none;
  border-color: #764ba2;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.time-input:hover {
  border-color: #764ba2;
}

/* Responsive */
@media (max-width: 900px) {
  .modal-container.shifts-modal {
    width: 100%;
    height: 100%;
    max-height: none;
    border-radius: 0;
  }

  .shifts-layout {
    flex-direction: column;
  }

  .available-buses-panel {
    width: 100%;
    max-height: 200px;
    border-right: none;
    border-bottom: 1px solid #e2e8f0;
  }

  .controls-row {
    flex-direction: column;
    align-items: stretch;
    gap: 12px;
  }

  .route-select,
  .date-display {
    width: 100%;
  }

  .action-buttons {
    justify-content: stretch;
  }

  .generate-btn,
  .clear-btn {
    flex: 1;
    justify-content: center;
  }
}
</style>
