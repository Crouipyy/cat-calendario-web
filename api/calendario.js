// NOTA: En Vercel, el sistema de archivos es de solo lectura
// Para escritura persistente, necesitarías una base de datos o almacenamiento externo
// Por ahora, usamos el archivo del repositorio para lectura
// y para escritura, el archivo se actualiza en el repositorio (requiere webhook o similar)

// Alternativa: Usar variables de entorno o base de datos
// Por simplicidad, aquí usamos el archivo del repo (solo lectura)

// Cache persistente en memoria (persiste entre requests en Vercel)
// NOTA: En Vercel, cada función serverless es stateless, pero podemos usar variables globales
// que persisten durante el tiempo de vida del proceso
let calendarioCache = null;
let ultimaLectura = 0;
const CACHE_DURATION = 5000; // 5 segundos

// Cache para cambios desde la web (persiste mientras la función esté activa)
let cambiosDesdeWeb = null;

function leerCalendario() {
    try {
        // PRIORIDAD 1: Si hay cambios desde la web O desde FiveM (cache en memoria), usar esos
        // El cache persiste mientras la función serverless esté activa
        if (cambiosDesdeWeb) {
            const ahora = Date.now();
            // El cache de cambios persiste por 5 minutos (300000ms) para dar tiempo a que FiveM sincronice
            if ((ahora - cambiosDesdeWeb.timestamp) < 300000) {
                console.log('[API] Retornando cambios desde cache (web o FiveM)');
                console.log('[API] Timestamp cache:', cambiosDesdeWeb.datos.ultimaActualizacion);
                return cambiosDesdeWeb.datos;
            } else {
                // Cache expirado, limpiar
                console.log('[API] Cache expirado, limpiando');
                cambiosDesdeWeb = null;
            }
        }
        
        // PRIORIDAD 2: Cache general (si existe y no expiró)
        const ahora = Date.now();
        if (calendarioCache && (ahora - ultimaLectura) < CACHE_DURATION) {
            console.log('[API] Retornando cache general');
            return calendarioCache;
        }
        
        // PRIORIDAD 3: Leer desde el archivo del repositorio (solo lectura)
        const fs = require('fs');
        const path = require('path');
        const dataPath = path.join(process.cwd(), 'calendario_data.json');
        
        if (fs.existsSync(dataPath)) {
            const contenido = fs.readFileSync(dataPath, 'utf8');
            const datosArchivo = JSON.parse(contenido);
            
            // Actualizar cache
            calendarioCache = datosArchivo;
            ultimaLectura = ahora;
            
            console.log('[API] Retornando datos desde archivo del repositorio');
            console.log('[API] Timestamp archivo:', datosArchivo.ultimaActualizacion);
            return datosArchivo;
        }
        
        // Si no existe, retornar estructura vacía
        const estructuraVacia = {
            semanas: [],
            meses: [],
            separadores: {},
            climasHorario: {},
            ultimaActualizacion: Math.floor(Date.now() / 1000)
        };
        calendarioCache = estructuraVacia;
        return estructuraVacia;
    } catch (error) {
        console.error('[API] Error leyendo calendario:', error);
        // Retornar cache si existe, sino estructura vacía
        return calendarioCache || {
            semanas: [],
            meses: [],
            separadores: {},
            climasHorario: {},
            ultimaActualizacion: Math.floor(Date.now() / 1000)
        };
    }
}

// IMPORTANTE: En Vercel, no puedes escribir archivos de forma persistente
// Usamos cache en memoria que persiste durante la ejecución de la función
// Para sincronización con FiveM, FiveM debe consultar esta API periódicamente
function guardarCalendario(datos) {
    try {
        // Actualizar cache en memoria con timestamp
        datos.ultimaActualizacion = Math.floor(Date.now() / 1000);
        
        // Guardar en cache de cambios (prioridad alta) - funciona tanto para web como FiveM
        cambiosDesdeWeb = {
            datos: datos,
            timestamp: Date.now()
        };
        
        // También actualizar cache general
        calendarioCache = datos;
        ultimaLectura = Date.now();
        
        // NOTA: Este cache persiste durante la ejecución de la función serverless
        // Para sincronización bidireccional:
        // 1. Cuando se guarda desde FiveM: se envía POST a esta API, actualiza el cache
        // 2. Cuando se guarda desde web: se actualiza el cache directamente
        // 3. FiveM consulta /api/calendario periódicamente y compara timestamps
        // 4. Si el cache es más reciente, FiveM actualiza su archivo local
        
        console.log('[API] Calendario actualizado en cache');
        console.log('[API] Timestamp:', datos.ultimaActualizacion);
        console.log('[API] Cache persistirá por 5 minutos para sincronización');
        return true;
    } catch (error) {
        console.error('[API] Error guardando calendario:', error);
        return false;
    }
}

export default async function handler(req, res) {
    // Configurar CORS
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }

    if (req.method === 'GET') {
        // Obtener calendario (público)
        const calendario = leerCalendario();
        
        if (calendario) {
            return res.status(200).json({
                success: true,
                calendario: calendario
            });
        } else {
            return res.status(500).json({
                error: 'Error al leer el calendario'
            });
        }
    }

    if (req.method === 'POST') {
        // Guardar calendario
        // NOTA: Si viene desde FiveM, no requiere autenticación (confianza interna)
        // Si viene desde la web, requiere autenticación
        const authHeader = req.headers.authorization;
        const { calendario } = req.body;
        
        if (!calendario) {
            return res.status(400).json({
                error: 'Datos del calendario no proporcionados'
            });
        }
        
        // Si hay token, verificar (viene desde web)
        if (authHeader && authHeader.startsWith('Bearer ')) {
            try {
                const jwt = require('jsonwebtoken');
                const JWT_SECRET = process.env.JWT_SECRET || 'tu_secreto_super_seguro_cambiar_en_produccion';
                const token = authHeader.replace('Bearer ', '');
                const decoded = jwt.verify(token, JWT_SECRET);
                
                console.log('[API] Guardando calendario desde web (usuario autenticado)');
            } catch (error) {
                return res.status(401).json({
                    error: 'Token inválido'
                });
            }
        } else {
            // Sin token = viene desde FiveM (confianza interna)
            console.log('[API] Guardando calendario desde FiveM (sin autenticación)');
        }

        const guardado = guardarCalendario(calendario);
        
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
    }

    return res.status(405).json({
        error: 'Method not allowed'
    });
}

