if not SERVER then return end

local M, cfg = SardonMatbaa, SardonMatbaa.Config

local function notify(ply, msg)
	if IsValid(ply) and ply.Notify then ply:Notify(msg) end
end

local function posterFile()
	return "sardon_matbaa/" .. game.GetMap() .. "_posterler.json"
end

function M.SavePosters()
	file.CreateDir("sardon_matbaa")

	local data = {}
	for _, ent in ipairs(ents.FindByClass("ent_matbaa_poster")) do
		if not IsValid(ent) or ent:GetURL() == "" then continue end

		data[#data + 1] = {
			pos = ent:GetPos(),
			ang = ent:GetAngles(),
			url = ent:GetURL(),
			format = ent:GetFormat(),
			printer = ent:GetPrinter(),
			owner = ent:GetOwnerChar(),
		}
	end

	file.Write(posterFile(), util.TableToJSON(data, true))
end

local function countPosters(charId)
	local n = 0
	for _, ent in ipairs(ents.FindByClass("ent_matbaa_poster")) do
		if IsValid(ent) and ent:GetOwnerChar() == charId then
			n = n + 1
		end
	end
	return n
end

function M.HangPoster(ply, item)
	if not IsValid(ply) or not ply:GetCharacter() or not item then return end

	local format = item.GetFormat and item:GetFormat()
	if not format or not format.asilabilir then
		notify(ply, "Este formato no se puede colgar.")
		return
	end

	local url = item:GetData("url")
	if not url or url == "" then return end

	local cleaned, err = M.ValidateURL(url)
	if not cleaned then
		notify(ply, err or "URL no válida.")
		return
	end

	local ch = ply:GetCharacter()
	if countPosters(ch:GetID()) >= cfg.PosterLimiti then
		notify(ply, "Ya tienes el máximo de pósters colgados (" .. cfg.PosterLimiti .. ").")
		return
	end

	local tr = util.TraceLine({
		start = ply:EyePos(),
		endpos = ply:EyePos() + ply:GetAimVector() * 110,
		filter = ply,
		mask = MASK_SOLID,
	})

	if not tr.Hit or tr.HitSky then
		notify(ply, "Debes mirar a una pared sólida.")
		return
	end

	if tr.HitNormal:Dot(ply:GetAimVector()) > -0.2 then
		notify(ply, "Acércate más a la pared.")
		return
	end

	local ang = tr.HitNormal:Angle()
	ang:RotateAroundAxis(ang:Right(), 90)
	ang:RotateAroundAxis(ang:Up(), 90)

	local ent = ents.Create("ent_matbaa_poster")
	if not IsValid(ent) then return end

	ent:SetPos(tr.HitPos + tr.HitNormal * 0.35)
	ent:SetAngles(ang)
	ent:SetURL(cleaned)
	ent:SetFormat(item.matbaaFormat)
	ent:SetPrinter(item:GetData("basan", ""))
	ent:SetOwnerChar(ch:GetID())
	ent:Spawn()

	item:Remove()
	ch:GetInventory():Sync(ply)
	M.SavePosters()
	notify(ply, "Póster colgado.")
end

local function restorePosters()
	local path = posterFile()
	if not file.Exists(path, "DATA") then return end

	local data = util.JSONToTable(file.Read(path, "DATA") or "") or {}

	for _, row in ipairs(data) do
		if not istable(row) or not isvector(row.pos) then continue end

		local ent = ents.Create("ent_matbaa_poster")
		if not IsValid(ent) then continue end

		ent:SetPos(row.pos)
		ent:SetAngles(row.ang or angle_zero)
		ent:SetURL(row.url or "")
		ent:SetFormat(row.format or "poster")
		ent:SetPrinter(row.printer or "")
		ent:SetOwnerChar(tonumber(row.owner) or 0)
		ent:Spawn()
	end
end

hook.Add("InitPostEntity", "SardonMatbaa.Posters", restorePosters)
hook.Add("PostCleanupMap", "SardonMatbaa.Posters", restorePosters)

hook.Add("EntityRemoved", "SardonMatbaa.PosterSave", function(ent)
	if IsValid(ent) and ent:GetClass() == "ent_matbaa_poster" then
		timer.Simple(0, M.SavePosters)
	end
end)