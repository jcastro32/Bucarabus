<template>
  <div class="bus-modal-content">
    <form @submit.prevent="handleSubmit" class="modal-form">
      <!-- Header con Foto y Switches -->
      <div class="modal-header-section">
        <div class="photo-upload-section">
          <div class="photo-circle" @click="triggerFileInput" title="Click para cambiar foto">
            <img v-if="formData.photo_url" :src="formData.photo_url" alt="Foto" @error="handleImageError" />
            <div v-else class="photo-placeholder">
              <span>🚌</span>
            </div>
          </div>
          <input
            ref="fileInput"
            type="file"
            accept="image/*"
            style="display: none"
            @change="handleFileUpload"
          />
        </div>
        
        <div class="status-switches">
          <label class="switch-item">
            <span class="switch-text">Activo</span>
            <div class="switch">
              <input type="checkbox" v-model="formData.status_bus" @change="handleStatusChange" />
              <span class="slider"></span>
            </div>
          </label>
        </div>
      </div>

      <!-- Información Básica -->
      <div class="form-section">
        <h3 class="section-title">📋 Información Básica</h3>
        
        <div class="form-row">
          <div class="form-group">
            <label for="plate_number" class="required">Placa</label>
            <input
              type="text"
              id="plate_number"
              v-model="formData.plate_number"
              placeholder="ABC123"
              maxlength="6"
              required
              :disabled="isEditMode"
              :class="{ 'error': errors.plate_number }"
              @input="formatPlateNumber"
            />
            <span v-if="errors.plate_number" class="error-message">{{ errors.plate_number }}</span>
          </div>

          <div class="form-group">
            <label for="amb_code" class="required">Código AMB</label>
            <input
              type="text"
              id="amb_code"
              v-model="formData.amb_code"
              placeholder="AMB-0001"
              maxlength="8"
              required
              :class="{ 'error': errors.amb_code }"
            />
            <span v-if="errors.amb_code" class="error-message">{{ errors.amb_code }}</span>
          </div>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label for="capacity" class="required">Capacidad</label>
            <input
              type="number"
              id="capacity"
              v-model.number="formData.capacity"
              min="10"
              max="999"
              placeholder="40"
              required
              :class="{ 'error': errors.capacity }"
            />
            <span v-if="errors.capacity" class="error-message">{{ errors.capacity }}</span>
          </div>

          <div class="form-group">
            <label for="id_company" class="required">Compañía</label>
            <select
              id="id_company"
              v-model.number="formData.id_company"
              required
              :class="{ 'error': errors.id_company }"
            >
              <option value="">Seleccione una compañía</option>
              <option value="1">Metrolínea</option>
              <option value="2">Cotraoriente</option>
              <option value="3">Cootransmagdalena</option>
              <option value="4">Cotrander</option>
            </select>
            <span v-if="errors.id_company" class="error-message">{{ errors.id_company }}</span>
          </div>
        </div>
      </div>

      <!-- Asignación de Conductor -->
      <div class="form-section">
        <h3 class="section-title">👨‍✈️ Asignación de Conductor</h3>
        
        <!-- Tarjeta informativa cuando hay asignación -->
        <div class="assignment-info-card" v-if="formData.id_user">
          <div class="info-content">
            <div class="info-row">
              <span class="label">👨‍✈️ Conductor:</span>
              <span class="value">{{ assignedDriverName }}</span>
            </div>
            <div class="info-row">
              <span class="label">📅 Asignado el:</span>
              <span class="value">{{ formatDateTime(formData.assignment_date) }}</span>
            </div>
          </div>
          <button 
            type="button" 
            class="btn-quick-access" 
            @click="goToAssignDriver"
          >
            <span class="btn-icon">🔄</span>
            <span>Gestionar Asignación</span>
            <span class="btn-arrow">→</span>
          </button>
        </div>

        <!-- Mensaje cuando NO hay asignación -->
        <div class="assignment-info-card empty" v-else>
          <div class="empty-icon">🚌</div>
          <p class="empty-text">Este bus no tiene conductor asignado</p>
          <button 
            type="button" 
            class="btn-quick-access primary" 
            @click="goToAssignDriver"
          >
            <span class="btn-icon">➕</span>
            <span>Asignar Conductor</span>
            <span class="btn-arrow">→</span>
          </button>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label for="id_card_owner" class="required">Cédula Propietario</label>
            <input
              type="number"
              id="id_card_owner"
              v-model.number="formData.id_card_owner"
              placeholder="1234567890"
              min="1"
              required
              :class="{ 'error': errors.id_card_owner }"
            />
            <span v-if="errors.id_card_owner" class="error-message">{{ errors.id_card_owner }}</span>
          </div>

          <div class="form-group">
            <label for="name_owner" class="required">Nombre Propietario</label>
            <input
              type="text"
              id="name_owner"
              v-model="formData.name_owner"
              placeholder="Nombre completo del propietario"
              maxlength="50"
              required
              :class="{ 'error': errors.name_owner }"
            />
            <span v-if="errors.name_owner" class="error-message">{{ errors.name_owner }}</span>
          </div>
        </div>

      </div>

      <!-- Documentación Legal -->
      <div class="form-section">
        <h3 class="section-title">📄 Documentación Legal</h3>

        <div class="docs-table">
          <table>
            <thead>
              <tr>
                <th>Documento</th>
                <th>Fecha de Vencimiento</th>
                <th>Estado</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td class="doc-label">SOAT</td>
                <td>
                  <input
                    type="date"
                    id="soat_exp"
                    v-model="formData.soat_exp"
                    :min="minDocumentDate"
                    required
                    :class="{ 'error': errors.soat_exp }"
                  />
                  <span v-if="errors.soat_exp" class="error-message-inline">{{ errors.soat_exp }}</span>
                </td>
                <td>
                  <span v-if="isExpiringSoon(formData.soat_exp)" class="warning-badge">⚠️ Por vencer</span>
                  <span v-else-if="formData.soat_exp" class="valid-badge">✓ Al día</span>
                </td>
              </tr>
              <tr>
                <td class="doc-label">Tecno</td>
                <td>
                  <input
                    type="date"
                    id="techno_exp"
                    v-model="formData.techno_exp"
                    :min="minDocumentDate"
                    required
                    :class="{ 'error': errors.techno_exp }"
                  />
                  <span v-if="errors.techno_exp" class="error-message-inline">{{ errors.techno_exp }}</span>
                </td>
                <td>
                  <span v-if="isExpiringSoon(formData.techno_exp)" class="warning-badge">⚠️ Por vencer</span>
                  <span v-else-if="formData.techno_exp" class="valid-badge">✓ Al día</span>
                </td>
              </tr>
              <tr>
                <td class="doc-label">RCC</td>
                <td>
                  <input
                    type="date"
                    id="rcc_exp"
                    v-model="formData.rcc_exp"
                    :min="minDocumentDate"
                    required
                    :class="{ 'error': errors.rcc_exp }"
                  />
                  <span v-if="errors.rcc_exp" class="error-message-inline">{{ errors.rcc_exp }}</span>
                </td>
                <td>
                  <span v-if="isExpiringSoon(formData.rcc_exp)" class="warning-badge">⚠️ Por vencer</span>
                  <span v-else-if="formData.rcc_exp" class="valid-badge">✓ Al día</span>
                </td>
              </tr>
              <tr>
                <td class="doc-label">RCE</td>
                <td>
                  <input
                    type="date"
                    id="rce_exp"
                    v-model="formData.rce_exp"
                    :min="minDocumentDate"
                    required
                    :class="{ 'error': errors.rce_exp }"
                  />
                  <span v-if="errors.rce_exp" class="error-message-inline">{{ errors.rce_exp }}</span>
                </td>
                <td>
                  <span v-if="isExpiringSoon(formData.rce_exp)" class="warning-badge">⚠️ Por vencer</span>
                  <span v-else-if="formData.rce_exp" class="valid-badge">✓ Al día</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Mensaje de Error Global -->
      <div v-if="globalError" class="global-error">
        ⚠️ {{ globalError }}
      </div>

      <!-- Botones de Acción -->
      <div class="modal-actions">
        <button type="button" class="btn secondary" @click="handleClose" :disabled="isSubmitting">
          Cancelar
        </button>
        <button type="submit" class="btn primary" :disabled="isSubmitting">
          <span v-if="isSubmitting" class="spinner"></span>
          {{ isSubmitting ? 'Guardando...' : (isEditMode ? 'Actualizar Bus' : 'Crear Bus') }}
        </button>
      </div>
    </form>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useAppStore } from '../../stores/app'
import { useBusesStore } from '../../stores/buses'
import { useDriversStore } from '../../stores/drivers'

const appStore = useAppStore()
const busesStore = useBusesStore()
const driversStore = useDriversStore()
const router = useRouter()

// Referencias
const fileInput = ref(null)

// Props
const props = defineProps({
  data: {
    type: Object,
    default: null
  },
  isEdit: {
    type: Boolean,
    default: false
  }
})

// Estado del modal
const isEditMode = computed(() => props.isEdit && props.data)
const isSubmitting = ref(false)

// Helper para fecha
const getTodayDate = () => new Date().toISOString().split('T')[0]

// Datos del formulario
const getDefaultFormData = () => ({
  plate_number: '',
  amb_code: '',
  id_user: null,
  assignment_date: null,
  id_company: '',
  capacity: null,
  photo_url: '',
  id_card_owner: null,
  name_owner: '',
  soat_exp: '',
  techno_exp: '',
  rcc_exp: '',
  rce_exp: '',
  status_bus: true
})

const formData = ref(getDefaultFormData())
const errors = ref({})
const globalError = ref('')

// Fechas
const minDocumentDate = computed(() => {
  const tomorrow = new Date()
  tomorrow.setDate(tomorrow.getDate() + 1)
  return tomorrow.toISOString().split('T')[0]
})

// Computed
const availableDrivers = computed(() => {
  return driversStore.drivers.filter(d => d.available && d.status_driver)
})

const allDrivers = computed(() => driversStore.drivers)

const assignedDriverName = computed(() => {
  if (!formData.value.id_user) return null
  const driver = driversStore.drivers.find(d => d.id_user === formData.value.id_user)
  return driver?.name_driver || 'Desconocido'
})

// =============================================
// MÉTODOS (DECLARAR ANTES DE LOS WATCHERS)
// =============================================

const formatPlateNumber = (event) => {
  let value = event.target.value.replace(/[^A-Z0-9]/gi, '').toUpperCase()
  
  if (value.length > 3) {
    value = value.slice(0, 3) + value.slice(3)
  }
  
  formData.value.plate_number = value.slice(0, 6)
}

const handleStatusChange = () => {
  if (!formData.value.status_bus) {
    const confirmed = confirm('⚠️ ¿Desactivar este bus? No podrá ser asignado a conductores ni rutas.')
    if (!confirmed) {
      formData.value.status_bus = true // Revertir
    }
  }
}

const isExpiringSoon = (dateString) => {
  if (!dateString) return false
  
  const expDate = new Date(dateString)
  const today = new Date()
  const diffTime = expDate - today
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
  
  return diffDays > 0 && diffDays <= 30
}

const formatDateForInput = (dateValue) => {
  if (!dateValue) return ''
  
  const date = typeof dateValue === 'string' 
    ? dateValue.split('T')[0] 
    : new Date(dateValue).toISOString().split('T')[0]
  
  return date
}

const formatDateTime = (dateValue) => {
  if (!dateValue) return '-'
  
  const date = new Date(dateValue)
  const day = String(date.getDate()).padStart(2, '0')
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const year = date.getFullYear()
  const hours = String(date.getHours()).padStart(2, '0')
  const minutes = String(date.getMinutes()).padStart(2, '0')
  
  return `${day}/${month}/${year} ${hours}:${minutes}`
}

const resetForm = () => {
  formData.value = getDefaultFormData()
  errors.value = {}
  globalError.value = ''
}

const loadBusData = (bus) => {
  console.log('📥 Cargando datos del bus:', bus)
  
  formData.value = {
    plate_number: bus.plate_number || '',
    amb_code: bus.amb_code || '',
    id_user: bus.id_user || null,
    assignment_date: bus.assignment_date || null,
    id_company: bus.id_company || '',
    capacity: bus.capacity || null,
    photo_url: bus.photo_url || '',
    id_card_owner: bus.id_card_owner || null,
    name_owner: bus.name_owner || '',
    soat_exp: formatDateForInput(bus.soat_exp),
    techno_exp: formatDateForInput(bus.techno_exp),
    rcc_exp: formatDateForInput(bus.rcc_exp),
    rce_exp: formatDateForInput(bus.rce_exp),
    status_bus: bus.status_bus ?? true
  }
  
  console.log('✅ FormData cargado:', formData.value)
}

const validateForm = () => {
  errors.value = {}

  // Validar placa
  if (!formData.value.plate_number?.trim()) {
    errors.value.plate_number = 'La placa es obligatoria'
  } else if (!/^[A-Z]{3}[0-9]{3}$/.test(formData.value.plate_number)) {
    errors.value.plate_number = 'Formato inválido. Debe ser ABC123 (3 letras + 3 números)'
  }

  // Validar código AMB
  if (!formData.value.amb_code?.trim()) {
    errors.value.amb_code = 'El código AMB es obligatorio'
  } else if (!/^AMB-[0-9]{4}$/.test(formData.value.amb_code)) {
    errors.value.amb_code = 'Formato inválido. Debe ser AMB-#### con 4 dígitos (ej: AMB-0001)'
  }

  // Validar capacidad
  if (!formData.value.capacity) {
    errors.value.capacity = 'La capacidad es obligatoria'
  } else if (formData.value.capacity < 10 || formData.value.capacity > 999) {
    errors.value.capacity = 'La capacidad debe estar entre 10 y 999'
  }

  // Validar compañía
  if (!formData.value.id_company) {
    errors.value.id_company = 'Debe seleccionar una compañía'
  }

  // Validar propietario
  if (!formData.value.id_card_owner || formData.value.id_card_owner <= 0) {
    errors.value.id_card_owner = 'La cédula del propietario es obligatoria'
  }

  if (!formData.value.name_owner?.trim()) {
    errors.value.name_owner = 'El nombre del propietario es obligatorio'
  } else if (formData.value.name_owner.trim().length < 3) {
    errors.value.name_owner = 'El nombre debe tener al menos 3 caracteres'
  }

  // Validar fechas de documentos
  const today = new Date()
  const validateDate = (dateField, fieldName) => {
    if (!formData.value[dateField]) {
      errors.value[dateField] = `La fecha de ${fieldName} es obligatoria`
    } else {
      const expDate = new Date(formData.value[dateField])
      if (expDate <= today) {
        errors.value[dateField] = `La fecha de ${fieldName} debe ser futura`
      }
    }
  }

  validateDate('soat_exp', 'SOAT')
  validateDate('techno_exp', 'Tecnomecánica')
  validateDate('rcc_exp', 'RCC')
  validateDate('rce_exp', 'RCE')

  return Object.keys(errors.value).length === 0
}

const handleSubmit = async () => {
  if (!validateForm()) {
    globalError.value = 'Por favor corrija los errores antes de continuar'
    return
  }

  isSubmitting.value = true
  globalError.value = ''

  try {
    const busData = { ...formData.value }

    if (isEditMode.value) {
      const result = await busesStore.updateBus(props.data.plate_number, busData)
      if (!result.success) {
        throw new Error(result.error)
      }
    } else {
      const result = await busesStore.createBus(busData)
      if (!result.success) {
        throw new Error(result.error)
      }
    }

    handleClose()
    resetForm()
  } catch (error) {
    console.error('Error al guardar bus:', error)
    globalError.value = error.message || 'Error al guardar el bus'
  } finally {
    isSubmitting.value = false
  }
}

const handleClose = () => {
  if (!isSubmitting.value) {
    resetForm()
    appStore.closeModal()
  }
}

const handleImageError = (event) => {
  event.target.src = 'https://via.placeholder.com/150?text=Sin+Foto'
}

const triggerFileInput = () => {
  fileInput.value?.click()
}

const handleFileUpload = async (event) => {
  const file = event.target.files?.[0]
  if (!file) return

  // Validar tipo
  if (!file.type.startsWith('image/')) {
    alert('Solo se permiten archivos de imagen')
    return
  }

  // Validar tamaño (max 5MB)
  if (file.size > 5 * 1024 * 1024) {
    alert('La imagen es muy grande. Máximo 5MB')
    return
  }

  try {
    // TODO: Implementar subida a servidor/storage
    const temporaryUrl = URL.createObjectURL(file)
    formData.value.photo_url = temporaryUrl
    
    console.warn('⚠️ Imagen cargada temporalmente. Debes implementar la subida al servidor.')
    console.log('📁 Archivo seleccionado:', file.name, 'Tamaño:', (file.size / 1024).toFixed(2), 'KB')
  } catch (error) {
    console.error('Error al procesar imagen:', error)
    alert('Error al procesar la imagen')
  }
}

const goToAssignDriver = () => {
  handleClose()
  router.push('/fleet/assign-driver')
}

// =============================================
// WATCHERS (DESPUÉS DE DECLARAR LOS MÉTODOS)
// =============================================

watch(() => props.data, (newBus) => {
  if (newBus) {
    loadBusData(newBus)
  } else {
    resetForm()
  }
}, { immediate: true, deep: true })

// Exponer método para que AppModals pueda invocarlo
defineExpose({
  handleSave: handleSubmit
})
</script>

<style scoped>
.modal-header-section {
  display: flex;
  align-items: center;
  gap: 32px;
  padding: 0 0 32px 0;
  border-bottom: 1px solid #e2e8f0;
  margin-bottom: 32px;
}

.photo-upload-section {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}

.photo-circle {
  width: 100px;
  height: 100px;
  border-radius: 50%;
  overflow: hidden;
  border: 2px solid #e2e8f0;
  transition: all 0.3s ease;
  position: relative;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  cursor: pointer;
}

.photo-circle:hover {
  border-color: #667eea;
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.15);
  transform: scale(1.02);
}

.photo-circle img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.photo-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%);
  color: #94a3b8;
  font-size: 36px;
  transition: all 0.2s ease;
}

.photo-circle:hover .photo-placeholder {
  color: #667eea;
}

.status-switches {
  display: flex;
  gap: 24px;
  flex: 1;
  justify-content: flex-end;
}

.switch-item {
  display: flex;
  align-items: center;
  gap: 12px;
  cursor: pointer;
  user-select: none;
}

.switch-text {
  font-size: 13px;
  font-weight: 500;
  color: #475569;
  letter-spacing: -0.01em;
}

.switch {
  position: relative;
  width: 44px;
  height: 22px;
  flex-shrink: 0;
}

.switch input {
  opacity: 0;
  width: 0;
  height: 0;
}

.slider {
  position: absolute;
  cursor: pointer;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: #e2e8f0;
  transition: 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  border-radius: 22px;
}

.slider:before {
  position: absolute;
  content: "";
  height: 16px;
  width: 16px;
  left: 3px;
  bottom: 3px;
  background-color: white;
  transition: 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  border-radius: 50%;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.switch input:checked + .slider {
  background-color: #667eea;
}

.switch input:checked + .slider:before {
  transform: translateX(22px);
}

.switch:hover .slider {
  background-color: #cbd5e1;
}

.switch input:checked:hover + .slider {
  background-color: #5a67d8;
}

.form-section {
  padding: 20px 0;
  border-bottom: 1px solid #e2e8f0;
}

.form-section:last-of-type {
  border-bottom: none;
}

.assignment-info-card {
  background: linear-gradient(135deg, #f8fafc 0%, #e0e7ff 100%);
  border: 2px solid #c7d2fe;
  border-radius: 12px;
  padding: 20px;
  margin-bottom: 16px;
}

.assignment-info-card.empty {
  background: linear-gradient(135deg, #f8fafc 0%, #fef3c7 100%);
  border-color: #fde68a;
  text-align: center;
  padding: 32px 20px;
}

.info-content {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-bottom: 12px;
}

.info-row {
  display: flex;
  align-items: center;
  gap: 12px;
}

.info-row .label {
  font-size: 13px;
  font-weight: 600;
  color: #475569;
  min-width: 140px;
}

.info-row .value {
  font-size: 14px;
  font-weight: 700;
  color: #1e293b;
  background: white;
  padding: 6px 14px;
  border-radius: 6px;
  border: 1px solid #e2e8f0;
}

.info-note {
  margin-top: 12px;
  padding-top: 12px;
  border-top: 1px solid #e0e7ff;
  font-size: 12px;
  color: #64748b;
  font-style: italic;
}

.btn-quick-access {
  width: 100%;
  margin-top: 16px;
  padding: 12px 20px;
  background: white;
  border: 2px solid #667eea;
  border-radius: 8px;
  color: #667eea;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s ease;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}

.btn-quick-access:hover {
  background: #667eea;
  color: white;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
}

.btn-quick-access.primary {
  background: #667eea;
  color: white;
}

.btn-quick-access.primary:hover {
  background: #5a67d8;
  border-color: #5a67d8;
}

.btn-icon {
  font-size: 16px;
}

.btn-arrow {
  margin-left: auto;
  font-size: 18px;
  transition: transform 0.3s ease;
}

.btn-quick-access:hover .btn-arrow {
  transform: translateX(4px);
}

.assignment-info-card.empty .info-note {
  border-top-color: #fde68a;
}

.empty-icon {
  font-size: 48px;
  margin-bottom: 12px;
}

.empty-text {
  font-size: 14px;
  font-weight: 600;
  color: #64748b;
  margin: 0 0 8px 0;
}

.readonly-input {
  background: #f8fafc !important;
  cursor: not-allowed;
  opacity: 0.7;
}

.info-text {
  display: block;
  margin-top: 6px;
  color: #64748b;
  font-size: 11px;
}

.section-title {
  margin: 0 0 20px 0;
  color: #1e293b;
  font-size: 18px;
  font-weight: 700;
  display: flex;
  align-items: center;
  gap: 8px;
}

.form-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 20px;
}

.form-group {
  margin-bottom: 20px;
}

.form-group label {
  display: block;
  margin-bottom: 8px;
  color: #475569;
  font-weight: 600;
  font-size: 14px;
}

.form-group label.required::after {
  content: " *";
  color: #ef4444;
}

.form-group input,
.form-group select,
.form-group textarea {
  width: 100%;
  padding: 12px 16px;
  border: 2px solid #e2e8f0;
  border-radius: 8px;
  font-size: 14px;
  transition: all 0.3s ease;
  font-family: inherit;
}

.form-group input:focus,
.form-group select:focus,
.form-group textarea:focus {
  outline: none;
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.form-group input.error,
.form-group select.error,
.form-group textarea.error {
  border-color: #ef4444;
}

.form-group input:disabled {
  background: #f8fafc;
  cursor: not-allowed;
  opacity: 0.6;
}

.error-message {
  display: block;
  margin-top: 6px;
  color: #ef4444;
  font-size: 12px;
  font-weight: 500;
}

.warning-message {
  display: block;
  margin-top: 6px;
  color: #f59e0b;
  font-size: 12px;
  font-weight: 500;
}

.global-error {
  background: #fee2e2;
  border: 1px solid #ef4444;
  color: #991b1b;
  padding: 16px;
  border-radius: 8px;
  margin-bottom: 20px;
  font-weight: 500;
  display: flex;
  align-items: center;
  gap: 8px;
}

.modal-actions {
  display: flex;
  gap: 12px;
  justify-content: flex-end;
  padding-top: 24px;
  border-top: 2px solid #f1f5f9;
}

.btn {
  padding: 12px 24px;
  border-radius: 8px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s ease;
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 140px;
  justify-content: center;
}

.btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn.primary {
  background: #667eea;
  color: white;
  border: none;
}

.btn.primary:hover:not(:disabled) {
  background: #5a67d8;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
}

.btn.secondary {
  background: white;
  color: #64748b;
  border: 2px solid #e2e8f0;
}

.btn.secondary:hover:not(:disabled) {
  background: #f8fafc;
  border-color: #cbd5e1;
}

.spinner {
  width: 16px;
  height: 16px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* Tabla de Documentación */
.docs-table {
  margin-top: 16px;
}

.docs-table table {
  width: 100%;
  border-collapse: collapse;
}

.docs-table thead {
  background: #f8fafc;
}

.docs-table th {
  padding: 12px 16px;
  text-align: left;
  font-size: 12px;
  font-weight: 600;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  border-bottom: 2px solid #e2e8f0;
}

.docs-table tbody tr {
  border-bottom: 1px solid #f1f5f9;
  transition: background 0.2s ease;
}

.docs-table tbody tr:hover {
  background: #f8fafc;
}

.docs-table td {
  padding: 12px 16px;
  vertical-align: middle;
}

.docs-table .doc-label {
  font-weight: 600;
  color: #1e293b;
  font-size: 13px;
  min-width: 80px;
}

.docs-table input[type="date"] {
  width: 100%;
  max-width: 200px;
  padding: 8px 12px;
  border: 2px solid #e2e8f0;
  border-radius: 6px;
  font-size: 13px;
  transition: all 0.3s ease;
}

.docs-table input[type="date"]:focus {
  outline: none;
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.docs-table input[type="date"].error {
  border-color: #ef4444;
}

.error-message-inline {
  display: block;
  margin-top: 4px;
  color: #ef4444;
  font-size: 11px;
  font-weight: 500;
}

.warning-badge {
  display: inline-block;
  padding: 4px 10px;
  background: #fef3c7;
  color: #92400e;
  border-radius: 12px;
  font-size: 11px;
  font-weight: 600;
}

.valid-badge {
  display: inline-block;
  padding: 4px 10px;
  background: #d1fae5;
  color: #065f46;
  border-radius: 12px;
  font-size: 11px;
  font-weight: 600;
}

/* Responsive */
@media (max-width: 768px) {
  .modal-header-section {
    flex-direction: column;
    align-items: center;
    gap: 20px;
  }

  .status-switches {
    justify-content: center;
    flex-wrap: wrap;
    gap: 16px;
  }

  .form-row {
    grid-template-columns: 1fr;
  }

  .modal-actions {
    flex-direction: column-reverse;
  }

  .btn {
    width: 100%;
  }
}
</style>
