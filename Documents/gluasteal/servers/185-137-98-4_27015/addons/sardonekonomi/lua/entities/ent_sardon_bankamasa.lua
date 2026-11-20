-- "addons\\sardonekonomi\\lua\\entities\\ent_sardon_bankamasa.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] ekonomi: Gringotts Takas Masası. İki kip:
--   masa (Tur ""): masa modeli; uzun kenarlar A (+Y) / B (-Y); başında istemcide goblin noter ("writing" bekler, "stamp" mühür).
--   gişe (Tur "gise"): haritadaki goblin veznedarın önüne konan görünmez, katı olmayan nokta (sardon_eko_gise). Goblin'e
--     bakıp E (sv_9bankamasa KeyPress); oyuncular gişenin önünde sağ/sol; haritadaki goblin SetAnimation ile mühür basar.
-- Teklif edilen eşyaların modelleri masada/tezgâhta, Galleon tutarına göre keseler. Sunucu mantığı sv_9bankamasa.lua.
AddCSLuaFile()

ENT.Base = "base_anim"
ENT.Type = "anim"
ENT.PrintName = "Gringotts Takas Masası"
ENT.Category = "!! Sardon"
ENT.Spawnable = false
ENT.Model = "models/konnie/diagonalley/leakycauldron/diningtable.mdl"
ENT.GoblinModel = "models/konnie/diagonalley/gringotts/goblin.mdl"

function ENT:SetupDataTables()
     self:NetworkVar("String", 0, "Tur")
end

function ENT:Gise() return self:GetTur() == "gise" end

if SERVER then
     function ENT:Initialize()
          self:SetNWString("Durum", "bekler")
          if self:Gise() then
               self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
               self:SetSolid(SOLID_NONE)
               self:SetMoveType(MOVETYPE_NONE)
               self:DrawShadow(false)
               self:GoblinBul()
               return
          end
          self:SetModel(util.IsValidModel(self.Model) and self.Model or "models/props_c17/FurnitureTable001a.mdl")
          self:PhysicsInit(SOLID_VPHYSICS)
          self:SetMoveType(MOVETYPE_VPHYSICS)
          self:SetSolid(SOLID_VPHYSICS)
          self:SetUseType(SIMPLE_USE)
          local f = self:GetPhysicsObject()
          if IsValid(f) then f:EnableMotion(false) end
     end

     function ENT:GoblinBul()
          local en, enD
          for _, x in ipairs(ents.FindInSphere(self:GetPos(), 220)) do
               if x ~= self and x:GetClass() ~= "ent_sardon_bankamasa" and string.find(string.lower(x:GetModel() or ""), "goblin", 1, true) then
                    local d = x:GetPos():DistToSqr(self:GetPos())
                    if not enD or d < enD then en, enD = x, d end
               end
          end
          self:SetNWEntity("Goblin", en or NULL)
     end

     local GOB_ANIM = {muhur = "stamp", inceler = "writing", selam = "writing3"}
     function ENT:GobAnim(d)
          if not self:Gise() then return end
          local g = self:GetNWEntity("Goblin")
          if IsValid(g) and GOB_ANIM[d] then g:Fire("SetAnimation", GOB_ANIM[d]) end
     end

     function ENT:Use(ply)
          if IsValid(ply) and ply:IsPlayer() and SardonEkonomi.Masa then SardonEkonomi.Masa.Kullan(self, ply) end
     end

     function ENT:OnRemove()
          local M = SardonEkonomi.Masa
          if not M then return end
          for ply, y in pairs(M.Yan) do if y.ent == self then M.Kalk(ply, "Masa kaldırıldı.") end end
     end
     return
end

SardonEkonomi = SardonEkonomi or {}
SardonEkonomi.MasaGorsel = SardonEkonomi.MasaGorsel or {}

local KESE = "models/items/jewels/purses/big_purse.mdl"
local KAGIT = "models/props_c17/paper01.mdl"
local SOZ = {
     bekler = "Gringotts Noteri · takas için bana bak, E",
     selam = "Hoş geldiniz. Tekliflerinizi koyun.",
     inceler = "İnceliyorum… kimse dokunmasın.",
     muhur = "Mühürlendi. Gringotts güvencesiyle.",
}

function ENT:Initialize()
     self.csm = {}
     if self:Gise() then
          self:SetRenderBounds(Vector(-90, -90, -60), Vector(90, 90, 90))
     else
          local mins, maxs = self:OBBMins(), self:OBBMaxs()
          self:SetRenderBounds(mins - Vector(20, 20, 0), maxs + Vector(60, 20, 90))
     end
end

local function Yap(self, anahtar, model)
     self.csm = self.csm or {}
     local c = self.csm[anahtar]
     if IsValid(c) and c.mdl == model then return c end
     if IsValid(c) then c:Remove() end
     c = ClientsideModel(model, RENDERGROUP_OPAQUE)
     if not IsValid(c) then return end
     c:SetNoDraw(true)
     c.mdl = model
     self.csm[anahtar] = c
     return c
end

function ENT:OnRemove()
     for _, c in pairs(self.csm or {}) do if IsValid(c) then c:Remove() end end
end

local function Sekans(c, ad, yedek)
     local s = c:LookupSequence(ad)
     if not s or s < 0 then s = c:LookupSequence(yedek or "writing") end
     return math.max(s or 0, 0)
end

-- teklif yerleşimi: (yan, sıra) → yerel konum; gişede tezgâh üstü, masada masa üstü
function ENT:EsyaYeri(yan, i, z)
     local isaret = yan == "A" and 1 or -1
     if self:Gise() then
          return Vector(-4 - math.floor((i - 1) / 4) * 11, isaret * (10 + ((i - 1) % 4) * 9), 0.3)
     end
     return Vector(-80 + (i - 1) * 20, isaret * 22, z + 0.3)
end

function ENT:KeseYeri(yan, k, z)
     local isaret = yan == "A" and 1 or -1
     if self:Gise() then return Vector(-28, isaret * (10 + k * 8), 0.5) end
     return Vector(80 + k * 8, isaret * 22, z + 0.5)
end

function ENT:Draw()
     local gise = self:Gise()
     if not gise then self:DrawModel() end
     local lp = LocalPlayer()
     if not IsValid(lp) or lp:GetPos():DistToSqr(self:GetPos()) > 1500 * 1500 then return end

     local durum = self:GetNWString("Durum", "bekler")
     local z = gise and 0 or self:OBBMaxs().z
     local kullanilan = {}

     -- masa kipinde istemci goblini
     if not gise then
          local g = Yap(self, "goblin", self.GoblinModel)
          if IsValid(g) then
               kullanilan.goblin = true
               local ad = durum == "muhur" and "stamp" or (durum == "inceler" and "writing2" or "writing")
               if g.seqAd ~= ad then
                    g.seqAd = ad
                    g.seq = Sekans(g, ad)
                    g:ResetSequence(g.seq)
                    g.seqBas = CurTime()
                    g.seqSure = math.max(g:SequenceDuration(g.seq), 0.2)
               end
               g:SetCycle(((CurTime() - (g.seqBas or 0)) / (g.seqSure or 1)) % 1)
               g:SetPos(self:LocalToWorld(Vector(self:OBBMaxs().x + 6, 0, 0)))
               g:SetAngles(self:LocalToWorldAngles(Angle(0, 180, 0)))
               g:SetupBones()
               g:DrawModel()
          end
     end

     -- teklifler
     local veri = SardonEkonomi.MasaGorsel[self]
     if veri then
          for _, yan in ipairs({"A", "B"}) do
               local t = veri[yan]
               for i, mdl in ipairs(t and t.esya or {}) do
                    local anahtar = yan .. i
                    local c = Yap(self, anahtar, mdl)
                    if IsValid(c) then
                         kullanilan[anahtar] = true
                         local mins, maxs = c:GetModelBounds()
                         local boy = math.max(maxs.x - mins.x, maxs.y - mins.y, maxs.z - mins.z, 1)
                         local olcek = math.Clamp((gise and 9 or 14) / boy, 0.12, 1.2)
                         local yer = self:EsyaYeri(yan, i, z)
                         yer.z = yer.z - mins.z * olcek
                         c:SetModelScale(olcek)
                         c:SetPos(self:LocalToWorld(yer))
                         c:SetAngles(self:LocalToWorldAngles(Angle(0, CurTime() * 8 % 360, 0)))
                         c:DrawModel()
                    end
               end
               local para = t and t.para or 0
               if para > 0 then
                    for k = 1, math.Clamp(math.ceil(para / 50), 1, 4) do
                         local anahtar = yan .. "kese" .. k
                         local c = Yap(self, anahtar, KESE)
                         if IsValid(c) then
                              kullanilan[anahtar] = true
                              c:SetModelScale(gise and 0.45 or 0.6)
                              c:SetPos(self:LocalToWorld(self:KeseYeri(yan, k, z)))
                              c:SetAngles(self:LocalToWorldAngles(Angle(0, k * 40, 0)))
                              c:DrawModel()
                         end
                    end
               end
          end
     end

     -- mühür: parşömen + ışıltı + ses
     if durum == "muhur" then
          local c = Yap(self, "kagit", KAGIT)
          if IsValid(c) then
               kullanilan.kagit = true
               c:SetPos(self:LocalToWorld(gise and Vector(6, 0, 0.5) or Vector(40, 0, z + 0.5)))
               c:SetAngles(self:LocalToWorldAngles(Angle(0, 90, 0)))
               c:DrawModel()
          end
          if not self.muhurEfekt or self.muhurEfekt < self:GetNWFloat("DurumZaman", 0) then
               self.muhurEfekt = CurTime()
               local ed = EffectData()
               ed:SetOrigin(self:LocalToWorld(gise and Vector(6, 0, 2) or Vector(40, 0, z + 2)))
               ed:SetMagnitude(2)
               ed:SetScale(1)
               ed:SetRadius(4)
               util.Effect("Sparks", ed)
               self:EmitSound("physics/wood/wood_box_impact_hard3.wav", 70, 90)
               timer.Simple(0.4, function() if IsValid(self) then self:EmitSound("ambient/levels/labs/coinslot1.wav", 65, 100) end end)
          end
     end

     for k, c in pairs(self.csm or {}) do
          if not kullanilan[k] and IsValid(c) then c:Remove() self.csm[k] = nil end
     end

     -- noterin sözü (3D2D, koyu zemin): gişede haritadaki goblinin üstünde
     local g = self:GetNWEntity("Goblin")
     local pos = (gise and IsValid(g)) and (g:GetPos() + Vector(0, 0, 62)) or self:LocalToWorld(Vector(self:OBBMaxs().x + 6, 0, 78))
     -- duvara girmesin: gişede goblinden tezgâha doğru, masada bakana doğru öne al
     local one = (gise and IsValid(g)) and (self:GetPos() - g:GetPos()) or (lp:EyePos() - pos)
     one.z = 0
     if one:LengthSqr() < 1 then one = lp:EyePos() - pos one.z = 0 end
     one:Normalize()
     pos = pos + one * 14
     local ang = Angle(0, (lp:EyePos() - pos):Angle().y + 90, 90)
     cam.Start3D2D(pos, ang, 0.07)
          surface.SetFont("SardonEko.EtiketKucuk")
          local metin = SOZ[durum] or SOZ.bekler
          local w = surface.GetTextSize(metin) + 40
          draw.RoundedBox(8, -w / 2, -6, w, 44, Color(20, 16, 12, 215))
          draw.SimpleText(metin, "SardonEko.EtiketKucuk", 0, 2, Color(232, 204, 140), TEXT_ALIGN_CENTER)
     cam.End3D2D()
end

net.Receive("SardonEko.MasaGorsel", function()
     local ent = net.ReadEntity()
     local veri = net.ReadTable()
     if IsValid(ent) then SardonEkonomi.MasaGorsel[ent] = veri end
end)
