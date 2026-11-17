-- "addons\\sardonpolaroid\\lua\\sardon_polaroid\\sh_init.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
local ITEM = ix.item.Register("PolaroidPhoto", nil, false, nil, true)

ITEM.width = 1
ITEM.height = 1
ITEM.model = "models/props_lab/frame001a.mdl"
ITEM.description = "Un instante capturado en el tiempo."
ITEM.name = "Recuerdo capturado"

ITEM.functions = {}
ITEM.functions["Dejar en el suelo"] = {
     tip = "dropTip",
     icon = "icon16/photo.png",
     OnRun = function(self)
          if self.entity then
               if IsValid(self.entity) then self.entity:Remove() end
               self.entity = nil
          end

          local ent = ents.Create("ent_polaroid_print")
          local pos = self:GetOwner():GetItemDropPos(ent) + Vector(0, 0, 5)
          ent:SetPos(pos)
          ent:SetImage(self:GetData("Image"))
          ent:SetAngles((self:GetOwner():GetPos() - pos):Angle())
          ent:Spawn()
          ent:GetPhysicsObject():Wake()

          self.player:EmitSound("npc/zombie/foot_slide" .. math.random(1, 3) .. ".wav", 75, math.random(90, 120), 1)

          -- Fotoğrafı artık yerdeki baskı taşıyor; eşya tamamen silinir. Remove(false, true)
          -- veritabanı satırını bırakıyordu: fotoğraf yeniden girişte eski yerinde geri çıkıp
          -- (dupe) o arada oraya konan eşyanın üstüne yazılıyordu.
          self:Remove()

          return false
     end,
     OnCanRun = function(self)
          return self:GetOwner() and IsValid(self:GetOwner())
     end
}

ITEM.functions["Rasgar"] = {
     tip = "Rasgar",
     icon = "icon16/photo.png",
     OnRun = function(self)
         local owner = self:GetOwner()
         local inventory = owner:GetCharacter():GetInventory()
 
         -- Itemi envanterden ve veritabanından kaldır (yırtılan fotoğraf geri gelmesin)
         self:Remove()
 
         -- Envanteri güncelle
         inventory:Sync(owner)
 
         return false
     end,
     OnCanRun = function(self)
         return self:GetOwner() and IsValid(self:GetOwner())
     end
 }
ITEM.functions["Copiar enlace"] = {
     tip = "Copiar enlace",
     icon = "icon16/picture_link.png",
     OnRun = function(self)
          self.player:SendLua("SetClipboardText(\"https://iili.io/" .. self:GetData("Image") .. ".png\")")
          return false
     end,
     OnCanRun = function(self)
          return self:GetOwner() and IsValid(self:GetOwner())
     end
}

ITEM.functions["Abrir en el navegador"] = {
     tip = "Abrir en el navegador",
     icon = "icon16/page_world.png",
     OnRun = function(self)
          self.player:SendLua("gui.OpenURL(\"https://iili.io/" .. self:GetData("Image") .. ".png\")")
          return false
     end,
     OnCanRun = function(self)
          return self:GetOwner() and IsValid(self:GetOwner())
     end
}

ix.command.Add("CreatePolaroid", {
     arguments = { ix.type.string },
     argumentNames = { "código iili.io" },
     description = "Genera una tarjeta polaroid a partir del código de iili.io.",
     superAdminOnly = true,
     OnRun = function(self, client, id)
          local ent = ents.Create("ent_polaroid_print")
          ent:SetImage(id)
          ent:SetPos(client:GetItemDropPos(ent))
          ent:SetNWBool("IsFresh", true)
          ent:Spawn()
          ent:GetPhysicsObject():Wake()
          return false
     end
})