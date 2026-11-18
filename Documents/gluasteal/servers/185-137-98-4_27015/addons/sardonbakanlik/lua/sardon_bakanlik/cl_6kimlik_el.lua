-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\cl_6kimlik_el.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sicil Defteri :: kimliğini gösterenin elinde 3B kart.
--
-- Sunucu gösterimde yakındakilere "SardonBakanlik.KimlikEl" yollar (gösteren, karşısındaki, süre, kartın yüzü).
--   kol      HL "Çiçek Uzat" (A_M_OfferFlower_Idle_OK) duruşunun kol kemiklerinin yerel açıları modelden bir kez
--            okunur; BuildBonePositions'ta öndeki kolun köprücük kemiğinden aşağısı bu açılara geçirilir
--            (0,35 sn ağırlıkla). Yürürken kol gövdeyle gider, duruşu korur. Sekansı olmayan modelde kol değişmez.
--   kart     başparmakla işaret parmağının arasında, alt kenarından tutulur; yüzü karşısındakine (yoksa öne)
--            dönük. Ön yüz kartın kendisidir: 512x320 RT'ye portresiyle bir kez pişer (4 yuva). Arka yüz genel.
--   asa      kart sağ eldeyse elde tutulan asa gösterim boyunca görünmez (kitap okuma gibi)
-- Boşta kanca yok: Think / PostPlayerDraw yalnız gösteren varken eklenir.

local B = SardonBakanlik
local K = B.Kimlik

local KART_W, KART_H = 7.2, 4.2   -- SHINE kompakt kart 600x350
local POZ_SEKANS, POZ_CYC = "A_M_OfferFlower_Idle_OK", 0.5
local GECIS = 0.35
local Kolay = B.UI.Kolay

-- dosya yenilenince eski geri çağrılar kalmasın
for ply, d in pairs(K.El or {}) do
     if IsValid(ply) and d.cb then ply:RemoveCallback("BuildBonePositions", d.cb) end
     if IsValid(d.silah) then d.silah:SetNoDraw(false) end
end
K.El = {}
local aktif = K.El

----------------------------------------------------------------------------------------
-- Kol duruşu
----------------------------------------------------------------------------------------
local pozlar = {} -- model -> {taraf, kemikler = {{i, par, aci}}} | false

local function PozHesapla(model)
     local p = pozlar[model]
     if p ~= nil then return p or nil end
     pozlar[model] = false

     local e = ClientsideModel(model, RENDERGROUP_OPAQUE)
     if not IsValid(e) then return nil end
     e:SetNoDraw(true)
     e:SetPos(vector_origin)
     e:SetAngles(angle_zero)
     local q = e:LookupSequence(POZ_SEKANS)
     if q < 0 then e:Remove() return nil end
     e:ResetSequence(q)
     e:SetSequence(q)
     e:SetCycle(POZ_CYC)
     e:InvalidateBoneCache()
     e:SetupBones()

     -- hangi el önde (model +X'e bakar)
     local function X(ad)
          local b = e:LookupBone(ad)
          local m = b and e:GetBoneMatrix(b)
          return m and m:GetTranslation().x or -1e9
     end
     local taraf = X("ValveBiped.Bip01_R_Hand") >= X("ValveBiped.Bip01_L_Hand") and "R" or "L"
     local kok = e:LookupBone("ValveBiped.Bip01_" .. taraf .. "_Clavicle") or e:LookupBone("ValveBiped.Bip01_" .. taraf .. "_UpperArm")
     if not kok then e:Remove() return nil end

     local kemikler = {}
     for i = 0, e:GetBoneCount() - 1 do
          local p0, altinda = i, false
          while p0 and p0 >= 0 do
               if p0 == kok then altinda = true break end
               p0 = e:GetBoneParent(p0)
          end
          if altinda then
               local par = e:GetBoneParent(i)
               local mi = e:GetBoneMatrix(i)
               local mp = par and par >= 0 and e:GetBoneMatrix(par)
               local ters = mp and mp:GetInverse()
               if mi and ters then kemikler[#kemikler + 1] = {i = i, par = par, aci = (ters * mi):GetAngles()} end
          end
     end
     e:Remove()
     if #kemikler == 0 then return nil end

     p = {taraf = taraf, kemikler = kemikler}
     pozlar[model] = p
     return p
end

local function KemikKur(ply)
     local d = aktif[ply]
     if not d or not d.poz or (d.agirlik or 0) <= 0.001 then return end
     local w = Kolay(d.agirlik)

     local orj = {}
     for _, k in ipairs(d.poz.kemikler) do
          orj[k.i] = ply:GetBoneMatrix(k.i)
          if orj[k.par] == nil then orj[k.par] = ply:GetBoneMatrix(k.par) or false end
     end

     local yeni = {}
     for _, k in ipairs(d.poz.kemikler) do
          local mi, mp = orj[k.i], orj[k.par]
          local ters = mp and mp:GetInverse()
          if mi and ters then
               local yerel = ters * mi
               local m = Matrix()
               m:SetAngles(LerpAngle(w, yerel:GetAngles(), k.aci))
               m:SetTranslation(yerel:GetTranslation())
               local son = (yeni[k.par] or mp) * m
               ply:SetBoneMatrix(k.i, son)
               yeni[k.i] = son
          end
     end
end

----------------------------------------------------------------------------------------
-- Kart yüzü yuvaları (512x320) ve portre pişirme
----------------------------------------------------------------------------------------
local yuvalar = {}
for i = 1, 4 do yuvalar[i] = {no = i, son = 0} end

local function KartPisir(yuva, kart)
     -- model ve kemikler çizim bağlamı dışında hazırlanır (çizimde SetCycle kemiğe yansımıyor)
     local ent = K.PortreModel(kart.gorunum)
     local anahtar = yuva.anahtar
     K.IsEkle(function()
          if yuva.anahtar ~= anahtar then return K.PortreSil(ent) end
          K.TamPisir(yuva.t, kart, false, ent)
          yuva.hazir = true
     end)
end

-- Elde görünen genel arka yüz (kişiye özel bilgi yok): bir kez pişer
local arka
local function ArkaYuz()
     if arka then return arka.hazir and arka.t end
     arka = {t = K.RTYap("sb_kimlik2_dunya_arka", 900, 525)}
     K.IsEkle(function()
          K.TamPisir(arka.t, nil, true)
          arka.hazir = true
     end)
end

local function YuvaAl(kart)
     local anahtar = table.concat({tostring(kart.no), tostring(kart.v), tostring(kart.meslek), tostring(kart.gorevli), tostring(kart.resit), tostring(kart.kan), tostring(kart.yil)}, "#")
     for _, y in ipairs(yuvalar) do
          if y.anahtar == anahtar then
               y.son = CurTime()
               return y
          end
     end
     local kullanilan = {}
     for _, d in pairs(aktif) do if d.yuva then kullanilan[d.yuva] = true end end
     local sec
     for _, y in ipairs(yuvalar) do
          if not kullanilan[y] and (not sec or y.son < sec.son) then sec = y end
     end
     sec = sec or yuvalar[1]
     sec.t = sec.t or K.RTYap("sb_kimlik2_yuva" .. sec.no, 900, 525)
     sec.anahtar, sec.son, sec.hazir = anahtar, CurTime(), false
     KartPisir(sec, kart)
     return sec
end

----------------------------------------------------------------------------------------
-- Dünyada çizim
----------------------------------------------------------------------------------------
local function KemikPos(ply, ad)
     local b = ply:LookupBone(ad)
     local m = b and ply:GetBoneMatrix(b)
     return m and m:GetTranslation()
end

local function KartCiz(ply)
     local d = aktif[ply]
     if not d or (d.gor or 0) <= 0.01 then return end
     if ply == LocalPlayer() and not ply:ShouldDrawLocalPlayer() then return end

     local taraf = d.poz and d.poz.taraf or "R"
     local on = "ValveBiped.Bip01_" .. taraf .. "_"
     local bas = KemikPos(ply, on .. "Finger02") or KemikPos(ply, on .. "Finger01")
     local isaret = KemikPos(ply, on .. "Finger12") or KemikPos(ply, on .. "Finger11")
     local el
     if bas and isaret then
          el = (bas + isaret) * 0.5
     else
          local b = ply:LookupBone(on .. "Hand")
          local m = b and ply:GetBoneMatrix(b)
          if not m then return end
          el = m:GetTranslation() + m:GetForward() * 3.5
     end

     -- yüz: karşısındakinin gözüne, yoksa öne; arkaya dönmesin, aşırı eğilmesin
     local ileriA = ply:EyeAngles()
     ileriA.p, ileriA.r = 0, 0
     local ileri = ileriA:Forward()
     local n = IsValid(d.hedef) and (d.hedef:EyePos() - el) or Vector(ileri)
     n:Normalize()
     n.z = math.Clamp(n.z, -0.35, 0.35)
     n:Normalize()
     local nokta = n:Dot(ileri)
     if nokta < 0.3 then
          n = n + ileri * (0.3 - nokta + 0.25)
          n:Normalize()
     end
     d.n = d.n and LerpVector(math.min(1, FrameTime() * 8), d.n, n) or n
     n = d.n:GetNormalized()

     local yukari = Vector(0, 0, 1) - n * n.z
     yukari:Normalize()
     -- biraz geriye yatık: üst kenar uzaklaşır
     local n2 = (n + yukari * 0.14):GetNormalized()
     local yukari2 = (yukari - n * 0.14):GetNormalized()
     n, yukari = n2, yukari2
     local sag = yukari:Cross(n)

     local olcek = 0.35 + 0.65 * Kolay(d.gor)
     local w, h = KART_W * olcek, KART_H * olcek
     local merkez = el + yukari * (h / 2 - 0.45 * olcek) + n * 0.25

     local isik = render.GetLightColor(merkez)
     local k = math.Clamp(0.22 + (isik.x * 0.3 + isik.y * 0.59 + isik.z * 0.11) * 1.3, 0.26, 0.86)

     -- ön yüz (köşeleri saydam: ui malzemesi)
     if d.yuva and d.yuva.hazir then
          local tl = merkez - sag * (w / 2) + yukari * (h / 2) + n * 0.04
          cam.Start3D2D(tl, sag:AngleEx(n), w / 900)
               surface.SetMaterial(d.yuva.t.ui)
               surface.SetDrawColor(250 * k, 240 * k, 222 * k, 255)
               surface.DrawTexturedRect(0, 0, 900, 525)
          cam.End3D2D()
     end

     -- arka yüz (genel)
     local arkaT = ArkaYuz()
     if arkaT then
          local tlA = merkez + sag * (w / 2) + yukari * (h / 2) - n * 0.04
          cam.Start3D2D(tlA, (-sag):AngleEx(-n), w / 900)
               surface.SetMaterial(arkaT.ui)
               surface.SetDrawColor(235 * k, 228 * k, 214 * k, 255)
               surface.DrawTexturedRect(0, 0, 900, 525)
          cam.End3D2D()
     end
end

----------------------------------------------------------------------------------------
-- Yaşam döngüsü
----------------------------------------------------------------------------------------
local Durdur

local function Bitir(ply, d)
     if IsValid(ply) and d.cb then ply:RemoveCallback("BuildBonePositions", d.cb) end
     if IsValid(d.silah) then d.silah:SetNoDraw(false) end
     aktif[ply] = nil
end

local function Dusun()
     local dt = FrameTime()
     local simdi = CurTime()
     for ply, d in pairs(aktif) do
          if not IsValid(ply) or not ply:Alive() then
               Bitir(ply, d)
          else
               local acik = simdi < d.bitis
               d.agirlik = math.Approach(d.agirlik or 0, (acik and d.poz) and 1 or 0, dt / GECIS)
               d.gor = math.Approach(d.gor or 0, acik and 1 or 0, dt / (acik and 0.45 or 0.25))

               -- model değiştiyse duruş yeniden
               local model = ply:GetModel()
               if d.model ~= model then
                    d.model = model
                    if d.cb then ply:RemoveCallback("BuildBonePositions", d.cb) d.cb = nil end
                    d.poz = PozHesapla(model)
                    if d.poz then d.cb = ply:AddCallback("BuildBonePositions", KemikKur) end
               end

               -- kart sağ eldeyse asa görünmesin
               local silah = ply:GetActiveWeapon()
               local gizle = acik and IsValid(silah) and silah:GetClass() == "weapon_hpwr_stick" and (not d.poz or d.poz.taraf == "R")
               if gizle and d.silah ~= silah then
                    if IsValid(d.silah) then d.silah:SetNoDraw(false) end
                    d.silah = silah
                    silah:SetNoDraw(true)
               elseif not gizle and IsValid(d.silah) and d.gor <= 0.3 then
                    d.silah:SetNoDraw(false)
                    d.silah = nil
               end

               if not acik and d.agirlik <= 0 and d.gor <= 0 then Bitir(ply, d) end
          end
     end
     if next(aktif) == nil then Durdur() end
end

local function Baslat()
     hook.Add("Think", "SardonBakanlik.KimlikEl", Dusun)
     hook.Add("PostPlayerDraw", "SardonBakanlik.KimlikEl", function(ply)
          if aktif[ply] then
               local ok, hata = pcall(KartCiz, ply)
               if not ok and not K.ElHata then
                    K.ElHata = true
                    ErrorNoHalt("[Sardon Bakanlık] kimlik 3B kart: " .. tostring(hata) .. "\n")
               end
          end
     end)
end

Durdur = function()
     hook.Remove("Think", "SardonBakanlik.KimlikEl")
     hook.Remove("PostPlayerDraw", "SardonBakanlik.KimlikEl")
end

function K.ElBasla(ply, kart, hedef, sure)
     local d = aktif[ply] or {agirlik = 0, gor = 0}
     d.kart, d.hedef = kart, hedef
     d.bitis = CurTime() + (sure or K.Ayar.GosterSure)
     d.yuva = YuvaAl(kart)
     aktif[ply] = d
     Baslat()
end

net.Receive("SardonBakanlik.KimlikEl", function()
     local ply = Entity(net.ReadUInt(16))
     local hedef = Entity(net.ReadUInt(16))
     local sure = net.ReadFloat()
     local kart = net.ReadTable()
     if not IsValid(ply) or not ply:IsPlayer() or not istable(kart) then return end
     K.ElBasla(ply, kart, IsValid(hedef) and hedef or nil, sure)
end)
