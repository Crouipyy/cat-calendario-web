-- "addons\\sardonshineadmin\\lua\\sardon_shineadmin\\cl_page_systems.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Shine Admin :: sistem sayfaları (baykuş, parşömen) ve kendi penceresini açan araçlar

--[[
*   baykuş  ([sardon] baykus :: cl_admin.lua'daki sekme kodu gömülü çalışır)
]]

ShineAdmin:RegisterPage("baykus", {
     label = "Correo de búho",
     icon = "feather",
     group = "systems",
     order = 10,
     title = "Correo de búho",
     subtitle = "Paquetes, permisos de objetos, mensajes, registros y ajustes del sistema.",
     access = "staff",
     available = function()
          return SardonBaykus and SardonBaykus.AdminTabs and vgui.GetControlTable("SardonBaykus.AdminPage") != nil
     end,

     build = function(ctx)
          local N = ShineAdmin.GetN()
          local u = N.u
          local P = ctx.panel

          local tabs = {}
          for _, tab in ipairs(SardonBaykus.AdminTabs) do
               tabs[#tabs + 1] = {tab.id, tab.name}
          end

          local page

          N.SubTabs(P, 0, 0, u(ctx.w), tabs, function()
               return IsValid(page) and page.activeTab or "overview"
          end, function(id)
               if (IsValid(page)) then page:ShowTab(id) end
          end)

          page = vgui.Create("SardonBaykus.AdminPage", P)
          page:SetPos(0, u(56))
          page:SetSize(u(ctx.w), u(ctx.h - 56))

          -- baykuşun veri alıcısı açık pencereye yazar; gömülü sayfa o pencere oluyor
          SardonBaykus.AdminFrame = page

          if (ctx.arg and ctx.arg.data) then
               page:SetData(ctx.arg.data)
          else
               RunConsoleCommand("baykus_admin")
          end

          ctx.SetHead({
               note = function()
                    local s = IsValid(page) and page.data and page.data.stats
                    return s and ((s.flights or 0) .. " EN VUELO  ·  " .. (s.pending or 0) .. " PENDIENTES") or "CARGANDO"
               end
          })

          ctx.OnLeave = function()
               if (SardonBaykus.AdminFrame == page) then SardonBaykus.AdminFrame = nil end
          end
     end
})

--[[
*   parşömen ayarları  ([hogwarts] lparsomen :: lparsomen.parsomenmiktar)
]]

ShineAdmin:RegisterPage("parsomen", {
     label = "Ajustes de pergamino",
     icon = "book",
     group = "magic",
     order = 30,
     title = "Ajustes de pergamino",
     subtitle = "Define cuántos pergaminos hacen falta para aprender cada hechizo.",
     access = "staff",
     rail = true,
     available = function() return lparsomen and HpwRewrite and HpwRewrite.GetSpells end,

     build = function(ctx)
          local N = ShineAdmin.GetN()
          local u = N.u
          local P = ctx.panel
          local W, H = ctx.w, ctx.h

          local defaultCount = tonumber(lparsomen.config and lparsomen.config.defaultparsomen) or 1
          local counts = {}
          local loaded = false
          local search = ""
          local sel
          local amount = defaultCount
          local list, slider

          local function rows()
               local out = {}

               for name in pairs(HpwRewrite:GetSpells()) do
                    if (search == "" or string.find(string.lower(name), search, 1, true)) then
                         out[#out + 1] = {name = name, count = counts[name], custom = counts[name] != nil}
                    end
               end

               table.sort(out, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
               return out
          end

          local function refresh()
               if (IsValid(list)) then list:SetItems(rows(), true) end
          end

          N.TextEntry(P, 0, 0, u(W), u(36), "Buscar hechizo", function(v)
               search = string.lower(string.Trim(v or ""))
               refresh()
          end)

          local head = vgui.Create("DPanel", P)
          head:SetPos(0, u(46))
          head:SetSize(u(W), u(30))
          head.Paint = function(s, w, h)
               N.TableHead(0, 0, w, {
                    {"Hechizo", u(16)},
                    {"Pergaminos necesarios", w - u(200)},
                    {"Origen", w - u(24), TEXT_ALIGN_RIGHT}
               })
          end

          list = N.VList(P, 0, u(76), u(W), u(H - 76 - 64), {
               rowH = u(38),
               gapY = 0,
               emptyText = "No se encontró ningún hechizo.",
               onClick = function(r)
                    sel = r.name
                    amount = r.count or defaultCount
                    if (IsValid(slider)) then slider.Slider:SetValue(amount) end
               end,
               paintRow = function(r, i, x, y, w, h, hovered)
                    local on = sel == r.name

                    if (on) then
                         N.Box(x, y, w, h, N.Clr.selRow)
                         N.Box(x, y, u(2), h, N.Clr.gold)
                    elseif (hovered) then
                         N.Box(x, y, w, h, N.Clr.hoverRow)
                    end

                    N.Box(x, y + h - 1, w, 1, N.Clr.tableLine)
                    N.Text(N.Clip(r.name, "row", w - u(240)), "row", x + u(16), y + h / 2, on and N.Clr.text or N.Clr.tdFirst, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    N.Text(tostring(r.count or defaultCount), "strong", x + w - u(200), y + h / 2, r.custom and N.Clr.gold or N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    N.Text(r.custom and "personalizado" or "predeterminado", "tiny", x + w - u(24), y + h / 2, r.custom and N.Clr.badgeText or N.Clr.faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
               end
          })

          local bar = N.StickyBar(P, 0, u(H - 56), u(W), function() end)

          slider = N.Slider(bar, 0, 0, u(W) - u(190), "Cantidad de pergaminos para el hechizo seleccionado", 1, 3000, 0,
               function() return amount end,
               function(v) amount = math.Clamp(math.Round(tonumber(v) or 1), 1, 3000) end)

          local save = N.Button(bar, u(W) - u(176), u(9), u(176), u(36), "Guardar", function()
               if (!sel) then return end

               net.Start("lparsomen.parsomenmiktar")
                    net.WriteString(sel)
                    net.WriteInt(amount, 32)
               net.SendToServer()

               ctx.Flash(sel .. " — pergaminos necesarios: " .. amount)
          end, "primary")
          save.Think = function(s) s:SetEnabled(sel != nil and loaded) end

          ctx.SetRail({
               hero = "icons/book",
               badge = {text = "Registro del servidor", icon = "server"},
               title = function() return sel or "Elige un hechizo" end,
               body = "Elige un hechizo de la lista, ajusta los pergaminos con el control deslizante y guarda. Los hechizos sin valor personalizado usan el predeterminado.",
               props = function()
                    local custom = table.Count(counts)
                    return {
                         {"Predeterminado", defaultCount},
                         {"Hechizos personalizados", custom},
                         {"Total de hechizos", table.Count(HpwRewrite:GetSpells())},
                         {"Valor del hechizo seleccionado", sel and (counts[sel] or defaultCount) or "—", N.Clr.gold}
                    }
               end,
               note = function() return loaded and "" or "Solicitando tabla al servidor…" end
          })

          ctx.SetRows = function(data)
               counts = {}

               for _, row in pairs(data or {}) do
                    if (istable(row) and row.buyu) then counts[row.buyu] = tonumber(row.adet) end
               end

               loaded = true
               refresh()
          end

          ctx.SetHead({count = function() return table.Count(counts) end, note = "PERSONALIZ."})

          refresh()

          if (ctx.arg and ctx.arg.rows) then
               ctx.SetRows(ctx.arg.rows)
          else
               ShineAdmin:Request("parsomen")
          end
     end
})

-- /kademe ve kaydetme yanıtı bu sayfaya gelir
ShineAdmin:Route("lparsomen.parsomenmiktar", function()
     local rows = net.ReadTable()
     local ctx = ShineAdmin:ActiveCtx("parsomen")

     if (ctx and ctx.SetRows) then
          ctx.SetRows(rows)
     else
          ShineAdmin:Open("parsomen", {rows = rows})
     end
end)

--[[
*   kendi penceresini açan araçlar
]]

ShineAdmin:RegisterPage("ders", ShineAdmin.LauncherPage({
     label = "Menú de clases",
     icon = "graduation",
     group = "systems",
     order = 30,
     title = "Menú de clases",
     subtitle = "Inicia una clase, ponla en cola o termínala.",
     access = "professor",
     available = function() return concommand.GetTable()["fx_ders_menu"] != nil end,
     description = "Herramienta para que los profesores gestionen las clases: iniciar, cola y finalizar desde esta ventana. Requiere casa de profesor, admin, bandera \"d\" o permiso \"ders\".",
     steps = {
          {"Abrir herramienta", "El menú de clases se abre en una ventana aparte."},
          {"Elegir clase", "Selecciona hechizo y curso e inicia la clase o ponla en cola."},
          {"Terminar", "Al acabar la clase, ciérrala desde el mismo menú."}
     },
     buttonLabel = "Abrir menú de clases",
     launch = function() RunConsoleCommand("fx_ders_menu") end
}))

ShineAdmin:RegisterPage("itemmenu", ShineAdmin.LauncherPage({
     label = "Menú de objetos",
     icon = "download",
     group = "tools",
     order = 10,
     title = "Menú de objetos",
     subtitle = "Obtén objetos de Helix o créalos en el suelo.",
     access = "itemmenu",
     available = function() return vgui.GetControlTable("ixItemMenu") != nil end,
     description = "Menú de creación de objetos del gamemode. Se desliza desde la derecha; también con C (menú contextual).",
     buttonLabel = "Abrir menú de objetos",
     launch = function()
          vgui.Create("ixItemMenu")

          if (IsValid(ix.gui.itemmenu)) then
               ix.gui.itemmenu:SetVisible(true)
               ix.gui.itemmenu:MoveTo(ScrW() - 350, 0, 0.2, 0, -1)
          end
     end
}))

ShineAdmin:RegisterPage("stock", ShineAdmin.LauncherPage({
     label = "Gestión de bolsa",
     icon = "lightning",
     group = "tools",
     order = 20,
     title = "Gestión de bolsa",
     subtitle = "Consulta el mercado y crea eventos bursátiles.",
     access = "staff",
     available = function() return stocks != nil end,
     description = "Ventana de administración del complemento de bolsa (!stockadmin). Abre o cierra mercados y crea eventos que afectan los precios.",
     buttonLabel = "Abrir gestión de bolsa",
     launch = function() ShineAdmin:Request("stock") end
}))

ShineAdmin:RegisterPage("ztheme", ShineAdmin.LauncherPage({
     label = "Música por zonas",
     icon = "moon",
     group = "tools",
     order = 30,
     title = "Música por zonas (ZTheme)",
     subtitle = "Coloca zonas de música y efectos en el mapa.",
     access = function(ply)
          -- sv_ztheme.lua hasAccess ile aynı
          return IsValid(ply) and (ply:IsSuperAdmin() or (ZTHEME and ZTHEME.Config and ZTHEME.Config.MenuRank and ZTHEME.Config.MenuRank[ply:GetUserGroup()]))
     end,
     available = function() return ZTHEME != nil end,
     description = "Menú de zonas ZTheme (!ztheme). Asigna música, radio y efectos de partículas a cada zona.",
     buttonLabel = "Abrir menú ZTheme",
     launch = function() RunConsoleCommand("say", "!ztheme") end
}))
