-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\_sh_6binek.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: binek — ayarlar ve tahminli hareket (iki tarafta da çalışır)
--
-- Binen oyuncunun kendisi bineğin gövdesidir: hull yaratığın boyuna büyür; yaratık modeli istemcide
-- oyuncunun altına çizilir, binici sırt kemiğine oturtulur (cl_binek_1ciz.lua). Hareket oyuncunun
-- kendi tahmin edilen hareketi: tick 16'da sunucu fiziğiyle sürülen süpürgedeki gecikme olmaz.
--   * Kara: hız ve yön SetupMove'da kademeli sürülür (ivme / fren / dönüş yayı); adım, basamak ve
--     çarpışma motorun yürüyüşü (Walk/Run hızı binerken tavana çekilir).
--   * Hava: kendi Move'umuz (true döner, motor hareketi atlanır); çarpışma TraceHull ile.
--   * Su: yine kendi Move'umuz; gövde su çizgisinde yüzer (motorun yüzmesi biniciyi dibe çekerdi).
-- Değişen bütün durum "sardon_binek" silahının ağ değişkenlerinde (tahmin edilir); hangi yaratığa
-- binildiği oyuncunun NW2 "SYBinek" dizgisinde (herkes çizsin diye).
--
-- Uçuş enerji modeli: hız, uçuş yönündeki yerçekimi bileşeniyle değişir ve hedef hıza döner (W ile
-- seyir, tuşsuz süzülme hızı). Pike hız kazandırır, burnu kaldırmak hızı irtifaya çevirir. W itiş,
-- SPACE kanat çırpışı (ikisi de kanat gücü harcar); tuş yoksa hafifçe alçalarak süzülür. Tutunma
-- hızının altında burun yavaşça düşer.

-- 11-13 opt (kodmod): kare başı kurulan sabitler dosya yereline alındı
local OPT_V_0_0_2 = Vector(0, 0, 2)
local OPT_V_0_0_40 = Vector(0, 0, 40)
local OPT_V_0_0_8 = Vector(0, 0, 8)
local OPT_V_0_0_1 = Vector(0, 0, 1)
local OPT_V_0_0_4 = Vector(0, 0, 4)
local OPT_V_0_0_20 = Vector(0, 0, 20)
local Y = SardonYaratik
local band = bit.band

Y.SILAH_BINEK = "sardon_binek"
-- G (İn) tuşu kullanıcı komutunda bu bitle taşınır: tahmin edilir, ağ mesajı gerekmez
Y.IN_BINEK_IN = IN_GRENADE1

Y.Binekler = Y.Binekler or {}
table.Empty(Y.Binekler)
table.Merge(Y.Binekler, {
     hippogriff = {
          hull = 30, boy = 100, goz = 104, adim = 26,
          -- yürü / dörtnal / geri (birim/sn); ivme, fren (dörtnaldan yürüyüşe), dur (birim/sn²); dönüş
          -- derece/sn. Yürüme 95: modelin yürüme animasyonu ~65'te adım atıyor, daha hızlısı koşuşturur.
          kara = {yuru = 95, kos = 380, geri = 70, ivme = 330, fren = 400, dur = 560, donus = 200, donusKos = 140},
          ucar = true,
          hava = {
               seyir = 580,      -- W ile ulaşılan hız
               tavan = 1400,     -- dikey pikede varılan hız
               asgari = 240,     -- tutunma hızı
               itis = 320,       -- W ivmesi
               suzulus = 450,    -- tuşsuz süzülme hızı (hafifçe alçalarak korunur)
               donus = 105,      -- derece/sn
               pikeAci = 55,
               konma = 380,      -- bu hızın altında yere yaklaşınca kendiliğinden konar
               cirpis = {hiz = 175, yukari = 0.32, maliyet = 12, aralik = 0.5},
               kalkis = {sure = 0.45, hiz = 320, yukari = 440, maliyet = 16},
          },
          -- suda gövde yüzeyin derin kadar altında yüzer (hull ortasının, boy/2, altında kalmalı: motor
          -- suyu ancak orada fark eder); hızlar birim/sn, dönüş derece/sn
          yuzme = {derin = 46, hiz = 110, hizli = 170, geri = 40, ivme = 150, dur = 170, donus = 110},
          kanat = 100, can = 600,
          eyer = {kemik = "staylofft_spine03", ileri = 4, ust = 8},
          ses = {
               ciglik = {{"npc/crow/alert3.wav", 58}, {"ambient/creatures/seagull_pain1.wav", 74}},
               cirpis = {"npc/crow/hop1.wav", 48},
               konma = {"npc/antlion/land1.wav", 85},
          },
          ciglikBekleme = 10,
          giris = "KANATLAR AÇILIYOR",
     },
     thestral = {
          hull = 30, boy = 104, goz = 108, adim = 26,
          kara = {yuru = 100, kos = 400, geri = 70, ivme = 340, fren = 400, dur = 560, donus = 200, donusKos = 145},
          ucar = true, otopilot = true, gorunmez = true,
          hava = {
               seyir = 620, tavan = 1450, asgari = 230, itis = 340, suzulus = 480, donus = 110, pikeAci = 55, konma = 380,
               cirpis = {hiz = 185, yukari = 0.32, maliyet = 11, aralik = 0.5},
               kalkis = {sure = 0.4, hiz = 330, yukari = 450, maliyet = 14},
               oto = 640,        -- Yön Duygusu seyir hızı
          },
          yuzme = {derin = 48, hiz = 110, hizli = 170, geri = 40, ivme = 150, dur = 170, donus = 110},
          kanat = 130, can = 500,
          eyer = {kemik = "staylofft_spine03", ileri = 4, ust = 8},
          ses = {
               ciglik = {{"npc/stalker/go_alert2a.wav", 70}},
               cirpis = {"npc/crow/hop1.wav", 40},
               adim = {"npc/dog/dog_footstep_run1.wav", 66},
               konma = {"npc/antlion/land1.wav", 75},
          },
          ciglikBekleme = 10,
          giris = "GÖLGELER KANATLANIYOR",
     },
     graphorn = {
          hull = 46, boy = 150, goz = 140, adim = 34,
          kara = {yuru = 130, kos = 360, geri = 70, ivme = 240, fren = 320, dur = 460, donus = 160, donusKos = 100},
          ucar = false,
          yuzme = {derin = 70, hiz = 90, hizli = 130, geri = 30, ivme = 110, dur = 150, donus = 70},
          kanat = 0, can = 1500,
          sekme = 0.4,      -- gelen büyülerin bu kadarı sırtından seker
          hucum = {hiz = 660, sure = 2.5, bekleme = 14, donus = 45, itme = 560, hasar = 12, kirma = 120},
          yereVur = {yaricap = 320, bekleme = 16, itme = 420, hasar = 8},
          eyer = {kemik = "staylofft_spine03", ileri = 0, ust = 12},
          ses = {
               ciglik = {{"npc/antlion_guard/angry1.wav", 82}},
               adim = {"npc/antlion_guard/foot_heavy1.wav", 90},
               hucum = {"npc/antlion_guard/angry2.wav", 90},
               vurus = {"npc/antlion_guard/shove1.wav", 80},
          },
          ciglikBekleme = 8,
          giris = "TOPRAK TİTRİYOR",
     },
})

-- Binicinin pozu: ilk bulunan sekans (broom ile aynı aile); bacaklar sırtın iki yanına açılır.
Y.BinekPoz = {
     sekans = {"sit_rollercoaster", "drive_airboat", "drive_jeep", "sit"},
     pelvisUst = 16, -- leğen kemiği eyer noktasının bu kadar üstünde
     kemik = {
          ["ValveBiped.Bip01_L_Thigh"] = Angle(-18, 0, -8),
          ["ValveBiped.Bip01_R_Thigh"] = Angle(18, 0, -8),
          ["ValveBiped.Bip01_L_Calf"] = Angle(0, 0, 20),
          ["ValveBiped.Bip01_R_Calf"] = Angle(0, 0, 20),
     },
}

------------------------------------------------------------------------ yardımcılar

function Y.BinekVeri(turId)
     return Y.Binekler[turId]
end

-- binilmişse bineğin silahı (durum burada), değilse nil
function Y.BinekSilah(ply)
     if not IsValid(ply) or not ply.GetActiveWeapon then return end
     local w = ply:GetActiveWeapon()
     if IsValid(w) and w:GetClass() == Y.SILAH_BINEK and w.GetTur and w:GetTur() ~= "" then return w end
end

function Y.Biniyor(ply)
     return IsValid(ply) and ply:GetNW2String("SYBinek", "") ~= ""
end

function Y.BinekKod(k)
     return table.concat({k.id, k.tur, Y.RenkBG(k), k.nadir or 1, k.evre or 3}, "|")
end

-- "id|tur|bg|nadir|evre"
function Y.BinekKodCoz(kod)
     local p = string.Explode("|", kod or "")
     return tonumber(p[1]), p[2], tonumber(p[3]) or 0, tonumber(p[4]) or 1, tonumber(p[5]) or 3
end

local function NadirHiz(w)
     local n = Y.Nadirlik[w:GetNadir()]
     return n and n.binekHiz or 1
end
Y.BinekNadirHiz = NadirHiz

-- bağa göre tepki (0.55 .. 1): bağı zayıf binek komutlara geç ve kararsız uyar
local function Tepki(w)
     return 0.55 + 0.45 * math.Clamp(w:GetBag() / 80, 0, 1)
end
Y.BinekTepki = Tepki

function Y.BinekKanatMax(b, binicilik)
     return (b.kanat or 0) * (1 + 0.08 * (binicilik or 0)) -- [11-09] Binicilik artık 2 kademe
end

-- Tahmin edilen kodda ses: sunucu sahibine göndermez (SuppressHostEvents), istemci kendisi çalar
local function Ses(ply, s, seviye, sapma)
     if not s then return end
     if SERVER or IsFirstTimePredicted() then
          ply:EmitSound(s[1], seviye or 80, (s[2] or 100) + math.random(-(sapma or 4), sapma or 4))
     end
end
Y.BinekSes = Ses

local function Rastgele(liste)
     return liste and liste[math.random(#liste)]
end
Y.BinekSesSec = Rastgele

------------------------------------------------------------------------ hull

-- SetHull ağdan gitmez: iki tarafta aynı anda uygulanır. Eski değerler (Engorgio gibi ölçekler)
-- saklanır, inince geri konur.
local function HullEsitle(ply, b)
     if b then
          if ply.YB_Hull == b then
               local _, maxs = ply:GetHull()
               if maxs.z == b.boy then return end
          end
          if not ply.YB_HullEski then
               local a1, a2 = ply:GetHull()
               local c1, c2 = ply:GetHullDuck()
               ply.YB_HullEski = {a1, a2, c1, c2, ply:GetStepSize()}
          end
          local mins, maxs = Vector(-b.hull, -b.hull, 0), Vector(b.hull, b.hull, b.boy)
          ply:SetHull(mins, maxs)
          ply:SetHullDuck(mins, maxs)
          ply:SetStepSize(b.adim or 24)
          ply.YB_Hull = b
     elseif ply.YB_Hull then
          local e = ply.YB_HullEski
          if e then
               ply:SetHull(e[1], e[2])
               ply:SetHullDuck(e[3], e[4])
               ply:SetStepSize(e[5])
          else
               ply:ResetHull()
          end
          ply.YB_Hull, ply.YB_HullEski = nil, nil
     end
end
Y.BinekHullEsitle = HullEsitle

-- kalkış için üstte yer var mı
local function TavanAcik(ply, pos, pay)
     local mins, maxs = ply:GetHull()
     local tr = util.TraceHull({
          start = pos + OPT_V_0_0_2, endpos = pos + Vector(0, 0, pay or 150),
          mins = mins, maxs = maxs, mask = MASK_PLAYERSOLID_BRUSHONLY, filter = ply,
     })
     return not tr.Hit and not tr.StartSolid
end
Y.BinekTavanAcik = TavanAcik

------------------------------------------------------------------------ yer: hız ve tuşlar

hook.Add("SetupMove", "SardonYaratik.Binek", function(ply, mv, cmd)
     local w = Y.BinekSilah(ply)
     local b = w and Y.Binekler[w:GetTur()]
     HullEsitle(ply, b)
     if not b then return end

     -- Tuşlar silinmez (bir sonraki tick'in "eski tuşları" bozulur, yeni basış algılanmaz). Motor
     -- zıplaması binerken sıfır güçle, çömelme hull'u ayakta hull'la aynı, çömelme hızı 1.
     local tus = mv:GetButtons()
     local eski = mv:GetOldButtons()
     ply.YB_Serbest = band(tus, IN_WALK) ~= 0
     if w:GetUcuyor() then return end

     local now, dt = CurTime(), FrameTime()
     local carpan = NadirHiz(w)
     local k = b.kara
     local ileri = band(tus, IN_FORWARD) ~= 0
     local geri = band(tus, IN_BACK) ~= 0 and not ileri
     local bakis = mv:GetAngles().y
     local ileriH, yanH = mv:GetForwardSpeed(), mv:GetSideSpeed()
     local tusVar = ileriH ~= 0 or yanH ~= 0

     local hc = b.hucum
     local hucumda = false
     if hc and ply:IsOnGround() then
          hucumda = now < w:GetHucumBas() + hc.sure
          if not hucumda and band(tus, IN_SPEED) ~= 0 and band(eski, IN_SPEED) == 0 and ileri and now >= w:GetHucumHazir() then
               w:SetHucumBas(now)
               w:SetHucumHazir(now + hc.sure + hc.bekleme)
               w:SetHucumYaw(bakis)
               Ses(ply, b.ses.hucum, 90)
               hucumda = true
          end
          -- hücumda gövde başlangıç yönünde ilerler, bakışa yavaşça döner
          if hucumda then w:SetHucumYaw(math.ApproachAngle(w:GetHucumYaw(), bakis, hc.donus * dt)) end
     end

     local v = mv:GetVelocity()
     local s = math.sqrt(v.x * v.x + v.y * v.y)

     -- suda motorun yüzmesi; uçmadan havadayken (düşerken) momentum korunur, yönlendirme yok
     if ply:WaterLevel() >= 2 then
          local hiz = (tusVar and k.yuru or 1) * carpan
          mv:SetMaxClientSpeed(hiz)
          mv:SetMaxSpeed(hiz)
          return
     end
     if not ply:IsOnGround() then
          mv:SetForwardSpeed(0)
          mv:SetSideSpeed(0)
          mv:SetMaxClientSpeed(math.max(s, 1))
          mv:SetMaxSpeed(math.max(s, 1))
          return
     end

     -- Yürüyüş: hız ve yön burada sürülür, motor yalnız adım / basamak / çarpışmayı yapar. Binek bir
     -- anda hızlanmaz, durmaz ya da yana kaymaz: hız kara.ivme / fren / dur ile değişir, hareket yönü
     -- saniyede en çok kara.donus (dörtnalda donusKos) derece döner.
     local hedefHiz = 0
     if hucumda then
          hedefHiz = hc.hiz
     elseif tusVar then
          hedefHiz = geri and k.geri or ((ileri and band(tus, IN_SPEED) ~= 0) and k.kos or k.yuru)
     end
     hedefHiz = hedefHiz * carpan

     local simdiki = s > 1 and math.deg(math.atan2(v.y, v.x)) or bakis
     local yon = simdiki
     if hucumda then
          yon = w:GetHucumYaw()
     elseif tusVar then
          local istek = bakis + math.deg(math.atan2(-yanH, ileriH))
          local fark = math.AngleDifference(istek, simdiki)
          if s < 45 then
               yon = istek
          elseif geri and math.abs(fark) > 100 then
               -- ileri giderken geri: önce durur
               hedefHiz = 0
          else
               local enCok = Lerp(math.Clamp(s / (k.kos * carpan), 0, 1), k.donus, k.donusKos) * dt
               yon = simdiki + math.Clamp(fark, -enCok, enCok)
          end
     end

     local oran = k.ivme
     if hedefHiz < s then oran = hedefHiz <= 0 and k.dur or k.fren end
     if hucumda then oran = oran * 3 end
     if now < w:GetSendele() then
          hedefHiz, oran, yon = 0, k.dur * 1.5, simdiki
     end
     local yeni = math.Approach(s, hedefHiz, oran * dt)

     -- Motor bu tick sürtünmeyle hızı düşürüp aynı yöndeki istekle geri ivmeler (sv_accelerate >
     -- sv_friction olduğu sürece sonuç tam "yeni" olur).
     local r = math.rad(yon)
     mv:SetVelocity(Vector(math.cos(r) * yeni, math.sin(r) * yeni, v.z))
     local d = math.rad(math.AngleDifference(yon, bakis))
     mv:SetForwardSpeed(yeni * math.cos(d))
     mv:SetSideSpeed(-yeni * math.sin(d))
     mv:SetMaxClientSpeed(math.max(yeni, 1))
     mv:SetMaxSpeed(math.max(yeni, 1))
end)

------------------------------------------------------------------------ hava

local function Dondur(a, b, enCok)
     local d = math.Clamp(a:Dot(b), -1, 1)
     local aci = math.acos(d)
     if aci <= enCok or aci < 1e-4 then return Vector(b.x, b.y, b.z) end
     local s = math.sin(aci)
     if s < 1e-3 then
          local v = Vector(a.x, a.y, a.z)
          v:Rotate(Angle(0, math.deg(enCok), 0))
          return v
     end
     local t = enCok / aci
     local v = a * (math.sin((1 - t) * aci) / s) + b * (math.sin(t * aci) / s)
     v:Normalize()
     return v
end

local function SudaMi(pos)
     local tr = util.TraceLine({start = pos + OPT_V_0_0_40, endpos = pos + OPT_V_0_0_8, mask = MASK_WATER})
     return tr.Hit or tr.StartSolid
end

-- iniş: hızlı/dik çarparsa sert iniş (sendeler, binek hasar alır)
local function Kon(ply, mv, w, b, p, vel, carpma, now)
     w:SetUcuyor(false)
     w:SetPike(false)
     w:SetItis(false)
     local sert = carpma > 520 or vel:Length() > 1100
     local yatay = Vector(vel.x, vel.y, 0) * (sert and 0.2 or 0.55)
     mv:SetOrigin(p)
     mv:SetVelocity(yatay)
     ply:SetGroundEntity(game.GetWorld())
     w:SetInisT(now)
     if sert then
          w:SetSendele(now + 1.1)
          Ses(ply, {"physics/body/body_medium_impact_hard1.wav", 80}, 80)
     end
     Ses(ply, b.ses.konma, 75)

     if w:GetOtopilot() then w:SetOtopilot(false) end
     if SERVER and Y.BinekKondu then Y.BinekKondu(ply, w, sert, carpma) end
     return true
end

-- Yön Duygusu: sıradaki rota noktası (portal noktasına varınca ışınlanır)
local function OtoHedef(ply, w, pos)
     local rota = ply.YB_Rota
     local i = w:GetRotaNo()
     local nokta = rota and rota[i]
     if not nokta then return end

     local fark = nokta.p - pos
     local yatay = Vector(fark.x, fark.y, 0):Length()
     local son = i >= #rota
     local yakin = son and 60 or (nokta.dar and 90 or 170)
     if fark:Length() < yakin or (not son and yatay < yakin * 0.6 and math.abs(fark.z) < 160) then
          i = i + 1
          w:SetRotaNo(i)
          nokta = rota[i]
          if not nokta then return end
          if nokta.isinla then
               -- cisimlenme: bir sonraki bölgeye geç
               if SERVER and Y.BinekIsinlandi then Y.BinekIsinlandi(ply, pos, nokta.p) end
               w:SetRotaNo(i + 1)
               return nokta, true
          end
          fark = nokta.p - pos
     end
     return nokta, false
end

local function Ucus(ply, mv, w, b, tus, eski, now, dt)
     local h = b.hava
     local function Bas(k) return band(tus, k) ~= 0 end
     local function YeniBas(k) return band(tus, k) ~= 0 and band(eski, k) == 0 end

     local pos = mv:GetOrigin()
     local vel = mv:GetVelocity()
     local V = vel:Length()
     local ang = mv:GetAngles()
     local yon = V > 1 and (vel / V) or Angle(0, ang.y, 0):Forward()
     local carpan = NadirHiz(w)
     local seyir, tavan, asgari = h.seyir * carpan, h.tavan * carpan, h.asgari
     local tepki = Tepki(w)
     local kilitli = now < w:GetSendele()
     local enerji = w:GetEnerji()
     local enerjiMax = w:GetEnerjiMax()

     -- su: kanatlar ıslanır, yaratık yüzer (motor yürüyüşüne bırak)
     if SudaMi(pos) then
          w:SetUcuyor(false)
          w:SetPike(false)
          w:SetOtopilot(false)
          ply:SetGroundEntity(NULL)
          return
     end

     -- Yön Duygusu: herhangi bir hareket tuşu kontrolü geri verir
     local oto = w:GetOtopilot()
     if oto and (Bas(IN_FORWARD) or Bas(IN_BACK) or Bas(IN_MOVELEFT) or Bas(IN_MOVERIGHT) or YeniBas(IN_JUMP)
          or Bas(IN_DUCK) or YeniBas(IN_RELOAD) or YeniBas(Y.IN_BINEK_IN)) then
          w:SetOtopilot(false)
          oto = false
          if SERVER and Y.BinekOtoBitti then Y.BinekOtoBitti(ply, "birakti") end
     end

     -- G: spiralle alçal / vazgeç
     if not oto and YeniBas(Y.IN_BINEK_IN) then w:SetInis(not w:GetInis()) end
     local inis = w:GetInis() and not oto

     ------------------------------------------------------------ hedef yön
     local hedef
     local isinla
     if oto then
          local nokta
          nokta, isinla = OtoHedef(ply, w, pos)
          if not nokta then
               w:SetOtopilot(false)
               oto = false
               if SERVER and Y.BinekOtoBitti then Y.BinekOtoBitti(ply, "rota") end
          elseif isinla then
               mv:SetOrigin(nokta.p)
               mv:SetVelocity(yon * math.min(V, 300))
               ply:SetGroundEntity(NULL)
               return true
          else
               hedef = (nokta.p - pos):GetNormalized()
          end
     end
     if not hedef then
          if inis then
               -- sağa dönerek 20° alçal (dönüş hızı aşağıda 35°/sn'ye sınırlı: geniş sarmal)
               hedef = Angle(20, yon:Angle().y - 25, 0):Forward()
          elseif ply.YB_Serbest or kilitli then
               hedef = yon
          else
               local p = math.Clamp(math.NormalizeAngle(ang.p), -70, 75)
               if Bas(IN_DUCK) then p = math.max(p, h.pikeAci) end
               -- hız düştükçe tırmanış açısı daralır: tutunma hızında en çok yatay uçar
               local suz = (h.suzulus or seyir * 0.78) * carpan
               p = math.max(p, -70 * math.Clamp((V - asgari) / math.max(suz - asgari, 1), 0, 1))
               local y = ang.y
               -- zayıf bağ: komutlara kararsız uyar
               local bag = w:GetBag()
               if bag < 40 then y = y + math.sin(now * 1.7) * (40 - bag) * 0.3 end
               hedef = Angle(p, y, 0):Forward()
          end
          -- kanat çırpmadan süzülürken hafifçe alçalır (yükseklik hıza döner)
          if not inis and not Bas(IN_FORWARD) and not Bas(IN_DUCK) and now - w:GetCirpisT() > 0.8 then
               hedef.z = hedef.z - 0.07
               hedef:Normalize()
          end
          -- tutunma hızının altında burun yavaşça düşer; kanat gücü bitince tırmanamaz
          if V < asgari then
               local k = math.Clamp((asgari - V) / (asgari * 0.4), 0, 1)
               local ha = hedef:Angle()
               hedef = Angle(math.max(math.NormalizeAngle(ha.p), 25 * k), ha.y, 0):Forward()
          end
          if enerji <= 0 and hedef.z > -0.05 then
               hedef.z = -0.05
               hedef:Normalize()
          end
     end

     -- Engel sezme: önündeki duvara / yere hızla gidiyorsa yönü yüzey boyunca kaydırır; tam
     -- karşıdan geliyorsa burnunu kaldırıp üstünden aşmaya çalışır (yaratık bilerek çarpmaz).
     local mins, maxs = ply:GetHull()
     local kacis = false
     if not kilitli and V > 120 then
          local bak = math.Clamp(V * 0.55, 140, 700)
          local on = util.TraceHull({start = pos, endpos = pos + yon * bak, mins = mins, maxs = maxs, mask = MASK_PLAYERSOLID_BRUSHONLY, filter = ply})
          local n = on.Hit and not on.StartSolid and on.HitNormal
          -- yer: yavaşsa konar, spiral inişte iner, pikede (CTRL) oyuncu bilerek dalıyor
          if n and not (n.z > 0.65 and (V < h.konma * 1.3 or inis or Bas(IN_DUCK))) then
               local yakinlik = 1 - on.Fraction
               local teget = hedef - n * hedef:Dot(n)
               if teget:LengthSqr() < 0.04 then
                    -- kafa kafaya: yüzeyin yukarı yönüne (duvarsa tırman, yerse düzel)
                    teget = OPT_V_0_0_1 - n * n.z
                    if teget:LengthSqr() < 0.04 then teget = Angle(0, ang.y + 90, 0):Forward() end
               end
               teget:Normalize()
               if hedef:Dot(n) < 0 then
                    hedef = teget + n * yakinlik * 0.6
                    hedef:Normalize()
                    kacis = true
               end
          end
     end

     local donus = inis and 35 or (h.donus * tepki * (oto and 1.8 or 1) * (kilitli and 0.25 or 1) * (kacis and 1.6 or 1))
     yon = Dondur(yon, hedef, math.rad(donus) * dt)

     ------------------------------------------------------------ hız
     local pike = Bas(IN_DUCK) and not oto and not inis
     if w:GetPike() ~= pike then w:SetPike(pike) end
     local itis = false

     if oto then
          local nokta = ply.YB_Rota and ply.YB_Rota[w:GetRotaNo()]
          local hedefHiz = (h.oto or seyir) * carpan
          if nokta then
               local kalan = nokta.p:Distance(pos)
               if nokta.dar then hedefHiz = math.min(hedefHiz, 260) end
               if w:GetRotaNo() >= #ply.YB_Rota then hedefHiz = math.min(hedefHiz, 160 + kalan * 0.8) end
          end
          V = math.Approach(V, hedefHiz, 420 * dt)
          itis = V < hedefHiz - 20 or yon.z > 0.2
     else
          -- Yerçekimi bileşeni: tırmanış hız yer, dalış hız kazandırır; hava direnci az (pikede
          -- kanatlar kapalı, tavana dayanır). Tuşsuz süzülüş hafif alçalışla süzülme hızında dengelenir;
          -- dalıştan kalan fazla hız birkaç saniyede erir, tırmanışta hız düştükçe burun iner.
          local kG = pike and 1.15 or (yon.z > 0 and 0.9 or 0.6)
          V = V - 600 * kG * yon.z * dt
          local cD = pike and 2.6e-4 * (1400 / tavan) ^ 2 or 1.2e-4
          V = V - cD * V * V * dt
          if inis then V = math.Approach(V, math.max(asgari * 1.15, 300), 200 * dt) end

          local suz = (h.suzulus or seyir * 0.78) * carpan
          if Bas(IN_FORWARD) and not kilitli and enerji > 0 and not inis then
               itis = true
               if V < seyir then V = math.min(seyir, V + h.itis * dt) end
               enerji = enerji - 6 * dt
          end
          local ust = itis and seyir or suz
          if not pike and not inis and V > ust then V = V - ((V - ust) * 0.25 + 10) * dt end
          if Bas(IN_BACK) and not kilitli then V = math.max(asgari * 0.5, V - 300 * dt) end

          -- kanat çırpışı
          local c = h.cirpis
          if YeniBas(IN_JUMP) and not kilitli and not inis and now >= w:GetCirpisHazir() and enerji >= c.maliyet then
               V = V + c.hiz
               yon = yon + Vector(0, 0, c.yukari)
               yon:Normalize()
               enerji = enerji - c.maliyet
               w:SetCirpisT(now)
               w:SetCirpisHazir(now + c.aralik)
               Ses(ply, b.ses.cirpis, 72, 6)
          end
     end
     if not itis and now - w:GetCirpisT() > 0.6 then enerji = enerji + 5 * dt end
     enerji = math.Clamp(enerji, 0, enerjiMax)
     if enerji ~= w:GetEnerji() then w:SetEnerji(enerji) end
     if w:GetItis() ~= itis then w:SetItis(itis) end

     V = math.Clamp(V, 0, tavan * 1.05)
     vel = yon * V
     -- kanatlar taşımıyor: çöker
     if not oto and V < asgari then vel.z = vel.z - (1 - V / asgari) * 100 end

     ------------------------------------------------------------ hareket + çarpışma
     local iz = {mins = mins, maxs = maxs, mask = MASK_PLAYERSOLID_BRUSHONLY, filter = ply}
     local kalan = 1
     for _ = 1, 3 do
          iz.start, iz.endpos = pos, pos + vel * dt * kalan
          local tr = util.TraceHull(iz)
          if tr.StartSolid then
               -- sıkıştı: yukarı it
               pos = pos + OPT_V_0_0_4
               break
          end
          if not tr.Hit then
               pos = tr.HitPos
               break
          end

          local n = tr.HitNormal
          local carpma = -vel:Dot(n)
          if n.z > 0.65 then
               return Kon(ply, mv, w, b, tr.HitPos, vel, carpma, now)
          end
          -- duvar / tavan: yüzey boyunca kay; hız kaybı çarpma açısına göre (sıyırınca az, kafa
          -- kafaya çok). Sersemleme ve hasar yalnız sert, neredeyse dik çarpmada.
          pos = tr.HitPos + n * 0.25
          kalan = kalan * (1 - tr.Fraction)
          local hizOnce = vel:Length()
          local dik = math.Clamp(carpma / math.max(hizOnce, 1), 0, 1)
          vel = vel + n * carpma
          vel = vel * (1 - 0.45 * dik)
          if carpma > 620 and dik > 0.7 and not kilitli then
               w:SetSendele(now + 0.7)
               Ses(ply, {"physics/body/body_medium_impact_hard1.wav", 90}, 80)
               if SERVER and Y.BinekHasar then Y.BinekHasar(ply, (carpma - 620) * 0.3, "carpma") end
          end
          if kalan < 0.02 then break end
     end

     -- yere yakın ve yavaş: kendiliğinden kon (SPACE basılıyken konmaz)
     if not Bas(IN_JUMP) and vel.z <= 20 and (vel:Length() < h.konma or inis) then
          iz.start, iz.endpos = pos, pos - OPT_V_0_0_20
          local tr = util.TraceHull(iz)
          if tr.Hit and not tr.StartSolid and tr.HitNormal.z > 0.65 then
               return Kon(ply, mv, w, b, tr.HitPos, vel, -vel.z, now)
          end
     end

     mv:SetOrigin(pos)
     mv:SetVelocity(vel)
     ply:SetGroundEntity(NULL)
     return true
end

local function Kalk(ply, mv, w, b, now, oto)
     local k = b.hava.kalkis
     w:SetUcuyor(true)
     w:SetKalkisBas(-1)
     w:SetInis(false)
     w:SetCirpisT(now)
     w:SetCirpisHazir(now + b.hava.cirpis.aralik)
     if not oto then w:SetEnerji(math.max(0, w:GetEnerji() - k.maliyet)) end

     local ileri = Angle(0, mv:GetAngles().y, 0):Forward()
     local yatay = mv:GetVelocity()
     yatay.z = 0
     mv:SetVelocity(ileri * math.max(yatay:Length(), k.hiz) + Vector(0, 0, k.yukari))
     mv:SetOrigin(mv:GetOrigin() + OPT_V_0_0_2)
     ply:SetGroundEntity(NULL)
     Ses(ply, b.ses.cirpis, 80, 4)
     if SERVER and Y.BinekKalkti then Y.BinekKalkti(ply, w) end
     return true
end

------------------------------------------------------------------------ su

-- Suyun yüzeyi: pos'un en çok ust kadar üstüne uzanan su varsa yüzeyin z'si. Su dünya fırçası; iz
-- iki tarafta aynı sonucu verir (istemcide PointContents bu haritada güvenilmez).
local function SuYuzeyi(pos, ust)
     local tr = util.TraceLine({start = pos + Vector(0, 0, ust), endpos = pos - OPT_V_0_0_1, mask = MASK_WATER})
     if not tr.StartSolid then return tr.Hit and tr.HitPos.z or nil end
     -- başlangıç da suyun içinde (derine batmış): daha yukarıdan
     tr = util.TraceLine({start = pos + Vector(0, 0, ust + 800), endpos = pos, mask = MASK_WATER})
     if tr.StartSolid then return pos.z + ust + 800 end
     return tr.Hit and tr.HitPos.z or nil
end
Y.SuYuzeyi = SuYuzeyi

-- binek su çizgisine kadar suya girmişse yüzeyin z'si (yüzer), değilse nil
function Y.BinekSuda(pos, b)
     local y = b and b.yuzme
     if not y then return end
     local z = SuYuzeyi(pos, b.boy + 40)
     if z and z - pos.z >= y.derin - 0.5 then return z end
end

-- yüzerken kayma; önündeki dik engel adım kadar alçaksa (iskele basamağı) üstünden geçer, kıyının
-- yürünür eğiminde kayarak yükselir
local function YuzKaydir(pos, vel, dt, iz, adim)
     local kalan = 1
     for _ = 1, 3 do
          local yol = vel * (dt * kalan)
          iz.start, iz.endpos = pos, pos + yol
          local tr = util.TraceHull(iz)
          if tr.StartSolid then
               pos = pos + OPT_V_0_0_2
               break
          end
          if not tr.Hit then
               pos = tr.HitPos
               break
          end
          local n = tr.HitNormal
          if n.z < 0.7 then
               local ileri = Vector(yol.x, yol.y, 0) * (1 - tr.Fraction)
               iz.start, iz.endpos = tr.HitPos, tr.HitPos + Vector(0, 0, adim)
               local yuk = util.TraceHull(iz)
               iz.start, iz.endpos = yuk.HitPos, yuk.HitPos + ileri
               local on = util.TraceHull(iz)
               if not on.StartSolid and on.Fraction > 0.2 then
                    iz.start, iz.endpos = on.HitPos, on.HitPos - Vector(0, 0, adim + 2)
                    pos = util.TraceHull(iz).HitPos
                    break
               end
          end
          pos = tr.HitPos + n * 0.03
          vel = vel - n * vel:Dot(n)
          kalan = kalan * (1 - tr.Fraction)
          if kalan < 0.02 then break end
     end
     return pos, vel
end

-- Yüzüş: gövde yüzeyin yuzme.derin altında tutulur, hız ve yön yerdeki gibi kademeli değişir.
-- Kıyının eğimine varınca kayarak su çizgisinin üstüne çıkar; sonraki tick motor yürüyüşü devralır.
local function Yuzus(ply, mv, w, b, tus, yuzey, dt)
     local y = b.yuzme
     local function Bas(k) return band(tus, k) ~= 0 end
     local pos = mv:GetOrigin()
     local v = mv:GetVelocity()
     local s = math.sqrt(v.x * v.x + v.y * v.y)
     local bakis = mv:GetAngles().y

     local ileri = (Bas(IN_FORWARD) and 1 or 0) - (Bas(IN_BACK) and 1 or 0)
     local yan = (Bas(IN_MOVERIGHT) and 1 or 0) - (Bas(IN_MOVELEFT) and 1 or 0)
     local hedefHiz = 0
     local yon = s > 1 and math.deg(math.atan2(v.y, v.x)) or bakis
     if ileri ~= 0 or yan ~= 0 then
          hedefHiz = (ileri < 0 and yan == 0) and y.geri or (Bas(IN_SPEED) and y.hizli or y.hiz)
          local istek = bakis + math.deg(math.atan2(-yan, ileri))
          if s < 30 then
               yon = istek
          else
               local enCok = y.donus * Tepki(w) * dt
               yon = yon + math.Clamp(math.AngleDifference(istek, yon), -enCok, enCok)
          end
     end
     hedefHiz = hedefHiz * NadirHiz(w)
     -- uçuştan / dörtnaldan gelen fazla hızı su çabuk keser
     local oran = hedefHiz >= s and y.ivme or (y.dur + math.max(s - y.hizli, 0) * 3)
     local yeni = math.Approach(s, hedefHiz, oran * dt)

     -- kaldırma: su çizgisine yaylanır; yukarıdan düşüp girdiyse dikey hız birkaç tick'te söner
     local vz = math.Clamp((yuzey - y.derin - pos.z) * 5, -220, 160)
     vz = Lerp(math.min(dt * 6, 1), v.z, vz)

     local r = math.rad(yon)
     local vel = Vector(math.cos(r) * yeni, math.sin(r) * yeni, vz)
     local mins, maxs = ply:GetHull()
     pos, vel = YuzKaydir(pos, vel, dt, {mins = mins, maxs = maxs, mask = MASK_PLAYERSOLID_BRUSHONLY, filter = ply}, b.adim or 24)

     mv:SetOrigin(pos)
     mv:SetVelocity(vel)
     ply:SetGroundEntity(NULL)
     return true
end

hook.Add("Move", "SardonYaratik.Binek", function(ply, mv)
     local w = Y.BinekSilah(ply)
     if not w then return end
     local b = Y.Binekler[w:GetTur()]
     if not b or ply:GetMoveType() ~= MOVETYPE_WALK then return end

     local now, dt = CurTime(), FrameTime()
     local tus, eski = mv:GetButtons(), mv:GetOldButtons()

     if w:GetUcuyor() then
          return Ucus(ply, mv, w, b, tus, eski, now, dt)
     end

     local function Bas(k) return band(tus, k) ~= 0 end
     local function YeniBas(k) return band(tus, k) ~= 0 and band(eski, k) == 0 end
     local yerde = ply:IsOnGround()

     -- kanat gücü yerde hızlı dolar
     local emax = w:GetEnerjiMax()
     if emax > 0 and w:GetEnerji() < emax then w:SetEnerji(math.min(emax, w:GetEnerji() + 20 * dt)) end
     if w:GetInis() then w:SetInis(false) end

     -- G: in (sunucu yapar)
     if YeniBas(Y.IN_BINEK_IN) and SERVER and Y.BinekIn then
          Y.BinekIn(ply, "tus")
          return
     end

     -- su çizgisine kadar suya girdiyse yüzer
     local yuzey = Y.BinekSuda(mv:GetOrigin(), b)
     if yuzey then
          if w:GetKalkisBas() ~= 0 then w:SetKalkisBas(0) end
          return Yuzus(ply, mv, w, b, tus, yuzey, dt)
     end

     local kilitli = now < w:GetSendele()

     -- Graphorn: yere vur
     local yv = b.yereVur
     if yv and YeniBas(IN_JUMP) and yerde and not kilitli and now >= w:GetVurusHazir() then
          w:SetVurusT(now)
          w:SetVurusHazir(now + yv.bekleme)
          Ses(ply, b.ses.vurus, 90)
          if SERVER and Y.BinekYereVur then Y.BinekYereVur(ply, w, b) end
     end
     if b.hucum and SERVER and now < w:GetHucumBas() + b.hucum.sure and Y.BinekHucumDarbe then
          Y.BinekHucumDarbe(ply, w, b)
     end

     if not b.ucar then return end

     -- Yön Duygusu yerde başladıysa kendiliğinden havalanır
     if w:GetOtopilot() then
          if TavanAcik(ply, mv:GetOrigin()) then return Kalk(ply, mv, w, b, now, true) end
          w:SetOtopilot(false)
          if SERVER and Y.BinekOtoBitti then Y.BinekOtoBitti(ply, "tavan") end
          return
     end

     -- SPACE basılı tut: kalkış
     if Bas(IN_JUMP) and not kilitli then
          local bas = w:GetKalkisBas()
          if bas == 0 then
               w:SetKalkisBas(now)
          elseif bas > 0 and now - bas >= b.hava.kalkis.sure then
               w:SetKalkisBas(-1) -- bırakılana dek tekrar denenmez
               if w:GetBinicilik() < 1 then
                    if SERVER and Y.BinekUyar then Y.BinekUyar(ply, "binicilik") end
               elseif w:GetEnerji() < b.hava.kalkis.maliyet then
                    if SERVER and Y.BinekUyar then Y.BinekUyar(ply, "enerji") end
               elseif not TavanAcik(ply, mv:GetOrigin()) then
                    if SERVER and Y.BinekUyar then Y.BinekUyar(ply, "tavan") end
               else
                    return Kalk(ply, mv, w, b, now, false)
               end
          end
     elseif w:GetKalkisBas() ~= 0 then
          w:SetKalkisBas(0)
     end
end)

------------------------------------------------------------------------ binici animasyonu

local pozOnbellek = {}

function Y.BinekPozSekans(ply)
     local mdl = ply:GetModel()
     local s = pozOnbellek[mdl]
     if s then return s end
     for _, ad in ipairs(Y.BinekPoz.sekans) do
          local seq = ply:LookupSequence(ad)
          if seq and seq >= 0 then
               pozOnbellek[mdl] = seq
               return seq
          end
     end
     return -1
end

hook.Add("CalcMainActivity", "SardonYaratik.Binek", function(ply, vel)
     if not Y.Biniyor(ply) then return end
     local seq = Y.BinekPozSekans(ply)
     if seq >= 0 then return ACT_MP_STAND_IDLE, seq end
end)

hook.Add("UpdateAnimation", "SardonYaratik.Binek", function(ply, vel, maxHiz)
     if not Y.Biniyor(ply) then return end
     ply:SetPlaybackRate(1)
     if CLIENT and Y.BinekGovde then Y.BinekGovde(ply, vel) end
     return true
end)

-- düşme hasarı yok (iniş Kon'da)
hook.Add("OnPlayerHitGround", "SardonYaratik.Binek", function(ply)
     if Y.Biniyor(ply) then return true end
end)

-- toynak / pençe sesleri
hook.Add("PlayerFootstep", "SardonYaratik.Binek", function(ply, pos, ayak, ses, hacim, filtre)
     if not Y.Biniyor(ply) then return end
     local _, turId = Y.BinekKodCoz(ply:GetNW2String("SYBinek", ""))
     local b = Y.Binekler[turId]
     if b and b.ses.adim and (SERVER or IsFirstTimePredicted()) then
          local hizli = ply:GetVelocity():Length2DSqr() > 200 * 200
          ply:EmitSound(b.ses.adim[1], hizli and 74 or 66, b.ses.adim[2] + math.random(-6, 6), hizli and 0.8 or 0.5)
     end
     return true
end)

-- binekteyken silah değiştirilemez
hook.Add("PlayerSwitchWeapon", "SardonYaratik.Binek", function(ply, eski, yeni)
     if Y.Biniyor(ply) and IsValid(yeni) and yeni:GetClass() ~= Y.SILAH_BINEK then return true end
end)

-- gece mi (StormFox2 varsa onun saati); sunucuda sv_4beyin aynısını kullanır, istemcide omuz uykusu
if not Y.Gece then
     function Y.Gece()
          local sf = StormFox2 and StormFox2.Time
          if sf and sf.IsNight then
               local ok, v = pcall(sf.IsNight)
               if ok then return v end
          end
          local saat = tonumber(os.date("%H")) or 12
          return saat >= 23 or saat < 6
     end
end
