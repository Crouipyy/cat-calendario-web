-- Sardon Baykuş :: panel de administración
SardonBaykus = SardonBaykus or {}
local B = SardonBaykus

util.AddNetworkString("SardonBaykus.Admin")
util.AddNetworkString("SardonBaykus.AdminData")

local function IsAdmin(ply)
	return IsValid(ply) and ply:IsAdmin()
end

local function Notify(ply, msg)
	if ply.Notify then ply:Notify(msg) else ix.util.Notify(ply, msg) end
end

local function CharName(charId)
	local id = tonumber(charId)
	if id and ix.char.loaded[id] then return ix.char.loaded[id].vars.name end
	return tostring(charId or "?")
end

local function BuildStats()
	local total = sql.Query("SELECT COUNT(*) AS c FROM sardon_baykus;")
	local unread = sql.Query("SELECT COUNT(*) AS c FROM sardon_baykus WHERE read_flag = '0';")
	local sent24 = sql.Query("SELECT COUNT(*) AS c FROM sardon_baykus WHERE timestamp > " .. (os.time() - 86400) .. ";")

	local flights = 0
	for _ in pairs(B.Flights or {}) do flights = flights + 1 end

	local pending = 0
	for _ in pairs(B.PendingBohca or {}) do pending = pending + 1 end

	return {
		totalMessages = total and tonumber(total[1].c) or 0,
		unread = unread and tonumber(unread[1].c) or 0,
		owlsOut = flights,
		flights = flights,
		pending = pending,
		sent24 = sent24 and tonumber(sent24[1].c) or 0,
		bohca24 = 0,
		drops24 = 0,
		whitelisted = B.WhitelistCount(),
	}
end

local function BuildMessages()
	local rows = sql.Query("SELECT * FROM sardon_baykus ORDER BY timestamp DESC LIMIT 150;") or {}
	local out = {}
	for _, r in ipairs(rows) do
		out[#out + 1] = {
			id = r.id,
			time = tonumber(r.timestamp) or 0,
			sender = CharName(r.sender),
			receiver = CharName(r.receiver),
			anonim = r.anonim == "1",
			unread = r.read_flag ~= "1",
			content = r.content,
			hasLocation = string.find(r.content or "", "-----LOCDATA%-") ~= nil,
		}
	end
	return out
end

local function BuildFlights()
	local out = {}
	for msgId, f in pairs(B.Flights or {}) do
		out[#out + 1] = {
			msgId = msgId,
			sender = IsValid(f.sender) and f.sender:Name() or "?",
			receiver = IsValid(f.receiver) and f.receiver:Name() or "?",
			summary = f.bohcaItem and "Bolsa" or "Carta",
			elapsed = math.floor(CurTime() - (f.start or CurTime())),
			distance = IsValid(f.owl) and IsValid(f.receiver) and math.floor(f.owl:GetPos():Distance(f.receiver:GetPos())) or -1,
			returning = f.returning == true,
		}
	end
	return out
end

local function BuildPending()
	local out = {}
	for msgId, p in pairs(B.PendingBohca or {}) do
		local online = false
		for _, ply in ipairs(player.GetAll()) do
			local ch = ply:GetCharacter()
			if ch and tostring(ch:GetID()) == p.ownerChar then online = true break end
		end
		out[#out + 1] = {
			msgId = msgId,
			owner = p.owner or "?",
			ownerOnline = online,
			sender = p.sender or "",
			receiver = p.receiver or p.owner or "",
			summary = p.summary or "",
			created = p.created or 0,
		}
	end
	return out
end

local function BuildPayload(open)
	local wl = {}
	for id, on in pairs(B.Whitelist or {}) do
		if on then wl[#wl + 1] = id end
	end
	table.sort(wl)

	return {
		open = open,
		stats = BuildStats(),
		logs = B.Logs or {},
		messages = BuildMessages(),
		flights = BuildFlights(),
		pending = BuildPending(),
		whitelist = wl,
		settings = table.Copy(B.Settings or B.DbDefaults()),
		defaults = B.DbDefaults(),
	}
end

function B.SendAdminData(ply, open)
	if not IsAdmin(ply) then return end
	local payload = BuildPayload(open == true)
	local json = util.TableToJSON(payload, false)
	local compressed = util.Compress(json)
	net.Start("SardonBaykus.AdminData")
	net.WriteUInt(#compressed, 32)
	net.WriteData(compressed, #compressed)
	net.Send(ply)
end

local function AdminLog(ply, action, details)
	B.Log("admin", ply:Name(), "", "", action .. (details and (": " .. details) or ""))
end

net.Receive("SardonBaykus.Admin", function(_, ply)
	if not IsAdmin(ply) then return end
	local action = net.ReadString()
	local payload = net.ReadTable() or {}

	if action == "refresh" or action == "whitelist_save" then
		if action == "whitelist_save" and istable(payload.ids) then
			B.Whitelist = {}
			for _, id in ipairs(payload.ids) do
				B.Whitelist[id] = true
			end
			B.SaveWhitelist()
			AdminLog(ply, "whitelist_save", #payload.ids .. " ítems")
			Notify(ply, "Lista de permitidos guardada.")
		end
		B.SendAdminData(ply, true)
		return
	end

	if action == "settings_save" and istable(payload.settings) then
		B.Settings = payload.settings
		B.SaveSettings()
		AdminLog(ply, "settings_save")
		Notify(ply, "Ajustes guardados.")
		B.SendAdminData(ply, true)
		return
	end

	if action == "message_delete" and payload.id then
		sql.Query("DELETE FROM sardon_baykus WHERE id = " .. sql.SQLStr(tostring(payload.id)) .. ";")
		AdminLog(ply, "message_delete", tostring(payload.id))
		Notify(ply, "Mensaje eliminado.")
		B.SendAdminData(ply, true)
		return
	end

	if action == "pending_delete" and payload.msgId then
		B.PendingBohca[payload.msgId] = nil
		B.SavePending()
		AdminLog(ply, "pending_delete", payload.msgId)
		Notify(ply, "Bolsa pendiente eliminada.")
		B.SendAdminData(ply, true)
		return
	end

	if action == "pending_give" and payload.msgId then
		for _, p in ipairs(player.GetAll()) do
			B.TryGivePendingBohca(p)
		end
		Notify(ply, "Se intentó entregar bolsas pendientes.")
		B.SendAdminData(ply, true)
		return
	end

	if action == "flight_deliver" and payload.msgId then
		timer.Remove("SardonBaykus.Flight_" .. payload.msgId)
		timer.Remove("SardonBaykus.FlightTimeout_" .. payload.msgId)
		B.FinishFlight(payload.msgId, true)
		AdminLog(ply, "flight_deliver", payload.msgId)
		B.SendAdminData(ply, true)
		return
	end

	if action == "flight_return" and payload.msgId then
		B.Flights[payload.msgId] = nil
		timer.Remove("SardonBaykus.Flight_" .. payload.msgId)
		AdminLog(ply, "flight_return", payload.msgId)
		B.SendAdminData(ply, true)
		return
	end

	if action == "flight_goto" and payload.msgId then
		local f = B.Flights[payload.msgId]
		if f and IsValid(f.owl) then
			ply:SetPos(f.owl:GetPos() + Vector(0, 0, 20))
		end
		return
	end

	if action == "webhook_test" then
		Notify(ply, "Webhook de prueba (no configurado en este servidor).")
		return
	end

	B.SendAdminData(ply, true)
end)