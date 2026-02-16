<template>
  <div class="landing-page">
    <!-- HEADER SIMPLE -->
    <header class="landing-header">
      <div class="header-container">
        <div class="logo">
          <h1>🚌 BucaraBus</h1>
        </div>
        <nav class="nav-menu">
          <a href="#features">Características</a>
          <a href="#how-it-works">Cómo Funciona</a>
          <a href="#contact">Contacto</a>
          
          <!-- Usuario autenticado -->
          <div v-if="authStore.isAuthenticated" class="user-badge">
            <span class="user-avatar-small">{{ authStore.userAvatar }}</span>
            <span class="user-name-small">{{ authStore.userName }}</span>
            <button class="btn-logout-small" @click="handleLogout" title="Cerrar sesión">
              🚪
            </button>
          </div>
          
          <!-- Usuario NO autenticado -->
          <template v-if="!authStore.isAuthenticated">
            <button class="btn-login" @click="goToLogin">
              🔐 Iniciar Sesión
            </button>
            <button class="btn-register" @click="goToRegister">
              ✨ Registrarse
            </button>
          </template>
          
          <!-- Botón de acceso cuando está autenticado -->
          <button v-if="authStore.isAuthenticated" class="btn-primary" @click="goToMonitor">
            {{ buttonText }}
          </button>
        </nav>
      </div>
    </header>

    <!-- HERO SECTION -->
    <section class="hero-section">
      <div class="hero-content">
        <div class="hero-text">
          <h1 class="hero-title">
            Gestión Inteligente de
            <span class="gradient-text">Transporte Urbano</span>
          </h1>
          <p class="hero-subtitle">
            Monitoriza en tiempo real tu flota de buses, optimiza rutas y mejora la experiencia de tus pasajeros con nuestra plataforma integral de gestión.
          </p>
          <div class="hero-actions">
            <button class="btn-hero-primary" @click="goToMonitor">
              <span class="btn-icon">🚀</span>
              Comenzar Ahora
            </button>
            <button class="btn-hero-secondary" @click="scrollToFeatures">
              <span class="btn-icon">📖</span>
              Conocer Más
            </button>
          </div>
          <div class="hero-stats">
            <div class="stat">
              <div class="stat-number">24/7</div>
              <div class="stat-label">Monitoreo</div>
            </div>
            <div class="stat">
              <div class="stat-number">100%</div>
              <div class="stat-label">En Tiempo Real</div>
            </div>
            <div class="stat">
              <div class="stat-number">∞</div>
              <div class="stat-label">Rutas</div>
            </div>
          </div>
        </div>
        <div class="hero-visual">
          <div class="visual-card">
            <div class="visual-icon">🗺️</div>
            <h3>Monitor en Vivo</h3>
            <p>Visualiza la ubicación de todos tus buses en tiempo real</p>
          </div>
          <div class="visual-card">
            <div class="visual-icon">📊</div>
            <h3>Analytics Avanzado</h3>
            <p>Datos e insights para tomar mejores decisiones</p>
          </div>
          <div class="visual-card">
            <div class="visual-icon">⚡</div>
            <h3>Gestión Rápida</h3>
            <p>Administra turnos, conductores y rutas en un solo lugar</p>
          </div>
        </div>
      </div>
    </section>

    <!-- FEATURES SECTION -->
    <section id="features" class="features-section">
      <div class="section-container">
        <div class="section-header">
          <h2 class="section-title">Todo lo que Necesitas</h2>
          <p class="section-subtitle">
            Herramientas profesionales para una gestión eficiente
          </p>
        </div>
        <div class="features-grid">
          <div class="feature-card">
            <div class="feature-icon">📍</div>
            <h3>Seguimiento GPS</h3>
            <p>Rastrea la ubicación exacta de cada bus con precisión en tiempo real.</p>
          </div>
          <div class="feature-card">
            <div class="feature-icon">🗺️</div>
            <h3>Gestión de Rutas</h3>
            <p>Crea, edita y optimiza rutas con herramientas visuales intuitivas.</p>
          </div>
          <div class="feature-card">
            <div class="feature-icon">👨‍✈️</div>
            <h3>Control de Conductores</h3>
            <p>Administra tu equipo de conductores, asignaciones y turnos.</p>
          </div>
          <div class="feature-card">
            <div class="feature-icon">🚌</div>
            <h3>Flota Completa</h3>
            <p>Gestiona todos tus vehículos, mantenimiento y estado operativo.</p>
          </div>
          <div class="feature-card">
            <div class="feature-icon">📊</div>
            <h3>Reportes y Analytics</h3>
            <p>Visualiza estadísticas y genera reportes detallados de operación.</p>
          </div>
          <div class="feature-card">
            <div class="feature-icon">🔔</div>
            <h3>Alertas Inteligentes</h3>
            <p>Recibe notificaciones de eventos importantes en tiempo real.</p>
          </div>
          <div class="feature-card">
            <div class="feature-icon">📅</div>
            <h3>Programación de Turnos</h3>
            <p>Planifica y gestiona horarios de forma eficiente y automatizada.</p>
          </div>
          <div class="feature-card">
            <div class="feature-icon">🌐</div>
            <h3>Acceso Web</h3>
            <p>Accede desde cualquier dispositivo con conexión a internet.</p>
          </div>
        </div>
      </div>
    </section>

    <!-- HOW IT WORKS SECTION -->
    <section id="how-it-works" class="how-section">
      <div class="section-container">
        <div class="section-header">
          <h2 class="section-title">Cómo Funciona</h2>
          <p class="section-subtitle">Simple, rápido y eficiente</p>
        </div>
        <div class="steps-grid">
          <div class="step-card">
            <div class="step-number">1</div>
            <h3>Registra tu Flota</h3>
            <p>Agrega tus buses, conductores y define tus rutas en minutos.</p>
          </div>
          <div class="step-arrow">→</div>
          <div class="step-card">
            <div class="step-number">2</div>
            <h3>Inicia el Monitoreo</h3>
            <p>Activa el seguimiento GPS y comienza a visualizar en tiempo real.</p>
          </div>
          <div class="step-arrow">→</div>
          <div class="step-card">
            <div class="step-number">3</div>
            <h3>Gestiona y Optimiza</h3>
            <p>Toma decisiones basadas en datos y mejora tu operación.</p>
          </div>
        </div>
      </div>
    </section>

    <!-- CTA SECTION -->
    <section id="contact" class="cta-section">
      <div class="cta-content">
        <h2>¿Listo para Transformar tu Flota?</h2>
        <p>Únete a las empresas que ya están optimizando su transporte urbano</p>
        <button class="btn-cta" @click="goToMonitor">
          <span class="btn-icon">🚀</span>
          Comenzar Gratis
        </button>
        <p class="cta-note">Sin tarjeta de crédito • Configuración en minutos</p>
      </div>
    </section>

    <!-- FOOTER -->
    <footer class="landing-footer">
      <div class="footer-container">
        <div class="footer-brand">
          <h3>🚌 BucaraBus</h3>
          <p>Sistema de Gestión de Transporte Urbano</p>
        </div>
        <div class="footer-links">
          <div class="footer-column">
            <h4>Producto</h4>
            <a href="#features">Características</a>
            <a href="#how-it-works">Cómo Funciona</a>
            <a href="#" @click.prevent="goToMonitor">Acceder</a>
          </div>
          <div class="footer-column">
            <h4>Soporte</h4>
            <a href="#contact">Contacto</a>
            <a href="#">Documentación</a>
            <a href="#">FAQ</a>
          </div>
          <div class="footer-column">
            <h4>Legal</h4>
            <a href="#">Términos</a>
            <a href="#">Privacidad</a>
            <a href="#">Cookies</a>
          </div>
        </div>
      </div>
      <div class="footer-bottom">
        <p>&copy; 2026 BucaraBus. Todos los derechos reservados.</p>
      </div>
    </footer>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const authStore = useAuthStore()

const buttonText = computed(() => {
  if (authStore.isAuthenticated) {
    const role = authStore.userRole
    if (role === 'driver') return 'Ir a App Conductor'
    if (role === 'passenger') return 'Ir a App Pasajero'
    return 'Ir al Dashboard'
  }
  return 'Acceder al Sistema'
})

const goToMonitor = () => {
  // Si el usuario ya está autenticado, redirigir según su rol
  if (authStore.isAuthenticated) {
    const role = authStore.userRole
    if (role === 'driver') {
      router.push('/conductor')
    } else if (role === 'passenger') {
      router.push('/pasajero')
    } else {
      router.push('/monitor')
    }
  } else {
    // Si no está autenticado, ir al login
    router.push('/login')
  }
}

const goToLogin = () => {
  router.push('/login')
}

const goToRegister = () => {
  router.push('/register')
}

const scrollToFeatures = () => {
  const element = document.getElementById('features')
  if (element) {
    element.scrollIntoView({ behavior: 'smooth' })
  }
}

const handleLogout = async () => {
  if (confirm('¿Cerrar sesión?')) {
    await authStore.logout()
    // Opcional: recargar la página para limpiar el estado
    window.location.reload()
  }
}
</script>

<style scoped>
/* === VARIABLES REUTILIZADAS === */
.landing-page {
  --primary: #667eea;
  --secondary: #764ba2;
  --success: #10b981;
  --dark: #1e293b;
  --gray: #64748b;
  --light: #f8fafc;
  --white: #ffffff;
  
  width: 100%;
  min-height: 100vh;
  background: var(--white);
  overflow-x: hidden;
  overflow-y: auto;
}

/* === HEADER === */
.landing-header {
  position: sticky;
  top: 0;
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10px);
  border-bottom: 1px solid #e2e8f0;
  z-index: 1000;
  padding: 1rem 0;
}

.header-container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 2rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.logo h1 {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--dark);
  margin: 0;
}

.nav-menu {
  display: flex;
  gap: 2rem;
  align-items: center;
}

.nav-menu a {
  text-decoration: none;
  color: var(--gray);
  font-weight: 500;
  transition: color 0.3s;
}

.nav-menu a:hover {
  color: var(--primary);
}

.btn-login {
  background: transparent;
  color: var(--primary);
  border: 2px solid var(--primary);
  padding: 0.75rem 1.5rem;
  border-radius: 8px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
}

.btn-login:hover {
  background: var(--primary);
  color: white;
  transform: translateY(-2px);
  box-shadow: 0 5px 15px rgba(102, 126, 234, 0.3);
}

.btn-register {
  background: linear-gradient(135deg, #10b981, #059669);
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 8px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
}

.btn-register:hover {
  transform: translateY(-2px);
  box-shadow: 0 10px 25px rgba(16, 185, 129, 0.3);
}

.btn-primary {
  background: linear-gradient(135deg, var(--primary), var(--secondary));
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 8px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
}

.btn-primary:hover {
  transform: translateY(-2px);
  box-shadow: 0 10px 25px rgba(102, 126, 234, 0.3);
}

/* === USER BADGE === */
.user-badge {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  background: rgba(102, 126, 234, 0.1);
  padding: 0.5rem 1rem;
  border-radius: 20px;
  border: 2px solid var(--primary);
}

.user-avatar-small {
  font-size: 1.2rem;
}

.user-name-small {
  font-weight: 600;
  color: var(--primary);
  font-size: 0.9rem;
}

.btn-logout-small {
  background: rgba(239, 68, 68, 0.1);
  border: none;
  color: #dc2626;
  padding: 0.25rem 0.5rem;
  border-radius: 8px;
  font-size: 1rem;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
}

.btn-logout-small:hover {
  background: rgba(239, 68, 68, 0.2);
  transform: scale(1.1);
}

/* === HERO SECTION === */
.hero-section {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 6rem 2rem;
  color: white;
}

.hero-content {
  max-width: 1200px;
  margin: 0 auto;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 4rem;
  align-items: center;
}

.hero-title {
  font-size: 3.5rem;
  font-weight: 800;
  line-height: 1.2;
  margin-bottom: 1.5rem;
}

.gradient-text {
  background: linear-gradient(135deg, #fbbf24, #f59e0b);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.hero-subtitle {
  font-size: 1.25rem;
  line-height: 1.8;
  margin-bottom: 2rem;
  opacity: 0.95;
}

.hero-actions {
  display: flex;
  gap: 1rem;
  margin-bottom: 3rem;
}

.btn-hero-primary,
.btn-hero-secondary {
  padding: 1rem 2rem;
  border-radius: 12px;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  border: none;
}

.btn-hero-primary {
  background: white;
  color: var(--primary);
}

.btn-hero-primary:hover {
  transform: translateY(-3px);
  box-shadow: 0 15px 35px rgba(0, 0, 0, 0.2);
}

.btn-hero-secondary {
  background: rgba(255, 255, 255, 0.2);
  color: white;
  border: 2px solid white;
}

.btn-hero-secondary:hover {
  background: rgba(255, 255, 255, 0.3);
}

.btn-icon {
  font-size: 1.2rem;
}

.hero-stats {
  display: flex;
  gap: 3rem;
}

.stat {
  text-align: center;
}

.stat-number {
  font-size: 2.5rem;
  font-weight: 800;
  margin-bottom: 0.25rem;
}

.stat-label {
  font-size: 0.9rem;
  opacity: 0.9;
}

.hero-visual {
  display: grid;
  gap: 1.5rem;
}

.visual-card {
  background: rgba(255, 255, 255, 0.15);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 16px;
  padding: 1.5rem;
  transition: all 0.3s;
}

.visual-card:hover {
  background: rgba(255, 255, 255, 0.25);
  transform: translateX(10px);
}

.visual-icon {
  font-size: 2.5rem;
  margin-bottom: 0.75rem;
}

.visual-card h3 {
  font-size: 1.25rem;
  margin-bottom: 0.5rem;
}

.visual-card p {
  font-size: 0.95rem;
  opacity: 0.9;
  margin: 0;
}

/* === FEATURES SECTION === */
.features-section,
.how-section {
  padding: 6rem 2rem;
  background: var(--light);
}

.section-container {
  max-width: 1200px;
  margin: 0 auto;
}

.section-header {
  text-align: center;
  margin-bottom: 4rem;
}

.section-title {
  font-size: 2.5rem;
  font-weight: 800;
  color: var(--dark);
  margin-bottom: 1rem;
}

.section-subtitle {
  font-size: 1.25rem;
  color: var(--gray);
}

.features-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 2rem;
}

.feature-card {
  background: white;
  padding: 2rem;
  border-radius: 16px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
  transition: all 0.3s;
  border: 1px solid #e2e8f0;
}

.feature-card:hover {
  transform: translateY(-5px);
  box-shadow: 0 15px 35px rgba(0, 0, 0, 0.1);
  border-color: var(--primary);
}

.feature-icon {
  font-size: 3rem;
  margin-bottom: 1rem;
}

.feature-card h3 {
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--dark);
  margin-bottom: 0.75rem;
}

.feature-card p {
  color: var(--gray);
  line-height: 1.6;
  margin: 0;
}

/* === HOW IT WORKS === */
.how-section {
  background: white;
}

.steps-grid {
  display: grid;
  grid-template-columns: 1fr auto 1fr auto 1fr;
  gap: 2rem;
  align-items: center;
}

.step-card {
  background: linear-gradient(135deg, var(--primary), var(--secondary));
  color: white;
  padding: 3rem 2rem;
  border-radius: 16px;
  text-align: center;
  position: relative;
}

.step-number {
  position: absolute;
  top: -20px;
  left: 50%;
  transform: translateX(-50%);
  width: 50px;
  height: 50px;
  background: var(--success);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.5rem;
  font-weight: 800;
  box-shadow: 0 5px 15px rgba(16, 185, 129, 0.4);
}

.step-card h3 {
  font-size: 1.5rem;
  margin: 1rem 0;
}

.step-card p {
  opacity: 0.95;
  line-height: 1.6;
  margin: 0;
}

.step-arrow {
  font-size: 3rem;
  color: var(--primary);
  font-weight: 800;
}

/* === CTA SECTION === */
.cta-section {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 6rem 2rem;
  text-align: center;
  color: white;
}

.cta-content h2 {
  font-size: 3rem;
  font-weight: 800;
  margin-bottom: 1rem;
}

.cta-content p {
  font-size: 1.25rem;
  margin-bottom: 2rem;
  opacity: 0.95;
}

.btn-cta {
  background: white;
  color: var(--primary);
  border: none;
  padding: 1.25rem 3rem;
  border-radius: 12px;
  font-size: 1.25rem;
  font-weight: 700;
  cursor: pointer;
  transition: all 0.3s;
  display: inline-flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 1rem;
}

.btn-cta:hover {
  transform: translateY(-3px);
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.2);
}

.cta-note {
  font-size: 0.9rem;
  opacity: 0.8;
  margin: 0;
}

/* === FOOTER === */
.landing-footer {
  background: var(--dark);
  color: white;
  padding: 4rem 2rem 2rem;
}

.footer-container {
  max-width: 1200px;
  margin: 0 auto;
  display: grid;
  grid-template-columns: 2fr 3fr;
  gap: 4rem;
  margin-bottom: 3rem;
}

.footer-brand h3 {
  font-size: 1.5rem;
  margin-bottom: 0.5rem;
}

.footer-brand p {
  color: var(--gray);
  margin: 0;
}

.footer-links {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 2rem;
}

.footer-column h4 {
  font-size: 1rem;
  margin-bottom: 1rem;
  color: white;
}

.footer-column a {
  display: block;
  color: var(--gray);
  text-decoration: none;
  margin-bottom: 0.75rem;
  transition: color 0.3s;
}

.footer-column a:hover {
  color: var(--primary);
}

.footer-bottom {
  text-align: center;
  padding-top: 2rem;
  border-top: 1px solid rgba(255, 255, 255, 0.1);
}

.footer-bottom p {
  color: var(--gray);
  margin: 0;
}

/* === RESPONSIVE === */
@media (max-width: 1024px) {
  .hero-content {
    grid-template-columns: 1fr;
    gap: 3rem;
  }

  .hero-title {
    font-size: 2.5rem;
  }

  .steps-grid {
    grid-template-columns: 1fr;
  }

  .step-arrow {
    display: none;
  }

  .footer-container {
    grid-template-columns: 1fr;
    gap: 2rem;
  }
}

@media (max-width: 768px) {
  .nav-menu {
    gap: 1rem;
  }

  .nav-menu a {
    display: none;
  }

  .user-badge {
    padding: 0.4rem 0.8rem;
  }

  .user-name-small {
    display: none;
  }

  .hero-title {
    font-size: 2rem;
  }

  .hero-subtitle {
    font-size: 1rem;
  }

  .hero-actions {
    flex-direction: column;
  }

  .hero-stats {
    gap: 1.5rem;
  }

  .section-title {
    font-size: 2rem;
  }

  .features-grid {
    grid-template-columns: 1fr;
  }

  .footer-links {
    grid-template-columns: 1fr;
  }
}
</style>
