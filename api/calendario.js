// API para manejar el calendario usando MySQL como almacenamiento persistente
const mysql = require('mysql2/promise');
const { calendarioPlantillaParaUI } = require('./calendarioPlantilla');
const { verificarBearer, normalizarPermisos } = require('./lib/auth');
const { obtenerConexion: obtenerConexionAux, asegurarTablas, registrarLog } = require('./lib/db');

// Función para obtener conexión a MySQL
async function obtenerConexion() {
    // Verificar que las variables de entorno necesarias estén configuradas
    const dbHost = process.env.DB_HOST;
    const dbUser = process.env.DB_USER;
    const dbPassword = process.env.DB_PASSWORD;
    const dbName = process.env.DB_NAME || 'cat_calendario'; // Valor por defecto
    const dbPort = process.env.DB_PORT || 3306;
    
    // Si no hay variables críticas, retornar null
    if (!dbHost || !dbUser || !dbPassword) {
        console.warn('[API] ⚠️ Variables de entorno de MySQL no configuradas completamente');
        console.warn('[API] DB_HOST:', dbHost ? '✓' : '✗');
        console.warn('[API] DB_USER:', dbUser ? '✓' : '✗');
        console.warn('[API] DB_PASSWORD:', dbPassword ? '✓' : '✗');
        console.warn('[API] DB_NAME:', dbName);
        return null;
    }
    
    try {
        console.log('[API] Intentando conectar a MySQL...');
        console.log('[API] Host:', dbHost);
        console.log('[API] User:', dbUser);
        console.log('[API] Database:', dbName);
        console.log('[API] Port:', parseInt(dbPort) || 3306);
        
        const conexion = await mysql.createConnection({
            host: dbHost,
            user: dbUser,
            password: dbPassword,
            database: dbName,
            port: parseInt(dbPort) || 3306,
            ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
            connectTimeout: 10000 // Timeout de 10 segundos
        });
        
        console.log('[API] ✓ Conexión a MySQL establecida correctamente');
        return conexion;
    } catch (error) {
        console.error('[API] ✗ Error conectando a MySQL:', error.message);
        console.error('[API] Error code:', error.code);
        console.error('[API] Error errno:', error.errno);
        
        // Mensaje específico para errores de permisos
        if (error.code === 'ER_DBACCESS_DENIED_ERROR' || error.errno === 1044) {
            console.error('[API] ⚠️ ERROR DE PERMISOS: El usuario no tiene acceso a la base de datos');
            console.error('[API] ⚠️ Verifica:');
            console.error('[API] ⚠️ 1. Que el nombre de la base de datos (DB_NAME) sea correcto');
            console.error('[API] ⚠️ 2. Que el usuario tenga permisos en MySQL para acceder a esa base de datos');
            console.error('[API] ⚠️ 3. Que la base de datos exista');
            console.error('[API] ⚠️ Base de datos intentada:', dbName);
        }

        if (error.code === 'ER_ACCESS_DENIED_ERROR' || error.errno === 1045) {
            console.error('[API] ⚠️ ACCESS DENIED (1045): usuario/contraseña O host de cliente no permitido.');
            console.error('[API] ⚠️ Vercel entra a MySQL como usuario@ec2-....amazonaws.com (no es tu PC).');
            console.error('[API] ⚠️ HeidiSQL funciona porque eres otro host (ej. localhost o tu IP).');
            console.error('[API] ⚠️ Solución típica: en el servidor 37.187.25.84 ejecuta como root:');
            console.error("[API]    CREATE USER IF NOT EXISTS 'fivemuser'@'%' IDENTIFIED BY 'TU_MISMA_CLAVE';");
            console.error('[API]    GRANT SELECT,INSERT,UPDATE,DELETE ON noroirp.* TO \'fivemuser\'@\'%\';');
            console.error('[API]    FLUSH PRIVILEGES;');
            console.error('[API] ⚠️ (Ajusta nombre de usuario/BD si usas otros.) Abre el puerto 3306 a Internet solo si asumes el riesgo.');
        }
        
        // No lanzar el error, dejar que la función que llama lo maneje
        return null;
    }
}

// Leer calendario desde MySQL
async function leerCalendario() {
    let conexion = null;
    try {
        conexion = await obtenerConexion();
        
        // Si no se pudo conectar, plantilla para la web
        if (!conexion) {
            console.warn('[API] ⚠️ No se pudo conectar a MySQL, retornando plantilla UI (no vacía) para evitar pantalla en blanco');
            return calendarioPlantillaParaUI();
        }
        
        // Obtener el último registro (id = 1 siempre, o el más reciente)
        let rows = [];
        try {
            [rows] = await conexion.execute(
                'SELECT datos, ultima_actualizacion FROM calendario WHERE id = 1 LIMIT 1'
            );
        } catch (executeError) {
            console.error('[API] Error ejecutando query:', executeError);
            console.error('[API] Error details:', executeError.message);
            return calendarioPlantillaParaUI();
        }

        // Sin fila id=1: insertar plantilla para que el GET siguiente y la web tengan datos reales en MySQL
        if (!rows || rows.length === 0) {
            const plantilla = calendarioPlantillaParaUI();
            const json = JSON.stringify(plantilla);
            await conexion.execute(
                'INSERT INTO calendario (id, datos, ultima_actualizacion, actualizado_por) VALUES (1, ?, ?, ?)',
                [json, plantilla.ultimaActualizacion, 'api-seed']
            );
            console.log('[API] No existía fila id=1 en calendario: insertada plantilla inicial (2 semanas).');
            return plantilla;
        }

        const rawDatos = rows[0].datos;
        const trimmed = rawDatos != null ? String(rawDatos).trim() : '';
        if (trimmed === '' || trimmed === '{}') {
            console.warn('[API] Columna datos vacía o {}: devolviendo plantilla UI SIN sobrescribir DB.');
            return calendarioPlantillaParaUI();
        }

        if (rows && rows.length > 0) {
            try {
                const datos = JSON.parse(trimmed);
                console.log('[API] Calendario leído desde MySQL');
                console.log('[API] Timestamp:', rows[0].ultima_actualizacion);

                let datosValidos = false;

                try {
                    if (datos && typeof datos === 'object') {
                        if (datos.semanas) {
                            if (Array.isArray(datos.semanas) && datos.semanas.length > 0) {
                                datosValidos = true;
                            } else if (typeof datos.semanas === 'object' && datos.semanas !== null) {
                                const keys = Object.keys(datos.semanas);
                                if (keys.length > 0) {
                                    for (const key of keys) {
                                        const semana = datos.semanas[key];
                                        if (semana && semana.dias && typeof semana.dias === 'object' && Object.keys(semana.dias).length > 0) {
                                            datosValidos = true;
                                            break;
                                        }
                                    }
                                }
                            }
                        }

                        if (!datosValidos && datos.separadores && typeof datos.separadores === 'object' && datos.separadores !== null) {
                            if (Object.keys(datos.separadores).length > 0) {
                                datosValidos = true;
                            }
                        }

                        if (!datosValidos && datos.climasHorario && typeof datos.climasHorario === 'object' && datos.climasHorario !== null) {
                            if (Object.keys(datos.climasHorario).length > 0) {
                                datosValidos = true;
                            }
                        }

                        if (!datosValidos && datos.meses) {
                            if (Array.isArray(datos.meses) && datos.meses.length > 0) {
                                datosValidos = true;
                            } else if (typeof datos.meses === 'object' && datos.meses !== null && Object.keys(datos.meses).length > 0) {
                                datosValidos = true;
                            }
                        }
                    }
                } catch (validationError) {
                    console.error('[API] Error en validación:', validationError);
                    datosValidos = true;
                }

                if (!datosValidos) {
                    console.warn('[API] JSON en MySQL sin semanas útiles: devolviendo plantilla UI SIN sobrescribir DB.');
                    return calendarioPlantillaParaUI();
                }

                // GMod compara ultimaActualizacion del JSON; asegurar que refleje la columna SQL (evita pull sin efecto si el JSON viejo no traía el campo).
                const tsCol = rows[0].ultima_actualizacion;
                const tsJson = Math.floor(Number(datos.ultimaActualizacion)) || 0;
                let tsMerged = tsJson;
                if (tsCol != null && tsCol !== '') {
                    const tc = Math.floor(Number(tsCol));
                    if (!Number.isNaN(tc) && tc > 0) {
                        tsMerged = Math.max(tc, tsJson);
                    }
                }
                datos.ultimaActualizacion = tsMerged;

                return datos;
            } catch (parseError) {
                console.error('[API] Error parseando JSON desde MySQL:', parseError);
                console.error('[API] Datos raw:', rows[0].datos ? String(rows[0].datos).substring(0, 100) : 'null');
                console.warn('[API] JSON corrupto: devolviendo plantilla UI SIN sobrescribir DB.');
                return calendarioPlantillaParaUI();
            }
        }

        console.log('[API] Caso inesperado en leerCalendario; devolviendo plantilla UI');
        return calendarioPlantillaParaUI();
    } catch (error) {
        console.error('[API] Error leyendo calendario desde MySQL:', error);
        return calendarioPlantillaParaUI();
    } finally {
        if (conexion) {
            await conexion.end();
        }
    }
}

// Guardar calendario en MySQL
async function guardarCalendario(datos, actualizadoPor = 'web') {
    let conexion = null;
    try {
        conexion = await obtenerConexion();
        
        // Si no se pudo conectar, retornar false
        if (!conexion) {
            console.error('[API] ⚠️ No se pudo conectar a MySQL para guardar');
            return false;
        }
        
        // Tabla de historial para auditoría / recuperación rápida
        try {
            await conexion.execute(
                `CREATE TABLE IF NOT EXISTS calendario_historial (
                    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                    calendario_id INT NOT NULL,
                    datos LONGTEXT NOT NULL,
                    ultima_actualizacion INT UNSIGNED NOT NULL DEFAULT 0,
                    actualizado_por VARCHAR(64) DEFAULT NULL,
                    snapshot_ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    motivo VARCHAR(64) DEFAULT NULL,
                    PRIMARY KEY (id),
                    KEY idx_calendario_id (calendario_id),
                    KEY idx_snapshot_ts (snapshot_ts)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`
            );
        } catch (historyTableError) {
            console.warn('[API] No se pudo asegurar tabla calendario_historial:', historyTableError.message);
        }

        try {
            const [prevRows] = await conexion.execute(
                'SELECT id, datos, ultima_actualizacion, actualizado_por FROM calendario WHERE id = 1 LIMIT 1'
            );
            if (prevRows && prevRows.length > 0) {
                const prev = prevRows[0];
                await conexion.execute(
                    'INSERT INTO calendario_historial (calendario_id, datos, ultima_actualizacion, actualizado_por, motivo) VALUES (?, ?, ?, ?, ?)',
                    [1, String(prev.datos || ''), Number(prev.ultima_actualizacion) || 0, prev.actualizado_por || 'unknown', 'before_overwrite']
                );
            }
        } catch (historyPrevError) {
            console.warn('[API] No se pudo guardar snapshot previo:', historyPrevError.message);
        }

        // Actualizar timestamp
        datos.ultimaActualizacion = Math.floor(Date.now() / 1000);
        const datosJSON = JSON.stringify(datos);
        
        // Insertar o actualizar (usando INSERT ... ON DUPLICATE KEY UPDATE)
        await conexion.execute(
            `INSERT INTO calendario (id, datos, ultima_actualizacion, actualizado_por) 
             VALUES (1, ?, ?, ?)
             ON DUPLICATE KEY UPDATE 
             datos = VALUES(datos), 
             ultima_actualizacion = VALUES(ultima_actualizacion),
             actualizado_por = VALUES(actualizado_por)`,
            [datosJSON, datos.ultimaActualizacion, actualizadoPor]
        );

        try {
            await conexion.execute(
                'INSERT INTO calendario_historial (calendario_id, datos, ultima_actualizacion, actualizado_por, motivo) VALUES (?, ?, ?, ?, ?)',
                [1, datosJSON, datos.ultimaActualizacion, actualizadoPor, 'after_write']
            );
        } catch (historyPostError) {
            console.warn('[API] No se pudo guardar snapshot posterior:', historyPostError.message);
        }
        
        console.log('[API] Calendario guardado en MySQL correctamente');
        console.log('[API] Timestamp:', datos.ultimaActualizacion);
        console.log('[API] Actualizado por:', actualizadoPor);
        return true;
    } catch (error) {
        console.error('[API] Error guardando calendario en MySQL:', error);
        return false;
    } finally {
        if (conexion) {
            await conexion.end();
        }
    }
}

module.exports = async function handler(req, res) {
    // Envolver TODO en try-catch para evitar cualquier error 500
    try {
        // Configurar CORS
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-CatCal-Sync-Token');

        if (req.method === 'OPTIONS') {
            return res.status(200).end();
        }

        if (req.method === 'GET') {
            // Obtener calendario (público)
            try {
                const calendario = await leerCalendario();
                
                // Asegurar que siempre retornamos un objeto válido
                if (!calendario) {
                    console.warn('[API] ⚠️ leerCalendario retornó null/undefined, usando plantilla UI');
                    return res.status(200).json({
                        success: true,
                        calendario: calendarioPlantillaParaUI()
                    });
                }
                
                return res.status(200).json({
                    success: true,
                    calendario: calendario,
                    ultimaActualizacion: Math.floor(Number(calendario && calendario.ultimaActualizacion)) || 0
                });
            } catch (error) {
                console.error('[API] Error en GET:', error);
                console.error('[API] Stack:', error.stack);
                // Retornar plantilla UI si el GET falla
                return res.status(200).json({
                    success: true,
                    calendario: calendarioPlantillaParaUI()
                });
            }
        }

        if (req.method === 'POST') {
        // Guardar calendario
        const authHeader = req.headers.authorization;
        const syncSecret = (process.env.CAT_CAL_SYNC_SECRET || process.env.CAT_CAL_SYNC || '').trim();
        const syncHeaderRaw = req.headers['x-catcal-sync-token'];
        const syncHeader = typeof syncHeaderRaw === 'string' ? syncHeaderRaw.trim() : '';
        const syncOk = syncSecret !== '' && syncHeader !== '' && syncHeader === syncSecret;

        const { calendario } = req.body;
        
        if (!calendario) {
            return res.status(400).json({
                error: 'Datos del calendario no proporcionados'
            });
        }
        
        // ✅ VALIDAR que los datos no estén vacíos antes de guardar
        const datosValidos = (
            (calendario.semanas && Array.isArray(calendario.semanas) && calendario.semanas.length > 0) ||
            (calendario.semanas && typeof calendario.semanas === 'object' && Object.keys(calendario.semanas).length > 0) ||
            (calendario.separadores && typeof calendario.separadores === 'object' && Object.keys(calendario.separadores).length > 0) ||
            (calendario.climasHorario && typeof calendario.climasHorario === 'object' && Object.keys(calendario.climasHorario).length > 0) ||
            (calendario.meses && Array.isArray(calendario.meses) && calendario.meses.length > 0)
        );
        
        if (!datosValidos) {
            console.warn('[API] ⚠️ Intento de guardar calendario vacío - RECHAZADO');
            return res.status(400).json({
                error: 'No se pueden guardar datos vacíos del calendario'
            });
        }
        
        let actualizadoPor = 'FiveM';
        let decoded = null;
        
        if (syncOk) {
            actualizadoPor = 'gmod';
            console.log('[API] Guardando calendario desde GMod (X-CatCal-Sync-Token)');
        } else if (authHeader && authHeader.startsWith('Bearer ')) {
            decoded = verificarBearer(req);
            if (!decoded) {
                return res.status(401).json({
                    error: 'Token inválido'
                });
            }

            const permisos = normalizarPermisos(decoded);
            if (permisos.indexOf('editar') === -1) {
                return res.status(403).json({
                    error: 'No tienes permiso para editar el calendario'
                });
            }

            actualizadoPor = decoded.username || 'web';
            console.log('[API] Guardando calendario desde web (usuario:', actualizadoPor, 'rol:', decoded.rol || '?', ')');
        } else if (syncSecret !== '') {
            return res.status(401).json({
                error: 'No autorizado: usa Bearer (web) o header X-CatCal-Sync-Token (GMod) con CAT_CAL_SYNC_SECRET'
            });
        } else {
            // Endurecido: evitar escrituras anónimas sin secreto.
            return res.status(401).json({
                error: 'No autorizado: configura CAT_CAL_SYNC o CAT_CAL_SYNC_SECRET y usa X-CatCal-Sync-Token (GMod), o Bearer (web).'
            });
        }

            try {
                const guardado = await guardarCalendario(calendario, actualizadoPor);
                
                if (guardado) {
                    try {
                        const logConn = await obtenerConexionAux();

                        if (logConn) {
                            await asegurarTablas(logConn);
                            await registrarLog(logConn, {
                                username: actualizadoPor,
                                rol: syncOk ? 'gmod' : (decoded && decoded.rol ? decoded.rol : 'web'),
                                accion: 'guardar_calendario',
                                detalles: 'Calendario OOC/web actualizado (ts=' + calendario.ultimaActualizacion + ')'
                            });
                            await logConn.end();
                        }
                    } catch (logErr) {
                        console.warn('[API] No se pudo registrar log de calendario:', logErr.message);
                    }

                    return res.status(200).json({
                        success: true,
                        message: 'Calendario guardado correctamente',
                        ultimaActualizacion: calendario.ultimaActualizacion
                    });
                } else {
                    return res.status(500).json({
                        error: 'Error al guardar el calendario'
                    });
                }
            } catch (error) {
                console.error('[API] Error en POST:', error);
                return res.status(500).json({
                    error: 'Error al guardar el calendario'
                });
            }
        }

        return res.status(405).json({
            error: 'Method not allowed'
        });
    } catch (globalError) {
        // Capturar CUALQUIER error que pueda ocurrir en TODO el handler
        console.error('[API] ⚠️ ERROR GLOBAL en handler:', globalError);
        console.error('[API] ⚠️ Error message:', globalError.message);
        console.error('[API] ⚠️ Error stack:', globalError.stack);
        
        // SIEMPRE retornar 200 con plantilla UI, NUNCA 500
        return res.status(200).json({
            success: true,
            calendario: calendarioPlantillaParaUI()
        });
    }
}
