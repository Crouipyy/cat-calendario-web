-- "addons\\sardonhayvan\\lua\\sardon_hayvan\\cl_admin.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Hayvan :: admin paneli (Shine Admin sayfası "hayvan") + bölge çizimi
--
-- Bölge eklemek: bölgenin merkezine git, "Nueva zona aquí". Ayarları sağdan
-- düzenle, "Guardar". "Mostrar zonas" açıkken dünyada halkalar çizilir.

SardonHayvan.AdminVeri = SardonHayvan.AdminVeri or {bolgeler = {}, toplam = 0, globalMax = 0}
SardonHayvan.Goster = SardonHayvan.Goster or false

function SardonHayvan:AdminIstek(islem, veri)
     net.Start("SardonHayvan.Admin")
          net.WriteString(islem)
          net.WriteTable(veri or {})
     net.SendToServer()
end

net.Receive("SardonHayvan.Liste", function()
     SardonHayvan.AdminVeri = net.ReadTable()

     local ctx = ShineAdmin and ShineAdmin.ActiveCtx and ShineAdmin:ActiveCtx("hayvan")
     if (ctx and ctx.HayvanYenile) then ctx.HayvanYenile() end
end)

/*
*   dünyada bölge halkaları (yalnızca admin, "göster" açıkken)
*/

local halkaRenk = Color(120, 220, 120, 200)
local halkaBos = Color(220, 190, 110, 160)
local SEGMENT = 48

surface.CreateFont("SardonHayvan.Bolge", {font = "Montserrat SemiBold", size = 48, weight = 600, extended = true})

hook.Add("PostDrawTranslucentRenderables", "SardonHayvan.Bolgeler", function(depth, skybox)
     if (!SardonHayvan.Goster or skybox or depth) then return end

     local eye = EyePos()

     for _, b in ipairs(SardonHayvan.AdminVeri.bolgeler or {}) do
          local pos = b.pos

          if (isvector(pos) and eye:DistToSqr(pos) < (b.yaricap + 4000) ^ 2) then
               local r = b.yaricap
               local renk = (b.canli or 0) > 0 and halkaRenk or halkaBos
               local z = pos.z + 6
               local onceki = Vector(pos.x + r, pos.y, z)

               for i = 1, SEGMENT do
                    local a = (i / SEGMENT) * math.pi * 2
                    local nokta = Vector(pos.x + math.cos(a) * r, pos.y + math.sin(a) * r, z)
                    render.DrawLine(onceki, nokta, renk, true)
                    onceki = nokta
               end

               render.DrawLine(pos, pos + Vector(0, 0, 90), renk, true)

               local ang = EyeAngles()
               cam.Start3D2D(pos + Vector(0, 0, 100), Angle(0, ang.y - 90, 90), 0.25)
                    draw.SimpleText(b.ad .. "  #" .. b.id, "SardonHayvan.Bolge", 0, 0, renk, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
                    draw.SimpleText((b.canli or 0) .. "/" .. b.max .. " canlı  ·  " .. #(b.turler or {}) .. " tür  ·  r " .. b.yaricap, "SardonHayvan.Bolge", 0, 8, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
               cam.End3D2D()
          end
     end
end)

-- göster açıkken sayaçlar güncel kalsın
timer.Create("SardonHayvan.GosterYenile", 5, 0, function()
     if (SardonHayvan.Goster and SardonHayvan.Yetkili(LocalPlayer())) then
          SardonHayvan:AdminIstek("liste")
     end
end)

/*
*   Shine Admin sayfası
*   ShineAdmin yüklenme sırası belli değil; sayfa tablosuna doğrudan yazılır
*   (cl_init.lua "ShineAdmin.Pages or {}" ile koruyor).
*/

local LIST_W = 340
local GAP = 24

local function TurAdlari(turler)
     local out = {}
     for _, id in ipairs(turler or {}) do
          local t = SardonHayvan.Turler[id]
          out[#out + 1] = t and t.ad or id
     end
     return table.concat(out, ", ")
end

local sayfa = {
     id = "hayvan",
     label = "Zonas de animales",
     icon = "leaf",
     group = "systems",
     order = 40,
     title = "Zonas de animales",
     subtitle = "Zonas donde aparecen animales al entrar un jugador. El centro se guarda en tu posición.",
     access = "staff",
     available = function() return SardonHayvan and SardonHayvan.Turler end,

     build = function(ctx)
          local N = ShineAdmin.GetN()
          local u = N.u
          local P = ctx.panel

          local secili -- bölge id
          local form -- düzenlenen kopya
          local bekleyenSecim -- "yeni bölge" sonrası en yüksek id'yi seç

          local detail
          local liste

          local function Bolge(id)
               for _, b in ipairs(SardonHayvan.AdminVeri.bolgeler or {}) do
                    if (b.id == id) then return b end
               end
          end

          local function FormKur(b)
               local set = {}
               for _, id in ipairs(b.turler or {}) do set[id] = true end

               form = {id = b.id, ad = b.ad, yaricap = b.yaricap, max = b.max, yeniden = b.yeniden, turler = set}
          end

          local function FormTurler()
               local out = {}
               for _, id in ipairs(SardonHayvan.TurSirasi) do
                    if (form.turler[id]) then out[#out + 1] = id end
               end
               return out
          end

          local function Degisti()
               local b = form and Bolge(form.id)
               if (!b) then return false end
               if (b.ad != form.ad or b.yaricap != form.yaricap or b.max != form.max or b.yeniden != form.yeniden) then return true end

               local a, c = FormTurler(), b.turler or {}
               if (#a != #c) then return true end
               for i = 1, #a do if (a[i] != c[i] and !table.HasValue(c, a[i])) then return true end end

               return false
          end

          local detailX = LIST_W + GAP
          local detailW = ctx.w - detailX
          local ustH = 52

          local function DetayKur()
               if (IsValid(detail)) then detail:Remove() end

               detail = vgui.Create("DPanel", P)
               detail:SetPos(u(detailX), u(ustH))
               detail:SetSize(u(detailW), u(ctx.h - ustH))
               detail.Paint = function() end

               local b = secili and Bolge(secili)
               local h = ctx.h - ustH

               if (!b) then
                    form = nil
                    ShineAdmin.Placeholder(detail, 0, 0, u(detailW), u(h), "Elige una zona a la izquierda o añade una nueva donde estés.")
                    return
               end

               if (!form or form.id != b.id) then FormKur(b) end

               -- ad
               local _, e = N.PlainEntry(detail, 0, 0, u(detailW), u(36), "Nombre de la zona", function(v)
                    form.ad = v
               end)
               e:SetValue(form.ad)

               -- sayılar
               local colW = math.floor((detailW - 20) / 3)

               N.Slider(detail, 0, u(48), u(colW), "Radio (unidades)", 150, 6000, 0,
                    function() return form.yaricap end, function(v) form.yaricap = math.floor(v) end)
               N.Slider(detail, u(colW + 10), u(48), u(colW), "Máximo de animales a la vez", 1, 5, 0,
                    function() return form.max end, function(v) form.max = math.floor(v) end)
               N.Slider(detail, u((colW + 10) * 2), u(48), u(colW), "Espera tras muerte (s)", 5, 3600, 0,
                    function() return form.yeniden end, function(v) form.yeniden = math.floor(v) end)

               -- durum
               local durum = vgui.Create("DPanel", detail)
               durum:SetPos(0, u(114))
               durum:SetSize(u(detailW), u(28))
               durum.Paint = function(s, pw, ph)
                    local g = Bolge(secili)
                    if (!g) then return end

                    local yazi = (g.canli or 0) .. " animales vivos  ·  en zona " .. (g.oyuncu or 0) .. " jugadores"
                    if ((g.kalan or 0) > 0) then yazi = yazi .. "  ·  hasta nuevo nacimiento " .. g.kalan .. " sn" end

                    N.Text(yazi, "small", 0, ph / 2, N.Clr.rowDesc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               end

               -- türler
               local turBaslik = vgui.Create("DPanel", detail)
               turBaslik:SetPos(0, u(146))
               turBaslik:SetSize(u(detailW), u(24))
               turBaslik.Paint = function(s, pw, ph)
                    if not form then return end   -- form silindiği karede (2026-11-13)
                    local n = 0
                    for _ in pairs(form.turler) do n = n + 1 end
                    N.Text("ESPECIES POSIBLES  (" .. n .. " seleccionadas, una al azar al nacer)", "tiny", 0, ph / 2, N.Clr.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               end

               local grid = N.VList(detail, 0, u(174), u(detailW), u(h - 174 - 64), {
                    rowH = u(44),
                    cols = 3,
                    gapX = u(8),
                    gapY = u(8),
                    onClick = function(id)
                         form.turler[id] = !form.turler[id] or nil
                    end,
                    paintRow = function(id, i, x, y, cw, ch, hovered)
                         local t = SardonHayvan.Turler[id]
                         local on = form.turler[id]

                         N.Box(x, y, cw, ch, on and Color(201, 174, 119, 18) or N.Clr.toolBg)
                         N.Outline(x, y, cw, ch, on and N.Clr.gold or (hovered and N.Clr.btnLine or N.Clr.toolLine), 1)
                         N.Text(t.ad, "row", x + u(12), y + u(8), on and N.Clr.goldAccent or N.Clr.rowText)
                         N.Text(t.can .. " vida  ·  " .. t.hasar .. " daño" .. (t.saldirgan == false and "  ·  pasivo" or ""), "micro", x + u(12), y + u(26), N.Clr.rowDesc)
                    end
               })
               grid:SetItems(SardonHayvan.TurSirasi)

               -- alt şerit
               local bar = N.StickyBar(detail, 0, u(h - 52), u(detailW), function()
                    if (Degisti()) then return "Hay cambios sin guardar.", N.Clr.warn end
                    return "#" .. form.id .. "  ·  " .. TurAdlari(FormTurler())
               end)

               local bx = u(detailW)
               local function Dugme(w, yazi, fn, stil)
                    bx = bx - u(w)
                    local d = N.Button(bar, bx, u(8), u(w), u(36), yazi, fn, stil)
                    bx = bx - u(8)
                    return d
               end

               local kaydet = Dugme(120, "Guardar", function()
                    SardonHayvan:AdminIstek("guncelle", {id = form.id, ad = form.ad, yaricap = form.yaricap, max = form.max, yeniden = form.yeniden, turler = FormTurler()})
               end, "primary")
               kaydet.Think = function(s) s:SetEnabled(Degisti()) end

               Dugme(96, "Generar", function()
                    SardonHayvan:AdminIstek("dogur", {id = form.id})
               end)

               Dugme(96, "Teletransportarse", function()
                    SardonHayvan:AdminIstek("git", {id = form.id})
               end)

               Dugme(130, "Centro aquí", function()
                    SardonHayvan:AdminIstek("konum", {id = form.id})
               end)

               Dugme(96, "Vaciar", function()
                    SardonHayvan:AdminIstek("temizle", {id = form.id})
               end)

               Dugme(80, "Borrar", function()
                    local id, ad = form.id, form.ad
                    N.Confirm("Borrar zona", ad .. ": se eliminará la zona y sus animales.", "Borrar", function()
                         secili = nil
                         form = nil
                         SardonHayvan:AdminIstek("sil", {id = id})
                    end, true)
               end, "danger")
          end

          -- üst şerit
          local x = 0
          N.Button(P, 0, 0, u(200), u(36), "Nueva zona aquí", function()
               local n = #(SardonHayvan.AdminVeri.bolgeler or {}) + 1
               bekleyenSecim = true
               SardonHayvan:AdminIstek("ekle", {ad = "Bölge " .. n, yaricap = 800, max = 1, yeniden = 120, turler = {"kurt"}})
          end, "primary")
          x = x + 208

          local goster = N.Button(P, u(x), 0, u(180), u(36), function()
               return SardonHayvan.Goster and "Ocultar zonas" or "Mostrar zonas"
          end, function()
               SardonHayvan.Goster = !SardonHayvan.Goster
          end)
          goster.NoCaps = true
          x = x + 188

          N.Button(P, u(x), 0, u(110), u(36), "Actualizar", function()
               SardonHayvan:AdminIstek("liste")
          end, "quiet")

          local sayac = vgui.Create("DPanel", P)
          sayac:SetPos(u(x + 120), 0)
          sayac:SetSize(u(ctx.w - x - 120), u(36))
          sayac.Paint = function(s, pw, ph)
               local v = SardonHayvan.AdminVeri
               N.Text("Haritada " .. (v.toplam or 0) .. " / " .. (v.globalMax or 0) .. " hayvan  ·  " .. #(v.bolgeler or {}) .. " bölge",
                    "small", pw, ph / 2, N.Clr.rowDesc, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
          end

          liste = N.VList(P, 0, u(ustH), u(LIST_W), u(ctx.h - ustH), {
               rowH = u(58),
               gapY = u(6),
               emptyText = "Aún no hay zonas.",
               onClick = function(b)
                    if (secili == b.id) then return end
                    secili = b.id
                    form = nil
                    DetayKur()
               end,
               paintRow = function(b, i, x, y, cw, ch, hovered)
                    local on = secili == b.id

                    N.Box(x, y, cw, ch, on and N.Clr.selRow or (hovered and N.Clr.hoverRow or N.Clr.toolBg))
                    N.Outline(x, y, cw, ch, on and N.Clr.gold or N.Clr.toolLine, 1)
                    N.Text(b.ad, "row", x + u(12), y + u(10), on and N.Clr.goldAccent or N.Clr.rowText)
                    N.Text("#" .. b.id .. "  ·  r " .. b.yaricap .. "  ·  " .. (b.canli or 0) .. "/" .. b.max .. " canlı  ·  " .. (b.oyuncu or 0) .. " jugadores",
                         "micro", x + u(12), y + u(32), N.Clr.rowDesc)

                    if ((b.canli or 0) > 0) then
                         N.Box(x + cw - u(14), y + u(14), u(6), u(6), N.Clr.ok)
                    end
               end
          })

          function ctx.HayvanYenile()
               local veri = SardonHayvan.AdminVeri.bolgeler or {}

               if (bekleyenSecim) then
                    bekleyenSecim = nil
                    local m
                    for _, b in ipairs(veri) do if (!m or b.id > m) then m = b.id end end
                    secili = m
                    form = nil
               end

               if (IsValid(liste)) then liste:SetItems(veri, true) end

               -- detay yalnızca seçim değişince kurulur (yazarken / sürüklerken bozulmasın);
               -- sayaçlar ve liste canlı veriden çiziliyor
               if (secili and !Bolge(secili)) then
                    secili = nil
                    form = nil
                    DetayKur()
               elseif (secili and (!form or form.id != secili)) then
                    DetayKur()
               end
          end

          ctx.SetHead({
               note = function()
                    local v = SardonHayvan.AdminVeri
                    return (v.toplam or 0) .. " ANIMALES  ·  " .. #(v.bolgeler or {}) .. " ZONAS"
               end
          })

          liste:SetItems(SardonHayvan.AdminVeri.bolgeler or {})
          DetayKur()
          SardonHayvan:AdminIstek("liste")
     end
}

ShineAdmin = ShineAdmin or {}
ShineAdmin.Pages = ShineAdmin.Pages or {}
ShineAdmin.Pages.hayvan = sayfa

-- konsoldan doğrudan bu sayfayı açar
concommand.Add("sardon_hayvan_admin", function()
     if (ShineAdmin and ShineAdmin.Open) then ShineAdmin:Open("hayvan") end
end)
