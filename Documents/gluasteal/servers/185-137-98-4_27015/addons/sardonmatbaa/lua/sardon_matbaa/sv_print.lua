if not SERVER then return end

local M, cfg = SardonMatbaa, SardonMatbaa.Config

local function notify(ply, msg)
	if IsValid(ply) and ply.Notify then ply:Notify(msg) end
end

function M.AbsorbItem(machine, ent)
	if not IsValid(machine) or not IsValid(ent) or ent:GetClass() ~= "ix_item" then return end

	local itemTable = ent:GetItemTable()
	if not itemTable then return end

	local uid = itemTable.uniqueID
	if uid ~= M.INK and uid ~= M.PAPER then return end

	if ent.ixItemID then
		local instance = ix.item.instances[ent.ixItemID]
		if instance and instance.Remove then
			instance:Remove()
		end
	end

	SafeRemoveEntity(ent)

	local st = M.GetStock(machine)
	if uid == M.INK then
		st.ink = math.min(st.ink + 1, 65535)
	else
		st.paper = math.min(st.paper + 1, 65535)
	end

	for _, ply in player.Iterator() do
		if IsValid(ply) and ply:GetPos():DistToSqr(machine:GetPos()) <= 220 * 220 then
			M.SyncStock(ply, machine)
		end
	end
end

function M.CancelJob(machine)
	if not IsValid(machine) or not machine.matbaaJob then return end

	local job = machine.matbaaJob
	machine.matbaaJob = nil
	machine:SetJobStart(0)
	machine:SetJobEnd(0)
	machine:SetJobOwner("")
	machine:SetJobFormat("")
	machine:SetJobCopies(0)

	local st = M.GetStock(machine)
	st.ink = math.min(st.ink + (job.ink or 0), 65535)
	st.paper = math.min(st.paper + (job.paper or 0), 65535)
end

function M.FinishJob(machine)
	if not IsValid(machine) or not machine.matbaaJob then return end

	local job = machine.matbaaJob
	machine.matbaaJob = nil
	machine:SetJobStart(0)
	machine:SetJobEnd(0)
	machine:SetJobOwner("")
	machine:SetJobFormat("")
	machine:SetJobCopies(0)

	local format = M.GetFormat(job.formatId)
	if not format then return end

	local ownerPly = job.owner
	local label = string.format("%dx %s", job.copies, format.ad)
	local charName = job.ownerName or ""
	local pos = machine:LocalToWorld(cfg.KutuOfset)
	local ang = machine:GetAngles()

	ix.item.Spawn(M.BOX, pos, function(item, entity)
		if not item then return end

		item:SetData("etiket", label)
		item:SetData("sahipAd", charName)

		local tries = 0
		local function fillBag()
			local bagInv = item:GetInventory()
			if bagInv then
				bagInv.vars.isBag = M.BOX
				for _ = 1, job.copies do
					if not bagInv:Add(format.item, 1, {
						url = job.url,
						basan = charName,
						tarih = os.time(),
					}) then break end
				end
				return
			end

			tries = tries + 1
			if tries < 40 then
				timer.Simple(0.05, fillBag)
			end
		end

		fillBag()

		if IsValid(entity) then
			entity:SetAngles(Angle(0, ang.y, 0))

			if IsValid(ownerPly) and cfg.KutuSahipKilidi > 0 then
				entity.matbaaLockUntil = CurTime() + cfg.KutuSahipKilidi
				entity.matbaaLockChar = job.ownerChar
			end

			local phys = entity:GetPhysicsObject()
			if IsValid(phys) then phys:Wake() end
		end

		if IsValid(ownerPly) then
			notify(ownerPly, "Tu caja de imprenta está lista junto a la máquina.")
		end
	end, ang)
end

local function startJob(machine, ply, format, url, copies)
	local ch = ply:GetCharacter()
	local needInk, needPaper = M.GetCost(format)
	local totalInk = needInk * copies
	local totalPaper = needPaper * copies
	local st = M.GetStock(machine)

	if st.ink < totalInk or st.paper < totalPaper then
		notify(ply, "No hay suficiente tinta o papel en la máquina.")
		return
	end

	st.ink = st.ink - totalInk
	st.paper = st.paper - totalPaper

	local duration = M.GetDuration(copies)
	local now = CurTime()

	machine.matbaaJob = {
		owner = ply,
		ownerChar = ch:GetID(),
		ownerName = ch:GetName(),
		formatId = format.id,
		url = url,
		copies = copies,
		ink = totalInk,
		paper = totalPaper,
	}

	machine:SetJobStart(now)
	machine:SetJobEnd(now + duration)
	machine:SetJobOwner(ch:GetName())
	machine:SetJobFormat(format.ad)
	machine:SetJobCopies(copies)

	M.SyncStock(ply, machine)
	notify(ply, "Impresión iniciada: " .. copies .. " × " .. format.ad .. ".")
end

net.Receive("SardonMatbaa.Print", function(_, ply)
	local machine = net.ReadEntity()
	local formatId = net.ReadString()
	local url = net.ReadString()
	local copies = net.ReadUInt(8)

	if not IsValid(ply) or not IsValid(machine) or machine:GetClass() ~= "ent_matbaa" then return end
	if not ply:GetCharacter() then return end
	if ply:GetPos():DistToSqr(machine:GetPos()) > 220 * 220 then return end
	if machine:IsBusy() then
		notify(ply, "La máquina está ocupada.")
		return
	end

	local format = M.GetFormat(formatId)
	if not format then
		notify(ply, "Formato de impresión no válido.")
		return
	end

	copies = math.Clamp(math.floor(copies), 1, cfg.MaksAdet)

	local cleaned, err = M.ValidateURL(url)
	if not cleaned then
		notify(ply, err or "URL no válida.")
		return
	end
	url = cleaned

	local st = M.GetStock(machine)
	local maxCopies = M.GetMaxCopies(format, st.ink, st.paper)
	if copies > maxCopies then
		notify(ply, "No hay materiales para esa cantidad.")
		return
	end

	startJob(machine, ply, format, url, copies)
end)