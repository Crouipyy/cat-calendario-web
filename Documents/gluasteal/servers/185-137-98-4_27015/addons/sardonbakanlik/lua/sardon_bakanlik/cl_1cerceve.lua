-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\cl_1cerceve.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Bakanlık :: Sicil Defteri penceresi. Sol mühür rayı (sayfalar), üst şerit, sayfa
-- yönlendirici, kip pencereleri (onay / metin sorma), bildirim şeridi.
--
-- Sayfalar cl_2_*.lua dosyalarında B.Sayfa(id, {ad, alt, izin, sira, ac, ciz, geri}) ile kaydolur.
--   ac(arg)            sayfa açılınca (veri isteği burada)
--   ciz(x, y, w, h)    her kare; içerik alanı tasarım px (270,104 - 1300x756)
--   geri()             Esc'e basılınca; true dönerse defter kapanmaz
-- Düz Lua (çevrimdışı çizim düzeneğinde de çalışır).

local B = SardonBakanlik
local U = B.UI
local R = U.R

B.Sayfalar = B.Sayfalar or {}
B.IstekAn = B.IstekAn or {}

function B.Sayfa(id, def)
     def.id = id
     B.Sayfalar[id] = def
end

-- Veri isteği (anı kaydedilir: yanıt kendi isteğimizse "Protean mürekkebi" oynamaz)
function B.Sor(eylem, arg)
     B.IstekAn[eylem] = RealTime()
     B.Iste(eylem, arg)
end

local ICERIK_X, ICERIK_Y, ICERIK_W, ICERIK_H = 270, 104, 1300, 756

local function Ben() return B.Bilgi(LocalPlayer()) end

local function GorunenSayfalar()
     local liste = {}
     local ply = LocalPlayer()
     for _, s in pairs(B.Sayfalar) do
          if not s.gizli and (not s.izin or B.Yetkili(ply, s.izin)) then liste[#liste + 1] = s end
     end
     table.sort(liste, function(a, b) return (a.sira or 50) < (b.sira or 50) end)
     return liste
end

----------------------------------------------------------------------------------------
-- Bildirim şeridi
----------------------------------------------------------------------------------------
local bildirimler = {}

function B.Toast(metin, tur)
     bildirimler[#bildirimler + 1] = {metin = tostring(metin), tur = tur or 0, an = RealTime()}
     if #bildirimler > 4 then table.remove(bildirimler, 1) end
     if tur == 2 then U.Ses("hata") elseif tur == 1 then U.Ses("tamam") end
end

B.Kanca("SardonBakanlikBildirim", "SardonBakanlik.Defter", function(metin, tur)
     if IsValid(B.Defter) then
          B.Toast(metin, tur)
          return true
     end
end)

local function BildirimCiz()
     local simdi = RealTime()
     local y = 96
     for i = #bildirimler, 1, -1 do
          local b = bildirimler[i]
          local t = simdi - b.an
          if t > 4.5 then
               table.remove(bildirimler, i)
          else
               local giris = U.Kolay(t / 0.25)
               local alfa = t > 4 and (1 - (t - 4) / 0.5) or 1
               local c = b.tur == 2 and R.kizil or (b.tur == 1 and R.yesil or R.altin)
               local satirlar = U.Sar(b.metin, 13, 700, 420)
               local h = 26 + #satirlar * 18
               local x = 1570 - 470 * giris

               surface.SetAlphaMultiplier(alfa)
               U.Kutu(x, y, 470, h, R.zeminKoyu, 0.96)
               U.Cerceve(x, y, 470, h, c, 0.85)
               U.Kutu(x, y, 3, h, c, 1)
               U.Baklava(x + 22, y + h / 2, 5, c, 1)
               for j, s in ipairs(satirlar) do U.Yazi(s, 13, 700, x + 40, y + 13 + (j - 0.5) * 18, R.fildisi) end
               surface.SetAlphaMultiplier(1)
               y = y + h + 8
          end
     end
end

----------------------------------------------------------------------------------------
-- Kip pencereleri
----------------------------------------------------------------------------------------
-- def: {baslik, w, h, ciz = function(x, y, w, h) ... end, odak, onek, ustune}
--   onek    bu kipin yazı kutusu kimliklerinin öneki (varsayılan "kip."); kapanınca yalnız onlar silinir
--   ustune  açık bir kip varsa onu kapatmadan üstüne açılır; kapanınca alttaki kip geri gelir
function B.Kip(def)
     local p = B.Defter
     if not IsValid(p) then return end

     def.onek = def.onek or "kip."
     def.an = RealTime()
     if p.kip and def.ustune then
          def.alt = p.kip
     else
          U.GirdiTemizle("kip.")
          U.GirdiTemizle("ksec.")
     end
     if not (def.alt and def.alt.onek == def.onek) then U.GirdiTemizle(def.onek) end

     p.kip = def
     U.Ses("kagit")
end

function B.KipKapat()
     local p = B.Defter
     local k = IsValid(p) and p.kip
     if not k then return end

     if not (k.alt and k.alt.onek == k.onek) then U.GirdiTemizle(k.onek) end
     p.kip = k.alt
     if k.alt then k.alt.an = RealTime() - 1 end
end

function B.Onay(baslik, metin, evet, fn, tehlike)
     B.Kip({baslik = baslik, w = 520, h = 0, ciz = function(x, y, w)
          local h = U.Paragraf(metin, 14, 700, x, y, w, R.govde, 21)
          local by = y + h + 22
          if U.Dugme(x + w - 150, by, 150, 38, evet or "Confirmar", tehlike and "tehlike" or "ana") then
               B.KipKapat()
               fn()
          end
          if U.Dugme(x + w - 290, by, 130, 38, "Cancelar", "ikincil") then B.KipKapat() end
          return by + 38 - y
     end})
end

-- fn(metin). secenek: {cokSatir, deger, maks, sayi, enAz, dugme}
function B.MetinSor(baslik, aciklama, yerTutucu, fn, secenek)
     secenek = secenek or {}
     local kh = secenek.cokSatir and 130 or 38
     B.Kip({baslik = baslik, w = 560, h = 0, ciz = function(x, y, w)
          local h = aciklama and (U.Paragraf(aciklama, 13, 700, x, y, w, R.ada, 20) + 12) or 0
          local metin = U.Girdi("kip.metin", x, y + h, w, kh, yerTutucu, {cokSatir = secenek.cokSatir, deger = secenek.deger, maks = secenek.maks, sayi = secenek.sayi})
          local by = y + h + kh + 18
          local yeterli = #string.Trim(metin) >= (secenek.enAz or 1)
          if (U.Dugme(x + w - 160, by, 160, 38, secenek.dugme or "Guardar", "ana", not yeterli) or (not secenek.cokSatir and U.GirdiEnter("kip.metin") and yeterli)) then
               B.KipKapat()
               fn(string.Trim(metin))
          end
          if U.Dugme(x + w - 300, by, 130, 38, "Cancelar", "ikincil") then B.KipKapat() end
          return by + 38 - y
     end, odak = "kip.metin"})
end

local function KipCiz(p)
     local k = p.kip
     if not k then return end

     local t = U.Kolay((RealTime() - k.an) / 0.18)
     U.Kutu(0, 0, U.TW, U.TH, R.siyah, 0.62 * t)
     -- ekranın tasarım alanı dışında kalan kenarları da karart
     surface.SetDrawColor(0, 0, 0, 158 * t)
     if U.OX > 0 then
          surface.DrawRect(0, 0, U.OX, ScrH())
          surface.DrawRect(ScrW() - U.OX, 0, U.OX, ScrH())
     end
     if U.OY > 0 then
          surface.DrawRect(0, 0, ScrW(), U.OY)
          surface.DrawRect(0, ScrH() - U.OY, ScrW(), U.OY)
     end

     local w = k.w or 520
     local h = (k.sonH or k.h or 200) + 96
     local x, y = (U.TW - w) / 2, (U.TH - h) / 2 - 10 * (1 - t)

     U.Kutu(x, y, w, h, R.zemin, 0.985)
     U.Gecis(x, y, w, 70, R.panelAcik, 0.9, "u")
     U.Cerceve(x, y, w, h, R.altin, 0.9)
     U.Cerceve(x + 4, y + 4, w - 8, h - 8, R.cizgi, 0.5)
     U.Baklava(x, y, 4, R.altinAcik, 1) U.Baklava(x + w, y, 4, R.altinAcik, 1)
     U.Baklava(x, y + h, 4, R.altinAcik, 1) U.Baklava(x + w, y + h, 4, R.altinAcik, 1)

     U.Yazi(k.baslik or "", 19, 600, x + 30, y + 36, R.fildisiAcik)
     U.SusCizgi(x + 30, y + 60, w - 60, R.altin, 0.6)

     k.sonH = k.ciz(x + 30, y + 76, w - 60, h - 96) or k.sonH or k.h or 200

     if k.odak and not k.odaklandi then
          k.odaklandi = true
          U.GirdiOdak(k.odak)
     end
end

----------------------------------------------------------------------------------------
-- Zemin, ray, üst şerit
----------------------------------------------------------------------------------------
local function ZeminCiz(w, h)
     surface.SetDrawColor(7, 11, 9, 255)
     surface.DrawRect(0, 0, w, h)

     local mat = U.GelisimDoku("background")
     if mat then
          -- ekranı kaplayacak şekilde ortala (oran korunur)
          local dw, dh = 1672, 941
          if SardonGelisim.DokuOlcu then dw, dh = SardonGelisim.DokuOlcu("background") end
          local olcek = math.max(w / dw, h / dh)
          local cw, ch = dw * olcek, dh * olcek
          surface.SetMaterial(mat)
          surface.SetDrawColor(150, 150, 150, 255)
          surface.DrawTexturedRect((w - cw) / 2, (h - ch) / 2, cw, ch)
          draw.NoTexture()
          surface.SetDrawColor(7, 11, 9, 150)
          surface.DrawRect(0, 0, w, h)
     end

     U.Toz(26)
     U.Yildiz(1486, 60, 1.6, 0.4)
     U.Yildiz(300, 872, 1.3, 2.1)
     U.Yildiz(1560, 520, 1.2, 4.0)
end

local function SaatYazisi()
     local dk = StormFox2 and StormFox2.Time and StormFox2.Time.Get and StormFox2.Time.Get()
     if tonumber(dk) then return string.format("%02d:%02d", math.floor(dk / 60) % 24, math.floor(dk % 60)) end
     return os.date("%H:%M")
end

local function RayCiz(p)
     local ben = Ben()
     local gise = p.gise

     U.Kutu(0, 0, 250, U.TH, R.zeminKoyu, 0.74)
     U.Gecis(249, 0, 1, U.TH, R.altin, 0.55, "u")
     U.Gecis(249, U.TH / 2, 1, U.TH / 2, R.altin, 0.25, "d")

     -- mühür
     local nefes = 0.5 + 0.5 * math.sin(U.Zaman() * 0.9)
     U.Parilti(125, 96, 250, R.altin, 26 + 16 * nefes)
     if not U.Resim(B.Doku("muhur"), 61, 32, 128, 128) then
          U.Halka(125, 96, 60, R.altin, 0.9)
          U.Yazi("M", 60, 600, 125, 98, R.altinAcik, 1)
     end
     U.Yazi("MINISTERIO DE MAGIA", 14, 600, 125, 184, R.fildisi, 1, 3)
     U.Etiket(gise and "Ventanilla del ciudadano" or B.Ayar.AracAdi, 125, 206, R.ust, 1, 10)
     U.SusCizgi(30, 226, 190, R.altin, 0.7)
     U.Baklava(125, 226, 4, R.altinAcik, 1)

     if gise then
          U.Paragraf("Las puertas del Ministerio están abiertas a todos. Paga tus deudas, consulta la lista de buscados y los decretos vigentes, o envía una denuncia o solicitud.", 12, 700, 30, 250, 190, R.ada, 18)
          return
     end

     -- sayfalar
     local sayilar = B.Veri.kumanda and B.Veri.kumanda.sayilar or {}
     local y = 246
     for _, s in ipairs(GorunenSayfalar()) do
          local secili = p.sayfa == s.id
          local ustunde = U.Icinde(14, y, 222, 40)

          if secili then
               U.Gecis(14, y, 222, 40, R.altin, 0.2, "l")
               U.Kutu(14, y, 2, 40, R.altinAcik, 1)
          elseif ustunde then
               U.Gecis(14, y, 222, 40, R.altin, 0.09, "l")
          end

          if secili then U.Baklava(36, y + 20, 5, R.altinAcik, 1) else U.BaklavaCizgi(36, y + 20, 5, ustunde and R.altin or R.pirinc, 0.9) end
          U.Yazi(B.Buyuk(s.ad), 12, 600, 54, y + 20, secili and R.fildisiAcik or (ustunde and R.butonYazi or R.ada), 0, 1.6)

          local rozet = s.rozet and sayilar[s.rozet] or 0
          if rozet > 0 then
               U.Disk(218, y + 20, 10, s.rozet == "onay" and R.kizil or R.altin, 0.9)
               U.Yazi(rozet > 99 and "99" or rozet, 10, 700, 218, y + 20, R.zeminKoyu, 1)
          end

          if ustunde then
               U.imlec = true
               if not secili and U.Tik(14, y, 222, 40) then B.Git(s.id) end
          end
          y = y + 42
     end

     -- kimlik kartı + mesai
     if ben then
          local gorev = B.Gorevde(LocalPlayer())
          U.SusCizgi(30, 776, 190, R.cizgi, 0.8)
          local char = LocalPlayer():GetCharacter()
          U.Yazi(U.Kisalt(char and char:GetName() or "", 14, 600, 200), 14, 600, 28, 798, R.fildisi)
          U.Yazi(U.Kisalt(ben.unvan or "", 12, 700, 200), 12, 700, 28, 818, R.ada)
          U.Etiket(B.DaireAd(ben.daire, true) .. " · " .. ben.kademe .. ". NIVEL", 28, 836, R.ust, 0, 9)

          if ben.denetci then
               U.Rozet("Inspector", 28, 868, R.mor, true)
          elseif U.Dugme(28, 852, 194, 32, gorev and "Salir de servicio" or "Entrar de servicio", gorev and "ikincil" or "ana") then
               B.Iste("mesai", {ac = not gorev})
          end
     end
end

local function UstCiz(p, sayfa)
     U.Yazi(sayfa and sayfa.ad or "", 26, 600, ICERIK_X, 44, R.fildisiAcik)
     local alt = sayfa and (isfunction(sayfa.alt) and sayfa.alt() or sayfa.alt) or ""
     U.Yazi(alt, 13, 700, ICERIK_X + 2, 76, R.ada)

     -- sağ üst: tehdit, saat, kapat
     local seviye = GetGlobalInt("SBTehdit", 0)
     local t = B.Tehdit[seviye] or B.Tehdit[0]
     local x = 1570

     if U.Dugme(x - 96, 28, 96, 30, "Cerrar  Esc", "duz") then B.Kapat() end
     x = x - 112

     U.Yazi(SaatYazisi(), 15, 600, x, 43, R.fildisi, 2)
     x = x - U.Olc(SaatYazisi(), 15, 600) - 22

     local ad = B.Buyuk(t.ad)
     local w = U.Olc(ad, 11, 600, 1.8) + 44
     local nabiz = seviye >= 2 and (0.55 + 0.45 * math.sin(U.Zaman() * 5)) or 1
     U.Kutu(x - w, 30, w, 26, t.renk, 0.12 + (seviye >= 2 and 0.12 * nabiz or 0))
     U.Cerceve(x - w, 30, w, 26, t.renk, 0.85)
     U.Baklava(x - w + 16, 43, 5, t.renk, nabiz)
     U.Yazi(ad, 11, 600, x - w + 30, 43, t.renk, 0, 1.8)
     U.Etiket("Nivel de amenaza", x - w - 10, 43, R.soluk, 2, 9)

     U.Gecis(ICERIK_X, 94, ICERIK_W, 1, R.altin, 0.55, "l")
end

----------------------------------------------------------------------------------------
-- Panel
----------------------------------------------------------------------------------------
local PANEL = {}

function PANEL:Init()
     self:SetSize(ScrW(), ScrH())
     self:SetPos(0, 0)
     self:MakePopup()
     self:SetKeyboardInputEnabled(true)
     self:SetAlpha(0)
     self:AlphaTo(255, 0.18)
     self.acilis = RealTime()
end

-- Karakter değişirse (yetki değişmiş olabilir) ya da oyuncu ölürse defter kapanır
function PANEL:Think()
     local ply = LocalPlayer()
     local char = IsValid(ply) and ply:GetCharacter()
     local id = char and char:GetID() or 0
     if not self.charId then self.charId = id end
     if id ~= self.charId or id == 0 then self:Remove() end
end

function PANEL:OnMousePressed(kod)
     local x, y = self:CursorPos()
     U.tik = {x = x, y = y, kod = kod}
     self:RequestFocus() -- boş yere tıklayınca yazı kutusunun odağı düşsün
end

function PANEL:OnMouseWheeled(delta)
     U.teker = U.teker + delta
end

function PANEL:OnKeyCodePressed(tus)
     if tus == SardonConfig:Get("bakanlik") and RealTime() - self.acilis > 0.3 then B.Kapat() end
end

function PANEL:Paint(w, h)
     local ok, hata = pcall(self.Ciz, self, w, h)
     if not ok then
          render.SetScissorRect(0, 0, 0, 0, false)
          surface.SetAlphaMultiplier(1)
          if not self.hataBasildi then
               self.hataBasildi = true
               ErrorNoHalt("[Sardon Bakanlık] defter çizimi: " .. tostring(hata) .. "\n")
          end
          self.hata = tostring(hata)
     end
     U.Bitir()
end

function PANEL:Ciz(w, h)
     U.Basla(self, w, h)
     ZeminCiz(w, h)

     local sayfa = B.Sayfalar[self.sayfa or ""]
     U.engel = self.kip ~= nil

     RayCiz(self)
     UstCiz(self, sayfa)
     if sayfa and sayfa.ciz then sayfa.ciz(ICERIK_X, ICERIK_Y, ICERIK_W, ICERIK_H) end
     U.MurekkepCiz(ICERIK_X, ICERIK_Y, ICERIK_W, ICERIK_H)

     if self.hata then
          U.Yazi("Se produjo un error al dibujar esta página; se ha registrado en la consola.", 13, 700, ICERIK_X, 880, R.kizil)
     end

     U.engel = false
     KipCiz(self)
end

function PANEL:PaintOver()
     BildirimCiz()
     U.MuhurCiz()

     if U.ipucu and not self.kip then
          local metin = U.ipucu
          local satirlar = U.Sar(metin, 12, 700, 300)
          local tw = 0
          for _, s in ipairs(satirlar) do tw = math.max(tw, U.Olc(s, 12, 700)) end
          local w, h = tw + 24, #satirlar * 17 + 14
          local x = math.Clamp((U.fareX - U.OX) / U.S + 16, 8, U.TW - w - 8)
          local y = math.Clamp((U.fareY - U.OY) / U.S + 20, 8, U.TH - h - 8)
          U.Kutu(x, y, w, h, R.zeminKoyu, 0.97)
          U.Cerceve(x, y, w, h, R.altin, 0.7)
          for i, s in ipairs(satirlar) do U.Yazi(s, 12, 700, x + 12, y + 7 + (i - 0.5) * 17, R.fildisi) end
     end
end

function PANEL:OnRemove()
     U.HepsiniYokEt()
     if B.Defter == self then B.Defter = nil end
     B.Iste("kapat", {})
     hook.Run("SardonBakanlikDefter", false)
end

vgui.Register("SardonBakanlik.Defter", PANEL, "EditablePanel")

----------------------------------------------------------------------------------------
-- Açma / kapama / gezinme
----------------------------------------------------------------------------------------
function B.Git(id, arg)
     local p = B.Defter
     if not IsValid(p) then return end
     local s = B.Sayfalar[id]
     if not s then return end
     if s.izin and not B.Yetkili(LocalPlayer(), s.izin) then return end

     if p.sayfa ~= id then U.Ses("sayfa") end
     p.sayfa = id
     p.hata, p.hataBasildi = nil, nil
     p.kip = nil
     if s.ac then s.ac(arg or {}) end
end

function B.Kapat()
     local p = B.Defter
     if not IsValid(p) or p.kapaniyor then return end
     p.kapaniyor = true
     p:SetMouseInputEnabled(false)
     p:SetKeyboardInputEnabled(false)
     U.Ses("geri")
     p:AlphaTo(0, 0.14, 0, function()
          if IsValid(p) then p:Remove() end
     end)
end

function B.Ac(sayfa, arg)
     local ply = LocalPlayer()
     if not IsValid(ply) or not ply:GetCharacter() then return end
     if IsValid(B.Defter) then
          if sayfa then B.Git(sayfa, arg) else B.Kapat() end
          return
     end

     local uye = B.Bilgi(ply) ~= nil
     local p = vgui.Create("SardonBakanlik.Defter")
     B.Defter = p
     p.gise = not uye
     hook.Run("SardonBakanlikDefter", true)
     U.Ses("kagit")

     if uye then
          B.Sor("kumanda", {})
          B.Git(sayfa or "kumanda", arg)
     else
          B.Git("gise", arg)
     end
end

-- Esc: önce kip, sonra sayfanın "geri"si, sonra defter
B.Kanca("OnPauseMenuShow", "SardonBakanlik.Defter", function()
     local p = B.Defter
     if not IsValid(p) then return end

     if p.kip then
          B.KipKapat()
          return false
     end
     local s = B.Sayfalar[p.sayfa or ""]
     if s and s.geri and s.geri() then return false end
     B.Kapat()
     return false
end)

B.Kanca("PlayerButtonDown", "SardonBakanlik.Tus", function(ply, tus)
     if tus ~= SardonConfig:Get("bakanlik") or not IsFirstTimePredicted() then return end
     if ply ~= LocalPlayer() or IsValid(B.Defter) then return end
     if (B.sonTus or 0) > RealTime() then return end
     B.sonTus = RealTime() + 0.4
     B.Ac()
end)

concommand.Add("sardon_bakanlik", function(_, _, args)
     B.Ac(args[1])
end)

-- Canlı eşitleme: kendi isteğimiz olmayan veri gelince mürekkep geçer
B.Kanca("SardonBakanlikVeri", "SardonBakanlik.Defter", function(anahtar, tablo)
     if anahtar == "kanun" then
          B.KanunDegisiklik(tablo.d)
          return
     end

     local p = B.Defter
     if not IsValid(p) then return end

     local s = B.Sayfalar[p.sayfa or ""]
     if s and s.veri then s.veri(anahtar, tablo) end
     if s and s.kanallar and s.kanallar[anahtar] and RealTime() - (B.IstekAn[anahtar] or 0) > 1.5 then U.Murekkep() end
end)

