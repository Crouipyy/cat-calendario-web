-- "addons\\sardonbaykus\\lua\\sardon_baykus\\cl_admin.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- /baykus_admin -- baykuş sistemi yönetim paneli (istemci). Sunucu: sv_admin.lua.
-- Sekmeler: Genel Bakış, Eşya İzinleri (whitelist), Havadaki Bohçalar, Bekleyen Bohçalar,
-- Mesajlar, Kayıtlar, Ayarlar. Tüm veri sunucudan tek pakette geliyor; her işlemden
-- sonra sunucu güncel veriyi yeniden yolluyor.
SardonBaykus = SardonBaykus or {}

surface.CreateFont("SardonBaykus.AdmTitle", {font = "Georgia", size = 24, weight = 700, extended = true, antialias = true})
surface.CreateFont("SardonBaykus.AdmHead", {font = "Georgia", size = 17, weight = 700, extended = true, antialias = true})
surface.CreateFont("SardonBaykus.AdmText", {font = "Tahoma", size = 14, weight = 500, extended = true, antialias = true})
surface.CreateFont("SardonBaykus.AdmSmall", {font = "Tahoma", size = 12, weight = 600, extended = true, antialias = true})
surface.CreateFont("SardonBaykus.AdmBtn", {font = "Tahoma", size = 14, weight = 800, extended = true, antialias = true})
surface.CreateFont("SardonBaykus.AdmStat", {font = "Georgia", size = 30, weight = 700, extended = true, antialias = true})

-- Renkler asa menüsü (Nocturne) paletine göre: panel Shine Admin içinde gömülü açılıyor
local T = {
     bg = Color(9, 15, 25, 252),
     side = Color(13, 20, 31, 255),
     panel = Color(16, 26, 38, 245),
     panel2 = Color(27, 38, 52, 250),
     line = Color(122, 143, 162, 60),
     gold = Color(201, 174, 119),
     goldDim = Color(150, 130, 90),
     text = Color(233, 228, 216),
     muted = Color(146, 154, 162),
     red = Color(191, 96, 88),
     green = Color(136, 180, 157),
     blue = Color(126, 164, 200),
     rowAlt = Color(255, 255, 255, 5),
     rowHover = Color(201, 174, 119, 12),
     rowSel = Color(201, 174, 119, 32)
}

local KIND_NAMES = {
     send = "Envío",
     deliver = "Entrega",
     drop = "Caída por Accio",
     pickup = "Recogida",
     ["return"] = "Devolución",
     pending = "En espera",
     admin = "Administración"
}

local KIND_COLORS = {
     send = T.gold,
     deliver = T.green,
     drop = T.red,
     pickup = Color(230, 150, 70),
     ["return"] = T.muted,
     pending = T.muted,
     admin = T.blue
}

local function Send(action, payload)
     net.Start("SardonBaykus.Admin")
          net.WriteString(action)
          net.WriteTable(payload or {})
     net.SendToServer()
end

local function Box(x, y, w, h, bg, border)
     draw.RoundedBox(2, x, y, w, h, border or T.line)
     draw.RoundedBox(2, x + 1, y + 1, w - 2, h - 2, bg)
end

local function FormatTime(ts)
     return ts and ts > 0 and os.date("%d.%m.%Y %H:%M", ts) or "-"
end

local function FormatDuration(sec)
     sec = math.max(0, math.floor(sec or 0))

     return sec >= 60 and (math.floor(sec / 60) .. " min " .. (sec % 60) .. " s") or (sec .. " s")
end

local function Button(parent, text, color, onClick)
     local btn = parent:Add("DButton")
     btn:SetText("")
     btn.label = text
     btn.accent = color or T.gold
     btn.DoClick = function(panel)
          if (!panel:GetDisabled()) then
               surface.PlaySound("ui/buttonclick.wav")
               onClick(panel)
          end
     end

     btn.Paint = function(panel, w, h)
          local disabled = panel:GetDisabled()
          local accent = disabled and T.line or panel.accent
          local hovered = panel:IsHovered() and !disabled

          draw.RoundedBox(2, 0, 0, w, h, accent)
          draw.RoundedBox(2, 1, 1, w - 2, h - 2, hovered and T.panel2 or T.panel)
          draw.SimpleText(panel.label, "SardonBaykus.AdmBtn", w / 2, h / 2, disabled and T.muted or accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end

     return btn
end

local function StyleScroll(vbar)
     vbar:SetWide(8)
     vbar.Paint = function() end
     vbar.btnUp.Paint = function() end
     vbar.btnDown.Paint = function() end
     vbar.btnGrip.Paint = function(_, w, h)
          draw.RoundedBox(4, 1, 0, w - 2, h, T.goldDim)
     end
end

local function TextEntry(parent, placeholder)
     local entry = parent:Add("DTextEntry")
     entry:SetFont("SardonBaykus.AdmText")
     entry:SetUpdateOnType(true)
     entry.Paint = function(panel, w, h)
          Box(0, 0, w, h, T.bg, panel:HasFocus() and T.gold or T.line)
          panel:DrawTextEntryText(T.text, T.gold, T.text)

          if (panel:GetValue() == "" and !panel:HasFocus() and placeholder) then
               draw.SimpleText(placeholder, "SardonBaykus.AdmText", 8, h / 2, T.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          end
     end

     return entry
end

local function ComboBox(parent, choices, selected, onSelect)
     local box = parent:Add("DComboBox")
     box:SetFont("SardonBaykus.AdmText")
     box:SetTextColor(T.text)
     box:SetSortItems(false)

     for _, choice in ipairs(choices) do
          box:AddChoice(choice[1], choice[2], choice[2] == selected)
     end

     box.Paint = function(panel, w, h)
          Box(0, 0, w, h, T.bg, panel:IsHovered() and T.gold or T.line)
     end

     box.OnSelect = function(_, _, _, data)
          onSelect(data)
     end

     return box
end

-- Temaya uygun DListView. AddRow(lv, colorOrNil, ...) ile satır ekle.
local function ListView(parent, columns)
     local lv = parent:Add("DListView")
     lv:SetMultiSelect(false)
     lv:SetHeaderHeight(26)
     lv:SetDataHeight(24)
     lv.Paint = function(_, w, h)
          Box(0, 0, w, h, T.panel)
     end

     StyleScroll(lv.VBar)

     for _, col in ipairs(columns) do
          local column = lv:AddColumn(col[1])

          if (col[2]) then
               column:SetFixedWidth(col[2])
          end

          column.Header:SetFont("SardonBaykus.AdmSmall")
          column.Header:SetTextColor(T.gold)
          column.Header.Paint = function(_, w, h)
               surface.SetDrawColor(T.side)
               surface.DrawRect(0, 0, w, h)
               surface.SetDrawColor(T.line)
               surface.DrawRect(0, h - 1, w, 1)
               surface.DrawRect(w - 1, 4, 1, h - 8)
          end
     end

     return lv
end

local function AddRow(lv, color, ...)
     local line = lv:AddLine(...)

     for _, label in ipairs(line.Columns) do
          label:SetFont("SardonBaykus.AdmText")
          label:SetTextColor(color or T.text)
     end

     line.Paint = function(panel, w, h)
          if (panel:IsSelected()) then
               surface.SetDrawColor(T.rowSel)
          elseif (panel:IsHovered()) then
               surface.SetDrawColor(T.rowHover)
          elseif (panel:GetID() % 2 == 0) then
               surface.SetDrawColor(T.rowAlt)
          else
               return
          end

          surface.DrawRect(0, 0, w, h)
     end

     return line
end

local function SetRowColor(line, color)
     for _, label in ipairs(line.Columns) do
          label:SetTextColor(color)
     end
end

local function ReadOnlyText(parent)
     local text = parent:Add("DTextEntry")
     text:SetMultiline(true)
     text:SetEditable(false)
     text:SetVerticalScrollbarEnabled(true)
     text:SetFont("SardonBaykus.AdmText")
     text.Paint = function(panel, w, h)
          Box(0, 0, w, h, T.bg)
          panel:DrawTextEntryText(T.text, T.gold, T.text)
     end

     return text
end

-- ============= SEKMELER =============
-- Her sekme: Build(frame, container, data) -- container her veri yenilemesinde temizlenip
-- yeniden kuruluyor; kalıcı olması gereken durum (whitelist taslağı, seçim, filtre) frame'de.

local TABS = {}

TABS[1] = {id = "overview", name = "Resumen", icon = "icon16/chart_bar.png"}

TABS[1].Build = function(frame, c, data)
     local s = data.stats or {}
     local cards = {
          {"Mensajes totales", s.totalMessages, T.gold},
          {"No leídos", s.unread, T.muted},
          {"Lechuzas en vuelo", s.owlsOut, T.blue},
          {"Bolsas en vuelo", s.flights, T.gold},
          {"Bolsas pendientes", s.pending, (s.pending or 0) > 0 and T.red or T.muted},
          {"Envíos (24h)", s.sent24, T.green},
          {"Con bolsa (24h)", s.bohca24, T.green},
          {"Accio (24h)", s.drops24, T.red},
          {"Objetos permitidos", s.whitelisted, (s.whitelisted or 0) == 0 and T.red or T.gold}
     }

     local grid = c:Add("DPanel")
     grid:Dock(TOP)
     grid:SetTall(3 * 92)
     grid.Paint = function(panel, w, h)
          local cw = (w - 2 * 12) / 3

          for i, card in ipairs(cards) do
               local col = (i - 1) % 3
               local row = math.floor((i - 1) / 3)
               local x, y = col * (cw + 12), row * 92

               Box(x, y, cw, 80, T.panel)
               surface.SetDrawColor(card[3])
               surface.DrawRect(x + 1, y + 10, 3, 60)
               draw.SimpleText(card[1], "SardonBaykus.AdmSmall", x + 16, y + 20, T.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               draw.SimpleText(tostring(card[2] or 0), "SardonBaykus.AdmStat", x + 16, y + 52, card[3], TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          end
     end

     if ((s.whitelisted or 0) == 0) then
          local warn = c:Add("DPanel")
          warn:Dock(TOP)
          warn:DockMargin(0, 4, 0, 8)
          warn:SetTall(34)
          warn.Paint = function(_, w, h)
               Box(0, 0, w, h, Color(70, 25, 20, 230), T.red)
               draw.SimpleText("Aún no se ha permitido ningún objeto -- los jugadores solo pueden poner Galleons en la bolsa. Elígelos en la pestaña \"Permisos de objetos\".", "SardonBaykus.AdmText", 12, h / 2, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          end
     end

     local head = c:Add("DLabel")
     head:Dock(TOP)
     head:DockMargin(0, 6, 0, 6)
     head:SetFont("SardonBaykus.AdmHead")
     head:SetTextColor(T.text)
     head:SetText("Últimos eventos")

     local lv = ListView(c, {{"Fecha", 120}, {"Tipo", 110}, {"Remitente", 150}, {"Destinatario", 150}, {"Detalle"}})
     lv:Dock(FILL)

     for i, log in ipairs(data.logs or {}) do
          if (i > 40) then
               break
          end

          AddRow(lv, KIND_COLORS[log.kind], FormatTime(log.time), KIND_NAMES[log.kind] or log.kind, log.sender, log.receiver, log.details)
     end
end

TABS[2] = {id = "whitelist", name = "Permisos de objetos", icon = "icon16/basket_put.png"}

TABS[2].Build = function(frame, c, data)
     local state = frame.wl

     local top = c:Add("DPanel")
     top:Dock(TOP)
     top:SetTall(32)
     top.Paint = function() end

     local search = TextEntry(top, "Buscar nombre o ID de objeto...")
     search:Dock(LEFT)
     search:SetWide(260)
     search:SetValue(state.search or "")

     local categories = {}
     local seen = {}

     for _, item in pairs(ix.item.list) do
          local cat = item.category or "Otros"

          if (!seen[cat]) then
               seen[cat] = true
               table.insert(categories, {L(cat), cat})
          end
     end

     table.sort(categories, function(a, b) return a[1] < b[1] end)
     table.insert(categories, 1, {"Todas las categorías", ""})

     local catBox = ComboBox(top, categories, state.category or "", function(value)
          state.category = value
          frame:RebuildList()
     end)
     catBox:Dock(LEFT)
     catBox:DockMargin(8, 0, 0, 0)
     catBox:SetWide(190)

     local filterBox = ComboBox(top, {{"Todos", "all"}, {"Solo permitidos", "on"}, {"Solo no permitidos", "off"}, {"Tipos bloqueados", "blocked"}}, state.filter or "all", function(value)
          state.filter = value
          frame:RebuildList()
     end)
     filterBox:Dock(LEFT)
     filterBox:DockMargin(8, 0, 0, 0)
     filterBox:SetWide(150)

     local save = Button(top, "Guardar", T.green, function()
          local ids = {}

          for id in pairs(state.draft) do
               table.insert(ids, id)
          end

          frame.resetWhitelist = true
          Send("whitelist_save", {ids = ids})
     end)
     save:Dock(RIGHT)
     save:SetWide(110)
     save.Think = function(panel)
          panel.label = state.dirty and "Guardar *" or "Guardar"
     end

     local revert = Button(top, "Deshacer", T.muted, function()
          frame:ResetWhitelistDraft()
          frame:RebuildList()
     end)
     revert:Dock(RIGHT)
     revert:DockMargin(0, 0, 8, 0)
     revert:SetWide(90)

     local bar = c:Add("DPanel")
     bar:Dock(TOP)
     bar:DockMargin(0, 8, 0, 8)
     bar:SetTall(30)
     bar.Paint = function(_, w, h)
          local count = table.Count(state.draft)
          draw.SimpleText("Permitidos: " .. count .. " objetos" .. (state.dirty and "   (cambios sin guardar)" or ""), "SardonBaykus.AdmText", w, h / 2, state.dirty and T.gold or T.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
     end

     local allowVisible = Button(bar, "Permitir visibles", T.gold, function()
          for _, id in ipairs(state.visible or {}) do
               if (!SardonBaykus.IsHardBlocked(ix.item.list[id])) then
                    state.draft[id] = true
               end
          end

          state.dirty = true
          frame:RebuildList()
     end)
     allowVisible:Dock(LEFT)
     allowVisible:SetWide(170)

     local denyVisible = Button(bar, "Quitar permiso a visibles", T.red, function()
          for _, id in ipairs(state.visible or {}) do
               state.draft[id] = nil
          end

          state.dirty = true
          frame:RebuildList()
     end)
     denyVisible:Dock(LEFT)
     denyVisible:DockMargin(8, 0, 0, 0)
     denyVisible:SetWide(200)

     -- Sağda seçili eşyanın önizlemesi.
     local preview = c:Add("DPanel")
     preview:Dock(RIGHT)
     preview:DockMargin(10, 0, 0, 0)
     preview:SetWide(230)
     preview.Paint = function(panel, w, h)
          Box(0, 0, w, h, T.panel)

          local item = ix.item.list[state.selected or ""]

          if (!item) then
               draw.SimpleText("Selecciona un objeto", "SardonBaykus.AdmText", w / 2, h / 2, T.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

               return
          end

          draw.SimpleText(L(item.name or "?"), "SardonBaykus.AdmHead", w / 2, 190, T.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          draw.SimpleText(item.uniqueID, "SardonBaykus.AdmSmall", w / 2, 210, T.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

          local blocked, reason = SardonBaykus.IsHardBlocked(item)
          local statusText = blocked and ("Bloqueado: " .. reason) or (state.draft[item.uniqueID] and "Se puede enviar por lechuza" or "No se puede enviar")
          local statusColor = blocked and T.red or (state.draft[item.uniqueID] and T.green or T.muted)

          draw.SimpleText(statusText, "SardonBaykus.AdmText", w / 2, 234, statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end

     local icon = preview:Add("SpawnIcon")
     icon:SetSize(160, 160)
     icon:SetPos(35, 12)
     icon:SetMouseInputEnabled(false)

     local desc = ReadOnlyText(preview)
     desc:SetPos(10, 252)
     desc:SetSize(210, 150)

     local toggle = Button(preview, "Cambiar permiso", T.gold, function()
          frame:ToggleWhitelist(state.selected)
     end)
     toggle:SetSize(210, 34)
     toggle:SetPos(10, 412)

     frame.wlPreview = function()
          local item = ix.item.list[state.selected or ""]

          icon:SetVisible(item != nil)
          toggle:SetDisabled(!item or SardonBaykus.IsHardBlocked(item))

          if (item) then
               icon:SetModel(item.model or "models/error.mdl")
               desc:SetValue(L(item.description or ""))
          else
               desc:SetValue("")
          end
     end

     local lv = ListView(c, {{"Permiso", 70}, {"Objeto"}, {"ID", 190}, {"Categoría", 150}})
     lv:Dock(FILL)
     frame.wlList = lv

     lv.OnRowSelected = function(_, _, line)
          state.selected = line.uniqueID
          frame.wlPreview()
     end

     lv.DoDoubleClick = function(_, _, line)
          frame:ToggleWhitelist(line.uniqueID)
     end

     search.OnValueChange = function(_, value)
          state.search = value
          frame:RebuildList()
     end

     frame:RebuildList()
     frame.wlPreview()
end

TABS[3] = {id = "flights", name = "Bolsas en vuelo", icon = "icon16/transmit.png"}

TABS[3].Build = function(frame, c, data)
     local bar = c:Add("DPanel")
     bar:Dock(BOTTOM)
     bar:DockMargin(0, 8, 0, 0)
     bar:SetTall(34)
     bar.Paint = function() end

     local lv = ListView(c, {{"Remitente", 150}, {"Destinatario", 150}, {"Contenido"}, {"Tiempo", 90}, {"Distancia", 80}, {"Estado", 100}})
     lv:Dock(FILL)

     for _, f in ipairs(data.flights or {}) do
          local line = AddRow(lv, f.returning and T.muted or T.text, f.sender, f.receiver, f.summary, FormatDuration(f.elapsed), f.distance >= 0 and (f.distance .. " b") or "-", f.returning and "Regresando" or "En camino")
          line.msgId = f.msgId
     end

     if (#(data.flights or {}) == 0) then
          AddRow(lv, T.muted, "", "", "No hay lechuzas transportando bolsas ahora.", "", "", "")
     end

     local function Selected()
          local _, line = lv:GetSelectedLine()

          return line and line.msgId
     end

     local actions = {
          {"Teletransportarse a la lechuza", T.blue, "flight_goto"},
          {"Entregar ahora", T.green, "flight_deliver"},
          {"Devolver al remitente", T.red, "flight_return"}
     }

     for _, a in ipairs(actions) do
          local btn = Button(bar, a[1], a[2], function()
               local msgId = Selected()

               if (msgId) then
                    Send(a[3], {msgId = msgId})
               end
          end)
          btn:Dock(LEFT)
          btn:DockMargin(0, 0, 8, 0)
          btn:SetWide(170)
     end

     local refresh = Button(bar, "Actualizar", T.gold, function()
          Send("refresh")
     end)
     refresh:Dock(RIGHT)
     refresh:SetWide(100)
end

TABS[4] = {id = "pending", name = "Bolsas pendientes", icon = "icon16/hourglass.png"}

TABS[4].Build = function(frame, c, data)
     local info = c:Add("DLabel")
     info:Dock(TOP)
     info:DockMargin(0, 0, 0, 8)
     info:SetFont("SardonBaykus.AdmText")
     info:SetTextColor(T.muted)
     info:SetText("Bolsas entregadas/devueltas mientras el dueño estaba desconectado. Se entregan automáticamente al cargar su personaje.")

     local bar = c:Add("DPanel")
     bar:Dock(BOTTOM)
     bar:DockMargin(0, 8, 0, 0)
     bar:SetTall(34)
     bar.Paint = function() end

     local lv = ListView(c, {{"Para", 150}, {"En línea", 70}, {"Remitente", 140}, {"Destinatario", 140}, {"Contenido"}, {"Fecha", 120}})
     lv:Dock(FILL)

     for _, p in ipairs(data.pending or {}) do
          local line = AddRow(lv, p.ownerOnline and T.green or T.text, p.owner, p.ownerOnline and "Sí" or "No", p.sender, p.receiver, p.summary, FormatTime(p.created))
          line.msgId = p.msgId
     end

     local function Selected()
          local _, line = lv:GetSelectedLine()

          return line and line.msgId, line
     end

     local give = Button(bar, "Entregar ahora", T.green, function()
          local msgId = Selected()

          if (msgId) then
               Send("pending_give", {msgId = msgId})
          end
     end)
     give:Dock(LEFT)
     give:SetWide(150)

     local delete = Button(bar, "Eliminar bolsa", T.red, function()
          local msgId, line = Selected()

          if (msgId) then
               Derma_Query("Esta bolsa y TODOS LOS OBJETOS DENTRO se eliminarán permanentemente:\n" .. line:GetColumnText(5), "Eliminar bolsa pendiente", "Eliminar", function()
                    Send("pending_delete", {msgId = msgId})
               end, "Cancelar")
          end
     end)
     delete:Dock(LEFT)
     delete:DockMargin(8, 0, 0, 0)
     delete:SetWide(150)
end

TABS[5] = {id = "messages", name = "Mensajes", icon = "icon16/email.png"}

TABS[5].Build = function(frame, c, data)
     local right = c:Add("DPanel")
     right:Dock(RIGHT)
     right:DockMargin(10, 0, 0, 0)
     right:SetWide(320)
     right.Paint = function() end

     local header = right:Add("DLabel")
     header:Dock(TOP)
     header:SetTall(40)
     header:SetFont("SardonBaykus.AdmText")
     header:SetTextColor(T.muted)
     header:SetWrap(true)
     header:SetText("Selecciona un mensaje para leerlo.")

     local delete = Button(right, "Eliminar mensaje", T.red, function()
          local _, line = frame.msgList:GetSelectedLine()

          if (line and line.msg) then
               Derma_Query("Este mensaje de lechuza también se eliminará del buzón del destinatario.", "Eliminar mensaje", "Eliminar", function()
                    Send("message_delete", {id = line.msg.id})
               end, "Cancelar")
          end
     end)
     delete:Dock(BOTTOM)
     delete:DockMargin(0, 8, 0, 0)
     delete:SetTall(34)

     local content = ReadOnlyText(right)
     content:Dock(FILL)

     local lv = ListView(c, {{"Fecha", 120}, {"Remitente", 140}, {"Destinatario", 140}, {"Anónimo", 64}, {"Estado", 80}})
     lv:Dock(FILL)
     frame.msgList = lv

     for _, m in ipairs(data.messages or {}) do
          local line = AddRow(lv, m.unread and T.gold or T.text, FormatTime(m.time), m.sender, m.receiver, m.anonim and "Sí" or "-", m.unread and "No leído" or "Leído")
          line.msg = m
     end

     lv.OnRowSelected = function(_, _, line)
          local m = line.msg

          header:SetText(m.sender .. " → " .. m.receiver .. (m.anonim and "  (anónimo)" or "") .. (m.hasLocation and "  · ubicación añadida" or "") .. "\n" .. FormatTime(m.time))
          content:SetValue(m.content or "")
     end
end

TABS[6] = {id = "logs", name = "Registros", icon = "icon16/book_open.png"}

TABS[6].Build = function(frame, c, data)
     local state = frame.logState

     local top = c:Add("DPanel")
     top:Dock(TOP)
     top:SetTall(32)
     top:DockMargin(0, 0, 0, 8)
     top.Paint = function() end

     local choices = {{"Todos los tipos", ""}}

     for _, kind in ipairs({"send", "deliver", "drop", "pickup", "return", "pending", "admin"}) do
          table.insert(choices, {KIND_NAMES[kind], kind})
     end

     local detail = ReadOnlyText(c)
     detail:Dock(BOTTOM)
     detail:DockMargin(0, 8, 0, 0)
     detail:SetTall(90)

     local lv = ListView(c, {{"Fecha", 120}, {"Tipo", 110}, {"Remitente", 140}, {"Destinatario", 140}, {"Persona", 130}, {"Detalle"}})
     lv:Dock(FILL)

     local function Rebuild()
          lv:Clear()

          local search = string.lower(state.search or "")

          for _, log in ipairs(data.logs or {}) do
               local haystack = string.lower(table.concat({log.sender or "", log.receiver or "", log.actor or "", log.details or ""}, " "))

               if ((state.kind == "" or state.kind == log.kind) and (search == "" or string.find(haystack, search, 1, true))) then
                    local line = AddRow(lv, KIND_COLORS[log.kind], FormatTime(log.time), KIND_NAMES[log.kind] or log.kind, log.sender, log.receiver, log.actor, log.details)
                    line.log = log
               end
          end
     end

     local kindBox = ComboBox(top, choices, state.kind, function(value)
          state.kind = value
          Rebuild()
     end)
     kindBox:Dock(LEFT)
     kindBox:SetWide(170)

     local search = TextEntry(top, "Buscar nombre o detalle...")
     search:Dock(LEFT)
     search:DockMargin(8, 0, 0, 0)
     search:SetWide(300)
     search:SetValue(state.search or "")
     search.OnValueChange = function(_, value)
          state.search = value
          Rebuild()
     end

     lv.OnRowSelected = function(_, _, line)
          local log = line.log

          detail:SetValue((KIND_NAMES[log.kind] or log.kind) .. " · " .. FormatTime(log.time) .. "\n" .. (log.details or ""))
     end

     Rebuild()
end

TABS[7] = {id = "settings", name = "Ajustes", icon = "icon16/cog.png"}

local SETTING_ROWS = {
     {"enabled", "bool", "Sistema de bolsas activo", "Si está desactivado no se pueden abrir bolsas ni enviar objetos por lechuza."},
     {"maxItems", "num", "Objetos por bolsa", "Máximo de objetos que caben en una bolsa (1-5).", 1, 5},
     {"maxMoney", "num", "Galleons por bolsa", "Si es 0 no se pueden enviar Galleons por lechuza.", 0, 10000000},
     {"accio", "bool", "Accio Statum hace caer la bolsa", "Si se lanza Accio Statum a una lechuza en vuelo, la bolsa cae al suelo."},
     {"accioRange", "num", "Alcance de Accio", "Distancia máxima a la que el hechizo afecta a la lechuza (unidades).", 200, 20000},
     {"flightTimeout", "num", "Tiempo límite de entrega (s)", "Si no se entrega en este tiempo, la bolsa vuelve al remitente.", 60, 7200},
     {"discord", "bool", "Registro de Discord", "Los envíos, entregas, Accio, recogidas y acciones de administración se escriben en Discord."},
     {"discordMessages", "bool", "Registrar también mensajes sin bolsa", "Si está desactivado, solo los envíos con bolsa van a Discord (los registros del panel siempre se guardan)."}
}

TABS[7].Build = function(frame, c, data)
     local draft = frame.settingsDraft

     local scroll = c:Add("DScrollPanel")
     scroll:Dock(FILL)
     StyleScroll(scroll:GetVBar())

     for _, row in ipairs(SETTING_ROWS) do
          local key, kind, title, help, min, max = unpack(row)

          local panel = scroll:Add("DPanel")
          panel:Dock(TOP)
          panel:DockMargin(0, 0, 8, 8)
          panel:SetTall(58)
          panel.Paint = function(_, w, h)
               Box(0, 0, w, h, T.panel)
               draw.SimpleText(title, "SardonBaykus.AdmHead", 14, 18, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               draw.SimpleText(help, "SardonBaykus.AdmSmall", 14, 40, T.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          end

          if (kind == "bool") then
               local toggle = Button(panel, "", T.gold, function(btn)
                    draft[key] = (draft[key] == 1) and 0 or 1
               end)
               toggle:Dock(RIGHT)
               toggle:DockMargin(0, 12, 12, 12)
               toggle:SetWide(110)
               toggle.Think = function(btn)
                    local on = draft[key] == 1
                    btn.label = on and "ACTIVADO" or "DESACTIVADO"
                    btn.accent = on and T.green or T.red
               end
          else
               local wang = panel:Add("DNumberWang")
               wang:Dock(RIGHT)
               wang:DockMargin(0, 14, 12, 14)
               wang:SetWide(130)
               wang:SetMinMax(min, max)
               wang:SetDecimals(0)
               wang:SetFont("SardonBaykus.AdmText")
               wang:SetValue(draft[key] or min)
               wang.OnValueChanged = function(_, value)
                    draft[key] = math.Clamp(math.floor(tonumber(value) or min), min, max)
               end
               wang.Paint = function(p, w, h)
                    Box(0, 0, w, h, T.bg, p:HasFocus() and T.gold or T.line)
                    p:DrawTextEntryText(T.text, T.gold, T.text)
               end
          end
     end

     local bar = c:Add("DPanel")
     bar:Dock(BOTTOM)
     bar:DockMargin(0, 8, 0, 0)
     bar:SetTall(36)
     bar.Paint = function() end

     local save = Button(bar, "Guardar ajustes", T.green, function()
          Send("settings_save", {settings = draft})
     end)
     save:Dock(LEFT)
     save:SetWide(170)

     local defaults = Button(bar, "Restablecer valores", T.muted, function()
          for key, value in pairs(data.defaults or {}) do
               draft[key] = value
          end

          frame:ShowTab(frame.activeTab)
     end)
     defaults:Dock(LEFT)
     defaults:DockMargin(8, 0, 0, 0)
     defaults:SetWide(170)

     local test = Button(bar, "Probar webhook de Discord", T.blue, function()
          Send("webhook_test")
     end)
     test:Dock(RIGHT)
     test:SetWide(230)
end

-- ============= ANA PENCERE =============

local FRAME_W, FRAME_H = 1080, 680

do
     local PANEL = {}

     function PANEL:Init()
          self:SetSize(math.min(FRAME_W, ScrW() - 40), math.min(FRAME_H, ScrH() - 40))
          self:Center()
          self:SetTitle("")
          self:ShowCloseButton(false)
          self:MakePopup()
          self:DockPadding(0, 0, 0, 0)

          self.wl = {draft = {}, filter = "all", category = "", search = ""}
          self.logState = {kind = "", search = ""}
          self.settingsDraft = {}
          self.activeTab = "overview"

          self.side = self:Add("DPanel")
          self.side:Dock(LEFT)
          self.side:SetWide(200)
          self.side:DockPadding(10, 64, 10, 10)
          self.side.Paint = function(_, w, h)
               draw.RoundedBoxEx(8, 0, 0, w, h, T.side, true, false, true, false)
               draw.SimpleText("🦉 Lechuza", "SardonBaykus.AdmTitle", 16, 22, T.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               draw.SimpleText("Panel de administración", "SardonBaykus.AdmSmall", 18, 44, T.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          end

          self.tabButtons = {}

          for _, tab in ipairs(TABS) do
               local btn = self.side:Add("DButton")
               btn:Dock(TOP)
               btn:DockMargin(0, 0, 0, 4)
               btn:SetTall(36)
               btn:SetText("")
               btn.icon = Material(tab.icon)
               btn.DoClick = function()
                    surface.PlaySound("ui/buttonclick.wav")
                    self:ShowTab(tab.id)
               end
               btn.Paint = function(panel, w, h)
                    local active = self.activeTab == tab.id

                    if (active) then
                         draw.RoundedBox(5, 0, 0, w, h, T.rowSel)
                         surface.SetDrawColor(T.gold)
                         surface.DrawRect(0, 6, 3, h - 12)
                    elseif (panel:IsHovered()) then
                         draw.RoundedBox(5, 0, 0, w, h, T.rowHover)
                    end

                    surface.SetDrawColor(color_white)
                    surface.SetMaterial(panel.icon)
                    surface.DrawTexturedRect(12, h / 2 - 8, 16, 16)
                    draw.NoTexture()

                    draw.SimpleText(tab.name, "SardonBaykus.AdmBtn", 38, h / 2, active and T.gold or T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               end

               self.tabButtons[tab.id] = btn
          end

          local close = Button(self, "✕", T.red, function()
               self:Remove()
          end)
          close:SetSize(32, 32)
          close.Think = function(panel)
               panel:SetPos(self:GetWide() - 44, 12)
          end

          self.content = self:Add("DPanel")
          self.content:Dock(FILL)
          self.content:DockMargin(18, 58, 18, 18)
          self.content.Paint = function() end
     end

     function PANEL:ResetWhitelistDraft()
          self.wl.draft = {}

          for _, id in ipairs(self.data and self.data.whitelist or {}) do
               self.wl.draft[id] = true
          end

          self.wl.dirty = false
     end

     function PANEL:SetData(data)
          local first = self.data == nil

          self.data = data

          if (first or self.resetWhitelist or !self.wl.dirty) then
               self.resetWhitelist = false
               self:ResetWhitelistDraft()
          end

          self.settingsDraft = table.Copy(data.settings or {})
          self:ShowTab(self.activeTab)
     end

     function PANEL:ToggleWhitelist(id)
          local item = ix.item.list[id or ""]

          if (!item or SardonBaykus.IsHardBlocked(item)) then
               return
          end

          self.wl.draft[id] = !self.wl.draft[id] or nil
          self.wl.dirty = true
          self:RebuildList(true)

          if (self.wlPreview) then
               self.wlPreview()
          end
     end

     -- Whitelist listesini filtreye göre yeniden doldurur. keepScroll: tek satır değiştiyse
     -- kaydırma konumunu koru.
     function PANEL:RebuildList(keepScroll)
          local lv = self.wlList

          if (!IsValid(lv)) then
               return
          end

          local scroll = lv.VBar:GetScroll()
          local state = self.wl
          local search = string.lower(state.search or "")
          local rows = {}

          for id, item in pairs(ix.item.list) do
               local name = L(item.name or id)
               local blocked = SardonBaykus.IsHardBlocked(item)
               local allowed = state.draft[id] == true
               local okFilter = state.filter == "all"
                    or (state.filter == "on" and allowed)
                    or (state.filter == "off" and !allowed and !blocked)
                    or (state.filter == "blocked" and blocked)

               if (okFilter and (state.category == "" or (item.category or "Otros") == state.category)
                    and (search == "" or string.find(string.lower(name), search, 1, true) or string.find(string.lower(id), search, 1, true))) then
                    table.insert(rows, {id = id, name = name, category = L(item.category or "Otros"), allowed = allowed, blocked = blocked})
               end
          end

          table.sort(rows, function(a, b)
               if (a.allowed != b.allowed) then
                    return a.allowed
               end

               return a.name < b.name
          end)

          lv:Clear()
          state.visible = {}

          for _, r in ipairs(rows) do
               local color = r.blocked and T.red or (r.allowed and T.green or T.muted)
               local line = AddRow(lv, color, r.blocked and "Bloqueado" or (r.allowed and "✔ Permitido" or "✖"), r.name, r.id, r.category)
               line.uniqueID = r.id

               if (r.allowed or !r.blocked) then
                    SetRowColor(line, color)
                    line.Columns[2]:SetTextColor(r.allowed and T.text or T.muted)
               end

               if (r.id == state.selected) then
                    line:SetSelected(true)
               end

               table.insert(state.visible, r.id)
          end

          if (keepScroll) then
               timer.Simple(0, function()
                    if (IsValid(lv)) then
                         lv.VBar:SetScroll(scroll)
                    end
               end)
          end
     end

     function PANEL:ShowTab(id)
          self.activeTab = id
          self.content:Clear()
          self.wlList = nil
          self.wlPreview = nil

          for _, tab in ipairs(TABS) do
               if (tab.id == id and self.data) then
                    tab.Build(self, self.content, self.data)
               end
          end
     end

     function PANEL:Paint(w, h)
          Box(0, 0, w, h, T.bg, T.goldDim)

          for _, tab in ipairs(TABS) do
               if (tab.id == self.activeTab) then
                    draw.SimpleText(tab.name, "SardonBaykus.AdmTitle", 218, 30, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               end
          end
     end

     vgui.Register("SardonBaykus.AdminFrame", PANEL, "DFrame")

     -- Shine Admin içine gömülen sürüm: kenar çubuğu / kapatma / popup yok, sekmeleri
     -- Shine Admin'in alt sekme şeridi değiştiriyor (ShowTab). Veri ve sekme kodu aynı.
     local PAGE = {}

     for k, v in pairs(PANEL) do
          if (isfunction(v) and k != "Init" and k != "Paint") then
               PAGE[k] = v
          end
     end

     function PAGE:Init()
          self.wl = {draft = {}, filter = "all", category = "", search = ""}
          self.logState = {kind = "", search = ""}
          self.settingsDraft = {}
          self.activeTab = "overview"

          self.content = self:Add("DPanel")
          self.content:Dock(FILL)
          self.content.Paint = function() end
     end

     function PAGE:Paint(w, h)
          if (!self.data) then
               draw.SimpleText("Cargando datos de lechuza…", "SardonBaykus.AdmText", w / 2, h / 2, T.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          end
     end

     vgui.Register("SardonBaykus.AdminPage", PAGE, "EditablePanel")
end

SardonBaykus.AdminTabs = TABS

net.Receive("SardonBaykus.AdminData", function()
     local len = net.ReadUInt(32)
     local raw = net.ReadData(len)
     local data = util.JSONToTable(util.Decompress(raw) or "")

     if (!data) then
          return
     end

     if (IsValid(SardonBaykus.AdminFrame)) then
          SardonBaykus.AdminFrame:SetData(data)
     elseif (data.open) then
          -- /baykus_admin artık Shine Admin'in Baykuş sayfasını açıyor; Shine Admin
          -- (veya asa menüsü arayüzü) yoksa eski pencereye dön
          if (ShineAdmin and ShineAdmin.GetN and ShineAdmin.GetN() and ShineAdmin:CanSee("baykus")) then
               ShineAdmin:Open("baykus", {data = data})
               return
          end

          SardonBaykus.AdminFrame = vgui.Create("SardonBaykus.AdminFrame")
          SardonBaykus.AdminFrame:SetData(data)
     end
end)
