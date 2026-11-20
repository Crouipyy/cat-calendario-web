-- "addons\\sardonekonomi\\lua\\entities\\ent_sardon_tuccar.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] ekonomi: NPC tüccar (türü NW: botanik, yaratik, iksir, balik, karaborsa). E ile satış penceresi.
-- Haritaya bağlı kip (Govde = haritadaki NPC propunun modeli): kendisi görünmez/katı değil, haritadaki NPC'ye bakıp E
-- (sv_5yer KeyPress); ad etiketi o NPC'nin üstünde. Kurulum: sardon_eko_bagla <tür> (NPC'ye bakarak).
AddCSLuaFile()

ENT.Base = "base_ai"
ENT.Type = "ai"
ENT.AutomaticFrameAdvance = true
ENT.PrintName = "Tüccar"
ENT.Category = "!! Sardon"
ENT.Spawnable = false

local POZ = {"idle_all_01", "idle_subtle", "pose_standing_02"}

function ENT:SetupDataTables()
     self:NetworkVar("String", 0, "Tur")
     self:NetworkVar("String", 1, "Govde")
end

function ENT:Bagli() return self:GetGovde() ~= "" end

function ENT:PozSekansi()
     for _, ad in ipairs(POZ) do
          local s = self:LookupSequence(ad)
          if s and s >= 0 then return s end
     end
     return 0
end

if SERVER then
     function ENT:Initialize()
          if self:Bagli() then
               self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
               self:SetSolid(SOLID_NONE)
               self:SetMoveType(MOVETYPE_NONE)
               self:DrawShadow(false)
               local en, enD
               for _, x in ipairs(ents.FindInSphere(self:GetPos(), 60)) do
                    if x ~= self and x:GetModel() == self:GetGovde() then
                         local d = x:GetPos():DistToSqr(self:GetPos())
                         if not enD or d < enD then en, enD = x, d end
                    end
               end
               self:SetNWEntity("GovdeEnt", en or NULL)
               return
          end
          local tt = SardonEkonomi and SardonEkonomi.Tuccar and SardonEkonomi.Tuccar.Turler[self:GetTur()]
          self:SetModel(tt and tt.model or "models/player/group01/male_02.mdl")
          self:SetHullSizeNormal()
          self:SetNPCState(NPC_STATE_SCRIPT)
          self:SetSolid(SOLID_BBOX)
          self:CapabilitiesAdd(CAP_ANIMATEDFACE or CAP_TURN_HEAD)
          self:SetUseType(SIMPLE_USE)
          self:DropToFloor()
          self:ResetSequence(self:PozSekansi())
     end

     function ENT:Use(ply)
          if IsValid(ply) and ply:IsPlayer() and SardonEkonomi.PencereGonder then
               SardonEkonomi.PencereGonder(ply, "tuccar", self)
          end
     end

     function ENT:OnTakeDamage() return 0 end
     return
end

local ADLAR = {
     botanik = {"Botanik Tüccarı", "Bitki ve tohum alır"}, yaratik = {"Yaratık Tüccarı", "Tüy, kıl, salgı alır"},
     iksir = {"İksir Tüccarı", "Kaynatılmış iksir alır"}, balik = {"Balık Tüccarı", "Taze balık alır"},
     karaborsa = {"Karaborsacı", "Soru sormaz, ucuza alır"},
     avci = {"Avcı Tüccarı", "Av parçası alır ve satar"},
}

-- etiket Madam Malkin gibi ([sardon] gorev cl_3aktor aktör yazısı): kutusuz, Cinzel ad + altın büyük harf unvan,
-- dış çizgili, kameraya dönük, kafa kemiğinin 12 birim üstü, uzaklaştıkça solar; saydam geçişte çizilir
ENT.RenderGroup = RENDERGROUP_BOTH

local function BasNoktasi(ent)
     local k = ent:LookupBone("ValveBiped.Bip01_Head1")
     if k then
          local m = ent:GetBoneMatrix(k)
          if m then return m:GetTranslation() + Vector(0, 0, 12) end
     end
     return ent:GetPos() + Vector(0, 0, 76)
end

local function Etiket(ent, ad, unvan)
     local lp = LocalPlayer()
     if not IsValid(lp) or not IsValid(ent) then return end
     local bas = BasNoktasi(ent)
     local d = lp:EyePos():Distance(bas)
     if d >= 700 then return end
     local alfa = math.Clamp((1100 - d) / 300, 0, 1)
     local G = SardonGorev
     local fAd = G and "SardonGorev.D_Ad" or "SardonEko.Etiket"
     local fUnvan = G and "SardonGorev.D_Unvan" or "SardonEko.EtiketKucuk"
     cam.Start3D2D(bas, Angle(0, EyeAngles().y - 90, 90), 0.06)
          draw.SimpleTextOutlined(ad, fAd, 0, 0, Color(232, 219, 182, 255 * alfa), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, Color(0, 0, 0, 170 * alfa))
          if unvan and unvan ~= "" then
               draw.SimpleTextOutlined((G and G.Buyuk) and G.Buyuk(unvan) or string.upper(unvan), fUnvan, 0, 4, Color(190, 162, 104, 230 * alfa), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 150 * alfa))
          end
     cam.End3D2D()
end

function ENT:Initialize()
     if self:Bagli() then self:SetRenderBounds(Vector(-200, -200, -100), Vector(200, 200, 200)) end
end

function ENT:Draw()
     if self:Bagli() then return end
     if self.pozModel ~= self:GetModel() then
          self.pozModel = self:GetModel()
          self.pozSeq = self:PozSekansi()
          self.pozSure = math.max(self:SequenceDuration(self.pozSeq), 0.1)
     end
     if self:GetSequence() ~= self.pozSeq then self:ResetSequence(self.pozSeq) end
     self:SetCycle((CurTime() / self.pozSure) % 1)
     self:DrawModel()
end

function ENT:DrawTranslucent()
     local ad = ADLAR[self:GetTur()] or {"Tüccar", ""}
     if self:Bagli() then
          local govde = self:GetNWEntity("GovdeEnt")
          if IsValid(govde) then Etiket(govde, ad[1], ad[2]) end
          return
     end
     Etiket(self, ad[1], ad[2])
end
