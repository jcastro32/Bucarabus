<template>
  <div class="driver-modal-content">
    <form @submit.prevent="handleSubmit" class="modal-form">
        <!-- Header con Foto y Switches -->
        <div class="modal-header-section">
          <div class="photo-upload-section">
            <div class="photo-circle" @click="triggerFileInput" title="Click para cambiar foto">
              <img v-if="formData.photo_driver" :src="formData.photo_driver" alt="Foto" @error="handleImageError" />
              <div v-else class="photo-placeholder">
                <span>📷</span>
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
                <input type="checkbox" v-model="formData.status_driver" />
                <span class="slider"></span>
              </div>
            </label>
            
            <label class="switch-item">
              <span class="switch-text">Disponible</span>
              <div class="switch">
                <input type="checkbox" v-model="formData.available" />
                <span class="slider"></span>
              </div>
            </label>
          </div>
        </div>

        <!-- Información Personal -->
        <div class="form-section">
          <h3 class="section-title">👤 Información Personal</h3>
          
          <div class="form-group">
            <label for="name_driver" class="required">Nombre Completo</label>
            <input
              type="text"
              id="name_driver"
              v-model="formData.name_driver"
              placeholder="Ej: Juan Pérez González"
              maxlength="200"
              required
              :class="{ 'error': errors.name_driver }"
            />
            <span v-if="errors.name_driver" class="error-message">{{ errors.name_driver }}</span>
          </div>

          <div class="form-row">
            <div class="form-group">
              <label for="id_card" class="required">Cédula</label>
              <input
                type="number"
                id="id_card"
                v-model.number="formData.id_card"
                placeholder="Ej: 1098765432"
                min="1"
                max="9999999999999"
                required
                :disabled="isEditMode"
                :class="{ 'error': errors.id_card }"
              />
              <span v-if="errors.id_card" class="error-message">{{ errors.id_card }}</span>
            </div>

            <div class="form-group">
              <label for="cel" class="required">Teléfono</label>
              <input
                type="tel"
                id="cel"
                v-model="formData.cel"
                placeholder="Ej: 3201234567"
                pattern="[0-9]{7,15}"
                maxlength="15"
                required
                :class="{ 'error': errors.cel }"
              />
              <span v-if="errors.cel" class="error-message">{{ errors.cel }}</span>
            </div>
          </div>

          <div class="form-group">
            <label for="email" class="required">Email</label>
            <input
              type="email"
              id="email"
              v-model="formData.email"
              placeholder="ejemplo@email.com"
              maxlength="320"
              required
              :disabled="isEditMode"
              :class="{ 'error': errors.email }"
            />
            <span v-if="errors.email" class="error-message">{{ errors.email }}</span>
          </div>

          <!-- Password (solo al crear) -->
          <div v-if="!isEditMode" class="form-row">
            <div class="form-group">
              <label for="password" class="required">Contraseña</label>
              <input
                type="password"
                id="password"
                v-model="formData.password"
                placeholder="Mínimo 8 caracteres"
                minlength="8"
                required
                :class="{ 'error': errors.password }"
              />
              <span v-if="errors.password" class="error-message">{{ errors.password }}</span>
            </div>

            <div class="form-group">
              <label for="password_confirm" class="required">Confirmar Contraseña</label>
              <input
                type="password"
                id="password_confirm"
                v-model="formData.password_confirm"
                placeholder="Repetir contraseña"
                minlength="8"
                required
                :class="{ 'error': errors.password_confirm }"
              />
              <span v-if="errors.password_confirm" class="error-message">{{ errors.password_confirm }}</span>
            </div>
          </div>

          <div class="form-group">
            <label for="address_driver">Dirección</label>
            <textarea
              id="address_driver"
              v-model="formData.address_driver"
              placeholder="Ej: Calle 123 #45-67, Bucaramanga"
              rows="2"
              :class="{ 'error': errors.address_driver }"
            ></textarea>
            <span v-if="errors.address_driver" class="error-message">{{ errors.address_driver }}</span>
          </div>
        </div>

        <!-- Información de Licencia -->
        <div class="form-section">
          <h3 class="section-title">🪪 Licencia de Conducción</h3>

          <div class="form-row">
            <div class="form-group">
              <label for="license_cat" class="required">Categoría</label>
              <select
                id="license_cat"
                v-model="formData.license_cat"
                required
                :class="{ 'error': errors.license_cat }"
              >
                <option value="">Seleccione una categoría</option>
                <option value="C1">C1 - Vehículos particulares</option>
                <option value="C2">C2 - Vehículos de servicio público</option>
                <option value="C3">C3 - Vehículos de carga</option>
              </select>
              <span v-if="errors.license_cat" class="error-message">{{ errors.license_cat }}</span>
            </div>

            <div class="form-group">
              <label for="license_exp" class="required">Fecha de Vencimiento</label>
              <input
                type="date"
                id="license_exp"
                v-model="formData.license_exp"
                :min="minLicenseDate"
                required
                :class="{ 'error': errors.license_exp }"
              />
              <span v-if="errors.license_exp" class="error-message">{{ errors.license_exp }}</span>
            </div>
          </div>
        </div>

        <!-- Fecha de Ingreso (solo para edición) -->
        <div v-if="isEditMode" class="form-section">
          <h3 class="section-title">📅 Información Adicional</h3>
          
          <div class="form-row">
            <div class="form-group">
              <label for="date_entry">Fecha de Ingreso</label>
              <input
                type="date"
                id="date_entry"
                v-model="formData.date_entry"
                :max="today"
                :class="{ 'error': errors.date_entry }"
              />
              <span v-if="errors.date_entry" class="error-message">{{ errors.date_entry }}</span>
            </div>

            <div class="form-group">
              <label>Última Actualización</label>
              <input
                type="text"
                :value="formatDateTime(formData.updated_at)"
                disabled
                class="readonly-field"
              />
            </div>
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
            {{ isSubmitting ? 'Guardando...' : (isEditMode ? 'Actualizar Conductor' : 'Crear Conductor') }}
          </button>
        </div>
      </form>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { useAppStore } from '../../stores/app'         
import { useDriversStore } from '../../stores/drivers'  
import { useAuthStore } from '../../stores/auth'
import { useFormValidation } from '../../composables/useFormValidation'

const appStore = useAppStore()
const driversStore = useDriversStore()
const authStore = useAuthStore()

// Referencias
const fileInput = ref(null)

// =============================================
// CONSTANTES DE VALIDACIÓN
// =============================================
const EMAIL_REGEX = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/
const PHONE_REGEX = /^[0-9]{7,15}$/
const VALID_LICENSE_CATEGORIES = ['C1', 'C2', 'C3']

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
const isEditMode = computed(() => props.isEdit)
const isSubmitting = ref(false)

// Helper para fecha
const getTodayDate = () => new Date().toISOString().split('T')[0]

// Datos del formulario
const getDefaultFormData = () => ({
  name_driver: '',
  id_card: null,
  cel: '',
  email: '',
  password: '',           // Solo para creación
  password_confirm: '',   // Solo para creación
  available: true,
  license_cat: '',
  license_exp: '',
  address_driver: '',
  photo_driver: '',
  date_entry: getTodayDate(),
  status_driver: true
})

const formData = ref(getDefaultFormData())

// Validaciones
const { errors, validators, validateForm: runValidation, resetErrors: clearValidationErrors } = useFormValidation()
const globalError = ref('')

const resetForm = () => {
  formData.value = getDefaultFormData()
  clearValidationErrors()
  globalError.value = ''
}

// Fechas
const today = computed(() => getTodayDate())
const minLicenseDate = computed(() => {
  const tomorrow = new Date()
  tomorrow.setDate(tomorrow.getDate() + 1)
  return tomorrow.toISOString().split('T')[0]
})

// =============================================
// MÉTODOS (DECLARAR ANTES DE LOS WATCHERS)
// =============================================

const loadDriverData = (driver) => {
  console.log('📥 Cargando datos del conductor completo:', driver)
  console.log('🔍 Tipo de license_exp:', typeof driver.license_exp, '| Valor:', driver.license_exp)
  console.log('🔍 Tipo de date_entry:', typeof driver.date_entry, '| Valor:', driver.date_entry)
  
  // Convertir fechas ISO a formato YYYY-MM-DD para inputs type="date"
  const formatDateForInput = (isoDate) => {
    if (!isoDate) return ''
    return isoDate.split('T')[0]
  }
  
  formData.value = {
    name_driver: driver.name_driver || '',
    id_card: driver.id_card || null,
    cel: driver.cel || '',
    email: driver.email || '',
    available: driver.available ?? true,
    license_cat: driver.license_cat || '',
    license_exp: formatDateForInput(driver.license_exp),
    address_driver: driver.address_driver || '',
    photo_driver: driver.photo_driver || '',
    date_entry: formatDateForInput(driver.date_entry) || getTodayDate(),
    status_driver: driver.status_driver ?? true,
    updated_at: driver.updated_at
  }
  
  console.log('✅ Datos asignados a formData.value.license_exp:', formData.value.license_exp)
  console.log('✅ Datos asignados a formData.value.date_entry:', formData.value.date_entry)
}

const resetErrors = () => {
  clearValidationErrors()
  globalError.value = ''
}

const validateForm = () => {
  const rules = {
    name_driver: [
      (val) => validators.required(val, 'El nombre es obligatorio'),
      (val) => validators.minLength(val, 3, 'El nombre debe tener al menos 3 caracteres')
    ],
    id_card: [
      (val) => validators.required(val, 'La cédula es obligatoria'),
      (val) => validators.positiveNumber(val, 'La cédula debe ser un número válido')
    ],
    cel: [
      (val) => validators.required(val, 'El teléfono es obligatorio'),
      (val) => validators.pattern(val, PHONE_REGEX, 'El teléfono debe tener entre 7 y 15 dígitos')
    ],
    email: [
      (val) => validators.required(val, 'El email es obligatorio'),
      (val) => validators.pattern(val, EMAIL_REGEX, 'El email no tiene un formato válido')
    ],
    license_cat: [
      (val) => validators.required(val, 'La categoría de licencia es obligatoria')
    ],
    license_exp: [
      (val) => validators.required(val, 'La fecha de vencimiento es obligatoria'),
      (val) => validators.futureDate(val, 'La fecha de vencimiento debe ser futura')
    ]
  }

  // Validaciones de password solo al crear
  if (!isEditMode.value) {
    rules.password = [
      (val) => validators.required(val, 'La contraseña es obligatoria'),
      (val) => validators.minLength(val, 8, 'La contraseña debe tener al menos 8 caracteres')
    ]
    rules.password_confirm = [
      (val) => validators.required(val, 'Debe confirmar la contraseña'),
      (val) => val === formData.value.password ? null : 'Las contraseñas no coinciden'
    ]
  }

  return runValidation(formData.value, rules)
}

const handleSubmit = async () => {
  if (!validateForm()) {
    globalError.value = 'Por favor corrija los errores antes de continuar'
    return
  }

  isSubmitting.value = true
  globalError.value = ''

  try {
    const driverData = {
      ...formData.value,
      user_create: authStore.userId || 'system',
      user_update: isEditMode.value ? (authStore.userId || 'system') : null
    }

    // Remover password_confirm antes de enviar (solo necesitamos password)
    delete driverData.password_confirm

    // Si estamos editando, NO enviar password
    if (isEditMode.value) {
      delete driverData.password
      const result = await driversStore.updateDriver(props.data.id, driverData)
      if (!result.success) {
        throw new Error(result.error)
      }
    } else {
      // Al crear, asegurar que password esté presente
      if (!driverData.password) {
        throw new Error('La contraseña es requerida')
      }
      const result = await driversStore.createDriver(driverData)
      if (!result.success) {
        throw new Error(result.error)
      }
    }

    handleClose()
    resetForm()
  } catch (error) {
    console.error('Error al guardar conductor:', error)
    globalError.value = error.message || 'Error al guardar el conductor'
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
    // TODO: Implementar subida a servidor/storage (AWS S3, Cloudinary, etc.)
    // Por ahora, usamos una URL temporal local para preview
    const temporaryUrl = URL.createObjectURL(file)
    formData.value.photo_driver = temporaryUrl
    
    // Aquí deberías subir la imagen a tu servidor y obtener la URL real
    // Ejemplo con FormData para enviar al backend:
    /*
    const formDataUpload = new FormData()
    formDataUpload.append('photo', file)
    
    const response = await apiClient.post('/upload/driver-photo', formDataUpload, {
      headers: { 'Content-Type': 'multipart/form-data' }
    })
    
    formData.value.photo_driver = response.data.url
    */
    
    console.warn('⚠️ Imagen cargada temporalmente. Debes implementar la subida al servidor.')
    console.log('📁 Archivo seleccionado:', file.name, 'Tamaño:', (file.size / 1024).toFixed(2), 'KB')
  } catch (error) {
    console.error('Error al procesar imagen:', error)
    alert('Error al procesar la imagen')
  }
}

const formatDateTime = (dateTime) => {
  if (!dateTime) return 'N/A'
  const date = new Date(dateTime)
  return date.toLocaleString('es-CO', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

// =============================================
// WATCHERS (DESPUÉS DE DECLARAR LOS MÉTODOS)
// =============================================

watch(() => props.data, (newDriver) => {
  if (newDriver) {
    loadDriverData(newDriver)
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

.readonly-field {
  background: #f8fafc !important;
  cursor: not-allowed;
}

.field-help {
  display: block;
  margin-top: 6px;
  color: #64748b;
  font-size: 12px;
  font-style: italic;
}

.error-message {
  display: block;
  margin-top: 6px;
  color: #ef4444;
  font-size: 12px;
  font-weight: 500;
}

.checkbox-group {
  margin-bottom: 12px;
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: 12px;
  cursor: pointer;
  padding: 12px;
  border-radius: 8px;
  transition: background 0.2s ease;
}

.checkbox-label:hover {
  background: #f8fafc;
}

.checkbox-label input[type="checkbox"] {
  width: 20px;
  height: 20px;
  cursor: pointer;
}

.checkbox-label span {
  color: #1e293b;
  font-size: 14px;
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