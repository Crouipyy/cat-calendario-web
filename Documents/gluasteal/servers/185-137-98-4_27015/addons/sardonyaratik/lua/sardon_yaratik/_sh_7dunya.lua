-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\_sh_7dunya.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: kişisel vivaryum — ortak (2026-11-10)
--
-- SYB › Vivaryum Anahtarı'nı açan karakterin kendi vivaryumu olur: bugünkü vivaryum bahçesi (Y.Alan kutusu)
-- her sahip için ayrı bir sanal dünya. [sardon] sims iç mekân altyapısı kullanılır (NW2Int "SimsInst";
-- gönderim, çarpışma, hasar, Use, sohbet ve Gspeak süzgeçleri orada). Dünyanın numarası A.Viv.Taban'dan
-- sonra sahip başına verilir, dünya boşalınca geri alınır. Oyuncunun bulunduğu dünya NW2Int "SYDunya" =
-- dünyanın sahibinin karakter numarası (0: hiçbirinde değil).
--
-- Giriş Yakalama Çantası'yla (gladstone el bavulu): açılır, yere bırakılır, kişi içine çekilir; çanta
-- dışarıda kapalı bekler. Çıkış bahçedeki sabit çıkış noktasından (Y.Alan.cikis, yetkili koyar), kişi
-- çantadan çıkar. Ayrıntılar sv_9vivaryum.lua / cl_9vivaryum.lua.
--
-- Bahçedeki ev bir statik prop (models/models/wandersspecialhouses/ev_1.mdl, haritada 13 kez; Lua ile
-- silinemez): göz bahçedeyken istemcide malzemeleri çizilmez (cl_9vivaryum), çarpışması kaldığı için ayak
-- izinin çevresine doğal engel konur (Y.EvOrtu), kapısı ve pencereleri (harita varlıkları) silinir.

local Y = SardonYaratik
local A = Y.Ayar

Y.NET.VIV = "SardonYaratik.Viv"           -- iki yönlü: giriş/çıkış olayları, ziyaret isteği, yerleştirme

function Y.VivaryumAcik(char)
     return char and Y.Beceri(char, "vivaryum") > 0 or false
end

-- oyuncunun bulunduğu vivaryum dünyasının sahibi (karakter numarası; 0: hiçbiri)
function Y.Dunyasi(ply)
     return IsValid(ply) and ply:GetNW2Int("SYDunya", 0) or 0
end

function Y.KendiDunyasinda(ply)
     local char = IsValid(ply) and ply:GetCharacter()
     return char and Y.Dunyasi(ply) == char:GetID() or false
end

------------------------------------------------------------------------ bahçedeki ev

-- ayak izi (çarpışması kalan statik prop; ev_1 hull'u, yaw 90, (-265, -8988, 4594)): yaratık yolları ve
-- yerleştirme buradan kaçınır
Y.EvIzi = {min = Vector(-705, -9290, 4380), max = Vector(36, -8724, 5200)}

function Y.EvIzinde(p, pay)
     pay = pay or 0
     local a, b = Y.EvIzi.min, Y.EvIzi.max
     return p.x >= a.x - pay and p.x <= b.x + pay and p.y >= a.y - pay and p.y <= b.y + pay and p.z >= a.z and p.z <= b.z
end

-- göz bahçedeyken çizilmeyen malzemeler: evin 26 malzemesi + üstündeki 3 pencere çıkartmasınınkiler.
-- Aynı modeller Hogsmeade'de ve Hogwarts'ta da var: yalnız göz bahçe kutusundayken gizlenir.
Y.EvMalzeme = {}
for _, ad in ipairs({"wood_1", "wood_2", "wood_3", "wood_4", "floor_1", "wood_5", "roof_1", "wall_1", "iron_1",
     "wall_2", "boder_1", "tent_1", "plaster_1", "wood_6", "glass_1", "arch_1", "wood_7", "iron_02", "trim_1",
     "wall_4", "wall_5", "wall_6", "wood_8", "wood_9", "floor_2", "wood_10"}) do
     Y.EvMalzeme[#Y.EvMalzeme + 1] = "models/wandersspecialhouses/" .. ad
end
Y.EvMalzeme[#Y.EvMalzeme + 1] = "models/4aukahogwarts/decals_citi_window1/constructwood001"
Y.EvMalzeme[#Y.EvMalzeme + 1] = "models/4aukahogwarts/decals_citi_window1/glasswindow002a_2"

-- silinen harita varlıkları (evin kapısı ve pencereleri): model + konum (8 birim içinde)
Y.EvSil = {
     {m = "models/mark2580/gtav/mp_apa_06/lobby/apa_p_mp_door_mpa.mdl", p = Vector(-117.05, -9168.73, 4630)},
     {m = "models/forci_props/poudlard/sm_hm_potions_ext_window_01.mdl", p = Vector(-284.68, -9126.59, 4647.62)},
     {m = "models/forci_props/poudlard/sm_hm_potions_ext_window_01.mdl", p = Vector(-365.47, -9126.59, 4647.62)},
}

-- evin yerine doğal engel (sunucuda katı prop_dynamic, bütün dünyalarda ortak): görünmez duvara çarpılmasın.
-- Modeller haritanın kendi bahçesinde kullanılanlar (istemcide zaten var).
local KAYA = "models/forci_props/poudlard/sm_ol_rock_md_a_big.mdl"
local KAYA_O = "models/forci_props/poudlard/sm_ol_rock_md_a_medium.mdl"
local LADIN = "models/forci_props/poudlard/sm_sprucetree_smalla_master.mdl"
local DISBUDAK = "models/forci_props/poudlard/sm_ashtree_medb_master_1_medium.mdl"
Y.EvOrtu = {
     -- ön sıra (evin güney yüzü y ≈ -9290; kayalar biraz önüne taşar)
     {m = KAYA_O, p = Vector(-585, -9250, 4520), yaw = 25, olcek = 1.0},
     {m = KAYA_O, p = Vector(-335, -9262, 4515), yaw = 160, olcek = 1.05},
     {m = KAYA_O, p = Vector(-90, -9250, 4520), yaw = 280, olcek = 1.0},
     -- batı ve doğu yüzleri
     {m = KAYA_O, p = Vector(-655, -9010, 4520), yaw = 95, olcek = 0.95},
     {m = KAYA_O, p = Vector(-660, -8820, 4515), yaw = 230, olcek = 0.85},
     {m = KAYA_O, p = Vector(10, -8860, 4515), yaw = 60, olcek = 0.75},
     {m = KAYA_O, p = Vector(45, -9045, 4505), yaw = 310, olcek = 0.5},
     -- ortada büyük kaya ve ağaçlar (çatının yerine)
     {m = KAYA, p = Vector(-350, -8935, 4500), yaw = 70, olcek = 1.0},
     {m = LADIN, p = Vector(-520, -8950, 4492), yaw = 10},
     {m = DISBUDAK, p = Vector(-180, -8880, 4492), yaw = 120},
     {m = LADIN, p = Vector(-360, -9110, 4492), yaw = 250, olcek = 0.8},
}

------------------------------------------------------------------------ sahibin yemlik/yuva yerleştirmesi

-- iki tarafta aynı denetim (istemci önizlemesi kırmızı/yeşil, sunucu Y.VivYerKoy). yer: sahibin yerleri
-- (Y.DunyaYerleri / istemcide Y.Alan)
function Y.VivYerUygun(cesit, p, yaw, yer)
     if not Y.AlanVar() or not isvector(p) or not Y.AlanIcinde(p) then return false, "Vivaryumun dışında." end
     local a, b = Y.Alan.min, Y.Alan.max
     if p.x < a.x + 60 or p.x > b.x - 60 or p.y < a.y + 60 or p.y > b.y - 60 then return false, "Duvara çok yakın." end
     if Y.EvIzinde(p, 70) then return false, "Burası kayalık; başka bir yer seç." end
     local cikis = Y.Alan.cikis
     if istable(cikis) and isvector(cikis[1]) and (cikis[1] - p):Length2D() < 170 then return false, "Çıkışa çok yakın." end
     for i in ipairs(Y.Alan.agil or {}) do
          if Y.AgilIcinde(i, p, -90) then return false, "Ağılın içine ya da dibine konmaz." end
     end
     local diger = cesit == "yemlik" and "yuva" or "yemlik"
     local q = yer and yer[diger] and yer[diger][1]
     if isvector(q) and (q - p):Length2D() < 130 then
          return false, (cesit == "yemlik" and "Kuluçka yuvasına" or "Yemliğe") .. " çok yakın."
     end
     return true
end
