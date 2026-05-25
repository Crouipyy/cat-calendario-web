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
// guardarlo en calendario_logs. El cliente envía SIEMPRE el calendario
// completo aunque el usuario sólo haya tocado una cosa, así que aquí
// hacemos un diff fino y reportamos únicamente las cosas que cambiaron
// de verdad (insensible al orden de propiedades dentro de los objetos).
// ---------------------------------------------------------------------------

function igualValor(a, b) {
    if (a === b) return true;
    if (a == null || b == null) return a === b;
    const ta = typeof a;
    if (ta !== typeof b) return false;
    if (ta !== 'object') return a === b;

    const aIsArr = Array.isArray(a), bIsArr = Array.isArray(b);
    if (aIsArr !== bIsArr) return false;
    if (aIsArr) {
        if (a.length !== b.length) return false;
        for (let i = 0; i < a.length; i++) {
            if (!igualValor(a[i], b[i])) return false;
        }
        return true;
    }
    const keysA = Object.keys(a);
    const keysB = Object.keys(b);
    if (keysA.length !== keysB.length) return false;
    for (const k of keysA) {
        if (!Object.prototype.hasOwnProperty.call(b, k)) return false;
        if (!igualValor(a[k], b[k])) return false;
    }
    return true;
}

function huellaClase(c) {
    if (!c || typeof c !== 'object') return '∅';
    const cursos = Array.isArray(c.cursos) ? c.cursos.slice().sort() : [];
    return JSON.stringify({
        t: String(c.titulo || '').trim(),
        d: String(c.descripcion || '').trim(),
        p: String(c.profesor || '').trim(),
        h: String(c.horaExacta || ''),
        cs: cursos
    });
}

function describirClase(c) {
    if (!c) return '(vacía)';
    const titulo = String(c.titulo || '').trim() || '(sin título)';
    const partes = [titulo];
    if (c.horaExacta) partes.push(c.horaExacta);
    if (Array.isArray(c.cursos) && c.cursos.length) {
        partes.push('cursos ' + c.cursos.join(', '));
    }
    return partes.join(' · ');
}

function describirEvento(e) {
    if (!e || typeof e !== 'object') return '(vacío)';
    const t = String(e.texto || '').trim();
    return t || '(evento sin texto)';
}

function arrayEnHora(v) {
    if (v == null) return [];
    return Array.isArray(v) ? v.filter(Boolean) : (v ? [v] : []);
}

// Diff de clases para una franja horaria. Devuelve frases legibles tipo
// "Añadida clase 'Pociones' (cursos 2º, 3º)" o "Modificada clase de S1 D2".
function diffClasesEnHora(prefijo, hora, A, B) {
    const out = [];
    const huellasA = A.map(huellaClase);
    const huellasB = B.map(huellaClase);
    const setA = new Set(huellasA);
    const setB = new Set(huellasB);
    const añadidas = B.filter((_, i) => !setA.has(huellasB[i]));
    const eliminadas = A.filter((_, i) => !setB.has(huellasA[i]));

    // Si en la misma franja se elimina N y se añade N, lo mostramos como
    // "Modificada" para que no parezca el doble de actividad.
    if (añadidas.length && añadidas.length === eliminadas.length) {
        for (let i = 0; i < añadidas.length; i++) {
            out.push(
                'Modificada clase en ' + prefijo + ' ' + hora + ': ' +
                describirClase(eliminadas[i]) + ' → ' + describirClase(añadidas[i])
            );
        }
        return out;
    }

    for (const c of añadidas) {
        out.push('Añadida clase en ' + prefijo + ' ' + hora + ': ' + describirClase(c));
    }
    for (const c of eliminadas) {
        out.push('Eliminada clase en ' + prefijo + ' ' + hora + ': ' + describirClase(c));
    }
    return out;
}

// Igual, para eventos por franja.
function diffEventosEnHora(prefijo, hora, A, B) {
    const out = [];
    const huellasA = A.map(e => JSON.stringify(e || {}));
    const huellasB = B.map(e => JSON.stringify(e || {}));
    const setA = new Set(huellasA);
    const setB = new Set(huellasB);
    const añadidos = B.filter((_, i) => !setA.has(huellasB[i]));
    const eliminados = A.filter((_, i) => !setB.has(huellasA[i]));

    if (añadidos.length && añadidos.length === eliminados.length) {
        for (let i = 0; i < añadidos.length; i++) {
            out.push(
                'Modificado evento en ' + prefijo + ' ' + hora + ': ' +
                describirEvento(eliminados[i]) + ' → ' + describirEvento(añadidos[i])
            );
        }
        return out;
    }
    for (const e of añadidos) {
        out.push('Añadido evento en ' + prefijo + ' ' + hora + ': ' + describirEvento(e));
    }
    for (const e of eliminados) {
        out.push('Eliminado evento en ' + prefijo + ' ' + hora + ': ' + describirEvento(e));
    }
    return out;
}

function resumenDiff(actual, nuevo) {
    actual = actual || {};
    nuevo = nuevo || {};
    const cambios = [];

    // ---- Semanas: clases, eventos por franja y atributos del día ----
    const semA = Array.isArray(actual.semanas) ? actual.semanas : [];
    const semB = Array.isArray(nuevo.semanas) ? nuevo.semanas : [];
    const totalSem = Math.max(semA.length, semB.length);
    const DIAS_NOM = ['Sáb', 'Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie'];

    for (let s = 0; s < totalSem; s++) {
        const semanaA = semA[s] || {};
        const semanaB = semB[s] || {};
        const diasA = Array.isArray(semanaA.dias) ? semanaA.dias : [];
        const diasB = Array.isArray(semanaB.dias) ? semanaB.dias : [];
        const totalDias = Math.max(diasA.length, diasB.length);

        for (let d = 0; d < totalDias; d++) {
            const diaA = diasA[d] || {};
            const diaB = diasB[d] || {};
            const nomDia = (diaB.nombre || diaA.nombre || DIAS_NOM[d] || ('Día ' + (d + 1)));
            const prefijo = 'S' + (s + 1) + ' ' + nomDia;

            // Clima del día (evento/luna/temperatura/estación)
            const atribs = [
                ['evento', 'evento'],
                ['luna', 'luna'],
                ['temperatura', 'temperatura'],
                ['estacion', 'estación']
            ];
            for (const [k, label] of atribs) {
                if (!igualValor(diaA[k], diaB[k])) {
                    cambios.push(
                        'Cambiado ' + label + ' de ' + prefijo + ': ' +
                        JSON.stringify(diaA[k]) + ' → ' + JSON.stringify(diaB[k])
                    );
                }
            }

            // Clases por hora
            const clasesA = diaA.clases || {};
            const clasesB = diaB.clases || {};
            const horas = new Set([...Object.keys(clasesA), ...Object.keys(clasesB)]);
            for (const hora of horas) {
                const A = arrayEnHora(clasesA[hora]);
                const B = arrayEnHora(clasesB[hora]);
                if (!igualValor(A, B)) {
                    cambios.push.apply(cambios, diffClasesEnHora(prefijo, hora, A, B));
                }
            }

            // Eventos por hora
            const evA = diaA.eventosHorario || {};
            const evB = diaB.eventosHorario || {};
            const horasEv = new Set([...Object.keys(evA), ...Object.keys(evB)]);
            for (const hora of horasEv) {
                const A = arrayEnHora(evA[hora]);
                const B = arrayEnHora(evB[hora]);
                if (!igualValor(A, B)) {
                    cambios.push.apply(cambios, diffEventosEnHora(prefijo, hora, A, B));
                }
            }
        }
    }

    // ---- Clima por franja (climasHorario) ----
    const climaA = actual.climasHorario || {};
    const climaB = nuevo.climasHorario || {};
    const horasClima = new Set([...Object.keys(climaA), ...Object.keys(climaB)]);
    for (const hora of horasClima) {
        if (!igualValor(climaA[hora], climaB[hora])) {
            cambios.push('Cambiado clima de la franja ' + hora + ': ' + (climaA[hora] || '∅') + ' → ' + (climaB[hora] || '∅'));
        }
    }

    // ---- Separadores / franjas horarias ----
    const sepA = actual.separadores || {};
    const sepB = nuevo.separadores || {};
    const horasSep = new Set([...Object.keys(sepA), ...Object.keys(sepB)]);
    for (const hora of horasSep) {
        if (!igualValor(sepA[hora], sepB[hora])) {
            const sb = sepB[hora] || {};
            const texto = String(sb.texto || '').trim();
            cambios.push(
                'Editada franja ' + hora + (texto ? ' ("' + texto + '")' : '')
            );
        }
    }

    // ---- Meses por semana ----
    const mesA = actual.meses || [];
    const mesB = nuevo.meses || [];
    const totalMes = Math.max(
        Array.isArray(mesA) ? mesA.length : 0,
        Array.isArray(mesB) ? mesB.length : 0
    );
    for (let i = 0; i < totalMes; i++) {
        if (!igualValor(mesA[i], mesB[i])) {
            cambios.push('Cambiados meses de S' + (i + 1));
        }
    }

    // ---- Tablón / notas ----
    const seccionesTablon = [
        ['tablonIndice', 'tablón (índice)'],
        ['tablonHorario', 'tablón (horario)'],
        ['tablonNormas', 'tablón (normas)'],
        ['tablonNotas', 'tablón (notas)'],
        ['tablonSecciones', 'tablón (estructura)'],
        ['notas', 'boletín de notas']
    ];
    for (const [k, label] of seccionesTablon) {
        if (!igualValor(actual[k], nuevo[k])) {
            cambios.push('Editado ' + label);
        }
    }

    if (!cambios.length) return 'sin cambios visibles';
    // Limitar a un tamaño razonable para la columna `detalles` (TEXT).
    const MAX = 12;
    if (cambios.length <= MAX) return cambios.join('; ');
    return cambios.slice(0, MAX).join('; ') + ' …(+' + (cambios.length - MAX) + ' cambios más)';
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
