-- "addons\\sardonshineadmin\\lua\\sardon_shineadmin\\cl_page_sam.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Shine Admin :: SAM sayfası ("!menu" ile açılan admin menüsü)
--
-- SAM'in kendi sekmeleri (komutlar, oyuncular, rütbeler, banlar, ayarlar) olduğu
-- gibi bu sayfanın içine kurulur; SAM dosyalarına dokunulmaz. Sunucu tarafında
-- hiçbir şey eklenmedi: her komut ve her veri isteği yine SAM'in kendi sunucu
-- kontrolünden (rütbe yetkisi, dokunulmazlık, bekleme süresi) geçer. Buradaki
-- yetki kuralı yalnızca sayfanın kimde görüneceğini belirler.
--
-- "!menu" / "sam menu": sayfayı görebilenlerde Shine Admin'i bu sayfada açar.
-- Göremeyenlerde (sıradan oyuncu) ve Nocturne yoksa SAM'in eski penceresi açılır.

-- SAM sekme listesini yerel tutuyor; add_tab'in üst değerinden okunur.
local samTabs

local function SamTabs()
     if (samTabs) then return samTabs end
     if (!sam or !sam.menu or !isfunction(sam.menu.add_tab)) then return end

     for i = 1, 16 do
          local name, value = debug.getupvalue(sam.menu.add_tab, i)
          if (!name) then break end

          if (name == "tabs" and istable(value)) then
               samTabs = value
               return samTabs
          end
     end
end

ShineAdmin:RegisterPage("sam", {
     label = "Administración SAM",
     icon = "admin",
     group = "home",
     order = 2,
     title = "Menú de administración SAM",
     subtitle = "Comandos, jugadores, rangos, baneos y ajustes de SAM.",
     access = "sam",
     available = function()
          return sam and sam.SUI and vgui.GetControlTable("SAM.ColumnSheet") != nil and SamTabs() != nil
     end,

     build = function(ctx)
          local N = ShineAdmin.GetN()
          local u = N.u
          local GetColor = sam.SUI.GetColor

          local host = vgui.Create("EditablePanel", ctx.panel)
          host:SetPos(0, 0)
          host:SetSize(u(ctx.w), u(ctx.h))
          host:SUI_TDLib()
          host.Paint = function(s, w, h)
               draw.RoundedBox(8, 0, 0, w, h, GetColor("frame"))
          end
          host.PaintOver = function(s, w, h)
               N.Outline(0, 0, w, h, N.Clr.toolLine, 1)
          end

          -- sekmeler kurulurken sam.menu.get() ile pencereyi istiyor; önce bu atanmalı
          ShineAdmin.SamHost = host

          local sheet = host:Add("SAM.ColumnSheet")
          sheet:Dock(FILL)
          sheet:InvalidateParent(true)
          sheet:InvalidateLayout(true)
          sheet.Paint = nil

          local scroller = sheet.tab_scroller
          scroller:DockMargin(0, 1, 0, 1)
          scroller.Paint = function(s, w, h)
               draw.RoundedBoxEx(8, 0, 0, w, h, GetColor("column_sheet_bar"), true, false, true, false)
          end

          local tabs = SamTabs()
          local sheets = {}

          for _, tab in SortedPairsByMemberValue(tabs, "pos") do
               sheets[tab.icon] = sheet:AddSheet(tab.icon, tab.func)
          end

          -- yetkisi olmayan sekmeleri gizle (SAM penceresindeki döngünün aynısı)
          local canvas = scroller:GetCanvas()

          host:On("Think", function()
               for _, tab in ipairs(tabs) do
                    local button = sheets[tab.icon]
                    if (!IsValid(button)) then continue end

                    if (tab.check and !tab.check()) then
                         if (button:IsVisible()) then
                              button:SetVisible(false)

                              if (sheet:GetActiveTab() == button) then
                                   sheet:SetActiveTab(sheet.tabs[1])
                              end

                              canvas:InvalidateLayout()
                         end
                    elseif (!button:IsVisible()) then
                         button:SetVisible(true)
                         canvas:InvalidateLayout()
                    end
               end
          end)

          ctx.SetHead({
               badge = string.utf8upper(LocalPlayer():GetUserGroup() or "user"),
               badgeIcon = "shield"
          })

          ctx.OnLeave = function()
               if (ShineAdmin.SamHost == host) then ShineAdmin.SamHost = nil end
          end
     end
})

--[[
*   "!menu" yönlendirmesi
*
*   SAM'in "OpenMenu" alıcısı her seferinde sam.menu.open_menu()'yü çağırır; o
*   sarılır. Asıl işlevler bir kez saklanır, dosya yeniden yüklenince üst üste
*   sarılmaz.
]]

local function Install()
     if (!sam or !sam.menu or !isfunction(sam.menu.open_menu) or !isfunction(sam.menu.get)) then
          return false
     end

     ShineAdmin.SamOrig = ShineAdmin.SamOrig or {open = sam.menu.open_menu, get = sam.menu.get}
     local orig = ShineAdmin.SamOrig

     sam.menu.open_menu = function()
          if (!ShineAdmin.GetN() or !ShineAdmin:CanSee("sam")) then
               return orig.open()
          end

          -- SAM'deki gibi aç / kapat
          local win = ShineAdmin.Window

          if (IsValid(win) and win.Page == "sam") then
               win:Close()
               return
          end

          local old = orig.get()
          if (IsValid(old) and old:IsVisible()) then old:Hide() end

          ShineAdmin:Open("sam")
     end

     sam.menu.get = function()
          local host = ShineAdmin.SamHost
          if (IsValid(host)) then return host end

          return orig.get()
     end

     return true
end

if (!Install()) then
     hook.Add("InitPostEntity", "ShineAdmin.Sam", function()
          timer.Create("ShineAdmin.Sam", 2, 15, function()
               if (Install()) then timer.Remove("ShineAdmin.Sam") end
          end)
     end)
end
