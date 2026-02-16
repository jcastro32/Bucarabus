<template>
  <div class="fleet-section">
    <div class="section-header">
      <div class="header-stats">
        <div class="stat-card">
          <h3>Total Buses</h3>
          <span>{{ totalBuses }}</span>
        </div>
        <div class="stat-card">
          <h3>Disponibles</h3>
          <span class="available">{{ availableBusesCount }}</span>
        </div>
        <div class="stat-card">
          <h3>Capacidad Total</h3>
          <span>{{ totalCapacity }}</span>
        </div>
      </div>
      <div class="header-actions">
        <button class="btn primary" @click="openBusModal">
          <span>➕</span> Nuevo Bus
        </button>
      </div>
    </div>

    <div class="fleet-controls">
      <div class="search-filters">
        <input
          type="text"
          v-model="searchQuery"
          placeholder="Buscar por placa, código AMB o compañía..."
          class="search-input"
          @input="filterBuses"
        />
        <select v-model="availabilityFilter" class="filter-select" @change="filterBuses">
          <option value="">Todos los estados</option>
          <option value="true">Disponibles</option>
          <option value="false">No disponibles</option>
        </select>
        <select v-model="companyFilter" class="filter-select" @change="filterBuses">
          <option value="">Todas las compañías</option>
          <option value="1">Metrolínea</option>
          <option value="2">Cotraoriente</option>
          <option value="3">Cootransmagdalena</option>
          <option value="4">Cotrander</option>
        </select>
      </div>
    </div>

    <div class="fleet-table-container">
      <table class="fleet-table">
        <thead>
          <tr>
            <th>Bus</th>
            <th>Empresa</th>
            <th>Documentación</th>
            <th>Acciones</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="bus in filteredBuses" :key="bus.plate_number">
            <td class="bus-cell">
              <div class="bus-info-compact">
                <div class="bus-avatar-with-plate">
                  <div class="bus-emoji">🚌</div>
                  <div class="bus-plate-overlay">{{ bus.plate_number }}</div>
                </div>
                <div class="bus-name-col">
                  <span class="code" v-if="bus.amb_code">{{ bus.amb_code }}</span>
                  <span class="driver" v-if="bus.id_user">
                    👨‍✈️ {{ getDriverName(bus.id_user) }}
                  </span>
                  <span class="driver no-driver" v-else>
                    Sin conductor
                  </span>
                </div>
              </div>
            </td>
            <td>
              <div class="company-cell">
                <span class="company-name" :class="getCompanyClass(bus.id_company)">{{ getCompanyName(bus.id_company) }}</span>
              </div>
            </td>
            <td>
              <div class="docs-icons">
                <span 
                  class="doc-icon" 
                  :class="getDocItemClass(bus.soat_exp)"
                  :title="'SOAT: ' + formatDateCompact(bus.soat_exp)"
                >
                  S
                </span>
                <span 
                  class="doc-icon" 
                  :class="getDocItemClass(bus.techno_exp)"
                  :title="'Tecnomecánica: ' + formatDateCompact(bus.techno_exp)"
                >
                  T
                </span>
                <span 
                  class="doc-icon" 
                  :class="getDocItemClass(bus.rcc_exp)"
                  :title="'RCC: ' + formatDateCompact(bus.rcc_exp)"
                >
                  C
                </span>
                <span 
                  class="doc-icon" 
                  :class="getDocItemClass(bus.rce_exp)"
                  :title="'RCE: ' + formatDateCompact(bus.rce_exp)"
                >
                  E
                </span>
              </div>
            </td>
            <td>
              <div class="actions-cell">
                <button class="btn-icon" title="Editar" @click="editBus(bus)">
                  ✏️
                </button>
                <button 
                  class="btn-icon" 
                  :title="bus.available ? 'Marcar No Disponible' : 'Marcar Disponible'"
                  @click="toggleAvailability(bus)"
                >
                  {{ bus.available ? '🚫' : '✅' }}
                </button>
              </div>
            </td>
          </tr>
          <tr v-if="filteredBuses.length === 0">
            <td colspan="4" class="no-data-cell">
              {{ searchQuery || availabilityFilter || companyFilter ? 'No se encontraron buses con los criterios de búsqueda.' : 'No hay buses registrados.' }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-if="filteredBuses.length === 0" class="no-data">
      {{ searchQuery || availabilityFilter || companyFilter ? 'No se encontraron buses con los criterios de búsqueda.' : 'No hay buses registrados. Haga clic en "Nuevo Bus" para agregar el primero.' }}
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAppStore } from '../stores/app'
import { useBusesStore } from '../stores/buses'
import { useDriversStore } from '../stores/drivers'

const appStore = useAppStore()
const busesStore = useBusesStore()
const driversStore = useDriversStore()

// Estado local
const searchQuery = ref('')
const availabilityFilter = ref('')
const companyFilter = ref('')

// Cargar datos al montar el componente
onMounted(async () => {
  await busesStore.fetchBuses()
  // await driversStore.fetchDrivers()
})

// Computed properties
const totalBuses = computed(() => busesStore.buses.length)
const availableBusesCount = computed(() => busesStore.availableBuses.length)
const totalCapacity = computed(() => busesStore.totalCapacity)

const filteredBuses = computed(() => {
  let buses = busesStore.buses

  // Filtrar por búsqueda
  if (searchQuery.value) {
    const query = searchQuery.value.toLowerCase()
    buses = buses.filter(bus =>
      bus.plate_number?.toLowerCase().includes(query) ||
      bus.amb_code?.toLowerCase().includes(query) ||
      getCompanyName(bus.id_company).toLowerCase().includes(query)
    )
  }

  // Filtrar por disponibilidad (is_active)
  if (availabilityFilter.value !== '') {
    const isActive = availabilityFilter.value === 'true'
    buses = buses.filter(bus => bus.is_active === isActive)
  }

  // Filtrar por compañía
  if (companyFilter.value) {
    buses = buses.filter(bus => bus.id_company === parseInt(companyFilter.value))
  }

  return buses
})

// Métodos
const openBusModal = () => {
  appStore.openModal('bus', null)
}

const editBus = (bus) => {
  appStore.openModal('editBus', bus)
}

const toggleAvailability = async (bus) => {
  const newStatus = !bus.available
  const action = newStatus ? 'marcar como disponible' : 'marcar como no disponible'

  if (confirm(`¿Está seguro de que desea ${action} el bus ${bus.plate_number}?`)) {
    const result = await busesStore.toggleAvailability(bus.plate_number)
    
    if (result.success) {
      console.log('✅ Disponibilidad cambiada exitosamente')
    } else {
      console.error('❌ Error al cambiar disponibilidad:', result.error)
      alert(`Error: ${result.error || 'No se pudo cambiar la disponibilidad'}`)
    }
  }
}

const getCompanyName = (companyId) => {
  const companies = {
    1: 'Metrolínea',
    2: 'Cotraoriente',
    3: 'Cootransmagdalena',
    4: 'Cotrander'
  }
  return companies[companyId] || 'Desconocida'
}

const getCompanyClass = (companyId) => {
  const classes = {
    1: 'company-1',
    2: 'company-2',
    3: 'company-3',
    4: 'company-4'
  }
  return classes[companyId] || 'company-default'
}

const getDriverName = (driverId) => {
  if (!driverId) return 'Sin asignar'
  const driver = driversStore.drivers.find(d => d.id_user === driverId)
  return driver ? driver.name_driver : 'Desconocido'
}

const getRouteName = (routeId) => {
  if (!routeId) return 'Sin ruta'
  // TODO: Integrar con routesStore cuando esté disponible
  return `Ruta ${routeId}`
}

const getSituation = (bus) => {
  if (!bus.status_bus) return 'Inactivo'
  if (!bus.available) return 'No disponible'
  if (bus.id_user && bus.id_route) return 'En servicio'
  if (bus.id_user) return 'Con conductor'
  return 'Disponible'
}

const getSituationClass = (bus) => {
  if (!bus.status_bus) return 'situation-inactive'
  if (!bus.available) return 'situation-unavailable'
  if (bus.id_user && bus.id_route) return 'situation-service'
  if (bus.id_user) return 'situation-ready'
  return 'situation-available'
}

const hasExpiredDocs = (bus) => {
  const today = new Date()
  const docs = [bus.soat_exp, bus.techno_exp, bus.rcc_exp, bus.rce_exp]
  
  return docs.some(doc => {
    if (!doc) return true
    return new Date(doc) <= today
  })
}

const isDocExpiringSoon = (dateString) => {
  if (!dateString) return false
  
  const expDate = new Date(dateString)
  const today = new Date()
  const diffTime = expDate - today
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
  
  return diffDays > 0 && diffDays <= 30
}

const getDocumentStatus = (bus) => {
  if (hasExpiredDocs(bus)) return 'Vencido'
  
  const docs = [bus.soat_exp, bus.techno_exp, bus.rcc_exp, bus.rce_exp]
  const expiringSoon = docs.some(doc => isDocExpiringSoon(doc))
  
  if (expiringSoon) return 'Por vencer'
  return 'Al día'
}

const getDocumentStatusClass = (bus) => {
  if (hasExpiredDocs(bus)) return 'doc-expired-text'
  
  const docs = [bus.soat_exp, bus.techno_exp, bus.rcc_exp, bus.rce_exp]
  const expiringSoon = docs.some(doc => isDocExpiringSoon(doc))
  
  if (expiringSoon) return 'doc-warning-text'
  return 'doc-valid-text'
}

const formatDate = (dateString) => {
  if (!dateString) return 'N/A'
  const date = new Date(dateString)
  return date.toLocaleDateString('es-CO', { year: 'numeric', month: 'long', day: 'numeric' })
}

const formatDateCompact = (dateString) => {
  if (!dateString) return 'N/A'
  const date = new Date(dateString)
  return date.toLocaleDateString('es-CO', { day: '2-digit', month: 'short', year: 'numeric' })
}

const getDocItemClass = (dateString) => {
  if (!dateString) return 'doc-missing'
  
  const expDate = new Date(dateString)
  const today = new Date()
  
  if (expDate <= today) return 'doc-expired'
  
  const diffTime = expDate - today
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
  
  if (diffDays <= 30) return 'doc-warning'
  return 'doc-valid'
}

const filterBuses = () => {
  // Los filtros se aplican automáticamente a través de computed properties
}
</script>

<style scoped>
.fleet-section {
  padding: 0;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 24px;
  padding: 20px;
  background: white;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
}

.header-stats {
  display: flex;
  gap: 16px;
}

.stat-card {
  text-align: center;
  background: #f8fafc;
  padding: 16px;
  border-radius: 8px;
  min-width: 120px;
}

.stat-card h3 {
  font-size: 12px;
  color: #64748b;
  margin: 0 0 8px 0;
  text-transform: uppercase;
  font-weight: 500;
}

.stat-card span {
  font-size: 24px;
  font-weight: 700;
  color: #667eea;
}

.stat-card span.available {
  color: #10b981;
}

.header-actions {
  display: flex;
  gap: 12px;
}

.btn {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 20px;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-weight: 500;
  transition: all 0.3s ease;
}

.btn.primary {
  background: #667eea;
  color: white;
}

.btn.primary:hover {
  background: #5a67d8;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
}

.fleet-controls {
  margin: 20px 0;
}

.search-filters {
  display: flex;
  gap: 15px;
  flex-wrap: wrap;
}

.search-input,
.filter-select {
  padding: 10px 12px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 14px;
  background: white;
  transition: border-color 0.3s ease;
}

.search-input {
  flex: 1;
  min-width: 200px;
}

.search-input:focus,
.filter-select:focus {
  outline: none;
  border-color: #667eea;
}

.fleet-table-container {
  background: white;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  overflow: auto;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  max-width: 100%;
  max-height: calc(100vh - 300px);
  min-height: 400px;
  
  /* Custom Scrollbar */
  scrollbar-width: thin;
  scrollbar-color: #cbd5e1 #f1f5f9;
}

.fleet-table-container::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

.fleet-table-container::-webkit-scrollbar-track {
  background: #f1f5f9;
  border-radius: 12px;
}

.fleet-table-container::-webkit-scrollbar-thumb {
  background-color: #cbd5e1;
  border-radius: 4px;
  border: 2px solid #f1f5f9;
}

.fleet-table-container::-webkit-scrollbar-thumb:hover {
  background-color: #94a3b8;
}

.fleet-table {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
  table-layout: fixed;
}

.fleet-table th:nth-child(1),
.fleet-table td:nth-child(1) {
  width: 40%;
}

.fleet-table th:nth-child(2),
.fleet-table td:nth-child(2) {
  width: 20%;
  text-align: center;
}

.fleet-table th:nth-child(3),
.fleet-table td:nth-child(3) {
  width: 25%;
  text-align: center;
}

.fleet-table th:nth-child(4),
.fleet-table td:nth-child(4) {
  width: 15%;
  text-align: center;
}

.fleet-table th {
  background: #f8fafc;
  padding: 14px 20px;
  text-align: left;
  font-size: 12px;
  font-weight: 600;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  border-bottom: 1px solid #e2e8f0;
  position: sticky;
  top: 0;
  z-index: 10;
}

.fleet-table td {
  padding: 12px 20px;
  border-bottom: 1px solid #f1f5f9;
  color: #1e293b;
  font-size: 14px;
  vertical-align: middle;
}

.fleet-table tr:last-child td {
  border-bottom: none;
}

.fleet-table tr:hover {
  background: #f8fafc;
}

.bus-info-compact {
  display: flex;
  align-items: center;
  gap: 14px;
}

.bus-avatar-with-plate {
  position: relative;
  width: 70px;
  height: 60px;
  border-radius: 50%;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  display: flex;
  align-items:center;
  justify-content: center;
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
  flex-shrink: 0;
  overflow: hidden;
}

.bus-emoji {
  font-size: 28px;
  margin-top: -12px;
}

.bus-plate-overlay {
  position: absolute;
  bottom: 5px;
  left: 50%;
  transform: translateX(-50%);
  background: rgba(30, 41, 59, 0.95);
  border: 1px solid rgba(71, 85, 105, 0.8);
  border-radius: 3px;
  padding: 2px 5px;
  font-size: 8.5px;
  font-weight: 700;
  letter-spacing: 1px;
  color: white;
  text-align: center;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
  white-space: nowrap;
  max-width: 85%;
  overflow: hidden;
  text-overflow: ellipsis;
}

.bus-name-col {
  display: flex;
  flex-direction: column;
}

.bus-name-col .code {
  font-size: 12px;
  color: #64748b;
}

.bus-name-col .driver {
  font-size: 12px;
  color: #1e293b;
  font-weight: 500;
}

.bus-name-col .driver.no-driver {
  color: #94a3b8;
  font-style: italic;
  font-weight: 400;
}

.company-cell {
  display: flex;
  justify-content: center;
  align-items: center;
}

.company-name {
  display: inline-block;
  padding: 6px 14px;
  border-radius: 6px;
  font-size: 13px;
  font-weight: 600;
  white-space: nowrap;
  border: 1px solid;
  transition: all 0.2s ease;
}

.company-name:hover {
  transform: translateY(-1px);
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

/* Metrolínea - Azul */
.company-name.company-1 {
  background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
  color: #1e40af;
  border-color: #93c5fd;
}

/* Cotraoriente - Verde */
.company-name.company-2 {
  background: linear-gradient(135deg, #d1fae5 0%, #a7f3d0 100%);
  color: #065f46;
  border-color: #6ee7b7;
}

/* Cootransmagdalena - Naranja */
.company-name.company-3 {
  background: linear-gradient(135deg, #fed7aa 0%, #fdba74 100%);
  color: #9a3412;
  border-color: #fb923c;
}

/* Cotrander - Morado */
.company-name.company-4 {
  background: linear-gradient(135deg, #e9d5ff 0%, #d8b4fe 100%);
  color: #6b21a8;
  border-color: #c084fc;
}

/* Default - Gris */
.company-name.company-default {
  background: linear-gradient(135deg, #f1f5f9 0%, #e2e8f0 100%);
  color: #475569;
  border-color: #cbd5e1;
}

.capacity-badge {
  background: #dbeafe;
  color: #1e40af;
  padding: 4px 10px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 600;
  display: inline-block;
}

.driver-assigned {
  color: #1e293b;
  font-weight: 500;
}

.no-driver {
  color: #94a3b8;
  font-style: italic;
  font-size: 13px;
}

.route-assigned {
  color: #1e293b;
  font-weight: 500;
}

.no-route {
  color: #94a3b8;
  font-style: italic;
  font-size: 13px;
}

.situation-badge {
  padding: 4px 10px;
  border-radius: 20px;
  font-size: 12px;
  font-weight: 500;
  display: inline-block;
}

.situation-service {
  background: #d1fae5;
  color: #065f46;
}

.situation-ready {
  background: #dbeafe;
  color: #1e40af;
}

.situation-available {
  background: #d1fae5;
  color: #065f46;
}

.situation-unavailable {
  background: #fee2e2;
  color: #991b1b;
}

.situation-inactive {
  background: #f1f5f9;
  color: #475569;
}

.docs-icons {
  display: flex;
  gap: 8px;
  justify-content: center;
  align-items: center;
}

.doc-icon {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  font-weight: 700;
  cursor: help;
  transition: all 0.2s ease;
}

.doc-icon:hover {
  transform: scale(1.2);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
}

.doc-icon.doc-valid {
  background: #d1fae5;
  color: #065f46;
  border: 2px solid #10b981;
}

.doc-icon.doc-warning {
  background: #fef3c7;
  color: #92400e;
  border: 2px solid #f59e0b;
}

.doc-icon.doc-expired {
  background: #fee2e2;
  color: #991b1b;
  border: 2px solid #ef4444;
}

.doc-icon.doc-missing {
  background: #f1f5f9;
  color: #94a3b8;
  border: 2px solid #cbd5e1;
}

.doc-status {
  font-size: 12px;
  font-weight: 600;
}

.status-badge-small {
  padding: 4px 10px;
  border-radius: 20px;
  font-size: 12px;
  font-weight: 500;
}

.status-badge-small.available {
  background: #d1fae5;
  color: #065f46;
}

.status-badge-small.unavailable {
  background: #f1f5f9;
  color: #475569;
}

.actions-cell {
  display: flex;
  gap: 10px;
  justify-content: center;
  align-items: center;
}

.btn-icon {
  width: 36px;
  height: 36px;
  border-radius: 8px;
  border: 1px solid #e2e8f0;
  background: white;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
  transition: all 0.2s ease;
}

.btn-icon:hover {
  background: #f8fafc;
  border-color: #cbd5e1;
  transform: translateY(-1px);
}

.no-data-cell {
  text-align: center;
  padding: 40px;
  color: #64748b;
  font-style: italic;
}

.no-data {
  text-align: center;
  padding: 40px 20px;
  color: #64748b;
  font-style: italic;
  background: #f8fafc;
  border-radius: 12px;
  margin: 20px 0;
}

.doc-valid-text {
  color: #10b981;
}

.doc-warning-text {
  color: #f59e0b;
}

.doc-expired-text {
  color: #ef4444;
}

/* Responsive */
@media (max-width: 768px) {
  .section-header {
    flex-direction: column;
    gap: 16px;
    align-items: stretch;
  }

  .header-stats {
    flex-wrap: wrap;
    justify-content: center;
  }

  .header-actions {
    justify-content: center;
  }

  .search-filters {
    flex-direction: column;
  }

  .search-input {
    min-width: auto;
  }
}
</style>
