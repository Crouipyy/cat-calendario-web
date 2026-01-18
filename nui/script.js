let calendarioData = {};
let esProfesor = false;
let config = {};
let semanaActual = 1;
let tooltipElement = null;
let contextMenu = null;
let claseParaEliminar = null;
let separadorParaEditar = null;
let separadorParaEliminar = null;

// Detectar modo web automáticamente
function detectarModoWeb() {
    // Si window.MODO_WEB está definido explícitamente, usarlo
    if (typeof window.MODO_WEB !== 'undefined') {
        return window.MODO_WEB === true;
    }
    
    // Detectar automáticamente:
    // - Si estamos en FiveM NUI, la URL será como "https://cfx-nui-..."
    // - Si estamos en un navegador real, la URL será como "https://tu-proyecto.vercel.app"
    
    const url = window.location.href;
    const hostname = window.location.hostname;
    
    // Si la URL contiene "cfx-nui", estamos en FiveM
    if (url.includes('cfx-nui') || hostname.includes('cfx-nui')) {
        return false; // Estamos en FiveM, NO en modo web
    }
    
    // Si GetParentResourceName está disponible y funciona, estamos en FiveM
    try {
        if (typeof GetParentResourceName === 'function') {
            const resourceName = GetParentResourceName();
            if (resourceName && resourceName !== 'web-mode' && resourceName !== 'unknown') {
                return false; // Estamos en FiveM
            }
        }
    } catch (e) {
        // Si falla, probablemente no estamos en FiveM
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

// Log para debugging
console.log('[Calendario] Modo Web detectado:', MODO_WEB);
console.log('[Calendario] API URL:', API_URL);

// Configuración por defecto (para modo web)
const configPorDefecto = {
    cursos: ["1º", "2º", "3º", "4º", "5º", "6º", "7º", "Todos"],
    meses: ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"],
    diasSemana: ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"],
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
    climas: ["EXTRASUNNY", "CLEAR", "NEUTRAL", "SMOG", "FOGGY", "OVERCAST", "CLOUDS", "CLEARING", "RAIN", "THUNDER", "SNOW", "BLIZZARD", "SNOWLIGHT", "XMAS", "HALLOWEEN"]
};

// Función para cargar datos desde API (modo web)
async function cargarDatosDesdeAPI() {
    // Verificar que estamos realmente en modo web (no FiveM)
    if (!MODO_WEB || !API_URL || API_URL === '' || API_URL.includes('cfx-nui')) {
        console.log('[Calendario] No se puede cargar desde API - estamos en FiveM o API_URL inválida');
        console.log('[Calendario] MODO_WEB:', MODO_WEB, 'API_URL:', API_URL);
        return;
    }
    
    try {
        console.log('[Calendario] Cargando datos desde:', `${API_URL}/api/calendario`);
        
        const response = await fetch(`${API_URL}/api/calendario`);
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const data = await response.json();
        console.log('[Calendario] Datos recibidos:', data);
        
        if (data.success && data.calendario) {
            calendarioData = data.calendario;
        } else {
            console.warn('[Calendario] No hay datos del calendario, usando estructura vacía');
            calendarioData = { semanas: [], meses: [], separadores: {}, climasHorario: {} };
        }
        
        // Cargar configuración
        config = configPorDefecto;
        
        // Verificar autenticación si hay token
        if (tokenAutenticacion) {
            try {
                const verifyResponse = await fetch(`${API_URL}/api/verificar`, {
                    headers: {
                        'Authorization': `Bearer ${tokenAutenticacion}`
                    }
                });
                const verifyData = await verifyResponse.json();
                if (verifyData.success) {
                    usuarioActual = verifyData.usuario;
                    esProfesor = verifyData.usuario.permisos && verifyData.usuario.permisos.includes('editar');
                } else {
                    tokenAutenticacion = null;
                    localStorage.removeItem('calendario_token');
                }
            } catch (e) {
                console.error('Error verificando token:', e);
            }
        }
        
        // Asegurar que el body esté visible
        document.body.style.display = 'block';
        
        // Mostrar calendario
        mostrarCalendario();
        
        // Mostrar botón guardar solo si es profesor
        const btnGuardar = document.getElementById('btnGuardar');
        if (btnGuardar) {
            btnGuardar.style.display = esProfesor ? 'block' : 'none';
        }
        
        // Mostrar botón de login si no está autenticado
        mostrarLoginSiNecesario();
        
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

// Función para mostrar login si es necesario
function mostrarLoginSiNecesario() {
    if (!MODO_WEB || tokenAutenticacion) return;
    
    // Crear modal de login si no existe
    if (!document.getElementById('modalLogin')) {
        const modalLogin = document.createElement('div');
        modalLogin.id = 'modalLogin';
        modalLogin.className = 'modal';
        modalLogin.style.display = 'block';
        modalLogin.innerHTML = `
            <div class="modal-content">
                <h3>🔐 Iniciar Sesión</h3>
                <p>Necesitas iniciar sesión para editar el calendario</p>
                <form id="formLogin">
                    <div class="form-group">
                        <label>Usuario:</label>
                        <input type="text" id="loginUsername" required>
                    </div>
                    <div class="form-group">
                        <label>Contraseña:</label>
                        <input type="password" id="loginPassword" required>
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
        
        document.getElementById('formLogin').addEventListener('submit', async (e) => {
            e.preventDefault();
            await hacerLogin();
        });
        
        document.getElementById('btnCerrarLogin').addEventListener('click', () => {
            modalLogin.style.display = 'none';
        });
    }
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
            usuarioActual = data.usuario;
            esProfesor = data.usuario.permisos && data.usuario.permisos.includes('editar');
            
            const btnGuardar = document.getElementById('btnGuardar');
            if (btnGuardar) {
                btnGuardar.style.display = esProfesor ? 'block' : 'none';
            }
            
            document.getElementById('modalLogin').style.display = 'none';
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
function GetParentResourceName() {
    if (MODO_WEB) {
        return 'web-mode';
    }
    // En FiveM, esta función está disponible globalmente
    if (typeof window.GetParentResourceName === 'function') {
        return window.GetParentResourceName();
    }
    return 'unknown';
}

// Inicializar
document.addEventListener('DOMContentLoaded', function() {
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
        } else {
            // En modo FiveM, ocultar hasta recibir mensaje
            document.body.style.display = 'none';
            console.log('[NUI] Modo FiveM detectado - Esperando mensaje del cliente');
        }
    } catch (error) {
        console.error('Error en inicialización:', error);
        document.body.innerHTML = '<div style="padding: 20px; text-align: center;"><h2>Error al cargar el calendario</h2><p>Revisa la consola para más detalles.</p></div>';
        document.body.style.display = 'block';
    }
});

function inicializarEventos() {
    
    console.log('NUI: Inicializando eventos...');

    // Inicializar selectores de color
    inicializarSelectoresColor();

    // Configurar eventos de clima horario
    const btnCancelarClimaHorario = document.getElementById('btnCancelarClimaHorario');
    const formClimaHorario = document.getElementById('formClimaHorario');
    
    if (btnCancelarClimaHorario) {
        btnCancelarClimaHorario.addEventListener('click', cerrarModalClimaHorario);
    }
    
    if (formClimaHorario) {
        formClimaHorario.addEventListener('submit', guardarClimaHorario);
    }

    document.getElementById('btnCancelarClimaHorario')?.addEventListener('click', cerrarModalClimaHorario);
    document.getElementById('formClimaHorario')?.addEventListener('submit', guardarClimaHorario);   
    document.getElementById('horaPruebaClima')?.addEventListener('input', function() {
        calcularClimaParaHora(this.value);
    });

    document.getElementById('btnAplicarClimaPrueba')?.addEventListener('click', aplicarClimaPrueba);
    document.getElementById('btnProbarClimas')?.addEventListener('click', abrirModalProbarClimas);
    document.getElementById('btnCerrarProbarClimas')?.addEventListener('click', cerrarModalProbarClimas);

    document.getElementById('btnConfirmarEliminarSeparador')?.addEventListener('click', confirmarEliminarSeparador);
    document.getElementById('btnCancelarEliminarSeparador')?.addEventListener('click', cerrarModalEliminarSeparador);
    
    // Botones de cierre (con verificación de existencia)
    const btnCerrar = document.getElementById('btnCerrar');
    const btnCerrar2 = document.getElementById('btnCerrar2');
    
    if (btnCerrar) btnCerrar.addEventListener('click', cerrarCalendario);
    if (btnCerrar2) btnCerrar2.addEventListener('click', cerrarCalendario);
    
    // Botones de semanas
    document.querySelectorAll('.btn-semana').forEach(btn => {
        btn.addEventListener('click', function() {
            cambiarSemana(parseInt(this.dataset.semana));
        });
    });
    
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
        { id: 'formClima', fn: guardarClima }
    ];
    
    elementosForms.forEach(item => {
        const elemento = document.getElementById(item.id);
        if (elemento) {
            elemento.addEventListener('submit', item.fn);
        }
    });
    
    // Botón guardar
    const btnGuardar = document.getElementById('btnGuardar');
    if (btnGuardar) {
        btnGuardar.addEventListener('click', function() {
            guardarCalendario();
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
    
    // Escuchar mensajes de NUI
    window.addEventListener('message', function(event) {
        const data = event.data;
        console.log('NUI: Mensaje recibido:', data.action);
        
        if (data.action === 'abrirCalendario') {
            console.log('NUI: Abriendo calendario con datos:', data.calendario);
            console.log('NUI: Configuración recibida:', data.config);
            
            calendarioData = data.calendario || {};
            esProfesor = data.esProfesor || false;
            config = data.config || {};
            
            // Asegurar que los arrays existan
            if (!config.cursos) config.cursos = [];
            if (!config.meses) config.meses = [];
            if (!config.diasSemana) config.diasSemana = [];
            if (!config.horarios) config.horarios = [];
            if (!config.lunas) config.lunas = [];
            if (!config.eventos) config.eventos = [];
            if (!config.separadores) config.separadores = [];
            
            // Asegurar que climas existe y tiene valores
            if (!config.climas || config.climas.length === 0) {
                console.log('NUI: Config.climas vacío, usando valores por defecto');
                config.climas = [
                    "EXTRASUNNY", "CLEAR", "NEUTRAL", "SMOG", "FOGGY", 
                    "OVERCAST", "CLOUDS", "CLEARING", "RAIN", "THUNDER", 
                    "SNOW", "BLIZZARD", "SNOWLIGHT", "XMAS", "HALLOWEEN"
                ];
            }
            
            console.log('NUI: Climas disponibles:', config.climas);
            
            document.body.style.display = 'block';
            mostrarCalendario();
            
            // Mostrar botón guardar solo si es profesor
            const btnGuardar = document.getElementById('btnGuardar');
            if (btnGuardar) {
                btnGuardar.style.display = esProfesor ? 'block' : 'none';
            }
        }
        
        if (data.action === 'cerrarCalendario') {
            document.body.style.display = 'none';
            // Limpiar cualquier context menu abierto
            cerrarContextMenu();
        }
    });
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
            htmlBarrasEstacion += `
                <div class="barra-estacion" 
                     ${clickHandler}
                     style="left: calc(120px + (100% - 120px) * ${barra.diaInicio} / ${numDias}); 
                            width: calc((100% - 120px) * ${barra.diasDuracion} / ${numDias}); 
                            background: ${colorEstacion};
                            ${cursorStyle}">
                    ${iconoEstacion} ${barra.nombre}
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
    
    let html = htmlBarrasEstacion + `
        <table class="tabla-calendario">
            <thead>
                <tr>
                    <th style="width: 120px;">Horario</th>
    `;
    
    // Encabezados de días con meses
    (config.diasSemana || []).forEach((dia, index) => {
        const diaData = semana.dias && semana.dias[index];
        const mesData = calendarioData.meses && calendarioData.meses[semanaIndex] && calendarioData.meses[semanaIndex][index];
        const mesesDisponibles = config.meses || ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
        
        html += `<th style="min-width: 180px;">
            <div class="mes-header" onclick="${esProfesor ? `abrirModalMeses(${semanaActual})` : ''}">
                ${mesData || mesesDisponibles[0] || 'Enero'} 📅
            </div>
            <div class="dia-header" onclick="${esProfesor ? `abrirModalClima(${semanaActual}, ${index + 1})` : ''}">
                ${dia}
                ${esProfesor ? '<br><small>👆 Click para editar clima</small>' : ''}
            </div>
            <div class="info-dia">
                🌡️ ${diaData?.temperatura || '--'}°C<br>
                🌙 ${diaData?.luna || '--'}<br>
                ${obtenerIconoEvento(diaData?.evento) || '🎉'} ${diaData?.evento || '--'}<br>
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
            // ✅ FIX: Manejar tanto arrays como objetos individuales para compatibilidad
            let separadoresArray = [];
            
            if (Array.isArray(separadoresFranja)) {
                // Si es un array, usar todos los elementos que tengan texto
                separadoresArray = separadoresFranja.filter(sep => sep && sep.texto);
            } else if (separadoresFranja.texto) {
                // Si es un objeto individual con texto, convertirlo a array
                separadoresArray = [separadoresFranja];
            }
            
            // ✅ FIX: Renderizar todos los separadores en orden
            separadoresArray.forEach((separador, separadorIndex) => {
                if (separador && separador.texto) {
                    html += generarHTMLSeparador(separador, horario.hora, separadorIndex);
                }
            });
        }
        
        // Fila normal de horario con información de debug
        html += `<tr>
            <td style="background: #f8f9fa; font-weight: bold; vertical-align: top; position: relative;">
                <div style="padding: 8px;">
                    ${horario.hora}
                    <div style="font-size: 11px; color: #666; margin-top: 3px;">
                        🌤️ ${traducirClima(climaHorario)}
                    </div>
                    <div style="font-size: 10px; color: #888; background: #f0f0f0; padding: 2px 4px; border-radius: 3px; margin-top: 2px;">
                        ${duracionTotal}min
                    </div>
                    ${esProfesor ? `
                        <button class="btn-editar-separador" 
                                onclick="abrirModalClimaHorario('${horario.hora}')" 
                                style="position: absolute; top: 5px; right: 5px; background: #17a2b8; color: white; border: none; padding: 2px 6px; border-radius: 3px; font-size: 10px; cursor: pointer;">
                            🌤️
                        </button>
                        <button class="btn-editar-separador" 
                                onclick="abrirModalSeparador('${horario.hora}')" 
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
                    const clasesOrdenadas = [...clases].sort((a, b) => {
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
                                    oncontextmenu="${esProfesor ? `mostrarContextMenuEvento(event, this, ${semanaActual}, ${diaIndex + 1}, '${horario.hora}', ${eventoIndex}); return false;` : ''}"
                                    ${esProfesor ? `onclick="abrirModalEventoExistente(${semanaActual}, ${diaIndex + 1}, '${horario.hora}', ${eventoIndex})"` : ''}>
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
                    
                    const eventosActivos = eventosArray.filter(evento => evento && evento.texto).length;
                    
                    const espaciosOcupados = clasesArray.length + eventosActivos;
                    
                    // ✅ FIX: Determinar límite de clases basado en la duración real de la franja
                    const maxClasesPermitidas = obtenerLimiteClasesPorFranja(horario.hora);
                    
                    console.log(`📊 Franja ${horario.hora}: ${clasesArray.length}/${maxClasesPermitidas} clases, ${eventosActivos}/2 eventos`);
                    
                    // Mostrar botón de agregar clase solo si no se ha alcanzado el límite específico de la franja
                    if (clasesArray.length < maxClasesPermitidas && espaciosOcupados < 4) {
                        html += `
                            <div class="clase-vacia agregar-mas"
                                data-semana="${semanaActual}"
                                data-dia="${diaIndex + 1}"
                                data-horario="${horario.hora}"
                                onclick="abrirModalClaseNueva(this)">
                                + Agregar Clase
                            </div>
                        `;
                    } else {
                        console.log(`🚫 Botón clase oculto: ${clasesArray.length} clases >= ${maxClasesPermitidas} límite o ${espaciosOcupados}/4 espacios ocupados`);
                    }
                    
                    // ✅ FIX: Mostrar botón de evento solo si no se ha alcanzado el límite de 2 eventos
                    if (eventosActivos < 2 && espaciosOcupados < 4) {
                        html += `
                            <div class="clase-vacia agregar-evento"
                                data-semana="${semanaActual}"
                                data-dia="${diaIndex + 1}"
                                data-horario="${horario.hora}"
                                onclick="abrirModalEventoNuevo(this)">
                                + Agregar Evento
                            </div>
                        `;
                    } else {
                        console.log(`🚫 Botón evento oculto: ${eventosActivos} eventos >= 2 límite o ${espaciosOcupados}/4 espacios ocupados`);
                    }
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
    
    // Mostrar hora sin segundos
    const horaMostrar = clase.horaExacta ? 
        clase.horaExacta.split(':').slice(0, 2).join(':') : '';
    
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
function obtenerOpcionesHorario(semana, dia, horario, claseIndex) {
    const semanaIndex = semana - 1;
    const diaIndex = dia - 1;
    
    const clasesExistentes = calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.clases[horario] || [];
    
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
    
    // ✅ LÓGICA SIMPLIFICADA Y CORREGIDA
    let maxClases = 1;
    let duracionClase = duracionTotal;
    
    // Para franjas de 30 minutos (20:00-20:30, 22:30-23:00) -> SOLO 1 CLASE
    if (duracionTotal === 30) {
        maxClases = 1;
        duracionClase = 30;
        console.log('🎯 Config: 1 clase de 30min (franja exacta de 30min)');
    }
    // Para franjas de 50 minutos (23:00-23:50) -> 2 clases
    else if (duracionTotal === 50) {
        maxClases = 2;
        duracionClase = 25;
        console.log('🎯 Config: 2 clases de 25min (franja de 50min)');
    }
    // Para franjas de 60 minutos (17:00-18:00, etc.) -> 2 clases
    else if (duracionTotal >= 60) {
        maxClases = 2;
        duracionClase = 30;
        console.log('🎯 Config: 2 clases de 30min (franja larga)');
    }
    // Para cualquier otra duración -> 1 clase
    else {
        maxClases = 1;
        duracionClase = duracionTotal;
        console.log('🎯 Config: 1 clase de ' + duracionClase + 'min (franja personalizada)');
    }
    
    console.log('📚 Máximo de clases permitidas:', maxClases);
    console.log('⏰ Duración por clase:', duracionClase, 'minutos');
    
    // Generar opciones según la duración
    const opciones = [];
    for (let i = 0; i < maxClases; i++) {
        const inicioMinutos = horaInicioMinutos + (i * duracionClase);
        const finMinutos = inicioMinutos + duracionClase;
        
        // Verificar que no exceda el fin de la franja
        if (finMinutos <= horaFinMinutos) {
            const horaInicio = convertirMinutosAHora(inicioMinutos);
            const horaFin = convertirMinutosAHora(finMinutos);
            
            opciones.push({
                value: horaInicio,
                label: `${horaInicio} - ${horaFin} (${duracionClase} min)`,
                duracion: duracionClase
            });
            
            console.log('➕ Opción generada:', horaInicio, '-', horaFin);
        }
    }
    
    // Si ya hay clases, determinar qué opciones están ocupadas
    const horasOcupadas = clasesExistentes
        .filter((clase, index) => index !== claseIndex)
        .map(clase => {
            if (clase.horaExacta) {
                return clase.horaExacta.split(':').slice(0, 2).join(':');
            }
            return null;
        })
        .filter(hora => hora);
    
    console.log('⛔ Horas ocupadas:', horasOcupadas);
    console.log('📋 Todas las opciones:', opciones.map(o => o.value));
    
    // Filtrar opciones disponibles
    const opcionesDisponibles = opciones.filter(opcion => 
        !horasOcupadas.includes(opcion.value)
    );
    
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
    const clasesArray = calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.clases[horario] || [];
    
    console.log('🔍 Verificando límites para franja:', horario);
    
    // ✅ FIX: Usar la función auxiliar para determinar límites
    const maxClasesPermitidas = obtenerLimiteClasesPorFranja(horario);
    
    console.log('📚 Máximo de clases permitidas:', maxClasesPermitidas);
    console.log('📊 Clases existentes:', clasesArray.length);
    
    // Verificar límite de clases según duración
    if (clasesArray.length >= maxClasesPermitidas) {
        mostrarNotificacion(`❌ Límite alcanzado: Máximo ${maxClasesPermitidas} clase(s) permitida(s) en esta franja`, 'error');
        return;
    }
    
    // Obtener opciones de horario disponibles
    const opcionesHorario = obtenerOpcionesHorario(semana, dia, horario, -1);
    
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
    
    inicializarSelectorCursos([]);
    
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

function generarHTMLSeparador(separador, horario, separadorIndex) {
    let estilo = 'background: #740001; color: white; padding: 12px; height: 50px;';
    if (separador.colorFondo) estilo += `background: ${separador.colorFondo} !important;`;
    if (separador.colorTexto) estilo += `color: ${separador.colorTexto} !important;`;
    estilo += 'border-bottom: 2px solid #d3a625; border-top: 2px solid #d3a625; font-size: 16px; font-weight: bold; text-align: center; vertical-align: middle;';
    
    const numDias = (config.diasSemana || []).length;
    
    let contenido = '';
    
    // Si tiene hora personalizada, mostrarla
    if (separador.mostrarHora) {
        const horaInicioFormateada = formatearHoraConMinutos(separador.horaInicio);
        const horaFinFormateada = formatearHoraConMinutos(separador.horaFin);
        
        const horaMostrar = horaInicioFormateada && horaFinFormateada 
            ? `${horaInicioFormateada} - ${horaFinFormateada}`
            : horario;
        
        contenido = `
            <div style="display: flex; align-items: center; justify-content: space-between; height: 100%; padding: 0 10px;"
                 oncontextmenu="${esProfesor ? `mostrarContextMenuSeparador(event, '${horario}', ${separadorIndex}); return false;` : ''}">
                <div style="background: rgba(0,0,0,0.3); padding: 5px 10px; border-radius: 4px; font-size: 14px; min-width: 120px; text-align: center;">
                    ${horaMostrar}
                </div>
                <span style="font-weight: bold; flex: 1; text-align: center;">${separador.texto}</span>
                ${esProfesor ? `<button class="btn-editar-separador" onclick="event.stopPropagation(); abrirModalSeparador('${horario}', ${separadorIndex})" style="margin-left: 10px;">✏️</button>` : ''}
            </div>
        `;
    } else {
        contenido = `
            <div style="display: flex; align-items: center; justify-content: center; height: 100%; padding: 0 10px;"
                 oncontextmenu="${esProfesor ? `mostrarContextMenuSeparador(event, '${horario}', ${separadorIndex}); return false;` : ''}">
                <span style="font-weight: bold;">${separador.texto}</span>
                ${esProfesor ? `<button class="btn-editar-separador" onclick="event.stopPropagation(); abrirModalSeparador('${horario}', ${separadorIndex})" style="margin-left: 10px;">✏️</button>` : ''}
            </div>
        `;
    }
    
    return `
        <tr class="separador-fila" data-horario="${horario}" data-separador-index="${separadorIndex}" data-tipo="separador">
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
    
    contextMenu.innerHTML = `
        <div class="context-menu-item" onclick="abrirModalSeparador('${horario}', ${separadorIndex})">
            ✏️ Editar Separador
        </div>
        <div class="context-menu-item eliminar" onclick="eliminarSeparador('${horario}', ${separadorIndex})">
            🗑️ Eliminar Separador
        </div>
    `;
    
    document.body.appendChild(contextMenu);
    
    // Resaltar el separador
    const separadorElement = document.querySelector(`.separador-fila[data-horario="${horario}"][data-separador-index="${separadorIndex}"]`);
    if (separadorElement) {
        separadorElement.classList.add('con-menu-contexto');
    }
}


// ENCONTRAR Y REEMPLAZAR en script.js - Función eliminarSeparador
function eliminarSeparador(horario, separadorIndex = null) {
    if (!esProfesor || !horario) return;
    
    // Obtener datos del separador para mostrar en el modal
    const separadoresFranja = calendarioData.separadores && calendarioData.separadores[horario];
    let separadorData = null;
    
    if (separadoresFranja) {
        if (Array.isArray(separadoresFranja)) {
            if (separadorIndex !== null && separadoresFranja[separadorIndex]) {
                separadorData = separadoresFranja[separadorIndex];
            }
        } else if (separadorIndex === null || separadorIndex === 0) {
            separadorData = separadoresFranja;
        }
    }
    
    if (!separadorData || !separadorData.texto) {
        mostrarNotificacion('No se encontró el separador para eliminar', 'error');
        return;
    }
    
    // Guardar referencia para eliminar
    separadorParaEliminar = { horario, index: separadorIndex };
    
    // Mostrar modal de confirmación personalizado
    document.getElementById('textoEliminarSeparador').textContent = 
        `¿Estás seguro de que quieres eliminar el separador "${separadorData.texto}"?`;
    
    document.getElementById('modalEliminarSeparador').style.display = 'block';
    
    // Cerrar context menu si está abierto
    cerrarContextMenu();
}

// Y actualizar la función de mostrar modal de eliminación
function mostrarModalEliminarSeparador(horario, separadorIndex = null) {
    if (!esProfesor || !horario) return;
    
    const separadoresFranja = calendarioData.separadores && calendarioData.separadores[horario];
    let separadorData = null;
    
    if (separadoresFranja) {
        if (Array.isArray(separadoresFranja)) {
            if (separadorIndex !== null && separadoresFranja[separadorIndex]) {
                separadorData = separadoresFranja[separadorIndex];
            }
        } else if (separadorIndex === null || separadorIndex === 0) {
            separadorData = separadoresFranja;
        }
    }
    
    if (!separadorData || !separadorData.texto) return;
    
    separadorParaEliminar = { horario, index: separadorIndex };
    
    document.getElementById('textoEliminarSeparador').textContent = 
        `¿Estás seguro de que quieres eliminar el separador "${separadorData.texto}"?`;
    
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
    
    const clasesArray = calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.clases[horario];
    const claseData = clasesArray && clasesArray[claseIndex] ? clasesArray[claseIndex] : {
        titulo: "",
        descripcion: "",
        profesor: "",
        cursos: [],
        horaExacta: ""
    };
    
    // Obtener opciones de horario disponibles (excluyendo la clase actual)
    const opcionesHorario = obtenerOpcionesHorario(semana, dia, horario, parseInt(claseIndex));
    
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
    
    inicializarSelectorCursos(Array.isArray(claseData.cursos) ? claseData.cursos : []);
    
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
    
    const claseData = calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.clases[horario]?.[claseIndex];
    
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
        
        if (calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.clases[horario]) {
            calendarioData.semanas[semanaIndex].dias[diaIndex].clases[horario].splice(claseIndex, 1);
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
    
    const diaData = calendarioData.semanas[semanaIndex]?.dias[diaIndex] || {
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
    
    const cursosDisponibles = config.cursos || ['1º', '2º', '3º', '4º', '5º', '6º', '7º', 'Todos'];
    
    cursosDisponibles.forEach(curso => {
        const isSelected = cursosSeleccionados.includes(curso);
        const option = document.createElement('div');
        option.className = `curso-option ${isSelected ? 'selected' : ''} ${curso === 'Todos' ? 'todos' : ''}`;
        option.innerHTML = `
            <input type="checkbox" ${isSelected ? 'checked' : ''} value="${curso}" style="display: none;">
            ${curso}
        `;
        option.addEventListener('click', function() {
            const checkbox = this.querySelector('input');
            
            // Si se selecciona "Todos", deseleccionar los demás
            if (curso === 'Todos' && !checkbox.checked) {
                document.querySelectorAll('#cursosSelector .curso-option').forEach(opt => {
                    if (opt !== this) {
                        const otherCheckbox = opt.querySelector('input');
                        otherCheckbox.checked = false;
                        opt.classList.remove('selected');
                    }
                });
                checkbox.checked = true;
                this.classList.add('selected');
            }
            // Si se selecciona un curso específico, deseleccionar "Todos"
            else if (curso !== 'Todos' && !checkbox.checked) {
                const todosOption = document.querySelector('#cursosSelector .curso-option.todos');
                if (todosOption) {
                    const todosCheckbox = todosOption.querySelector('input');
                    todosCheckbox.checked = false;
                    todosOption.classList.remove('selected');
                }
                checkbox.checked = true;
                this.classList.add('selected');
            }
            // Si se deselecciona
            else {
                checkbox.checked = !checkbox.checked;
                this.classList.toggle('selected', checkbox.checked);
            }
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
        const [horas, minutos] = horaString.split(':');
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

// Función auxiliar para determinar límites basados en duración - CORREGIDA
function obtenerLimiteClasesPorFranja(horario) {
    const horarioConfig = config.horarios.find(h => h.hora === horario);
    
    if (!horarioConfig) return 2; // Por defecto
    
    // ✅ CORRECCIÓN: Calcular duración en minutos correctamente
    const horaInicioMinutos = convertirHoraDecimalAMinutos(horarioConfig.inicio);
    const horaFinMinutos = convertirHoraDecimalAMinutos(horarioConfig.fin);
    const duracionTotal = horaFinMinutos - horaInicioMinutos;
    
    console.log(`⏱️ Franja ${horario}: ${duracionTotal} minutos (${horarioConfig.inicio} -> ${horarioConfig.fin})`);
    
    // Para franjas de 30 minutos: solo 1 clase
    if (duracionTotal === 30) {
        console.log('🎯 Límite: 1 clase (franja de 30min)');
        return 1;
    }
    // Para franjas de 50 minutos: 2 clases
    else if (duracionTotal === 50) {
        console.log('🎯 Límite: 2 clases (franja de 50min)');
        return 2;
    }
    // Para franjas de 60+ minutos: 2 clases
    else if (duracionTotal >= 60) {
        console.log('🎯 Límite: 2 clases (franja de 60+ min)');
        return 2;
    }
    // Para cualquier otra duración: 1 clase
    else {
        console.log('🎯 Límite: 1 clase (franja de ' + duracionTotal + 'min)');
        return 1;
    }
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
    
    // Obtener y normalizar la hora exacta (CORREGIDO: usar el select correcto)
    const horaExactaSelect = document.getElementById('horaExactaClaseSelect');
    const horaExacta = horaExactaSelect ? horaExactaSelect.value.split(':').slice(0, 2).join(':') : "";
    
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
    
    const claseData = calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.clases[horario]?.[claseIndex];
    
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
    if (MODO_WEB) {
        // En modo web, solo ocultar (no hay que cerrar NUI)
        document.body.style.display = 'none';
    } else {
        // En modo FiveM, notificar al cliente
        fetch(`https://${GetParentResourceName()}/cerrarCalendario`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: JSON.stringify({})
        }).then(() => {
            document.body.style.display = 'none';
        });
    }
}

// Guardar cambios
document.getElementById('btnGuardar').addEventListener('click', function() {
    fetch(`https://${GetParentResourceName()}/guardarCambios`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: JSON.stringify({calendario: calendarioData})
    })
    .then(response => response.json())
    .then(data => {
        if (data === 'ok') {
            mostrarNotificacion('Cambios guardados correctamente', 'success');
        } else {
            mostrarNotificacion('Error al guardar cambios', 'error');
        }
    });
});

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
    
    // ✅ FIX: Verificar límite de eventos (máximo 2 por franja)
    const semanaIndex = semana - 1;
    const diaIndex = dia - 1;
    
    const clasesArray = calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.clases[horario] || [];
    const eventosArray = calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.eventosHorario && calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.eventosHorario[horario] ? 
        (Array.isArray(calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.eventosHorario[horario]) ? 
         calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.eventosHorario[horario] : 
         [calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.eventosHorario[horario]]) : [];
    
    const eventosActivos = eventosArray.filter(evento => evento && evento.texto).length;
    const elementosExistentes = clasesArray.length + eventosActivos;
    
    console.log(`📊 Elementos en franja ${horario}: ${clasesArray.length} clases + ${eventosActivos} eventos = ${elementosExistentes}/4`);
    
    // ✅ FIX: Máximo 2 eventos por franja
    if (eventosActivos >= 2) {
        mostrarNotificacion('❌ Límite alcanzado: Máximo 2 eventos por franja horaria', 'error');
        return;
    }
    
    // ✅ FIX: Máximo 4 elementos totales (clases + eventos) por franja
    if (elementosExistentes >= 4) {
        mostrarNotificacion('❌ Límite alcanzado: Máximo 4 elementos (clases + eventos) por franja horaria', 'error');
        return;
    }
    
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
    const eventosArray = calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.eventosHorario && calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.eventosHorario[horario] ? 
        (Array.isArray(calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.eventosHorario[horario]) ? 
         calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.eventosHorario[horario] : 
         [calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.eventosHorario[horario]]) : [];
    
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
                separadorData = { ...separadorData, ...separadoresFranja[separadorIndex] };
            }
        } else if (separadorIndex === null || separadorIndex === 0) {
            // Si es un objeto individual y es el primer separador (o nuevo)
            separadorData = { ...separadorData, ...separadoresFranja };
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
        let horaInicioValue = separadorData.horaInicio || "";
        let horaFinValue = separadorData.horaFin || "";
        
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
    
    // ✅ FIX: Verificar límites antes de guardar
    const clasesArray = calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.clases[horario] || [];
    const eventosArray = calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.eventosHorario && calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.eventosHorario[horario] ? 
        (Array.isArray(calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.eventosHorario[horario]) ? 
         calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.eventosHorario[horario] : 
         [calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.eventosHorario[horario]]) : [];
    
    const eventosActivos = eventosArray.filter(evento => evento && evento.texto).length;
    const elementosExistentes = clasesArray.length + eventosActivos;
    
    // Si estamos editando un evento existente, no contar doble
    const esEdicion = eventoIndex < eventosActivos;
    
    if (!esEdicion && eventosActivos >= 2) {
        mostrarNotificacion('❌ No se puede agregar evento: límite de 2 eventos por franja alcanzado', 'error');
        return;
    }
    
    if (!esEdicion && elementosExistentes >= 4) {
        mostrarNotificacion('❌ No se puede agregar evento: límite de 4 elementos por franja alcanzado', 'error');
        return;
    }
    
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
        horaInicio = `${partes[0]}:${partes[1]}`; // Mantener solo HH:MM
    }
    
    if (horaFin && horaFin.includes(':')) {
        const partes = horaFin.split(':');
        horaFin = `${partes[0]}:${partes[1]}`; // Mantener solo HH:MM
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
        <div class="context-menu-item eliminar" onclick="eliminarEvento(${semana}, ${dia}, '${horario}', ${eventoIndex})">
            🗑️ Eliminar Evento
        </div>
    `;
    
    document.body.appendChild(contextMenu);
}

function eliminarEvento(semana, dia, horario, eventoIndex) {
    const semanaIndex = semana - 1;
    const diaIndex = dia - 1;
    
    if (calendarioData.semanas[semanaIndex]?.dias[diaIndex]?.eventosHorario[horario]) {
        // ✅ FIX: Manejar tanto arrays como objetos individuales
        if (Array.isArray(calendarioData.semanas[semanaIndex].dias[diaIndex].eventosHorario[horario])) {
            // Es un array, eliminar el elemento específico
            calendarioData.semanas[semanaIndex].dias[diaIndex].eventosHorario[horario].splice(eventoIndex, 1);
            
            // Si el array queda vacío, limpiarlo
            if (calendarioData.semanas[semanaIndex].dias[diaIndex].eventosHorario[horario].length === 0) {
                calendarioData.semanas[semanaIndex].dias[diaIndex].eventosHorario[horario] = {
                    texto: "",
                    colorFondo: "",
                    colorTexto: "",
                    cursiva: false
                };
            }
        } else {
            // Es un objeto individual, limpiarlo
            calendarioData.semanas[semanaIndex].dias[diaIndex].eventosHorario[horario] = {
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


// NUEVO: Función para mostrar modal de confirmación de eliminación de separador
function mostrarModalEliminarSeparador(horario) {
    if (!esProfesor || !horario) return;
    
    const separadorData = calendarioData.separadores && calendarioData.separadores[horario];
    if (!separadorData || !separadorData.texto) return;
    
    separadorParaEliminar = horario;
    
    document.getElementById('textoEliminarSeparador').textContent = 
        `¿Estás seguro de que quieres eliminar el separador "${separadorData.texto}"?`;
    
    document.getElementById('modalEliminarSeparador').style.display = 'block';
}

// REEMPLAZAR la función confirmarEliminarSeparador
function confirmarEliminarSeparador() {
    if (!separadorParaEliminar) return;
    
    const { horario, index } = separadorParaEliminar;
    
    console.log('Eliminando separador:', horario, 'índice:', index);
    
    if (calendarioData.separadores && calendarioData.separadores[horario]) {
        if (Array.isArray(calendarioData.separadores[horario])) {
            // Eliminar el separador específico del array
            if (index !== null && index < calendarioData.separadores[horario].length) {
                calendarioData.separadores[horario].splice(index, 1);
                
                // Si el array queda vacío, eliminarlo completamente
                if (calendarioData.separadores[horario].length === 0) {
                    delete calendarioData.separadores[horario];
                }
            }
        } else {
            // Si es un objeto individual, eliminarlo
            delete calendarioData.separadores[horario];
        }
        
        mostrarNotificacion('Separador eliminado correctamente', 'success');
        guardarCalendario(); // Guardar cambios automáticamente
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
        "EXTRASUNNY", "CLEAR", "NEUTRAL", "SMOG", "FOGGY", 
        "OVERCAST", "CLOUDS", "CLEARING", "RAIN", "THUNDER", 
        "SNOW", "BLIZZARD", "SNOWLIGHT", "XMAS", "HALLOWEEN"
    ];
    
    console.log('Climas disponibles:', climasDisponibles);
    
    if (climasDisponibles.length === 0) {
        console.error('No hay climas disponibles en la configuración');
        mostrarNotificacion('Error: No hay climas configurados', 'error');
        return;
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

// Función separada para guardar
function guardarCalendario() {
    if (!esProfesor) {
        mostrarNotificacion('No tienes permisos para guardar cambios', 'error');
        return;
    }
    
    console.log('Enviando datos al servidor:', calendarioData);
    
    if (MODO_WEB) {
        // Modo web: usar API REST
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
        .then(response => {
            if (!response.ok) {
                if (response.status === 401) {
                    // Token inválido, pedir login de nuevo
                    tokenAutenticacion = null;
                    localStorage.removeItem('calendario_token');
                    mostrarLoginSiNecesario();
                    throw new Error('Sesión expirada');
                }
                throw new Error('Error en la respuesta del servidor');
            }
            return response.json();
        })
        .then(data => {
            console.log('Respuesta del servidor:', data);
            if (data.success) {
                mostrarNotificacion('✅ Cambios guardados correctamente', 'success');
            } else {
                mostrarNotificacion('❌ Error al guardar cambios', 'error');
            }
        })
        .catch(error => {
            console.error('Error al guardar:', error);
            mostrarNotificacion('❌ Error de conexión al guardar: ' + error.message, 'error');
        });
    } else {
        // Modo FiveM: usar NUI callback
        fetch(`https://${GetParentResourceName()}/guardarCambios`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({
                calendario: calendarioData
            })
        })
        .then(response => {
            if (!response.ok) {
                throw new Error('Error en la respuesta del servidor');
            }
            return response.json();
        })
        .then(data => {
            console.log('Respuesta del servidor:', data);
            if (data === 'ok' || data === true) {
                mostrarNotificacion('✅ Cambios guardados correctamente', 'success');
            } else {
                mostrarNotificacion('❌ Error al guardar cambios', 'error');
            }
        })
        .catch(error => {
            console.error('Error al guardar:', error);
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
function aplicarClimaPrueba() {
    const resultadoDiv = document.getElementById('resultadoClimaPrueba');
    const clima = resultadoDiv.dataset.climaActual;
    const hora = document.getElementById('horaPruebaClima').value;
    
    if (!clima) {
        mostrarNotificacion('Primero selecciona una hora para probar', 'error');
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
    
    document.getElementById('btnGuardar').style.display = 'block';
    cerrarModalConfirmarEliminarBarra();
    barraParaEliminar = null;
}

function cerrarModalConfirmarEliminarBarra() {
    document.getElementById('modalConfirmarEliminarBarra').style.display = 'none';
    barraParaEliminar = null;
}

document.getElementById('btnAgregarBarra')?.addEventListener('click', function() {
    document.getElementById('modalBarraIndex').value = '-1';
    document.getElementById('estacionBarra').value = 'Primavera';
    document.getElementById('diaInicioBarra').value = '0';
    document.getElementById('diasDuracionBarra').value = '7';
    document.getElementById('tituloModalBarra').textContent = '➕ Nueva Barra de Estación';
    
    actualizarPreviewBarra();
    document.getElementById('modalEditarBarra').style.display = 'block';
});

document.getElementById('btnCerrarBarrasEstacion')?.addEventListener('click', cerrarModalBarrasEstacion);
document.getElementById('btnCancelarEditarBarra')?.addEventListener('click', cerrarModalEditarBarra);
document.getElementById('btnConfirmarEliminarBarra')?.addEventListener('click', confirmarEliminarBarraEstacion);
document.getElementById('btnCancelarEliminarBarra')?.addEventListener('click', cerrarModalConfirmarEliminarBarra);

document.getElementById('formEditarBarra')?.addEventListener('submit', function(e) {
    e.preventDefault();
    guardarBarra();
});

// Event listeners para actualizar preview en tiempo real
document.getElementById('estacionBarra')?.addEventListener('change', actualizarPreviewBarra);
document.getElementById('diaInicioBarra')?.addEventListener('input', actualizarPreviewBarra);
document.getElementById('diasDuracionBarra')?.addEventListener('input', actualizarPreviewBarra);

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
    
    document.getElementById('btnGuardar').style.display = 'block';
}