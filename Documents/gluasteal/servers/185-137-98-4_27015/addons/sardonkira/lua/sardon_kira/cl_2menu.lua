-- "addons\\sardonkira\\lua\\sardon_kira\\cl_2menu.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kira v2 :: /Kira menüsü "PM Kiralarım". Görünüm önceki (v1) kira menüsünden: XeninUI çerçevesi, solda
-- gradyanlı kira kartları, sağda model + ad + kırmızı süre çubuğu. v2 işlevleri eklendi: durum, karaktere bağlama,
-- SC ile ya da sitede uzatma, kira yoksa "Model Kirala". Kenar rengi bağlı karakterin fraksiyonundan.
local K = SardonKira
local D = K.D
local OP = K.OP

local COL_DARK_21 = Color(21, 21, 21)
local COL_MOR = Color(135, 90, 207)
local COL_PASIF = Color(110, 110, 110)
local COL_KIRMIZI = Color(255, 70, 70)
local COL_YESIL = Color(110, 205, 140)
local COL_SARI = Color(235, 190, 90)
local COL_SOLUK = Color(171, 171, 171)
local DURUM_RENK = { BEKLIYOR = COL_SARI, ETKIN = COL_YESIL, TOLERANS = COL_KIRMIZI, CIKTI = COL_SOLUK, IPTAL = COL_SOLUK }

XeninUI:CreateFont("KiraMenu.PM.Title", 48)
XeninUI:CreateFont("KiraMenu.PM.Status", 20)
XeninUI:CreateFont("KiraMenu.PM.SubStatus", 16)

local function tarih(t) return t and os.date("%d.%m.%Y", t) or "—" end

local function karakter(id)
     return id and ix.char.loaded[id] or nil
end

local function renkler(r)
     local c = karakter(r.karakterId)
     local f = c and ix.faction.indices[c:GetFaction()]
     local col = (f and f.color) or COL_MOR
     local h, s, l = ColorToHSL(col)
     return col, HSLToColor((h + 10) % 360, s, math.min(1, l + 0.05))
end

local function ilerleme(r)
     local simdi = K.Simdi()
     if r.durum == D.ETKIN and r.bitis and r.baslangic then
          local sure = math.max(1, r.bitis - r.baslangic)
          local kalan = r.bitis - simdi
          local metin
          if kalan < K.GUN then
               metin = "Süresinin dolmasına " .. math.max(1, math.floor(kalan / 3600)) .. " saat kaldı."
          else
               metin = "Süresinin dolmasına " .. math.ceil(kalan / K.GUN) .. " gün kaldı."
          end
          return math.Clamp((simdi - r.baslangic) / sure, 0, 1), metin
     elseif r.durum == D.TOLERANS and r.bitis then
          local g = math.max(0, math.ceil((r.bitis + K.TOLERANS_GUN * K.GUN - simdi) / K.GUN))
          return 1, "Süresi doldu: " .. g .. " gün içinde uzatırsan geri gelir."
     elseif r.durum == D.BEKLIYOR then
          return 0, r.anlikOge and "Sunucuya yükleniyor, birazdan hazır." or "Sabah 05:00 restartında yayına girer."
     end
     return 1, K.DURUM_YAZI[r.durum] or r.durum
end

local function Dugme(parent, metin, fn)
     local b = parent:Add("DButton")
     b:SetFont("XeninUI.DropdownPopup")
     b:SetText(metin)
     b:SetTextColor(color_white)
     b.Paint = function(s, w, h)
          draw.RoundedBox(8, 0, 0, w, h, s.kapali and COL_PASIF or (s:IsHovered() and Color(155, 110, 227) or COL_MOR))
     end
     b.DoClick = function(s) if not s.kapali then fn(s) end end
     return b
end

-- ------------------------------------------------------------------ çerçeve
do
     local PANEL = {}
     function PANEL:Init()
          self:SetSize(ScreenScale(450), ScreenScale(185))
          self:Center()
          self:SetTitle("PM Kiralarım")
          local plyBar = self:Add("XeninUI.Sidebar.Player")
          plyBar:SetSize(ScreenScale(80), 64)
          plyBar:SetY(40)
          self.nav = self:Add("XeninUI.SidebarV2")
          self.nav:DockMargin(0, 64, 0, 0)
          self.nav:Dock(LEFT)
          self.nav:SetWide(ScreenScale(80))
          self.body = self:Add("Panel")
          self.body:Dock(FILL)
          self.nav:SetBody(self.body)
          self.closeBtn.DoClick = function() self:Remove() end
     end

     function PANEL:Doldur(secili)
          local nav = self.nav
          local liste = K.Benim.liste or {}
          nav:CreateDivider()
          for _, r in ipairs(liste) do
               local c1, c2 = renkler(r)
               nav:CreatePanel(r.ad or r.kod, (r.paket or "?") .. "MB · " .. (K.DURUM_YAZI[r.durum] or r.durum), "SardonKira.PM", nil, {
                    colors = { c1, c2 },
                    data = r,
               })
          end
          nav:CreateDivider()
          nav:CreatePanel("Model Kirala", "shop.shineroleplay.com", "SardonKira.PM.Kirala", nil, {
               colors = { Color(128, 42, 42), Color(175, 49, 66) },
          })
          local hedef = 1
          for i, b in ipairs(nav.Sidebar) do
               if secili and b.Name == secili then hedef = i end
          end
          nav:SetActive(hedef)
     end

     vgui.Register("SardonKira.Menu", PANEL, "XeninUI.Frame")
end

-- ------------------------------------------------------------------ kira sayfası
do
     local PANEL = {}
     function PANEL:Init()
          self.model = self:Add("DModelPanel")
          self.model:SetSize(ScreenScale(236) / 3, ScreenScale(170))
          self.model:SetPos(0, -ScreenScale(8))
          self.model:SetFOV(25)
          self.model:SetModel("models/johnaga/johnaga_deatheater.mdl")
          self.model.LayoutEntity = function(s, ent)
               ent:SetAngles(Angle(0, 45, 0))
          end

          local x = ScreenScale(236) / 3 + ScreenScale(4)
          self.baslik = self:Add("DLabel")
          self.baslik:SetFont("KiraMenu.PM.Title")
          self.baslik:SetTextColor(color_white)
          self.baslik:SetPos(x, ScreenScale(4))

          self.cubuk = self:Add("Panel")
          self.cubuk:SetPos(x, ScreenScale(24))
          self.cubuk:SetSize(ScreenScale(200), ScreenScale(12))
          self.cubuk.oran, self.cubuk.metin = 0, ""
          self.cubuk.Paint = function(s, w, h)
               draw.RoundedBox(3, 0, 0, w, h, color_white)
               draw.RoundedBox(3, 0, 0, w * s.oran, h, COL_KIRMIZI)
               draw.SimpleText(s.metin, "KiraMenu.PM.Status", w / 2, h / 2, Color(0, 0, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          end

          self.bilgi = self:Add("Panel")
          self.bilgi:SetPos(x, ScreenScale(40))
          self.bilgi:SetSize(ScreenScale(280), ScreenScale(48))
          self.bilgi.Paint = function(s, w, h)
               local r = self.r
               if not r then return end
               local satir = ScreenScale(9.5)
               local function yaz(i, anahtar, deger, renk)
                    draw.SimpleText(anahtar, "KiraMenu.PM.Status", 0, (i - 1) * satir, COL_SOLUK)
                    draw.SimpleText(deger, "KiraMenu.PM.Status", ScreenScale(58), (i - 1) * satir, renk or color_white)
               end
               local c = karakter(r.karakterId)
               yaz(1, "Durum:", K.DURUM_YAZI[r.durum] or r.durum, DURUM_RENK[r.durum])
               yaz(2, "Başlangıç Tarihi:", tarih(r.baslangic))
               yaz(3, "Belirlenen Süre:", (r.bitis and r.baslangic) and (math.floor((r.bitis - r.baslangic) / K.GUN + 0.5) .. " gün (bitiş " .. tarih(r.bitis) .. ")") or "—")
               yaz(4, "Karakter:", c and c:GetName() or (r.karakterId and ("#" .. r.karakterId) or "seçilmedi"), r.karakterId and color_white or COL_SARI)
          end

          -- karaktere bağla
          local y1 = ScreenScale(92)
          self.secim = self:Add("DButton")
          self.secim:SetFont("XeninUI.DropdownPopup")
          self.secim:SetText("Karakter Seç")
          self.secim:SetTextColor(color_white)
          self.secim:SetPos(x, y1)
          self.secim:SetSize(ScreenScale(130), ScreenScale(16))
          self.secim.Paint = function(s, w, h) draw.RoundedBox(8, 0, 0, w, h, s.renk or COL_DARK_21) end
          self.secim.DoClick = function(s)
               if IsValid(s.acilir) then s.acilir:Remove() end
               s.acilir = vgui.Create("XeninUI.DropdownPopup")
               for _, id in ipairs(ix.characters or {}) do
                    local c = ix.char.loaded[id]
                    if c then
                         local f = ix.faction.indices[c:GetFaction()]
                         s.acilir:AddChoice(c:GetName(), function()
                              self.secilen = id
                              s:SetText(c:GetName())
                              s.renk = f and f.color or COL_DARK_21
                         end, color_white, f and f.color or COL_MOR)
                    end
               end
               s.acilir:SetPos(s:LocalToScreen(0, s:GetTall()))
               s.acilir:MakePopup()
          end
          self.secim.OnRemove = function(s) if IsValid(s.acilir) then s.acilir:Remove() end end

          self.bagla = Dugme(self, "Karaktere Bağla", function()
               local r = self.r
               local c = self.secilen and ix.char.loaded[self.secilen]
               if not r or not c then return K.Bildirim("Önce bir karakter seç.") end
               Derma_Query("\"" .. (r.ad or r.kod) .. "\" kirası " .. c:GetName() .. " karakterine bağlanacak. Bağı 30 gün değiştiremezsin.",
                    "Karaktere Bağla", "Bağla", function() K.Iste(OP.BAGLA, { kod = r.kod, karakterId = self.secilen }) end, "Vazgeç")
          end)
          self.bagla:SetPos(x + ScreenScale(136), y1)
          self.bagla:SetSize(ScreenScale(100), ScreenScale(16))

          -- uzatma
          local y2 = ScreenScale(112)
          self.uzatSC = Dugme(self, "Uzat", function()
               local r = self.r
               if not r or not r.uzatmaSC or not K.Benim.sc then return end
               Derma_Query("\"" .. (r.ad or r.kod) .. "\" kirası 30 gün uzatılacak: " .. r.uzatmaSC .. " SC (bakiyen " .. K.Benim.sc .. " SC).",
                    "Kirayı Uzat", "Uzat", function() K.Iste(OP.UZAT_SC, { kod = r.kod }) end, "Vazgeç")
          end)
          self.uzatSC:SetPos(x, y2)
          self.uzatSC:SetSize(ScreenScale(130), ScreenScale(16))

          self.site = Dugme(self, "Sitede Uzat", function()
               gui.OpenURL((K.Benim.site or K.SITE_URL) .. "/kiralarim")
          end)
          self.site:SetPos(x + ScreenScale(136), y2)
          self.site:SetSize(ScreenScale(100), ScreenScale(16))
     end

     function PANEL:SetData(tbl)
          local r = tbl.data
          self.r = r
          self.baslik:SetText((r.ad or r.kod) .. " - " .. (r.paket or "?") .. "MB")
          self.baslik:SizeToContents()
          self.cubuk.oran, self.cubuk.metin = ilerleme(r)
          if file.Exists(r.modelYolu or "", "GAME") then
               self.model:SetModel(r.modelYolu)
               local e = self.model.Entity
               if IsValid(e) then e:SetLOD(0) end
          end
          local c = karakter(r.karakterId)
          if c then
               self.secilen = r.karakterId
               self.secim:SetText(c:GetName())
               local f = ix.faction.indices[c:GetFaction()]
               self.secim.renk = f and f.color or nil
          end
          local kalanBag = r.karakterId and r.bagTarih and (r.bagTarih + (K.Benim.bagAralik or K.BAG_ARALIK) - K.Simdi()) or 0
          local etkin = r.durum == D.ETKIN
          self.bagla.kapali = not etkin or kalanBag > 0
          self.bagla:SetText((etkin and kalanBag > 0) and (math.ceil(kalanBag / K.GUN) .. " gün sonra") or "Karaktere Bağla")
          self.secim:SetEnabled(etkin and kalanBag <= 0)
          local uzatilir = etkin or r.durum == D.TOLERANS
          local sc = K.Benim.sc
          if uzatilir and r.uzatmaSC and sc then
               self.uzatSC:SetText("Uzat · " .. r.uzatmaSC .. " SC")
               self.uzatSC.kapali = sc < r.uzatmaSC
          else
               self.uzatSC:SetText(uzatilir and "Oyunda uzatma kapalı" or "Uzatılamaz")
               self.uzatSC.kapali = true
          end
          self.site:SetText(uzatilir and "Sitede Uzat" or "Sitede Aç")
     end

     function PANEL:Paint(w, h) end

     vgui.Register("SardonKira.PM", PANEL, "DPanel")
end

-- ------------------------------------------------------------------ "Model Kirala"
do
     local PANEL = {}
     function PANEL:Init()
          self.ac = Dugme(self, "Siteyi Aç", function() gui.OpenURL((K.Benim.site or K.SITE_URL) .. "/kira") end)
     end

     function PANEL:PerformLayout(w, h)
          self.ac:SetSize(ScreenScale(110), ScreenScale(16))
          self.ac:SetPos(w / 2 - ScreenScale(55), h / 2 + ScreenScale(18))
     end

     function PANEL:Paint(w, h)
          local bos = #(K.Benim.liste or {}) == 0
          draw.SimpleText(bos and "Henüz kiralık modelin yok." or "Yeni bir model kirala", "KiraMenu.PM.Title", w / 2, h / 2 - ScreenScale(24), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          draw.SimpleText("Modelini shop.shineroleplay.com'a yükle; boyutu ölçülür, ödeme ve incelemeden sonra", "KiraMenu.PM.Status", w / 2, h / 2 - ScreenScale(6), COL_SOLUK, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          draw.SimpleText("dakikalar içinde oyuna gelir ve 30 gün senin olur.", "KiraMenu.PM.Status", w / 2, h / 2 + ScreenScale(4), COL_SOLUK, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end

     vgui.Register("SardonKira.PM.Kirala", PANEL, "DPanel")
end

-- ------------------------------------------------------------------ açma / yenileme
function K.MenuAc()
     local secili
     if IsValid(K.MenuPanel) then
          local nav = K.MenuPanel.nav
          local b = nav and nav.Sidebar and nav.Sidebar[nav.Active]
          secili = b and b.Name
          K.MenuPanel:Remove()
     end
     K.MenuPanel = vgui.Create("SardonKira.Menu")
     K.MenuPanel:MakePopup()
     K.MenuPanel:Doldur(secili)
end

hook.Add("SardonKiraListe", "SardonKira.Menu", function()
     if IsValid(K.MenuPanel) then K.MenuAc() end
end)

concommand.Add("sardon_kira", function() K.Iste(OP.ISTE) K.MenuAc() end)
