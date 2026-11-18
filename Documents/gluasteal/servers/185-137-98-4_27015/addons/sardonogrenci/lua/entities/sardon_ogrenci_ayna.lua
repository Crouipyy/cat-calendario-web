-- "addons\\sardonogrenci\\lua\\entities\\sardon_ogrenci_ayna.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Yatakhane aynası: tuvalet masası (HL2 furniture_vanity01a; atölye içeriğinde ayakta duran ayna modeli yok), kemerli
-- çerçevesinde gerçek yansıma. E ile kısıtlı Görünüm Aynası: yalnız dinlenme ifadesi (mimik), ücretsiz; saç ve makyaj
-- kuaförde. Yetkili koyar (Q menüsü › Sardon · Öğrenci), /AynaKaydet haritaya kalıcı yazar ([sardon] ogrenci sv_4oyun.lua).
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Espejo del dormitorio"
ENT.Author = "Sardon"
ENT.Category = "Sardon · Estudiante"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH

local MODEL = "models/props_interiors/furniture_vanity01a.mdl"

if SERVER then
     function ENT:Initialize()
          self:SetModel(MODEL)
          self:PhysicsInit(SOLID_VPHYSICS)
          self:SetMoveType(MOVETYPE_VPHYSICS)
          self:SetSolid(SOLID_VPHYSICS)
          self:SetUseType(SIMPLE_USE)
          local fizik = self:GetPhysicsObject()
          if IsValid(fizik) then fizik:EnableMotion(false) end
     end

     function ENT:Use(ply)
          if not IsValid(ply) or not ply:IsPlayer() or (ply.sogAynaKullan or 0) > CurTime() then return end
          ply.sogAynaKullan = CurTime() + 1
          if SardonOgrenci and SardonOgrenci.KisitliAc then SardonOgrenci.KisitliAc(ply, "ayna", self) end
     end

     function ENT:SpawnFunction(ply, tr, sinif)
          if not tr.Hit then return end
          local ent = ents.Create(sinif)
          ent:SetPos(tr.HitPos - tr.HitNormal * ent:OBBMins().z)
          ent:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
          ent:Spawn()
          return ent
     end

     return
end

----------------------------------------------------------------------------------------
-- Cam: çerçevenin iç açıklığı (model uzayı; masanın önü +X, cam x düzleminde, üst köşeler yuvarlak). Kenarlar
-- çerçevenin altına biraz taşar, çerçeve kalınlığının (x -11.5..-10.1) içinde kalır (10-28 önden ızgarayla ölçüldü).
----------------------------------------------------------------------------------------
local CAM = {x = -10.6, y = 9.9, z0 = 3.2, z1 = 33.1, r = 5.2}
local CAM_MERKEZ = Vector(CAM.x, 0, (CAM.z0 + CAM.z1) / 2)
local YANSIMA = CreateClientConVar("sardon_ayna_yansima", "1", true, false, "Reflexión real en los espejos del dormitorio (0: off)", 0, 1)
local MESAFE = 260

local camMesh
do
     local c, kose = CAM, {}
     kose[#kose + 1] = Vector(c.x, -c.y, c.z0)
     kose[#kose + 1] = Vector(c.x, c.y, c.z0)
     for i = 0, 9 do
          local a = math.rad(i * 10)
          kose[#kose + 1] = Vector(c.x, c.y - c.r + c.r * math.cos(a), c.z1 - c.r + c.r * math.sin(a))
     end
     for i = 9, 18 do
          local a = math.rad(i * 10)
          kose[#kose + 1] = Vector(c.x, -c.y + c.r + c.r * math.cos(a), c.z1 - c.r + c.r * math.sin(a))
     end
     local function nokta(v)
          return {pos = v, normal = Vector(1, 0, 0), u = (v.y + c.y) / (2 * c.y), v = 1 - (v.z - c.z0) / (c.z1 - c.z0)}
     end
     local ucgen = {}
     for i = 2, #kose - 1 do
          ucgen[#ucgen + 1] = nokta(kose[1])
          ucgen[#ucgen + 1] = nokta(kose[i])
          ucgen[#ucgen + 1] = nokta(kose[i + 1])
     end
     camMesh = Mesh()
     camMesh:BuildFromTriangles(ucgen)
end

-- yansıma yokken (uzak, kapalı, arkadan) koyu cam: haritanın küp haritasını yansıtır
local CAM_MAT = CreateMaterial("sog_ayna_cam_1", "UnlitGeneric", {["$basetexture"] = "vgui/black", ["$envmap"] = "env_cubemap",
     ["$envmaptint"] = "[0.42 0.44 0.48]"})

local aynalar = {}
local aktif, sonGoz          -- bu karede yansıması hazır ayna ve hangi görüş için
local ciziyor = false        -- yansıma çizilirken (iç içe) aynanın camı çizilmez
local rt, rtMat, rtW, rtH

local function rtHazirla(w, h)
     if rt and rtW == w and rtH == h then return end
     rtW, rtH = w, h
     local ad = "sog_ayna_yansima_" .. w .. "x" .. h
     rt = GetRenderTargetEx(ad, w, h, RT_SIZE_LITERAL, MATERIAL_RT_DEPTH_SEPARATE, bit.bor(4, 8, 256), 0, IMAGE_FORMAT_RGB888)
     rtMat = CreateMaterial(ad, "UnlitGeneric", {["$basetexture"] = rt:GetName()})
     rtMat:SetTexture("$basetexture", rt)
end

-- [hogwarts] base performant render ana kameranın görmediği propları gizliyor (NoDraw + EFL_NO_THINK_FUNCTION);
-- yansıma odanın arkasını gösterdiği için aynanın çevresindekiler çizim süresince açılır. Sarmalanmış
-- render.RenderView her çağrıda haritadaki bütün gizlileri açtığı için asıl işlev çağrılır.
local yakin, yakinZaman, yakinAyna = {}, 0, nil

local function gizliAc(ayna, p)
     if yakinAyna ~= ayna or RealTime() > yakinZaman then
          yakinAyna, yakinZaman, yakin = ayna, RealTime() + 1, {}
          for _, e in ipairs(ents.FindInSphere(p, 700)) do
               if IsValid(e) and not e:IsPlayer() and not e:IsWeapon() and e ~= ayna then yakin[#yakin + 1] = e end
          end
     end
     local acilan = {}
     for _, e in ipairs(yakin) do
          if IsValid(e) and e:GetNoDraw() and e:IsEFlagSet(EFL_NO_THINK_FUNCTION) then
               e:SetNoDraw(false)
               acilan[#acilan + 1] = e
          end
     end
     return acilan
end

-- Ana görüşün ayna düzlemine göre yansıması RT'ye; cam ENT:Draw'da şablonla ekran hizalı (yatay ters) çizilir.
-- origin/angles/fov: o karenin görüşü (RenderScene); w, h: görüşün en/boy oranında RT boyu
function SardonOgrenciAynaYansima(origin, angles, fov, w, h)
     aktif, sonGoz = nil, nil
     if ciziyor or not YANSIMA:GetBool() or not next(aynalar) then return end
     local O = SardonOgrenci
     if O and IsValid(O.AynaPanel) and O.AynaPanel:IsVisible() then return end
     -- 11-14 opt: bakış yönü yalnız menzilde ve önü dönük ilk aynada bir kez hesaplanır (aynalar uyurken / uzakken
     -- RenderScene'de karede Vector yok). Koşul sırası ve kısa devre aynı; angles değiştirilmiyor, değer aynı.
     local ileri
     local en, enUzak
     for ent in pairs(aynalar) do
          if not IsValid(ent) then
               aynalar[ent] = nil
          elseif not ent:IsDormant() then
               local p = ent:LocalToWorld(CAM_MERKEZ)
               local d = origin - p
               local uzak = d:LengthSqr()
               if uzak < MESAFE * MESAFE and d:Dot(ent:GetForward()) > 2 then
                    ileri = ileri or angles:Forward()
                    if (p - origin):GetNormalized():Dot(ileri) > 0.25 and (not enUzak or uzak < enUzak) then
                         en, enUzak = ent, uzak
                    end
               end
          end
     end
     if not en then return end

     rtHazirla(math.floor((w or ScrW()) / 2), math.floor((h or ScrH()) / 2))
     local p, n = en:LocalToWorld(CAM_MERKEZ), en:GetForward()
     local function yansit(v) return v - 2 * v:Dot(n) * n end
     local goz = origin - 2 * (origin - p):Dot(n) * n
     local aci = yansit(angles:Forward()):AngleEx(yansit(angles:Up()))
     local RenderView = render.RenderView_Internal or render.RenderView

     ciziyor = true
     local acilan = gizliAc(en, p)
     render.PushRenderTarget(rt)
     render.Clear(0, 0, 0, 255, true, true)
     local eskiKirpma = render.EnableClipping(true)
     render.PushCustomClipPlane(n, n:Dot(p))
     local ok = pcall(RenderView, {origin = goz, angles = aci, fov = fov, x = 0, y = 0, w = rtW, h = rtH, znear = 2, zfar = 1600,
          drawviewmodel = false, drawhud = false, dopostprocess = false, drawmonitors = false, drawviewer = true})
     render.PopCustomClipPlane()
     render.EnableClipping(eskiKirpma)
     render.PopRenderTarget()
     for _, e in ipairs(acilan) do
          if IsValid(e) then e:SetNoDraw(true) end
     end
     ciziyor = false
     if ok then aktif, sonGoz = en, origin end
end

hook.Add("RenderScene", "SardonOgrenciAyna", function(origin, angles, fov)
     SardonOgrenciAynaYansima(origin, angles, fov)
end)

function ENT:Initialize()
     aynalar[self] = true
end

function ENT:OnRemove()
     aynalar[self] = nil
end

function ENT:Draw(flags)
     self:DrawModel(flags)
     if ciziyor then return end
     aynalar[self] = true

     local yansima = aktif == self and rtMat and sonGoz and EyePos():DistToSqr(sonGoz) < 0.01
          and (EyePos() - self:LocalToWorld(CAM_MERKEZ)):Dot(self:GetForward()) > 0
     cam.PushModelMatrix(self:GetWorldTransformMatrix())
     render.CullMode(MATERIAL_CULLMODE_NONE)
     if not yansima then
          render.SetMaterial(CAM_MAT)
          camMesh:Draw()
          render.CullMode(MATERIAL_CULLMODE_CCW)
          cam.PopModelMatrix()
          return
     end

     -- camın görünen pikselleri şablona; yansıma ekrana hizalı yalnız oraya (derinlik yazmadan, öndekiler örter)
     render.ClearStencil()
     render.SetStencilEnable(true)
     render.SetStencilWriteMask(255)
     render.SetStencilTestMask(255)
     render.SetStencilReferenceValue(1)
     render.SetStencilCompareFunction(STENCIL_ALWAYS)
     render.SetStencilPassOperation(STENCIL_REPLACE)
     render.SetStencilFailOperation(STENCIL_KEEP)
     render.SetStencilZFailOperation(STENCIL_KEEP)
     render.SetMaterial(CAM_MAT)
     camMesh:Draw()
     render.CullMode(MATERIAL_CULLMODE_CCW)
     cam.PopModelMatrix()

     render.SetStencilCompareFunction(STENCIL_EQUAL)
     render.SetStencilPassOperation(STENCIL_KEEP)
     local g = render.GetViewSetup and render.GetViewSetup()
     local w, h = g and g.width or ScrW(), g and g.height or ScrH()
     cam.Start2D()
          render.OverrideDepthEnable(true, false)
          surface.SetMaterial(rtMat)
          surface.SetDrawColor(255, 255, 255, 255)
          surface.DrawTexturedRectUV(0, 0, w, h, 1, 0, 0, 1)
          render.OverrideDepthEnable(false)
     cam.End2D()
     render.SetStencilEnable(false)
end

-- yakındayken üstünde ad ve ne yapılabileceği
function ENT:DrawTranslucent()
     local ply = LocalPlayer()
     local uzak = ply:GetPos():DistToSqr(self:GetPos())
     if uzak > 180 * 180 then return end
     local a = math.Clamp((180 * 180 - uzak) / (70 * 70), 0, 1)
     local pos = self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z + 10))
     local ac = (ply:EyePos() - pos):Angle()
     cam.Start3D2D(pos, Angle(0, ac.y + 90, 90), 0.07)
          draw.SimpleText("Espejo del dormitorio", "SOg.Kat", 0, 0, Color(250, 224, 168, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          draw.SimpleText("E  ·  expresión en reposo", "SOg.Alt", 0, 42, Color(214, 208, 196, 230 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          draw.SimpleText("pelo y maquillaje en la peluquería", "SOg.Alt", 0, 78, Color(180, 172, 160, 200 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     cam.End3D2D()
end
