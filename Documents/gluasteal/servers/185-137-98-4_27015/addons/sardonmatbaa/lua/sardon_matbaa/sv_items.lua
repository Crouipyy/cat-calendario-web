if not SERVER then return end

local M, cfg = SardonMatbaa, SardonMatbaa.Config

local function notify(ply, msg)
	if IsValid(ply) and ply.Notify then ply:Notify(msg) end
end

function M.ShowToTarget(ply, item)
	if not IsValid(ply) or not item then return end

	local tr = ply:GetEyeTrace()
	local target = IsValid(tr.Entity) and tr.Entity:IsPlayer() and tr.Entity or ply
	local format = item.GetFormat and item:GetFormat()

	net.Start("SardonMatbaa.View")
	net.WriteString(item:GetData("url", ""))
	net.WriteString(format and format.ad or "")
	net.WriteString(item:GetData("basan", ""))
	net.WriteString(ply:GetCharacter() and ply:GetCharacter():GetName() or ply:Name())
	net.Send(target)
end

function M.PickUpPrint(ply, ent)
	if not IsValid(ply) or not IsValid(ent) or not ply:GetCharacter() then return end

	local inv = ply:GetCharacter():GetInventory()
	if inv:FindEmptySlot(1, 1) == nil then
		notify(ply, "No tienes espacio en el inventario.")
		return
	end

	local format = M.GetFormat(ent:GetFormat())
	if not format or not format.item then return end

	if not inv:Add(format.item, 1, {
		url = ent:GetURL(),
		basan = ent:GetPrinter(),
		tarih = os.time(),
	}) then
		notify(ply, "No se pudo recoger la impresión.")
		return
	end

	ply:EmitSound("npc/zombie/foot_slide" .. math.random(1, 3) .. ".wav", 75, math.random(90, 120), 1)

	if ent:GetClass() == "ent_matbaa_poster" then
		SafeRemoveEntity(ent)
		M.SavePosters()
	else
		SafeRemoveEntity(ent)
	end
end

function M.EmptyBox(ply, item)
	if not IsValid(ply) or not item or not ply:GetCharacter() then return end

	local bagInv = item:GetInventory and item:GetInventory()
	if not bagInv then return end

	local mainInv = ply:GetCharacter():GetInventory()
	local moved = 0

	for _, bagItem in pairs(bagInv:GetItems()) do
		if bagItem.isMatbaaPrint then
			if bagItem:Transfer(mainInv:GetID()) then
				moved = moved + 1
			elseif not mainInv:Add(bagItem.uniqueID, 1, bagItem.data) then
				notify(ply, "Inventario lleno; no se pudo vaciar del todo.")
				break
			else
				bagItem:Remove()
				moved = moved + 1
			end
		end
	end

	if moved > 0 then
		notify(ply, moved .. " impresión(es) movida(s) a tu inventario.")
		mainInv:Sync(ply)
		bagInv:Sync(ply)
	end
end

hook.Add("CanPlayerTakeItem", "SardonMatbaa.KutuKilit", function(client, item)
	if not IsValid(client) or not item or item.uniqueID ~= M.BOX then return end
	if not IsValid(item.entity) or not cfg.KutuSahipKilidi or cfg.KutuSahipKilidi <= 0 then return end

	local ent = item.entity
	local untilTime = ent.matbaaLockUntil

	if untilTime and CurTime() < untilTime then
		local ch = client:GetCharacter()
		if not ch or ent.matbaaLockChar ~= ch:GetID() then
			notify(client, "Solo quien encargó la impresión puede recoger la caja por ahora.")
			return false
		end
	end
end)