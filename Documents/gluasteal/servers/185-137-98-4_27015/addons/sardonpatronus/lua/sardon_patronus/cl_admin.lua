-- "addons\\sardonpatronus\\lua\\sardon_patronus\\cl_admin.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Patronus :: Shine Admin sayfaları
--
--   "patronus" : çevrimiçi karakterlerin patronusu (hayvan atama, ustalık,
--                cismaniyi doğrudan açma)
--   "ruhemici" : NPC Ruh Emici bölgeleri (merkez = bulunduğun nokta) + dünyada
--                bölge halkaları
-- İkisi de aynı ağ mesajlarını kullanır (sv_ruhemici.lua: Admin / Liste).

SardonPatronus = SardonPatronus or {}
local P = SardonPatronus

P.AdminVeri = P.AdminVeri or {bolgeler = {}, kisiler = {}, toplam = 0, globalMax = 0}
P.BolgeGoster = P.BolgeGoster or false

function P.AdminIstek(islem, veri)
     net.Start("SardonPatronus.Admin")
          net.WriteString(islem)
          net.WriteTable(veri or {})
     net.SendToServer()
end

net.Receive("SardonPatronus.Liste", function()
     P.AdminVeri = net.ReadTable()

     if not (ShineAdmin and ShineAdmin.ActiveCtx) then return end
     for _, id in ipairs({"patronus", "ruhemici"}) do
          local ctx = ShineAdmin:ActiveCtx(id)
          if ctx and ctx.PatronusYenile then ctx.PatronusYenile() end
     end
end)

/*
*   dünyada bölge halkaları (yalnızca "göster" açıkken)
*/

local halkaDolu = Color(150, 190, 255, 210)
local halkaBos = Color(120, 130, 160, 170)
local SEGMENT = 48

surface.CreateFont("SardonPatronus.Bolge", {font = "Montserrat SemiBold", size = 48, weight = 600, extended = true})

hook.Add("PostDrawTranslucentRenderables", "SardonPatronus.Bolgeler", function(derinlik, gokyuzu)
     if not P.BolgeGoster or gokyuzu or derinlik then return end

     local goz = EyePos()

     for _, b in ipairs(P.AdminVeri.bolgeler or {}) do
          local pos = b.pos

          if isvector(pos) and goz:DistToSqr(pos) < (b.yaricap + 4000) ^ 2 then
               local r = b.yaricap
               local renk = (b.canli or 0) > 0 and halkaDolu or halkaBos
               local z = pos.z + 6
               local onceki = Vector(pos.x + r, pos.y, z)

               for i = 1, SEGMENT do
                    local a = (i / SEGMENT) * math.pi * 2
                    local nokta = Vector(pos.x + math.cos(a) * r, pos.y + math.sin(a) * r, z)
                    render.DrawLine(onceki, nokta, renk, true)
                    onceki = nokta
               end

               render.DrawLine(pos, pos + Vector(0, 0, 90), renk, true)

               cam.Start3D2D(pos + Vector(0, 0, 100), Angle(0, EyeAngles().y - 90, 90), 0.25)
                    draw.SimpleText(b.ad .. "  #" .. b.id, "SardonPatronus.Bolge", 0, 0, renk, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
                    draw.SimpleText((b.canli or 0) .. "/" .. b.max .. " Ruh Emici  ·  r " .. b.yaricap, "SardonPatronus.Bolge", 0, 8, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
               cam.End3D2D()
          end
     end
end)

timer.Create("SardonPatronus.GosterYenile", 5, 0, function()
     if P.BolgeGoster and P.Yetkili(LocalPlayer()) then P.AdminIstek("liste") end
end)

local LIST_W = 340
local GAP = 24
local UST_H = 52

/*
*   sayfa: oyuncu patronusları
*/

local sayfaKisi = {
     id = "patronus",
     label = "Patronus",
     icon = "star",
     group = "players",
     order = 45,
     title = "Patronus",
     subtitle = "Animal patronus y maestría de personajes en línea. El animal sale al azar en el primer lanzamiento corpóreo; se puede cambiar aquí.",
     access = "staff",
     available = function() return SardonPatronus and SardonPatronus.Hayvanlar end,

     build = function(ctx)
          local N = ShineAdmin.GetN()
          local u = N.u
          local S = ctx.panel

          local secili -- steamid64
          local ustalik = 0
          local detail, liste

          local function Kisi(sid)
               for _, k in ipairs(P.AdminVeri.kisiler or {}) do
                    if k.sid == sid then return k end
               end
          end

          local detailX = LIST_W + GAP
          local detailW = ctx.w - detailX

          local function DetayKur()
               if IsValid(detail) then detail:Remove() end

               detail = vgui.Create("DPanel", S)
               detail:SetPos(u(detailX), u(UST_H))
               detail:SetSize(u(detailW), u(ctx.h - UST_H))
               detail.Paint = function() end

               local h = ctx.h - UST_H
               local k = secili and Kisi(secili)

               if not k then
                    ShineAdmin.Placeholder(detail, 0, 0, u(detailW), u(h), "Elige un jugador de la izquierda.")
                    return
               end

               ustalik = k.ustalik or 0

               local durum = vgui.Create("DPanel", detail)
               durum:SetPos(0, 0)
               durum:SetSize(u(detailW), u(52))
               durum.Paint = function(s, pw, ph)
                    local g = Kisi(secili)
                    if not g then return end
                    local hayvan = g.tur and P.Hayvanlar[g.tur]

                    N.Text(g.ad, "row", 0, u(4), N.Clr.goldAccent)
                    N.Text((hayvan and hayvan.ad or "Aún sin forma") .. "  ·  maestría " .. (g.ustalik or 0) .. " / " .. P.Ayar.CismaniEsik
                         .. "  ·  Onur " .. (g.onur or 0) .. "  ·  " .. (g.cismani and "puede corpóreo" or "solo niebla"),
                         "small", 0, u(30), N.Clr.rowDesc)
               end

               N.Slider(detail, 0, u(60), u(detailW - 150), "Maestría (lanzamientos exitosos)", 0, 100, 0,
                    function() return ustalik end, function(v) ustalik = math.floor(v) end)
               N.Button(detail, u(detailW - 140), u(70), u(140), u(36), "Guardar maestría", function()
                    P.AdminIstek("ustalik", {sid = secili, deger = ustalik})
               end)

               local baslik = vgui.Create("DPanel", detail)
               baslik:SetPos(0, u(126))
               baslik:SetSize(u(detailW), u(24))
               baslik.Paint = function(s, pw, ph)
                    N.Text("ANIMAL PATRONUS  (clic para asignar al instante)", "tiny", 0, ph / 2, N.Clr.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               end

               local grid = N.VList(detail, 0, u(154), u(detailW), u(h - 154 - 64), {
                    rowH = u(44),
                    cols = 3,
                    gapX = u(8),
                    gapY = u(8),
                    onClick = function(id)
                         P.AdminIstek("tur", {sid = secili, tur = id})
                    end,
                    paintRow = function(id, i, x, y, cw, ch, hovered)
                         local t = P.Hayvanlar[id]
                         local g = Kisi(secili)
                         local on = g and g.tur == id

                         N.Box(x, y, cw, ch, on and Color(201, 174, 119, 18) or N.Clr.toolBg)
                         N.Outline(x, y, cw, ch, on and N.Clr.gold or (hovered and N.Clr.btnLine or N.Clr.toolLine), 1)
                         N.Text(t.ad, "row", x + u(12), y + u(8), on and N.Clr.goldAccent or N.Clr.rowText)
                         N.Text("peso de aparición " .. (t.agirlik or 1), "micro", x + u(12), y + u(26), N.Clr.rowDesc)
                    end
               })
               grid:SetItems(P.HayvanSirasi)

               local bar = N.StickyBar(detail, 0, u(h - 52), u(detailW), function()
                    local g = Kisi(secili)
                    if not g then return "" end
                    return g.acik and "Corpóreo directo activo (ustalık aranmıyor)." or "Corpóreo ligado a maestría."
               end)

               local bx = u(detailW)
               local function Dugme(w, yazi, fn, stil)
                    bx = bx - u(w)
                    local d = N.Button(bar, bx, u(8), u(w), u(36), yazi, fn, stil)
                    bx = bx - u(8)
                    return d
               end

               local ac = Dugme(220, function()
                    local g = Kisi(secili)
                    return (g and g.acik) and "Volver a ligar a maestría" or "Activar corpóreo directo"
               end, function()
                    local g = Kisi(secili)
                    if g then P.AdminIstek("acik", {sid = secili, acik = not g.acik}) end
               end)
               ac.NoCaps = true

               Dugme(200, "Reiniciar animal", function()
                    local sid, ad = secili, k.ad
                    N.Confirm("Reiniciar animal", ad .. " bir sonraki cismani atışında yeniden rastgele bir hayvan çekecek.", "Reiniciar", function()
                         P.AdminIstek("tur", {sid = sid})
                    end, true)
               end, "danger")
          end

          N.Button(S, 0, 0, u(110), u(36), "Actualizar", function()
               P.AdminIstek("liste")
          end, "quiet")

          liste = N.VList(S, 0, u(UST_H), u(LIST_W), u(ctx.h - UST_H), {
               rowH = u(58),
               gapY = u(6),
               emptyText = "No hay jugadores con personaje cargado.",
               onClick = function(k)
                    if secili == k.sid then return end
                    secili = k.sid
                    DetayKur()
               end,
               paintRow = function(k, i, x, y, cw, ch, hovered)
                    local on = secili == k.sid
                    local hayvan = k.tur and P.Hayvanlar[k.tur]

                    N.Box(x, y, cw, ch, on and N.Clr.selRow or (hovered and N.Clr.hoverRow or N.Clr.toolBg))
                    N.Outline(x, y, cw, ch, on and N.Clr.gold or N.Clr.toolLine, 1)
                    N.Text(k.ad, "row", x + u(12), y + u(10), on and N.Clr.goldAccent or N.Clr.rowText)
                    N.Text((hayvan and hayvan.ad or "sin forma") .. "  ·  maestría " .. (k.ustalik or 0), "micro", x + u(12), y + u(32), N.Clr.rowDesc)

                    if k.cismani then N.Box(x + cw - u(14), y + u(14), u(6), u(6), N.Clr.ok) end
               end
          })

          function ctx.PatronusYenile()
               if IsValid(liste) then liste:SetItems(P.AdminVeri.kisiler or {}, true) end
               if secili and not Kisi(secili) then
                    secili = nil
                    DetayKur()
               end
          end

          ctx.SetHead({
               note = function() return #(P.AdminVeri.kisiler or {}) .. " PERSONAJES" end
          })

          liste:SetItems(P.AdminVeri.kisiler or {})
          DetayKur()
          P.AdminIstek("liste")
     end
}

/*
*   sayfa: Ruh Emici bölgeleri
*/

local sayfaBolge = {
     id = "ruhemici",
     label = "Zonas de Dementoreses",
     icon = "moon",
     group = "systems",
     order = 41,
     title = "Zonas de Dementoreses",
     subtitle = "Zonas donde aparece un NPC Dementores al entrar un jugador. El centro se guarda en tu posición. Solo el patronus los repele.",
     access = "staff",
     available = function() return SardonPatronus and SardonPatronus.Hayvanlar end,

     build = function(ctx)
          local N = ShineAdmin.GetN()
          local u = N.u
          local S = ctx.panel

          local secili, form, bekleyenSecim
          local detail, liste

          local function Bolge(id)
               for _, b in ipairs(P.AdminVeri.bolgeler or {}) do
                    if b.id == id then return b end
               end
          end

          local function Degisti()
               local b = form and Bolge(form.id)
               if not b then return false end
               return b.ad ~= form.ad or b.yaricap ~= form.yaricap or b.max ~= form.max or b.yeniden ~= form.yeniden
          end

          local detailX = LIST_W + GAP
          local detailW = ctx.w - detailX

          local function DetayKur()
               if IsValid(detail) then detail:Remove() end

               detail = vgui.Create("DPanel", S)
               detail:SetPos(u(detailX), u(UST_H))
               detail:SetSize(u(detailW), u(ctx.h - UST_H))
               detail.Paint = function() end

               local h = ctx.h - UST_H
               local b = secili and Bolge(secili)

               if not b then
                    form = nil
                    ShineAdmin.Placeholder(detail, 0, 0, u(detailW), u(h), "Elige una zona a la izquierda o añade una nueva donde estés.")
                    return
               end

               if not form or form.id ~= b.id then
                    form = {id = b.id, ad = b.ad, yaricap = b.yaricap, max = b.max, yeniden = b.yeniden}
               end

               local _, e = N.PlainEntry(detail, 0, 0, u(detailW), u(36), "Nombre de la zona", function(v)
                    form.ad = v
               end)
               e:SetValue(form.ad)

               local colW = math.floor((detailW - 20) / 3)

               N.Slider(detail, 0, u(48), u(colW), "Radio (unidades)", 200, 6000, 0,
                    function() return form.yaricap end, function(v) form.yaricap = math.floor(v) end)
               N.Slider(detail, u(colW + 10), u(48), u(colW), "Máximo de Dementoreses a la vez", 1, 4, 0,
                    function() return form.max end, function(v) form.max = math.floor(v) end)
               N.Slider(detail, u((colW + 10) * 2), u(48), u(colW), "Espera tras expulsión (s)", 10, 3600, 0,
                    function() return form.yeniden end, function(v) form.yeniden = math.floor(v) end)

               local durum = vgui.Create("DPanel", detail)
               durum:SetPos(0, u(114))
               durum:SetSize(u(detailW), u(28))
               durum.Paint = function(s, pw, ph)
                    local g = Bolge(secili)
                    if not g then return end

                    local yazi = (g.canli or 0) .. " Ruh Emici  ·  bölgede " .. (g.oyuncu or 0) .. " oyuncu"
                    if (g.kalan or 0) > 0 then yazi = yazi .. "  ·  yeni doğuma " .. g.kalan .. " sn" end
                    N.Text(yazi, "small", 0, ph / 2, N.Clr.rowDesc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               end

               local bar = N.StickyBar(detail, 0, u(h - 52), u(detailW), function()
                    if Degisti() then return "Hay cambios sin guardar.", N.Clr.warn end
                    if not form then return end   -- form silindiği karede (2026-11-14)
                    return "#" .. form.id
               end)

               local bx = u(detailW)
               local function Dugme(w, yazi, fn, stil)
                    bx = bx - u(w)
                    local d = N.Button(bar, bx, u(8), u(w), u(36), yazi, fn, stil)
                    bx = bx - u(8)
                    return d
               end

               local kaydet = Dugme(120, "Guardar", function()
                    P.AdminIstek("guncelle", {id = form.id, ad = form.ad, yaricap = form.yaricap, max = form.max, yeniden = form.yeniden})
               end, "primary")
               kaydet.Think = function(s) s:SetEnabled(Degisti()) end

               Dugme(96, "Generar", function() P.AdminIstek("dogur", {id = form.id}) end)
               Dugme(96, "Teletransportarse", function() P.AdminIstek("git", {id = form.id}) end)
               Dugme(130, "Centro aquí", function() P.AdminIstek("konum", {id = form.id}) end)
               Dugme(96, "Vaciar", function() P.AdminIstek("temizle", {id = form.id}) end)

               Dugme(80, "Borrar", function()
                    local id, ad = form.id, form.ad
                    N.Confirm("Borrar zona", ad .. " bölgesi ve içindeki Ruh Emiciler kaldırılacak.", "Borrar", function()
                         secili = nil
                         form = nil
                         P.AdminIstek("sil", {id = id})
                    end, true)
               end, "danger")
          end

          local x = 0
          N.Button(S, 0, 0, u(200), u(36), "Nueva zona aquí", function()
               local n = #(P.AdminVeri.bolgeler or {}) + 1
               bekleyenSecim = true
               P.AdminIstek("ekle", {ad = "Ruh Emici " .. n, yaricap = 900, max = 1, yeniden = 180})
          end, "primary")
          x = x + 208

          local goster = N.Button(S, u(x), 0, u(180), u(36), function()
               return P.BolgeGoster and "Ocultar zonas" or "Mostrar zonas"
          end, function()
               P.BolgeGoster = not P.BolgeGoster
          end)
          goster.NoCaps = true
          x = x + 188

          N.Button(S, u(x), 0, u(110), u(36), "Actualizar", function()
               P.AdminIstek("liste")
          end, "quiet")

          local sayac = vgui.Create("DPanel", S)
          sayac:SetPos(u(x + 120), 0)
          sayac:SetSize(u(ctx.w - x - 120), u(36))
          sayac.Paint = function(s, pw, ph)
               local v = P.AdminVeri
               N.Text("Haritada " .. (v.toplam or 0) .. " / " .. (v.globalMax or 0) .. " Ruh Emici  ·  " .. #(v.bolgeler or {}) .. " bölge",
                    "small", pw, ph / 2, N.Clr.rowDesc, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
          end

          liste = N.VList(S, 0, u(UST_H), u(LIST_W), u(ctx.h - UST_H), {
               rowH = u(58),
               gapY = u(6),
               emptyText = "Aún no hay zonas.",
               onClick = function(b)
                    if secili == b.id then return end
                    secili = b.id
                    form = nil
                    DetayKur()
               end,
               paintRow = function(b, i, rx, ry, cw, ch, hovered)
                    local on = secili == b.id

                    N.Box(rx, ry, cw, ch, on and N.Clr.selRow or (hovered and N.Clr.hoverRow or N.Clr.toolBg))
                    N.Outline(rx, ry, cw, ch, on and N.Clr.gold or N.Clr.toolLine, 1)
                    N.Text(b.ad, "row", rx + u(12), ry + u(10), on and N.Clr.goldAccent or N.Clr.rowText)
                    N.Text("#" .. b.id .. "  ·  r " .. b.yaricap .. "  ·  " .. (b.canli or 0) .. "/" .. b.max .. "  ·  " .. (b.oyuncu or 0) .. " oyuncu",
                         "micro", rx + u(12), ry + u(32), N.Clr.rowDesc)

                    if (b.canli or 0) > 0 then N.Box(rx + cw - u(14), ry + u(14), u(6), u(6), N.Clr.ok) end
               end
          })

          function ctx.PatronusYenile()
               local veri = P.AdminVeri.bolgeler or {}

               if bekleyenSecim then
                    bekleyenSecim = nil
                    local m
                    for _, b in ipairs(veri) do if not m or b.id > m then m = b.id end end
                    secili = m
                    form = nil
               end

               if IsValid(liste) then liste:SetItems(veri, true) end

               if secili and not Bolge(secili) then
                    secili = nil
                    form = nil
                    DetayKur()
               elseif secili and (not form or form.id ~= secili) then
                    DetayKur()
               end
          end

          ctx.SetHead({
               note = function()
                    local v = P.AdminVeri
                    return (v.toplam or 0) .. " DEMENTORES  ·  " .. #(v.bolgeler or {}) .. " BÖLGE"
               end
          })

          liste:SetItems(P.AdminVeri.bolgeler or {})
          DetayKur()
          P.AdminIstek("liste")
     end
}

-- ShineAdmin yüklenme sırası belli değil; sayfa tablosuna doğrudan yazılır.
ShineAdmin = ShineAdmin or {}
ShineAdmin.Pages = ShineAdmin.Pages or {}
ShineAdmin.Pages.patronus = sayfaKisi
ShineAdmin.Pages.ruhemici = sayfaBolge

concommand.Add("sardon_patronus_admin", function()
     if ShineAdmin and ShineAdmin.Open then ShineAdmin:Open("patronus") end
end)

concommand.Add("sardon_ruhemici_admin", function()
     if ShineAdmin and ShineAdmin.Open then ShineAdmin:Open("ruhemici") end
end)
