if not SERVER then return end

SardonPolaroid = SardonPolaroid or {}

util.AddNetworkString("SardonPolaroid.ChooseMode")
util.AddNetworkString("SardonPolaroid.StartCapture")
util.AddNetworkString("SardonPolaroid.Notify")

SardonPolaroid.Pending = SardonPolaroid.Pending or {}

local function notify(ply, msg)
	if not IsValid(ply) then return end
	if ply.Notify then ply:Notify(msg) end
end

function SardonPolaroid.HasPending(ply)
	return IsValid(ply) and SardonPolaroid.Pending[ply] ~= nil
end

function SardonPolaroid.ClearPending(ply)
	if not IsValid(ply) then return end
	SardonPolaroid.Pending[ply] = nil
end

function SardonPolaroid.RemoveCameras(ply)
	for _, ent in ipairs(ents.FindByClass("ent_polaroid_camera")) do
		if IsValid(ent) and ent:GetNWEntity("Owner") == ply then
			ent:Remove()
		end
	end
end

function SardonPolaroid.AskMode(ply, hitPos)
	if not IsValid(ply) or not ply:GetCharacter() then return end
	if ply:GetCharacter():GetInventory():FindEmptySlot(1, 1) == nil then
		notify(ply, "No tienes espacio en el inventario para una foto.")
		return
	end

	SardonPolaroid.RemoveCameras(ply)
	SardonPolaroid.Pending[ply] = {
		hitPos = hitPos,
		started = CurTime(),
	}

	net.Start("SardonPolaroid.ChooseMode")
	net.Send(ply)
end

include("sardon_polaroid/sv_capture.lua")
include("sardon_polaroid/sv_foto.lua")

net.Receive("SardonPolaroid.ChooseMode", function(_, ply)
	if not IsValid(ply) or not SardonPolaroid.Pending[ply] then return end

	local mode = net.ReadUInt(2)
	if mode == 0 then
		SardonPolaroid.ClearPending(ply)
		return
	end

	SardonPolaroid.BeginCapture(ply, mode)
end)

hook.Add("PlayerDisconnected", "SardonPolaroid.Pending", function(ply)
	SardonPolaroid.ClearPending(ply)
	SardonPolaroid.RemoveCameras(ply)
end)

MsgN("[SardonPolaroid] sv_init cargado.")