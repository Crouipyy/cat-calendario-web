-- "addons\\sardonbaykus\\lua\\sardon_baykus\\cl_baykus.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
local baykusPng = Material("baykus/baykus_background.jpg")
hook.Add(
     "PostDrawTranslucentRenderables",
     "Baykus2",
     function(bDepth, bSkybox)
          -- 11-13 opt: 3B gökyüzü geçişinde çizme (göz önündeki mektup paneli karede iki kez boyanıyordu)
          if bSkybox then return end
          if not (BAYKUS_OPENSENDMENU and BAYKUS_OPENSENDMENU:IsValid()) or not LocalPlayer():Alive() then return end
          if ix.option.Get("thirdpersonEnabled", false) then ix.option.Set("thirdpersonEnabled", false) end
          cam.Start3D2D(EyePos() + EyeVector() * 4 + Vector(3, 3, 2.5 + math.sin(CurTime()) * 0.2), Angle(170, EyeAngles().y + 80, -95 + (math.sin(CurTime() + 30) * 2) + (EyeAngles().x * -1)), .01)
          BAYKUS_OPENSENDMENU:PaintManual()
          cam.End3D2D()
     end
)

BAYKUS_OPENSENDMENU = BAYKUS_OPENSENDMENU or nil
local parsomen = {Material("revolutionary_baykus/baykus_back.png"), Material("baykus/write.png")}
local clr_dark_text = Color(29, 29, 29)
local clr_dark_text_a = Color(29, 29, 29, 199)
local clr_follow_btn = Color(39, 15, 0, 133)
local clr_delete_bg = Color(39, 15, 0, 210)
local clr_bohca_bg = Color(39, 15, 0, 60)
local clr_bohca_sel = Color(200, 150, 60, 150)
function BAYKUSMENU_OPEN(target)
     local localPos = LocalPlayer():GetPos()
     if LocalPlayer():GetArea() == "Karanlık Orman" then
          chat.AddText(Color(255, 20, 20), "No puedes enviar ni recibir lechuzas mientras estás en el Bosque Oscuro.")
     else
          net.Start("update_baykusstat")
          net.WriteString("yzr")
          net.WriteBool(true)
          net.SendToServer()
          if IsValid(BAYKUS_OPENSENDMENU) then
               BAYKUS_OPENSENDMENU:Remove()
          end

          BAYKUS_OPENSENDMENU = vgui.Create("DFrame")
          BAYKUS_OPENSENDMENU:SetTitle("")
          BAYKUS_OPENSENDMENU:SetDraggable(false)
          BAYKUS_OPENSENDMENU:SetSize(415, 600)
          BAYKUS_OPENSENDMENU:Center()
          BAYKUS_OPENSENDMENU:MakePopup()
          local checkbox = vgui.Create("DCheckBox", BAYKUS_OPENSENDMENU)
          checkbox:SetPos(415 / 2 - 15 / 2, 35)

          local includeLocation = vgui.Create("DCheckBox", BAYKUS_OPENSENDMENU)
          includeLocation:SetPos(415 - 30, 600 - 30)

          function BAYKUS_OPENSENDMENU:Paint(w, h)
               surface.SetMaterial(parsomen[1])
               surface.SetDrawColor(color_white)
               surface.DrawTexturedRect(0, 0, w, h)
               draw.SimpleText("¿Anónimo?", "baykus_yazi", 415 / 2, 30, clr_dark_text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               draw.SimpleText("Incluir mi ubicación", "baykus_yazik", 415 - 35, 600 - 31, clr_dark_text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
          end

          function BAYKUS_OPENSENDMENU.OnRemove()
               net.Start("update_baykusstat")
               net.WriteString("yzr")
               net.WriteBool(false)
               net.SendToServer()
          end

          local text = vgui.Create("DTextEntry", BAYKUS_OPENSENDMENU)
          text:SetSize(310, 375)
          text:SetPos(60, 120)
          text:SetFont("baykus_yazi")
          text:SetMultiline(true)
          text:SetTextColor(Color(0, 0, 0, 240))
          text:SetEditable(true)
          text:SetPaintBackground(false)
          text:RequestFocus()
          function text:AllowInput()
               return #string.Explode("\n", text:GetValue()) > 12
          end

          -- Eşya bohçası seçici (bkz. cl_bohca.lua): sadece DOLU bohçalar listelenir,
          -- varsayılan "bohça yok" -- değerli eşyalar yanlışlıkla gitmesin.
          local bohcaChoice = 0
          local bohcas = SardonBaykus and SardonBaykus.GetSendableBohcas and SardonBaykus.GetSendableBohcas() or {}
          local bohcaBox = vgui.Create("DComboBox", BAYKUS_OPENSENDMENU)
          bohcaBox:SetPos(60, 497)
          bohcaBox:SetSize(295, 24)
          bohcaBox:SetFont("baykus_yazik")
          bohcaBox:SetTextColor(clr_dark_text)
          bohcaBox:SetSortItems(false)
          bohcaBox:AddChoice(#bohcas > 0 and "Sin bolsa" or "No tienes bolsas llenas", 0, true)
          for _, info in ipairs(bohcas) do
               bohcaBox:AddChoice(info.label .. (info.summary != "" and (" (" .. info.summary .. ")") or ""), info.id)
          end
          bohcaBox:SetEnabled(#bohcas > 0)
          function bohcaBox:OnSelect(_, _, data)
               bohcaChoice = data or 0
          end
          function bohcaBox:Paint(w, h)
               draw.RoundedBox(4, 0, 0, w, h, bohcaChoice != 0 and clr_bohca_sel or clr_bohca_bg)
          end

          local SendBtn = vgui.Create("DButton", BAYKUS_OPENSENDMENU)
          SendBtn:SetText("Enviar")
          SendBtn:SetSize(100, 30)
          SendBtn:SetPos((415 / 2) - 50, 530)
          SendBtn.DoClick = function()
               BAYKUS_OPENSENDMENU:Remove()
               net.Start("baykus_send")
               net.WriteEntity(target)
               net.WriteBool(checkbox:GetChecked())
               if includeLocation:GetChecked() then
                    local pos = LocalPlayer():GetPos()
                    net.WriteString(text:GetValue() .. "-----LOCDATA-" .. pos[1] .. ", " .. pos[2] .. ", " .. pos[3])
               else
                    net.WriteString(text:GetValue())
               end
               net.WriteUInt(bohcaChoice, 32)
               net.SendToServer()
          end
     end
end

hook.Add(
     "PopulateScoreboardPlayerMenu",
     "Baykus",
     function(target, menu)
          local bRecognize = LocalPlayer():GetCharacter():DoesRecognize(target:GetCharacter()) or hook.Run("IsPlayerRecognized", target)
          if not bRecognize then return end

          local ent = StPets.DoesHave(LocalPlayer(), "PetOwl")
          if ent then
               if not (ent and ent:GetPos():Distance(item:GetOwner():GetPos()) < 2000 and not ent:GetNWBool("busy", false)) then return end
          else
               if ply and ply:GetCharacter() and ply:GetCharacter():GetInventory() and #ply:GetCharacter():GetInventory():GetItemsByUniqueID("PetOwl") == 0 then return end
                    end

          menu:AddOption(
               "Enviar lechuza",
               function()
                    BAYKUSMENU_OPEN(target)
                    ix.gui.menu:Remove()
               end
          )
     end
)

BAYKUS_OPENMENU = BAYKUS_OPENMENU or nil
surface.CreateFont(
     "baykus_yazi",
     {
          font = "Jim Nightshade",
          extended = true,
          size = 24,
          weight = 600,
          blursize = 0,
          scanlines = 0,
          antialias = true,
          underline = false,
          italic = false,
          strikeout = false,
          symbol = false,
          rotary = false,
          shadow = false,
          additive = false,
          outline = false,
     }
)

surface.CreateFont(
     "baykus_yaziA",
     {
          font = "Jim Nightshade",
          extended = true,
          size = 52,
          weight = 600,
          blursize = 0,
          scanlines = 0,
          antialias = true,
          underline = false,
          italic = false,
          strikeout = false,
          symbol = false,
          rotary = false,
          shadow = false,
          additive = false,
          outline = false,
     }
)

surface.CreateFont(
     "baykus_yazik",
     {
          font = "Arial", --  Use the font-name which is shown to you by your operating system Font Viewer, not the file name
          extended = true,
          size = 15,
          weight = 900,
          blursize = 0,
          scanlines = 0,
          antialias = true,
          underline = false,
          italic = false,
          strikeout = false,
          symbol = false,
          rotary = false,
          shadow = false,
          additive = false,
          outline = false,
     }
)

surface.CreateFont(
     "baykus_yazikb",
     {
          font = "Arial", --  Use the font-name which is shown to you by your operating system Font Viewer, not the file name
          extended = true,
          size = 20,
          weight = 900,
          blursize = 0,
          scanlines = 0,
          antialias = true,
          underline = false,
          italic = false,
          strikeout = false,
          symbol = false,
          rotary = false,
          shadow = false,
          additive = false,
          outline = false,
     }
)

surface.CreateFont(
     "baykus_yaziT",
     {
          font = "Harry P", --  Use the font-name which is shown to you by your operating system Font Viewer, not the file name
          extended = true,
          size = 90,
          weight = 900,
          blursize = 0,
          scanlines = 0,
          antialias = true,
          underline = false,
          italic = false,
          strikeout = false,
          symbol = false,
          rotary = false,
          shadow = false,
          additive = false,
          outline = false,
     }
)

surface.CreateFont(
     "baykus_yaziD",
     {
          font = "Jim Nightshade", --  Use the font-name which is shown to you by your operating system Font Viewer, not the file name
          extended = true,
          size = (ScreenScale(108 * 3) * 415 / 600 + ScreenScale(5)) * 20 / 415,
          weight = 500,
          blursize = 0,
          scanlines = 0,
          antialias = true,
          underline = false,
          italic = false,
          strikeout = false,
          symbol = false,
          rotary = false,
          shadow = false,
          additive = false,
          outline = false,
     }
)

hook.Add(
     "PostDrawTranslucentRenderables",
     "Baykus",
     function(bDepth, bSkybox)
          -- 11-13 opt: 3B gökyüzü geçişinde çizme (göz önündeki mektup paneli karede iki kez boyanıyordu)
          if bSkybox then return end
          if not (BAYKUS_OPENMENU and BAYKUS_OPENMENU:IsValid()) or not LocalPlayer():Alive() then return end
          local ply = LocalPlayer()
          if ix.option.Get("thirdpersonEnabled") then
               cam.Start3D2D(ply:GetBonePosition(ply:LookupBone("ValveBiped.Bip01_Head1")) + ply:EyeAngles():Forward() * 15 + Vector(0, 0, 3 + math.sin(CurTime()) * 3), Angle(180, ply:EyeAngles().y + 90, -100 + (ply:EyeAngles().x * -0.5)), .02)
               BAYKUS_OPENMENU:PaintManual()
               cam.End3D2D()
          else
               cam.Start3D2D(EyePos() + EyeVector() * 6 + Vector(0, 0, 2.5 + math.sin(CurTime()) * 0.2), Angle(180, EyeAngles().y + 90, -95 + (math.sin(CurTime() + 30) * 2) + (EyeAngles().x * -1)), .005)
               BAYKUS_OPENMENU:PaintManual()
               cam.End3D2D()
          end
     end
)

hook.Add("PlayerButtonDown", 'BomamnaBaykoo', function(ply, key)
     if (key == SardonConfig:Get("baykus_next")) then
          if IsValid(BAYKUS_OPENMENU) then
               BAYKUS_OPENMENU:Remove()
               BAYKUS_OPENMENU = nil

               return
          end
     end
end)

net.Receive(
     "baykus_send",
     function()
          local data = net.ReadTable()
          if IsValid(BAYKUS_OPENMENU) and #data == 0 then
               BAYKUS_OPENMENU:Remove()
               BAYKUS_OPENMENU = nil

               return
          end

          if #data == 0 then return end
          OpenBaykusMessage(data[1], #data)
     end
)

local lastOwlPos = nil

function OpenBaykusMessage(msg, total)
     if IsValid(BAYKUS_OPENMENU) then
          BAYKUS_OPENMENU:Remove()
     end

     ix.option.Set("thirdpersonEnabled", false)
     net.Start("baykus_read")
     net.WriteString(msg.id)
     net.SendToServer()
     net.Start("update_baykusstat")
     net.WriteString("okyr")
     net.WriteBool(true)
     net.SendToServer()
     BAYKUS_OPENMENU = vgui.Create("DFrame")
     function BAYKUS_OPENMENU.OnRemove()
          net.Start("update_baykusstat")
          net.WriteString("okyr")
          net.WriteBool(false)
          net.SendToServer()
     end

     BAYKUS_OPENMENU:ShowCloseButton(false)
     BAYKUS_OPENMENU:SetSize(0, 0)
     BAYKUS_OPENMENU:SetTitle("")
     BAYKUS_OPENMENU:SetDraggable(false)
     BAYKUS_OPENMENU:SetPos(-622 / 2, -900)
     BAYKUS_OPENMENU:SetSize(622, 900)
     BAYKUS_OPENMENU:SetPaintedManually(true)
     function BAYKUS_OPENMENU:Paint(w, h)
          surface.SetMaterial(parsomen[1])
          surface.SetDrawColor(color_white)
          surface.DrawTexturedRect(0, 0, w, h)
          if msg.anonim ~= "1" then
               draw.SimpleText(msg.name or msg.sender, "baykus_yaziA", w / 2, 38, clr_dark_text_a, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          end
     end

     local locdat = string.Explode("-----LOCDATA-", msg.content)

     if locdat[2] then
          timer.Remove("BaykusExpiry")
          lastOwlPos = Vector(unpack(string.Explode(", ", locdat[2])))

          local FollowBtn = vgui.Create("DButton", BAYKUS_OPENMENU)
          FollowBtn:SetPos(60, 500)
          FollowBtn:SetSize(300, 40)
          function FollowBtn:Paint(w, h)
               draw.SimpleText("(" .. input.GetKeyName(SardonConfig:Get("baykus_mark")) .. ")", "baykus_yazik", 20, 10, clr_follow_btn, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               draw.SimpleText("Seguir ubicación", "baykus_yazikb", 20, 27, clr_follow_btn, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          end

          timer.Create("BaykusExpiry", 120, 1, function ()
               lastOwlPos = nil
          end)
     end

     local text = vgui.Create("DTextEntry", BAYKUS_OPENMENU)
     text:SetSize(500, 860)
     text:SetPos(60, 120)
     text:CenterHorizontal()
     text:SetFont("baykus_yaziA")
     text:SetMultiline(true)
     text:SetValue(locdat[1])
     text:SetTextColor(Color(0, 0, 0, 240))
     text:SetEditable(false)
     text:SetPaintBackground(false)

     local DeleteBtn = vgui.Create("DButton", BAYKUS_OPENMENU)
     DeleteBtn:SetText("")
     DeleteBtn:SetPos((415 / 2) - 150, 622)
     DeleteBtn:SetSize(300, 40)
     function DeleteBtn:Paint(w, h)
          draw.RoundedBox(5, 0, 0, 40, 40, clr_delete_bg)
          draw.SimpleText("(" .. input.GetKeyName(SardonConfig:Get("baykus_next")) .. ")", "baykus_yazik", 20, 10, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          draw.SimpleText("X", "baykus_yazikb", 20, 27, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end
end

hook.Add("PlayerButtonUp", "BaykusTakipNavigo", function (_, key)
     if not IsFirstTimePredicted() or key != SardonConfig:Get("baykus_mark") or not lastOwlPos then return end

     LocalPlayer():Notify("Usa la tecla [ALT] para seguir la ubicación de la lechuza.")
     GMap.OwlPos = {
          lastOwlPos,
          CurTime()
     }
end)

BAYKUS_LISTMENU = BAYKUS_LISTMENU or nil

local revolutionaryMaterials = {Material("revolutionary_baykus/cardBack.png", "smooth nocull"), Material("revolutionary_baykus/cardFront.png", "smooth nocull")}
net.Receive(
     "baykus_list",
     function()
          if IsValid(BAYKUS_LISTMENU) then
               BAYKUS_LISTMENU:Remove()

               return
          end

          local data = net.ReadTable()
          BAYKUS_LISTMENU = vgui.Create("DFrame")
          local __t = ScreenScale(5)
          local t = 145
          BAYKUS_LISTMENU:SetSize(ScreenScale(108 * 3) * 415 / 600 + t, ScreenScale(108 * 3))
          BAYKUS_LISTMENU:Center()
          BAYKUS_LISTMENU:MakePopup()
          BAYKUS_LISTMENU:SetTitle("Mis lechuzas")
          local activeText = BAYKUS_LISTMENU:Add("DPanel")

          activeText:Dock(FILL)
          local text = activeText:Add("DTextEntry")
          text:SetSize(310, 375)
          text:SetFont("baykus_yaziD")
          text:SetEditable(false)
          text:SetPaintBackground(false)
          text:SetTextColor(Color(0, 0, 0, 240))
          text:SetMultiline(true)
          text:DockMargin(45, 80, 45, 20)
          text:Dock(FILL)

          local author = activeText:Add("DLabel")
          author:SetPaintBackground(false)
          author:SetFont("baykus_yaziD")
          author:SetTextColor(Color(0, 0, 0, 240))
          author:SetContentAlignment(5)
          author:DockMargin(0, 50, 0, 0)
          author:Dock(TOP)
          author:SetText("")


          function activeText:Paint(_w, h)
               local w = h * 415 / 600

               if #text:GetText() ~= 0 then
                    surface.SetMaterial(parsomen[1])
                    surface.SetDrawColor(color_white)
                    surface.DrawTexturedRect(0, 0, w, h)
                    surface.DrawTexturedRect(0, 0, w, h)
               end
          end

          -- function BAYKUS_LISTMENU:Paint(w, h)
          --      surface.SetMaterial(baykusPng)
          --      surface.SetDrawColor(Color(255, 255, 255))
          --      surface.DrawTexturedRect(0, 0, w, h)
          -- end
          local scrollable = vgui.Create("DScrollPanel", BAYKUS_LISTMENU)

          scrollable:SetWide(t)
          scrollable:DockPadding(__t, __t, __t, __t)
          scrollable:Dock(LEFT)
          local grid = vgui.Create("DGrid", scrollable)
          grid:SetCols(1)

          grid:SetColWide(t)
          grid:SetRowHeight(t)
          for key, value in ipairs(data) do
               local item = grid:Add("DButton")
               item:SetSize(t, t)
               item:SetText("")
               local mdlPanel = nil
               if value.mdl then
                    mdlPanel = item:Add("BaykusIcon")
                    mdlPanel:CenterHorizontal()
                    mdlPanel:SetY(t - 105)
                    mdlPanel:SetX(mdlPanel:GetX() + 2)
                    mdlPanel:SetPaintedManually(true)
                    mdlPanel:SetMouseInputEnabled(false)

                    for _, v in ipairs(string.Explode("", value.bgs)) do
                         mdlPanel:SetBodygroup(_ - 1, tonumber(v))
                    end
                    mdlPanel:SetModel(value.mdl, 0)
                    mdlPanel:SetHidden(value.anonim == "1")
               end

               item.DoClick = function ()
                    text:SetText(value.content)
                    author:SetText(value.anonim == "0" and (value.name or value.sender) or "")
                    author:SizeToContents()
                    author:CenterHorizontal()
               end

               function item:Paint(w, h)
                    surface.SetMaterial(revolutionaryMaterials[1])
                    surface.SetDrawColor(color_white)
                    surface.DrawTexturedRect(0, 0, w, h)
                    if mdlPanel then
                         mdlPanel:PaintManual()
                    end

                    surface.SetMaterial(revolutionaryMaterials[2])
                    surface.SetDrawColor(color_white)
                    surface.DrawTexturedRect(0, 0, w, h)
                    -- if value.anonim ~= "1" then
                    --      draw.SimpleText(value.sender, "baykus_yazi", __w / 2, 27, Color(29, 29, 29, 199), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    -- end
                    -- draw.SimpleText(os.date("%H:%M:%S - %d/%m/%Y", tonumber(value.timestamp)), "baykus_yazi", 40, 540, Color(39, 15, 0, 231), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               end

               -- local text = vgui.Create("DTextEntry", item)
               -- text:SetSize(__h * 1.93, __w * 1.106)
               -- text:SetPos(60, 120)
               -- text:SetFont("baykus_yazi")
               -- text:SetMultiline(true)
               -- text:SetValue(value.content)
               -- text:SetTextColor(Color(0, 0, 0, 240))
               -- text:SetEditable(false)
               -- text:SetPaintBackground(false)
               -- local btn = vgui.Create("DButton", item)
               -- btn:SetText("")
               -- btn:SetImage("icon16/cancel.png")
               -- btn:SetSize(25, 25)
               -- btn:SetPos(370, 20)
               -- btn.DoClick = function()
               --      net.Start("baykus_list")
               --      net.WriteString(value.id)
               --      net.SendToServer()
               --      grid:RemoveItem(item)
               --      item:Remove()
               -- end
               grid:AddItem(item)
          end
     end
)

util.PrecacheModel("models/spottedowl_flying.mdl")

--hook.Add("HUDPaint", "baykusnotify", function ()
     --local ply = LocalPlayer()

    -- if not ply then return end

   --  local count = ply:GetNWInt("baykus_inbox", 0)

   --  if count == 0 then
--if IsValid(POSTOWLCSENT) then
   --            POSTOWLCSENT:Remove()
     --     end
--return
    -- end

     --draw.DrawText(count .. " tane baykuş mesajınız var [" .. input.GetKeyName(SardonConfig:Get("baykus_next")):upper() .. "]", "scoreB", 10, 10, color_white)
--end)

do
     local PANEL = {}
     local BODYGROUPS_EMPTY = "000000000"
     AccessorFunc(PANEL, "model", "Model", FORCE_STRING)
     AccessorFunc(PANEL, "bHidden", "Hidden", FORCE_BOOL)
     function PANEL:Init()
          self:SetSize(72, 72)
          self.bodygroups = BODYGROUPS_EMPTY
     end

     function PANEL:SetModel(model, skin, bodygroups)
          model = model:gsub("\\", "/")
          if isstring(bodygroups) then
               if bodygroups:len() == 9 then
                    for i = 1, bodygroups:len() do
                         self:SetBodygroup(i, tonumber(bodygroups[i]) or 0)
                    end
               else
                    self.bodygroups = BODYGROUPS_EMPTY
               end
          end

          self.model = model
          self.skin = skin
          self.path = "materials/spawnicons/" .. model:sub(1, #model - 4) .. ((isnumber(skin) and skin > 0) and ("_skin" .. tostring(skin)) or "") .. (self.bodygroups ~= BODYGROUPS_EMPTY and ("_" .. self.bodygroups) or "") .. ".png" -- remove extension -- skin number -- bodygroups
          local material = Material(self.path, "smooth")
          -- we don't have a cached spawnicon texture, so we need to forcefully generate one
          if material:IsError() then
               self.id = "ixScoreboardIcon" .. self.path
               self.renderer = self:Add("ModelImage")
               self.renderer:SetVisible(false)
               self.renderer:SetModel(model, skin, self.bodygroups)
               self.renderer:RebuildSpawnIcon()
               -- this is the only way to get a callback for generated spawn icons, it's bad but it's only done once
               hook.Add(
                    "SpawniconGenerated",
                    self.id,
                    function(lastModel, filePath, modelsLeft)
                         filePath = filePath:gsub("\\", "/"):lower()
                         if filePath == self.path then
                              hook.Remove("SpawniconGenerated", self.id)
                              self.material = Material(filePath, "smooth")
                              self.renderer:Remove()
                         end
                    end
               )
          else
               self.material = material
          end
     end

     function PANEL:SetBodygroup(k, v)
          if k < 0 or k > 8 or v < 0 or v > 9 then return end
          self.bodygroups = self.bodygroups:SetChar(k + 1, v)
     end

     function PANEL:GetModel()
          return self.model or "models/error.mdl"
     end

     function PANEL:GetSkin()
          return self.skin or 1
     end

     function PANEL:DoClick()
     end

     function PANEL:DoRightClick()
     end

     function PANEL:OnMouseReleased(key)
          if key == MOUSE_LEFT then
               self:DoClick()
          elseif key == MOUSE_RIGHT then
               self:DoRightClick()
          end
     end

     function PANEL:Paint(width, height)
          if not self.material then return end
          surface.SetMaterial(self.material)
          surface.SetDrawColor(self.bHidden and color_black or color_white)
          surface.DrawTexturedRect(0, 0, width, height)
     end

     function PANEL:Remove()
          if self.id then
               hook.Remove("SpawniconGenerated", self.id)
          end
     end

     vgui.Register("BaykusIcon", PANEL, "Panel")
end

hook.Add(
     "PostPlayerDraw",
     "baykusDonen",
     function(ply)
          if ply:GetNWBool("baykus_yzr", false) then
               render.Model(
                    {
                         model = "models/hornedowl_flying.mdl",
                         pos = ply:EyePos() + Vector(0, 0, 30 + math.sin(CurTime()) * 5),
                         angle = Angle(0, CurTime() * 50, 0)
                    }
               )
          end

          if LocalPlayer() ~= ply and ply:GetNWBool("baykus_okyr", false) then
               cam.Start3D2D(ply:GetBonePosition(ply:LookupBone("ValveBiped.Bip01_Head1")) + ply:EyeAngles():Forward() * 15 + Vector(0, 0, 3 + math.sin(CurTime()) * 3), Angle(180, ply:EyeAngles().y + 90, -100 + (ply:EyeAngles().x * -0.5)), .02)
               surface.SetMaterial(parsomen[1])
               surface.SetDrawColor(color_white)
               surface.DrawTexturedRect(-415 / 2, -600, 415, 600)
               cam.End3D2D()
               cam.Start3D2D(ply:GetBonePosition(ply:LookupBone("ValveBiped.Bip01_Head1")) + ply:EyeAngles():Forward() * 15 + Vector(0, 0, 3 - math.sin(CurTime()) * 3), Angle(180, ply:EyeAngles().y - 90, -70 - (ply:EyeAngles().x * -0.5)), .02)
               surface.SetMaterial(parsomen[1])
               surface.SetDrawColor(color_white)
               surface.DrawTexturedRect(-415 / 2, -600, 415, 600)
               cam.End3D2D()
          end
     end
)

hook.Remove("SetupWorldFog", "StormFox2.Sky.WorldFog")
