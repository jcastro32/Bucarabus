import express from 'express'
const router = express.Router()

/**
 * Buscar lugares usando Nominatim (OpenStreetMap)
 * Proxy endpoint para evitar problemas de CORS
 */
router.get('/search', async (req, res) => {
  try {
    const { q } = req.query

    if (!q || q.length < 2) {
      return res.json({
        success: true,
        data: []
      })
    }

    // Hacer petición a Nominatim con headers apropiados
    const response = await fetch(
      `https://nominatim.openstreetmap.org/search?` + 
      `q=${encodeURIComponent(q)}&` +
      `format=json&` +
      `limit=10&` +
      `countrycodes=co&` +
      `viewbox=-73.35,6.7,-72.95,7.25&` +
      `bounded=1`,
      {
        headers: {
          'User-Agent': 'BucaraBus/1.0 (Sistema de transporte público)'
        }
      }
    )

    if (!response.ok) {
      throw new Error(`Nominatim API error: ${response.status}`)
    }

    const results = await response.json()

    // Formatear resultados
    const formatted = results.map(r => ({
      lat: parseFloat(r.lat),
      lng: parseFloat(r.lon),
      name: r.name || r.display_name.split(',')[0],
      address: r.display_name,
      type: r.type,
      osmId: r.osm_id
    }))

    res.json({
      success: true,
      data: formatted
    })
  } catch (error) {
    console.error('Error en geocoding search:', error)
    res.status(500).json({
      success: false,
      error: 'Error al buscar ubicación',
      message: error.message
    })
  }
})

export default router
