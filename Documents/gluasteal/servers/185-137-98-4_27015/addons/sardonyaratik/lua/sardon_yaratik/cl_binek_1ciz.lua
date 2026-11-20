-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\cl_binek_1ciz.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: binek (istemci) — çizim, kamera, tuş, olaylar
--
-- Binen her oyuncunun altına yaratığın ClientsideModel'i çizilir (NW2 "SYBinek"). Gövde yönü
-- hızdan, havada burun eğimi ve dönüşe yatma da hızdan, yerde eğim zeminden hesaplanır; animasyon
-- karesi modelin ölçülmüş adım hızına göre ilerletilir. Binici eyer kemiğine oturtulur: oturma pozundaki leğen kemiği eyere denk gelecek
-- şekilde render origin kaydırılır.
--
-- Thestral'i yalnız "Ölüm Görmüş" (NW2 "SYOlum") oyuncular görür; görmeyenler biniciyi havada
-- oturur görür.

local Y = SardonYaratik
local band = bit.band

------------------------------------------------------------------------ Thestral görünürlüğü

function Y.ThestralGorur()
     local ply = LocalPlayer()
     return IsValid(ply) and (ply:GetNW2Bool("SYOlum", false) or ply:GetNW2Bool("SYThestralGorus", false))
end

function Y.CizimEngeli(ent)
     return ent:GetTur() == "thestral" and ent:GetEvre() > 0 and not Y.ThestralGorur()
end

------------------------------------------------------------------------ binek modelleri

-- canlı yenilemede önceki sürümün modelleri (gizli ama bellekte) kalmasın
for _, eski in pairs(Y.BinekCizimleri or {}) do
     if IsValid(eski.mdl) then eski.mdl:Remove() end
end
local binekler = {} -- [oyuncu] = durum
Y.BinekCizimleri = binekler

local function Kur(ply, kod)
     local o = binekler[ply]
     if o and IsValid(o.mdl) then o.mdl:Remove() end
     binekler[ply] = nil

     local _, turId, bg, nadir, evre = Y.BinekKodCoz(kod)
     local tur, b = Y.Turler[turId], Y.Binekler[turId]
     if not tur or not b or not file.Exists(tur.model, "GAME") then return end

     local mdl = ClientsideModel(tur.model, RENDERGROUP_OPAQUE)
     if not IsValid(mdl) then return end
     mdl:SetNoDraw(true)
     local grup = mdl:FindBodygroupByName("staylofft_color")
     if grup and grup >= 0 then mdl:SetBodygroup(grup, bg) end
     local olcek = (tur.olcek or 1) * ((Y.Evreler[evre] or {}).olcek or 1)
     mdl:SetModelScale(olcek, 0)

     o = {
          kod = kod, mdl = mdl, tur = tur, b = b, turId = turId, nadir = nadir, olcek = olcek,
          yaw = ply:EyeAngles().y, pitch = 0, bank = 0, cycle = 0, anim = nil, son = RealTime(),
          kemik = mdl:LookupBone(b.eyer.kemik),
     }
     binekler[ply] = o
     return o
end

local function Sekans(o, ad)
     o.seqler = o.seqler or {}
     local s = o.seqler[ad]
     if not s then
          s = o.mdl:LookupSequence(ad) or -1
          if s < 0 then s = o.mdl:LookupSequence("idle") or 0 end
          o.seqler[ad] = s
     end
     return s
end

-- Kanatlı modellerin (fly sekansı olanlar) sadeleştirilmiş LOD1/LOD2 ağlarında kanatlar kemiklere
-- bağlı değil: kamera biraz uzaklaşınca kanatlar animasyondan bağımsız, açık ve düz kalıyordu
-- (uçarken hiç çırpmıyor, yerde açık duruyor). Öbür hayvanlar da orta mesafede kaba LOD'a erken
-- düşüyordu. Bu mesafelerin içinde LOD0'a zorlanır, uzakta motor seçer. Dünyadaki yaratık varlığı
-- da (entities/sardon_yaratik.lua) bunu kullanır.
local LOD_KANATLI, LOD_DIGER = 3500, 3000
local kanatli = {}
function Y.KanatLOD(ent, pos)
     local m = ent:GetModel()
     local k = kanatli[m]
     if k == nil then
          k = (ent:LookupSequence("fly") or -1) >= 0
          kanatli[m] = k
     end
     local esik = k and LOD_KANATLI or LOD_DIGER
     local lod = EyePos():DistToSqr(pos) < esik * esik and 0 or -1
     if ent.YLod ~= lod then
          ent.YLod = lod
          ent:SetLOD(lod)
     end
end

-- yürüyüş ile dörtnal arasında geçişte kare kaldığı yerden sürer: bacak pozu sıçramaz
local AILE = {walk = "kara", run = "kara"}

-- Modelin kendi adım hızı (ayak kemiklerinden ölçülmüş, ölçek 1'de; tur.adim) × model ölçeği:
-- oynatma hızı = gerçek hız / bu, ayaklar yerde kaymaz.
local function Dogal(o, kos)
     local a = o.tur.adim or o.tur.animHiz
     return math.max((kos and a.kos or a.yuru) * o.olcek, 1)
end

-- animasyon adı ve oynatma hızı; eşiklerde tolerans var (sınırda gidip gelmesin)
local function AnimSec(ply, o, w, vel, now)
     local hiz = vel:Length2D()
     if w and w:GetUcuyor() then
          -- pikede kanatlar toplanır; geri kalan her şeyde kanat çırpar, sıklığı eforla değişir
          if w:GetPike() then return "glide", 0.6 end
          if now - w:GetCirpisT() < 0.9 then return "fly", 1.6 end
          -- W ile düzenli, tuşsuz süzülüşte ağır ve geniş; hedef hızın altında kaldıkça ve tırmandıkça
          -- sıklaşır, dik inişte daha da ağırlaşır (oran sürekli, sıçramaz)
          local h, carpan, itis = o.b.hava, Y.BinekNadirHiz(w), w:GetItis()
          local hedef = itis and h.seyir * carpan * 0.95 or (h.suzulus or h.seyir * 0.78) * carpan
          local yavas = math.Clamp((hedef - vel:Length()) / math.max(hedef - h.asgari, 1), 0, 1)
          local efor = math.max(yavas, math.Clamp(vel.z / 300, 0, 1))
          return "fly", (itis and 1 or 0.72) + 0.45 * efor - 0.12 * math.Clamp(-vel.z / 300, 0, 1)
     end
     if o.suda then return "swim", math.Clamp(0.6 + hiz / 150, 0.6, 1.5) end
     if not ply:IsOnGround() and o.b.ucar then return "fly", 1.2 end
     if w and now < w:GetSendele() then return "idle", 1.6 end
     local durEsik = (o.anim == "walk" or o.anim == "run") and 6 or 14
     if hiz < durEsik then
          -- uzun süre durunca arada tımarlanır ya da otlanır (herkeste aynı sırayla: zaman dilimi)
          o.durT = o.durT or now
          if now - o.durT > 6 and w then
               local dilim = math.floor((now - w:GetBinisT()) / 14) + w:GetKimlik()
               local secim = dilim % 6
               if secim == 3 then return "groom", 1 end
               if secim == 5 then return "eat", 1 end
          end
          return "idle", 1
     end
     o.durT = nil
     local nw, nr = Dogal(o, false), Dogal(o, true)
     local k = o.b.kara
     local carpan = w and Y.BinekNadirHiz(w) or 1
     -- yürüyüşten dörtnala iki animasyonun da en az bozulduğu hızda geçer
     local esik = math.Clamp(math.sqrt(nw * nr), k.yuru * carpan * 1.15, k.kos * carpan * 0.8)
     if hiz < esik * (o.anim == "run" and 0.92 or 1.05) then
          return "walk", (o.geri and -1 or 1) * math.Clamp(hiz / nw, 0.35, 2.1)
     end
     return "run", math.Clamp(hiz / nr, 0.45, 1.7)
end

-- yokuşta gövde eğimi: ön ve arka ayak altındaki zeminin farkı (+ burun aşağı)
local function ZeminEgim(pos, yaw, yari)
     local f = Angle(0, yaw, 0):Forward() * yari
     local yuk, asagi = Vector(0, 0, 44), Vector(0, 0, 90)
     local on = util.TraceLine({start = pos + f + yuk, endpos = pos + f - asagi, mask = MASK_PLAYERSOLID_BRUSHONLY})
     local ar = util.TraceLine({start = pos - f + yuk, endpos = pos - f - asagi, mask = MASK_PLAYERSOLID_BRUSHONLY})
     if not on.Hit or not ar.Hit or on.StartSolid or ar.StartSolid then return 0 end
     return math.Clamp(math.deg(math.atan2(ar.HitPos.z - on.HitPos.z, 2 * yari)), -22, 22)
end

local pelvisAd = "ValveBiped.Bip01_Pelvis"

-- Oyuncu modelinde SetRenderOrigin işlemiyor; binici kök kemiğin (pelvis) konum kaydırmasıyla eyere
-- taşınır (aksesuarlar kemiğe bağlı olduğu için onlar da gelir), yönü UpdateAnimation'da verilir.
local function PelvisSifirla(ply)
     local i = ply:LookupBone(pelvisAd)
     if i then ply:ManipulateBonePosition(i, vector_origin) end
end

function Y.BinekGovde(ply)
     local o = binekler[ply]
     if o then
          o.renderYaw = o.yaw
          ply:SetRenderAngles(Angle(0, o.yaw, 0))
     end
end

local function KemikPoz(ply, aktif)
     for ad, a in pairs(Y.BinekPoz.kemik) do
          local i = ply:LookupBone(ad)
          if i then ply:ManipulateBoneAngles(i, aktif and a or angle_zero) end
     end
end

local function Guncelle(ply, o)
     local ft = math.min(RealFrameTime(), 0.1)
     local now = CurTime()
     local w = Y.BinekSilah(ply)
     local b = o.b
     -- hız yumuşatılır: tahmin ve ağ güncellemesindeki küçük dalgalanmalar gövdeyi titretmesin
     local hamV = ply:GetVelocity()
     o.v = o.v and LerpVector(math.min(ft * 8, 1), o.v, hamV) or hamV
     local vel = o.v
     local ucuyor = w and w:GetUcuyor()
     -- yüzüyor mu: hareketle aynı sına (_sh_6binek.lua Y.BinekSuda); yüzme ayarı olmayanda motor yüzmesi
     local yuzey = not ucuyor and Y.BinekSuda(ply:GetPos(), b) or nil
     o.suda = yuzey ~= nil or (not ucuyor and not b.yuzme and ply:WaterLevel() >= 2)

     -- geri geri yürüyüş: duruştan bakışın tersine kalkınca gövde dönmez, adımlar tersine oynar
     local yh = vel:Length2D()
     if ucuyor or yh < 6 then
          o.geri = false
     else
          local fark = math.abs(math.AngleDifference(vel:Angle().y, ply:EyeAngles().y))
          if o.geri then
               if fark < 120 then o.geri = false end
          elseif yh < 40 and yh > (o.yh or 0) and fark > 160 then
               o.geri = true
          end
     end
     o.yh = yh

     ------------------------------------------------------------ yön, eğim, yatış
     local hedefYaw = o.yaw
     local hedefPitch, hedefBank = 0, 0
     if ucuyor then
          if vel:LengthSqr() > 400 then
               local va = vel:Angle()
               hedefYaw = va.y
               hedefPitch = math.Clamp(math.NormalizeAngle(va.p), -40, w:GetPike() and 65 or 45)
          end
     elseif w and b.hucum and now < w:GetHucumBas() + b.hucum.sure then
          hedefYaw = w:GetHucumYaw()
     else
          if vel:Length2DSqr() > 30 * 30 then hedefYaw = vel:Angle().y + (o.geri and 180 or 0) end
          if ply:IsOnGround() then
               if now >= (o.egimT or 0) then
                    o.egimT = now + 0.05
                    o.egim = ZeminEgim(ply:GetPos(), o.yaw, (o.tur.kutu and o.tur.kutu[1] or 60) * o.olcek * 0.45)
               end
               hedefPitch = o.egim or 0
          end
     end
     local onceYaw = o.yaw
     o.yaw = math.ApproachAngle(o.yaw, hedefYaw, ft * (ucuyor and 180 or 260))
     local donusHizi = math.AngleDifference(o.yaw, onceYaw) / math.max(ft, 0.001)
     o.donus = Lerp(math.min(ft * 4, 1), o.donus or 0, donusHizi)
     if ucuyor then
          hedefBank = math.Clamp(-o.donus * 0.3, -40, 40)
     elseif yh > 200 then
          -- dörtnalda dönüşe hafifçe yatar
          hedefBank = math.Clamp(-o.donus * 0.06, -9, 9)
     end

     -- Graphorn yere vururken şahlanır
     if w and b.yereVur then
          local t = now - w:GetVurusT()
          if t >= 0 and t < 0.7 then
               hedefPitch = t < 0.3 and -24 * (t / 0.3) or -24 * (1 - (t - 0.3) / 0.4)
          end
     end
     if w and now < w:GetSendele() then hedefBank = math.sin(now * 14) * 6 end

     o.pitch = Lerp(math.min(ft * 3.5, 1), o.pitch, hedefPitch)
     o.bank = Lerp(math.min(ft * 3, 1), o.bank, hedefBank)
     o.son = RealTime()

     ------------------------------------------------------------ animasyon
     local anim, hiz = AnimSec(ply, o, w, vel, now)
     -- seçim en az 0.35 sn tutulur (kanat çırpışı hariç)
     if o.anim and anim ~= o.anim and now - (o.animT or 0) < 0.35 and not (anim == "fly" and w and now - w:GetCirpisT() < 0.1) then
          anim = o.anim
     end
     local seq = Sekans(o, anim)
     if o.anim ~= anim then
          if not (AILE[anim] and AILE[anim] == AILE[o.anim]) then o.cycle = 0 end
          o.anim = anim
          o.animT = now
          o.mdl:ResetSequence(seq)
          o.hiz = hiz
     end
     o.hiz = Lerp(math.min(ft * 5, 1), o.hiz or hiz, hiz)
     local sure = math.max(o.mdl:SequenceDuration(seq), 0.05)
     o.cycle = (o.cycle + ft * o.hiz / sure) % 1
     o.mdl:SetSequence(seq)
     o.mdl:SetCycle(o.cycle)
     o.mdl:SetPlaybackRate(0)

     ------------------------------------------------------------ konum
     local gorsel = Angle(o.pitch, o.yaw, o.bank)
     local merkezH = b.boy * 0.35
     local pos = ply:GetPos()
     -- suda yüzme sekansının su çizgisi (tur.suCizgi) yüzeye oturur, hafifçe iner kalkar; suya girip
     -- çıkarken kayma yumuşak
     local suOfs = 0
     if yuzey then
          suOfs = yuzey - pos.z - (o.tur.suCizgi or 36) * o.olcek + math.sin(now * 2.4 + ply:EntIndex()) * 1.5
     end
     o.suOfs = Lerp(math.min(ft * 4, 1), o.suOfs or 0, suOfs)
     local mpos = pos + Vector(0, 0, merkezH + o.suOfs) - gorsel:Up() * merkezH
     local mang = Angle(gorsel.p, gorsel.y, gorsel.r)
     mang:RotateAroundAxis(mang:Up(), o.tur.yonOfset or -90)
     o.mdl:SetPos(mpos)
     o.mdl:SetAngles(mang)
     Y.KanatLOD(o.mdl, mpos)
     o.mdl:SetupBones()

     ------------------------------------------------------------ su: giriş sıçraması, dalga, kulaç sesi
     -- (Thestral görünmese de su çalkalanır)
     if yuzey and EyePos():DistToSqr(pos) < 3000 * 3000 then
          local yp = Vector(pos.x, pos.y, yuzey)
          if not o.sudaydi then
               local ed = EffectData()
               ed:SetOrigin(yp)
               ed:SetNormal(Vector(0, 0, 1))
               ed:SetScale(math.Clamp(-vel.z / 30, 8, 18))
               util.Effect("watersplash", ed)
               sound.Play("ambient/water/water_splash" .. math.random(1, 3) .. ".wav", yp, 75, math.random(90, 105), 0.8)
          end
          if now >= (o.dalgaT or 0) then
               o.dalgaT = now + (yh > 40 and 0.3 or 1)
               local ed = EffectData()
               ed:SetOrigin(yp + Angle(0, o.yaw, 0):Forward() * (yh > 40 and b.hull or 0))
               ed:SetNormal(Vector(0, 0, 1))
               ed:SetScale(yh > 40 and 10 or 7)
               ed:SetFlags(0)
               util.Effect("waterripple", ed)
          end
          if o.anim == "swim" and o.cycle < (o.kulacCycle or 0) then
               sound.Play("player/footsteps/wade" .. math.random(1, 8) .. ".wav", yp, 68, math.random(78, 92), yh > 30 and 0.7 or 0.35)
          end
     end
     o.kulacCycle = o.cycle
     o.sudaydi = yuzey ~= nil

     o.gorunmez = b.gorunmez and not Y.ThestralGorur()
     if not o.gorunmez then
          -- nadirlik parıltısı (dünyadaki yaratıklardaki gibi)
          if o.nadir >= 2 and (o.parT or 0) < now and EyePos():DistToSqr(pos) < 1500 * 1500 then
               o.parT = now + (o.nadir == 3 and 0.18 or 0.45)
               local r = (Y.Nadirlik[o.nadir] or Y.Nadirlik[1]).renk
               local u = b.hull * 1.6
               Y.Kivilcim(pos + Vector(math.Rand(-u, u), math.Rand(-u, u), math.Rand(b.boy * 0.3, b.boy * 0.8)), r, 1, 8, 1.4, o.nadir == 3 and 3 or 2, 10)
          end
     end

     ------------------------------------------------------------ binici eyerde
     local eyer
     local m = o.kemik and o.mdl:GetBoneMatrix(o.kemik)
     if m then
          eyer = m:GetTranslation()
     else
          eyer = mpos + gorsel:Up() * (b.boy * 0.6)
     end
     eyer = eyer + gorsel:Up() * b.eyer.ust + gorsel:Forward() * b.eyer.ileri

     -- Kaydırma her karede taze hesaplanır: kaydırmasız kemik kurulumu bu karenin konumunda yapılır,
     -- pelvisin yeri ölçülür, eyere olan fark model uzayına çevrilir (önceki kareden hesaplamak hızlı
     -- giderken biniciyi bir kare ileri / geri oynatıyordu).
     o.pelvis = o.pelvis or ply:LookupBone(pelvisAd)
     if o.pelvis then
          local ra = Angle(0, o.renderYaw or o.yaw, 0)
          ply:ManipulateBonePosition(o.pelvis, vector_origin)
          ply:InvalidateBoneCache()
          ply:SetupBones()
          local pm = ply:GetBoneMatrix(o.pelvis)
          if pm then
               local istenen = eyer + Vector(0, 0, Y.BinekPoz.pelvisUst or 0)
               local yerel = WorldToLocal(istenen - pm:GetTranslation(), angle_zero, vector_origin, ra)
               if yerel:Length() > 160 then yerel = yerel:GetNormalized() * 160 end
               o.kaydir = yerel
               ply:ManipulateBonePosition(o.pelvis, yerel)
          end
          ply:InvalidateBoneCache()
     end
end

hook.Add("PrePlayerDraw", "SardonYaratik.Binek", function(ply)
     local kod = ply:GetNW2String("SYBinek", "")
     local o = binekler[ply]
     if kod == "" then
          if o then
               if IsValid(o.mdl) then o.mdl:Remove() end
               binekler[ply] = nil
               KemikPoz(ply, false)
               PelvisSifirla(ply)
          end
          return
     end
     if not o or o.kod ~= kod or not IsValid(o.mdl) then
          o = Kur(ply, kod)
          if not o then return end
          KemikPoz(ply, true)
     end

     -- Oyuncu bir karede birden çok kez çizilebilir (gölge, yansıma, ikinci kameralar). Durum
     -- (animasyon karesi, yumuşatmalar, binici kaydırması) karede bir kez ilerler, model her çizimde
     -- aynı pozla çizilir; yoksa animasyon çizim sayısı kadar hızlı oynuyordu.
     local kare = FrameNumber()
     if o.kare ~= kare then
          o.kare = kare
          Guncelle(ply, o)
     end
     if not o.gorunmez then o.mdl:DrawModel() end
end)

timer.Create("SardonYaratik.BinekTemizle", 5, 0, function()
     local simdi = RealTime()
     for ply, o in pairs(binekler) do
          if not IsValid(ply) or simdi - o.son > 10 then
               if IsValid(o.mdl) then o.mdl:Remove() end
               binekler[ply] = nil
               if IsValid(ply) then
                    KemikPoz(ply, false)
                    PelvisSifirla(ply)
               end
          end
     end
end)

function Y.BinekGorsel(ply)
     return binekler[ply]
end

------------------------------------------------------------------------ kamera

-- Helix thirdperson eklentisinin CalcView'i normal kancalardan önce çalışır; binerken
-- CanOverrideView false döner (eklenti kendiliğinden çekilir), inince eski hâli sürer.
local meta = FindMetaTable("Player")
local function TPSar()
     if not meta.CanOverrideView or meta.CanOverrideView == meta.SardonYaratikCOV then return end
     local asil = meta.CanOverrideView
     meta.SardonYaratikCOV = function(self, ...)
          if Y.Biniyor(self) then return false end
          return asil(self, ...)
     end
     meta.CanOverrideView = meta.SardonYaratikCOV
end
TPSar()
timer.Create("SardonYaratik.BinekTP", 5, 0, TPSar)

local kam = {mesafe = 200, fov = nil, roll = 0}
local IZ_KUTU = Vector(8, 8, 8)

local function IzFiltre(ent)
     return not (ent:IsPlayer() or ent:IsNPC() or ent:IsWeapon() or ent.IsSardonYaratik)
end

hook.Add("CalcView", "SardonYaratik.BinekKamera", function(ply, pos, ang, fov)
     if ply ~= LocalPlayer() or not Y.Biniyor(ply) or not ply:Alive() or ply:GetViewEntity() ~= ply then
          kam.fov = nil
          kam.gercek = nil
          kam.z = nil
          return
     end
     local w = Y.BinekSilah(ply)
     local b = w and Y.Binekler[w:GetTur()]
     if not b then return end

     local ft = math.min(FrameTime(), 0.1)
     local hiz = ply:GetVelocity():Length()
     local ucuyor = w:GetUcuyor()
     local hedefMesafe = b.hull * 4 + 150 + (ucuyor and 60 or 0) + math.Clamp(hiz - 300, 0, 1000) * 0.08
     kam.mesafe = Lerp(math.min(ft * 4, 1), kam.mesafe, hedefMesafe)

     local hedefFov = fov + math.Clamp((hiz - 450) / 900, 0, 1) * 18
     kam.fov = Lerp(math.min(ft * 3, 1), kam.fov or fov, hedefFov)

     local o = binekler[ply]
     kam.roll = Lerp(math.min(ft * 4, 1), kam.roll, (ucuyor and o) and o.bank * 0.18 or 0)

     -- bakış noktası binicinin başı hizasında; yerde basamak / yokuşta yükseklik yumuşatılır
     -- (tick 16'da basamağa çıkış tek tick'te olur, kamera sıçramasın)
     local merkez = ply:GetPos() + Vector(0, 0, b.goz)
     if not ucuyor and ply:IsOnGround() and kam.z and math.abs(kam.z - merkez.z) < 64 then
          kam.z = Lerp(1 - math.exp(-ft * 10), kam.z, merkez.z)
          merkez.z = kam.z
     else
          kam.z = merkez.z
     end
     local yon = (-ang:Forward() + ang:Up() * 0.1):GetNormalized()
     local hedef = merkez + yon * kam.mesafe
     local tr = util.TraceHull({start = merkez, endpos = hedef, mins = -IZ_KUTU, maxs = IZ_KUTU, filter = IzFiltre, mask = MASK_SOLID})
     -- duvar yaklaşınca kamera hemen içeri gelir (içinden geçmesin), açılırken yavaşça geri çekilir
     local izin = tr.HitPos:Distance(merkez)
     if not kam.gercek or izin < kam.gercek then
          kam.gercek = izin
     else
          kam.gercek = Lerp(math.min(ft * 2.5, 1), kam.gercek, izin)
     end
     return {origin = merkez + yon * kam.gercek, angles = Angle(ang.p, ang.y, kam.roll), fov = kam.fov, drawviewer = true}
end)

hook.Add("ShouldDrawLocalPlayer", "SardonYaratik.Binek", function(ply)
     if Y.Biniyor(ply) and ply:Alive() then return true end
end)

------------------------------------------------------------------------ G tuşu (komutta IN_GRENADE1)

local function InTusu()
     if SardonConfig and SardonConfig.Options and SardonConfig.Options.binek_in then
          return SardonConfig:Get("binek_in")
     end
     return KEY_G
end
Y.BinekInTusu = InTusu

hook.Add("CreateMove", "SardonYaratik.Binek", function(cmd)
     local ply = LocalPlayer()
     if not Y.Biniyor(ply) then return end
     if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or ply:IsTyping() then return end
     if input.IsKeyDown(InTusu()) then cmd:AddKey(Y.IN_BINEK_IN) end
end)

------------------------------------------------------------------------ biniş durumu (yerel)

local oncekiKod = ""
local ruzgar

hook.Add("Think", "SardonYaratik.BinekYerel", function()
     local ply = LocalPlayer()
     if not IsValid(ply) then return end
     local kod = ply:GetNW2String("SYBinek", "")
     if kod ~= oncekiKod then
          local indi = kod == ""
          oncekiKod = kod
          if indi then
               -- Helix thirdperson kamerası binişten önceki açıda kalmasın
               ply.camAng = ply:EyeAngles()
               ply.YB_Rota = nil
               if Y.BinekIndi then Y.BinekIndi() end
          elseif Y.BinekBindi then
               Y.BinekBindi(kod)
          end
     end

     -- rüzgâr sesi hızla artar
     local w = kod ~= "" and Y.BinekSilah(ply)
     local hiz = w and w:GetUcuyor() and ply:GetVelocity():Length() or 0
     if hiz > 250 then
          if not ruzgar then
               ruzgar = CreateSound(ply, "vehicles/fast_windloop1.wav")
               ruzgar:PlayEx(0, 100)
          end
          ruzgar:ChangeVolume(math.Clamp((hiz - 250) / 1000, 0, 0.65), 0.2)
          ruzgar:ChangePitch(math.Clamp(80 + hiz / 30, 80, 125), 0.2)
     elseif ruzgar then
          ruzgar:ChangeVolume(0, 0.4)
          if hiz == 0 and not w then
               ruzgar:Stop()
               ruzgar = nil
          end
     end
end)

------------------------------------------------------------------------ ağ

function Y.YonDuygusuIste()
     net.Start(Y.NET.BINEK)
          net.WriteString("yon_liste")
     net.SendToServer()
end

function Y.YonDuygusuSec(ad)
     net.Start(Y.NET.BINEK)
          net.WriteString("yon_sec")
          net.WriteString(ad)
     net.SendToServer()
end

local OLAY = {}

OLAY.kalkis = function(ply, p)
     Y.Duman(p + Vector(0, 0, 6), Color(150, 140, 120), 10, 16)
     Y.Kivilcim(p + Vector(0, 0, 30), Color(235, 230, 215), 10, 120, 1.4, 2.5, 30)
end
OLAY.kondu = function(ply, p)
     Y.Duman(p + Vector(0, 0, 4), Color(150, 140, 120), 6, 12)
end
OLAY.sert = function(ply, p)
     Y.Duman(p + Vector(0, 0, 4), Color(140, 130, 110), 16, 18)
end
OLAY.bin = function(ply, p)
     Y.Kivilcim(p + Vector(0, 0, 50), Y.R.soluk, 18, 60, 1.2, 3, 30)
end
OLAY.bayildi = function(ply, p)
     Y.Duman(p + Vector(0, 0, 30), Color(70, 70, 80), 14, 18)
     Y.Kivilcim(p + Vector(0, 0, 40), Color(180, 190, 220), 16, 40, 1.6, 2.5, 20)
end
OLAY.vurus = function(ply, p)
     for i = 0, 15 do
          local a = i / 16 * math.pi * 2
          Y.Duman(p + Vector(math.cos(a) * 60, math.sin(a) * 60, 6), Color(130, 115, 95), 1, 22)
     end
end
OLAY.carpti = function(ply, p)
     Y.Duman(p + Vector(0, 0, 30), Color(130, 115, 95), 6, 14)
end
OLAY.isinla = function(ply, p)
     Y.Duman(p + Vector(0, 0, 50), Color(40, 40, 50), 18, 26)
     Y.Kivilcim(p + Vector(0, 0, 60), Color(160, 170, 210), 24, 140, 0.9, 3, 20)
     sound.Play("ambient/energy/whiteflash.wav", p, 70, 140, 0.4)
end
OLAY.sekme = function(ply, p)
     Y.Kivilcim(p, Color(150, 200, 255), 20, 160, 0.6, 2.5, 10)
end
OLAY.ciglik = function() end

net.Receive(Y.NET.BINEK, function()
     local op = net.ReadString()
     local ply = LocalPlayer()
     if op == "rota" then
          local ad = net.ReadString()
          local n = net.ReadUInt(9)
          local rota = {}
          for i = 1, n do
               rota[i] = {p = net.ReadVector(), isinla = net.ReadBool() or nil, dar = net.ReadBool() or nil}
          end
          ply.YB_Rota = rota
          Y.BinekOtoAd = ad
     elseif op == "rota_sil" then
          ply.YB_Rota = nil
          Y.BinekOtoAd = nil
     elseif op == "yon_liste" then
          local n = net.ReadUInt(10)
          local liste = {}
          for i = 1, n do liste[i] = {ad = net.ReadString(), d = net.ReadUInt(20)} end
          if Y.YonDuygusuAc then Y.YonDuygusuAc(liste) end
     elseif op == "olay" then
          local ad = net.ReadString()
          local kim = net.ReadEntity()
          local p = net.ReadVector()
          local deger = net.ReadFloat()
          -- görmeyenler Thestral'in olay efektlerini de görmez (binicinin kendi olayları hariç)
          local f = OLAY[ad]
          if f then f(kim, p, deger) end
          if Y.BinekOlayHUD then Y.BinekOlayHUD(kim, ad, p, deger) end
     end
end)

