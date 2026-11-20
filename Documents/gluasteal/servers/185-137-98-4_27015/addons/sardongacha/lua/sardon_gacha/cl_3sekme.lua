-- "addons\\sardongacha\\lua\\sardon_gacha\\cl_3sekme.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   TAB › Shine Store sekmesi. Solda iki seçenek: Gacha (asa dileği afişi) ve Shine Store.
*   Shine Store eklentisi gelince sayfayı "SardonShineStoreSayfa" kancasıyla doldurur
*   (hook.Add("SardonShineStoreSayfa", ad, function(panel) ... return true end)); kanca yoksa
*   sayfa "yakında" kartını ve SG.Ayar.storeKomut komutu varsa mağazayı açan düğmeyi gösterir.
*   Eski davranış ([sardon] commands: sekme menüyü kapatıp pulsarstore_open çalıştırıyordu)
*   bu kayıtla eziliyor; eklenti yüklenmezse eskisi kalır.
*/
local SG = SardonGacha

local SAYFALAR = {
     { id = "gacha", ad = "Gacha", alt = "Asa Dileği", ikon = "bilet", sinif = "SardonGacha.Afis" },
     { id = "store", ad = "Shine Store", alt = "Mağaza", ikon = "adak", sinif = "SardonGacha.Store" },
}

-- Başka eklentiler sol menüye sayfa ekler: hook.Add("SardonShineStoreSayfalar", ad, function(liste)
-- liste[#liste + 1] = { id, ad, alt, sinif, ikonCiz = function(x, y, boy, alfa) } end) — nil döndürmeli.
function SG.MagazaSayfalari()
     local liste = {}
     for i, s in ipairs(SAYFALAR) do liste[i] = s end
     hook.Run("SardonShineStoreSayfalar", liste)
     return liste
end

local PANEL = {}

function PANEL:Init()
     SG.Magaza = self
     self.liste = SG.MagazaSayfalari()
     self.sayfa = "gacha"
     for _, s in ipairs(self.liste) do
          if s.id == SG.SonSayfa then self.sayfa = s.id end
     end
     self.dugmeler = {}
     self.sayfalar = {}
     self.acilis = RealTime()

     for i, s in ipairs(self.liste) do
          local b = self:Add("DButton")
          b:SetText("")
          b.sayfa = s
          b.Paint = function(btn, w, h) self:MenuDugmeCiz(btn, w, h) end
          b.DoClick = function()
               if self.sayfa == s.id then return end
               SG.Cal("tik")
               self:SayfaAc(s.id)
          end
          b.OnCursorEntered = function() SG.Cal("uzerinde") end
          self.dugmeler[i] = b
     end

     self:SayfaAc(self.sayfa)
     SG.DurumIste()
end

function PANEL:OnRemove()
     if SG.Magaza == self then SG.Magaza = nil end
end

function PANEL:SayfaAc(id)
     self.sayfa = id
     SG.SonSayfa = id
     for _, p in pairs(self.sayfalar) do if IsValid(p) then p:SetVisible(false) end end
     local p = self.sayfalar[id]
     if not IsValid(p) then
          local sinif = "SardonGacha.Store"
          for _, s in ipairs(self.liste or SAYFALAR) do
               if s.id == id and s.sinif then sinif = s.sinif end
          end
          p = self:Add(sinif)
          self.sayfalar[id] = p
     end
     p:SetVisible(true)
     p.gecis = RealTime()
     self:InvalidateLayout(true)
end

function PANEL:Olcek()
     local w, h = self:GetSize()
     return math.min(w / 1640, h / 860)
end

function PANEL:PerformLayout(w, h)
     local S = self:Olcek()
     self.S = S
     self.railW = math.floor(232 * S)
     for i, b in ipairs(self.dugmeler) do
          b:SetPos(math.floor(16 * S), math.floor((132 + (i - 1) * 84) * S))
          b:SetSize(self.railW - math.floor(32 * S), math.floor(72 * S))
     end
     for _, p in pairs(self.sayfalar) do
          if IsValid(p) then
               p:SetPos(self.railW + math.floor(8 * S), 0)
               p:SetSize(w - self.railW - math.floor(8 * S), h)
          end
     end
end

function PANEL:MenuDugmeCiz(b, w, h)
     local S, R = self.S or 1, SG.R
     local s = b.sayfa
     local secili = self.sayfa == s.id
     local ust = b:IsHovered()
     if secili then
          SG.Gradyan(0, 0, w, h, Color(190, 162, 104, 46), "sol")
          SG.Kutu(0, 0, math.max(2, math.floor(3 * S)), h, R.altinAcik)
          SG.Kutu(0, h - 1, w, 1, R.cizgi)
     elseif ust then
          SG.Gradyan(0, 0, w, h, Color(190, 162, 104, 22), "sol")
     end
     local ik = math.floor(38 * S)
     if s.ikonCiz then
          s.ikonCiz(math.floor(16 * S), h / 2 - ik / 2, ik, secili and 1 or 0.7)
     else
          SG.Ikon(s.ikon, math.floor(16 * S), h / 2 - ik / 2, ik, secili and 1 or 0.7)
     end
     local tx = math.floor(66 * S)
     SG.Yazi(s.ad, SG.F(21 * S, "orta"), tx, h / 2 - 3 * S, secili and R.altinAcik or (ust and R.fildisiAcik or R.fildisi), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
     local alt = s.alt
     if s.id == "store" and not SG.StoreVar() then alt = "Yakında" end
     SG.Yazi(SG.Buyuk(alt), SG.F(11 * S, "orta"), tx, h / 2 + 4 * S, R.soluk)
end

function SG.StoreVar()
     if #table.GetKeys(hook.GetTable()["SardonShineStoreSayfa"] or {}) > 0 then return true end
     local k = SG.Ayar.storeKomut
     return isstring(k) and k ~= "" and concommand.GetTable()[k] ~= nil
end

function PANEL:Paint(w, h)
     local S, R = self.S or self:Olcek(), SG.R
     -- zemin: seçili afişin arka planı ya da Celestial gök
     local afis = self.sayfa == "gacha" and IsValid(self.sayfalar.gacha) and self.sayfalar.gacha:SeciliAfis() or nil
     local arka = afis and afis.arkaplan ~= "" and SG.UrlMat(afis.arkaplan)
     if arka then
          SG.Kutu(0, 0, w, h, R.zemin)
          SG.Kapla(arka, 0, 0, w, h, 1)
          SG.Kutu(0, 0, w, h, Color(4, 8, 6, 120))
     else
          SG.Zemin(0, 0, w, h)
     end

     -- sol ray
     local rw = self.railW or 232
     SG.Gradyan(0, 0, rw * 1.6, h, Color(4, 8, 6, 235), "sol")
     SG.Kutu(rw, math.floor(28 * S), 1, h - math.floor(56 * S), R.cizgiSoluk)

     SG.Yazi("S H I N E", SG.F(12 * S, "orta"), 22 * S, 34 * S, R.altin)
     SG.Yazi("Mağaza", SG.F(34 * S, "baslik"), 20 * S, 52 * S, R.fildisiAcik)
     SG.Kesik(22 * S, 110 * S, rw - 44 * S, R.cizgi)
     SG.Baklava(rw - 22 * S, 110 * S, 3 * S, R.altin, 1, true)

     -- cüzdan özeti
     local adak, bilet, toz = SG.Cuzdan()
     local ay = SG.Ayar
     local satirlar = { { "adak", adak, ay.adakAd }, { "bilet", bilet, ay.biletAd }, { "toz", toz, ay.tozAd } }
     local y0 = h - 186 * S
     SG.Yazi(SG.Buyuk("Cüzdan"), SG.F(11 * S, "orta"), 22 * S, y0, R.altin)
     SG.Kutu(22 * S, y0 + 20 * S, rw - 44 * S, 1, R.cizgiSoluk)
     for i, s in ipairs(satirlar) do
          local yy = y0 + (30 + (i - 1) * 44) * S
          SG.Ikon(s[1], 20 * S, yy, 32 * S)
          SG.Yazi(SG.Sayi(s[2]), SG.F(19 * S, "orta"), 62 * S, yy + 1 * S, R.fildisiAcik)
          SG.Yazi(s[3], SG.F(12 * S, "govde"), 62 * S, yy + 21 * S, R.soluk)
     end
end

vgui.Register("SardonGacha.Magaza", PANEL, "EditablePanel")

/*
*   Shine Store sayfası (yer tutucu; eklenti kancayla doldurur)
*/
local STORE = {}

function STORE:Init()
     self.dolu = hook.Run("SardonShineStoreSayfa", self) == true
     if self.dolu then return end
     self.ac = self:Add("DButton")
     self.ac:SetText("")
     self.ac.DoClick = function()
          local k = SG.Ayar.storeKomut
          if not (isstring(k) and concommand.GetTable()[k]) then return end
          SG.Cal("tik")
          if IsValid(ix.gui.menu) then ix.gui.menu:Remove() end
          RunConsoleCommand(k)
     end
     self.ac.Paint = function(b, w, h)
          local R = SG.R
          local var = SG.StoreVar()
          SG.Hap(0, 0, w, h, var and (b:IsHovered() and Color(250, 242, 220) or R.krem) or Color(60, 62, 56), var and R.altin or nil)
          SG.Yazi(var and "Mağazayı aç" or "Henüz açılmadı", SG.F(h * 0.36, "orta"), w / 2, h / 2, var and R.kremKoyu or R.soluk, 1, 1)
     end
end

function STORE:PerformLayout(w, h)
     if self.dolu or not IsValid(self.ac) then return end
     local S = math.min(w / 1360, h / 860)
     self.S = S
     self.ac:SetSize(260 * S, 52 * S)
     self.ac:SetPos(w / 2 - 130 * S, h / 2 + 96 * S)
end

function STORE:Paint(w, h)
     if self.dolu then return end
     local S, R = self.S or 1, SG.R
     local kw, kh = 760 * S, 360 * S
     local x, y = w / 2 - kw / 2, h / 2 - kh / 2 - 20 * S
     SG.Kutu(x, y, kw, kh, Color(8, 13, 11, 215))
     SG.Cerceve(x, y, kw, kh, R.cizgi)
     SG.Koseler(x - 4 * S, y - 4 * S, kw + 8 * S, kh + 8 * S, 18 * S, R.altin)
     SG.Parilti(w / 2, y + 70 * S, 260 * S, 160 * S, R.altin, 50)
     SG.Ikon("adak", w / 2 - 34 * S, y + 36 * S, 68 * S)
     SG.Yazi("S H I N E   S T O R E", SG.F(13 * S, "orta"), w / 2, y + 124 * S, R.altin, 1)
     SG.Yazi("Yakında", SG.F(46 * S, "baslik"), w / 2, y + 146 * S, R.fildisiAcik, 1)
     local satir = SG.Sar("Shine Store mağazası bu sekmeye eklenecek. O zamana kadar asa dileği için soldaki Gacha sayfasını kullanabilirsin.", SG.F(17 * S), kw - 120 * S)
     for i, s in ipairs(satir) do
          SG.Yazi(s, SG.F(17 * S), w / 2, y + (214 + (i - 1) * 24) * S, R.govde, 1)
     end
end

vgui.Register("SardonGacha.Store", STORE, "EditablePanel")

/*
*   TAB menü kaydı ([sardon] ui cl_menu.lua PopulateTabs: CreateMenuButtons sonrası bu kanca)
*/
hook.Add("SardonMenuSekmeleri", "SardonGacha", function(tabs)
     tabs["!!shinestore"] = {
          hoswarsIcon = "icon_inventory",
          bHideBackground = true,
          Create = function(info, container)
               local p = container:Add("SardonGacha.Magaza")
               p:SetSize(container:GetSize())
          end,
          OnSelected = function(info, container)
               SG.DurumIste()
          end,
     }
end)

local function DilEkle()
     for dil in pairs(ix.lang.stored or {}) do
          ix.lang.AddTable(dil, { ["!!shinestore"] = "Shine Store" })
     end
end
DilEkle()

concommand.Add("sardon_gacha", function()
     -- TAB menüsünü Shine Store sekmesinde aç
     if IsValid(ix.gui.menu) then ix.gui.menu:Remove() end
     local menu = vgui.Create("ixMenu")
     timer.Simple(0, function()
          if not IsValid(menu) or not menu.tabs then return end
          for _, b in ipairs(menu.tabs.buttons or {}) do
               if b.name == "!!shinestore" then b:OnMousePressed(MOUSE_LEFT) break end
          end
     end)
end, nil, "Asa Dileği (TAB › Shine Store) sekmesini açar.")
