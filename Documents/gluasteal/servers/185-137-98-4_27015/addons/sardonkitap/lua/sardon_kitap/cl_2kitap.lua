-- "addons\\sardonkitap\\lua\\sardon_kitap\\cl_2kitap.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kitap :: kitap ekranı (iki sayfa)
--   Sol sayfa: kapak bilgisi, sahip/hane, içindekiler (okundu ✓, yarım %), dünyaya bağlı bölümler, sınav.
--   Sağ sayfa: bölüm metni + sayfa çevirme, okuma ilerlemesi (sunucu sayar), rün çizimi, kenar notları
--   (el yazısı, sağ kenar sütunu); dinamik listeler ve ayrıntı sayfaları; yıl sonu sınavı.
--   Tıklanabilir alanlar her karede Paint içinde yeniden kurulur (self.alanlar); çizim ve not girişi alt panel.

local SK = SardonKitap
local R = SK.R

SK.Ilerleme = SK.Ilerleme or {}
SK.NotVeri = SK.NotVeri or {}

local function Char() return IsValid(LocalPlayer()) and LocalPlayer():GetCharacter() or nil end

-- elde açık kitabın sayfası da çevrilir / yazma duruşu ([sardon] anims sh_kitap.lua)
local function Anim(ne, a)
     local KA = SardonKitapAnim
     if KA and KA.Iste then KA.Iste(ne, a) end
end

local DURUM_METIN = {
     okuyor = {"Okunuyor", R.murekkepK},
     hizli = {"Okunuyor · burası okumaya elverişli, iki kat hızlı", R.iyi},
     yuruyor = {"Yürürken okuyamazsın; dur ve oku", R.uyari},
     kitapyok = {"Kitap artık sende değil", R.kotu},
}

local PANEL = {}

function PANEL:Init()
     SK.Fontlar()
     self:SetSize(ScrW(), ScrH())
     self:SetPos(0, 0)
     self:MakePopup()
     self.acilis = CurTime()
     self.alanlar = {}
     self.tocKaydir = 0
     self.secim = {tur = "giris"}
     surface.PlaySound("physics/cardboard/cardboard_box_impact_soft2.wav")
end

function PANEL:Geometri()
     local W = math.min(SK.S(1260), ScrW() - 40)
     local H = math.min(SK.S(780), ScrH() - 40)
     self.bx, self.by, self.bw, self.bh = math.floor((ScrW() - W) / 2), math.floor((ScrH() - H) / 2), W, H
     local k = SK.S(18)
     self.pw = math.floor((W - k * 2) / 2)
     self.ph = H - k * 2
     self.lx, self.ly = self.bx + k, self.by + k
     self.rx, self.ry = self.lx + self.pw, self.ly
     self.pad = SK.S(34)
end

function PANEL:Kur(v)
     self.veri = v
     self.k = SK.Kitap[v.kitap]
     self:Geometri()
     if v.bolum and v.bolum ~= "" then
          local _, i = SK.BolumBul(v.kitap, v.bolum)
          if i then return self:BolumAc(i) end
     end
     if not self.secim or self.secim.tur == "giris" then self.secim = {tur = "giris"} end
end

function PANEL:OkumaDurdur()
     if self.okunan then
          net.Start("SardonKitap.OkuDur") net.SendToServer()
          self.okunan = nil
     end
end

function PANEL:CizimKapat()
     if IsValid(self.cizim) then self.cizim:Remove() end
     self.cizim = nil
end

function PANEL:NotKapat()
     if IsValid(self.notGiris) then
          self.notGiris:Remove()
          Anim("yaz", false)
     end
     self.notGiris = nil
end

function PANEL:BolumAc(i)
     local liste = SK.Bolumler(self.k.id)
     local b = liste[i]
     if not b then return end
     self:CizimKapat()
     self:NotKapat()
     local onceki = self.secim and self.secim.tur == "bolum" and self.secim.i or 0
     self.secim = {tur = "bolum", i = i, sayfa = 1}
     surface.PlaySound("physics/cardboard/cardboard_box_impact_soft" .. math.random(1, 3) .. ".wav")
     Anim("cevir", i >= onceki)
     local char = Char()
     local key = SK.Anahtar(self.k.id, b.id)
     if self.okunan ~= key then self:OkumaDurdur() end
     if char and not SK.Okundu(char, self.k.id, b.id) and self.veri.egil == "" and not self.okunan then
          net.Start("SardonKitap.OkuBasla")
          net.WriteString(self.k.id)
          net.WriteString(b.id)
          net.SendToServer()
          self.okunan = key
     end
end

function PANEL:Kapat()
     self:OkumaDurdur()
     self:CizimKapat()
     self:NotKapat()
     SK.Acik = nil
     self:Remove()
end

function PANEL:OnKeyCodePressed(k)
     if k == KEY_ESCAPE or k == KEY_TAB then return self:Kapat() end
     local s = self.secim
     if s.tur == "bolum" then
          local b = SK.Bolumler(self.k.id)[s.i]
          if not b then return end
          if (k == KEY_RIGHT or k == KEY_D) and s.sayfa < #b.sayfalar then s.sayfa = s.sayfa + 1 surface.PlaySound("physics/cardboard/cardboard_box_impact_soft1.wav") Anim("cevir", true) end
          if (k == KEY_LEFT or k == KEY_A) and s.sayfa > 1 then s.sayfa = s.sayfa - 1 surface.PlaySound("physics/cardboard/cardboard_box_impact_soft1.wav") Anim("cevir", false) end
     end
end

function PANEL:OnMouseWheeled(d)
     local mx = self:CursorPos()
     if mx < self.rx then self.tocKaydir = math.max(0, self.tocKaydir - d * SK.S(30)) end
end

function PANEL:Alan(x, y, w, h, fn)
     self.alanlar[#self.alanlar + 1] = {x, y, w, h, fn}
     return SK.Ustunde(self, x, y, w, h)
end

function PANEL:OnMousePressed(k)
     if k ~= MOUSE_LEFT then return end
     if self.sahne then return end
     local mx, my = self:CursorPos()
     for i = #self.alanlar, 1, -1 do
          local a = self.alanlar[i]
          if mx >= a[1] and mx <= a[1] + a[3] and my >= a[2] and my <= a[2] + a[4] then
               a[5]()
               return
          end
     end
     -- kitabın dışına tıklama kapatır
     if mx < self.bx or mx > self.bx + self.bw or my < self.by or my > self.by + self.bh then self:Kapat() end
end

/*
*   küçük çizim parçaları
*/
local function Tik(x, y, s, c)
     surface.SetDrawColor(c)
     for o = 0, 1 do
          surface.DrawLine(x, y + s * 0.5 + o, x + s * 0.4, y + s + o)
          surface.DrawLine(x + s * 0.4, y + s + o, x + s, y + o)
     end
end

local function Cubuk(x, y, w, h, oran, c)
     SK.Kutu(x, y, w, h, Color(R.kenar.r, R.kenar.g, R.kenar.b, 90))
     SK.Kutu(x, y, math.floor(w * math.Clamp(oran, 0, 1)), h, c)
end

local function Dugme(pnl, x, y, w, h, metin, fn, renk, kapali)
     local ust = (not kapali) and pnl:Alan(x, y, w, h, fn)
     local c = renk or R.altin
     SK.Kutu(x, y, w, h, Color(c.r, c.g, c.b, kapali and 40 or (ust and 90 or 55)))
     surface.SetDrawColor(c.r, c.g, c.b, kapali and 90 or 200)
     surface.DrawOutlinedRect(x, y, w, h, 1)
     SK.Yazi(metin, "etiket", x + w / 2, y + h / 2, kapali and R.soluk or R.murekkep, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

/*
*   sol sayfa: içindekiler
*/
function PANEL:SolSayfa(char)
     local k, v = self.k, self.veri
     local x, y, w = self.lx + self.pad, self.ly + self.pad, self.pw - self.pad * 2
     for _, s in ipairs(SK.Sar(k.ad, "baslik", w)) do
          SK.Yazi(s, "baslik", x, y, R.murekkep)
          y = y + SK.SatirYuk("baslik")
     end
     SK.Yazi(k.en, "italik", x, y + SK.S(2), R.murekkepK)
     y = y + SK.SatirYuk("italik") + SK.S(4)
     SK.Yazi(SK.Buyuk(k.yazar), "ust", x, y, R.altin)
     y = y + SK.S(22)

     local hane = SK.HaneBul(v.hane)
     local sahipMetin = v.egil ~= "" and ("Kitabın sahibi: " .. v.egil .. " · okuman ilerlemez") or ("Sahibi: " .. (v.sahip ~= "" and v.sahip or "?"))
     if hane then
          SK.Kutu(x, y + SK.S(3), SK.S(10), SK.S(10), hane.renk)
          SK.Yazi(sahipMetin .. " · " .. hane.ad, "metinK", x + SK.S(16), y, R.murekkepK)
     else
          SK.Yazi(sahipMetin, "metinK", x, y, R.murekkepK)
     end
     y = y + SK.S(28)
     SK.Kutu(x, y, w, 1, Color(R.kenar.r, R.kenar.g, R.kenar.b, 160))
     y = y + SK.S(12)

     -- satırlar: statik bölümler + dinamik bölümler
     local satirlar = {}
     for i, b in ipairs(SK.Bolumler(k.id)) do satirlar[#satirlar + 1] = {tur = "bolum", i = i, b = b} end
     self.dinamik = SK.DinamikBolumler(k.id, char, v.ek)
     for i, d in ipairs(self.dinamik) do satirlar[#satirlar + 1] = {tur = "dinamik", i = i, d = d} end

     local sinavY = self.ly + self.ph - self.pad - SK.S(36)
     local rh = SK.S(31)
     local alanAlt = (SK.Ayar.sinavAcik and sinavY - SK.S(12)) or (self.ly + self.ph - self.pad)
     local gorunur = math.floor((alanAlt - y) / rh)
     local toplamH = #satirlar * rh
     self.tocKaydir = math.Clamp(self.tocKaydir, 0, math.max(0, toplamH - gorunur * rh))
     local bas = math.floor(self.tocKaydir / rh) + 1

     for n = bas, math.min(#satirlar, bas + gorunur - 1) do
          local s = satirlar[n]
          local ry = y + (n - bas) * rh
          local secili = (s.tur == "bolum" and self.secim.tur == "bolum" and self.secim.i == s.i) or
               (s.tur == "dinamik" and (self.secim.tur == "dinamik" or self.secim.tur == "detay") and self.secim.d == s.i)
          local ust = self:Alan(x - SK.S(6), ry, w + SK.S(12), rh - 2, function()
               if s.tur == "bolum" then self:BolumAc(s.i) else
                    self:OkumaDurdur() self:CizimKapat() self:NotKapat()
                    self.secim = {tur = "dinamik", d = s.i}
                    surface.PlaySound("physics/cardboard/cardboard_box_impact_soft2.wav")
               end
          end)
          if secili or ust then SK.Kutu(x - SK.S(6), ry, w + SK.S(12), rh - 2, Color(R.altin.r, R.altin.g, R.altin.b, secili and 46 or 24)) end

          if s.tur == "bolum" then
               local b = s.b
               local okundu = char and SK.Okundu(char, k.id, b.id)
               if okundu then
                    Tik(x, ry + SK.S(9), SK.S(12), R.iyi)
               else
                    local il = SK.Ilerleme[SK.Anahtar(k.id, b.id)]
                    local bir = il and il.birikim or (char and tonumber((SK.Veri(char).i or {})[SK.Anahtar(k.id, b.id)])) or 0
                    if bir > 0 then
                         SK.Yazi("%" .. math.floor(math.min(99, bir / SK.BolumSure(b) * 100)), "ust", x, ry + SK.S(9), R.uyari)
                    else
                         SK.Kutu(x + SK.S(4), ry + SK.S(13), SK.S(4), SK.S(4), R.soluk)
                    end
               end
               SK.Yazi(b.baslik, "metinK", x + SK.S(28), ry + SK.S(6), R.murekkep)
               if b.buyu and SK.BuyuVar(b.buyu) then
                    local bilir = HpwRewrite and HpwRewrite.PlayerHasSpell and HpwRewrite:PlayerHasSpell(LocalPlayer(), b.buyu)
                    local acemi = char and SK.Acemi(char, b.buyu)
                    local etiket, c = "büyü", R.mavi
                    if acemi then etiket, c = "acemi", R.uyari elseif bilir then etiket, c = "biliyorsun", R.iyi end
                    SK.Yazi(etiket, "ust", x + w, ry + SK.S(9), c, TEXT_ALIGN_RIGHT)
               end
          else
               local d = s.d
               SK.Isik(x + SK.S(6), ry + SK.S(15), SK.S(8), R.altin, 200)
               SK.Yazi(d.baslik, "metinK", x + SK.S(28), ry + SK.S(6), R.murekkep)
               SK.Yazi(d.sayac or "", "ust", x + w, ry + SK.S(9), R.altin, TEXT_ALIGN_RIGHT)
          end
     end
     if #satirlar > gorunur then
          SK.Yazi("tekerlekle kaydır", "ust", x + w, alanAlt - SK.S(2), R.soluk, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
     end

     -- yıl sonu sınavı
     if SK.Ayar.sinavAcik and char then
          local yil = k.yil
          local vt = SK.Veri(char)
          local gecti = istable(vt.sv) and vt.sv[yil]
          local hazir, toplam = 0, 0
          for _, kk in ipairs(SK.YilKitaplari(yil)) do
               for _, b in ipairs(SK.Bolumler(kk.id)) do
                    if b.soru then
                         toplam = toplam + 1
                         if SK.Okundu(char, kk.id, b.id) then hazir = hazir + 1 end
                    end
               end
          end
          -- 11-15: 2-7. yılda tek cilt, 9 sorulu bölüm; gerekli sayı o yılda olandan fazla olamaz (sv_8yil.lua)
          local gerekli = math.min(SK.Ayar.sinavSoru, toplam)
          local metin = gecti and (yil .. ". yıl sınavını geçtin") or (yil .. ". Yıl Sonu Sınavı · " .. math.min(hazir, gerekli) .. "/" .. gerekli .. " bölüm")
          local kapali = gecti or gerekli < 1 or hazir < gerekli or v.egil ~= ""
          Dugme(self, x, sinavY, w, SK.S(32), metin, function()
               net.Start("SardonKitap.Sinav") net.WriteUInt(yil, 4) net.SendToServer()
          end, gecti and R.iyi or R.altin, kapali)
     end
end

/*
*   sağ sayfa
*/
function PANEL:SagGiris(char, x, y, w)
     local k = self.k
     SK.Yazi("İçindekiler'den bir bölüm seç.", "baslikK", x, y, R.murekkep)
     y = y + SK.S(40)
     for _, s in ipairs(SK.Sar(k.ozet, "metin", w)) do
          SK.Yazi(s, "metin", x, y, R.murekkep)
          y = y + SK.SatirYuk("metin")
     end
     y = y + SK.S(16)
     local ipucu = {
          "Bir bölümü açınca okuma başlar; sunucu süreyi sayar. Yürürken okuma durur.",
          "Kütüphanede ve ortak salonlarda okuma iki kat hızlıdır.",
          "Büyü bölümünü bitirince rünü havada çiz: kitap sana yolu gösterir, büyü Büyü Ağacı fiyatının %20 altına öğrenilir ve bir süre acemi kalır.",
          "Sayfanın kenarına not düşebilirsin; kitabı satarsan notlar yeni sahibine kalır.",
     }
     for _, t in ipairs(ipucu) do
          for i, s in ipairs(SK.Sar(t, "metinK", w - SK.S(18))) do
               if i == 1 then SK.Kutu(x, y + SK.S(8), SK.S(5), SK.S(5), R.altin) end
               SK.Yazi(s, "metinK", x + SK.S(18), y, R.murekkepK)
               y = y + SK.SatirYuk("metinK")
          end
          y = y + SK.S(6)
     end
end

function PANEL:Notlar(b, x, y, w, h)
     if not SK.Ayar.notlarAcik then return end
     local seri = self.veri.seri
     local liste = (SK.NotVeri[seri] or {})[b.id] or {}
     SK.Yazi("KENAR", "ust", x, y, R.soluk)
     y = y + SK.S(18)
     local alt = y + h - SK.S(60)
     for _, n in ipairs(liste) do
          local satirlar = SK.Sar(n.metin, "elK", w)
          if y + #satirlar * SK.S(18) + SK.S(16) > alt then
               SK.Yazi("…", "el", x, y, R.mavi)
               break
          end
          for _, s in ipairs(satirlar) do
               SK.Yazi(s, "elK", x, y, Color(40, 60, 110))
               y = y + SK.S(18)
          end
          SK.Yazi("— " .. n.yazar, "ust", x + w, y, R.soluk, TEXT_ALIGN_RIGHT)
          y = y + SK.S(18)
     end
     if self.veri.egil == "" and not IsValid(self.notGiris) and #liste < 6 then
          local ust = self:Alan(x, alt + SK.S(24), w, SK.S(22), function() self:NotAc(b, x, alt, w) end)
          SK.Yazi("+ not düş", "el", x, alt + SK.S(22), ust and R.mavi or Color(70, 90, 140))
     end
end

function PANEL:NotAc(b, x, y, w)
     self:NotKapat()
     local e = vgui.Create("DTextEntry", self)
     e:SetPos(x, y)
     e:SetSize(w, SK.S(56))
     e:SetMultiline(true)
     e:SetFont("sk.elK")
     e:SetPlaceholderText("Notunu yaz, Enter ile kaydet")
     e:SetPaintBackground(false)
     e.Paint = function(s, pw, ph)
          SK.Kutu(0, 0, pw, ph, Color(255, 250, 235, 120))
          surface.SetDrawColor(R.kenar) surface.DrawOutlinedRect(0, 0, pw, ph, 1)
          s:DrawTextEntryText(Color(40, 60, 110), R.altin, Color(40, 60, 110))
     end
     e.OnKeyCodeTyped = function(s, kc)
          if kc == KEY_ESCAPE then self:NotKapat() return true end
          if kc == KEY_ENTER or kc == KEY_PAD_ENTER then
               local metin = string.Trim(s:GetValue())
               if metin ~= "" then
                    net.Start("SardonKitap.NotYaz")
                    net.WriteString(self.k.id)
                    net.WriteString(b.id)
                    net.WriteString(metin)
                    net.SendToServer()
               end
               self:NotKapat()
               return true
          end
     end
     e:RequestFocus()
     self.notGiris = e
     Anim("yaz", true)
end

function PANEL:SagBolum(char, x, y, w)
     local s = self.secim
     local b = SK.Bolumler(self.k.id)[s.i]
     if not b then return end
     local kenarW = SK.Ayar.notlarAcik and SK.S(150) or 0
     local tw = w - kenarW - (kenarW > 0 and SK.S(18) or 0)
     local alt = self.ry + self.ph - self.pad

     SK.Yazi(SK.Buyuk("Bölüm " .. s.i), "ust", x, y, R.altin)
     y = y + SK.S(16)
     for _, sat in ipairs(SK.Sar(b.baslik, "baslik", tw)) do
          SK.Yazi(sat, "baslik", x, y, R.murekkep)
          y = y + SK.SatirYuk("baslik")
     end
     y = y + SK.S(8)
     local metinBas = y
     local durumY = alt - SK.S(118)

     if IsValid(self.cizim) then
          -- çizim alanı metnin yerini alır
          self.cizim:SetPos(x, metinBas)
          self.cizim:SetSize(tw, durumY - metinBas - SK.S(4))
          local ust = self:Alan(x, durumY + SK.S(6), SK.S(130), SK.S(26), function() self:CizimKapat() end)
          SK.Yazi("‹ metne dön", "etiket", x, durumY + SK.S(10), ust and R.altin or R.murekkepK)
     else
          local sayfa = b.sayfalar[s.sayfa] or ""
          local lh = SK.SatirYuk("metin")
          for _, sat in ipairs(SK.Sar(sayfa, "metin", tw)) do
               if y + lh > durumY - SK.S(30) then break end
               SK.Yazi(sat, "metin", x, y, R.murekkep)
               y = y + lh
          end
          -- sayfa çevirme
          if #b.sayfalar > 1 then
               local ny = durumY - SK.S(26)
               local cx = x + tw / 2
               if s.sayfa > 1 then
                    local u = self:Alan(cx - SK.S(70), ny - SK.S(4), SK.S(30), SK.S(24), function() s.sayfa = s.sayfa - 1 surface.PlaySound("physics/cardboard/cardboard_box_impact_soft1.wav") Anim("cevir", false) end)
                    SK.Yazi("‹", "baslikK", cx - SK.S(56), ny + SK.S(8), u and R.altin or R.murekkepK, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               end
               SK.Yazi(s.sayfa .. " / " .. #b.sayfalar, "etiket", cx, ny + SK.S(8), R.murekkepK, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               if s.sayfa < #b.sayfalar then
                    local u = self:Alan(cx + SK.S(40), ny - SK.S(4), SK.S(30), SK.S(24), function() s.sayfa = s.sayfa + 1 surface.PlaySound("physics/cardboard/cardboard_box_impact_soft1.wav") Anim("cevir", true) end)
                    SK.Yazi("›", "baslikK", cx + SK.S(56), ny + SK.S(8), u and R.altin or R.murekkepK, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               end
          end
     end

     -- kenar notları
     if kenarW > 0 then
          local kx = x + w - kenarW
          SK.Kutu(kx - SK.S(10), metinBas, 1, durumY - metinBas, Color(R.kenar.r, R.kenar.g, R.kenar.b, 120))
          self:Notlar(b, kx, metinBas, kenarW, durumY - metinBas)
     end

     -- durum alanı
     SK.Kutu(x, durumY, w, 1, Color(R.kenar.r, R.kenar.g, R.kenar.b, 140))
     local dy = durumY + SK.S(12)
     local okundu = char and SK.Okundu(char, self.k.id, b.id)
     local key = SK.Anahtar(self.k.id, b.id)
     if IsValid(self.cizim) then
          -- yalnız "metne dön" (yukarıda)
     elseif not okundu then
          if self.veri.egil ~= "" then
               SK.Yazi("Bu kitap senin değil; okuman ilerlemez.", "metinK", x, dy, R.murekkepK)
          else
               local il = SK.Ilerleme[key]
               local gerek = il and il.gerek or SK.BolumSure(b)
               local bir = il and il.birikim or (char and tonumber((SK.Veri(char).i or {})[key])) or 0
               if il and (il.durum == "okuyor" or il.durum == "hizli") then
                    bir = math.min(gerek, bir + (CurTime() - il.t) * (il.durum == "hizli" and SK.Ayar.yerCarpani or 1))
               end
               local dm = DURUM_METIN[il and il.durum or ""] or {"Okuma başlıyor…", R.murekkepK}
               SK.Yazi(dm[1], "etiket", x, dy, dm[2])
               SK.Yazi(math.floor(bir) .. " / " .. math.floor(gerek) .. " sn", "etiket", x + w, dy, R.murekkepK, TEXT_ALIGN_RIGHT)
               Cubuk(x, dy + SK.S(24), w, SK.S(8), bir / math.max(1, gerek), R.altin)
               if b.buyu and SK.BuyuVar(b.buyu) then
                    SK.Yazi("Okuyup bitirince " .. b.buyu .. " rününü çizebilirsin.", "metinK", x, dy + SK.S(42), R.murekkepK)
               end
          end
     else
          Tik(x, dy + SK.S(2), SK.S(12), R.iyi)
          SK.Yazi("Bu bölümü okudun.", "etiket", x + SK.S(20), dy, R.iyi)
          if b.buyu and SK.BuyuVar(b.buyu) then
               local bilir = HpwRewrite:PlayerHasSpell(LocalPlayer(), b.buyu)
               local acemi = char and SK.Acemi(char, b.buyu)
               if acemi then
                    SK.Yazi(b.buyu .. " acemi · " .. (tonumber(acemi.n) or 0) .. "/" .. SK.Ayar.acemiKullanim .. " kullanım", "metinK", x, dy + SK.S(30), R.uyari)
                    SK.Yazi("Derste ya da 5. yıl+ bir öğrencinin yanında kullanırsan ustalaşırsın.", "metinK", x, dy + SK.S(54), R.murekkepK)
               elseif bilir then
                    SK.Yazi("Bu büyüyü biliyorsun.", "metinK", x, dy + SK.S(30), R.murekkepK)
               elseif self.veri.egil ~= "" then
                    SK.Yazi("Rünü yalnızca kendi kitabınla çizebilirsin.", "metinK", x, dy + SK.S(30), R.murekkepK)
               else
                    local ode, _, tam = SK.KitapMaliyeti(char, b.buyu)
                    local bedel = ode .. " Büyü Puanı" .. ((tonumber(tam) or 0) > ode and (" · Büyü Ağacı'nda " .. tam) or "")
                    SK.Yazi("Bedel: " .. bedel, "metinK", x, dy + SK.S(30), R.murekkepK)
                    Dugme(self, x, dy + SK.S(58), SK.S(220), SK.S(32), b.buyu .. " rününü çiz", function()
                         -- rün havada çizilir (cl_3cizim): kitap gizlenir, bitince geri gelir
                         self:CizimKapat()
                         if SK.Cizim3BBasla then SK.Cizim3BBasla(self, self.k.id, b.id, b.buyu) end
                    end, R.mavi)
               end
          end
     end
end

function PANEL:SagDinamik(char, x, y, w)
     local d = self.dinamik and self.dinamik[self.secim.d]
     if not d then return end
     SK.Yazi(SK.Buyuk(self.k.yazar), "ust", x, y, R.altin)
     SK.Yazi(d.baslik, "baslik", x, y + SK.S(16), R.murekkep)
     SK.Yazi(d.sayac or "", "etiket", x + w, y + SK.S(28), R.altin, TEXT_ALIGN_RIGHT)
     y = y + SK.S(64)
     if d.kilit and #d.girdiler == 0 then
          for _, s in ipairs(SK.Sar(d.kilit, "metin", w)) do
               SK.Yazi(s, "metin", x, y, R.murekkepK)
               y = y + SK.SatirYuk("metin")
          end
          return
     end
     -- iki sütunlu liste, sayfa sayfa
     local rh = SK.S(40)
     local cw = math.floor((w - SK.S(16)) / 2)
     local alt = self.ry + self.ph - self.pad - SK.S(30)
     local satir = math.max(1, math.floor((alt - y) / rh))
     local sayfaBasi = satir * 2
     local toplamSayfa = math.max(1, math.ceil(#d.girdiler / sayfaBasi))
     self.secim.ls = math.Clamp(self.secim.ls or 1, 1, toplamSayfa)
     local bas = (self.secim.ls - 1) * sayfaBasi
     for n = 1, sayfaBasi do
          local g = d.girdiler[bas + n]
          if not g then break end
          local col = (n - 1) % 2
          local row = math.floor((n - 1) / 2)
          local gx, gy = x + col * (cw + SK.S(16)), y + row * rh
          local ust = g.acik and self:Alan(gx, gy, cw, rh - SK.S(4), function()
               self.secim = {tur = "detay", d = self.secim.d, g = g, ls = self.secim.ls}
               surface.PlaySound("physics/cardboard/cardboard_box_impact_soft2.wav")
          end)
          SK.Kutu(gx, gy, cw, rh - SK.S(4), Color(R.parsomenK.r, R.parsomenK.g, R.parsomenK.b, ust and 255 or 150))
          if g.altin then
               surface.SetDrawColor(R.altin) surface.DrawOutlinedRect(gx, gy, cw, rh - SK.S(4), 2)
          end
          SK.Yazi(g.ad, "metinK", gx + SK.S(10), gy + SK.S(3), g.acik and R.murekkep or R.soluk)
          SK.Yazi(g.alt or "", "ust", gx + SK.S(10), gy + SK.S(21), g.acik and R.murekkepK or R.soluk)
     end
     if toplamSayfa > 1 then
          local ny = alt + SK.S(8)
          local cx = x + w / 2
          if self.secim.ls > 1 then
               local u = self:Alan(cx - SK.S(70), ny - SK.S(4), SK.S(30), SK.S(24), function() self.secim.ls = self.secim.ls - 1 Anim("cevir", false) end)
               SK.Yazi("‹", "baslikK", cx - SK.S(56), ny + SK.S(8), u and R.altin or R.murekkepK, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          end
          SK.Yazi(self.secim.ls .. " / " .. toplamSayfa, "etiket", cx, ny + SK.S(8), R.murekkepK, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          if self.secim.ls < toplamSayfa then
               local u = self:Alan(cx + SK.S(40), ny - SK.S(4), SK.S(30), SK.S(24), function() self.secim.ls = self.secim.ls + 1 Anim("cevir", true) end)
               SK.Yazi("›", "baslikK", cx + SK.S(56), ny + SK.S(8), u and R.altin or R.murekkepK, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          end
     end
end

function PANEL:SagDetay(char, x, y, w)
     local s = self.secim
     local det = SK.DinamikDetay(self.k.id, s.g)
     local u = self:Alan(x, y - SK.S(2), SK.S(160), SK.S(20), function() self.secim = {tur = "dinamik", d = s.d, ls = s.ls} end)
     SK.Yazi("‹ listeye dön", "etiket", x, y, u and R.altin or R.murekkepK)
     y = y + SK.S(26)
     if not det then return end
     SK.Yazi(SK.Buyuk(det.ust or ""), "ust", x, y, R.altin)
     y = y + SK.S(16)
     for _, sat in ipairs(SK.Sar(det.baslik or "", "baslik", w)) do
          SK.Yazi(sat, "baslik", x, y, R.murekkep)
          y = y + SK.SatirYuk("baslik")
     end
     y = y + SK.S(8)
     for _, e in ipairs(det.etiketler or {}) do
          SK.Yazi(SK.Buyuk(e[1]), "ust", x, y + SK.S(3), R.soluk)
          local sat = SK.Sar(tostring(e[2]), "metinK", w - SK.S(130))
          for i, t in ipairs(sat) do SK.Yazi(t, "metinK", x + SK.S(130), y + (i - 1) * SK.SatirYuk("metinK"), R.murekkep) end
          y = y + math.max(1, #sat) * SK.SatirYuk("metinK") + SK.S(4)
     end
     y = y + SK.S(8)
     local alt = self.ry + self.ph - self.pad - SK.S(70)
     for _, p in ipairs(det.paragraflar or {}) do
          if p ~= "" then
               for _, sat in ipairs(SK.Sar(p, "metin", w)) do
                    if y > alt then break end
                    SK.Yazi(sat, "metin", x, y, R.murekkep)
                    y = y + SK.SatirYuk("metin")
               end
               y = y + SK.S(8)
          end
     end
     if det.not_ then
          local ny = math.max(y + SK.S(6), alt)
          SK.Yazi(det.not_, "elK", x + SK.S(20), ny, Color(40, 60, 110))
          SK.Yazi("— " .. (det.notImza or ""), "ust", x + w, ny + SK.S(26), R.soluk, TEXT_ALIGN_RIGHT)
     end
end

function PANEL:SagSinav(char, x, y, w)
     local sn = self.secim.sinav
     if not sn then return end
     SK.Yazi(SK.Buyuk(sn.yil .. ". yıl sonu sınavı"), "ust", x, y, R.altin)
     y = y + SK.S(18)
     if sn.sonuc then
          local r = sn.sonuc
          SK.Yazi(r.gecti and "Geçtin!" or "Kaldın", "dev", x, y, r.gecti and R.iyi or R.kotu)
          y = y + SK.S(56)
          SK.Yazi(r.dogru .. " / " .. r.toplam .. " doğru", "baslikK", x, y, R.murekkep)
          y = y + SK.S(36)
          local m = r.gecti and "Sınavı geçtin; Büyü Ağacı'na 1 Büyü Puanı eklendi." or ("Kitapları biraz daha oku; " .. SK.Ayar.sinavBekleme .. " dakika sonra yeniden girebilirsin.")
          for _, s in ipairs(SK.Sar(m, "metin", w)) do SK.Yazi(s, "metin", x, y, R.murekkep) y = y + SK.SatirYuk("metin") end
          return
     end
     local q = sn.sorular[sn.i]
     if not q then return end
     SK.Yazi("Soru " .. sn.i .. " / " .. #sn.sorular, "etiket", x, y, R.murekkepK)
     y = y + SK.S(26)
     for _, s in ipairs(SK.Sar(q[1], "baslikK", w)) do SK.Yazi(s, "baslikK", x, y, R.murekkep) y = y + SK.SatirYuk("baslikK") end
     y = y + SK.S(18)
     for j, m in ipairs(q[2]) do
          local h = SK.S(42)
          local u = self:Alan(x, y, w, h, function()
               sn.cevap[sn.i] = j
               surface.PlaySound("buttons/button14.wav")
               if sn.i < #sn.sorular then
                    sn.i = sn.i + 1
               else
                    net.Start("SardonKitap.SinavCevap")
                    net.WriteUInt(#sn.sorular, 5)
                    for i = 1, #sn.sorular do net.WriteUInt(sn.cevap[i] or 0, 3) end
                    net.SendToServer()
                    sn.bekliyor = true
                    self.sahne = CurTime()
               end
          end)
          SK.Kutu(x, y, w, h, Color(R.parsomenK.r, R.parsomenK.g, R.parsomenK.b, u and 255 or 160))
          surface.SetDrawColor(R.kenar) surface.DrawOutlinedRect(x, y, w, h, 1)
          SK.Yazi(string.char(64 + j) .. ")", "etiket", x + SK.S(12), y + h / 2, R.altin, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          SK.Yazi(m, "metinK", x + SK.S(40), y + h / 2, R.murekkep, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          y = y + h + SK.S(10)
     end
end

/*
*   ana çizim
*/
function PANEL:Paint(w, h)
     self.alanlar = {}
     local a = math.Clamp((CurTime() - self.acilis) * 5, 0, 1)
     -- sınav sahnesi: ekran 0.4 sn'de çekilir, sonuç gelince 0.5 sn'de döner
     if self.sahne and CurTime() - self.sahne > 12 then
          -- yanıt gelmediyse ekran geri gelir
          self.sahne, self.sahneDonus = nil, CurTime()
     end
     if self.sahne then
          a = a * (1 - math.Clamp((CurTime() - self.sahne) / 0.4, 0, 1))
     elseif self.sahneDonus then
          a = a * math.Clamp((CurTime() - self.sahneDonus) / 0.5, 0, 1)
     end
     if a <= 0.01 then return end
     surface.SetAlphaMultiplier(a)
     SK.Kutu(0, 0, w, h, R.zemin)
     SK.Deri(self.bx, self.by, self.bw, self.bh)
     SK.Parsomen(self.lx, self.ly, self.pw, self.ph, false, true)
     SK.Parsomen(self.rx, self.ry, self.pw, self.ph, true, false)
     -- sırt çizgisi
     SK.Kutu(self.rx - 1, self.ry, 2, self.ph, Color(80, 56, 34, 160))

     local char = Char()
     local ok, hata = pcall(function()
          self:SolSayfa(char)
          local x, y, pw = self.rx + self.pad, self.ry + self.pad, self.pw - self.pad * 2
          local t = self.secim.tur
          if t == "bolum" then self:SagBolum(char, x, y, pw)
          elseif t == "dinamik" then self:SagDinamik(char, x, y, pw)
          elseif t == "detay" then self:SagDetay(char, x, y, pw)
          elseif t == "sinav" then self:SagSinav(char, x, y, pw)
          else self:SagGiris(char, x, y, pw) end
     end)
     if not ok and not self.hataYazildi then
          self.hataYazildi = true
          ErrorNoHalt("[Sardon Kitap] kitap ekranı çizilemedi: " .. tostring(hata) .. "\n")
     end
     SK.Yazi("Esc · kapat    ← → · sayfa çevir", "ust", self.bx + self.bw / 2, self.by + self.bh + SK.S(6), Color(220, 210, 190, 160), TEXT_ALIGN_CENTER)
     surface.SetAlphaMultiplier(1)
end

function PANEL:OnRemove()
     if SK.Acik == self then SK.Acik = nil end
     -- karakter kitabı kapatıp kaldırır
     if not SK.KitapDegisiyor and not (IsValid(SK.Acik) and SK.Acik ~= self) then Anim("kapa", "oku") end
end

vgui.Register("SardonKitap.Kitap", PANEL, "EditablePanel")

-- Esc oyunun menüsünü açmasın, kitabı kapatsın
hook.Add("OnPauseMenuShow", "SardonKitap.Kitap", function()
     -- havada rün çizerken Esc kitaba döner
     if SK.Cizim3BAcik and SK.Cizim3BAcik() then
          SK.Cizim3BBitir()
          return false
     end
     if IsValid(SK.Acik) then
          SK.Acik:Kapat()
          return false
     end
end)

/*
*   ağ
*/
net.Receive("SardonKitap.Ac", function()
     local v = {kitap = net.ReadString(), bolum = net.ReadString(), seri = net.ReadUInt(32), sahip = net.ReadString(),
          hane = net.ReadString(), egil = net.ReadString(), ek = net.ReadTable()}
     if not SK.Kitap[v.kitap] then return end
     if IsValid(SK.Acik) and SK.Acik.k and SK.Acik.k.id == v.kitap and SK.Acik.veri.egil == v.egil then
          SK.Acik:Kur(v)
          return
     end
     -- başka kitaba geçiş: eski panelin kapanışı yeni okuma animasyonunu kapatmasın
     SK.KitapDegisiyor = true
     if IsValid(SK.Acik) then SK.Acik:Kapat() end
     local p = vgui.Create("SardonKitap.Kitap")
     SK.Acik = p
     SK.KitapDegisiyor = nil
     p:Kur(v)
     if v.egil ~= "" then SK.Kart("Sınıf arkadaşının kitabına bakıyorsun", "Kitabın sahibi: " .. v.egil .. " · okuman ilerlemez", "bilgi") end
end)

net.Receive("SardonKitap.Ilerleme", function()
     local k, b, bir, gerek, durum = net.ReadString(), net.ReadString(), net.ReadFloat(), net.ReadFloat(), net.ReadString()
     local key = SK.Anahtar(k, b)
     if durum == "tamam" then
          SK.Ilerleme[key] = nil
          surface.PlaySound("buttons/button9.wav")
          if IsValid(SK.Acik) and SK.Acik.okunan == key then SK.Acik.okunan = nil end
          return
     end
     SK.Ilerleme[key] = {birikim = bir, gerek = gerek, durum = durum, t = CurTime()}
     if durum == "kitapyok" and IsValid(SK.Acik) then SK.Acik.okunan = nil end
end)

net.Receive("SardonKitap.Notlar", function()
     local seri = net.ReadUInt(32)
     local t = {}
     for i = 1, net.ReadUInt(10) do
          local n = {no = net.ReadUInt(32), bolum = net.ReadString(), yazar = net.ReadString(), metin = net.ReadString(), zaman = net.ReadUInt(32)}
          t[n.bolum] = t[n.bolum] or {}
          table.insert(t[n.bolum], n)
     end
     SK.NotVeri[seri] = t
end)

net.Receive("SardonKitap.CizimSonuc", function()
     local ok, skor, metin = net.ReadBool(), net.ReadFloat(), net.ReadString()
     -- havada çizim açıksa sonucu o gösterir (kart kitap geri gelince çıkar)
     if SK.Cizim3BSonuc and SK.Cizim3BSonuc(ok, skor, metin) then return end
     if ok then SK.Kart("Büyü öğrenildi", metin, "iyi") end
end)

net.Receive("SardonKitap.Sinav", function()
     local yil = net.ReadUInt(4)
     local sorular = {}
     for i = 1, net.ReadUInt(5) do
          local q = {net.ReadString(), {}}
          for j = 1, net.ReadUInt(3) do q[2][j] = net.ReadString() end
          sorular[i] = q
     end
     local p = SK.Acik
     if not IsValid(p) then return end
     p:OkumaDurdur()
     p:CizimKapat()
     p:NotKapat()
     p.secim = {tur = "sinav", sinav = {yil = yil, sorular = sorular, cevap = {}, i = 1}}
end)

net.Receive("SardonKitap.SinavCevap", function()
     local dogru, toplam, gecti = net.ReadUInt(5), net.ReadUInt(5), net.ReadBool()
     local p = SK.Acik
     if IsValid(p) and p.secim.tur == "sinav" then
          p.secim.sinav.sonuc = {dogru = dogru, toplam = toplam, gecti = gecti}
     end
     if IsValid(p) and p.sahne then
          p.sahne = nil
          p.sahneDonus = CurTime()
     end
     surface.PlaySound(gecti and "buttons/button9.wav" or "buttons/button10.wav")
end)
