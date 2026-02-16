<template>
  <header id="main-header">
    <div class="header-left">
      <button id="sidebar-toggle" class="sidebar-toggle" @click="toggleSidebar">
        <span class="hamburger"></span>
      </button>
      <div class="logo">
        <h1>🚌 BucaraBus</h1>
      </div>
    </div>

    <div class="header-center">
      <div class="global-search">
        <input
          type="text"
          id="global-search"
          v-model="searchQuery"
          placeholder="Buscar buses, rutas, conductores..."
          @input="handleSearch"
        />
        <button class="search-btn" @click="performSearch">🔍</button>
      </div>
    </div>

    <div class="header-right">
      <div class="header-stats">
        <div class="stat-pill active">
          <span class="stat-icon">🚌</span>
          <span class="stat-value" id="buses-active">{{ activeBusesCount }}</span>
          <span class="stat-label">Activos</span>
        </div>
        <div class="stat-pill routes">
          <span class="stat-icon">🛣️</span>
          <span class="stat-value" id="routes-total">{{ totalRoutesCount }}</span>
          <span class="stat-label">Rutas</span>
        </div>
        <div class="stat-pill alerts">
          <span class="stat-icon">🚨</span>
          <span class="stat-value" id="alerts-count">3</span>
          <span class="stat-label">Alertas</span>
        </div>
      </div>

      <div class="user-menu">
        <button id="notifications-btn" class="icon-btn">
          <span class="notification-icon">🔔</span>
          <span class="notification-badge">3</span>
        </button>
        <div class="user-info">
          <div class="user-avatar">{{ userAvatar }}</div>
          <div class="user-details">
            <span id="current-user">{{ userName }}</span>
            <span class="user-role">{{ userRole }}</span>
          </div>
          <button id="logout-btn" class="logout-btn" @click="handleLogout">
            🚪 Salir
          </button>
        </div>
      </div>
    </div>
  </header>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAppStore } from '../stores/app'
import { useAuthStore } from '../stores/auth'
import { useBusesStore } from '../stores/buses'
import { useRoutesStore } from '../stores/routes'

const router = useRouter()
const appStore = useAppStore()
const authStore = useAuthStore()
const busesStore = useBusesStore()
const routesStore = useRoutesStore()

// Estado local
const searchQuery = ref('')

// Getters computados - Usuario
const userName = computed(() => authStore.userName)
const userRole = computed(() => {
  const role = authStore.userRole
  const roleNames = {
    'admin': 'Administrador',
    'driver': 'Conductor',
    'passenger': 'Pasajero',
    'guest': 'Invitado'
  }
  return roleNames[role] || role
})
const userAvatar = computed(() => authStore.userAvatar)

// Getters computados - Stats
const activeBusesCount = computed(() => {
  try {
    return busesStore.activeBuses?.length || 0
  } catch (e) {
    return 0
  }
})
const totalRoutesCount = computed(() => {
  try {
    return routesStore.routesCount || 0
  } catch (e) {
    return 0
  }
})

// Métodos
const toggleSidebar = () => {
  appStore.toggleSidebar()
}

const handleSearch = () => {
  // Implementar búsqueda global
  console.log('Searching for:', searchQuery.value)
}

const performSearch = () => {
  handleSearch()
}

const handleLogout = async () => {
  if (confirm('¿Estás seguro de que deseas cerrar sesión?')) {
    await authStore.logout()
    router.push('/login')
  }
}
</script>

<style scoped>
/* Header styles - migrated from original CSS */
#main-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 20px;
  color: white;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  z-index: 1000;
  position: relative;
  height: 70px;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 15px;
  flex: 0 0 auto;
}

.sidebar-toggle {
  background: rgba(255, 255, 255, 0.15);
  border: none;
  width: 40px;
  height: 40px;
  border-radius: 8px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s ease;
}

.sidebar-toggle:hover {
  background: rgba(255, 255, 255, 0.25);
  transform: scale(1.05);
}

.hamburger {
  width: 18px;
  height: 2px;
  background: white;
  position: relative;
  transition: all 0.3s ease;
}

.hamburger::before,
.hamburger::after {
  content: '';
  position: absolute;
  width: 18px;
  height: 2px;
  background: white;
  transition: all 0.3s ease;
}

.hamburger::before { top: -6px; }
.hamburger::after { bottom: -6px; }

.logo h1 {
  font-size: 24px;
  font-weight: 700;
  margin: 0;
  background: linear-gradient(45deg, #fff, #f0f8ff);
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
}

.header-center {
  flex: 1;
  display: flex;
  justify-content: center;
  max-width: 600px;
  margin: 0 20px;
}

.global-search {
  display: flex;
  width: 100%;
  max-width: 400px;
  background: rgba(255, 255, 255, 0.15);
  border-radius: 12px;
  padding: 4px;
  backdrop-filter: blur(10px);
}

.global-search input {
  flex: 1;
  border: none;
  background: transparent;
  padding: 10px 15px;
  color: white;
  font-size: 14px;
  outline: none;
}

.global-search input::placeholder {
  color: rgba(255, 255, 255, 0.7);
}

.search-btn {
  background: rgba(255, 255, 255, 0.2);
  border: none;
  width: 40px;
  height: 40px;
  border-radius: 8px;
  color: white;
  cursor: pointer;
  transition: all 0.2s ease;
}

.search-btn:hover {
  background: rgba(255, 255, 255, 0.3);
}

.header-right {
  display: flex;
  align-items: center;
  gap: 20px;
  flex: 0 0 auto;
}

.header-stats {
  display: flex;
  gap: 15px;
}

.stat-pill {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 8px 12px;
  background: rgba(255, 255, 255, 0.15);
  border-radius: 10px;
  min-width: 70px;
  backdrop-filter: blur(10px);
  transition: all 0.2s ease;
}

.stat-pill:hover {
  background: rgba(255, 255, 255, 0.25);
  transform: translateY(-2px);
}

.stat-pill.active { border: 2px solid #10b981; }
.stat-pill.routes { border: 2px solid #3b82f6; }
.stat-pill.alerts { border: 2px solid #f59e0b; }

.stat-icon { font-size: 16px; margin-bottom: 2px; }
.stat-value { font-size: 18px; font-weight: bold; line-height: 1; }
.stat-label { font-size: 10px; opacity: 0.8; }

.user-menu {
  display: flex;
  align-items: center;
  gap: 15px;
}

.icon-btn {
  position: relative;
  background: rgba(255, 255, 255, 0.15);
  border: none;
  width: 40px;
  height: 40px;
  border-radius: 50%;
  color: white;
  cursor: pointer;
  transition: all 0.2s ease;
}

.icon-btn:hover {
  background: rgba(255, 255, 255, 0.25);
  transform: scale(1.05);
}

.notification-badge {
  position: absolute;
  top: -5px;
  right: -5px;
  background: #ef4444;
  color: white;
  font-size: 10px;
  font-weight: bold;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px 16px;
  background: rgba(255, 255, 255, 0.15);
  border-radius: 30px;
  backdrop-filter: blur(10px);
}

.user-avatar {
  width: 38px;
  height: 38px;
  border-radius: 50%;
  background: linear-gradient(135deg, #667eea, #764ba2);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.3rem;
  flex-shrink: 0;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
}

.user-details {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.user-details span {
  font-size: 13px;
  font-weight: 500;
  line-height: 1.2;
}

.user-role {
  font-size: 11px !important;
  opacity: 0.8;
  font-weight: 400 !important;
}

.logout-btn {
  background: rgba(255, 255, 255, 0.2);
  border: none;
  color: white;
  padding: 6px 12px;
  border-radius: 15px;
  font-size: 12px;
  cursor: pointer;
  transition: all 0.2s ease;
  font-weight: 500;
}

.logout-btn:hover {
  background: rgba(255, 255, 255, 0.4);
  transform: scale(1.05);
}

/* Responsive */
@media (max-width: 768px) {
  .header-stats {
    display: none;
  }

  .global-search {
    max-width: 200px;
  }

  .logo h1 {
    font-size: 18px;
  }

  .user-details {
    display: none;
  }

  .user-info {
    padding: 6px;
  }
}
</style>