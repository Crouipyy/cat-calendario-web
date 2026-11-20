-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\cl_5oyun.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: mini oyunlar (fırçalama, eğitim)
--
-- Sunucu jetonla açar (Y.NET.OYUN). Kamera yaratığa yaklaşır (yanından ya da önünden), ekran
-- fareye açılır. Bitince skor (0..1) jetonla sunucuya gider; sunucu oyunun süresini denetler.
--
-- Fırçalama: yaratığın sırt hattında 7 kirli yer; sol tık basılıyken fareyle üzerlerinden geçtikçe
-- temizlenir. Skor = temizlik, hızlı bitirene küçük ek.
-- Eğitim: 6 komut. Halka hedef çembere oturduğu anda doğru yön tuşu (W/A/S/D).
-- Selam (hipogrif): fareyle gözüne bakılır, halka dolana dek göz kaçırılmaz (kaçırdıkça hipogrif
-- huzursuzlanır, gözü oynar); sonra SPACE basılı tutularak yavaşça eğilinir. Skor ≥ 0.6 kabul.

local Y = SardonYaratik
local R = Y.R

local OYUN_SURE = {firca = 25}
local KOMUTLAR = {
     {ad = "GEL", tus = KEY_W, harf = "W", ok = "↑"},
     {ad = "DÖN", tus = KEY_A, harf = "A", ok = "←"},
     {ad = "OTUR", tus = KEY_S, harf = "S", ok = "↓"},
     {ad = "BEKLE", tus = KEY_D, harf = "D", ok = "→"},
}
local TUR_SAYISI = 6

------------------------------------------------------------------------ kamera

local kamera -- {ent, mod, bas}

-- Helix thirdperson eklentisinin CalcView'i normal kancalardan önce çalışır; oyun boyunca kapatılır
-- (süpürge, baykuş, polaroid de böyle yapıyor), bitince eski hâline döner.
local tpEski
local function TPKapat()
     if not (ix and ix.option) then return end
     tpEski = ix.option.Get("thirdpersonEnabled", false)
     if tpEski then ix.option.Set("thirdpersonEnabled", false) end
end
local function TPGeri()
     if tpEski and ix and ix.option then ix.option.Set("thirdpersonEnabled", true) end
     tpEski = nil
end

local function KameraHedef(ent, mod)
     if not IsValid(ent) or not ent.CizimKonumu then return end
     local p, a = ent:CizimKonumu()
     local u, g, h = Y.VarlikKutu(ent)
     u, g, h = u or 20, g or 20, h or 30
     local merkez = p + Vector(0, 0, h * 0.5)
     local ileri = Angle(0, a.y, 0):Forward()
     local sag = Angle(0, a.y, 0):Right()
     local uzak = math.max(70, math.max(u * 2, h) * 1.25 + 40)
     local konum
     if mod == "selam" then
          -- önden, baş hizasından: hipogrif oyuncuya döndü
          konum = merkez + ileri * uzak * 0.85 + Vector(0, 0, h * 0.4)
          return konum, (merkez + Vector(0, 0, h * 0.25) - konum):Angle()
     elseif mod == "egit" then
          konum = merkez + ileri * uzak + Vector(0, 0, h * 0.35)
     else
          -- oyuncunun bulunduğu taraftan bak (karakter görüntüyü kapatmasın)
          local taraf = (LocalPlayer():GetPos() - p):Dot(sag) >= 0 and 1 or -1
          konum = merkez + sag * taraf * uzak + Vector(0, 0, h * 0.55 + 12) - ileri * u * 0.15
     end
     return konum, (merkez - konum):Angle()
end

hook.Add("CalcView", "SardonYaratik.OyunKamera", function(ply, pos, ang, fov)
     if not kamera then return end
     local hp, ha = KameraHedef(kamera.ent, kamera.mod)
     if not hp then return end
     local t = math.Clamp((RealTime() - kamera.bas) / 0.45, 0, 1)
     t = t * t * (3 - 2 * t)
     if kamera.cikis then t = 1 - math.Clamp((RealTime() - kamera.cikis) / 0.35, 0, 1) end
     return {origin = LerpVector(t, pos, hp), angles = LerpAngle(t, ang, ha), fov = fov, drawviewer = true}
end)

hook.Add("SardonHUDGizle", "SardonYaratik.Oyun", function()
     if Y.OyunAcik then return true end
end)

hook.Add("HUDShouldDraw", "SardonYaratik.Oyun", function(ad)
     if Y.OyunAcik and (ad == "CHudCrosshair" or ad == "CHudHealth" or ad == "CHudBattery") then return false end
end)

------------------------------------------------------------------------ panel

local PANEL = {}

function PANEL:Init()
     self:SetSize(ScrW(), ScrH())
     self:SetPos(0, 0)
     self:MakePopup()
     self:SetKeyboardInputEnabled(true)
     self.bas = RealTime()
     self.T = Y.TuvalYap(1600, 900)
     self.toz = {}
     hook.Add("OnPauseMenuShow", self, function(s)
          s:Bitir(true)
          return false
     end)
end

function PANEL:PerformLayout(w, h)
     self.T.Olc(w, h)
end

function PANEL:Kur(tur, id, jeton, ent)
     self.tur, self.id, self.jeton, self.ent = tur, id, jeton, ent
     local yt = IsValid(ent) and ent:TurVeri()
     self.ad = IsValid(ent) and (ent:GetAd() ~= "" and ent:GetAd() or (yt and yt.ad)) or "Yaratık"
     kamera = {ent = ent, mod = tur, bas = RealTime()}

     if tur == "selam" then
          local k = Y.BenimKayit(id)
          local bag = (k and k.bag) or 0
          self.temasSure = Lerp(math.Clamp(bag / 85, 0, 1), 3.2, 1.4)
          self.faz, self.temas, self.huzursuz = 1, 0, 0
          self.egil, self.egilN, self.egilSapma = 0, 0, 0
          self.fazT = RealTime()
          return
     end
     if tur == "firca" then
          self.kirler = {}
          for i = 1, 7 do
               self.kirler[i] = {t = -0.36 + 0.72 * (i - 1) / 6 + math.Rand(-0.03, 0.03), yan = math.Rand(-0.25, 0.25), kir = 1, boy = math.Rand(0.8, 1.2)}
          end
          self.ses = CreateSound(LocalPlayer(), "physics/cardboard/cardboard_box_scrape_smooth_loop1.wav")
     else
          local k = Y.BenimKayit(id)
          local sev = Y.Seviye(k and k.xp)
          self.halkaSure = math.max(1.0, 1.4 - sev * 0.04)
          self.turlar = {}
          self.turNo = 0
          self:SonrakiKomut(RealTime() + 0.9)
     end
end

------------------------------------------------------------------------ eğitim

function PANEL:SonrakiKomut(zaman)
     self.turNo = self.turNo + 1
     if self.turNo > TUR_SAYISI then
          self.bitecek = RealTime() + 0.8
          return
     end
     local onceki = self.komut and self.komut.k
     local k
     repeat k = KOMUTLAR[math.random(#KOMUTLAR)] until k ~= onceki or #KOMUTLAR == 1
     self.komut = {k = k, bas = zaman, hedef = zaman + self.halkaSure}
end

function PANEL:KomutSonuc(puan, yazi)
     self.turlar[#self.turlar + 1] = {puan = puan, yazi = yazi, t = RealTime()}
     self.sonYazi = {yazi = yazi, t = RealTime(), puan = puan}
     self.komut = nil
     if puan >= 1 then surface.PlaySound("buttons/blip1.wav")
     elseif puan > 0 then surface.PlaySound("buttons/button17.wav")
     else surface.PlaySound("buttons/button10.wav") end
     self:SonrakiKomut(RealTime() + 0.6)
end

function PANEL:OnKeyCodePressed(kod)
     if kod == KEY_ESCAPE then self:Bitir(true) return end
     if self.tur ~= "egit" or not self.komut then return end
     local c = self.komut
     local simdi = RealTime()
     if simdi < c.bas then return end
     local hangi
     for _, k in ipairs(KOMUTLAR) do if k.tus == kod then hangi = k end end
     if not hangi then return end
     if hangi ~= c.k then self:KomutSonuc(0, "Yanlış komut") return end
     local fark = math.abs(simdi - c.hedef)
     if fark <= 0.12 then self:KomutSonuc(1, "Kusursuz")
     elseif fark <= 0.28 then self:KomutSonuc(0.6, "İyi")
     else self:KomutSonuc(0, simdi < c.hedef and "Erken" or "Geç") end
end

------------------------------------------------------------------------ bitiş

function PANEL:Skor()
     if self.tur == "selam" then return self.selamSkor or 0 end
     if self.tur == "firca" then
          local top = 0
          for _, k in ipairs(self.kirler) do top = top + (1 - k.kir) end
          local temiz = top / #self.kirler
          local gecen = RealTime() - self.bas
          local hiz = math.Clamp(1 - (gecen - 6) / 19, 0, 1)
          return math.Clamp(0.75 * temiz + 0.25 * hiz * temiz, 0, 1)
     end
     local top = 0
     for _, t in ipairs(self.turlar) do top = top + t.puan end
     return top / TUR_SAYISI
end

function PANEL:Bitir(iptal)
     if self.bitti then return end
     self.bitti = true
     Y.Islem("oyun_bitir", self.jeton, iptal and "iptal" or "", self:Skor())
     if kamera then kamera.cikis = RealTime() end
     local bu = kamera
     timer.Simple(0.35, function()
          if kamera == bu then kamera = nil end
          if not Y.OyunAcik then TPGeri() end
     end)
     self:Remove()
end

function PANEL:OnRemove()
     if self.ses then self.ses:Stop() end
     Y.OyunAcik = nil
     if not self.bitti then
          self.bitti = true
          Y.Islem("oyun_bitir", self.jeton or 0, "iptal", 0)
          kamera = nil
          TPGeri()
     end
end

------------------------------------------------------------------------ selam

function PANEL:GozNoktasi(simdi)
     local ent = self.ent
     local p
     local i1, i2 = ent:LookupBone("staylofft_eye_left"), ent:LookupBone("staylofft_eye_right")
     if i1 and i2 then
          local a, b = ent:GetBonePosition(i1), ent:GetBonePosition(i2)
          if a and b then p = (a + b) * 0.5 end
     end
     if not p then
          local q, an = ent:CizimKonumu()
          local u, _, h = Y.VarlikKutu(ent)
          p = q + Vector(0, 0, (h or 40) * 0.85) + Angle(0, an.y, 0):Forward() * (u or 20) * 0.8
     end
     local sc = p:ToScreen()
     local s = math.max(ScrH() / 1080, 0.6)
     -- huzursuzlandıkça göz kayar
     local sal = (8 + 30 * self.huzursuz) * s
     return sc.x + math.sin(simdi * 1.3) * sal + math.sin(simdi * 3.1) * sal * 0.4, sc.y + math.cos(simdi * 1.7) * sal * 0.6, sc.visible
end

function PANEL:SelamSonuc(iyi)
     if self.sonuc then return end
     local skor
     if iyi then
          skor = 0.55 * (1 - self.huzursuz) + 0.45 * (1 - self.egilSapma / math.max(self.egilN, 1))
     else
          skor = math.min(0.4, 0.4 * (1 - self.huzursuz))
     end
     self.selamSkor = math.Clamp(skor, 0, 1)
     self.sonuc = {t = RealTime(), iyi = self.selamSkor >= 0.6}
     surface.PlaySound(self.sonuc.iyi and "ambient/levels/canals/windchime2.wav" or "buttons/button10.wav")
     self.bitecek = RealTime() + 0.9
end

function PANEL:SelamDusun(simdi)
     if self.sonuc then return end
     local ft = FrameTime()
     local s = math.max(ScrH() / 1080, 0.6)
     local hx, hy = self:GozNoktasi(simdi)
     local mx, my = gui.MousePos()
     local icinde = math.sqrt((mx - hx) ^ 2 + (my - hy) ^ 2) < 40 * s
     self.icinde = icinde

     if self.faz == 1 then
          if icinde then
               self.temas = math.min(1, self.temas + ft / self.temasSure)
          else
               self.temas = math.max(0, self.temas - ft / (self.temasSure * 2))
               self.huzursuz = math.min(1, self.huzursuz + ft * 0.45)
          end
          if self.huzursuz >= 1 then self:SelamSonuc(false) return end
          if self.temas >= 1 then
               self.faz = 2
               self.fazT = simdi
               surface.PlaySound("buttons/blip1.wav")
          end
     else
          if input.IsKeyDown(KEY_SPACE) then
               self.egil = math.min(1, self.egil + ft / 1.4)
               self.egilN = self.egilN + 1
               if not icinde then self.egilSapma = self.egilSapma + 1 end
               if self.egil >= 1 then self:SelamSonuc(true) end
          elseif self.egil > 0.05 or simdi - self.fazT > 7 then
               -- yarıda doğruldu ya da hiç eğilmedi
               self:SelamSonuc(false)
          end
     end
end

function PANEL:SelamCiz(w, h, s, simdi)
     local T = self.T
     local hx, hy, gorunur = self:GozNoktasi(simdi)
     if gorunur and not self.sonuc then
          local r = 40 * s
          local renk = self.icinde and R.tamam or R.uyari
          -- hedef bölge ve dolan halka
          surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 160)
          local adim = 48
          for i = 0, adim - 1 do
               if i % 2 == 0 then
                    local a0, a1 = i / adim * math.pi * 2, (i + 1) / adim * math.pi * 2
                    surface.DrawLine(hx + math.cos(a0) * r, hy + math.sin(a0) * r, hx + math.cos(a1) * r, hy + math.sin(a1) * r)
               end
          end
          local oran = self.faz == 1 and self.temas or self.egil
          if oran > 0 then
               draw.NoTexture()
               surface.SetDrawColor(renk.r, renk.g, renk.b, 235)
               local n = math.max(2, math.ceil(64 * oran))
               for i = 0, n - 1 do
                    local a0 = -math.pi / 2 + math.pi * 2 * oran * i / n
                    local a1 = -math.pi / 2 + math.pi * 2 * oran * (i + 1) / n
                    surface.DrawPoly({
                         {x = hx + math.cos(a0) * (r + 3 * s), y = hy + math.sin(a0) * (r + 3 * s)},
                         {x = hx + math.cos(a0) * (r + 8 * s), y = hy + math.sin(a0) * (r + 8 * s)},
                         {x = hx + math.cos(a1) * (r + 8 * s), y = hy + math.sin(a1) * (r + 8 * s)},
                         {x = hx + math.cos(a1) * (r + 3 * s), y = hy + math.sin(a1) * (r + 3 * s)},
                    })
               end
          end
          Y.Parilti(hx, hy, r * 2.2, renk, self.icinde and 50 or 22)
     end

     -- fare
     local mx, my = gui.MousePos()
     Y.Parilti(mx, my, 36 * s, R.soluk, 45)

     -- sabır çubuğu
     T.Yazi("SABRI", 11, 600, 520, 112, R.sonuk, 0, 2)
     T.Cubuk(520, 124, 560, 8, 1 - self.huzursuz, self.huzursuz > 0.6 and R.hata or R.tamam)

     local cx = 800
     if self.sonuc then
          local a = math.Clamp((simdi - self.sonuc.t) / 0.25, 0, 1)
          T.Yazi(self.sonuc.iyi and "Hipogrif eğiliyor..." or "Hipogrif şahlandı!", 30, "baslik", cx, 760, self.sonuc.iyi and R.tamam or R.hata, 1, 3, a)
     elseif self.faz == 1 then
          T.Yazi("GÖZ TEMASI", 26, "baslik", cx, 740, R.parlak, 1, 4)
          T.Yazi(self.icinde and "Gözünü kaçırma..." or "Gözüne bak!", 16, "isim", cx, 778, self.icinde and R.sonuk or R.uyari, 1)
     else
          T.Yazi("EĞİL", 30, "baslik", cx, 740, R.parlak, 1, 6)
          T.Yazi("SPACE basılı tut · gözünü ayırmadan yavaşça", 15, 600, cx, 778, R.altin, 1)
          T.Cubuk(700, 800, 200, 6, self.egil, R.tamam)
     end
end

function PANEL:Think()
     if not IsValid(self.ent) then self:Bitir(true) return end
     local simdi = RealTime()

     if self.tur == "selam" then
          self:SelamDusun(simdi)
     elseif self.tur == "firca" then
          local gecen = simdi - self.bas
          local mx, my = gui.MousePos()
          local basili = input.IsMouseDown(MOUSE_LEFT)
          local hiz = 0
          if self.sonFare then
               hiz = math.sqrt((mx - self.sonFare[1]) ^ 2 + (my - self.sonFare[2]) ^ 2)
          end
          self.sonFare = {mx, my}
          local ovuyor = false
          if basili and hiz > 0 then
               local s = math.max(ScrH() / 1080, 0.6)
               for _, k in ipairs(self.kirler) do
                    if k.sx and k.kir > 0 then
                         local d = math.sqrt((mx - k.sx) ^ 2 + (my - k.sy) ^ 2)
                         if d < 42 * s * k.boy then
                              k.kir = math.max(0, k.kir - hiz * 0.0055 / s)
                              ovuyor = true
                              if k.kir <= 0 and not k.parladi then
                                   k.parladi = simdi
                                   surface.PlaySound("ambient/levels/canals/windchime2.wav")
                              end
                         end
                    end
               end
               if math.random() < 0.5 then
                    table.insert(self.toz, {x = mx, y = my, vx = math.Rand(-60, 60), vy = math.Rand(-80, -10), t = simdi})
               end
          end
          if self.ses then
               if ovuyor and not self.ses:IsPlaying() then self.ses:PlayEx(0.25, 120) end
               if self.ses:IsPlaying() then self.ses:ChangeVolume(ovuyor and math.Clamp(hiz / 30, 0.08, 0.35) or 0, 0.1) end
          end
          local hepsi = true
          for _, k in ipairs(self.kirler) do if k.kir > 0 then hepsi = false end end
          if (hepsi and gecen > 4.2) or gecen > OYUN_SURE.firca then
               self.bitecek = self.bitecek or (simdi + (hepsi and 0.6 or 0))
          end
     elseif self.komut and simdi > self.komut.hedef + 0.32 then
          self:KomutSonuc(0, "Kaçtı")
     end

     if self.bitecek and simdi >= self.bitecek then self:Bitir(false) end
end

------------------------------------------------------------------------ çizim

function PANEL:Paint(w, h)
     local T = self.T
     local s = math.max(ScrH() / 1080, 0.6)
     local simdi = RealTime()

     -- üst şerit
     T.Ton(R.zemin, 0.92)
     T.Dolu(0, 0, 1600, 86)
     T.Ton(R.cizgi, 1)
     T.Cizgi(0, 86, 1600, 86)
     local baslik = self.tur == "firca" and "FIRÇALA" or (self.tur == "selam" and "SELAM" or "EĞİT")
     T.Yazi(baslik, 26, "baslik", 800, 34, R.parlak, 1, 6)
     T.Yazi(self.ad or "", 15, "isim", 800, 64, R.sonuk, 1)

     if self.tur == "selam" then
          self:SelamCiz(w, h, s, simdi)
     elseif self.tur == "firca" then
          self:FircaCiz(w, h, s, simdi)
     else
          self:EgitCiz(w, h, s, simdi)
     end

     -- alt ipucu
     local ipucu = self.tur == "firca" and "Sol tık basılı tut, kirli yerlerin üzerinden fareyi gezdir   ·   ESC: vazgeç"
          or (self.tur == "selam" and "Fareyle hipogrifin gözünde kal; halka dolunca SPACE ile eğil   ·   ESC: vazgeç"
          or "Halka içteki çembere oturunca komutun tuşuna bas   ·   ESC: vazgeç")
     T.Ton(R.zemin, 0.92)
     T.Dolu(0, 852, 1600, 48)
     T.Yazi(ipucu, 13, 600, 800, 876, R.soluk, 1)
end

function PANEL:FircaCiz(w, h, s, simdi)
     local T = self.T
     local ent = self.ent
     if not IsValid(ent) then return end
     local p, a = ent:CizimKonumu()
     local u, g, hh = Y.VarlikKutu(ent)
     local tur = ent:TurVeri()
     local ileri = Angle(0, a.y, 0):Forward()
     local sag = Angle(0, a.y, 0):Right()
     local sirt = (tur and tur.sirt or 0.55) * hh

     local toplam = 0
     for _, k in ipairs(self.kirler) do
          local q = p + ileri * (k.t * u * 2) + sag * (k.yan * g) + Vector(0, 0, sirt)
          local sc = q:ToScreen()
          k.sx, k.sy = sc.x, sc.y
          toplam = toplam + (1 - k.kir)
          if sc.visible then
               local r = 30 * s * k.boy
               if k.kir > 0 then
                    -- çamur lekesi
                    local alfa = 60 + 170 * k.kir
                    for j = 1, 3 do
                         local ox, oy = math.sin(j * 2.1 + k.t * 9) * r * 0.35, math.cos(j * 1.7 + k.yan * 7) * r * 0.3
                         draw.RoundedBox(r, sc.x + ox - r * 0.6, sc.y + oy - r * 0.6, r * 1.2, r * 1.2, Color(92, 70, 44, alfa * 0.55))
                    end
                    -- ortada küçük altın baklava: ovulacak yer
                    local h = 5 * s
                    draw.NoTexture()
                    surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 90 + 120 * k.kir)
                    surface.DrawPoly({{x = sc.x, y = sc.y - h}, {x = sc.x + h, y = sc.y}, {x = sc.x, y = sc.y + h}, {x = sc.x - h, y = sc.y}})
               elseif k.parladi and simdi - k.parladi < 1.2 then
                    local g2 = (simdi - k.parladi) / 1.2
                    Y.Parilti(sc.x, sc.y, r * (2 + g2 * 3), R.parlak, 200 * (1 - g2))
               end
          end
     end

     -- toz
     for i = #self.toz, 1, -1 do
          local d = self.toz[i]
          local g2 = simdi - d.t
          if g2 > 0.8 then
               table.remove(self.toz, i)
          else
               local x, y = d.x + d.vx * g2, d.y + d.vy * g2 + 60 * g2 * g2
               surface.SetDrawColor(190, 170, 130, 200 * (1 - g2 / 0.8))
               surface.DrawRect(x - 2 * s, y - 2 * s, 4 * s, 4 * s)
          end
     end

     -- ilerleme ve süre
     local oran = toplam / #self.kirler
     T.Yazi("TEMİZLİK", 11, 600, 520, 112, R.sonuk, 0, 2)
     T.Cubuk(520, 124, 560, 8, oran, R.temizlik)
     local kalan = math.max(0, OYUN_SURE.firca - (simdi - self.bas))
     T.Yazi(string.format("%.0f sn", kalan), 11, 600, 1080, 112, kalan < 6 and R.hata or R.sonuk, 2)
     T.Cubuk(520, 138, 560, 3, kalan / OYUN_SURE.firca, R.altin)

     -- fırça imleci
     local mx, my = gui.MousePos()
     local basili = input.IsMouseDown(MOUSE_LEFT)
     Y.Parilti(mx, my, (basili and 70 or 46) * s, R.soluk, basili and 70 or 35)
end

function PANEL:EgitCiz(w, h, s, simdi)
     local T = self.T
     local cx, cy = 800, 470

     -- geçmiş
     for i = 1, TUR_SAYISI do
          local t = self.turlar[i]
          local x = 800 + (i - (TUR_SAYISI + 1) / 2) * 34
          T.Ton(t and (t.puan >= 1 and R.tamam or (t.puan > 0 and R.uyari or R.hata)) or R.kilit, 1)
          T.Baklava(x, 130, t and 8 or 5)
     end

     local c = self.komut
     if c and simdi >= c.bas then
          local oran = math.Clamp((c.hedef - simdi) / self.halkaSure, -0.3, 1)
          -- hedef çember
          T.Ton(R.altin, 0.9)
          T.Yay(cx, cy, 70, 3, 0, math.pi * 2)
          -- daralan halka
          local r = 70 + 150 * math.max(oran, 0)
          local yakin = math.abs(simdi - c.hedef) <= 0.12
          T.Ton(yakin and R.tamam or R.parlak, 0.95)
          T.Yay(cx, cy, r, yakin and 6 or 4, 0, math.pi * 2)
          if yakin then T.Isik(cx, cy, 120, R.tamam, 60) end
          T.Yazi(c.k.ad, 34, "baslik", cx, cy - 8, R.parlak, 1, 4)
          T.Yazi(c.k.ok .. "  " .. c.k.harf, 18, 600, cx, cy + 30, R.altin, 1)
     elseif c then
          T.Yazi("Hazır ol...", 20, "isim", cx, cy, R.sonuk, 1)
     end

     if self.sonYazi and simdi - self.sonYazi.t < 0.9 then
          local a = 1 - (simdi - self.sonYazi.t) / 0.9
          local renk = self.sonYazi.puan >= 1 and R.tamam or (self.sonYazi.puan > 0 and R.uyari or R.hata)
          T.Yazi(self.sonYazi.yazi, 22, "baslik", cx, cy + 150 - a * 20, renk, 1, 2, a)
     end
end

vgui.Register("SardonYaratik.Oyun", PANEL, "EditablePanel")

function Y.OyunAc(tur, id, jeton, ent)
     if IsValid(Y.OyunPaneli) then Y.OyunPaneli:Remove() end
     if IsValid(Y.Radyal) then Y.Radyal:Remove() end
     if not IsValid(ent) then
          Y.Islem("oyun_bitir", jeton, "iptal", 0)
          return
     end
     Y.OyunAcik = true
     if tpEski == nil then TPKapat() end
     local p = vgui.Create("SardonYaratik.Oyun")
     p:Kur(tur, id, jeton, ent)
     Y.OyunPaneli = p
end
