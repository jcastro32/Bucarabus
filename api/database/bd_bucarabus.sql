-- =============================================
-- BucaraBUS - Base de Datos Principal
-- Sistema de gestión de transporte público
-- =============================================
-- Version: 2.0
-- Fecha: Febrero 2025
-- Arquitectura: PostgreSQL + PostGIS
-- =============================================

-- =============================================
-- 1. EXTENSIONES
-- =============================================

CREATE EXTENSION IF NOT EXISTS postgis;

-- =============================================
-- 2. LIMPIEZA (DROP en orden inverso de dependencias)
-- =============================================

-- Primero eliminar tablas dependientes
DROP TABLE IF EXISTS tab_trips CASCADE;
DROP TABLE IF EXISTS tab_favorite_routes CASCADE;
DROP TABLE IF EXISTS tab_bus_assignments CASCADE;
DROP TABLE IF EXISTS tab_routes CASCADE;
DROP TABLE IF EXISTS tab_buses CASCADE;
DROP TABLE IF EXISTS tab_driver_details CASCADE;
DROP TABLE IF EXISTS tab_user_roles CASCADE;
DROP TABLE IF EXISTS tab_roles CASCADE;
DROP TABLE IF EXISTS tab_users CASCADE;

-- Tablas legacy/obsoletas
DROP TABLE IF EXISTS tab_drivers CASCADE;
DROP TABLE IF EXISTS tab_subscriptions CASCADE;
DROP TABLE IF EXISTS trips CASCADE;

-- =============================================
-- 3. TABLAS PRINCIPALES (en orden de dependencias)
-- =============================================

-- --------------------------------------------
-- 3.1 TABLA: tab_users
-- Descripción: Tabla base de usuarios del sistema
-- --------------------------------------------

CREATE TABLE tab_users (
  id_user       INTEGER         NOT NULL,
  email         VARCHAR(320)    UNIQUE NOT NULL,
  password_hash VARCHAR(60)     NOT NULL,
  full_name     VARCHAR(100)    NOT NULL,
  avatar_url    VARCHAR(500),
  created_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ,
  user_create   INTEGER         NOT NULL DEFAULT 1735689600,
  user_update   INTEGER,
  last_login    TIMESTAMPTZ,
  is_active     BOOLEAN         NOT NULL DEFAULT TRUE,

  CONSTRAINT pk_users PRIMARY KEY (id_user),
  CONSTRAINT chk_users_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
  CONSTRAINT fk_users_created_by FOREIGN KEY (user_create) REFERENCES tab_users(id_user) ON DELETE SET DEFAULT DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT fk_users_updated_by FOREIGN KEY (user_update) REFERENCES tab_users(id_user) ON DELETE SET NULL
);

-- --------------------------------------------
-- 3.2 TABLA: tab_roles
-- Descripción: Catálogo de roles del sistema
-- --------------------------------------------

CREATE TABLE tab_roles (
  id_role     SMALLINT        NOT NULL,
  role_name   VARCHAR(50)     NOT NULL UNIQUE,
  description TEXT,
  is_active   BOOLEAN         NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ,
  user_create INTEGER         NOT NULL DEFAULT 1735689600,
  user_update INTEGER,
  
  CONSTRAINT pk_roles PRIMARY KEY (id_role),
  CONSTRAINT fk_roles_created_by FOREIGN KEY (user_create) REFERENCES tab_users(id_user) ON DELETE SET DEFAULT,
  CONSTRAINT fk_roles_updated_by FOREIGN KEY (user_update) REFERENCES tab_users(id_user) ON DELETE SET NULL
);

-- --------------------------------------------
-- 3.3 TABLA: tab_user_roles
-- Descripción: Relación muchos-a-muchos entre usuarios y roles
-- --------------------------------------------

CREATE TABLE tab_user_roles (
  id_user     INTEGER         NOT NULL,
  id_role     SMALLINT        NOT NULL,
  assigned_at TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  assigned_by INTEGER,
  is_active   BOOLEAN         NOT NULL DEFAULT TRUE,
  
  CONSTRAINT pk_user_roles PRIMARY KEY (id_user, id_role),
  CONSTRAINT fk_user_roles_user FOREIGN KEY (id_user) REFERENCES tab_users(id_user) ON DELETE CASCADE,
  CONSTRAINT fk_user_roles_role FOREIGN KEY (id_role) REFERENCES tab_roles(id_role) ON DELETE CASCADE,
  CONSTRAINT fk_user_roles_assigned_by FOREIGN KEY (assigned_by) REFERENCES tab_users(id_user) ON DELETE SET NULL
);

-- --------------------------------------------
-- 3.4 TABLA: tab_driver_details
-- Descripción: Información específica para conductores
-- --------------------------------------------

CREATE TABLE tab_driver_details (
  id_card         DECIMAL(12,0)   NOT NULL,
  id_user         INTEGER         NOT NULL UNIQUE,
  cel             VARCHAR(15)     NOT NULL,
  available       BOOLEAN         NOT NULL DEFAULT TRUE,
  license_cat     VARCHAR(2)      NOT NULL,
  license_exp     DATE            NOT NULL,
  address_driver  TEXT,
  date_entry      DATE            NOT NULL DEFAULT CURRENT_DATE,
  status_driver   BOOLEAN         NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  user_create     INTEGER         NOT NULL DEFAULT 1735689600,
  updated_at      TIMESTAMPTZ,
  user_update     INTEGER,
  
  CONSTRAINT pk_driver_details PRIMARY KEY (id_card),
  CONSTRAINT fk_driver_details_user FOREIGN KEY (id_user) REFERENCES tab_users(id_user) ON DELETE CASCADE,
  CONSTRAINT fk_driver_details_created_by FOREIGN KEY (user_create) REFERENCES tab_users(id_user) ON DELETE SET DEFAULT,
  CONSTRAINT fk_driver_details_updated_by FOREIGN KEY (user_update) REFERENCES tab_users(id_user) ON DELETE SET NULL,
  CONSTRAINT chk_driver_license_cat CHECK (license_cat IN ('C1', 'C2', 'C3')),
  CONSTRAINT chk_driver_cel_format CHECK (cel ~ '^[0-9]{7,15}$'),
  CONSTRAINT chk_driver_license_exp CHECK (license_exp > date_entry)
);

-- --------------------------------------------
-- 3.5 TABLA: tab_buses
-- Descripción: Catálogo de buses del sistema
-- --------------------------------------------

CREATE TABLE tab_buses (
  plate_number  VARCHAR(6)      NOT NULL,
  amb_code      VARCHAR(8)      NOT NULL UNIQUE,
  id_user       INTEGER,
  id_company    SMALLINT        NOT NULL,
  capacity      SMALLINT        NOT NULL,
  photo_url     VARCHAR(500),
  soat_exp      DATE            NOT NULL,
  techno_exp    DATE            NOT NULL,
  rcc_exp       DATE            NOT NULL,
  rce_exp       DATE            NOT NULL,
  id_card_owner DECIMAL(12,0)   NOT NULL,
  name_owner    VARCHAR(100)    NOT NULL,
  is_active     BOOLEAN         NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ,
  user_create   INTEGER         NOT NULL DEFAULT 1735689600,
  user_update   INTEGER,
  
  CONSTRAINT pk_buses PRIMARY KEY (plate_number),
  CONSTRAINT fk_buses_driver FOREIGN KEY (id_user) REFERENCES tab_users(id_user) ON DELETE SET NULL,
  CONSTRAINT fk_buses_created_by FOREIGN KEY (user_create) REFERENCES tab_users(id_user) ON DELETE SET DEFAULT,
  CONSTRAINT fk_buses_updated_by FOREIGN KEY (user_update) REFERENCES tab_users(id_user) ON DELETE SET NULL,
  CONSTRAINT chk_buses_plate_format CHECK (plate_number ~ '^[A-Z]{3}[0-9]{3}$'),
  CONSTRAINT chk_buses_amb_format CHECK (amb_code ~ '^AMB-[0-9]{4}$'),
  CONSTRAINT chk_buses_company CHECK (id_company BETWEEN 1 AND 99),
  CONSTRAINT chk_buses_capacity CHECK (capacity BETWEEN 10 AND 999),
  CONSTRAINT chk_buses_soat_exp CHECK (soat_exp > CURRENT_DATE),
  CONSTRAINT chk_buses_techno_exp CHECK (techno_exp > CURRENT_DATE),
  CONSTRAINT chk_buses_rcc_exp CHECK (rcc_exp > CURRENT_DATE),
  CONSTRAINT chk_buses_rce_exp CHECK (rce_exp > CURRENT_DATE)
);

-- --------------------------------------------
-- 3.6 TABLA: tab_routes
-- Descripción: Catálogo de rutas con geometría PostGIS
-- --------------------------------------------

CREATE TABLE tab_routes (
  id_route      INTEGER         NOT NULL,
  name_route    VARCHAR(200)    NOT NULL,
  path_route    GEOMETRY(LineString, 4326) NOT NULL,
  descrip_route TEXT,
  color_route   VARCHAR(7)      NOT NULL,
  start_area    GEOMETRY(Polygon, 4326),
  end_area      GEOMETRY(Polygon, 4326),
  status_route  BOOLEAN         NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ,
  user_create   INTEGER         NOT NULL DEFAULT 1735689600,
  user_update   INTEGER,
  
  CONSTRAINT pk_routes PRIMARY KEY (id_route),
  CONSTRAINT fk_routes_created_by FOREIGN KEY (user_create) REFERENCES tab_users(id_user) ON DELETE SET DEFAULT,
  CONSTRAINT fk_routes_updated_by FOREIGN KEY (user_update) REFERENCES tab_users(id_user) ON DELETE SET NULL,
  CONSTRAINT chk_routes_color_format CHECK (color_route ~ '^#[0-9A-Fa-f]{6}$')
);

-- --------------------------------------------
-- 3.7 TABLA: tab_favorite_routes
-- Descripción: Rutas favoritas de los usuarios
-- --------------------------------------------

CREATE TABLE tab_favorite_routes (
  id_user   INTEGER         NOT NULL,
  id_route  INTEGER         NOT NULL,
  added_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  
  CONSTRAINT pk_favorite_routes PRIMARY KEY (id_user, id_route),
  CONSTRAINT fk_fav_routes_user FOREIGN KEY (id_user) REFERENCES tab_users(id_user) ON DELETE CASCADE,
  CONSTRAINT fk_fav_routes_route FOREIGN KEY (id_route) REFERENCES tab_routes(id_route) ON DELETE CASCADE
);

-- --------------------------------------------
-- 3.8 TABLA: tab_bus_assignments
-- Descripción: Historial de asignaciones bus-conductor
-- --------------------------------------------

CREATE TABLE tab_bus_assignments (
  id_assignment INTEGER         GENERATED BY DEFAULT AS IDENTITY,
  plate_number  VARCHAR(6)      NOT NULL,
  id_user       INTEGER         NOT NULL,
  assigned_at   TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  unassigned_at TIMESTAMPTZ,
  assigned_by   INTEGER         NOT NULL DEFAULT 1735689600,
  unassigned_by INTEGER,
  created_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  user_create   INTEGER         NOT NULL DEFAULT 1735689600,
  updated_at    TIMESTAMPTZ,
  user_update   INTEGER,
  
  CONSTRAINT pk_bus_assignments PRIMARY KEY (id_assignment),
  CONSTRAINT fk_assignments_bus FOREIGN KEY (plate_number) REFERENCES tab_buses(plate_number) ON DELETE CASCADE,
  CONSTRAINT fk_assignments_driver FOREIGN KEY (id_user) REFERENCES tab_users(id_user) ON DELETE CASCADE,
  CONSTRAINT fk_assignments_assigned_by FOREIGN KEY (assigned_by) REFERENCES tab_users(id_user) ON DELETE SET DEFAULT,
  CONSTRAINT fk_assignments_unassigned_by FOREIGN KEY (unassigned_by) REFERENCES tab_users(id_user) ON DELETE SET NULL,
  CONSTRAINT fk_assignments_created_by FOREIGN KEY (user_create) REFERENCES tab_users(id_user) ON DELETE SET DEFAULT,
  CONSTRAINT fk_assignments_updated_by FOREIGN KEY (user_update) REFERENCES tab_users(id_user) ON DELETE SET NULL,
  CONSTRAINT chk_assignments_dates CHECK (unassigned_at IS NULL OR unassigned_at >= assigned_at)
);

-- --------------------------------------------
-- 3.9 TABLA: tab_trips
-- Descripción: Turnos/viajes programados para las rutas
-- --------------------------------------------

CREATE TABLE tab_trips (
  id_trip       BIGINT          GENERATED BY DEFAULT AS IDENTITY,
  id_route      INTEGER         NOT NULL,
  trip_date     DATE            NOT NULL,
  start_time    TIME(0)         NOT NULL,
  end_time      TIME(0)         NOT NULL,
  plate_number  VARCHAR(6),
  status_trip   VARCHAR(20)     NOT NULL DEFAULT 'pending',
  created_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  user_create   INTEGER         NOT NULL DEFAULT 1735689600,
  updated_at    TIMESTAMPTZ,
  user_update   INTEGER,
  
  CONSTRAINT pk_trips PRIMARY KEY (id_trip),
  CONSTRAINT fk_trips_route FOREIGN KEY (id_route) REFERENCES tab_routes(id_route) ON DELETE CASCADE,
  CONSTRAINT fk_trips_bus FOREIGN KEY (plate_number) REFERENCES tab_buses(plate_number) ON DELETE SET NULL,
  CONSTRAINT fk_trips_created_by FOREIGN KEY (user_create) REFERENCES tab_users(id_user) ON DELETE SET DEFAULT,
  CONSTRAINT fk_trips_updated_by FOREIGN KEY (user_update) REFERENCES tab_users(id_user) ON DELETE SET NULL,
  CONSTRAINT chk_trips_status CHECK (status_trip IN ('pending', 'assigned', 'active', 'completed', 'cancelled')),
  CONSTRAINT chk_trips_times CHECK (end_time > start_time),
  CONSTRAINT chk_trips_date CHECK (trip_date >= CURRENT_DATE - INTERVAL '7 days'),
  CONSTRAINT uq_trips_route_datetime UNIQUE (id_route, trip_date, start_time)
);

-- =============================================
-- 4. ÍNDICES (organizados por tabla)
-- =============================================

-- Índices - tab_users
CREATE INDEX idx_users_email ON tab_users(LOWER(email));
CREATE INDEX idx_users_active ON tab_users(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_users_created_by ON tab_users(user_create);
CREATE INDEX idx_users_updated_by ON tab_users(user_update) WHERE user_update IS NOT NULL;
CREATE INDEX idx_users_last_login ON tab_users(last_login DESC) WHERE last_login IS NOT NULL;

-- Índices - tab_roles
CREATE INDEX idx_roles_active ON tab_roles(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_roles_created_by ON tab_roles(user_create);
CREATE INDEX idx_roles_updated_by ON tab_roles(user_update) WHERE user_update IS NOT NULL;

-- Índices - tab_user_roles
CREATE INDEX idx_user_roles_user ON tab_user_roles(id_user) WHERE is_active = TRUE;
CREATE INDEX idx_user_roles_role ON tab_user_roles(id_role) WHERE is_active = TRUE;
CREATE INDEX idx_user_roles_assigned_by ON tab_user_roles(assigned_by);

-- Índices - tab_driver_details
CREATE INDEX idx_driver_details_user ON tab_driver_details(id_user);
CREATE INDEX idx_driver_details_available ON tab_driver_details(available) WHERE available = TRUE AND status_driver = TRUE;
CREATE INDEX idx_driver_details_license_exp ON tab_driver_details(license_exp);
CREATE INDEX idx_driver_details_created_by ON tab_driver_details(user_create);
CREATE INDEX idx_driver_details_updated_by ON tab_driver_details(user_update) WHERE user_update IS NOT NULL;

-- Índices - tab_buses
CREATE INDEX idx_buses_amb_code ON tab_buses(amb_code);
CREATE INDEX idx_buses_driver ON tab_buses(id_user) WHERE id_user IS NOT NULL;
CREATE INDEX idx_buses_active ON tab_buses(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_buses_company ON tab_buses(id_company);
CREATE INDEX idx_buses_created_by ON tab_buses(user_create);
CREATE INDEX idx_buses_updated_by ON tab_buses(user_update) WHERE user_update IS NOT NULL;

-- Índices - tab_routes
CREATE INDEX idx_routes_active ON tab_routes(status_route) WHERE status_route = TRUE;
CREATE INDEX idx_routes_name ON tab_routes(name_route);
CREATE INDEX idx_routes_created_by ON tab_routes(user_create);
CREATE INDEX idx_routes_updated_by ON tab_routes(user_update) WHERE user_update IS NOT NULL;

-- Índices espaciales - tab_routes
CREATE INDEX idx_routes_path_gist ON tab_routes USING GIST(path_route);
CREATE INDEX idx_routes_start_area_gist ON tab_routes USING GIST(start_area) WHERE start_area IS NOT NULL;
CREATE INDEX idx_routes_end_area_gist ON tab_routes USING GIST(end_area) WHERE end_area IS NOT NULL;

-- Índices - tab_favorite_routes
CREATE INDEX idx_fav_routes_user ON tab_favorite_routes(id_user);
CREATE INDEX idx_fav_routes_route ON tab_favorite_routes(id_route);
CREATE INDEX idx_fav_routes_added ON tab_favorite_routes(added_at DESC);

-- Índices - tab_bus_assignments
CREATE INDEX idx_assignments_bus ON tab_bus_assignments(plate_number);
CREATE INDEX idx_assignments_driver ON tab_bus_assignments(id_user);
CREATE INDEX idx_assignments_assigned_at ON tab_bus_assignments(assigned_at DESC);
CREATE INDEX idx_assignments_active ON tab_bus_assignments(plate_number, id_user) WHERE unassigned_at IS NULL;
CREATE INDEX idx_assignments_assigned_by ON tab_bus_assignments(assigned_by);
CREATE INDEX idx_assignments_created_by ON tab_bus_assignments(user_create);
CREATE INDEX idx_assignments_updated_by ON tab_bus_assignments(user_update) WHERE user_update IS NOT NULL;

-- Índices - tab_trips
CREATE INDEX idx_trips_route_date ON tab_trips(id_route, trip_date);
CREATE INDEX idx_trips_date ON tab_trips(trip_date);
CREATE INDEX idx_trips_bus ON tab_trips(plate_number) WHERE plate_number IS NOT NULL;
CREATE INDEX idx_trips_status ON tab_trips(status_trip);
CREATE INDEX idx_trips_pending ON tab_trips(id_route, trip_date) WHERE status_trip = 'pending';
CREATE INDEX idx_trips_created_by ON tab_trips(user_create);
CREATE INDEX idx_trips_updated_by ON tab_trips(user_update) WHERE user_update IS NOT NULL;

-- =============================================
-- 5. DATOS INICIALES (SEEDS)
-- =============================================

-- --------------------------------------------
-- 5.1 Usuario del Sistema
-- --------------------------------------------

INSERT INTO tab_users (
  id_user,
  email,
  password_hash,
  full_name,
  created_at,
  user_create,
  is_active
) VALUES (
  1735689600,
  'system@bucarabus.local',
  '$2b$10$SYSTEMUSERDUMMYHASH0000000000000000000000000000000',
  'Sistema Bucarabus',
  NOW(),
  1735689600,
  TRUE
)
ON CONFLICT (id_user) DO NOTHING;

-- --------------------------------------------
-- 5.2 Roles del Sistema
-- --------------------------------------------

INSERT INTO tab_roles (id_role, role_name, description, user_create) VALUES
  (1, 'Pasajero', 'Usuario que consulta rutas y horarios', 1735689600),
  (2, 'Conductor', 'Conductor de buses del sistema', 1735689600),
  (3, 'Supervisor', 'Supervisor de operaciones', 1735689600),
  (4, 'Administrador', 'Administrador del sistema', 1735689600)
ON CONFLICT (id_role) DO NOTHING;

-- --------------------------------------------
-- 5.3 Asignar rol al usuario del sistema
-- --------------------------------------------

INSERT INTO tab_user_roles (id_user, id_role, assigned_at, is_active)
VALUES (1735689600, 4, NOW(), TRUE)
ON CONFLICT (id_user, id_role) DO NOTHING;

-- =============================================
-- 6. COMENTARIOS DE DOCUMENTACIÓN
-- =============================================

-- Comentarios de tablas
COMMENT ON TABLE tab_users IS 'Tabla base de usuarios del sistema (pasajeros, conductores, supervisores, administradores)';
COMMENT ON TABLE tab_roles IS 'Catálogo de roles del sistema';
COMMENT ON TABLE tab_user_roles IS 'Relación muchos-a-muchos: un usuario puede tener múltiples roles';
COMMENT ON TABLE tab_driver_details IS 'Información específica para usuarios con rol de conductor';
COMMENT ON TABLE tab_buses IS 'Catálogo de buses del sistema de transporte';
COMMENT ON TABLE tab_routes IS 'Catálogo de rutas con geometría PostGIS';
COMMENT ON TABLE tab_favorite_routes IS 'Rutas favoritas de los usuarios';
COMMENT ON TABLE tab_bus_assignments IS 'Historial de asignaciones bus-conductor';
COMMENT ON TABLE tab_trips IS 'Turnos/viajes programados para las rutas';

-- Comentarios de campos de auditoría - tab_users
COMMENT ON COLUMN tab_users.user_create IS 'ID del usuario que creó este registro (FK a tab_users)';
COMMENT ON COLUMN tab_users.user_update IS 'ID del usuario que actualizó por última vez (FK a tab_users)';
COMMENT ON COLUMN tab_users.created_at IS 'Fecha y hora de creación del registro';
COMMENT ON COLUMN tab_users.updated_at IS 'Fecha y hora de última actualización';

-- Comentarios de campos de auditoría - tab_roles
COMMENT ON COLUMN tab_roles.user_create IS 'ID del usuario administrador que creó este rol';
COMMENT ON COLUMN tab_roles.user_update IS 'ID del usuario administrador que actualizó este rol';

-- Comentarios de campos de auditoría - tab_driver_details
COMMENT ON COLUMN tab_driver_details.user_create IS 'ID del usuario administrador que creó este conductor';
COMMENT ON COLUMN tab_driver_details.user_update IS 'ID del usuario administrador que actualizó este conductor';

-- Comentarios de campos de auditoría - tab_buses
COMMENT ON COLUMN tab_buses.user_create IS 'ID del usuario administrador que creó el bus (FK a tab_users)';
COMMENT ON COLUMN tab_buses.user_update IS 'ID del usuario administrador que actualizó el bus por última vez (FK a tab_users)';
COMMENT ON COLUMN tab_buses.created_at IS 'Fecha y hora de creación del registro';
COMMENT ON COLUMN tab_buses.updated_at IS 'Fecha y hora de última actualización';

-- Comentarios de campos de auditoría - tab_routes
COMMENT ON COLUMN tab_routes.user_create IS 'ID del usuario administrador que creó la ruta (FK a tab_users)';
COMMENT ON COLUMN tab_routes.user_update IS 'ID del usuario administrador que actualizó la ruta por última vez (FK a tab_users)';
COMMENT ON COLUMN tab_routes.created_at IS 'Fecha y hora de creación del registro';
COMMENT ON COLUMN tab_routes.updated_at IS 'Fecha y hora de última actualización';

-- Comentarios de campos de auditoría - tab_bus_assignments
COMMENT ON COLUMN tab_bus_assignments.assigned_by IS 'ID del usuario que realizó la asignación (FK a tab_users)';
COMMENT ON COLUMN tab_bus_assignments.unassigned_by IS 'ID del usuario que realizó la desasignación (FK a tab_users)';
COMMENT ON COLUMN tab_bus_assignments.user_create IS 'ID del usuario que creó el registro (FK a tab_users)';
COMMENT ON COLUMN tab_bus_assignments.user_update IS 'ID del usuario que actualizó el registro (FK a tab_users)';

-- Comentarios de campos de auditoría - tab_trips
COMMENT ON COLUMN tab_trips.user_create IS 'ID del usuario administrador que creó el turno/viaje (FK a tab_users)';
COMMENT ON COLUMN tab_trips.user_update IS 'ID del usuario administrador que actualizó el turno/viaje (FK a tab_users)';
COMMENT ON COLUMN tab_trips.created_at IS 'Fecha y hora de creación del registro';
COMMENT ON COLUMN tab_trips.updated_at IS 'Fecha y hora de última actualización';

-- =============================================
-- 7. RESUMEN DEL ESQUEMA
-- =============================================

/*
CONVENCIONES DE AUDITORÍA:
---------------------------
Todas las tablas incluyen campos de auditoría estandarizados:

user_create: INTEGER NOT NULL DEFAULT 1735689600
             FK a tab_users(id_user) ON DELETE SET DEFAULT
             Registra quién creó el registro

user_update: INTEGER NULL
             FK a tab_users(id_user) ON DELETE SET NULL
             Registra quién realizó la última actualización

created_at:  TIMESTAMPTZ NOT NULL DEFAULT NOW()
             Fecha/hora de creación con zona horaria

updated_at:  TIMESTAMPTZ NULL
             Fecha/hora de última actualización

ID del usuario del sistema: 1735689600 (Epoch 2025-01-01)

TIPOS DE DATOS ESTANDARIZADOS:
-------------------------------
- Timestamps: TIMESTAMPTZ (con zona horaria)
- IDs de rutas: INTEGER (más eficiente que DECIMAL)
- Compañías: SMALLINT (1-99)
- Capacidad: SMALLINT (10-999)
- Texto corto: VARCHAR con límite especificado
- Texto largo: TEXT

ÍNDICES:
--------
- Campos de búsqueda frecuente
- Foreign keys principales
- Índices parciales para filtros comunes (WHERE is_active = TRUE)
- Índices espaciales GIST para geometrías PostGIS
- Índices de auditoría en user_create/user_update

FOREIGN KEYS:
-------------
- ON DELETE CASCADE: Cuando el padre debe eliminar hijos
- ON DELETE SET NULL: Cuando la relación es opcional
- ON DELETE SET DEFAULT: Para campos de auditoría (usa sistema)
- DEFERRABLE: Para referencias circulares (ej: tab_users.user_create)
*/

-- =============================================
-- FIN DEL ESQUEMA
-- =============================================


