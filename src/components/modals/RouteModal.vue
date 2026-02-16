<template>
  <div class="form-grid">
    <!-- ID solo visible en modo edición (no editable) -->
    <div v-if="isEdit" class="form-group">
      <label for="route-id">ID de Ruta</label>
      <input
        type="text"
        id="route-id"
        :value="formData.id"
        class="form-input"
        disabled
      >
      <span class="hint-text">El ID no se puede modificar</span>
    </div>
    <div class="form-group" :class="{ 'full-width': !isEdit }">
      <label for="route-name">Nombre de Ruta *</label>
      <input
        type="text"
        id="route-name"
        v-model="formData.name"
        placeholder="Ej: Ruta Centro - Norte"
        required
        class="form-input"
        :class="{ error: errors.name }"
      >
      <span v-if="errors.name" class="error-message">{{ errors.name }}</span>
    </div>
    <div class="form-group" :class="{ 'full-width': isEdit }">
      <label for="route-color">Color de Ruta</label>
      <input
        type="color"
        id="route-color"
        v-model="formData.color"
        class="form-input color-input"
      >
    </div>
    <div class="form-group full-width">
      <label for="route-description">Descripción</label>
      <textarea
        id="route-description"
        v-model="formData.description"
        rows="3"
        placeholder="Descripción de la ruta..."
        class="form-textarea"
      ></textarea>
    </div>

    <!-- Información de ruta dibujada -->
    <div v-if="formData.path && formData.path.length > 0" class="info-panel route-info-panel">
      <div class="route-info-content">
        <strong>📍 Ruta dibujada:</strong> {{ formData.path.length }} puntos
        <span v-if="isEdit" class="distance-info">
          | Distancia: {{ calculateDistance() }} km
        </span>
      </div>
    </div>
    
    <!-- Nota informativa en modo edición -->
    <div v-if="isEdit" class="info-panel info-note">
      <strong>ℹ️ Información:</strong> Los puntos de la ruta no se pueden modificar. Si necesitas cambiar el recorrido, crea una nueva ruta.
    </div>
    
    <!-- Nota informativa en modo creación -->
    <div v-if="!isEdit" class="info-panel info-note">
      <strong>💡 Nota:</strong> El ID de la ruta se generará automáticamente al guardar.
    </div>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue'
import { useRoutesStore } from '../../stores/routes'
import { useAppStore } from '../../stores/app'

const props = defineProps({
  data: {
    type: Object,
    default: () => ({})
  },
  isEdit: {
    type: Boolean,
    default: false
  }
})

const routesStore = useRoutesStore()
const appStore = useAppStore()

// Estado del formulario
const formData = ref({
  id: '',
  name: '',
  color: '#ef4444',
  description: '',
  path: [],
  user: 'admin' // Usuario por defecto para auditoría
})

const errors = ref({})

// Watchers
watch(() => props.data, (newData) => {
  if (newData && props.isEdit) {
    // Modo edición: cargar todos los datos
    formData.value = { ...newData }
  } else if (newData && newData.path) {
    // Modo nuevo con path dibujado
    formData.value = {
      id: '', // Se genera en el backend
      name: '',
      color: '#ef4444',
      description: '',
      path: newData.path,
      user: 'admin'
    }
  } else if (!props.isEdit) {
    // Modo nuevo sin path
    formData.value = {
      id: '', // Se genera en el backend
      name: '',
      color: '#ef4444',
      description: '',
      path: [],
      user: 'admin'
    }
  }
}, { immediate: true })

// Métodos
const calculateDistance = () => {
  if (!formData.value.path || formData.value.path.length < 2) return '0.00'
  
  let distance = 0
  for (let i = 0; i < formData.value.path.length - 1; i++) {
    const [lat1, lng1] = formData.value.path[i]
    const [lat2, lng2] = formData.value.path[i + 1]
    
    // Fórmula de distancia euclidiana simple (aproximada)
    const d = Math.sqrt(Math.pow(lat2 - lat1, 2) + Math.pow(lng2 - lng1, 2))
    distance += d
  }
  
  // Convertir a km (aproximado: 1 grado ≈ 111 km)
  return (distance * 111).toFixed(2)
}

const validateForm = () => {
  errors.value = {}

  if (!formData.value.name?.trim()) {
    errors.value.name = 'El nombre de ruta es obligatorio'
  }
  
  // Solo validar path en modo creación
  if (!props.isEdit && (!formData.value.path || formData.value.path.length < 2)) {
    errors.value.path = 'La ruta debe tener al menos 2 puntos'
    alert('Por favor dibuja la ruta en el mapa con al menos 2 puntos')
  }

  return Object.keys(errors.value).length === 0
}

const handleSave = () => {
  if (!validateForm()) {
    return
  }

  const routeData = {
    name: formData.value.name.trim(),
    color: formData.value.color,
    description: formData.value.description?.trim() || '',
    path: formData.value.path || [],
    user: formData.value.user || 'admin'
  }

  try {
    if (props.isEdit) {
      // En edición, incluir el ID existente
      routeData.id = formData.value.id
      routesStore.updateRoute(props.data.id, routeData)
      alert(`Ruta "${routeData.name}" actualizada exitosamente`)
    } else {
      // En creación, el backend genera el id_route
      routesStore.addRoute(routeData)
      alert(`Ruta "${routeData.name}" creada exitosamente`)
    }

    // Limpiar estado de dibujo
    appStore.stopRouteDrawing()
    appStore.clearRoutePoints()
    
    appStore.closeModal()
  } catch (error) {
    console.error('Error saving route:', error)
    alert('Error al guardar la ruta')
  }
}

const handleCancel = () => {
  // Limpiar estado de dibujo por si acaso
  appStore.stopRouteDrawing()
  appStore.clearRoutePoints()
  
  appStore.closeModal()
}

// Exponer métodos
defineExpose({
  handleSave,
  handleCancel
})
</script>

<style scoped>
.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.form-group.full-width {
  grid-column: 1 / -1;
}

.form-group label {
  font-weight: 500;
  color: #374151;
  font-size: 14px;
}

.form-input,
.form-textarea {
  padding: 12px 16px;
  border: 2px solid #e5e7eb;
  border-radius: 8px;
  font-size: 14px;
  transition: all 0.3s ease;
  background: white;
}

.form-input:focus,
.form-textarea:focus {
  outline: none;
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.form-textarea {
  resize: vertical;
  min-height: 80px;
  font-family: inherit;
}

.form-input:disabled {
  background: #f9fafb;
  color: #6b7280;
  cursor: not-allowed;
}

.form-input.error {
  border-color: #ef4444;
}

.error-message {
  color: #ef4444;
  font-size: 12px;
  font-weight: 500;
}

.info-panel {
  background: rgba(59, 130, 246, 0.05);
  border: 1px solid rgba(59, 130, 246, 0.2);
  border-radius: 8px;
  padding: 16px;
  color: #1e40af;
  font-size: 14px;
  line-height: 1.5;
  grid-column: 1 / -1;
}

.info-panel strong {
  color: #1d4ed8;
}

.info-panel.info-note {
  background: rgba(156, 163, 175, 0.1);
  border-color: rgba(156, 163, 175, 0.3);
  color: #4b5563;
}

.info-panel.info-note strong {
  color: #374151;
}

.route-info-content {
  display: block;
}

.distance-info {
  color: #6366f1;
  font-size: 13px;
  margin-left: 8px;
}

.hint-text {
  font-size: 12px;
  color: #9ca3af;
  font-style: italic;
}

/* Responsive */
@media (max-width: 768px) {
  .form-grid {
    grid-template-columns: 1fr;
    gap: 16px;
  }
}
</style>