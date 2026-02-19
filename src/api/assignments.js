import apiClient from './client.js'
import { SYSTEM_USER_ID } from '../constants/system'

/**
 * Asignar conductor a bus
 */
export const assignDriver = async (plateNumber, idUser, user = SYSTEM_USER_ID) => {
  const response = await apiClient.post('/assignments', {
    plate_number: plateNumber,
    id_user: idUser,
    user
  })
  return response.data
}

/**
 * Desasignar conductor de bus
 */
export const unassignDriver = async (plateNumber, user = SYSTEM_USER_ID) => {
  const response = await apiClient.delete(`/assignments/${plateNumber}`, {
    data: { user }
  })
  return response.data
}

/**
 * Obtener historial de asignaciones de un bus
 */
export const getBusHistory = async (plateNumber) => {
  const response = await apiClient.get(`/assignments/bus/${plateNumber}`)
  return response.data
}

export default { assignDriver, unassignDriver, getBusHistory }
