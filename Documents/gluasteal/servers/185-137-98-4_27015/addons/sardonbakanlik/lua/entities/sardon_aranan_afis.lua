-- "addons\\sardonbakanlik\\lua\\entities\\sardon_aranan_afis.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- SE BUSCA afişi: büyücü fotoğrafları gibi portre KIPIRDAR. Aranan persona(s)nin modeli bir render
-- hedefine düşük kare hızında çizilir (yalnızca yakındaki afgestiona için). Bakanlığın como máximo ödüllü
-- üç arananı 12 saniyede bir sırayla gösterilir; aranan yoksa Ministerio mührü asılı durur.
-- Yönetici spawn menüsünden koyar, /BakanlikPanoKaydet ile haritaya kalıcı yazar (sv_pano.lua).
-- 11-13 opt (kodmod): kare başı kurulan sabitler dosya yereline alındı
local OPT_A_0_90_0 = Angle(0, 90, 0)
local OPT_V_n23p7_n23p7_1p9 = Vector(-23.7, -23.7, 1.9)
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Cartel SE BUSCA"
ENT.Author = "Sardon"
ENT.Category = "Sardon · Ministerio"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH

local MODEL = "models/hunter/plates/plate1x1.mdl"

if SERVER then
     function ENT:Initialize()
          self:SetModel(MODEL)
          self:PhysicsInit(SOLID_VPHYSICS)
          self:SetMoveType(MOVETYPE_VPHYSICS)
          self:SetSolid(SOLID_VPHYSICS)
          self:SetColor(Color(40, 28, 20))
          self:SetMaterial("models/debug/debugwhite")
          local fizik = self:GetPhysicsObject()
          if IsValid(fizik) then fizik:EnableMotion(false) end
     end

     function ENT:SpawnFunction(ply, tr, sinif)
          if not tr.Hit then return end
          local ent = ents.Create(sinif)
          ent:SetPos(tr.HitPos + tr.HitNormal * 2)
          local ac = tr.HitNormal:Angle()
          ac:RotateAroundAxis(ac:Right(), -90)
          ent:SetAngles(ac)
          ent:Spawn()
          return ent
     end

     return
end

-- Varlıklar eklentiden atrás yüklenebilir: SardonBakanlik çalışma anında okunur
local B = setmetatable({}, {__index = function(_, k) return SardonBakanlik and SardonBakanlik[k] end})
local istendi = 0

local function Liste()
     local v = B and B.Veri and B.Veri["aranan.afis"]
     local guncel = GetGlobalInt("SBArananSurum", 0)
     if (not v or v.surum ~= guncel) and RealTime() - istendi > 5 then
          istendi = RealTime()
          if B and B.Iste then B.Iste("aranan.afis", {}) end
     end
     return v and v.liste or {}
end

-- Portre render hedefleri: aynı persona(s) bütün afgestionade tek hedefi paylaşır (como máximo 3)
local portreler = {} -- [sira] = {rt, mat, model, csm, son}

local portreHatasi = false
local istek = {} -- bu karede çizilmek istenen portreler: [sira] = {model, öğrenci görünümü}

local function Portre(sira, model, ogr)
     istek[sira] = {model, ogr}
     return portreler[sira]
end

-- öğrenci görünümü ([sardon] ogrenci): saç, giysi, yüz rengi ve hatlarıyla giydirilir
local function OgrenciGiydir(csm, ogr)
     local O = SardonOgrenci
     if not ogr or not istable(ogr.d) or not O or not O.OnizlemeGiydir or not O.Hazir() then return false end
     local g = isstring(ogr.kod) and HLStudents.DecodeGear(ogr.kod) or nil
     if g and g.gender ~= ogr.d.gender then g = nil end
     O.OnizlemeGiydir(csm, ogr.d, g and g.gear or O.BaslangicGiyili(ogr.d.gender), g and g.house or 1, g and g.hood, 1)
     return csm.sogS ~= nil
end

local function PortreHazirla(sira, model, ogr)
     local p = portreler[sira]
     if not p then
          local rt = GetRenderTargetEx("SardonBakanlikAfis" .. sira, 256, 320, RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_SEPARATE, 0, 0, IMAGE_FORMAT_RGBA8888)
          p = {rt = rt, mat = CreateMaterial("SardonBakanlikAfisMat" .. sira, "UnlitGeneric", {["$basetexture"] = rt:GetName(), ["$vertexcolor"] = 1}), son = 0}
          portreler[sira] = p
     end

     local anahtar = tostring(model) .. "|" .. (ogr and util.TableToJSON(ogr) or "")
     if p.anahtar ~= anahtar then
          if IsValid(p.csm) then
               if SardonOgrenci and SardonOgrenci.OnizlemeTemizle then SardonOgrenci.OnizlemeTemizle(p.csm) end
               p.csm:Remove()
          end
          p.csm = nil
          p.model, p.anahtar, p.ogrenci = model, anahtar, false
          if model and model ~= "" and util.IsValidModel(model) then
               local csm = ClientsideModel(model, RENDERGROUP_OPAQUE)
               if IsValid(csm) then
                    csm:SetNoDraw(true)
                    p.ogrenci = OgrenciGiydir(csm, ogr)
                    local seq = csm:LookupSequence("idle_all_01")
                    if seq and seq > 0 then csm:ResetSequence(seq) end
                    p.csm = csm
               end
          end
     end
     return p
end

-- Render hedefine çizim sahne başlamadan yapılır (varlığın Draw'ı içinde değil); 12 kare/sn
local function PortreleriCiz()
     local simdi = RealTime()

     for sira, v in pairs(istek) do
          local p = PortreHazirla(sira, v[1], v[2])
          if IsValid(p.csm) and simdi - p.son > 0.083 then
               p.son = simdi
               local csm = p.csm
               csm:SetCycle((simdi * 0.25) % 1)
               local bas = csm:LookupBone("ValveBiped.Bip01_Head1")
               if bas then csm:ManipulateBoneAngles(bas, Angle(0, math.sin(simdi * 0.7) * 14, math.sin(simdi * 0.45) * 5)) end
               csm:SetupBones()
               local kafa = bas and csm:GetBonePosition(bas) or Vector(0, 0, 64)
               local goz = kafa + Vector(38, 0, -2)

               render.PushRenderTarget(p.rt)
                    render.Clear(58, 46, 34, 255, true, true)
                    cam.Start3D(goz, (kafa + Vector(0, 0, -4) - goz):Angle(), 40, 0, 0, 256, 320)
                         render.SuppressEngineLighting(true)
                         render.ResetModelLighting(0.75, 0.68, 0.55)
                         render.SetModelLighting(BOX_FRONT, 1, 0.92, 0.78)
                         csm:DrawModel()
                         if p.ogrenci then SardonOgrenci.ParcaCiz(csm) end
                         render.SuppressEngineLighting(false)
                    cam.End3D()
               render.PopRenderTarget()
          end
     end
end

hook.Add("PreRender", "SardonBakanlik.Afis", function()
     if next(istek) == nil then return end
     local ok, hata = pcall(PortreleriCiz)
     istek = {}
     if not ok then
          render.SuppressEngineLighting(false)
          if not portreHatasi then
               portreHatasi = true
               ErrorNoHalt("[Sardon Ministerio] afiş portresi: " .. tostring(hata) .. "\n")
          end
     end
end)

surface.CreateFont("SBAfis.Baslik", {font = "Montserrat SemiBold", size = 64, weight = 600, extended = true})
surface.CreateFont("SBAfis.Ad", {font = "Montserrat SemiBold", size = 36, weight = 600, extended = true})
surface.CreateFont("SBAfis.Metin", {font = "Arial", size = 22, weight = 700, extended = true})

local KIZIL = Color(150, 30, 26)
local MUREKKEP = Color(52, 34, 22)

function ENT:Draw()
     self:DrawModel()
     local uzak = LocalPlayer():GetPos():DistToSqr(self:GetPos())
     if uzak > 800 * 800 then return end

     local liste = Liste()
     local sira = #liste > 0 and (math.floor(CurTime() / 12) % math.min(3, #liste)) + 1 or 0
     local a = liste[sira]

     -- yüzey: plakanın üst yüzü (yerel +Z); 2B x ekseni yerel +Y, y ekseni yerel +X
     local ac = self:LocalToWorldAngles(OPT_A_0_90_0)
     local pos = self:LocalToWorld(OPT_V_n23p7_n23p7_1p9)

     local portre = (a and uzak < 500 * 500) and Portre(sira, a.model, a.ogr) or nil

     cam.Start3D2D(pos, ac, 0.05)
          pcall(function()
               local W, H = 940, 940
               local kagit = B and B.Doku and B.Doku("kagit")
               if kagit then
                    surface.SetMaterial(kagit)
                    surface.SetDrawColor(255, 244, 222, 255)
                    surface.DrawTexturedRect(0, 0, W, H)
                    draw.NoTexture()
               else
                    surface.SetDrawColor(226, 208, 166, 255)
                    surface.DrawRect(0, 0, W, H)
               end

               if not a then
                    local muhur = B and B.Doku and B.Doku("muhur")
                    if muhur then
                         surface.SetMaterial(muhur)
                         surface.SetDrawColor(120, 90, 60, 255)
                         surface.DrawTexturedRect(W / 2 - 200, 160, 400, 400)
                         draw.NoTexture()
                    end
                    draw.SimpleText("NADIE EN BUSCA", "SBAfis.Baslik", W / 2, 660, MUREKKEP, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText("Ministerio de Magia · Oficina de Aurores", "SBAfis.Metin", W / 2, 730, MUREKKEP, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    return
               end

               draw.SimpleText("SE BUSCA", "SBAfis.Baslik", W / 2, 70, KIZIL, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               -- portre çerçevesi
               local px, py, pw, ph = W / 2 - 220, 130, 440, 520
               surface.SetDrawColor(70, 50, 34, 255)
               surface.DrawRect(px - 8, py - 8, pw + 16, ph + 16)
               if portre and portre.mat then
                    surface.SetMaterial(portre.mat)
                    surface.SetDrawColor(232, 214, 180, 255) -- sepya
                    surface.DrawTexturedRect(px, py, pw, ph)
                    draw.NoTexture()
               else
                    surface.SetDrawColor(96, 80, 62, 255)
                    surface.DrawRect(px, py, pw, ph)
               end

               draw.SimpleText(B.Buyuk(tostring(a.ad)), "SBAfis.Ad", W / 2, 700, MUREKKEP, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               draw.SimpleText(string.sub(tostring(a.gerekce), 1, 60), "SBAfis.Metin", W / 2, 750, MUREKKEP, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               if (a.odul or 0) > 0 then
                    draw.SimpleText("RECOMPENSA: " .. B.Para(a.odul), "SBAfis.Ad", W / 2, 810, KIZIL, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               end
               draw.SimpleText("Quienes lo vean avise al Ministerio de Magia (/Ihbar)", "SBAfis.Metin", W / 2, 875, MUREKKEP, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          end)
     cam.End3D2D()
end

hook.Add("ShutDown", "SardonBakanlik.Afis", function()
     for _, p in pairs(portreler) do
          if IsValid(p.csm) then p.csm:Remove() end
     end
end)
