/**
 * 🔒 Composable: Verificar Sesión Completa
 * 
 * Verifica si el usuario tiene una sesión completa con uid/email
 * Si solo tiene datos de localStorage (sin uid), redirige a login
 * 
 * Uso en componentes que necesitan uid/email:
 * ```javascript
 * import { useRequireFullSession } from '@/composables/useRequireFullSession'
 * 
 * const { hasFullSession, requireFullSession } = useRequireFullSession()
 * 
 * onMounted(() => {
 *   requireFullSession() // Auto-redirige a login si no tiene uid
 * })
 * ```
 */

import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

export function useRequireFullSession() {
  const authStore = useAuthStore()
  const router = useRouter()

  // Verificar si tiene sesión completa (uid y email disponibles)
  const hasFullSession = computed(() => {
    return authStore.isAuthenticated && authStore.userId !== null
  })

  /**
   * Requiere sesión completa, redirige a login si solo tiene datos de localStorage
   * @param {string} returnPath - Ruta a la que volver después del login
   */
  function requireFullSession(returnPath = null) {
    if (!authStore.isAuthenticated) {
      console.warn('⚠️ No hay sesión activa, redirigiendo a login...')
      router.push({
        path: '/login',
        query: returnPath ? { redirect: returnPath } : {}
      })
      return false
    }

    if (authStore.userId === null) {
      console.warn('⚠️ Sesión limitada (solo localStorage), requiere re-login para obtener uid/email')
      router.push({
        path: '/login',
        query: { 
          redirect: returnPath || router.currentRoute.value.fullPath,
          reason: 'session_limited'
        }
      })
      return false
    }

    return true
  }

  return {
    hasFullSession,
    requireFullSession
  }
}
