// API para manejar el calendario usando MySQL como almacenamiento persistente.
//
// Cambios respecto a la versión histórica:
// 1) En POST autenticados con Bearer (web) ahora se mira el ROL del JWT:
//    - admin     -> guarda exactamente lo que mande la web.
//    - profesor  -> sólo se aceptan cambios en clases / eventosHorario por
//                   día y en el panel de notas (notas, tablonSecciones).
//                   Todo lo demás (clima, separadores, meses, estructura de
//                   semanas...) se restaura desde la fila actual de MySQL.
// 2) Cada POST exitoso registra una entrada en calendario_logs con un
//    resumen de qué cambió.

const mysql = require('mysql2/promise');
const { calendarioPlantillaParaUI } = require('./calendarioPlantilla');
const { asegurarTablas, registrarLog } = require('../lib/db');
const { verificarBearer } = require('../lib/auth');

// ---------------------------------------------------------------------------
// Conexión MySQL (se mantiene local con logging detallado para no perder los
// mensajes de diagnóstico que ya estaban en la versión anterior).
// ---------------------------------------------------------------------------
async function obtenerConexion() {
    const dbHost = process.env.DB_HOST;
    const dbUser = process.env.DB_USER;
    const dbPassword = process.env.DB_PASSWORD;
    const dbName = process.env.DB_NAME || 'cat_calendario';
    const dbPort = process.env.DB_PORT || 3306;

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
        const conexion = await mysql.createConnection({
            host: dbHost,
            user: dbUser,
            password: dbPassword,
            database: dbName,
            port: parseInt(dbPort) || 3306,
            ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
            connectTimeout: 10000
        });
        console.log('[API] ✓ Conexión a MySQL establecida correctamente');
        return conexion;
    } catch (error) {
        console.error('[API] ✗ Error conectando a MySQL:', error.message);
        console.error('[API] Error code:', error.code);
        console.error('[API] Error errno:', error.errno);
        return null;
    }
}

// ---------------------------------------------------------------------------
// Lectura/escritura del calendario (sin cambios de comportamiento).
// ---------------------------------------------------------------------------
async function leerCalendarioConexion(conexion) {
    let rows = [];
    try {
        [rows] = await conexion.execute(
            'SELECT datos, ultima_actualizacion FROM calendario WHERE id = 1 LIMIT 1'
        );
    } catch (executeError) {
        console.error('[API] Error ejecutando query:', executeError);
        return calendarioPlantillaParaUI();
    }

    if (!rows || rows.length === 0) {
        const plantilla = calendarioPlantillaParaUI();
        const json = JSON.stringify(plantilla);
        await conexion.execute(
            'INSERT INTO calendario (id, datos, ultima_actualizacion, actualizado_por) VALUES (1, ?, ?, ?)',
            [json, plantilla.ultimaActualizacion, 'api-seed']
        );
        console.log('[API] No existía fila id=1: insertada plantilla inicial.');
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
        return plantilla;
    }

    try {
        const datos = JSON.parse(trimmed);
        const tsCol = rows[0].ultima_actualizacion;
        const tsJson = Math.floor(Number(datos.ultimaActualizacion)) || 0;
        let tsMerged = tsJson;
        if (tsCol != null && tsCol !== '') {
            const tc = Math.floor(Number(tsCol));
            if (!Number.isNaN(tc) && tc > 0) tsMerged = Math.max(tc, tsJson);
        }
        datos.ultimaActualizacion = tsMerged;
        return datos;
    } catch (parseError) {
        console.error('[API] JSON inválido en MySQL, devolvemos plantilla:', parseError.message);
        const plantilla = calendarioPlantillaParaUI();
        return plantilla;
    }
}

async function leerCalendario() {
    let conexion = null;
    try {
        conexion = await obtenerConexion();
        if (!conexion) return calendarioPlantillaParaUI();
        return await leerCalendarioConexion(conexion);
    } catch (error) {
        console.error('[API] Error leyendo calendario:', error);
        return calendarioPlantillaParaUI();
    } finally {
        if (conexion) {
            try { await conexion.end(); } catch (_) {}
        }
    }
}

async function guardarCalendarioConexion(conexion, datos, actualizadoPor) {
    datos.ultimaActualizacion = Math.floor(Date.now() / 1000);
    const datosJSON = JSON.stringify(datos);
    await conexion.execute(
        `INSERT INTO calendario (id, datos, ultima_actualizacion, actualizado_por)
         VALUES (1, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
             datos = VALUES(datos),
             ultima_actualizacion = VALUES(ultima_actualizacion),
             actualizado_por = VALUES(actualizado_por)`,
        [datosJSON, datos.ultimaActualizacion, actualizadoPor]
    );
    console.log('[API] Calendario guardado por', actualizadoPor, '@', datos.ultimaActualizacion);
}

// ---------------------------------------------------------------------------
// Restricciones para rol "profesor": fusionamos lo que envía el cliente con
// lo que ya está en BD, dejando que sólo "ganen" los campos permitidos.
// ---------------------------------------------------------------------------
function aplicarRestriccionesProfesor(actual, entrante) {
    // Empezamos a partir de una copia profunda de lo actual y vamos
    // sobreescribiendo sólo los campos que un profesor puede tocar.
    const base = JSON.parse(JSON.stringify(actual || {}));

    // Notas / tablón: campos abiertos a profesores.
    if (entrante && Object.prototype.hasOwnProperty.call(entrante, 'notas')) {
        base.notas = entrante.notas;
    }
    if (entrante && Object.prototype.hasOwnProperty.call(entrante, 'tablonSecciones')) {
        base.tablonSecciones = entrante.tablonSecciones;
    }
    if (entrante && Object.prototype.hasOwnProperty.call(entrante, 'tablonNotas')) {
        base.tablonNotas = entrante.tablonNotas;
    }
    if (entrante && Object.prototype.hasOwnProperty.call(entrante, 'tablonNormas')) {
        base.tablonNormas = entrante.tablonNormas;
    }
    if (entrante && Object.prototype.hasOwnProperty.call(entrante, 'tablonHorario')) {
        base.tablonHorario = entrante.tablonHorario;
    }
    if (entrante && Object.prototype.hasOwnProperty.call(entrante, 'tablonIndice')) {
        base.tablonIndice = entrante.tablonIndice;
    }

    // Semanas: sólo se permiten cambios en `clases` y `eventosHorario` de
    // cada día. El resto de campos por día (luna, temperatura, estación,
    // evento, nombre…) y la lista de semanas en sí permanecen como están.
    if (Array.isArray(entrante && entrante.semanas) && Array.isArray(base.semanas)) {
        const total = Math.min(entrante.semanas.length, base.semanas.length);
        for (let i = 0; i < total; i++) {
            const semIn = entrante.semanas[i];
            const semBase = base.semanas[i];
            if (!semIn || !semBase || !Array.isArray(semIn.dias) || !Array.isArray(semBase.dias)) continue;

            const totalDias = Math.min(semIn.dias.length, semBase.dias.length);
            for (let d = 0; d < totalDias; d++) {
                const diaIn = semIn.dias[d];
                const diaBase = semBase.dias[d];
                if (!diaIn || !diaBase) continue;

                if (diaIn.clases && typeof diaIn.clases === 'object') {
                    diaBase.clases = diaBase.clases || {};
                    for (const hora of Object.keys(diaIn.clases)) {
                        // Sólo aceptamos horas que ya existen en el calendario
                        // actual para que un profesor no pueda crear "franjas
                        // horarias" nuevas (eso lo bloquea el admin).
                        if (Object.prototype.hasOwnProperty.call(diaBase.clases, hora)) {
                            diaBase.clases[hora] = diaIn.clases[hora];
                        }
                    }
                }

                if (diaIn.eventosHorario && typeof diaIn.eventosHorario === 'object') {
                    diaBase.eventosHorario = diaBase.eventosHorario || {};
                    for (const hora of Object.keys(diaIn.eventosHorario)) {
                        if (Object.prototype.hasOwnProperty.call(diaBase.eventosHorario, hora)) {
                            diaBase.eventosHorario[hora] = diaIn.eventosHorario[hora];
                        }
                    }
                }
            }
        }
    }

    return base;
}

// ---------------------------------------------------------------------------
// Resumen "humano" del diff entre el calendario antiguo y el nuevo, para
// guardarlo en calendario_logs.
// ---------------------------------------------------------------------------
function resumenDiff(actual, nuevo) {
    const cambios = [];
    actual = actual || {};
    nuevo = nuevo || {};

    const cmp = (a, b) => JSON.stringify(a) !== JSON.stringify(b);

    if (cmp(actual.climasHorario, nuevo.climasHorario)) cambios.push('clima');
    if (cmp(actual.separadores, nuevo.separadores)) cambios.push('separadores/franjas');
    if (cmp(actual.meses, nuevo.meses)) cambios.push('meses');
    if (cmp(actual.notas, nuevo.notas)) cambios.push('notas');
    if (cmp(actual.tablonSecciones, nuevo.tablonSecciones)) cambios.push('tablón');

    if (Array.isArray(actual.semanas) && Array.isArray(nuevo.semanas)) {
        const total = Math.max(actual.semanas.length, nuevo.semanas.length);
        const semanasEditadas = [];
        for (let i = 0; i < total; i++) {
            if (cmp(actual.semanas[i], nuevo.semanas[i])) semanasEditadas.push(i + 1);
        }
        if (semanasEditadas.length) {
            cambios.push('semanas ' + semanasEditadas.join(','));
        }
    } else if (cmp(actual.semanas, nuevo.semanas)) {
        cambios.push('semanas');
    }

    return cambios.length ? cambios.join(', ') : 'sin cambios visibles';
}

// ---------------------------------------------------------------------------
// Handler principal
// ---------------------------------------------------------------------------
module.exports = async function handler(req, res) {
    try {
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-CatCal-Sync-Token');

        if (req.method === 'OPTIONS') {
            return res.status(200).end();
        }

        if (req.method === 'GET') {
            try {
                const calendario = await leerCalendario();
                if (!calendario) {
                    return res.status(200).json({
                        success: true,
                        calendario: calendarioPlantillaParaUI()
                    });
                }
                return res.status(200).json({
                    success: true,
                    calendario,
                    ultimaActualizacion: Math.floor(Number(calendario && calendario.ultimaActualizacion)) || 0
                });
            } catch (error) {
                console.error('[API] Error en GET:', error);
                return res.status(200).json({
                    success: true,
                    calendario: calendarioPlantillaParaUI()
                });
            }
        }

        if (req.method !== 'POST') {
            return res.status(405).json({ error: 'Method not allowed' });
        }

        // ---- POST: guardar calendario ----
        const authHeader = req.headers.authorization;
        const syncSecret = (process.env.CAT_CAL_SYNC_SECRET || '').trim();
        const syncHeaderRaw = req.headers['x-catcal-sync-token'];
        const syncHeader = typeof syncHeaderRaw === 'string' ? syncHeaderRaw.trim() : '';
        const syncOk = syncSecret !== '' && syncHeader !== '' && syncHeader === syncSecret;

        const { calendario } = req.body || {};
        if (!calendario) {
            return res.status(400).json({ error: 'Datos del calendario no proporcionados' });
        }

        const datosValidos = (
            (Array.isArray(calendario.semanas) && calendario.semanas.length > 0) ||
            (calendario.semanas && typeof calendario.semanas === 'object' && Object.keys(calendario.semanas).length > 0) ||
            (calendario.separadores && typeof calendario.separadores === 'object' && Object.keys(calendario.separadores).length > 0) ||
            (calendario.climasHorario && typeof calendario.climasHorario === 'object' && Object.keys(calendario.climasHorario).length > 0) ||
            (Array.isArray(calendario.meses) && calendario.meses.length > 0)
        );
        if (!datosValidos) {
            console.warn('[API] ⚠️ Intento de guardar calendario vacío - RECHAZADO');
            return res.status(400).json({ error: 'No se pueden guardar datos vacíos del calendario' });
        }

        // Determinar quién hace la petición y con qué autoridad.
        let actualizadoPor = 'FiveM';
        let usuarioWeb = null;       // payload del JWT si proviene de la web
        let modoSync = 'fivem';      // 'gmod' | 'web' | 'fivem'

        if (syncOk) {
            actualizadoPor = 'gmod';
            modoSync = 'gmod';
        } else if (authHeader && authHeader.startsWith('Bearer ')) {
            usuarioWeb = verificarBearer(req);
            if (!usuarioWeb) {
                return res.status(401).json({ error: 'Token inválido' });
            }
            actualizadoPor = usuarioWeb.username || 'web';
            modoSync = 'web';
        } else if (syncSecret !== '') {
            return res.status(401).json({
                error: 'No autorizado: usa Bearer (web) o X-CatCal-Sync-Token (GMod) con CAT_CAL_SYNC_SECRET'
            });
        }

        let conexion = null;
        try {
            conexion = await obtenerConexion();
            if (!conexion) {
                return res.status(500).json({ error: 'No se pudo conectar a la base de datos' });
            }
            await asegurarTablas(conexion);

            // Para la web (rol profesor) necesitamos lo que hay actualmente
            // para hacer el merge restrictivo.
            const calendarioActual = await leerCalendarioConexion(conexion);

            let calendarioFinal = calendario;
            let resumen = '';

            if (modoSync === 'web' && usuarioWeb && usuarioWeb.rol !== 'admin') {
                calendarioFinal = aplicarRestriccionesProfesor(calendarioActual, calendario);
                resumen = resumenDiff(calendarioActual, calendarioFinal);
                console.log('[API] POST web (profesor "' + actualizadoPor + '"): ' + resumen);
            } else {
                resumen = resumenDiff(calendarioActual, calendarioFinal);
                console.log('[API] POST ' + modoSync + ' ("' + actualizadoPor + '"): ' + resumen);
            }

            await guardarCalendarioConexion(conexion, calendarioFinal, actualizadoPor);

            // Auditoría: sólo registramos cambios web (admin/profesor).
            // Las syncs masivas de GMod no se registran para no llenar la tabla.
            if (modoSync === 'web' && usuarioWeb) {
                await registrarLog(conexion, {
                    username: usuarioWeb.username,
                    rol: usuarioWeb.rol || 'profesor',
                    accion: 'Editar calendario',
                    detalles: resumen
                });
            }

            return res.status(200).json({
                success: true,
                message: 'Calendario guardado correctamente',
                ultimaActualizacion: calendarioFinal.ultimaActualizacion
            });
        } catch (error) {
            console.error('[API] Error en POST:', error);
            return res.status(500).json({ error: 'Error al guardar el calendario' });
        } finally {
            if (conexion) {
                try { await conexion.end(); } catch (_) {}
            }
        }
    } catch (globalError) {
        console.error('[API] ⚠️ ERROR GLOBAL en handler:', globalError);
        return res.status(200).json({
            success: true,
            calendario: calendarioPlantillaParaUI()
        });
    }
};
