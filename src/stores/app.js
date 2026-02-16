import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useAppStore = defineStore('app', () => {
  // Estado
  const currentUser = ref({
    name: 'Admin BucaraBus',
    role: 'Administrator'
  })

  const sidebarOpen = ref(true)
  const isAuthenticated = ref(true) // Para desarrollo, siempre true

  // Estado del mapa
  const mapInstance = ref(null)
  const isDrawingRoute = ref(false)
  const currentRoutePoints = ref([])
  const routeMarkers = ref([])

  // Estado de modales
  const activeModal = ref(null)
  const modalData = ref(null)
  
  // Estado de modales individuales
  const modals = ref({
    driver: false,
    bus: false,
    route: false,
    shift: false,
    shifts: false
  })

  // Getters computados
  const activeBusesCount = computed(() => {
    const busesStore = useBusesStore()
    return busesStore.buses.filter(bus => bus.status_bus).length
  })

  const totalRoutesCount = computed(() => {
    const routesStore = useRoutesStore()
    return Object.keys(routesStore.routes).length
  })

  // Acciones
  const toggleSidebar = () => {
    sidebarOpen.value = !sidebarOpen.value
  }

  const setMapInstance = (map) => {
    mapInstance.value = map
  }

  const startRouteDrawing = () => {
    isDrawingRoute.value = true
    currentRoutePoints.value = []
    routeMarkers.value = []
  }

  const stopRouteDrawing = () => {
    isDrawingRoute.value = false
  }

  const addRoutePoint = (point) => {
    currentRoutePoints.value.push(point)
  }

  const removeLastRoutePoint = () => {
    if (currentRoutePoints.value.length > 0) {
      currentRoutePoints.value.pop()
    }
  }

  const clearRoutePoints = () => {
    currentRoutePoints.value = []
    routeMarkers.value.forEach(marker => {
      if (mapInstance.value) {
        mapInstance.value.removeLayer(marker)
      }
    })
    routeMarkers.value = []
  }

  const openModal = (modalType, data = null) => {
    activeModal.value = modalType
    modalData.value = data
    // Actualizar el estado específico del modal
    if (modals.value.hasOwnProperty(modalType)) {
      modals.value[modalType] = true
    }
  }

  const closeModal = (modalType = null) => {
    if (modalType) {
      // Cerrar modal específico
      if (modals.value.hasOwnProperty(modalType)) {
        modals.value[modalType] = false
      }
      if (activeModal.value === modalType) {
        activeModal.value = null
        modalData.value = null
      }
    } else {
      // Cerrar modal activo
      if (activeModal.value && modals.value.hasOwnProperty(activeModal.value)) {
        modals.value[activeModal.value] = false
      }
      activeModal.value = null
      modalData.value = null
    }
  }

  return {
    // Estado
    currentUser,
    sidebarOpen,
    isAuthenticated,
    mapInstance,
    isDrawingRoute,
    currentRoutePoints,
    routeMarkers,
    activeModal,
    modalData,
    modals,

    // Getters
    activeBusesCount,
    totalRoutesCount,

    // Acciones
    toggleSidebar,
    setMapInstance,
    startRouteDrawing,
    stopRouteDrawing,
    addRoutePoint,
    removeLastRoutePoint,
    clearRoutePoints,
    openModal,
    closeModal
  }
})

// Importar otros stores para evitar dependencias circulares
import { useBusesStore } from './buses'
import { useRoutesStore } from './routes'