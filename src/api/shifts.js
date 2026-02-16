/**
 * API Client para Turnos Activos
 */

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3001/api';

/**
 * Obtener todos los turnos activos
 */
export async function getActiveShifts() {
    const response = await fetch(`${API_URL}/shifts`);
    const data = await response.json();
    
    if (!data.success) {
        throw new Error(data.error || 'Error al obtener turnos');
    }
    
    return data.data;
}

/**
 * Obtener turno activo por placa
 */
export async function getShiftByPlate(plateNumber) {
    const response = await fetch(`${API_URL}/shifts/${plateNumber}`);
    const data = await response.json();
    
    if (!data.success) {
        throw new Error(data.error || 'Error al obtener turno');
    }
    
    return data.data;
}

/**
 * Iniciar un turno
 */
export async function startShift(shiftData) {
    const response = await fetch(`${API_URL}/shifts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(shiftData)
    });
    
    const data = await response.json();
    
    if (!data.success) {
        throw new Error(data.error || 'Error al iniciar turno');
    }
    
    return data.data;
}

/**
 * Finalizar un turno
 */
export async function endShift(plateNumber) {
    const response = await fetch(`${API_URL}/shifts/${plateNumber}`, {
        method: 'DELETE'
    });
    
    const data = await response.json();
    
    if (!data.success) {
        throw new Error(data.error || 'Error al finalizar turno');
    }
    
    return data.data;
}

/**
 * Obtener buses disponibles (sin turno activo)
 */
export async function getAvailableBuses() {
    const response = await fetch(`${API_URL}/shifts/available-buses`);
    const data = await response.json();
    
    if (!data.success) {
        throw new Error(data.error || 'Error al obtener buses disponibles');
    }
    
    return data.data;
}

export default {
    getActiveShifts,
    getShiftByPlate,
    startShift,
    endShift,
    getAvailableBuses
};
