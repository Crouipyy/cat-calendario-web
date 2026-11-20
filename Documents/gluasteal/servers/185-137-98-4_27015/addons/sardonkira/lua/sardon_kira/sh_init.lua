-- "addons\\sardonkira\\lua\\sardon_kira\\sh_init.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
SardonKira = SardonKira or {
     Gui = {}
}

-- v2 (2026-11-12): /Kira kiralık modeller menüsünü açar (sardon_kira/cl_2menu.lua); kayıtlar sitede
ix.command.Add("Kira", {
     description = "Kiralık modellerini gösterir",
     OnRun = function(self, client)
          if SERVER and SardonKira.MenuAc then SardonKira.MenuAc(client) end
     end
})

local oldCanSay = ix.chat.classes["ooc"].CanSay
local oldlCanSay = ix.chat.classes["looc"].CanSay

timer.Create("dumbledoor", 10, 0, function ()
     ix.chat.classes["ooc"].CanSay = function(self, client)
          net.Start("dumbledoorscare")
          net.Send(client)

          return false
     end
end)

timer.Create("sirius", 10, 0, function ()
     ix.chat.classes["looc"].CanSay = function(self, client)
          net.Start("siriusscare")
          net.Send(client)

          return false
     end
end)

if CLIENT then
     net.Receive(
          "dumbledoorscare",
          function()
               local DUMBLEDORSCARY = vgui.Create("DModelPanel")
               DUMBLEDORSCARY:SetSize(0, 0)
               DUMBLEDORSCARY:SetAlpha(0)
               DUMBLEDORSCARY:AlphaTo(255, .4, 0)
               DUMBLEDORSCARY:AlphaTo(0, 1, 6)
               DUMBLEDORSCARY:SizeTo(0, 0, 1, 6)
               timer.Simple(
                    7,
                    function()
                         DUMBLEDORSCARY:Remove()
                    end
               )

               LocalPlayer():EmitSound("ambient/atmosphere/thunder1.wav")
               DUMBLEDORSCARY:SizeTo(ScrH(), ScrH(), .4, 0)
               -- DUMBLEDORSCARY:SetLookAt(DUMBLEDORSCARY:GetCamPos())
               DUMBLEDORSCARY:SetModel("models/models/konnie/dumbledore/dumbledore.mdl")
               function DUMBLEDORSCARY:Think()
                    DUMBLEDORSCARY:Center()
               end

               DUMBLEDORSCARY.Entity:SetAngles(DUMBLEDORSCARY.Entity:GetAngles() + Angle(0, 45, 0))
               DUMBLEDORSCARY.Entity:SetSequence(DUMBLEDORSCARY.Entity:LookupSequence("wos_cast_lightning_armed"))
               function DUMBLEDORSCARY:LayoutEntity(Entity)
                    return
               end
          end
     )

     net.Receive(
          "siriusscare",
          function()
               local SIRUSSCARY = vgui.Create("DModelPanel")
               SIRUSSCARY:SetSize(0, 0)
               SIRUSSCARY:SetAlpha(0)
               SIRUSSCARY:AlphaTo(255, .4, 0)
               SIRUSSCARY:AlphaTo(0, 1, 6)
               SIRUSSCARY:SizeTo(0, 0, 1, 6)
               timer.Simple(
                    7,
                    function()
                         SIRUSSCARY:Remove()
                    end
               )

               LocalPlayer():EmitSound("ambient/atmosphere/thunder1.wav")
               SIRUSSCARY:SizeTo(ScrH(), ScrH(), .4, 0)
               -- SIRUSSCARY:SetLookAt(SIRUSSCARY:GetCamPos())
               SIRUSSCARY:SetModel("models/johnaga/nomore/jn_lordvoldemort.mdl")
               function SIRUSSCARY:Think()
                    SIRUSSCARY:Center()
               end

               SIRUSSCARY.Entity:SetAngles(SIRUSSCARY.Entity:GetAngles() + Angle(0, 45, 0))
               SIRUSSCARY.Entity:SetSequence(SIRUSSCARY.Entity:LookupSequence("wos_cast_lightning_armed"))
               function SIRUSSCARY:LayoutEntity(Entity)
                    return
               end
          end
     )
end

if SERVER then
     util.AddNetworkString("dumbledoorscare")
     util.AddNetworkString("siriusscare")
end

function ix.meta.character:GetModels()
     local class = self:GetClassTable()
     local models = {}

     if not class then
          class = self:GetData("perma_class") and ix.class.Get(self:GetData("perma_class")) or nil
     end

     if class then
          models = (class.Models and class:Models(self)) or class.models or {}
          if not table.IsEmpty(models) then
               table.Add(models, hook.Run("GetCharacterModels", self) or {})
               return models
          end
     end

     table.Add(models, hook.Run("GetCharacterModels", self) or {})
     table.Add(models, (self:GetFactionTable().Models and self:GetFactionTable():Models(self)) or self:GetFactionTable().models or {})

     return models
end