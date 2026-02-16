import apiClient from './client'

/**
 * Obtener viajes por ruta y fecha
 */
export async function getTripsByRouteAndDate(routeId, date) {
  const response = await apiClient.get(`/trips/${routeId}/${date}`)
  return response.data
}

/**
 * Obtener un viaje por ID
 */
export async function getTripById(id) {
  const response = await apiClient.get(`/trips/single/${id}`)
  return response.data
}

/**
 * Crear un viaje individual
 */
export async function createTrip(tripData) {
  const response = await apiClient.post('/trips', tripData)
  return response.data
}

/**
 * Crear múltiples viajes (batch)
 * @param {Object} batchData - { id_route, trip_date, trips: [{start_time, end_time, plate_number}], user_create }
 */
export async function createTripsBatch(batchData) {
  const response = await apiClient.post('/trips/batch', batchData)
  return response.data
}

/**
 * Actualizar viaje
 */
export async function updateTrip(id, updateData) {
  const response = await apiClient.put(`/trips/${id}`, updateData)
  return response.data
}

/**
 * Asignar o desasignar bus
 * @param {number} id - ID del viaje
 * @param {string|null} plateNumber - Placa del bus (null para desasignar)
 * @param {string} userUpdate - Usuario que hace el cambio
 */
export async function setTripBus(id, plateNumber, userUpdate) {
  const response = await apiClient.patch(`/trips/${id}/bus`, {
    plate_number: plateNumber,
    user_update: userUpdate
  })
  return response.data
}

/**
 * Eliminar viaje
 */
export async function deleteTrip(id) {
  const response = await apiClient.delete(`/trips/${id}`)
  return response.data
}

/**
 * Eliminar todos los viajes de una ruta/fecha
 */
export async function deleteTripsByDate(routeId, date) {
  const response = await apiClient.delete(`/trips/by-date/${routeId}/${date}`)
  return response.data
}

/**
 * Cancelar viaje (soft delete)
 */
export async function cancelTrip(id, userUpdate) {
  const response = await apiClient.patch(`/trips/${id}/cancel`, {
    user_update: userUpdate
  })
  return response.data
}
