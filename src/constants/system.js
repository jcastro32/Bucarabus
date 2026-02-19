/**
 * Constantes del Sistema BucaraBus
 * ================================
 * Valores constantes utilizados en toda la aplicación
 */

/**
 * ID del usuario de sistema (usado para creaciones/actualizaciones automáticas)
 * Este ID corresponde al usuario 'system@bucarabus.local' en la base de datos
 * Valor: ID 1 (reservado para el usuario del sistema)
 */
export const SYSTEM_USER_ID = 1

/**
 * IDs de roles del sistema
 */
export const ROLES = {
  PASAJERO: 1,
  CONDUCTOR: 2,
  SUPERVISOR: 3,
  ADMINISTRADOR: 4
}

/**
 * Estados de viaje
 */
export const TRIP_STATUS = {
  PENDING: 'pending',
  ASSIGNED: 'assigned',
  IN_PROGRESS: 'in_progress',
  COMPLETED: 'completed',
  CANCELLED: 'cancelled'
}

/**
 * Estados de ruta
 */
export const ROUTE_STATUS = {
  ACTIVE: 'active',
  INACTIVE: 'inactive',
  MAINTENANCE: 'maintenance'
}
