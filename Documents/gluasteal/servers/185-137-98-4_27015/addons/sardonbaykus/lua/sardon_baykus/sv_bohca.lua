-- Sardon Baykuş :: bolsa de objetos y Galleons
SardonBaykus = SardonBaykus or {}
local B = SardonBaykus

local function Notify(ply, msg)
	if not IsValid(ply) then return end
	if ply.Notify then ply:Notify(msg) else ix.util.Notify(ply, msg) end
end

function B.Setting(key)
	local s = B.Settings or {}
	return s[key]
end

function B.BohcaEnabled()
	return B.Setting("enabled") ~= 0
end

function B.MaxBohcaItems()
	return math.Clamp(tonumber(B.Setting("maxItems")) or B.MaxItemsHard or 5, 1, 5)
end

function B.MaxBohcaMoney()
	return math.max(0, tonumber(B.Setting("maxMoney")) or 50000)
end

hook.Add("CanTransferItem", "SardonBaykus.Bohca", function(item, _oldInv, newInv, x, y)
	if not B.BohcaEnabled() then return end
	local bag = newInv and newInv.vars and newInv.vars.isBag
	if bag ~= B.BohcaID then return end

	local itemTable = ix.item.list[item.uniqueID]
	local blocked, reason = B.IsHardBlocked(itemTable)
	if blocked then
		if item.player then Notify(item.player, reason or "No puedes meter eso en la bolsa.") end
		return false
	end

	if not B.IsWhitelisted(item.uniqueID) then
		if item.player then Notify(item.player, "Ese objeto no está permitido en bolsas de lechuza.") end
		return false
	end

	local bohca
	for _, it in pairs(ix.item.instances) do
		if it.uniqueID == B.BohcaID and it:GetData("id") == newInv:GetID() then
			bohca = it
			break
		end
	end

	if bohca and #B.GetBohcaItems(bohca) >= B.MaxBohcaItems() then
		if item.player then Notify(item.player, "La bolsa ya tiene el máximo de objetos.") end
		return false
	end
end)

function B.PutMoney(ply, item, amount)
	if not B.BohcaEnabled() then
		Notify(ply, "El sistema de bolsas está desactivado.")
		return
	end
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then return end
	local maxM = B.MaxBohcaMoney()
	if maxM <= 0 then
		Notify(ply, "No se pueden enviar Galleons por lechuza.")
		return
	end

	local char = ply:GetCharacter()
	if not char or char:GetMoney() < amount then
		Notify(ply, "No tienes suficientes Galleons.")
		return
	end

	local current = B.GetBohcaMoney(item)
	if current + amount > maxM then
		Notify(ply, "Superarías el límite de la bolsa (" .. maxM .. " G).")
		return
	end

	char:TakeMoney(amount)
	item:SetData("money", current + amount)
	Notify(ply, "Has guardado " .. amount .. " Galleons en la bolsa.")
end

function B.TakeMoney(ply, item)
	local money = B.GetBohcaMoney(item)
	if money <= 0 then return end
	local char = ply:GetCharacter()
	if not char then return end
	char:GiveMoney(money)
	item:SetData("money", 0)
	Notify(ply, "Has recuperado " .. money .. " Galleons.")
end

function B.CollectAll(ply, item)
	local char = ply:GetCharacter()
	local inv = char and char:GetInventory()
	if not inv then return end

	for _, sub in ipairs(B.GetBohcaItems(item)) do
		if not inv:Add(sub.uniqueID, 1, sub.data) then
			ix.item.Spawn(sub.uniqueID, ply:GetItemDropPos(), nil, angle_zero, sub.data)
		end
		sub:Remove()
	end

	B.TakeMoney(ply, item)
	Notify(ply, "Has vaciado la bolsa en tu inventario.")
end

function B.AttachBohcaToSend(ply, itemId)
	local inv = ply:GetCharacter() and ply:GetCharacter():GetInventory()
	if not inv then return false end
	local item = inv:GetItemByID(itemId)
	if not item or item.uniqueID ~= B.BohcaID then
		Notify(ply, "Bolsa no encontrada.")
		return false
	end
	if B.IsBohcaEmpty(item) then
		Notify(ply, "La bolsa está vacía.")
		return false
	end
	if not item:Remove() then
		Notify(ply, "No se pudo retirar la bolsa del inventario.")
		return false
	end
	return item
end

function B.DeliverBohca(flight, receiver, _row)
	local item = flight and flight.bohcaItem
	if not item then return end

	local inv = receiver:GetCharacter() and receiver:GetCharacter():GetInventory()
	if inv and inv:Add(item.uniqueID, 1, item.data) then
		item:SetData("from", flight.sender and flight.sender:Name() or "")
		Notify(receiver, "Has recibido una bolsa con objetos por lechuza.")
		B.Log("deliver", "", "", receiver:Name(), "Bolsa entregada")
		return
	end

	B.PendingBohca = B.PendingBohca or {}
	B.PendingBohca[flight.msgId] = {
		msgId = flight.msgId,
		owner = receiver:Name(),
		ownerChar = tostring(receiver:GetCharacter():GetID()),
		summary = table.concat(B.SummarizeBohca(item), ", "),
		created = os.time(),
		itemData = item.data,
		bagInv = item:GetData("id"),
		money = B.GetBohcaMoney(item),
	}
	B.SavePending()
	Notify(receiver, "Tu bolsa quedó en espera (sin hueco en el inventario).")
	B.Log("pending", "", "", receiver:Name(), "Bolsa en espera")
end

function B.TryGivePendingBohca(ply)
	local ch = ply:GetCharacter()
	if not ch then return end
	local cid = tostring(ch:GetID())
	local inv = ch:GetInventory()
	if not inv then return end

	for msgId, pend in pairs(B.PendingBohca or {}) do
		if pend.ownerChar == cid then
			if inv:Add(B.BohcaID, 1, pend.itemData or {}) then
				B.PendingBohca[msgId] = nil
				B.SavePending()
				Notify(ply, "Una bolsa pendiente ha llegado a tu inventario.")
			end
		end
	end
end

hook.Add("SardonBaykusAccioStatum", "SardonBaykus.Bohca", function(caster, wand)
	if B.Setting("accio") == 0 then return end
	if not IsValid(caster) or not IsValid(wand) then return end

	local range = tonumber(B.Setting("accioRange")) or 1200
	local aim = wand.HPWGetAimEntity and wand:HPWGetAimEntity(range) or caster:GetEyeTrace().Entity

	for msgId, flight in pairs(B.Flights or {}) do
		local owl = flight.owl
		if IsValid(owl) and flight.bohcaItem and owl:GetPos():DistToSqr(caster:GetPos()) <= range * range then
			local item = flight.bohcaItem
			flight.bohcaItem = nil
			B.Flights[msgId] = nil
			owl:SetNWBool("SardonBohca", false)
			owl:SetNWBool("busy", false)

			if IsValid(item.entity) then return end
			local drop = item.Spawn and item:Spawn(caster:GetItemDropPos()) or ix.item.Spawn(B.BohcaID, caster:GetItemDropPos(), nil, angle_zero, item.data)
			B.Log("drop", caster:Name(), "", "", "Accio Statum soltó bolsa (msg " .. msgId .. ")")
			Notify(caster, "La bolsa cayó al suelo.")
			return
		end
	end
end)

-- stub llamado desde otros addons si hace falta enganchar hechizos
function B.AccioHookStub()
	hook.Run("SardonBaykusAccioStatum")
end