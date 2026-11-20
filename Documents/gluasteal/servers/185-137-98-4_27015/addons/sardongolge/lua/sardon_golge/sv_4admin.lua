-- Servidor :: Shine Admin Sombra + registros (cl_3sayfa)
if not SERVER then return end

local S = SardonGolge
if not S then return end

local DATA = S.DATA or "sardon_golge"

sql.Query([[CREATE TABLE IF NOT EXISTS sardon_golge_kayit (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	tur TEXT,
	kim TEXT,
	kimSid TEXT,
	hedef TEXT,
	hedefSid TEXT,
	ayrinti TEXT,
	zaman INTEGER
)]])

local KAYIT_CACHE

function S.KayitEkle(tur, kimPly, hedefPly, ayrinti)
	tur = tostring(tur or "?")
	ayrinti = tostring(ayrinti or "")
	local kim, kimSid, hedef, hedefSid = "", "", "", ""
	if IsValid(kimPly) then
		kim = kimPly:Nick()
		kimSid = kimPly:SteamID64()
	elseif isstring(kimPly) then kimSid = kimPly end
	if IsValid(hedefPly) then
		hedef = hedefPly:Nick()
		hedefSid = hedefPly:SteamID64()
	elseif isstring(hedefPly) then hedef = hedefPly end
	sql.Query(string.format(
		"INSERT INTO sardon_golge_kayit (tur,kim,kimSid,hedef,hedefSid,ayrinti,zaman) VALUES (%s,%s,%s,%s,%s,%s,%d)",
		sql.SQLStr(tur), sql.SQLStr(kim), sql.SQLStr(kimSid), sql.SQLStr(hedef), sql.SQLStr(hedefSid), sql.SQLStr(ayrinti), os.time()
	))
	KAYIT_CACHE = nil
end

function S.KayitListe()
	if KAYIT_CACHE then return KAYIT_CACHE end
	local rows = sql.Query("SELECT * FROM sardon_golge_kayit ORDER BY id DESC LIMIT 200") or {}
	KAYIT_CACHE = {}
	for _, r in ipairs(rows) do
		KAYIT_CACHE[#KAYIT_CACHE + 1] = {
			id = tonumber(r.id) or 0,
			tur = r.tur,
			kim = r.kim,
			kimSid = r.kimSid,
			hedef = r.hedef,
			hedefSid = r.hedefSid,
			ayrinti = r.ayrinti,
			zaman = tonumber(r.zaman) or 0,
		}
	end
	return KAYIT_CACHE
end

function S.AdminGorebilir(ply)
	if not IsValid(ply) then return false end
	if ShineAdmin and ShineAdmin.Can and ShineAdmin.Can(ply, "staff") then return true end
	return ply:IsAdmin()
end

function S.AdminYazabilir(ply)
	return IsValid(ply) and ply:IsSuperAdmin()
end

local function AdminPaket(ply)
	S.Mallar = S.Mallar or (S.MallarYukle and S.MallarYukle()) or {}
	S.Noktalar = S.Noktalar or (S.NoktalarYukle and S.NoktalarYukle()) or {}
	local golge = S.Golge or {}
	local noktalar = {}
	for i, n in ipairs(S.Noktalar) do
		local p = n.pos or {}
		local pos = Vector(p.x or 0, p.y or 0, p.z or 0)
		noktalar[#noktalar + 1] = {
			no = i,
			pos = string.format("%.0f, %.0f, %.0f", pos.x, pos.y, pos.z),
			ipucu = n.ipucu or "",
			alan = n.alan or "",
			uz = IsValid(ply) and math.floor(ply:GetPos():Distance(pos)) or 0,
			yaw = n.yaw or n.uz,
		}
	end
	local mallar = {}
	for _, m in ipairs(S.Mallar) do
		mallar[#mallar + 1] = table.Merge(table.Copy(m), {
			gecerli = ix.item.list[m.esya] ~= nil,
		})
	end
	return {
		ayar = table.Copy(S.Ayar),
		varsayilan = S.AYAR_VARSAYILAN or table.Copy(S.Ayar),
		sema = S.AYAR_SEMA or {},
		yaz = S.AdminYazabilir(ply),
		hafta = S.Hafta(),
		digerFiyat = S.DigerFiyat(S.Hafta()),
		noktalar = noktalar,
		mallar = mallar,
		aktorVar = golge.no ~= nil,
		aktorAlan = golge.muhatap ~= "" and ("Hablando con " .. golge.muhatap) or "",
		simdiki = golge.simdiki or 0,
		siradaki = golge.siradaki or 0,
		gezintiKalan = math.max(0, (golge.gezintiBit or 0) - CurTime()),
		muhatap = golge.muhatap or "",
	}
end

local function Gonder(ply)
	net.Start(S.AyarNet or "SardonGolge.Ayar")
	net.WriteString(util.TableToJSON({
		admin = AdminPaket(ply),
		istemci = table.Copy(S.Ayar),
	}) or "{}")
	net.Send(ply)
end

net.Receive(S.AyarNet or "SardonGolge.Ayar", function(_, ply)
	if not S.AdminGorebilir(ply) then return end
	if (ply._GolgeAdminCd or 0) > CurTime() then return end
	ply._GolgeAdminCd = CurTime() + 0.12
	local t = util.JSONToTable(net.ReadString() or "") or {}
	local islem = t.islem or "iste"

	if islem == "iste" then
		Gonder(ply)
		return
	end

	if not S.AdminYazabilir(ply) then return end

	if islem == "yaz" and istable(t.ayar) then
		for _, a in ipairs(S.AYAR_SEMA or {}) do
			if t.ayar[a.k] ~= nil then S.Ayar[a.k] = t.ayar[a.k] end
		end
		if S.AyarKaydet then S.AyarKaydet() end
		S.KayitEkle("ayar", ply, nil, "Guardado")
		Gonder(ply)
		return
	end

	if islem == "sifirla" then
		S.Ayar = table.Copy(S.AYAR_VARSAYILAN or S.Ayar)
		if S.AyarKaydet then S.AyarKaydet() end
		S.KayitEkle("ayar", ply, nil, "Valores por defecto")
		Gonder(ply)
		return
	end

	if islem == "nokta_ekle" then
		S.Noktalar = S.NoktalarYukle()
		S._Noktalar = S.Noktalar
		local tr = util.TraceLine({ start = ply:EyePos(), endpos = ply:EyePos() + ply:EyeAngles():Forward() * 4096, filter = ply })
		S.Noktalar[#S.Noktalar + 1] = {
			pos = { x = tr.HitPos.x, y = tr.HitPos.y, z = tr.HitPos.z },
			yaw = ply:EyeAngles().y,
			ipucu = tostring(t.ipucu or ""),
			alan = game.GetMap(),
		}
		S.NoktalarKaydet()
		S.KayitEkle("nokta", ply, nil, "Punto " .. #S.Noktalar)
		Gonder(ply)
		return
	end

	if islem == "nokta_git" then
		local no = tonumber(t.no)
		local n = S.NoktalarYukle()[no]
		if n and n.pos then
			ply:SetPos(Vector(n.pos.x, n.pos.y, n.pos.z) + Vector(0, 0, 8))
			ply:SetEyeAngles(Angle(0, n.yaw or n.uz or 0, 0))
		end
		return
	end

	if islem == "nokta_ipucu" then
		local no = tonumber(t.no)
		S.Noktalar = S.NoktalarYukle()
		if S.Noktalar[no] then
			S.Noktalar[no].ipucu = tostring(t.ipucu or "")
			S._Noktalar = S.Noktalar
			S.NoktalarKaydet()
		end
		Gonder(ply)
		return
	end

	if islem == "nokta_sil" then
		local no = tonumber(t.no)
		S.Noktalar = S.NoktalarYukle()
		if S.Noktalar[no] then
			table.remove(S.Noktalar, no)
			S._Noktalar = S.Noktalar
			S.NoktalarKaydet()
		end
		Gonder(ply)
		return
	end

	if islem == "simdi" then
		if S.GolgeTeleport then S.GolgeTeleport(false) end
		Gonder(ply)
		return
	end

	if islem == "mal_kaydet" and istable(t.mal) then
		S.Mallar = S.MallarYukle()
		local m = t.mal
		if not m.id or m.id == 0 then
			local maxId = 0
			for _, x in ipairs(S.Mallar) do maxId = math.max(maxId, tonumber(x.id) or 0) end
			m.id = maxId + 1
			S.Mallar[#S.Mallar + 1] = m
		else
			for i, x in ipairs(S.Mallar) do
				if x.id == m.id then S.Mallar[i] = m break end
			end
		end
		S.MallarKaydet()
		S.KayitEkle("mal_ayar", ply, nil, m.ad or m.esya)
		Gonder(ply)
		return
	end

	if islem == "mal_sil" then
		local id = tonumber(t.id)
		S.Mallar = S.MallarYukle()
		for i, m in ipairs(S.Mallar) do
			if m.id == id then table.remove(S.Mallar, i) break end
		end
		S.MallarKaydet()
		Gonder(ply)
		return
	end
end)

hook.Add("PlayerInitialSpawn", "SardonGolge.AyarSync", function(ply)
	timer.Simple(6, function()
		if not IsValid(ply) then return end
		net.Start(S.AyarNet or "SardonGolge.Ayar")
		net.WriteString(util.TableToJSON({ istemci = table.Copy(S.Ayar) }) or "{}")
		net.Send(ply)
	end)
end)

MsgN("[SardonGolge] sv_4admin cargado.")