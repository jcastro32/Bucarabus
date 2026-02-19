import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import apiClient from '../api/client'
import { SYSTEM_USER_ID } from '../constants/system'

export const useDriversStore = defineStore('drivers', () => {
  // =============================================
  // STATE
  // =============================================
  const drivers = ref([])
  const loading = ref(false)
  const error = ref(null)

  // =============================================
  // GETTERS (COMPUTED)
  // =============================================
  const totalDrivers = computed(() => drivers.value.length)

  const availableDrivers = computed(() => 
    drivers.value.filter(driver => driver.available && driver.status_driver)
  )

  const unavailableDrivers = computed(() => 
    drivers.value.filter(driver => !driver.available || !driver.status_driver)
  )

  const averageExperience = computed(() => {
    if (drivers.value.length === 0) return 0
    const total = drivers.value.reduce((sum, driver) => sum + (driver.experience || 0), 0)
    return (total / drivers.value.length).toFixed(1)
  })

  const driversByCategory = computed(() => {
    return drivers.value.reduce((acc, driver) => {
      const cat = driver.license_cat || 'Sin categoría'
      acc[cat] = (acc[cat] || 0) + 1
      return acc
    }, {})
  })

  const expiredLicenses = computed(() => {
    const today = new Date()
    return drivers.value.filter(driver => {
      if (!driver.license_exp) return false
      const expDate = new Date(driver.license_exp)
      return expDate < today
    })
  })

  const expiringSoonLicenses = computed(() => {
    const today = new Date()
    const thirtyDaysFromNow = new Date(today.getTime() + (30 * 24 * 60 * 60 * 1000))
    
    return drivers.value.filter(driver => {
      if (!driver.license_exp) return false
      const expDate = new Date(driver.license_exp)
      return expDate > today && expDate <= thirtyDaysFromNow
    })
  })

  // =============================================
  // ACTIONS
  // =============================================

  /**
   * Obtener todos los conductores
   */
  async function fetchDrivers() {
    loading.value = true
    error.value = null

    try {
      console.log('🔄 Iniciando fetchDrivers...')
      const response = await apiClient.get('/drivers')
      
      console.log('📥 Respuesta completa:', response)
      console.log('📊 response.data:', response.data)
      
      // Si la respuesta tiene data.data (formato del backend)
      const driversData = response.data.data || response.data
      
      console.log('📋 driversData:', driversData)
      console.log('📏 Cantidad de conductores:', driversData.length)
      
      // Mapear campos de BD a formato frontend
      drivers.value = driversData.map(mapDriverFromDB)
      
      console.log('✅ Conductores cargados:', drivers.value.length)
      console.log('👥 Conductores mapeados:', drivers.value)
      return { success: true, data: drivers.value }
    } catch (err) {
      console.error('❌ Error al obtener conductores:', err)
      console.error('📛 Error response:', err.response)
      error.value = err.message
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  /**
   * Crear nuevo conductor
   */
  async function createDriver(driverData) {
    loading.value = true
    error.value = null

    try {
      // Preparar datos para enviar a la API
      const payload = {
        name_driver: driverData.name_driver,
        id_card: driverData.id_card,
        cel: driverData.cel,
        email: driverData.email,
        password: driverData.password,  // Password requerido al crear
        license_cat: driverData.license_cat,
        license_exp: driverData.license_exp,
        address_driver: driverData.address_driver || null,
        photo_driver: driverData.photo_driver || null,
        user_create: driverData.user_create || SYSTEM_USER_ID
      }

      console.log('📤 Enviando datos a la API (sin password por seguridad):', { ...payload, password: '***' })
      
      const response = await apiClient.post('/drivers', payload)

      console.log('📥 Respuesta de la API:', response.data)

      if (!response.data.success) {
        throw new Error(response.data.message || 'Error al crear conductor')
      }

      // Recargar la lista de conductores desde la BD
      await fetchDrivers()

      return { 
        success: true, 
        message: response.data.message,
        driver_id: response.data.data?.id_user
      }
    } catch (err) {
      console.error('❌ Error al crear conductor:', err)
      error.value = err.response?.data?.message || err.message
      return { 
        success: false, 
        error: err.response?.data?.message || err.message 
      }
    } finally {
      loading.value = false
    }
  }

  /**
   * Actualizar conductor existente
   */
  async function updateDriver(driverId, driverData) {
    loading.value = true
    error.value = null

    try {
      const payload = {
        name_driver: driverData.name_driver,
        cel: driverData.cel,
        email: driverData.email,
        available: driverData.available,
        license_cat: driverData.license_cat,
        license_exp: driverData.license_exp,
        address_driver: driverData.address_driver || null,
        photo_driver: driverData.photo_driver || null,
        date_entry: driverData.date_entry,
        status_driver: driverData.status_driver,
        user_update: driverData.user_update || SYSTEM_USER_ID
      }

      console.log('📤 Actualizando conductor:', driverId, payload)
      
      const response = await apiClient.put(`/drivers/${driverId}`, payload)

      console.log('📥 Respuesta de actualización:', response.data)

      if (!response.data.success) {
        throw new Error(response.data.message || 'Error al actualizar conductor')
      }

      // Recargar la lista de conductores desde la BD
      await fetchDrivers()

      return { 
        success: true, 
        message: response.data.message 
      }
    } catch (err) {
      console.error('❌ Error al actualizar conductor:', err)
      error.value = err.response?.data?.message || err.message
      return { 
        success: false, 
        error: err.response?.data?.message || err.message 
      }
    } finally {
      loading.value = false
    }
  }

  /**
   * Eliminar conductor
   */
  async function deleteDriver(driverId) {
    loading.value = true
    error.value = null

    try {
      console.log('🗑️ Eliminando conductor:', driverId)
      
      const response = await apiClient.delete(`/drivers/${driverId}`)

      console.log('✅ Respuesta de eliminación:', response.data)

      if (!response.data.success) {
        throw new Error(response.data.message || 'Error al eliminar conductor')
      }

      // Eliminar del estado local
      drivers.value = drivers.value.filter(d => d.id !== driverId)

      return { 
        success: true, 
        message: response.data.message 
      }
    } catch (err) {
      console.error('❌ Error al eliminar conductor:', err)
      error.value = err.response?.data?.message || err.message
      return { 
        success: false, 
        error: err.response?.data?.message || err.message 
      }
    } finally {
      loading.value = false
    }
  }

  /**
   * Cambiar disponibilidad del conductor
   */
  async function toggleDriverAvailability(driverId) {
    const driver = drivers.value.find(d => d.id === driverId)
    if (!driver) {
      return { success: false, error: 'Conductor no encontrado' }
    }

    const newAvailability = !driver.available

    try {
      console.log(`🔄 Cambiando disponibilidad del conductor ${driverId} a ${newAvailability}`)
      
      const response = await apiClient.patch(`/drivers/${driverId}/availability`, {
        available: newAvailability
      })

      console.log('✅ Respuesta del servidor:', response.data)

      if (response.data.success) {
        driver.available = newAvailability
      }

      return response.data
    } catch (err) {
      console.error('❌ Error al cambiar disponibilidad:', err)
      return { success: false, error: err.message }
    }
  }

  /**
   * Buscar conductores
   */
  function searchDrivers(query) {
    if (!query) return drivers.value

    const searchTerm = query.toLowerCase()
    return drivers.value.filter(driver => 
      driver.name_driver?.toLowerCase().includes(searchTerm) ||
      driver.id_card?.toString().includes(searchTerm) ||
      driver.cel?.toString().includes(searchTerm) ||
      driver.email?.toLowerCase().includes(searchTerm)
    )
  }

  /**
   * Obtener conductor por ID
   */
  function getDriverById(driverId) {
    return drivers.value.find(d => d.id === driverId)
  }

  /**
   * Validar si la licencia está vigente
   */
  function isLicenseValid(driverId) {
    const driver = drivers.value.find(d => d.id === driverId)
    if (!driver || !driver.license_exp) return false

    const today = new Date()
    const expDate = new Date(driver.license_exp)
    return expDate > today
  }

  /**
   * Validar si la licencia vence pronto (próximos 30 días)
   */
  function isLicenseExpiringSoon(driverId) {
    const driver = drivers.value.find(d => d.id === driverId)
    if (!driver || !driver.license_exp) return false

    const today = new Date()
    const expDate = new Date(driver.license_exp)
    const thirtyDaysFromNow = new Date(today.getTime() + (30 * 24 * 60 * 60 * 1000))

    return expDate > today && expDate <= thirtyDaysFromNow
  }

  /**
   * Obtener días hasta vencimiento de licencia
   */
  function getDaysUntilExpiration(driverId) {
    const driver = drivers.value.find(d => d.id === driverId)
    if (!driver || !driver.license_exp) return null

    const today = new Date()
    const expDate = new Date(driver.license_exp)
    const diffTime = expDate - today
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))

    return diffDays
  }

  // =============================================
  // HELPER FUNCTIONS
  // =============================================

  /**
   * Mapear datos de BD a formato frontend
   * Mantener campos en inglés para consistencia con backend
   */
  function mapDriverFromDB(dbDriver) {
    return {
      // IDs y datos básicos
      id: parseInt(dbDriver.id_user) || dbDriver.id_user,
      id_user: dbDriver.id_user,
      name_driver: dbDriver.name_driver,
      id_card: parseInt(dbDriver.id_card) || dbDriver.id_card,
      cel: dbDriver.cel,
      email: dbDriver.email,
      
      // Estado
      available: dbDriver.available,
      status_driver: dbDriver.status_driver,
      
      // Licencia
      license_cat: dbDriver.license_cat,
      license_exp: dbDriver.license_exp,
      
      // Dirección y foto
      address_driver: dbDriver.address_driver,
      photo_driver: dbDriver.photo_driver,
      
      // Fechas
      date_entry: dbDriver.date_entry,
      created_at: dbDriver.created_at,
      updated_at: dbDriver.updated_at,
      
      // Auditoría
      user_create: dbDriver.user_create,
      user_update: dbDriver.user_update,
      
      // Campos calculados
      experience: calculateExperience(dbDriver.date_entry)
    }
  }

  /**
   * Calcular años de experiencia
   */
  function calculateExperience(dateEntry) {
    if (!dateEntry) return 0
    
    const entryDate = new Date(dateEntry)
    const today = new Date()
    const diffTime = today - entryDate
    const diffYears = diffTime / (1000 * 60 * 60 * 24 * 365.25)
    
    return Math.max(0, Math.floor(diffYears))
  }

  // =============================================
  // RETURN
  // =============================================
  return {
    // State
    drivers,
    loading,
    error,

    // Getters
    totalDrivers,
    availableDrivers,
    unavailableDrivers,
    averageExperience,
    driversByCategory,
    expiredLicenses,
    expiringSoonLicenses,

    // Actions
    fetchDrivers,
    createDriver,
    updateDriver,
    deleteDriver,
    toggleDriverAvailability,
    searchDrivers,
    getDriverById,
    isLicenseValid,
    isLicenseExpiringSoon,
    getDaysUntilExpiration
  }
})