-- "addons\\sardonshineadmin\\lua\\sardon_shineadmin\\cl_page_players.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Shine Admin :: oyuncu sayfaları (whitelist, sosyal medya, ırk)
-- Her sayfa kaynak eklentinin ağ mesajlarını aynen kullanır; sunucu tarafı değişmedi.

local LIST_W = 360
local GAP = 24

-- sol: oyuncu listesi, sağ: seçilen oyuncunun paneli (build(detail, ply, w, h))
local function PlayerSplit(ctx, onSelect)
     local N = ShineAdmin.GetN()
     local u = N.u
     local P = ctx.panel
     local sel

     local detailX = LIST_W + GAP
     local detailW = ctx.w - detailX

     local detail

     local function show(ply)
          if (IsValid(detail)) then detail:Remove() end

          detail = vgui.Create("DPanel", P)
          detail:SetPos(u(detailX), 0)
          detail:SetSize(u(detailW), u(ctx.h))
          detail.Paint = function() end

          if (!IsValid(ply)) then
               ShineAdmin.Placeholder(detail, 0, 0, u(detailW), u(ctx.h), "Selecciona un jugador a la izquierda.")
               return
          end

          onSelect(detail, ply, detailW, ctx.h)
     end

     ShineAdmin.PlayerList(P, 0, 0, u(LIST_W), u(ctx.h), function() return sel end, function(ply)
          sel = ply
          show(ply)
     end)

     show(nil)

     return {
          Select = function(ply)
               sel = ply
               show(ply)
          end,
          Get = function() return sel end
     }
end

-- küçük başlık + oyuncu adı şeridi
local function DetailHead(N, parent, w, ply, eyebrow)
     local u = N.u

     local head = vgui.Create("DPanel", parent)
     head:SetPos(0, 0)
     head:SetSize(u(w), u(64))
     head.Paint = function(s, pw, ph)
          if (!IsValid(ply)) then return end

          N.AvatarTile(0, 0, u(44), string.sub(ply:Nick(), 1, 1), true)
          N.Eyebrow(eyebrow, u(58), u(2), N.Clr.gold)
          N.Text(N.Clip(ply:Nick(), "heading", pw - u(70)), "heading", u(58), u(14))
          N.Box(0, ph - 1, pw, 1, N.Clr.headLine)
     end

     return head
end

--[[
*   whitelist  (whitelist_sardon / [sardon] config :: sardon_wl_req, sardon_wl)
]]

ShineAdmin:RegisterPage("whitelist", {
     label = "Lista blanca",
     icon = "users",
     group = "players",
     order = 10,
     title = "Editor de lista blanca",
     subtitle = "Define las casas y clases a las que el jugador puede acceder.",
     access = "whitelist",

     build = function(ctx)
          local N = ShineAdmin.GetN()
          local u = N.u

          -- sunucudan gelen son durum ve kaydedilmemiş değişiklikler
          local state = {target = nil, factions = {}, classes = {}, changes = {factions = {}, classes = {}}}
          local rebuild

          local function dirtyCount()
               return table.Count(state.changes.factions) + table.Count(state.changes.classes)
          end

          local function factionOn(faction)
               local v = state.changes.factions[faction.uniqueID]
               if (v == nil) then v = state.factions[faction.uniqueID] end
               return v and true or false
          end

          local function classOn(class)
               local v = state.changes.classes[class.uniqueID]
               if (v == nil) then v = state.classes[class.uniqueID] end
               return v and true or false
          end

          local function set(kind, id, value, original)
               -- asıl değere dönülürse değişiklik sayılmasın
               if ((original and true or false) == value) then
                    state.changes[kind][id] = nil
               else
                    state.changes[kind][id] = value
               end
          end

          local split

          local function request(ply)
               state.target = ply
               state.loaded = false
               state.changes = {factions = {}, classes = {}}

               net.Start("sardon_wl_req")
                    net.WriteEntity(ply)
               net.SendToServer()
          end

          split = PlayerSplit(ctx, function(detail, ply, w, h)
               if (state.target != ply) then
                    if (dirtyCount() > 0) then
                         ctx.Flash("Se descartaron cambios sin guardar del jugador anterior.", "bad")
                    end

                    request(ply)
               end

               DetailHead(N, detail, w, ply, "LISTA BLANCA")

               if (!state.loaded) then
                    local wait = vgui.Create("DPanel", detail)
                    wait:SetPos(0, u(80))
                    wait:SetSize(u(w), u(40))
                    wait.Paint = function()
                         N.Text("Solicitando datos de lista blanca al servidor…", "body", 0, u(10), N.Clr.faint)
                    end
                    return
               end

               local scroll = N.Scroll(detail, 0, u(76), u(w), u(h - 76 - 64))
               local canvas = scroll:GetCanvas()

               for _, faction in ipairs(ix.faction.indices) do
                    local on = factionOn(faction)

                    local classes = {}
                    for _, class in pairs(ix.class.list) do
                         if (class.faction == faction.index) then classes[#classes + 1] = class end
                    end

                    local row = N.Toggle(canvas, 0, 0, u(w) - u(12), u(50), faction.name,
                         function() return factionOn(faction) end,
                         function(v)
                              set("factions", faction.uniqueID, v, state.factions[faction.uniqueID])
                              rebuild()
                         end,
                         #classes .. " clases  ·  " .. (on and "casa abierta" or "casa cerrada; clases bloqueadas"))
                    row:Dock(TOP)

                    -- hane rengi sol kenarda
                    local paint = row.Paint
                    row.Paint = function(s, pw, ph)
                         paint(s, pw, ph)
                         N.Box(pw - u(56), ph / 2 - u(4), u(8), u(8), faction.color or N.Clr.gold)
                    end

                    for _, class in ipairs(classes) do
                         local crow = N.Toggle(canvas, 0, 0, u(w) - u(12), u(40), "     " .. class.name,
                              function() return classOn(class) end,
                              function(v) set("classes", class.uniqueID, v, state.classes[class.uniqueID]) end,
                              nil, !on)
                         crow:Dock(TOP)
                    end
               end

               local bar = N.StickyBar(detail, 0, u(h - 52), u(w), function()
                    local n = dirtyCount()
                    if (n > 0) then return n .. " cambios sin guardar", N.Clr.warn end
                    return "Sin cambios. Al guardar también se registra en Discord."
               end)

               local save = N.Button(bar, u(w) - u(170), u(8), u(170), u(36), "Guardar", function()
                    if (!IsValid(state.target)) then return end

                    net.Start("sardon_wl")
                         net.WriteEntity(state.target)
                         net.WriteTable(state.changes.factions)
                         net.WriteTable(state.changes.classes)
                    net.SendToServer()

                    ctx.Flash("Lista blanca guardada para " .. state.target:Nick() .. ".")

                    -- sunucudan güncel hali tekrar iste
                    local target = state.target
                    timer.Simple(0.3, function()
                         if (IsValid(target) and state.target == target) then request(target) end
                    end)
               end, "primary")
               save.Think = function(s) s:SetEnabled(dirtyCount() > 0) end

               local revert = N.Button(bar, u(w) - u(170) - u(130), u(8), u(120), u(36), "Deshacer", function()
                    state.changes = {factions = {}, classes = {}}
                    rebuild()
               end, "ghost")
               revert.Think = function(s) s:SetEnabled(dirtyCount() > 0) end
          end)

          rebuild = function()
               if (IsValid(state.target)) then split.Select(state.target) end
          end

          -- sardon_wl yanıtı (bkz. yönlendirme aşağıda)
          ctx.SetWL = function(ply, factions, classes)
               if (!IsValid(ply)) then return end

               state.target = ply
               state.factions = factions or {}
               state.classes = classes or {}
               state.changes = {factions = {}, classes = {}}
               state.loaded = true
               rebuild()
          end

          ctx.OnLeave = function()
               if (dirtyCount() > 0) then
                    ShineAdmin.Window:Flash("Se descartaron cambios sin guardar en la lista blanca.", "bad")
               end
          end

          if (ctx.arg and IsValid(ctx.arg.target)) then
               ctx.SetWL(ctx.arg.target, ctx.arg.factions, ctx.arg.classes)
          end
     end
})

-- Skor tablosundaki "Whitelistlerini Düzenle" de bu sayfayı açar
ShineAdmin:Route("sardon_wl", function()
     local ply = net.ReadEntity()
     local factions = net.ReadTable()
     local classes = net.ReadTable()

     local ctx = ShineAdmin:ActiveCtx("whitelist")

     if (ctx and ctx.SetWL) then
          ctx.SetWL(ply, factions, classes)
     else
          ShineAdmin:Open("whitelist", {target = ply, factions = factions, classes = classes})
     end
end)

--[[
*   sosyal medya  ([sardon] socials :: socials_update)
]]

ShineAdmin:RegisterPage("socials", {
     label = "Redes sociales",
     icon = "mic",
     group = "players",
     order = 20,
     title = "Cuentas de redes sociales",
     subtitle = "Edita el ID de Discord y el usuario de Twitch del jugador.",
     access = "socials",

     build = function(ctx)
          local N = ShineAdmin.GetN()
          local u = N.u

          PlayerSplit(ctx, function(detail, ply, w, h)
               DetailHead(N, detail, w, ply, "REDES SOCIALES")

               local info = vgui.Create("DPanel", detail)
               info:SetPos(0, u(80))
               info:SetSize(u(w), u(230))
               info.Paint = function(s, pw, ph)
                    if (!IsValid(ply)) then return end

                    N.SectionLabel("ID de Discord", 0, 0, pw, "users")
                    N.SectionLabel("Usuario de Twitch", 0, u(96), pw, "eye")

                    local y = u(190)
                    y = y + N.Property(0, y, pw, "Cuenta de Discord vinculada", ply:GetNWString("discord_name", "") != "" and ply:GetNWString("discord_name") or "—")
               end

               local discord = N.PlainEntry(detail, 0, u(108), u(w), u(38), "ID de usuario de Discord (número)")
               discord:SetValue(ply:GetNWString("discord_id", ""))

               local twitch = N.PlainEntry(detail, 0, u(204), u(w), u(38), "kullanici_adi  (twitch.tv/…)")
               twitch:SetValue(ply:GetNWString("twitch_name", ""))

               local bar = N.StickyBar(detail, 0, u(h - 52), u(w), function()
                    return "Los campos vacíos se eliminan del registro del jugador."
               end)

               N.Button(bar, u(w) - u(170), u(8), u(170), u(36), "Guardar", function()
                    if (!IsValid(ply)) then return end

                    net.Start("socials_update")
                         net.WriteString(util.TableToJSON({
                              type = "UPDATE",
                              discord = string.Trim(discord:GetValue()),
                              twitch = string.Trim(twitch:GetValue())
                         }))
                         net.WriteEntity(ply)
                    net.SendToServer()

                    ctx.Flash("Datos de redes sociales guardados para " .. ply:Nick() .. ".")
               end, "primary")
          end)
     end
})

--[[
*   ırk değişimi  ([fx] irk :: "irkdegis" konsol komutu, sunucu yetki kontrolü yapar)
]]

ShineAdmin:RegisterPage("irk", {
     label = "Cambio de raza",
     icon = "leaf",
     group = "players",
     order = 30,
     title = "Cambio de raza",
     subtitle = "Cambia la raza del jugador; opcionalmente vuelve a mostrar la pantalla de elección.",
     access = "leader",
     available = function() return fx_irk and fx_irk.irklar end,

     build = function(ctx)
          local N = ShineAdmin.GetN()
          local u = N.u

          local races = {}
          for name, data in pairs(fx_irk.irklar) do
               races[#races + 1] = {name = name, key = data.realkey}
          end
          table.sort(races, function(a, b) return a.name < b.name end)

          PlayerSplit(ctx, function(detail, ply, w, h)
               local pick
               local showScreen = true

               DetailHead(N, detail, w, ply, "RAZA")

               local current = vgui.Create("DPanel", detail)
               current:SetPos(0, u(76))
               current:SetSize(u(w), u(40))
               current.Paint = function(s, pw, ph)
                    if (!IsValid(ply)) then return end

                    local key = ply:GetNWString("fx_irk", "")
                    local name = "—"
                    for _, r in ipairs(races) do
                         if (r.key == key) then name = r.name end
                    end

                    N.Property(0, 0, pw, "Raza actual", name, N.Clr.gold)
               end

               local grid = N.VList(detail, 0, u(128), u(w), u(h - 128 - 52 - 60), {
                    rowH = u(54),
                    cols = 3,
                    gapX = u(10),
                    gapY = u(10),
                    onClick = function(r) pick = r end,
                    paintRow = function(r, i, x, y, cw, ch, hovered)
                         local on = pick == r
                         local isCurrent = IsValid(ply) and ply:GetNWString("fx_irk", "") == r.key

                         N.Box(x, y, cw, ch, on and Color(201, 174, 119, 16) or N.Clr.toolBg)
                         N.Outline(x, y, cw, ch, on and N.Clr.gold or (hovered and N.Clr.btnLine or N.Clr.toolLine), 1)
                         N.Text(N.Clip(r.name, "serif", cw - u(30)), "serif", x + u(16), y + u(10))
                         N.Text(isCurrent and "raza actual" or r.key, "tiny", x + u(16), y + u(34), isCurrent and N.Clr.ok or N.Clr.rowDesc)
                    end
               })
               grid:SetItems(races)

               N.Toggle(detail, 0, u(h - 52 - 54), u(w), u(50), "Volver a mostrar pantalla de elección",
                    function() return showScreen end,
                    function(v) showScreen = v end,
                    "Se vuelve a abrir la pantalla de elección de raza al jugador.")

               local bar = N.StickyBar(detail, 0, u(h - 52), u(w), function()
                    if (!pick) then return "Primero elige la nueva raza." end
                    return ply:Nick() .. " → " .. pick.name
               end)

               local apply = N.Button(bar, u(w) - u(170), u(8), u(170), u(36), "Aplicar", function()
                    if (!IsValid(ply) or !pick) then return end

                    LocalPlayer():ConCommand("irkdegis \"" .. ply:SteamID() .. "\" \"" .. pick.key .. "\" " .. (showScreen and "1" or "0"))
                    ctx.Flash("Cambio de raza enviado para " .. ply:Nick() .. ": " .. pick.name)
               end, "primary")
               apply.Think = function(s) s:SetEnabled(pick != nil) end
          end)
     end
})

-- !irkdegis komutu da bu sayfayı açar
ShineAdmin:Route("fx_irk-irkdegis", function()
     ShineAdmin:Open("irk")
end)

--[[
*   şans baremi  ([sardon] sans :: "sardon_sans_ayarla" konsol komutu, sunucu yetki kontrolü yapar)
]]

ShineAdmin:RegisterPage("sans", {
     label = "Baremo de suerte",
     icon = "leaf",
     group = "players",
     order = 31,
     title = "Baremo de suerte",
     subtitle = "Cambia el baremo de suerte de hoy del jugador (D … SS+). Se sortea de nuevo cada día a las 07:00.",
     access = "leader",
     available = function() return SardonSans and SardonSans.Baremler end,

     build = function(ctx)
          local N = ShineAdmin.GetN()
          local u = N.u

          PlayerSplit(ctx, function(detail, ply, w, h)
               local pick

               DetailHead(N, detail, w, ply, "SUERTE")

               local current = vgui.Create("DPanel", detail)
               current:SetPos(0, u(76))
               current:SetSize(u(w), u(40))
               current.Paint = function(s, pw, ph)
                    if (!IsValid(ply)) then return end

                    local temel = SardonSans:Barem(math.max(ply:GetSansTemel(), 1)).id
                    local bonus = ply:GetSansBonus()
                    local deger = bonus != 0 and (temel .. "  (" .. (bonus > 0 and "+" or "") .. bonus .. " etken)") or temel
                    if (ply.SansAcik and !ply:SansAcik()) then deger = deger .. "  · oculto al jugador (sin lectura)" end
                    N.Property(0, 0, pw, "Baremo de hoy", deger, N.Clr.gold)
               end

               local grid = N.VList(detail, 0, u(128), u(w), u(h - 128 - 60), {
                    rowH = u(54),
                    cols = 5,
                    gapX = u(10),
                    gapY = u(10),
                    onClick = function(b) pick = b end,
                    paintRow = function(b, i, x, y, cw, ch, hovered)
                         local on = pick == b
                         local isCurrent = IsValid(ply) and math.max(ply:GetSansTemel(), 1) == b.index

                         N.Box(x, y, cw, ch, on and Color(201, 174, 119, 16) or N.Clr.toolBg)
                         N.Outline(x, y, cw, ch, on and N.Clr.gold or (hovered and N.Clr.btnLine or N.Clr.toolLine), 1)
                         N.Text(b.id, "serif", x + u(16), y + u(10), b.renk)
                         N.Text(isCurrent and "actual" or ("x" .. string.format("%.2f", b.carpan)), "tiny", x + u(16), y + u(34), isCurrent and N.Clr.ok or N.Clr.rowDesc)
                    end
               })
               grid:SetItems(SardonSans.Baremler)

               local bar = N.StickyBar(detail, 0, u(h - 52), u(w), function()
                    if (!pick) then return "Primero elige el nuevo baremo." end
                    return ply:Nick() .. " → " .. pick.id
               end)

               local apply = N.Button(bar, u(w) - u(170), u(8), u(170), u(36), "Aplicar", function()
                    if (!IsValid(ply) or !pick) then return end

                    LocalPlayer():ConCommand("sardon_sans_ayarla \"" .. ply:SteamID() .. "\" \"" .. pick.id .. "\"")
                    ctx.Flash("Baremo de suerte enviado para " .. ply:Nick() .. ": " .. pick.id)
               end, "primary")
               apply.Think = function(s) s:SetEnabled(pick != nil) end
          end)
     end
})

--[[
*   ruhsal denge  ([sardon] onur :: sardon_onur_sifirla (yetkili) / sardon_onur_ayarla (leader),
*   sunucu yetki kontrolü yapar). Değer oyuncunun yüklü karakterine uygulanır.
]]

ShineAdmin:RegisterPage("onur", {
     label = "Equilibrio espiritual",
     icon = "leaf",
     group = "players",
     order = 32,
     title = "Equilibrio espiritual",
     subtitle = "Reinicia el honor del personaje cargado del jugador o (líder de gestión) fíjalo a un valor concreto.",
     access = "staff",
     available = function() return SardonOnur and SardonOnur.Kademe end,

     build = function(ctx)
          local N = ShineAdmin.GetN()
          local u = N.u

          PlayerSplit(ctx, function(detail, ply, w, h)
               DetailHead(N, detail, w, ply, "EQUILIBRIO ESPIRITUAL")

               local current = vgui.Create("DPanel", detail)
               current:SetPos(0, u(76))
               current:SetSize(u(w), u(84))
               current.Paint = function(s, pw, ph)
                    if (!IsValid(ply)) then return end

                    local deger = ply:GetOnur()
                    local kademe = SardonOnur:Kademe(deger)
                    N.Property(0, 0, pw, "Honor actual", deger .. " / -" .. SardonOnur.Sinir .. "  ·  " .. kademe.ad, kademe.renk)

                    local esik = SardonOnur.ZorEsik
                    if (esik and deger <= esik) then
                         N.Text("%" .. math.abs(esik) * 100 / SardonOnur.Sinir .. " del umbral oscuro: las ganancias hacia la luz se reducen.", "tiny", 0, u(52), N.Clr.warn)
                    end
               end

               local y = 176
               N.Button(detail, 0, u(y), u(220), u(36), "Reiniciar honor (luz)", function()
                    if (!IsValid(ply)) then return end

                    N.Confirm("Reiniciar honor", "El honor del personaje cargado de " .. ply:Nick() .. " pasará a 0 (Luz, inicio).", "Reiniciar", function()
                         if (!IsValid(ply)) then return end
                         LocalPlayer():ConCommand("sardon_onur_sifirla \"" .. ply:SteamID() .. "\"")
                         ctx.Flash("Reinicio de honor enviado para " .. ply:Nick() .. ".")
                    end)
               end, "primary")

               if (ShineAdmin.Can(LocalPlayer(), "leader")) then
                    local miktar
                    y = y + 56
                    N.PlainEntry(detail, 0, u(y), u(200), u(36), "-1000 … 0 (0 luz)", function(v) miktar = tonumber(v) end)
                    N.Button(detail, u(210), u(y), u(170), u(36), "Ajustar a este valor", function()
                         if (!IsValid(ply) or !miktar) then return end

                         local n = SardonOnur:Clamp(miktar)
                         LocalPlayer():ConCommand("sardon_onur_ayarla \"" .. ply:SteamID() .. "\" " .. n)
                         ctx.Flash("Ajuste de honor enviado para " .. ply:Nick() .. ": " .. n)
                    end)
               end
          end)
     end
})

--[[
*   envanter  (sv_envanter.lua :: ShineAdmin.Envanter.Iste / Veri / Al / Sil)
*
*   Oyuncunun envanteri Helix envanter ızgarası gibi çizilir: ana envanter ve
*   her çanta kendi ızgarasında, eşyalar model ikonlarıyla. Yuvalar sunucunun
*   karakter ekranındaki (SardonKarakter.YuvaCiz) ile aynı; yoksa Helix'in
*   düz yuvası. Eşya seçilip yetkilinin üzerine alınır ya da silinir.
]]

local function DrawSlot(x, y, w, h, filled)
     if (SardonKarakter and SardonKarakter.YuvaCiz) then
          SardonKarakter.YuvaCiz(x, y, w, h, filled and "dolu" or nil)
          return
     end

     surface.SetDrawColor(0, 0, 0, 85)
     surface.DrawRect(x, y, w, h)
     surface.SetDrawColor(255, 255, 255, filled and 30 or 12)
     surface.DrawOutlinedRect(x, y, w, h, 1)
end

-- Helix'in eşya ikonu (iconCam / exRender dahil), envanter nesnesi olmadan
local function ItemIcon(parent, it, size, isSel, onPick)
     local def = ix.item.list[it.uniqueID]

     local icon = vgui.Create("SpawnIcon", parent)
     icon:SetSize(it.w * size, it.h * size)
     icon:SetModel(it.model, it.skin)
     icon:SetTooltip(it.name .. "\n" .. it.uniqueID .. "  ·  #" .. it.id .. (it.equip and "\nequipado" or ""))

     if (def and def.exRender and ikon) then
          icon.Icon:SetVisible(false)
          icon.ExtraPaint = function(s, w, h)
               local mat = ikon:GetIcon(def.uniqueID)
               if (mat) then
                    surface.SetMaterial(mat)
                    surface.SetDrawColor(color_white)
                    surface.DrawTexturedRect(0, 0, w, h)
               else
                    ikon:renderIcon(def.uniqueID, def.width, def.height, it.model, def.iconCam)
               end
          end
     elseif (def and def.iconCam) then
          icon.Icon:RebuildSpawnIconEx({cam_pos = def.iconCam.pos, cam_ang = def.iconCam.ang, cam_fov = def.iconCam.fov})
     end

     icon.Paint = function(s, w, h)
          if (isSel()) then
               surface.SetDrawColor(197, 156, 68, 30)
               surface.DrawRect(2, 2, w - 4, h - 4)
               surface.SetDrawColor(225, 187, 113)
               surface.DrawOutlinedRect(1, 1, w - 2, h - 2, 1)
          elseif (it.w > 1 or it.h > 1) then
               surface.SetDrawColor(123, 103, 66, 90)
               surface.DrawOutlinedRect(2, 2, w - 4, h - 4, 1)
          end

          if (s.ExtraPaint) then s:ExtraPaint(w, h) end
     end

     icon.PaintOver = function(s, w, h)
          if (it.equip) then
               surface.SetDrawColor(110, 200, 120)
               surface.DrawRect(w - 10, h - 10, 6, 6)
          end
     end

     icon.DoClick = function() onPick(it) end
     icon.DoRightClick = function() onPick(it, true) end
     icon.OpenMenu = function() end

     return icon
end

-- w x h hücreli ızgara + eşyaları; yükseklik döner
local function InventoryGrid(parent, title, invW, invH, items, size, isSel, onPick)
     local N = ShineAdmin.GetN()
     local u = N.u
     local TITLE_H = u(26)

     local holder = vgui.Create("DPanel", parent)
     holder:SetSize(invW * size, TITLE_H + invH * size)
     holder.Paint = function(s, pw)
          N.Text(title, "tiny", 0, u(4), N.Clr.gold)
     end

     local grid = vgui.Create("DPanel", holder)
     grid:SetPos(0, TITLE_H)
     grid:SetSize(invW * size, invH * size)

     local filled = {}
     for _, it in ipairs(items) do
          for dx = 0, it.w - 1 do
               for dy = 0, it.h - 1 do filled[(it.x + dx) .. ":" .. (it.y + dy)] = true end
          end
     end

     grid.Paint = function(s, pw, ph)
          local p = math.max(1, math.floor(size * 0.04))
          for x = 1, invW do
               for y = 1, invH do
                    DrawSlot((x - 1) * size + p, (y - 1) * size + p, size - p * 2, size - p * 2, filled[x .. ":" .. y])
               end
          end
     end

     for _, it in ipairs(items) do
          if (it.x >= 1 and it.y >= 1) then
               local icon = ItemIcon(grid, it, size, function() return isSel(it) end, onPick)
               icon:SetPos((it.x - 1) * size, (it.y - 1) * size)
          end
     end

     return holder
end

ShineAdmin:RegisterPage("envanter", {
     label = "Inventario",
     icon = "eye",
     group = "players",
     order = 25,
     title = "Inventario del jugador",
     subtitle = "Consulta el inventario del jugador; quédate objetos, bórralos o vacía el inventario por completo.",
     access = "staff",

     build = function(ctx)
          local N = ShineAdmin.GetN()
          local u = N.u

          local state = {target = nil, loaded = false}
          local split

          local function request(ply)
               state.target = ply
               state.loaded = false

               net.Start("ShineAdmin.Envanter.Iste")
                    net.WriteEntity(ply)
               net.SendToServer()
          end

          local function action(msg, ply, id)
               net.Start(msg)
                    net.WriteEntity(ply)
                    net.WriteUInt(id, 32)
               net.SendToServer()
          end

          local function take(ply, it)
               if (IsValid(ply)) then action("ShineAdmin.Envanter.Al", ply, it.id) end
          end

          local function askDelete(ply, it)
               N.Confirm("Eliminar objeto", it.name .. " (#" .. it.id .. ") se eliminará permanentemente del inventario de " .. ply:Nick() .. ".", "Eliminar", function()
                    if (IsValid(ply)) then action("ShineAdmin.Envanter.Sil", ply, it.id) end
               end, true)
          end

          split = PlayerSplit(ctx, function(detail, ply, w, h)
               if (state.target != ply) then
                    state.sel = nil
                    request(ply)
               end

               DetailHead(N, detail, w, ply, "INVENTARIO")

               if (!state.loaded) then
                    local wait = vgui.Create("DPanel", detail)
                    wait:SetPos(0, u(80))
                    wait:SetSize(u(w), u(40))
                    wait.Paint = function()
                         N.Text("Solicitando inventario al servidor…", "body", 0, u(10), N.Clr.faint)
                    end
                    return
               end

               if (!state.hasChar) then
                    ShineAdmin.Placeholder(detail, 0, u(76), u(w), u(h - 76), "El jugador no tiene un personaje cargado.")
                    return
               end

               -- seçili eşya yenilenen listede yoksa bırak
               if (state.sel) then
                    local found
                    for _, it in ipairs(state.items) do
                         if (it.id == state.sel.id) then found = it end
                    end
                    state.sel = found
               end

               local info = vgui.Create("DPanel", detail)
               info:SetPos(0, u(76))
               info:SetSize(u(w), u(40))
               info.Paint = function(s, pw, ph)
                    N.Property(0, 0, pw, "Personaje", state.charName .. "  (#" .. state.charID .. ")  ·  " .. #state.items .. " objetos", N.Clr.gold)
               end

               local function isSel(it) return state.sel and state.sel.id == it.id end

               local function onPick(it, right)
                    state.sel = it

                    if (right) then
                         local m = DermaMenu()
                         m:AddOption("Tomar para mí", function() take(ply, it) end):SetIcon("icon16/arrow_down.png")
                         m:AddOption("Eliminar", function() askDelete(ply, it) end):SetIcon("icon16/delete.png")
                         m:Open()
                    end
               end

               -- ızgaralar: ana envanter + her çanta, kaydırılabilir alanda
               local scrollY = u(124)
               local scrollH = u(h) - scrollY - u(60)
               local scroll = N.Scroll(detail, 0, scrollY, u(w), scrollH)
               local canvas = scroll:GetCanvas()

               local areaW = u(w) - u(20)
               local size = math.floor(math.min(u(64), areaW / math.max(state.w, 1)))

               local byInv = {}
               for _, it in ipairs(state.items) do
                    byInv[it.invID] = byInv[it.invID] or {}
                    table.insert(byInv[it.invID], it)
               end

               local y = 0
               local main = InventoryGrid(canvas, "INVENTARIO PRINCIPAL  ·  " .. state.w .. "x" .. state.h, state.w, state.h, byInv[state.invID] or {}, size, isSel, onPick)
               main:SetPos(0, y)
               y = y + main:GetTall() + u(18)

               for _, bag in ipairs(state.bags) do
                    local bagSize = math.floor(math.min(size, areaW / math.max(bag.w, 1)))
                    local g = InventoryGrid(canvas, string.utf8upper(bag.name) .. "  ·  " .. bag.w .. "x" .. bag.h, bag.w, bag.h, byInv[bag.id] or {}, bagSize, isSel, onPick)
                    g:SetPos(0, y)
                    y = y + g:GetTall() + u(18)
               end

               -- yerleşimi bozuk (konumsuz) eşyalar da görünsün
               local lost = {}
               for _, it in ipairs(state.items) do
                    if (it.x < 1 or it.y < 1) then lost[#lost + 1] = it.name .. " (#" .. it.id .. ")" end
               end
               if (#lost > 0) then
                    local l = vgui.Create("DPanel", canvas)
                    l:SetPos(0, y)
                    l:SetSize(areaW, u(24))
                    l.Paint = function()
                         N.Text("Sin posición: " .. table.concat(lost, ", "), "tiny", 0, u(4), N.Clr.warn)
                    end
               end

               local bar = N.StickyBar(detail, 0, u(h - 52), u(w), function()
                    if (state.sel) then
                         return state.sel.name .. "  ·  #" .. state.sel.id .. (state.sel.equip and "  ·  equipado" or ""), N.Clr.gold
                    end
                    return "Elige un objeto (clic derecho: menú). Todas las acciones se registran."
               end)

               local bx = u(w)

               bx = bx - u(210)
               local wipe = N.Button(bar, bx, u(8), u(210), u(36), "Vaciar inventario por completo", function()
                    if (!IsValid(ply)) then return end

                    N.Confirm("Vaciar inventario por completo", "Se eliminarán permanentemente los " .. #state.items .. " objetos del personaje " .. ply:Nick() .. " (" .. state.charName .. "), incluidas las bolsas. No se puede deshacer.", "Eliminar todo", function()
                         if (IsValid(ply)) then action("ShineAdmin.Envanter.Sil", ply, 0) end
                    end, true)
               end, "danger")
               wipe.Think = function(s) s:SetEnabled(#state.items > 0) end

               bx = bx - u(100)
               local del = N.Button(bar, bx, u(8), u(90), u(36), "Eliminar", function()
                    if (state.sel and IsValid(ply)) then askDelete(ply, state.sel) end
               end, "danger")
               del.Think = function(s) s:SetEnabled(state.sel != nil) end

               bx = bx - u(150)
               local takeBtn = N.Button(bar, bx, u(8), u(140), u(36), "Tomar para mí", function()
                    if (state.sel) then take(ply, state.sel) end
               end, "primary")
               takeBtn.Think = function(s) s:SetEnabled(state.sel != nil and ply != LocalPlayer()) end

               bx = bx - u(100)
               N.Button(bar, bx, u(8), u(90), u(36), "Actualizar", function()
                    if (IsValid(ply)) then request(ply) end
               end, "ghost")
          end)

          ctx.SetEnvanter = function(ply, data)
               if (!IsValid(ply) or state.target != ply) then return end

               for k, v in pairs(data) do state[k] = v end
               state.loaded = true

               split.Select(ply)
          end
     end
})

net.Receive("ShineAdmin.Envanter.Veri", function()
     local ply = net.ReadEntity()
     local data = {hasChar = net.ReadBool(), items = {}, bags = {}}

     if (data.hasChar) then
          data.charName = net.ReadString()
          data.charID = net.ReadUInt(32)
          data.invID = net.ReadUInt(32)
          data.w = net.ReadUInt(8)
          data.h = net.ReadUInt(8)

          for i = 1, net.ReadUInt(8) do
               data.bags[i] = {id = net.ReadUInt(32), w = net.ReadUInt(8), h = net.ReadUInt(8), name = net.ReadString()}
          end

          for i = 1, net.ReadUInt(12) do
               data.items[i] = {
                    id = net.ReadUInt(32),
                    invID = net.ReadUInt(32),
                    uniqueID = net.ReadString(),
                    name = net.ReadString(),
                    model = net.ReadString(),
                    skin = net.ReadUInt(8),
                    x = net.ReadUInt(8),
                    y = net.ReadUInt(8),
                    w = net.ReadUInt(8),
                    h = net.ReadUInt(8),
                    equip = net.ReadBool()
               }
          end
     end

     local ctx = ShineAdmin:ActiveCtx("envanter")
     if (ctx and ctx.SetEnvanter) then ctx.SetEnvanter(ply, data) end
end)
