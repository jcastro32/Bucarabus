<script setup>
import { computed } from 'vue'
import { useAppStore } from '../stores/app'
import { useRoutesStore } from '../stores/routes'

const appStore = useAppStore()
const routesStore = useRoutesStore()

const routes = computed(() => routesStore.routesList)

// Función para iniciar el dibujo de una nueva ruta
const openNewRouteModal = () => {
  // Activar modo de dibujo en el mapa
  appStore.startRouteDrawing()
}

// Función para editar una ruta existente
const editRoute = (route) => {
  appStore.openModal('editRoute', route)
}

// 🆕 Computed para determinar el texto y acción del botón
const allRoutesVisible = computed(() => {
  if (routes.value.length === 0) return false
  return routes.value.every(route => route.visible)
})

const toggleAllRoutesAction = () => {
  if (allRoutesVisible.value) {
    routesStore.hideAllRoutes()
  } else {
    routesStore.showAllRoutes()
  }
}

const toggleAllRoutesText = computed(() => {
  if (routes.value.length === 0) return 'Mostrar Todas'
  return allRoutesVisible.value ? 'Ocultar Todas' : 'Mostrar Todas'
})



// 🆕 NUEVA FUNCIÓN: Eliminar ruta con confirmación
const deleteRoute = async (route) => {
  // 1️⃣ Pedir confirmación al usuario
  const confirmed = confirm(
    `¿Estás seguro de eliminar la ruta "${route.name}"?\n\nEsta acción no se puede deshacer.`
  )
  
  // 2️⃣ Si el usuario confirma, eliminar
  if (confirmed) {
    try {
      // 3️⃣ Llamar al store para eliminar
      const response = await routesStore.deleteRoute(route.id)
      
      // 4️⃣ Mostrar mensaje de éxito (con advertencia si existe)
      let message = `Ruta "${route.name}" eliminada exitosamente`
      
      if (response.warning) {
        message += '\n\n⚠️ ADVERTENCIA:\n' + response.warning
      }
      
      alert(message)
    } catch (error) {
      // 5️⃣ Manejar errores específicos
      console.error('Error eliminando ruta:', error)
      
      let errorMessage = 'Error al eliminar la ruta'
      
      if (error.code === 'ROUTE_HAS_ACTIVE_TRIPS') {
        errorMessage = '❌ No se puede eliminar la ruta porque tiene viajes activos en curso.\n\nEspera a que terminen los viajes para poder eliminarla.'
      } else if (error.code === 'ROUTE_NOT_FOUND') {
        errorMessage = '❌ La ruta no existe o ya fue eliminada.'
      } else {
        errorMessage += ':\n' + (error.message || 'Error desconocido')
      }
      
      alert(errorMessage)
    }
  }
}


</script>

<template>
  <div class="routes-widget">
    <div class="widget-card">
      <div class="widget-header">
        <h3>🛣️ Control de Rutas</h3>
      </div>
      <div class="widget-content">
        <div class="routes-actions">
          <button class="action-btn primary" @click="openNewRouteModal">
            <span class="btn-icon">➕</span>
            Nueva Ruta

            <!--boton cambia dinámicamente las rutas-->
          </button>
          <button class="action-btn secondary" @click="toggleAllRoutesAction" :disabled="routes.length === 0">
            <span class="btn-icon">🗺️</span>
            {{ toggleAllRoutesText }}
          </button>
        </div>

        <div class="routes-list-scroll">
          <div class="routes-list">
            <div v-if="routes.length === 0" class="no-routes">
              No hay rutas registradas
            </div>
            <div v-else class="route-items">
              <div 
                v-for="route in routes" 
                :key="route.id" 
                class="route-item"
                :class="{ 'route-active': route.visible }"
              >
                <div class="route-info">
                  <h4>{{ route.name }}</h4>
                  <p class="route-description">{{ route.description || 'Sin descripción' }}</p>
                  <div class="route-stats">
                    <span class="stat">📍 {{ route.stops?.length || 0 }} paradas</span>
                    <span class="stat">🚌 {{ route.buses?.length || 0 }} buses</span>
                  </div>
                </div>
                <div class="route-actions">
                  <!-- Botón para mostrar/ocultar -->
                  <button 
                    class="icon-btn" 
                    @click="routesStore.toggleRouteVisibility(route.id)"
                    :title="route.visible ? 'Ocultar en mapa' : 'Mostrar en mapa'"
                  >
                    {{ route.visible ? '👁️' : '👁️‍🗨️' }}
                  </button>
                  
                  <!-- Botón para editar -->
                  <button 
                    class="icon-btn" 
                    @click="editRoute(route)"
                    title="Editar ruta"
                  >
                    ✏️
                  </button>
                  
                  <!-- 🆕 NUEVO BOTÓN: Eliminar -->
                  <button 
                    class="icon-btn danger" 
                    @click="deleteRoute(route)"
                    title="Eliminar ruta"
                  >
                    🗑️
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.routes-widget {
  max-width: 380px;
}
.widget-card {
  background: rgba(255, 255, 255, 0.95);
  border-radius: 16px;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.15);
  backdrop-filter: blur(10px);
}
.widget-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 20px;
  color: white;
  border-radius: 16px 16px 0 0;
}
.widget-header h3 {
  margin: 0;
  font-size: 1.25rem;
  font-weight: 600;
}
.widget-content {
  padding: 20px;
}
.routes-actions {
  display: flex;
  gap: 10px;
  margin-bottom: 20px;
}
.action-btn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 12px 16px;
  border: none;
  border-radius: 10px;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s ease;
}
.action-btn.primary {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
}
.action-btn.primary:hover {
  transform: translateY(-2px);
  box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
}
.action-btn.secondary {
  background: white;
  color: #667eea;
  border: 2px solid #667eea;
}
.action-btn.secondary:hover:not(:disabled) {
  background: #667eea;
  color: white;
}
.action-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.btn-icon {
  font-size: 1.1rem;
}
.routes-list-scroll {
  max-height: calc(100vh - 350px);
  overflow-y: auto;
  margin: 0 -20px;
  padding: 0 20px;
}
.routes-list-scroll::-webkit-scrollbar {
  width: 6px;
}
.routes-list-scroll::-webkit-scrollbar-track {
  background: #f1f5f9;
  border-radius: 10px;
}
.routes-list-scroll::-webkit-scrollbar-thumb {
  background: #cbd5e1;
  border-radius: 10px;
}
.routes-list-scroll::-webkit-scrollbar-thumb:hover {
  background: #94a3b8;
}
.no-routes {
  text-align: center;
  padding: 40px 20px;
  color: #94a3b8;
  font-size: 0.95rem;
}
.route-items {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.route-item {
  background: white;
  border: 2px solid #e2e8f0;
  border-radius: 12px;
  padding: 16px;
  display: flex;
  justify-content: space-between;
  align-items: start;
  transition: all 0.3s ease;
}
.route-item:hover {
  border-color: #667eea;
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.15);
}
.route-item.route-active {
  border-color: #10b981;
  background: linear-gradient(135deg, rgba(16, 185, 129, 0.05) 0%, rgba(16, 185, 129, 0.02) 100%);
}
.route-info {
  flex: 1;
}
.route-info h4 {
  margin: 0 0 8px 0;
  color: #1e293b;
  font-size: 1rem;
  font-weight: 600;
}
.route-description {
  margin: 0 0 12px 0;
  color: #64748b;
  font-size: 0.85rem;
}
.route-stats {
  display: flex;
  gap: 16px;
}
.stat {
  font-size: 0.8rem;
  color: #64748b;
  display: flex;
  align-items: center;
  gap: 4px;
}
.route-actions {
  display: flex;
  gap: 8px;
}
.icon-btn {
  width: 36px;
  height: 36px;
  border: none;
  background: #f1f5f9;
  border-radius: 8px;
  cursor: pointer;
  font-size: 1.1rem;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s ease;
}
.icon-btn:hover {
  background: #e2e8f0;
  transform: scale(1.1);
}

/* 🆕 Estilo para botón de eliminar */
.icon-btn.danger {
  background: #fee2e2;  /* Fondo rojo claro */
  color: #dc2626;       /* Texto rojo */
}

.icon-btn.danger:hover {
  background: #dc2626;  /* Fondo rojo intenso al pasar mouse */
  color: white;         /* Texto blanco */
  transform: scale(1.1); /* Hace el botón un poco más grande */
}
</style>
