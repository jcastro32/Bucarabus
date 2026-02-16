import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

// Usuarios de prueba
const DEMO_USERS = {
  'admin@bucarabus.com': {
    uid: 'admin-001',
    email: 'admin@bucarabus.com',
    password: 'admin123',
    displayName: 'Administrador',
    role: 'admin',
    avatar: '👨‍💼'
  },
  'conductor@bucarabus.com': {
    uid: 'driver-001',
    email: 'conductor@bucarabus.com',
    password: 'conductor123',
    displayName: 'Conductor',
    role: 'driver',
    avatar: '👨‍✈️'
  },
  'pasajero@bucarabus.com': {
    uid: 'passenger-001',
    email: 'pasajero@bucarabus.com',
    password: 'pasajero123',
    displayName: 'Pasajero',
    role: 'passenger',
    avatar: '👤'
  }
}

export const useAuthStore = defineStore('auth', () => {
  // =============================================
  // STATE
  // =============================================
  const currentUser = ref(null)
  const isAuthenticated = ref(false)
  const loading = ref(false)
  const error = ref(null)

  // =============================================
  // GETTERS
  // =============================================
  const userId = computed(() => currentUser.value?.uid || null)
  const userEmail = computed(() => currentUser.value?.email || null)
  const userName = computed(() => currentUser.value?.displayName || currentUser.value?.email || 'Usuario')
  const userRole = computed(() => currentUser.value?.role || 'guest')
  const userAvatar = computed(() => currentUser.value?.avatar || '👤')

  // =============================================
  // ACTIONS
  // =============================================

  /**
   * Inicializar usuario desde localStorage
   */
  function initializeUser() {
    try {
      const storedUser = localStorage.getItem('bucarabus_user')
      if (storedUser) {
        const userData = JSON.parse(storedUser)
        currentUser.value = userData
        isAuthenticated.value = true
        console.log('✅ Usuario restaurado desde localStorage:', userData.displayName)
      } else {
        console.log('ℹ️ No hay sesión guardada')
      }
    } catch (err) {
      console.error('❌ Error al restaurar usuario:', err)
      localStorage.removeItem('bucarabus_user')
    }
  }

  /**
   * Login con validación de usuarios de prueba
   */
  async function login(email, password) {
    loading.value = true
    error.value = null

    try {
      // Simular delay de red
      await new Promise(resolve => setTimeout(resolve, 800))

      // Validar usuario de prueba
      const demoUser = DEMO_USERS[email.toLowerCase()]
      
      if (!demoUser) {
        throw new Error('Usuario no encontrado')
      }

      if (demoUser.password !== password) {
        throw new Error('Contraseña incorrecta')
      }

      // Login exitoso
      const { password: _, ...userWithoutPassword } = demoUser
      currentUser.value = userWithoutPassword
      isAuthenticated.value = true

      // Guardar en localStorage
      localStorage.setItem('bucarabus_user', JSON.stringify(userWithoutPassword))
      
      console.log('✅ Login exitoso:', userWithoutPassword.displayName)

      return { success: true }
    } catch (err) {
      error.value = err.message
      console.error('❌ Login error:', err.message)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  /**
   * Registro de nuevo usuario
   */
  async function register(userData) {
    loading.value = true
    error.value = null

    try {
      // Simular delay de red
      await new Promise(resolve => setTimeout(resolve, 1000))

      // Validar que el email no exista ya
      if (DEMO_USERS[userData.email.toLowerCase()]) {
        throw new Error('Este correo electrónico ya está registrado')
      }

      // Generar avatar según el rol
      let avatar = '👤'
      if (userData.role === 'admin') avatar = '👨‍💼'
      else if (userData.role === 'driver') avatar = '👨‍✈️'
      else if (userData.role === 'passenger') avatar = '👤'

      // Crear nuevo usuario
      const newUser = {
        uid: `user-${Date.now()}`,
        email: userData.email,
        displayName: userData.name,
        role: userData.role,
        avatar: avatar
      }

      // Agregar a DEMO_USERS (solo en memoria, no persiste en reload)
      DEMO_USERS[userData.email.toLowerCase()] = {
        ...newUser,
        password: userData.password
      }

      // Auto-login después del registro
      currentUser.value = newUser
      isAuthenticated.value = true

      // Guardar en localStorage
      localStorage.setItem('bucarabus_user', JSON.stringify(newUser))
      
      console.log('✅ Registro exitoso:', newUser.displayName)

      return { success: true }
    } catch (err) {
      error.value = err.message
      console.error('❌ Register error:', err.message)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  /**
   * Logout
   */
  async function logout() {
    currentUser.value = null
    isAuthenticated.value = false
    localStorage.removeItem('bucarabus_user')
    console.log('✅ Sesión cerrada')
  }

  /**
   * Actualizar perfil de usuario
   */
  async function updateProfile(data) {
    if (!currentUser.value) return { success: false, error: 'No hay usuario autenticado' }

    try {
      currentUser.value = {
        ...currentUser.value,
        ...data
      }
      return { success: true }
    } catch (err) {
      error.value = err.message
      return { success: false, error: err.message }
    }
  }

  // =============================================
  // INICIALIZACIÓN
  // =============================================
  // Inicializar usuario al cargar el store
  initializeUser()

  // =============================================
  // RETURN
  // =============================================
  return {
    // State
    currentUser,
    isAuthenticated,
    loading,
    error,

    // Getters
    userId,
    userEmail,
    userName,
    userRole,
    userAvatar,

    // Actions
    login,
    register,
    logout,
    updateProfile,
    initializeUser
  }
})
