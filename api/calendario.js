// API para manejar el calendario usando MySQL como almacenamiento persistente
const mysql = require('mysql2/promise');

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
        const conexion = await mysql.createConnection({
            host: dbHost,
            user: dbUser,
            password: dbPassword,
            database: dbName,
            port: parseInt(dbPort) || 3306,
            ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
            connectTimeout: 10000 // Timeout de 10 segundos
        });
        return conexion;
    } catch (error) {
        console.error('[API] Error conectando a MySQL:', error);
        console.error('[API] Error details:', error.message);
        console.error('[API] Stack:', error.stack);
        // No lanzar el error, dejar que la función que llama lo maneje
        return null;
    }
}

// Leer calendario desde MySQL
async function leerCalendario() {
    let conexion = null;
    try {
        conexion = await obtenerConexion();
        
        // Si no se pudo conectar, retornar estructura vacía
        if (!conexion) {
            console.warn('[API] ⚠️ No se pudo conectar a MySQL, retornando estructura vacía');
            return {
                semanas: [],
                meses: [],
                separadores: {},
                climasHorario: {},
                ultimaActualizacion: Math.floor(Date.now() / 1000)
            };
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
            // Si hay error en la query, retornar estructura vacía
            return {
                semanas: [],
                meses: [],
                separadores: {},
                climasHorario: {},
                ultimaActualizacion: Math.floor(Date.now() / 1000)
            };
        }
        
        if (rows && rows.length > 0) {
            try {
                const datos = JSON.parse(rows[0].datos);
                console.log('[API] Calendario leído desde MySQL');
                console.log('[API] Timestamp:', rows[0].ultima_actualizacion);
                
                // ✅ VALIDAR que los datos no estén vacíos de forma segura
                let datosValidos = false;
                
                try {
                    if (datos && typeof datos === 'object') {
                        if (datos.semanas) {
                            if (Array.isArray(datos.semanas) && datos.semanas.length > 0) {
                                datosValidos = true;
                            } else if (typeof datos.semanas === 'object' && datos.semanas !== null) {
                                const keys = Object.keys(datos.semanas);
                                if (keys.length > 0) {
                                    // Verificar que al menos una semana tenga datos
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
                    // Si hay error en la validación, retornar los datos de todos modos
                    datosValidos = true;
                }
                
                // Siempre retornar los datos, validados o no
                return datos;
            } catch (parseError) {
                console.error('[API] Error parseando JSON desde MySQL:', parseError);
                console.error('[API] Datos raw:', rows[0].datos ? rows[0].datos.substring(0, 100) : 'null');
                // En lugar de lanzar error, retornar estructura vacía
                return {
                    semanas: [],
                    meses: [],
                    separadores: {},
                    climasHorario: {},
                    ultimaActualizacion: rows[0].ultima_actualizacion || Math.floor(Date.now() / 1000)
                };
            }
        }
        
        // Si no existe, retornar estructura vacía
        console.log('[API] No hay datos en MySQL, retornando estructura vacía');
        return {
            semanas: [],
            meses: [],
            separadores: {},
            climasHorario: {},
            ultimaActualizacion: Math.floor(Date.now() / 1000)
        };
    } catch (error) {
        console.error('[API] Error leyendo calendario desde MySQL:', error);
        // Retornar estructura vacía en caso de error
        return {
            semanas: [],
            meses: [],
            separadores: {},
            climasHorario: {},
            ultimaActualizacion: Math.floor(Date.now() / 1000)
        };
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
                    console.warn('[API] ⚠️ leerCalendario retornó null/undefined, usando estructura vacía');
                    return res.status(200).json({
                        success: true,
                        calendario: {
                            semanas: [],
                            meses: [],
                            separadores: {},
                            climasHorario: {},
                            ultimaActualizacion: Math.floor(Date.now() / 1000)
                        }
                    });
                }
                
                return res.status(200).json({
                    success: true,
                    calendario: calendario
                });
            } catch (error) {
                console.error('[API] Error en GET:', error);
                console.error('[API] Stack:', error.stack);
                // Retornar estructura vacía en lugar de error 500 para que la web no se rompa
                return res.status(200).json({
                    success: true,
                    calendario: {
                        semanas: [],
                        meses: [],
                        separadores: {},
                        climasHorario: {},
                        ultimaActualizacion: Math.floor(Date.now() / 1000)
                    }
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
        
        // SIEMPRE retornar 200 con estructura vacía, NUNCA 500
        return res.status(200).json({
            success: true,
            calendario: {
                semanas: [],
                meses: [],
                separadores: {},
                climasHorario: {},
                ultimaActualizacion: Math.floor(Date.now() / 1000)
            }
        });
    }
}
