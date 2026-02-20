import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import apiClient from '../api/client'

// =============================================
// 🔒 POLÍTICA DE SEGURIDAD - localStorage
// =============================================
// ✅ QUÉ SE GUARDA: displayName, role, avatar, allRoles (datos públicos)
// ❌ QUÉ NO SE GUARDA: uid, email (datos sensibles)
//
// RAZÓN: Protección contra XSS (Cross-Site Scripting)
// - Si un atacante inyecta código malicioso, NO puede robar uid/email
// - Los datos solo existen en memoria durante la sesión
// - Para operaciones que necesiten uid/email, se re-autentica con backend
// =============================================
//hola
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
  // ⚠️ NOTA: userId y userEmail pueden ser NULL si la sesión fue restaurada desde localStorage
  // Para obtener estos datos, el usuario debe re-autenticarse o hacer una llamada al backend
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
   * ⚠️ NOTA: Solo restaura datos NO sensibles (displayName, role, avatar)
   * Para operaciones que necesiten uid/email, se debe re-autenticar o usar backend
   */
  function initializeUser() {
    try {
      const storedUser = localStorage.getItem('bucarabus_user')
      const storedActiveRole = localStorage.getItem('bucarabus_active_role')
      
      if (storedUser) {
        const userData = JSON.parse(storedUser)
        
        // ✅ SEGURIDAD: localStorage solo tiene displayName, role, avatar
        // NO tiene uid ni email (para proteger contra XSS)
        currentUser.value = {
          uid: null,  // Se obtiene del backend si es necesario
          email: null,  // Se obtiene del backend si es necesario
          displayName: userData.displayName,
          role: userData.role,
          avatar: userData.avatar,
          allRoles: userData.allRoles || []
        }
        isAuthenticated.value = true
        
        // Restaurar rol activo o usar el rol principal
        activeRole.value = storedActiveRole || userData.role
        
        console.log('✅ Usuario restaurado desde localStorage:', userData.displayName, '- Rol activo:', activeRole.value)
        console.log('ℹ️ Sesión limitada: uid y email requieren re-autenticación si es necesario')
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
        
        // Construir objeto de usuario completo (en memoria)
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

        // ✅ SEGURIDAD: Solo guardar datos NO sensibles en localStorage
        const secureStorage = {
          displayName: userData.full_name,
          role: role,
          avatar: userData.avatar_url || getDefaultAvatar(role),
          allRoles: userData.roles || []
          // ❌ NO guardar: uid, email (datos sensibles)
        }
        localStorage.setItem('bucarabus_user', JSON.stringify(secureStorage))
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
   * Registro de nuevo usuario con API backend real
   */
  async function register(userData) {
    loading.value = true
    error.value = null

    try {
      console.log('📝 Registrando usuario con backend:', userData.email)
      
      // Determinar avatar según el rol
      let avatar = '👤'
      if (userData.role === 'admin') avatar = '👨‍💼'
      else if (userData.role === 'driver') avatar = '👨‍✈️'
      else if (userData.role === 'passenger') avatar = '👤'

      // Llamar a la API de registro
      const response = await apiClient.post('/users', {
        email: userData.email,
        password: userData.password,
        full_name: userData.name,  // Backend espera 'full_name'
        avatar_url: null,
        initial_role: 1  // 1 = Pasajero (por seguridad, siempre pasajero en registro público)
      })

      if (response.data.success) {
        const newUserData = response.data.data
        
        console.log('✅ Usuario registrado en BD:', newUserData)
        
        // Construir objeto de usuario completo (en memoria)
        const userForStore = {
          uid: newUserData.id_user,
          email: newUserData.email,
          displayName: newUserData.full_name,
          role: 'passenger',  // Siempre pasajero en registro público
          avatar: newUserData.avatar_url || avatar,
          allRoles: newUserData.roles || [],
          lastLogin: newUserData.last_login
        }

        // Auto-login después del registro exitoso
        currentUser.value = userForStore
        isAuthenticated.value = true
        activeRole.value = 'passenger'

        // ✅ SEGURIDAD: Solo guardar datos NO sensibles en localStorage
        const secureStorage = {
          displayName: newUserData.full_name,
          role: 'passenger',
          avatar: newUserData.avatar_url || avatar,
          allRoles: newUserData.roles || []
          // ❌ NO guardar: uid, email (datos sensibles)
        }
        localStorage.setItem('bucarabus_user', JSON.stringify(secureStorage))
        localStorage.setItem('bucarabus_active_role', 'passenger')
        
        console.log('✅ Registro exitoso y auto-login:', userForStore.displayName)

        return { success: true }
      } else {
        throw new Error(response.data.message || 'Error al crear la cuenta')
      }
      
    } catch (err) {
      // Manejar errores de red y del servidor
      const errorMessage = err.response?.data?.message || err.message || 'Error al crear la cuenta'
      error.value = errorMessage
      console.error('❌ Error en registro:', errorMessage)
      return { success: false, error: errorMessage }
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
