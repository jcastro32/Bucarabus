// =============================================
// BucaraBUS - Configuración de Base de Datos
// =============================================
// Actualizar este archivo en: api/config/database.js
// =============================================

const { Pool } = require('pg');

// =============================================
// CONFIGURACIÓN PARA db_bucarabus
// =============================================

const pool = new Pool({
  user: 'bucarabus_user',
  host: 'localhost',
  database: 'db_bucarabus',  // ⚠️ CAMBIO: antes era 'bucarabus_db'
  password: 'bucarabus2024',
  port: 5432,
  
  // Configuración de pool
  max: 20,                    // Máximo de conexiones
  idleTimeoutMillis: 30000,   // Tiempo antes de cerrar conexión idle
  connectionTimeoutMillis: 2000,
});

// Manejo de errores del pool
pool.on('error', (err, client) => {
  console.error('Error inesperado en el cliente PostgreSQL', err);
  process.exit(-1);
});

// Test de conexión
pool.query('SELECT NOW()', (err, res) => {
  if (err) {
    console.error('❌ Error al conectar a la base de datos:', err);
  } else {
    console.log('✅ Conectado a PostgreSQL - db_bucarabus');
    console.log('📊 Timestamp del servidor:', res.rows[0].now);
  }
});

module.exports = pool;

// =============================================
// NOTAS IMPORTANTES - MIGRACIÓN v2.0
// =============================================

/*
CAMBIOS CRÍTICOS EN FUNCIONES:

1. user_create y user_update ahora son INTEGER (antes VARCHAR)
   
   ❌ ANTES (INCORRECTO):
   const result = await pool.query(
     'SELECT * FROM fun_create_user($1, $2, $3, $4, $5)',
     [email, hash, name, avatar, 'system']  // ❌ VARCHAR
   );

   ✅ AHORA (CORRECTO):
   const result = await pool.query(
     'SELECT * FROM fun_create_user($1, $2, $3, $4, $5)',
     [email, hash, name, 1735689600, avatar]  // ✅ INTEGER + orden diferente
   );

2. ORDEN DE PARÁMETROS CAMBIÓ:
   - Parámetros obligatorios (como user_create) van ANTES de los opcionales (DEFAULT)
   
   fun_create_user(email, hash, name, user_create, avatar?)
   fun_update_user(id_user, user_update, name?, avatar?)
   fun_create_route(name, path, user_create, description?, color?)

3. TODAS LAS FUNCIONES RETORNAN:
   {
     success: boolean,
     msg: string,
     error_code: string | null,
     id_*: number | null
   }

   ✅ MANEJO CORRECTO:
   const { rows } = await pool.query('SELECT * FROM fun_create_user(...)');
   const { success, msg, error_code, id_user } = rows[0];
   
   if (!success) {
     throw new Error(msg);  // O manejar error_code en frontend
   }

4. ID DEL USUARIO DEL SISTEMA:
   const SYSTEM_USER_ID = 1735689600;  // Epoch 2025-01-01
   
   Usar en:
   - fun_create_* cuando req.user no existe (ej: registro público)
   - fun_update_* tomar de req.user.id_user (JWT)
   - fun_delete_* tomar de req.user.id_user (JWT)

EJEMPLO COMPLETO DE MIGRACIÓN:

// ❌ ANTES
async createUser(email, password, name) {
  const hash = await bcrypt.hash(password, 10);
  const result = await pool.query(
    'SELECT * FROM fun_create_user($1, $2, $3, $4, $5)',
    [email, hash, name, null, 'system']
  );
  return result.rows[0];
}

// ✅ AHORA
async createUser(email, password, name, avatar = null) {
  const hash = await bcrypt.hash(password, 10);
  const SYSTEM_USER_ID = 1735689600;
  
  const result = await pool.query(
    'SELECT * FROM fun_create_user($1, $2, $3, $4, $5)',
    [email, hash, name, SYSTEM_USER_ID, avatar]
  );
  
  const { success, msg, error_code, id_user } = result.rows[0];
  
  if (!success) {
    const error = new Error(msg);
    error.code = error_code;
    throw error;
  }
  
  return { id_user, email, name, avatar };
}

ARCHIVOS A ACTUALIZAR:

1. api/config/database.js ✅ (este archivo)
2. api/services/users.service.js
3. api/services/drivers.service.js
4. api/services/buses.service.js
5. api/services/routes.service.js
6. api/services/trips.service.js
7. api/services/assignments.service.js
8. api/services/shifts.service.js

PATRÓN RECOMENDADO:

// Constante global
const SYSTEM_USER_ID = 1735689600;

// Helper para obtener user_id del request
function getUserId(req) {
  return req.user?.id_user || SYSTEM_USER_ID;
}

// Uso en servicios
async updateBus(plateNumber, data, req) {
  const userId = getUserId(req);
  
  const result = await pool.query(
    'SELECT * FROM fun_update_bus($1, $2, $3, ... $13)',
    [plateNumber, data.amb, data.company, ..., userId]
  );
  
  const { success, msg, error_code } = result.rows[0];
  if (!success) throw new Error(msg);
  
  return result.rows[0];
}
*/
