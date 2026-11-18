-- "addons\\sardonbakanlik\\lua\\entities\\sardon_kararname_panosu.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Decreto Panosu: duvara asılan Ministerio panosu. En vigorki son dört kararname parşömen
-- olarak çivilenir; yeni kararname çıkınca pano yenilenir ve çivi sesi gelir.
-- Yönetici spawn menüsünden koyar, /BakanlikPanoKaydet ile haritaya kalıcı yazar (sv_pano.lua).
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Tablón de decretos"
ENT.Author = "Sardon"
ENT.Category = "Sardon · Ministerio"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH

local MODEL = "models/hunter/plates/plate1x2.mdl"

if SERVER then
     function ENT:Initialize()
          self:SetModel(MODEL)
          self:PhysicsInit(SOLID_VPHYSICS)
          self:SetMoveType(MOVETYPE_VPHYSICS)
          self:SetSolid(SOLID_VPHYSICS)
          self:SetColor(Color(46, 32, 22))
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
local surum = -1
local istendi = 0

local function Veri()
     local v = B and B.Veri and B.Veri["kararname.pano"]
     local guncel = GetGlobalInt("SBDecretoSurum", 0)
     if (not v or v.surum ~= guncel) and RealTime() - istendi > 5 then
          istendi = RealTime()
          if B and B.Iste then B.Iste("kararname.pano", {}) end
     end
     return v
end

function ENT:Think()
     local guncel = GetGlobalInt("SBDecretoSurum", 0)
     if self.sbSurum and self.sbSurum ~= guncel and LocalPlayer():GetPos():DistToSqr(self:GetPos()) < 1200 * 1200 then
          self:EmitSound("physics/metal/metal_solid_impact_soft" .. math.random(1, 3) .. ".wav", 65, 120)
     end
     self.sbSurum = guncel
end

local ALTIN = Color(190, 162, 104)
local MUREKKEP = Color(52, 34, 22)

surface.CreateFont("SBPano.Baslik", {font = "Montserrat SemiBold", size = 34, weight = 600, extended = true})
surface.CreateFont("SBPano.Ust", {font = "Montserrat SemiBold", size = 15, weight = 600, extended = true})
surface.CreateFont("SBPano.Kart", {font = "Montserrat SemiBold", size = 21, weight = 600, extended = true})
surface.CreateFont("SBPano.Metin", {font = "Arial", size = 16, weight = 700, extended = true})

local function Sar(metin, genislik, enCok)
     surface.SetFont("SBPano.Metin")
     local satirlar, cur = {}, ""
     for kelime in string.gmatch(metin, "%S+") do
          local aday = cur == "" and kelime or (cur .. " " .. kelime)
          if cur ~= "" and surface.GetTextSize(aday) > genislik then
               satirlar[#satirlar + 1] = cur
               cur = kelime
               if #satirlar >= enCok then break end
          else
               cur = aday
          end
     end
     if cur ~= "" and #satirlar < enCok then satirlar[#satirlar + 1] = cur end
     return satirlar
end

function ENT:Draw()
     self:DrawModel()
     if LocalPlayer():GetPos():DistToSqr(self:GetPos()) > 900 * 900 then return end

     -- yüzey: plakanın üst yüzü (yerel +Z); 2B x ekseni yerel +Y, y ekseni yerel +X
     local ac = self:LocalToWorldAngles(Angle(0, 90, 0))
     local pos = self:LocalToWorld(Vector(-23.7, -47.4, 1.9))

     cam.Start3D2D(pos, ac, 0.05)
          local ok = pcall(function()
               local W, H = 1880, 940
               surface.SetDrawColor(38, 26, 18, 255)
               surface.DrawRect(0, 0, W, H)
               surface.SetDrawColor(ALTIN.r, ALTIN.g, ALTIN.b, 255)
               surface.DrawOutlinedRect(12, 12, W - 24, H - 24, 3)
               draw.SimpleText("DECRETOS DEL MINISTERIO DE MAGIA", "SBPano.Baslik", W / 2, 60, ALTIN, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

               local v = Veri()
               local liste = v and v.liste or {}
               if #liste == 0 then
                    draw.SimpleText("No hay decretos en vigor.", "SBPano.Metin", W / 2, H / 2, Color(200, 190, 160), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    return
               end

               local kagit = B and B.Doku and B.Doku("kagit")
               local mum = B and B.Doku and B.Doku("mum")
               local kw, kh = 420, 780
               for i = 1, math.min(4, #liste) do
                    local k = liste[i]
                    local x, y = 40 + (i - 1) * (kw + 26), 110
                    if kagit then
                         surface.SetMaterial(kagit)
                         surface.SetDrawColor(255, 248, 232, 255)
                         surface.DrawTexturedRect(x, y, kw, kh)
                         draw.NoTexture()
                    else
                         surface.SetDrawColor(226, 208, 166, 255)
                         surface.DrawRect(x, y, kw, kh)
                    end
                    surface.SetDrawColor(120, 120, 120, 255)
                    surface.DrawRect(x + kw / 2 - 6, y + 10, 12, 12) -- çivi

                    local tur = (B and B.DecretoTurAd and B.DecretoTurAd[k.tur]) or "Decreto"
                    draw.SimpleText(B.Buyuk(tur) .. " NO. " .. k.no, "SBPano.Ust", x + kw / 2, y + 50, Color(120, 84, 48), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    local bas = Sar(k.baslik, kw - 50, 3)
                    for j, s in ipairs(bas) do
                         surface.SetFont("SBPano.Kart")
                         draw.SimpleText(s, "SBPano.Kart", x + kw / 2, y + 70 + j * 28, MUREKKEP, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                    local my = y + 100 + #bas * 28
                    for j, s in ipairs(Sar(k.metin, kw - 60, 17)) do
                         draw.SimpleText(s, "SBPano.Metin", x + 30, my + j * 24, MUREKKEP, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end
                    draw.SimpleText("— " .. tostring(k.yazan_ad), "SBPano.Metin", x + kw - 30, y + kh - 46, Color(90, 60, 36), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    if mum then
                         surface.SetMaterial(mum)
                         surface.SetDrawColor(255, 255, 255, 255)
                         surface.DrawTexturedRect(x + 20, y + kh - 120, 100, 100)
                         draw.NoTexture()
                    end
               end
          end)
          if not ok then draw.NoTexture() end
     cam.End3D2D()
end
