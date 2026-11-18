-- "addons\\sardonogrenci\\lua\\sardon_ogrenci\\_sh_5esya.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Öğrenci :: giysi eşyaları. Taban "base_ogrenci_giysi" + katalogdaki her giysi için bir eşya
-- (ogr_<kimlik>). Veri: l = renk (görünüm numarası; kalıcı), h = kapüşon takılı, gv = son giyenin cinsiyeti
-- (ikon/model için), kh = karşılama cüppesi (hane seçilince hane rengine geçer), g = "giydirilecek" (eski kayıt ya da
-- yeni verilen takım; karakter yüklenince ekipmana taşınır). Giyili = karakterin "sardon_kiyafet" ekipman
-- envanterinde; oradan yalnız O.Cikar ile çıkar, atılamaz. Sahiplik kuralları sv_2kiyafet.lua'da.
local O = SardonOgrenci

-- yere atılan giysi askıda durur (Madam Malkin askısı, koleksiyonda); yoksa bavul
O.DunyaModeli = "models/konnie/diagonalley/madame/hanger.mdl"

ix.inventory.Register(O.EKIPMAN, O.EKIPMAN_W, 1)

function O.EkipmanMi(inv)
     return istable(inv) and istable(inv.vars) and inv.vars.isBag == O.EKIPMAN
end

-- Karakterin kıyafet ekipman envanteri (henüz oluşturulmadıysa nil)
function O.Ekipman(char)
     if not char then return end
     local inv = ix.item.inventories[char:GetData("kiyafetEnv") or -1]
     if O.EkipmanMi(inv) then return inv end
     for _, v in ipairs(char:GetInventory(true) or {}) do
          if O.EkipmanMi(v) then return v end
     end
end

-- giyili mi (ekipman envanterinde)
function O.Giyili(item)
     return item ~= nil and O.EkipmanMi(ix.item.inventories[item.invID or 0])
end

local function oyuncuCinsi(ply)
     if not IsValid(ply) then return nil end
     local c = O.TabanMi(ply:GetModel())
     if c then return c end
     local d = ply:GetCharacter() and O.KarakterDurumu(ply:GetCharacter())
     return d and d.gender or nil
end

-- eşyanın katalog kimliği
function O.EsyaGiysi(item)
     return item and item.giysi
end

-- eşyayı gösterirken kullanılacak cinsiyet: giyen/son giyen, yoksa eşyanın var olduğu ilk cinsiyet
local function gosterimCinsi(item, ply)
     local g = O.Giysi[item.giysi or ""]
     if not g then return "m" end
     local c = oyuncuCinsi(ply) or item:GetData("gv")
     if c and g[c] then return c end
     return g.m and "m" or "f"
end

function O.EsyaParca(item, ply)
     local cins = gosterimCinsi(item, ply)
     return O.GiysiParcasi(item.giysi, cins), cins
end

-- oyuncunun cinsiyeti bu giysiyi giyebilir mi
function O.GiyebilirMi(ply, item)
     local c = oyuncuCinsi(ply)
     return c ~= nil and O.GiysiParcaKimligi(item.giysi, c) ~= nil
end

function O.RenkIzni(ply)
     local k = O.Ayar.RenkDegistir
     return k == "serbest" or (k == "yetkili" and O.Yetkili(ply))
end

----------------------------------------------------------------------------------------
-- Taban
----------------------------------------------------------------------------------------
local TABAN = ix.item.Register(O.ESYA_TABAN, nil, true, nil, true)
TABAN.name = "Prenda de estudiante"
TABAN.description = "Una prenda de estudiante."
TABAN.model = "models/hl_students/gear/robe_sturobe01.mdl"
TABAN.WorldModel = O.DunyaModeli
TABAN.width = 1
TABAN.height = 1
TABAN.category = "Ropa"
TABAN.noBusiness = true

function TABAN:GetName()
     local g = O.Giysi[self.giysi or ""]
     if not g then return self.name end
     local p = O.EsyaParca(self, CLIENT and LocalPlayer() or nil)
     local l = self:GetData("l", 1)
     local renk = p and #p.looks > 1 and O.RenkAdi(p, l) or ""
     return renk ~= "" and (g.ad .. " (" .. renk .. ")") or g.ad
end

function TABAN:GetDescription()
     local g = O.Giysi[self.giysi or ""]
     if not g then return "Esta prenda ya no está en el catálogo." end

     local t = {O.SlotAd[g.slot] or g.slot}
     if not g.f then t[#t + 1] = "Solo la pueden vestir estudiantes chicos." end
     if not g.m then t[#t + 1] = "Solo la pueden vestir estudiantes chicas." end

     local p = O.EsyaParca(self, CLIENT and LocalPlayer() or nil)
     if p and #p.looks > 1 then
          local hane = 0
          for i = 1, #p.looks do
               if O.HaneRengiMi(p, i) then hane = hane + 1 end
          end
          t[#t + 1] = #p.looks .. " color(es)" .. (hane > 0 and (" (" .. hane .. " de casa: se tiñe según tu casa)") or "") .. "."
     end

     if p and #p.looks > 1 and O.Ayar.RenkDegistir ~= "serbest" then
          t[#t + 1] = "El color es permanente; otro color se compra aparte en Madam Malkin."
     end

     if O.Giyili(self) then
          t[#t + 1] = "Puesta. Para quitarla: arrástrala del slot del guardarropa al inventario."
     else
          t[#t + 1] = "Para vestirla: arrástrala al slot del personaje o usa Vestir."
     end
     return table.concat(t, "\n")
end

function TABAN:GetModel()
     local pid = O.GiysiParcaKimligi(self.giysi, gosterimCinsi(self))
     return pid and ("models/hl_students/gear/" .. pid .. ".mdl") or self.model
end

TABAN.functions.Equip = {
     name = "Vestir",
     tip = "Ponte la prenda (la que ocupaba el mismo slot vuelve al inventario).",
     icon = "icon16/user_suit.png",
     OnRun = function(item)
          if SERVER then
               local ok = O.Giy(item.player, item)
               if not ok and IsValid(item.player) then
                    item.player:Notify("No se pudo vestir esa prenda.")
               end
          end
          return false
     end,
     OnCanRun = function(item)
          return not IsValid(item.entity) and IsValid(item.player) and not O.Giyili(item) and O.GiyebilirMi(item.player, item)
     end
}

TABAN.functions.EquipUn = {
     name = "Quitar",
     tip = "Quítate la prenda (vuelve al inventario).",
     icon = "icon16/cross.png",
     OnRun = function(item)
          if SERVER then
               local ok = O.Cikar(item.player, item)
               if not ok and IsValid(item.player) then
                    item.player:Notify("No se pudo quitar la prenda (¿inventario lleno?).")
               end
          end
          return false
     end,
     OnCanRun = function(item)
          return not IsValid(item.entity) and (O.Giyili(item) or item:GetData("g") == true)
     end
}

TABAN.functions.Renk = {
     name = "Cambiar color",
     tip = "Opciones de color de la prenda.",
     icon = "icon16/color_wheel.png",
     OnClick = function(item)
          if O.RenkSeciciAc then O.RenkSeciciAc(item) end
          return false
     end,
     OnRun = function() return false end,
     OnCanRun = function(item)
          if IsValid(item.entity) or not O.RenkIzni(item.player) then return false end
          local p = O.EsyaParca(item, item.player)
          return p ~= nil and #p.looks > 1
     end
}

TABAN.functions.Kapuson = {
     name = "Capucha arriba / abajo",
     tip = "Capucha de la túnica.",
     icon = "icon16/arrow_refresh.png",
     OnRun = function(item)
          if SERVER then O.KapusonDegistir(item.player, item) end
          return false
     end,
     OnCanRun = function(item)
          if IsValid(item.entity) or not O.Giyili(item) then return false end
          local p = O.GiysiParcasi(item.giysi, oyuncuCinsi(item.player) or "m")
          return p ~= nil and p.slot == "robe" and p.variant.h ~= nil
     end
}

-- (ekipman envanterine giriş/çıkış sv_2kiyafet.lua CanTransferItem kancasında)
local birak = TABAN.functions.drop
if birak and not birak.sardonOgrenci then
     local eski = birak.OnCanRun
     birak.sardonOgrenci = true
     birak.OnCanRun = function(item)
          if O.Giyili(item) or item:GetData("g") then return false end
          return not eski or eski(item)
     end
end

function TABAN:OnRemoved()
     if not SERVER or not (O.Giyili(self) or self:GetData("g")) then return end
     local sahip = self:GetOwner()
     timer.Simple(0, function()
          if IsValid(sahip) then O.Uygula(sahip) end
     end)
end

if CLIENT then
     local ikonlar = {}
     function O.IkonMat(yol)
          if not yol then return end
          local m = ikonlar[yol]
          if m == nil then
               m = file.Exists("materials/" .. yol, "GAME") and Material(yol, "smooth mips") or false
               ikonlar[yol] = m
          end
          return m or nil
     end

     local zemin = Color(13, 15, 23, 238)
     local altin = Color(226, 190, 120)

     -- ikon panelinin üstüne paketin kendi giysi ikonu (giyenin hanesinin renginde)
     function TABAN:PaintOver(item, w, h)
          local char = LocalPlayer():GetCharacter()
          local p = O.EsyaParca(item, LocalPlayer())
          local m = p and O.IkonMat(O.GiysiIkonYolu(p, item:GetData("l", 1), char and O.HaneNo(char:GetFaction()) or 1))
          if m then
               draw.RoundedBox(4, 2, 2, w - 4, h - 4, zemin)
               local b = math.min(w, h) - 6
               surface.SetMaterial(m)
               surface.SetDrawColor(255, 255, 255)
               surface.DrawTexturedRect((w - b) / 2, (h - b) / 2, b, b)
          end

          if item:GetData("g") or O.Giyili(item) then
               surface.SetDrawColor(altin.r, altin.g, altin.b, 150)
               surface.DrawOutlinedRect(2, 2, w - 4, h - 4, 1)
               draw.RoundedBox(4, w - 13, 5, 8, 8, altin)
          end
     end
end

----------------------------------------------------------------------------------------
-- Katalog eşyaları
----------------------------------------------------------------------------------------
for _, id in ipairs(O.GiysiSira) do
     local g = O.Giysi[id]
     local ITEM = ix.item.Register(O.ESYA_ONEK .. id, O.ESYA_TABAN, false, nil, true)
     ITEM.name = g.ad
     ITEM.giysi = id
     ITEM.category = O.SlotKategori[g.slot] or "Ropa"
     ITEM.model = "models/hl_students/gear/" .. (g.m or g.f) .. ".mdl"
end

----------------------------------------------------------------------------------------
-- v1 (Staylofft tabanı) eşyası: kayıtlı örnekler yüklenebilsin diye; sv_1kayit.lua ilk yüklemede yenisiyle değiştirir
----------------------------------------------------------------------------------------
local ESKI = ix.item.Register(O.ESKI_ESYA, nil, false, nil, true)
ESKI.name = "Ropa de estudiante antigua"
ESKI.description = "Prenda del sistema de aspecto antiguo; al cargar el personaje se sustituye por la nueva."
ESKI.model = "models/props_c17/suitcase001a.mdl"
ESKI.width = 1
ESKI.height = 1
ESKI.category = "Ropa"
ESKI.noBusiness = true
