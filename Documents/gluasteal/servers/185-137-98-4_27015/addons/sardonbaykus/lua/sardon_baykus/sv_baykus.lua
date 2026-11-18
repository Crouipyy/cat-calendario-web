-- Sardon Baykuş :: lógica de mensajes y red
SardonBaykus = SardonBaykus or {}
local B = SardonBaykus

util.AddNetworkString("baykus_send")
util.AddNetworkString("baykus_list")
util.AddNetworkString("baykus_read")
util.AddNetworkString("update_baykusstat")

B.Flights = B.Flights or {}

local DARK_AREA = "Karanlık Orman"

local function Notify(ply, msg)
	if not IsValid(ply) then return end
	if ply.Notify then
		ply:Notify(msg)
	elseif ix and ix.util and ix.util.Notify then
		ix.util.Notify(ply, msg)
	end
end

local function CharId(ply)
	local ch = IsValid(ply) and ply:GetCharacter()
	return ch and tostring(ch:GetID()) or nil
end

local function CharName(charId)
	local id = tonumber(charId)
	if id and ix.char.loaded[id] then
		return ix.char.loaded[id].vars.name or charId
	end
	return charId or "?"
end

function B.EnrichRows(rows)
	rows = rows or {}
	return SardonUtil and SardonUtil.TableMap(rows, function(val)
		local sid = tonumber(val.sender)
		if sid and ix.char.loaded[sid] then
			val.mdl = ix.char.loaded[sid].vars.model
			val.name = ix.char.loaded[sid].vars.name
			val.bgs = ix.char.loaded[sid].vars.bodygroups or "0"
		end
		return val
	end) or rows
end

function B.UpdateInbox(ply)
	if not IsValid(ply) then return end
	local cid = CharId(ply)
	if not cid then
		ply:SetNWInt("baykus_inbox", 0)
		return
	end
	local q = sql.Query("SELECT COUNT(*) AS c FROM sardon_baykus WHERE receiver = " .. sql.SQLStr(cid) .. " AND read_flag = '0';")
	local n = q and tonumber(q[1].c) or 0
	ply:SetNWInt("baykus_inbox", n)
end

local function InDarkForest(ply)
	if not IsValid(ply) or not ply.GetArea then return false end
	return ply:GetArea() == DARK_AREA
end

local function CanUseOwl(ply)
	if InDarkForest(ply) then return false, "No puedes enviar ni recibir lechuzas en el Bosque Oscuro." end
	return true
end

local function ContentLimit(text)
	text = tostring(text or "")
	if #text > 8000 then
		text = string.sub(text, 1, 8000)
	end
	return text
end

function B.SendMessageTable(ply, rows)
	if not IsValid(ply) then return end
	net.Start("baykus_send")
	net.WriteTable(B.EnrichRows(rows))
	net.Send(ply)
end

function B.SendList(ply)
	local cid = CharId(ply)
	if not cid then return end
	local rows = sql.Query("SELECT * FROM sardon_baykus WHERE receiver = " .. sql.SQLStr(cid) .. " ORDER BY timestamp DESC LIMIT 80;") or {}
	net.Start("baykus_list")
	net.WriteTable(B.EnrichRows(rows))
	net.Send(ply)
end

function B.DeliverScroll(ply, msgId)
	if not IsValid(ply) then return end
	local row = sql.Query("SELECT * FROM sardon_baykus WHERE id = " .. sql.SQLStr(tostring(msgId)) .. " LIMIT 1;")
	if not row or not row[1] then return end
	local inv = ply:GetCharacter() and ply:GetCharacter():GetInventory()
	if inv then
		inv:Add("owl_scroll", 1, {msgId = tostring(msgId)})
	end
	B.UpdateInbox(ply)
end

function B.FinishFlight(msgId, delivered)
	local flight = B.Flights[msgId]
	if not flight then return end
	B.Flights[msgId] = nil

	if IsValid(flight.owl) then
		flight.owl:SetNWBool("SardonBohca", false)
		flight.owl:SetNWBool("busy", false)
		if flight.owl.SetNWEntity then
			flight.owl:SetNWEntity("target", NULL)
		end
	end

	local row = sql.Query("SELECT * FROM sardon_baykus WHERE id = " .. sql.SQLStr(tostring(msgId)) .. " LIMIT 1;")
	if not row or not row[1] then return end
	local r = row[1]
	local receiver = player.GetByCharID and player.GetByCharID(tonumber(r.receiver))
	if not IsValid(receiver) then
		for _, p in ipairs(player.GetAll()) do
			if CharId(p) == r.receiver then
				receiver = p
				break
			end
		end
	end

	if delivered and IsValid(receiver) then
		B.SendMessageTable(receiver, {r})
		B.DeliverScroll(receiver, msgId)
		if flight and flight.bohcaItem then
			B.DeliverBohca(flight, receiver, r)
		end
		B.Log("deliver", "", CharName(r.sender), CharName(r.receiver), "Mensaje entregado" .. (flight and flight.bohcaItem and " con bolsa" or ""))
	else
		B.SendMessageTable(receiver, {r})
		if IsValid(receiver) then
			B.DeliverScroll(receiver, msgId)
		end
	end
end

function B.StartFlight(sender, receiver, msgId, withBohca)
	B.Flights[tostring(msgId)] = {
		msgId = tostring(msgId),
		sender = sender,
		receiver = receiver,
		start = CurTime(),
		bohcaItem = withBohca,
		returning = false,
	}

	local owl
	if StPets and StPets.DoesHave then
		owl = StPets.DoesHave(sender, "PetOwl") or StPets.DoesHave(sender, "owl")
	end

	local flight = B.Flights[tostring(msgId)]
	flight.owl = owl

	local delay = 8
	if IsValid(owl) and IsValid(receiver) then
		owl:SetNWBool("busy", true)
		if owl.SetNWEntity then
			owl:SetNWEntity("target", receiver)
		end
		if withBohca then
			owl:SetNWBool("SardonBohca", true)
		end
		local dist = owl:GetPos():Distance(receiver:GetPos())
		delay = math.Clamp(dist / 400, 4, 45)
	end

	timer.Create("SardonBaykus.Flight_" .. msgId, delay, 1, function()
		B.FinishFlight(msgId, true)
	end)

	timer.Create("SardonBaykus.FlightTimeout_" .. msgId, (B.Settings and B.Settings.flightTimeout) or 600, 1, function()
		if B.Flights[tostring(msgId)] then
			B.Log("return", "", CharName(CharId(sender)), CharName(CharId(receiver)), "Tiempo de vuelo agotado")
			B.Flights[tostring(msgId)] = nil
		end
	end)
end

function B.InsertMessage(sender, receiver, content, anonim, bohcaMeta)
	local ts = os.time()
	local q = string.format(
		"INSERT INTO sardon_baykus (sender, receiver, content, anonim, read_flag, timestamp, bohca_owner, bohca_data) VALUES (%s, %s, %s, %s, '0', %d, %s, %s);",
		sql.SQLStr(CharId(sender)),
		sql.SQLStr(CharId(receiver)),
		sql.SQLStr(content),
		sql.SQLStr(anonim and "1" or "0"),
		ts,
		sql.SQLStr(bohcaMeta and bohcaMeta.owner or ""),
		sql.SQLStr(bohcaMeta and util.TableToJSON(bohcaMeta.data or {}) or "")
	)
	sql.Query(q)
	local idRow = sql.Query("SELECT last_insert_rowid() AS id;")
	return idRow and idRow[1] and idRow[1].id
end

function B.MarkRead(ply, msgId)
	local cid = CharId(ply)
	if not cid then return end
	sql.Query("UPDATE sardon_baykus SET read_flag = '1' WHERE id = " .. sql.SQLStr(tostring(msgId)) .. " AND receiver = " .. sql.SQLStr(cid) .. ";")
	B.UpdateInbox(ply)
end

-- Suscripción de periódico / entrega automatizada
function B.GazeteTeslim(ply, itemUnique, data)
	if not IsValid(ply) or not ply:GetCharacter() then return false end
	local inv = ply:GetCharacter():GetInventory()
	if not inv then return false end
	itemUnique = itemUnique or "gazete_sayi"
	data = istable(data) and data or {}
	local content = data.content or data.manset or data.metin or "Tu ejemplar del periódico ha llegado."
	local msgId = B.InsertMessage(ply, ply, ContentLimit(content), false, nil)
	if not msgId then return false end
	if data.giveItem ~= false then
		inv:Add("owl_scroll", 1, {msgId = tostring(msgId)})
	end
	B.UpdateInbox(ply)
	B.SendMessageTable(ply, sql.Query("SELECT * FROM sardon_baykus WHERE id = " .. sql.SQLStr(tostring(msgId)) .. ";") or {})
	B.Log("deliver", "gazete", CharName(CharId(ply)), CharName(CharId(ply)), "Entrega de periódico")
	return true
end

net.Receive("update_baykusstat", function(_, ply)
	local key = net.ReadString()
	local on = net.ReadBool()
	if key == "yzr" then
		ply:SetNWBool("baykus_yzr", on)
	elseif key == "okyr" then
		ply:SetNWBool("baykus_okyr", on)
	end
end)

net.Receive("baykus_read", function(_, ply)
	B.MarkRead(ply, net.ReadString())
end)

net.Receive("baykus_send", function(_, ply)
	local target = net.ReadEntity()
	local anonim = net.ReadBool()
	local text = ContentLimit(net.ReadString())
	local bohcaItemId = net.ReadUInt(32)

	local ok, err = CanUseOwl(ply)
	if not ok then
		Notify(ply, err)
		return
	end

	if not IsValid(target) or not target:IsPlayer() or target == ply then
		Notify(ply, "Destinatario inválido.")
		return
	end

	local ok2, err2 = CanUseOwl(target)
	if not ok2 then
		Notify(ply, err2)
		return
	end

	if not ply:GetCharacter() or not target:GetCharacter() then
		Notify(ply, "Ambos deben tener personaje.")
		return
	end

	local bohcaItem
	if bohcaItemId > 0 and B.AttachBohcaToSend then
		bohcaItem = B.AttachBohcaToSend(ply, bohcaItemId)
		if bohcaItem == false then
			return
		end
	end

	local msgId = B.InsertMessage(ply, target, text, anonim, nil)
	if not msgId then
		Notify(ply, "No se pudo guardar el mensaje.")
		return
	end

	B.Log("send", ply:Name(), CharName(CharId(ply)), CharName(CharId(target)), (#text > 80 and string.sub(text, 1, 77) .. "..." or text))
	B.StartFlight(ply, target, msgId, bohcaItem)
	Notify(ply, "La lechuza ha partido con tu carta.")
	B.UpdateInbox(target)
end)

hook.Add("PlayerLoadedCharacter", "SardonBaykus.Inbox", function(ply)
	timer.Simple(1, function()
		if IsValid(ply) then
			B.UpdateInbox(ply)
			B.TryGivePendingBohca(ply)
		end
	end)
end)

hook.Add("PlayerInitialSpawn", "SardonBaykus.Fog", function(ply)
	timer.Simple(2, function()
		if IsValid(ply) then
			B.UpdateFog(ply)
		end
	end)
end)

hook.Add("OnPlayerAreaChanged", "SardonBaykus.Fog", function(ply, _old, _new)
	B.UpdateFog(ply)
end)

function B.UpdateFog(ply)
	if not IsValid(ply) then return end
	local fac = ply:GetCharacter() and ply:GetCharacter():GetFaction()
	local name = fac and ix.faction.indices[fac] and ix.faction.indices[fac].name or ""
	local exempt = string.find(name, "Oscuro") or string.find(name, "Snatcher")
	ply:SetNWBool("fogReq", InDarkForest(ply) and not exempt)
end

-- API usada desde sh_items (servidor)
function B.OpenScrollList(ply)
	B.SendList(ply)
end

MsgN("[SardonBaykus] Servidor listo.")

function B.OpenSingleScroll(ply, item)
	if not item then return false end
	local msgId = item:GetData("msgId")
	if not msgId then return false end
	local row = sql.Query("SELECT * FROM sardon_baykus WHERE id = " .. sql.SQLStr(tostring(msgId)) .. " LIMIT 1;") or {}
	B.SendMessageTable(ply, row)
	return false
end