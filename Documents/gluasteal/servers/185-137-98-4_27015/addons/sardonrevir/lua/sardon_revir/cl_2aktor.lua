-- "addons\\sardonrevir\\lua\\sardon_revir\\cl_2aktor.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Revir :: istemci aktörleri (Madam Pomfrey ve hastalar), belirti görselleri, kalıntı halesi,
-- Accio ile uçan eşyalar, konuşma balonları, masadaki defter, dünya efektleri.
--
-- Sekanslar ADIYLA kurulur (sunucu/istemci sekans sıraları farklı olabilir). Poz değişince (ayakta / yatıyor /
-- oturuyor) model yeniden kurulur: var olan ClientsideModel'de sekans değişimi eski pozla karışıyor.
-- Yatış: model pitch -90 döndürülür (yüz yukarı), baş yatağın baş ucuna; oturuş: sit_zen ile şiltede bağdaş.

local R = SardonRevir
local SA = setmetatable({}, {__index = function(_, k) local A = SardonAkran return A and A[k] end}) -- akran sonradan yüklenebilir

R.CA = R.CA or {}
R.Balon = R.Balon or {}
R.Ucanlar = R.Ucanlar or {}

local M = {
     isik = Material("sprites/light_glow02_add"),
     halka = Material("effects/select_ring"),
     dalga = Material("particle/particle_ring_wave_additive"),
     keskin = Material("particle/particle_ring_sharp"),
     iz = Material("trails/laser")
}

local MODEL_YEDEK = "models/player/kleiner.mdl"

local function ModelVar(m)
     return isstring(m) and m != "" and file.Exists(m, "GAME")
end

-- [sardon] ogrenci HL gövdesi (taban yalnız kafa + el, giysi/saç ayrı parça): hasta adı + modelden tohumlu
-- rastgele görünüm ve hane okul takımı; tohum herkeste aynı olduğu için her istemcide aynı kişi görünür.
-- Hane unvanın başında ("Gryffindor · 3. yıl"). Parçaları AktorCiz O.ParcaCiz ile çizer.
local HANE_NO = {Gryffindor = 1, Slytherin = 2, Ravenclaw = 3, Hufflepuff = 4}
local function HLGiydir(c, ent)
     local O, v = SardonOgrenci, c.v
     if (!O or !O.Hazir or !O.Hazir() or !O.Rastgele or !O.OnizlemeGiydir or !HLStudents or !HLStudents.IsStudentModel(ent:GetModel())) then return end
     local cins = HLStudents.GenderOfModel(ent:GetModel()) == "f" and "f" or "m"
     local yuz = 1
     for i, f in ipairs(HLStudents.FacesOf and HLStudents.FacesOf(cins) or {}) do
          if (string.lower(f.model or "") == string.lower(ent:GetModel())) then yuz = i break end
     end
     local asil = math.random
     math.random = R.Rastgele(tonumber(util.CRC((v.ad or "") .. "|" .. (v.model or ""))))
     local ok, d = pcall(O.Rastgele, cins)
     math.random = asil
     if (!ok or !istable(d)) then return end
     d.face = yuz
     local giyili = {}
     for _, g in ipairs(O.HaneTakimi and O.HaneTakimi[cins] or {}) do
          local pid = O.GiysiParcaKimligi(g[1], cins)
          local p = pid and O.GiysiParcasi(g[1], cins)
          if (p) then giyili[p.slot] = {piece = pid, look = g[2]} end
     end
     pcall(O.OnizlemeGiydir, ent, d, giyili, HANE_NO[string.match(v.unvan or "", "^(%a+)") or ""] or 1, false, 1)
end

--[[
*   net
]]

local function Oku()
     local v = {}
     v.id = net.ReadUInt(16)
     v.tur = net.ReadString()
     v.model = net.ReadString()
     v.ad = net.ReadString()
     v.unvan = net.ReadString()
     v.poz = net.ReadString()
     v.yatak = net.ReadUInt(4)
     v.pos = net.ReadVector()
     v.yaw = net.ReadFloat()
     v.yol = {}
     for i = 1, net.ReadUInt(6) do v.yol[i] = net.ReadVector() end
     v.yolBas = net.ReadFloat()
     v.hiz = net.ReadFloat()
     v.hedefYaw = net.ReadFloat()
     v.efektler = {}
     for e in string.gmatch(net.ReadString(), "[^,]+") do v.efektler[e] = true end
     v.siddet = net.ReadUInt(4)
     v.kalinti = net.ReadString()
     v.kalintiBitis = net.ReadFloat()
     v.gizli = net.ReadBool()
     v.sahip = net.ReadUInt(16)
     v.giris = net.ReadBool()
     v.cikis = net.ReadBool()
     v.anim = net.ReadString()
     v.animBas = net.ReadFloat()
     if (#v.yol < 2) then v.yol = nil end
     -- yol uzunluğu
     if (v.yol) then
          local L = 0
          for i = 2, #v.yol do L = L + v.yol[i - 1]:Distance(v.yol[i]) end
          v.yolL = L
     end
     return v
end

local function Sil(c)
     if (IsValid(c.ent)) then c.ent:Remove() end
     if (c.em) then c.em:Finish() c.em = nil end
end

net.Receive("SardonRevir.Aktor", function()
     local op = net.ReadUInt(2)
     if (op == 2) then
          local id = net.ReadUInt(16)
          local c = R.CA[id]
          if (c) then Sil(c) end
          R.CA[id] = nil
          R.Balon[id] = nil
          return
     end
     local v = Oku()
     local c = R.CA[v.id]
     if (!c) then
          c = {alfa = v.giris and 0 or 1, girisBas = v.giris and RealTime() or nil, cycle = 0, yaw = v.yaw}
          R.CA[v.id] = c
     end
     local onceki = c.v
     if (onceki and (onceki.poz != v.poz or onceki.model != v.model)) then c.yenidenKur = true end
     if (onceki and onceki.anim != v.anim and v.anim != "") then c.yenidenKur = true end
     c.v = v
end)

--[[
*   model
]]

local function SekansAd(ent, ad)
     if (!ad or ad == "") then return -1 end
     local s = ent:LookupSequence(ad) or -1
     if (s >= 0) then
          local b = ent:GetSequenceInfo(s)
          local an = b and b.anims and b.anims[1]
          local ai = an and ent:GetAnimInfo(an)
          if (ai and bit.band(ai.flags or 0, 4) != 0) then
               -- katman jesti: tam gövde sürümü
               local o = ent:LookupSequence(ad .. "_original") or -1
               return o
          end
     end
     return s
end

-- 11-14 opt: SekansAd sonucu aktör başına önbellekte (LookupSequence + GetSequenceInfo/GetAnimInfo tabloları aktör
-- başına karede ~1,3 KB idi). Anahtar: varlığın kendisi (rawequal; model yalnız ModelKur'da, yeni varlıkla ve HLGiydir
-- ile kurulur) + sekans adı; aktör başına en çok 4-5 ad (walk_all / idle_all_01 / sit_zen + v.anim, v.anim değişince
-- model yeniden kurulur). DynaBase animasyonları yeniden bağlayınca sekans numaraları değişir: PostLoadAnimations'ta
-- boşaltılır (cl_3aktor, sh_anims, savasbitki ile aynı yol).
local function SekansOnb(c, ent, ad)
     if (ad == nil) then return SekansAd(ent, ad) end -- nil anahtar olamaz
     local onb = c.optSekans
     if (!onb or !rawequal(c.optSekansEnt, ent)) then
          onb = {}
          c.optSekans, c.optSekansEnt = onb, ent
     end
     local s = onb[ad]
     if (s == nil) then
          s = SekansAd(ent, ad)
          onb[ad] = s
     end
     return s
end

hook.Add("PostLoadAnimations", "SardonRevir.SekansOnb", function()
     for _, c in pairs(R.CA) do c.optSekans = nil end
end)

local function ModelKur(c)
     if (IsValid(c.ent)) then c.ent:Remove() end
     local v = c.v
     local m = ModelVar(v.model) and v.model or MODEL_YEDEK
     local ent = ClientsideModel(m, RENDERGROUP_OPAQUE)
     if (!IsValid(ent)) then return end
     ent:SetIK(false)
     ent:SetNoDraw(true) -- elle çizilir (saydamlık ve renk tonu için)
     ent.SardonRevir = c
     c.ent = ent
     HLGiydir(c, ent)
     c.cycle = 0
     c.manip = {}
     c.seqAd = nil
     c.yenidenKur = false
     c.kemik = {
          bas = ent:LookupBone("ValveBiped.Bip01_Head1"),
          omurga = ent:LookupBone("ValveBiped.Bip01_Spine2"),
          sagOn = ent:LookupBone("ValveBiped.Bip01_R_Forearm"),
          sagUst = ent:LookupBone("ValveBiped.Bip01_R_UpperArm"),
          sagEl = ent:LookupBone("ValveBiped.Bip01_R_Hand"),
          solUyluk = ent:LookupBone("ValveBiped.Bip01_L_Thigh"),
          sagUyluk = ent:LookupBone("ValveBiped.Bip01_R_Thigh"),
          solBaldir = ent:LookupBone("ValveBiped.Bip01_L_Calf"),
          sagBaldir = ent:LookupBone("ValveBiped.Bip01_R_Calf")
     }
     c.altAgac = nil -- kafa / el alt ağacı ilk SetupBones'tan sonra çıkarılır (taze modelde kemik sayısı 0 olabilir)
     c.basYaw = ent:LookupPoseParameter("head_yaw") >= 0
     c.basPitch = ent:LookupPoseParameter("head_pitch") >= 0
end

--[[
*   konum ve poz
]]

local function YolKonum(v)
     local gidilen = (CurTime() - v.yolBas) * v.hiz
     local d = gidilen
     local yol = v.yol
     for i = 2, #yol do
          local seg = yol[i - 1]:Distance(yol[i])
          if (d <= seg) then
               local f = seg > 0 and d / seg or 1
               return LerpVector(f, yol[i - 1], yol[i]), (yol[i] - yol[i - 1]):Angle().y, true, v.yolL - gidilen
          end
          d = d - seg
     end
     local son = yol[#yol]
     return son, (yol[#yol] - yol[#yol - 1]):Angle().y, false, 0
end

-- yerleşim: konum, açı, sekans adı, yatıyor mu
local function Yerlesim(c)
     local v = c.v
     if (v.yol) then
          local pos, yaw, yurur, kalan = YolKonum(v)
          if (yurur) then return pos, Angle(0, yaw, 0), "walk_all", false, kalan end
          return pos, Angle(0, v.hedefYaw or yaw, 0), "idle_all_01", false, 0
     end
     local y = v.yatak > 0 and R.Yatak(v.yatak)
     if (y and v.poz == "yat") then
          local dir, yawH = R.YatakYon(y)
          local pos = y.bas - dir * 72
          pos.z = y.bas.z + 7
          return pos, Angle(-90, yawH + 180, 0), "idle_all_01", true
     end
     if (y and v.poz == "otur") then
          local dir, yawH = R.YatakYon(y)
          local pos = y.bas * 0.62 + y.ayak * 0.38
          pos.z = y.bas.z - 1
          return pos, Angle(0, yawH + 180, 0), "sit_zen", false
     end
     return v.pos, Angle(0, v.yaw, 0), "idle_all_01", false
end
R.AktorYerlesim = Yerlesim

--[[
*   belirti görselleri
]]

local function Manip(c, kemik, ang, olcek, konum)
     local ent = c.ent
     if (!kemik or kemik < 0) then return end
     if (ang) then ent:ManipulateBoneAngles(kemik, ang) end
     if (olcek) then ent:ManipulateBoneScale(kemik, olcek) end
     if (konum) then ent:ManipulateBonePosition(kemik, konum) end
     c.manip[kemik] = true
end

local SIFIR_A, BIR_V, SIFIR_V = Angle(0, 0, 0), Vector(1, 1, 1), Vector(0, 0, 0)

local function ManipSifirla(c)
     for kemik in pairs(c.manip) do
          c.ent:ManipulateBoneAngles(kemik, SIFIR_A)
          c.ent:ManipulateBoneScale(kemik, BIR_V)
          c.ent:ManipulateBonePosition(kemik, SIFIR_V)
     end
     c.manip = {}
end

-- kökün altındaki kemikler ve ebeveyne göre yerel konumları (ölçek çocuğa geçmez; alt ağacı büyütmek için
-- her çocuğa aynı ölçek + (s-1) x yerel konum gerekir)
local function AltAgac(ent, kok)
     local liste = {}
     if (!kok or kok < 0) then return liste end
     for i = 0, ent:GetBoneCount() - 1 do
          local p, ata = ent:GetBoneParent(i), false
          local derinlik = 0
          while (p and p >= 0 and derinlik < 64) do
               if (p == kok) then ata = true break end
               p = ent:GetBoneParent(p)
               derinlik = derinlik + 1
          end
          if (ata) then
               local Mc, Mp = ent:GetBoneMatrix(i), ent:GetBoneMatrix(ent:GetBoneParent(i))
               if (Mc and Mp) then
                    local yerel = WorldToLocal(Mc:GetTranslation(), Angle(), Mp:GetTranslation(), Mp:GetAngles())
                    liste[#liste + 1] = {i, yerel}
               end
          end
     end
     return liste
end

-- kafa: Head1 alt ağacı + saç zincirleri (bu modellerde saç Spine4'e bağlı). Saç kökü kafa merkezine göre
-- ölçeklenir: kayma = (s-1) x (saç - kafa), ebeveyn çerçevesinde.
local function KafaAgaci(ent, bas)
     local liste = AltAgac(ent, bas)
     local Mb = bas and bas >= 0 and ent:GetBoneMatrix(bas)
     if (!Mb) then return liste end
     local var = {}
     for _, d in ipairs(liste) do var[d[1]] = true end
     for i = 0, ent:GetBoneCount() - 1 do
          local ad = string.lower(ent:GetBoneName(i) or "")
          local p = ent:GetBoneParent(i)
          if (!var[i] and string.find(ad, "hair", 1, true) and p and p >= 0) then
               local Mi, Mp = ent:GetBoneMatrix(i), ent:GetBoneMatrix(p)
               if (Mi and Mp) then
                    local pAd = string.lower(ent:GetBoneName(p) or "")
                    local yerel
                    if (string.find(pAd, "hair", 1, true)) then
                         yerel = WorldToLocal(Mi:GetTranslation(), Angle(), Mp:GetTranslation(), Mp:GetAngles())
                    else
                         local fark = Mi:GetTranslation() - Mb:GetTranslation()
                         yerel = WorldToLocal(Mp:GetTranslation() + fark, Angle(), Mp:GetTranslation(), Mp:GetAngles())
                    end
                    liste[#liste + 1] = {i, yerel}
               end
          end
     end
     return liste
end

local function AgacOlcek(c, kok, alt, s)
     Manip(c, kok, nil, Vector(s, s, s))
     for _, d in ipairs(alt or {}) do Manip(c, d[1], nil, Vector(s, s, s), d[2] * (s - 1)) end
end

local function KemikEfekt(c, t)
     local v, k = c.v, c.kemik
     local e = v.efektler
     local m = 1 + v.siddet * 0.1
     ManipSifirla(c)
     if (e.kol_bukuk) then Manip(c, k.sagOn, Angle(25 * m, -55 * m, 35)) end
     if (e.kol_sarkik) then
          Manip(c, k.sagUst, Angle(0, 18 + 12 * math.sin(t * 1.3), 8 * math.sin(t * 0.9)))
          Manip(c, k.sagOn, Angle(0, 38 + 18 * math.sin(t * 1.7 + 1), 0))
     end
     if (e.el_buyuk and c.altAgac) then
          AgacOlcek(c, k.sagEl, c.altAgac.el, 2 + 0.15 * math.sin(t * 2) + v.siddet * 0.05)
     end
     if (e.bas_buyuk and c.altAgac) then
          AgacOlcek(c, k.bas, c.altAgac.bas, 1.55 + 0.05 * math.sin(t * 3) + v.siddet * 0.03)
     end
     if (e.bacak_dans) then
          local f = 9 + v.siddet * 0.5
          Manip(c, k.solUyluk, Angle(0, 28 * math.sin(t * f), 6 * math.sin(t * f * 0.5)))
          Manip(c, k.sagUyluk, Angle(0, 28 * math.sin(t * f + math.pi), -6 * math.sin(t * f * 0.5)))
          Manip(c, k.solBaldir, Angle(0, 35 * math.abs(math.sin(t * f + 0.6)), 0))
          Manip(c, k.sagBaldir, Angle(0, 35 * math.abs(math.sin(t * f + math.pi + 0.6)), 0))
     end
     if (e.titreme) then
          local a = 1.6 * m
          Manip(c, k.omurga, Angle(math.Rand(-a, a), math.Rand(-a, a), math.Rand(-a, a)))
     end
end

local function Renk(c)
     local e = c.v.efektler
     local r, g, b = 1, 1, 1
     if (e.ton_yesil) then r, g, b = r * 0.72, g * 1.0, b * 0.66 end
     if (e.ton_mavi) then r, g, b = r * 0.74, g * 0.84, b * 1.0 end
     if (e.benek_mor) then r, g, b = r * 0.98, g * 0.8, b * 0.98 end
     return r, g, b
end

local function KemikPos(c, kemik, ofs)
     if (!kemik or kemik < 0) then return c.cizPos + Vector(0, 0, 50) end
     local M = c.ent:GetBoneMatrix(kemik)
     if (!M) then return c.cizPos + Vector(0, 0, 50) end
     local p = M:GetTranslation()
     if (ofs) then p = p + M:GetForward() * ofs.x + M:GetRight() * ofs.y + M:GetUp() * ofs.z end
     return p
end

local function Parcacik(c, mat, pos, hiz, omur, bas, son, renk, yercekimi, alfa)
     c.em = c.em or ParticleEmitter(pos, false)
     if (!c.em) then return end
     c.em:SetPos(pos)
     local p = c.em:Add(mat, pos)
     if (!p) then return end
     p:SetVelocity(hiz)
     p:SetDieTime(omur)
     p:SetStartAlpha(alfa or 200)
     p:SetEndAlpha(0)
     p:SetStartSize(bas)
     p:SetEndSize(son)
     p:SetRoll(math.Rand(0, 360))
     p:SetRollDelta(math.Rand(-1, 1))
     p:SetColor(renk.r, renk.g, renk.b)
     p:SetGravity(yercekimi or vector_origin)
     p:SetAirResistance(40)
end

local function ParcacikEfekt(c, t, dt)
     local v, k = c.v, c.kemik
     local e = v.efektler
     c.sonP = c.sonP or {}
     local function Sik(ad, aralik)
          if ((c.sonP[ad] or 0) > t) then return false end
          c.sonP[ad] = t + aralik * math.Rand(0.7, 1.3) / (1 + v.siddet * 0.08)
          return true
     end
     local bas = KemikPos(c, k.bas)
     if (e.duman_bas and Sik("duman_bas", 0.16)) then
          for _, yan in ipairs({-5, 5}) do
               local p = KemikPos(c, k.bas, Vector(1, yan, 2))
               Parcacik(c, "particle/smokesprites_0001", p, VectorRand() * 4 + Vector(0, 0, 18), math.Rand(1, 1.8), 2, 9, Color(230, 230, 230), Vector(0, 0, 10), 90)
          end
     end
     if (e.kivilcim_bas and Sik("kivilcim", 1.4)) then
          local p = KemikPos(c, k.bas, Vector(6, 0, -2))
          for i = 1, 7 do
               Parcacik(c, "effects/spark", p, VectorRand() * 50 + Vector(0, 0, 25), math.Rand(0.3, 0.7), 1.5, 0, Color(255, 180, 90), Vector(0, 0, -300), 255)
          end
          Parcacik(c, "sprites/light_glow02_add", p, vector_origin, 0.3, 10, 0, Color(255, 150, 60), nil, 200)
          if (math.random() < 0.4) then sound.Play("ambient/energy/spark" .. math.random(1, 6) .. ".wav", p, 55, 130, 0.35) end
     end
     if (e.kabarcik_agiz and Sik("kabarcik", 0.35)) then
          local p = KemikPos(c, k.bas, Vector(7, 0, -3))
          Parcacik(c, "effects/bubble", p, VectorRand() * 6 + Vector(0, 0, 14), math.Rand(1.2, 2.2), math.Rand(1, 2.5), 0.5, Color(255, 255, 255), Vector(0, 0, 6), 230)
     end
     if (e.nefes_buz and Sik("nefes", 1.7)) then
          local p = KemikPos(c, k.bas, Vector(7, 0, -3))
          for i = 1, 6 do
               Parcacik(c, "particle/smokesprites_0001", p, (c.ent:GetForward() * 18 + VectorRand() * 5), math.Rand(0.8, 1.4), 1.5, 7, Color(220, 236, 255), Vector(0, 0, 4), 70)
          end
     end
     if (e.duman_kol and Sik("duman_kol", 0.25)) then
          local p = KemikPos(c, k.sagOn, Vector(6, 0, 0))
          Parcacik(c, "particle/smokesprites_0001", p, VectorRand() * 3 + Vector(0, 0, 14), math.Rand(1, 1.6), 1.5, 6, Color(150, 140, 130), Vector(0, 0, 8), 80)
     end
     if (e.kan and Sik("kan", 0.8)) then
          local p = KemikPos(c, k.omurga, Vector(math.Rand(-3, 3), math.Rand(-4, 4), 0))
          Parcacik(c, "sprites/light_glow02_add", p, Vector(0, 0, -6), 0.9, 2, 0.5, Color(170, 20, 20), Vector(0, 0, -60), 230)
     end
     if (e.pembe_bas and Sik("pembe", 0.5)) then
          local p = KemikPos(c, k.bas, Vector(4, 0, 2))
          Parcacik(c, "sprites/light_glow02_add", p + VectorRand() * 4, Vector(0, 0, 10), math.Rand(0.8, 1.4), 3, 0, Color(255, 120, 200), Vector(0, 0, 8), 200)
     end
     if (e.benek_mor and Sik("benek", 0.6)) then
          local p = KemikPos(c, k.bas, Vector(math.Rand(-2, 4), math.Rand(-5, 5), math.Rand(-6, 2)))
          Parcacik(c, "sprites/light_glow02_add", p, vector_origin, math.Rand(0.8, 1.5), 2.5, 1, Color(170, 80, 200), nil, 160)
     end
end

-- ara sıra ses
local function Ses(c, t)
     local v = c.v
     if (v.tur != "hasta" or v.poz != "yat") then return end
     c.sonSes = c.sonSes or (t + math.Rand(4, 12))
     if (t < c.sonSes) then return end
     c.sonSes = t + math.Rand(13, 28) / (1 + v.siddet * 0.1)
     local e = v.efektler
     if (e.bilincsiz) then return end
     local p = c.cizPos + Vector(0, 0, 10)
     local kiz = string.find(v.model, "kiz", 1, true) != nil or string.find(v.model, "student_f", 1, true) != nil
     if (e.kahkaha) then
          sound.Play("vo/ravenholm/madlaugh0" .. math.random(1, 4) .. ".wav", p, 60, kiz and 150 or 128, 0.45)
     elseif (e.kol_bukuk or e.kol_sarkik or e.duman_kol or e.kan or e.el_buyuk or e.bacak_dans or v.siddet > 4) then
          sound.Play("vo/npc/" .. (kiz and "female01" or "male01") .. "/moan0" .. math.random(1, 5) .. ".wav", p, 58, kiz and 108 or 112, 0.3)
     elseif (math.random() < 0.45) then
          sound.Play("ambient/voices/cough" .. math.random(1, 4) .. ".wav", p, 56, kiz and 125 or 108, 0.3)
     end
end

--[[
*   güncelleme
]]

local BAS_YUKSEK = Vector(0, 0, 62) -- 11-13 opt: baş bakışında karede yeni Vector yerine sabit (yalnız toplamada okunur)

local function Guncelle(c, dt, t, lp)
     local v = c.v
     if (!IsValid(c.ent) or c.yenidenKur) then ModelKur(c) end
     local ent = c.ent
     if (!IsValid(ent)) then return end

     local pos, ang, seqAd, yatiyor, kalan = Yerlesim(c)
     if (v.anim != "" and CurTime() - v.animBas < 2.5 and !v.yol) then seqAd = v.anim end
     local yurur = seqAd == "walk_all"

     -- süzülme
     if (v.efektler.suzulme and v.poz == "yat") then pos = pos + Vector(0, 0, 6 + 3 * math.sin(t * 1.6) + v.siddet * 0.4) end
     if (v.efektler.titreme) then pos = pos + VectorRand() * (0.25 + v.siddet * 0.04) end

     -- yön yumuşatma (yürürken)
     if (yurur) then
          c.yaw = math.ApproachAngle(c.yaw or ang.y, ang.y, dt * 260)
          ang = Angle(0, c.yaw, 0)
     else
          c.yaw = ang.y
     end
     c.cizPos, c.cizAng, c.yatiyor = pos, ang, yatiyor

     -- saydamlık
     local hedef = 1
     if (c.girisBas) then
          hedef = math.Clamp((RealTime() - c.girisBas) / 0.8, 0, 1)
          if (hedef >= 1) then c.girisBas = nil end
     end
     if (v.cikis and v.yol and kalan and kalan < 70) then hedef = math.Clamp(kalan / 70, 0, 1) end
     c.alfa = hedef

     -- sekans
     local seq = SekansOnb(c, ent, seqAd) -- 11-14 opt: önbellekli (SekansOnb)
     if (seq < 0) then seq = SekansOnb(c, ent, "idle_all_01") end
     if (seq >= 0) then
          if (c.seqAd != seqAd) then
               c.seqAd = seqAd
               c.cycle = 0
               local bilgi = ent:GetSequenceInfo(seq)
               c.dongulu = !bilgi or bit.band(bilgi.flags or 1, 1) == 1 or seqAd == "walk_all" or seqAd == "idle_all_01" or seqAd == "sit_zen"
          end
          ent:SetSequence(seq)
          ent:SetPoseParameter("move_y", 0)
          ent:SetPoseParameter("move_yaw", 0)
          local hiz = 1
          if (yurur) then
               ent:SetPoseParameter("move_x", 1)
               local yer = ent:GetSequenceGroundSpeed(seq) or 0
               if (yer > 5) then hiz = math.Clamp(v.hiz / yer, 0.4, 2.2) end
          else
               ent:SetPoseParameter("move_x", 0)
          end
          local sure = math.max(ent:SequenceDuration(seq), 0.05)
          c.cycle = c.cycle + dt * hiz / sure
          if (c.dongulu) then c.cycle = c.cycle % 1 else c.cycle = math.min(c.cycle, 0.999) end
          ent:SetCycle(c.cycle)
     end

     -- baş: yakındaki oyuncuya bakar (bilinçsizken bakmaz)
     if (c.basYaw) then
          local hy, hp = 0, 0
          local goz = lp:EyePos()
          if (!v.efektler.bilincsiz and pos:DistToSqr(goz) < 280 * 280 and !yurur) then
               local basPos = c.yatiyor and (pos + ang:Up() * 64) or (pos + BAS_YUKSEK) -- 11-13 opt: sabit ofset
               local a = (goz - basPos):Angle()
               if (c.yatiyor) then
                    -- yatarken başın "yukarısı" gövde ekseni; yana dönüş = yönün yatağa göre sağ/sol bileşeni
                    local yerel = WorldToLocal(goz, SIFIR_A, basPos, ang) -- 11-13 opt: Angle() yerine dosyadaki sıfır açı sabiti
                    hy = math.Clamp(math.deg(math.atan2(yerel.y, yerel.x)), -55, 55)
               else
                    hy = math.Clamp(math.AngleDifference(a.y, ang.y), -60, 60)
                    hp = math.Clamp(math.NormalizeAngle(a.p), -30, 30)
               end
          end
          c.basY = Lerp(math.min(1, dt * 4), c.basY or 0, hy)
          c.basP = Lerp(math.min(1, dt * 4), c.basP or 0, hp)
          ent:SetPoseParameter("head_yaw", c.basY)
          if (c.basPitch) then ent:SetPoseParameter("head_pitch", c.basP) end
     end

     ent:SetPos(pos)
     ent:SetAngles(ang)
     if (v.tur == "hasta") then
          if (!c.altAgac and ent:GetBoneCount() > 0 and (v.efektler.bas_buyuk or v.efektler.el_buyuk)) then
               ent:SetupBones()
               c.altAgac = {bas = KafaAgaci(ent, c.kemik.bas), el = AltAgac(ent, c.kemik.sagEl)}
          end
          KemikEfekt(c, t)
     end
     ent:InvalidateBoneCache()
     ent:SetupBones()
     if (v.tur == "hasta" and c.alfa > 0.5 and pos:DistToSqr(lp:GetPos()) < 1500 * 1500) then
          ParcacikEfekt(c, t, dt)
          Ses(c, t)
     end
end

-- revirin yakınında mıyız (uzakta hiçbir şey kurulmaz/çizilmez)
-- 11-14 opt: kutunun merkezi kutu tablosu ve min/max vektörleri (kimlik, rawequal) başına önbellekte. R.Harita her
-- güncellemede R.HaritaCoz ile yeni tablo ve yeni vektörlerle gelir; istemcide kutu.min/max hiç yerinde değiştirilmez.
-- Aynı girdi, aynı hesap: merkez aynı. Bu kare başı iki Vector ayırması (Think + HUD + bakış) kalkar.
local yakinKutu, yakinMin, yakinMax, yakinMerkez
local function Yakin(lp)
     local h = R.Harita
     if (!h) then return false end
     if (R.YakinZorla) then return true end -- sınama: uzaktan sabit kamerayla görüntü almak için
     local k = h.kutu
     if (!rawequal(yakinKutu, k) or !rawequal(yakinMin, k.min) or !rawequal(yakinMax, k.max)) then
          yakinMerkez = (k.min + k.max) / 2
          yakinKutu, yakinMin, yakinMax = k, k.min, k.max
     end
     return lp:GetPos():DistToSqr(yakinMerkez) < 3200 * 3200
end
R.RevirYakin = Yakin

hook.Add("Think", "SardonRevir.Aktorler", function()
     local lp = LocalPlayer()
     if (!IsValid(lp)) then return end
     local yakin = Yakin(lp)
     local t = CurTime()
     local dt = math.min(FrameTime(), 0.1)
     for id, c in pairs(R.CA) do
          if (!yakin or c.v.gizli) then
               if (IsValid(c.ent)) then Sil(c) c.ent = nil end
          else
               Guncelle(c, dt, t, lp)
          end
     end
end)

--[[
*   çizim
]]

local function KalintiCiz(c, t)
     local v = c.v
     if (v.kalinti == "" or CurTime() > v.kalintiBitis) then return end
     local k = R.Kalintilar[v.kalinti]
     if (!k) then return end
     local kalan = v.kalintiBitis - CurTime()
     local a = math.Clamp(kalan / 4, 0, 1)
     local merkez = c.yatiyor and (c.cizPos + c.cizAng:Up() * 34 + Vector(0, 0, 6)) or (c.cizPos + Vector(0, 0, 36))
     local col = k.renk
     render.SetMaterial(M.isik)
     render.DrawSprite(merkez, 90 + 10 * math.sin(t * 2), 70, Color(col.r, col.g, col.b, 90 * a))
     render.SetMaterial(M.halka)
     render.DrawQuadEasy(merkez - Vector(0, 0, 14), Vector(0, 0, 1), 110, 110, Color(col.r, col.g, col.b, 140 * a), (t * 30) % 360)
     render.DrawQuadEasy(merkez - Vector(0, 0, 14), Vector(0, 0, 1), 80, 80, Color(col.r, col.g, col.b, 90 * a), -(t * 45) % 360)
     c.sonK = c.sonK or 0
     if (t > c.sonK) then
          c.sonK = t + 0.08
          Parcacik(c, "sprites/light_glow02_add", merkez + VectorRand() * 30, Vector(0, 0, math.Rand(8, 22)), math.Rand(0.8, 1.6), math.Rand(2, 4), 0, col, nil, 220 * a)
     end
end

local function BilincsizCiz(c, t)
     if (!c.v.efektler.bilincsiz or !c.yatiyor) then return end
     local bas = KemikPos(c, c.kemik.bas, Vector(0, 0, 9))
     render.SetMaterial(M.isik)
     for i = 0, 2 do
          local a = t * 2.2 + i * 2.094
          local p = bas + Vector(math.cos(a) * 9, math.sin(a) * 9, 4 + math.sin(t * 3 + i) * 1.5)
          render.DrawSprite(p, 4, 4, Color(255, 240, 180, 200))
     end
end

local function AktorCiz(c)
     local ent = c.ent
     if (!IsValid(ent) or c.alfa <= 0.01) then return end
     local r, g, b = Renk(c)
     render.SetColorModulation(r, g, b)
     if (c.alfa < 1) then render.SetBlend(c.alfa) end
     ent:DrawModel()
     if (ent.sogS and SardonOgrenci and SardonOgrenci.ParcaCiz) then SardonOgrenci.ParcaCiz(ent) end
     render.SetBlend(1)
     render.SetColorModulation(1, 1, 1)
end

hook.Add("PostDrawOpaqueRenderables", "SardonRevir.Aktorler", function(derinlik, gok)
     if (gok or derinlik) then return end
     for _, c in pairs(R.CA) do
          if (IsValid(c.ent) and !c.v.gizli) then AktorCiz(c) end
     end
end)

--[[
*   Accio ile uçan eşya
]]

net.Receive("SardonRevir.Accio", function()
     local no = net.ReadUInt(4)
     local n = net.ReadUInt(6)
     local yol = {}
     for i = 1, n do yol[i] = net.ReadVector() end
     local sure = net.ReadFloat()
     local caster = net.ReadEntity()
     local e = R.Esyalar[no]
     if (!e or n < 2) then return end
     local L = 0
     for i = 2, n do L = L + yol[i - 1]:Distance(yol[i]) end
     local m = ModelVar(e.model) and e.model or "models/props_junk/PopCan01a.mdl"
     local ent = ClientsideModel(m, RENDERGROUP_OPAQUE)
     if (IsValid(ent)) then
          ent:SetModelScale(e.olcek or 1, 0)
          ent:SetNoDraw(false)
     end
     R.Ucanlar[#R.Ucanlar + 1] = {e = e, yol = yol, L = L, bas = CurTime(), sure = sure, ent = ent}
     sound.Play("hpwrewrite/spells/hillium.wav", yol[1], 60, 170, 0.3)
     if (IsValid(caster) and caster == LocalPlayer()) then surface.PlaySound("weapons/physcannon/physcannon_pickup.wav") end
end)

local function UcanKonum(u, f)
     local d = u.L * f
     for i = 2, #u.yol do
          local seg = u.yol[i - 1]:Distance(u.yol[i])
          if (d <= seg) then return LerpVector(seg > 0 and d / seg or 1, u.yol[i - 1], u.yol[i]) end
          d = d - seg
     end
     return u.yol[#u.yol]
end

hook.Add("Think", "SardonRevir.Ucanlar", function()
     if (#R.Ucanlar == 0) then return end
     local t = CurTime()
     for i = #R.Ucanlar, 1, -1 do
          local u = R.Ucanlar[i]
          local f = math.Clamp((t - u.bas) / u.sure, 0, 1)
          local ease = f * f * (3 - 2 * f)
          local p = UcanKonum(u, ease) + Vector(0, 0, math.sin(f * math.pi) * 18)
          if (IsValid(u.ent)) then
               u.ent:SetPos(p)
               u.ent:SetAngles(Angle(t * 140 % 360, t * 220 % 360, 0))
          end
          u.em = u.em or ParticleEmitter(p, false)
          if (u.em) then
               local pr = u.em:Add("sprites/light_glow02_add", p)
               if (pr) then
                    pr:SetDieTime(0.6)
                    pr:SetStartAlpha(200)
                    pr:SetEndAlpha(0)
                    pr:SetStartSize(5)
                    pr:SetEndSize(0)
                    pr:SetColor(u.e.renk.r, u.e.renk.g, u.e.renk.b)
                    pr:SetVelocity(VectorRand() * 6)
               end
          end
          if (f >= 1) then
               if (IsValid(u.ent)) then u.ent:Remove() end
               if (u.em) then
                    for k = 1, 22 do
                         local pr = u.em:Add("sprites/light_glow02_add", p)
                         if (pr) then
                              pr:SetDieTime(math.Rand(0.5, 1.1))
                              pr:SetStartAlpha(255)
                              pr:SetEndAlpha(0)
                              pr:SetStartSize(math.Rand(2, 5))
                              pr:SetEndSize(0)
                              pr:SetColor(u.e.renk.r, u.e.renk.g, u.e.renk.b)
                              pr:SetVelocity(VectorRand() * 70)
                              pr:SetGravity(Vector(0, 0, -60))
                         end
                    end
                    u.em:Finish()
               end
               sound.Play("ambient/levels/citadel/weapon_disintegrate" .. math.random(1, 4) .. ".wav", p, 55, 180, 0.25)
               table.remove(R.Ucanlar, i)
          end
     end
end)

--[[
*   dünya efektleri
]]

local efektler = {}

local function Patlat(pos, renk, n, hiz, mat, boyut, yercekimi)
     if (SA and SA.Patlat3D and !mat) then return SA.Patlat3D(pos, renk, n, hiz, nil, boyut) end
     local em = ParticleEmitter(pos, false)
     if (!em) then return end
     for i = 1, n do
          local p = em:Add(mat or "sprites/light_glow02_add", pos + VectorRand() * 4)
          if (p) then
               local v = VectorRand()
               v.z = math.abs(v.z) * 0.6 + 0.2
               p:SetVelocity(v * math.Rand(0.4, 1) * (hiz or 120))
               p:SetGravity(yercekimi or Vector(0, 0, -40))
               p:SetAirResistance(60)
               p:SetDieTime(math.Rand(0.8, 1.8))
               p:SetStartAlpha(220)
               p:SetEndAlpha(0)
               p:SetStartSize(math.Rand(2, boyut or 6))
               p:SetEndSize(mat and (boyut or 6) * 2 or 0)
               p:SetRoll(math.Rand(0, 360))
               p:SetColor(renk.r, renk.g, renk.b)
          end
     end
     em:Finish()
end

local function Yukselen(pos, renk, n, yaricap)
     local em = ParticleEmitter(pos, false)
     if (!em) then return end
     for i = 1, n do
          local a = math.Rand(0, math.pi * 2)
          local r = math.Rand(0, yaricap or 30)
          local p = em:Add("sprites/light_glow02_add", pos + Vector(math.cos(a) * r, math.sin(a) * r, math.Rand(-10, 10)))
          if (p) then
               p:SetVelocity(Vector(0, 0, math.Rand(20, 60)))
               p:SetDieTime(math.Rand(1.2, 2.6))
               p:SetStartAlpha(255)
               p:SetEndAlpha(0)
               p:SetStartSize(math.Rand(2, 5))
               p:SetEndSize(0)
               p:SetColor(renk.r, renk.g, renk.b)
               p:SetAirResistance(20)
          end
     end
     em:Finish()
end

net.Receive("SardonRevir.Efekt", function()
     local tur = net.ReadString()
     local pos = net.ReadVector()
     local renk = net.ReadColor(false)
     local ek = net.ReadString()
     local lp = LocalPlayer()
     if (!IsValid(lp) or lp:GetPos():DistToSqr(pos) > 3000 * 3000) then return end
     local t = RealTime()

     if (tur == "buyu") then
          Patlat(pos + Vector(0, 0, 14), renk, 40, 110)
          Yukselen(pos + Vector(0, 0, 4), renk, 30, 34)
          efektler[#efektler + 1] = {tur = "halka", pos = pos + Vector(0, 0, 2), renk = renk, bas = t, sure = 1.2, boy = 160}
          sound.Play("hpwrewrite/spells/hillium.wav", pos, 66, 120, 0.55)
     elseif (tur == "iyilesti") then
          Yukselen(pos, Color(255, 236, 170), 70, 40)
          Yukselen(pos, renk, 40, 30)
          efektler[#efektler + 1] = {tur = "halka", pos = pos + Vector(0, 0, 2), renk = Color(255, 230, 160), bas = t, sure = 2, boy = 220}
          efektler[#efektler + 1] = {tur = "sutun", pos = pos, renk = Color(255, 236, 180), bas = t, sure = 1.6}
          sound.Play("ambient/energy/whiteflash.wav", pos, 70, 150, 0.5)
          sound.Play("hpwrewrite/spells/hillium.wav", pos, 70, 100, 0.6)
     elseif (tur == "pomfrey") then
          Yukselen(pos, renk, 80, 40)
          efektler[#efektler + 1] = {tur = "halka", pos = pos + Vector(0, 0, 2), renk = renk, bas = t, sure = 2, boy = 200}
          sound.Play("hpwrewrite/spells/hillium.wav", pos, 70, 90, 0.6)
     elseif (tur == "yanlis") then
          Patlat(pos + Vector(0, 0, 18), Color(110, 90, 120), 16, 50, "particle/smokesprites_0001", 10, Vector(0, 0, 20))
          Patlat(pos + Vector(0, 0, 18), Color(170, 60, 60), 18, 90)
          sound.Play("ambient/levels/labs/electric_explosion" .. math.random(1, 5) .. ".wav", pos, 60, 160, 0.35)
     elseif (tur == "koruma") then
          efektler[#efektler + 1] = {tur = "halka", pos = pos + Vector(0, 0, 30), renk = renk, bas = t, sure = 1, boy = 120, dik = true}
          sound.Play("ambient/energy/zap" .. math.random(1, 3) .. ".wav", pos, 60, 170, 0.4)
     elseif (tur == "tutmadi") then
          Patlat(pos, renk, 14, 60)
          Patlat(pos, Color(120, 110, 100), 8, 30, "particle/smokesprites_0001", 6, Vector(0, 0, 15))
          sound.Play("ambient/fire/ignite.wav", pos, 60, 140, 0.3)
     elseif (tur == "dagildi") then
          Patlat(pos, renk, 10, 40, "particle/smokesprites_0001", 6, Vector(0, 0, 10))
     elseif (tur == "tara") then
          efektler[#efektler + 1] = {tur = "tarama", pos = pos, renk = renk, bas = t, sure = 1.3}
          sound.Play("ambient/levels/citadel/strange_talk" .. math.random(3, 9) .. ".wav", pos, 60, 140, 0.35)
     elseif (tur == "muayene") then
          sound.Play("physics/cardboard/cardboard_box_impact_soft" .. math.random(1, 7) .. ".wav", pos, 55, 110, 0.3)
     elseif (tur == "esya") then
          Yukselen(pos, renk, 30, 24)
     elseif (tur == "ogrendi") then
          Yukselen(pos, renk, 90, 30)
          efektler[#efektler + 1] = {tur = "halka", pos = pos - Vector(0, 0, 38), renk = renk, bas = t, sure = 2.4, boy = 240}
          sound.Play("ambient/energy/whiteflash.wav", pos, 75, 120, 0.6)
     end
end)

hook.Add("PostDrawTranslucentRenderables", "SardonRevir.Dunya", function(derinlik, gok)
     if (gok) then return end
     local t = CurTime()
     for _, c in pairs(R.CA) do
          if (IsValid(c.ent) and !c.v.gizli and c.cizPos) then
               KalintiCiz(c, t)
               BilincsizCiz(c, t)
          end
     end
     local rt = RealTime()
     for i = #efektler, 1, -1 do
          local e = efektler[i]
          local f = (rt - e.bas) / e.sure
          if (f >= 1) then
               table.remove(efektler, i)
          elseif (e.tur == "halka") then
               render.SetMaterial(M.dalga)
               local boy = e.boy * (0.2 + f)
               local nrm = e.dik and (EyePos() - e.pos):GetNormalized() or Vector(0, 0, 1)
               render.DrawQuadEasy(e.pos, nrm, boy, boy, Color(e.renk.r, e.renk.g, e.renk.b, 230 * (1 - f)), 0)
          elseif (e.tur == "sutun") then
               render.SetMaterial(M.isik)
               local a = 200 * math.sin(f * math.pi)
               for k = 0, 5 do
                    render.DrawSprite(e.pos + Vector(0, 0, k * 14), 60 - k * 6, 60 - k * 6, Color(e.renk.r, e.renk.g, e.renk.b, a))
               end
          elseif (e.tur == "tarama") then
               -- aşağıdan yukarı tarayan halka
               render.SetMaterial(M.keskin)
               local z = -20 + f * 70
               render.DrawQuadEasy(e.pos + Vector(0, 0, z), Vector(0, 0, 1), 90, 90, Color(e.renk.r, e.renk.g, e.renk.b, 200 * (1 - f)), 0)
               render.DrawQuadEasy(e.pos + Vector(0, 0, z), Vector(0, 0, -1), 90, 90, Color(e.renk.r, e.renk.g, e.renk.b, 200 * (1 - f)), 0)
          end
     end
end)

--[[
*   masadaki defter (yakındayken kurulur): masanın üstünde süzülen açık kitap.
*   Hep hafifçe parlar; nöbette biraz, bakınca (E) tam parlar.
]]

local DEFTER = {
     model = "models/sbs/hogwarts/wu/hwm_bigbook_open.mdl", olcek = 0.7,
     yuk = 8, egim = -24,          -- masadan yükseklik, okuyana doğru eğim (eksi = uzak kenar yukarı)
     renk = Color(255, 214, 140),
     isik = 47011                  -- DynamicLight sırası
}

if (IsValid(R.DefterEnt)) then R.DefterEnt:Remove() R.DefterEnt = nil end -- canlı yenilemede yeniden kurulsun

local defterModel
local function DefterModeli()
     if (defterModel) then return defterModel end
     for _, m in ipairs({DEFTER.model, "models/hpwrewrite/books/book2.mdl", "models/props_lab/bindergreen.mdl"}) do
          if (file.Exists(m, "GAME")) then defterModel = m break end
     end
     defterModel = defterModel or "models/props_lab/bindergreen.mdl"
     return defterModel
end

-- kendi ışığıyla çizilir: sayfalar sıcak, parlaklıkla birlikte açılır
local function DefterCiz(self)
     local g = R.DefterParlak or 0
     render.SuppressEngineLighting(true)
     render.ResetModelLighting(0.42 + 0.2 * g, 0.38 + 0.18 * g, 0.3 + 0.12 * g)
     render.SetModelLighting(BOX_TOP, 1.2 + 0.6 * g, 1.08 + 0.52 * g, 0.84 + 0.34 * g)
     render.SetModelLighting(BOX_LEFT, 0.8 + 0.3 * g, 0.72 + 0.26 * g, 0.56 + 0.2 * g)
     self:DrawModel()
     render.SuppressEngineLighting(false)
     -- ışık katmanı: aynı model sıcak renkte toplamalı yeniden çizilir, sayfalar ışık saçar
     -- (opak malzemede SetBlend işlemez; yoğunluk renk çarpanıyla)
     local k = 0.2 + 0.75 * g + 0.06 * math.sin(CurTime() * 2.2)
     render.OverrideBlend(true, BLEND_ONE, BLEND_ONE, BLENDFUNC_ADD)
     render.SetColorModulation(k, k * 0.84, k * 0.52)
     self:DrawModel()
     render.SetColorModulation(1, 1, 1)
     render.OverrideBlend(false)
end

local DEFTER_UST = Vector(0, 0, 1) -- 11-13 opt: HL kitabı ekseninde karede yeni Vector yerine sabit (yalnız çarpılır)

hook.Add("Think", "SardonRevir.Defter", function()
     local lp = LocalPlayer()
     local h = R.Harita
     if (!IsValid(lp) or !h) then return end
     local uzak = lp:GetPos():DistToSqr(h.defter.pos)
     if (uzak < 1800 * 1800 and !IsValid(R.DefterEnt)) then
          -- 11-05: açık Şifacılık Kitabı (St_prop3, [sardon] anims SardonKitapAnim); yoksa eski büyük kitap
          local KA = SardonKitapAnim
          local e
          if (KA and KA.KitapYap) then
               KA.Hazirla("medical_book")
               e = KA.KitapYap("medical_book")
               if (IsValid(e)) then
                    e:SetNoDraw(false)
                    e.skaHL = true
               end
          end
          if (!IsValid(e)) then
               e = ClientsideModel(DefterModeli(), RENDERGROUP_OPAQUE)
               if (IsValid(e) and DefterModeli() == DEFTER.model) then e:SetModelScale(DEFTER.olcek) end
          end
          if (IsValid(e)) then
               e.RenderOverride = DefterCiz
               R.DefterEnt = e
          end
     elseif (uzak >= 1800 * 1800 and IsValid(R.DefterEnt)) then
          R.DefterEnt:Remove()
          R.DefterEnt = nil
     end
     local e = R.DefterEnt
     if (!IsValid(e)) then return end

     local b = R.Bakilan and R.Bakilan()
     local hedef = (b and b.tur == "defter") and 1 or (R.Nobet and 0.5 or 0.25)
     R.DefterParlak = Lerp(math.min(1, FrameTime() * 5), R.DefterParlak or 0, hedef)

     local t = CurTime()
     if (e.skaHL) then
          -- HL kitabı Binding_Center çerçevesiyle: sayfalar yukarı ve okuyana 24° eğik, başı okuyandan uzakta
          local KA = SardonKitapAnim
          local ya = Angle(0, h.defter.yaw, 0)
          local F, Rv = ya:Forward(), ya:Right()
          local eg = math.rad(24 + math.sin(t * 0.9) * 1.5)
          local Y = DEFTER_UST * math.cos(eg) - F * math.sin(eg) -- 11-13 opt: sabit eksen
          local Z = Rv:Cross(Y)
          local pos = h.defter.pos + Vector(0, 0, DEFTER.yuk + 4 + math.sin(t * 1.4) * 1.1)
          KA.Poz(e, "dongu", 0)
          if (!KA.Yerlestir(e, pos, Rv:AngleEx(Z), 0.9)) then e:SetPos(pos) end
     else
          -- yaw = okuyanın baktığı yön (Yerleşim'de masaya bakarak kaydedilen); kitap modeli buna 90° dik durur
          local ang = Angle(0, h.defter.yaw + 90, 0)
          ang:RotateAroundAxis(ang:Forward(), DEFTER.egim + math.sin(t * 0.9) * 1.5)
          e:SetPos(h.defter.pos + Vector(0, 0, DEFTER.yuk + math.sin(t * 1.4) * 1.1))
          e:SetAngles(ang)
     end

     if (uzak < 900 * 900) then
          local dl = DynamicLight(DEFTER.isik)
          if (dl) then
               local g = R.DefterParlak
               dl.pos = h.defter.pos + Vector(0, 0, DEFTER.yuk + 12)
               dl.r, dl.g, dl.b = DEFTER.renk.r, DEFTER.renk.g, DEFTER.renk.b
               dl.brightness = 0.5 + 1.2 * g
               dl.decay = 600
               dl.size = 90 + 60 * g
               dl.dietime = t + 0.25
          end
     end
end)

-- 11-13 opt: karede yeni Vector/Color yerine sabit ofsetler ve tek geçici renk. render.DrawQuadEasy/DrawSprite rengi
-- çağrı anında okur, saklamaz; alanlar her çağrıdan hemen önce Color() ile aynı biçimde (üst sınır 255) kurulur.
local MASA_OFS, HARE_OFS = Vector(0, 0, 0.4), Vector(0, 0, 5)
local isikRenk = Color(255, 255, 255)

hook.Add("PostDrawTranslucentRenderables", "SardonRevir.DefterIsik", function(derinlik, gok)
     local e = R.DefterEnt
     if (gok or derinlik or !IsValid(e) or !R.Harita) then return end
     local g = R.DefterParlak or 0
     local t = CurTime()
     local rk = DEFTER.renk
     local masa = R.Harita.defter.pos + MASA_OFS
     local p = e:GetPos() + HARE_OFS

     -- masaya vuran ışık + yavaş dönen halka
     render.SetMaterial(M.isik)
     isikRenk.r, isikRenk.g, isikRenk.b, isikRenk.a = rk.r, rk.g, rk.b, math.min(45 + 75 * g, 255)
     render.DrawQuadEasy(masa, vector_up, 52 + 10 * g, 44 + 8 * g, isikRenk, 0)
     render.SetMaterial(M.halka)
     isikRenk.r, isikRenk.g, isikRenk.b, isikRenk.a = rk.r, rk.g, rk.b, math.min(30 + 70 * g, 255)
     render.DrawQuadEasy(masa, vector_up, 32 + 6 * g, 32 + 6 * g, isikRenk, t * 12 % 360)

     -- kitabın haresi
     render.SetMaterial(M.isik)
     isikRenk.r, isikRenk.g, isikRenk.b, isikRenk.a = rk.r, rk.g, rk.b, math.min(70 + 110 * g, 255)
     render.DrawSprite(p, 60 + 24 * g + 5 * math.sin(t * 2), 44 + 16 * g, isikRenk)

     -- sayfalardan yükselen zerreler
     for i = 1, 12 do
          local f = (t * 0.3 + i / 12) % 1
          local a = i * 2.4 + t * 0.6
          local r = 9 * (1 - f * 0.5)
          local s = math.sin(f * math.pi)
          local q = p + Vector(math.cos(a) * r, math.sin(a) * r * 0.7, 2 + f * 30)
          isikRenk.r, isikRenk.g, isikRenk.b, isikRenk.a = 255, 236, 190, math.min(230 * s * (0.45 + 0.55 * g), 255)
          render.DrawSprite(q, (2 + 1.6 * g) * s, (2 + 1.6 * g) * s, isikRenk)
     end
end)

--[[
*   konuşma balonları
]]

net.Receive("SardonRevir.Soz", function()
     local id = net.ReadUInt(16)
     local metin = net.ReadString()
     local sure = net.ReadFloat()
     local sahip = net.ReadUInt(16)
     R.Balon[id] = {metin = metin, bitis = RealTime() + sure, bas = RealTime(), sahip = sahip}
end)

function R.AktorBasPos(c)
     if (!c or !c.cizPos) then return nil end
     if (IsValid(c.ent) and c.kemik and c.kemik.bas and c.kemik.bas >= 0) then
          local M = c.ent:GetBoneMatrix(c.kemik.bas)
          if (M) then return M:GetTranslation() + Vector(0, 0, c.yatiyor and 16 or 14) end
     end
     return c.cizPos + Vector(0, 0, c.yatiyor and 30 or 78)
end

-- Balonlar cl_6hud'un HUDPaint'inde çizilir (R.BalonlariCiz)
function R.BalonlariCiz()
     local lp = LocalPlayer()
     local now = RealTime()
     R.Fontlar()
     for id, b in pairs(R.Balon) do
          local c = R.CA[id]
          if (now > b.bitis or !c) then
               R.Balon[id] = nil
          elseif (!(R.Diy and R.Diy.aktor == id) and c.cizPos and !c.v.gizli) then
               local pos = R.AktorBasPos(c)
               local mesafe = pos:Distance(lp:EyePos())
               if (mesafe < 900) then
                    local sp = pos:ToScreen()
                    if (sp.visible) then
                         local a = math.Clamp((now - b.bas) / 0.25, 0, 1) * math.Clamp((b.bitis - now) / 0.4, 0, 1) * math.Clamp((900 - mesafe) / 250, 0, 1)
                         local satirlar = R.Sar(b.metin, "balon", 300)
                         local w = 0
                         for _, s in ipairs(satirlar) do w = math.max(w, R.YaziG(s, "balon")) end
                         w = w + 24
                         local h = #satirlar * 18 + 16
                         local x, y = sp.x - w / 2, sp.y - h - 10
                         draw.RoundedBox(8, x, y, w, h, Color(14, 20, 18, 220 * a))
                         surface.SetDrawColor(R.C.altinK.r, R.C.altinK.g, R.C.altinK.b, 120 * a)
                         surface.DrawOutlinedRect(x, y, w, h, 1)
                         draw.NoTexture()
                         surface.SetDrawColor(14, 20, 18, 220 * a)
                         surface.DrawPoly({{x = sp.x - 7, y = y + h}, {x = sp.x + 7, y = y + h}, {x = sp.x, y = y + h + 8}})
                         for i, s in ipairs(satirlar) do
                              R.Yazi(s, "balon", sp.x, y + 8 + (i - 1) * 18, R.C.fildisi, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 255 * a)
                         end
                    end
               end
          end
     end
end
