import apiClient from './client.js'

/**
 * 🗺️ API de Rutas
 */
export const routesApi = {
  /**
   * Obtener todas las rutas
   */
  async getAll() {
    try {
      const response = await apiClient.get('/routes')
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Obtener ruta por ID
   */
  async getById(id) {
    try {
      const response = await apiClient.get(`/routes/${id}`)
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Crear nueva ruta
   */
  async create(routeData) {
    try {
      const response = await apiClient.post('/routes', routeData)
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Actualizar ruta existente
   */
  async update(id, routeData) {
    try {
      const response = await apiClient.put(`/routes/${id}`, routeData)
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Eliminar ruta
   */
  async delete(id) {
    try {
      const response = await apiClient.delete(`/routes/${id}`)
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Buscar rutas
   */
  async search(query) {
    try {
      const response = await apiClient.get('/routes/search', {
        params: { q: query }
      })
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Alternar visibilidad de ruta
   */
  async toggleVisibility(id) {
    try {
      const response = await apiClient.patch(`/routes/${id}/visibility`)
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Obtener distancia de ruta
   */
  async getDistance(id) {
    try {
      const response = await apiClient.get(`/routes/${id}/distance`)
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Agregar parada a ruta
   */
  async addStop(routeId, stopData) {
    try {
      const response = await apiClient.post(`/routes/${routeId}/stops`, stopData)
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Asignar bus a ruta
   */
  async assignBus(routeId, busId) {
    try {
      const response = await apiClient.post(`/routes/${routeId}/buses`, { busId })
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Manejador de errores
   */
  handleError(error) {
    if (error.response) {
      // Error de respuesta del servidor
      const errorObj = {
        success: false,
        error: error.response.data.error || 'Error del servidor',
        message: error.response.data.message,
        status: error.response.status
      }
      
      // Incluir código de error si existe
      if (error.response.data.code) {
        errorObj.code = error.response.data.code
      }
      
      return errorObj
    } else if (error.request) {
      // No se recibió respuesta
      return {
        success: false,
        error: 'No se pudo conectar con el servidor',
        message: 'Verifica tu conexión a internet o que el servidor esté corriendo'
      }
    } else {
      // Error en la configuración de la request
      return {
        success: false,
        error: 'Error en la petición',
        message: error.message
      }
    }
  }
}

export default routesApi
