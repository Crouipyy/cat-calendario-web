local QBCore = nil
local calendarioAbierto = false
local esProfesor = false

local puntosInteraccion = Config.PuntosInteraccion or {}
local marcadoresCreados = false
local enZonaInteraccion = false
local puntoInteraccionActual = nil
local blips = {}

-- FUNCIÓN: Verificar si el jugador está cerca de algún punto de interacción
local function EstaCercaDePuntoInteraccion()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    for _, punto in ipairs(puntosInteraccion) do
        local distancia = #(playerCoords - vector3(punto.x, punto.y, punto.z))
        if distancia < 3.0 then -- Radio de 3 metros
            return true, punto
        end
    end
    
    return false, nil
end

-- Sistema de clima automático por horario
local function InicializarSistemaClima()
    print('[Calendario] Inicializando sistema de clima automático...')
    
    -- Solicitar el clima actual al servidor
    TriggerServerEvent('cat_calendario:solicitarClimaActual')
end

-- Evento para recibir el clima del servidor
RegisterNetEvent('cat_calendario:establecerClima')
AddEventHandler('cat_calendario:establecerClima', function(clima)
    print('[Calendario] Clima recibido del servidor:', clima)
    
    -- El servidor ya se encarga de cambiar el clima automáticamente
    -- Este evento es principalmente para sincronización inicial
end)

-- Comando para que los profesores puedan cambiar el clima manualmente
RegisterCommand('cambiarclima', function(source, args)
    if not esProfesor then
        QBCore.Functions.Notify("No tienes permisos para cambiar el clima", "error")
        return
    end
    
    if not args[1] then
        QBCore.Functions.Notify("Uso: /cambiarclima [tipo-clima]", "error")
        QBCore.Functions.Notify("Climas disponibles: EXTRASUNNY, CLEAR, CLOUDS, OVERCAST, RAIN, FOGGY", "primary")
        return
    end
    
    local clima = string.upper(args[1])
    TriggerServerEvent('cat_calendario:establecerClimaManual', clima)
end)

-- Comando para ver los horarios de clima actuales
RegisterCommand('horariosclima', function()
    if not esProfesor then
        QBCore.Functions.Notify("No tienes permisos para ver esta información", "error")
        return
    end
    
    QBCore.Functions.Notify("Revisa la consola F8 para ver los horarios de clima", "primary")
    print("[Calendario] Horarios de Clima:")
    for franja, clima in pairs(Config.Horarios) do
        print("  " .. franja .. ": " .. clima)
    end
end)

-- Verificar si el jugador es profesor
local function VerificarPermisos()
    if not QBCore then return false end
    
    local playerData = QBCore.Functions.GetPlayerData()
    if playerData and playerData.job then
        local jobName = playerData.job.name
        local jobGrade = playerData.job.grade.level
        
        print('[Calendario] Verificando permisos para:', jobName, 'Grado:', jobGrade)
        
        -- Verificar si el job está en la lista permitida
        for _, jobPermitido in ipairs(Config.JobsPermitidos) do
            if jobName == jobPermitido then
                -- Verificar si el grado está permitido (si está configurado)
                if Config.GradosPermitidos[jobName] then
                    for _, gradoPermitido in ipairs(Config.GradosPermitidos[jobName]) do
                        if jobGrade == gradoPermitido then
                            esProfesor = true
                            print('[Calendario] Permisos CONCEDIDOS - Profesor detectado')
                            return true
                        end
                    end
                else
                    -- Si no hay grados específicos configurados, cualquier grado tiene permiso
                    esProfesor = true
                    print('[Calendario] Permisos CONCEDIDOS - Profesor detectado (sin verificación de grado)')
                    return true
                end
            end
        end
    end
    
    esProfesor = false
    print('[Calendario] Permisos DENEGADOS - No es profesor')
    return false
end

-- Función para verificar si ox_lib está disponible
local function OxLibDisponible()
    local estado = GetResourceState('ox_lib')
    if estado == 'started' then
        -- Verificar que la librería esté realmente cargada
        return pcall(function() return lib ~= nil end)
    end
    return false
end

-- Función SEGURA para mostrar texto UI con ox_lib
local function MostrarTextoUI()
    if OxLibDisponible() then
        pcall(function()
            lib.showTextUI('[E] - Ver Calendario Escolar', {
                position = "left-center",
                icon = 'calendar',
                style = {
                    borderRadius = 5,
                    backgroundColor = '#740001',
                    color = 'white'
                }
            })
        end)
    else
        -- Sistema nativo de texto
        BeginTextCommandDisplayHelp("STRING")
        AddTextComponentSubstringPlayerName("Presiona ~INPUT_CONTEXT~ para ver el Calendario Escolar")
        EndTextCommandDisplayHelp(0, false, true, -1)
    end
end

-- Función SEGURA para ocultar texto UI con ox_lib
local function OcultarTextoUI()
    if OxLibDisponible() then
        pcall(function()
            lib.hideTextUI()
        end)
    end
    -- El texto nativo se oculta automáticamente
end

-- Función para crear marcadores y zonas de interacción
local function CrearMarcadoresInteraccion()
    if marcadoresCreados then return end
    
    print('[Calendario] Creando puntos de interacción...')
    
    for i, punto in ipairs(puntosInteraccion) do
        -- Crear blip
        local blip = AddBlipForCoord(punto.x, punto.y, punto.z)
        SetBlipSprite(blip, 475) -- Sprite de tablero/mapa
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 4) -- Color azul
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Calendario Escolar")
        EndTextCommandSetBlipName(blip)
        
        table.insert(blips, blip)
        
        print(string.format('[Calendario] Blip creado en: %.2f, %.2f, %.2f', punto.x, punto.y, punto.z))
    end
    
    marcadoresCreados = true
    print('[Calendario] Marcadores de interacción creados')
end

-- Función para abrir calendario
local function AbrirCalendario()
    -- VERIFICAR que esté cerca de un punto de interacción
    local cerca, punto = EstaCercaDePuntoInteraccion()
    if not cerca then
        -- print('[Calendario] Intento de abrir calendario fuera de zona de interacción')
        -- QBCore.Functions.Notify("Debes estar cerca de un tablero de anuncios para ver el calendario", "error")
        return
    end
    
    if calendarioAbierto then 
        print('[Calendario] Ya está abierto')
        return 
    end
    
    if not QBCore then
        print('[Calendario] Error: QBCore no disponible')
        return
    end
    
    VerificarPermisos()
    SetNuiFocus(true, true)
    calendarioAbierto = true
    
    print('[Calendario] Abriendo calendario, es profesor:', esProfesor)
    
    -- Obtener datos del calendario del servidor
    QBCore.Functions.TriggerCallback('cat_calendario:obtenerCalendario', function(datos)
        calendarioData = datos.calendario or {}
        config = datos.config or {}
        
        -- ENVIAR TODA LA CONFIGURACIÓN COMPLETA AL NUI
        SendNUIMessage({
            action = 'abrirCalendario',
            calendario = calendarioData,
            esProfesor = esProfesor,
            config = config
        })
    end)
end

-- Función para cerrar calendario
local function CerrarCalendario()
    if not calendarioAbierto then return end
    
    calendarioAbierto = false
    -- Desactivar NUI focus INMEDIATAMENTE (múltiples veces para asegurar)
    SetNuiFocus(false, false)
    SetNuiFocus(false, false)
    SetNuiFocus(false, false)
    
    -- Enviar mensaje al NUI para ocultar
    SendNUIMessage({action = 'cerrarCalendario'})
    
    -- Asegurarse de que el focus se desactive múltiples veces (por si hay algún delay)
    Citizen.SetTimeout(0, function()
        SetNuiFocus(false, false)
    end)
    Citizen.SetTimeout(10, function()
        SetNuiFocus(false, false)
    end)
    Citizen.SetTimeout(50, function()
        SetNuiFocus(false, false)
    end)
    Citizen.SetTimeout(100, function()
        SetNuiFocus(false, false)
    end)
    Citizen.SetTimeout(200, function()
        SetNuiFocus(false, false)
    end)
    Citizen.SetTimeout(500, function()
        SetNuiFocus(false, false)
    end)
end

-- Función para traducir clima (agregar si no existe)
local function traducirClima(clima)
    local traducciones = {
        ['EXTRASUNNY'] = 'Muy Soleado',
        ['CLEAR'] = 'Despejado',
        ['NEUTRAL'] = 'Neutral',
        ['SMOG'] = 'Neblina',
        ['FOGGY'] = 'Brumoso',
        ['OVERCAST'] = 'Nublado',
        ['CLOUDS'] = 'Nubes',
        ['CLEARING'] = 'Despejando',
        ['RAIN'] = 'Lluvia',
        ['THUNDER'] = 'Tormenta',
        ['SNOW'] = 'Nieve',
        ['BLIZZARD'] = 'Ventisca',
        ['SNOWLIGHT'] = 'Nieve Ligera',
        ['XMAS'] = 'Navidad',
        ['HALLOWEEN'] = 'Halloween'
    }
    
    return traducciones[clima] or clima
end

-- Comando para abrir calendario
RegisterCommand('calendario', function()
    -- Verificar que esté cerca de un punto de interacción
    local cerca, punto = EstaCercaDePuntoInteraccion()
    if not cerca then
        --QBCore.Functions.Notify("Debes estar cerca de un tablero de anuncios para ver el calendario", "error")
        return
    end
    
    AbrirCalendario()
end)

-- Cerrar calendario desde NUI
RegisterNUICallback('cerrarCalendario', function(data, cb)
    -- Desactivar focus INMEDIATAMENTE antes de responder
    SetNuiFocus(false, false)
    SetNuiFocus(false, false)
    
    -- Responder primero para que el NUI sepa que se recibió
    cb('ok')
    
    -- Luego cerrar (esto asegura que el callback se complete)
    CerrarCalendario()
    
    -- Asegurarse de que SetNuiFocus se desactive correctamente
    SetNuiFocus(false, false)
    
    -- Forzar desactivación adicional
    Citizen.SetTimeout(0, function()
        SetNuiFocus(false, false)
    end)
    Citizen.SetTimeout(50, function()
        SetNuiFocus(false, false)
    end)
end)

-- Guardar cambios (solo profesores)
RegisterNUICallback('guardarCambios', function(data, cb)
    if not esProfesor or not QBCore then
        QBCore.Functions.Notify("No tienes permisos para editar el calendario", "error")
        cb('error')
        return
    end
    
    QBCore.Functions.TriggerCallback('cat_calendario:guardarCalendario', function(resultado)
        if resultado then
            QBCore.Functions.Notify("Calendario actualizado correctamente", "success")
        else
            QBCore.Functions.Notify("Error al guardar el calendario", "error")
        end
        cb(resultado and 'ok' or 'error')
    end, data.calendario)
end)

-- Cerrar con ESC
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if calendarioAbierto then
            if IsControlJustReleased(0, 322) or IsControlJustReleased(0, 177) then -- ESC o BACKSPACE
                -- Desactivar focus INMEDIATAMENTE
                SetNuiFocus(false, false)
                SetNuiFocus(false, false)
                CerrarCalendario()
                -- Asegurarse de que SetNuiFocus se desactive correctamente
                SetNuiFocus(false, false)
            end
        end
    end
end)

-- Thread adicional para forzar desactivación del cursor cuando el calendario está cerrado
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100) -- Revisar cada 100ms
        if not calendarioAbierto then
            -- Si el calendario está cerrado, forzar desactivación del cursor
            SetNuiFocus(false, false)
        end
    end
end)

-- Obtener QBCore
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
    
    print('[Calendario] QBCore inicializado correctamente en el cliente')
    
    -- Esperar un poco más para que ox_lib se cargue completamente
    Citizen.Wait(5000)
    
    -- Verificar permisos cuando QBCore esté listo
    VerificarPermisos()
    
    -- Verificar estado de ox_lib
    if OxLibDisponible() then
        print('[Calendario] ox_lib detectado y funcionando')
    else
        print('[Calendario] ox_lib no disponible, usando sistema nativo')
    end
end)

-- Manejar cuando el jugador se une
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    if QBCore then
        VerificarPermisos()
        CrearMarcadoresInteraccion()
        InicializarSistemaClima() -- Sistema de clima
        print('[Calendario] Jugador cargado, calendario listo')
    end
end)

-- Manejar cambio de trabajo
AddEventHandler('QBCore:Client:OnJobUpdate', function(JobInfo)
    print('[Calendario] Trabajo actualizado, verificando permisos...')
    VerificarPermisos()
end)

-- Manejar interacción con tecla E
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        -- Verificar si está cerca de algún punto
        local cerca, punto = EstaCercaDePuntoInteraccion()
        
        if cerca and punto then
            -- Dibujar marcador en el mundo
            DrawMarker(2, punto.x, punto.y, punto.z + 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 116, 0, 186, 100, false, true, 2, false, nil, nil, false)
            
            -- Mostrar texto de ayuda si no está mostrado
            if not enZonaInteraccion then
                enZonaInteraccion = true
                puntoInteraccionActual = punto
                
                MostrarTextoUI()
                print('[Calendario] Mostrando texto de ayuda')
            end
            
            -- Verificar si presiona E estando cerca
            if IsControlJustReleased(0, 38) then -- Tecla E
                AbrirCalendario()
            end
            
        elseif enZonaInteraccion then
            -- Si estaba en zona pero ya no está cerca, ocultar texto
            enZonaInteraccion = false
            puntoInteraccionActual = nil
            
            OcultarTextoUI()
            print('[Calendario] Ocultando texto de ayuda')
        end
    end
end)

-- Aplicar clima cuando el recurso se inicia
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- Esperar a que el jugador esté listo
        Citizen.SetTimeout(10000, function()
            InicializarSistemaClima()
        end)
    end
end)

-- Limpiar blips cuando el recurso se detenga
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for _, blip in ipairs(blips) do
            RemoveBlip(blip)
        end
        print('[Calendario] Blips eliminados')
    end
end)

RegisterNetEvent('cat_calendario:actualizarCalendario')
AddEventHandler('cat_calendario:actualizarCalendario', function(calendario)
    calendarioData = calendario
    print('[Calendario] Calendario actualizado desde el servidor')
    
    -- Si el calendario está abierto, refrescar la vista
    if calendarioAbierto then
        SendNUIMessage({
            action = 'actualizarCalendario',
            calendario = calendarioData
        })
    end
end)

RegisterNUICallback('aplicarClimaPrueba', function(data, cb)
    TriggerServerEvent('cat_calendario:aplicarClimaPrueba', data)
    cb('ok')
end)

-- Evento para recibir notificaciones de cambio de clima
RegisterNetEvent('cat_calendario:notificarCambioClima')
AddEventHandler('cat_calendario:notificarCambioClima', function(clima, hora)
    print('[Calendario] 🌤️ Notificación:', clima, 'a las', hora)
    
    -- Solo notificar a profesores
    if esProfesor then
        QBCore.Functions.Notify(string.format('🌤️ Clima automático: %s (%s)', 
            traducirClima(clima), hora), 'primary', 5000)
    end
end)

RegisterCommand('estadoclima', function()
    local hora = os.date("%H:%M")
    QBCore.Functions.Notify(string.format('⏰ Hora: %s - Revisa consola F8', hora), 'primary')
    
    print('[Calendario] Estado del clima:')
    print('- Hora servidor:', hora)
    print('- Es profesor:', esProfesor)
end)

RegisterNetEvent('cat_calendario:forzarCambioClima')
AddEventHandler('cat_calendario:forzarCambioClima', function(clima)
    print('[Calendario] Aplicando cambio de clima:', clima)
    
    -- Transición suave
    SetWeatherTypeOverTime(clima, 15.0)
    Citizen.Wait(15000)
    
    -- Establecer clima permanente
    SetWeatherTypePersist(clima)
    SetWeatherTypeNow(clima)
    SetWeatherTypeNowPersist(clima)
    
    -- Limpiar override
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    
    print('[Calendario] Clima cambiado a:', clima)
end)