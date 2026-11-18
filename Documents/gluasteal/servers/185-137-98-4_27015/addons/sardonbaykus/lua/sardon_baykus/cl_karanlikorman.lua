-- "addons\\sardonbaykus\\lua\\sardon_baykus\\cl_karanlikorman.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Karanlık Orman: "izleniyorsun" atmosferi (eski düz siyah sisin yerine).
--
-- Sunucu (sv_baykus.lua) bölgeye girince fogReq NW bayrağını açar; Karanlık Taraf,
-- Snatcher'lar ve "Diğer" muaf. Buradaki her şey istemci tarafında ve kişiye özel:
-- kimse başkasının gördüğünü görmez, sesini duymaz. Gruptakiler "sen de duydun mu?"
-- diye sorduğunda cevap hep "hayır" olur.
--
-- Hepsini tek bir gizli değer yönetir: DİKKAT (0..1), yani ormanın seni ne kadar fark
-- ettiği. Yalnız olmak, kıpırdamadan durmak, Lumos yakmak, gece, ormanda uzun kalmak ve
-- yüksek Onur artırır; yakındaki her oyuncu düşürür.
--
--   * Yaşayan sis: rengini haritanın o noktadaki ışığından alır, nefes alır gibi açılıp
--     kapanır, dikkat arttıkça üstüne kapanır. Lumos sisi geri iter ama ışık sisi
--     aydınlatır ve dikkati çeker.
--   * Gözler: ağaç arkalarından bakan göz çiftleri, yalnızca göz ucuyla görülür.
--     Doğrudan bakınca kırpıp kaybolurlar, yaklaşınca çekilirler. Lumos ışığını yansıtırlar.
--   * Yankı adımlar: adımların arkandan, biraz gecikmeyle tekrarlanır. Durunca bazen
--     bir adım fazla atılır.
--   * Gölgen: arkanda, sisin sınırında kendi modelinin simsiyah, kıpırtısız bir kopyası.
--     Dönüp bakarsan bir an durur ve kaybolur. Bakmazsan her seferinde biraz yaklaşır.
--   * Orman susar: Gölge varken kuşlar ve çıtırtılar kesilir, yerine uğultu ve kalp
--     atışı gelir. Sessizliğin kendisi uyarıdır.
--   * Ani dönüş: hızla arkana dönersen orada bir şey yoktur, ama az önce baktığın,
--     şimdi sırtında kalan yerden bir dal kırılır.
--   * Kenar kararması, görmediğin en yakın gözlemcinin tarafına doğru ağırlaşır.

local LP = LocalPlayer
local CurTime, FrameTime = CurTime, FrameTime
local IsValid = IsValid
local math_Rand, math_random, math_Clamp, math_sin, math_deg, math_acos = math.Rand, math.random, math.Clamp, math.sin, math.deg, math.acos
local Lerp, Vector, Angle = Lerp, Vector, Angle

hook.Remove("Think", "darkforest")
hook.Remove("SetupWorldFog", "darkforest")

-- Dosya autorefresh ile yeniden yüklenince eski figür modelleri sahipsiz kalmasın
SardonKOModeller = SardonKOModeller or {}
for ent in pairs(SardonKOModeller) do
     if IsValid(ent) then ent:Remove() end
end
SardonKOModeller = {}

local function modelOlustur(mdl)
     local ent = ClientsideModel(mdl, RENDERGROUP_OPAQUE)
     if IsValid(ent) then
          ent:SetNoDraw(true)
          SardonKOModeller[ent] = true
     end
     return ent
end

local function modelSil(ent)
     if IsValid(ent) then ent:Remove() end
     SardonKOModeller[ent] = nil
end

---------------------------------------------------------------------------
-- Durum
---------------------------------------------------------------------------
local inten = 0          -- giriş/çıkış geçişi, 0..1 (4 sn)
local intenE = 0         -- yumuşatılmış hali
local dikkat = 0         -- ormanın seni fark etmesi, 0..1
local dikkatHedef = 0
local girisZamani = nil
local sonHareket = CurTime()
local lumosOverride = false
local sessizlik = 0      -- Gölge varken 1'e gider

local fogStart, fogEnd, fogEndHedef = 0, 11000, 900
local fogR, fogG, fogB = 0, 0, 0
local SIS_YOSUN = Vector(15, 21, 18)  -- turba/yosun, karanlıkta neredeyse siyah
local SIS_LUMOS = Vector(46, 54, 64)  -- Lumos ışığının sisi aydınlattığı soğuk ton
local sisIsik, sonIsikOlcum = 1, 0

net.Receive("lumosGlboal", function()
     lumosOverride = true
     timer.Remove("lumosGlobal")
     timer.Create("lumosGlobal", net.ReadUInt(8), 1, function()
          lumosOverride = false
     end)
end)

local function lumosAcik(lp)
     return lumosOverride or lp:GetNWBool("lumos", false)
end

local function aktif()
     return intenE > 0.01
end

-- Bakış: kare başına bir kez (Think'te) alınır. Render kancaları su yansıması gibi ek
-- görüntülerde de çağrılır; orada EyePos yansıma kamerasıdır, bu yüzden hep bunu kullan.
local kEye, kFwd = Vector(0, 0, 0), Vector(1, 0, 0)
local function bakisGuncelle()
     kEye = EyePos()
     kFwd = EyeAngles():Forward()
end

-- Bakış yönüyle hedef arasındaki açı (derece)
local function bakisAcisi(hedef)
     local d = hedef - kEye
     d:Normalize()
     return math_deg(math_acos(math_Clamp(kFwd:Dot(d), -1, 1)))
end

local function yerBul(p)
     local dn = util.TraceLine({start = p + Vector(0, 0, 60), endpos = p - Vector(0, 0, 400), mask = MASK_SOLID_BRUSHONLY})
     if not dn.Hit or dn.StartSolid then return end
     return dn.HitPos
end

local function gorunurMu(lp, hedef)
     local tr = util.TraceLine({start = EyePos(), endpos = hedef, mask = MASK_SOLID, filter = lp})
     return tr.Fraction > 0.97
end

---------------------------------------------------------------------------
-- Sesler (hepsi VPK'da doğrulandı)
---------------------------------------------------------------------------
local SES_KUS = {"npc/crow/idle1.wav", "npc/crow/idle2.wav", "npc/crow/idle3.wav", "npc/crow/idle4.wav", "npc/crow/alert2.wav", "npc/crow/alert3.wav", "ambient/animal/crow.wav", "ambient/animal/crow_1.wav", "ambient/animal/crow_2.wav"}
local SES_CITIRTI = {"ambient/materials/wood_creak1.wav", "ambient/materials/wood_creak2.wav", "ambient/materials/wood_creak3.wav", "ambient/materials/wood_creak4.wav", "ambient/materials/wood_creak5.wav", "ambient/materials/wood_creak6.wav"}
local SES_DAL = {"physics/wood/wood_plank_impact_soft1.wav", "physics/wood/wood_plank_impact_soft2.wav", "physics/wood/wood_plank_impact_soft3.wav", "physics/wood/wood_solid_impact_soft1.wav", "physics/wood/wood_solid_impact_soft2.wav"}
local SES_RUZGAR = "ambient/nature/wind_leaves_mild_gust_1.wav"
local SES_FISILTI = {"ambient/levels/citadel/strange_talk1.wav", "ambient/levels/citadel/strange_talk3.wav", "ambient/levels/citadel/strange_talk4.wav", "ambient/levels/citadel/strange_talk5.wav", "ambient/levels/citadel/strange_talk6.wav", "ambient/levels/citadel/strange_talk7.wav", "ambient/levels/citadel/strange_talk8.wav", "ambient/levels/citadel/strange_talk9.wav", "ambient/levels/citadel/strange_talk10.wav", "ambient/levels/citadel/strange_talk11.wav"}
local SES_NEFES = "player/breathe1.wav"

local function rastgele(t) return t[math_random(#t)] end

-- Dal kırılması: yumuşak tahta darbesi tiz çalınınca ince bir çıtırtıya döner
local function dalKir(pos, vol)
     sound.Play(rastgele(SES_DAL), pos, 72, math_random(135, 160), vol)
end

local donguler = {}
local function dongu(ad, dosya, hedefVol, pitch)
     local lp = LP()
     local d = donguler[ad]
     if not d then
          if hedefVol <= 0.01 then return end
          d = {patch = CreateSound(lp, dosya), vol = 0}
          donguler[ad] = d
     end
     d.vol = Lerp(math.min(FrameTime() * 1.5, 1), d.vol, hedefVol)
     if d.vol <= 0.01 then
          if d.patch:IsPlaying() then d.patch:Stop() end
          return
     end
     -- tek seferlik dosyalar (kalp atışı) bitince yeniden başlar, döngüler zaten sürer
     if not d.patch:IsPlaying() then d.patch:PlayEx(d.vol, pitch or 100) end
     d.patch:ChangeVolume(d.vol, 0)
end

local function donguleriKapat()
     for ad, d in pairs(donguler) do
          if d.patch then d.patch:Stop() end
          donguler[ad] = nil
     end
end

---------------------------------------------------------------------------
-- Dikkat
---------------------------------------------------------------------------
local function dikkatHesapla(lp)
     local pos = lp:GetPos()
     local d = 0.2

     local yakin = 0
     for _, p in player.Iterator() do
          if p ~= lp and p:Alive() and p:GetPos():DistToSqr(pos) < 202500 then -- 450^2
               yakin = yakin + 1
          end
     end
     d = d + (yakin == 0 and 0.25 or -0.2 * yakin)

     d = d + math.min((CurTime() - sonHareket) / 20, 1) * 0.25
     if lumosAcik(lp) then d = d + 0.2 end
     if girisZamani then d = d + math.min((CurTime() - girisZamani) / 180, 1) * 0.2 end

     if StormFox2 and StormFox2.Time and StormFox2.Time.IsNight and StormFox2.Time.IsNight() then
          d = d + 0.1
     end

     -- Orman ışıkta yürüyeni sevmez, karanlıkta yürüyeni tanır
     if lp.GetOnur then d = d + math_Clamp(lp:GetOnur() / 1000, -1, 1) * 0.15 end

     -- Yakındaki bir patronus ormanın bakışını uzak tutar ([sardon] patronus)
     if SardonPatronus and SardonPatronus.YakinKoruma and SardonPatronus.YakinKoruma(500) then d = d - 0.6 end

     return math_Clamp(d, 0, 1)
end

---------------------------------------------------------------------------
-- Gözler
---------------------------------------------------------------------------
-- Her göz çifti, sisin derinliğinde duran simsiyah bir figürün yüzündedir. Figür sisle
-- değil saf siyahla çizilir: arkasındaki ağaçlar sise gömülürken o ormandan daha koyu
-- bir boşluk gibi durur. Lumos sisi aydınlattığında silüet daha da belirginleşir.
local GOLGE_MAT = CreateMaterial("sardon_karanlikorman_golge", "UnlitGeneric", {
     ["$basetexture"] = "vgui/white",
     ["$translucent"] = "1",
     ["$vertexalpha"] = "1",
})
local GOZ_MAT = Material("sprites/light_glow02_add")
local GOZ_BEYAZ = Color(235, 238, 240)
local GOZ_KAN = Color(255, 60, 40)
local gozRenk = Color(0, 0, 0)
-- cüppeli silüet ve sıska, uzun uzuvlu bir beden; ikisi de oyuncu animasyonlu (yürüyebilir)
local FIGUR_MODEL = {"models/player/monk.mdl", "models/player/corpse1.mdl", "models/player/monk.mdl"}
local gozler = {}
local gozSonraki = 0
local gezenSonraki = 0
local takipSonraki = 0
local SES_HISIRTI = {"player/footsteps/grass1.wav", "player/footsteps/grass2.wav", "player/footsteps/grass3.wav", "player/footsteps/grass4.wav", "player/footsteps/dirt1.wav", "player/footsteps/dirt2.wav"}

local function bas(g)
     return g.pos + Vector(0, 0, 62 * g.olcek)
end

-- mutlak: mesMin/mesMax sis oranı değil doğrudan birim
local function figurYeriBul(lp, aciMin, aciMax, mesMin, mesMax, mutlak)
     local eye = EyePos()
     local yon = Angle(0, EyeAngles().y + (math_random(2) == 1 and -1 or 1) * math_Rand(aciMin, aciMax), 0):Forward()
     local mesafe = mutlak and math_Rand(mesMin, mesMax) or math_Clamp(fogEndHedef * math_Rand(mesMin, mesMax), 300, 950)
     local tr = util.TraceLine({start = eye, endpos = eye + yon * mesafe, mask = MASK_SOLID, filter = lp})
     local p
     if tr.Hit then
          if tr.Fraction * mesafe < math.min(250, mesafe * 0.6) then return end
          p = tr.HitPos - yon * 24 -- ağacın/kayanın hemen önünde duruyor
     else
          p = tr.HitPos
     end

     local yer = yerBul(p)
     if not yer then return end
     if not gorunurMu(lp, yer + Vector(0, 0, 64)) then return end
     return yer
end

local function figurOlustur(g)
     local ent = modelOlustur(FIGUR_MODEL[math_random(#FIGUR_MODEL)])
     if not IsValid(ent) then return false end
     ent:SetModelScale(g.olcek, 0) -- insandan bir tık uzun: tanıdık ama yanlış
     g.ent = ent
     g.seqDur = ent:LookupSequence("idle_all_01")
     g.seqYuru = ent:LookupSequence("walk_all")
     g.seqKos = ent:LookupSequence("run_all_01")
     if g.seqDur < 0 then g.seqDur = 0 end
     g.surYuru = g.seqYuru >= 0 and math.max(ent:SequenceDuration(g.seqYuru), 0.1) or 1
     g.surKos = g.seqKos >= 0 and math.max(ent:SequenceDuration(g.seqKos), 0.1) or 1
     g.kafaKemik = ent:LookupBone("ValveBiped.Bip01_Head1")
     g.gorKontrol = 0
     ent:ResetSequence(g.seqDur)
     ent:SetCycle(0)
     ent:SetPlaybackRate(0)
     return true
end

local function gozSil(i)
     local g = table.remove(gozler, i)
     if g then modelSil(g.ent) end
end

local function gozleriTemizle()
     for i = #gozler, 1, -1 do gozSil(i) end
end

local function gozYeni(pos, tur)
     local t = CurTime()
     local g = {pos = pos, dogus = t, kirp = t + math_Rand(2, 5), ayrik = math_Rand(1.8, 2.3), olcek = math_Rand(1.06, 1.18)}
     g.yaw = (EyePos() - pos):Angle().y
     if tur == "takip" then
          g.takip, g.hiz = true, 0
          g.hedefMesafe = Lerp(dikkat, 450, 320)
          g.sonPos, g.sonKontrol, g.adimZaman, g.engel = Vector(pos), t, 0, 0
     elseif tur == "gezen" then
          g.gezen, g.hiz = true, math_Rand(45, 80)
          g.yon = math_random(2) == 1 and 1 or -1
          g.durGez, g.faz = false, t + math_Rand(1.5, 3)
          g.omur = t + math_Rand(6, 12)
          g.sonPos, g.sonKontrol = Vector(pos), t
     end
     if not figurOlustur(g) then return end
     gozler[#gozler + 1] = g
end

local function gozKapat(g)
     if not g.kapanis then g.kapanis = CurTime() end
end

local function gezenGuncelle(lp, g, t, eye)
     if t > g.omur then gozKapat(g) return end

     -- yakalanınca durur, döner ve geri bakar, sonra söner
     if g.yakalandi then
          g.durGez = true
          if t - g.yakalandi > 0.8 then gozKapat(g) end
          return
     end
     if bakisAcisi(bas(g)) < 9 then g.yakalandi = t return end

     if t > g.faz then
          g.durGez = not g.durGez
          g.faz = t + (g.durGez and math_Rand(1, 2.5) or math_Rand(1.5, 3.5))
          if not g.durGez then
               if math_random() < 0.4 then g.yon = -g.yon end
               sound.Play(rastgele(SES_HISIRTI), g.pos, 60, math_random(70, 85), 0.25)
          end
     end
     if g.durGez then return end

     -- etrafında teğet dolanır, hafifçe yaklaşıp uzaklaşarak
     local fark = g.pos - eye
     fark.z = 0
     fark:Normalize()
     local teget = Vector(-fark.y * g.yon, fark.x * g.yon, 0)
     local adim = (teget + fark * math_sin(t * 0.5 + g.dogus) * 0.25) * g.hiz * FrameTime()
     g.pos = g.pos + adim
     g.hareketYaw = adim:Angle().y

     if t - g.sonKontrol > 0.1 then
          g.sonKontrol = t
          -- bir şeyin arkasına girdiyse bir daha çıkmaz
          local yukari = Vector(0, 0, 40)
          local tr = util.TraceLine({start = g.sonPos + yukari, endpos = g.pos + yukari, mask = MASK_SOLID, filter = lp})
          if tr.Hit then gozKapat(g) return end
          local yer = yerBul(g.pos)
          if not yer or math.abs(yer.z - g.pos.z) > 40 then gozKapat(g) return end
          g.pos.z = yer.z
          g.sonPos = Vector(g.pos)
     end
end

-- Takipçi: arkandan, sisin içinden gelir. Ona bakmadığın sürece yürür, göz ucuna
-- girdiği an donar; adımlarını duyarsın ama dönünce yerinde kıpırtısız durur. Tam
-- üstüne bakarsan bir an geri bakar ve kaybolur. Bakılmadıkça mesafeyi yavaşça kapatır.
local function takipIsinla(lp, g)
     local yer = figurYeriBul(lp, 140, 180, g.hedefMesafe + 40, g.hedefMesafe + 140, true)
     if yer then
          g.pos, g.sonPos, g.engel = yer, Vector(yer), 0
          g.yaw = (EyePos() - yer):Angle().y
     end
end

local function takipAdim(g, vol)
     if math_random() < 0.08 then
          dalKir(g.pos, vol) -- arada ayağının altında bir dal kırılır
     else
          sound.Play(rastgele(SES_HISIRTI), g.pos, 70, math_random(82, 95), vol)
     end
end

local function takipGuncelle(lp, g, t, eye)
     local ft = FrameTime()
     if g.yakalandi then
          g.hiz = 0
          if t - g.yakalandi > 0.8 then gozKapat(g) end
          return
     end
     local aci = bakisAcisi(bas(g))
     if aci < 10 and gorunurMu(lp, bas(g)) then g.yakalandi = t return end

     local fark = lp:GetPos() - g.pos
     fark.z = 0
     local mesafe = fark:Length()
     fark:Normalize()

     g.hedefMesafe = math.max(g.hedefMesafe - ft * 3, 280)

     if mesafe > 1100 then
          if aci > 90 then takipIsinla(lp, g) end
          return
     end

     -- göz ucunda bile donar; yalnızca ekran dışındayken yürür
     local hedefHiz = 0
     local fazla = mesafe - g.hedefMesafe
     if aci > 65 and fazla > 0 then
          hedefHiz = math_Clamp(lp:GetVelocity():Length2D() * 1.05 + fazla * 0.6, 40, 260)
     end

     local onceki = g.hiz
     g.hiz = math.Approach(g.hiz, hedefHiz, ft * 400)
     local vol = math_Clamp(0.45 + dikkat * 0.25, 0, 1)
     if g.hiz < 1 then
          -- durduğunda bazen son bir adım
          if onceki >= 1 and math_random() < 0.35 then
               timer.Simple(math_Rand(0.2, 0.5), function()
                    if g.ent and IsValid(g.ent) and not g.kapanis then takipAdim(g, vol * 0.8) end
               end)
          end
          return
     end

     local yon = fark
     if g.yanKac and t < g.yanKac then
          yon = (Vector(-fark.y * g.yanYon, fark.x * g.yanYon, 0) + fark * 0.3):GetNormalized()
     end
     g.pos = g.pos + yon * g.hiz * ft
     g.hareketYaw = yon:Angle().y

     if t > g.adimZaman then
          g.adimZaman = t + math_Clamp(48 / g.hiz, 0.25, 0.7)
          if math_random() < 0.65 then takipAdim(g, vol) end
     end

     if t - g.sonKontrol > 0.1 then
          g.sonKontrol = t
          local yukari = Vector(0, 0, 40)
          local tr = util.TraceLine({start = g.sonPos + yukari, endpos = g.pos + yukari, mask = MASK_SOLID, filter = lp})
          local yer = not tr.Hit and yerBul(g.pos)
          if not yer or math.abs(yer.z - g.sonPos.z) > 40 then
               -- engel: geri al, yana sap; takılı kaldıysa görülmüyorken arkana geç
               g.pos = Vector(g.sonPos)
               g.engel = g.engel + 1
               g.yanKac, g.yanYon = t + 0.8, math_random(2) == 1 and 1 or -1
               if g.engel > 6 and aci > 90 then takipIsinla(lp, g) end
               return
          end
          g.pos.z = yer.z
          g.sonPos = Vector(g.pos)
          g.engel = math.max(g.engel - 0.2, 0)
     end
end

local function gozlerGuncelle(lp)
     local t = CurTime()
     local eye = EyePos()
     local sabit, gezen, takip = 0, 0, 0
     for i = #gozler, 1, -1 do
          local g = gozler[i]
          if g.kapanis then
               if t - g.kapanis > 0.6 then
                    if g.takip then takipSonraki = math.max(takipSonraki, t + math_Rand(12, 30) * (1.3 - dikkat)) end
                    gozSil(i)
               end
          elseif eye:DistToSqr(g.pos) < 62500 then -- 250^2: yaklaşınca çalılara çekilir
               sound.Play(SES_RUZGAR, g.pos, 65, math_random(110, 130), 0.35)
               gozKapat(g)
          elseif g.takip then
               takipGuncelle(lp, g, t, eye)
               takip = takip + 1
          elseif g.gezen then
               gezenGuncelle(lp, g, t, eye)
               gezen = gezen + 1
          elseif bakisAcisi(bas(g)) < 9 then
               gozKapat(g) -- doğrudan bakılınca kırpar ve silinir
          elseif t > g.gorKontrol then
               g.gorKontrol = t + 0.25 -- görüş izini her kare değil, saniyede 4 kez
               if gorunurMu(lp, bas(g)) then sabit = sabit + 1 else gozSil(i) end
          else
               sabit = sabit + 1
          end
     end

     if not lp:Alive() or lp:GetMoveType() == MOVETYPE_NOCLIP or intenE < 0.6 then return end

     local en = math.floor(1 + dikkat * 2)
     if lumosAcik(lp) then en = en + 1 end
     if t > gozSonraki and sabit < en then
          local yer = figurYeriBul(lp, 35, 150, 0.7, 0.9)
          if yer then gozYeni(yer) end
          gozSonraki = t + math_Rand(2, 6) * (1.3 - dikkat)
     end

     if t > gezenSonraki and gezen < 1 then
          local yer = figurYeriBul(lp, 30, 75, 0.6, 0.8)
          if yer then gozYeni(yer, "gezen") end
          gezenSonraki = t + math_Rand(6, 14) * (1.4 - dikkat)
     end

     if t > takipSonraki and takip < 1 then
          local d = Lerp(dikkat, 450, 320)
          local yer = figurYeriBul(lp, 140, 180, d + 80, d + 200, true)
          if yer then gozYeni(yer, "takip") end
          takipSonraki = t + 3
     end
end

-- Kare başına bir kez (Think): yön, animasyon, kemikler ve göz konumu. Çizim kancası
-- bir karede birkaç kez çağrılabildiği için zamanla ilerleyen durum orada tutulmaz.
local function figurHazirla()
     local eye = kEye
     local ft = FrameTime()
     for i = 1, #gozler do
          local g = gozler[i]
          local ent = g.ent
          if IsValid(ent) then
               local hiz = g.takip and g.hiz or (g.gezen and not g.durGez and g.hiz) or 0
               local yurur = hiz > 5
               local hedefYaw = yurur and g.hareketYaw or (eye - g.pos):Angle().y
               g.yaw = math.ApproachAngle(g.yaw, hedefYaw, ft * 200)

               local seq, ref, sur = g.seqDur, 75, 1
               if hiz > 140 and g.seqKos >= 0 then
                    seq, ref, sur = g.seqKos, 220, g.surKos
               elseif yurur and g.seqYuru >= 0 then
                    seq, sur = g.seqYuru, g.surYuru
               end
               if ent:GetSequence() ~= seq then ent:ResetSequence(seq) end
               if seq == g.seqDur then
                    ent:SetCycle(0)
               else
                    g.cyc = ((g.cyc or 0) + ft * hiz / ref / sur) % 1
                    ent:SetCycle(g.cyc)
               end

               ent:SetPos(g.pos)
               ent:SetAngles(Angle(0, g.yaw, 0))
               ent:SetupBones()

               local kafa = g.kafaKemik and ent:GetBonePosition(g.kafaKemik) or bas(g)
               local ileri = ent:GetForward()
               g.goz = kafa + ileri * 4 * g.olcek
               g.goz.z = g.goz.z + 1.5 * g.olcek
               -- gözler yalnızca yüz sana dönükken parlar: yan yürürken sadece silüet
               local d = eye - g.goz
               d:Normalize()
               g.yuzBakis = math_Clamp((ileri:Dot(d) - 0.3) / 0.5, 0, 1)
          end
     end
end

-- Opak geçiş: siyah figürler (sadece çizim)
local function figurCiz()
     if #gozler == 0 then return end
     local t = CurTime()

     render.FogMode(MATERIAL_FOG_NONE)
     render.MaterialOverride(GOLGE_MAT)
     render.SetColorModulation(0, 0, 0)
     for i = 1, #gozler do
          local g = gozler[i]
          if IsValid(g.ent) then
               local alfa = math.min((t - g.dogus) / 1.5, 1) * intenE
               if g.kapanis then alfa = alfa * (1 - math.min((t - g.kapanis) / 0.5, 1)) end
               if alfa > 0.01 then
                    render.SetBlend(alfa)
                    g.ent:DrawModel()
               end
          end
     end
     render.SetBlend(1)
     render.SetColorModulation(1, 1, 1)
     render.MaterialOverride(nil)
     render.FogMode(MATERIAL_FOG_LINEAR)
end

-- Saydam geçiş: gözler (sise gömülmesinler diye sis kapalı)
local function gozCiz()
     if #gozler == 0 then return end
     local lp = LP()
     local t = CurTime()
     local eye = EyePos() -- sprite boyu çizilen görüntüye göre
     local karanlik = lp.GetOnur and lp:GetOnur() <= -300
     local taban = karanlik and GOZ_KAN or GOZ_BEYAZ
     local parlak = intenE * (lumosAcik(lp) and 0.75 or 0.5)

     render.FogMode(MATERIAL_FOG_NONE)
     render.SetMaterial(GOZ_MAT)
     for i = 1, #gozler do
          local g = gozler[i]
          if g.goz and g.yuzBakis then
               local aci = bakisAcisi(g.goz)
               local a = math_Clamp((aci - 8) / 14, 0, 1) * math.min((t - g.dogus) / 2, 1) * parlak * g.yuzBakis
               if g.yakalandi then a = parlak * g.yuzBakis end

               local h = 1
               if g.kapanis then
                    h = 1 - math.min((t - g.kapanis) / 0.15, 1)
               elseif t > g.kirp then
                    local k = t - g.kirp
                    if k < 0.12 then h = 0.1 else g.kirp = t + math_Rand(2.5, 6) end
               end

               if a > 0.01 and h > 0.01 then
                    local fark = g.goz - eye
                    local sag = fark:Angle():Right()
                    local boy = math.max(3, fark:Length() * 0.009)
                    local s1, s2 = g.goz + sag * g.ayrik, g.goz - sag * g.ayrik
                    gozRenk.r, gozRenk.g, gozRenk.b, gozRenk.a = taban.r * a, taban.g * a, taban.b * a, 255
                    render.DrawSprite(s1, boy, boy * h, gozRenk)
                    render.DrawSprite(s2, boy, boy * h, gozRenk)
               end
          end
     end
     render.FogMode(MATERIAL_FOG_LINEAR)
end

---------------------------------------------------------------------------
-- Gölgen
---------------------------------------------------------------------------
local golge = nil
local golgeSonraki = CurTime() + 60

local function golgeKaldir(cooldown)
     if golge then modelSil(golge.ent) end
     golge = nil
     golgeSonraki = CurTime() + (cooldown or math_Rand(90, 200))
end

local function golgeYeri(lp, mesafe)
     local eye = EyePos()
     local yon = Angle(0, EyeAngles().y + 180 + math_Rand(-35, 35), 0):Forward()
     local tr = util.TraceLine({start = eye, endpos = eye + yon * mesafe, mask = MASK_SOLID, filter = lp})
     if tr.Fraction < 0.8 then return end
     local yer = yerBul(tr.HitPos - yon * 20)
     if not yer then return end
     if not gorunurMu(lp, yer + Vector(0, 0, 50)) then return end
     return yer
end

local function golgeOlustur(lp)
     local mesafe = math.max(fogEndHedef * math_Rand(0.5, 0.65), 280)
     local yer = golgeYeri(lp, mesafe)
     if not yer then return end

     local ent = modelOlustur(lp:GetModel())
     if not IsValid(ent) then return end
     for i = 0, lp:GetNumBodyGroups() - 1 do
          ent:SetBodygroup(i, lp:GetBodygroup(i))
     end
     -- İsimle seç: sunucu indeksi istemci modelinde başka animasyona denk gelebilir
     local seq = ent:LookupSequence("idle_all_01")
     if seq < 0 then seq = ent:LookupSequence("idle_subtle") end
     ent:ResetSequence(math.max(seq, 0))
     ent:SetCycle(0)
     ent:SetPlaybackRate(0)

     golge = {ent = ent, pos = yer, mesafe = mesafe, dogus = CurTime(), yer = CurTime(), goruldu = nil, alfa = 0}
end

local function golgeGuncelle(lp)
     local t = CurTime()

     if not golge then
          if t > golgeSonraki and dikkat > 0.5 and intenE > 0.9 and lp:Alive() and lp:IsOnGround()
               and lp:GetMoveType() ~= MOVETYPE_NOCLIP and math_random() < 0.1 + dikkat * 0.2 then
               golgeOlustur(lp)
               if not golge then golgeSonraki = t + 5 end
          end
          return
     end

     local gogus = golge.pos + Vector(0, 0, 50)

     if golge.goruldu then
          -- bir an göz göze, sonra yok
          local k = t - golge.goruldu
          if k > 0.4 and not golge.citirti then
               golge.citirti = true
               sound.Play(rastgele(SES_CITIRTI), golge.pos, 70, math_random(80, 95), 0.6)
          end
          golge.alfa = 1 - math_Clamp((k - 0.4) / 0.6, 0, 1)
          if k > 1 then golgeKaldir() end
          return
     end

     golge.alfa = math.min(golge.alfa + FrameTime() * 0.5, 1)

     if bakisAcisi(gogus) < 28 and gorunurMu(lp, gogus) then
          golge.goruldu = t
          return
     end

     -- bakılmadıkça yaklaşır; sırtına geldiğinde nefesi duyulur ve gider
     if t - golge.yer > 18 then
          local yeni = golge.mesafe * 0.7
          if yeni < 260 then
               sound.Play(SES_NEFES, EyePos() - EyeAngles():Forward() * 40, 60, math_random(85, 95), 0.5)
               golgeKaldir(math_Rand(150, 260))
               return
          end
          local yer = golgeYeri(lp, yeni)
          if yer then
               golge.pos, golge.mesafe = yer, yeni
          end
          golge.yer = t
     end

     if lp:GetPos():DistToSqr(golge.pos) < 48400 then golgeKaldir() return end -- 220^2
end

local function golgeHazirla()
     if not golge or not IsValid(golge.ent) then return end
     local ent = golge.ent
     ent:SetPos(golge.pos)
     ent:SetAngles(Angle(0, (kEye - golge.pos):Angle().y, 0))
     ent:SetupBones()
end

local function golgeCiz()
     if not golge or not IsValid(golge.ent) or golge.alfa <= 0.01 then return end
     local ent = golge.ent
     render.MaterialOverride(GOLGE_MAT)
     render.SetColorModulation(0.01, 0.01, 0.012)
     render.SetBlend(golge.alfa * intenE)
     ent:DrawModel()
     render.SetBlend(1)
     render.SetColorModulation(1, 1, 1)
     render.MaterialOverride(nil)
end

---------------------------------------------------------------------------
-- Yankı adımlar
---------------------------------------------------------------------------
local sonAdim, sonAdimSes, sonAdimVol = 0, nil, 0.5
local hizliydi = false

local function arkadanCal(snd, uzak, vol, pitch)
     local lp = LP()
     if not IsValid(lp) or intenE < 0.5 then return end
     local geri = -lp:EyeAngles():Forward()
     geri.z = 0
     geri:Normalize()
     sound.Play(snd, lp:GetPos() + geri * uzak + Vector(0, 0, 8), 68, pitch, vol)
end

hook.Add("PlayerFootstep", "SardonKaranlikOrman", function(ply, _, _, snd, vol)
     if ply ~= LP() or intenE < 0.5 or not IsFirstTimePredicted() then return end
     sonAdim, sonAdimSes, sonAdimVol = CurTime(), snd, vol
     -- her adım değil: kusursuz yankı makine gibi gelir, eksik olanı tedirgin eder
     if math_random() > 0.55 + dikkat * 0.4 then return end
     local uzak = Lerp(dikkat, 380, 140)
     local v = math_Clamp(vol * (0.35 + dikkat * 0.45), 0, 1)
     timer.Simple(math_Rand(0.28, 0.42), function()
          arkadanCal(snd, uzak, v, math_random(88, 96))
     end)
end)

---------------------------------------------------------------------------
-- Ortam sesleri
---------------------------------------------------------------------------
local ortamSonraki = 0

local function ortamSesi()
     if sessizlik > 0.3 then return end
     local eye = EyePos()
     local yon = Angle(0, math_Rand(0, 360), 0):Forward()
     local pos = eye + yon * math_Rand(350, 1100) + Vector(0, 0, math_Rand(0, 200))
     local r = math_random()
     if dikkat > 0.7 and r < 0.12 then
          -- uzakta, anlaşılmayan bir konuşma: kalın ve neredeyse duyulmaz
          sound.Play(rastgele(SES_FISILTI), pos, 70, math_random(68, 80), 0.18)
     elseif r < 0.45 then
          sound.Play(rastgele(SES_KUS), pos, 80, math_random(85, 100), 0.5)
     elseif r < 0.75 then
          sound.Play(rastgele(SES_CITIRTI), pos, 72, math_random(85, 105), 0.5)
     elseif r < 0.9 then
          dalKir(pos, 0.55)
     else
          sound.Play(SES_RUZGAR, pos, 75, math_random(90, 105), 0.45)
     end
end

---------------------------------------------------------------------------
-- Ani dönüş
---------------------------------------------------------------------------
local yawOrnek = {}
local yawSonOrnek = 0
local donusSonraki = 0

local function donusKontrol(lp)
     local t = CurTime()
     if t - yawSonOrnek < 0.05 then return end
     yawSonOrnek = t
     local yaw = EyeAngles().y
     table.insert(yawOrnek, 1, {t = t, yaw = yaw})
     if #yawOrnek > 12 then yawOrnek[13] = nil end

     if t < donusSonraki then return end
     for i = 2, #yawOrnek do
          local o = yawOrnek[i]
          if t - o.t > 0.5 then break end
          if math.abs(math.AngleDifference(yaw, o.yaw)) > 115 then
               donusSonraki = t + 15
               table.Empty(yawOrnek)

               -- arkasına bakılan gözler saklanır
               for _, g in ipairs(gozler) do
                    if bakisAcisi(g.pos) < 60 then g.kapanis = t - 1 end
               end

               if math_random() < 0.4 + dikkat * 0.5 then
                    local eskiYon = Angle(0, o.yaw, 0):Forward()
                    timer.Simple(math_Rand(0.5, 0.9), function()
                         if not aktif() then return end
                         dalKir(EyePos() + eskiYon * math_Rand(250, 450), 0.7)
                    end)
               end
               return
          end
     end
end

---------------------------------------------------------------------------
-- Ana döngü
---------------------------------------------------------------------------
local sonDikkat = 0

local function temizle()
     gozleriTemizle()
     golgeKaldir(60)
     donguleriKapat()
     girisZamani = nil
     dikkat, dikkatHedef, sessizlik = 0, 0, 0
end

hook.Add("Think", "SardonKaranlikOrman", function()
     local lp = LP()
     if not IsValid(lp) then return end

     local istek = lp:GetNWBool("fogReq", false)
     local onceki = intenE
     inten = math.Approach(inten, istek and 1 or 0, FrameTime() / 4)
     intenE = math.EaseInOut(inten, 0, 0.3)

     if not aktif() then
          if onceki > 0.01 then temizle() end
          return
     end

     local t = CurTime()
     bakisGuncelle()
     if istek and not girisZamani then
          girisZamani = t
          takipSonraki = t + math_Rand(8, 15) -- takipçi önce izini sürer, hemen gelmez
     end

     local hiz = lp:GetVelocity():Length2DSqr()
     if hiz > 400 then sonHareket = t end -- 20^2

     -- durunca bazen bir adım fazla
     if hiz > 3600 then
          hizliydi = true
     elseif hizliydi and hiz < 25 then
          hizliydi = false
          if sonAdimSes and t - sonAdim < 0.6 and math_random() < 0.25 + dikkat * 0.4 then
               local snd, v = sonAdimSes, math_Clamp(sonAdimVol * (0.4 + dikkat * 0.4), 0, 1)
               timer.Simple(math_Rand(0.5, 0.9), function()
                    arkadanCal(snd, Lerp(dikkat, 300, 120), v, math_random(88, 94))
               end)
          end
     end

     if t - sonDikkat > 0.25 then
          sonDikkat = t
          dikkatHedef = dikkatHesapla(lp) * intenE
     end
     dikkat = math.Approach(dikkat, dikkatHedef, FrameTime() * 0.08)

     local hedef = Lerp(dikkat, 950, 340) * (1 + 0.08 * math_sin(t * 0.9))
     if lumosAcik(lp) then hedef = math.max(hedef, 700) end
     fogEndHedef = Lerp(math.min(FrameTime() * 0.7, 1), fogEndHedef, hedef)

     gozlerGuncelle(lp)
     golgeGuncelle(lp)
     donusKontrol(lp)
     figurHazirla()
     golgeHazirla()

     sessizlik = math.Approach(sessizlik, golge and not golge.goruldu and 1 or 0, FrameTime() * 0.6)

     if t > ortamSonraki then
          ortamSonraki = t + math_Rand(5, 13)
          ortamSesi()
     end

     dongu("ton", "ambient/atmosphere/tone_quiet.wav", 0.3 * intenE * (1 - sessizlik * 0.7))
     dongu("ugultu", "ambient/levels/citadel/drone1lp.wav", 0.45 * intenE * sessizlik, 70)
     dongu("kalp", "player/heartbeat1.wav", intenE * math.max(sessizlik * 0.55, dikkat > 0.85 and 0.2 or 0))
end)

---------------------------------------------------------------------------
-- Sis
---------------------------------------------------------------------------
local function sisHesapla()
     local lp = LP()
     local t = CurTime()
     local lumos = lumosAcik(lp)

     if t - sonIsikOlcum > 0.2 then
          sonIsikOlcum = t
          local lc = render.GetLightColor(EyePos())
          sisIsik = Lerp(0.3, sisIsik, math_Clamp((lc.x + lc.y + lc.z) * 2, 0.35, 1.8))
     end

     local renk = SIS_YOSUN * sisIsik
     if lumos then renk = renk + (SIS_LUMOS - renk) * 0.75 end
     fogR = Lerp(FrameTime() * 2, fogR, renk.x * intenE)
     fogG = Lerp(FrameTime() * 2, fogG, renk.y * intenE)
     fogB = Lerp(FrameTime() * 2, fogB, renk.z * intenE)

     fogStart = Lerp(intenE, 0, lumos and 80 or 0)
     fogEnd = Lerp(intenE, 11000, fogEndHedef)
end

hook.Add("SetupWorldFog", "SardonKaranlikOrman", function()
     if not aktif() then return end
     sisHesapla()
     render.FogMode(MATERIAL_FOG_LINEAR)
     render.FogStart(fogStart)
     render.FogEnd(fogEnd)
     render.FogMaxDensity(0.96)
     render.FogColor(fogR, fogG, fogB)
     return true
end)

hook.Add("SetupSkyboxFog", "SardonKaranlikOrman", function(scale)
     if not aktif() then return end
     render.FogMode(MATERIAL_FOG_LINEAR)
     render.FogStart(fogStart * scale)
     render.FogEnd(fogEnd * scale)
     render.FogMaxDensity(1)
     render.FogColor(fogR, fogG, fogB)
     return true
end)

hook.Add("PostDrawOpaqueRenderables", "SardonKaranlikOrman", function(depth, sky)
     if depth or sky or not aktif() then return end
     figurCiz()
     golgeCiz()
end)

hook.Add("PostDrawTranslucentRenderables", "SardonKaranlikOrman", function(depth, sky)
     if depth or sky or not aktif() then return end
     gozCiz()
end)

---------------------------------------------------------------------------
-- Ekran: renk çekilmesi + yöne duyarlı kenar kararması
---------------------------------------------------------------------------
local GRAD_L = Material("vgui/gradient-l") -- solda opak
local GRAD_R = Material("vgui/gradient-r") -- sağda opak
local GRAD_U = Material("vgui/gradient-u") -- üstte opak
local GRAD_D = Material("vgui/gradient-d") -- altta opak
local renkTab = {
     ["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
     ["$pp_colour_brightness"] = 0, ["$pp_colour_contrast"] = 1, ["$pp_colour_colour"] = 1,
     ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
}
local yanSol, yanSag = 0, 0

hook.Add("RenderScreenspaceEffects", "SardonKaranlikOrman", function()
     if not aktif() or SardonFPSBoost or dikkat * intenE < 0.03 then return end
     renkTab["$pp_colour_colour"] = 1 - dikkat * 0.3 * intenE
     renkTab["$pp_colour_brightness"] = -0.02 * dikkat * intenE
     DrawColorModify(renkTab)
end)

-- Ekranda olmayan ama yakın olan gözlemcinin hangi yanda olduğunu bul
local function gozlemciYonu()
     local eye = kEye
     local sag = kFwd:Angle():Right()
     local enYakin, yon = math.huge, 0
     local function bak(pos)
          local d = eye:DistToSqr(pos)
          if d < enYakin and bakisAcisi(pos) > 45 then
               enYakin = d
               yon = (pos - eye):Dot(sag) > 0 and 1 or -1
          end
     end
     for i = 1, #gozler do
          if not gozler[i].kapanis then bak(gozler[i].pos) end
     end
     if golge and not golge.goruldu then bak(golge.pos) end
     return yon
end

hook.Add("HUDPaintBackground", "SardonKaranlikOrman", function()
     if not aktif() then return end
     local w, h = ScrW(), ScrH()
     local yon = gozlemciYonu()
     local ft = FrameTime() * 0.8
     yanSol = Lerp(ft, yanSol, yon == -1 and 1 or 0)
     yanSag = Lerp(ft, yanSag, yon == 1 and 1 or 0)

     local nabiz = sessizlik > 0.05 and (0.5 + 0.5 * math_sin(CurTime() * 7.5)) * sessizlik * 0.15 or 0
     local taban = intenE * (0.35 + dikkat * 0.35 + nabiz)
     local kenar = w * 0.3
     local dikey = h * 0.25

     surface.SetMaterial(GRAD_L)
     surface.SetDrawColor(0, 0, 0, math.min(255 * (taban + yanSol * 0.3 * intenE), 255))
     surface.DrawTexturedRect(0, 0, kenar, h)
     surface.SetMaterial(GRAD_R)
     surface.SetDrawColor(0, 0, 0, math.min(255 * (taban + yanSag * 0.3 * intenE), 255))
     surface.DrawTexturedRect(w - kenar, 0, kenar, h)
     surface.SetDrawColor(0, 0, 0, 255 * taban * 0.8)
     surface.SetMaterial(GRAD_U)
     surface.DrawTexturedRect(0, 0, w, dikey)
     surface.SetMaterial(GRAD_D)
     surface.DrawTexturedRect(0, h - dikey, w, dikey)
end)
