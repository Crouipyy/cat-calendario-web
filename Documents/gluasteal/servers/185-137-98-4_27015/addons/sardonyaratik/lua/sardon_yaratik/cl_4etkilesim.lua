-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\cl_4etkilesim.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: etkileşim (nişan, erişim, yakalama, eşleşme isteği, Kneazle, Jobberknoll)
--
-- Varlıklar katı değil (SOLID_NONE) ve istemcide bölütten çizildiği için sunucu izi işe yaramaz:
-- nişan, çizim konumundaki yönlü kutuyla (tur.kutu × ölçek) istemcide bulunur. E basılınca sunucu
-- yakınlığı yaratığın gerçek bölüt konumuyla yeniden denetler.
--
-- E kancası ve bakım mührü cl_4muhur.lua'da, bakış kartları cl_4kart.lua'da (V2 arayüzü).

local Y = SardonYaratik
local A = Y.Ayar
local R = Y.R

------------------------------------------------------------------------ yaratık kümesi
-- (11-06) ents.FindByClass her çağrıda haritadaki bütün varlıkları (~2300) geziyordu; nişan 20 Hz, yumurta/sersem
-- 4 Hz, Kneazle 1 Hz (saniyede ~29 tam tarama). Varlıklar oluşup silindikçe kümede; 2 sn'de bir tam tazeleme
-- (tam güncelleme, kaçan olay). Dönen liste paylaşılır: çağıran değiştirmez.
local kume, liste, kirli = {}, {}, true
local function kumeTazele()
     table.Empty(kume)
     for _, e in ipairs(ents.FindByClass("sardon_yaratik")) do kume[e] = true end
     kirli = true
end
kumeTazele()
hook.Add("OnEntityCreated", "SardonYaratik.Kume", function(e)
     if IsValid(e) and e:GetClass() == "sardon_yaratik" then kume[e] = true kirli = true end
end)
hook.Add("EntityRemoved", "SardonYaratik.Kume", function(e)
     if kume[e] then kume[e] = nil kirli = true end
end)
timer.Create("SardonYaratik.Kume", 2, 0, kumeTazele)
function Y.YaratikListe()
     if kirli then
          liste = {}
          for e in pairs(kume) do if IsValid(e) then liste[#liste + 1] = e end end
          kirli = false
     end
     return liste
end

------------------------------------------------------------------------ nişan

local hedef, hedefT = nil, 0

local function Kutu(ent)
     local tur = ent:TurVeri()
     if not tur then return end
     local o = ent:Olcek()
     if ent:GetEvre() == 0 then
          return 3 * o, 3 * o, 7 * o
     end
     local k = tur.kutu or {30, 30, 30}
     return k[1] * o * 0.5, k[2] * o * 0.5, k[3] * o
end
Y.VarlikKutu = Kutu

-- 11-14 opt: nişan / yemlik görüş izi için tek girdi ve sonuç tablosu: start, endpos, mask her izden hemen önce
-- yazılır (filter eskisi gibi hiç yok); sonuç hemen okunur, saklanmaz ve döndürülmez
local izSonuc = {}
local izGirdi = {mask = MASK_SOLID_BRUSHONLY, output = izSonuc}

local function HedefBul()
     local ply = LocalPlayer()
     -- 11-14 opt: göz konumu, bakış ışını ve oyuncu konumu tembel: gerektiği ilk yaratıkta bir kez okunur (yakında yaratık
     -- yokken 20 Hz'de vektör yok; döngüde bunları değiştiren bir şey yok, değerler aynı). Işın (yon * 700) her
     -- yaratıkta aynıydı: bir kez çarpılır, IntersectRayWithOBB değiştirmez.
     local bas, isin, benPos
     local enIyi, enD
     for _, ent in ipairs(Y.YaratikListe()) do
          if IsValid(ent) and ent.CizimKonumu and not ent:IsDormant() then
               local p, a = ent:CizimKonumu()
               benPos = benPos or ply:GetPos()
               if p:DistToSqr(benPos) < 420 * 420 then
                    local u, g, h = Kutu(ent)
                    if u then
                         if not bas then bas, isin = EyePos(), EyeAngles():Forward() * 700 end
                         local vur = util.IntersectRayWithOBB(bas, isin, p, Angle(0, a.y, 0), Vector(-u, -g, 0), Vector(u, g, h))
                         if vur then
                              local d = vur:DistToSqr(bas)
                              if not enD or d < enD then
                                   izGirdi.start, izGirdi.endpos, izGirdi.mask = bas, vur, MASK_SOLID_BRUSHONLY
                                   util.TraceLine(izGirdi)
                                   if not izSonuc.Hit or izSonuc.Fraction > 0.98 then enIyi, enD = ent, d end
                              end
                         end
                    end
               end
          end
     end
     return enIyi
end

function Y.Hedef()
     local simdi = RealTime()
     if simdi - hedefT > 0.05 then
          hedefT = simdi
          hedef = HedefBul()
     end
     if IsValid(hedef) then return hedef end
end

-- yemlik: noktanın çevresindeki yönlü kutu (Y.YemlikKutu); arada duvar varsa sayılmaz
local yemlikHedef, yemlikT = nil, 0

local function YemlikBul()
     local ply = LocalPlayer()
     -- 11-14 opt: HedefBul'daki gibi tembel göz / ışın / oyuncu konumu (yakında yemlik yokken vektör yok)
     local bas, isin, benPos
     local enI, enD
     for i, p in ipairs(Y.Alan.yemlik or {}) do
          benPos = benPos or ply:GetPos()
          if p:DistToSqr(benPos) < 400 * 400 then
               if not bas then bas, isin = EyePos(), EyeAngles():Forward() * 600 end
               local vur = util.IntersectRayWithOBB(bas, isin, p, Angle(0, Y.YerYon("yemlik", i), 0), Y.YemlikKutu[1], Y.YemlikKutu[2])
               if vur then
                    local d = vur:DistToSqr(bas)
                    -- 11-14 opt: ucuz mesafe koşulu önce, iz yalnız daha yakın adayda (iz yan etkisiz; sonuç aynı)
                    if not enD or d < enD then
                         izGirdi.start, izGirdi.endpos, izGirdi.mask = bas, vur, MASK_SOLID_BRUSHONLY
                         util.TraceLine(izGirdi)
                         if not izSonuc.Hit or izSonuc.Fraction > 0.98 then enI, enD = i, d end
                    end
               end
          end
     end
     return enI
end

function Y.YemlikHedef()
     local simdi = RealTime()
     if simdi - yemlikT > 0.1 then
          yemlikT = simdi
          yemlikHedef = YemlikBul()
     end
     return yemlikHedef
end

local function YemlikErisimde(i)
     local p = Y.Alan.yemlik and Y.Alan.yemlik[i]
     return p ~= nil and p:Distance(LocalPlayer():GetPos()) <= A.EtkilesimMesafe + 60
end
Y.YemlikErisimde = YemlikErisimde

local function Erisimde(ent)
     local u = Kutu(ent) or 20
     local p = ent:CizimKonumu()
     return p:Distance(LocalPlayer():GetPos()) <= A.EtkilesimMesafe + u
end
Y.Erisimde = Erisimde

local function KullanTusu()
     local bag = input.LookupBinding("+use") or "e"
     local kod = input.GetKeyCode(bag)
     return kod and kod > 0 and input.IsKeyDown(kod)
end

------------------------------------------------------------------------ yardımcılar

local function Kalan(k, eylem, sure)
     if not k or not k.sonEtk then return 0 end
     return math.max(0, (k.sonEtk[eylem] or 0) + sure - Y.SunucuZamani())
end
Y.EylemKalan = Kalan

local function Envanter()
     local char = LocalPlayer():GetCharacter()
     return char and char:GetInventory()
end

function Y.YemAdetleri()
     local out = {}
     local inv = Envanter()
     if not inv then return out end
     for _, it in pairs(inv:GetItemsByUniqueID("yaratik_yem", true) or {}) do
          local y = it:GetData("yem", "genel")
          out[y] = (out[y] or 0) + it:GetData("adet", 1)
     end
     return out
end

function Y.EsyaVarMi(uid, bos)
     local inv = Envanter()
     if not inv then return false end
     for _, it in pairs(inv:GetItemsByUniqueID(uid, true) or {}) do
          if not bos or not it:GetData("yid") then return true end
     end
     return false
end

------------------------------------------------------------------------ yabani / eş adayları

-- yabani yaratık (Faz 3): kayıtsız varlık, Durum ENT_YABANI / ENT_SERSEM
local function Yabani(ent)
     local d = ent:GetDurum()
     return d == (Y.ENT_YABANI or 4) or d == (Y.ENT_SERSEM or 5)
end
Y.YabaniMi = Yabani

-- yakındaki aynı türden, karşı cins yetişkinler (kendi ya da başkasının; başkasınınkine istek gider)
function Y.EsAdaylari(ent)
     local k = Y.BenimKayit(ent:GetKimlik())
     local out = {}
     if not k or not k.cins then return out end
     local karsi = k.cins == "e" and "d" or "e"
     local p = ent:CizimKonumu()
     for _, e in ipairs(Y.YaratikListe()) do
          if IsValid(e) and e ~= ent and e:GetKimlik() > 0 and e:GetTur() == ent:GetTur() and e:GetEvre() >= 3 and e:GetDurum() <= 2
               and e:GetNW2String("SYCins", "") == karsi and e:CizimKonumu():DistToSqr(p) < 900 * 900 then
               local sahip = e:GetSahip()
               local benim = sahip == LocalPlayer()
               local ad = e:GetAd() ~= "" and e:GetAd() or (e:TurVeri() or {}).ad or "?"
               out[#out + 1] = {ad = ad, alt = benim and ("senin · " .. Y.CinsAdi(karsi)) or ((IsValid(sahip) and sahip:Nick() or "?") .. " · onay ister"),
                    op = "esles", ek = tostring(e:GetKimlik()), aktif = true}
          end
     end
     return out
end

-- Bakım mührü, bakış kartları ve E kancası: cl_4muhur.lua, cl_4kart.lua (V2).

------------------------------------------------------------------------ yakalama (Faz 3)

-- E bırakılınca yakalama biter (sunucu yakalama yoksa yok sayar)
hook.Add("Think", "SardonYaratik.Yakala", function()
     if not Y.YakalaTus or KullanTusu() then return end
     Y.YakalaTus = nil
     Y.Islem("yakala", 0, "birak")
end)

-- ilerleme halkası (sunucu NW2: SYYakalaBas / SYYakalaSure)
hook.Add("HUDPaint", "SardonYaratik.YakalaHalka", function()
     local ply = LocalPlayer()
     local bas = ply:GetNW2Float("SYYakalaBas", 0)
     if bas <= 0 then return end
     local sure = math.max(ply:GetNW2Float("SYYakalaSure", 1), 0.1)
     local f = math.Clamp((CurTime() - bas) / sure, 0, 1)
     local s = math.max(ScrH() / 1080, 0.6)
     local cx, cy = ScrW() / 2, ScrH() / 2 + 70 * s
     local r = 28 * s
     local n = 60
     for i = 0, n - 1 do
          local a = math.rad(i / n * 360 - 90)
          local dolu = i / n < f
          if dolu then surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 255) else surface.SetDrawColor(30, 40, 34, 220) end
          surface.DrawRect(cx + math.cos(a) * r - 2.5 * s, cy + math.sin(a) * r - 2.5 * s, 5 * s, 5 * s)
     end
     Y.Parilti(cx, cy, r * 3.2, R.altin, 30 + 50 * f)
     draw.SimpleText(math.floor(f * 100) .. "%", Y.Font(14 * s, 600), cx, cy, R.parlak, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     draw.SimpleText("Yakalanıyor · E'yi bırakma", Y.Font(12 * s, 600), cx, cy + r + 14 * s, R.soluk, TEXT_ALIGN_CENTER)
end)

------------------------------------------------------------------------ eşleşme isteği (Faz 3)

local ISTEK = {}

function ISTEK:Init()
     local s = math.max(ScrH() / 1080, 0.6)
     self.s = s
     self:SetSize(440 * s, 150 * s)
     self:SetPos((ScrW() - self:GetWide()) / 2, ScrH() * 0.62)
     self:MakePopup()
     self:SetKeyboardInputEnabled(false)
     self.acilis = RealTime()
     local function Dugme(yazi, x, op, renk)
          local b = self:Add("DButton")
          b:SetText("")
          b:SetSize(130 * s, 34 * s)
          b:SetPos(x, self:GetTall() - 46 * s)
          b.Paint = function(d, w, h)
               local ust = d:IsHovered()
               surface.SetDrawColor(ust and 34 or 16, ust and 44 or 30, ust and 30 or 24, 250)
               surface.DrawRect(0, 0, w, h)
               surface.SetDrawColor(renk.r, renk.g, renk.b, 255)
               surface.DrawOutlinedRect(0, 0, w, h, 1)
               draw.SimpleText(yazi, Y.Font(14 * s, "baslik"), w / 2, h / 2, ust and R.parlak or renk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          end
          b.DoClick = function()
               surface.PlaySound("ui/buttonclickrelease.wav")
               Y.Islem("esles_cevap", 0, op)
               self:Remove()
          end
     end
     Dugme("KABUL", self:GetWide() / 2 - 140 * s, "kabul", R.altin)
     Dugme("REDDET", self:GetWide() / 2 + 10 * s, "red", R.hata)
end

function ISTEK:Kur(kimden, onunki, benimki, turAd, sure, saat)
     self.kimden, self.onunki, self.benimki, self.turAd, self.sure, self.saat = kimden, onunki, benimki, turAd, sure, saat
end

function ISTEK:Think()
     if RealTime() - self.acilis > (self.sure or 60) then self:Remove() end
end

function ISTEK:Paint(w, h)
     local s = self.s
     surface.SetDrawColor(7, 18, 13, 245)
     surface.DrawRect(0, 0, w, h)
     surface.SetDrawColor(R.sevgi.r, R.sevgi.g, R.sevgi.b, 255)
     surface.DrawRect(0, 0, w, 2 * s)
     surface.SetDrawColor(58, 70, 52, 255)
     surface.DrawOutlinedRect(0, 0, w, h, 1)
     draw.SimpleText("EŞLEŞME İSTEĞİ", Y.Font(15 * s, "baslik"), 14 * s, 10 * s, R.altin)
     local kalan = math.max(0, math.ceil((self.sure or 60) - (RealTime() - self.acilis)))
     draw.SimpleText(kalan .. " sn", Y.Font(12 * s, 400), w - 14 * s, 12 * s, R.sonuk, TEXT_ALIGN_RIGHT)
     -- adlara ek getirmeden (Türkçe ünlü uyumu adın son harfine bağlı)
     draw.SimpleText((self.kimden or "?") .. " eşleştirmek istiyor:", Y.Font(13 * s, 600), 14 * s, 38 * s, R.parlak)
     draw.SimpleText(string.format("%s (onun)  +  %s (senin)  ·  %s", self.onunki or "?", self.benimki or "?", self.turAd or ""),
          Y.Font(13 * s, 600), 14 * s, 58 * s, R.altin)
     draw.SimpleText((self.saat and self.saat > 0) and ("Çiftleşme Ağılı'nda ~" .. self.saat .. " saat kalırlar · yumurta isteği gönderenin.")
          or "Yumurta isteği gönderene gider.", Y.Font(12 * s, 400), 14 * s, 80 * s, R.sonuk)
end

vgui.Register("SardonYaratik.EslesIstek", ISTEK, "EditablePanel")

net.Receive(Y.NET.ESLES, function()
     local kimden, onunki, benimki, turAd, sure = net.ReadString(), net.ReadString(), net.ReadString(), net.ReadString(), net.ReadUInt(8)
     local saat = net.ReadUInt(8)
     if IsValid(Y.EslesPanel) then Y.EslesPanel:Remove() end
     local p = vgui.Create("SardonYaratik.EslesIstek")
     p:Kur(kimden, onunki, benimki, turAd, sure, saat)
     Y.EslesPanel = p
     surface.PlaySound("ambient/levels/canals/windchime2.wav")
end)

------------------------------------------------------------------------ Kneazle: tehlike sezgisi (Faz 4)

-- Yanında yürüyen genç/yetişkin Kneazle (ya da Sezgi İksiri, NW2 "SYSezgi"); sana asa doğrultanı,
-- yakındaki kurt adamı ve yabani Graphorn'u sezer: tıslar, ekranın kenarında yönünü gösterir.
local sezgi = {liste = {}, son = {}, t = 0, kn = nil, knT = 0}

local function Kneazle()
     local simdi = RealTime()
     if simdi < sezgi.knT then return sezgi.kn end
     sezgi.knT = simdi + 1
     sezgi.kn = nil
     local ben = LocalPlayer()
     for _, e in ipairs(Y.YaratikListe()) do
          if IsValid(e) and e:GetTur() == "kneazle" and e:GetSahip() == ben and e:GetDurum() == 2 and e:GetEvre() >= 2 then
               sezgi.kn = e
               break
          end
     end
     return sezgi.kn
end

local SEZGI_YAZI = {asa = "Sana asa doğrultuldu", kurt = "Kurt adam", graphorn = "Graphorn"}

local function Sez(hedef, tur, kn)
     local simdi = RealTime()
     local anahtar = tostring(hedef) .. tur
     if (sezgi.son[anahtar] or 0) > simdi then
          for _, u in ipairs(sezgi.liste) do if u.hedef == hedef and u.tur == tur then u.bitis = simdi + 3 end end
          return
     end
     sezgi.son[anahtar] = simdi + A.Yetenek.Sezgi.Bekleme
     table.insert(sezgi.liste, {hedef = hedef, tur = tur, bitis = simdi + 5})
     if IsValid(kn) then
          sound.Play("npc/headcrab_poison/ph_hiss1.wav", kn:GetPos(), 70, math.random(150, 175), 0.8)
     else
          surface.PlaySound("ambient/levels/canals/windchime5.wav")
     end
end

hook.Add("Think", "SardonYaratik.KneazleSezgi", function()
     local simdi = RealTime()
     if simdi < sezgi.t then return end
     sezgi.t = simdi + 0.4
     local kn = Kneazle()
     local ben = LocalPlayer()
     sezgi.iksir = not IsValid(kn) and ben:GetNW2Bool("SYSezgi", false)
     if not IsValid(kn) and not sezgi.iksir then return end
     local S = A.Yetenek.Sezgi
     local mp, goz = ben:GetPos(), ben:EyePos()
     for _, o in ipairs(player.GetAll()) do
          if o ~= ben and o:Alive() then
               local d = o:GetPos():Distance(mp)
               if d < S.Kurt and o:GetNW2Bool("KurtAdam", false) then Sez(o, "kurt", kn) end
               local w = o:GetActiveWeapon()
               if d < S.Asa and IsValid(w) and w:GetClass() == "weapon_hpwr_stick" and (not o.IsWepRaised or o:IsWepRaised()) then
                    local yon = (goz - o:EyePos()):GetNormalized()
                    if o:GetAimVector():Dot(yon) > 0.985 then
                         local tr = util.TraceLine({start = o:EyePos(), endpos = goz, filter = {o, ben}, mask = MASK_SOLID_BRUSHONLY})
                         if not tr.Hit then Sez(o, "asa", kn) end
                    end
               end
          end
     end
     for _, e in ipairs(Y.YaratikListe()) do
          if IsValid(e) and e:GetTur() == "graphorn" and e:GetDurum() == (Y.ENT_YABANI or 4) and e:GetPos():Distance(mp) < S.Graphorn then
               Sez(e, "graphorn", kn)
          end
     end
end)

-- ekran kenarında, tehdidin yönünü gösteren üçgen ve yazı
local function Ucgen(cx, cy, aci, r, boy, renk)
     local ux, uy = math.sin(aci), -math.cos(aci)
     local px, py = -uy, ux
     local uc = {x = cx + ux * (r + boy), y = cy + uy * (r + boy)}
     local a = {x = cx + ux * r + px * boy * 0.7, y = cy + uy * r + py * boy * 0.7}
     local b = {x = cx + ux * r - px * boy * 0.7, y = cy + uy * r - py * boy * 0.7}
     -- köşeler saat yönünde olmalı (DrawPoly ters sırayı çizmez)
     local t = {uc, a, b}
     if (a.x - uc.x) * (b.y - uc.y) - (a.y - uc.y) * (b.x - uc.x) < 0 then t = {uc, b, a} end
     draw.NoTexture()
     surface.SetDrawColor(renk.r, renk.g, renk.b, renk.a or 255)
     surface.DrawPoly(t)
end

hook.Add("HUDPaint", "SardonYaratik.KneazleSezgi", function()
     if #sezgi.liste == 0 then return end
     local simdi = RealTime()
     local s = math.max(ScrH() / 1080, 0.6)
     local cx, cy = ScrW() / 2, ScrH() / 2
     local r = math.min(ScrW(), ScrH()) * 0.36
     local goz, bakis = EyePos(), EyeAngles().y
     for i = #sezgi.liste, 1, -1 do
          local u = sezgi.liste[i]
          if simdi > u.bitis or not IsValid(u.hedef) then
               table.remove(sezgi.liste, i)
          else
               local d = u.hedef:GetPos() - goz
               local aci = math.rad(-math.AngleDifference(d:Angle().y, bakis))
               local nabiz = 0.6 + 0.4 * math.abs(math.sin(simdi * 6))
               local renk = Color(Y.R.hata.r, Y.R.hata.g, Y.R.hata.b, 255 * nabiz)
               Ucgen(cx, cy, aci, r, 18 * s, renk)
               local yx, yy = cx + math.sin(aci) * (r - 26 * s), cy - math.cos(aci) * (r - 26 * s)
               draw.SimpleText(SEZGI_YAZI[u.tur] or "", Y.Font(13 * s, 600), yx, yy, Color(242, 224, 179, 230 * nabiz), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          end
     end
     draw.SimpleText(sezgi.iksir and "Sezgi İksiri" or "Kneazle tıslıyor", Y.Font(12 * s, 600), cx, cy + r + 30 * s, Color(Y.R.hata.r, Y.R.hata.g, Y.R.hata.b, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

------------------------------------------------------------------------ Jobberknoll: dinle / haykırış (Faz 4)

local TUR_BICIM = {w = "fısıldadı", y = "bağırdı", me = "", it = ""}

local function SatirYazi(s)
     if s.t == "me" then return "* " .. s.ad .. " " .. s.m end
     if s.t == "it" then return "** " .. s.m end
     local fiil = TUR_BICIM[s.t]
     return s.ad .. (fiil and fiil ~= "" and (" (" .. fiil .. ")") or "") .. ": " .. s.m
end

local TANIK = {}

function TANIK:Init()
     local s = math.max(ScrH() / 1080, 0.6)
     self.s = s
     self:SetSize(560 * s, 460 * s)
     self:Center()
     self:MakePopup()
     self:SetKeyboardInputEnabled(false)
     local kapat = self:Add("DButton")
     kapat:SetText("")
     kapat:SetSize(120 * s, 32 * s)
     kapat:SetPos(self:GetWide() - 132 * s, self:GetTall() - 44 * s)
     kapat.Paint = function(d, w, h)
          surface.SetDrawColor(d:IsHovered() and 34 or 16, d:IsHovered() and 44 or 30, d:IsHovered() and 30 or 24, 250)
          surface.DrawRect(0, 0, w, h)
          surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 255)
          surface.DrawOutlinedRect(0, 0, w, h, 1)
          draw.SimpleText("KAPAT", Y.Font(14 * s, "baslik"), w / 2, h / 2, d:IsHovered() and R.parlak or R.altin, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end
     kapat.DoClick = function() self:Remove() end
     self.liste = self:Add("DScrollPanel")
     self.liste:SetPos(14 * s, 64 * s)
     self.liste:SetSize(self:GetWide() - 28 * s, self:GetTall() - 120 * s)
end

function TANIK:Kur(veri)
     self.ad = veri.ad or "Jobberknoll"
     self.baslik, self.alt = veri.baslik, veri.alt -- Tanık İksiri (sv_9iksir.lua)
     local s = self.s
     local simdi = veri.simdi or os.time()
     for _, satir in ipairs(veri.satirlar or {}) do
          local l = self.liste:Add("DLabel")
          l:SetFont(Y.Font(13 * s, 400))
          l:SetTextColor(R.yazi)
          l:SetWrap(true)
          l:SetAutoStretchVertical(true)
          l:Dock(TOP)
          l:DockMargin(0, 0, 8 * s, 8 * s)
          l:SetText(Y.SureYazi(math.max(simdi - (satir.z or simdi), 0)) .. " önce — " .. SatirYazi(satir))
     end
end

function TANIK:Paint(w, h)
     local s = self.s
     surface.SetDrawColor(7, 18, 13, 245)
     surface.DrawRect(0, 0, w, h)
     surface.SetDrawColor(R.bag.r, R.bag.g, R.bag.b, 255)
     surface.DrawRect(0, 0, w, 2 * s)
     surface.SetDrawColor(58, 70, 52, 255)
     surface.DrawOutlinedRect(0, 0, w, h, 1)
     draw.SimpleText(self.baslik or "SESSİZ TANIK", Y.Font(16 * s, "baslik"), 14 * s, 12 * s, R.altin)
     draw.SimpleText(self.alt or ((self.ad or "") .. " yanında söylenenleri hatırlıyor (en yeni üstte)"), Y.Font(12 * s, 400), 14 * s, 36 * s, R.sonuk)
end

vgui.Register("SardonYaratik.Tanik", TANIK, "EditablePanel")

net.Receive(Y.NET.YETENEK, function()
     local tur = net.ReadString()
     local veri = net.ReadTable() or {}
     if tur == "delilik" then
          if Y.DelilikBaslat then Y.DelilikBaslat(veri) end
     elseif tur == "tanik" then
          if IsValid(Y.TanikPanel) then Y.TanikPanel:Remove() end
          local p = vgui.Create("SardonYaratik.Tanik")
          p:Kur(veri)
          Y.TanikPanel = p
     elseif tur == "haykir" then
          chat.AddText(Color(201, 182, 238), "Ölmekte olan " .. (veri.ad or "Jobberknoll") .. ", duyduğu her şeyi tersten haykırıyor:")
          for _, satir in ipairs(veri.satirlar or {}) do
               chat.AddText(Color(232, 222, 250), "   «" .. SatirYazi(satir) .. "»")
          end
          surface.PlaySound("ambient/voices/f_scream1.wav")
     end
end)
