-- Servidor :: catálogos de comerciantes y plantillas de panel
if not SERVER then return end

local E = SardonEkonomi
if not E then return end

E.TezgahSinir = 5
E.TezgahGun = 3 * 86400
E.MasaOran = 0.03
E.MasaHarc = 3
E.SozlesmeSiniri = 3
E.PanoGunlukIs = 3
E.PanoHaftalikIs = 1

local function ItemVar(id)
	if not id or id == "" then return false end
	return ix and ix.item and ix.item.list and ix.item.list[id] ~= nil
end

local function ItemAd(id)
	local it = ix and ix.item and ix.item.list and ix.item.list[id]
	return it and (it.name or id) or id
end

E.EsyaAd = ItemAd

function E.EsyaMalID(item)
	if not item then return nil end
	local uid = item.uniqueID
	if uid == "ingredient" then
		return "ingredient:" .. tostring(item:GetData("type", "?"))
	end
	return uid
end

function E.EsyaAdet(item)
	if not item then return 0 end
	if item.uniqueID == "ingredient" then
		return math.max(1, math.floor(item:GetData("count", 1) or 1))
	end
	return math.max(1, math.floor(item:GetData("count", 1) or 1))
end

local function MalListe(tabl)
	local c = {}
	for _, m in ipairs(tabl or {}) do
		if ItemVar(m.id) or string.StartWith(m.id, "ingredient:") then
			c[#c + 1] = m
		end
	end
	return c
end

local SB_SIRA = {"sb_adamotu", "sb_lahana", "sb_tentakula", "sb_mandrake", "sb_nane", "sb_sisymbrium"}
local BALIK = {"Hamsi", "Sardalya", "Pterophyllum", "Kömür Balığı", "Arapayma"}
local HAYVAN = {"hayvan_post", "hayvan_tuyu", "hayvan_kemik", "hayvan_dis", "hayvan_pence", "hayvan_kus_tuyu", "hayvan_yilan_derisi", "hayvan_kurbaga_salgi"}
local IKSIR_ING = {"ingredient:belladonna", "ingredient:nettle", "ingredient:dittany", "ingredient:ginger", "ingredient:lavender", "ingredient:fluxweed"}
local KARABORSA = {"owl_scroll", "Kurt_adam_calisi", "dusunseli_sise", "zonko_bombtastic_bombs", "hayvan_akrep_zehri", "hayvan_ejderha_kani"}
local AVCU_ALIM = {"hayvan_post", "hayvan_kemik", "hayvan_dis", "hayvan_pence", "hayvan_grifon_tuyu", "hayvan_wyvern_pulu"}
local AVCU_SATILIK = {
	{id = "Esca_Piscibus_Kitabı", fiyat = 45, aciklama = "Manual de pesca mágica"},
	{id = "yaratik_firca", fiyat = 12, aciklama = "Cepillo para criaturas"},
	{id = "obs_tilsim", fiyat = 28, aciklama = "Amuleto de observación"},
}

local function Kademe(id)
	if string.find(id, "ejderha") or string.find(id, "anka") or id == "Arapayma" then return 3 end
	if string.find(id, "grifon") or string.find(id, "wyvern") or id == "Pterophyllum" then return 2 end
	return 1
end

local function MalSatir(id, baz, n, kademe)
	kademe = kademe or Kademe(id)
	return {id = id, ad = ItemAd(id), baz = baz or 4, n = n or 3, kademe = kademe}
end

E.Tuccar = E.Tuccar or {}
E.Tuccar.Turler = {
	botanik = {
		ad = "Botánico",
		unvan = "Compra plantas y semillas",
		model = "models/player/group01/male_02.mdl",
		satirlar = MalListe({
			MalSatir("sb_adamotu", 3, 3, 1), MalSatir("sb_lahana", 4, 3, 1), MalSatir("sb_tentakula", 6, 2, 2),
			MalSatir("sb_mandrake", 8, 2, 2), MalSatir("sb_nane", 3, 4, 1), MalSatir("sb_sisymbrium", 5, 3, 1),
		}),
	},
	yaratik = {
		ad = "Criaturas",
		unvan = "Plumas, pelo y productos",
		model = "models/player/group01/female_02.mdl",
		satirlar = MalListe({
			MalSatir("hayvan_kus_tuyu", 2, 5, 1), MalSatir("hayvan_post", 3, 4, 1), MalSatir("hayvan_kurbaga_salgi", 4, 3, 1),
			MalSatir("hayvan_yilan_derisi", 5, 3, 2), MalSatir("yaratik_cuval", 7, 2, 2), MalSatir("yaratik_yumurta", 12, 1, 3),
		}),
	},
	iksir = {
		ad = "Pociones",
		unvan = "Ingredientes y pociones",
		model = "models/player/group01/male_04.mdl",
		satirlar = MalListe({
			MalSatir("ingredient:belladonna", 3, 4, 1), MalSatir("ingredient:nettle", 3, 4, 1),
			MalSatir("ingredient:dittany", 5, 3, 2), MalSatir("ingredient:lavender", 4, 3, 1),
			MalSatir("sardon_pocion", 10, 2, 2),
		}),
	},
	balik = {
		ad = "Pescadero",
		unvan = "Pescado fresco",
		model = "models/player/group01/male_06.mdl",
		satirlar = MalListe({
			MalSatir("Hamsi", 2, 6, 1), MalSatir("Sardalya", 3, 5, 1), MalSatir("Pterophyllum", 6, 3, 2),
			MalSatir("Kömür Balığı", 5, 3, 2), MalSatir("Arapayma", 14, 1, 3),
		}),
	},
	karaborsa = {
		ad = "Mercado negro",
		unvan = "Sin preguntas, precios bajos",
		model = "models/player/group01/male_08.mdl",
		satirlar = MalListe({
			MalSatir("owl_scroll", 4, 3, 2), MalSatir("Kurt_adam_calisi", 6, 2, 2),
			MalSatir("hayvan_akrep_zehri", 7, 2, 2), MalSatir("hayvan_ejderha_kani", 12, 1, 3),
			MalSatir("zonko_bombtastic_bombs", 8, 2, 2),
		}),
	},
	avci = {
		ad = "Cazador",
		unvan = "Piezas de caza",
		model = "models/player/group01/male_09.mdl",
		satirlar = MalListe({
			MalSatir("hayvan_post", 3, 4, 1), MalSatir("hayvan_kemik", 2, 5, 1), MalSatir("hayvan_dis", 3, 4, 1),
			MalSatir("hayvan_pence", 4, 3, 1), MalSatir("hayvan_grifon_tuyu", 9, 2, 3), MalSatir("hayvan_wyvern_pulu", 11, 2, 3),
		}),
		satilik = MalListe(AVCU_SATILIK),
	},
}

-- IDs base por tipo (fallback si catálogo vacío)
E._KatalogYedek = {
	botanik = SB_SIRA, yaratik = HAYVAN, balik = BALIK, iksir = IKSIR_ING, karaborsa = KARABORSA, avci = AVCU_ALIM,
}

E.PanoSablon = {}
for _, tur in ipairs({"botanik", "yaratik", "iksir", "balik", "karaborsa", "avci"}) do
	local tt = E.Tuccar.Turler[tur]
	if tt and tt.satirlar and #tt.satirlar > 0 then
		E.PanoSablon[tur] = tt.satirlar
	end
end

function E.PanoIsSablonlari()
	local havuz = {}
	for _, liste in pairs(E.PanoSablon) do
		for _, m in ipairs(liste) do havuz[#havuz + 1] = m end
	end
	if #havuz == 0 then
		for _, id in ipairs(SB_SIRA) do havuz[#havuz + 1] = MalSatir(id, 4, 2, 1) end
	end
	return havuz
end

function E.TalepYukle()
	E._Talep = E._Talep or E.OkuJSON(E.DATA .. "/talep.json", {}) or {}
	return E._Talep
end

function E.TalepKaydet()
	E.YazJSON(E.DATA .. "/talep.json", E.TalepYukle())
end

function E.TalepOran(malId)
	local t = E.TalepYukle()
	local r = t[malId]
	if not r then
		r = {oran = math.random(55, 95), adet = 0}
		t[malId] = r
	end
	return math.Clamp(math.floor(r.oran or 70), 40, 100)
end

function E.TalepFiyat(mal, oran)
	oran = oran or E.TalepOran(mal.id)
	local taban = math.floor((mal.baz or 3) * 0.4)
	local tam = mal.baz or 3
	return math.max(taban, math.floor(taban + (tam - taban) * oran / 100))
end

hook.Add("InitPostEntity", "SardonEkonomi.Katalog", function()
	E.TalepYukle()
	timer.Simple(2, function()
		for malId, r in pairs(E.TalepYukle()) do
			if not ItemVar(malId) and not string.StartWith(malId, "ingredient:") then
				-- mantener demanda aunque falte el ítem
			end
		end
	end)
end)