-- "addons\\sardonogrenci\\lua\\sardon_ogrenci\\cl_9magaza.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Öğrenci :: Madam Malkin dükkânının "Cüppe & Kıyafet" bölümü (istemci). Dükkân [sardon] aksesuar
-- cl_2magaza.lua'dır; bu bölüm "SardonMagazaBolumleri" kancasıyla eklenir ve dükkânın içerik alanını doldurur.
-- Sol: arama + yuva kategorileri + "yalnız bana uyanlar"; orta: kartlar; sağ: karakterin üstünde deneme, renk seçimi
-- (kalıcı; sunucu sv_5magaza.lua), satın alma. Tema [sardon] karakter'den (SardonKarakter.*).
local O = SardonOgrenci

local SK, S

local function TemaHazir()
     SK = SardonKarakter
     S = SK and SK.S
     return SK ~= nil and SK.PanelCiz ~= nil
end

local function Sigdir(metin, font, w)
     surface.SetFont(font)
     if surface.GetTextSize(metin) <= w then return metin end

     local kisa = metin
     while utf8.len(kisa) and utf8.len(kisa) > 1 do
          kisa = kisa:sub(1, utf8.offset(kisa, 0, #kisa) - 1) -- son harfi at (GMod'da offset(s, -1) son bayttan başlar)
          if surface.GetTextSize(kisa .. "…") <= w then return kisa .. "…" end
     end

     return "…"
end

local rozetZemin = Color(16, 26, 20, 240)

local function Rozet(metin, x, y, sag, renk)
     local f = SK.Font(10, 600)
     surface.SetFont(f)
     local tw, th = surface.GetTextSize(metin)
     local bw, bh = tw + S(10), th + S(4)
     if sag then x = x - bw end

     surface.SetDrawColor(rozetZemin)
     surface.DrawRect(x, y, bw, bh)
     surface.SetDrawColor(renk or SK.Renk.birincilKenar)
     surface.DrawOutlinedRect(x, y, bw, bh, 1)
     draw.SimpleText(metin, f, x + bw / 2, y + bh / 2, renk or SK.Renk.altinParlak, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local kartZemin = Color(12, 19, 16, 235)
local kartIc = Color(7, 12, 10, 200)
local soluk = Color(255, 255, 255, 90)

-- seçilen yuvaya göre önizleme kamerası: {yakınlık, yükseklik, yön}
local KAMERA = {
     hat = {0.45, 0, 25}, face = {0.42, 0, 15}, scarf = {0.6, 0, 25}, robe = {1, 0, 200}, upper = {0.8, 0, 25},
     hands = {0.75, -6, 40}, lower = {0.8, -14, 25}, socks = {0.6, -28, 25}, shoes = {0.6, -28, 30},
}

----------------------------------------------------------------------------------------
-- Kart
----------------------------------------------------------------------------------------
local KART = {}

function KART:Init()
     self:SetText("")
end

function KART:Kur(id, bolum)
     self.id = id
     self.bolum = bolum
     self.g = O.Giysi[id]
     self.ad = nil
     self.uyar = bolum.cins == nil or O.GiysiParcaKimligi(id, bolum.cins) ~= nil
     local p = O.GiysiParcasi(id, bolum.cins or "m") or O.GiysiHerhangi(id)
     self.renkSayi = p and #p.looks or 1
     self:SetTooltip(self.g.ad .. "\n" .. (O.SlotAd[self.g.slot] or self.g.slot) .. (self.renkSayi > 1 and ("  ·  " .. self.renkSayi .. " colores") or ""))
end

function KART:Paint(w, h)
     local R = SK.Renk
     local b = self.bolum
     local secili = b.secili ~= nil and b.secili.id == self.id
     local hover = self:IsHovered()
     local ikonB = math.max(S(24), math.min(w - S(24), h - S(56)))

     surface.SetDrawColor(kartZemin)
     surface.DrawRect(0, 0, w, h)
     surface.SetDrawColor(kartIc)
     surface.DrawRect(S(6), S(5), w - S(12), ikonB + S(6))

     if secili then
          surface.SetDrawColor(164, 141, 57, 40)
          surface.DrawRect(1, 1, w - 2, h - 2)
     elseif hover then
          surface.SetDrawColor(203, 169, 91, 18)
          surface.DrawRect(1, 1, w - 2, h - 2)
     end

     surface.SetDrawColor(secili and R.yuvaSecili or (hover and R.altin or R.yuvaKenar))
     surface.DrawOutlinedRect(0, 0, w, h, 1)

     -- seçiliyse seçilen renk, değilse ilk renk
     local m = O.GiysiIkonu(self.id, b.cins, secili and b.secili.l or 1)
     if m then
          surface.SetMaterial(m)
          surface.SetDrawColor(self.uyar and color_white or soluk)
          surface.DrawTexturedRect((w - ikonB) / 2, S(8), ikonB, ikonB)
     end

     local f = SK.Font(12, 600)
     self.ad = self.ad or Sigdir(self.g.ad, f, w - S(14))
     draw.SimpleText(self.ad, f, w / 2, h - S(34), self.uyar and R.beyaz or R.soluk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

     local fiyat = O.Fiyat(self.id)
     local yazi, renk
     if not self.uyar then
          yazi, renk = b.cins == "f" and "Solo chicos" or "Solo chicas", R.kilit
     elseif fiyat <= 0 then
          yazi, renk = "Gratis", R.basari
     else
          yazi, renk = O.ParaYazi(fiyat), (b.para or 0) >= fiyat and R.altin or R.kilit
     end
     draw.SimpleText(yazi, SK.Font(12), w / 2, h - S(16), renk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

     if self.renkSayi > 1 then
          draw.SimpleText(self.renkSayi .. " colores", SK.Font(10), S(11), S(8) + ikonB - S(4), R.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
     end
     return true
end

function KART:PaintOver(w, h)
     local b = self.bolum
     if O.Magaza.Yeni[self.id] then Rozet("NUEVO", S(6), S(6)) end

     local n = b.sahip[self.id]
     if n then Rozet(n > 1 and ("Tuyo ×" .. n) or "Tuyo", w - S(6), S(6), true, SK.Renk.basari) end
end

function KART:DoClick()
     self.bolum:Sec(self.id)
end

function KART:DoDoubleClick()
     self.bolum:Sec(self.id)
     self.bolum:SatinAlSor()
end

vgui.Register("SardonOgrenci.MagazaKart", KART, "DButton")

----------------------------------------------------------------------------------------
-- Renk karosu (seçili kıyafetin bir görünümü)
----------------------------------------------------------------------------------------
local KARO = {}

function KARO:Init()
     self:SetText("")
end

function KARO:Paint(w, h)
     local R = SK.Renk
     local b = self.bolum
     local s = b.secili
     if not s then return true end
     local secili = s.l == self.l
     local hover = self:IsHovered()

     surface.SetDrawColor(kartIc)
     surface.DrawRect(0, 0, w, h)

     local m = O.GiysiIkonu(s.id, b.cins, self.l)
     if m then
          surface.SetMaterial(m)
          surface.SetDrawColor(color_white)
          surface.DrawTexturedRect(2, 2, w - 4, h - 4)
     end

     surface.SetDrawColor(secili and R.yuvaSecili or (hover and R.altin or R.yuvaKenar))
     surface.DrawOutlinedRect(0, 0, w, h, secili and 2 or 1)

     if b.sahip[s.id .. "#" .. self.l] then
          draw.RoundedBox(3, w - S(10), S(3), S(7), S(7), R.basari)
     end
     return true
end

function KARO:DoClick()
     self.bolum:RenkSec(self.l)
end

vgui.Register("SardonOgrenci.MagazaRenk", KARO, "DButton")

----------------------------------------------------------------------------------------
-- Bölüm
----------------------------------------------------------------------------------------
local BOLUM = {}

function BOLUM:Init()
     TemaHazir()
     self.kategori = "tumu"
     self.yalnizUyan = true
     self.cins = O.YerelCins()
     self.kullanabilir = O.KiyafetKullanabilir()
     self.sahip = O.SahipSayilari()
     self.para = 0
     self.kartlar = {}
     self.bekleyen, self.bekleyenNo = {}, 1

     self.arama = SK.AramaKutusu(self, "Buscar ropa…")
     self.arama.OnValueChange = function() self.yenile = RealTime() + 0.15 end

     self.kategoriler = self:Add("Panel")
     self:KategorileriKur()

     -- cinsiyet süzgeci (öğrenci görünümü yoksa cinsiyet bilinmez: hepsi gösterilir)
     self.uyan = self:Add("DButton")
     self.uyan:SetText("")
     self.uyan:SetTooltip("Si está desactivado, también se ven prendas del otro género (no se pueden comprar).")
     self.uyan.Paint = function(this, w, h)
          local R = SK.Renk
          local acik = self.yalnizUyan and self.cins ~= nil
          local hover = this:IsHovered() and self.cins ~= nil
          local b = S(16)
          local y = (h - b) / 2
          surface.SetDrawColor(12, 19, 16)
          surface.DrawRect(S(4), y, b, b)
          surface.SetDrawColor(hover and R.altinParlak or R.altin)
          surface.DrawOutlinedRect(S(4), y, b, b, 1)
          if acik then
               surface.SetDrawColor(R.altinParlak)
               surface.DrawRect(S(8), y + S(4), b - S(8), b - S(8))
          end
          draw.SimpleText("Solo lo que me vale", SK.Font(12), S(28), h / 2, self.cins and (hover and R.altinParlak or R.beyaz) or R.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          return true
     end
     self.uyan.DoClick = function()
          if not self.cins then return end
          self.yalnizUyan = not self.yalnizUyan
          self.sayilar = nil
          self:Doldur()
          surface.PlaySound("ui/buttonrollover.wav")
     end

     self.izgara = self:Add("DScrollPanel")
     local vbar = self.izgara:GetVBar()
     vbar:SetWide(S(5))
     vbar:SetHideButtons(true)
     vbar.Paint = function() end
     vbar.btnGrip.Paint = function(this, w, h)
          surface.SetDrawColor(SK.Renk.altinSoluk)
          surface.DrawRect(0, 0, w, h)
     end

     self.duzen = self.izgara:Add("DIconLayout")
     self.duzen:Dock(TOP)
     self.duzen:DockMargin(0, 0, S(10), 0)
     self.duzen:SetSpaceX(S(10))
     self.duzen:SetSpaceY(S(10))

     if vgui.GetControlTable("SardonKarakter.Model") then
          self.model = self:Add("SardonKarakter.Model")
          -- Madam Malkin açılış görünümü ([sardon] aksesuar cl_2magaza.lua)
          if SardonAksesuar and SardonAksesuar.MagazaKamera then SardonAksesuar.MagazaKamera(self.model) end
     else
          self.model = self:Add("DModelPanel")
          self.model:SetModel(LocalPlayer():GetModel())
          self.model:SetFOV(30)
     end

     self.bilgi = self:Add("Panel")
     self.bilgi.Paint = function(this, w, h) self:BilgiCiz(w, h) end

     self.renkler = self:Add("DScrollPanel")
     local rbar = self.renkler:GetVBar()
     rbar:SetWide(S(4))
     rbar:SetHideButtons(true)
     rbar.Paint = function() end
     rbar.btnGrip.Paint = function(this, w, h)
          surface.SetDrawColor(SK.Renk.altinSoluk)
          surface.DrawRect(0, 0, w, h)
     end
     self.renkDuzen = self.renkler:Add("DIconLayout")
     self.renkDuzen:Dock(TOP)
     self.renkDuzen:DockMargin(0, 0, S(6), 0)
     self.renkDuzen:SetSpaceX(S(6))
     self.renkDuzen:SetSpaceY(S(6))

     self.al = SK.Dugme(self, "Comprar", "birincil", "coins")
     self.al.DoClick = function() self:SatinAlSor() end

     self:Doldur()
end

local function kategoriIkonCiz(k, x, y, b, renk)
     if k.slot then
          O.YuvaIkonCiz(k.slot, x, y, b, renk)
     else
          SK.IkonCiz(k.ikon, x, y, b, renk)
     end
end

-- Kategoriler: Tümü, (Yeni gelenler), her yuva (baştan ayağa), Sende olanlar
function BOLUM:KategorileriKur()
     self.kategoriler:Clear()

     local liste = {{id = "tumu", ad = "Todo", ikon = "sparkle"}}
     if next(O.Magaza.Yeni) then liste[#liste + 1] = {id = "yeni", ad = "Novedades", ikon = "star"} end
     for _, slot in ipairs(O.YuvaSira) do
          liste[#liste + 1] = {id = slot, ad = O.SlotKategori[slot] or slot, slot = slot}
     end
     liste[#liste + 1] = {id = "sende", ad = "Lo que tienes", ikon = "bag"}

     for _, k in ipairs(liste) do
          local b = self.kategoriler:Add("DButton")
          b:SetText("")
          b:Dock(TOP)
          b:SetTall(S(38))
          b:DockMargin(0, 0, 0, S(5))
          b.k = k
          b.Paint = function(this, w, h)
               local R = SK.Renk
               local secili = self.kategori == this.k.id
               SK.SegmentCiz(this, w, h, secili)
               kategoriIkonCiz(this.k, S(12), (h - S(16)) / 2, S(16), secili and R.altinParlak or R.altin)
               draw.SimpleText(this.k.ad, SK.Font(13), S(38), h / 2, secili and R.altinParlak or R.beyaz, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               draw.SimpleText(self:KategoriSayisi(this.k.id), SK.Font(11), w - S(12), h / 2, R.soluk, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
               return true
          end
          b.DoClick = function(this)
               if self.kategori == this.k.id then return end
               self.kategori = this.k.id
               self:Doldur()
               surface.PlaySound("ui/buttonrollover.wav")
          end
     end
end

function BOLUM:Uyar(id, sorgu, kategori)
     local g = O.Giysi[id]
     kategori = kategori or self.kategori

     if kategori == "sende" then
          if not self.sahip[id] then return false end
     else
          if not O.Satilik(id) then return false end
          if kategori == "yeni" then
               if not O.Magaza.Yeni[id] then return false end
          elseif kategori ~= "tumu" and g.slot ~= kategori then
               return false
          end
     end

     if self.yalnizUyan and self.cins and not O.GiysiParcaKimligi(id, self.cins) then return false end
     return sorgu == "" or SK.Kucuk(g.ad):find(sorgu, 1, true) ~= nil or id:find(sorgu, 1, true) ~= nil
end

function BOLUM:KategoriSayisi(k)
     self.sayilar = self.sayilar or {}
     local imza = table.Count(self.sahip)
     local c = self.sayilar[k]
     if c and c[1] == imza then return c[2] end

     local n = 0
     for _, id in ipairs(O.GiysiSira) do
          if self:Uyar(id, "", k) then n = n + 1 end
     end
     self.sayilar[k] = {imza, n}
     return n
end

local yuvaSira = {}
for i, slot in ipairs(O.YuvaSira) do yuvaSira[slot] = i end

function BOLUM:Liste()
     local sorgu = SK.Kucuk(string.Trim(self.arama:GetText() or ""))
     local t = {}
     for _, id in ipairs(O.GiysiSira) do
          if self:Uyar(id, sorgu) then t[#t + 1] = id end
     end

     local yeni = O.Magaza.Yeni
     table.sort(t, function(a, b)
          local ya, yb = yeni[a] == true, yeni[b] == true
          if ya ~= yb then return ya end
          local sa, sb = yuvaSira[O.Giysi[a].slot] or 99, yuvaSira[O.Giysi[b].slot] or 99
          if sa ~= sb then return sa < sb end
          return SK.Kucuk(O.Giysi[a].ad) < SK.Kucuk(O.Giysi[b].ad)
     end)
     return t
end

-- büyük listede donmasın diye kartlar kare kare eklenir (Think)
function BOLUM:Doldur()
     self.duzen:Clear()
     self.kartlar = {}
     self.bekleyen, self.bekleyenNo = self:Liste(), 1
     self.bosListe = #self.bekleyen == 0
     self.izgara:GetVBar():SetScroll(0)
end

function BOLUM:Sec(id)
     if self.secili and self.secili.id == id then return end
     self.secili = {id = id, l = 1}
     self:RenkleriKur()

     local m = self.model
     local k = KAMERA[O.Giysi[id].slot]
     if IsValid(m) and m.hedefYaw and k then
          m.hedefYakinlik, m.yukseklik, m.hedefYaw = k[1], k[2], k[3]
     end
end

function BOLUM:RenkSec(l)
     if not self.secili then return end
     self.secili.l = l
     surface.PlaySound("ui/buttonrollover.wav")
end

function BOLUM:RenkleriKur()
     self.renkDuzen:Clear()
     local s = self.secili
     local p = s and (O.GiysiParcasi(s.id, self.cins or "m") or O.GiysiHerhangi(s.id))
     if not p or #p.looks <= 1 then return end

     local b = self.karoB or S(40)
     for i = 1, #p.looks do
          local k = self.renkDuzen:Add("SardonOgrenci.MagazaRenk")
          k:SetSize(b, b)
          k.bolum = self
          k.l = i
          k:SetTooltip(O.RenkAdi(p, i) .. (O.HaneRengiMi(p, i) and "  (se tiñe con el color de la casa)" or ""))
     end
     self.renkler:GetVBar():SetScroll(0)
end

function BOLUM:SatinAlSor()
     local s = self.secili
     local m = self.magaza
     if not s or not IsValid(m) then return end

     if not self.kullanabilir then
          m:Bildirim("La ropa de estudiante se usa con aspecto de estudiante (primero /Gorunum).", true)
          return
     end

     local p = self.cins and O.GiysiParcasi(s.id, self.cins)
     if not p then
          m:Bildirim("Esta prenda no tiene una forma que te valga.", true)
          return
     end

     local fiyat = O.Fiyat(s.id)
     if fiyat > (self.para or 0) then
          m:Bildirim("No tienes suficientes Galeones.", true)
          return
     end

     local renk = #p.looks > 1 and O.RenkAdi(p, s.l) or ""
     local ad = O.Giysi[s.id].ad .. (renk ~= "" and (" (" .. renk .. ")") or "")
     local metin = "¿Quieres comprar " .. ad .. " por " .. O.ParaYazi(fiyat) .. "?"
     if #p.looks > 1 then metin = metin .. "\n\nEl color no se puede cambiar después." end
     if self.sahip[s.id .. "#" .. s.l] then metin = metin .. "\nYa tienes este color." end

     local id, l = s.id, s.l
     m:Onay("Comprar", metin, function()
          net.Start("SardonOgrenci.SatinAl")
               net.WriteString(id)
               net.WriteUInt(l, 8)
          net.SendToServer()
     end, "Comprar")
end

-- dükkân ve gardırop önizlemesi: deneme {id, l} karakterin üstünde, o yuvadakinin yerine
function BOLUM:Dene(dn)
     local ent = IsValid(self.model) and self.model.Entity
     if not IsValid(ent) then return end

     local pid = dn and self.cins and O.GiysiParcaKimligi(dn.id, self.cins)
     local p = pid and O.GiysiParcasi(dn.id, self.cins)
     if p then
          local l = math.Clamp(dn.l or 1, 1, #p.looks)
          local eski = ent.sogDeneme
          if not eski or eski.piece ~= pid or eski.look ~= l then ent.sogDeneme = {slot = p.slot, piece = pid, look = l} end
     elseif ent.sogDeneme then
          ent.sogDeneme = nil
     end
end

function BOLUM:Think()
     local simdi = RealTime()

     if self.yenile and simdi >= self.yenile then
          self.yenile = nil
          self:Doldur()
     end

     for _ = 1, 12 do
          local id = self.bekleyen[self.bekleyenNo]
          if not id then break end
          self.bekleyenNo = self.bekleyenNo + 1

          local k = self.duzen:Add("SardonOgrenci.MagazaKart")
          k:SetSize(self.kartW or S(150), self.kartH or S(196))
          k:Kur(id, self)
          self.kartlar[#self.kartlar + 1] = k
     end

     if (self.sahipZamani or 0) < simdi then
          self.sahipZamani = simdi + 0.5
          self.sahip = O.SahipSayilari()
          local char = LocalPlayer():GetCharacter()
          self.para = char and char:GetMoney() or 0
     end

     -- fareyle üstüne gelinen renk ya da kart, yoksa seçili kıyafet karakterin üstünde denenir
     local hover = vgui.GetHoveredPanel()
     local dn
     self.hoverL = nil
     while IsValid(hover) and hover ~= self do
          if hover.bolum == self then
               if hover.l and self.secili then
                    dn = {id = self.secili.id, l = hover.l}
                    self.hoverL = hover.l
                    break
               elseif hover.id then
                    dn = {id = hover.id, l = (self.secili and self.secili.id == hover.id) and self.secili.l or 1}
                    break
               end
          end
          hover = hover:GetParent()
     end
     self:Dene(dn or self.secili)

     local s = self.secili
     local fiyat = s and O.Fiyat(s.id) or 0
     local uyar = s ~= nil and self.cins ~= nil and O.GiysiParcaKimligi(s.id, self.cins) ~= nil
     self.al:SetDisabled(not s or not self.kullanabilir or not uyar or fiyat > (self.para or 0))
     self.al.metin = s and (fiyat > 0 and ("Comprar · " .. O.ParaYazi(fiyat)) or "Obtener gratis") or "Comprar"
end

function BOLUM:BilgiCiz(w, h)
     local R = SK.Renk

     if not self.kullanabilir then
          draw.SimpleText("Ropa de estudiante", SK.Font(17, 400, true), w / 2, S(18), Color(200, 196, 178), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          draw.SimpleText("se usa con aspecto de estudiante: primero /Gorunum.", SK.Font(12), w / 2, S(44), R.soluk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          return
     end

     local s = self.secili
     if not s then
          draw.SimpleText("Elige una prenda", SK.Font(17, 400, true), w / 2, S(18), Color(200, 196, 178), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          draw.SimpleText("Pasar: probar  ·  Clic: elegir  ·  Doble clic: comprar", SK.Font(11), w / 2, S(44), R.soluk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          draw.SimpleText("El color se elige al comprar y no cambia después.", SK.Font(11), w / 2, S(64), R.soluk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          return
     end

     local g = O.Giysi[s.id]
     local p = O.GiysiParcasi(s.id, self.cins or "m") or O.GiysiHerhangi(s.id)
     local baslik = SK.Font(19, 400, true)
     local y = 0
     draw.SimpleText(Sigdir(g.ad, baslik, w), baslik, 0, y, Color(234, 214, 170))
     y = y + S(28)

     draw.SimpleText((O.SlotAd[g.slot] or g.slot) .. (p and #p.looks > 1 and ("  ·  " .. #p.looks .. " colores") or ""), SK.Font(12), 0, y, R.altin)
     y = y + S(20)

     local l = self.hoverL or s.l
     if p and #p.looks > 1 then
          local ad = O.RenkAdi(p, l)
          if O.HaneRengiMi(p, l) then ad = ad .. "  (color de la casa)" end
          draw.SimpleText(Sigdir("Color: " .. ad, SK.Font(12), w), SK.Font(12), 0, y, R.beyaz)
          y = y + S(20)
     end

     if self.cins and not O.GiysiParcaKimligi(s.id, self.cins) then
          draw.SimpleText(self.cins == "f" and "Solo la pueden llevar estudiantes chicos." or "Solo la pueden llevar estudiantes chicas.", SK.Font(12), 0, y, R.kilit)
     elseif self.sahip[s.id .. "#" .. l] then
          draw.SimpleText("Ya tienes este color.", SK.Font(12), 0, y, R.basari)
     elseif self.sahip[s.id] then
          draw.SimpleText("Ya tienes otro color de esta prenda.", SK.Font(12), 0, y, R.soluk)
     end
end

function BOLUM:PerformLayout(w, h)
     local solW = S(220)
     local sagW = math.floor(w * 0.29)
     local ortaX = solW + S(18)
     local ortaW = w - solW - sagW - S(36)

     self.arama:SetPos(0, 0)
     self.arama:SetSize(solW, S(38))
     local uyanH = S(32)
     self.kategoriler:SetPos(0, S(50))
     self.kategoriler:SetSize(solW, math.max(0, h - S(50) - uyanH - S(8)))
     self.uyan:SetPos(0, h - uyanH)
     self.uyan:SetSize(solW, uyanH)

     self.izgara:SetPos(ortaX, 0)
     self.izgara:SetSize(ortaW, h)

     local bosluk = S(10)
     local sutun = math.max(2, math.floor((ortaW - S(16) + bosluk) / (S(150) + bosluk)))
     local kartW = math.floor((ortaW - S(16) - bosluk * (sutun - 1)) / sutun)
     self.kartW, self.kartH = kartW, kartW + S(46)
     for _, k in ipairs(self.kartlar) do
          if IsValid(k) then k:SetSize(self.kartW, self.kartH) end
     end

     local sagX = w - sagW
     local dugmeH = S(42)
     local modelH = math.floor(h * 0.5)
     local bilgiH = S(94)
     self.model:SetPos(sagX, 0)
     self.model:SetSize(sagW, modelH)
     self.bilgi:SetPos(sagX, modelH + S(8))
     self.bilgi:SetSize(sagW, bilgiH)

     local renkY = modelH + S(8) + bilgiH
     self.renkler:SetPos(sagX, renkY)
     self.renkler:SetSize(sagW, math.max(0, h - renkY - dugmeH - S(10)))

     local karoB = math.Clamp(math.floor((sagW - S(10) - S(6) * 7) / 8), S(28), S(48))
     if karoB ~= self.karoB then
          self.karoB = karoB
          for _, k in ipairs(self.renkDuzen:GetChildren()) do k:SetSize(karoB, karoB) end
     end

     self.al:SetPos(sagX, h - dugmeH)
     self.al:SetSize(sagW, dugmeH)
end

function BOLUM:Paint(w, h)
     if self.bosListe and IsValid(self.izgara) then
          local gx, gy = self.izgara:GetPos()
          draw.SimpleText(self.kategori == "sende" and "Aún no tienes ropa de estudiante." or "No se encontró la prenda que buscas.", SK.Font(15, 400, true), gx + self.izgara:GetWide() / 2, gy + S(60), SK.Renk.soluk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end
end

vgui.Register("SardonOgrenci.MagazaBolum", BOLUM, "EditablePanel")

----------------------------------------------------------------------------------------
-- Dükkâna bölüm olarak eklenme ve satın alma sonucu
----------------------------------------------------------------------------------------
hook.Add("SardonMagazaBolumleri", "SardonOgrenci", function(magaza, liste)
     if not O.Hazir() or not TemaHazir() then return end
     local p = magaza:Add("SardonOgrenci.MagazaBolum")
     p.magaza = magaza
     table.insert(liste, 1, {id = "kiyafet", ad = "TÚNICAS Y ROPA", panel = p, varsayilan = O.KiyafetKullanabilir()})
end)

net.Receive("SardonOgrenci.SatinSonuc", function()
     local basarili, _, _, metin = net.ReadBool(), net.ReadString(), net.ReadUInt(8), net.ReadString()
     if basarili then surface.PlaySound("ambient/levels/labs/coinslot1.wav") end

     local SA = SardonAksesuar
     local m = SA and SA.magaza
     if IsValid(m) then
          m:Bildirim(metin, not basarili)
          local b = m.bolumPanelleri and m.bolumPanelleri.kiyafet
          if IsValid(b) then b.sahipZamani = 0 end
     else
          notification.AddLegacy(metin, basarili and NOTIFY_GENERIC or NOTIFY_ERROR, 4)
     end
end)
