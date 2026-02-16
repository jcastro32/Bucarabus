import pg from 'pg'
import dotenv from 'dotenv'

dotenv.config()

const { Pool, types } = pg

// Configurar pg para que devuelva DATE como string en formato YYYY-MM-DD
// OID 1082 es el tipo DATE en PostgreSQL
types.setTypeParser(1082, (val) => val)

// Configuración del pool de conexiones
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'db_newBucarabus',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD,
  min: parseInt(process.env.DB_POOL_MIN) || 2,
  max: parseInt(process.env.DB_POOL_MAX) || 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
})

// Evento de error
pool.on('error', (err, client) => {
  console.error('❌ Error inesperado en el pool de PostgreSQL:', err)
  process.exit(-1)
})

// Verificar conexión
pool.query('SELECT NOW()', (err, res) => {
  if (err) {
    console.error('❌ Error conectando a PostgreSQL:', err)
  } else {
    console.log('✅ PostgreSQL conectado exitosamente')
    console.log('📅 Timestamp del servidor:', res.rows[0].now)
  }
})

export default pool
