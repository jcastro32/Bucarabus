<template>
  <div class="drivers-section">
    <div class="section-header">
      <div class="header-stats">
        <div class="stat-card">
          <h3>Total Conductores</h3>
          <span>{{ totalDrivers }}</span>
        </div>
        <div class="stat-card">
          <h3>Disponibles</h3>
          <span class="available">{{ availableDriversCount }}</span>
        </div>
        <div class="stat-card">
          <h3>Experiencia Promedio</h3>
          <span>{{ averageExperience }} años</span>
        </div>
      </div>
      <div class="header-actions">
        <button class="btn primary" @click="openDriverModal">
          <span>➕</span> Nuevo Conductor
        </button>
      </div>
    </div>

    <div class="drivers-controls">
      <div class="search-filters">
        <input
          type="text"
          v-model="searchQuery"
          placeholder="Buscar por nombre, cédula o teléfono..."
          class="search-input"
          @input="filterDrivers"
        />
        <select v-model="availabilityFilter" class="filter-select" @change="filterDrivers">
          <option value="">Todos los estados</option>
          <option value="true">Disponibles</option>
          <option value="false">No disponibles</option>
        </select>
        <select v-model="categoryFilter" class="filter-select" @change="filterDrivers">
          <option value="">Todas las categorías</option>
          <option value="C1">Categoría C1</option>
          <option value="C2">Categoría C2</option>
          <option value="C3">Categoría C3</option>
        </select>
      </div>
    </div>

    <div class="drivers-table-container">
      <table class="drivers-table">
        <thead>
          <tr>
            <th>Conductor</th>
            <th>Cédula</th>
            <th>Teléfono</th>
            <th>Licencia</th>
            <th>Estado</th>
            <th>Acciones</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="driver in filteredDrivers" :key="driver.id">
            <td class="driver-cell">
              <div class="driver-info-compact">
                <div class="driver-avatar-small">
                  <span>👤</span>
                </div>
                <div class="driver-name-col">
                  <span class="name">{{ driver.name_driver }}</span>
                  <span class="email" v-if="driver.email">{{ driver.email }}</span>
                </div>
              </div>
            </td>
            <td>{{ driver.id_card }}</td>
            <td>{{ driver.cel }}</td>
            <td>
              <div class="license-cell">
                <span class="category-badge-small">{{ driver.license_cat }}</span>
                <span class="license-date" :class="getLicenseStatusClass(driver.id)">
                  {{ formatDate(driver.license_exp) }}
                  <span v-if="!isLicenseValid(driver.id)">⚠️</span>
                </span>
              </div>
            </td>
            <td>
              <span class="status-badge-small" :class="driver.available ? 'available' : 'unavailable'">
                {{ driver.available ? 'Disponible' : 'No disponible' }}
              </span>
            </td>
            <td>
              <div class="actions-cell">
                <button class="btn-icon" title="Editar" @click="editDriver(driver)">
                  ✏️
                </button>
                <button class="btn-icon" title="Ver Detalles" @click="viewDriverDetails(driver)">
                  👁️
                </button>
                <button 
                  class="btn-icon" 
                  :title="driver.available ? 'Marcar No Disponible' : 'Marcar Disponible'"
                  @click="toggleAvailability(driver)"
                >
                  {{ driver.available ? '🚫' : '✅' }}
                </button>
              </div>
            </td>
          </tr>
          <tr v-if="filteredDrivers.length === 0">
            <td colspan="6" class="no-data-cell">
              {{ searchQuery || availabilityFilter || categoryFilter ? 'No se encontraron conductores con los criterios de búsqueda.' : 'No hay conductores registrados.' }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-if="filteredDrivers.length === 0" class="no-data">
      {{ searchQuery || availabilityFilter || categoryFilter ? 'No se encontraron conductores con los criterios de búsqueda.' : 'No hay conductores registrados. Haga clic en "Nuevo Conductor" para agregar el primero.' }}
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAppStore } from '../stores/app'
import { useDriversStore } from '../stores/drivers'

const appStore = useAppStore()
const driversStore = useDriversStore()

// Estado local
const searchQuery = ref('')
const availabilityFilter = ref('')
const categoryFilter = ref('')

// Cargar conductores al montar el componente
onMounted(async () => {
  await driversStore.fetchDrivers()
})

// Computed properties
const totalDrivers = computed(() => driversStore.totalDrivers)
const availableDriversCount = computed(() => driversStore.availableDrivers.length)
const averageExperience = computed(() => driversStore.averageExperience)

const filteredDrivers = computed(() => {
  let drivers = driversStore.drivers

  // Filtrar por búsqueda
  if (searchQuery.value) {
    drivers = driversStore.searchDrivers(searchQuery.value)
  }

  // Filtrar por disponibilidad
  if (availabilityFilter.value !== '') {
    const isAvailable = availabilityFilter.value === 'true'
    drivers = drivers.filter(driver => driver.available === isAvailable)
  }

  // Filtrar por categoría
  if (categoryFilter.value) {
    drivers = drivers.filter(driver => driver.license_cat === categoryFilter.value)
  }

  return drivers
})

// Métodos
const openDriverModal = () => {
  appStore.openModal('driver', null)
}

const editDriver = (driver) => {
  appStore.openModal('editDriver', driver)
}

const viewDriverDetails = (driver) => {
  alert(`Detalles del Conductor\n\n` +
    `Nombre: ${driver.name_driver}\n` +
    `Cédula: ${driver.id_card}\n` +
    `Teléfono: ${driver.cel}\n` +
    `Email: ${driver.email || 'N/A'}\n` +
    `Dirección: ${driver.address_driver || 'N/A'}\n\n` +
    `Licencia: ${driver.id_card}\n` +
    `Categoría: ${driver.license_cat}\n` +
    `Vencimiento: ${formatDate(driver.license_exp)}\n` +
    `Experiencia: ${driver.experience} años\n\n` +
    `Estado: ${driver.available ? 'Disponible' : 'No disponible'}`
  )
}

const toggleAvailability = async (driver) => {
  const newStatus = !driver.available
  const action = newStatus ? 'marcar como disponible' : 'marcar como no disponible'

  if (confirm(`¿Está seguro de que desea ${action} a ${driver.name_driver}?`)) {
    console.log(`🔄 Intentando cambiar disponibilidad del conductor ${driver.id} de ${driver.available} a ${newStatus}`)
    
    const result = await driversStore.toggleDriverAvailability(driver.id)
    
    console.log('📝 Resultado:', result)
    
    if (result.success) {
      console.log('✅ Disponibilidad cambiada exitosamente')
      // La UI se actualizará automáticamente gracias a la reactividad
    } else {
      console.error('❌ Error al cambiar disponibilidad:', result.error)
      alert(`Error: ${result.error || 'No se pudo cambiar la disponibilidad'}`)
    }
  }
}

const isLicenseValid = (driverId) => {
  return driversStore.isLicenseValid(driverId)
}

const isLicenseExpiringSoon = (driverId) => {
  return driversStore.isLicenseExpiringSoon(driverId)
}

const getLicenseStatusClass = (driverId) => {
  if (!isLicenseValid(driverId)) return 'license-expired-text'
  if (isLicenseExpiringSoon(driverId)) return 'license-warning-text'
  return 'license-valid-text'
}

const formatDate = (dateString) => {
  if (!dateString) return 'N/A'
  const date = new Date(dateString)
  return date.toLocaleDateString('es-CO', { year: 'numeric', month: 'long', day: 'numeric' })
}

const filterDrivers = () => {
  // Los filtros se aplican automáticamente a través de computed properties
}
</script>

<style scoped>
.drivers-section {
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

.drivers-controls {
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

.drivers-table-container {
  background: white;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  overflow: auto; /* Enable both horizontal and vertical scrolling */
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  max-width: 100%;
  max-height: calc(100vh - 300px); /* Limit height to viewport minus header/controls */
  min-height: 400px; /* Ensure reasonable minimum height */
  
  /* Custom Scrollbar */
  scrollbar-width: thin;
  scrollbar-color: #cbd5e1 #f1f5f9;
}

.drivers-table-container::-webkit-scrollbar {
  width: 8px; /* Width for vertical scrollbar */
  height: 8px; /* Height for horizontal scrollbar */
}

.drivers-table-container::-webkit-scrollbar-track {
  background: #f1f5f9;
  border-radius: 12px;
}

.drivers-table-container::-webkit-scrollbar-thumb {
  background-color: #cbd5e1;
  border-radius: 4px;
  border: 2px solid #f1f5f9;
}

.drivers-table-container::-webkit-scrollbar-thumb:hover {
  background-color: #94a3b8;
}

.drivers-table {
  width: 100%;
  border-collapse: separate; /* Required for sticky header border */
  border-spacing: 0;
  min-width: 800px;
}

.drivers-table th {
  background: #f8fafc;
  padding: 16px;
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

.drivers-table td {
  padding: 16px;
  border-bottom: 1px solid #f1f5f9;
  color: #1e293b;
  font-size: 14px;
  vertical-align: middle;
}

.drivers-table tr:last-child td {
  border-bottom: none;
}

.drivers-table tr:hover {
  background: #f8fafc;
}

.driver-info-compact {
  display: flex;
  align-items: center;
  gap: 12px;
}

.driver-avatar-small {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
  color: white;
}

.driver-name-col {
  display: flex;
  flex-direction: column;
}

.driver-name-col .name {
  font-weight: 600;
  color: #1e293b;
}

.driver-name-col .email {
  font-size: 12px;
  color: #64748b;
}

.license-cell {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.category-badge-small {
  background: #e0e7ff;
  color: #4338ca;
  padding: 2px 8px;
  border-radius: 12px;
  font-size: 11px;
  font-weight: 700;
  display: inline-block;
  width: fit-content;
}

.license-date {
  font-size: 12px;
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
  gap: 8px;
}

.btn-icon {
  width: 32px;
  height: 32px;
  border-radius: 6px;
  border: 1px solid #e2e8f0;
  background: white;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 16px;
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

.license-valid-text {
  color: #10b981;
}

.license-warning-text {
  color: #f59e0b;
  font-weight: 700;
}

.license-expired-text {
  color: #ef4444;
  font-weight: 700;
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
