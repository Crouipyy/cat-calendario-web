-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\cl_6defter.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: Yaratık Defteri (TAB menüsü sekmesi) — çekirdek
--
-- 1600×900 tasarım alanı, Karakter Gelişimi'nin Celestial arka planı. Anlık çizim (Paint) ve
-- kare başına kaydedilen tıklama bölgeleri. Sekmelerin çizimi cl_7/cl_8 dosyalarında
-- (Y.DefterCiz[sekme]). Kayıtlar sunucudan Y.Benim ile gelir; ihtiyaçlar istemcide Y.Tahmin ile
-- saniyede bir ileri hesaplanır.

local Y = SardonYaratik
local R = Y.R

Y.DefterCiz = Y.DefterCiz or {}
Y.DefterSecili = Y.DefterSecili

local SEKMELER = {
     {id = "codex", ad = "CODEX"},
     {id = "yaratiklar", ad = "YARATIKLARIM"},
     {id = "vivaryum", ad = "VİVARYUM"},
     {id = "ansiklopedi", ad = "ANSİKLOPEDİ"},
}

------------------------------------------------------------------------ model görüntüleyici

-- Sıra değişince eski ClientsideModel'i değiştirmek pozu karıştırıyor: her görünüm için taze model.
local Model = {}
Model.__index = Model

function Y.ModelGoster()
     return setmetatable({}, Model)
end

function Model:Ayarla(tur, bg, evre, yumurta)
     local anahtar = tostring(tur and tur.model) .. "|" .. tostring(bg) .. "|" .. tostring(yumurta)
     if self.anahtar == anahtar and IsValid(self.mdl) then return end
     self:Kaldir()
     self.anahtar = anahtar
     self.tur = tur
     self.yumurta = yumurta
     if not tur then return end
     local yol = yumurta and Y.Ayar.YumurtaModel or tur.model
     if not file.Exists(yol, "GAME") then self.eksik = true return end
     self.eksik = nil
     local mdl = ClientsideModel(yol, RENDERGROUP_OPAQUE)
     if not IsValid(mdl) then return end
     mdl:SetNoDraw(true)
     if not yumurta then
          local g = mdl:FindBodygroupByName("staylofft_color")
          if g and g >= 0 then mdl:SetBodygroup(g, bg or 0) end
          local seq = mdl:LookupSequence((tur.anim and tur.anim.idle) or "idle")
          if seq and seq >= 0 then
               mdl:ResetSequence(seq)
               self.sure = math.max(mdl:SequenceDuration(seq), 0.1)
          end
     end
     self.mdl = mdl
     self.animAd = "idle"
     self.donus = self.donus or 35
end

-- gösterilen animasyonu değiştir (Ansiklopedi'deki önizleme düğmeleri)
function Model:Anim(ad)
     local mdl = self.mdl
     if not IsValid(mdl) or self.yumurta or not self.tur or self.animAd == ad then return end
     local gercek = (self.tur.anim and self.tur.anim[ad]) or ad
     local seq = mdl:LookupSequence(gercek)
     if not seq or seq < 0 then return end
     mdl:ResetSequence(seq)
     self.sure = math.max(mdl:SequenceDuration(seq), 0.1)
     self.animAd = ad
     self.animBas = RealTime()
end

-- modelde bulunan animasyonlar (Y.AnimAdlari sırasıyla)
function Model:Animler()
     local out = {}
     local mdl = self.mdl
     if not IsValid(mdl) or self.yumurta then return out end
     for _, a in ipairs(Y.AnimAdlari or {}) do
          local seq = mdl:LookupSequence((self.tur.anim and self.tur.anim[a[1]]) or a[1])
          if seq and seq >= 0 then out[#out + 1] = a end
     end
     return out
end

function Model:Kaldir()
     if IsValid(self.mdl) then self.mdl:Remove() end
     self.mdl = nil
     self.anahtar = nil
end

-- x, y, w, h: ekran pikseli
function Model:Ciz(x, y, w, h, surukle)
     local mdl = self.mdl
     local tur = self.tur
     if not IsValid(mdl) or not tur then return end

     local k = self.yumurta and {8, 8, 10} or (tur.kutu or {30, 30, 30})
     local L, H = math.max(k[1], k[2]), k[3]
     if self.yumurta then
          local o = (tur.yumurta and tur.yumurta.olcek) or 1
          L, H = 6 * o, 7 * o
          mdl:SetModelScale(o, 0)
     end
     local fov = 32
     local tanX = math.tan(math.rad(fov / 2))
     local tanY = tanX / (w / h)
     local d = math.max((L * 0.62) / tanX, (H * 0.62) / tanY) + L * 0.4

     if not surukle then self.donus = (self.donus or 0) + FrameTime() * 14 end
     local hedef = Vector(0, 0, H * 0.48)
     local kam = Vector(d, 0, H * 0.62)
     mdl:SetPos(vector_origin)
     mdl:SetAngles(Angle(0, self.donus + (tur.yonOfset or -90) + 90, 0))
     if self.sure then mdl:SetCycle(((RealTime() - (self.animBas or 0)) / self.sure) % 1) end
     if self.yumurta and tur.yumurta and tur.yumurta.renk then
          local r = tur.yumurta.renk
          render.SetColorModulation(r.r / 255, r.g / 255, r.b / 255)
     end

     cam.Start3D(kam, (hedef - kam):Angle(), fov, x, y, w, h, 4, 4000)
          render.SuppressEngineLighting(true)
          render.SetModelLighting(BOX_FRONT, 0.95, 0.9, 0.82)
          render.SetModelLighting(BOX_BACK, 0.25, 0.3, 0.35)
          render.SetModelLighting(BOX_RIGHT, 0.6, 0.55, 0.5)
          render.SetModelLighting(BOX_LEFT, 0.35, 0.4, 0.45)
          render.SetModelLighting(BOX_TOP, 1, 0.97, 0.9)
          render.SetModelLighting(BOX_BOTTOM, 0.12, 0.14, 0.13)
          mdl:SetupBones()
          mdl:DrawModel()
          render.SuppressEngineLighting(false)
     cam.End3D()
     render.SetColorModulation(1, 1, 1)
end

------------------------------------------------------------------------ panel

local PANEL = {}

function PANEL:Init()
     self.T = Y.TuvalYap(1600, 900)
     self.sekme = Y.DefterCiz.codex and "codex" or "yaratiklar"
     self.tiklar = {}
     self.kaydir = {}
     self.model = Y.ModelGoster()
     self.tahminler = {}
     self.tahminT = 0
     Y.Islem("liste")
     hook.Add("SardonYaratikListe", self, function(s) s.tahminT = 0 end)
end

function PANEL:PerformLayout(w, h)
     self.T.Olc(w, h)
end

function PANEL:OnRemove()
     self.model:Kaldir()
     if self.model2 then self.model2:Kaldir() end
end

-- tıklama bölgesi (tasarım koordinatı)
function PANEL:Tik(x, y, w, h, fn, ipucu)
     self.tiklar[#self.tiklar + 1] = {x, y, w, h, fn, ipucu}
end

function PANEL:Fare()
     local mx, my = self:CursorPos()
     return self.T.Geri(mx, my)
end

function PANEL:Ustunde(x, y, w, h)
     local mx, my = self:Fare()
     return self:IsHovered() and mx >= x and mx <= x + w and my >= y and my <= y + h
end

function PANEL:OnMousePressed(kod)
     local mx, my = self:Fare()
     if kod == MOUSE_LEFT then
          for i = #self.tiklar, 1, -1 do
               local t = self.tiklar[i]
               if mx >= t[1] and mx <= t[1] + t[3] and my >= t[2] and my <= t[2] + t[4] then
                    surface.PlaySound("ui/buttonclick.wav")
                    t[5]()
                    return
               end
          end
          -- model alanında sürükleme
          if self.modelAlan and mx >= self.modelAlan[1] and mx <= self.modelAlan[1] + self.modelAlan[3] and my >= self.modelAlan[2] and my <= self.modelAlan[2] + self.modelAlan[4] then
               self.surukle = {mx, self.model.donus or 0}
               self:MouseCapture(true)
          end
     end
end

function PANEL:OnMouseReleased(kod)
     if self.surukle then
          self.surukle = nil
          self:MouseCapture(false)
     end
end

function PANEL:OnMouseWheeled(d)
     local mx, my = self:Fare()
     for alan, b in pairs(self.kaydirAlan or {}) do
          if mx >= b[1] and mx <= b[1] + b[3] and my >= b[2] and my <= b[2] + b[4] then
               self.kaydir[alan] = math.Clamp((self.kaydir[alan] or 0) - d * 60, 0, math.max(0, b[5] or 0))
               return true
          end
     end
end

function PANEL:Think()
     if self.surukle then
          local mx = self:Fare()
          self.model.donus = self.surukle[2] + (mx - self.surukle[1]) * 0.6
     end
end

-- kayıt tahmini (saniyede bir)
function PANEL:Tahmin(k)
     local simdi = Y.SunucuZamani()
     if simdi ~= self.tahminT then
          self.tahminT = simdi
          self.tahminler = {}
     end
     local t = self.tahminler[k.id]
     if not t then
          t = Y.Tahmin(k, simdi)
          self.tahminler[k.id] = t
     end
     return t
end

-- düğme (tasarım koordinatı); aktif değilse soluk
function PANEL:Dugme(x, y, w, h, yazi, fn, aktif, vurgu)
     local T = self.T
     local ustunde = aktif ~= false and self:Ustunde(x, y, w, h)
     T.Ton(ustunde and R.satirSecili or R.satir, 1)
     T.Dolu(x, y, w, h)
     T.Ton(aktif == false and R.cizgi or (vurgu and R.parlak or R.altin), aktif == false and 1 or (ustunde and 1 or 0.7))
     T.Cerceve(x, y, w, h)
     T.Yazi(Y.Buyuk(yazi), 12, 600, x + w / 2, y + h / 2, aktif == false and R.kilit or (ustunde and R.parlak or R.soluk), 1, 1.5)
     if aktif ~= false and fn then self:Tik(x, y, w, h, fn) end
end

function PANEL:Paint(w, h)
     local T = self.T
     self.tiklar = {}
     self.kaydirAlan = {}
     self.modelAlan = nil

     -- arka plan
     local bg = SardonGelisim and SardonGelisim.Doku and SardonGelisim.Doku("background")
     surface.SetDrawColor(7, 14, 11, 255)
     surface.DrawRect(0, 0, w, h)
     if bg then
          surface.SetMaterial(bg)
          surface.SetDrawColor(255, 255, 255, 255)
          local bw, bh = w, w * 0.5625
          if bh < h then bh, bw = h, h / 0.5625 end
          surface.DrawTexturedRect((w - bw) / 2, (h - bh) / 2, bw, bh)
          draw.NoTexture()
          surface.SetDrawColor(5, 12, 9, 150)
          surface.DrawRect(0, 0, w, h)
     end

     -- başlık
     T.Yazi("YARATIK DEFTERİ", 28, "baslik", 48, 42, R.parlak, 0, 5)
     local b = Y.Benim or {}
     local stok = 0
     for _, n in pairs(b.yemlik or {}) do stok = stok + n end
     T.Yazi(string.format("Vivaryum %d/%d yaratık  ·  %d/%d yumurta  ·  yemlikte %d yem", b.canli or 0, b.kapasite or 0, b.yumurta or 0, Y.Ayar.KuluckaSiniri, stok),
          13, 400, 50, 72, R.sonuk, 0)

     -- sekmeler
     local sx = 1552
     for i = #SEKMELER, 1, -1 do
          local s = SEKMELER[i]
          local gw = T.Olcu(s.ad, 14, "baslik") + 12 + 32
          sx = sx - gw
          local secili = self.sekme == s.id
          local ustunde = self:Ustunde(sx, 22, gw, 44)
          T.Yazi(s.ad, 14, "baslik", sx + gw / 2, 44, secili and R.parlak or (ustunde and R.soluk or R.sonuk), 1, 2)
          if secili then
               T.Ton(R.altin, 1)
               T.Dolu(sx + 16, 62, gw - 32, 2)
               T.Baklava(sx + gw / 2, 63, 4)
          end
          self:Tik(sx, 22, gw, 44, function() self.sekme = s.id end)
     end
     T.Ton(R.cizgi, 1)
     T.Dolu(40, 88, 1520, 1)

     local f = Y.DefterCiz[self.sekme]
     if f then
          local ok, hata = pcall(f, self, T, w, h)
          if not ok then
               T.Yazi("Çizim hatası: " .. tostring(hata), 12, 400, 48, 120, R.hata, 0)
               if not self.hataYazildi then
                    self.hataYazildi = true
                    ErrorNoHalt("[Sardon Yaratık] Defter: " .. tostring(hata) .. "\n")
               end
          end
     end
end

vgui.Register("SardonYaratik.Defter", PANEL, "EditablePanel")

------------------------------------------------------------------------ TAB sekmesi

hook.Add("CreateMenuButtons", "SardonYaratik", function(tabs)
     tabs["yaratik"] = {
          hoswarsIcon = "icon_map",
          bHideBackground = true,
          Create = function(info, container)
               local ekran = container:Add("SardonYaratik.Defter")
               ekran:SetSize(container:GetSize())
               container.sardonYaratik = ekran
          end
     }
end)

local function DilEkle()
     for dil in pairs(ix.lang.stored or {}) do
          ix.lang.AddTable(dil, {yaratik = "Yaratık Defteri"})
     end
end
DilEkle()
timer.Simple(5, DilEkle)
