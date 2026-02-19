import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import apiClient from '../api/client'

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
  const activeRole = ref(null) // Rol actualmente activo

  // =============================================
  // GETTERS
  // =============================================
  const userId = computed(() => currentUser.value?.uid || null)
  const userEmail = computed(() => currentUser.value?.email || null)
  const userName = computed(() => currentUser.value?.displayName || currentUser.value?.email || 'Usuario')
  const userRole = computed(() => activeRole.value || currentUser.value?.role || 'guest')
  const userAvatar = computed(() => currentUser.value?.avatar || '👤')
  
  // Roles disponibles del usuario actual
  const availableRoles = computed(() => {
    if (!currentUser.value?.allRoles || currentUser.value.allRoles.length === 0) {
      return [{ id_role: getRoleId(currentUser.value?.role), role_name: getRoleName(currentUser.value?.role) }]
    }
    return currentUser.value.allRoles
  })
  
  // Verificar si el usuario tiene múltiples roles
  const hasMultipleRoles = computed(() => availableRoles.value.length > 1)

  // =============================================
  // ACTIONS
  // =============================================

  /**
   * Inicializar usuario desde localStorage
   */
  function initializeUser() {
    try {
      const storedUser = localStorage.getItem('bucarabus_user')
      const storedActiveRole = localStorage.getItem('bucarabus_active_role')
      
      if (storedUser) {
        const userData = JSON.parse(storedUser)
        currentUser.value = userData
        isAuthenticated.value = true
        
        // Restaurar rol activo o usar el rol principal
        activeRole.value = storedActiveRole || userData.role
        
        console.log('✅ Usuario restaurado desde localStorage:', userData.displayName, '- Rol activo:', activeRole.value)
      } else {
        console.log('ℹ️ No hay sesión guardada')
      }
    } catch (err) {
      console.error('❌ Error al restaurar usuario:', err)
      localStorage.removeItem('bucarabus_user')
      localStorage.removeItem('bucarabus_active_role')
    }
  }

  /**
   * Login con API backend real
   */
  async function login(email, password) {
    loading.value = true
    error.value = null

    try {
      console.log('🔐 Intentando login con backend:', email)
      
      // Llamar a la API de autenticación
      const response = await apiClient.post('/auth/login', {
        email,
        password
      })

      if (response.data.success) {
        const userData = response.data.data
        
        // Determinar el rol principal del usuario
        let role = 'guest'
        if (userData.roles && userData.roles.length > 0) {
          // Prioridad: Admin > Supervisor > Conductor > Pasajero
          if (userData.roles.some(r => r.id_role === 4)) {
            role = 'admin'
          } else if (userData.roles.some(r => r.id_role === 3)) {
            role = 'supervisor'
          } else if (userData.roles.some(r => r.id_role === 2)) {
            role = 'driver'
          } else if (userData.roles.some(r => r.id_role === 1)) {
            role = 'passenger'
          }
        }
        
        // Construir objeto de usuario para el store
        const userForStore = {
          uid: userData.id_user,
          email: userData.email,
          displayName: userData.full_name,
          role: role,
          avatar: userData.avatar_url || getDefaultAvatar(role),
          allRoles: userData.roles || [],
          lastLogin: userData.last_login
        }
        
        currentUser.value = userForStore
        isAuthenticated.value = true
        activeRole.value = role // Establecer rol activo inicial

        // Guardar en localStorage
        localStorage.setItem('bucarabus_user', JSON.stringify(userForStore))
        localStorage.setItem('bucarabus_active_role', role)
        
        console.log('✅ Login exitoso:', userForStore.displayName, '- Rol:', role)

        return { success: true }
      } else {
        throw new Error(response.data.message || 'Error al iniciar sesión')
      }
    } catch (err) {
      const errorMessage = err.response?.data?.message || err.message || 'Error de conexión'
      error.value = errorMessage
      console.error('❌ Login error:', errorMessage)
      
      // Si el servidor no responde, intentar con usuarios demo como fallback
      if (!err.response) {
        console.log('⚠️ Servidor no disponible, intentando con usuarios demo...')
        return loginWithDemoUsers(email, password)
      }
      
      return { success: false, error: errorMessage }
    } finally {
      loading.value = false
    }
  }

  /**
   * Fallback: Login con usuarios demo cuando el backend no está disponible
   */
  function loginWithDemoUsers(email, password) {
    const demoUser = DEMO_USERS[email.toLowerCase()]
    
    if (!demoUser) {
      return { success: false, error: 'Usuario no encontrado' }
    }

    if (demoUser.password !== password) {
      return { success: false, error: 'Contraseña incorrecta' }
    }

    const { password: _, ...userWithoutPassword } = demoUser
    currentUser.value = userWithoutPassword
    isAuthenticated.value = true
    localStorage.setItem('bucarabus_user', JSON.stringify(userWithoutPassword))
    
    console.log('✅ Login exitoso (modo demo):', userWithoutPassword.displayName)
    return { success: true }
  }

  /**
   * Obtener avatar por defecto según el rol
   */
  function getDefaultAvatar(role) {
    const avatars = {
      admin: '👨‍💼',
      supervisor: '👨‍🏫',
      driver: '👨‍✈️',
      passenger: '👤',
      guest: '❓'
    }
    return avatars[role] || '👤'
  }

  /**
   * Obtener nombre del rol en español
   */
  function getRoleName(roleKey) {
    const names = {
      admin: 'Administrador',
      supervisor: 'Supervisor',
      driver: 'Conductor',
      passenger: 'Pasajero',
      guest: 'Invitado'
    }
    return names[roleKey] || roleKey
  }

  /**
   * Obtener ID del rol
   */
  function getRoleId(roleKey) {
    const ids = {
      admin: 4,
      supervisor: 3,
      driver: 2,
      passenger: 1,
      guest: 0
    }
    return ids[roleKey] || 0
  }

  /**
   * Convertir id_role a roleKey
   */
  function roleIdToKey(id_role) {
    const keys = {
      4: 'admin',
      3: 'supervisor',
      2: 'driver',
      1: 'passenger'
    }
    return keys[id_role] || 'guest'
  }

  /**
   * Cambiar de rol activo sin cerrar sesión
   */
  function switchRole(newRole) {
    if (!currentUser.value) {
      console.error('❌ No hay usuario autenticado')
      return { success: false, error: 'No hay usuario autenticado' }
    }

    // Verificar que el usuario tenga ese rol
    const hasRole = availableRoles.value.some(r => {
      const roleKey = roleIdToKey(r.id_role)
      return roleKey === newRole
    })

    if (!hasRole) {
      console.error('❌ Usuario no tiene el rol:', newRole)
      return { success: false, error: 'No tienes acceso a ese rol' }
    }

    activeRole.value = newRole
    
    // Actualizar en currentUser también para consistencia
    currentUser.value = {
      ...currentUser.value,
      role: newRole
    }

    // Guardar en localStorage
    localStorage.setItem('bucarabus_user', JSON.stringify(currentUser.value))
    localStorage.setItem('bucarabus_active_role', newRole)

    console.log('✅ Rol cambiado a:', newRole)
    return { success: true, role: newRole }
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
    activeRole.value = null
    localStorage.removeItem('bucarabus_user')
    localStorage.removeItem('bucarabus_active_role')
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
    activeRole,

    // Getters
    userId,
    userEmail,
    userName,
    userRole,
    userAvatar,
    availableRoles,
    hasMultipleRoles,

    // Actions
    login,
    register,
    logout,
    updateProfile,
    initializeUser,
    switchRole,
    
    // Helpers
    getRoleName,
    roleIdToKey
  }
})
