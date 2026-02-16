<template>
  <!-- Generic Modal -->
  <div v-if="activeModal" id="generic-modal" class="modal" @click.self="closeModal">
    <div class="modal-content">
      <div class="modal-header">
        <h2 id="modal-title">{{ modalTitle }}</h2>
        <button class="modal-close" @click="closeModal">&times;</button>
      </div>
      <div class="modal-body" id="modal-body">
        <component :is="currentModalComponent" v-bind="modalProps" ref="modalComponentRef" />
      </div>
      <div v-if="showModalFooter" class="modal-footer">
        <button class="btn secondary" @click="closeModal">Cancelar</button>
        <button class="btn primary" id="modal-save" @click="handleSave">Guardar</button>
      </div>
    </div>
  </div>

  <!-- Delete Confirmation Modal -->
  <div v-if="showDeleteModal" id="delete-modal" class="modal" @click.self="closeDeleteModal">
    <div class="modal-content">
      <div class="modal-header">
        <h2 id="delete-modal-title">Confirmar Eliminación</h2>
      </div>
      <div class="modal-body">
        <p id="delete-modal-message">{{ deleteMessage }}</p>
      </div>
      <div class="modal-footer">
        <button class="btn secondary" @click="closeDeleteModal">Cancelar</button>
        <button class="btn danger" id="confirm-delete-btn" @click="confirmDelete">Eliminar</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue'
import { useAppStore } from '../stores/app'

// Import modal components
import BusModal from './modals/BusModal.vue'
import DriverModal from './modals/DriverModal.vue'
import RouteModal from './modals/RouteModal.vue'
import ShiftModal from './modals/ShiftModal.vue'
import ShiftsModal from './modals/ShiftsModal.vue'

const appStore = useAppStore()

// Referencia al componente modal hijo
const modalComponentRef = ref(null)

// Estado computado
const activeModal = computed(() => appStore.activeModal)
const modalData = computed(() => appStore.modalData)

// Debug: ver cuando cambia el modal activo
watch(activeModal, (newModal) => {
  console.log('📋 AppModals - Modal activo cambió:', newModal)
})

const modalTitle = computed(() => {
  const titles = {
    bus: 'Nuevo Bus',
    editBus: 'Editar Bus',
    driver: 'Nuevo Conductor',
    editDriver: 'Editar Conductor',
    route: 'Nueva Ruta',
    editRoute: 'Editar Ruta',
    shift: 'Nuevo Turno',
    editShift: 'Editar Turno',
    shifts: 'Panel de Despacho de Viajes'
  }
  return titles[activeModal.value] || 'Modal'
})

const currentModalComponent = computed(() => {
  const components = {
    bus: BusModal,
    editBus: BusModal,
    driver: DriverModal,
    editDriver: DriverModal,
    route: RouteModal,
    editRoute: RouteModal,
    shift: ShiftModal,
    editShift: ShiftModal,
    shifts: ShiftsModal
  }
  return components[activeModal.value] || null
})

const modalProps = computed(() => ({
  data: modalData.value,
  isEdit: activeModal.value?.startsWith('edit')
}))

// Determinar si mostrar el footer con botones genéricos
// Los modales de driver y bus tienen sus propios botones, así que no necesitan el footer
const showModalFooter = computed(() => {
  const modalsWithoutFooter = ['driver', 'editDriver', 'bus', 'editBus']
  return !modalsWithoutFooter.includes(activeModal.value)
})

// Estado local para delete modal
const showDeleteModal = ref(false)
const deleteMessage = ref('')
const deleteCallback = ref(null)

// Métodos
const closeModal = () => {
  appStore.closeModal()
}

const handleSave = () => {
  // Invocar el método handleSave del componente modal hijo
  if (modalComponentRef.value && typeof modalComponentRef.value.handleSave === 'function') {
    modalComponentRef.value.handleSave()
  } else {
    console.warn('Modal component does not have handleSave method')
    closeModal()
  }
}

const openDeleteModal = (message, callback) => {
  deleteMessage.value = message
  deleteCallback.value = callback
  showDeleteModal.value = true
}

const closeDeleteModal = () => {
  showDeleteModal.value = false
  deleteMessage.value = ''
  deleteCallback.value = null
}

const confirmDelete = () => {
  if (deleteCallback.value) {
    deleteCallback.value()
  }
  closeDeleteModal()
}

// Exponer métodos globalmente para uso en otros componentes
defineExpose({
  openDeleteModal
})
</script>

<style scoped>
/* Modal styles - migrated from original CSS */
.modal {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(0, 0, 0, 0.6);
  z-index: 10000;
  display: flex;
  justify-content: center;
  align-items: center;
  backdrop-filter: blur(4px);
  animation: fadeIn 0.3s ease;
}

.modal-content {
  background: linear-gradient(145deg, #ffffff 0%, #f8fafc 100%);
  padding: 0;
  border-radius: 20px;
  width: 95%;
  max-width: 500px;
  max-height: 90vh;
  text-align: left;
  box-shadow:
    0 25px 50px rgba(0, 0, 0, 0.2),
    0 10px 25px rgba(0, 0, 0, 0.1);
  overflow: hidden;
  animation: slideIn 0.3s ease;
}

.modal-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  margin: 0;
  padding: 25px 30px;
  font-weight: 500;
  font-size: 20px;
  text-align: center;
  box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3);
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.modal-header h2 {
  margin: 0;
  flex: 1;
}

.modal-close {
  background: none;
  border: none;
  color: white;
  font-size: 24px;
  cursor: pointer;
  padding: 4px;
  border-radius: 4px;
  transition: all 0.2s ease;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.modal-close:hover {
  background: rgba(255, 255, 255, 0.2);
}

.modal-body {
  padding: 30px;
  max-height: 60vh;
  overflow-y: auto;
}

.modal-footer {
  padding: 20px 30px;
  background: #f8fafc;
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  border-top: 1px solid #e2e8f0;
}

.btn {
  padding: 12px 24px;
  border-radius: 8px;
  font-weight: 500;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.2s ease;
  border: none;
  display: inline-flex;
  align-items: center;
  gap: 8px;
  text-decoration: none;
  min-width: 100px;
  justify-content: center;
}

.btn.primary {
  background: linear-gradient(135deg, #48bb78 0%, #38a169 100%);
  color: white;
  box-shadow: 0 4px 15px rgba(72, 187, 120, 0.3);
}

.btn.primary:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 25px rgba(72, 187, 120, 0.4);
}

.btn.secondary {
  background: #e2e8f0;
  color: #4a5568;
  border: 1px solid #cbd5e0;
}

.btn.secondary:hover {
  background: #cbd5e0;
  transform: translateY(-1px);
}

.btn.danger {
  background: #ef4444;
  color: white;
}

.btn.danger:hover {
  background: #dc2626;
  transform: translateY(-1px);
}

/* Animations */
@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes slideIn {
  from { transform: translateY(-20px); opacity: 0; }
  to { transform: translateY(0); opacity: 1; }
}

/* Responsive */
@media (max-width: 768px) {
  .modal-content {
    width: 95%;
    margin: 10px;
  }

  .modal-header,
  .modal-body,
  .modal-footer {
    padding-left: 20px;
    padding-right: 20px;
  }

  .modal-footer {
    flex-direction: column;
  }

  .btn {
    width: 100%;
  }
}

/* Scrollbar styling */
.modal-body::-webkit-scrollbar {
  width: 6px;
}

.modal-body::-webkit-scrollbar-track {
  background: #f1f5f9;
  border-radius: 3px;
}

.modal-body::-webkit-scrollbar-thumb {
  background: #cbd5e1;
  border-radius: 3px;
}

.modal-body::-webkit-scrollbar-thumb:hover {
  background: #94a3b8;
}
</style>