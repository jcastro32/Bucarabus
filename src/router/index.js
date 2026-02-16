import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'

// Layout base unificado
import BaseLayout from '../layouts/BaseLayout.vue'

// Views
import LandingView from '../views/LandingView.vue'
import LoginView from '../views/LoginView.vue'
import RegisterView from '../views/RegisterView.vue'
import MonitorView from '../views/MonitorView.vue'
import FleetView from '../views/FleetView.vue'
import RoutesView from '../views/RoutesView.vue'
import DriversView from '../views/DriversView.vue'
import ShiftsView from '../views/ShiftsView.vue'
import AnalyticsView from '../views/AnalyticsView.vue'
import AlertsView from '../views/AlertsView.vue'
import SettingsView from '../views/SettingsView.vue'
import DriverAppView from '../views/DriverAppView.vue'
import PassengerAppView from '../views/PassengerAppView.vue'
import UsersView from '../views/UsersView.vue'

const routes = [
  // Landing Page
  {
    path: '/',
    name: 'landing',
    component: LandingView,
    meta: { title: 'BucaraBus - Sistema de Gestión de Transporte', hideNav: true, public: true }
  },
  // Login
  {
    path: '/login',
    name: 'login',
    component: LoginView,
    meta: { title: 'Iniciar Sesión', hideNav: true, public: true }
  },
  // Register
  {
    path: '/register',
    name: 'register',
    component: RegisterView,
    meta: { title: 'Registrarse', hideNav: true, public: true }
  },
  // Todas las rutas principales usan BaseLayout
  {
    path: '/',
    component: BaseLayout,
    meta: { requiresAuth: true },
    children: [
      // Rutas con mapa
      {
        path: 'monitor',
        name: 'monitor',
        component: MonitorView,
        meta: { title: 'Monitor en Tiempo Real', section: 'monitor', hasMap: true }
      },
      {
        path: 'routes',
        name: 'routes',
        component: RoutesView,
        meta: { title: 'Gestión de Rutas', section: 'routes', hasMap: true }
      },
      // Rutas sin mapa
      {
        path: 'fleet',
        name: 'fleet',
        component: FleetView,
        meta: { title: 'Buses', section: 'buses', hasMap: false }
      },
      {
        path: 'fleet/assign-driver',
        name: 'assign-driver',
        component: () => import('../views/AssignDriverView.vue'),
        meta: { title: 'Asignar Conductor', section: 'assign-driver', hasMap: false }
      },
      {
        path: 'drivers',
        name: 'drivers',
        component: DriversView,
        meta: { title: 'Gestión de Conductores', section: 'drivers', hasMap: false }
      },
      {
        path: 'shifts',
        name: 'shifts',
        component: ShiftsView,
        meta: { title: 'Gestión de Turnos', section: 'shifts', hasMap: false }
      },
      {
        path: 'users',
        name: 'users',
        component: UsersView,
        meta: { title: 'Gestión de Usuarios', section: 'users', hasMap: false }
      },
      {
        path: 'analytics',
        name: 'analytics',
        component: AnalyticsView,
        meta: { title: 'Análisis y Reportes', section: 'analytics', hasMap: false }
      },
      {
        path: 'alerts',
        name: 'alerts',
        component: AlertsView,
        meta: { title: 'Centro de Alertas', section: 'alerts', hasMap: false }
      },
      {
        path: 'settings',
        name: 'settings',
        component: SettingsView,
        meta: { title: 'Configuración del Sistema', section: 'settings', hasMap: false }
      }
    ]
  },
  // Ruta para App de Conductor (PWA)
  {
    path: '/conductor',
    name: 'driver-app',
    component: DriverAppView,
    meta: { title: 'App Conductor', hideNav: true, public: true, requiresAuth: true }
  },
  // Ruta para App de Pasajeros (PWA)
  {
    path: '/pasajero',
    name: 'passenger-app',
    component: PassengerAppView,
    meta: { title: 'BucaraBus - Dónde está mi bus', hideNav: true, public: true, requiresAuth: true }
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

// Actualizar el título de la página y proteger rutas
router.beforeEach((to, from, next) => {
  // Actualizar título
  document.title = to.meta.title ? `${to.meta.title} - BucaraBus` : 'BucaraBus Dashboard'
  
  // Verificar autenticación
  const authStore = useAuthStore()
  const requiresAuth = to.matched.some(record => record.meta.requiresAuth)
  const isPublic = to.meta.public
  const userRole = authStore.userRole
  
  if (requiresAuth && !authStore.isAuthenticated) {
    // Ruta protegida y usuario no autenticado -> redirigir a login
    console.log('🔒 Acceso denegado, redirigiendo a login')
    next({
      name: 'login',
      query: { redirect: to.fullPath }
    })
  } else if (to.name === 'login' && authStore.isAuthenticated) {
    // Usuario autenticado intenta ir a login -> redirigir según rol
    console.log('✅ Usuario ya autenticado, redirigiendo...')
    if (userRole === 'driver') {
      next({ name: 'driver-app' })
    } else if (userRole === 'passenger') {
      next({ name: 'passenger-app' })
    } else {
      next({ name: 'monitor' })
    }
  } else if (authStore.isAuthenticated && to.path.startsWith('/monitor') && (userRole === 'driver' || userRole === 'passenger')) {
    // Conductor o pasajero intentando acceder al dashboard -> redirigir a su vista
    console.log('⚠️ Acceso restringido para este rol, redirigiendo...')
    if (userRole === 'driver') {
      next({ name: 'driver-app' })
    } else {
      next({ name: 'passenger-app' })
    }
  } else {
    // Permitir acceso
    next()
  }
})

export default router