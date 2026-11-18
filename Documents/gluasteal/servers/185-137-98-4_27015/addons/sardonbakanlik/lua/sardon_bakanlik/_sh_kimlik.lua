-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\_sh_kimlik.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Ministerio :: Documento de identidad de mago. Ortak ayarlar, uygunluk ve Helix eşyası.
--
-- Kart fiziksel bir Helix eşyasıdır (bakanlik_kimlik): yere atılır, verilir, çalınır. Eşya verisi
-- yalnız kartın yüzünü taşır; geçerliliğin tek kaynağı sunucudaki sb_kimlik kaydıdır (sv_kimlik.lua).
-- Sahte kart da aynı eşyadır: yüzü gerçeğinden ayırt edilmez, numarası da aynı sayaçtan gelir;
-- yalnızca Consulta del Ministerio onu registrosta "sahte" bulur.
--
-- Eşya verisi: {no, ad, hane (0-4), yil, kan, meslek, gorevli (daire adı ya da ""), verilis, v}
--   bos = true    Gölge'nin sattığı, henüz doldurulmamış sahte belge
--
-- Dosya adı "_" ile başlıyor: SardonUtil cl_/sv_ dosyalarından atrás yükler.

local B = SardonBakanlik
B.Kimlik = B.Kimlik or {}
local K = B.Kimlik

K.ESYA = "bakanlik_kimlik"

K.Ayar = {
     Ucret = 2,               -- G; kayıp/çalıntı sonrası yeni kimlik (Hazine'ye). İlk kimlik bedava.
     GosterMesafe = 150,      -- "baktığın personaye" göster
     YakinMesafe = 250,       -- "yakındakilere" göster
     IsteMesafe = 300,        -- "Kimlik İste"
     BakMesafe = 160,         -- kelepçeli personanin kimliğine bakma
     GosterSure = 8,          -- s; kart elde ve ekranda
     GosterBekleme = 4,       -- s; iki gösterim arası
     IsteSure = 20,           -- s; yanıt verilmezse "yanıt vermedi"
     IsteBekleme = 30,        -- s; aynı agente aynı personaden
     GorduSure = 900,         -- s; gösterilen kart agentenin L menüsünde bu kadar geçerli (K17)
     KontrolNotAra = 600,     -- s; aynı kart + aynı agente için sicile como máximo bir kontrol notu
     SorguSure = 120,         -- s; gösterilen kart bu süre içinde sorgulanabilir
     FotoBekleme = 600,       -- s; fotoğraf yenileme arası
     ElMesafe = 700,          -- 3B kartı görecek oyuncular (gösterene uzaklık)
     NoOnek = "BB/NK-",
}

K.Kanlar = {
     {id = "safkan", ad = "Puro sangre"},
     {id = "melez", ad = "Mestizo"},
     {id = "muggle", ad = "Nacido de muggles"},
}
K.KanAd = {}
for _, k in ipairs(K.Kanlar) do K.KanAd[k.id] = k.ad end

-- CHAR:GetHouse() sırası (schema/meta/sh_character.lua HOGWARTS_HOUSE)
K.Casaler = {"Gryffindor", "Ravenclaw", "Slytherin", "Hufflepuff"}
K.CasaRenk = {Color(174, 52, 44), Color(52, 82, 150), Color(42, 112, 70), Color(214, 168, 56)}

K.DurumAd = {
     gecerli = "Válido", kayip = "Perdido / robo denunciado", iptal = "Anulado (yerine yenisi verildi)",
     sahte = "Número sin registro", vefat = "Titular fallecido", bekliyor = "Pendiente de entrega",
}

----------------------------------------------------------------------------------------
-- Uygunluk ve karakter bilgisi (iki tarafta)
----------------------------------------------------------------------------------------
-- Kimlik almayanlar: hayaletler, yaratıklar, yetkili görev rolü, ev cinleri
function K.Uygun(ply)
     local char = IsValid(ply) and ply.GetCharacter and ply:GetCharacter()
     if not char then return false end
     local f = char:GetFaction()
     if f == FACTION_HAYALET or f == FACTION_YARATIK or f == FACTION_GRINGOTTS then return false end
     if SardonCin and SardonCin.Model and SardonCin.Model(ply) then return false end
     return true
end

function K.Casa(char)
     return (char and char.GetHouse and char:GetHouse()) or 0
end

function K.Ogrenci(char) return K.Casa(char) > 0 end

function K.Yil(char)
     if not K.Ogrenci(char) then return 0 end
     if SK and SK.Yil then
          local ok, y = pcall(SK.Yil, char)
          if ok and tonumber(y) then return math.Clamp(math.floor(y), 1, 7) end
     end
     return 1
end

-- Kanonda büyücü 17'sinde reşit olur: Hogwarts'ın 7.º cursoı
function K.ResitDegil(hane, yil)
     return (tonumber(hane) or 0) > 0 and (tonumber(yil) or 0) > 0 and tonumber(yil) < 7
end

-- Kartın meslek satırı ve agente mührü (daire adı; boşsa mühür yok)
function K.Meslek(ply, char)
     char = char or (IsValid(ply) and ply:GetCharacter())
     if not char then return "Mago independiente", "" end
     if K.Ogrenci(char) then return "Estudiante de Hogwarts", "" end

     local b = IsValid(ply) and B.Bilgi(ply)
     if b and not b.denetci then
          return b.unvan or "Funcionario del Ministerio", B.DaireAd(b.daire) or ""
     end

     local f = char:GetFaction()
     local s = ix.class.list[char:GetClass() or 0]
     if f == FACTION_PROF then
          if s and string.find(s.name or "", "rof", 1, true) then
               return (string.gsub(s.name, "Profesor$", "Profesor")), ""
          end
          return "Profesor de Hogwarts", ""
     end
     if f == FACTION_HOGCALISAN then return "Empleado de Hogwarts", "" end
     if f == FACTION_BUYUBAKANLIGI then return "Empleado del Ministerio de Magia", "" end
     if f == FACTION_SEHERBAZ then return "Auror", "" end
     return "Mago independiente", ""
end

-- Kimin sorgusu: "bakanlik" (mesaideki, sicil yetkili), "snatcher", "profesor" ya da nil.
-- Presentarucu her istekte yeniden sorar; istemcide yalnız düğmeyi gösterir.
function K.SorguRol(ply)
     local char = IsValid(ply) and ply:GetCharacter()
     if not char then return nil end
     if SERVER then
          if B.Yapabilir(ply, "sicil") then return "bakanlik" end
     elseif B.Yetkili(ply, "sicil") and (B.Gorevde(ply) or (B.Bilgi(ply) or {}).denetci) then
          return "bakanlik"
     end
     local f = char:GetFaction()
     if f == FACTION_SNATCHER then return "snatcher" end
     if f == FACTION_PROF then return "profesor" end
     return nil
end

-- Bu rol bu personaden kimlik isteyebilir mi? (Profesor yalnız öğrenciden)
function K.IsteyebilirMi(rol, hedef)
     if not rol then return false end
     if rol == "profesor" then return K.Ogrenci(IsValid(hedef) and hedef:GetCharacter()) end
     return true
end

-- Karakterin en posesiónki kimlik eşyaları (çantalar dahil)
function K.Kartlar(char)
     local inv = char and char:GetInventory()
     if not inv then return {} end
     local liste = {}
     for _, it in pairs(inv:GetItems(false)) do
          if it.uniqueID == K.ESYA then liste[#liste + 1] = it end
     end
     table.sort(liste, function(a, b) return a.id < b.id end)
     return liste
end

----------------------------------------------------------------------------------------
-- Helix eşyası
----------------------------------------------------------------------------------------
local ITEM = ix.item.Register(K.ESYA, nil, false, nil, true)
ITEM.name = "Documento de identidad de mago"
ITEM.description = "Registro Mágico de Población del Ministerio de Magia'nin verdiği kimlik. Protean büyüsüyle Ministerio siciline bağlıdır."
ITEM.model = "models/props_c17/paper01.mdl"
ITEM.category = "Documentos"
ITEM.width = 1
ITEM.height = 1
ITEM.noBusiness = true

function ITEM:GetName()
     if self:GetData("bos") then return "Documento de identidad en blanco" end
     local ad = self:GetData("ad")
     return ad and ("Identidad · " .. ad) or self.name
end

function ITEM:GetDescription()
     if self:GetData("bos") then
          return "Sin sello, boş bir kimlik belgesi. Kâğıdı da mürekkebi de del Ministeriokine benziyor; üstüne yazılana herkes inanır… sorgulanmadıkça."
     end
     return self.description
end

function ITEM:PopulateTooltip(tooltip)
     if self:GetData("bos") then return end
     local satir = tooltip:AddRowAfter("name", "kimlik")
     satir:SetBackgroundColor(Color(150, 120, 60))
     local hane = K.Casaler[tonumber(self:GetData("hane", 0)) or 0]
     satir:SetText(tostring(self:GetData("no", "?")) .. (hane and (" · " .. hane) or "") .. " · " .. os.date("%d.%m.%Y", tonumber(self:GetData("verilis", 0)) or 0))
     satir:SizeToContents()
end

local function Elde(item) return not IsValid(item.entity) end

ITEM.functions.Incele = {
     name = "Examinar",
     icon = "icon16/vcard.png",
     OnRun = function(item)
          if SERVER and K.Incele then K.Incele(item.player, item) end
          return false
     end,
     OnCanRun = function(item) return Elde(item) and not item:GetData("bos") end,
}

ITEM.functions.Goster = {
     name = "Mostrar",
     icon = "icon16/user_go.png",
     isMulti = true,
     multiOptions = function()
          return {
               {name = "A quien miras", data = {kip = "bakilan"}},
               {name = "A quienes están cerca", data = {kip = "yakin"}},
          }
     end,
     OnRun = function(item, data)
          if SERVER and K.Goster then K.Goster(item.player, item, istable(data) and data.kip or "bakilan") end
          return false
     end,
     OnCanRun = function(item) return Elde(item) and not item:GetData("bos") end,
}

ITEM.functions.Rellenar = {
     name = "Rellenar",
     icon = "icon16/pencil.png",
     OnClick = function(item)
          if K.RellenarAc then K.RellenarAc(item.id) end
          return false
     end,
     OnRun = function() return false end,
     OnCanRun = function(item) return Elde(item) and item:GetData("bos") == true end,
}

-- Envanter hücresinde küçük kart: SHINE kompakt kimlik (yeşil şerit, fildişi alan, mühür)
if CLIENT then
     local fildisi, serit, kenar, cizgi = Color(232, 221, 186), Color(20, 45, 34), Color(209, 189, 133), Color(116, 116, 81)
     function ITEM.PaintOver(panel, item, w, h)
          local cw = math.floor(w * 0.84)
          local ch = math.floor(cw * 350 / 600)
          local x, y = math.floor((w - cw) / 2), math.floor((h - ch) / 2)
          surface.SetDrawColor(0, 0, 0, 90)
          surface.DrawRect(x + 2, y + 2, cw, ch)
          surface.SetDrawColor(fildisi)
          surface.DrawRect(x, y, cw, ch)
          local sw = math.floor(cw * 0.25)
          surface.SetDrawColor(serit)
          surface.DrawRect(x, y, sw, ch)
          -- kemerli portre yeri
          surface.SetDrawColor(156, 149, 111, 255)
          surface.DrawRect(x + math.floor(sw * 0.2), y + math.floor(ch * 0.25), math.floor(sw * 0.6), math.floor(ch * 0.45))
          surface.SetDrawColor(cizgi.r, cizgi.g, cizgi.b, 150)
          for i = 0, 2 do surface.DrawRect(x + sw + 5, y + 6 + i * math.floor((ch - 12) / 3), math.floor((cw - sw) * 0.6) - i * 5, 2) end
          surface.SetDrawColor(kenar)
          surface.DrawOutlinedRect(x, y, cw, ch, 1)
          if item:GetData("bos") then return end
          local mat = B.Doku and (B.Doku("kimlik2_muhur") or B.Doku("mum"))
          if mat then
               surface.SetMaterial(mat)
               surface.SetDrawColor(255, 255, 255, 240)
               local m = math.floor(ch * 0.42)
               surface.DrawTexturedRect(x + math.floor((sw - m) / 2), y + ch - m - 1, m, m)
               draw.NoTexture()
          end
     end
end
