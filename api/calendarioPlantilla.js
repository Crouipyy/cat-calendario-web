// Plantilla mínima válida para el NUI (misma rejilla que Helix sh_config.lua).
// Compartida por api/calendario.js y scripts de siembra MySQL.

const HORARIOS_PLANTILLA = [
    { hora: '16:10 - 17:00', clima: 'RAIN' },
    { hora: '17:00 - 18:00', clima: 'CLEARING' },
    { hora: '18:00 - 19:00', clima: 'CLEAR' },
    { hora: '19:00 - 20:00', clima: 'FOGGY' },
    { hora: '20:00 - 20:30', clima: 'FOGGY' },
    { hora: '21:45 - 22:30', clima: 'FOGGY' },
    { hora: '22:30 - 23:00', clima: 'CLEAR' },
    { hora: '23:00 - 23:50', clima: 'CLEAR' },
    { hora: '00:30 - 01:00', clima: 'CLEAR' }
];
const DIAS_SEMANA = ['Sábado', 'Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];
const MESES_NOMBRE = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
const ESTACION_POR_DIA_GLOBAL = [
    'Otoño', 'Otoño', 'Otoño', 'Otoño', 'Invierno', 'Invierno', 'Invierno',
    'Primavera', 'Primavera', 'Primavera', 'Verano', 'Verano', 'Verano', 'Verano'
];

function calendarioPlantillaParaUI() {
    const ultima = Math.floor(Date.now() / 1000);
    const separadores = {};
    const climasHorario = {};
    for (const h of HORARIOS_PLANTILLA) {
        separadores[h.hora] = {
            texto: '',
            colorFondo: '#740001',
            colorTexto: '#ffffff',
            cursiva: false,
            mostrarHora: false,
            horaInicio: '',
            horaFin: ''
        };
        climasHorario[h.hora] = h.clima || 'CLEAR';
    }

    const meses = [[], []];
    for (let s = 0; s < 2; s++) {
        for (let d = 0; d < 7; d++) {
            meses[s][d] = MESES_NOMBRE[(s * 7 + d) % 12];
        }
    }

    function buildWeek(weekIdx) {
        const dias = [];
        for (let dia = 0; dia < 7; dia++) {
            const g = weekIdx * 7 + dia;
            const estacion = ESTACION_POR_DIA_GLOBAL[g] || 'Primavera';
            const clases = {};
            const eventosHorario = {};
            for (const h of HORARIOS_PLANTILLA) {
                clases[h.hora] = [];
                eventosHorario[h.hora] = {
                    texto: '',
                    colorFondo: '#fff3cd',
                    colorTexto: '#000000',
                    cursiva: false
                };
            }
            dias.push({
                nombre: DIAS_SEMANA[dia],
                evento: 'Ninguno',
                luna: 'Luna Nueva',
                temperatura: 20,
                estacion,
                clases,
                eventosHorario
            });
        }
        return { estacion: 'Mixta', dias };
    }

    return {
        semanas: [buildWeek(0), buildWeek(1)],
        meses,
        separadores,
        climasHorario,
        ultimaActualizacion: ultima
    };
}

module.exports = { calendarioPlantillaParaUI, HORARIOS_PLANTILLA };
