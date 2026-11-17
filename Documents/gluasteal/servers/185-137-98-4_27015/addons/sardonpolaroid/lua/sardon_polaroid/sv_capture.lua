if not SERVER then return end

SardonPolaroid = SardonPolaroid or {}

local MAX_ID_LEN = 96

local function notify(ply, msg)
	if IsValid(ply) and ply.Notify then ply:Notify(msg) end
end

local function playerCamera(ply)
	for _, ent in ipairs(ents.FindByClass("ent_polaroid_camera")) do
		if IsValid(ent) and ent:GetNWEntity("Owner") == ply then
			return ent
		end
	end
end

local function spawnCamera(ply, mode, hitPos)
	local eye = ply:EyePos()
	local flat = Angle(0, ply:EyeAngles().y, 0)
	local pos, ang

	if mode == 1 then
		pos = eye + flat:Forward() * 52 + Vector(0, 0, 6)
		ang = (eye - pos):Angle()
	else
		pos = (isvector(hitPos) and hitPos or (eye + flat:Forward() * 72)) + Vector(0, 0, 12)
		ang = (eye - pos):Angle()
	end

	local cam = ents.Create("ent_polaroid_camera")
	if not IsValid(cam) then return end

	cam:SetPos(pos)
	cam:SetAngles(ang)
	cam:Spawn()
	cam:Activate()
	cam:SetNWEntity("Owner", ply)

	return cam
end

function SardonPolaroid.BeginCapture(ply, mode)
	local pending = SardonPolaroid.Pending[ply]
	if not pending or not IsValid(ply) or not ply:GetCharacter() then return end

	if pending.camera and IsValid(pending.camera) then
		pending.camera:Remove()
	end

	pending.mode = mode
	pending.camera = spawnCamera(ply, mode, pending.hitPos)
	if not IsValid(pending.camera) then
		notify(ply, "No se pudo crear la cámara.")
		SardonPolaroid.ClearPending(ply)
		return
	end

	net.Start("SardonPolaroid.StartCapture")
	net.Send(ply)
end

function SardonPolaroid.FinishCapture(ply, imageId)
	if not IsValid(ply) or not ply:GetCharacter() then return end

	local pending = SardonPolaroid.Pending[ply]
	if not pending then
		notify(ply, "No hay ninguna captura pendiente.")
		return
	end

	if not isstring(imageId) or imageId == "" or #imageId > MAX_ID_LEN or imageId:find("[^%w%-_]") then
		notify(ply, "Identificador de imagen no válido.")
		SardonPolaroid.ClearPending(ply)
		SardonPolaroid.RemoveCameras(ply)
		return
	end

	local inv = ply:GetCharacter():GetInventory()
	if inv:FindEmptySlot(1, 1) == nil then
		notify(ply, "No tienes espacio en el inventario.")
		SardonPolaroid.ClearPending(ply)
		SardonPolaroid.RemoveCameras(ply)
		return
	end

	if not inv:Add("PolaroidPhoto", 1, { Image = imageId }) then
		notify(ply, "No se pudo añadir la foto al inventario.")
		SardonPolaroid.ClearPending(ply)
		SardonPolaroid.RemoveCameras(ply)
		return
	end

	ply:EmitSound("npc/scanner/scanner_photo1.wav", 75, 100, 0.8)
	notify(ply, "El recuerdo ha quedado capturado.")

	SardonPolaroid.ClearPending(ply)
	SardonPolaroid.RemoveCameras(ply)
end

net.Receive("SardonPolaroid.Notify", function(_, ply)
	if not IsValid(ply) or not SardonPolaroid.Pending[ply] then return end

	local cam = playerCamera(ply)
	if IsValid(cam) then
		cam:SetNWBool("Flashed", true)
		timer.Simple(0.25, function()
			if IsValid(cam) then cam:SetNWBool("Flashed", false) end
		end)
	end
end)

net.Receive("SardonPolaroid.StartCapture", function(_, ply)
	local id = net.ReadString()
	if id == "" then return end
	SardonPolaroid.FinishCapture(ply, id)
end)