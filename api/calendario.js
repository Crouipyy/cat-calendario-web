// NOTA: En Vercel, el sistema de archivos es de solo lectura
// Para escritura persistente, necesitarías una base de datos o almacenamiento externo
// Por ahora, usamos el archivo del repositorio para lectura
// y para escritura, el archivo se actualiza en el repositorio (requiere webhook o similar)

// Alternativa: Usar variables de entorno o base de datos
// Por simplicidad, aquí usamos el archivo del repo (solo lectura)

let calendarioCache = null;
let ultimaLectura = 0;
const CACHE_DURATION = 5000; // 5 segundos

function leerCalendario() {
    try {
        // Intentar leer desde el archivo del repositorio
        const fs = require('fs');
        const path = require('path');
        const dataPath = path.join(process.cwd(), 'calendario_data.json');
        
        // Solo leer si el cache expiró
        const ahora = Date.now();
        if (calendarioCache && (ahora - ultimaLectura) < CACHE_DURATION) {
            return calendarioCache;
        }
        
        if (fs.existsSync(dataPath)) {
            const contenido = fs.readFileSync(dataPath, 'utf8');
            calendarioCache = JSON.parse(contenido);
            ultimaLectura = ahora;
            return calendarioCache;
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
        console.error('Error leyendo calendario:', error);
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
// Esta función actualiza el cache en memoria, pero no persiste
// Para persistencia real, necesitarías:
// 1. Base de datos (MongoDB, PostgreSQL, etc.)
// 2. Almacenamiento en la nube (AWS S3, etc.)
// 3. Webhook que actualice el repositorio de GitHub
function guardarCalendario(datos) {
    try {
        // Actualizar cache en memoria
        datos.ultimaActualizacion = Math.floor(Date.now() / 1000);
        calendarioCache = datos;
        ultimaLectura = Date.now();
        
        // NOTA: En producción, aquí deberías guardar en una base de datos
        // Por ahora, solo actualizamos el cache
        // El archivo real se actualiza desde FiveM o mediante webhook
        
        console.log('[API] Calendario actualizado en cache (no persistente)');
        return true;
    } catch (error) {
        console.error('Error guardando calendario:', error);
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
        // Guardar calendario (requiere autenticación)
        const authHeader = req.headers.authorization;
        
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                error: 'Token no proporcionado'
            });
        }

        const token = authHeader.replace('Bearer ', '');
        
        // Verificar token (simplificado - en producción usar jwt.verify)
        try {
            const jwt = require('jsonwebtoken');
            const JWT_SECRET = process.env.JWT_SECRET || 'tu_secreto_super_seguro_cambiar_en_produccion';
            const decoded = jwt.verify(token, JWT_SECRET);
            
            // Token válido, guardar calendario
            const { calendario } = req.body;
            
            if (!calendario) {
                return res.status(400).json({
                    error: 'Datos del calendario no proporcionados'
                });
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
        } catch (error) {
            return res.status(401).json({
                error: 'Token inválido'
            });
        }
    }

    return res.status(405).json({
        error: 'Method not allowed'
    });
}

