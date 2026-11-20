-- "addons\\sardoncigirtkan\\lua\\sardon_cigirtkan\\cl_6admin.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Çığırtkan :: Shine Admin sayfası ("cigirtkan").
--
-- Sol: yoldaki / havadaki çığırtkanlar (tıkla: yok et) ve son gönderimler. Sağ: toplu çığırtkan kuralları
-- (gönderen faction/sınıf -> hedef; tıkla: sil, "Añadir regla" ile yenisi) ve gönderme yasakları.
-- Sesin kendisi burada yok: sunucuda yalnızca zarf yok olana dek RAM'de durur; kalıcı kopyası
-- Discord kaydındaki MP3 ekidir.
local C = SardonCigirtkan

C.AdminVeri = C.AdminVeri or {ucan = {}, yasak = {}, son = {}, kurallar = {}}

function C.AdminIstek(islem, veri)
     net.Start("SardonCigirtkan.Admin")
          net.WriteString(islem)
          net.WriteTable(veri or {})
     net.SendToServer()
end

net.Receive("SardonCigirtkan.AdminListe", function()
     C.AdminVeri = net.ReadTable()
     local ctx = ShineAdmin and ShineAdmin.ActiveCtx and ShineAdmin:ActiveCtx("cigirtkan")
     if ctx and ctx.CigirtkanYenile then ctx.CigirtkanYenile() end
end)

local DURUM_AD = {ucus = "En lechuza", [1] = "Planeando", [2] = "Esperando apertura", [3] = "Gritando", [4] = "Preguntando de nuevo", [5] = "Quemándose"}

local function Zaman(t)
     return os.date("%d.%m %H:%M", tonumber(t) or 0)
end

-- Kural seçenekleri (Helix tabloları istemcide de var)
local function Secenekler(hedefMi)
     local t = {}
     if hedefMi then
          t[#t + 1] = {tur = "kendi", id = "", ad = "Kendi faction'ı", alt = "Gönderen hangi faction'daysa (ör. sınıf başkanının kendi hanesi)"}
     end
     local f = {}
     for id, fac in pairs(ix.faction.teams) do
          f[#f + 1] = {tur = "faction", id = id, ad = fac.name or id, alt = "Faction" .. (isstring(fac.category) and ("  ·  " .. fac.category) or "")}
     end
     table.sort(f, function(a, b) return a.ad < b.ad end)
     local c = {}
     for _, cl in pairs(ix.class.list) do
          if cl.uniqueID then
               local fac = ix.faction.indices[cl.faction]
               c[#c + 1] = {tur = "class", id = cl.uniqueID, ad = cl.name or cl.uniqueID, alt = "Sınıf  ·  " .. (fac and fac.name or "?"), fad = fac and fac.name or ""}
          end
     end
     table.sort(c, function(a, b)
          if a.fad ~= b.fad then return a.fad < b.fad end
          return a.ad < b.ad
     end)
     for _, x in ipairs(f) do t[#t + 1] = x end
     for _, x in ipairs(c) do t[#t + 1] = x end
     return t
end

local LIST_W, GAP, UST_H = 470, 16, 48

local sayfa = {
     id = "cigirtkan",
     label = "Gritón",
     icon = "mic",
     group = "magic",
     order = 48,
     title = "Gritón",
     subtitle = "Gritones en ruta, reglas masivas, prohibiciones y últimos envíos. El audio no se guarda en el servidor; la prueba es el MP3 adjunto en Discord.",
     access = "superadmin",
     available = function() return SardonCigirtkan ~= nil end,

     build = function(ctx)
          local N = ShineAdmin.GetN()
          local u = N.u
          local S = ctx.panel
          local ucan, son, kurallar, yasak
          local ortu

          local function Baslik(ust, x, y, w, yazi)
               local b = vgui.Create("DPanel", ust)
               b:SetPos(x, y)
               b:SetSize(w, u(24))
               b.Paint = function(_, pw, ph)
                    N.Text(yazi, "tiny", 0, ph / 2, N.Clr.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               end
          end

          -- Kural ekleme örtüsü: solda gönderen, sağda hedef
          local function KuralEkleAc()
               if IsValid(ortu) then ortu:Remove() end
               local secG, secH
               ortu = vgui.Create("DPanel", S)
               ortu:SetPos(0, 0)
               ortu:SetSize(u(ctx.w), u(ctx.h))
               ortu.Paint = function(_, pw, ph)
                    N.Box(0, 0, pw, ph, N.Clr.toolBg)
                    N.Outline(0, 0, pw, ph, N.Clr.toolLine, 1)
                    N.Text("NUEVA REGLA DE GRITÓN MASIVO", "tiny", u(16), u(14), N.Clr.gold)
                    N.Text((secG and secG.ad or "elige emisor") .. "   →   " .. (secH and secH.ad or "elige destino"), "row", u(16), u(34),
                         (secG and secH) and N.Clr.goldAccent or N.Clr.rowDesc)
               end
               local yariW = math.floor((ctx.w - 16 * 3) / 2)
               local listeH = ctx.h - 76 - 60
               local function Liste(x, baslik, hedefMi)
                    Baslik(ortu, u(x), u(70), u(yariW), baslik)
                    local l = N.VList(ortu, u(x), u(98), u(yariW), u(listeH - 22), {
                         rowH = u(44),
                         gapY = u(4),
                         onClick = function(s)
                              if hedefMi then secH = s else secG = s end
                         end,
                         paintRow = function(s, i, rx, ry, cw, ch, hovered)
                              local on = (hedefMi and secH or secG) == s
                              N.Box(rx, ry, cw, ch, on and N.Clr.selRow or (hovered and N.Clr.hoverRow or N.Clr.toolBg))
                              N.Outline(rx, ry, cw, ch, on and N.Clr.gold or N.Clr.toolLine, 1)
                              N.Text(s.ad, "small", rx + u(12), ry + u(6), on and N.Clr.goldAccent or N.Clr.rowText)
                              N.Text(s.alt, "micro", rx + u(12), ry + u(25), N.Clr.rowDesc)
                         end
                    })
                    l:SetItems(Secenekler(hedefMi))
               end
               Liste(16, "EMISOR (todos en esta facción o clase pueden enviar)", false)
               Liste(32 + yariW, "DESTINO (va a todos los miembros en línea)", true)
               N.Button(ortu, u(ctx.w - 16 - 150), u(ctx.h - 50), u(150), u(36), "Añadir regla", function()
                    if not secG or not secH then return end
                    C.AdminIstek("kuralEkle", {gTur = secG.tur, gId = secG.id, hTur = secH.tur, hId = secH.id})
                    ortu:Remove()
               end)
               N.Button(ortu, u(ctx.w - 16 - 150 - 8 - 120), u(ctx.h - 50), u(120), u(36), "Cancelar", function()
                    ortu:Remove()
               end, "quiet")
          end

          local x = 0
          local function Ust(w, yazi, fn, stil)
               N.Button(S, u(x), 0, u(w), u(36), yazi, fn, stil)
               x = x + w + 8
          end
          Ust(110, "Actualizar", function() C.AdminIstek("liste") end, "quiet")
          Ust(230, "Dame un gritón vacío", function() C.AdminIstek("ver") end)
          Ust(150, "Añadir regla", KuralEkleAc)
          Ust(230, "Prohibir a quien miro", function() C.AdminIstek("yasakBak") end, "danger")

          -- sol sütun
          local solH = ctx.h - UST_H
          local ucanH = math.floor(solH * 0.45)
          Baslik(S, 0, u(UST_H), u(LIST_W), "EN RUTA (clic: destruir)")
          ucan = N.VList(S, 0, u(UST_H + 28), u(LIST_W), u(ucanH - 28), {
               rowH = u(54),
               gapY = u(6),
               emptyText = "No hay gritones en ruta.",
               onClick = function(f)
                    N.Confirm("Destruir gritón", (f.gonderen or "?") .. " → " .. (f.alici or "?") .. " el gritón arderá al instante, se borrará el audio.", "Destruir", function()
                         C.AdminIstek("yokEt", {id = f.id})
                    end, true)
               end,
               paintRow = function(f, i, rx, ry, cw, ch, hovered)
                    N.Box(rx, ry, cw, ch, hovered and N.Clr.hoverRow or N.Clr.toolBg)
                    N.Outline(rx, ry, cw, ch, N.Clr.toolLine, 1)
                    N.Text((f.gonderen or "?") .. "  →  " .. (f.alici or "?"), "row", rx + u(12), ry + u(8), N.Clr.rowText)
                    N.Text((DURUM_AD[f.durum] or tostring(f.durum)) .. "  ·  " .. C.SureYazi(f.sure) .. (f.anonim and "  ·  anonim" or ""),
                         "micro", rx + u(12), ry + u(30), N.Clr.rowDesc)
               end
          })
          Baslik(S, 0, u(UST_H + ucanH + 8), u(LIST_W), "ÚLTIMOS ENVÍOS")
          son = N.VList(S, 0, u(UST_H + ucanH + 36), u(LIST_W), u(solH - ucanH - 36), {
               rowH = u(44),
               gapY = u(4),
               emptyText = "Aún no hay registros.",
               paintRow = function(s, i, rx, ry, cw, ch, hovered)
                    N.Box(rx, ry, cw, ch, N.Clr.toolBg)
                    N.Outline(rx, ry, cw, ch, N.Clr.toolLine, 1)
                    N.Text((s.gonderen or "?") .. "  →  " .. (s.alici or "?"), "small", rx + u(12), ry + u(6), N.Clr.rowText)
                    N.Text(Zaman(s.zaman) .. "  ·  " .. (s.olay or "") .. "  ·  " .. C.SureYazi(s.sure) .. ((s.anonim == 1 or s.anonim == "1") and "  ·  anonim" or ""), "micro", rx + u(12), ry + u(25), N.Clr.rowDesc)
               end
          })

          -- sağ sütun
          local sagX = LIST_W + GAP
          local sagW = ctx.w - sagX
          local kuralH = math.floor(solH * 0.58)
          Baslik(S, u(sagX), u(UST_H), u(sagW), "REGLAS DE GRITÓN MASIVO  (clic: borrar · sin regla solo superadmin envía a todos)")
          kurallar = N.VList(S, u(sagX), u(UST_H + 28), u(sagW), u(kuralH - 28), {
               rowH = u(44),
               gapY = u(4),
               emptyText = "Sin reglas: solo superadmin puede enviar en masa.",
               onClick = function(k)
                    N.Confirm("Borrar regla", k.gonderen .. " → " .. k.hedef, "Borrar", function()
                         C.AdminIstek("kuralSil", {id = k.id})
                    end, true)
               end,
               paintRow = function(k, i, rx, ry, cw, ch, hovered)
                    N.Box(rx, ry, cw, ch, hovered and N.Clr.hoverRow or N.Clr.toolBg)
                    N.Outline(rx, ry, cw, ch, N.Clr.toolLine, 1)
                    N.Text(k.gonderen .. "   →   " .. k.hedef, "small", rx + u(12), ry + u(6), N.Clr.rowText)
                    N.Text((k.gTur == "class" and "sınıf" or "faction") .. " → " .. (k.hTur == "kendi" and "gönderenin kendi faction'ı" or (k.hTur == "class" and "sınıf" or "faction")),
                         "micro", rx + u(12), ry + u(25), N.Clr.rowDesc)
               end
          })
          Baslik(S, u(sagX), u(UST_H + kuralH + 8), u(sagW), "PROHIBIDOS DE ENVIAR  (tıkla: quitar prohibición)")
          yasak = N.VList(S, u(sagX), u(UST_H + kuralH + 36), u(sagW), u(solH - kuralH - 36), {
               rowH = u(44),
               gapY = u(4),
               emptyText = "Nadie prohibido.",
               onClick = function(y)
                    C.AdminIstek("yasakKaldir", {sid = y.sid})
               end,
               paintRow = function(y, i, rx, ry, cw, ch, hovered)
                    N.Box(rx, ry, cw, ch, hovered and N.Clr.hoverRow or N.Clr.toolBg)
                    N.Outline(rx, ry, cw, ch, N.Clr.toolLine, 1)
                    N.Text((y.ad or y.sid) .. "  ·  " .. y.sid, "small", rx + u(12), ry + u(6), N.Clr.rowText)
                    N.Text("yasaklayan " .. (y.kim or "?") .. "  ·  " .. Zaman(y.zaman), "micro", rx + u(12), ry + u(25), N.Clr.rowDesc)
               end
          })

          function ctx.CigirtkanYenile()
               if IsValid(ucan) then ucan:SetItems(C.AdminVeri.ucan or {}, true) end
               if IsValid(son) then son:SetItems(C.AdminVeri.son or {}, true) end
               if IsValid(kurallar) then kurallar:SetItems(C.AdminVeri.kurallar or {}, true) end
               if IsValid(yasak) then yasak:SetItems(C.AdminVeri.yasak or {}, true) end
          end

          ctx.SetHead({
               note = function() return #(C.AdminVeri.ucan or {}) .. " YOLDA  ·  " .. #(C.AdminVeri.kurallar or {}) .. " KURAL  ·  " .. #(C.AdminVeri.yasak or {}) .. " YASAKLI" end
          })

          ctx.CigirtkanYenile()
          C.AdminIstek("liste")
     end
}

ShineAdmin = ShineAdmin or {}
ShineAdmin.Pages = ShineAdmin.Pages or {}
ShineAdmin.Pages.cigirtkan = sayfa

concommand.Add("sardon_cigirtkan_admin", function()
     if ShineAdmin and ShineAdmin.Open then ShineAdmin:Open("cigirtkan") end
end)
