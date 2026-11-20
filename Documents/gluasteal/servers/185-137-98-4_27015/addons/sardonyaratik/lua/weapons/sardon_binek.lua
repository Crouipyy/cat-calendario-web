-- "addons\\sardonyaratik\\lua\\weapons\\sardon_binek.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
--[[
     [sardon] yaratik :: binek "silahı"

     Binerken verilir, inince alınır; elde görünmez. Asıl işi bineğin değişen durumunu ağ
     değişkenlerinde tutmak: silah değişkenleri sahibinde tahmin edilir, böylece hareket kancaları
     (_sh_6binek.lua) iki tarafta aynı sonucu verir, HUD da doğrudan buradan okur.

       SOL TIK  → çığlık / kükreme
       R        → Thestral: Yön Duygusu (gidilecek yer listesi; Yön Duygusu açıkken kapatır)
]]

AddCSLuaFile()

SWEP.PrintName = "Binek"
SWEP.Author = "Sardon"
SWEP.Category = "Hogwarts"
SWEP.Spawnable = false
SWEP.AdminOnly = true

SWEP.ViewModel = "models/weapons/c_arms.mdl"
SWEP.WorldModel = ""
SWEP.UseHands = false
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.Slot = 5
SWEP.SlotPos = 9
SWEP.HoldType = "normal"

-- Helix: her zaman kaldırılmış sayılsın (aksi halde saldırı tuşları silinir)
SWEP.IsAlwaysRaised = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:SetupDataTables()
     self:NetworkVar("String", 0, "Tur")
     self:NetworkVar("Int", 0, "Kimlik")
     self:NetworkVar("Int", 1, "Nadir")
     self:NetworkVar("Int", 2, "Binicilik")
     self:NetworkVar("Int", 3, "RotaNo")
     self:NetworkVar("Float", 0, "Bag")
     self:NetworkVar("Float", 1, "Can")
     self:NetworkVar("Float", 2, "CanMax")
     self:NetworkVar("Float", 3, "Enerji")
     self:NetworkVar("Float", 4, "EnerjiMax")
     self:NetworkVar("Float", 5, "KalkisBas")
     self:NetworkVar("Float", 6, "CirpisT")
     self:NetworkVar("Float", 7, "CirpisHazir")
     self:NetworkVar("Float", 8, "Sendele")
     self:NetworkVar("Float", 9, "CiglikT")
     self:NetworkVar("Float", 10, "CiglikHazir")
     self:NetworkVar("Float", 11, "HucumBas")
     self:NetworkVar("Float", 12, "HucumHazir")
     self:NetworkVar("Float", 13, "HucumYaw")
     self:NetworkVar("Float", 14, "VurusT")
     self:NetworkVar("Float", 15, "VurusHazir")
     self:NetworkVar("Float", 16, "InisT")
     self:NetworkVar("Float", 17, "BinisT")
     self:NetworkVar("Bool", 0, "Ucuyor")
     self:NetworkVar("Bool", 1, "Inis")
     self:NetworkVar("Bool", 2, "Otopilot")
     self:NetworkVar("Bool", 3, "Itis")
     self:NetworkVar("Bool", 4, "Pike")

     if SERVER then
          self:SetHucumBas(-100)
          self:SetRotaNo(1)
     end
end

function SWEP:Initialize()
     self:SetHoldType(self.HoldType)
end

function SWEP:Deploy()
     self:SetHoldType(self.HoldType)
     return true
end

-- binekteyken başka silaha geçilemez (inerken sunucu silahı zaten alır)
function SWEP:Holster()
     local ply = self:GetOwner()
     return not (IsValid(ply) and SardonYaratik and SardonYaratik.Biniyor(ply))
end

function SWEP:PrimaryAttack()
     local Y = SardonYaratik
     local b = Y and Y.Binekler[self:GetTur()]
     local ply = self:GetOwner()
     if not b or not IsValid(ply) then return end
     local now = CurTime()
     self:SetNextPrimaryFire(now + 0.5)
     if now < self:GetCiglikHazir() or now < self:GetSendele() then return end

     self:SetCiglikT(now)
     self:SetCiglikHazir(now + (b.ciglikBekleme or 10))
     for _, s in ipairs(b.ses.ciglik or {}) do Y.BinekSes(ply, s, 95, 5) end
     if SERVER and Y.BinekCiglik then Y.BinekCiglik(ply, self, b) end
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
     if not CLIENT or not IsFirstTimePredicted() then return end
     local Y = SardonYaratik
     local b = Y and Y.Binekler[self:GetTur()]
     if not b or not b.otopilot then return end
     if RealTime() < (self.YonT or 0) then return end
     self.YonT = RealTime() + 0.6
     -- Yön Duygusu açıksa R onu kapatır (Move'da); değilse liste istenir
     if not self:GetOtopilot() and Y.YonDuygusuIste then Y.YonDuygusuIste() end
end

function SWEP:DrawWorldModel()
end

function SWEP:PreDrawViewModel()
     return true
end

function SWEP:ShouldDrawViewModel()
     return false
end

function SWEP:DrawHUD()
end

function SWEP:OnDrop()
     if SERVER then self:Remove() end
end
