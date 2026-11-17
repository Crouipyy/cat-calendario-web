if not SERVER then return end

SardonMatbaa = SardonMatbaa or {}
local M, cfg = SardonMatbaa, SardonMatbaa.Config

util.AddNetworkString("SardonMatbaa.Open")
util.AddNetworkString("SardonMatbaa.Stock")
util.AddNetworkString("SardonMatbaa.Deposit")
util.AddNetworkString("SardonMatbaa.Withdraw")
util.AddNetworkString("SardonMatbaa.Print")
util.AddNetworkString("SardonMatbaa.View")

local USE_DIST = 220

local function char(ply)
	return IsValid(ply) and ply:GetCharacter()
end

local function notify(ply, msg)
	if IsValid(ply) and ply.Notify then ply:Notify(msg) end
end

function M.GetStock(machine)
	machine.matbaaStock = machine.matbaaStock or { ink = 0, paper = 0 }
	return machine.matbaaStock
end

function M.SyncStock(ply, machine)
	if not IsValid(machine) then return end
	local st = M.GetStock(machine)

	net.Start("SardonMatbaa.Stock")
	net.WriteUInt(math.min(st.ink, 65535), 16)
	net.WriteUInt(math.min(st.paper, 65535), 16)
	net.Send(ply)
end

function M.OpenMenu(client, machine)
	if not IsValid(client) or not IsValid(machine) or machine:GetClass() ~= "ent_matbaa" then return end
	if client:GetPos():DistToSqr(machine:GetPos()) > USE_DIST * USE_DIST then return end
	if not char(client) then return end

	local st = M.GetStock(machine)

	net.Start("SardonMatbaa.Open")
	net.WriteEntity(machine)
	net.WriteUInt(math.min(st.ink, 65535), 16)
	net.WriteUInt(math.min(st.paper, 65535), 16)
	net.Send(client)
end

local function validMachine(ply, ent)
	if not IsValid(ply) or not IsValid(ent) or ent:GetClass() ~= "ent_matbaa" then return false end
	if ply:GetPos():DistToSqr(ent:GetPos()) > USE_DIST * USE_DIST then return false end
	if not char(ply) then return false end
	return true
end

local function takeItems(inv, uniqueID, amount)
	amount = math.max(0, math.floor(amount or 0))
	if amount <= 0 then return 0 end

	local taken = 0
	for _, item in pairs(inv:GetItems()) do
		if taken >= amount then break end
		if item.uniqueID == uniqueID and not IsValid(item.entity) then
			item:Remove()
			taken = taken + 1
		end
	end

	return taken
end

local function giveItems(ply, uniqueID, amount)
	amount = math.max(0, math.floor(amount or 0))
	if amount <= 0 then return true end

	local inv = char(ply):GetInventory()
	for _ = 1, amount do
		if not inv:Add(uniqueID, 1) then
			return false
		end
	end

	return true
end

net.Receive("SardonMatbaa.Deposit", function(_, ply)
	local machine = net.ReadEntity()
	local inkAmt = net.ReadUInt(16)
	local paperAmt = net.ReadUInt(16)

	if not validMachine(ply, machine) then return end

	local inv = char(ply):GetInventory()
	local st = M.GetStock(machine)

	if inkAmt > 0 then
		local moved = takeItems(inv, M.INK, inkAmt)
		st.ink = math.min(st.ink + moved, 65535)
	end

	if paperAmt > 0 then
		local moved = takeItems(inv, M.PAPER, paperAmt)
		st.paper = math.min(st.paper + moved, 65535)
	end

	inv:Sync(ply)
	M.SyncStock(ply, machine)
end)

net.Receive("SardonMatbaa.Withdraw", function(_, ply)
	local machine = net.ReadEntity()
	local inkAmt = net.ReadUInt(16)
	local paperAmt = net.ReadUInt(16)

	if not validMachine(ply, machine) then return end

	local st = M.GetStock(machine)
	inkAmt = math.min(inkAmt, st.ink)
	paperAmt = math.min(paperAmt, st.paper)

	if inkAmt > 0 and not giveItems(ply, M.INK, inkAmt) then
		notify(ply, "No tienes espacio en el inventario para la tinta.")
		return
	end

	if paperAmt > 0 and not giveItems(ply, M.PAPER, paperAmt) then
		notify(ply, "No tienes espacio en el inventario para el papel.")
		return
	end

	st.ink = st.ink - inkAmt
	st.paper = st.paper - paperAmt
	char(ply):GetInventory():Sync(ply)
	M.SyncStock(ply, machine)
end)

include("sardon_matbaa/sv_print.lua")
include("sardon_matbaa/sv_poster.lua")
include("sardon_matbaa/sv_items.lua")

MsgN("[SardonMatbaa] sv_init cargado.")