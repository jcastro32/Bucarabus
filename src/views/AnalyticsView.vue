<template>
  <div class="analytics-section">
    <div class="section-header">
      <h4>Dashboard Analítico</h4>
      <p>Métricas y análisis del rendimiento operacional</p>
    </div>

    <div class="analytics-grid">
      <div class="analytics-card">
        <h4>Eficiencia Operacional</h4>
        <div class="metric-large">87%</div>
        <p class="metric-trend positive">+5.2% vs mes anterior</p>
      </div>
      <div class="analytics-card">
        <h4>Puntualidad</h4>
        <div class="metric-large">92%</div>
        <p class="metric-trend positive">+1.8% vs mes anterior</p>
      </div>
      <div class="analytics-card">
        <h4>Uso de Flota</h4>
        <div class="metric-large">78%</div>
        <p class="metric-trend negative">-2.1% vs mes anterior</p>
      </div>
      <div class="analytics-card">
        <h4>Satisfacción</h4>
        <div class="metric-large">4.3/5</div>
        <p class="metric-trend positive">+0.3 vs mes anterior</p>
      </div>
    </div>

    <div class="routes-performance">
      <h4>Rendimiento por Rutas</h4>
      <div
        v-for="route in routesPerformance"
        :key="route.id"
        class="performance-item"
      >
        <span class="route-name">{{ route.name }}</span>
        <div class="performance-bar">
          <div class="performance-fill" :style="{ width: route.performance + '%' }"></div>
        </div>
        <span class="performance-value">{{ route.performance }}%</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRoutesStore } from '../stores/routes'

const routesStore = useRoutesStore()

// Estado local
const routesPerformance = ref([
  { id: 1, name: 'Ruta Centro', performance: 87 },
  { id: 2, name: 'Ruta Norte', performance: 92 },
  { id: 3, name: 'Ruta Sur', performance: 78 }
])
</script>

<style scoped>
.analytics-section {
  padding: 0;
}

.section-header {
  margin-bottom: 24px;
}

.section-header h4 {
  margin: 0 0 8px 0;
  color: #1e293b;
  font-size: 18px;
  font-weight: 600;
}

.section-header p {
  margin: 0;
  color: #64748b;
}

.analytics-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 20px;
  margin: 20px 0;
}

.analytics-card {
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  padding: 24px;
  text-align: center;
  transition: all 0.3s ease;
}

.analytics-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
}

.analytics-card h4 {
  margin: 0 0 16px 0;
  color: #1e293b;
  font-size: 14px;
  font-weight: 500;
}

.metric-large {
  font-size: 2.5rem;
  font-weight: 700;
  color: #667eea;
  margin: 8px 0;
}

.metric-trend {
  font-size: 12px;
  font-weight: 500;
  margin: 8px 0 0 0;
}

.metric-trend.positive {
  color: #10b981;
}

.metric-trend.negative {
  color: #ef4444;
}

.routes-performance {
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  padding: 24px;
  margin-top: 20px;
}

.routes-performance h4 {
  margin: 0 0 20px 0;
  color: #1e293b;
}

.performance-item {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-bottom: 16px;
}

.performance-item:last-child {
  margin-bottom: 0;
}

.route-name {
  min-width: 120px;
  font-weight: 500;
  color: #1e293b;
}

.performance-bar {
  flex: 1;
  height: 8px;
  background: #f1f5f9;
  border-radius: 4px;
  overflow: hidden;
}

.performance-fill {
  height: 100%;
  background: linear-gradient(90deg, #667eea, #10b981);
  transition: width 0.3s ease;
}

.performance-value {
  min-width: 40px;
  text-align: right;
  font-weight: 600;
  color: #1e293b;
}

/* Responsive */
@media (max-width: 768px) {
  .analytics-grid {
    grid-template-columns: 1fr;
  }

  .performance-item {
    flex-direction: column;
    align-items: flex-start;
    gap: 8px;
  }

  .route-name {
    min-width: auto;
  }
}
</style>