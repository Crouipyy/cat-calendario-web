Config = {}

Config.ZonaHoraria = 1 -- UTC+1 para España (ajustar según servidor)

-- O mejor, detectar automáticamente:
Config.DiferenciaHoraria = function()
    local horaUTC = os.date("!%H")
    local horaLocal = os.date("%H")
    return (tonumber(horaLocal) - tonumber(horaUTC)) % 24
end

-- Configuración de franjas horarias EXTENDIDAS
Config.Horarios = {
    {hora = "16:10 - 17:00", inicio = 16.17, fin = 17, clima = "CLEARING"},      -- 16:10 = 16 + 10/60 = 16.17
    {hora = "17:00 - 18:00", inicio = 17, fin = 18, clima = "CLEARING"},
    {hora = "18:00 - 19:00", inicio = 18, fin = 19, clima = "CLEAR"},
    {hora = "19:00 - 20:00", inicio = 19, fin = 20, clima = "FOGGY"},
    {hora = "20:00 - 20:30", inicio = 20, fin = 20.5, clima = "FOGGY"},          -- 20:30 = 20.5
    {hora = "21:45 - 22:30", inicio = 21.75, fin = 22.5, clima = "FOGGY"},       -- 21:45 = 21 + 45/60 = 21.75
    {hora = "22:30 - 23:00", inicio = 22.5, fin = 23, clima = "CLEAR"},          -- 22:30 = 22.5
    {hora = "23:00 - 23:50", inicio = 23, fin = 23.83, clima = "CLEAR"},         -- 23:50 = 23 + 50/60 ≈ 23.83
    {hora = "00:30 - 01:00", inicio = 0.5, fin = 1, clima = "CLEAR"}             -- 00:30 = 0.5, 01:00 = 1
}

-- Estaciones del año
Config.Estaciones = {
    [1] = "Otoño",
    [2] = "Invierno", 
    [3] = "Primavera",
    [4] = "Verano"
}

-- NUEVO: Configuración de estaciones por día (2 semanas = 14 días)
-- Puedes asignar cualquier estación a cualquier día
-- Semana 1: Días 1-7, Semana 2: Días 8-14
Config.EstacionesPorDia = {
    -- Semana 1
    [1] = {dia = 1, estacion = "Otoño"},      -- Lunes Semana 1
    [2] = {dia = 2, estacion = "Otoño"},      -- Martes Semana 1
    [3] = {dia = 3, estacion = "Otoño"},      -- Miércoles Semana 1
    [4] = {dia = 4, estacion = "Otoño"},      -- Jueves Semana 1
    [5] = {dia = 5, estacion = "Invierno"},   -- Viernes Semana 1
    [6] = {dia = 6, estacion = "Invierno"},   -- Sábado Semana 1
    [7] = {dia = 7, estacion = "Invierno"},   -- Domingo Semana 1
    -- Semana 2
    [8] = {dia = 1, estacion = "Primavera"},  -- Lunes Semana 2
    [9] = {dia = 2, estacion = "Primavera"},  -- Martes Semana 2
    [10] = {dia = 3, estacion = "Primavera"}, -- Miércoles Semana 2
    [11] = {dia = 4, estacion = "Verano"},    -- Jueves Semana 2
    [12] = {dia = 5, estacion = "Verano"},    -- Viernes Semana 2
    [13] = {dia = 6, estacion = "Verano"},    -- Sábado Semana 2
    [14] = {dia = 7, estacion = "Verano"}     -- Domingo Semana 2
}

-- Días de la semana
Config.DiasSemana = {
    "Sábado", "Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes"
}

-- Meses del año para roleo
Config.Meses = {
    "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
    "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
}

-- Cursos disponibles
Config.Cursos = {
    "1º", "2º", "3º", "4º", "5º", "6º", "7º", "Todos"
}

-- Eventos especiales con iconos
Config.EventosEspeciales = {
    {nombre = "Ninguno", icono = ""},
    {nombre = "Inicio de Curso", icono = "💼"},
    {nombre = "House Day", icono = "🏰"},
    {nombre = "Music Day", icono = "🎶"},
    {nombre = "Ghost Day", icono = "👻"},
    {nombre = "Año Nuevo", icono = "🎆"},
    {nombre = "Festividad de Invierno", icono = "⛄"},
    {nombre = "San Valentin", icono = "💘"},
    {nombre = "Cartas Encantadas", icono = "💌"},
    {nombre = "Día del Teatro", icono = "🎭"},
    {nombre = "Día de San Patricio", icono = "🍀"},
    {nombre = "Festival de Equinoccio", icono = "🌒☀️"},
    {nombre = "Pascua", icono = "🥚"},
    {nombre = "April Fool's", icono = "🤡"},
    {nombre = "Festival de Primavera", icono = "🌸"},
    {nombre = "Día de Hogwarts", icono = "🦉"},
    {nombre = "Día del Invernadero", icono = "🌱"},
    {nombre = "Dia del Repaso", icono = "📖"},
    {nombre = "Fin de Examenes", icono = "✍️"},
    {nombre = "Fin de Curso", icono = "🎓"},
    {nombre = "Halloween", icono = "🎃"},
    {nombre = "Navidad", icono = "❄️"},
    {nombre = "Torneo de los Tres Magos", icono = "⚡"},
    {nombre = "Partido de Quidditch", icono = "🏆"},
    {nombre = "Exámenes Finales", icono = "📚"},
    {nombre = "Fiesta de Bienvenida", icono = "🎉"},
    {nombre = "Baile de Navidad", icono = "💃"},
    {nombre = "Visita a Hogsmeade", icono = "🏘️"},
    {nombre = "Celebración de Cumpleaños", icono = "🎂"},
    {nombre = "Concierto del Coro", icono = "🎵"},
    {nombre = "Exposición de Arte Mágico", icono = "🎨"},
    {nombre = "Feria del Libro", icono = "📖"},
    {nombre = "Torneo de Duelo", icono = "⚔️"}
}

-- Separadores predefinidos
Config.Separadores = {
    "TOQUE DE QUEDA",
    "DESCANSO",
    "COMEDOR",
    "RECREO",
    "ACTIVIDADES EXTRAESCOLARES",
    "CLUBES",
    "HORARIO NOCTURNO",
    "HORA DE ESTUDIO",
    "CLASES NOCTURNAS",
    "GUARDIA"
}

-- Colores predefinidos para eventos y separadores
Config.Colores = {
    {nombre = "Rojo Gryffindor", valor = "#740001"},
    {nombre = "Dorado Gryffindor", valor = "#d3a625"},
    {nombre = "Azul Ravenclaw", valor = "#0e1a40"},
    {nombre = "Bronce Ravenclaw", valor = "#946b2d"},
    {nombre = "Amarillo Hufflepuff", valor = "#ecb939"},
    {nombre = "Negro Hufflepuff", valor = "#372e29"},
    {nombre = "Verde Slytherin", valor = "#1a472a"},
    {nombre = "Plateado Slytherin", valor = "#5d5d5d"},
    {nombre = "Rojo Oscuro", valor = "#8b0000"},
    {nombre = "Verde Oscuro", valor = "#006400"},
    {nombre = "Azul Oscuro", valor = "#00008b"},
    {nombre = "Morado", valor = "#4b0082"},
    {nombre = "Naranja", valor = "#ff8c00"},
    {nombre = "Rosa", valor = "#ff69b4"},
    {nombre = "Gris", valor = "#808080"},
    {nombre = "Negro", valor = "#000000"},
    {nombre = "Blanco", valor = "#ffffff"}
}

-- Fases lunares (mejoradas)
Config.Lunas = {
    "Luna Nueva",
    "Luna Creciente",
    "Cuarto Creciente", 
    "Gibosa Creciente",
    "Luna Llena",
    "Gibosa Menguante",
    "Cuarto Menguante",
    "Luna Menguante"
}

-- Climas disponibles (compatibles con qb-weathersync)
Config.Climas = {
    "EXTRASUNNY",
    "CLEAR", 
    "NEUTRAL",
    "SMOG",
    "FOGGY",
    "OVERCAST",
    "CLOUDS",
    "CLEARING",
    "RAIN",
    "THUNDER",
    "SNOW",
    "BLIZZARD",
    "SNOWLIGHT",
    "XMAS",
    "HALLOWEEN"
}

-- Rangos de temperatura por estación (mantenemos para roleo)
Config.Temperaturas = {
    ["Primavera"] = {min = 15, max = 25},
    ["Verano"] = {min = 25, max = 35},
    ["Otoño"] = {min = 10, max = 20},
    ["Invierno"] = {min = -5, max = 10}
}

-- Jobs que pueden editar el calendario (profesores)
Config.JobsPermitidos = {
    "escuela",
    "director",
    "subdirector"
}

-- Grados que tienen permisos
Config.GradosPermitidos = {
    ["escuela"] = {0, 1},
    ["director"] = {0},
    ["subdirector"] = {0}
}

-- Tamaños de texto para separadores
Config.TamanosTexto = {
    {nombre = "Pequeño", valor = "12px"},
    {nombre = "Mediano", valor = "14px"},
    {nombre = "Grande", valor = "16px"},
    {nombre = "Muy Grande", valor = "18px"},
    {nombre = "Enorme", valor = "20px"}
}

-- Alturas para separadores
Config.AlturasSeparador = {
    {nombre = "Delgado", valor = "30px"},
    {nombre = "Normal", valor = "40px"},
    {nombre = "Alto", valor = "50px"},
    {nombre = "Muy Alto", valor = "60px"}
}

-- Configuración del servidor web externo
Config.WebServer = {
    enabled = true, -- Activar sincronización con servidor web
    url = "http://localhost:3000", -- URL del servidor web (cambiar por tu IP pública si es necesario)
    syncInterval = 30, -- Intervalo de sincronización en segundos (0 para desactivar auto-sync)
    apiKey = "" -- Opcional: API key para autenticación (dejar vacío si no se usa)
}

-- NUEVO: Puntos de interacción para abrir el calendario
Config.PuntosInteraccion = {
    -- Ejemplo de coordenadas para Hogwarts (ajusta según tu mapa)
    {x = 3432.541016, y = 7038.139160, z = 74.107834, descripcion = "Tablero de anuncios - Entrada Principal"},
    {x = -1080.0, y = -295.0, z = 37.8, descripcion = "Tablero de anuncios - Gran Comedor"},
    {x = -1065.0, y = -310.0, z = 37.8, descripcion = "Tablero de anuncios - Sala Común"},
    -- Añade más puntos según necesites
}