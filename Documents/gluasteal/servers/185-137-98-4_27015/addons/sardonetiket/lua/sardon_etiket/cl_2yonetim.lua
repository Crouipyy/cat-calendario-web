-- "addons\\sardonetiket\\lua\\sardon_etiket\\cl_2yonetim.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Sardon Etiket — Shine Admin › Discord Etiketi sayfası (istemci). Veri sv_6yonetim (E.YonetimIslem).
*   Özet kutuları, ayarlar (açık/kapalı, SC/saat, saat uzunluğu, AFK, yoklama aralığı), çevrimiçi oyuncular.
*/
SardonEtiket = SardonEtiket or {}
local E = SardonEtiket
local OP = E.OP

local DURUM_RENK

local function Kaydet()
     if not (ShineAdmin and ShineAdmin.RegisterPage and ShineAdmin.GetN) then return false end
     if ShineAdmin.Access then ShineAdmin.Access.etiket = function(p) return E.Yonetici(p) end end
     ShineAdmin:RegisterPage("etiket", {
          label = "Etiqueta de Discord",
          icon = "star",
          group = "systems",
          order = 47,
          title = "Etiqueta de Discord (SHNE)",
          subtitle = "ShineCoin por hora activa a jugadores con la etiqueta SHNE en Discord; ajustes y estados en línea.",
          access = function(p) return E.Yonetici(p) end,
          build = function(ctx)
               local N = ShineAdmin.GetN()
               local u = N.u
               local P, W, H = ctx.panel, ctx.w, ctx.h
               DURUM_RENK = DURUM_RENK or {
                    etiket = N.Clr.ok, etiket_yok = N.Clr.rowDesc, bagli_degil = N.Clr.faint,
                    sunucuda_degil = N.Clr.warn, cakisma = N.Clr.warn, hata = N.Clr.warn,
               }
               E.YonetimPanel = P
               E.Iste(OP.Y_ISTE)
               local function V() return E.YVeri end

               -- özet kutuları
               local ust = vgui.Create("DPanel", P)
               ust:SetPos(0, 0)
               ust:SetSize(u(W), u(84))
               ust.Paint = function(_, w, h)
                    local v = V()
                    local o = v and v.ozet
                    local a = v and v.ayar
                    local kutular = {
                         { "Bugün", o and (o.gunKisi .. " kişi · " .. o.gunSc .. " SC") or "—" },
                         { "Son 7 gün", o and (o.haftaSc .. " SC" .. (o.haftaHata > 0 and (" · " .. o.haftaHata .. " hata") or "")) or "—" },
                         { "Tüm zamanlar", o and (o.topKisi .. " kişi · " .. o.topSc .. " SC") or "—" },
                         { "Durum", a and ((a.acik and "Açık" or "KAPALI") .. " · kuyruk " .. (v.kuyruk or 0)) or "—" },
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

               -- ayarlar
               local ayarY = 96
               local ayarlar = vgui.Create("DPanel", P)
               ayarlar:SetPos(0, u(ayarY))
               ayarlar:SetSize(u(W), u(124))
               ayarlar.Paint = function(_, w, h)
                    N.Box(0, 0, w, h, N.Clr.toolBg)
                    N.Outline(0, 0, w, h, N.Clr.toolLine, 1)
                    N.TextSpaced("AYARLAR", "micro", u(14), u(10), N.Clr.thText, u(2))
               end
               local taslak = {}
               N.Toggle(ayarlar, u(14), u(30), u(300), u(44), "Sistem açık",
                    function()
                         if taslak.acik ~= nil then return taslak.acik end
                         local v = V()
                         return v and v.ayar and v.ayar.acik
                    end,
                    function(yeni) taslak.acik = yeni end,
                    "Kapalıyken yoklama ve sayaç durur")
               local alanlar = {
                    { "scSaat", "SC / dönem" }, { "dkSaat", "Dönem (aktif dk)" }, { "afkDk", "AFK eşiği (dk)" }, { "yoklaDk", "Yoklama (dk)" },
               }
               local girisler = {}
               for i, a in ipairs(alanlar) do
                    local x = 340 + (i - 1) * 150
                    local lbl = vgui.Create("DPanel", ayarlar)
                    lbl:SetPos(u(x), u(28))
                    lbl:SetSize(u(140), u(18))
                    lbl.Paint = function(_, w, h) N.Text(a[2], "tiny", 0, 0, N.Clr.rowDesc) end
                    local _, e = N.PlainEntry(ayarlar, u(x), u(48), u(130), u(34), "")
                    e:SetNumeric(true)
                    girisler[a[1]] = e
               end
               local function Doldur()
                    local v = V()
                    if not (v and v.ayar) then return end
                    for k, e in pairs(girisler) do
                         if IsValid(e) and not e:HasFocus() then e:SetValue(tostring(v.ayar[k] or "")) end
                    end
               end
               local kaydet = N.Button(ayarlar, u(W) - u(300), u(44), u(140), u(40), "Kaydet", function()
                    local t = { acik = taslak.acik }
                    for k, e in pairs(girisler) do
                         local n = tonumber(e:GetValue())
                         if n then t[k] = n end
                    end
                    taslak = {}
                    E.Iste(OP.Y_AYAR, t)
                    ctx.Flash("Etiket ayarları gönderildi.")
               end, "primary")
               kaydet.Think = function(s) s:SetEnabled(E.Yonetici(LocalPlayer())) end
               N.Button(ayarlar, u(W) - u(150), u(44), u(136), u(40), "Herkesi yokla", function()
                    E.Iste(OP.Y_YOKLA)
                    ctx.Flash("Çevrimiçi herkes yoklama kuyruğuna alındı.")
               end)

               -- oyuncular
               local listeY = ayarY + 136
               local baslik = vgui.Create("DPanel", P)
               baslik:SetPos(0, u(listeY))
               baslik:SetSize(u(W), u(26))
               local SUT = { 0.0, 0.26, 0.47, 0.67, 0.78, 0.89 }
               local SUT_AD = { "Oyuncu", "Discord", "Durum", "Dönem", "Bugün", "Toplam" }
               baslik.Paint = function(_, w, h)
                    for i, ad in ipairs(SUT_AD) do
                         N.TextSpaced(string.utf8upper(ad), "micro", u(12) + (w - u(24)) * SUT[i], u(6), N.Clr.thText, u(1))
                    end
               end
               local liste = N.VList(P, 0, u(listeY + 28), u(W), u(H - listeY - 28), {
                    rowH = u(40),
                    paintRow = function(r, i, x, y, cw, ch, hovered)
                         N.Box(x, y, cw, ch, hovered and N.Clr.btnLine or N.Clr.toolBg)
                         local function X(k) return x + u(12) + (cw - u(24)) * SUT[k] end
                         local sw = (cw - u(24)) * 0.2
                         N.Text(N.Clip(r.ad or "?", "tiny", sw), "tiny", X(1), y + u(12), N.Clr.thText)
                         N.Text(N.Clip(r.dad or r.discord or "—", "tiny", sw), "tiny", X(2), y + u(12), N.Clr.rowDesc)
                         local dm = E.DurumAd[r.durum] or r.durum or "?"
                         if r.durum == "etiket" and r.neden then dm = dm .. " (" .. r.neden .. ")" end
                         if r.diger then dm = dm .. " · " .. r.diger end
                         N.Text(N.Clip(dm, "tiny", sw), "tiny", X(3), y + u(12), DURUM_RENK[r.durum] or N.Clr.rowDesc)
                         N.Text((r.dk or 0) .. " dk", "tiny", X(4), y + u(12), N.Clr.thText)
                         N.Text((r.gunSc or 0) .. " SC", "tiny", X(5), y + u(12), N.Clr.gold)
                         N.Text((r.topSc or 0) .. " SC", "tiny", X(6), y + u(12), N.Clr.gold)
                    end,
               })

               local function Yenile()
                    local v = V()
                    Doldur()
                    if v and IsValid(liste) and liste.SetItems then liste:SetItems(v.oyuncular or {}, true) end
                    if v and ctx.SetHead then
                         local n = 0
                         for _, r in ipairs(v.oyuncular or {}) do if r.durum == "etiket" then n = n + 1 end end
                         ctx.SetHead({ count = n, note = "ETİKETLİ" })
                    end
               end
               E.YYenile = Yenile
               Yenile()
               return function() E.Iste(OP.Y_ISTE) end
          end,
     })
     return true
end

if not Kaydet() then
     timer.Create("SardonEtiket.Shine", 2, 30, function() if Kaydet() then timer.Remove("SardonEtiket.Shine") end end)
end
