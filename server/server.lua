local QBCore = nil
local calendarioData = {}

local climaInterval = nil
local ultimoClimaAplicado = nil

-- Función para guardar en MySQL
local function GuardarCalendarioEnMySQL(datos)
    if not Config.Database or not Config.Database.enabled then
        return false
    end
    
    if not datos or next(datos) == nil then
        print('[Calendario] No hay datos para guardar en MySQL')
        return false
    end
    
    -- Actualizar timestamp
    datos.ultimaActualizacion = os.time()
    local datosJSON = json.encode(datos)
    
    -- Usar oxmysql para guardar en MySQL
    -- INSERT ... ON DUPLICATE KEY UPDATE para actualizar el registro con id=1
    MySQL.Async.execute(
        [[INSERT INTO calendario (id, datos, ultima_actualizacion, actualizado_por) 
          VALUES (1, ?, ?, 'FiveM')
          ON DUPLICATE KEY UPDATE 
          datos = VALUES(datos), 
          ultima_actualizacion = VALUES(ultima_actualizacion),
          actualizado_por = VALUES(actualizado_por)]],
        {datosJSON, datos.ultimaActualizacion},
        function(affectedRows)
            if affectedRows > 0 then
                print('[Calendario] ✅ Calendario guardado en MySQL correctamente')
            else
                print('[Calendario] ⚠️ No se pudo guardar en MySQL')
            end
        end
    )
    
    return true
end

-- Función para cargar desde MySQL
local function CargarCalendarioDesdeMySQL()
    if not Config.Database or not Config.Database.enabled then
        return false
    end
    
    MySQL.Async.fetchAll(
        'SELECT datos, ultima_actualizacion FROM calendario WHERE id = 1 LIMIT 1',
        {},
        function(result)
            if result and #result > 0 then
                local datos, error = json.decode(result[1].datos)
                if datos then
                    calendarioData = datos
                    print('[Calendario] ✅ Calendario cargado desde MySQL')
                    print('[Calendario] Timestamp MySQL:', result[1].ultima_actualizacion)
                    
                    -- Asegurar que climasHorario existe
                    AsegurarClimasHorario()
                else
                    print('[Calendario] ⚠️ Error decodificando datos de MySQL:', error)
                end
            else
                print('[Calendario] ⚠️ No hay datos en MySQL, usando archivo local')
            end
        end
    )
    
    return true
end

-- Función para asegurar que climasHorario tenga valores
local function AsegurarClimasHorario()
    if not calendarioData.climasHorario then
        calendarioData.climasHorario = {}
        print('[Calendario] climasHorario creado desde cero')
    end
    
    -- Verificar y completar climas faltantes
    for _, horario in ipairs(Config.Horarios) do
        if not calendarioData.climasHorario[horario.hora] then
            calendarioData.climasHorario[horario.hora] = horario.clima or "CLEAR"
            print('[Calendario] Clima agregado para:', horario.hora, '->', horario.clima)
        end
    end
end

-- Función mejorada para inicializar calendario
local function InicializarCalendario()
    calendarioData = {
        semanas = {},
        meses = {},
        separadores = {},
        climasHorario = {},
        ultimaActualizacion = os.time()
    }
    
    -- Inicializar meses por defecto (2 semanas = 14 días)
    calendarioData.meses = {}
    for semana = 1, 2 do
        calendarioData.meses[semana] = {}
        for dia = 1, 7 do
            local mesIndex = ((semana - 1) * 7 + dia - 1) % 12 + 1
            calendarioData.meses[semana][dia] = Config.Meses[mesIndex] or "Enero"
        end
    end
    
    -- Inicializar semanas y días (2 semanas = 14 días)
    for semana = 1, 2 do
        calendarioData.semanas[semana] = {
            estacion = "Mixta", -- No usamos estación por semana, sino por día
            dias = {}
        }
        
        for dia = 1, 7 do
            -- Calcular el índice global del día (1-14)
            local diaGlobal = (semana - 1) * 7 + dia
            
            -- Obtener la estación para este día específico desde Config.EstacionesPorDia
            local estacionActual = "Primavera" -- Valor por defecto
            if Config.EstacionesPorDia and Config.EstacionesPorDia[diaGlobal] then
                estacionActual = Config.EstacionesPorDia[diaGlobal].estacion
            end
            
            local tempConfig = Config.Temperaturas[estacionActual] or {min = 15, max = 25}
            local temperatura = math.random(tempConfig.min, tempConfig.max)
            
            calendarioData.semanas[semana].dias[dia] = {
                nombre = Config.DiasSemana[dia] or "Día " .. dia,
                evento = "Ninguno",
                luna = Config.Lunas[math.random(1, #Config.Lunas)] or "Luna Nueva",
                temperatura = temperatura,
                estacion = estacionActual, -- NUEVO: Guardamos la estación por día
                clases = {},
                eventosHorario = {}
            }
            
            -- Inicializar estructuras de clases y eventos
            for _, horario in ipairs(Config.Horarios) do
                calendarioData.semanas[semana].dias[dia].clases[horario.hora] = {}
                calendarioData.semanas[semana].dias[dia].eventosHorario[horario.hora] = {
                    texto = "",
                    colorFondo = "#fff3cd",
                    colorTexto = "#000000",
                    cursiva = false
                }
            end
        end
    end
    
    -- Inicializar separadores
    calendarioData.separadores = {}
    for _, horario in ipairs(Config.Horarios) do
        calendarioData.separadores[horario.hora] = {
            texto = "",
            colorFondo = "#740001",
            colorTexto = "#ffffff", 
            cursiva = false,
            mostrarHora = false,
            horaInicio = "",
            horaFin = ""
        }
    end
    
    -- ✅ INICIALIZAR CLIMAS HORARIO CON VALORES DE CONFIG
    calendarioData.climasHorario = {}
    for _, horario in ipairs(Config.Horarios) do
        calendarioData.climasHorario[horario.hora] = horario.clima or "CLEAR"
    end
    
    print('[Calendario] Calendario inicializado correctamente')
    return true
end

-- Función para sincronizar con servidor web externo
local function SincronizarConWebServer(datos)
    if not Config.WebServer or not Config.WebServer.enabled then
        return false
    end
    
    local url = Config.WebServer.url
    if not url or url == "" then
        return false
    end
    
    -- Asegurar que los datos tengan timestamp actualizado
    if not datos then
        datos = calendarioData
    end
    
    -- Actualizar timestamp antes de sincronizar para que la web sepa que hay cambios
    datos.ultimaActualizacion = os.time()
    
    -- Asegurar que climasHorario existe antes de sincronizar
    AsegurarClimasHorario()
    
    -- Usar PerformHttpRequest para enviar datos a la API
    -- El API espera { calendario: datos }, no solo los datos
    local payload = {
        calendario = datos
    }
    local datosJSON = json.encode(payload)
    local apiUrl = url .. '/api/calendario'
    
    print('[Calendario] 🌐 Sincronizando con servidor web: ' .. apiUrl)
    print('[Calendario] 🌐 Enviando datos del juego a la web...')
    print('[Calendario] 🌐 Timestamp:', datos.ultimaActualizacion)
    
    -- Enviar POST a la API web para actualizar MySQL
    PerformHttpRequest(apiUrl, function(statusCode, response, headers)
        if statusCode == 200 then
            print('[Calendario] ✅ Calendario sincronizado con servidor web correctamente')
            local datosRespuesta, error = json.decode(response)
            if datosRespuesta and datosRespuesta.success then
                print('[Calendario] ✅ Confirmación del servidor web recibida')
                print('[Calendario] ✅ Timestamp confirmado:', datosRespuesta.ultimaActualizacion or 'N/A')
            end
        else
            print('[Calendario] ⚠️ Error sincronizando con servidor web. Status:', statusCode)
            if response then
                print('[Calendario] ⚠️ Respuesta:', response)
                -- Intentar decodificar el error para más información
                local errorData, err = json.decode(response)
                if errorData and errorData.error then
                    print('[Calendario] ⚠️ Error detallado:', errorData.error)
                end
            end
        end
    end, 'POST', datosJSON, {
        ['Content-Type'] = 'application/json'
    })
    
    return true
end

-- Función para guardar en MySQL
local function GuardarCalendarioEnMySQL(datos)
    if not Config.Database or not Config.Database.enabled then
        return false
    end
    
    if not datos or next(datos) == nil then
        print('[Calendario] No hay datos para guardar en MySQL')
        return false
    end
    
    -- Actualizar timestamp
    datos.ultimaActualizacion = os.time()
    local datosJSON = json.encode(datos)
    
    -- Usar oxmysql para guardar en MySQL
    MySQL.Async.execute(
        [[INSERT INTO calendario (id, datos, ultima_actualizacion, actualizado_por) 
          VALUES (1, ?, ?, 'FiveM')
          ON DUPLICATE KEY UPDATE 
          datos = VALUES(datos), 
          ultima_actualizacion = VALUES(ultima_actualizacion),
          actualizado_por = VALUES(actualizado_por)]],
        {datosJSON, datos.ultimaActualizacion},
        function(affectedRows)
            if affectedRows > 0 then
                print('[Calendario] ✅ Calendario guardado en MySQL correctamente')
            else
                print('[Calendario] ⚠️ No se pudo guardar en MySQL')
            end
        end
    )
    
    return true
end

-- Función mejorada para guardar en archivo
local function GuardarCalendarioEnArchivo()
    if not calendarioData or next(calendarioData) == nil then
        print('[Calendario] No hay datos para guardar')
        return false
    end
    
    -- Actualizar timestamp antes de guardar
    calendarioData.ultimaActualizacion = os.time()
    
    -- Asegurar que climasHorario existe antes de guardar
    AsegurarClimasHorario()
    
    -- PRIORIDAD 1: Guardar en MySQL si está habilitado
    if Config.Database and Config.Database.enabled then
        GuardarCalendarioEnMySQL(calendarioData)
    end
    
    -- PRIORIDAD 2: Guardar en archivo local (backup)
    local resourcePath = GetResourcePath(GetCurrentResourceName())
    local dataPath = resourcePath .. '/calendario_data.json'
    
    local file = io.open(dataPath, "w")
    if file then
        local datosJSON = json.encode(calendarioData)
        file:write(datosJSON)
        file:close()
        print('[Calendario] Calendario guardado en archivo correctamente')
    else
        print('[Calendario] ⚠️ Error: No se pudo abrir el archivo para escritura')
    end
    
    -- PRIORIDAD 3: Sincronizar con servidor web (para que la web también tenga los datos)
    -- IMPORTANTE: Sincronizar después de guardar en MySQL para asegurar consistencia
    if Config.WebServer and Config.WebServer.enabled then
        -- Esperar un poco para que MySQL termine de guardar antes de sincronizar
        CreateThread(function()
            Wait(500) -- Esperar 500ms para que MySQL termine
            SincronizarConWebServer(calendarioData)
        end)
    end
    
    return true
end

-- Función mejorada para cargar desde archivo
local function CargarCalendarioDesdeArchivo(callback)
    -- PRIORIDAD 1: Intentar cargar desde MySQL si está habilitado
    if Config.Database and Config.Database.enabled then
        local cargadoDesdeMySQL = false
        MySQL.Async.fetchAll(
            'SELECT datos, ultima_actualizacion FROM calendario WHERE id = 1 LIMIT 1',
            {},
            function(result)
                if result and #result > 0 then
                    local datos, error = json.decode(result[1].datos)
                    if datos then
                        calendarioData = datos
                        print('[Calendario] ✅ Calendario cargado desde MySQL')
                        print('[Calendario] Timestamp MySQL:', result[1].ultima_actualizacion)
                        AsegurarClimasHorario()
                        cargadoDesdeMySQL = true
                        
                        -- Ejecutar callback si existe
                        if callback then
                            callback(true)
                        end
                    else
                        print('[Calendario] ⚠️ Error decodificando datos de MySQL:', error)
                    end
                end
                
                -- Si no se pudo cargar desde MySQL, intentar desde archivo
                if not cargadoDesdeMySQL then
                    local resourcePath = GetResourcePath(GetCurrentResourceName())
                    local filePath = resourcePath .. '/calendario_data.json'
                    
                    local file = io.open(filePath, "r")
                    if file then
                        local contenido = file:read("*a")
                        file:close()
                        
                        if contenido and contenido ~= "" then
                            local datos, error = json.decode(contenido)
                            if datos then
                                calendarioData = datos
                                print('[Calendario] Calendario cargado desde archivo (fallback)')
                                AsegurarClimasHorario()
                                -- Guardar en MySQL para sincronizar
                                GuardarCalendarioEnMySQL(calendarioData)
                                
                                -- Ejecutar callback si existe
                                if callback then
                                    callback(true)
                                end
                            else
                                print('[Calendario] Error decodificando archivo:', error)
                                InicializarCalendario()
                                if callback then
                                    callback(false)
                                end
                            end
                        else
                            InicializarCalendario()
                            if callback then
                                callback(false)
                            end
                        end
                    else
                        print('[Calendario] No se pudo cargar el archivo, inicializando nuevo calendario')
                        InicializarCalendario()
                        if callback then
                            callback(false)
                        end
                    end
                end
            end
        )
        
        -- Retornar true inmediatamente (la carga es asíncrona)
        return true
    end
    
    -- PRIORIDAD 2: Cargar desde archivo si MySQL no está habilitado
    local resourcePath = GetResourcePath(GetCurrentResourceName())
    local filePath = resourcePath .. '/calendario_data.json'
    
    local file = io.open(filePath, "r")
    if file then
        local contenido = file:read("*a")
        file:close()
        
        if contenido and contenido ~= "" then
            local datos, error = json.decode(contenido)
            if datos then
                calendarioData = datos
                print('[Calendario] Calendario cargado desde archivo correctamente')
                
                -- ✅ ASEGURAR QUE CLIMAS HORARIO EXISTA Y ESTÉ COMPLETO
                AsegurarClimasHorario()
                
                if callback then
                    callback(true)
                end
                return true
            else
                print('[Calendario] Error decodificando archivo:', error)
            end
        end
    end
    
    print('[Calendario] No se pudo cargar el archivo, inicializando nuevo calendario')
    local resultado = InicializarCalendario()
    if callback then
        callback(resultado)
    end
    return resultado
end

-- Función para verificar permisos en el servidor
local function VerificarPermisosServidor(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local jobName = Player.PlayerData.job.name
    local jobGrade = Player.PlayerData.job.grade.level
    
    for _, jobPermitido in ipairs(Config.JobsPermitidos) do
        if jobName == jobPermitido then
            if Config.GradosPermitidos[jobName] then
                for _, gradoPermitido in ipairs(Config.GradosPermitidos[jobName]) do
                    if jobGrade == gradoPermitido then
                        return true
                    end
                end
            else
                return true
            end
        end
    end
    
    return false
end

-- Función para registrar callbacks
local function RegistrarCallbacks()
    -- Obtener calendario
    QBCore.Functions.CreateCallback('cat_calendario:obtenerCalendario', function(source, cb)
        if next(calendarioData) == nil then
            InicializarCalendario()
        end
        
        -- ✅ ASEGURAR CLIMAS ANTES DE ENVIAR
        AsegurarClimasHorario()
        
        local configCompleta = {
            horarios = Config.Horarios,
            estaciones = Config.Estaciones,
            diasSemana = Config.DiasSemana,
            meses = Config.Meses,
            cursos = Config.Cursos,
            eventos = Config.EventosEspeciales,
            separadores = Config.Separadores,
            colores = Config.Colores,
            lunas = Config.Lunas,
            temperaturas = Config.Temperaturas,
            tamanosTexto = Config.TamanosTexto,
            alturasSeparador = Config.AlturasSeparador,
            climas = Config.Climas
        }
        
        cb({calendario = calendarioData, config = configCompleta})
    end)

    QBCore.Functions.CreateCallback('cat_calendario:guardarCalendario', function(source, cb, datosCalendario)
        if not VerificarPermisosServidor(source) then
            cb(false)
            return
        end
        
        print('[Calendario] Guardando calendario...')
        
        calendarioData = datosCalendario
        calendarioData.ultimaActualizacion = os.time()
        
        -- ✅ ASEGURAR CLIMAS ANTES DE GUARDAR
        AsegurarClimasHorario()
        
        GuardarCalendarioEnArchivo()
        cb(true)
    end)
end

-- Variable para rastrear última modificación del archivo
local ultimaModificacionArchivo = 0

-- Función para sincronizar desde la API web (HTTP)
local function SincronizarDesdeAPIWeb()
    if not Config.WebServer or not Config.WebServer.enabled then
        return
    end
    
    local url = Config.WebServer.url
    if not url or url == "" then
        return
    end
    
    local apiUrl = url .. '/api/calendario'
    
    -- Usar PerformHttpRequest para obtener datos de la API
    PerformHttpRequest(apiUrl, function(statusCode, response, headers)
        if statusCode == 200 then
            local datos, error = json.decode(response)
            if datos and datos.success and datos.calendario then
                local calendarioWeb = datos.calendario
                
                -- Comparar timestamps
                local timestampWeb = calendarioWeb.ultimaActualizacion or 0
                local timestampLocal = calendarioData.ultimaActualizacion or 0
                
                if timestampWeb > timestampLocal then
                    print('[Calendario] 🌐 Cambios detectados desde servidor web (API)')
                    print('[Calendario] Timestamp web:', timestampWeb, 'vs local:', timestampLocal)
                    
                    -- Actualizar datos locales
                    calendarioData = calendarioWeb
                    ultimaModificacionArchivo = timestampWeb
                    
                    -- Guardar en archivo local para persistencia
                    GuardarCalendarioEnArchivo()
                    
                    -- Notificar a todos los clientes
                    TriggerClientEvent('cat_calendario:actualizarCalendario', -1, calendarioData)
                    print('[Calendario] ✅ Calendario sincronizado desde servidor web')
                else
                    print('[Calendario] 🔄 Calendario ya está actualizado (web:', timestampWeb, 'local:', timestampLocal, ')')
                end
            else
                print('[Calendario] ⚠️ Error decodificando respuesta de API web:', error)
            end
        else
            print('[Calendario] ⚠️ Error consultando API web. Status:', statusCode)
        end
    end, 'GET', '', {
        ['Content-Type'] = 'application/json'
    })
end

-- Función para verificar cambios en el archivo (desde servidor web - método antiguo)
local function VerificarCambiosEnArchivo()
    if not Config.WebServer or not Config.WebServer.enabled then
        return
    end
    
    local resourcePath = GetResourcePath(GetCurrentResourceName())
    local dataPath = resourcePath .. '/calendario_data.json'
    
    -- Verificar si el archivo existe y obtener su tiempo de modificación
    local file = io.open(dataPath, "r")
    if file then
        file:close()
        
        -- En Lua/FiveM no hay forma directa de obtener mtime, así que leemos el archivo
        -- y comparamos el timestamp de ultimaActualizacion
        local fileContent = io.open(dataPath, "r")
        if fileContent then
            local contenido = fileContent:read("*a")
            fileContent:close()
            
            local datos, error = json.decode(contenido)
            if datos and datos.ultimaActualizacion then
                if datos.ultimaActualizacion > ultimaModificacionArchivo then
                    print('[Calendario] 🌐 Cambios detectados desde archivo local, actualizando...')
                    calendarioData = datos
                    ultimaModificacionArchivo = datos.ultimaActualizacion
                    
                    -- Notificar a todos los clientes
                    TriggerClientEvent('cat_calendario:actualizarCalendario', -1, calendarioData)
                    print('[Calendario] ✅ Calendario actualizado desde archivo local')
                end
            end
        end
    end
end

-- Thread para verificar cambios periódicamente desde la API web
CreateThread(function()
    if Config.WebServer and Config.WebServer.enabled and Config.WebServer.syncInterval and Config.WebServer.syncInterval > 0 then
        -- Esperar un poco al inicio para que todo se inicialice
        Wait(5000)
        
        while true do
            Wait(Config.WebServer.syncInterval * 1000)
            
            -- Primero verificar cambios en archivo local (método antiguo)
            VerificarCambiosEnArchivo()
            
            -- Luego sincronizar desde API web (método nuevo - bidireccional)
            if Config.WebServer.url and Config.WebServer.url ~= "" then
                SincronizarDesdeAPIWeb()
            end
        end
    end
end)

-- Obtener QBCore y inicializar
CreateThread(function()
    while not QBCore do
        QBCore = exports['qb-core']:GetCoreObject()
        if not QBCore then
            TriggerEvent('QBCore:GetObject', function(obj) 
                QBCore = obj 
            end)
        end
        Wait(200)
    end
    
    print('[Calendario] QBCore inicializado correctamente en el servidor')
    
    RegistrarCallbacks()
    
    -- Cargar calendario con callback para sincronizar después
    CargarCalendarioDesdeArchivo(function(cargado)
        if cargado then
            -- Inicializar timestamp de última modificación
            if calendarioData.ultimaActualizacion then
                ultimaModificacionArchivo = calendarioData.ultimaActualizacion
            end
            
            -- ✅ SINCRONIZAR CON LA WEB DESPUÉS DE CARGAR AL INICIAR EL SERVIDOR
            if Config.WebServer and Config.WebServer.enabled then
                print('[Calendario] 🌐 Sincronizando calendario con servidor web al iniciar...')
                -- Esperar un poco para asegurar que todo esté listo
                Wait(2000)
                SincronizarConWebServer(calendarioData)
            end
        else
            print('[Calendario] Error al inicializar calendario')
        end
        
        print('[Calendario] Recurso completamente inicializado')
        
        if Config.WebServer and Config.WebServer.enabled then
            print('[Calendario] 🌐 Sincronización con servidor web ACTIVADA')
            if Config.WebServer.syncInterval and Config.WebServer.syncInterval > 0 then
                print('[Calendario] 🔄 Verificando cambios cada ' .. Config.WebServer.syncInterval .. ' segundos')
            end
        end
    end)
end)

-- Función para obtener el clima según la hora actual
local function ObtenerClimaPorHora()
    -- Obtener hora UTC y ajustar a España (UTC+1/UTC+2)
    local horaUTC = os.date("!%H:%M")
    local horaLocal = os.date("%H:%M")
    
    print('[Calendario] 🔍 Calculando clima - UTC:', horaUTC, 'Local:', horaLocal)
    
    -- Determinar diferencia horaria para España
    local diferenciaHoraria = 1 -- UTC+1 en invierno
    
    -- Detectar horario de verano (UTC+2)
    local mes = tonumber(os.date("%m"))
    local dia = tonumber(os.date("%d"))
    
    if (mes > 3 and mes < 10) or 
       (mes == 3 and dia >= 25) or 
       (mes == 10 and dia <= 25) then
        diferenciaHoraria = 2 -- UTC+2 en verano
    end
    
    -- Calcular hora española
    local horaNum, minutoNum = horaUTC:match("(%d+):(%d+)")
    horaNum = tonumber(horaNum)
    minutoNum = tonumber(minutoNum)
    
    local horaEspania = horaNum + diferenciaHoraria
    if horaEspania >= 24 then horaEspania = horaEspania - 24 end
    
    local horaActual = string.format("%02d:%02d", horaEspania, minutoNum)
    local horaActualDecimal = horaEspania + (minutoNum / 60)
    
    print('[Calendario] 🇪🇸 Hora España:', horaActual, '(UTC+'..diferenciaHoraria..')')
    
    -- Buscar en climas configurados en el calendario
    if calendarioData and calendarioData.climasHorario then
        for horarioStr, clima in pairs(calendarioData.climasHorario) do
            local horaInicioStr, horaFinStr = horarioStr:match("(%d+:%d+)%s*-%s*(%d+:%d+)")
            
            if horaInicioStr and horaFinStr then
                local hIni, mIni = horaInicioStr:match("(%d+):(%d+)")
                local hFin, mFin = horaFinStr:match("(%d+):(%d+)")
                
                hIni = tonumber(hIni); mIni = tonumber(mIni)
                hFin = tonumber(hFin); mFin = tonumber(mFin)
                
                local inicioDecimal = hIni + (mIni / 60)
                local finDecimal = hFin + (mFin / 60)
                
                -- Manejar franjas que pasan de medianoche
                if inicioDecimal > finDecimal then
                    if horaActualDecimal >= inicioDecimal or horaActualDecimal < finDecimal then
                        print('[Calendario] ✅ Clima encontrado (franja nocturna):', clima, 'en', horarioStr)
                        return clima
                    end
                else
                    if horaActualDecimal >= inicioDecimal and horaActualDecimal < finDecimal then
                        print('[Calendario] ✅ Clima encontrado:', clima, 'en', horarioStr)
                        return clima
                    end
                end
            end
        end
    end
    
    -- Fallback a Config.Horarios
    for _, horario in ipairs(Config.Horarios) do
        local horaInicio = horario.inicio
        local horaFin = horario.fin
        
        -- Manejar franjas nocturnas
        if horaInicio > horaFin then
            if horaActualDecimal >= horaInicio or horaActualDecimal < horaFin then
                print('[Calendario] ✅ Clima encontrado en Config (nocturno):', horario.clima)
                return horario.clima
            end
        else
            if horaActualDecimal >= horaInicio and horaActualDecimal < horaFin then
                print('[Calendario] ✅ Clima encontrado en Config:', horario.clima)
                return horario.clima
            end
        end
    end
    
    print('[Calendario] ⚠️ No se encontró franja, usando CLEAR por defecto')
    return "CLEAR"
end

-- =============================================
-- SISTEMA DE CLIMA AUTOMÁTICO SIMPLIFICADO
-- =============================================

-- Función optimizada para cambiar clima
local function CambiarClimaAutomatico()
    local climaCalculado = ObtenerClimaPorHora()
    local horaActual = os.date("%H:%M:%S")
    
    if climaCalculado ~= ultimoClimaAplicado then
        print('[Calendario] 🌤️ APLICANDO CAMBIO DE CLIMA:', climaCalculado, 'a las', horaActual)
        
        -- Método 1: Usar export directo de qb-weathersync
        local success = false
        
        if exports['qb-weathersync'] and type(exports['qb-weathersync'].setWeather) == "function" then
            success = exports['qb-weathersync']:setWeather(climaCalculado)
            print('[Calendario] 📡 Método Export - Resultado:', success)
        end
        
        -- Método 2: Usar evento como fallback
        if not success then
            TriggerEvent('qb-weathersync:server:setWeather', climaCalculado)
            print('[Calendario] 📡 Método Evento - Disparado')
            success = true -- Asumir éxito con evento
        end
        
        if success then
            ultimoClimaAplicado = climaCalculado
            -- Notificar a todos los clientes
            TriggerClientEvent('cat_calendario:notificarCambioClima', -1, climaCalculado, horaActual)
            print('[Calendario] ✅ Cambio de clima exitoso')
        else
            print('[Calendario] ❌ Error al cambiar clima')
        end
    else
        print('[Calendario] 🔄 Clima ya está actualizado:', climaCalculado)
    end
end

-- Sistema automático simplificado
local function IniciarSistemaClimaAutomatico()
    -- Detener sistema anterior si existe
    if climaInterval then
        ClearTimeout(climaInterval)
        climaInterval = nil
    end
    
    print('[Calendario] 🚀 INICIANDO SISTEMA AUTOMÁTICO DE CLIMA...')
    
    -- Función de verificación
    local function VerificarYCambiarClima()
        CambiarClimaAutomatico()
        
        -- Programar siguiente verificación en 30 segundos
        climaInterval = SetTimeout(30000, VerificarYCambiarClima)
    end
    
    -- Primera ejecución inmediata
    VerificarYCambiarClima()
end

-- Detener sistema
local function DetenerSistemaClimaAutomatico()
    if climaInterval then
        ClearTimeout(climaInterval)
        climaInterval = nil
        print('[Calendario] ⏹️ Sistema de clima detenido')
    end
end

-- =============================================
-- EVENTOS Y COMANDOS
-- =============================================

-- Al iniciar el recurso
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        print('[Calendario] 🔧 Iniciando sistema de clima automático...')
        
        -- Esperar 10 segundos para que todos los recursos estén listos
        SetTimeout(10000, function()
            IniciarSistemaClimaAutomatico()
        end)
    end
end)

-- Al detener el recurso
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        DetenerSistemaClimaAutomatico()
    end
end)

-- Evento para notificar cambios de clima
RegisterNetEvent('cat_calendario:notificarCambioClima')
AddEventHandler('cat_calendario:notificarCambioClima', function(clima, hora)
    print(string.format('[Calendario] Notificando cambio de clima: %s a las %s', clima, hora))
end)

-- Evento para que los clientes obtengan el clima actual
RegisterServerEvent('cat_calendario:obtenerClimaActual')
AddEventHandler('cat_calendario:obtenerClimaActual', function()
    local src = source
    local climaActual = ObtenerClimaPorHora()
    TriggerClientEvent('cat_calendario:establecerClima', src, climaActual)
end)

-- Evento para establecer clima manual (profesores)
RegisterServerEvent('cat_calendario:establecerClimaManual')
AddEventHandler('cat_calendario:establecerClimaManual', function(clima)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player then
        local jobName = Player.PlayerData.job.name
        local esPermitido = false
        
        for _, jobPermitido in ipairs(Config.JobsPermitidos) do
            if jobName == jobPermitido then
                esPermitido = true
                break
            end
        end
        
        if esPermitido then
            local success = exports['qb-weathersync']:setWeather(clima)
            if success then
                TriggerClientEvent('QBCore:Notify', src, "Clima cambiado a: " .. clima, "success")
            else
                TriggerClientEvent('QBCore:Notify', src, "Error al cambiar clima", "error")
            end
        else
            TriggerClientEvent('QBCore:Notify', src, "No tienes permisos para cambiar el clima", "error")
        end
    end
end)

-- Función para traducir climas
local function TraducirClima(clima)
    local traducciones = {
        ['EXTRASUNNY'] = 'Muy Soleado ☀️',
        ['CLEAR'] = 'Despejado 🌤️',
        ['NEUTRAL'] = 'Neutral 🌫️',
        ['SMOG'] = 'Neblina 🌁',
        ['FOGGY'] = 'Brumoso 🌫️',
        ['OVERCAST'] = 'Nublado ☁️',
        ['CLOUDS'] = 'Nubes ⛅',
        ['CLEARING'] = 'Despejando 🌤️',
        ['RAIN'] = 'Lluvia 🌧️',
        ['THUNDER'] = 'Tormenta ⛈️',
        ['SNOW'] = 'Nieve ❄️',
        ['BLIZZARD'] = 'Ventisca 🌨️',
        ['SNOWLIGHT'] = 'Nieve Ligera 🌨️',
        ['XMAS'] = 'Navidad 🎄',
        ['HALLOWEEN'] = 'Halloween 🎃'
    }
    
    return traducciones[clima] or clima
end

-- Comando para forzar clima actual
RegisterCommand('forzarclimaactual', function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        local jobName = Player.PlayerData.job.name
        local esPermitido = false
        
        for _, jobPermitido in ipairs(Config.JobsPermitidos) do
            if jobName == jobPermitido then
                esPermitido = true
                break
            end
        end
        
        if esPermitido then
            local climaEncontrado = ObtenerClimaPorHora()
            local success = exports['qb-weathersync']:setWeather(climaEncontrado)
            if success then
                TriggerClientEvent('QBCore:Notify', source, 
                    string.format('🌤️ Clima forzado a: %s', TraducirClima(climaEncontrado)), 
                    'success', 5000)
            else
                TriggerClientEvent('QBCore:Notify', source, "Error al forzar clima", "error")
            end
        else
            TriggerClientEvent('QBCore:Notify', source, "No tienes permisos para este comando", "error")
        end
    end
end)

-- Evento para aplicar clima de prueba
RegisterServerEvent('cat_calendario:aplicarClimaPrueba')
AddEventHandler('cat_calendario:aplicarClimaPrueba', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player then
        local jobName = Player.PlayerData.job.name
        local esPermitido = false
        
        for _, jobPermitido in ipairs(Config.JobsPermitidos) do
            if jobName == jobPermitido then
                esPermitido = true
                break
            end
        end
        
        if esPermitido then
            local success = exports['qb-weathersync']:setWeather(data.clima)
            if success then
                TriggerClientEvent('QBCore:Notify', src, 
                    string.format('🌤️ Clima de prueba aplicado: %s', TraducirClima(data.clima)), 
                    'success', 5000)
            else
                TriggerClientEvent('QBCore:Notify', src, "Error al aplicar clima de prueba", "error")
            end
        else
            TriggerClientEvent('QBCore:Notify', src, "No tienes permisos", "error")
        end
    end
end)

-- Comandos para controlar el sistema
RegisterCommand('climaauto', function(source, args)
    local src = source
    local action = args[1] or 'status'
    
    if action == 'iniciar' then
        IniciarSistemaClimaAutomatico()
        TriggerClientEvent('QBCore:Notify', src, 'Sistema automático de clima INICIADO', 'success')
    elseif action == 'detener' then
        DetenerSistemaClimaAutomatico()
        TriggerClientEvent('QBCore:Notify', src, 'Sistema automático de clima DETENIDO', 'error')
    elseif action == 'forzar' then
        CambiarClimaAutomatico()
        TriggerClientEvent('QBCore:Notify', src, 'Clima actualizado manualmente', 'primary')
    else
        -- Mostrar status
        local status = climaInterval and 'ACTIVO' or 'INACTIVO'
        local climaActual = ultimoClimaAplicado or 'Ninguno'
        TriggerClientEvent('QBCore:Notify', src, 
            string.format('Estado: %s | Clima: %s', status, climaActual), 'primary')
    end
end)

-- Comando para ver clima actual calculado
RegisterCommand('climainfo', function(source)
    local src = source
    local climaCalculado = ObtenerClimaPorHora()
    local horaActual = os.date("%H:%M:%S")
    
    TriggerClientEvent('QBCore:Notify', src, 
        string.format('Clima calculado: %s (%s)', climaCalculado, horaActual), 'primary')
    
    print(string.format('[Calendario] 📊 Info - Hora: %s, Clima: %s, Último: %s', 
        horaActual, climaCalculado, ultimoClimaAplicado or 'Ninguno'))
end)

-- Comando de diagnóstico
RegisterCommand('diagnosticoautoclima', function(source, args)
    print('=== DIAGNÓSTICO COMPLETO AUTO-CLIMA ===')
    
    -- Estado del sistema
    print('✅ Sistema activo:', climaInterval ~= nil)
    
    -- Clima actual
    local climaCalculado = ObtenerClimaPorHora()
    local climaActualQb = "UNKNOWN"
    
    if exports['qb-weathersync'] and type(exports['qb-weathersync'].getWeatherState) == "function" then
        climaActualQb = exports['qb-weathersync']:getWeatherState()
    end
    
    print('🌤️ Clima calculado:', climaCalculado)
    print('🌤️ Clima actual qb-weathersync:', climaActualQb)
    print('🔍 Diferencia:', climaCalculado ~= climaActualQb and 'SI' or 'NO')
    
    if source > 0 then
        TriggerClientEvent('QBCore:Notify', source, 
            string.format('Diagnóstico: %s vs %s', climaCalculado, climaActualQb), 'primary')
    end
end)

-- Comando para cambiar clima inmediato
RegisterCommand('cambiarclimainmediato', function(source, args)
    local src = source
    local clima = args[1]
    
    if not clima then
        -- Si no se especifica clima, usar el calculado
        clima = ObtenerClimaPorHora()
    end
    
    print('[INMEDIATO] Cambiando clima a:', clima)
    
    -- Método directo
    local success = exports['qb-weathersync']:setWeather(clima)
    
    -- Forzar sincronización
    TriggerEvent('qb-weathersync:server:RequestStateSync')
    
    print('[INMEDIATO] Resultado:', success)
    
    if src > 0 then
        if success then
            TriggerClientEvent('QBCore:Notify', src, "Clima cambiado: " .. clima, "success")
        else
            TriggerClientEvent('QBCore:Notify', src, "Error al cambiar clima", "error")
        end
    end
end)

-- Evento para que los clientes soliciten el clima actual
RegisterServerEvent('cat_calendario:solicitarClimaActual')
AddEventHandler('cat_calendario:solicitarClimaActual', function()
    local src = source
    local climaActual = ObtenerClimaPorHora()
    TriggerClientEvent('cat_calendario:establecerClima', src, climaActual)
end)

-- Inicialización final
CreateThread(function()
    -- Esperar 10 segundos después de que todo cargue
    Wait(10000)
    
    print('[Calendario] 🔧 EJECUTANDO INICIALIZACIÓN FORZADA...')
    
    -- Verificar si el sistema está activo
    if not climaInterval then
        print('[Calendario] ⚠️ Sistema no iniciado - FORZANDO INICIO...')
        IniciarSistemaClimaAutomatico()
        
        -- Verificar que se inició
        Wait(3000)
        if climaInterval then
            print('[Calendario] ✅ Inicialización forzada EXITOSA')
        else
            print('[Calendario] ❌ Error en inicialización forzada')
        end
    else
        print('[Calendario] ✅ Sistema ya estaba activo')
    end
end)