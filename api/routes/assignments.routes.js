import express from 'express'
import assignmentsService from '../services/assignments.service.js'

const router = express.Router()
const SYSTEM_USER_ID = 1;

/**
 * POST /api/assignments - Asignar conductor a bus 
 * Body: { plate_number, id_user, user }
 * Nota: id_user es el id del usuario conductor (tabla tab_users)
 */
router.post('/', async (req, res) => {
  try {
    const { plate_number, id_user, user } = req.body;
    
    if (!plate_number) {
      return res.status(400).json({ success: false, message: 'Placa requerida' });
    }
    
    const result = await assignmentsService.assignDriver(plate_number, id_user, user || SYSTEM_USER_ID);
    
    if (!result.success) {
      return res.status(400).json(result);
    }
    res.status(201).json(result);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * GET /api/assignments/bus/:plate - Historial de un bus
 * (DEBE IR ANTES que DELETE /:plate para evitar conflictos)
 */
router.get('/bus/:plate', async (req, res) => {
  try {
    const result = await assignmentsService.getBusHistory(req.params.plate);
    res.json(result);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * DELETE /api/assignments/:plate - Desasignar conductor
 * Body: { user }
 */
router.delete('/:plate', async (req, res) => {
  try {
    const { plate } = req.params;
    const { user } = req.body;
    
    const result = await assignmentsService.unassignDriver(plate, user || SYSTEM_USER_ID);
    
    if (!result.success) {
      return res.status(400).json(result);
    }
    res.json(result);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

export default router;
