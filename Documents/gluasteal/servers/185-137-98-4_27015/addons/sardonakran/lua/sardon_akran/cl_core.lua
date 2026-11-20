-- "addons\\sardonakran\\lua\\sardon_akran\\cl_core.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Akran Yardımı :: istemci çekirdeği
--   * sunucu verisi (ayar, harita, görev, sayfa verisi)
--   * 2B yardımcılar: ışık, kalın çizgi, rün çizimi, parçacık sistemi (cl_sayfa / cl_talim de kullanır)
--   * ekran: bildirim şeritleri, görev takip kartı, okuma kitabı, raf paneli, davet ve onay pencereleri
--   * dünya: raf plakaları, talim alanı halkaları, okuyan öğrencinin süzülen kitabı, efektler
--
-- Dokular: oyunla gelen materyaller (sprites/light_glow02_add, trails/laser, effects/select_ring,
-- particle/particle_ring_wave_additive, particle/smokesprites_0001 ...) ve asa menüsünün gömülü
-- kitap dokuları (K.Mat: deri, köşe süsü, parşömen şerit, gök plakası). Dosya dağıtımı gerekmez.

local SA = SardonAkran

SA.Gorev = SA.Gorev or nil
SA.HaritaVeri = SA.HaritaVeri or {raflar = {}, alanlar = {}}
SA.PanelVeri = SA.PanelVeri or nil

/*
*   ------------------------------------------------------------------
*   renkler, fontlar, dokular
*   ------------------------------------------------------------------
*/

SA.R = {
     altin = Color(222, 192, 120),
     altinK = Color(174, 145, 92),
     pirinc = Color(156, 128, 80),
     fildisi = Color(224, 215, 191),
     soluk = Color(171, 169, 147),
     sonuk = Color(127, 137, 120),
     adacayi = Color(174, 196, 140),
     kotu = Color(196, 104, 90),
     uyari = Color(214, 160, 96),
     zemin = Color(12, 18, 16, 236),
     zeminK = Color(8, 13, 11, 250),
     cizgi = Color(125, 104, 69, 110),
     murekkep = Color(52, 36, 22),
     parsomen = Color(214, 196, 158),
     mavi = Color(140, 190, 230)
}
local R = SA.R

local fontKur
function SA.Fontlar()
     if (fontKur) then return end
     fontKur = true

     local serif, sans = "Georgia", "Montserrat Medium"
     local function F(ad, yuz, boy, kalin)
          surface.CreateFont("sak." .. ad, {font = yuz, size = boy, weight = kalin or 400, extended = true, antialias = true})
     end

     F("dev", serif, 38)
     F("buyuk", serif, 28)
     F("baslik", serif, 25)
     F("orta", serif, 21)
     F("kitap", serif, 18)
     F("kitapK", serif, 16)
     F("alt", sans, 17, 500)
     F("kucuk", sans, 15, 500)
     F("ust", sans, 13, 600)
     F("plaka", serif, 44)
     F("plakaK", sans, 18, 600)
     F("sirt", serif, 15)
end

local glow = Material("sprites/light_glow02_add")
local hasGlow = !glow:IsError()

local M3 = {
     iz = Material("trails/laser"),
     isik = Material("sprites/light_glow02_add"),
     halka = Material("effects/select_ring"),
     dalga = Material("particle/particle_ring_wave_additive"),
     keskin = Material("particle/particle_ring_sharp"),
     toz = Material("particle/smokesprites_0001"),
     kivilcim = Material("effects/spark"),
     parlak = Material("sprites/glow04_noz"),
     isin = Material("sprites/physbeama")
}
SA.M3 = M3

-- asa menüsü kitap teması dokusu (yoksa nil)
function SA.K()
     local N = HpwRewrite and HpwRewrite.Nocturne
     return N and N.Kitap and N.Kitap.Mat and N.Kitap or nil
end

function SA.Doku(ad)
     local K = SA.K()
     return K and K.Mat(ad) or nil
end

/*
*   ------------------------------------------------------------------
*   2B yardımcılar
*   ------------------------------------------------------------------
*/

function SA.Isik(x, y, r, c, a)
     if (!hasGlow) then return end
     surface.SetMaterial(glow)
     surface.SetDrawColor(c.r, c.g, c.b, a or 255)
     surface.DrawTexturedRect(x - r, y - r, r * 2, r * 2)
     draw.NoTexture()
end

function SA.Kalin(x1, y1, x2, y2, t, c, a)
     local dx, dy = x2 - x1, y2 - y1
     local len = math.sqrt(dx * dx + dy * dy)
     if (len < 0.5) then return end
     local nx, ny = -dy / len * t / 2, dx / len * t / 2
     draw.NoTexture()
     surface.SetDrawColor(c.r, c.g, c.b, a or c.a or 255)
     surface.DrawPoly({
          {x = x1 + nx, y = y1 + ny},
          {x = x2 + nx, y = y2 + ny},
          {x = x2 - nx, y = y2 - ny},
          {x = x1 - nx, y = y1 - ny}
     })
end

local daireOnbellek = {}
function SA.Daire(x, y, r, c, a, seg)
     seg = seg or 24
     local birim = daireOnbellek[seg]
     if (!birim) then
          birim = {}
          for i = 1, seg do
               local an = i / seg * math.pi * 2
               birim[i] = {math.cos(an), math.sin(an)}
          end
          daireOnbellek[seg] = birim
     end
     local pts = {}
     for i, b in ipairs(birim) do pts[i] = {x = x + b[1] * r, y = y + b[2] * r} end
     draw.NoTexture()
     surface.SetDrawColor(c.r, c.g, c.b, a or c.a or 255)
     surface.DrawPoly(pts)
end

function SA.Halka(x, y, r, t, c, a, seg, bas, son)
     seg = seg or 40
     bas, son = bas or 0, son or 1
     local n = math.max(2, math.floor(seg * (son - bas)))
     local px, py
     for i = 0, n do
          local an = (bas + (son - bas) * i / n) * math.pi * 2 - math.pi / 2
          local nx, ny = x + math.cos(an) * r, y + math.sin(an) * r
          if (px) then SA.Kalin(px, py, nx, ny, t, c, a) end
          px, py = nx, ny
     end
end

-- 4 kollu yıldız
function SA.Yildiz(x, y, r, c, a)
     local k = r * 0.28
     draw.NoTexture()
     surface.SetDrawColor(c.r, c.g, c.b, a or 255)
     surface.DrawPoly({{x = x, y = y - r}, {x = x + k, y = y}, {x = x, y = y + r}, {x = x - k, y = y}})
     surface.DrawPoly({{x = x - r, y = y}, {x = x, y = y - k}, {x = x + r, y = y}, {x = x, y = y + k}})
end

function SA.Metin(str, font, x, y, c, ax, ay, a)
     if (a) then c = ColorAlpha(c, a) end
     return draw.SimpleText(str, "sak." .. font, x, y, c, ax, ay)
end

function SA.MetinG(str, font)
     surface.SetFont("sak." .. font)
     return surface.GetTextSize(tostring(str or ""))
end

local sarOnbellek = {}
function SA.Sar(str, font, maxw)
     local anahtar = font .. "|" .. maxw .. "|" .. str
     local s = sarOnbellek[anahtar]
     if (s) then return s end

     surface.SetFont("sak." .. font)
     local satirlar, satir = {}, ""
     for kelime in string.gmatch(str, "%S+") do
          local deneme = satir == "" and kelime or (satir .. " " .. kelime)
          if (surface.GetTextSize(deneme) > maxw and satir != "") then
               satirlar[#satirlar + 1] = satir
               satir = kelime
          else
               satir = deneme
          end
     end
     if (satir != "") then satirlar[#satirlar + 1] = satir end

     if (table.Count(sarOnbellek) > 300) then sarOnbellek = {} end
     sarOnbellek[anahtar] = satirlar
     return satirlar
end

-- deri zemin + köşe süsleri + ince çerçeve (doku yoksa düz renk)
function SA.Kart(x, y, w, h, alfa, kose)
     local K = SA.K()
     alfa = alfa or 1
     surface.SetDrawColor(R.zemin.r, R.zemin.g, R.zemin.b, R.zemin.a * alfa)
     draw.NoTexture()
     surface.DrawRect(x, y, w, h)

     if (K and K.Mat("leather_dark")) then
          surface.SetMaterial(K.Mat("leather_dark"))
          surface.SetDrawColor(255, 255, 255, 70 * alfa)
          surface.DrawTexturedRectUV(x, y, w, h, 0, 0, w / 512, h / 512)
          draw.NoTexture()
     end

     surface.SetDrawColor(R.cizgi.r, R.cizgi.g, R.cizgi.b, R.cizgi.a * alfa)
     surface.DrawOutlinedRect(x, y, w, h, 1)
     surface.SetDrawColor(R.altinK.r, R.altinK.g, R.altinK.b, 40 * alfa)
     surface.DrawOutlinedRect(x + 3, y + 3, w - 6, h - 6, 1)

     if (kose != false and K and K.Mat("frame_corner")) then
          local m = K.Mat("frame_corner")
          local s = kose or 26
          local hs = s / 2
          surface.SetMaterial(m)
          surface.SetDrawColor(255, 255, 255, 255 * alfa)
          surface.DrawTexturedRectRotated(x + hs - 3, y + hs - 3, s, s, 0)
          surface.DrawTexturedRectRotated(x + w - hs + 3, y + hs - 3, s, s, -90)
          surface.DrawTexturedRectRotated(x + w - hs + 3, y + h - hs + 3, s, s, 180)
          surface.DrawTexturedRectRotated(x + hs - 3, y + h - hs + 3, s, s, 90)
          draw.NoTexture()
     end
end

-- gök plakası: TAB menüsündeki dönen büyü çemberi + sabit S logosu; dokular yoksa çizilmiş halkalar
local plakaCember = Material("hoswars_ui/magic_circle.png", "smooth")
local plakaLogo = Material("hoswars_ui/logo_s.png", "smooth")

function SA.GokPlaka(x, y, r, alfa, donus)
     if (!plakaCember:IsError()) then
          local d = r * 2
          surface.SetMaterial(plakaCember)
          surface.SetDrawColor(255, 255, 255, 255 * (alfa or 1))
          surface.DrawTexturedRectRotated(x, y, d, d, donus or 0)
          if (!plakaLogo:IsError()) then
               -- TAB menüsündeki oran: 164 px çember içinde 60x75 logo
               local lw, lh = d * 60 / 164, d * 75 / 164
               surface.SetMaterial(plakaLogo)
               surface.DrawTexturedRect(x - lw / 2, y - lh / 2, lw, lh)
          end
          draw.NoTexture()
          return
     end
     SA.Halka(x, y, r, 1.5, R.altinK, 90 * (alfa or 1), 48)
     SA.Halka(x, y, r * 0.82, 1, R.altinK, 50 * (alfa or 1), 48)
     for i = 0, 11 do
          local an = math.rad((donus or 0) + i * 30)
          SA.Kalin(x + math.cos(an) * r * 0.84, y + math.sin(an) * r * 0.84, x + math.cos(an) * r * 0.97, y + math.sin(an) * r * 0.97, 1.5, R.altinK, 90 * (alfa or 1))
     end
end

-- HL2 sesleri (ui/achievement_earned yalnızca CS:S içeriğinde, herkeste yok)
function SA.Ses(tur)
     local ply = LocalPlayer()
     if (!IsValid(ply)) then return end
     if (tur == "iyi") then
          ply:EmitSound("ambient/energy/whiteflash.wav", 75, 150, 0.45, CHAN_STATIC)
          surface.PlaySound("buttons/blip1.wav")
     elseif (tur == "kotu") then
          surface.PlaySound("buttons/button10.wav")
     elseif (tur == "buyu") then
          ply:EmitSound("ambient/levels/citadel/strange_talk" .. math.random(3, 9) .. ".wav", 75, 130, 0.5, CHAN_STATIC)
     else
          surface.PlaySound("friends/message.wav")
     end
end

-- metni genişliğe sığdırır (sonuna …)
function SA.Kirp(str, font, maxw)
     surface.SetFont("sak." .. font)
     if (surface.GetTextSize(str) <= maxw) then return str end
     local out = ""
     for ch in string.gmatch(str, "[%z\1-\127\194-\244][\128-\191]*") do
          if (surface.GetTextSize(out .. ch .. "…") > maxw) then break end
          out = out .. ch
     end
     return out .. "…"
end

function SA.BuyuIkon(buyu)
     if (!HpwRewrite or !HpwRewrite.GetSpellIcon) then return nil end
     local m = HpwRewrite:GetSpellIcon(buyu)
     if (!m or m:IsError() or m:GetName() == "debug/debugempty" or m:GetName() == "__error") then return nil end
     return m
end

/*
*   rün (2B): ham yol [-1,1], merkez + yarıçap; oran 0..1 kadarı çizilir, uçta ışık
*/

function SA.Run2D(buyu, cx, cy, s, oran, renk, kalin, alfa, ucIsik)
     local sablon = SA.Sablon(buyu)
     if (!sablon) then return end
     local ham = sablon.ham
     alfa = alfa or 255
     oran = math.Clamp(oran or 1, 0, 1)

     local son = math.max(1, math.floor(#ham * oran))
     local px, py
     for i = 1, son do
          local p = ham[i]
          local x, y = cx + p.x * s, cy - p.y * s
          if (px) then SA.Kalin(px, py, x, y, kalin or 2, renk, alfa) end
          px, py = x, y
     end

     if (ucIsik and px) then
          SA.Isik(px, py, 16, renk, alfa)
          SA.Isik(px, py, 6, color_white, alfa)
     end

     -- başlangıç halkası
     local b = ham[1]
     SA.Halka(cx + b.x * s, cy - b.y * s, 5, 1.5, renk, alfa * 0.8, 16)
     return px, py
end

/*
*   2B parçacıklar :: her panel kendi örneğini tutar
*/

function SA.Parcacik()
     local P = {liste = {}}

     function P:Ekle(x, y, vx, vy, omur, boy, renk, yercekimi, tur)
          if (#self.liste > 450) then return end
          self.liste[#self.liste + 1] = {x = x, y = y, vx = vx, vy = vy, omur = omur, yas = 0, boy = boy, renk = renk, g = yercekimi or 60, tur = tur}
     end

     function P:Patlama(x, y, renk, n, guc)
          for i = 1, n do
               local a = math.Rand(0, math.pi * 2)
               local v = math.Rand(40, 170) * (guc or 1)
               self:Ekle(x, y, math.cos(a) * v, math.sin(a) * v - math.Rand(10, 50), math.Rand(0.6, 1.5), math.Rand(5, 14), renk, 90)
          end
     end

     function P:Yukselen(x, y, w, h, renk, n)
          for i = 1, n or 1 do
               self:Ekle(x + math.Rand(0, w), y + math.Rand(0, h), math.Rand(-6, 6), math.Rand(-28, -10), math.Rand(1.4, 3.2), math.Rand(3, 8), renk, -4)
          end
     end

     function P:Kul(x, y, renk, n)
          for i = 1, n do
               self:Ekle(x + math.Rand(-8, 8), y + math.Rand(-8, 8), math.Rand(-30, 30), math.Rand(-20, 10), math.Rand(0.9, 1.8), math.Rand(4, 9), renk, 110, "kul")
          end
     end

     function P:Ciz(ox, oy)
          local ft = math.min(FrameTime(), 0.05)
          ox, oy = ox or 0, oy or 0
          for i = #self.liste, 1, -1 do
               local p = self.liste[i]
               p.yas = p.yas + ft
               if (p.yas >= p.omur) then
                    table.remove(self.liste, i)
               else
                    p.vy = p.vy + p.g * ft
                    p.vx = p.vx * (1 - 1.4 * ft)
                    p.x = p.x + p.vx * ft
                    p.y = p.y + p.vy * ft

                    local f = 1 - p.yas / p.omur
                    local b = p.boy * (0.35 + f * 0.65)
                    if (p.tur == "kul") then
                         draw.NoTexture()
                         surface.SetDrawColor(p.renk.r, p.renk.g, p.renk.b, 200 * f)
                         surface.DrawRect(ox + p.x - b / 4, oy + p.y - b / 4, b / 2, b / 2)
                    else
                         SA.Isik(ox + p.x, oy + p.y, b, p.renk, 255 * math.min(1, f * 1.6))
                    end
               end
          end
     end

     return P
end

/*
*   ------------------------------------------------------------------
*   net
*   ------------------------------------------------------------------
*/

SA.AyarGeldi = SA.AyarGeldi or false

net.Receive("SardonAkran.Ayar", function()
     SA.Ayar = SA.AyarTemizle(net.ReadTable())
     SA.AyarGeldi = true
     hook.Run("SardonAkranAyar")
end)

net.Receive("SardonAkran.Harita", function()
     local n = net.ReadUInt(32)
     local ham = util.Decompress(net.ReadData(n) or "")
     local t = ham and util.JSONToTable(ham)
     if (!t) then return end

     for _, r in ipairs(t.raflar or {}) do
          r.pos = Vector(r.x, r.y, r.z)
          r.normal = Vector(r.nx, r.ny, r.nz)
     end
     for _, a in ipairs(t.alanlar or {}) do
          a.pos = Vector(a.x, a.y, a.z)
     end

     SA.HaritaVeri = {raflar = t.raflar or {}, alanlar = t.alanlar or {}}
     SA.KatOrtalama = nil
     hook.Run("SardonAkranHarita")
end)

net.Receive("SardonAkran.Gorev", function()
     local eski = SA.Gorev
     if (!net.ReadBool()) then
          SA.Gorev = nil
     else
          SA.Gorev = {
               buyu = net.ReadString(),
               asama = net.ReadUInt(3),
               raf = net.ReadUInt(16),
               okunan = net.ReadUInt(16),
               basari = net.ReadUInt(8),
               tohum = net.ReadUInt(32),
               ogretmen = net.ReadUInt(32),
               ogretmenAd = net.ReadString(),
               bitis = CurTime() + net.ReadUInt(32),
               cezaBitis = CurTime() + net.ReadFloat(),
               alindi = CurTime()
          }
     end

     if (SA.Gorev and (!eski or eski.asama != SA.Gorev.asama)) then SA.KartAcilis = RealTime() end
     hook.Run("SardonAkranGorev", SA.Gorev, eski)
end)

net.Receive("SardonAkran.Panel", function()
     SA.PanelVeri = net.ReadTable()
     SA.PanelVeri.alindi = RealTime()
     hook.Run("SardonAkranPanel", SA.PanelVeri)
end)

function SA.PanelIste()
     net.Start("SardonAkran.PanelIste")
     net.SendToServer()
end

function SA.Teklif(ent, buyu)
     net.Start("SardonAkran.Teklif")
          net.WriteEntity(ent)
          net.WriteString(buyu)
     net.SendToServer()
end

function SA.Onayla(ogrenciId, kabul)
     net.Start("SardonAkran.Onay")
          net.WriteUInt(ogrenciId, 32)
          net.WriteBool(kabul)
     net.SendToServer()
end

function SA.Iptal(ogrenciId)
     net.Start("SardonAkran.Iptal")
          net.WriteUInt(ogrenciId, 32)
     net.SendToServer()
end

function SA.CharOyuncu(charid)
     for _, p in player.Iterator() do
          local c = p:GetCharacter()
          if (c and c:GetID() == charid) then return p end
     end
end

function SA.RafBul(id)
     for _, r in ipairs(SA.HaritaVeri.raflar) do
          if (r.id == id) then return r end
     end
end

function SA.AlandaMi(pos)
     for _, a in ipairs(SA.HaritaVeri.alanlar) do
          if (SA.AlanIcinde(a, a.pos, pos)) then return a end
     end
end

function SA.EnYakinAlan(pos)
     local en, enD
     for _, a in ipairs(SA.HaritaVeri.alanlar) do
          local d = SA.AlanUzaklik(a, a.pos, pos)
          if (!enD or d < enD) then en, enD = a, d end
     end
     return en, enD
end

-- katların ortalama yüksekliği (raflardan); oyuncunun bulunduğu katı tahmin eder
function SA.KatBul(pos)
     if (!SA.KatOrtalama) then
          local top, say = {}, {}
          for _, r in ipairs(SA.HaritaVeri.raflar) do
               top[r.kat] = (top[r.kat] or 0) + r.pos.z
               say[r.kat] = (say[r.kat] or 0) + 1
          end
          SA.KatOrtalama = {}
          for k, t in pairs(top) do SA.KatOrtalama[k] = t / say[k] end
     end

     -- kütüphaneden çok uzaktaysa kat söylenmez
     local yakin = false
     for _, r in ipairs(SA.HaritaVeri.raflar) do
          if (math.abs(r.pos.x - pos.x) < 2600 and math.abs(r.pos.y - pos.y) < 2600) then yakin = true break end
     end
     if (!yakin) then return nil end

     local enK, enD
     for k, z in pairs(SA.KatOrtalama) do
          local d = math.abs(z - (pos.z + 40))
          if (!enD or d < enD) then enK, enD = k, d end
     end
     return enK
end

/*
*   ------------------------------------------------------------------
*   bildirim şeritleri
*   ------------------------------------------------------------------
*/

local seritler = {}
local seritP = SA.Parcacik()

function SA.Serit(baslik, alt, tur)
     SA.Fontlar()
     local renk = tur == "kotu" and R.kotu or (tur == "bilgi" and R.adacayi or R.altin)
     table.insert(seritler, 1, {baslik = baslik, alt = alt, renk = renk, bas = RealTime(), sure = tur == "kotu" and 5 or 6.5, tur = tur})
     while (#seritler > 3) do table.remove(seritler) end

     local y = ScrH() * 0.16
     if (tur == "kotu") then
          seritP:Kul(ScrW() / 2, y, Color(120, 110, 100), 24)
     else
          seritP:Patlama(ScrW() / 2, y, renk, tur == "iyi" and 40 or 18, 1.1)
     end
end

net.Receive("SardonAkran.Bildirim", function()
     local baslik, alt, tur = net.ReadString(), net.ReadString(), net.ReadString()
     SA.Serit(baslik, alt, tur)
     SA.Ses(tur)
     hook.Run("SardonAkranBildirim", baslik, alt, tur)
     chat.AddText(Color(222, 192, 120), "[Akran Yardımı] ", color_white, baslik, Color(171, 169, 147), alt != "" and (" · " .. alt) or "")
end)

local function SeritCiz()
     if (#seritler == 0 and #seritP.liste == 0) then return end
     local now = RealTime()
     local y0 = ScrH() * 0.16

     for i = #seritler, 1, -1 do
          local s = seritler[i]
          local t = now - s.bas
          if (t > s.sure) then
               table.remove(seritler, i)
          else
               local giris = math.Clamp(t / 0.35, 0, 1)
               local cikis = math.Clamp((s.sure - t) / 0.6, 0, 1)
               local a = math.min(giris, cikis)
               local e = 1 - (1 - giris) ^ 3

               local bw = math.max(SA.MetinG(s.baslik, "baslik"), SA.MetinG(s.alt, "alt")) + 120
               local bh = s.alt != "" and 74 or 50
               local x = ScrW() / 2 - bw / 2
               local y = y0 + (i - 1) * (bh + 8) - (1 - e) * 20

               SA.Isik(ScrW() / 2, y + bh / 2, bw * 0.55, s.renk, 26 * a)
               SA.Kart(x, y, bw, bh, a * 0.97, 18)

               local band = SA.Doku("parchment_band")
               if (band) then
                    surface.SetMaterial(band)
                    surface.SetDrawColor(s.renk.r, s.renk.g, s.renk.b, 34 * a)
                    surface.DrawTexturedRect(x + 4, y + 4, bw - 8, bh - 8)
                    draw.NoTexture()
               end

               SA.Kalin(x + 30, y + bh - 9, x + bw - 30, y + bh - 9, 1, s.renk, 90 * a)
               SA.Yildiz(x + 24, y + bh / 2, 7, s.renk, 255 * a)
               SA.Yildiz(x + bw - 24, y + bh / 2, 7, s.renk, 255 * a)

               SA.Metin(s.baslik, "baslik", ScrW() / 2, y + (s.alt != "" and 24 or bh / 2), s.renk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 255 * a)
               if (s.alt != "") then SA.Metin(s.alt, "alt", ScrW() / 2, y + 51, R.fildisi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 230 * a) end
          end
     end

     seritP:Ciz()
end

/*
*   ------------------------------------------------------------------
*   görev takip kartı (sağ) :: aşamaya göre ipucu, kat tahmini, talim pusulası
*   ------------------------------------------------------------------
*/

local kartP = SA.Parcacik()
local sonKartToz = 0

local function SureYaz(sn)
     sn = math.max(0, math.floor(sn))
     if (sn >= 3600) then return string.format("%d sa %02d dk", math.floor(sn / 3600), math.floor(sn % 3600 / 60)) end
     return string.format("%02d:%02d", math.floor(sn / 60), sn % 60)
end
SA.SureYaz = SureYaz

local function Pusula(cx, cy, r, hedefPos, renk, a)
     local ply = LocalPlayer()
     local yon = (hedefPos - ply:GetPos()):Angle().y
     local fark = math.rad(math.NormalizeAngle(yon - ply:EyeAngles().y))
     -- ekranda yukarı = ileri, sağ = sağ
     local an = -fark - math.pi / 2

     SA.Halka(cx, cy, r, 1.2, R.altinK, 120 * a, 32)
     for i = 0, 3 do
          local k = i * math.pi / 2
          SA.Kalin(cx + math.cos(k) * (r - 4), cy + math.sin(k) * (r - 4), cx + math.cos(k) * r, cy + math.sin(k) * r, 1.5, R.altinK, 140 * a)
     end

     local ux, uy = math.cos(an), math.sin(an)
     local px, py = -uy, ux
     local uc = {x = cx + ux * (r - 6), y = cy + uy * (r - 6)}
     local sol = {x = cx - ux * 6 + px * 7, y = cy - uy * 6 + py * 7}
     local sag = {x = cx - ux * 6 - px * 7, y = cy - uy * 6 - py * 7}
     draw.NoTexture()
     surface.SetDrawColor(renk.r, renk.g, renk.b, 255 * a)
     surface.DrawPoly({uc, sag, {x = cx, y = cy}})
     surface.DrawPoly({uc, {x = cx, y = cy}, sol})
     SA.Isik(uc.x, uc.y, 10, renk, 160 * a)
end

local function KartCiz()
     local g = SA.Gorev
     if (!g or SA.CizimModu) then return end
     local ply = LocalPlayer()
     if (!IsValid(ply) or !ply:Alive()) then return end

     local asama = SA.Asamalar[g.asama]
     if (!asama) then return end

     local acilis = math.Clamp((RealTime() - (SA.KartAcilis or 0)) / 0.5, 0, 1)
     local e = 1 - (1 - acilis) ^ 3
     local W, H = 390, 198
     local x = ScrW() - W - 24 + (1 - e) * 60
     local y = math.floor(ScrH() * 0.30)
     local a = e

     SA.Kart(x, y, W, H, a * 0.95, 22)

     -- üst satır: aşama noktaları
     SA.Metin("AKRAN YARDIMI  ·  " .. asama.ust, "ust", x + 18, y + 16, R.altinK, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 255 * a)
     for i = 1, 4 do
          local nx = x + W - 18 - (4 - i) * 14
          local tamam, simdi = i < g.asama, i == g.asama
          if (simdi) then
               SA.Isik(nx, y + 16, 10 + math.sin(RealTime() * 4) * 2, R.altin, 160 * a)
               SA.Yildiz(nx, y + 16, 5, R.altin, 255 * a)
          else
               SA.Daire(nx, y + 16, 3, tamam and R.adacayi or R.sonuk, (tamam and 255 or 120) * a, 12)
          end
     end

     -- büyü simgesi + adı
     local ikon = SA.BuyuIkon(g.buyu)
     local slot = SA.Doku("icon_slot")
     if (slot) then
          surface.SetMaterial(slot)
          surface.SetDrawColor(255, 255, 255, 255 * a)
          surface.DrawTexturedRect(x + 14, y + 30, 46, 46)
     end
     if (ikon) then
          surface.SetMaterial(ikon)
          surface.SetDrawColor(255, 255, 255, 255 * a)
          surface.DrawTexturedRect(x + 19, y + 35, 36, 36)
     else
          SA.Run2D(g.buyu, x + 37, y + 53, 14, 1, R.altin, 1.5, 220 * a)
     end
     draw.NoTexture()

     SA.Metin(g.buyu, "orta", x + 70, y + 41, R.fildisi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 255 * a)
     SA.Metin(asama.ad .. "  ·  " .. g.asama .. "/4", "kucuk", x + 70, y + 64, R.altin, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 255 * a)

     local ty = y + 94
     local function Satir(str, renk, font)
          SA.Metin(str, font or "kucuk", x + 18, ty, renk or R.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 255 * a)
          ty = ty + 22
     end

     if (g.asama == 1) then
          local raf = SA.RafBul(g.raf)
          if (raf) then
               Satir("Hedef: " .. (SA.Roma[raf.kat] or raf.kat) .. ". kat  ·  " .. raf.no .. " numaralı raf", R.fildisi, "alt")
               local kat = SA.KatBul(ply:GetPos())
               if (!kat) then
                    Satir("Kütüphaneye git.", R.uyari)
               elseif (kat == raf.kat) then
                    Satir("Doğru kattasın, raf numaralarına bak.", R.adacayi)
               else
                    local fark = raf.kat - kat
                    Satir("Şu an " .. (SA.Roma[kat] or kat) .. ". kattasın  ·  " .. math.abs(fark) .. " kat " .. (fark > 0 and "yukarı" or "aşağı") .. " çık", R.uyari)
               end
          else
               Satir("Hedef raf kaldırılmış; görevi iptal edip yeniden başla.", R.kotu)
          end
          local ceza = (g.cezaBitis or 0) - CurTime()
          if (ceza > 0) then
               Satir("Yanlış kitap: " .. math.ceil(ceza) .. " sn bekle", R.kotu)
          else
               Satir("Rafa bakıp E'ye bas.", R.sonuk)
          end
     elseif (g.asama == 2) then
          local gerek = SA.OkumaGerek(ply)
          local okunan = ply:GetNW2Int("SardonAkranOkunan", g.okunan)
          local okuyor = ply:GetNW2Bool("SardonAkranOkuyor")
          Satir(okuyor and "Okuyorsun..." or "Raftan uzaklaştın; okuma durdu.", okuyor and R.adacayi or R.kotu, "alt")
          Satir("Kalan: " .. SureYaz(gerek - okunan), R.soluk)

          local bw = W - 36
          surface.SetDrawColor(30, 36, 28, 230 * a)
          surface.DrawRect(x + 18, ty, bw, 5)
          local f = math.Clamp(okunan / gerek, 0, 1)
          surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 255 * a)
          surface.DrawRect(x + 18, ty, bw * f, 5)
          SA.Isik(x + 18 + bw * f, ty + 2, 9, R.altin, 200 * a)
     elseif (g.asama == 3) then
          local alan, uzak = SA.EnYakinAlan(ply:GetPos())
          local ogretmen = SA.CharOyuncu(g.ogretmen)
          local icinde = SA.AlandaMi(ply:GetPos())

          if (icinde) then
               local tus = SardonConfig and SardonConfig.Options and SardonConfig.Options.akran_talim and input.GetKeyName(SardonConfig:Get("akran_talim")) or "J"
               Satir("Talim alanındasın · [" .. string.upper(tus or "J") .. "] talime başla", R.adacayi, "alt")
          elseif (alan) then
               Satir((alan.ad or "Talim alanı") .. "  ·  " .. math.max(0, math.floor(uzak * 0.019)) .. " m", R.fildisi, "alt")
               Pusula(x + W - 36, y + 58, 16, alan.pos, R.altin, a)
          else
               Satir("Henüz talim alanı yok.", R.kotu)
          end

          if (ogretmen == ply) then
               Satir("Test görevi: öğretmen sensin.", R.sonuk)
          elseif (IsValid(ogretmen) and ogretmen:Alive()) then
               local d = ogretmen:GetPos():Distance(ply:GetPos())
               local ok = d <= SA.Ayar.ogretmenMesafe
               Satir("Öğretmenin " .. (g.ogretmenAd or "") .. (ok and " seni izliyor" or " uzakta"), ok and R.adacayi or R.uyari)
          else
               Satir("Öğretmenin " .. (g.ogretmenAd or "") .. " burada değil.", R.uyari)
          end
          Satir("Başarılı rün: " .. g.basari .. " / " .. SA.Ayar.basariGerek, R.soluk)
     elseif (g.asama == 4) then
          Satir("Öğretmeninin onayı bekleniyor.", R.adacayi, "alt")
          Satir((g.ogretmenAd or "Öğretmenin") .. " asa menüsünden onaylayacak.", R.soluk)
     end

     SA.Metin("Süre: " .. SureYaz(g.bitis - CurTime()), "kucuk", x + W - 18, y + H - 14, R.sonuk, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, 200 * a)

     if (RealTime() > sonKartToz) then
          sonKartToz = RealTime() + 0.25
          kartP:Yukselen(x + 10, y + H - 20, W - 20, 10, R.altinK, 1)
     end
     kartP:Ciz()
end

/*
*   ------------------------------------------------------------------
*   okuma kitabı (ekran altı) :: sayfalar ilerler, rün yavaşça belirir
*   ------------------------------------------------------------------
*/

local kitapP = SA.Parcacik()
local kitapDurum = {kucuk = 0, sonSayfa = 0, cevir = 0}

local function OkumaCiz()
     local g = SA.Gorev
     if (!g or g.asama != 2) then return end
     local ply = LocalPlayer()

     local gerek = SA.OkumaGerek(ply)
     local okunan = ply:GetNW2Int("SardonAkranOkunan", g.okunan)
     local okuyor = ply:GetNW2Bool("SardonAkranOkuyor")
     local f = math.Clamp(okunan / gerek, 0, 1)

     -- hareket ederken küçülür, durunca açılır
     local hedef = (ply:GetVelocity():Length2D() > 60 or !okuyor) and 1 or 0
     kitapDurum.kucuk = Lerp(math.min(1, FrameTime() * 5), kitapDurum.kucuk, hedef)
     local k = kitapDurum.kucuk

     local W, H = 760, Lerp(k, 290, 68)
     local x, y = ScrW() / 2 - W / 2, ScrH() - H - 168

     local metin = SA.KitapMetni(g.buyu)
     local sayfa = math.min(#metin, 1 + math.floor(f * #metin))
     if (sayfa != kitapDurum.sonSayfa) then
          if (kitapDurum.sonSayfa != 0) then
               kitapDurum.cevir = RealTime()
               kitapP:Yukselen(x + W / 2 - 20, y + 30, 40, H - 60, R.parsomen, 14)
          end
          kitapDurum.sonSayfa = sayfa
     end

     SA.Kart(x, y, W, H, 0.96, 24)

     if (k < 0.98) then
          local ia = 1 - k
          local px, py, pw, ph = x + 16, y + 16, W / 2 - 22, H - 46
          local qx = x + W / 2 + 6

          -- parşömen sayfalar
          for _, sx in ipairs({px, qx}) do
               surface.SetDrawColor(R.parsomen.r, R.parsomen.g, R.parsomen.b, 235 * ia)
               draw.NoTexture()
               surface.DrawRect(sx, py, pw, ph)
               surface.SetDrawColor(120, 96, 60, 60 * ia)
               surface.DrawOutlinedRect(sx + 4, py + 4, pw - 8, ph - 8, 1)
          end
          -- cilt gölgesi
          for i = 0, 10 do
               surface.SetDrawColor(60, 40, 20, (60 - i * 5) * ia)
               surface.DrawRect(x + W / 2 - 6 + i, py, 1, ph)
               surface.DrawRect(x + W / 2 - 6 - i, py, 1, ph)
          end

          -- sol: bölüm metni (sayfa çevrilince kayarak gelir)
          local cev = math.Clamp((RealTime() - kitapDurum.cevir) / 0.45, 0, 1)
          local ma = ia * cev
          local bolum = metin[sayfa]
          SA.Metin(bolum[1], "orta", px + 16, py + 22, R.murekkep, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 255 * ma)
          SA.Kalin(px + 16, py + 38, px + 16 + SA.MetinG(bolum[1], "orta"), py + 38, 1, R.murekkep, 120 * ma)
          local satirlar = SA.Sar(bolum[2], "kitapK", pw - 32)
          for i, s in ipairs(satirlar) do
               if (i > 8) then break end
               SA.Metin(s, "kitapK", px + 16 + (1 - cev) * 12, py + 30 + i * 20, R.murekkep, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 230 * ma)
          end
          SA.Metin("— " .. sayfa .. " —", "kitapK", px + pw / 2, py + ph - 12, Color(110, 86, 56), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 200 * ia)

          -- sağ: rün (okundukça mürekkep yayılır)
          local cx, cy = qx + pw / 2, py + ph / 2 - 6
          local r = math.min(pw, ph) * 0.36
          SA.GokPlaka(cx, cy, r * 1.28, 0.22 * ia, RealTime() * 4)
          SA.Run2D(g.buyu, cx, cy, r, 1, Color(120, 96, 60), 1.5, 50 * ia)
          local ux, uy = SA.Run2D(g.buyu, cx, cy, r, f, R.murekkep, 2.6, 255 * ia, false)
          if (ux and okuyor and f < 1) then
               SA.Isik(ux, uy, 14 + math.sin(RealTime() * 6) * 3, R.altin, 200 * ia)
               if (math.random() < 0.3) then kitapP:Ekle(ux, uy, math.Rand(-12, 12), math.Rand(-30, -8), math.Rand(0.5, 1.1), math.Rand(3, 6), R.altin, 0) end
          end
          SA.Metin("Asa hareketi", "kitapK", cx, py + ph - 12, Color(110, 86, 56), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 200 * ia)
     end

     -- alt şerit: durum + ilerleme
     local by = y + H - 22
     local durum = okuyor and ("Okunuyor  ·  " .. g.buyu) or "Raftan uzaklaştın · okuma durdu"
     SA.Metin(durum, "kucuk", x + 18, by + 4, okuyor and R.adacayi or R.kotu, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     SA.Metin(SureYaz(gerek - okunan), "kucuk", x + W - 18, by + 4, R.fildisi, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
     local bx, bw = x + 290, W - 380
     surface.SetDrawColor(30, 36, 28, 230)
     draw.NoTexture()
     surface.DrawRect(bx, by + 2, bw, 4)
     surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 255)
     surface.DrawRect(bx, by + 2, bw * f, 4)
     SA.Isik(bx + bw * f, by + 4, 10, R.altin, okuyor and 220 or 80)

     kitapP:Ciz()
end

hook.Add("HUDPaint", "SardonAkran.Ekran", function()
     SA.Fontlar()
     KartCiz()
     OkumaCiz()
     SeritCiz()
end)

/*
*   ------------------------------------------------------------------
*   raf paneli :: raftaki kitaplar, doğru olanı seç
*   ------------------------------------------------------------------
*/

-- panel içinde döndürülmüş metin: dönüş merkezi ekran koordinatı, çizim panel koordinatı
-- (sardon_shopic iksirci "TÜKENDİ" damgasıyla aynı yöntem)
local function YaziDondur(panel, str, font, x, y, renk, aci)
     local ax, ay = panel:LocalToScreen(x, y)
     local m = Matrix()
     m:Translate(Vector(ax, ay, 0))
     m:Rotate(Angle(0, aci, 0))
     m:Translate(Vector(-ax, -ay, 0))
     render.PushFilterMag(TEXFILTER.ANISOTROPIC)
     render.PushFilterMin(TEXFILTER.ANISOTROPIC)
     cam.PushModelMatrix(m, true)
          draw.SimpleText(str, "sak." .. font, x, y, renk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     cam.PopModelMatrix()
     render.PopFilterMin()
     render.PopFilterMag()
end

function SA.RafPaneli(rafId, ceza)
     local g = SA.Gorev
     local raf = SA.RafBul(rafId)
     if (!g or !raf) then return end
     SA.Fontlar()

     if (IsValid(SA.RafPanel)) then SA.RafPanel:Remove() end

     local kitaplar = SA.RafKitaplari(rafId, g)
     local W, H = 860, 470
     local fr = vgui.Create("DFrame")
     fr:SetSize(W, H)
     fr:Center()
     fr:SetTitle("")
     fr:ShowCloseButton(false)
     fr:SetDraggable(false)
     fr:MakePopup()
     fr:SetAlpha(0)
     fr:AlphaTo(255, 0.2)
     SA.RafPanel = fr

     local P = SA.Parcacik()
     local st = {secili = nil, sonuc = nil, sonucT = 0, cezaBitis = CurTime() + (ceza or 0), ucan = nil, sallan = {}}
     local RAF_X, RAF_Y, RAF_W, RAF_H = 40, 96, W - 80, 290
     local zemin = RAF_Y + RAF_H - 18

     -- kitap yerleşimi
     local toplamW = 0
     for _, k in ipairs(kitaplar) do
          k.w = math.floor(54 + k.kalin * 30)
          k.h = math.floor(k.boy * (RAF_H - 46))
          toplamW = toplamW + k.w + 6
     end
     local bx = RAF_X + (RAF_W - toplamW) / 2
     for _, k in ipairs(kitaplar) do
          k.x, k.kalk = bx, 0
          bx = bx + k.w + 6
     end

     local function Uzerinde(mx, my)
          for i, k in ipairs(kitaplar) do
               if (mx >= k.x and mx <= k.x + k.w and my >= zemin - k.h - 14 and my <= zemin) then return i end
          end
     end

     fr.Paint = function(s, w, h)
          local now = RealTime()
          SA.Kart(0, 0, w, h, 1, 30)

          SA.Metin("KÜTÜPHANE  ·  " .. (SA.Roma[raf.kat] or raf.kat) .. ". KAT", "ust", 40, 32, R.altinK, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          SA.Metin(raf.no .. " numaralı raf", "buyuk", 40, 60, R.fildisi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          SA.Metin("Aradığın kitap:", "kucuk", w - 40, 34, R.soluk, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
          SA.Metin(g.buyu, "baslik", w - 40, 58, R.altin, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

          -- raf gövdesi (ahşap)
          for i = 0, RAF_H do
               local t = i / RAF_H
               surface.SetDrawColor(36 + t * 18, 22 + t * 10, 14 + t * 6, 255)
               surface.DrawRect(RAF_X, RAF_Y + i, RAF_W, 1)
          end
          local deri = SA.Doku("leather_dark")
          if (deri) then
               surface.SetMaterial(deri)
               surface.SetDrawColor(140, 100, 70, 40)
               surface.DrawTexturedRectUV(RAF_X, RAF_Y, RAF_W, RAF_H, 0, 0, RAF_W / 512, RAF_H / 512)
               draw.NoTexture()
          end
          -- arka duvardaki mum ışığı
          SA.Isik(RAF_X + RAF_W * 0.2, RAF_Y + 40, 160, Color(255, 170, 90), 22 + math.sin(now * 3) * 4)
          SA.Isik(RAF_X + RAF_W * 0.8, RAF_Y + 40, 160, Color(255, 170, 90), 22 + math.cos(now * 2.6) * 4)

          local mx, my = s:CursorPos()
          local hov = (!st.sonuc and !st.ucan) and Uzerinde(mx, my) or nil
          local cezali = st.cezaBitis > CurTime()

          for i, k in ipairs(kitaplar) do
               local hedefKalk = (hov == i and !cezali) and 16 or 0
               k.kalk = Lerp(math.min(1, FrameTime() * 12), k.kalk, hedefKalk)
               local sx = (st.sallan[i] and st.sallan[i] > now) and math.sin(now * 60) * 3 or 0
               local kx, ky = k.x + sx, zemin - k.h - k.kalk

               local gorunur = true
               if (st.ucan == i) then
                    local t = math.Clamp((now - st.sonucT) / 0.8, 0, 1)
                    ky = ky - t * t * 220
                    gorunur = t < 1
               end

               if (gorunur) then
                    local c = SA.KitapRenkleri[k.renk] or SA.KitapRenkleri[1]
                    local dim = cezali and 0.55 or 1
                    -- sırt: kenarlarda koyulaşan gövde
                    for j = 0, k.w - 1 do
                         local t = math.abs(j / (k.w - 1) - 0.42) * 2
                         local m = (1 - t * 0.55) * dim
                         surface.SetDrawColor(c.r * m, c.g * m, c.b * m, 255)
                         surface.DrawRect(kx + j, ky, 1, k.h)
                    end
                    -- altın bantlar
                    local bant = R.altinK
                    surface.SetDrawColor(bant.r * dim, bant.g * dim, bant.b * dim, 230)
                    surface.DrawRect(kx + 3, ky + 12, k.w - 6, 3)
                    surface.DrawRect(kx + 3, ky + k.h - 16, k.w - 6, 3)
                    if (k.bant > 0) then
                         surface.DrawRect(kx + 3, ky + 20, k.w - 6, 1)
                         surface.DrawRect(kx + 3, ky + k.h - 22, k.w - 6, 1)
                    end
                    if (k.bant == 2) then SA.Yildiz(kx + k.w / 2, ky + k.h - 34, 5, bant, 220 * dim) end

                    -- başlık (dikey); model matrisi ekran koordinatı ister
                    local cx, cy = kx + k.w / 2, ky + k.h / 2
                    k.yazi = k.yazi or SA.Kirp(k.baslik, "sirt", k.h - 46)
                    YaziDondur(s, k.yazi, "sirt", cx, cy, Color(232 * dim, 214 * dim, 168 * dim), -90)

                    if (hov == i) then
                         SA.Isik(cx, ky - 6, k.w * 0.9, R.altin, 50)
                         surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 160)
                         surface.DrawOutlinedRect(kx - 1, ky - 1, k.w + 2, k.h + 2, 1)
                         if (math.random() < 0.15) then P:Yukselen(kx, ky - 4, k.w, 4, Color(200, 180, 140), 1) end
                    end
               end
          end

          -- raf tahtası
          surface.SetDrawColor(70, 44, 26, 255)
          surface.DrawRect(RAF_X - 8, zemin, RAF_W + 16, 14)
          surface.SetDrawColor(110, 76, 44, 255)
          surface.DrawRect(RAF_X - 8, zemin, RAF_W + 16, 2)
          surface.SetDrawColor(R.altinK.r, R.altinK.g, R.altinK.b, 120)
          surface.DrawOutlinedRect(RAF_X, RAF_Y, RAF_W, RAF_H, 1)

          -- alt yazı: üzerindeki kitabın adı ya da durum
          local alt, altRenk = "Bir kitabın üzerine gel, adını oku; doğru olanı seç.", R.soluk
          if (cezali) then
               alt, altRenk = "Yanlış kitap · " .. math.ceil(st.cezaBitis - CurTime()) .. " saniye bekle", R.kotu
          elseif (st.sonuc == true) then
               alt, altRenk = "Buldun! Okumaya başlıyorsun...", R.altin
          elseif (hov) then
               alt, altRenk = "“" .. kitaplar[hov].baslik .. "”", R.fildisi
          end
          SA.Metin(alt, hov and "orta" or "alt", w / 2, H - 52, altRenk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          SA.Metin("ESC / sağ tık: kapat", "kucuk", w / 2, H - 24, R.sonuk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

          P:Ciz()
     end

     fr.OnMousePressed = function(s, kod)
          if (kod == MOUSE_RIGHT) then s:Remove() return end
          if (st.sonuc or st.ucan or st.bekliyor) then return end
          if (st.cezaBitis > CurTime()) then
               surface.PlaySound("buttons/button10.wav")
               return
          end
          local mx, my = s:CursorPos()
          local i = Uzerinde(mx, my)
          if (!i) then return end

          st.secili = i
          st.bekliyor = true
          surface.PlaySound("physics/cardboard/cardboard_box_impact_soft2.wav")
          net.Start("SardonAkran.KitapSec")
               net.WriteUInt(rafId, 16)
               net.WriteUInt(i, 8)
          net.SendToServer()
     end

     fr.OnKeyCodePressed = function(s, kod)
          if (kod == KEY_ESCAPE or kod == KEY_E) then s:Remove() end
     end

     fr.Think = function(s)
          if (input.IsKeyDown(KEY_ESCAPE)) then
               gui.HideGameUI()
               s:Remove()
               return
          end
          local r = SA.RafBul(rafId)
          if (!r or LocalPlayer():EyePos():Distance(r.pos) > 260 or !LocalPlayer():Alive()) then s:Remove() end
     end

     function fr:Sonuc(ok, cezaSn)
          st.bekliyor = false
          local i = st.secili
          local k = i and kitaplar[i]
          if (!k) then return end
          local cx, cy = k.x + k.w / 2, zemin - k.h / 2

          if (ok) then
               st.sonuc, st.sonucT, st.ucan = true, RealTime(), i
               P:Patlama(cx, cy, R.altin, 70, 1.3)
               P:Yukselen(k.x, zemin - k.h, k.w, k.h, R.altin, 30)
               SA.Ses("iyi")
               timer.Simple(1.1, function() if (IsValid(fr)) then fr:AlphaTo(0, 0.25, 0, function() if (IsValid(fr)) then fr:Remove() end end) end end)
          else
               st.cezaBitis = CurTime() + (cezaSn or 0)
               st.sallan[i] = RealTime() + 0.35
               P:Kul(cx, zemin - k.h, Color(150, 140, 125), 40)
               surface.PlaySound("physics/wood/wood_box_impact_soft3.wav")
               if (SA.Gorev) then SA.Gorev.cezaBitis = st.cezaBitis end
          end
     end
end

net.Receive("SardonAkran.RafAc", function()
     local id = net.ReadUInt(16)
     local ceza = net.ReadFloat()
     SA.RafPaneli(id, ceza)
end)

net.Receive("SardonAkran.KitapSonuc", function()
     local ok = net.ReadBool()
     local ceza = net.ReadFloat()
     if (IsValid(SA.RafPanel) and SA.RafPanel.Sonuc) then SA.RafPanel:Sonuc(ok, ceza) end
end)

/*
*   ------------------------------------------------------------------
*   küçük pencere (davet / onay) :: deri kart, büyü simgesi çevresinde dönen kıvılcımlar
*   ------------------------------------------------------------------
*/

local function Pencere(baslik, ust, buyu, govde, dugmeler, sure)
     SA.Fontlar()
     local W, H = 520, 286
     local fr = vgui.Create("DFrame")
     fr:SetSize(W, H)
     fr:SetPos(ScrW() / 2 - W / 2, ScrH() * 0.58 - H / 2)
     fr:SetTitle("")
     fr:ShowCloseButton(false)
     fr:SetDraggable(true)
     fr:MakePopup()
     fr:SetKeyboardInputEnabled(false)
     fr:SetAlpha(0)
     fr:AlphaTo(255, 0.25)

     local P = SA.Parcacik()
     local bas = RealTime()
     local bitis = sure and (RealTime() + sure)
     P:Patlama(70, 104, R.altin, 30, 0.8)

     fr.Paint = function(s, w, h)
          local now = RealTime()
          SA.Isik(w / 2, h / 2, w * 0.7, R.altin, 18)
          SA.Kart(0, 0, w, h, 1, 26)

          SA.Metin(ust, "ust", 30, 28, R.altinK, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          SA.Metin(baslik, "baslik", 30, 52, R.fildisi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

          -- simge + yörünge
          local cx, cy = 70, 120
          SA.GokPlaka(cx, cy, 44, 0.5, now * 10)
          local ikon = SA.BuyuIkon(buyu)
          if (ikon) then
               surface.SetMaterial(ikon)
               surface.SetDrawColor(255, 255, 255, 255)
               surface.DrawTexturedRect(cx - 22, cy - 22, 44, 44)
               draw.NoTexture()
          else
               SA.Run2D(buyu, cx, cy, 20, 1, R.altin, 2, 255)
          end
          for i = 0, 2 do
               local an = now * 1.6 + i * math.pi * 2 / 3
               local px, py = cx + math.cos(an) * 48, cy + math.sin(an) * 48
               SA.Isik(px, py, 8, R.altin, 220)
               if (math.random() < 0.08) then P:Ekle(px, py, 0, -10, 0.8, 4, R.altin, -10) end
          end

          SA.Metin(buyu, "orta", 136, 96, R.altin, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          for i, satir in ipairs(SA.Sar(govde, "alt", w - 166)) do
               if (i > 4) then break end
               SA.Metin(satir, "alt", 136, 112 + i * 21, R.fildisi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          end

          if (bitis) then
               local f = math.Clamp((bitis - now) / sure, 0, 1)
               surface.SetDrawColor(30, 36, 28, 230)
               surface.DrawRect(24, h - 78, w - 48, 3)
               surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 255)
               surface.DrawRect(24, h - 78, (w - 48) * f, 3)
               SA.Isik(24 + (w - 48) * f, h - 77, 7, R.altin, 200)
          end

          P:Ciz()
     end

     fr.Think = function(s)
          if (bitis and RealTime() > bitis) then s:Remove() end
     end

     local n = #dugmeler
     local bw = math.floor((W - 48 - (n - 1) * 10) / n)
     for i, d in ipairs(dugmeler) do
          local b = vgui.Create("DButton", fr)
          b:SetPos(24 + (i - 1) * (bw + 10), H - 60)
          b:SetSize(bw, 38)
          b:SetText("")
          b.Paint = function(s, w, h)
               local hov = s:IsHovered()
               local birincil = d.birincil
               local tex = SA.K() and SA.K().Slice3
               if (birincil and tex and SA.K().Slice3(hov and "button_hover" or "button_primary", 0, 0, w, h, 24)) then
                    draw.NoTexture()
               else
                    surface.SetDrawColor(birincil and 92 or 20, birincil and 44 or 28, birincil and 36 or 24, 255)
                    surface.DrawRect(0, 0, w, h)
                    surface.SetDrawColor(R.altinK.r, R.altinK.g, R.altinK.b, hov and 220 or 120)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
               end
               if (hov) then SA.Isik(w / 2, h / 2, w * 0.45, R.altin, 30) end
               SA.Metin(d.ad, "alt", w / 2, h / 2, hov and R.altin or R.fildisi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          end
          b.DoClick = function()
               surface.PlaySound("buttons/lightswitch2.wav")
               if (d.fn) then d.fn() end
               if (IsValid(fr)) then fr:AlphaTo(0, 0.15, 0, function() if (IsValid(fr)) then fr:Remove() end end) end
          end
     end

     return fr
end

net.Receive("SardonAkran.Davet", function()
     local ent = net.ReadEntity()
     local _ = net.ReadUInt(32)
     local ad = net.ReadString()
     local buyu = net.ReadString()
     local sure = net.ReadUInt(8)

     SA.Ses("buyu")
     if (IsValid(SA.DavetPanel)) then SA.DavetPanel:Remove() end

     local function Cevap(v)
          net.Start("SardonAkran.DavetCevap")
               net.WriteBool(v)
          net.SendToServer()
     end

     SA.DavetPanel = Pencere("Akran Yardımı Daveti", "BİR ÖĞRETMEN SENİ SEÇTİ", buyu,
          ad .. " sana " .. buyu .. " büyüsünü öğretmek istiyor. Kabul edersen kütüphanede kitabını bulacak, okuyacak ve talim alanında rününü çizeceksin.",
          {
               {ad = "Kabul et", birincil = true, fn = function() Cevap(true) end},
               {ad = "Reddet", fn = function() Cevap(false) end}
          }, sure)
end)

net.Receive("SardonAkran.OnayIste", function()
     local ogrenciId = net.ReadUInt(32)
     local ad = net.ReadString()
     local buyu = net.ReadString()
     local ent = net.ReadEntity()

     SA.Ses("iyi")
     if (IsValid(SA.OnayPanel)) then SA.OnayPanel:Remove() end

     local yakin = IsValid(ent) and ent:GetPos():Distance(LocalPlayer():GetPos()) <= SA.Ayar.ogretmenMesafe
     local govde = ad .. ", " .. buyu .. " rününü " .. SA.Ayar.basariGerek .. " kez başarıyla çizdi."
     if (!yakin) then govde = govde .. " Onaylamak için yanına git." end

     SA.OnayPanel = Pencere("Öğrencin hazır", "AKRAN YARDIMI · ONAY", buyu, govde, {
          {ad = "Büyüyü öğret", birincil = true, fn = function() SA.Onayla(ogrenciId, true) end},
          {ad = "Bir tur daha", fn = function() SA.Onayla(ogrenciId, false) end},
          {ad = "Sonra"}
     })
end)

/*
*   ------------------------------------------------------------------
*   dünya :: raf plakaları, talim alanları, okuyan öğrencilerin kitabı, efektler
*   ------------------------------------------------------------------
*/

local adminGoster = CreateClientConVar("sardon_akran_goster", "0", false, false, "Akran Yardımı raf ve talim alanlarını her yerden gösterir (yetkili)")

local function PlakaCiz(r, mesafe, gorevde, admin)
     local a = math.Clamp(1 - (mesafe - 180) / 120, 0, 1)
     if (admin) then a = math.max(a, 0.85) end
     if (a <= 0) then return end

     local ang = r.normal:Angle()
     ang:RotateAroundAxis(ang:Up(), 90)
     ang:RotateAroundAxis(ang:Forward(), 90)

     local pos = r.pos + r.normal * 0.6
     if (gorevde) then
          render.SetMaterial(M3.isik)
          render.DrawSprite(pos, 26 + math.sin(RealTime() * 3 + r.id) * 4, 26, Color(255, 210, 140, 70 * a))
     end

     cam.Start3D2D(pos, ang, 0.05)
          local w, h = 230, 112
          surface.SetDrawColor(18, 14, 10, 230 * a)
          draw.NoTexture()
          surface.DrawRect(-w / 2, -h / 2, w, h)
          surface.SetDrawColor(R.pirinc.r, R.pirinc.g, R.pirinc.b, 255 * a)
          surface.DrawOutlinedRect(-w / 2, -h / 2, w, h, 3)
          surface.SetDrawColor(R.pirinc.r, R.pirinc.g, R.pirinc.b, 120 * a)
          surface.DrawOutlinedRect(-w / 2 + 8, -h / 2 + 8, w - 16, h - 16, 1)
          draw.SimpleText(r.no, "sak.plaka", 0, 4, ColorAlpha(R.altin, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          draw.SimpleText((SA.Roma[r.kat] or r.kat) .. ". KAT", "sak.plakaK", 0, -h / 2 + 22, ColorAlpha(R.soluk, 220 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          if (admin) then
               draw.SimpleText("#" .. r.id, "sak.plakaK", 0, h / 2 + 18, ColorAlpha(R.mavi, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          end
     cam.End3D2D()
end

-- dikdörtgen talim alanı: kenar ışınları, köşe ışıkları, içe daralan çerçeve, çevrede dolaşan rün ışıkları
function SA.DikdortgenCiz(merkez, en, boy, yaw, a, renk, parlak)
     local now = RealTime()
     local ileri = Angle(0, yaw, 0):Forward()
     local yan = Vector(-ileri.y, ileri.x, 0)
     local hx, hy = ileri * (boy / 2), yan * (en / 2)
     local k = {merkez + hx + hy, merkez - hx + hy, merkez - hx - hy, merkez + hx - hy}

     render.SetMaterial(M3.isin)
     local kay = now * 0.6
     for i = 1, 4 do
          local p1, p2 = k[i], k[i % 4 + 1]
          local uz = p1:Distance(p2) / 96
          render.DrawBeam(p1, p2, 9, kay, kay + uz, Color(renk.r, renk.g, renk.b, 200 * a))
     end

     -- içe doğru daralan çerçeve (dairedeki dalganın karşılığı)
     local d = 1 - (now * 0.4) % 1
     local ic = Color(renk.r, renk.g, renk.b, 110 * (1 - d) * a)
     for i = 1, 4 do
          local p1, p2 = merkez + (k[i] - merkez) * d, merkez + (k[i % 4 + 1] - merkez) * d
          render.DrawBeam(p1, p2, 5, 0, 1, ic)
     end

     render.SetMaterial(M3.isik)
     for i = 1, 4 do
          render.DrawSprite(k[i] + Vector(0, 0, 4), 34, 34, Color(renk.r, renk.g, renk.b, 190 * a))
     end

     -- çevrede süzülen rün ışıkları: çevre boyunca eşit aralıklı
     local cevre = (en + boy) * 2
     local n = parlak and 12 or 6
     for i = 1, n do
          local yol = ((now * 0.03 + i / n) % 1) * cevre
          local p
          if (yol < boy) then p = k[2] + ileri * yol
          elseif (yol < boy + en) then p = k[1] - yan * (yol - boy)
          elseif (yol < boy * 2 + en) then p = k[4] - ileri * (yol - boy - en)
          else p = k[3] + yan * (yol - boy * 2 - en) end
          render.DrawSprite(p + Vector(0, 0, 18 + math.sin(now * 2 + i) * 10), 14, 14, Color(renk.r, renk.g, renk.b, 160 * a))
     end
end

local function AlanCiz(al, parlak, admin)
     local now = RealTime()
     local merkez = al.pos + Vector(0, 0, 3)
     local yuk = Vector(0, 0, 1)
     local a = parlak and 1 or 0.35

     if (SA.AlanDikdortgenMi(al)) then
          SA.DikdortgenCiz(merkez, al.en, al.boy, al.yaw or 0, a, Color(255, 214, 140), parlak)
          if (admin) then
               local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)
               cam.Start3D2D(merkez + Vector(0, 0, 60), ang, 0.2)
                    draw.SimpleText((al.ad or "Talim") .. "  #" .. al.id .. "  " .. SA.AlanOlcuYaz(al), "sak.plakaK", 0, 0, R.mavi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               cam.End3D2D()
          end
          return
     end

     render.SetMaterial(M3.halka)
     render.DrawQuadEasy(merkez, yuk, al.r * 2, al.r * 2, Color(255, 214, 140, 120 * a), now * 8 % 360)
     render.DrawQuadEasy(merkez, yuk, al.r * 1.7, al.r * 1.7, Color(200, 180, 120, 70 * a), -now * 12 % 360)

     render.SetMaterial(M3.dalga)
     local d = (now * 0.4) % 1
     render.DrawQuadEasy(merkez, yuk, al.r * 2 * d, al.r * 2 * d, Color(255, 220, 160, 90 * (1 - d) * a), 0)

     -- çevrede süzülen rün ışıkları
     render.SetMaterial(M3.isik)
     local n = parlak and 10 or 6
     for i = 1, n do
          local an = now * 0.35 + i / n * math.pi * 2
          local p = merkez + Vector(math.cos(an) * al.r * 0.92, math.sin(an) * al.r * 0.92, 18 + math.sin(now * 2 + i) * 10)
          render.DrawSprite(p, 14, 14, Color(255, 220, 150, 160 * a))
     end

     if (admin) then
          local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)
          cam.Start3D2D(merkez + Vector(0, 0, 60), ang, 0.2)
               draw.SimpleText((al.ad or "Talim") .. "  #" .. al.id .. "  r=" .. al.r, "sak.plakaK", 0, 0, R.mavi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          cam.End3D2D()
     end
end

-- okuyan öğrencilerin süzülen kitabı
local okuyanlar = {}
local kitapModel
local function KitapModeli()
     if (kitapModel) then return kitapModel end
     for _, m in ipairs({"models/hpwrewrite/books/book2.mdl", "models/hpwrewrite/books/book1.mdl", "models/props_lab/bindergreen.mdl"}) do
          if (util.IsValidModel(m)) then kitapModel = m break end
     end
     kitapModel = kitapModel or "models/props_lab/bindergreen.mdl"
     return kitapModel
end

local sonOkuyanTarama = 0
local okumaEm

hook.Add("Think", "SardonAkran.Okuyanlar", function()
     local now = RealTime()
     if (now > sonOkuyanTarama) then
          sonOkuyanTarama = now + 0.5
          local benim = LocalPlayer()
          for _, p in player.Iterator() do
               local okuyor = p:GetNW2Bool("SardonAkranOkuyor") and p:Alive() and (p != benim or p:ShouldDrawLocalPlayer()) and p:GetPos():DistToSqr(benim:GetPos()) < 1400 * 1400
               -- 11-05: öğrenci kitabı elinde açıp okur ([sardon] anims sh_kitap, kip "akran"); süzülen kitap yalnız
               -- elde kitap açılamadıysa (oturma pozu, savaş vb.), okuma başladıktan 1.5 sn sonra
               if (okuyor) then
                    p.SardonAkranOkuBas = p.SardonAkranOkuBas or now
                    okuyor = p:GetNW2String("SKAKip", "") != "akran" and now - p.SardonAkranOkuBas > 1.5
               else
                    p.SardonAkranOkuBas = nil
               end
               if (okuyor and !IsValid(okuyanlar[p])) then
                    local m = ClientsideModel(KitapModeli(), RENDERGROUP_OPAQUE)
                    if (IsValid(m)) then
                         m:SetModelScale(0.8)
                         m:SetNoDraw(false)
                         okuyanlar[p] = m
                    end
               elseif (!okuyor and IsValid(okuyanlar[p])) then
                    okuyanlar[p]:Remove()
                    okuyanlar[p] = nil
               end
          end
          for p, m in pairs(okuyanlar) do
               if (!IsValid(p)) then
                    if (IsValid(m)) then m:Remove() end
                    okuyanlar[p] = nil
               end
          end
     end

     for p, m in pairs(okuyanlar) do
          if (IsValid(p) and IsValid(m)) then
               local ileri = Angle(0, p:EyeAngles().y, 0):Forward()
               local pos = p:GetPos() + Vector(0, 0, 50 + math.sin(now * 1.6) * 2) + ileri * 20
               m:SetPos(pos)
               -- okuyana bakan kenar aşağıda, uzak kenar yukarıda: sayfa okuyana dönük
               local ang = Angle(25, p:EyeAngles().y + 180, 0)
               ang:RotateAroundAxis(ang:Forward(), math.sin(now * 1.1) * 4)
               m:SetAngles(ang)

               if (math.random() < 0.18) then
                    okumaEm = okumaEm or ParticleEmitter(pos, false)
                    if (okumaEm) then
                         okumaEm:SetPos(pos)
                         local pr = okumaEm:Add("sprites/light_glow02_add", pos + VectorRand() * 4 + Vector(0, 0, 4))
                         if (pr) then
                              pr:SetVelocity(Vector(math.Rand(-6, 6), math.Rand(-6, 6), math.Rand(14, 30)))
                              pr:SetDieTime(math.Rand(1.2, 2.2))
                              pr:SetStartAlpha(230)
                              pr:SetEndAlpha(0)
                              pr:SetStartSize(math.Rand(1.5, 3))
                              pr:SetEndSize(0)
                              pr:SetColor(255, 214, 150)
                              pr:SetAirResistance(20)
                         end
                    end
               end

               local dl = DynamicLight(p:EntIndex() + 4096)
               if (dl) then
                    dl.pos = pos + Vector(0, 0, 8)
                    dl.r, dl.g, dl.b = 255, 200, 130
                    dl.brightness = 0.6
                    dl.decay = 300
                    dl.size = 90
                    dl.dietime = CurTime() + 0.2
               end
          end
     end
end)

-- efektler
local efektler = {}

local function Patlat3D(pos, renk, n, hiz, mat, boyut)
     local em = ParticleEmitter(pos, false)
     if (!em) then return end
     for i = 1, n do
          local p = em:Add(mat or "sprites/light_glow02_add", pos + VectorRand() * 4)
          if (p) then
               local v = VectorRand()
               v.z = math.abs(v.z) * 0.6 + 0.2
               p:SetVelocity(v * math.Rand(0.4, 1) * (hiz or 120))
               p:SetGravity(Vector(0, 0, -40))
               p:SetAirResistance(60)
               p:SetDieTime(math.Rand(0.8, 1.8))
               p:SetStartAlpha(255)
               p:SetEndAlpha(0)
               p:SetStartSize(math.Rand(2, boyut or 6))
               p:SetEndSize(0)
               p:SetRoll(math.Rand(0, 360))
               p:SetColor(renk.r, renk.g, renk.b)
          end
     end
     em:Finish()
end
SA.Patlat3D = Patlat3D

local function Toz3D(pos, n)
     local em = ParticleEmitter(pos, false)
     if (!em) then return end
     for i = 1, n do
          local p = em:Add("particle/smokesprites_0001", pos + VectorRand() * 10)
          if (p) then
               p:SetVelocity(VectorRand() * 20 + Vector(0, 0, 10))
               p:SetDieTime(math.Rand(1.2, 2.4))
               p:SetStartAlpha(70)
               p:SetEndAlpha(0)
               p:SetStartSize(math.Rand(6, 10))
               p:SetEndSize(math.Rand(18, 28))
               p:SetRoll(math.Rand(0, 360))
               p:SetRollDelta(math.Rand(-1, 1))
               p:SetColor(150, 140, 120)
               p:SetAirResistance(40)
          end
     end
     em:Finish()
end

local function UcNokta(p)
     if (!IsValid(p)) then return vector_origin end
     local w = p:GetActiveWeapon()
     if (IsValid(w) and p != LocalPlayer() or (IsValid(w) and p:ShouldDrawLocalPlayer())) then
          local at = p:LookupAttachment("anim_attachment_RH")
          if (at and at > 0) then
               local d = p:GetAttachment(at)
               if (d) then return d.Pos + p:GetAimVector() * 8 end
          end
     end
     return p:EyePos() - Vector(0, 0, 12) + p:GetAimVector() * 20
end

net.Receive("SardonAkran.Efekt", function()
     local tur = net.ReadUInt(4)
     local a = net.ReadEntity()
     local b = net.ReadEntity()
     if (!IsValid(a)) then return end

     local merkez = a:GetPos() + Vector(0, 0, 48)

     if (tur == 1 or tur == 4) then
          efektler[#efektler + 1] = {tur = tur, a = a, b = IsValid(b) and b or a, bas = RealTime(), sure = tur == 4 and 3 or 2}
          local hedef = IsValid(b) and b or a
          Patlat3D(hedef:GetPos() + Vector(0, 0, 48), Color(255, 214, 140), tur == 4 and 90 or 40, tur == 4 and 160 or 90)
          if (tur == 4) then
               hedef:EmitSound("ambient/energy/whiteflash.wav", 65, 120, 0.5)
          else
               hedef:EmitSound("ambient/levels/citadel/weapon_disintegrate" .. math.random(1, 4) .. ".wav", 55, 160, 0.25)
          end
     elseif (tur == 2) then
          Patlat3D(merkez + a:GetForward() * 12, Color(255, 220, 150), 50, 80)
          efektler[#efektler + 1] = {tur = 2, a = a, bas = RealTime(), sure = 1.2}
          a:EmitSound("ambient/energy/whiteflash.wav", 55, 170, 0.3)
     elseif (tur == 3) then
          Patlat3D(merkez + Vector(0, 0, 20), Color(255, 214, 140), 70, 110)
          efektler[#efektler + 1] = {tur = 3, a = a, bas = RealTime(), sure = 1.6}
          a:EmitSound("ambient/energy/whiteflash.wav", 60, 140, 0.4)
     elseif (tur == 5) then
          Toz3D(merkez + a:GetForward() * 30, 14)
     end
end)

local function EfektCiz()
     local now = RealTime()
     for i = #efektler, 1, -1 do
          local e = efektler[i]
          local t = (now - e.bas) / e.sure
          if (t >= 1 or !IsValid(e.a)) then
               table.remove(efektler, i)
          elseif (e.tur == 1 or e.tur == 4) then
               -- öğretmenin asasından öğrenciye akan ışık
               local p1, p2 = UcNokta(e.a), (IsValid(e.b) and e.b:GetPos() + Vector(0, 0, 50) or UcNokta(e.a))
               local a = math.sin(t * math.pi)
               local renk = e.tur == 4 and Color(255, 220, 150, 255 * a) or Color(180, 220, 255, 220 * a)
               render.SetMaterial(M3.iz)
               render.StartBeam(16)
               for s = 0, 15 do
                    local f = s / 15
                    local p = LerpVector(f, p1, p2) + Vector(0, 0, math.sin(f * math.pi) * 18 + math.sin(now * 12 + f * 9) * 2)
                    render.AddBeam(p, 6 * (1 - math.abs(f - 0.5)) + 2, f * 2 - now * 3, renk)
               end
               render.EndBeam()
               render.SetMaterial(M3.isik)
               render.DrawSprite(p1, 24, 24, renk)
               render.DrawSprite(p2, 40 * a, 40 * a, renk)
          elseif (e.tur == 2 or e.tur == 3) then
               local merkez = e.a:GetPos() + Vector(0, 0, e.tur == 3 and 82 or 50)
               render.SetMaterial(M3.dalga)
               local s = 20 + t * (e.tur == 3 and 90 or 60)
               render.DrawQuadEasy(merkez, Vector(0, 0, 1), s, s, Color(255, 220, 160, 200 * (1 - t)), now * 40 % 360)
               render.DrawQuadEasy(merkez, Vector(0, 0, -1), s, s, Color(255, 220, 160, 200 * (1 - t)), now * 40 % 360)
          end
     end
end

hook.Add("PostDrawTranslucentRenderables", "SardonAkran.Dunya", function(derinlik, gokyuzu)
     if (gokyuzu) then return end
     SA.Fontlar()
     local ply = LocalPlayer()
     if (!IsValid(ply)) then return end
     local goz = ply:EyePos()
     local g = SA.Gorev
     local admin = adminGoster:GetBool() and ply:IsSuperAdmin()

     local rafGorev = g and g.asama == 1
     local menzil = admin and 3000 or 320
     -- 11-13 opt: ~73 rafın her birinde Distance (userdata __index + C çağrısı) yerine önce Lua sayılarıyla eksen farkı.
     -- r.pos = Vector(r.x, r.y, r.z) (net alımı, yukarıda); bir eksende fark menzil + 1'i aşarsa Distance de menzili
     -- aşar (float yuvarlaması ~0.002 birim), raf eskiden de çizilmezdi. x/y/z yoksa eski yol.
     local gx, gy, gz = goz:Unpack()
     local sinir = menzil + 1
     for _, r in ipairs(SA.HaritaVeri.raflar) do
          local x, y, z = r.x, r.y, r.z
          if (!(x and y and z) or math.abs(x - gx) <= sinir and math.abs(y - gy) <= sinir and math.abs(z - gz) <= sinir) then
               local d = goz:Distance(r.pos)
               if (d < menzil) then PlakaCiz(r, d, rafGorev, admin) end
          end
     end

     local talimde = g and g.asama == 3
     for _, al in ipairs(SA.HaritaVeri.alanlar) do
          local d = goz:Distance(al.pos)
          if (admin or d < al.r + (talimde and 2500 or 700)) then AlanCiz(al, talimde or admin, admin) end
     end

     EfektCiz()
end)

/*
*   asa menüsünü Akran Yardımı sayfasında açar
*/

function SA.MenuAc()
     if (!HpwRewrite or !HpwRewrite.VGUI or !HpwRewrite.VGUI.OpenNewSpellManager) then return end
     local w = HpwRewrite.VGUI:OpenNewSpellManager()
     if (IsValid(w) and w.SwitchPage) then w:SwitchPage("akran") end
end

concommand.Add("sardon_akran", function() SA.MenuAc() end, nil, "Asa menüsünü Akran Yardımı sayfasında açar")

