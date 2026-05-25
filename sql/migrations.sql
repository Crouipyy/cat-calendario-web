-- =====================================================================
-- Migraciones para el sistema de cuentas y auditoría del calendario web.
-- Ejecutar UNA VEZ contra la base de datos que usa la API en Vercel
-- (la misma que ya contiene la tabla `calendario`). Es seguro re-ejecutar.
-- =====================================================================

-- 1) Usuarios web del calendario.
--    rol = 'admin'    -> puede entrar al panel "Administración" (gestionar
--                        cuentas, ver logs) y editar TODO el calendario.
--    rol = 'profesor' -> sólo puede añadir/editar clases, eventos y notas;
--                        no puede tocar clima, separadores, meses, etc.
CREATE TABLE IF NOT EXISTS calendario_usuarios (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    username        VARCHAR(64)  NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    rol             ENUM('admin','profesor') NOT NULL DEFAULT 'profesor',
    creado_por      VARCHAR(64) DEFAULT NULL,
    creado_en       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2) Log de cambios del calendario (auditoría visible sólo para admins).
--    `accion` describe qué cambió a alto nivel (ej. "Editar clases",
--    "Cambiar clima", "Crear usuario"). `detalles` es texto libre con
--    contexto adicional (ej. semana/día/hora afectados).
CREATE TABLE IF NOT EXISTS calendario_logs (
    id        BIGINT AUTO_INCREMENT PRIMARY KEY,
    fecha     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    username  VARCHAR(64)   NOT NULL,
    rol       VARCHAR(16)   NOT NULL DEFAULT '',
    accion    VARCHAR(96)   NOT NULL,
    detalles  TEXT,
    INDEX idx_fecha    (fecha),
    INDEX idx_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
