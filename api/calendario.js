// API para manejar el calendario usando MySQL como almacenamiento persistente
const mysql = require('mysql2/promise');
const { calendarioPlantillaParaUI } = require('./calendarioPlantilla');

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
            console.error('[API]    GRANT SELECT,INSERT,UPDATE,DELETE ON gmodserverdb.* TO \'fivemuser\'@\'%\';');
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
            const plantilla = calendarioPlantillaParaUI();
            const json = JSON.stringify(plantilla);
            await conexion.execute(
                'UPDATE calendario SET datos = ?, ultima_actualizacion = ?, actualizado_por = ? WHERE id = 1',
                [json, plantilla.ultimaActualizacion, 'api-seed-vacio']
            );
            console.log('[API] Columna datos vacía o {}: rellenada con plantilla inicial.');
            return plantilla;
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
                    const plantilla = calendarioPlantillaParaUI();
                    const json = JSON.stringify(plantilla);
                    await conexion.execute(
                        'UPDATE calendario SET datos = ?, ultima_actualizacion = ?, actualizado_por = ? WHERE id = 1',
                        [json, plantilla.ultimaActualizacion, 'api-seed-invalido']
                    );
                    console.log('[API] JSON en MySQL sin semanas útiles: sustituido por plantilla inicial.');
                    return plantilla;
                }

                return datos;
            } catch (parseError) {
                console.error('[API] Error parseando JSON desde MySQL:', parseError);
                console.error('[API] Datos raw:', rows[0].datos ? String(rows[0].datos).substring(0, 100) : 'null');
                const plantilla = calendarioPlantillaParaUI();
                const json = JSON.stringify(plantilla);
                try {
                    await conexion.execute(
                        'UPDATE calendario SET datos = ?, ultima_actualizacion = ?, actualizado_por = ? WHERE id = 1',
                        [json, plantilla.ultimaActualizacion, 'api-seed-parse']
                    );
                    console.log('[API] JSON corrupto: columna datos sustituida por plantilla.');
                } catch (e) {
                    console.error('[API] No se pudo escribir plantilla tras parse error:', e.message);
                }
                return plantilla;
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
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

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
                    calendario: calendario
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
        
        // Si hay token, verificar (viene desde web)
        if (authHeader && authHeader.startsWith('Bearer ')) {
            try {
                const jwt = require('jsonwebtoken');
                const JWT_SECRET = process.env.JWT_SECRET || 'tu_secreto_super_seguro_cambiar_en_produccion';
                const token = authHeader.replace('Bearer ', '');
                const decoded = jwt.verify(token, JWT_SECRET);
                
                actualizadoPor = decoded.username || 'web';
                console.log('[API] Guardando calendario desde web (usuario:', actualizadoPor, ')');
            } catch (error) {
                return res.status(401).json({
                    error: 'Token inválido'
                });
            }
        } else {
            // Sin token = viene desde FiveM (confianza interna)
            console.log('[API] Guardando calendario desde FiveM');
        }

            try {
                const guardado = await guardarCalendario(calendario, actualizadoPor);
                
                if (guardado) {
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
