let calendarioData = {};
let esProfesor = false;
let puedePublicarTablon = false;
let esAdmin = false;
let config = {};
let semanaActual = 1;
let tooltipElement = null;
let contextMenu = null;
let claseParaEliminar = null;
let separadorParaEditar = null;
let separadorParaEliminar = null;

function jsArg(val) {
    return JSON.stringify(val == null ? '' : val);
}

/** Valor JS seguro dentro de atributos HTML con comillas dobles (onclick, oncontextmenu). */
function htmlJsArg(val) {
    return jsArg(val).replace(/"/g, '&quot;');
}

function escAttr(val) {
    return String(val == null ? '' : val)
        .replace(/&/g, '&amp;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;')
        .replace(/</g, '&lt;');
}

function actualizarControlesPublicacionNotas() {
    const pub = document.getElementById('tablon-notas-publicado');
    const pubLbl = pub && pub.closest ? pub.closest('.tablon-notas-meta-lbl') : null;
    if (pubLbl) {
        pubLbl.style.display = puedePublicarTablon ? '' : 'none';
    }
}

function actualizarBotonesAccionTablon() {
    const btnGuardar = document.getElementById('btnGuardar');
    const btnPublicar = document.getElementById('btnPublicarTablon');
    const btnBorrar = document.getElementById('btnBorrarHorario');

    if (MODO_WEB) {
        if (btnGuardar) {
            btnGuardar.style.display = (esProfesor && !puedePublicarTablon) ? 'block' : 'none';
            btnGuardar.textContent = '💾 Guardar Cambios';
        }
        if (btnPublicar) {
            btnPublicar.style.display = puedePublicarTablon ? 'block' : 'none';
        }
        if (btnBorrar) {
            btnBorrar.style.display = 'none';
        }
    } else {
        if (btnGuardar) {
            btnGuardar.style.display = esProfesor ? 'block' : 'none';
            btnGuardar.textContent = puedePublicarTablon
                ? '💾 Guardar y publicar tablón'
                : '💾 Guardar Cambios';
        }
        if (btnPublicar) {
            btnPublicar.style.display = 'none';
        }
        if (btnBorrar) {
            btnBorrar.style.display = (!MODO_WEB && puedePublicarTablon) ? 'block' : 'none';
        }
    }

    actualizarControlesPublicacionNotas();
}

/** Pestañas del tablón (Índice, Horario, textos). Misma UI en GMod y web. */
const TABLON_TEXTO_PLANO_KEYS = ['optativas', 'clubes'];
const TABLON_TABS_ORDER = ['indice', 'horario', 'normas', 'optativas', 'clubes', 'notas'];
let pestanaTablonActual = 'indice';
/** Profesor: vista tablón por defecto; true = formulario de edición. */
let normasModoEdicion = false;
/** Profesor: boletín notas vista vs editor. */
let notasModoEdicion = false;
/** Contexto del personaje que abre el panel (GMod). */
let contextoVisor = {};
/** Recorte servidor para alumnos (sin filas ajenas). */
let notasVistaAlumno = null;

/** Horario canónico del servidor (España peninsular). Los datos se guardan con estas horas. */
const HORARIO_ZONA_ORIGEN = 'Europe/Madrid';

function obtenerFechaReferenciaMadrid() {
    const partes = new Intl.DateTimeFormat('en-US', {
        timeZone: HORARIO_ZONA_ORIGEN,
        year: 'numeric',
        month: 'numeric',
        day: 'numeric'
    }).formatToParts(new Date());

    const out = {};
    partes.forEach(function (p) {
        if (p.type !== 'literal') {
            out[p.type] = parseInt(p.value, 10);
        }
    });

    return { y: out.year, mo: out.month, d: out.day };
}

function getPartsInTimeZone(epochMs, timeZone) {
    const partes = new Intl.DateTimeFormat('en-US', {
        timeZone: timeZone,
        year: 'numeric',
        month: 'numeric',
        day: 'numeric',
        hour: 'numeric',
        minute: 'numeric',
        second: 'numeric',
        hour12: false
    }).formatToParts(new Date(epochMs));

    const out = {};
    partes.forEach(function (p) {
        if (p.type !== 'literal') {
            out[p.type] = parseInt(p.value, 10);
        }
    });

    return out;
}

function madridWallClockToUtc(y, mo, d, h, mi) {
    let utc = Date.UTC(y, mo - 1, d, h, mi);

    for (let i = 0; i < 8; i++) {
        const p = getPartsInTimeZone(utc, HORARIO_ZONA_ORIGEN);
        const want = Date.UTC(y, mo - 1, d, h, mi);
        const got = Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute);
        const diff = want - got;

        if (diff === 0) {
            break;
        }

        utc += diff;
    }

    return utc;
}

function formatearUtcEnZonaLocal(utcMs) {
    return new Intl.DateTimeFormat(undefined, {
        hour: '2-digit',
        minute: '2-digit',
        hour12: false
    }).format(new Date(utcMs));
}

function minutosMadridWallALocalHHMM(ref, totalMin, extraDayOffset) {
    let mins = totalMin;
    let dayOff = extraDayOffset || 0;

    while (mins < 0) {
        mins += 1440;
        dayOff -= 1;
    }

    while (mins >= 1440) {
        mins -= 1440;
        dayOff += 1;
    }

    const h = Math.floor(mins / 60);
    const mi = mins % 60;
    const utc = madridWallClockToUtc(ref.y, ref.mo, ref.d + dayOff, h, mi);

    return formatearUtcEnZonaLocal(utc);
}

function formatearRangoMinutosMadridALocal(iniMin, finMin, cruzaMedianoche) {
    const ref = obtenerFechaReferenciaMadrid();
    const inicio = minutosMadridWallALocalHHMM(ref, iniMin, 0);
    const fin = minutosMadridWallALocalHHMM(ref, finMin, cruzaMedianoche ? 1 : 0);

    return inicio + ' - ' + fin;
}

function debeMostrarHorarioEnZonaLocal() {
    try {
        const visor = Intl.DateTimeFormat().resolvedOptions().timeZone;

        return visor && visor !== HORARIO_ZONA_ORIGEN;
    } catch (e) {
        return false;
    }
}

function obtenerEtiquetaZonaHorariaVisor() {
    try {
        return Intl.DateTimeFormat().resolvedOptions().timeZone || '';
    } catch (e) {
        return '';
    }
}

function formatearFranjaHorariaVisor(franjaMadrid, horarioConfigOpt) {
    if (!franjaMadrid) {
        return '';
    }

    if (!debeMostrarHorarioEnZonaLocal()) {
        return franjaMadrid;
    }

    const cfg = horarioConfigOpt || (config.horarios && config.horarios.find(function (h) {
        return h.hora === franjaMadrid;
    }));

    let iniMin;
    let finMin;

    if (cfg && cfg.inicio != null && cfg.fin != null) {
        iniMin = convertirHoraDecimalAMinutos(cfg.inicio);
        finMin = convertirHoraDecimalAMinutos(cfg.fin);
    } else {
        const partes = extraerHorasDelHorario(franjaMadrid);
        iniMin = convertirHoraDecimalAMinutos(partes.inicio);
        finMin = convertirHoraDecimalAMinutos(partes.fin);
    }

    return formatearRangoMinutosMadridALocal(iniMin, finMin, finMin <= iniMin);
}

function convertirHoraMadridALocal(horaHHMM) {
    const norm = formatearHoraConMinutos(horaHHMM);

    if (!norm || !debeMostrarHorarioEnZonaLocal()) {
        return norm;
    }

    const partes = norm.split(':').map(Number);
    const ref = obtenerFechaReferenciaMadrid();
    const utc = madridWallClockToUtc(ref.y, ref.mo, ref.d, partes[0], partes[1] || 0);

    return formatearUtcEnZonaLocal(utc);
}

function formatearHoraParaVisor(horaString) {
    if (!horaString) {
        return '';
    }

    const base = horaString.split(':').slice(0, 2).join(':');

    return convertirHoraMadridALocal(base);
}

function arrayDesdeObjetoNormasApartados(arrOrObj) {
    if (arrOrObj == null) {
        return [];
    }
    if (Array.isArray(arrOrObj)) {
        return arrOrObj;
    }
    if (typeof arrOrObj === 'object') {
        return Object.keys(arrOrObj)
            .sort(function (a, b) {
                return Number(a) - Number(b);
            })
            .map(function (k) {
                return arrOrObj[k];
            })
            .filter(function (x) {
                return x != null;
            });
    }
    return [];
}

function asegurarNormasApartados(d) {
    const arr = arrayDesdeObjetoNormasApartados(d.normasApartados);
    const normalized = arr.map(function (x) {
        if (!x || typeof x !== 'object') {
            return { titulo: '', cuerpo: '' };
        }
        return {
            titulo: typeof x.titulo === 'string' ? x.titulo : '',
            cuerpo: typeof x.cuerpo === 'string' ? x.cuerpo : ''
        };
    });
    if (normalized.length === 0) {
        const leg = typeof d.normas === 'string' ? d.normas.trim() : '';
        if (leg) {
            d.normasApartados = [{ titulo: 'Normativa', cuerpo: leg }];
            return;
        }
    }
    d.normasApartados = normalized;
}

function obtenerDefNotas() {
    return (config && config.notas) || configPorDefecto.notas || {};
}

function deepMergeAsignaturasPorCurso(def, cur) {
    const out = {};
    let i;
    for (i = 1; i <= 7; i++) {
        const k = String(i);
        const base = def && def[k] && Array.isArray(def[k]) ? def[k].slice() : [];
        const ext = cur && cur[k] && Array.isArray(cur[k]) ? cur[k] : [];
        const seen = {};
        const merged = [];

        base.forEach(function (subject) {
            if (subject && !seen[subject]) {
                seen[subject] = true;
                merged.push(subject);
            }
        });

        out[k] = merged.length > 0 ? merged : base;
    }
    return out;
}

function normalizePromocion(value) {
    if (value == null) {
        return '';
    }
    const raw = String(value).trim();
    if (raw === '' || raw === '-' || raw === '—') {
        return '';
    }
    const lower = raw
        .toLowerCase()
        .replace(/í/g, 'i');
    if (lower === 'si' || lower === 's' || lower === 'yes') {
        return 'Si';
    }
    if (lower === 'no' || lower === 'n') {
        return 'No';
    }
    return '';
}

function asegurarNotasBoletin(d) {
    const def = obtenerDefNotas();
    const legacy = typeof d.notas === 'string' ? d.notas.trim() : '';

    if (!d.notasBoletin || typeof d.notasBoletin !== 'object') {
        d.notasBoletin = {
            publicado: false,
            tituloListado: def.tituloListadoDefault || 'LISTADO DE NOTAS',
            anioEscolarLabel: def.anioEscolarLabelDefault || '',
            leyenda: '',
            asignaturasPorCurso: deepMergeAsignaturasPorCurso(def.asignaturasPorCursoDefault, null),
            filas: []
        };
        if (legacy) {
            d.notasBoletin.legacyTextoPlano = legacy;
        }
        d.notas = '';
        return;
    }
    const nb = d.notasBoletin;
    nb.publicado = !!nb.publicado;
    if (typeof nb.tituloListado !== 'string') {
        nb.tituloListado = def.tituloListadoDefault || '';
    }
    if (typeof nb.anioEscolarLabel !== 'string') {
        nb.anioEscolarLabel = def.anioEscolarLabelDefault || '';
    }
    nb.leyenda = '';
    nb.asignaturasPorCurso = deepMergeAsignaturasPorCurso(
        def.asignaturasPorCursoDefault,
        nb.asignaturasPorCurso
    );
    if (!Array.isArray(nb.filas)) {
        nb.filas = [];
    }
    if (!nb.exclusiones || typeof nb.exclusiones !== 'object') {
        nb.exclusiones = {};
    }
    nb.filas.forEach(function (row) {
        if (!row || typeof row !== 'object') {
            return;
        }
        row.characterId = Number(row.characterId) || 0;
        row.nombreIc = typeof row.nombreIc === 'string' ? row.nombreIc : '';
        row.casa = typeof row.casa === 'string' ? row.casa : 'Otra';
        row.factionIndex = Number(row.factionIndex) || 0;
        row.anyo = Math.max(0, Math.min(7, Number(row.anyo) || 0));
        if (!row.notas || typeof row.notas !== 'object') {
            row.notas = {};
        }
        row.promocion = normalizePromocion(row.promocion);
    });
    if (typeof d.notas !== 'string') {
        d.notas = '';
    }
}

function notasFilasOrdenadasConIndice(filas) {
    const arr = [];
    if (!Array.isArray(filas)) {
        return arr;
    }
    filas.forEach(function (row, oi) {
        arr.push({ row: row, oi: oi });
    });
    arr.sort(function (a, b) {
        const ya = Number(a.row.anyo) || 0;
        const yb = Number(b.row.anyo) || 0;
        if (ya !== yb) {
            return yb - ya;
        }
        const ca = String(a.row.casa || '').localeCompare(String(b.row.casa || ''));
        if (ca !== 0) {
            return ca;
        }
        return String(a.row.nombreIc || '').localeCompare(String(b.row.nombreIc || ''));
    });
    return arr;
}

function notasColorCasa(casa) {
    const col = (obtenerDefNotas().coloresCasa && obtenerDefNotas().coloresCasa[casa]) || null;
    return col || (obtenerDefNotas().coloresCasa && obtenerDefNotas().coloresCasa.Otra) || '#5c4a3a';
}

function notasCasasEdicionLista() {
    const def = obtenerDefNotas();
    const base = ['Gryffindor', 'Hufflepuff', 'Ravenclaw', 'Slytherin'];
    const arr = def.casasBoletinOpciones;
    if (Array.isArray(arr) && arr.length) {
        const out = arr
            .map(function (x) {
                return String(x);
            })
            .filter(function (name) {
                return name && name !== 'Otra';
            });
        if (out.length) {
            return out;
        }
    }
    return base.slice();
}

function notasCalificacionesSelectLista(curso) {
    const def = obtenerDefNotas();
    const letterYears = def.cursosCalificacionLetras || [5, 7];
    const yearNum = Number(curso) || 0;

    if (letterYears.indexOf(yearNum) !== -1) {
        const arr = def.calificacionesBoletin;
        if (Array.isArray(arr) && arr.length) {
            return arr
                .map(function (x) {
                    return String(x).trim();
                })
                .filter(function (x) {
                    return x.length > 0;
                });
        }
        return ['E', 'S', 'A', 'I', 'D', 'T'];
    }

    const maxNum = Number(def.calificacionesNumericasMax) || 10;
    const out = [];
    let i;
    for (i = 0; i <= maxNum; i++) {
        out.push(String(i));
    }
    return out;
}

function notasCursoUsaLetras(anyo) {
    const def = obtenerDefNotas();
    const letterYears = def.cursosCalificacionLetras || [5, 7];
    return letterYears.indexOf(Number(anyo) || 0) !== -1;
}

/** Rango visual tipo hoja IC (E/S/A/I/D/T). '' = sin clase; 'vac' = guion; 'num' = 0–10; 'texto' = APTO etc. */
function notasRangoCalificacion(val, anyo) {
    if (val == null || val === '') {
        return '';
    }
    const s = String(val).trim();
    if (s === '-' || s === '—') {
        return 'vac';
    }
    const n = parseFloat(s.replace(',', '.'));
    if (!isNaN(n)) {
        if (!notasCursoUsaLetras(anyo) && n >= 0 && n <= 10 && /^-?\d+([.,]\d+)?$/.test(s)) {
            return 'num';
        }
        if (n >= 100) {
            return 'e';
        }
        if (n >= 75) {
            return 's';
        }
        if (n >= 50) {
            return 'a';
        }
        if (n >= 35) {
            return 'i';
        }
        if (n >= 25) {
            return 'd';
        }
        return 't';
    }
    const up = s.toUpperCase();
    const letterMap = {
        E: 'e',
        S: 's',
        A: 'a',
        I: 'i',
        D: 'd',
        T: 't',
        O: 'e',
        P: 'i',
        NP: 't',
        IN: 'd',
        NT: 'd'
    };
    if (letterMap[up]) {
        return letterMap[up];
    }
    return 'texto';
}

function notasAplicarClaseACelda(td, rawVal, anyo) {
    if (!td) {
        return;
    }
    td.className = (td.className || '')
        .replace(/\btablon-notas-val--\w+/g, '')
        .replace(/\s+/g, ' ')
        .trim();
    const r = notasRangoCalificacion(rawVal, anyo);
    const base = 'tablon-notas-celda-nota';
    if (r) {
        td.className = (base + ' tablon-notas-val--' + r).trim();
    } else {
        td.className = base;
    }
}

function notasAppendAnioEscolarBar(parent, labelText) {
    const bar = document.createElement('div');
    bar.className = 'tablon-notas-anio-bar';
    bar.textContent = labelText ? String(labelText) : '';
    parent.appendChild(bar);
}

/** Tablas de lectura por curso (7º → 1º): mismo criterio que vista profesor. */
function notasAppendTablasLecturaPorCurso(wrap, nb) {
    if (!wrap || !nb) {
        return;
    }
    let curso;
    for (curso = 7; curso >= 1; curso--) {
        const filasC = (nb.filas || []).filter(function (f) {
            return f && (Number(f.anyo) || 0) === curso;
        });
        if (filasC.length === 0) {
            continue;
        }
        filasC.sort(function (a, b) {
            const ca = String(a.casa || '').localeCompare(String(b.casa || ''));
            if (ca !== 0) {
                return ca;
            }
            return String(a.nombreIc || '').localeCompare(String(b.nombreIc || ''));
        });
        const cols =
            (nb.asignaturasPorCurso && nb.asignaturasPorCurso[String(curso)]) ||
            (nb.asignaturasPorCurso && nb.asignaturasPorCurso[curso]) ||
            [];
        const tw = document.createElement('div');
        tw.className = 'tablon-notas-tabla-wrap';
        const table = document.createElement('table');
        table.className = 'tablon-notas-tabla tablon-notas-tabla--hogwarts';
        const thead = document.createElement('thead');
        const trTot = document.createElement('tr');
        const thTot = document.createElement('th');
        thTot.colSpan = 4 + cols.length;
        thTot.className = 'tablon-notas-total-bar';
        thTot.textContent = 'TOTAL ALUMNOS ' + curso + 'º | ' + filasC.length;
        trTot.appendChild(thTot);
        thead.appendChild(trTot);
        const hr = document.createElement('tr');
        hr.className = 'tablon-notas-head-cols';
        ['Nombre', 'Casa', 'Curso', '¿PROMOCIONA?'].concat(cols).forEach(function (lab) {
            const th = document.createElement('th');
            th.textContent = lab;
            hr.appendChild(th);
        });
        thead.appendChild(hr);
        table.appendChild(thead);
        const tbody = document.createElement('tbody');
        filasC.forEach(function (f, idx) {
            const tr = document.createElement('tr');
            tr.className = idx % 2 === 0 ? 'tablon-notas-fila--a' : 'tablon-notas-fila--b';
            const promo = f.promocion != null && String(f.promocion).trim() !== '' ? String(f.promocion) : '—';
            [f.nombreIc || '', f.casa || '', f.anyo ? String(f.anyo) + 'º' : '—', promo].forEach(function (txt, j) {
                const td = document.createElement('td');
                td.textContent = txt;
                if (j === 1) {
                    td.className = 'tablon-notas-celda-casa';
                    td.style.color = '#fff';
                    td.style.background = notasColorCasa(f.casa);
                    td.style.fontWeight = '700';
                }
                tr.appendChild(td);
            });
            cols.forEach(function (col) {
                const td = document.createElement('td');
                const v =
                    f.notas && Object.prototype.hasOwnProperty.call(f.notas, col) ? f.notas[col] : '—';
                const disp = v === '' || v == null ? '—' : String(v);
                td.textContent = disp;
                notasAplicarClaseACelda(td, disp === '—' ? '' : disp, f.anyo);
                tr.appendChild(td);
            });
            tbody.appendChild(tr);
        });
        table.appendChild(tbody);
        tw.appendChild(table);
        wrap.appendChild(tw);
    }
}

function buildNotasVistaAlumnoDesdeBoletin(nb) {
    const def = obtenerDefNotas();

    if (!nb || typeof nb !== 'object') {
        return null;
    }

    if (!nb.publicado) {
        return {
            publicado: false,
            mensaje: def.msgNoPublicado || 'Las notas aún no están publicadas.'
        };
    }

    const filas = Array.isArray(nb.filas) ? nb.filas : [];

    return {
        publicado: true,
        tituloListado: nb.tituloListado || def.tituloListadoDefault || 'Notas',
        anioEscolarLabel: nb.anioEscolarLabel || '',
        leyenda: nb.leyenda || '',
        asignaturasPorCurso: deepMergeAsignaturasPorCurso(
            def.asignaturasPorCursoDefault,
            nb.asignaturasPorCurso || null
        ),
        filas: filas
    };
}

function syncNotasVistaAlumnoDesdeCalendario() {
    if (esProfesor) {
        return;
    }

    asegurarTablonSecciones();
    const nb = calendarioData.tablonSecciones.notasBoletin;
    const built = buildNotasVistaAlumnoDesdeBoletin(nb);

    if (built) {
        notasVistaAlumno = built;
    }
}

function renderVistaNotasAlumno() {
    const wrap = document.getElementById('tablon-notas-alumno');
    if (!wrap) {
        return;
    }
    wrap.innerHTML = '';
    const def = obtenerDefNotas();

    if (!notasVistaAlumno) {
        syncNotasVistaAlumnoDesdeCalendario();
    }

    const nv = notasVistaAlumno;

    if (nv && nv.publicado === false) {
        const p = document.createElement('div');
        p.className = 'tablon-notas-msg';
        p.textContent = nv.mensaje || def.msgNoPublicado || 'Las notas aún no están publicadas.';
        wrap.appendChild(p);
        return;
    }

    if (nv && nv.publicado === true) {
        const hero = document.createElement('header');
        hero.className = 'tablon-notas-hero';
        const t = document.createElement('h2');
        t.className = 'tablon-notas-hero-tit';
        t.textContent = nv.tituloListado || def.tituloListadoDefault || 'Notas';
        hero.appendChild(t);
        wrap.appendChild(hero);
        if (nv.anioEscolarLabel && String(nv.anioEscolarLabel).trim()) {
            notasAppendAnioEscolarBar(wrap, 'AÑO ESCOLAR ' + String(nv.anioEscolarLabel).trim());
        }
        const estado = document.createElement('p');
        estado.className = 'tablon-notas-estado';
        estado.textContent = 'Publicado · listado completo por curso';
        wrap.appendChild(estado);

        const filasNv = Array.isArray(nv.filas) ? nv.filas : [];
        if (filasNv.length > 0) {
            const nbView = {
                filas: filasNv,
                asignaturasPorCurso: deepMergeAsignaturasPorCurso(
                    def.asignaturasPorCursoDefault,
                    nv.asignaturasPorCurso || null
                )
            };
            notasAppendTablasLecturaPorCurso(wrap, nbView);
            return;
        }

        if (nv.fila) {
            const cols = Array.isArray(nv.columnas) ? nv.columnas : [];
            const f = nv.fila;
            const tw = document.createElement('div');
            tw.className = 'tablon-notas-tabla-wrap';
            const table = document.createElement('table');
            table.className = 'tablon-notas-tabla tablon-notas-tabla--hogwarts';
            const thead = document.createElement('thead');
            const hr = document.createElement('tr');
            hr.className = 'tablon-notas-head-cols';
            ['Nombre', 'Casa', 'Curso', '¿PROMOCIONA?'].concat(cols).forEach(function (lab) {
                const th = document.createElement('th');
                th.textContent = lab;
                hr.appendChild(th);
            });
            thead.appendChild(hr);
            table.appendChild(thead);
            const tbody = document.createElement('tbody');
            const tr = document.createElement('tr');
            tr.className = 'tablon-notas-fila--a';
            const casaColor = notasColorCasa(f.casa);
            const promo = f.promocion != null && String(f.promocion).trim() !== '' ? String(f.promocion) : '—';
            [f.nombreIc || '', f.casa || '', f.anyo ? String(f.anyo) + 'º' : '—', promo].forEach(function (txt) {
                const td = document.createElement('td');
                td.textContent = txt;
                if (txt === f.casa) {
                    td.className = 'tablon-notas-celda-casa';
                    td.style.color = '#fff';
                    td.style.background = casaColor;
                    td.style.fontWeight = '700';
                }
                tr.appendChild(td);
            });
            cols.forEach(function (col) {
                const td = document.createElement('td');
                const key = col;
                const v =
                    f.notas && Object.prototype.hasOwnProperty.call(f.notas, key)
                        ? f.notas[key]
                        : f.notas && f.notas[col] != null
                          ? f.notas[col]
                          : '—';
                const disp = v === '' || v == null ? '—' : String(v);
                td.textContent = disp;
                notasAplicarClaseACelda(td, disp === '—' ? '' : disp, f.anyo);
                tr.appendChild(td);
            });
            tbody.appendChild(tr);
            table.appendChild(tbody);
            tw.appendChild(table);
            wrap.appendChild(tw);
            return;
        }

        const p2 = document.createElement('div');
        p2.className = 'tablon-notas-msg';
        p2.textContent = def.msgBoletinPublicadoVacio || 'El boletín publicado está vacío.';
        wrap.appendChild(p2);
        return;
    }

    const p3 = document.createElement('div');
    p3.className = 'tablon-notas-msg';
    p3.textContent =
        'No se pudo cargar la vista de notas. Si estás en la web pública, solo el equipo ve el listado completo.';
    wrap.appendChild(p3);
}

function renderVistaNotasProfe(nb) {
    const wrap = document.getElementById('tablon-notas-vista-profe');
    if (!wrap) {
        return;
    }
    wrap.innerHTML = '';
    const def = obtenerDefNotas();
    const hero = document.createElement('header');
    hero.className = 'tablon-notas-hero';
    const t = document.createElement('h2');
    t.className = 'tablon-notas-hero-tit';
    t.textContent = nb.tituloListado || def.tituloListadoDefault || 'Notas';
    hero.appendChild(t);
    wrap.appendChild(hero);
    if (nb.anioEscolarLabel && String(nb.anioEscolarLabel).trim()) {
        notasAppendAnioEscolarBar(wrap, 'AÑO ESCOLAR ' + String(nb.anioEscolarLabel).trim());
    }
    const estado = document.createElement('p');
    estado.className = 'tablon-notas-estado';
    estado.textContent = nb.publicado
        ? 'Publicado (alumnos ven el listado completo por curso)'
        : 'Borrador · oculto para alumnos';
    wrap.appendChild(estado);

    notasAppendTablasLecturaPorCurso(wrap, nb);
}

function renderEditorNotasProfe(nb) {
    const root = document.getElementById('tablon-notas-cursos-edit');
    if (!root) {
        return;
    }
    root.innerHTML = '';
    const casasLista = notasCasasEdicionLista();
    const pub = document.getElementById('tablon-notas-publicado');
    if (pub) {
        pub.checked = !!nb.publicado;
    }
    const tit = document.getElementById('tablon-notas-titulo');
    if (tit) {
        tit.value = nb.tituloListado || '';
    }
    const an = document.getElementById('tablon-notas-anio');
    if (an) {
        an.value = nb.anioEscolarLabel || '';
    }

    let curso;
    for (curso = 7; curso >= 1; curso--) {
        const sec = document.createElement('section');
        sec.className = 'tablon-notas-curso-sec';
        const h3 = document.createElement('h3');
        h3.className = 'tablon-notas-curso-tit';
        h3.textContent = curso + 'º curso';
        sec.appendChild(h3);
        const cols =
            (nb.asignaturasPorCurso && nb.asignaturasPorCurso[String(curso)]) ||
            (nb.asignaturasPorCurso && nb.asignaturasPorCurso[curso]) ||
            [];
        let nEnCurso = 0;
        const ordenPrev = notasFilasOrdenadasConIndice(nb.filas);
        ordenPrev.forEach(function (item) {
            if ((Number(item.row.anyo) || 0) === curso) {
                nEnCurso++;
            }
        });
        const colsLine = document.createElement('div');
        colsLine.className = 'tablon-notas-meta-lbl';
        colsLine.textContent = 'Asignaturas (nombres separados por coma)';
        const colsIn = document.createElement('input');
        colsIn.type = 'text';
        colsIn.className = 'tablon-notas-meta-in';
        colsIn.setAttribute('data-notas-cols-curso', String(curso));
        colsIn.value = cols.join(', ');
        colsLine.appendChild(colsIn);
        sec.appendChild(colsLine);

        const tw = document.createElement('div');
        tw.className = 'tablon-notas-tabla-wrap';
        const table = document.createElement('table');
        table.className = 'tablon-notas-tabla tablon-notas-tabla--hogwarts';
        const thead = document.createElement('thead');
        const trTot = document.createElement('tr');
        const thTot = document.createElement('th');
        thTot.colSpan = 6 + cols.length;
        thTot.className = 'tablon-notas-total-bar';
        thTot.textContent = 'TOTAL ALUMNOS ' + curso + 'º | ' + nEnCurso;
        trTot.appendChild(thTot);
        thead.appendChild(trTot);
        const hr = document.createElement('tr');
        hr.className = 'tablon-notas-fila-head tablon-notas-head-cols';
        ['Nombre IC', 'Casa', 'Curso', '¿PROMOCIONA?', 'ID', 'Quitar'].concat(cols).forEach(function (lab) {
            const th = document.createElement('th');
            th.textContent = lab;
            hr.appendChild(th);
        });
        thead.appendChild(hr);
        table.appendChild(thead);
        const tbody = document.createElement('tbody');
        const orden = notasFilasOrdenadasConIndice(nb.filas);
        let ridx = 0;
        orden.forEach(function (item) {
            const f = item.row;
            if ((Number(f.anyo) || 0) !== curso) {
                return;
            }
            const tr = document.createElement('tr');
            tr.setAttribute('data-orig-idx', String(item.oi));
            tr.className = ridx % 2 === 0 ? 'tablon-notas-fila--a' : 'tablon-notas-fila--b';
            ridx++;
            const tdNom = document.createElement('td');
            const inNom = document.createElement('input');
            inNom.className = 'tablon-notas-meta-in tablon-notas-in-nombre';
            inNom.value = f.nombreIc || '';
            tdNom.appendChild(inNom);
            tr.appendChild(tdNom);
            const tdCasa = document.createElement('td');
            const inCasa = document.createElement('select');
            inCasa.className = 'tablon-notas-meta-in tablon-notas-in-casa';
            const curCasa = String(f.casa || '').trim();
            if (curCasa && casasLista.indexOf(curCasa) === -1) {
                const oLegacy = document.createElement('option');
                oLegacy.value = curCasa;
                oLegacy.textContent = curCasa + ' (legacy)';
                inCasa.appendChild(oLegacy);
            }
            casasLista.forEach(function (nombreCasa) {
                const opt = document.createElement('option');
                opt.value = nombreCasa;
                opt.textContent = nombreCasa;
                inCasa.appendChild(opt);
            });
            if (curCasa && casasLista.indexOf(curCasa) === -1) {
                inCasa.value = curCasa;
            } else {
                inCasa.value =
                    curCasa && casasLista.indexOf(curCasa) !== -1
                        ? curCasa
                        : casasLista[0] || 'Gryffindor';
            }
            tdCasa.appendChild(inCasa);
            tr.appendChild(tdCasa);
            const tdAnyo = document.createElement('td');
            const sel = document.createElement('select');
            sel.className = 'tablon-notas-in-anyo';
            let a;
            for (a = 0; a <= 7; a++) {
                const opt = document.createElement('option');
                opt.value = String(a);
                opt.textContent = a === 0 ? '—' : String(a) + 'º';
                if ((Number(f.anyo) || 0) === a) {
                    opt.selected = true;
                }
                sel.appendChild(opt);
            }
            tdAnyo.appendChild(sel);
            tr.appendChild(tdAnyo);
            const tdProm = document.createElement('td');
            const selProm = document.createElement('select');
            selProm.className = 'tablon-notas-meta-in tablon-notas-in-prom';
            const promoVal = normalizePromocion(f.promocion);
            ['', 'Si', 'No'].forEach(function (optVal) {
                const opt = document.createElement('option');
                opt.value = optVal;
                opt.textContent = optVal === '' ? '—' : optVal;
                if (promoVal === optVal) {
                    opt.selected = true;
                }
                selProm.appendChild(opt);
            });
            tdProm.appendChild(selProm);
            tr.appendChild(tdProm);
            const tdId = document.createElement('td');
            tdId.textContent = String(f.characterId || '');
            tdId.className = 'tablon-notas-celda-id';
            tr.appendChild(tdId);
            const tdDel = document.createElement('td');
            tdDel.className = 'tablon-notas-celda-quitar';
            const btnDel = document.createElement('button');
            btnDel.type = 'button';
            btnDel.className = 'tablon-notas-btn-quitar';
            btnDel.textContent = 'Quitar';
            btnDel.setAttribute('data-orig-idx', String(item.oi));
            btnDel.addEventListener('click', function () {
                notasEliminarFilaAlumno(item.oi);
            });
            tdDel.appendChild(btnDel);
            tr.appendChild(tdDel);
            cols.forEach(function (col) {
                const td = document.createElement('td');
                const sel = document.createElement('select');
                sel.className = 'tablon-notas-celda-in tablon-notas-celda-sel';
                sel.setAttribute('data-asig', col);
                const val =
                    f.notas && Object.prototype.hasOwnProperty.call(f.notas, col) ? f.notas[col] : '';
                const rawStr = val == null ? '' : String(val).trim();
                const vacio = rawStr === '' || rawStr === '-' || rawStr === '—';
                const dispVal = vacio ? '' : rawStr;
                const gradesLista = notasCalificacionesSelectLista(curso);
                const optVac = document.createElement('option');
                optVac.value = '';
                optVac.textContent = '—';
                sel.appendChild(optVac);
                gradesLista.forEach(function (g) {
                    const op = document.createElement('option');
                    op.value = g;
                    op.textContent = g;
                    sel.appendChild(op);
                });
                let found = false;
                if (!vacio) {
                    let gi;
                    for (gi = 0; gi < gradesLista.length; gi++) {
                        if (
                            gradesLista[gi] === dispVal ||
                            String(gradesLista[gi]).toUpperCase() === dispVal.toUpperCase()
                        ) {
                            sel.value = gradesLista[gi];
                            found = true;
                            break;
                        }
                    }
                    if (!found) {
                        const oL = document.createElement('option');
                        oL.value = dispVal;
                        oL.textContent = dispVal + ' (legacy)';
                        sel.appendChild(oL);
                        sel.value = dispVal;
                    }
                } else {
                    sel.value = '';
                }
                notasAplicarClaseACelda(td, vacio ? '' : dispVal, curso);
                td.appendChild(sel);
                tr.appendChild(td);
            });
            tbody.appendChild(tr);
        });
        table.appendChild(tbody);
        tw.appendChild(table);
        sec.appendChild(tw);
        root.appendChild(sec);
    }
}

function aplicarNotasAlDOM() {
    const panel = document.getElementById('panel-notas');
    const alumno = document.getElementById('tablon-notas-alumno');
    const vistaP = document.getElementById('tablon-notas-vista-profe');
    const editP = document.getElementById('tablon-notas-editor-profe');
    if (!panel || !alumno || !vistaP || !editP) {
        return;
    }
    asegurarTablonSecciones();
    const nb = calendarioData.tablonSecciones.notasBoletin;
    panel.classList.toggle('tablon-notas-es-profe', !!esProfesor);
    panel.classList.toggle('tablon-notas--editando', !!esProfesor && !!notasModoEdicion);

    if (!esProfesor) {
        alumno.style.display = 'block';
        vistaP.style.display = 'none';
        editP.style.display = 'none';
        renderVistaNotasAlumno();
        return;
    }

    alumno.style.display = 'none';
    if (notasModoEdicion) {
        vistaP.style.display = 'none';
        editP.style.display = 'flex';
        renderEditorNotasProfe(nb);
    } else {
        vistaP.style.display = 'block';
        editP.style.display = 'none';
        renderVistaNotasProfe(nb);
    }

    actualizarControlesPublicacionNotas();
}

function notasEliminarFilaAlumno(origIdx) {
    if (!esProfesor) {
        return;
    }
    leerNotasBoletinDelDOM();
    asegurarTablonSecciones();
    const nb = calendarioData.tablonSecciones.notasBoletin;
    const idx = parseInt(origIdx, 10);
    if (!nb || !Array.isArray(nb.filas) || isNaN(idx) || !nb.filas[idx]) {
        return;
    }
    const row = nb.filas[idx];
    const label =
        (row.nombreIc && String(row.nombreIc).trim()) ||
        (row.characterId ? 'ID ' + row.characterId : 'este alumno');
    if (!window.confirm('¿Quitar a "' + label + '" del boletín de notas?')) {
        return;
    }
    const cid = Number(row.characterId) || 0;
    if (cid > 0) {
        if (!nb.exclusiones) {
            nb.exclusiones = {};
        }
        nb.exclusiones[String(cid)] = true;
    }
    nb.filas.splice(idx, 1);
    aplicarNotasAlDOM();
}

function leerNotasBoletinDelDOM() {
    if (!esProfesor) {
        return;
    }
    const d = calendarioData.tablonSecciones;
    if (!d || !d.notasBoletin) {
        return;
    }
    const nb = d.notasBoletin;
    const pub = document.getElementById('tablon-notas-publicado');
    if (pub && puedePublicarTablon) {
        nb.publicado = !!pub.checked;
    }
    const tit = document.getElementById('tablon-notas-titulo');
    if (tit) {
        nb.tituloListado = tit.value;
    }
    const an = document.getElementById('tablon-notas-anio');
    if (an) {
        nb.anioEscolarLabel = an.value;
    }
    nb.leyenda = '';
    let c;
    for (c = 1; c <= 7; c++) {
        const inp = document.querySelector('input[data-notas-cols-curso="' + String(c) + '"]');
        if (inp && typeof inp.value === 'string') {
            const parts = inp.value.split(',');
            const cleaned = [];
            parts.forEach(function (p) {
                const t = p.replace(/^\s+|\s+$/g, '');
                if (t) {
                    cleaned.push(t);
                }
            });
            if (!nb.asignaturasPorCurso) {
                nb.asignaturasPorCurso = {};
            }
            nb.asignaturasPorCurso[String(c)] = cleaned;
        }
    }
    const root = document.getElementById('tablon-notas-cursos-edit');
    if (!root) {
        return;
    }
    root.querySelectorAll('tr[data-orig-idx]').forEach(function (tr) {
        const oi = parseInt(tr.getAttribute('data-orig-idx'), 10);
        if (isNaN(oi) || !nb.filas || !nb.filas[oi]) {
            return;
        }
        const row = nb.filas[oi];
        const ni = tr.querySelector('.tablon-notas-in-nombre');
        const ci = tr.querySelector('.tablon-notas-in-casa');
        const si = tr.querySelector('.tablon-notas-in-anyo');
        if (ni) {
            row.nombreIc = ni.value;
        }
        if (ci) {
            row.casa = ci.value;
        }
        if (si) {
            row.anyo = Math.max(0, Math.min(7, parseInt(si.value, 10) || 0));
        }
        const pi = tr.querySelector('.tablon-notas-in-prom');
        if (pi) {
            row.promocion = normalizePromocion(pi.value);
        }
        if (!row.notas) {
            row.notas = {};
        }
        tr.querySelectorAll('input[data-asig], select[data-asig]').forEach(function (inp) {
            const col = inp.getAttribute('data-asig');
            if (col) {
                row.notas[col] = inp.value;
            }
        });
    });
}

function inicializarEditorNotasBoletin() {
    if (window._catCalNotasEditorWired) {
        return;
    }
    window._catCalNotasEditorWired = true;
    const pan = document.getElementById('panel-notas');
    if (pan && !pan._catCalNotasInputColor) {
        pan._catCalNotasInputColor = true;
        function catCalActualizarColorCeldaNota(ev) {
            const t = ev.target;
            if (
                !t ||
                !t.classList ||
                !t.classList.contains('tablon-notas-celda-in') ||
                !t.parentNode ||
                t.parentNode.tagName !== 'TD'
            ) {
                return;
            }
            let anyo = 0;
            const tr = t.closest ? t.closest('tr') : null;
            if (tr) {
                const selAnyo = tr.querySelector('.tablon-notas-in-anyo');
                if (selAnyo) {
                    anyo = Number(selAnyo.value) || 0;
                }
            }
            notasAplicarClaseACelda(t.parentNode, t.value, anyo);
        }
        pan.addEventListener('input', catCalActualizarColorCeldaNota);
        pan.addEventListener('change', catCalActualizarColorCeldaNota);
    }
}

function inicializarModoNotasLecturaEditor() {
    if (window._catCalNotasModoWired) {
        return;
    }
    window._catCalNotasModoWired = true;
    const btnE = document.getElementById('tablon-notas-modo-editar');
    const btnV = document.getElementById('tablon-notas-modo-ver');
    if (btnE) {
        btnE.addEventListener('click', function () {
            if (!esProfesor) {
                return;
            }
            notasModoEdicion = true;
            aplicarNotasAlDOM();
        });
    }
    if (btnV) {
        btnV.addEventListener('click', function () {
            if (!esProfesor) {
                return;
            }
            leerNotasBoletinDelDOM();
            notasModoEdicion = false;
            aplicarNotasAlDOM();
        });
    }
}

function asegurarTablonSecciones() {
    if (!calendarioData.tablonSecciones || typeof calendarioData.tablonSecciones !== 'object') {
        calendarioData.tablonSecciones = {};
    }
    const d = calendarioData.tablonSecciones;
    TABLON_TEXTO_PLANO_KEYS.forEach(function (k) {
        if (typeof d[k] !== 'string') {
            d[k] = '';
        }
    });
    if (typeof d.notas !== 'string') {
        d.notas = '';
    }
    asegurarNormasApartados(d);
    asegurarNotasBoletin(d);
}

function renderVistaNormasApartados(ts) {
    const v = document.getElementById('tablon-view-normas');
    if (!v) {
        return;
    }
    v.innerHTML = '';
    const wrap = document.createElement('div');
    wrap.className = 'tablon-normas-lectura';
    const cab = document.createElement('div');
    cab.className = 'tablon-normas-lectura-cabecera';
    cab.textContent = 'NORMATIVAS DE LA ESCUELA DE MAGIA Y HECHICERÍA HOGWARTS';
    const cuerpo = document.createElement('div');
    cuerpo.className = 'tablon-normas-lectura-cuerpo';
    wrap.appendChild(cab);
    wrap.appendChild(cuerpo);
    v.appendChild(wrap);

    const arr = ts.normasApartados || [];
    if (arr.length === 0) {
        const p = document.createElement('p');
        p.className = 'tablon-normas-lectura-vacia';
        p.textContent = esProfesor
            ? 'Todavía no hay capítulos en el tablón. Entrá en «Editar capítulos» para añadir el primero y guardá los cambios.'
            : 'Aquí aparecerá la normativa cuando el equipo la publique en el calendario.';
        cuerpo.appendChild(p);
        return;
    }
    arr.forEach(function (bloque, idx) {
        const fila = document.createElement('div');
        fila.className =
            'tablon-normas-lectura-fila ' + (idx % 2 === 0 ? 'tablon-normas-lectura-fila--a' : 'tablon-normas-lectura-fila--b');
        const num = document.createElement('div');
        num.className = 'tablon-normas-lectura-num';
        num.textContent = String(idx + 1);
        const col = document.createElement('div');
        col.className = 'tablon-normas-lectura-col';
        const titulo = (bloque.titulo || '').trim() || 'Capítulo ' + (idx + 1);
        const lineaTit = document.createElement('div');
        lineaTit.className = 'tablon-normas-lectura-titulo';
        lineaTit.textContent = titulo;
        const cuerpoTxt = document.createElement('div');
        cuerpoTxt.className = 'tablon-normas-lectura-parrafos';
        cuerpoTxt.style.whiteSpace = 'pre-wrap';
        cuerpoTxt.textContent = bloque.cuerpo || '';
        col.appendChild(lineaTit);
        col.appendChild(cuerpoTxt);
        fila.appendChild(num);
        fila.appendChild(col);
        cuerpo.appendChild(fila);
    });
}

function crearDomBloqueEditNormas(bloque, idx, len) {
    const wrap = document.createElement('div');
    wrap.className = 'tablon-normas-bloque-edit';
    wrap.setAttribute('data-idx', String(idx));
    wrap.innerHTML =
        '<div class="tablon-normas-edit-toolbar">' +
        '<span class="tablon-normas-edit-num">Capítulo ' +
        (idx + 1) +
        '</span>' +
        '<div class="tablon-normas-edit-acciones">' +
        '<button type="button" class="tablon-normas-subir" title="Subir" aria-label="Subir">↑</button>' +
        '<button type="button" class="tablon-normas-bajar" title="Bajar" aria-label="Bajar">↓</button>' +
        '<button type="button" class="tablon-normas-quitar" title="Quitar apartado">Quitar</button>' +
        '</div></div>' +
        '<div class="tablon-normas-campo">' +
        '<label class="tablon-normas-label">Título</label>' +
        '<input type="text" class="tablon-normas-titulo-in" maxlength="160" placeholder="Ej.: Conducta en pasillos y aulas" />' +
        '</div>' +
        '<div class="tablon-normas-campo">' +
        '<label class="tablon-normas-label">Normas</label>' +
        '<textarea class="tablon-normas-cuerpo-in" rows="7" placeholder="Párrafos y listas; se respetan los saltos de línea al publicar…"></textarea>' +
        '</div>';
    wrap.querySelector('.tablon-normas-titulo-in').value = bloque.titulo || '';
    wrap.querySelector('.tablon-normas-cuerpo-in').value = bloque.cuerpo || '';
    const sub = wrap.querySelector('.tablon-normas-subir');
    const baj = wrap.querySelector('.tablon-normas-bajar');
    if (sub) {
        sub.disabled = idx <= 0;
    }
    if (baj) {
        baj.disabled = idx >= len - 1;
    }
    return wrap;
}

function renderEditorNormasApartados(ts) {
    const root = document.getElementById('tablon-normas-bloques-edit');
    if (!root) {
        return;
    }
    root.innerHTML = '';
    const arr = ts.normasApartados || [];
    const len = arr.length;
    arr.forEach(function (bloque, idx) {
        root.appendChild(crearDomBloqueEditNormas(bloque, idx, len));
    });
}

function aplicarNormasApartadosAlDOM() {
    const ts = calendarioData.tablonSecciones;
    const v = document.getElementById('tablon-view-normas');
    const editor = document.getElementById('tablon-edit-normas');
    const panel = document.getElementById('panel-normas');
    if (!v || !editor) {
        return;
    }
    if (panel) {
        panel.classList.toggle('tablon-normas-es-profe', !!esProfesor);
        panel.classList.toggle('tablon-normas--editando', !!esProfesor && !!normasModoEdicion);
    }
    renderVistaNormasApartados(ts);
    renderEditorNormasApartados(ts);
    const enEdicion = !!esProfesor && !!normasModoEdicion;
    if (enEdicion) {
        v.style.display = 'none';
        editor.style.display = 'flex';
    } else {
        v.style.display = 'flex';
        editor.style.display = 'none';
    }
}

function aplicarTablonSeccionesAlDOM() {
    asegurarTablonSecciones();
    const ts = calendarioData.tablonSecciones;
    TABLON_TEXTO_PLANO_KEYS.forEach(function (key) {
        const v = document.getElementById('tablon-view-' + key);
        const e = document.getElementById('tablon-edit-' + key);
        const txt = ts[key] || '';
        if (v) {
            v.textContent = txt;
        }
        if (e) {
            e.value = txt;
        }
        if (v && e) {
            if (esProfesor) {
                v.style.display = 'none';
                e.style.display = 'block';
            } else {
                v.style.display = 'block';
                e.style.display = 'none';
            }
        }
    });
    aplicarNormasApartadosAlDOM();
    aplicarNotasAlDOM();
}

function leerNormasApartadosDelDOM() {
    const root = document.getElementById('tablon-normas-bloques-edit');
    if (!root) {
        return;
    }
    const rows = root.querySelectorAll('.tablon-normas-bloque-edit');
    const arr = [];
    rows.forEach(function (row) {
        const t = row.querySelector('.tablon-normas-titulo-in');
        const c = row.querySelector('.tablon-normas-cuerpo-in');
        arr.push({
            titulo: t ? t.value : '',
            cuerpo: c ? c.value : ''
        });
    });
    calendarioData.tablonSecciones.normasApartados = arr;
    calendarioData.tablonSecciones.normas = '';
}

function leerTablonSeccionesDelDOM() {
    if (!esProfesor) {
        return;
    }
    asegurarTablonSecciones();
    TABLON_TEXTO_PLANO_KEYS.forEach(function (key) {
        const el = document.getElementById('tablon-edit-' + key);
        if (el && typeof el.value === 'string') {
            calendarioData.tablonSecciones[key] = el.value;
        }
    });
    leerNormasApartadosDelDOM();
    leerNotasBoletinDelDOM();
}

function inicializarEditorNormasApartados() {
    if (window._catCalNormasEditorWired) {
        return;
    }
    window._catCalNormasEditorWired = true;
    const ed = document.getElementById('tablon-edit-normas');
    if (!ed) {
        return;
    }
    ed.addEventListener('click', function (ev) {
        const t = ev.target;
        if (t && t.id === 'tablon-normas-anadir') {
            if (!esProfesor) {
                return;
            }
            leerNormasApartadosDelDOM();
            if (!Array.isArray(calendarioData.tablonSecciones.normasApartados)) {
                calendarioData.tablonSecciones.normasApartados = [];
            }
            calendarioData.tablonSecciones.normasApartados.push({ titulo: 'Nuevo capítulo', cuerpo: '' });
            aplicarNormasApartadosAlDOM();
            return;
        }
        const sub = t && t.closest ? t.closest('.tablon-normas-subir') : null;
        const baj = t && t.closest ? t.closest('.tablon-normas-bajar') : null;
        const del = t && t.closest ? t.closest('.tablon-normas-quitar') : null;
        const row = t && t.closest ? t.closest('.tablon-normas-bloque-edit') : null;
        if (!esProfesor || !row) {
            return;
        }
        const idx = parseInt(row.getAttribute('data-idx'), 10);
        if (del) {
            leerNormasApartadosDelDOM();
            const arr = calendarioData.tablonSecciones.normasApartados;
            if (!isNaN(idx) && arr && idx >= 0 && idx < arr.length) {
                arr.splice(idx, 1);
            }
            aplicarNormasApartadosAlDOM();
            return;
        }
        leerNormasApartadosDelDOM();
        const arr = calendarioData.tablonSecciones.normasApartados;
        if (!arr || isNaN(idx)) {
            return;
        }
        if (sub && idx > 0) {
            const tmp = arr[idx - 1];
            arr[idx - 1] = arr[idx];
            arr[idx] = tmp;
            aplicarNormasApartadosAlDOM();
            return;
        }
        if (baj && idx < arr.length - 1) {
            const tmp2 = arr[idx + 1];
            arr[idx + 1] = arr[idx];
            arr[idx] = tmp2;
            aplicarNormasApartadosAlDOM();
        }
    });
}

function inicializarModoNormasLecturaEditor() {
    if (window._catCalNormasModoWired) {
        return;
    }
    window._catCalNormasModoWired = true;
    const btnEditar = document.getElementById('tablon-normas-modo-editar');
    const btnVer = document.getElementById('tablon-normas-modo-ver');
    if (btnEditar) {
        btnEditar.addEventListener('click', function () {
            if (!esProfesor) {
                return;
            }
            normasModoEdicion = true;
            aplicarNormasApartadosAlDOM();
        });
    }
    if (btnVer) {
        btnVer.addEventListener('click', function () {
            if (!esProfesor) {
                return;
            }
            leerNormasApartadosDelDOM();
            normasModoEdicion = false;
            aplicarNormasApartadosAlDOM();
        });
    }
}

function cambiarPestanaTablon(id) {
    if (TABLON_TABS_ORDER.indexOf(id) === -1) {
        id = 'indice';
    }
    if (id !== 'normas') {
        normasModoEdicion = false;
    }
    if (id !== 'notas') {
        notasModoEdicion = false;
    }
    pestanaTablonActual = id;
    TABLON_TABS_ORDER.forEach(function (pid) {
        const panel = document.getElementById('panel-' + pid);
        if (panel) {
            panel.classList.toggle('tablon-panel--activa', pid === id);
        }
    });
    document.querySelectorAll('.tablon-nav-principal [data-catcal-tab]').forEach(function (btn) {
        btn.classList.toggle('tablon-nav-activa', btn.getAttribute('data-catcal-tab') === id);
    });
    if (id === 'horario') {
        try {
            mostrarCalendario();
        } catch (e1) {
            catCalDebugLog('cambiarPestanaTablon mostrarCalendario: ' + String(e1));
        }
    }
    if (id === 'notas') {
        try {
            aplicarNotasAlDOM();
        } catch (e2) {
            catCalDebugLog('cambiarPestanaTablon notas: ' + String(e2));
        }
    }
}

function refrescarTablonTrasAbrir() {
    normasModoEdicion = false;
    notasModoEdicion = false;
    asegurarTablonSecciones();
    aplicarTablonSeccionesAlDOM();
    cambiarPestanaTablon('indice');
}

// Garry's Mod DHTML: URL suele ser asset://garrysmod/... — forzar modo embebido (nunca API Vercel/MySQL).
(function () {
    try {
        var href = (typeof window !== 'undefined' && window.location && window.location.href) || '';
        var proto = (typeof window !== 'undefined' && window.location && window.location.protocol) || '';
        if (proto === 'asset:' || href.indexOf('asset://') === 0 || href.indexOf('garrysmod/html/cat_calendario') !== -1) {
            window.MODO_GMOD = true;
            window.MODO_WEB = false;
            window.API_URL = '';
        }
    } catch (e) {}
})();

/** Debug (solo modo web / consola navegador). En GMod no se usa para no spamear ni mostrar overlay. */
function catCalDebugLog(msg) {
    if (typeof window !== 'undefined' && window.MODO_GMOD === true) {
        return;
    }
    var t = '';
    try {
        t = new Date().toISOString().substring(11, 23);
    } catch (e0) {
        t = '?';
    }
    var line = '[' + t + '] ' + String(msg);
    try {
        console.log('[CAT_CAL]', line);
    } catch (e1) {}
    try {
        if (typeof gmod !== 'undefined' && gmod && typeof gmod.CalLog === 'function') {
            gmod.CalLog('[CAT_CAL] ' + line);
        }
    } catch (e2) {}
    try {
        var o = document.getElementById('catcal-debug-overlay');
        if (o) {
            o.style.display = 'block';
            o.appendChild(document.createTextNode(line + '\n'));
        }
    } catch (e3) {}
}
try {
    window.catCalDebugLog = catCalDebugLog;
} catch (e4) {}

catCalDebugLog('script.js: inicio parse (tras IIFE MODO_GMOD)');

/**
 * Helix/Lua y MySQL pueden devolver tablas como {"1": sem1, "2": sem2} o arrays con [null, sem1, sem2].
 * El UI usa semanas[0] y semanas[1]. Normaliza para evitar "No hay datos para esta semana".
 */
function normalizarCalendarioRecibido(cal) {
    if (!cal || typeof cal !== 'object') {
        return {};
    }
    const out = Object.assign({}, cal);

    function arrayDesdeObjetoOAgujero(arrOrObj) {
        if (arrOrObj == null) {
            return [];
        }
        if (Array.isArray(arrOrObj)) {
            if (arrOrObj.length > 1 && arrOrObj[0] == null && arrOrObj[1] != null) {
                return arrOrObj.slice(1);
            }
            return arrOrObj;
        }
        const keys = Object.keys(arrOrObj).sort(function (a, b) {
            return Number(a) - Number(b);
        });
        return keys.map(function (k) {
            return arrOrObj[k];
        }).filter(function (x) {
            return x != null;
        });
    }

    out.semanas = arrayDesdeObjetoOAgujero(out.semanas);

    if (Array.isArray(out.semanas)) {
        out.semanas = out.semanas.map(function (semana) {
            if (!semana || typeof semana !== 'object') {
                return semana;
            }
            const dias = arrayDesdeObjetoOAgujero(semana.dias);
            return Object.assign({}, semana, { dias: dias });
        });
    }

    out.meses = arrayDesdeObjetoOAgujero(out.meses);

    return out;
}

// Guardar referencia a la función nativa de FiveM ANTES de definir nuestra función
// Esto evita que nuestra función sobrescriba la nativa y cause recursión
const NATIVE_GET_PARENT_RESOURCE_NAME = (typeof window !== 'undefined' && typeof window.GetParentResourceName === 'function') 
    ? window.GetParentResourceName.bind(window) 
    : null;

// Detectar modo web automáticamente (SIN llamar a GetParentResourceName para evitar recursión)
function detectarModoWeb() {
    if (typeof window !== 'undefined' && window.MODO_GMOD === true) {
        return false;
    }
    const href0 = (typeof window !== 'undefined' && window.location && window.location.href) || '';
    const proto0 = (typeof window !== 'undefined' && window.location && window.location.protocol) || '';
    if (proto0 === 'asset:' || href0.indexOf('asset://') === 0 || href0.indexOf('garrysmod/html/cat_calendario') !== -1) {
        return false;
    }
    // Si window.MODO_WEB está definido explícitamente, usarlo
    if (typeof window.MODO_WEB !== 'undefined') {
        return window.MODO_WEB === true;
    }
    
    // Detectar automáticamente SOLO basándose en la URL:
    // - Si estamos en FiveM NUI, la URL será como "https://cfx-nui-..."
    // - Si estamos en un navegador real, la URL será como "https://tu-proyecto.vercel.app"
    
    const url = window.location.href;
    const hostname = window.location.hostname;
    
    // Si la URL contiene "cfx-nui", estamos definitivamente en FiveM
    if (url.includes('cfx-nui') || hostname.includes('cfx-nui')) {
        return false; // Estamos en FiveM, NO en modo web
    }
    
    // Si llegamos aquí y la URL es http/https normal (no cfx-nui), estamos en web
    if (window.location.protocol === 'http:' || window.location.protocol === 'https:') {
        // Verificar que no sea una URL de FiveM
        if (!url.includes('cfx-nui') && !hostname.includes('cfx-nui')) {
            return true; // Estamos en un navegador web real
        }
    }
    
    return false; // Por defecto, asumir que estamos en FiveM
}

function obtenerAPIURL() {
    if (typeof window !== 'undefined' && window.MODO_GMOD === true) {
        return '';
    }
    const href0 = (typeof window !== 'undefined' && window.location && window.location.href) || '';
    const proto0 = (typeof window !== 'undefined' && window.location && window.location.protocol) || '';
    if (proto0 === 'asset:' || href0.indexOf('asset://') === 0 || href0.indexOf('garrysmod/html/cat_calendario') !== -1) {
        return '';
    }
    // Si está definido explícitamente, usarlo
    if (window.API_URL && window.API_URL !== '' && window.API_URL !== 'https://cfx-nui-cat_calendario') {
        return window.API_URL;
    }
    
    // Si estamos en modo web real, obtener desde la URL actual
    const url = window.location.href;
    const hostname = window.location.hostname;
    
    // Si es una URL de FiveM, no devolver nada (no usar API)
    if (url.includes('cfx-nui') || hostname.includes('cfx-nui')) {
        return ''; // No usar API en FiveM
    }
    
    // Obtener automáticamente desde la URL actual
    return window.location.origin;
}

const MODO_WEB = detectarModoWeb();
const API_URL = obtenerAPIURL();
let tokenAutenticacion = localStorage.getItem('calendario_token') || null;
let usuarioActual = null;
let ultimoTimestamp = null; // Para detectar cambios en modo web
let pollingInterval = null; // Referencia al intervalo de polling

// Log para debugging
console.log('[Calendario] Modo Web detectado:', MODO_WEB);
console.log('[Calendario] API URL:', API_URL);

// Configuración por defecto (para modo web)
const configPorDefecto = {
    cursos: ["1º", "2º", "3º", "4º", "5º", "6º", "7º", "Todos"],
    meses: ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"],
    diasSemana: ["Sábado", "Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes"],
    horarios: [
        {hora: "16:10 - 17:00", inicio: 16.17, fin: 17, clima: "CLEARING"},
        {hora: "17:00 - 18:00", inicio: 17, fin: 18, clima: "CLEARING"},
        {hora: "18:00 - 19:00", inicio: 18, fin: 19, clima: "CLEAR"},
        {hora: "19:00 - 20:00", inicio: 19, fin: 20, clima: "FOGGY"},
        {hora: "20:00 - 20:30", inicio: 20, fin: 20.5, clima: "FOGGY"},
        {hora: "21:45 - 22:30", inicio: 21.75, fin: 22.5, clima: "FOGGY"},
        {hora: "22:30 - 23:00", inicio: 22.5, fin: 23, clima: "CLEAR"},
        {hora: "23:00 - 23:50", inicio: 23, fin: 23.83, clima: "CLEAR"},
        {hora: "00:30 - 01:00", inicio: 0.5, fin: 1, clima: "CLEAR"}
    ],
    lunas: ["Luna Nueva", "Luna Creciente", "Cuarto Creciente", "Gibosa Creciente", "Luna Llena", "Gibosa Menguante", "Cuarto Menguante", "Luna Menguante"],
    eventos: [
        {nombre: "Ninguno", icono: ""},
        {nombre: "Inicio de Curso", icono: "💼"},
        {nombre: "House Day", icono: "🏰"},
        {nombre: "Music Day", icono: "🎶"},
        {nombre: "Ghost Day", icono: "👻"},
        {nombre: "Año Nuevo", icono: "🎆"},
        {nombre: "Festividad de Invierno", icono: "⛄"},
        {nombre: "San Valentin", icono: "💘"},
        {nombre: "Cartas Encantadas", icono: "💌"},
        {nombre: "Día del Teatro", icono: "🎭"},
        {nombre: "Día de San Patricio", icono: "🍀"},
        {nombre: "Festival de Equinoccio", icono: "🌒☀️"},
        {nombre: "Pascua", icono: "🥚"},
        {nombre: "April Fool's", icono: "🤡"},
        {nombre: "Festival de Primavera", icono: "🌸"},
        {nombre: "Día de Hogwarts", icono: "🦉"},
        {nombre: "Día del Invernadero", icono: "🌱"},
        {nombre: "Dia del Repaso", icono: "📖"},
        {nombre: "Fin de Examenes", icono: "✍️"},
        {nombre: "Fin de Curso", icono: "🎓"},
        {nombre: "Halloween", icono: "🎃"},
        {nombre: "Navidad", icono: "❄️"},
        {nombre: "Torneo de los Tres Magos", icono: "⚡"},
        {nombre: "Partido de Quidditch", icono: "🏆"},
        {nombre: "Exámenes Finales", icono: "📚"},
        {nombre: "Fiesta de Bienvenida", icono: "🎉"},
        {nombre: "Baile de Navidad", icono: "💃"},
        {nombre: "Visita a Hogsmeade", icono: "🏘️"},
        {nombre: "Celebración de Cumpleaños", icono: "🎂"},
        {nombre: "Concierto del Coro", icono: "🎵"},
        {nombre: "Exposición de Arte Mágico", icono: "🎨"},
        {nombre: "Feria del Libro", icono: "📖"},
        {nombre: "Torneo de Duelo", icono: "⚔️"}
    ],
    separadores: ["TOQUE DE QUEDA", "DESCANSO", "COMEDOR", "RECREO", "ACTIVIDADES EXTRAESCOLARES", "CLUBES", "HORARIO NOCTURNO", "HORA DE ESTUDIO", "CLASES NOCTURNAS", "GUARDIA"],
    colores: [
        {nombre: "Rojo Gryffindor", valor: "#740001"},
        {nombre: "Dorado Gryffindor", valor: "#d3a625"},
        {nombre: "Azul Ravenclaw", valor: "#0e1a40"},
        {nombre: "Bronce Ravenclaw", valor: "#946b2d"},
        {nombre: "Amarillo Hufflepuff", valor: "#ecb939"},
        {nombre: "Negro Hufflepuff", valor: "#372e29"},
        {nombre: "Verde Slytherin", valor: "#1a472a"},
        {nombre: "Plateado Slytherin", valor: "#5d5d5d"},
        {nombre: "Rojo Oscuro", valor: "#8b0000"},
        {nombre: "Verde Oscuro", valor: "#006400"},
        {nombre: "Azul Oscuro", valor: "#00008b"},
        {nombre: "Morado", valor: "#4b0082"},
        {nombre: "Naranja", valor: "#ff8c00"},
        {nombre: "Rosa", valor: "#ff69b4"},
        {nombre: "Gris", valor: "#808080"},
        {nombre: "Negro", valor: "#000000"},
        {nombre: "Blanco", valor: "#ffffff"}
    ],
    climas: ["CLEAR", "CLOUDS", "CLEARING", "RAIN", "THUNDER", "FOGGY"],
    notas: {
        msgNoPublicado:
            'Las notas del curso aún no están publicadas. Consultá con el profesorado.',
        msgSinFila: 'No hay una fila de boletín asociada a tu personaje. Si debiera aparecer, contactá al profesorado.',
        msgPublicadoSinFila: 'Tu personaje no figura en el listado de notas publicado.',
        msgBoletinPublicadoVacio: 'Las notas están publicadas pero el boletín aún no tiene filas.',
        tituloListadoDefault: 'LISTADO DE NOTAS DEL COLEGIO HOGWARTS DE MAGIA Y HECHICERÍA',
        anioEscolarLabelDefault: 'Año escolar IC',
        leyendaDefault: '',
        asignaturasPorCursoDefault: {
            '1': ['Encantamientos', 'Transformaciones', 'Herbología', 'HDM', 'Pociones', 'DCAO', 'Vuelo', 'Teoría Mágica'],
            '2': ['Encantamientos', 'Transformaciones', 'Herbología', 'HDM', 'Pociones', 'DCAO'],
            '3': ['Encantamientos', 'Transformaciones', 'Herbología', 'HDM', 'Pociones', 'DCAO', 'CCM', 'Astronomía', 'Adivinación', 'Runas Antiguas', 'Estudios Muggle'],
            '4': ['Encantamientos', 'Transformaciones', 'Herbología', 'HDM', 'Pociones', 'DCAO', 'CCM', 'Astronomía', 'Adivinación', 'Runas Antiguas', 'Estudios Muggle'],
            '5': ['Encantamientos', 'Transformaciones', 'Herbología', 'HDM', 'Pociones', 'DCAO', 'CCM', 'Astronomía', 'Adivinación', 'Runas Antiguas', 'Estudios Muggle'],
            '6': ['Encantamientos', 'Transformaciones', 'Herbología', 'HDM', 'Pociones', 'DCAO', 'CCM', 'Astronomía', 'Adivinación', 'Runas Antiguas', 'Estudios Muggle'],
            '7': ['Encantamientos', 'Transformaciones', 'Herbología', 'HDM', 'Pociones', 'DCAO', 'CCM', 'Astronomía', 'Adivinación', 'Runas Antiguas', 'Estudios Muggle']
        },
        coloresCasa: {
            Gryffindor: '#740001',
            Ravenclaw: '#0e1a40',
            Hufflepuff: '#ecb939',
            Slytherin: '#1a472a',
            Otra: '#5c4a3a'
        },
        casasBoletinOpciones: ['Gryffindor', 'Hufflepuff', 'Ravenclaw', 'Slytherin'],
        calificacionesBoletin: ['E', 'S', 'A', 'I', 'D', 'T'],
        cursosCalificacionLetras: [5, 7],
        calificacionesNumericasMax: 10
    }
};

// Compatibilidad CEF antiguo (GMod): sin optional chaining (?.) en todo el archivo.
function elOn(id, eventName, handler) {
    var el = document.getElementById(id);
    if (el) {
        el.addEventListener(eventName, handler);
    }
}

function celdaDiaCal(semanaIndex, diaIndex) {
    var sm = calendarioData.semanas;
    if (!sm || sm[semanaIndex] == null) {
        return null;
    }
    var dias = sm[semanaIndex].dias;
    if (!dias || dias[diaIndex] == null) {
        return null;
    }
    return dias[diaIndex];
}

function clasesEnFranjaCal(semanaIndex, diaIndex, horario) {
    var d = celdaDiaCal(semanaIndex, diaIndex);
    if (!d || !d.clases) {
        return [];
    }
    var c = d.clases[horario];
    return c || [];
}

function eventosHorarioComoArray(semanaIndex, diaIndex, horario) {
    var d = celdaDiaCal(semanaIndex, diaIndex);
    if (!d || !d.eventosHorario) {
        return [];
    }
    var ev = d.eventosHorario[horario];
    if (!ev) {
        return [];
    }
    return Array.isArray(ev) ? ev : [ev];
}

function claseEnFranjaCal(semanaIndex, diaIndex, horario, claseIndex) {
    var arr = clasesEnFranjaCal(semanaIndex, diaIndex, horario);
    if (claseIndex === '' || claseIndex == null) {
        return undefined;
    }
    return arr[claseIndex];
}

function handleCalendarioPostMessage(event) {
    catCalDebugLog('handleCalendarioPostMessage: entrando');
    var data = event.data;
    catCalDebugLog('handleCal: typeof data=' + typeof data);
    if (typeof data === 'string') {
        try {
            data = JSON.parse(data);
            catCalDebugLog('handleCal: JSON.parse string OK');
        } catch (e0) {
            catCalDebugLog('handleCal: JSON.parse string FALLA ' + String(e0));
            return;
        }
    }
    if (!data || !data.action) {
        catCalDebugLog('handleCal: sin data o sin action, ignorado');
        return;
    }
    catCalDebugLog('handleCal: action=' + String(data.action));

    if (data.action === 'abrirCalendario') {
        catCalDebugLog('abrirCalendario: normalizando calendario…');
        try {
            var rawSem = data.calendario && data.calendario.semanas;
            catCalDebugLog('abrirCal: semanas typeof=' + typeof rawSem + (Array.isArray(rawSem) ? ' len=' + rawSem.length : ' keys=' + (rawSem && typeof rawSem === 'object' ? Object.keys(rawSem).length : 'n/a')));
        } catch (eSz) {
            catCalDebugLog('abrirCal: error inspeccion semanas ' + String(eSz));
        }

        calendarioData = normalizarCalendarioRecibido(data.calendario || {});
        esProfesor = data.esProfesor || false;
        puedePublicarTablon = data.puedePublicarTablon || false;
        config = data.config || {};
        contextoVisor = data.contextoVisor && typeof data.contextoVisor === 'object' ? data.contextoVisor : {};
        notasVistaAlumno =
            data.notasVistaAlumno && typeof data.notasVistaAlumno === 'object' ? data.notasVistaAlumno : null;

        if (!config.cursos) {
            config.cursos = [];
        }
        if (!config.meses) {
            config.meses = [];
        }
        if (!config.diasSemana) {
            config.diasSemana = [];
        }
        if (!config.horarios) {
            config.horarios = [];
        }
        if (!config.lunas) {
            config.lunas = [];
        }
        if (!config.eventos) {
            config.eventos = [];
        }
        if (!config.separadores) {
            config.separadores = [];
        }

        if (!config.diasSemana || config.diasSemana.length === 0) {
            config.diasSemana = configPorDefecto.diasSemana.slice();
        }
        if (!config.horarios || config.horarios.length === 0) {
            config.horarios = JSON.parse(JSON.stringify(configPorDefecto.horarios));
        }

        if (!config.climas || config.climas.length === 0) {
            catCalDebugLog('config.climas vacio -> por defecto');
            config.climas = [
                'CLEAR', 'CLOUDS', 'CLEARING', 'RAIN', 'THUNDER', 'FOGGY'
            ];
        }

        if (!config.notas || typeof config.notas !== 'object') {
            config.notas = Object.assign({}, configPorDefecto.notas);
        } else {
            config.notas = Object.assign({}, configPorDefecto.notas, config.notas);
        }

        if (data.tituloVentana) {
            var tituloHeader = document.querySelector('.header h1');
            if (tituloHeader) {
                tituloHeader.textContent = data.tituloVentana;
            }
        }

        document.body.style.display = 'block';
        catCalDebugLog('abrirCal: body display block, llamando mostrarCalendario()');
        try {
            mostrarCalendario();
            catCalDebugLog('abrirCal: mostrarCalendario() retorno OK');
        } catch (eMc) {
            catCalDebugLog('abrirCal: mostrarCalendario EXC ' + String(eMc));
        }

        actualizarBotonesAccionTablon();
        refrescarTablonTrasAbrir();
    }

    if (data.action === 'cerrarCalendario') {
        catCalDebugLog('cerrarCalendario');
        document.body.style.display = 'none';
        cerrarContextMenu();
    }

    if (data.action === 'actualizarCalendario') {
        catCalDebugLog('actualizarCalendario');
        if (data.calendario) {
            notasVistaAlumno = null;
            calendarioData = normalizarCalendarioRecibido(data.calendario);
            mostrarCalendario();
            asegurarTablonSecciones();
            aplicarTablonSeccionesAlDOM();
        }
    }
}

// Función para cargar datos desde API (modo web)
async function cargarDatosDesdeAPI() {
    if (typeof window !== 'undefined' && window.MODO_GMOD === true) {
        return;
    }
    // Verificar que estamos realmente en modo web (no FiveM)
    if (!MODO_WEB || !API_URL || API_URL === '' || API_URL.includes('cfx-nui')) {
        console.log('[Calendario] No se puede cargar desde API - estamos en FiveM o API_URL inválida');
        console.log('[Calendario] MODO_WEB:', MODO_WEB, 'API_URL:', API_URL);
        return;
    }
    
    try {
        console.log('[Calendario] Cargando datos desde:', `${API_URL}/api/calendario`);

        // Verificar sesión ANTES de pintar la UI (evita modo solo lectura tras login)
        if (tokenAutenticacion) {
            try {
                const verifyResponse = await fetch(`${API_URL}/api/verificar`, {
                    headers: {
                        'Authorization': `Bearer ${tokenAutenticacion}`
                    }
                });
                const verifyData = await verifyResponse.json();
                if (verifyData.success) {
                    aplicarRolUsuario(verifyData.usuario);
                } else {
                    tokenAutenticacion = null;
                    localStorage.removeItem('calendario_token');
                    aplicarRolUsuario(null);
                }
            } catch (e) {
                console.error('Error verificando token:', e);
                aplicarRolUsuario(null);
            }
        } else {
            aplicarRolUsuario(null);
        }
        
        const response = await fetch(`${API_URL}/api/calendario`);
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const data = await response.json();
        console.log('[Calendario] Datos recibidos:', data);
        
        if (data.success && data.calendario) {
            const nuevoTimestamp = data.calendario.ultimaActualizacion || 0;

            if (ultimoTimestamp !== null && nuevoTimestamp > ultimoTimestamp) {
                console.log('[Calendario] 🔄 Cambios detectados! Timestamp anterior:', ultimoTimestamp, 'Nuevo:', nuevoTimestamp);
                mostrarNotificacion('🔄 Calendario actualizado', 'info');
            }

            ultimoTimestamp = nuevoTimestamp;
            config = configPorDefecto;
            calendarioData = normalizarCalendarioRecibido(data.calendario);
        } else {
            console.warn('[Calendario] No hay datos del calendario, usando estructura vacía');
            calendarioData = { semanas: [], meses: [], separadores: {}, climasHorario: {} };
        }

        // Cargar configuración (por si el bloque anterior no entró)
        if (!config || !config.horarios || config.horarios.length === 0) {
            config = configPorDefecto;
        }
        
        // Asegurar que el body esté visible
        document.body.style.display = 'block';
        
        // Pintar una sola vez, ya con permisos de edición aplicados
        mostrarCalendario();

        asegurarTablonSecciones();
        syncNotasVistaAlumnoDesdeCalendario();
        aplicarTablonSeccionesAlDOM();
        cambiarPestanaTablon('indice');

        actualizarBarraAuth();
        ensureModalLoginExists();
        
        console.log('[Calendario] Calendario cargado correctamente');
        
    } catch (error) {
        console.error('Error cargando datos desde API:', error);
        console.error('Stack:', error.stack);
        
        // Mostrar mensaje de error más detallado
        const errorMsg = error.message || 'Error desconocido';
        mostrarNotificacion(`Error al cargar el calendario: ${errorMsg}`, 'error');
        
        // Mostrar el body con mensaje de error
        document.body.style.display = 'block';
        document.body.innerHTML = `
            <div style="padding: 40px; text-align: center; font-family: Arial, sans-serif;">
                <h2 style="color: #dc3545;">Error al cargar el calendario</h2>
                <p style="color: #666; margin: 20px 0;">${errorMsg}</p>
                <p style="color: #999; font-size: 12px;">Revisa la consola del navegador (F12) para más detalles.</p>
                <button onclick="location.reload()" style="padding: 10px 20px; background: #740001; color: white; border: none; border-radius: 5px; cursor: pointer; margin-top: 20px;">
                    Recargar Página
                </button>
            </div>
        `;
    }
}

// Función para iniciar polling periódico (solo en modo web)
function iniciarPollingPeriodico() {
    if (typeof window !== 'undefined' && window.MODO_GMOD === true) {
        return;
    }
    // Solo en modo web y si no hay un intervalo ya activo
    if (!MODO_WEB || !API_URL || API_URL === '' || API_URL.includes('cfx-nui')) {
        return;
    }
    
    // Si ya hay un intervalo activo, no crear otro
    if (pollingInterval !== null) {
        console.log('[Calendario] Polling ya está activo');
        return;
    }
    
    console.log('[Calendario] 🔄 Iniciando polling periódico (cada 30 segundos)');
    
    // Intervalo de 30 segundos (30000 ms)
    pollingInterval = setInterval(async () => {
        try {
            // Verificar si la página está visible (no hacer polling si está en segundo plano)
            if (document.hidden) {
                console.log('[Calendario] Página en segundo plano, omitiendo polling');
                return;
            }
            
            console.log('[Calendario] 🔍 Verificando cambios...');
            
            const response = await fetch(`${API_URL}/api/calendario`);
            
            if (!response.ok) {
                console.warn('[Calendario] Error en polling:', response.status);
                return;
            }
            
            const data = await response.json();
            
            if (data.success && data.calendario) {
                const nuevoTimestamp = data.calendario.ultimaActualizacion || 0;
                
                // Comparar timestamps
                if (ultimoTimestamp !== null && nuevoTimestamp > ultimoTimestamp) {
                    console.log('[Calendario] 🔄 Cambios detectados! Actualizando calendario...');
                    console.log('[Calendario] Timestamp anterior:', ultimoTimestamp, 'Nuevo:', nuevoTimestamp);
                    
                    // Actualizar datos
                    ultimoTimestamp = nuevoTimestamp;
                    calendarioData = normalizarCalendarioRecibido(data.calendario);
                    
                    // Actualizar la vista si el calendario está visible
                    if (document.body.style.display !== 'none') {
                        mostrarCalendario();
                        asegurarTablonSecciones();
                        syncNotasVistaAlumnoDesdeCalendario();
                        aplicarTablonSeccionesAlDOM();
                        mostrarNotificacion('🔄 Calendario actualizado automáticamente', 'info');
                    }
                } else if (ultimoTimestamp === null) {
                    // Primera vez, solo guardar el timestamp
                    ultimoTimestamp = nuevoTimestamp;
                } else {
                    console.log('[Calendario] ✅ Sin cambios (timestamp:', nuevoTimestamp, ')');
                }
            }
        } catch (error) {
            console.error('[Calendario] Error en polling:', error);
            // No mostrar notificación de error en polling para no molestar al usuario
        }
    }, 30000); // 30 segundos
    
    console.log('[Calendario] ✅ Polling iniciado correctamente');
}

// Función para detener polling (útil si se necesita)
function detenerPollingPeriodico() {
    if (pollingInterval !== null) {
        clearInterval(pollingInterval);
        pollingInterval = null;
        console.log('[Calendario] Polling detenido');
    }
}

function permisosDesdeUsuario(usuario) {
    if (!usuario) {
        return [];
    }

    if (Array.isArray(usuario.permisos) && usuario.permisos.length > 0) {
        return usuario.permisos;
    }

    if (usuario.rol === 'admin') {
        return ['editar', 'publicar'];
    }

    return ['editar'];
}

function refrescarUIEdicionCalendario() {
    if (!calendarioData || typeof calendarioData !== 'object') {
        return;
    }

    const tieneDatos = (
        (calendarioData.semanas && (Array.isArray(calendarioData.semanas) ? calendarioData.semanas.length > 0 : Object.keys(calendarioData.semanas).length > 0)) ||
        (calendarioData.tablonSecciones && typeof calendarioData.tablonSecciones === 'object')
    );

    if (!tieneDatos) {
        return;
    }

    mostrarCalendario();
    refrescarTablonTrasAbrir();
}

function aplicarRolUsuario(usuario) {
    if (!usuario) {
        usuarioActual = null;
        esProfesor = false;
        puedePublicarTablon = false;
        esAdmin = false;
        syncNotasVistaAlumnoDesdeCalendario();
        actualizarBotonesAccionTablon();
        refrescarUIEdicionCalendario();
        return;
    }
    usuarioActual = usuario;
    const permisos = permisosDesdeUsuario(usuario);
    esProfesor = permisos.indexOf('editar') !== -1;
    puedePublicarTablon = permisos.indexOf('publicar') !== -1;
    esAdmin = usuario.rol === 'admin';

    if (!esProfesor) {
        syncNotasVistaAlumnoDesdeCalendario();
    } else {
        notasVistaAlumno = null;
    }

    actualizarBotonesAccionTablon();
    refrescarUIEdicionCalendario();
}

function actualizarBarraAuth() {
    const label = document.getElementById('authUserLabel');
    const btnLogin = document.getElementById('btnLoginHeader');
    const btnLogout = document.getElementById('btnLogoutHeader');
    const btnAdmin = document.getElementById('btnAdminPanel');
    const btnGuardar = document.getElementById('btnGuardar');

    if (!MODO_WEB) {
        if (label) label.hidden = true;
        if (btnLogin) btnLogin.hidden = true;
        if (btnLogout) btnLogout.hidden = true;
        if (btnAdmin) btnAdmin.hidden = true;
        return;
    }

    const loggedIn = !!(tokenAutenticacion && usuarioActual);

    if (label) {
        if (loggedIn) {
            label.textContent = (usuarioActual.username || '') +
                (usuarioActual.rol ? ' (' + usuarioActual.rol + ')' : '');
            label.hidden = false;
        } else {
            label.hidden = true;
        }
    }
    if (btnLogin) btnLogin.hidden = loggedIn;
    if (btnLogout) btnLogout.hidden = !loggedIn;
    if (btnAdmin) btnAdmin.hidden = !(loggedIn && esAdmin);
    actualizarBotonesAccionTablon();
}

function ensureModalLoginExists() {
    if (!MODO_WEB || document.getElementById('modalLogin')) return;

    const modalLogin = document.createElement('div');
    modalLogin.id = 'modalLogin';
    modalLogin.className = 'modal';
    modalLogin.style.display = 'none';
    modalLogin.innerHTML = `
        <div class="modal-content">
            <h3>🔐 Iniciar Sesión</h3>
            <p>Necesitas iniciar sesión para editar el calendario</p>
            <form id="formLogin">
                <div class="form-group">
                    <label>Usuario:</label>
                    <input type="text" id="loginUsername" required autocomplete="username">
                </div>
                <div class="form-group">
                    <label>Contraseña:</label>
                    <input type="password" id="loginPassword" required autocomplete="current-password">
                </div>
                <div class="modal-botones">
                    <button type="submit" class="btn-guardar">Iniciar Sesión</button>
                    <button type="button" id="btnCerrarLogin" class="btn-cerrar">Cerrar</button>
                </div>
            </form>
            <p style="margin-top: 15px; font-size: 12px; color: #666;">
                Puedes ver el calendario sin iniciar sesión, pero necesitas autenticarte para editarlo.
            </p>
        </div>
    `;
    document.body.appendChild(modalLogin);

    document.getElementById('formLogin').addEventListener('submit', async function (e) {
        e.preventDefault();
        await hacerLogin();
    });

    document.getElementById('btnCerrarLogin').addEventListener('click', function () {
        modalLogin.style.display = 'none';
    });
}

function abrirModalLogin() {
    if (!MODO_WEB) return;
    ensureModalLoginExists();
    const modalLogin = document.getElementById('modalLogin');
    if (modalLogin) modalLogin.style.display = 'block';
}

function cerrarSesion() {
    tokenAutenticacion = null;
    localStorage.removeItem('calendario_token');
    aplicarRolUsuario(null);
    const modalLogin = document.getElementById('modalLogin');
    if (modalLogin) modalLogin.style.display = 'none';
    actualizarBarraAuth();
    mostrarNotificacion('Sesión cerrada', 'info');
}

function authHeadersJson() {
    return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + tokenAutenticacion
    };
}

function abrirPanelAdmin() {
    if (!esAdmin || !tokenAutenticacion) return;
    const modal = document.getElementById('modalAdmin');
    if (!modal) return;
    modal.style.display = 'block';
    cargarUsuariosAdmin();
}

function cerrarPanelAdmin() {
    const modal = document.getElementById('modalAdmin');
    if (modal) modal.style.display = 'none';
}

function cambiarTabAdmin(tabId) {
    document.querySelectorAll('.admin-tab').forEach(function (btn) {
        btn.classList.toggle('admin-tab--activa', btn.getAttribute('data-admin-tab') === tabId);
    });
    const panelUsuarios = document.getElementById('adminPanelUsuarios');
    const panelLogs = document.getElementById('adminPanelLogs');
    if (panelUsuarios) {
        panelUsuarios.classList.toggle('admin-panel--activa', tabId === 'usuarios');
    }
    if (panelLogs) {
        panelLogs.classList.toggle('admin-panel--activa', tabId === 'logs');
    }
    if (tabId === 'logs') {
        cargarLogsAdmin();
    }
}

async function cargarUsuariosAdmin() {
    const cont = document.getElementById('adminUsersList');
    if (!cont || !tokenAutenticacion) return;
    cont.innerHTML = '<p style="padding:12px;">Cargando usuarios…</p>';
    try {
        const res = await fetch(API_URL + '/api/usuarios', { headers: { Authorization: 'Bearer ' + tokenAutenticacion } });
        const data = await res.json();
        if (!res.ok || !data.success) {
            cont.innerHTML = '<p style="padding:12px;color:#c00;">' + (data.error || 'Error al cargar usuarios') + '</p>';
            return;
        }
        const usuarios = data.usuarios || [];
        if (!usuarios.length) {
            cont.innerHTML = '<p style="padding:12px;">No hay usuarios registrados.</p>';
            return;
        }
        cont.innerHTML = usuarios.map(function (u) {
            const esYo = usuarioActual && u.username === usuarioActual.username;
            return '<div class="admin-user-row">' +
                '<span><strong>' + escapeHtmlAdmin(u.username) + '</strong> · ' + escapeHtmlAdmin(u.rol || '') +
                (esYo ? ' <em>(tú)</em>' : '') + '</span>' +
                '<div class="admin-user-actions">' +
                '<button type="button" data-admin-action="rol" data-username="' + escapeHtmlAdmin(u.username) + '" data-rol="' + escapeHtmlAdmin(u.rol) + '">Cambiar rol</button>' +
                '<button type="button" data-admin-action="pass" data-username="' + escapeHtmlAdmin(u.username) + '">Nueva contraseña</button>' +
                (esYo ? '' : '<button type="button" data-admin-action="del" data-username="' + escapeHtmlAdmin(u.username) + '">Eliminar</button>') +
                '</div></div>';
        }).join('');
    } catch (err) {
        cont.innerHTML = '<p style="padding:12px;color:#c00;">Error de conexión</p>';
    }
}

async function cargarLogsAdmin() {
    const cont = document.getElementById('adminLogsList');
    if (!cont || !tokenAutenticacion) return;
    const q = (document.getElementById('adminLogSearch') && document.getElementById('adminLogSearch').value) || '';
    cont.innerHTML = '<p style="padding:12px;">Cargando historial…</p>';
    try {
        let url = API_URL + '/api/logs?limit=80';
        if (q.trim()) url += '&q=' + encodeURIComponent(q.trim());
        const res = await fetch(url, { headers: { Authorization: 'Bearer ' + tokenAutenticacion } });
        const data = await res.json();
        if (!res.ok || !data.success) {
            cont.innerHTML = '<p style="padding:12px;color:#c00;">' + (data.error || 'Error al cargar historial') + '</p>';
            return;
        }
        const logs = data.logs || [];
        if (!logs.length) {
            cont.innerHTML = '<p style="padding:12px;">Sin registros.</p>';
            return;
        }
        cont.innerHTML = logs.map(function (log) {
            const fecha = log.fecha ? String(log.fecha).replace('T', ' ').slice(0, 19) : '';
            return '<div class="admin-log-row">' +
                '<span><strong>' + escapeHtmlAdmin(log.username || '') + '</strong> · ' + escapeHtmlAdmin(log.accion || '') + '</span>' +
                '<span style="color:#666;font-size:12px;">' + escapeHtmlAdmin(fecha) + '</span>' +
                (log.detalles ? '<div style="width:100%;font-size:12px;color:#444;">' + escapeHtmlAdmin(log.detalles) + '</div>' : '') +
                '</div>';
        }).join('');
    } catch (err) {
        cont.innerHTML = '<p style="padding:12px;color:#c00;">Error de conexión</p>';
    }
}

function escapeHtmlAdmin(text) {
    return String(text || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

async function crearUsuarioAdmin() {
    const username = (document.getElementById('adminNewUsername') || {}).value || '';
    const password = (document.getElementById('adminNewPassword') || {}).value || '';
    const rol = (document.getElementById('adminNewRol') || {}).value || 'profesor';
    if (!username.trim() || !password) {
        mostrarNotificacion('Usuario y contraseña son obligatorios', 'error');
        return;
    }
    try {
        const res = await fetch(API_URL + '/api/usuarios', {
            method: 'POST',
            headers: authHeadersJson(),
            body: JSON.stringify({ username: username.trim(), password: password, rol: rol })
        });
        const data = await res.json();
        if (!res.ok || !data.success) {
            mostrarNotificacion(data.error || 'No se pudo crear el usuario', 'error');
            return;
        }
        mostrarNotificacion('Usuario creado', 'success');
        document.getElementById('adminNewUsername').value = '';
        document.getElementById('adminNewPassword').value = '';
        cargarUsuariosAdmin();
    } catch (e) {
        mostrarNotificacion('Error de conexión', 'error');
    }
}

async function adminAccionUsuario(action, username, rolActual) {
    if (action === 'rol') {
        const nuevoRol = rolActual === 'admin' ? 'profesor' : 'admin';
        if (!window.confirm('¿Cambiar rol de "' + username + '" a ' + nuevoRol + '?')) return;
        try {
            const res = await fetch(API_URL + '/api/usuarios?username=' + encodeURIComponent(username), {
                method: 'PUT',
                headers: authHeadersJson(),
                body: JSON.stringify({ rol: nuevoRol })
            });
            const data = await res.json();
            if (!res.ok || !data.success) {
                mostrarNotificacion(data.error || 'No se pudo actualizar', 'error');
                return;
            }
            mostrarNotificacion('Rol actualizado', 'success');
            cargarUsuariosAdmin();
        } catch (e) {
            mostrarNotificacion('Error de conexión', 'error');
        }
        return;
    }
    if (action === 'pass') {
        const nuevaPass = window.prompt('Nueva contraseña para "' + username + '" (mín. 6 caracteres):');
        if (!nuevaPass) return;
        try {
            const res = await fetch(API_URL + '/api/usuarios?username=' + encodeURIComponent(username), {
                method: 'PUT',
                headers: authHeadersJson(),
                body: JSON.stringify({ password: nuevaPass })
            });
            const data = await res.json();
            if (!res.ok || !data.success) {
                mostrarNotificacion(data.error || 'No se pudo cambiar la contraseña', 'error');
                return;
            }
            mostrarNotificacion('Contraseña actualizada', 'success');
        } catch (e) {
            mostrarNotificacion('Error de conexión', 'error');
        }
        return;
    }
    if (action === 'del') {
        if (!window.confirm('¿Eliminar al usuario "' + username + '"?')) return;
        try {
            const res = await fetch(API_URL + '/api/usuarios?username=' + encodeURIComponent(username), {
                method: 'DELETE',
                headers: { Authorization: 'Bearer ' + tokenAutenticacion }
            });
            const data = await res.json();
            if (!res.ok || !data.success) {
                mostrarNotificacion(data.error || 'No se pudo eliminar', 'error');
                return;
            }
            mostrarNotificacion('Usuario eliminado', 'success');
            cargarUsuariosAdmin();
        } catch (e) {
            mostrarNotificacion('Error de conexión', 'error');
        }
    }
}

function inicializarBarraAuthYAdmin() {
    if (!MODO_WEB) return;

    elOn('btnLoginHeader', 'click', abrirModalLogin);
    elOn('btnLogoutHeader', 'click', cerrarSesion);
    elOn('btnAdminPanel', 'click', abrirPanelAdmin);
    elOn('btnCerrarAdmin', 'click', cerrarPanelAdmin);
    elOn('btnAdminCreateUser', 'click', crearUsuarioAdmin);
    elOn('btnAdminReloadLogs', 'click', cargarLogsAdmin);

    document.querySelectorAll('.admin-tab').forEach(function (btn) {
        btn.addEventListener('click', function () {
            cambiarTabAdmin(btn.getAttribute('data-admin-tab'));
        });
    });

    const usersList = document.getElementById('adminUsersList');
    if (usersList) {
        usersList.addEventListener('click', function (ev) {
            const btn = ev.target.closest('[data-admin-action]');
            if (!btn) return;
            adminAccionUsuario(
                btn.getAttribute('data-admin-action'),
                btn.getAttribute('data-username'),
                btn.getAttribute('data-rol')
            );
        });
    }

    actualizarBarraAuth();
    ensureModalLoginExists();
}

// Abre el modal de login (p. ej. al intentar guardar sin sesión)
function mostrarLoginSiNecesario() {
    if (!MODO_WEB) return;
    abrirModalLogin();
}

// Función para hacer login
async function hacerLogin() {
    const username = document.getElementById('loginUsername').value;
    const password = document.getElementById('loginPassword').value;
    
    try {
        const response = await fetch(`${API_URL}/api/login`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ username, password })
        });
        
        const data = await response.json();
        
        if (data.success && data.token) {
            tokenAutenticacion = data.token;
            localStorage.setItem('calendario_token', tokenAutenticacion);
            aplicarRolUsuario(data.usuario);
            actualizarBarraAuth();

            const modalLogin = document.getElementById('modalLogin');
            if (modalLogin) modalLogin.style.display = 'none';
            mostrarNotificacion('Sesión iniciada correctamente', 'success');
        } else {
            mostrarNotificacion(data.error || 'Error al iniciar sesión', 'error');
        }
    } catch (error) {
        console.error('Error en login:', error);
        mostrarNotificacion('Error de conexión', 'error');
    }
}

// Función helper para GetParentResourceName (compatibilidad FiveM)
// IMPORTANTE: NO usar MODO_WEB aquí para evitar recursión
function GetParentResourceName() {
    // Verificar SOLO basándose en la URL (sin usar MODO_WEB)
    const url = window.location.href;
    
    if (url.includes('cfx-nui')) {
        // Estamos en FiveM, intentar usar la función nativa primero
        if (NATIVE_GET_PARENT_RESOURCE_NAME) {
            try {
                // Llamar a la función nativa guardada (no a nuestra función)
                const result = NATIVE_GET_PARENT_RESOURCE_NAME();
                if (result && result !== 'web-mode' && result !== 'unknown') {
                    return result;
                }
            } catch (e) {
                // Si falla, continuar con el método alternativo
            }
        }
        
        // Si no está disponible, extraer el nombre del recurso desde la URL
        const match = url.match(/cfx-nui-([^/]+)/);
        if (match && match[1]) {
            return match[1];
        }
        return 'cat_calendario'; // Nombre por defecto
    }
    
    // Si NO es cfx-nui, estamos en modo web
    return 'web-mode';
}

// Inicializar
document.addEventListener('DOMContentLoaded', function() {
    catCalDebugLog('DOMContentLoaded: MODO_WEB=' + MODO_WEB + ' MODO_GMOD=' + (typeof window !== 'undefined' ? window.MODO_GMOD : '?'));
    console.log('NUI: Interfaz cargada, inicializando eventos...');
    console.log('Modo Web:', MODO_WEB);
    console.log('API URL:', API_URL);
    console.log('URL actual:', window.location.href);
    
    try {
        inicializarEventos();
        
        // Solo cargar desde API si estamos en modo web REAL (no FiveM)
        if (MODO_WEB && API_URL && API_URL !== '' && !API_URL.includes('cfx-nui')) {
            // En modo web REAL, mostrar el body inmediatamente y cargar datos
            document.body.style.display = 'block';
            // Cargar datos desde API
            cargarDatosDesdeAPI().catch(error => {
                console.error('Error cargando datos:', error);
                mostrarNotificacion('Error al cargar el calendario. Verifica la consola para más detalles.', 'error');
            });
            
            // Iniciar polling periódico para detectar cambios (cada 30 segundos)
            iniciarPollingPeriodico();
        } else if (typeof window !== 'undefined' && window.MODO_GMOD === true) {
            // GMod DHTML: no ocultar body (display:none deja panel blanco si falla postMessage o la cola JS).
            document.body.style.display = 'block';
            console.log('[NUI] GMod: panel visible; esperando mensaje del cliente Lua');
        } else {
            // FiveM u otros embebidos: ocultar hasta recibir mensaje
            document.body.style.display = 'none';
            console.log('[NUI] Modo embebido (no web): esperando mensaje del cliente');
        }
    } catch (error) {
        console.error('Error en inicialización:', error);
        try {
            catCalDebugLog('DOMContentLoaded CATCH: ' + String(error));
        } catch (e2) {}
        document.body.innerHTML = '<div style="padding: 20px; text-align: center;"><h2>Error al cargar el calendario</h2><p>Revisa la consola para más detalles.</p></div>';
        document.body.style.display = 'block';
    }
});

function inicializarEventos() {
    catCalDebugLog('inicializarEventos: entrada');
    console.log('NUI: Inicializando eventos...');

    // Inicializar selectores de color
    inicializarSelectoresColor();

    // Configurar eventos de clima horario
    elOn('btnCancelarClimaHorario', 'click', cerrarModalClimaHorario);
    elOn('horaPruebaClima', 'input', function() {
        calcularClimaParaHora(this.value);
    });

    elOn('btnAplicarClimaPrueba', 'click', aplicarClimaPrueba);
    elOn('btnProbarClimas', 'click', abrirModalProbarClimas);
    elOn('btnCerrarProbarClimas', 'click', cerrarModalProbarClimas);

    elOn('btnConfirmarEliminarSeparador', 'click', confirmarEliminarSeparador);
    elOn('btnCancelarEliminarSeparador', 'click', cerrarModalEliminarSeparador);
    
    // Botones de cierre (con verificación de existencia)
    const btnCerrar = document.getElementById('btnCerrar');
    const btnCerrar2 = document.getElementById('btnCerrar2');
    
    if (btnCerrar) btnCerrar.addEventListener('click', cerrarCalendario);
    if (btnCerrar2) btnCerrar2.addEventListener('click', cerrarCalendario);

    inicializarBarraAuthYAdmin();
    
    // Botones de semanas
    document.querySelectorAll('.btn-semana').forEach(btn => {
        btn.addEventListener('click', function() {
            cambiarSemana(parseInt(this.dataset.semana));
        });
    });

    const tablonMain = document.getElementById('tablon-main');
    if (tablonMain) {
        tablonMain.addEventListener('click', function (ev) {
            const el = ev.target.closest('[data-catcal-tab]');
            if (!el || !tablonMain.contains(el)) {
                return;
            }
            const id = el.getAttribute('data-catcal-tab');
            if (id) {
                cambiarPestanaTablon(id);
            }
            const semRaw = el.getAttribute('data-catcal-semana');
            if (semRaw) {
                const n = parseInt(semRaw, 10);
                if (n === 1 || n === 2) {
                    cambiarSemana(n);
                }
            }
        });
    }
    
    // Modals principales (con verificación de existencia)
    const elementosModals = [
        { id: 'btnCancelar', fn: cerrarModal },
        { id: 'btnCancelarMeses', fn: cerrarModalMeses },
        { id: 'btnCancelarClima', fn: cerrarModalClima },
        { id: 'btnCancelarEliminar', fn: cerrarModalEliminar },
        { id: 'btnConfirmarEliminar', fn: confirmarEliminarClase },
        { id: 'btnCancelarEvento', fn: cerrarModalEvento },
        { id: 'btnCancelarSeparador', fn: cerrarModalSeparador },
        { id: 'btnConfirmarEliminarSeparador', fn: confirmarEliminarSeparador },
        { id: 'btnCancelarEliminarSeparador', fn: cerrarModalEliminarSeparador }
    ];
    
    elementosModals.forEach(item => {
        const elemento = document.getElementById(item.id);
        if (elemento) {
            elemento.addEventListener('click', item.fn);
        }
    });
    
    // Forms (con verificación de existencia)
    const elementosForms = [
        { id: 'formEvento', fn: guardarEvento },
        { id: 'formSeparador', fn: guardarSeparador },
        { id: 'formClase', fn: guardarClase },
        { id: 'formMeses', fn: guardarMeses },
        { id: 'formClima', fn: guardarClima },
        { id: 'formClimaHorario', fn: guardarClimaHorario }
    ];
    
    elementosForms.forEach(item => {
        const elemento = document.getElementById(item.id);
        if (elemento) {
            elemento.addEventListener('submit', item.fn);
        }
    });
    
    // Botón guardar (borrador local en GMod)
    const btnGuardar = document.getElementById('btnGuardar');
    if (btnGuardar) {
        btnGuardar.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            console.log('[Calendario] DEBUG: Botón guardar clickeado');
            guardarCalendario();
            return false;
        });
    }

    const btnPublicarTablon = document.getElementById('btnPublicarTablon');
    if (btnPublicarTablon) {
        btnPublicarTablon.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            publicarTablon();
            return false;
        });
    }

    const btnBorrarHorario = document.getElementById('btnBorrarHorario');
    if (btnBorrarHorario) {
        btnBorrarHorario.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            borrarHorarioCompleto();
            return false;
        });
    }
    
    // Cerrar context menu al hacer click fuera
    document.addEventListener('click', function(event) {
        // Solo cerrar si no se hizo click en el context menu mismo
        if (contextMenu && !contextMenu.contains(event.target)) {
            cerrarContextMenu();
        }
    });
    
    // Cerrar context menu con ESC
    document.addEventListener('keydown', function(event) {
        if (event.key === 'Escape') {
            cerrarContextMenu();
        }
    });

    inicializarEditorNormasApartados();
    inicializarModoNormasLecturaEditor();
    inicializarEditorNotasBoletin();
    inicializarModoNotasLecturaEditor();
}

function cambiarSemana(semana) {
    semanaActual = semana;
    document.querySelectorAll('.btn-semana').forEach(btn => {
        btn.classList.toggle('activa', parseInt(btn.dataset.semana) === semana);
    });
    mostrarCalendario();
}

function mostrarCalendario() {
    const semanaIndex = semanaActual - 1;
    const semana = calendarioData.semanas && calendarioData.semanas[semanaIndex];
    try {
        catCalDebugLog('mostrarCalendario: semanaActual=' + semanaActual + ' semanaIndex=' + semanaIndex + ' tieneSemana=' + !!semana + ' numHorarios=' + ((config.horarios && config.horarios.length) || 0));
    } catch (eDbg) {}

    if (!semana) {
        document.getElementById('calendario').innerHTML = '<p>Error: No hay datos para esta semana</p>';
        return;
    }
    
    const calendario = document.getElementById('calendario');
    const numDias = (config.diasSemana || []).length;
    
    // Generar barras de estación
    let htmlBarrasEstacion = '';
    if (semana.barrasEstacion && semana.barrasEstacion.length > 0) {
        htmlBarrasEstacion = '<div class="barras-estacion-container">';
        semana.barrasEstacion.forEach((barra, index) => {
            const iconoEstacion = obtenerIconoEstacion(barra.nombre);
            const colorEstacion = obtenerColorEstacion(barra.nombre);
            const clickHandler = esProfesor ? `onclick="abrirModalBarrasEstacion(${semanaActual})"` : '';
            const cursorStyle = esProfesor ? 'cursor: pointer;' : '';
            const nombreBarra = (typeof barra.nombre === 'string') ? barra.nombre : '';
            htmlBarrasEstacion += `
                <div class="barra-estacion" 
                     ${clickHandler}
                     style="left: calc(120px + (100% - 120px) * ${barra.diaInicio} / ${numDias}); 
                            width: calc((100% - 120px) * ${barra.diasDuracion} / ${numDias}); 
                            background: ${colorEstacion};
                            ${cursorStyle}">
                    ${iconoEstacion} ${nombreBarra}
                    ${esProfesor ? '<br><small style="font-size: 10px;">✏️ Click para editar</small>' : ''}
                </div>
            `;
        });
        htmlBarrasEstacion += '</div>';
    } else if (esProfesor) {
        // Mostrar botón para agregar si no hay barras
        htmlBarrasEstacion = `
            <div class="barras-estacion-container" style="display: flex; align-items: center; justify-content: center;">
                <button onclick="abrirModalBarrasEstacion(${semanaActual})" 
                        style="padding: 10px 20px; background: #d3a625; color: #2c2c2c; border: none; border-radius: 8px; cursor: pointer; font-weight: bold;">
                    + Agregar Barras de Estación
                </button>
            </div>
        `;
    }
    
    let htmlZona = '';
    if (debeMostrarHorarioEnZonaLocal()) {
        const tzVisor = obtenerEtiquetaZonaHorariaVisor();
        htmlZona = '<div class="calendario-zona-aviso" role="status">🕐 Horarios en tu zona horaria'
            + (tzVisor ? ' (' + tzVisor + ')' : '')
            + '. Los datos del servidor están en horario de España (peninsular).</div>';
    }

    let html = htmlZona + htmlBarrasEstacion + `
        <table class="tabla-calendario">
            <thead>
                <tr>
                    <th style="width: 120px;">Horario</th>
    `;
    
    // Encabezados de días con meses
    (config.diasSemana || []).forEach((dia, index) => {
        const diaData = semana.dias && semana.dias[index];
        let mesData = calendarioData.meses && calendarioData.meses[semanaIndex] && calendarioData.meses[semanaIndex][index];
        const mesesDisponibles = config.meses || ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
        if (typeof mesData !== 'string' || !mesData.trim()) {
            mesData = mesesDisponibles[0] || 'Enero';
        }
        
        html += `<th>
            <div class="mes-header" onclick="${esProfesor ? `abrirModalMeses(${semanaActual})` : ''}">
                ${mesData || mesesDisponibles[0] || 'Enero'} 📅
            </div>
            <div class="dia-header" onclick="${esProfesor ? `abrirModalClima(${semanaActual}, ${index + 1})` : ''}">
                ${dia}
                ${esProfesor ? '<br><small>👆 Click para editar clima</small>' : ''}
            </div>
            <div class="info-dia">
                🌡️ ${(diaData && diaData.temperatura) || '--'}°C<br>
                🌙 ${(diaData && diaData.luna) || '--'}<br>
                ${obtenerIconoEvento(diaData && diaData.evento) || '🎉'} ${(diaData && diaData.evento) || '--'}<br>
            </div>
        </th>`;
    });
    
    html += `</tr></thead><tbody>`;
    
    // Filas de horarios con información de debug
    (config.horarios || []).forEach((horario, horarioIndex) => {
        // Calcular duración real para mostrar en debug
        const { inicio: horaInicioStr, fin: horaFinStr } = extraerHorasDelHorario(horario.hora);
        const horarioConfig = config.horarios.find(h => h.hora === horario.hora);
        let duracionTotal = 0;
        
        if (horarioConfig) {
            const horaInicioMinutos = convertirHoraDecimalAMinutos(horarioConfig.inicio);
            const horaFinMinutos = convertirHoraDecimalAMinutos(horarioConfig.fin);
            duracionTotal = horaFinMinutos - horaInicioMinutos;
        }
        
        // Obtener clima de la franja horaria
        let climaHorario = "CLEAR";
        if (calendarioData.climasHorario && calendarioData.climasHorario[horario.hora]) {
            climaHorario = calendarioData.climasHorario[horario.hora];
        } else if (horario.clima) {
            climaHorario = horario.clima;
        }
        
        // Añadir separadores para esta franja horaria
        const separadoresFranja = calendarioData.separadores && calendarioData.separadores[horario.hora];
        if (separadoresFranja) {
            if (Array.isArray(separadoresFranja)) {
                separadoresFranja.forEach(function (separador, rawIndex) {
                    if (separador && separador.texto) {
                        html += generarHTMLSeparador(separador, horario.hora, rawIndex);
                    }
                });
            } else if (separadoresFranja.texto) {
                html += generarHTMLSeparador(separadoresFranja, horario.hora, 0);
            }
        }
        
        // Fila normal de horario con información de debug
        html += `<tr>
            <td style="background: #f8f9fa; font-weight: bold; vertical-align: top; position: relative;">
                <div style="padding: 8px;">
                    ${formatearFranjaHorariaVisor(horario.hora, horarioConfig)}
                    <div style="font-size: 11px; color: #666; margin-top: 3px;">
                        🌤️ ${traducirClima(climaHorario)}
                    </div>
                    <div style="font-size: 10px; color: #888; background: #f0f0f0; padding: 2px 4px; border-radius: 3px; margin-top: 2px;">
                        ${duracionTotal}min
                    </div>
                    ${esProfesor ? `
                        <button class="btn-editar-separador" 
                                onclick="abrirModalClimaHorario(${htmlJsArg(horario.hora)})" 
                                style="position: absolute; top: 5px; right: 5px; background: #17a2b8; color: white; border: none; padding: 2px 6px; border-radius: 3px; font-size: 10px; cursor: pointer;">
                            🌤️
                        </button>
                        <button class="btn-editar-separador" 
                                onclick="abrirModalSeparador(${htmlJsArg(horario.hora)})" 
                                style="position: absolute; top: 5px; right: 30px; background: #740001; color: white; border: none; padding: 2px 6px; border-radius: 3px; font-size: 10px; cursor: pointer;">
                            📏
                        </button>
                    ` : ''}
                </div>
            </td>`;
        
        (config.diasSemana || []).forEach((_, diaIndex) => {
            const diaData = semana.dias && semana.dias[diaIndex];
            
            html += `<td style="vertical-align: top;">`;
            
            if (diaData && diaData.clases && diaData.eventosHorario) {
                const clases = diaData.clases[horario.hora];
                const evento = diaData.eventosHorario[horario.hora];
                
                html += `<div class="clase-container">`;
                
                // Mostrar clases existentes
                if (Array.isArray(clases) && clases.length > 0) {
                    const clasesOrdenadas = clases.slice().sort((a, b) => {
                        const horaA = a.horaExacta || '00:00';
                        const horaB = b.horaExacta || '00:00';
                        return horaA.localeCompare(horaB);
                    });
                    
                    clasesOrdenadas.forEach((clase, claseIndex) => {
                        html += crearHTMLClase(clase, semanaActual, diaIndex + 1, horario.hora, claseIndex);
                    });
                }
                
                // Mostrar eventos si existen
                const eventosArray = diaData.eventosHorario && diaData.eventosHorario[horario.hora] ? 
                    (Array.isArray(diaData.eventosHorario[horario.hora]) ? diaData.eventosHorario[horario.hora] : [diaData.eventosHorario[horario.hora]]) : [];

                if (eventosArray.length > 0) {
                    eventosArray.forEach((evento, eventoIndex) => {
                        if (evento && evento.texto) {
                            const estiloEvento = generarEstiloEvento(evento);
                            html += `
                                <div class="evento ${evento.cursiva ? 'cursiva' : ''}" 
                                    style="${estiloEvento}"
                                    oncontextmenu="${esProfesor ? `mostrarContextMenuEvento(event, this, ${semanaActual}, ${diaIndex + 1}, ${htmlJsArg(horario.hora)}, ${eventoIndex}); return false;` : ''}"
                                    ${esProfesor ? `onclick="abrirModalEventoExistente(${semanaActual}, ${diaIndex + 1}, ${htmlJsArg(horario.hora)}, ${eventoIndex})"` : ''}>
                                    ${evento.texto}
                                    ${esProfesor ? '<div style="font-size:9px;color:#666;">✏️ Click editar | 🔘 Click derecho eliminar</div>' : ''}
                                </div>
                            `;
                        }
                    });
                }
                
                // Botones para agregar
                if (esProfesor) {
                    const clasesArray = diaData.clases[horario.hora] || [];
                    const eventosArray = diaData.eventosHorario && diaData.eventosHorario[horario.hora] ? 
                        (Array.isArray(diaData.eventosHorario[horario.hora]) ? diaData.eventosHorario[horario.hora] : [diaData.eventosHorario[horario.hora]]) : [];
                    
                    html += `
                            <div class="clase-vacia agregar-mas"
                                data-semana="${semanaActual}"
                                data-dia="${diaIndex + 1}"
                                data-horario="${horario.hora}"
                                onclick="abrirModalClaseNueva(this)">
                                + Agregar Clase
                            </div>
                        `;

                    html += `
                            <div class="clase-vacia agregar-evento"
                                data-semana="${semanaActual}"
                                data-dia="${diaIndex + 1}"
                                data-horario="${horario.hora}"
                                onclick="abrirModalEventoNuevo(this)">
                                + Agregar Evento
                            </div>
                        `;
                }
                
                html += `</div>`;
            }
            
            html += `</td>`;
        });
        
        html += `</tr>`;
    });
    
    html += `</tbody></table>`;
    calendario.innerHTML = html;
    
    console.log('📅 Calendario renderizado con información de duraciones');
}



function obtenerIconoEvento(nombreEvento) {
    if (!nombreEvento || !config.eventos) return '🎉';
    
    const evento = config.eventos.find(e => {
        // Manejar tanto el formato antiguo (string) como el nuevo (objeto)
        if (typeof e === 'string') return e === nombreEvento;
        return e.nombre === nombreEvento;
    });
    
    if (!evento) return '🎉';
    
    // Si es string, devolver icono por defecto, si es objeto, devolver su icono
    if (typeof evento === 'string') {
        return obtenerIconoPorDefecto(evento);
    } else {
        return evento.icono || obtenerIconoPorDefecto(evento.nombre);
    }
}

// Función para iconos por defecto (backup)
function obtenerIconoPorDefecto(nombreEvento) {
    const iconosPorDefecto = {
        'Ninguno': '',
        'Navidad': '🎄',
        'Halloween': '🎃',
        'Torneo de los Tres Magos': '⚡',
        'Partido de Quidditch': '🏆',
        'Exámenes Finales': '📚',
        'Fiesta de Bienvenida': '🎉',
        'Baile de Navidad': '💃',
        'Visita a Hogsmeade': '🏘️',
        'Clase de Pociones': '🧪',
        'Clase de Transformaciones': '🦋',
        'Clase de Defensa Contra las Artes Oscuras': '🛡️',
        'Clase de Herbología': '🌿',
        'Clase de Adivinación': '🔮',
        'Clase de Astronomía': '⭐',
        'Clase de Encantamientos': '✨',
        'Clase de Vuelo': '🧹',
        'Clase de Historia de la Magia': '📜',
        'Clase de Cuidado de Criaturas Mágicas': '🐉',
        'Festival de Invierno': '❄️',
        'Celebración de Cumpleaños': '🎂',
        'Concierto del Coro': '🎵',
        'Exposición de Arte Mágico': '🎨',
        'Feria del Libro': '📖',
        'Torneo de Duelo': '⚔️'
    };
    
    return iconosPorDefecto[nombreEvento] || '🎉';
}

// Función para obtener icono de estación
function obtenerIconoEstacion(estacion) {
    const iconosEstaciones = {
        'Primavera': '🌸',
        'Verano': '☀️',
        'Otoño': '🍂',
        'Invierno': '❄️'
    };
    return iconosEstaciones[estacion] || '🌿';
}

// Función para obtener color de estación
function obtenerColorEstacion(estacion) {
    const coloresEstaciones = {
        'Primavera': 'linear-gradient(135deg, #83a4d4, #b6fbff)',
        'Verano': 'linear-gradient(135deg, #f093fb, #f5576c)',
        'Otoño': 'linear-gradient(135deg, #fa709a, #fee140)',
        'Invierno': 'linear-gradient(135deg, #4facfe, #00f2fe)'
    };
    return coloresEstaciones[estacion] || 'linear-gradient(135deg, #667eea, #764ba2)';
}

function crearHTMLClase(clase, semana, dia, horario, claseIndex) {
    const cursos = Array.isArray(clase.cursos) ? clase.cursos : [];
    const cursosHTML = cursos.length > 0 
        ? `<div class="clase-cursos">${cursos.map(curso => 
            `<span class="curso-badge ${curso === 'Todos' ? 'todos' : ''}">${curso}</span>`
          ).join('')}</div>`
        : '';
    
    const horaMostrar = clase.horaExacta ? formatearHoraParaVisor(clase.horaExacta) : '';
    
    const horaHTML = horaMostrar 
        ? `<div class="clase-hora">🕐 ${horaMostrar}</div>`
        : '';
    
    const multiClassIndicator = claseIndex > 0 ? `<div class="multi-clase-indicator">${claseIndex + 1}</div>` : '';
    
    return `
        <div class="clase" 
             data-semana="${semana}"
             data-dia="${dia}"
             data-horario="${horario}"
             data-clase-index="${claseIndex}"
             onmouseover="mostrarTooltip(event, this)"
             onmouseout="ocultarTooltip()"
             oncontextmenu="${esProfesor ? 'mostrarContextMenu(event, this); return false;' : ''}"
             ${esProfesor ? 'onclick="abrirModalClaseExistente(this)"' : ''}>
            ${multiClassIndicator}
            <div class="clase-contenido">
                <div class="clase-titulo">${clase.titulo}</div>
                <div class="clase-detalles">
                    <span>👨‍🏫 ${clase.profesor || 'Sin profesor'}</span>
                    ${horaHTML}
                </div>
                ${cursosHTML}
                ${esProfesor ? '<div style="font-size:9px;color:#666;">✏️ Click editar | 🔘 Click derecho eliminar</div>' : ''}
            </div>
        </div>
    `;
}

// FUNCIÓN COMPLETAMENTE CORREGIDA - Maneja correctamente todas las franjas
function normalizarHoraClase(horaExacta) {
    if (!horaExacta) {
        return '';
    }

    return String(horaExacta).split(':').slice(0, 2).join(':');
}

function cursosClaseSolapan(cursosA, cursosB) {
    const a = Array.isArray(cursosA) ? cursosA.filter(Boolean) : [];
    const b = Array.isArray(cursosB) ? cursosB.filter(Boolean) : [];

    if (!a.length || !b.length) {
        return false;
    }

    if (a.includes('Todos') || b.includes('Todos')) {
        return true;
    }

    return a.some(function (curso) {
        return b.indexOf(curso) !== -1;
    });
}

function obtenerCursosSeleccionadosModal() {
    return Array.from(document.querySelectorAll('#cursosSelector .curso-option.selected'))
        .map(function (opt) {
            const input = opt.querySelector('input');
            return input ? input.value : null;
        })
        .filter(function (curso) {
            return curso !== null;
        });
}

function claseConflictaHorarioCursos(clase, horaNorm, cursosPendientes, claseIndexExcluir, index) {
    if (index === claseIndexExcluir) {
        return false;
    }

    if (!clase || !horaNorm) {
        return false;
    }

    if (normalizarHoraClase(clase.horaExacta) !== horaNorm) {
        return false;
    }

    if (!cursosPendientes || !cursosPendientes.length) {
        return false;
    }

    return cursosClaseSolapan(clase.cursos, cursosPendientes);
}

function refrescarOpcionesHoraModalClase() {
    const modal = document.getElementById('modalClase');

    if (!modal || modal.style.display === 'none') {
        return;
    }

    const semana = document.getElementById('modalSemana').value;
    const dia = document.getElementById('modalDia').value;
    const horario = document.getElementById('modalHorario').value;
    const claseIndex = parseInt(document.getElementById('modalClaseIndex').value, 10) || 0;
    const horaSelect = document.getElementById('horaExactaClaseSelect');
    const horaActual = horaSelect ? horaSelect.value : '';
    const opciones = obtenerOpcionesHorario(
        semana,
        dia,
        horario,
        claseIndex,
        obtenerCursosSeleccionadosModal()
    );

    inicializarSelectorHora(opciones, horaActual);
}

function obtenerContextoModalClase() {
    const semanaEl = document.getElementById('modalSemana');
    const diaEl = document.getElementById('modalDia');
    const horarioEl = document.getElementById('modalHorario');
    const claseIndexEl = document.getElementById('modalClaseIndex');
    const horaSelect = document.getElementById('horaExactaClaseSelect');

    if (!semanaEl || !diaEl || !horarioEl) {
        return null;
    }

    const semana = parseInt(semanaEl.value, 10);
    const dia = parseInt(diaEl.value, 10);
    const horario = horarioEl.value;
    const claseIndex = parseInt(claseIndexEl && claseIndexEl.value, 10);

    if (!semana || !dia || !horario) {
        return null;
    }

    return {
        semanaIndex: semana - 1,
        diaIndex: dia - 1,
        horario: horario,
        claseIndex: isNaN(claseIndex) ? -1 : claseIndex,
        horaNorm: horaSelect ? normalizarHoraClase(horaSelect.value) : ''
    };
}

function obtenerCursosOcupadosEnHora(semanaIndex, diaIndex, horario, horaNorm, claseIndexExcluir) {
    const info = {
        ocupados: {},
        todosOcupado: false,
        hayAlguno: false
    };

    if (!horaNorm) {
        return info;
    }

    const clases = clasesEnFranjaCal(semanaIndex, diaIndex, horario);

    clases.forEach(function (clase, index) {
        if (index === claseIndexExcluir) {
            return;
        }

        if (normalizarHoraClase(clase.horaExacta) !== horaNorm) {
            return;
        }

        info.hayAlguno = true;

        const cursos = Array.isArray(clase.cursos) ? clase.cursos : [];

        if (cursos.includes('Todos')) {
            info.todosOcupado = true;
            return;
        }

        cursos.forEach(function (curso) {
            info.ocupados[curso] = true;
        });
    });

    return info;
}

function cursoEstaBloqueadoEnHora(curso, infoOcupacion) {
    if (!infoOcupacion || (!infoOcupacion.hayAlguno && !infoOcupacion.todosOcupado)) {
        return false;
    }

    if (infoOcupacion.todosOcupado) {
        return true;
    }

    if (curso === 'Todos') {
        return Object.keys(infoOcupacion.ocupados).length > 0;
    }

    return !!infoOcupacion.ocupados[curso];
}

function refrescarSelectorCursosModalClase() {
    const modal = document.getElementById('modalClase');

    if (!modal || modal.style.display === 'none') {
        return;
    }

    inicializarSelectorCursos(obtenerCursosSeleccionadosModal());
}

function obtenerOpcionesHorario(semana, dia, horario, claseIndex, cursosPendientes) {
    const semanaIndex = semana - 1;
    const diaIndex = dia - 1;
    
    const clasesExistentes = clasesEnFranjaCal(semanaIndex, diaIndex, horario);
    
    console.log('🔍 Analizando franja:', horario);
    
    // Extraer horas de inicio y fin del string del horario
    const { inicio: horaInicioStr, fin: horaFinStr } = extraerHorasDelHorario(horario);
    
    // Buscar la configuración completa del horario para obtener los valores decimales
    const horarioConfig = config.horarios.find(h => h.hora === horario);
    let horaInicioMinutos, horaFinMinutos;
    
    if (horarioConfig) {
        // Usar los valores decimales de la configuración
        horaInicioMinutos = convertirHoraDecimalAMinutos(horarioConfig.inicio);
        horaFinMinutos = convertirHoraDecimalAMinutos(horarioConfig.fin);
        console.log('⚙️ Usando configuración decimal:', horarioConfig.inicio, '->', horaInicioMinutos, 'min', horarioConfig.fin, '->', horaFinMinutos, 'min');
    } else {
        // Fallback: calcular desde el string
        horaInicioMinutos = convertirHoraDecimalAMinutos(horaInicioStr);
        horaFinMinutos = convertirHoraDecimalAMinutos(horaFinStr);
        console.log('⚠️ Usando cálculo desde string');
    }
    
    const duracionTotal = horaFinMinutos - horaInicioMinutos;
    
    console.log('⏱️ Duración total calculada:', duracionTotal, 'minutos');
    console.log('📊 Rango:', convertirMinutosAHora(horaInicioMinutos), '-', convertirMinutosAHora(horaFinMinutos));
    
    const pasoMinutos = 15;
    const duracionEtiqueta = Math.min(pasoMinutos, duracionTotal);

    console.log('📚 Franja sin límite de clases; paso de inicio:', pasoMinutos, 'min');

    const opciones = [];
    for (let inicioMinutos = horaInicioMinutos; inicioMinutos < horaFinMinutos; inicioMinutos += pasoMinutos) {
        const finMinutos = Math.min(inicioMinutos + duracionEtiqueta, horaFinMinutos);
        const horaInicio = convertirMinutosAHora(inicioMinutos);
        const horaFin = convertirMinutosAHora(finMinutos);
        const duracionOpcion = finMinutos - inicioMinutos;

        opciones.push({
            value: horaInicio,
            label: `${formatearHoraParaVisor(horaInicio)} - ${formatearHoraParaVisor(horaFin)} (${duracionOpcion} min)`,
            duracion: duracionOpcion
        });

        console.log('➕ Opción generada:', horaInicio, '-', horaFin);
    }
    
    // Bloquear hora solo si choca con los mismos cursos/años (permite misma hora para cursos distintos).
    const opcionesDisponibles = opciones.filter(function (opcion) {
        if (!cursosPendientes || !cursosPendientes.length) {
            const clasesMismaHora = clasesExistentes.filter(function (clase, index) {
                if (index === claseIndex) {
                    return false;
                }

                return normalizarHoraClase(clase.horaExacta) === opcion.value;
            });

            if (!clasesMismaHora.length) {
                return true;
            }

            return !clasesMismaHora.some(function (clase) {
                const cursos = Array.isArray(clase.cursos) ? clase.cursos : [];
                return cursos.includes('Todos');
            });
        }

        return !clasesExistentes.some(function (clase, index) {
            return claseConflictaHorarioCursos(clase, opcion.value, cursosPendientes, claseIndex, index);
        });
    });
    
    console.log('✅ Opciones disponibles:', opcionesDisponibles.map(o => o.value));
    
    return opcionesDisponibles;
}

// Función auxiliar para convertir hora a minutos
function convertirHoraAMinutos(horaStr) {
    const [horas, minutos] = horaStr.split(':').map(Number);
    return (horas * 60) + minutos;
}

// Función para convertir minutos a hora en formato HH:MM
function convertirMinutosAHora(minutos) {
    const horas = Math.floor(minutos / 60);
    const mins = minutos % 60;
    return `${horas.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}`;
}

// Función para convertir hora decimal a minutos
function convertirHoraDecimalAMinutos(horaDecimal) {
    console.log('🔢 Convirtiendo hora decimal:', horaDecimal);
    
    // Si ya es string con formato HH:MM, convertir directamente
    if (typeof horaDecimal === 'string' && horaDecimal.includes(':')) {
        const [horas, minutos] = horaDecimal.split(':').map(Number);
        return (horas * 60) + minutos;
    }
    
    // Si es número decimal (como 20.5 para 20:30)
    const horas = Math.floor(horaDecimal);
    const minutosDecimal = horaDecimal - horas;
    const minutos = Math.round(minutosDecimal * 60);
    
    console.log(`🔢 ${horaDecimal} -> ${horas}h ${minutos}m -> ${(horas * 60) + minutos}min`);
    return (horas * 60) + minutos;
}

// Función para extraer horas de inicio y fin de un horario string
function extraerHorasDelHorario(horarioStr) {
    console.log('📋 Extrayendo horas de:', horarioStr);
    
    // Ejemplo: "20:00 - 20:30" -> ["20:00", "20:30"]
    const partes = horarioStr.split(' - ');
    if (partes.length !== 2) {
        console.error('❌ Formato de horario inválido:', horarioStr);
        return { inicio: '00:00', fin: '00:00' };
    }
    
    return {
        inicio: partes[0].trim(),
        fin: partes[1].trim()
    };
}


function abrirModalClaseNueva(elemento) {
    if (!esProfesor) return;
    
    const semana = elemento.dataset.semana;
    const dia = elemento.dataset.dia;
    const horario = elemento.dataset.horario;
    
    const semanaIndex = semana - 1;
    const diaIndex = dia - 1;
    
    // Obtener el array de clases existentes
    const clasesArray = clasesEnFranjaCal(semanaIndex, diaIndex, horario);

    const opcionesHorario = obtenerOpcionesHorario(semana, dia, horario, -1, []);
    
    if (opcionesHorario.length === 0) {
        mostrarNotificacion('❌ No hay horarios disponibles en esta franja', 'error');
        return;
    }
    
    document.getElementById('modalSemana').value = semana;
    document.getElementById('modalDia').value = dia;
    document.getElementById('modalHorario').value = horario;
    document.getElementById('modalClaseIndex').value = clasesArray.length;
    
    // Limpiar formulario
    document.getElementById('tituloClase').value = "";
    document.getElementById('descripcionClase').value = "";
    document.getElementById('profesorClase').value = "";
    
    // Configurar selector de hora automático
    inicializarSelectorHora(opcionesHorario, "");

    refrescarSelectorCursosModalClase();
    
    document.getElementById('modalClase').style.display = 'block';
    
    console.log('✅ Modal abierto correctamente para nueva clase');
}

// NUEVO: Función para manejar la opción de hora en separadores
function configurarOpcionHoraSeparador() {
    const checkbox = document.getElementById('mostrarHoraSeparador');
    const grupoHorario = document.getElementById('grupoHorarioPersonalizado');
    
    if (checkbox && grupoHorario) {
        checkbox.addEventListener('change', function() {
            grupoHorario.style.display = this.checked ? 'block' : 'none';
            
            // Si se activa y no hay horas configuradas, sugerir la hora actual
            if (this.checked) {
                const horaInicio = document.getElementById('horaInicioSeparador');
                const horaFin = document.getElementById('horaFinSeparador');
                
                if ((!horaInicio.value || !horaFin.value) && separadorParaEditar) {
                    // Extraer hora del horario actual (ej: "08:00 - 09:00")
                    const partes = separadorParaEditar.split(' - ');
                    if (partes.length === 2) {
                        if (!horaInicio.value) {
                            horaInicio.value = partes[0] + ':00';
                        }
                        if (!horaFin.value) {
                            horaFin.value = partes[1] + ':00';
                        }
                    }
                }
            }
        });
    }
}

function obtenerSeparadorEnFranja(horarioKey, separadorIndex) {
    const franja = calendarioData.separadores && calendarioData.separadores[horarioKey];
    if (!franja) {
        return null;
    }

    if (Array.isArray(franja)) {
        if (separadorIndex === null || separadorIndex === undefined) {
            return null;
        }

        return franja[separadorIndex] || null;
    }

    if (separadorIndex === null || separadorIndex === undefined || separadorIndex === 0) {
        return franja;
    }

    return null;
}

function generarHTMLSeparador(separador, horario, separadorIndex) {
    const horarioJs = htmlJsArg(horario);
    const horarioAttr = escAttr(horario);

    let estilo = 'background: #740001; color: white; padding: 12px; height: 50px;';
    if (separador.colorFondo) estilo += `background: ${separador.colorFondo} !important;`;
    if (separador.colorTexto) estilo += `color: ${separador.colorTexto} !important;`;
    estilo += 'border-bottom: 2px solid #d3a625; border-top: 2px solid #d3a625; font-size: 16px; font-weight: bold; text-align: center; vertical-align: middle;';
    
    const numDias = (config.diasSemana || []).length;
    
    let contenido = '';
    
    // Si tiene hora personalizada, mostrarla
    if (separador.mostrarHora) {
        const horaInicioFormateada = formatearHoraParaVisor(separador.horaInicio);
        const horaFinFormateada = formatearHoraParaVisor(separador.horaFin);
        
        let horaMostrar;
        if (horaInicioFormateada && horaFinFormateada) {
            horaMostrar = `${horaInicioFormateada} - ${horaFinFormateada}`;
        } else {
            // ✅ FIX: Si no hay hora personalizada, formatear el horario del config también
            const { inicio, fin } = extraerHorasDelHorario(horario);
            const inicioFormateado = formatearHoraParaVisor(inicio);
            const finFormateado = formatearHoraParaVisor(fin);
            horaMostrar = `${inicioFormateado} - ${finFormateado}`;
        }
        
        contenido = `
            <div style="display: flex; align-items: center; justify-content: space-between; height: 100%; padding: 0 10px;"
                 oncontextmenu="${esProfesor ? `mostrarContextMenuSeparador(event, ${horarioJs}, ${separadorIndex}); return false;` : ''}">
                <div style="background: rgba(0,0,0,0.3); padding: 5px 10px; border-radius: 4px; font-size: 14px; min-width: 120px; text-align: center;">
                    ${horaMostrar}
                </div>
                <span style="font-weight: bold; flex: 1; text-align: center;">${separador.texto}</span>
                ${esProfesor ? `<button class="btn-editar-separador" onclick="event.stopPropagation(); abrirModalSeparador(${horarioJs}, ${separadorIndex})" style="margin-left: 10px;">✏️</button>` : ''}
            </div>
        `;
    } else {
        contenido = `
            <div style="display: flex; align-items: center; justify-content: center; height: 100%; padding: 0 10px;"
                 oncontextmenu="${esProfesor ? `mostrarContextMenuSeparador(event, ${horarioJs}, ${separadorIndex}); return false;` : ''}">
                <span style="font-weight: bold;">${separador.texto}</span>
                ${esProfesor ? `<button class="btn-editar-separador" onclick="event.stopPropagation(); abrirModalSeparador(${horarioJs}, ${separadorIndex})" style="margin-left: 10px;">✏️</button>` : ''}
            </div>
        `;
    }
    
    return `
        <tr class="separador-fila" data-horario="${horarioAttr}" data-separador-index="${separadorIndex}" data-tipo="separador">
            <td colspan="${numDias + 1}" style="${estilo}">
                ${contenido}
            </td>
        </tr>
    `;
}

// ACTUALIZAR la función mostrarContextMenuSeparador
function mostrarContextMenuSeparador(event, horario, separadorIndex) {
    if (!esProfesor) return;
    
    event.preventDefault();
    
    if (contextMenu) {
        contextMenu.remove();
    }
    
    contextMenu = document.createElement('div');
    contextMenu.className = 'context-menu';
    contextMenu.style.position = 'fixed';
    contextMenu.style.left = event.clientX + 'px';
    contextMenu.style.top = event.clientY + 'px';
    
    const horarioJs = htmlJsArg(horario);
    const horarioAttr = escAttr(horario);

    contextMenu.innerHTML = `
        <div class="context-menu-item" onclick="abrirModalSeparador(${horarioJs}, ${separadorIndex})">
            ✏️ Editar Separador
        </div>
        <div class="context-menu-item eliminar" onclick="eliminarSeparador(${horarioJs}, ${separadorIndex})">
            🗑️ Eliminar Separador
        </div>
    `;
    
    document.body.appendChild(contextMenu);
    
    // Resaltar el separador
    const separadorElement = document.querySelector(`.separador-fila[data-horario="${horarioAttr}"][data-separador-index="${separadorIndex}"]`);
    if (separadorElement) {
        separadorElement.classList.add('con-menu-contexto');
    }
}


// ENCONTRAR Y REEMPLAZAR en script.js - Función eliminarSeparador
function eliminarSeparador(horario, separadorIndex = null) {
    if (!esProfesor || !horario) return;

    const separadorData = obtenerSeparadorEnFranja(horario, separadorIndex);

    if (!separadorData) {
        mostrarNotificacion('No se encontró el separador para eliminar', 'error');
        return;
    }

    separadorParaEliminar = { horario: horario, index: separadorIndex };

    const etiqueta = separadorData.texto || 'Separador sin título';
    document.getElementById('textoEliminarSeparador').textContent =
        '¿Estás seguro de que quieres eliminar el separador "' + etiqueta + '"?';

    document.getElementById('modalEliminarSeparador').style.display = 'block';

    cerrarContextMenu();
}

// Y actualizar la función de mostrar modal de eliminación
function mostrarModalEliminarSeparador(horario, separadorIndex = null) {
    if (!esProfesor || !horario) return;

    const separadorData = obtenerSeparadorEnFranja(horario, separadorIndex);
    if (!separadorData) return;

    separadorParaEliminar = { horario: horario, index: separadorIndex };

    const etiqueta = separadorData.texto || 'Separador sin título';
    document.getElementById('textoEliminarSeparador').textContent =
        '¿Estás seguro de que quieres eliminar el separador "' + etiqueta + '"?';

    document.getElementById('modalEliminarSeparador').style.display = 'block';
}

// Función para abrir modal para clase existente
function abrirModalClaseExistente(elemento) {
    if (!esProfesor) return;
    
    const semana = elemento.dataset.semana;
    const dia = elemento.dataset.dia;
    const horario = elemento.dataset.horario;
    const claseIndex = elemento.dataset.claseIndex;
    
    const semanaIndex = semana - 1;
    const diaIndex = dia - 1;
    
    const clasesArray = clasesEnFranjaCal(semanaIndex, diaIndex, horario);
    const claseData = clasesArray && clasesArray[claseIndex] ? clasesArray[claseIndex] : {
        titulo: "",
        descripcion: "",
        profesor: "",
        cursos: [],
        horaExacta: ""
    };
    
    // Obtener opciones de horario disponibles (excluyendo la clase actual)
    const opcionesHorario = obtenerOpcionesHorario(
        semana,
        dia,
        horario,
        parseInt(claseIndex, 10),
        Array.isArray(claseData.cursos) ? claseData.cursos : []
    );
    
    // Normalizar la hora seleccionada (quitar segundos si existen)
    const horaSeleccionadaNormalizada = claseData.horaExacta ? 
        claseData.horaExacta.split(':').slice(0, 2).join(':') : "";
    
    document.getElementById('modalSemana').value = semana;
    document.getElementById('modalDia').value = dia;
    document.getElementById('modalHorario').value = horario;
    document.getElementById('modalClaseIndex').value = claseIndex;
    document.getElementById('tituloClase').value = claseData.titulo || "";
    document.getElementById('descripcionClase').value = claseData.descripcion || "";
    document.getElementById('profesorClase').value = claseData.profesor || "";
    
    // Configurar selector de hora con hora normalizada
    inicializarSelectorHora(opcionesHorario, horaSeleccionadaNormalizada);

    refrescarSelectorCursosModalClase();
    
    document.getElementById('modalClase').style.display = 'block';
}


// FUNCIÓN COMPLETAMENTE CORREGIDA para inicializar selector de hora (NO DESHABILITAR)
function inicializarSelectorHora(opcionesDisponibles, horaSeleccionada) {
    console.log('🕐 Inicializando selector de hora...');
    console.log('📋 Opciones disponibles:', opcionesDisponibles);
    console.log('🎯 Hora seleccionada:', horaSeleccionada);
    
    // Buscar el contenedor existente
    let container = document.getElementById('horaExactaClase');
    
    // Si no existe, crear uno nuevo
    if (!container) {
        console.log('⚠️ Contenedor no encontrado, creando uno nuevo...');
        const formGroup = document.querySelector('#formClase .form-group:nth-child(4)');
        if (formGroup) {
            container = document.createElement('div');
            container.id = 'horaExactaClase';
            formGroup.appendChild(container);
        } else {
            console.error('❌ No se pudo encontrar el formulario para agregar el selector de hora');
            return;
        }
    }
    
    // Limpiar el contenedor
    container.innerHTML = '';
    
    // Crear el elemento select
    const select = document.createElement('select');
    select.id = 'horaExactaClaseSelect';
    select.className = 'hora-selector';
    select.required = true;
    
    // ✅ CORRECCIÓN: NUNCA DESHABILITAR EL SELECTOR, incluso con una sola opción
    // Si solo hay una opción disponible, seleccionarla automáticamente PERO NO DESHABILITAR
    if (opcionesDisponibles.length === 1 && !horaSeleccionada) {
        const unicaOpcion = opcionesDisponibles[0];
        select.innerHTML = `<option value="${unicaOpcion.value}" selected>${unicaOpcion.label}</option>`;
        // ✅ IMPORTANTE: NO deshabilitar el selector
        select.disabled = false; // Mantener habilitado para que se pueda hacer click
        console.log('✅ Una sola opción, seleccionada automáticamente PERO HABILITADA:', unicaOpcion.value);
    } else {
        // Agregar opción vacía si hay múltiples opciones
        if (opcionesDisponibles.length > 1) {
            const emptyOption = document.createElement('option');
            emptyOption.value = "";
            emptyOption.textContent = "Selecciona una hora";
            emptyOption.disabled = true;
            emptyOption.selected = !horaSeleccionada;
            select.appendChild(emptyOption);
        }
        
        // Agregar opciones disponibles
        opcionesDisponibles.forEach(opcion => {
            const option = document.createElement('option');
            option.value = opcion.value;
            option.textContent = opcion.label;
            option.selected = (opcion.value === horaSeleccionada);
            select.appendChild(option);
        });
        
        select.disabled = false;
        console.log('📝 Selector con múltiples opciones creado');
    }
    
    // ✅ AGREGAR ESTILOS PARA INDICAR QUE ES LA ÚNICA OPCIÓN (pero sigue siendo clickeable)
    if (opcionesDisponibles.length === 1) {
        select.style.backgroundColor = '#f8f9fa';
        select.style.borderColor = '#d3a625';
        select.title = 'Esta es la única hora disponible en esta franja';
    }
    
    // Agregar el select al contenedor
    container.appendChild(select);
    
    // Agregar texto de ayuda
    const helpText = document.createElement('small');
    if (opcionesDisponibles.length === 1) {
        helpText.textContent = 'Hora única disponible en esta franja (seleccionada automáticamente)';
        helpText.style.color = '#d3a625';
        helpText.style.fontWeight = 'bold';
    } else {
        helpText.textContent = 'Hora específica dentro de la franja horaria';
    }
    container.appendChild(helpText);

    select.addEventListener('change', function () {
        refrescarSelectorCursosModalClase();
        refrescarOpcionesHoraModalClase();
    });

    refrescarSelectorCursosModalClase();

    console.log('✅ Selector de hora inicializado correctamente (SIEMPRE HABILITADO)');
}

function mostrarContextMenu(event, elemento) {
    event.preventDefault();
    
    if (contextMenu) {
        contextMenu.remove();
    }
    
    contextMenu = document.createElement('div');
    contextMenu.className = 'context-menu';
    contextMenu.style.position = 'fixed';
    contextMenu.style.left = event.clientX + 'px';
    contextMenu.style.top = event.clientY + 'px';
    
    contextMenu.innerHTML = `
        <div class="context-menu-item eliminar" onclick="abrirModalEliminar(this.parentElement)">
            🗑️ Eliminar Clase
        </div>
    `;
    
    // Guardar referencia al elemento para eliminar
    contextMenu.claseElement = elemento;
    
    document.body.appendChild(contextMenu);
}

function abrirModalEliminar(contextMenuElement) {
    const elemento = contextMenuElement.claseElement;
    const semana = elemento.dataset.semana;
    const dia = elemento.dataset.dia;
    const horario = elemento.dataset.horario;
    const claseIndex = elemento.dataset.claseIndex;
    
    const semanaIndex = semana - 1;
    const diaIndex = dia - 1;
    
    const claseData = claseEnFranjaCal(semanaIndex, diaIndex, horario, claseIndex);
    
    if (claseData) {
        claseParaEliminar = { semanaIndex, diaIndex, horario, claseIndex };
        document.getElementById('textoEliminar').textContent = 
            `¿Estás seguro de que quieres eliminar la clase "${claseData.titulo}"?`;
        document.getElementById('modalEliminar').style.display = 'block';
    }
    
    if (contextMenu) {
        contextMenu.remove();
        contextMenu = null;
    }
}

function confirmarEliminarClase() {
    if (claseParaEliminar) {
        const { semanaIndex, diaIndex, horario, claseIndex } = claseParaEliminar;
        
        var dDel = celdaDiaCal(semanaIndex, diaIndex);
        if (dDel && dDel.clases && dDel.clases[horario]) {
            dDel.clases[horario].splice(claseIndex, 1);
        }
        
        claseParaEliminar = null;
        cerrarModalEliminar();
        mostrarCalendario();
    }
}

function abrirModalClima(semana, dia) {
    if (!esProfesor) return;
    
    const semanaIndex = semana - 1;
    const diaIndex = dia - 1;
    
    const diaData = celdaDiaCal(semanaIndex, diaIndex) || {
        temperatura: 20,
        luna: config.lunas ? config.lunas[0] : 'Luna Nueva',
        evento: 'Ninguno'
    };
    
    document.getElementById('modalClimaSemana').value = semana;
    document.getElementById('modalClimaDia').value = dia;
    document.getElementById('temperaturaClima').value = diaData.temperatura || 20;
    
    // Llenar selector de lunas
    const lunaSelect = document.getElementById('lunaClima');
    lunaSelect.innerHTML = '';
    (config.lunas || ['Luna Nueva', 'Luna Creciente', 'Cuarto Creciente', 'Gibosa Creciente', 'Luna Llena', 'Gibosa Menguante', 'Cuarto Menguante', 'Luna Menguante']).forEach(luna => {
        const option = document.createElement('option');
        option.value = luna;
        option.textContent = luna;
        option.selected = luna === diaData.luna;
        lunaSelect.appendChild(option);
    });
    
    // Llenar selector de eventos
    const eventSelect = document.getElementById('eventoClima');
    eventSelect.innerHTML = '';
    (config.eventos || []).forEach(eventoObj => {
        const option = document.createElement('option');
        let nombreEvento, iconoEvento;
        
        if (typeof eventoObj === 'string') {
            nombreEvento = eventoObj;
            iconoEvento = obtenerIconoPorDefecto(eventoObj);
        } else {
            nombreEvento = eventoObj.nombre;
            iconoEvento = eventoObj.icono || obtenerIconoPorDefecto(eventoObj.nombre);
        }
        
        option.value = nombreEvento;
        option.textContent = `${iconoEvento} ${nombreEvento}`;
        option.selected = nombreEvento === (diaData.evento || 'Ninguno');
        eventSelect.appendChild(option);
    });
    
    document.getElementById('modalClima').style.display = 'block';
}

function traducirClima(clima) {
    const traducciones = {
        'EXTRASUNNY': '☀️ Muy Soleado',
        'CLEAR': '🌤️ Despejado', 
        'NEUTRAL': '🌫️ Neutral',
        'SMOG': '🌁 Neblina',
        'FOGGY': '🌫️ Brumoso',
        'OVERCAST': '☁️ Muy Nublado',
        'CLOUDS': '⛅ Nubes',
        'CLEARING': '🌤️ Despejando',
        'RAIN': '🌧️ Lluvia',
        'THUNDER': '⛈️ Tormenta',
        'SNOW': '❄️ Nieve',
        'BLIZZARD': '🌨️ Ventisca',
        'SNOWLIGHT': '🌨️ Nieve Ligera',
        'XMAS': '🎄 Navidad',
        'HALLOWEEN': '🎃 Halloween'
    };
    
    return traducciones[clima] || clima;
}

function inicializarSelectorCursos(cursosSeleccionados) {
    const container = document.getElementById('cursosSelector');
    container.innerHTML = '';

    const ctx = obtenerContextoModalClase();
    let infoOcupacion = { ocupados: {}, todosOcupado: false, hayAlguno: false };

    if (ctx && ctx.horaNorm) {
        infoOcupacion = obtenerCursosOcupadosEnHora(
            ctx.semanaIndex,
            ctx.diaIndex,
            ctx.horario,
            ctx.horaNorm,
            ctx.claseIndex
        );
    }

    cursosSeleccionados = (Array.isArray(cursosSeleccionados) ? cursosSeleccionados : []).filter(function (curso) {
        return !cursoEstaBloqueadoEnHora(curso, infoOcupacion);
    });

    const cursosDisponibles = config.cursos || ['1º', '2º', '3º', '4º', '5º', '6º', '7º', 'Todos'];

    cursosDisponibles.forEach(curso => {
        const bloqueado = ctx && ctx.horaNorm && cursoEstaBloqueadoEnHora(curso, infoOcupacion);
        const isSelected = !bloqueado && cursosSeleccionados.includes(curso);
        const option = document.createElement('div');
        option.className = `curso-option ${isSelected ? 'selected' : ''} ${curso === 'Todos' ? 'todos' : ''}${bloqueado ? ' bloqueado' : ''}`;

        if (bloqueado) {
            option.title = 'Ya hay una clase a esta hora para este curso/año';
        }

        option.innerHTML = `
            <input type="checkbox" ${isSelected ? 'checked' : ''} value="${curso}" style="display: none;"${bloqueado ? ' disabled' : ''}>
            ${curso}
        `;
        option.addEventListener('click', function() {
            if (this.classList.contains('bloqueado')) {
                mostrarNotificacion('❌ Ese curso/año ya tiene clase a esta hora', 'error');
                return;
            }

            const checkbox = this.querySelector('input');

            if (curso === 'Todos' && !checkbox.checked) {
                document.querySelectorAll('#cursosSelector .curso-option').forEach(opt => {
                    if (opt !== this && !opt.classList.contains('bloqueado')) {
                        const otherCheckbox = opt.querySelector('input');
                        otherCheckbox.checked = false;
                        opt.classList.remove('selected');
                    }
                });
                checkbox.checked = true;
                this.classList.add('selected');
            }
            else if (curso !== 'Todos' && !checkbox.checked) {
                const todosOption = document.querySelector('#cursosSelector .curso-option.todos');
                if (todosOption && !todosOption.classList.contains('bloqueado')) {
                    const todosCheckbox = todosOption.querySelector('input');
                    todosCheckbox.checked = false;
                    todosOption.classList.remove('selected');
                }
                checkbox.checked = true;
                this.classList.add('selected');
            }
            else {
                checkbox.checked = !checkbox.checked;
                this.classList.toggle('selected', checkbox.checked);
            }

            refrescarOpcionesHoraModalClase();
        });
        container.appendChild(option);
    });
}

function abrirModalMeses(semana) {
    if (!esProfesor) return;
    
    document.getElementById('modalMesesSemana').value = semana;
    
    const semanaIndex = semana - 1;
    const mesesSemana = calendarioData.meses && calendarioData.meses[semanaIndex];
    const mesesDisponibles = config.meses || ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    
    const container = document.getElementById('mesesSelector');
    container.innerHTML = '';
    
    (config.diasSemana || []).forEach((dia, index) => {
        const mesActual = mesesSemana && mesesSemana[index] ? mesesSemana[index] : mesesDisponibles[0];
        
        const diaDiv = document.createElement('div');
        diaDiv.className = 'form-group';
        diaDiv.innerHTML = `
            <label>${dia}:</label>
            <select class="mes-select" data-dia="${index}">
                ${mesesDisponibles.map(mes => 
                    `<option value="${mes}" ${mes === mesActual ? 'selected' : ''}>${mes}</option>`
                ).join('')}
            </select>
        `;
        container.appendChild(diaDiv);
    });
    
    document.getElementById('modalMeses').style.display = 'block';
}

// Funciones para manejar selectores de color personalizados
function inicializarSelectoresColor() {
    // Selectores para separador
    inicializarSelectorColor(
        'colorFondoSeparadorPicker',
        'colorFondoSeparadorHex', 
        'colorFondoPreview',
        '#740001'
    );
    
    inicializarSelectorColor(
        'colorTextoSeparadorPicker',
        'colorTextoSeparadorHex',
        'colorTextoPreview', 
        '#ffffff'
    );
    
    // Selectores para evento
    inicializarSelectorColor(
        'colorFondoEventoPicker',
        'colorFondoEventoHex',
        'colorFondoEventoPreview',
        '#fff3cd'
    );
    
    inicializarSelectorColor(
        'colorTextoEventoPicker', 
        'colorTextoEventoHex',
        'colorTextoEventoPreview',
        '#000000'
    );
}

// MEJORADO: Función para formatear hora con minutos
function formatearHoraConMinutos(horaString) {
    if (!horaString) return '';
    
    // Si ya está en formato HH:MM, devolverlo
    if (horaString.includes(':')) {
        let [horas, minutos] = horaString.split(':');
        
        // ✅ FIX: Convertir cualquier hora "12:xx" a "00:xx" (medianoche)
        // Esto corrige el problema donde medianoche se muestra como "12:00", "12:15", "12:20", etc.
        // en lugar de "00:00", "00:15", "00:20", etc.
        // Nota: En este calendario no hay horas de mediodía (12:xx PM), así que es seguro convertir todas
        if (horas === '12') {
            horas = '00';
        }
        
        return `${horas.padStart(2, '0')}:${minutos.padStart(2, '0')}`;
    }
    
    return horaString;
}


function inicializarSelectorColor(pickerId, hexId, previewId, colorDefault) {
    const picker = document.getElementById(pickerId);
    const hexInput = document.getElementById(hexId);
    const preview = document.getElementById(previewId);
    
    if (!picker || !hexInput || !preview) return;
    
    // Establecer valor por defecto
    picker.value = colorDefault;
    hexInput.value = colorDefault;
    preview.style.backgroundColor = colorDefault;
    
    // Cuando cambia el picker de color
    picker.addEventListener('input', function() {
        hexInput.value = this.value;
        preview.style.backgroundColor = this.value;
    });
    
    // Cuando se escribe manualmente el hex
    hexInput.addEventListener('input', function() {
        const color = this.value;
        if (/^#[0-9A-F]{6}$/i.test(color)) {
            picker.value = color;
            preview.style.backgroundColor = color;
        }
    });
    
    // Validar formato hex al perder foco
    hexInput.addEventListener('blur', function() {
        if (!/^#[0-9A-F]{6}$/i.test(this.value)) {
            this.value = picker.value; // Revertir al valor válido
        }
    });
}

function obtenerLimiteClasesPorFranja(horario) {
    const horarioConfig = config.horarios.find(h => h.hora === horario);

    if (!horarioConfig) {
        return Number.MAX_SAFE_INTEGER;
    }

    const horaInicioMinutos = convertirHoraDecimalAMinutos(horarioConfig.inicio);
    const horaFinMinutos = convertirHoraDecimalAMinutos(horarioConfig.fin);
    const duracionTotal = horaFinMinutos - horaInicioMinutos;
    const pasoMinutos = 15;

    return Math.max(1, Math.ceil(duracionTotal / pasoMinutos));
}

function guardarClase(event) {
    event.preventDefault();
    
    const semana = document.getElementById('modalSemana').value;
    const dia = document.getElementById('modalDia').value;
    const horario = document.getElementById('modalHorario').value;
    const claseIndex = parseInt(document.getElementById('modalClaseIndex').value) || 0;
    
    const semanaIndex = semana - 1;
    const diaIndex = dia - 1;
    
    // Obtener cursos seleccionados
    const cursosSeleccionados = Array.from(document.querySelectorAll('#cursosSelector .curso-option.selected'))
        .map(opt => {
            const input = opt.querySelector('input');
            return input ? input.value : null;
        })
        .filter(curso => curso !== null);
    
    // Asegurar estructura
    if (!calendarioData.semanas) calendarioData.semanas = [];
    if (!calendarioData.semanas[semanaIndex]) calendarioData.semanas[semanaIndex] = {dias: []};
    if (!calendarioData.semanas[semanaIndex].dias[diaIndex]) calendarioData.semanas[semanaIndex].dias[diaIndex] = {clases: {}};
    if (!calendarioData.semanas[semanaIndex].dias[diaIndex].clases[horario]) {
        calendarioData.semanas[semanaIndex].dias[diaIndex].clases[horario] = [];
    }
    
    const horaExactaSelect = document.getElementById('horaExactaClaseSelect');
    const horaExacta = horaExactaSelect ? horaExactaSelect.value.split(':').slice(0, 2).join(':') : "";

    if (horaExacta && cursosSeleccionados.length > 0) {
        const clasesFranja = calendarioData.semanas[semanaIndex].dias[diaIndex].clases[horario] || [];
        const conflicto = clasesFranja.some(function (clase, idx) {
            if (idx === claseIndex) {
                return false;
            }

            if (normalizarHoraClase(clase.horaExacta) !== horaExacta) {
                return false;
            }

            return cursosClaseSolapan(clase.cursos, cursosSeleccionados);
        });

        if (conflicto) {
            mostrarNotificacion('❌ Ya hay una clase a esa hora para los mismos cursos/años', 'error');
            return;
        }
    }

    console.log('💾 Guardando clase con hora:', horaExacta);
    
    const nuevaClase = {
        titulo: document.getElementById('tituloClase').value,
        descripcion: document.getElementById('descripcionClase').value,
        profesor: document.getElementById('profesorClase').value,
        cursos: cursosSeleccionados,
        horaExacta: horaExacta
    };
    
    // Si es una clase existente, reemplazarla, sino agregar nueva
    if (claseIndex < calendarioData.semanas[semanaIndex].dias[diaIndex].clases[horario].length) {
        calendarioData.semanas[semanaIndex].dias[diaIndex].clases[horario][claseIndex] = nuevaClase;
    } else {
        calendarioData.semanas[semanaIndex].dias[diaIndex].clases[horario].push(nuevaClase);
    }
    
    // Ordenar las clases por hora exacta después de guardar
    calendarioData.semanas[semanaIndex].dias[diaIndex].clases[horario].sort((a, b) => {
        const horaA = a.horaExacta || '00:00';
        const horaB = b.horaExacta || '00:00';
        return horaA.localeCompare(horaB);
    });
    
    cerrarModal();
    mostrarCalendario();
    mostrarNotificacion('Clase guardada correctamente', 'success');
}

function guardarMeses(event) {
    event.preventDefault();
    
    const semana = document.getElementById('modalMesesSemana').value;
    const semanaIndex = semana - 1;
    
    if (!calendarioData.meses) calendarioData.meses = [];
    if (!calendarioData.meses[semanaIndex]) calendarioData.meses[semanaIndex] = [];
    
    document.querySelectorAll('.mes-select').forEach(select => {
        const diaIndex = parseInt(select.dataset.dia);
        calendarioData.meses[semanaIndex][diaIndex] = select.value;
    });
    
    cerrarModalMeses();
    mostrarCalendario();
}

function guardarClima(event) {
    event.preventDefault();
    
    const semana = document.getElementById('modalClimaSemana').value;
    const dia = document.getElementById('modalClimaDia').value;
    
    const semanaIndex = semana - 1;
    const diaIndex = dia - 1;
    
    // Asegurar que existe la estructura
    if (!calendarioData.semanas[semanaIndex]) {
        calendarioData.semanas[semanaIndex] = { dias: [] };
    }
    if (!calendarioData.semanas[semanaIndex].dias[diaIndex]) {
        calendarioData.semanas[semanaIndex].dias[diaIndex] = {};
    }
    
    // Actualizar datos
    calendarioData.semanas[semanaIndex].dias[diaIndex].temperatura = parseInt(document.getElementById('temperaturaClima').value);
    calendarioData.semanas[semanaIndex].dias[diaIndex].luna = document.getElementById('lunaClima').value;
    calendarioData.semanas[semanaIndex].dias[diaIndex].evento = document.getElementById('eventoClima').value;
    
    cerrarModalClima();
    mostrarCalendario();
    mostrarNotificacion('Información del día guardada correctamente', 'success');
}

function mostrarTooltip(event, elemento) {
    if (tooltipElement) tooltipElement.remove();
    
    const semana = elemento.dataset.semana;
    const dia = elemento.dataset.dia;
    const horario = elemento.dataset.horario;
    const claseIndex = elemento.dataset.claseIndex;
    
    const semanaIndex = semana - 1;
    const diaIndex = dia - 1;
    
    const claseData = claseEnFranjaCal(semanaIndex, diaIndex, horario, claseIndex);
    
    if (!claseData) return;
    
    const cursos = Array.isArray(claseData.cursos) ? claseData.cursos : [];
    const cursosHTML = cursos.length > 0 
        ? `<div class="tooltip-cursos"><strong>Cursos:</strong> ${cursos.join(', ')}</div>`
        : '';
    
    const horaHTML = claseData.horaExacta 
        ? `<p><strong>Hora exacta:</strong> ${claseData.horaExacta}</p>`
        : '';
    
    tooltipElement = document.createElement('div');
    tooltipElement.className = 'tooltip';
    tooltipElement.innerHTML = `
        <h4>${claseData.titulo}</h4>
        <p><strong>Profesor:</strong> ${claseData.profesor || 'No asignado'}</p>
        <p><strong>Descripción:</strong> ${claseData.descripcion || 'Sin descripción'}</p>
        ${horaHTML}
        <p><strong>Horario:</strong> ${horario}</p>
        <p><strong>Día:</strong> ${(config.diasSemana || [])[diaIndex] || 'Día ' + (diaIndex + 1)}</p>
        ${cursosHTML}
    `;
    
    document.body.appendChild(tooltipElement);
    
    const rect = elemento.getBoundingClientRect();
    tooltipElement.style.left = (rect.left + 10) + 'px';
    tooltipElement.style.top = (rect.bottom + 5) + 'px';
}

function cerrarModal() {
    document.getElementById('modalClase').style.display = 'none';
}

function cerrarModalMeses() {
    document.getElementById('modalMeses').style.display = 'none';
}

function cerrarModalClima() {
    document.getElementById('modalClima').style.display = 'none';
}

function cerrarModalEliminar() {
    document.getElementById('modalEliminar').style.display = 'none';
    claseParaEliminar = null;
}

function cerrarCalendario() {
    console.log('[Calendario] DEBUG: cerrarCalendario() llamado, MODO_WEB =', MODO_WEB);
    if (MODO_WEB) {
        // En modo web, solo ocultar (no hay que cerrar NUI)
        console.log('[Calendario] DEBUG: Modo web, ocultando body');
        document.body.style.display = 'none';
    } else if (typeof gmod !== 'undefined' && gmod && typeof gmod.CalCerrar === 'function') {
        gmod.CalCerrar();
    } else {
        // En modo FiveM, simplemente llamar al callback y dejar que el cliente maneje el cierre
        // NO ocultar el body aquí, el cliente lo hará con SendNUIMessage
        console.log('[Calendario] DEBUG: Modo FiveM detectado, obteniendo resourceName...');
        let resourceName = 'cat_calendario'; // Valor por defecto
        try {
            console.log('[Calendario] DEBUG: Intentando llamar GetParentResourceName()...');
            const url = window.location.href;
            console.log('[Calendario] DEBUG: URL actual:', url);
            
            // Extraer directamente de la URL sin usar GetParentResourceName()
            if (url.includes('cfx-nui')) {
                const match = url.match(/cfx-nui-([^/]+)/);
                if (match && match[1]) {
                    resourceName = match[1];
                    console.log('[Calendario] DEBUG: ResourceName extraído de URL:', resourceName);
                } else {
                    console.log('[Calendario] DEBUG: No se pudo extraer de URL, usando por defecto');
                }
            }
            
            // No usar la función nativa ya que está causando bloqueos
            // El resourceName extraído de la URL es suficiente
            console.log('[Calendario] DEBUG: Usando resourceName extraído de URL (sin función nativa para evitar bloqueos)');
            
            console.log('[Calendario] DEBUG: ResourceName final:', resourceName);
        } catch (e) {
            console.error('[Calendario] DEBUG: Error al obtener resourceName:', e);
            console.error('[Calendario] DEBUG: Stack trace:', e.stack);
            console.log('[Calendario] DEBUG: Usando resourceName por defecto:', resourceName);
        }
        
        console.log('[Calendario] DEBUG: Verificando condiciones... resourceName existe?', !!resourceName, 'es web-mode?', resourceName === 'web-mode', 'es unknown?', resourceName === 'unknown');
        
        if (resourceName && resourceName !== 'web-mode' && resourceName !== 'unknown') {
            try {
                const url = `https://${resourceName}/cerrarCalendario`;
                console.log('[Calendario] DEBUG: Enviando fetch a', url);
                const fetchPromise = fetch(url, {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json; charset=UTF-8'},
                    body: JSON.stringify({})
                });
                console.log('[Calendario] DEBUG: Fetch iniciado, esperando respuesta...');
                fetchPromise
                .then(response => {
                    console.log('[Calendario] DEBUG: Respuesta recibida, status =', response.status, 'ok =', response.ok);
                    if (!response.ok) {
                        console.error('[Calendario] Error al cerrar calendario:', response.status);
                    }
                    return response.json();
                })
                .then(data => {
                    console.log('[Calendario] DEBUG: Datos de respuesta:', data);
                })
                .catch(error => {
                    console.error('[Calendario] DEBUG: Error en fetch:', error);
                    console.error('[Calendario] DEBUG: Stack trace:', error.stack);
                });
            } catch (e) {
                console.error('[Calendario] DEBUG: Error al intentar cerrar (catch):', e);
                console.error('[Calendario] DEBUG: Stack trace:', e.stack);
            }
        } else {
            console.log('[Calendario] DEBUG: resourceName inválido, no se puede cerrar. resourceName =', resourceName);
        }
    }
}

// Guardar cambios - ELIMINADO (duplicado, ya está en guardarCalendario())
// El botón ya está configurado en inicializarEventos() para llamar a guardarCalendario()

function mostrarNotificacion(mensaje, tipo) {
    const notificacion = document.createElement('div');
    notificacion.style.cssText = `
        position: fixed; top: 20px; right: 20px; padding: 15px 20px;
        background: ${tipo === 'success' ? '#28a745' : '#dc3545'};
        color: white; border-radius: 5px; z-index: 10000; font-weight: bold;
    `;
    notificacion.textContent = mensaje;
    document.body.appendChild(notificacion);
    setTimeout(() => notificacion.remove(), 3000);
}

function ocultarTooltip() {
    if (tooltipElement) {
        tooltipElement.remove();
        tooltipElement = null;
    }
}

function generarEstiloEvento(evento) {
    let estilo = '';
    if (evento.colorFondo) estilo += `background: ${evento.colorFondo};`;
    if (evento.colorTexto) estilo += `color: ${evento.colorTexto};`;
    if (evento.tamanoTexto) estilo += `font-size: ${evento.tamanoTexto};`;
    return estilo;
}

function generarEstiloSeparador(separador) {
    let estilo = 'background: #740001; color: white; padding: 12px; height: 50px;';
    if (separador.colorFondo) estilo += `background: ${separador.colorFondo} !important;`;
    if (separador.colorTexto) estilo += `color: ${separador.colorTexto} !important;`;
    if (separador.cursiva) estilo += 'font-style: italic;';
    estilo += 'border-bottom: 2px solid #d3a625; border-top: 2px solid #d3a625; font-size: 16px; font-weight: bold; text-align: center; vertical-align: middle;';
    return estilo;
}

// // Función para cambiar altura del separador
// function cambiarAlturaSeparador(horario) {
//     if (!esProfesor) return;
    
//     const separador = calendarioData.separadores && calendarioData.separadores[horario];
//     if (!separador || !separador.texto) return;
    
//     const alturas = config.alturasSeparador || [
//         {nombre: "Delgado", valor: "30px"},
//         {nombre: "Normal", valor: "40px"},
//         {nombre: "Alto", valor: "50px"},
//         {nombre: "Muy Alto", valor: "60px"}
//     ];
    
//     // Encontrar la altura actual y cambiar a la siguiente
//     const alturaActual = separador.altura || "40px";
//     let siguienteAltura = alturas[0].valor; // Por defecto la primera
    
//     for (let i = 0; i < alturas.length; i++) {
//         if (alturas[i].valor === alturaActual) {
//             siguienteAltura = alturas[(i + 1) % alturas.length].valor;
//             break;
//         }
//     }
    
//     separador.altura = siguienteAltura;
//     mostrarCalendario();
    
//     mostrarNotificacion(`Altura del separador cambiada a: ${obtenerNombreAltura(siguienteAltura)}`, 'success');
// }

function obtenerNombreAltura(valorAltura) {
    const alturas = config.alturasSeparador || [
        {nombre: "Delgado", valor: "30px"},
        {nombre: "Normal", valor: "40px"},
        {nombre: "Alto", valor: "50px"},
        {nombre: "Muy Alto", valor: "60px"}
    ];
    
    const altura = alturas.find(a => a.valor === valorAltura);
    return altura ? altura.nombre : "Normal";
}

function abrirModalEventoNuevo(elemento) {
    if (!esProfesor) return;
    
    const semana = elemento.dataset.semana;
    const dia = elemento.dataset.dia;
    const horario = elemento.dataset.horario;
    
    const semanaIndex = semana - 1;
    const diaIndex = dia - 1;
    const eventosArray = eventosHorarioComoArray(semanaIndex, diaIndex, horario);
    const eventosActivos = eventosArray.filter(evento => evento && evento.texto).length;

    document.getElementById('modalEventoSemana').value = semana;
    document.getElementById('modalEventoDia').value = dia;
    document.getElementById('modalEventoHorario').value = horario;
    document.getElementById('modalEventoIndex').value = eventosActivos; // Nuevo campo para índice del evento
    
    // Limpiar formulario
    document.getElementById('textoEvento').value = "";
    document.getElementById('cursivaEvento').checked = false;
    
    // Inicializar selectores de color con valores por defecto
    if (document.getElementById('colorFondoEventoPicker')) {
        document.getElementById('colorFondoEventoPicker').value = "#fff3cd";
        document.getElementById('colorFondoEventoHex').value = "#fff3cd";
        document.getElementById('colorFondoEventoPreview').style.backgroundColor = "#fff3cd";
    }
    
    if (document.getElementById('colorTextoEventoPicker')) {
        document.getElementById('colorTextoEventoPicker').value = "#000000";
        document.getElementById('colorTextoEventoHex').value = "#000000";
        document.getElementById('colorTextoEventoPreview').style.backgroundColor = "#000000";
    }
    
    document.getElementById('modalEvento').style.display = 'block';
}

// Nueva función específica para inicializar colores en modal de evento
function inicializarSelectoresColorModalEvento(colorFondo, colorTexto) {
    // Selector de color de fondo
    const fondoPicker = document.getElementById('colorFondoEventoPicker');
    const fondoHex = document.getElementById('colorFondoEventoHex');
    const fondoPreview = document.getElementById('colorFondoEventoPreview');
    
    if (fondoPicker && fondoHex && fondoPreview) {
        fondoPicker.value = colorFondo;
        fondoHex.value = colorFondo;
        fondoPreview.style.backgroundColor = colorFondo;
        
        fondoPicker.addEventListener('input', function() {
            fondoHex.value = this.value;
            fondoPreview.style.backgroundColor = this.value;
        });
        
        fondoHex.addEventListener('input', function() {
            const color = this.value;
            if (/^#[0-9A-F]{6}$/i.test(color)) {
                fondoPicker.value = color;
                fondoPreview.style.backgroundColor = color;
            }
        });
    }
    
    // Selector de color de texto
    const textoPicker = document.getElementById('colorTextoEventoPicker');
    const textoHex = document.getElementById('colorTextoEventoHex');
    const textoPreview = document.getElementById('colorTextoEventoPreview');
    
    if (textoPicker && textoHex && textoPreview) {
        textoPicker.value = colorTexto;
        textoHex.value = colorTexto;
        textoPreview.style.backgroundColor = colorTexto;
        
        textoPicker.addEventListener('input', function() {
            textoHex.value = this.value;
            textoPreview.style.backgroundColor = this.value;
        });
        
        textoHex.addEventListener('input', function() {
            const color = this.value;
            if (/^#[0-9A-F]{6}$/i.test(color)) {
                textoPicker.value = color;
                textoPreview.style.backgroundColor = color;
            }
        });
    }
}

function abrirModalEventoExistente(semana, dia, horario, eventoIndex) {
    if (!esProfesor) return;
    
    const semanaIndex = semana - 1;
    const diaIndex = dia - 1;
    
    // ✅ FIX: Obtener el evento específico del array
    const eventosArray = eventosHorarioComoArray(semanaIndex, diaIndex, horario);
    
    const eventoData = eventosArray[eventoIndex] || {
        texto: "",
        colorFondo: "#fff3cd",
        colorTexto: "#000000",
        cursiva: false
    };
    
    document.getElementById('modalEventoSemana').value = semana;
    document.getElementById('modalEventoDia').value = dia;
    document.getElementById('modalEventoHorario').value = horario;
    document.getElementById('modalEventoIndex').value = eventoIndex; // Nuevo campo para índice del evento
    
    document.getElementById('textoEvento').value = eventoData.texto || "";
    document.getElementById('cursivaEvento').checked = eventoData.cursiva || false;
    
    // Inicializar selectores de color
    inicializarSelectoresColor();
    
    // Establecer colores existentes
    if (eventoData.colorFondo) {
        document.getElementById('colorFondoEventoPicker').value = eventoData.colorFondo;
        document.getElementById('colorFondoEventoHex').value = eventoData.colorFondo;
        document.getElementById('colorFondoEventoPreview').style.backgroundColor = eventoData.colorFondo;
    }
    
    if (eventoData.colorTexto) {
        document.getElementById('colorTextoEventoPicker').value = eventoData.colorTexto;
        document.getElementById('colorTextoEventoHex').value = eventoData.colorTexto;
        document.getElementById('colorTextoEventoPreview').style.backgroundColor = eventoData.colorTexto;
    }
    
    document.getElementById('modalEvento').style.display = 'block';
}

function abrirModalSeparador(horario, separadorIndex = null) {
    if (!esProfesor) return;
    
    separadorParaEditar = { horario, index: separadorIndex };
    
    // ✅ FIX: Obtener el separador específico o crear uno nuevo
    let separadorData = {
        texto: "",
        colorFondo: "#740001",
        colorTexto: "#ffffff",
        cursiva: false,
        mostrarHora: false,
        horaInicio: "",
        horaFin: ""
    };
    
    const separadoresFranja = calendarioData.separadores && calendarioData.separadores[horario];
    if (separadoresFranja) {
        if (Array.isArray(separadoresFranja)) {
            // Si es un array y tenemos un índice válido, obtener ese separador
            if (separadorIndex !== null && separadoresFranja[separadorIndex]) {
                separadorData = Object.assign({}, separadorData, separadoresFranja[separadorIndex]);
            }
        } else if (separadorIndex === null || separadorIndex === 0) {
            // Si es un objeto individual y es el primer separador (o nuevo)
            separadorData = Object.assign({}, separadorData, separadoresFranja);
        }
    }
    
    // Llenar selector de textos predefinidos
    const textoSeparador = document.getElementById('textoSeparador');
    if (textoSeparador) {
        textoSeparador.innerHTML = '<option value="">Sin separador</option>';
        (config.separadores || []).forEach(sep => {
            const option = document.createElement('option');
            option.value = sep;
            option.textContent = sep;
            option.selected = sep === separadorData.texto;
            textoSeparador.appendChild(option);
        });
    }
    
    const textoPersonalizado = document.getElementById('textoSeparadorPersonalizado');
    if (textoPersonalizado) {
        textoPersonalizado.value = (config.separadores || []).includes(separadorData.texto) ? "" : separadorData.texto;
    }
    
    // Configurar opción de hora
    const mostrarHoraCheckbox = document.getElementById('mostrarHoraSeparador');
    const grupoHorario = document.getElementById('grupoHorarioPersonalizado');
    
    if (mostrarHoraCheckbox) {
        mostrarHoraCheckbox.checked = separadorData.mostrarHora || false;
        grupoHorario.style.display = separadorData.mostrarHora ? 'block' : 'none';
    }
    
    // MEJORADO: Configurar horas personalizadas con minutos
    const horaInicio = document.getElementById('horaInicioSeparador');
    const horaFin = document.getElementById('horaFinSeparador');
    
    if (horaInicio && horaFin) {
        // Convertir formato de hora si es necesario
        // ✅ FIX: Formatear las horas antes de cargarlas en el input para corregir "12:xx" a "00:xx"
        let horaInicioValue = formatearHoraConMinutos(separadorData.horaInicio || "");
        let horaFinValue = formatearHoraConMinutos(separadorData.horaFin || "");
        
        // Si la hora está en formato HH:MM sin segundos, convertir a formato time
        if (horaInicioValue && horaInicioValue.length === 5 && horaInicioValue.includes(':')) {
            horaInicioValue += ':00'; // Añadir segundos para input type="time"
        }
        if (horaFinValue && horaFinValue.length === 5 && horaFinValue.includes(':')) {
            horaFinValue += ':00'; // Añadir segundos para input type="time"
        }
        
        horaInicio.value = horaInicioValue;
        horaFin.value = horaFinValue;
    }
    
    // Inicializar selectores de color para separador
    inicializarSelectoresColorModalSeparador(
        separadorData.colorFondo || "#740001",
        separadorData.colorTexto || "#ffffff"
    );
    
    // Configurar evento para el checkbox
    configurarOpcionHoraSeparador();
    
    document.getElementById('modalSeparador').style.display = 'block';
}

// Nueva función específica para inicializar colores en modal de separador
function inicializarSelectoresColorModalSeparador(colorFondo, colorTexto) {
    // Selector de color de fondo
    const fondoPicker = document.getElementById('colorFondoSeparadorPicker');
    const fondoHex = document.getElementById('colorFondoSeparadorHex');
    const fondoPreview = document.getElementById('colorFondoPreview');
    
    if (fondoPicker && fondoHex && fondoPreview) {
        fondoPicker.value = colorFondo;
        fondoHex.value = colorFondo;
        fondoPreview.style.backgroundColor = colorFondo;
        
        fondoPicker.addEventListener('input', function() {
            fondoHex.value = this.value;
            fondoPreview.style.backgroundColor = this.value;
        });
        
        fondoHex.addEventListener('input', function() {
            const color = this.value;
            if (/^#[0-9A-F]{6}$/i.test(color)) {
                fondoPicker.value = color;
                fondoPreview.style.backgroundColor = color;
            }
        });
    }
    
    // Selector de color de texto
    const textoPicker = document.getElementById('colorTextoSeparadorPicker');
    const textoHex = document.getElementById('colorTextoSeparadorHex');
    const textoPreview = document.getElementById('colorTextoPreview');
    
    if (textoPicker && textoHex && textoPreview) {
        textoPicker.value = colorTexto;
        textoHex.value = colorTexto;
        textoPreview.style.backgroundColor = colorTexto;
        
        textoPicker.addEventListener('input', function() {
            textoHex.value = this.value;
            textoPreview.style.backgroundColor = this.value;
        });
        
        textoHex.addEventListener('input', function() {
            const color = this.value;
            if (/^#[0-9A-F]{6}$/i.test(color)) {
                textoPicker.value = color;
                textoPreview.style.backgroundColor = color;
            }
        });
    }
}

function guardarEvento(event) {
    event.preventDefault();
    
    const semana = document.getElementById('modalEventoSemana').value;
    const dia = document.getElementById('modalEventoDia').value;
    const horario = document.getElementById('modalEventoHorario').value;
    const eventoIndex = parseInt(document.getElementById('modalEventoIndex').value) || 0;
    
    const semanaIndex = semana - 1;
    const diaIndex = dia - 1;
    
    // Asegurar estructura
    if (!calendarioData.semanas[semanaIndex]) calendarioData.semanas[semanaIndex] = {dias: []};
    if (!calendarioData.semanas[semanaIndex].dias[diaIndex]) calendarioData.semanas[semanaIndex].dias[diaIndex] = {eventosHorario: {}};
    
    // ✅ FIX: Convertir a array si es necesario
    if (!Array.isArray(calendarioData.semanas[semanaIndex].dias[diaIndex].eventosHorario[horario])) {
        // Si existe un evento antiguo como objeto, convertirlo a array
        if (calendarioData.semanas[semanaIndex].dias[diaIndex].eventosHorario[horario] && 
            calendarioData.semanas[semanaIndex].dias[diaIndex].eventosHorario[horario].texto) {
            calendarioData.semanas[semanaIndex].dias[diaIndex].eventosHorario[horario] = [
                calendarioData.semanas[semanaIndex].dias[diaIndex].eventosHorario[horario]
            ];
        } else {
            calendarioData.semanas[semanaIndex].dias[diaIndex].eventosHorario[horario] = [];
        }
    }
    
    const nuevoEvento = {
        texto: document.getElementById('textoEvento').value,
        colorFondo: document.getElementById('colorFondoEventoHex').value,
        colorTexto: document.getElementById('colorTextoEventoHex').value,
        cursiva: document.getElementById('cursivaEvento').checked
    };
    
    // Si es un evento existente, reemplazarlo, sino agregar nuevo
    if (eventoIndex < calendarioData.semanas[semanaIndex].dias[diaIndex].eventosHorario[horario].length) {
        calendarioData.semanas[semanaIndex].dias[diaIndex].eventosHorario[horario][eventoIndex] = nuevoEvento;
    } else {
        calendarioData.semanas[semanaIndex].dias[diaIndex].eventosHorario[horario].push(nuevoEvento);
    }
    
    cerrarModalEvento();
    mostrarCalendario();
    mostrarNotificacion('Evento guardado correctamente', 'success');
}

function guardarSeparador(event) {
    event.preventDefault();
    
    if (!separadorParaEditar) return;
    
    const { horario, index } = separadorParaEditar;
    
    const textoSeparador = document.getElementById('textoSeparador').value;
    const textoPersonalizado = document.getElementById('textoSeparadorPersonalizado').value;
    const mostrarHora = document.getElementById('mostrarHoraSeparador').checked;
    let horaInicio = document.getElementById('horaInicioSeparador').value;
    let horaFin = document.getElementById('horaFinSeparador').value;
    
    // MEJORADO: Convertir formato de hora (quitar segundos si existen)
    if (horaInicio && horaInicio.includes(':')) {
        const partes = horaInicio.split(':');
        let horas = partes[0];
        let minutos = partes[1];
        
        // ✅ FIX: Convertir cualquier hora "12:xx" a "00:xx" (medianoche) al guardar
        // Esto corrige el problema donde medianoche se guarda como "12:00", "12:15", "12:20", etc.
        if (horas === '12') {
            horas = '00';
        }
        
        horaInicio = `${horas.padStart(2, '0')}:${minutos.padStart(2, '0')}`; // Mantener solo HH:MM
    }
    
    if (horaFin && horaFin.includes(':')) {
        const partes = horaFin.split(':');
        let horas = partes[0];
        let minutos = partes[1];
        
        // ✅ FIX: Convertir cualquier hora "12:xx" a "00:xx" (medianoche) al guardar
        // Esto corrige el problema donde medianoche se guarda como "12:00", "12:15", "12:20", etc.
        if (horas === '12') {
            horas = '00';
        }
        
        horaFin = `${horas.padStart(2, '0')}:${minutos.padStart(2, '0')}`; // Mantener solo HH:MM
    }
    
    const textoFinal = textoPersonalizado || textoSeparador;
    
    if (!calendarioData.separadores) calendarioData.separadores = {};
    
    const nuevoSeparador = {
        texto: textoFinal,
        colorFondo: document.getElementById('colorFondoSeparadorHex').value,
        colorTexto: document.getElementById('colorTextoSeparadorHex').value,
        cursiva: false,
        mostrarHora: mostrarHora,
        horaInicio: horaInicio,
        horaFin: horaFin
    };
    
    // ✅ FIX: Manejar arrays de separadores
    if (!calendarioData.separadores[horario]) {
        // Si no existe separador para esta franja, crear array con el nuevo
        calendarioData.separadores[horario] = [nuevoSeparador];
    } else if (Array.isArray(calendarioData.separadores[horario])) {
        // Si ya es un array
        if (index !== null && index < calendarioData.separadores[horario].length) {
            // Reemplazar separador existente
            calendarioData.separadores[horario][index] = nuevoSeparador;
        } else {
            // Agregar nuevo separador al final del array
            calendarioData.separadores[horario].push(nuevoSeparador);
        }
    } else {
        // Si es un objeto individual, convertirlo a array y agregar el nuevo
        calendarioData.separadores[horario] = [
            calendarioData.separadores[horario],
            nuevoSeparador
        ];
    }
    
    cerrarModalSeparador();
    mostrarCalendario();
    mostrarNotificacion('Separador guardado correctamente', 'success');
}

function mostrarContextMenuEvento(event, elemento, semana, dia, horario, eventoIndex) {
    event.preventDefault();
    
    if (contextMenu) {
        contextMenu.remove();
    }
    
    contextMenu = document.createElement('div');
    contextMenu.className = 'context-menu';
    contextMenu.style.position = 'fixed';
    contextMenu.style.left = event.clientX + 'px';
    contextMenu.style.top = event.clientY + 'px';
    
    contextMenu.innerHTML = `
        <div class="context-menu-item eliminar" onclick="eliminarEvento(${semana}, ${dia}, ${htmlJsArg(horario)}, ${eventoIndex})">
            🗑️ Eliminar Evento
        </div>
    `;
    
    document.body.appendChild(contextMenu);
}

function eliminarEvento(semana, dia, horario, eventoIndex) {
    const semanaIndex = semana - 1;
    const diaIndex = dia - 1;
    
    var dEv = celdaDiaCal(semanaIndex, diaIndex);
    if (dEv && dEv.eventosHorario && dEv.eventosHorario[horario]) {
        // ✅ FIX: Manejar tanto arrays como objetos individuales
        if (Array.isArray(dEv.eventosHorario[horario])) {
            // Es un array, eliminar el elemento específico
            dEv.eventosHorario[horario].splice(eventoIndex, 1);
            
            // Si el array queda vacío, limpiarlo
            if (dEv.eventosHorario[horario].length === 0) {
                dEv.eventosHorario[horario] = {
                    texto: "",
                    colorFondo: "",
                    colorTexto: "",
                    cursiva: false
                };
            }
        } else {
            // Es un objeto individual, limpiarlo
            dEv.eventosHorario[horario] = {
                texto: "",
                colorFondo: "",
                colorTexto: "",
                cursiva: false
            };
        }
    }
    
    if (contextMenu) {
        contextMenu.remove();
        contextMenu = null;
    }
    
    mostrarCalendario();
    mostrarNotificacion('Evento eliminado correctamente', 'success');
}

function cerrarModalEvento() {
    document.getElementById('modalEvento').style.display = 'none';
}

function cerrarModalSeparador() {
    document.getElementById('modalSeparador').style.display = 'none';
    separadorParaEditar = null;
    
    // Limpiar también el context menu si existe
    cerrarContextMenu();
}

function confirmarEliminarSeparador() {
    if (!separadorParaEliminar || typeof separadorParaEliminar !== 'object') return;

    const horario = separadorParaEliminar.horario;
    const index = separadorParaEliminar.index;

    if (!horario) {
        mostrarNotificacion('Error: No se pudo encontrar el separador', 'error');
        cerrarModalEliminarSeparador();
        return;
    }

    const separadorData = obtenerSeparadorEnFranja(horario, index);
    if (!separadorData) {
        mostrarNotificacion('Error: No se pudo encontrar el separador', 'error');
        cerrarModalEliminarSeparador();
        return;
    }

    if (calendarioData.separadores && calendarioData.separadores[horario]) {
        if (Array.isArray(calendarioData.separadores[horario])) {
            if (index !== null && index !== undefined && index < calendarioData.separadores[horario].length) {
                calendarioData.separadores[horario].splice(index, 1);

                if (calendarioData.separadores[horario].length === 0) {
                    delete calendarioData.separadores[horario];
                }
            }
        } else {
            delete calendarioData.separadores[horario];
        }

        mostrarNotificacion('Separador eliminado correctamente', 'success');
        guardarCalendario();
    } else {
        mostrarNotificacion('Error: No se pudo encontrar el separador', 'error');
    }

    cerrarModalEliminarSeparador();
    mostrarCalendario();
}

// Asegurar que esta función existe
function cerrarModalEliminarSeparador() {
    document.getElementById('modalEliminarSeparador').style.display = 'none';
    separadorParaEliminar = null;
    
    // Limpiar también el context menu si existe
    if (contextMenu) {
        contextMenu.remove();
        contextMenu = null;
    }
    
    // Quitar resaltado de separadores
    document.querySelectorAll('.separador-fila.con-menu-contexto').forEach(sep => {
        sep.classList.remove('con-menu-contexto');
    });
}

// ACTUALIZADA: Función para cerrar context menus
function cerrarContextMenu() {
    if (contextMenu) {
        contextMenu.remove();
        contextMenu = null;
        
        // Quitar resaltado de separadores
        document.querySelectorAll('.separador-fila.con-menu-contexto').forEach(sep => {
            sep.classList.remove('con-menu-contexto');
        });
    }
}

// Función para abrir modal de clima por franja horaria - MEJORADA
function abrirModalClimaHorario(horario) {
    if (!esProfesor) return;
    
    const climaActual = calendarioData.climasHorario ? calendarioData.climasHorario[horario] : "CLEAR";
    
    document.getElementById('modalClimaHorarioFranja').value = horario;
    document.getElementById('infoFranjaHoraria').textContent = horario;
    
    // Llenar selector de climas
    const climaSelect = document.getElementById('climaHorarioSelect');
    climaSelect.innerHTML = '';
    
    // Usar climas de config o lista por defecto
    const climasDisponibles = config.climas || [
        "CLEAR", "CLOUDS", "CLEARING", "RAIN", "THUNDER", "FOGGY"
    ];
    
    console.log('Climas disponibles:', climasDisponibles);
    
    if (climasDisponibles.length === 0) {
        console.error('No hay climas disponibles en la configuración');
        mostrarNotificacion('Error: No hay climas configurados', 'error');
        return;
    }
    
    const setClimas = new Set(climasDisponibles);
    if (climaActual && !setClimas.has(climaActual)) {
        const optLegacy = document.createElement('option');
        optLegacy.value = climaActual;
        optLegacy.textContent = traducirClima(climaActual) + ' (legacy)';
        optLegacy.selected = true;
        climaSelect.appendChild(optLegacy);
    }
    
    climasDisponibles.forEach(clima => {
        const option = document.createElement('option');
        option.value = clima;
        option.textContent = traducirClima(clima);
        option.selected = clima === climaActual;
        climaSelect.appendChild(option);
    });
    
    document.getElementById('modalClimaHorario').style.display = 'block';
}

// Función para guardar clima por franja horaria
function guardarClimaHorario(event) {
    event.preventDefault();
    
    const horario = document.getElementById('modalClimaHorarioFranja').value;
    const nuevoClima = document.getElementById('climaHorarioSelect').value;
    
    console.log('Guardando clima para horario:', horario, '->', nuevoClima);
    
    // Asegurar que climasHorario existe
    if (!calendarioData.climasHorario) {
        calendarioData.climasHorario = {};
        console.log('climasHorario inicializado');
    }
    
    // Guardar el clima
    calendarioData.climasHorario[horario] = nuevoClima;
    console.log('climasHorario actualizado:', calendarioData.climasHorario);
    
    cerrarModalClimaHorario();
    mostrarCalendario();
    mostrarNotificacion(`Clima de ${horario} actualizado a: ${traducirClima(nuevoClima)}`, 'success');
    
    // Guardar automáticamente los cambios
    guardarCalendario();
}

function cerrarModalClimaHorario() {
    document.getElementById('modalClimaHorario').style.display = 'none';
}

function generarHorarioVacioDesdeConfig() {
    const horariosCfg = (config && config.horarios && config.horarios.length) ? config.horarios : configPorDefecto.horarios;
    const diasSemana = (config && config.diasSemana && config.diasSemana.length) ? config.diasSemana : configPorDefecto.diasSemana;
    const mesesCfg = (config && config.meses && config.meses.length) ? config.meses : configPorDefecto.meses;
    const lunasCfg = (config && config.lunas && config.lunas.length) ? config.lunas : configPorDefecto.lunas;
    const tempsCfg = (config && config.temperaturas) ? config.temperaturas : (configPorDefecto.temperaturas || {});

    const out = {
        semanas: {},
        meses: {},
        separadores: {},
        climasHorario: {},
        ultimaActualizacion: Math.floor(Date.now() / 1000)
    };

    for (let semana = 1; semana <= 2; semana++) {
        out.meses[semana] = [];
        for (let dia = 1; dia <= 7; dia++) {
            const mesIndex = ((semana - 1) * 7 + dia - 1) % 12;
            out.meses[semana][dia] = mesesCfg[mesIndex] || 'Enero';
        }
    }

    for (let semana = 1; semana <= 2; semana++) {
        out.semanas[semana] = { estacion: 'Mixta', dias: {} };

        for (let dia = 1; dia <= 7; dia++) {
            const tempConfig = tempsCfg.Primavera || { min: 15, max: 25 };
            const temperatura = Math.floor(Math.random() * (tempConfig.max - tempConfig.min + 1)) + tempConfig.min;

            out.semanas[semana].dias[dia] = {
                nombre: diasSemana[dia - 1] || ('Día ' + dia),
                evento: 'Ninguno',
                luna: lunasCfg[Math.floor(Math.random() * lunasCfg.length)] || 'Luna Nueva',
                temperatura: temperatura,
                estacion: 'Primavera',
                clases: {},
                eventosHorario: {}
            };

            horariosCfg.forEach(function (horario) {
                out.semanas[semana].dias[dia].clases[horario.hora] = [];
                out.semanas[semana].dias[dia].eventosHorario[horario.hora] = {
                    texto: '',
                    colorFondo: '#fff3cd',
                    colorTexto: '#000000',
                    cursiva: false
                };
            });
        }
    }

    horariosCfg.forEach(function (horario) {
        out.separadores[horario.hora] = {
            texto: '',
            colorFondo: '#740001',
            colorTexto: '#ffffff',
            cursiva: false,
            mostrarHora: false,
            horaInicio: '',
            horaFin: ''
        };
        out.climasHorario[horario.hora] = horario.clima || 'CLEAR';
    });

    return out;
}

function aplicarCalendarioTrasBorrarHorario(payload) {
    if (!payload || !payload.calendario) {
        return;
    }

    const preservedTablon = calendarioData && calendarioData.tablonSecciones;
    calendarioData = payload.calendario;

    if (preservedTablon && (!calendarioData.tablonSecciones || typeof calendarioData.tablonSecciones !== 'object')) {
        calendarioData.tablonSecciones = preservedTablon;
    }

    if (payload.config) {
        config = payload.config;
    }

    semanaActual = 1;
    mostrarCalendario();
    refrescarTablonTrasAbrir();
    mostrarNotificacion('Horario borrado por completo.', 'success');
}

function borrarHorarioCompleto() {
    if (MODO_WEB) {
        return;
    }

    if (!puedePublicarTablon) {
        mostrarNotificacion('No tienes permiso para borrar el horario', 'error');
        return;
    }

    const msg = '¿Borrar TODO el horario escolar (clases, eventos y franjas) de las dos semanas?\n\nLas secciones del tablón (normas, optativas, clubes, notas) NO se tocarán.';
    if (!window.confirm(msg)) {
        return;
    }

    const preservedTablon = calendarioData && calendarioData.tablonSecciones;
    const horarioVacio = generarHorarioVacioDesdeConfig();

    if (preservedTablon) {
        horarioVacio.tablonSecciones = preservedTablon;
    }

    if (MODO_WEB) {
        if (!tokenAutenticacion) {
            mostrarNotificacion('Debes iniciar sesión para borrar el horario', 'error');
            mostrarLoginSiNecesario();
            return;
        }

        fetch(`${API_URL}/api/calendario`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${tokenAutenticacion}`
            },
            body: JSON.stringify({ calendario: horarioVacio })
        })
        .then(function (response) {
            if (!response.ok) {
                if (response.status === 403) {
                    throw new Error('Solo staff/administradores pueden borrar el horario OOC');
                }
                throw new Error('Error en la respuesta del servidor');
            }
            return response.json();
        })
        .then(function (data) {
            if (data.success) {
                aplicarCalendarioTrasBorrarHorario({ calendario: horarioVacio, config: config });
                if (data.ultimaActualizacion) {
                    ultimoTimestamp = data.ultimaActualizacion;
                    calendarioData.ultimaActualizacion = data.ultimaActualizacion;
                }
            } else {
                mostrarNotificacion('No se pudo borrar el horario en la web', 'error');
            }
        })
        .catch(function (error) {
            console.error('Error al borrar horario:', error);
            mostrarNotificacion('Error al borrar: ' + error.message, 'error');
        });
        return;
    }

    if (typeof gmod !== 'undefined' && gmod && typeof gmod.CalBorrarHorario === 'function') {
        try {
            gmod.CalBorrarHorario();
            mostrarNotificacion('Borrado de horario enviado al servidor…', 'info');
        } catch (e) {
            console.error(e);
            mostrarNotificacion('Error al borrar el horario', 'error');
        }
        return;
    }

    mostrarNotificacion('Borrar horario no está disponible en este entorno.', 'error');
}

// Publicar tablón en la web (staff IC / admin OOC)
function publicarTablon() {
    if (!puedePublicarTablon) {
        mostrarNotificacion('No tienes permiso para publicar el tablón', 'error');
        return;
    }

    if (MODO_WEB || esProfesor) {
        leerTablonSeccionesDelDOM();
    }

    if (MODO_WEB) {
        if (!tokenAutenticacion) {
            mostrarNotificacion('Debes iniciar sesión para publicar el tablón', 'error');
            mostrarLoginSiNecesario();
            return;
        }

        fetch(`${API_URL}/api/calendario`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${tokenAutenticacion}`
            },
            body: JSON.stringify({
                calendario: calendarioData
            })
        })
        .then(response => {
            if (!response.ok) {
                if (response.status === 401) {
                    tokenAutenticacion = null;
                    localStorage.removeItem('calendario_token');
                    aplicarRolUsuario(null);
                    actualizarBarraAuth();
                    mostrarLoginSiNecesario();
                    throw new Error('Sesión expirada');
                }
                if (response.status === 403) {
                    throw new Error('Solo administradores pueden publicar el tablón OOC');
                }
                throw new Error('Error en la respuesta del servidor');
            }
            return response.json();
        })
        .then(data => {
            if (data.success) {
                if (data.ultimaActualizacion) {
                    ultimoTimestamp = data.ultimaActualizacion;
                    calendarioData.ultimaActualizacion = data.ultimaActualizacion;
                }
                mostrarNotificacion('✅ Tablón publicado correctamente', 'success');
            } else {
                mostrarNotificacion('❌ Error al publicar el tablón', 'error');
            }
        })
        .catch(error => {
            console.error('Error al publicar:', error);
            mostrarNotificacion('❌ Error al publicar: ' + error.message, 'error');
        });
        return;
    }

    if (typeof gmod !== 'undefined' && gmod && typeof gmod.CalPublicar === 'function') {
        try {
            gmod.CalPublicar();
            mostrarNotificacion('Publicación del tablón enviada al servidor.', 'info');
        } catch (e) {
            console.error(e);
            mostrarNotificacion('❌ Error al publicar el tablón', 'error');
        }
        return;
    }

    mostrarNotificacion('Publicar tablón no está disponible en este entorno.', 'error');
}

// Función separada para guardar
function guardarCalendario() {
    console.log('[Calendario] DEBUG: guardarCalendario() llamado');
    console.log('[Calendario] DEBUG: esProfesor =', esProfesor);
    console.log('[Calendario] DEBUG: MODO_WEB =', MODO_WEB);
    
    if (!esProfesor) {
        mostrarNotificacion('No tienes permisos para guardar cambios', 'error');
        return;
    }

    leerTablonSeccionesDelDOM();

    if (MODO_WEB) {
        if (!tokenAutenticacion) {
            mostrarNotificacion('Debes iniciar sesión para guardar cambios', 'error');
            mostrarLoginSiNecesario();
            return;
        }

        fetch(`${API_URL}/api/calendario`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${tokenAutenticacion}`
            },
            body: JSON.stringify({
                calendario: calendarioData
            })
        })
        .then(function (response) {
            if (!response.ok) {
                if (response.status === 401) {
                    tokenAutenticacion = null;
                    localStorage.removeItem('calendario_token');
                    aplicarRolUsuario(null);
                    actualizarBarraAuth();
                    mostrarLoginSiNecesario();
                    throw new Error('Sesión expirada');
                }
                if (response.status === 403) {
                    throw new Error('No tienes permiso para guardar el calendario');
                }
                throw new Error('Error en la respuesta del servidor');
            }
            return response.json();
        })
        .then(function (data) {
            if (data.success) {
                if (data.ultimaActualizacion) {
                    ultimoTimestamp = data.ultimaActualizacion;
                    calendarioData.ultimaActualizacion = data.ultimaActualizacion;
                }
                mostrarNotificacion('Calendario guardado correctamente', 'success');
            } else {
                mostrarNotificacion('Error al guardar el calendario', 'error');
            }
        })
        .catch(function (error) {
            console.error('Error al guardar:', error);
            mostrarNotificacion('Error al guardar: ' + error.message, 'error');
        });
        return;
    }

    console.log('[Calendario] DEBUG: Enviando datos al servidor:', calendarioData);
    
    if (typeof gmod !== 'undefined' && gmod && typeof gmod.CalGuardar === 'function') {
        try {
            gmod.CalGuardar(JSON.stringify({ calendario: calendarioData }));
            mostrarNotificacion('Guardado enviado. El clima automático solo usa datos ya guardados en el servidor; confirma con el aviso en el juego.', 'info');
        } catch (e) {
            console.error(e);
            mostrarNotificacion('❌ Error al guardar cambios', 'error');
        }
    } else {
        // Modo FiveM: usar NUI callback
        console.log('[Calendario] DEBUG: Modo FiveM, obteniendo resourceName para guardar...');
        let resourceName;
        try {
            const url = window.location.href;
            if (url.includes('cfx-nui')) {
                const match = url.match(/cfx-nui-([^/]+)/);
                if (match && match[1]) {
                    resourceName = match[1];
                    console.log('[Calendario] DEBUG: ResourceName extraído de URL:', resourceName);
                } else {
                    resourceName = 'cat_calendario';
                    console.log('[Calendario] DEBUG: Usando resourceName por defecto:', resourceName);
                }
            } else {
                resourceName = 'cat_calendario';
                console.log('[Calendario] DEBUG: No es cfx-nui, usando resourceName por defecto:', resourceName);
            }
        } catch (e) {
            console.error('[Calendario] DEBUG: Error al obtener resourceName:', e);
            resourceName = 'cat_calendario';
        }
        
        const fetchUrl = `https://${resourceName}/guardarCambios`;
        console.log('[Calendario] DEBUG: Enviando fetch a:', fetchUrl);
        
        fetch(fetchUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({
                calendario: calendarioData
            })
        })
        .then(response => {
            console.log('[Calendario] DEBUG: Respuesta recibida, status:', response.status, 'ok:', response.ok);
            if (!response.ok) {
                throw new Error('Error en la respuesta del servidor');
            }
            return response.json();
        })
        .then(data => {
            console.log('[Calendario] DEBUG: Respuesta del servidor al guardar:', data);
            if (data === 'ok' || data === true) {
                mostrarNotificacion('✅ Cambios guardados correctamente', 'success');
                console.log('[Calendario] DEBUG: Guardado exitoso, calendario permanece abierto - NO se cierra');
                // IMPORTANTE: NO cerrar el calendario después de guardar, solo mostrar notificación
                // El calendario debe permanecer abierto para que el usuario pueda seguir editando
            } else {
                mostrarNotificacion('❌ Error al guardar cambios', 'error');
            }
        })
        .catch(error => {
            console.error('[Calendario] DEBUG: Error al guardar:', error);
            console.error('[Calendario] DEBUG: Stack trace:', error.stack);
            mostrarNotificacion('❌ Error de conexión al guardar', 'error');
        });
    }
}


function abrirModalProbarClimas() {
    if (!esProfesor) return;
    
    document.getElementById('modalProbarClimas').style.display = 'block';
    
    // Establecer hora actual por defecto
    const ahora = new Date();
    const horaActual = ahora.getHours().toString().padStart(2, '0') + ':' + 
                      ahora.getMinutes().toString().padStart(2, '0');
    document.getElementById('horaPruebaClima').value = horaActual;
    
    // Actualizar lista de climas configurados
    actualizarListaClimasConfigurados();
    
    // Calcular clima inicial
    calcularClimaParaHora(horaActual);
}

// Función para calcular qué clima se activaría en una hora específica
function calcularClimaParaHora(hora) {
    console.log('Calculando clima para hora:', hora);
    
    const climasHorario = calendarioData.climasHorario || {};
    console.log('climasHorario disponible:', climasHorario);
    
    let climaEncontrado = "CLEAR";
    let horarioEncontrado = "";
    
    // Buscar en qué franja horaria cae la hora
    for (const [horario, clima] of Object.entries(climasHorario)) {
        console.log('Verificando horario:', horario, 'clima:', clima);
        
        const [horaInicio, horaFin] = horario.split(' - ');
        if (horaInicio && horaFin) {
            console.log('Comparando:', hora, '>=', horaInicio, '&&', hora, '<', horaFin);
            
            if (hora >= horaInicio && hora < horaFin) {
                climaEncontrado = clima;
                horarioEncontrado = horario;
                console.log('¡Coincidencia encontrada!');
                break;
            }
        }
    }
    
    // Mostrar resultado
    const resultadoDiv = document.getElementById('resultadoClimaPrueba');
    if (horarioEncontrado) {
        resultadoDiv.innerHTML = `
            <div style="color: #155724; background: #d4edda; padding: 10px; border-radius: 5px;">
                <strong>${traducirClima(climaEncontrado)}</strong><br>
                <small>Franja: ${horarioEncontrado}</small>
            </div>
        `;
    } else {
        resultadoDiv.innerHTML = `
            <div style="color: #856404; background: #fff3cd; padding: 10px; border-radius: 5px;">
                <strong>No se encontró franja horaria</strong><br>
                <small>Configura los climas en las franjas horarias primero</small>
            </div>
        `;
    }
    
    // Guardar clima para poder aplicarlo
    resultadoDiv.dataset.climaActual = climaEncontrado;
    resultadoDiv.dataset.horarioEncontrado = horarioEncontrado;
}

// Función para actualizar lista de climas configurados
function actualizarListaClimasConfigurados() {
    const listaDiv = document.getElementById('listaClimasConfigurados');
    const climasHorario = calendarioData.climasHorario || {};
    
    console.log('Actualizando lista de climas:', climasHorario);
    
    if (Object.keys(climasHorario).length === 0) {
        listaDiv.innerHTML = '<div style="color: #856404; background: #fff3cd; padding: 10px; border-radius: 3px;">No hay climas configurados. Usa el botón 🌤️ en cada franja horaria para configurarlos.</div>';
        return;
    }
    
    let html = '';
    for (const [horario, clima] of Object.entries(climasHorario)) {
        html += `
            <div style="display: flex; justify-content: space-between; padding: 5px 0; border-bottom: 1px solid #dee2e6;">
                <span>${horario}</span>
                <span style="font-weight: bold;">${traducirClima(clima)}</span>
            </div>
        `;
    }
    listaDiv.innerHTML = html;
}

// Función para aplicar clima de prueba
function catCalStormFoxIntegracionActiva() {
    const ix = (config && config.integracionStormFox) || {};
    return ix.enabled === true && (ix.syncWeather === true || ix.syncTemperature === true);
}

function aplicarClimaPrueba() {
    const resultadoDiv = document.getElementById('resultadoClimaPrueba');
    const clima = resultadoDiv.dataset.climaActual;
    const hora = document.getElementById('horaPruebaClima').value;
    
    if (!clima) {
        mostrarNotificacion('Primero selecciona una hora para probar', 'error');
        return;
    }

    if (!catCalStormFoxIntegracionActiva()) {
        mostrarNotificacion('Vista previa: ' + traducirClima(clima) + ' (no se aplica a StormFox)', 'info');
        return;
    }

    if (typeof window !== 'undefined' && window.MODO_GMOD === true) {
        if (typeof gmod !== 'undefined' && gmod && typeof gmod.CalClimaPrueba === 'function') {
            try {
                gmod.CalClimaPrueba(JSON.stringify({ clima: clima, hora: hora }));
                mostrarNotificacion(`Solicitud enviada: ${traducirClima(clima)}`, 'success');
            } catch (e) {
                console.error(e);
                mostrarNotificacion('Error al enviar clima de prueba', 'error');
            }
            return;
        }
        mostrarNotificacion('Puente GMod no disponible para clima de prueba.', 'error');
        return;
    }
    
    fetch(`https://${GetParentResourceName()}/aplicarClimaPrueba`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: JSON.stringify({clima: clima, hora: hora})
    })
    .then(response => response.json())
    .then(data => {
        if (data === 'ok') {
            mostrarNotificacion(`✅ Clima aplicado: ${traducirClima(clima)} (Hora: ${hora})`, 'success');
        } else {
            mostrarNotificacion('❌ Error al aplicar clima', 'error');
        }
    })
    .catch(error => {
        console.error('Error:', error);
        mostrarNotificacion('❌ Error de conexión', 'error');
    });
}

function cerrarModalProbarClimas() {
    document.getElementById('modalProbarClimas').style.display = 'none';
}

// ==================== FUNCIONES PARA BARRAS DE ESTACIÓN ====================

function abrirModalBarrasEstacion(semana) {
    document.getElementById('modalBarrasSemana').value = semana;
    renderizarListaBarras();
    document.getElementById('modalBarrasEstacion').style.display = 'block';
}

function cerrarModalBarrasEstacion() {
    document.getElementById('modalBarrasEstacion').style.display = 'none';
}

function renderizarListaBarras() {
    const semana = parseInt(document.getElementById('modalBarrasSemana').value);
    const semanaIndex = semana - 1;
    const semanaData = calendarioData.semanas[semanaIndex];
    
    if (!semanaData.barrasEstacion) {
        semanaData.barrasEstacion = [];
    }
    
    const lista = document.getElementById('listaBarrasEstacion');
    
    if (semanaData.barrasEstacion.length === 0) {
        lista.innerHTML = '<p style="text-align: center; color: #666; padding: 20px;">No hay barras de estación configuradas</p>';
        return;
    }
    
    let html = '';
    semanaData.barrasEstacion.forEach((barra, index) => {
        const icono = obtenerIconoEstacion(barra.nombre);
        const color = obtenerColorEstacion(barra.nombre);
        html += `
            <div style="background: ${color}; color: white; padding: 10px; border-radius: 5px; margin-bottom: 8px; display: flex; justify-content: space-between; align-items: center;">
                <div>
                    <strong>${icono} ${barra.nombre}</strong><br>
                    <small>Día ${barra.diaInicio} → ${barra.diaInicio + barra.diasDuracion - 1} (${barra.diasDuracion} días)</small>
                </div>
                <div>
                    <button onclick="editarBarra(${index})" style="background: rgba(255,255,255,0.3); color: white; border: none; padding: 5px 10px; border-radius: 3px; cursor: pointer; margin-right: 5px;">
                        ✏️ Editar
                    </button>
                    <button onclick="eliminarBarra(${index})" style="background: rgba(255,0,0,0.5); color: white; border: none; padding: 5px 10px; border-radius: 3px; cursor: pointer;">
                        🗑️ Eliminar
                    </button>
                </div>
            </div>
        `;
    });
    
    lista.innerHTML = html;
}

function editarBarra(index) {
    const semana = parseInt(document.getElementById('modalBarrasSemana').value);
    const semanaIndex = semana - 1;
    const barra = calendarioData.semanas[semanaIndex].barrasEstacion[index];
    
    document.getElementById('modalBarraIndex').value = index;
    document.getElementById('estacionBarra').value = barra.nombre;
    document.getElementById('diaInicioBarra').value = barra.diaInicio;
    document.getElementById('diasDuracionBarra').value = barra.diasDuracion;
    document.getElementById('tituloModalBarra').textContent = '✏️ Editar Barra de Estación';
    
    actualizarPreviewBarra();
    document.getElementById('modalEditarBarra').style.display = 'block';
}

let barraParaEliminar = null;

function eliminarBarra(index) {
    barraParaEliminar = index;
    document.getElementById('modalConfirmarEliminarBarra').style.display = 'block';
}

function confirmarEliminarBarraEstacion() {
    if (barraParaEliminar === null) return;
    
    const semana = parseInt(document.getElementById('modalBarrasSemana').value);
    const semanaIndex = semana - 1;
    
    calendarioData.semanas[semanaIndex].barrasEstacion.splice(barraParaEliminar, 1);
    renderizarListaBarras();
    mostrarCalendario();
    mostrarNotificacion('Barra eliminada. Recuerda guardar los cambios.', 'success');
    
    actualizarBotonesAccionTablon();
    cerrarModalConfirmarEliminarBarra();
    barraParaEliminar = null;
}

function cerrarModalConfirmarEliminarBarra() {
    document.getElementById('modalConfirmarEliminarBarra').style.display = 'none';
    barraParaEliminar = null;
}

elOn('btnAgregarBarra', 'click', function() {
    document.getElementById('modalBarraIndex').value = '-1';
    document.getElementById('estacionBarra').value = 'Primavera';
    document.getElementById('diaInicioBarra').value = '0';
    document.getElementById('diasDuracionBarra').value = '7';
    document.getElementById('tituloModalBarra').textContent = '➕ Nueva Barra de Estación';
    
    actualizarPreviewBarra();
    document.getElementById('modalEditarBarra').style.display = 'block';
});

elOn('btnCerrarBarrasEstacion', 'click', cerrarModalBarrasEstacion);
elOn('btnCancelarEditarBarra', 'click', cerrarModalEditarBarra);
elOn('btnConfirmarEliminarBarra', 'click', confirmarEliminarBarraEstacion);
elOn('btnCancelarEliminarBarra', 'click', cerrarModalConfirmarEliminarBarra);

elOn('formEditarBarra', 'submit', function(e) {
    e.preventDefault();
    guardarBarra();
});

// Event listeners para actualizar preview en tiempo real
elOn('estacionBarra', 'change', actualizarPreviewBarra);
elOn('diaInicioBarra', 'input', actualizarPreviewBarra);
elOn('diasDuracionBarra', 'input', actualizarPreviewBarra);

function actualizarPreviewBarra() {
    const estacion = document.getElementById('estacionBarra').value;
    const diaInicio = parseInt(document.getElementById('diaInicioBarra').value) || 0;
    const diasDuracion = parseInt(document.getElementById('diasDuracionBarra').value) || 1;
    
    const icono = obtenerIconoEstacion(estacion);
    const color = obtenerColorEstacion(estacion);
    
    const barraPreview = document.getElementById('barraPreview');
    const leftPercent = (diaInicio / 7) * 100;
    const widthPercent = (diasDuracion / 7) * 100;
    
    barraPreview.style.left = leftPercent + '%';
    barraPreview.style.width = widthPercent + '%';
    barraPreview.style.background = color;
    barraPreview.textContent = `${icono} ${estacion}`;
}

function cerrarModalEditarBarra() {
    document.getElementById('modalEditarBarra').style.display = 'none';
}

function guardarBarra() {
    const semana = parseInt(document.getElementById('modalBarrasSemana').value);
    const semanaIndex = semana - 1;
    const barraIndex = parseInt(document.getElementById('modalBarraIndex').value);
    
    const nuevaBarra = {
        nombre: document.getElementById('estacionBarra').value,
        diaInicio: parseInt(document.getElementById('diaInicioBarra').value),
        diasDuracion: parseInt(document.getElementById('diasDuracionBarra').value)
    };
    
    // Validar que no se pase de los límites
    if (nuevaBarra.diaInicio < 0 || nuevaBarra.diaInicio > 6) {
        mostrarNotificacion('❌ El día de inicio debe estar entre 0 y 6', 'error');
        return;
    }
    
    if (nuevaBarra.diasDuracion < 1 || nuevaBarra.diasDuracion > 7) {
        mostrarNotificacion('❌ La duración debe estar entre 1 y 7 días', 'error');
        return;
    }
    
    if (nuevaBarra.diaInicio + nuevaBarra.diasDuracion > 7) {
        mostrarNotificacion('❌ La barra se sale del rango de la semana (máximo 7 días)', 'error');
        return;
    }
    
    if (!calendarioData.semanas[semanaIndex].barrasEstacion) {
        calendarioData.semanas[semanaIndex].barrasEstacion = [];
    }
    
    if (barraIndex === -1) {
        // Nueva barra
        calendarioData.semanas[semanaIndex].barrasEstacion.push(nuevaBarra);
        mostrarNotificacion('✅ Barra agregada. Recuerda guardar los cambios.', 'success');
    } else {
        // Editar barra existente
        calendarioData.semanas[semanaIndex].barrasEstacion[barraIndex] = nuevaBarra;
        mostrarNotificacion('✅ Barra actualizada. Recuerda guardar los cambios.', 'success');
    }
    
    cerrarModalEditarBarra();
    renderizarListaBarras();
    mostrarCalendario();
    
    actualizarBotonesAccionTablon();
}

// GMod DHTML: el postMessage desde Lua puede ejecutarse antes de DOMContentLoaded;
// el listener debe existir en cuanto se parsea este archivo (handleCalendarioPostMessage es function hoisted).
catCalDebugLog('registrando window.addEventListener(message) al final de script.js');
window.addEventListener('message', handleCalendarioPostMessage);