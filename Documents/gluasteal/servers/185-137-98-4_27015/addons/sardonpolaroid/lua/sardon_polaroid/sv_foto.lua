if not SERVER then return end

SardonFoto = SardonFoto or {}

util.AddNetworkString("SardonFoto.Durum")
util.AddNetworkString("SardonFoto.Ac")
util.AddNetworkString("SardonFoto.Kapat")

local COOLDOWN = 15
local active = setmetatable({}, { __mode = "k" })
local cooldown = setmetatable({}, { __mode = "k" })

local function notify(ply, msg)
	if IsValid(ply) and ply.Notify then ply:Notify(msg) end
end

local function sinemaBloquea(ply)
	return SardonSinema and SardonSinema.Aktif and SardonSinema.Aktif(ply)
end

function SardonFoto.Cerrar(ply, razon, aplicarCooldown)
	if not IsValid(ply) or not active[ply] then return end

	active[ply] = nil

	if aplicarCooldown then
		cooldown[ply] = CurTime() + COOLDOWN
	end

	net.Start("SardonFoto.Kapat")
	net.WriteString(razon or "")
	net.Send(ply)
end

local function abrir(ply)
	if active[ply] then
		SardonFoto.Cerrar(ply)
		return
	end

	if (cooldown[ply] or 0) > CurTime() then
		local rest = math.ceil(cooldown[ply] - CurTime())
		notify(ply, "Debes esperar " .. rest .. " s antes de volver al modo foto.")
		return
	end

	if not ply:Alive() then
		notify(ply, "No puedes usar el modo foto ahora.")
		return
	end

	if sinemaBloquea(ply) then
		notify(ply, "No puedes usar el modo foto con la cámara de cine activa.")
		return
	end

	active[ply] = true

	net.Start("SardonFoto.Ac")
	net.Send(ply)
end

ix.command.Add("Foto", {
	description = "Modo foto: cámara libre de corto alcance alrededor de tu personaje. Escríbelo de nuevo para cerrar.",
	alias = { "FotoModu", "Fotograf" },
	OnRun = function(_, client)
		abrir(client)
		return false
	end,
})

net.Receive("SardonFoto.Durum", function(_, ply)
	if not IsValid(ply) then return end
	local abierto = net.ReadBool()

	if abierto then
		active[ply] = true
	else
		active[ply] = nil
	end
end)

hook.Add("EntityTakeDamage", "SardonFoto.Dano", function(target, dmg)
	if not IsValid(target) or not target:IsPlayer() then return end
	if not active[target] then return end

	SardonFoto.Cerrar(target, "El modo foto se cerró porque recibiste daño.", true)
end)

hook.Add("PlayerDeath", "SardonFoto.Muerte", function(ply)
	SardonFoto.Cerrar(ply, "", false)
end)

hook.Add("PlayerDisconnected", "SardonFoto.Salida", function(ply)
	active[ply] = nil
	cooldown[ply] = nil
end)

hook.Add("SetupMove", "SardonFoto.Movimiento", function(ply, mv)
	if not active[ply] then return end
	mv:SetMaxClientSpeed(0.0001)
	mv:SetMaxSpeed(0.0001)
end)