-- "addons\\sardonekonomi\\lua\\sardon_ekonomi\\cl_6yonetim.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
--[[
     Sardon Ekonomi :: Shine Admin › Ekonomi sayfası (istemci). Veri sv_9yonetim.lua (SardonEko.Yonetim).
     Arz grafiği (14 gün), bugünkü kaynak/gider dökümü, Hazine, tüccar talebi, en zenginler, tavan/vergi ayarı.
]]

SardonEkonomi = SardonEkonomi or {}
local E = SardonEkonomi

local function Iste(islem, a)
     net.Start("SardonEko.Yonetim")
          net.WriteString(islem or "yenile")
          net.WriteTable(a or {})
     net.SendToServer()
end

local function Sayi(n) return string.Comma(math.floor(tonumber(n) or 0)) end

local function SayfaKaydet()
     if not (ShineAdmin and ShineAdmin.RegisterPage) then return false end
     ShineAdmin:RegisterPage("ekonomi", {
          label = "Economía",
          icon = "star",
          group = "systems",
          order = 5,
          title = "Economía",
          subtitle = "Oferta de galeones, ingresos/gastos diarios, Tesoro, demanda de comerciantes y ajustes.",
          access = function(ply) return ply:IsAdmin() end,
          available = function() return SardonEkonomi ~= nil end,

          build = function(ctx)
               local N = ShineAdmin.GetN()
               local u = N.u
               local P = ctx.panel
               local W, H = ctx.w, ctx.h
               E.YonetimPanel = P
               Iste("yenile")

               local function V() return E.YonetimVeri end

               -- üst kutular
               local ust = vgui.Create("DPanel", P)
               ust:SetPos(0, 0)
               ust:SetSize(u(W), u(84))
               ust.Paint = function(_, w, h)
                    local v = V()
                    local son = v and v.gunluk[#v.gunluk]
                    local fark = 0
                    for _, r in ipairs(v and v.bugun or {}) do fark = fark + r.giris - r.cikis end
                    local kutular = {
                         {"Oferta (inicio día)", son and Sayi(son.cep + son.banka) .. " G" or "—"},
                         {"Tesorería", v and Sayi(v.hazine) .. " G" or "—"},
                         {"Neto de hoy", v and ((fark >= 0 and "+" or "") .. Sayi(fark) .. " G") or "—"},
                         {"Anuncios · contratos · aplazado", v and (v.ilan .. " · " .. v.sozlesme .. " · " .. Sayi(v.alacak) .. " G") or "—"},
                    }
                    local cw = (w - u(12) * 3) / 4
                    for i, k in ipairs(kutular) do
                         local x = (i - 1) * (cw + u(12))
                         N.Box(x, 0, cw, h - u(8), N.Clr.toolBg)
                         N.Outline(x, 0, cw, h - u(8), N.Clr.toolLine, 1)
                         N.Box(x, u(12), u(2), h - u(32), N.Clr.gold)
                         N.TextSpaced(string.utf8upper(k[1]), "micro", x + u(16), u(14), N.Clr.thText, u(2))
                         N.Text(N.Clip(k[2], "count", cw - u(28)), "count", x + u(16), u(32), N.Clr.bigStat)
                    end
               end

               -- arz grafiği
               local grafik = vgui.Create("DPanel", P)
               grafik:SetPos(0, u(94))
               grafik:SetSize(u(W), u(150))
               grafik.Paint = function(_, w, h)
                    N.Box(0, 0, w, h, N.Clr.toolBg)
                    N.Outline(0, 0, w, h, N.Clr.toolLine, 1)
                    N.TextSpaced("OFERTA (BOLSILLO + BANCO), ÚLTIMOS 14 DÍAS", "micro", u(14), u(10), N.Clr.thText, u(2))
                    local g = V() and V().gunluk or {}
                    if #g == 0 then return end
                    local enCok = 1
                    for _, r in ipairs(g) do enCok = math.max(enCok, r.cep + r.banka) end
                    local bw = (w - u(28)) / 14
                    for i, r in ipairs(g) do
                         local oran = (r.cep + r.banka) / enCok
                         local bh = math.max(u(2), (h - u(60)) * oran)
                         local x = u(14) + (i - 1) * bw
                         N.Box(x + u(3), h - u(24) - bh, bw - u(6), bh, N.Clr.gold)
                         N.Text(string.sub(r.gun, 6), "tiny", x + u(3), h - u(20), N.Clr.rowDesc)
                    end
               end

               -- bugünkü döküm
               local solW = (W - 12) * 0.55
               local listeY = 256
               local liste = N.VList(P, 0, u(listeY), u(solW), u(H - listeY - 64), {
                    rowH = u(40),
                    paintRow = function(r, i, x, y, cw, ch, hovered)
                         N.Box(x, y, cw, ch, hovered and N.Clr.btnLine or N.Clr.toolBg)
                         N.Text(N.Clip(r.kaynak .. "  (" .. r.hesap .. ")", "tiny", cw * 0.55), "tiny", x + u(12), y + u(12), N.Clr.thText)
                         N.Text("+" .. Sayi(r.giris), "tiny", x + cw * 0.6, y + u(12), N.Clr.ok)
                         N.Text("-" .. Sayi(r.cikis), "tiny", x + cw * 0.8, y + u(12), N.Clr.rowDesc)
                    end
               })

               -- sağ: talep + zenginler
               local sag = vgui.Create("DPanel", P)
               sag:SetPos(u(solW + 12), u(listeY))
               sag:SetSize(u(W - solW - 12), u(H - listeY - 64))
               sag.Paint = function(_, w, h)
                    local v = V()
                    N.Box(0, 0, w, h, N.Clr.toolBg)
                    N.Outline(0, 0, w, h, N.Clr.toolLine, 1)
                    N.TextSpaced("DEMANDA COMERCIANTES (HOY)", "micro", u(12), u(10), N.Clr.thText, u(2))
                    local y = u(30)
                    for i, t in ipairs(v and v.talep or {}) do
                         if i > 7 then break end
                         N.Text(N.Clip(t.ad, "tiny", w * 0.55), "tiny", u(12), y, N.Clr.thText)
                         N.Text(t.adet .. " uds · %" .. t.oran, "tiny", w * 0.62, y, t.oran >= 80 and N.Clr.ok or N.Clr.rowDesc)
                         y = y + u(20)
                    end
                    y = math.max(y, u(30) + u(20) * 2) + u(14)
                    N.TextSpaced("MÁS RICOS (BOLSILLO + BANCO)", "micro", u(12), y, N.Clr.thText, u(2))
                    y = y + u(20)
                    for i, z in ipairs(v and v.zengin or {}) do
                         if y > h - u(20) then break end
                         N.Text(i .. ". " .. N.Clip(z.ad or "?", "tiny", w * 0.5), "tiny", u(12), y, N.Clr.thText)
                         N.Text(Sayi(z.cep + z.banka) .. " G", "tiny", w * 0.62, y, N.Clr.gold)
                         y = y + u(20)
                    end
               end

               -- ayarlar (süperadmin)
               local bar = N.StickyBar(P, 0, u(H - 52), u(W), function()
                    local a = V() and V().ayar
                    if not a then return "Esperando datos…" end
                    return string.format("Techo %d G · impuesto %%%d · muerte %%%d (exento bajo niv. %d)", a.tavan, math.floor(a.vergi * 100 + 0.5), math.floor(a.olumOran * 100 + 0.5), a.olumMuafSeviye)
               end)
               local tavan = vgui.Create("DTextEntry", bar)
               tavan:SetPos(u(W) - u(470), u(10))
               tavan:SetSize(u(80), u(32))
               tavan:SetNumeric(true)
               tavan:SetPlaceholderText("techo")
               local vergi = vgui.Create("DTextEntry", bar)
               vergi:SetPos(u(W) - u(380), u(10))
               vergi:SetSize(u(80), u(32))
               vergi:SetNumeric(true)
               vergi:SetPlaceholderText("imp. %")
               local kaydet = N.Button(bar, u(W) - u(290), u(8), u(130), u(36), "Guardar", function()
                    local a = {}
                    if tonumber(tavan:GetValue()) then a.tavan = tonumber(tavan:GetValue()) end
                    if tonumber(vergi:GetValue()) then a.vergi = tonumber(vergi:GetValue()) / 100 end
                    Iste("ayar", a)
                    ctx.Flash("Ajustes de economía enviados.")
               end, "primary")
               kaydet.Think = function(s) s:SetEnabled(LocalPlayer():IsSuperAdmin()) end
               N.Button(bar, u(W) - u(150), u(8), u(150), u(36), "Actualizar", function() Iste("yenile") end)

               local function Yenile()
                    local v = V()
                    if v and IsValid(liste) and liste.SetItems then liste:SetItems(v.bugun or {}) end
                    if v then ctx.SetHead({count = #(v.bugun or {}), note = "FUENTE"}) end
               end
               E.YonetimYenile = Yenile
               Yenile()
               return function() Iste("yenile") end
          end
     })
     return true
end

if not SayfaKaydet() then
     hook.Add("InitPostEntity", "SardonEkonomi.Yonetim", function() timer.Simple(2, SayfaKaydet) end)
end

net.Receive("SardonEko.Yonetim", function()
     E.YonetimVeri = net.ReadTable()
     if E.YonetimYenile and IsValid(E.YonetimPanel) then E.YonetimYenile() end
end)
