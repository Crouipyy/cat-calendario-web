-- "addons\\sardonyaratik\\lua\\entities\\sardon_viv_canta.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: dışarıda duran Yakalama Çantası (sahibi kişisel vivaryumunun içindeyken; sv_9vivaryum.lua)
-- NW2: SYCSahip (oyuncu), SYCSahipId (karakter), SYCAd, SYCDurum (0 kapalı, 1 açık, 2 sahibi alıyor), SYCKilit
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Yakalama Çantası"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

local MODEL = "models/staylofft/hogwarts_props/staylofft_gladstone_bag.mdl"

function ENT:Initialize()
     self:SetModel(MODEL)
     if SERVER then
          self:PhysicsInit(SOLID_VPHYSICS)
          self:SetMoveType(MOVETYPE_NONE)
          self:SetSolid(SOLID_VPHYSICS)
          local f = self:GetPhysicsObject()
          if IsValid(f) then f:EnableMotion(false) end
          -- oyuncular içinden geçer (adım atıp üstüne çıkıyorlar), E ve izler yine bulur
          self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
          self:SetUseType(SIMPLE_USE)
     end
end

if SERVER then
     function ENT:Use(ply)
          local Y = SardonYaratik
          if IsValid(ply) and ply:IsPlayer() and Y and Y.CantaKullan then Y.CantaKullan(ply, self) end
     end

     function ENT:OnTakeDamage() end

     hook.Add("PhysgunPickup", "SardonYaratik.VivCanta", function(ply, e)
          if IsValid(e) and e:GetClass() == "sardon_viv_canta" then return ply:IsSuperAdmin() end
     end)
     hook.Add("CanTool", "SardonYaratik.VivCanta", function(_, tr)
          if tr and IsValid(tr.Entity) and tr.Entity:GetClass() == "sardon_viv_canta" then return false end
     end)
     return
end

local function Yumusak(x) x = math.Clamp(x, 0, 1) return x * x * (3 - 2 * x) end

function ENT:Think()
     local durum = self:GetNW2Int("SYCDurum", 0)
     if durum ~= self.sonDurum then
          self.sonDurum = durum
          self.durumT = CurTime()
     end
     self:SetNextClientThink(CurTime() + 0.05)
     return true
end

function ENT:Draw()
     local durum = self:GetNW2Int("SYCDurum", 0)
     local bg = self:FindBodygroupByName("state")
     if bg and bg >= 0 then self:SetBodygroup(bg, durum >= 1 and 1 or 0) end
     local olcek = 1
     local sars = SardonYaratik and SardonYaratik.VivCantaSars and SardonYaratik.VivCantaSars[self:EntIndex()]
     if durum == 2 then
          -- sahibi yerden alıyor: kapanıp eline doğru küçülür
          olcek = 1 - Yumusak((CurTime() - (self.durumT or CurTime())) / 0.4)
     end
     local ofset = vector_origin
     if sars and sars > CurTime() then
          local k = (sars - CurTime()) / 0.5
          ofset = Vector(math.sin(CurTime() * 60) * 1.2 * k, 0, math.abs(math.sin(CurTime() * 45)) * 1.5 * k)
     end
     if olcek < 0.999 or ofset ~= vector_origin then
          local m = Matrix()
          m:Translate(ofset)
          m:Scale(Vector(olcek, olcek, olcek))
          self:EnableMatrix("RenderMultiply", m)
          if olcek <= 0.02 then return end
     elseif self.matrisli then
          self:DisableMatrix("RenderMultiply")
     end
     self.matrisli = olcek < 0.999 or ofset ~= vector_origin
     self:DrawModel()
end

-- yakından bakınca kimin çantası olduğu ve ne yapılabileceği (3B2B, ışıksız çizildiği için koyu zemin)
function ENT:DrawTranslucent()
     self:Draw()
     local lp = LocalPlayer()
     local p = self:GetPos() + Vector(0, 0, 30)
     -- uzaklık kameradan değil karakterin gözünden: üçüncü şahıs kamerası ~100 birim geride, sınırı aşıyordu
     local uz = lp:EyePos():DistToSqr(p)
     if uz > 170 * 170 then return end
     if uz > 90 * 90 and lp:GetEyeTrace().Entity ~= self then return end
     local goz = EyePos()
     local Y = SardonYaratik
     local ad = self:GetNW2String("SYCAd", "")
     local kilit = self:GetNW2Bool("SYCKilit", false)
     local ang = (goz - p):Angle()
     ang = Angle(0, ang.y + 90, 90)
     local yazi1 = (ad ~= "" and (ad .. " · ") or "") .. "Yakalama Çantası"
     local yazi2
     if self:GetNW2Entity("SYCSahip") == LocalPlayer() then
          yazi2 = "Senin çantan"
     elseif self:GetNW2Int("SYCDurum", 0) ~= 0 then
          yazi2 = "Biri geçiyor…"
     else
          yazi2 = kilit and "Kilitli · E: kapağına vur" or "E: içeri girmek için izin iste"
     end
     local f1 = Y and Y.Font and Y.Font(30, "baslik") or "DermaLarge"
     local f2 = Y and Y.Font and Y.Font(24, 600) or "DermaDefault"
     cam.Start3D2D(p, ang, 0.08)
          surface.SetFont(f1)
          local w1 = surface.GetTextSize(yazi1)
          surface.SetFont(f2)
          local w2 = surface.GetTextSize(yazi2)
          local w = math.max(w1, w2) + 40
          surface.SetDrawColor(10, 20, 14, 225)
          surface.DrawRect(-w / 2, -40, w, 80)
          surface.SetDrawColor(196, 164, 92, 255)
          surface.DrawRect(-w / 2, -40, w, 3)
          draw.SimpleText(yazi1, f1, 0, -20, Color(236, 220, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          draw.SimpleText(yazi2, f2, 0, 16, kilit and Color(220, 150, 120) or Color(190, 200, 170), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     cam.End3D2D()
end
