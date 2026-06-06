// Helper compartido por las funciones de api/ para abrir una conexión
// MySQL contra la misma base de datos que usa el calendario.
//
// Este archivo está en /lib/, NO en /api/, así que Vercel no lo expone
// como ruta HTTP.

const mysql = require('mysql2/promise');

async function obtenerConexion() {
    const dbHost = process.env.DB_HOST;
    const dbUser = process.env.DB_USER;
    const dbPassword = process.env.DB_PASSWORD;
    const dbName = process.env.DB_NAME || 'cat_calendario';
    const dbPort = process.env.DB_PORT || 3306;

    if (!dbHost || !dbUser || !dbPassword) {
        console.warn('[lib/db] Variables de entorno MySQL incompletas:',
            { DB_HOST: !!dbHost, DB_USER: !!dbUser, DB_PASSWORD: !!dbPassword, DB_NAME: dbName });
        return null;
    }

    try {
        const conexion = await mysql.createConnection({
            host: dbHost,
            user: dbUser,
            password: dbPassword,
            database: dbName,
            port: parseInt(dbPort) || 3306,
            ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
            connectTimeout: 10000
        });
        return conexion;
    } catch (error) {
        console.error('[lib/db] Error conectando a MySQL:', error.message, error.code);
        return null;
    }
}

// Crea las tablas calendario_usuarios y calendario_logs si no existen.
// Es idempotente: se llama desde los handlers para que no haga falta
// ejecutar manualmente sql/migrations.sql al estrenar la deploy.
async function asegurarTablas(conexion) {
    if (!conexion) return false;
    try {
        await conexion.execute(`
            CREATE TABLE IF NOT EXISTS calendario_usuarios (
                id              INT AUTO_INCREMENT PRIMARY KEY,
                username        VARCHAR(64)  NOT NULL UNIQUE,
                password_hash   VARCHAR(255) NOT NULL,
                rol             ENUM('admin','profesor') NOT NULL DEFAULT 'profesor',
                creado_por      VARCHAR(64) DEFAULT NULL,
                creado_en       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
                actualizado_en  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP
                                ON UPDATE CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);
        await conexion.execute(`
            CREATE TABLE IF NOT EXISTS calendario_logs (
                id        BIGINT AUTO_INCREMENT PRIMARY KEY,
                fecha     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
                username  VARCHAR(64)   NOT NULL,
                rol       VARCHAR(16)   NOT NULL DEFAULT '',
                accion    VARCHAR(96)   NOT NULL,
                detalles  TEXT,
                INDEX idx_fecha    (fecha),
                INDEX idx_username (username)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);
        return true;
    } catch (error) {
        console.error('[lib/db] No se pudieron asegurar las tablas auxiliares:', error.message);
        return false;
    }
}

async function registrarLog(conexion, { username, rol, accion, detalles }) {
    if (!conexion) return false;
    try {
        await conexion.execute(
            'INSERT INTO calendario_logs (username, rol, accion, detalles) VALUES (?, ?, ?, ?)',
            [
                String(username || 'desconocido').slice(0, 64),
                String(rol || '').slice(0, 16),
                String(accion || '').slice(0, 96),
                detalles == null ? null : String(detalles).slice(0, 4000)
            ]
        );
        return true;
    } catch (error) {
        console.error('[lib/db] Error escribiendo en calendario_logs:', error.message);
        return false;
    }
}

module.exports = { obtenerConexion, asegurarTablas, registrarLog };
