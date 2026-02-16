import express from 'express';
import * as shiftsService from '../services/shifts.service.js';

const router = express.Router();

/**
 * GET /api/shifts
 * Obtener todos los turnos activos
 */
router.get('/', async (req, res) => {
    try {
        const shifts = await shiftsService.getActiveShifts();
        res.json({
            success: true,
            data: shifts,
            count: shifts.length
        });
    } catch (error) {
        console.error('Error al obtener turnos activos:', error);
        res.status(500).json({
            success: false,
            error: 'Error al obtener turnos activos',
            message: error.message
        });
    }
});

/**
 * GET /api/shifts/available-buses
 * Obtener buses disponibles (sin turno activo)
 */
router.get('/available-buses', async (req, res) => {
    try {
        const buses = await shiftsService.getAvailableBuses();
        res.json({
            success: true,
            data: buses,
            count: buses.length
        });
    } catch (error) {
        console.error('Error al obtener buses disponibles:', error);
        res.status(500).json({
            success: false,
            error: 'Error al obtener buses disponibles',
            message: error.message
        });
    }
});

/**
 * GET /api/shifts/:plateNumber
 * Obtener turno activo por placa
 */
router.get('/:plateNumber', async (req, res) => {
    try {
        const shift = await shiftsService.getActiveShiftByPlate(req.params.plateNumber);
        if (!shift) {
            return res.status(404).json({
                success: false,
                error: 'No se encontró turno activo para este bus'
            });
        }
        res.json({
            success: true,
            data: shift
        });
    } catch (error) {
        console.error('Error al obtener turno:', error);
        res.status(500).json({
            success: false,
            error: 'Error al obtener turno',
            message: error.message
        });
    }
});

/**
 * POST /api/shifts
 * Iniciar un nuevo turno
 */
router.post('/', async (req, res) => {
    try {
        const { plate_number, id_route } = req.body;
        
        if (!plate_number || !id_route) {
            return res.status(400).json({
                success: false,
                error: 'Se requiere plate_number e id_route'
            });
        }
        
        const shift = await shiftsService.startShift({ plate_number, id_route });
        res.status(201).json({
            success: true,
            data: shift,
            message: 'Turno iniciado exitosamente'
        });
    } catch (error) {
        console.error('Error al iniciar turno:', error);
        res.status(500).json({
            success: false,
            error: 'Error al iniciar turno',
            message: error.message
        });
    }
});

/**
 * PUT /api/shifts/:plateNumber/progress
 * Actualizar progreso del turno
 */
router.put('/:plateNumber/progress', async (req, res) => {
    try {
        const { progress, trips_completed } = req.body;
        
        const shift = await shiftsService.updateProgress(
            req.params.plateNumber, 
            progress, 
            trips_completed
        );
        
        if (!shift) {
            return res.status(404).json({
                success: false,
                error: 'No se encontró turno activo para este bus'
            });
        }
        
        res.json({
            success: true,
            data: shift
        });
    } catch (error) {
        console.error('Error al actualizar progreso:', error);
        res.status(500).json({
            success: false,
            error: 'Error al actualizar progreso',
            message: error.message
        });
    }
});

/**
 * DELETE /api/shifts/:plateNumber
 * Finalizar turno
 */
router.delete('/:plateNumber', async (req, res) => {
    try {
        const shift = await shiftsService.endShift(req.params.plateNumber);
        if (!shift) {
            return res.status(404).json({
                success: false,
                error: 'No se encontró turno activo para este bus'
            });
        }
        res.json({
            success: true,
            data: shift,
            message: 'Turno finalizado exitosamente'
        });
    } catch (error) {
        console.error('Error al finalizar turno:', error);
        res.status(500).json({
            success: false,
            error: 'Error al finalizar turno',
            message: error.message
        });
    }
});

export default router;
