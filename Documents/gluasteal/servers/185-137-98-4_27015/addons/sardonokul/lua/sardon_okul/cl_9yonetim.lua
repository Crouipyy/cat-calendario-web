-- "addons\\sardonokul\\lua\\sardon_okul\\cl_9yonetim.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Shine Admin › Canlı Okul (istemci). Veri ve işlemler sv_9yonetim.lua ("SardonOkul.Yonetim").
*
*   Üstte durum kutuları; alt sekmeler: Koridordakiler (canlı öğrenciler) · İlişkiler (çevrimiçi karakterler ×
*   öğrenci) · Ayarlar ve maliyet. Görüntüleme admin, değişiklik süperadmin.
*   Açmak: Shine Admin › Sistemler › Canlı Okul ya da konsol "sardon_okul_admin".
*/
local K = SardonOkul

K.Yon = K.Yon or { sekme = "canli" }
local Y = K.Yon

local function Iste(islem, a)
     a = a or {}
     if a.uid == nil then a.uid = Y.uid end
     net.Start("SardonOkul.Yonetim")
     net.WriteString(islem or "yenile")
     net.WriteString(util.TableToJSON(a))
     net.SendToServer()
end

local TERCIH = { [0] = "cerrado", [1] = "poco", [2] = "normal" }
local DURUM = { dur = "quieto", yuru = "caminando", bekle = "esperando", konus = "hablando", takip = "acompañando", cekil = "retirándose", pusu = "en emboscada" }

local function Sure(sn)
     sn = math.floor(tonumber(sn) or 0)
     if sn < 60 then return sn .. " sn" end
     return math.floor(sn / 60) .. " dk " .. (sn % 60) .. " sn"
end

-- Türkçe sayı yazımı: ondalık virgül, binlik nokta
local function Ond(x, hane)
     return (string.gsub(string.format("%." .. (hane or 1) .. "f", tonumber(x) or 0), "%.", ","))
end
local function Binlik(n)
     return (string.gsub(string.Comma(math.floor(tonumber(n) or 0)), ",", "."))
end

local function Mikro(us)
     us = tonumber(us) or 0
     if us >= 1000 then return Ond(us / 1000, 2) .. " ms" end
     return string.format("%.0f µs", us)
end

local function HaneRenk(hane, N)
     local r = K.HaneRenk and K.HaneRenk[hane or ""]
     return r and Color(r[1], r[2], r[3]) or N.Clr.rowText
end

local function SayfaKaydet()
     if not (ShineAdmin and ShineAdmin.RegisterPage) then return false end
     ShineAdmin:RegisterPage("okul", {
          label = "Escuela en vivo",
          icon = "star",
          group = "systems",
          order = 7,
          title = "Escuela en vivo",
          subtitle = "NPC estudiantes en los pasillos, relaciones con jugadores, brújulas, techos y coste del servidor.",
          access = function(ply) return ply:IsAdmin() end,
          available = function() return SardonOkul ~= nil end,

          build = function(ctx)
               local N = ShineAdmin.GetN()
               local u = N.u
               local P = ctx.panel
               local W, H = ctx.w, ctx.h
               Y.panel = P
               Iste("yenile")

               local function V() return Y.veri end
               local function D() return Y.veri and Y.veri.durum end
               local function Yetki() return LocalPlayer():IsSuperAdmin() end

               /*
               *   üst kutular
               */
               local ust = vgui.Create("DPanel", P)
               ust:SetPos(0, 0)
               ust:SetSize(u(W), u(84))
               ust.Paint = function(_, w, h)
                    local d = D()
                    local kutular = {
                         { "En el pasillo", d and (d.canli .. " / " .. math.min(d.maks, d.tavan)) or "—", d and (d.acik and (d.oyuncu .. " jugadores en línea") or "SISTEMA DESACTIVADO") or "", d and not d.acik },
                         { "Escudo de carga", d and (d.kalkan and "ACTIVO" or "kapalı") or "—", d and ("intervalo de tick ×" .. Ond(d.yuk, 3) .. " · ticks tardíos %" .. Ond(d.gec * 100, 1)) or "", d and d.kalkan },
                         { "Ronda del director", d and d.tur and Mikro(d.tur.ort) or "—", d and d.tur and ("máximo en el último minuto " .. Mikro(d.tur.maks)) or "" },
                         { "Emboscadas · vigías", d and (d.pusu .. " · " .. d.gozcu) or "—", d and ((d.pusuAcik and "emboscadas activas" or "EMBOSCADAS DESACTIVADAS") .. " · total " .. d.pusuSay) or "", d and not d.pusuAcik },
                         { "Preferencia del jugador", d and (d.tercih[3] .. " · " .. d.tercih[2] .. " · " .. d.tercih[1]) or "—", "normal · poco · cerrado" },
                    }
                    local n = #kutular
                    local cw = (w - u(12) * (n - 1)) / n
                    for i, k in ipairs(kutular) do
                         local x = (i - 1) * (cw + u(12))
                         N.Box(x, 0, cw, h - u(8), N.Clr.toolBg)
                         N.Outline(x, 0, cw, h - u(8), N.Clr.toolLine, 1)
                         N.Box(x, u(12), u(2), h - u(32), k[4] and N.Clr.bad or N.Clr.gold)
                         N.TextSpaced(string.utf8upper(k[1]), "micro", x + u(16), u(10), N.Clr.thText, u(2))
                         N.Text(N.Clip(k[2], "count", cw - u(28)), "count", x + u(16), u(24), k[4] and N.Clr.bad or N.Clr.bigStat)
                         N.Text(N.Clip(k[3], "tiny", cw - u(28)), "tiny", x + u(16), u(58), N.Clr.rowDesc)
                    end
               end

               /*
               *   alt sekmeler
               */
               local govdeY = 144
               local govdeH = H - govdeY - 60
               local govde = {}
               local function Kok(ad)
                    local p = vgui.Create("DPanel", P)
                    p:SetPos(0, u(govdeY))
                    p:SetSize(u(W), u(govdeH))
                    p:SetPaintBackground(false)
                    govde[ad] = p
                    return p
               end
               local function SekmeAc(ad)
                    Y.sekme = ad
                    for k, p in pairs(govde) do
                         if IsValid(p) then p:SetVisible(k == ad) end
                    end
               end
               Y.SekmeAc = SekmeAc
               N.SubTabs(P, 0, u(92), u(W), {
                    { "canli", "EN EL PASILLO" }, { "iliski", "RELACIONES" }, { "bag", "VÍNCULO Y VENDEDORES" }, { "ayar", "AJUSTES Y COSTE" },
               }, function() return Y.sekme end, function(id) SekmeAc(id) end)

               /*
               *   1) Koridordakiler
               */
               local kokCanli = Kok("canli")
               local listeW = u(W)
               local hucreW = listeW - u(12)
               local SUT = { 0.012, 0.23, 0.37, 0.48, 0.60, 0.74 }
               local baslik = vgui.Create("DPanel", kokCanli)
               baslik:SetPos(0, 0)
               baslik:SetSize(listeW, u(30))
               baslik.Paint = function(_, w)
                    N.TableHead(0, 0, w, {
                         { "Estudiante", hucreW * SUT[1] }, { "Casa · año", hucreW * SUT[2] }, { "Estado", hucreW * SUT[3] }, { "Rol", hucreW * SUT[4] },
                         { "Para quién", hucreW * SUT[5] }, { "Quién ve · tiempo", hucreW * SUT[6] },
                    })
               end
               local canliListe = N.VList(kokCanli, 0, u(34), listeW, u(govdeH - 34), {
                    rowH = u(34), gapY = u(2),
                    emptyText = "Ahora no hay estudiantes materializados en el pasillo.",
                    paintRow = function(r, i, x, y, cw, ch, hovered, hx)
                         N.Box(x, y, cw, ch, hovered and N.Clr.hoverRow or N.Clr.toolBg)
                         local cy = y + ch / 2
                         N.Text(N.Clip(r.ad or "?", "strong", cw * 0.23), "strong", x + cw * SUT[1], cy, HaneRenk(r.hane, N), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text((K.HaneAd and K.HaneAd[r.hane] or r.hane or "") .. " · " .. tostring(r.yil or "?"), "small", x + cw * SUT[2], cy, N.Clr.rowDesc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(DURUM[r.durum] or r.durum or "", "small", x + cw * SUT[3], cy, r.durum == "pusu" and N.Clr.bad or N.Clr.rowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(N.Clip(r.rol or "", "small", cw * 0.13), "small", x + cw * SUT[4], cy, N.Clr.warn, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(N.Clip(r.icin or "", "small", cw * 0.13), "small", x + cw * SUT[5], cy, N.Clr.rowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         local son = (r.izleyen or 0) .. " · " .. Sure(r.yas)
                         -- üzerine gelince sağda GİT / KALDIR çıkar: kalan süre o zaman yazılmaz
                         if not hovered and r.kalan and r.kalan > 0 then son = son .. "  (quedan " .. Sure(r.kalan) .. ")" end
                         N.Text(son, "small", x + cw * SUT[6], cy, N.Clr.rowDesc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         if hovered then
                              local kaldir = hx and hx >= cw - u(84)
                              local git = hx and not kaldir and hx >= cw - u(150)
                              N.Text("IR", "smallb", x + cw - u(120), cy, git and N.Clr.goldAccent or N.Clr.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                              N.Text("QUITAR", "smallb", x + cw - u(44), cy, kaldir and N.Clr.bad or N.Clr.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                         end
                    end,
                    onClick = function(r, i, relX, relY, cw)
                         if relX >= cw - u(84) then
                              if not Yetki() then ctx.Flash("Solo el superadmin puede quitar estudiantes.") return end
                              Iste("kaldir", { id = r.id })
                         elseif relX >= cw - u(150) then
                              Iste("git", { id = r.id })
                         end
                    end,
               })

               /*
               *   2) İlişkiler: solda çevrimiçi karakterler, sağda seçilenin öğrencilerle ilişkisi
               */
               local kokIliski = Kok("iliski")
               local solW = math.floor(W * 0.34)
               local sagX = solW + 14
               local sagW = W - sagX
               local oyuncuListe = N.VList(kokIliski, 0, 0, u(solW), u(govdeH), {
                    rowH = u(46), gapY = u(2),
                    emptyText = "No hay personajes en línea.",
                    paintRow = function(r, i, x, y, cw, ch, hovered)
                         local secili = Y.uid == r.uid
                         N.Box(x, y, cw, ch, secili and N.Clr.selRow or (hovered and N.Clr.hoverRow or N.Clr.toolBg))
                         if secili then N.Box(x, y + u(6), u(2), ch - u(12), N.Clr.gold) end
                         N.Text(N.Clip(r.ad or "?", "strong", cw - u(90)), "strong", x + u(12), y + u(15), secili and N.Clr.goldAccent or N.Clr.rowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         local alt = r.dost .. " amigos · " .. r.hasim .. " enemistad"
                         if r.tercih ~= 2 then alt = alt .. " · aglomeración " .. (TERCIH[r.tercih] or "?") end
                         N.Text(N.Clip(alt, "small", cw - u(24)), "small", x + u(12), y + u(33), N.Clr.rowDesc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         if r.pusu then
                              N.Text("EN EMBOSCADA", "smallb", x + cw - u(10), y + u(15), N.Clr.bad, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                         elseif (r.enDusuk or 0) <= -60 then
                              N.Text(tostring(r.enDusuk), "smallb", x + cw - u(10), y + u(15), N.Clr.warn, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                         end
                    end,
                    onClick = function(r)
                         Y.uid = r.uid
                         Iste("yenile")
                    end,
               })

               local sagBas = vgui.Create("DPanel", kokIliski)
               sagBas:SetPos(u(sagX), 0)
               sagBas:SetSize(u(sagW), u(44))
               sagBas.Paint = function(_, w, h)
                    N.Box(0, 0, w, h, N.Clr.toolBg)
                    N.Outline(0, 0, w, h, N.Clr.toolLine, 1)
                    local il = V() and V().iliski
                    if not il or il.uid ~= Y.uid then
                         N.Text("Elige un personaje a la izquierda.", "body", u(14), h / 2, N.Clr.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         return
                    end
                    N.Text(N.Clip(il.ad or "?", "subhead", w * 0.4), "subhead", u(14), h / 2, N.Clr.goldAccent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    N.Text(#il.satir .. " relaciones · " .. il.hatira .. " recuerdos · " .. il.notlar .. " notas · karakter no " .. il.kar, "small", w * 0.42, h / 2, N.Clr.rowDesc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               end
               local hepsiniSil = N.Button(sagBas, u(sagW - 168), u(6), u(160), u(32), "Reiniciar todo", function()
                    local il = V() and V().iliski
                    if not il or il.uid ~= Y.uid then return end
                    N.Confirm("Reiniciar relaciones", il.ad .. " karakterinin bütün öğrencilerle se borran las relaciones con estudiantes (recuerdos y notas se mantienen). Silinmeden önce sunucuda data/sardon_okul/yedek altına yedeklenir.", "Reiniciar", function()
                         Iste("sifirla", { uid = il.uid })
                    end, true)
               end)
               hepsiniSil.Think = function(s)
                    local il = V() and V().iliski
                    s:SetEnabled(Yetki() and il ~= nil and il.uid == Y.uid and #il.satir > 0)
               end

               local hucre2 = u(sagW) - u(12)
               local SUT2 = { 0.015, 0.30, 0.47, 0.56 }
               local baslik2 = vgui.Create("DPanel", kokIliski)
               baslik2:SetPos(u(sagX), u(50))
               baslik2:SetSize(u(sagW), u(30))
               baslik2.Paint = function(_, w)
                    N.TableHead(0, 0, w, {
                         { "Estudiante", hucre2 * SUT2[1] }, { "Rango", hucre2 * SUT2[2] }, { "Puan", hucre2 * SUT2[3] }, { "Historial entre ellos", hucre2 * SUT2[4] },
                    })
               end
               local iliskiListe = N.VList(kokIliski, u(sagX), u(84), u(sagW), u(govdeH - 84), {
                    rowH = u(34), gapY = u(2),
                    emptyText = "Este personaje aún no tiene historial con nadie.",
                    paintRow = function(r, i, x, y, cw, ch, hovered, hx)
                         N.Box(x, y, cw, ch, hovered and N.Clr.hoverRow or N.Clr.toolBg)
                         local cy = y + ch / 2
                         local p = tonumber(r.p) or 0
                         local renk = p <= -20 and N.Clr.bad or (p >= 20 and N.Clr.ok or N.Clr.rowText)
                         N.Text(N.Clip(r.ad or "?", "strong", cw * 0.27), "strong", x + cw * SUT2[1], cy, HaneRenk(r.hane, N), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(K.KademeAd and K.KademeAd[r.k] or tostring(r.k), "small", x + cw * SUT2[2], cy, renk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text((p > 0 and "+" or (p < 0 and "−" or "")) .. string.format("%.0f", math.abs(p)), "smallb", x + cw * SUT2[3], cy, renk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         local hesap = {}
                         if (r.py or 0) > 0 then hesap[#hesap + 1] = r.py .. " victorias" end
                         if (r.nz or 0) > 0 then hesap[#hesap + 1] = r.nz .. " derrotas" end
                         if r.unvan then hesap[#hesap + 1] = r.unvan end
                         N.Text(N.Clip(table.concat(hesap, " · "), "small", cw * 0.44 - u(190)), "small", x + cw * SUT2[4], cy, N.Clr.rowDesc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         if hovered and Yetki() then
                              local b = hx and math.floor((cw - hx) / u(60)) or -1      -- 0 = sıfırla, 1 = +10, 2 = −10
                              N.Text("−10", "smallb", x + cw - u(150), cy, b == 2 and N.Clr.bad or N.Clr.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                              N.Text("+10", "smallb", x + cw - u(90), cy, b == 1 and N.Clr.ok or N.Clr.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                              N.Text("SIFIR", "smallb", x + cw - u(30), cy, b == 0 and N.Clr.goldAccent or N.Clr.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                         end
                    end,
                    onClick = function(r, i, relX, relY, cw)
                         if not Yetki() then return end
                         local b = math.floor((cw - relX) / u(60))
                         if b == 0 then
                              N.Confirm("Reiniciar relación", (r.ad or "?") .. " ile ilişki, victorias / derrotas kaydıyla birlikte silinir. Silinmeden önce yedeklenir.", "Reiniciar", function()
                                   Iste("sifirla", { id = r.id })
                              end, true)
                         elseif b == 1 then
                              Iste("puan", { id = r.id, fark = 10 })
                         elseif b == 2 then
                              Iste("puan", { id = r.id, fark = -10 })
                         end
                    end,
               })

               /*
               *   3) Ayarlar ve maliyet (içerik yüksekliği ~310: sıkı satırlar)
               */
               local kokAyar = Kok("ayar")
               local yarim = math.floor((W - 20) / 2)
               -- anahtar · değer satırı (N.Property'nin 22 px'lik sıkı hali); yükseklik döner
               local function Satir(x, y, w, anahtar, deger, renk)
                    N.Box(x, y, w, 1, N.Clr.propLine)
                    local cy = y + u(11)
                    N.Text(N.Clip(anahtar, "small", w * 0.42), "small", x, cy, N.Clr.propKey, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    N.Text(N.Clip(tostring(deger), "small", w * 0.57), "small", x + w, cy, renk or N.Clr.propVal, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    return u(22)
               end
               local function Anahtar(y, etiket, alan, aciklama)
                    N.Toggle(kokAyar, 0, u(y), u(yarim), u(46), etiket, function()
                         local d = D()
                         return d and d[alan == "acik" and "acik" or (alan .. "Acik")]
                    end, function(v)
                         if not Yetki() then ctx.Flash("Solo el superadmin puede cambiar este ajuste.") return end
                         Iste("ayar", { [alan] = v })
                    end, aciklama)
               end
               Anahtar(0, "Escuela en vivo", "acik", "Desactivada: todos vuelven al cuaderno y no renacen. Las relaciones no se borran.")
               Anahtar(48, "Emboscadas", "pusu", "Yeminli düşmanın kurduğu pusular. Kapalıyken süreç bekler, kayıt silinmez.")
               Anahtar(96, "Travesuras", "muzip", "Küs öğrencilerin hasarsız şakaları (bağcık, mürekkep, dans...).")
               local sessiz = false
               local kaydirici = N.Slider(kokAyar, 0, u(150), u(yarim), "Máximo de estudiantes a la vez (servidor)", 0, 24, 0, function()
                    local d = D()
                    return d and d.maks or 24
               end, function(v)
                    if sessiz then return end
                    v = math.Round(v)
                    timer.Create("SardonOkul.YonMaks", 0.7, 1, function()
                         if not LocalPlayer():IsSuperAdmin() then return end
                         Iste("ayar", { maks = v })
                    end)
               end)
               Y.MaksYaz = function(v)
                    if not IsValid(kaydirici) or not IsValid(kaydirici.Slider) or timer.Exists("SardonOkul.YonMaks") then return end
                    if kaydirici.Slider:IsEditing() then return end
                    sessiz = true
                    kaydirici.Slider:SetValue(v)
                    sessiz = false
               end

               local kural = vgui.Create("DPanel", kokAyar)
               kural:SetPos(0, u(212))
               kural:SetSize(u(yarim), u(govdeH - 212))
               kural.Paint = function(_, w, h)
                    local d = D()
                    if not d then return end
                    local y = u(4)
                    y = y + Satir(0, y, w, "Por jugador", "en çok " .. d.oyuncuBasi .. " öğrenci (pusu anında 5)")
                    y = y + Satir(0, y, w, "Regla de aglomeración", d.kalabalikMesafe .. " birimde " .. d.kalabalik .. "+ gerçek oyuncu varsa doğmaz")
                    y = y + Satir(0, y, w, "Director", Ond(d.turSn, 1) .. " sn'de bir tur · turda " .. d.turOyuncu .. " oyuncu · en çok 1 rota")
                    Satir(0, y, w, "Plantilla · nodos de ruta · hora escolar", d.kadro .. " · " .. d.dugum .. " · " .. string.format("%02d:%02d", math.floor(d.saat), math.floor((d.saat % 1) * 60)))
               end

               local maliyet = vgui.Create("DPanel", kokAyar)
               maliyet:SetPos(u(yarim + 20), 0)
               maliyet:SetSize(u(W - yarim - 20), u(govdeH))
               maliyet.Paint = function(_, w, h)
                    N.Box(0, 0, w, h, N.Clr.toolBg)
                    N.Outline(0, 0, w, h, N.Clr.toolLine, 1)
                    local d = D()
                    if not d then
                         N.Text("Esperando datos…", "body", u(14), u(14), N.Clr.faint)
                         return
                    end
                    local x, gw = u(14), w - u(28)
                    N.SectionLabel("Coste del servidor (nuestro Lua)", x, u(10), gw)
                    local y = u(28)
                    local function Kalem(ad, m, saniyede)
                         if not m then
                              y = y + Satir(x, y, gw, ad, "aún no se ejecutó", N.Clr.faint)
                              return 0
                         end
                         y = y + Satir(x, y, gw, ad, "ort " .. Mikro(m.ort) .. " · son dk en çok " .. Mikro(m.maks) .. " · " .. Binlik(m.say) .. " llamadas")
                         return (m.genel or 0) * saniyede
                    end
                    local top = Kalem("Ronda del director (2/s)", d.tur, 1 / math.max(d.turSn, 0.1))
                    top = top + Kalem("Temporizador de emboscadas (sürerken sn'de 4)", d.pusuM, d.pusu > 0 and 4 or 0)
                    Kalem("Comprobación de impacto de hechizo (atış başına)", d.buyu, 0)
                    -- tick 16: saniyede 1 000 000 µs'lik bütçe
                    y = y + Satir(x, y, gw, "Total por segundo", Mikro(top) .. "  (del presupuesto por segundo %" .. Ond(top / 10000, 3) .. " kadarı)", N.Clr.goldAccent)

                    y = y + u(10)
                    N.SectionLabel("Escudo de carga", x, y, gw)
                    y = y + u(18)
                    y = y + Satir(x, y, gw, "Intervalo de tick · ticks tardíos", "×" .. Ond(d.yuk, 3) .. " (eşik ×" .. Ond(d.yukOran, 2) .. ") · %" .. Ond(d.gec * 100, 1) .. " (eşik %" .. Ond(d.yukGec * 100, 0) .. ")",
                         (d.yuk > d.yukOran or d.gec > d.yukGec) and N.Clr.bad or nil)
                    y = y + Satir(x, y, gw, "Escudo", (d.kalkan and "AÇIK: nuevo nacimiento y emboscadas paradas" or "kapalı") .. " · açılıştan beri " .. d.kalkanSay .. " kez", d.kalkan and N.Clr.bad or nil)

                    y = y + u(10)
                    N.SectionLabel("Desde el arranque", x, y, gw)
                    y = y + u(18)
                    y = y + Satir(x, y, gw, "Nacimientos · retiradas · relevos · rutas · saludos", d.dogum .. " · " .. d.cekilme .. " · " .. (d.devir or 0) .. " · " .. Binlik(d.rota) .. " · " .. d.selam)
                    y = y + Satir(x, y, gw, "Última emboscada", tostring(d.sonPusu or "yok"))
                    Satir(x, y, gw, "Último error", tostring(d.sonHata or "yok"), d.sonHata and N.Clr.bad or nil)
               end

               /*
               *   4) Bağ ve satıcılar (sv_9satici.lua K.BagDurum): bugünün rafları, satıcı yerleri, doğum günleri, kurallar
               */
               local kokBag = Kok("bag")
               local bagP = vgui.Create("DPanel", kokBag)
               bagP:SetPos(0, 0)
               bagP:SetSize(u(W), u(govdeH))
               bagP.Paint = function(_, w, h)
                    local d = D()
                    local b = d and d.bag
                    if not istable(b) then
                         N.Text(d and "Bağ sistemi bu sunucu sürümünde yok." or "Esperando datos…", "body", u(14), u(14), N.Clr.faint)
                         return
                    end
                    local bosluk = u(20)
                    local sw = (w - bosluk * 2) / 3
                    local function Kutu(x)
                         N.Box(x, 0, sw, h, N.Clr.toolBg)
                         N.Outline(x, 0, sw, h, N.Clr.toolLine, 1)
                         return x + u(14), sw - u(28)
                    end
                    -- raflar
                    for i, st in ipairs({ { "balyumruk", "Balyumruk · şekerleme" }, { "zonko", "Zonko · şaka oyuncağı" } }) do
                         local x, gw = Kutu((i - 1) * (sw + bosluk))
                         local r = istable(b.raf) and b.raf[st[1]] or {}
                         N.SectionLabel(st[2] .. " · bugünün rafı", x, u(10), gw)
                         local y = u(28)
                         local fiyat = tostring(r.fiyat or "?") .. " Galleon" .. ((tonumber(r.paket) or 1) > 1 and (" · " .. r.paket .. " adetlik paket") or "")
                         y = y + Satir(x, y, gw, r.yer and "Satıcı yerinde · fiyat" or "Satıcı", r.yer and fiyat or ("YERLEŞMEDİ · sardon_okul_satici_koy " .. st[1]), (not r.yer) and N.Clr.bad or nil)
                         y = y + u(6)
                         for j, ad in ipairs(istable(r.mal) and r.mal or {}) do
                              y = y + Satir(x, y, gw, tostring(j), ad)
                         end
                         if #(istable(r.mal) and r.mal or {}) == 0 then y = y + Satir(x, y, gw, "Raf", "boş", N.Clr.bad) end
                         -- yardımlar (sv_6yardim.lua K.YardimDurum): solda sayaçlar, ortada kurallar
                         local yd = istable(b.yardim) and b.yardim or nil
                         if yd then
                              local ya = istable(yd.ayar) and yd.ayar or {}
                              y = y + u(10)
                              if i == 1 then
                                   N.SectionLabel("Yardımlar · açılıştan beri", x, y, gw)
                                   y = y + u(18)
                                   y = y + Satir(x, y, gw, "Armağan · hizmet · haber · savuşturma", tostring(yd.armagan or 0) .. " · " .. tostring(yd.hizmet or 0) .. " · " .. tostring(yd.bilgi or 0) .. " · " .. tostring(yd.savus or 0))
                                   Satir(x, y, gw, "Bekleyen kazan nöbeti · son hizmet", tostring(yd.nobet or 0) .. (yd.sar and "" or " (köprü yok)") .. " · " .. tostring(yd.sonHizmet or "yok"),
                                        (not yd.sar) and N.Clr.faint or nil)
                              else
                                   N.SectionLabel("Yardım kuralları", x, y, gw)
                                   y = y + u(18)
                                   y = y + Satir(x, y, gw, "Armağan · haber · hizmet · nadir", tostring(ya.armagan) .. " · " .. tostring(ya.bilgi) .. " · " .. tostring(ya.hizmet) .. " · " .. tostring(ya.nadir) .. " kalp")
                                   Satir(x, y, gw, "Hizmet · nadir · nöbet · koruma", "günde " .. tostring(ya.gunluk) .. " · haftada " .. tostring(ya.haftalik) .. " · +" .. tostring(ya.bonus) .. " · " .. tostring(math.floor((tonumber(ya.koruma) or 0) / 60)) .. " dk")
                              end
                         end
                    end
                    -- takvim + kurallar
                    local x, gw = Kutu(2 * (sw + bosluk))
                    N.SectionLabel("Bugün ayın " .. tostring(b.ay) .. ". günü", x, u(10), gw)
                    local y = u(28)
                    local function Adlar(t) return (istable(t) and #t > 0) and table.concat(t, ", ") or "yok" end
                    y = y + Satir(x, y, gw, "Doğum günü bugün", Adlar(b.dogum), (istable(b.dogum) and #b.dogum > 0) and N.Clr.goldAccent or nil)
                    y = y + Satir(x, y, gw, "Doğum günü yarın", Adlar(b.yarin))
                    -- olaylar (sv_7kutlama.lua K.OlayDurum): zincir adımı + düello + maç + kavga + kutlama + birlikte yemek
                    local ol = istable(b.olay) and b.olay or nil
                    local olay = ol and ((tonumber(ol.zincir) or 0) + (tonumber(ol.duello) or 0) + (tonumber(ol.mac) or 0) + (tonumber(ol.kavga) or 0) + (tonumber(ol.kutlama) or 0) + (tonumber(ol.yemek) or 0)) or nil
                    y = y + Satir(x, y, gw, olay and "Desde el arranque satış · hediye · olay" or "Desde el arranque satış · hediye",
                         tostring(b.satis or 0) .. " · " .. tostring(b.hediye or 0) .. (olay and (" · " .. olay) or ""))
                    -- kanon eşya kullanımı (sv_6esya.lua K.EsyaDurum)
                    local es = istable(b.esya) and b.esya or nil
                    if es then
                         y = y + Satir(x, y, gw, "Şekerleme · şaka (oyuncu · öğrenci)", tostring(es.seker or 0) .. " · " .. tostring(es.saka or 0) .. " (" .. tostring(es.oyuncu or 0) .. " · " .. tostring(es.ogrenci or 0) .. ")"
                              .. (es.acik == false and " · oyuncuya kapalı" or ""), es.acik == false and N.Clr.goldAccent or nil)
                    end
                    local a = istable(b.ayar) and b.ayar or {}
                    y = y + u(10)
                    N.SectionLabel("Kurallar", x, y, gw)
                    y = y + u(18)
                    y = y + Satir(x, y, gw, "Bayılır · sever · benzer · sıradan", "+" .. tostring(a.bayilir) .. " · +" .. tostring(a.sever) .. " · +" .. tostring(a.benzer) .. " · +" .. tostring(a.notr))
                    y = y + Satir(x, y, gw, "Sevmediği", tostring(a.sevmez))
                    y = y + Satir(x, y, gw, "Hediye · günlük kazanç tavanı", "günde 1 · +" .. tostring(a.gunluk) .. " (öğrenci başına)")
                    y = y + Satir(x, y, gw, "Doğum günü", "hediye ×" .. tostring(a.carpan) .. " · tavan +" .. tostring(a.tavan))
                    y = y + Satir(x, y, gw, "Bağ kapısı", tostring(a.kapi) .. " puan (kişisel rica bitmeden)")
                    y = y + Satir(x, y, gw, "Satıcıdan alım", "eşya başına günde " .. tostring(a.alim) .. " kez")
                    Satir(x, y, gw, "Kalp", "her 10 puan bir kalp · 10 kalp = Can dostu")
               end

               /*
               *   alt çubuk
               */
               local bar = N.StickyBar(P, 0, u(H - 52), u(W), function()
                    local d = D()
                    if not d then return "Esperando datos…" end
                    if not Yetki() then return "Modo lectura: solo superadmin puede cambiar." end
                    return "Quitar estudiantes o disolver emboscadas no escribe relaciones."
               end)
               local hepsi = N.Button(bar, u(W) - u(500), u(8), u(170), u(36), "Quitar todos", function()
                    N.Confirm("Quitar todos los estudiantes", "Koridordaki bütün öğrenciler deftere döner, süren pusular kayıt yazılmadan dağıtılır. Sistem açıksa yenileri kısa süre sonra doğar.", "Kaldır", function()
                         Iste("hepsi")
                    end, true)
               end)
               hepsi.Think = function(s) s:SetEnabled(Yetki()) end
               local dagit = N.Button(bar, u(W) - u(320), u(8), u(160), u(36), "Disolver emboscadas", function() Iste("dagit") end)
               dagit.Think = function(s) s:SetEnabled(Yetki()) end
               N.Button(bar, u(W) - u(150), u(8), u(150), u(36), "Actualizar", function() Iste("yenile") end, "primary")

               local function Yenile()
                    local v = V()
                    -- başka sayfaya geçildiyse (içerik paneli ortak) dokunma
                    if not v or not IsValid(ust) then return end
                    if IsValid(canliListe) then canliListe:SetItems(v.canli or {}, true) end
                    if IsValid(oyuncuListe) then oyuncuListe:SetItems(v.oyuncu or {}, true) end
                    if IsValid(iliskiListe) then
                         local il = v.iliski
                         iliskiListe:SetItems(il and il.uid == Y.uid and il.satir or {}, true)
                    end
                    if v.durum and Y.MaksYaz then Y.MaksYaz(v.durum.maks) end
                    ctx.SetHead({ count = v.durum and v.durum.canli or 0, note = "EN PASILLO" })
               end
               Y.Yenile = Yenile
               SekmeAc(Y.sekme or "canli")
               Yenile()

               -- sayfa açıkken 3 sn'de bir tazele (koridordakiler listesi canlı kalsın)
               timer.Create("SardonOkul.YonTazele", 3, 0, function()
                    if not IsValid(P) or not IsValid(ust) then timer.Remove("SardonOkul.YonTazele") return end
                    Iste("yenile")
               end)
               ctx.OnLeave = function() timer.Remove("SardonOkul.YonTazele") end

               return function() Iste("yenile") end
          end,
     })
     return true
end

if not SayfaKaydet() then
     hook.Add("InitPostEntity", "SardonOkul.Yonetim", function() timer.Simple(2, SayfaKaydet) end)
     timer.Simple(5, SayfaKaydet)
end

net.Receive("SardonOkul.Yonetim", function()
     local n = net.ReadUInt(16)
     local t = util.JSONToTable(util.Decompress(net.ReadData(n)) or "")
     if not istable(t) then return end
     Y.veri = t
     if Y.Yenile and IsValid(Y.panel) then Y.Yenile() end
end)

concommand.Add("sardon_okul_admin", function()
     if ShineAdmin and ShineAdmin.Open then ShineAdmin:Open("okul") end
end)
