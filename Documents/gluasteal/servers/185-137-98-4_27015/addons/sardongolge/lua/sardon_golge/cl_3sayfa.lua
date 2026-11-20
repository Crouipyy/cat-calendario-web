-- "addons\\sardongolge\\lua\\sardon_golge\\cl_3sayfa.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Gölge :: istemci — Shine Admin "Gölge · Levazımatçı" sayfası. Sekmeler:
--   Ayarlar  : fiyat, hak, paket, hediye/Bakanlık olasılığı, gezinti, hançer/kılık süreleri, tezgâh kapalı
--              (sunucu sv_3golge S.AYAR_SEMA; kaydetme süper admin, görme yetkili)
--   Noktalar : Gölge'nin ışınlandığı noktalar — ekle (bulunduğun yer + ipucu), git, ipucu yaz, sil, şimdi ışınla
--   Kayıtlar : son 200 saplama / alışveriş / kılık / ışınlanma / ayar kaydı (sqlite sardon_golge_kayit)
-- Ağ: "SardonGolge.Ayar" (JSON; {admin = ...} sayfa verisi, {istemci = ...} herkesin kullandığı ayarlar).
-- Kalıp: [sardon] ck cl_2sayfa.lua, [sardon] portkey cl_5shine.lua.
local S = SardonGolge

S.AdminVeri = S.AdminVeri or nil
S.AdminSurum = S.AdminSurum or 0
S.KayitSurum = S.KayitSurum or 0

local TURLER = {
     saplama = "Clavada", satin = "Compra", donus = "Asumió disfraz", kilik_bitti = "Disfraz terminado",
     isinlanma = "Sombra teletransportada", hak_sifirla = "Cupos restablecidos", ayar = "Ajuste modificado", nokta = "Punto",
     mal = "Venta de mercancía", mal_ayar = "Ajuste de mercancía", dolandirma = "Estafa",
}

local SEKMELER = { { "ayar", "Ajustes" }, { "mal", "Mercancías" }, { "nokta", "Puntos" }, { "kayit", "Registros" } }
local KAYIT_SEKME = { { "hepsi", "Todos" }, { "saplama", "Clavada" }, { "satin", "Compra" }, { "mal", "Mercancías" }, { "kilik", "Disfraz" }, { "isinlanma", "Sombra" }, { "ayar", "Ajustes" } }

local function Admin(islem, t)
     t = t or {}
     t.islem = islem
     net.Start("SardonGolge.Ayar")
     net.WriteString(util.TableToJSON(t))
     net.SendToServer()
end

net.Receive("SardonGolge.Ayar", function()
     local t = util.JSONToTable(net.ReadString() or "") or {}
     if istable(t.istemci) then table.Merge(S.Ayar, t.istemci) end
     if istable(t.admin) then
          S.AdminVeri = t.admin
          S.AdminSurum = S.AdminSurum + 1
     end
end)

local function Gosterim(a, v)
     if a.tur == "bool" then return v == true end
     return math.Round((tonumber(v) or 0) / (a.birim or 1))
end

local function Saklama(a, g)
     if a.tur == "bool" then return g == true end
     return math.Round(tonumber(g) or 0) * (a.birim or 1)
end

----------------------------------------------------------------------------------------
-- Ayarlar sekmesi
----------------------------------------------------------------------------------------
local function AyarlarKur(N, kok, W, H, ctx)
     local u = N.u
     local V = S.AdminVeri
     if not V then
          kok.Paint = function(_, w, h) N.Text("Cargando ajustes…", "body", w / 2, h / 2, N.Clr.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
          return
     end
     kok.Paint = nil
     local taslak = table.Copy(V.ayar or {})
     kok.taslak = taslak

     local function Kirli()
          local n = 0
          for _, a in ipairs(V.sema or {}) do
               if Gosterim(a, taslak[a.k]) ~= Gosterim(a, V.ayar[a.k]) then n = n + 1 end
          end
          return n
     end
     kok.Kirli = Kirli

     local sc = N.Scroll(kok, 0, 0, u(W), u(H - 64))
     local kolW = math.floor((W - 16) / 2)
     local y = 0
     local gruplar, sira = {}, {}
     for _, a in ipairs(V.sema or {}) do
          if not gruplar[a.grup] then gruplar[a.grup] = {} sira[#sira + 1] = a.grup end
          table.insert(gruplar[a.grup], a)
     end

     for _, grup in ipairs(sira) do
          local bas = vgui.Create("DPanel", sc)
          bas:SetPos(0, u(y))
          bas:SetSize(u(W) - u(12), u(30))
          bas.Paint = function(_, w, h)
               N.Text(grup, "body", u(4), h / 2, N.Clr.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Box(0, h - 1, w, 1, N.Clr.tableLine)
          end
          y = y + 38
          local i = 0
          for _, a in ipairs(gruplar[grup]) do
               local x = (i % 2) * (kolW + 16)
               if a.tur == "bool" then
                    N.Toggle(sc, u(x), u(y), u(kolW), u(54), a.ad, function() return taslak[a.k] == true end,
                         function(v) if V.yaz then taslak[a.k] = v end end, a.aciklama, not V.yaz)
               else
                    local etiket = a.ad .. "   ·   predeterminado " .. Gosterim(a, (V.varsayilan or {})[a.k])
                    local sl = N.Slider(sc, u(x), u(y), u(kolW), etiket, a.min, a.max, 0, function() return Gosterim(a, taslak[a.k]) end,
                         function(v) taslak[a.k] = Saklama(a, v) end)
                    if not V.yaz and sl.Slider then sl.Slider:SetEnabled(false) end
               end
               i = i + 1
               if i % 2 == 0 then y = y + 62 end
          end
          if i % 2 == 1 then y = y + 62 end
          y = y + 10
     end

     local bar = N.StickyBar(kok, 0, u(H - 56), u(W), function()
          if not V.yaz then return "Solo lectura: solo el súper admin puede cambiar los ajustes.", N.Clr.warn end
          local n = Kirli()
          if n > 0 then return n .. " cambio(s) sin guardar.", N.Clr.warn end
          return "Esta semana (" .. tostring(V.hafta) .. ") el precio para los demás es " .. tostring(V.digerFiyat) .. " galeones. Al guardar entra en vigor al instante."
     end)
     local kaydet = N.Button(bar, u(W) - u(170), u(9), u(170), u(36), "Guardar", function()
          Admin("yaz", { ayar = taslak })
          ctx.Flash("Ajustes de Sombra enviados.")
     end)
     kaydet.Think = function(s) s:SetEnabled(V.yaz == true and Kirli() > 0) end
     local sifirla = N.Button(bar, u(W) - u(170) - u(200), u(9), u(190), u(36), "Restaurar por defecto", function()
          N.Confirm("Restaurar por defecto", "Todos los ajustes de Sombra vuelven a los valores de instalación (precios, cupos, duraciones).", "Restablecer", function()
               Admin("sifirla")
          end, true)
     end, "ghost")
     sifirla.Think = function(s) s:SetEnabled(V.yaz == true) end
     local geri = N.Button(bar, u(W) - u(170) - u(200) - u(160), u(9), u(150), u(36), "Descartar cambios", function()
          for k in pairs(taslak) do taslak[k] = V.ayar[k] end
          kok:Yeniden()
     end, "quiet")
     geri.Think = function(s) s:SetEnabled(Kirli() > 0) end
end

----------------------------------------------------------------------------------------
-- Noktalar sekmesi
----------------------------------------------------------------------------------------
local function NoktalarKur(N, kok, W, H, ctx)
     local u = N.u
     local sel
     local function V() return S.AdminVeri or {} end
     local function Secili()
          for _, n in ipairs(V().noktalar or {}) do if n.no == sel then return n end end
     end

     local durum = vgui.Create("DPanel", kok)
     durum:SetPos(0, 0)
     durum:SetSize(u(W), u(34))
     durum.Paint = function(_, w, h)
          local v = V()
          local metin = (v.aktorVar and ("Sombra ahora: " .. ((v.aktorAlan or "") ~= "" and v.aktorAlan or "fuera de zona") .. (v.simdiki and v.simdiki > 0 and ("  (punto " .. v.simdiki .. ")") or "")) or "Sombra no está en el mundo")
               .. "   ·   siguiente: " .. ((v.siradaki or 0) > 0 and ("punto " .. v.siradaki) or "—")
               .. "   ·   cambio automático de lugar en " .. S.Sure(v.gezintiKalan or 0)
               .. ((v.muhatap or "") ~= "" and ("   ·   hablando con: " .. v.muhatap) or "")
          N.Text(N.Clip(metin, "tiny", w - u(8)), "tiny", u(4), h / 2, N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     end

     local head = vgui.Create("DPanel", kok)
     head:SetPos(0, u(36))
     head:SetSize(u(W), u(30))
     head.Paint = function(_, w)
          N.TableHead(0, 0, w, { { "No", u(16) }, { "Pista / zona", w * 0.1 }, { "Distancia", w - u(24), TEXT_ALIGN_RIGHT } })
     end

     local list = N.VList(kok, 0, u(66), u(W), u(H - 66 - 132), {
          rowH = u(46),
          gapY = 0,
          emptyText = "No hay puntos. Sombra permanece en el lugar de misión (Cabeza de Jabalí).",
          onClick = function(n) sel = n.no end,
          paintRow = function(n, _, x, y, w, h, hovered)
               local on = sel == n.no
               if on then
                    N.Box(x, y, w, h, N.Clr.selRow)
                    N.Box(x, y, u(2), h, N.Clr.gold)
               elseif hovered then
                    N.Box(x, y, w, h, N.Clr.hoverRow)
               end
               N.Box(x, y + h - 1, w, 1, N.Clr.tableLine)
               local v = V()
               local rozet = (n.no == v.simdiki and "AHORA" or "") .. (n.no == v.siradaki and ((n.no == v.simdiki and " · " or "") .. "SIGUIENTE") or "")
               N.Text(tostring(n.no), "row", x + u(16), y + h / 2, on and N.Clr.text or N.Clr.tdFirst, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Text(N.Clip(n.ipucu ~= "" and n.ipucu or "(sin pista: se dice desde la zona)", "row", w * 0.72), "row", x + w * 0.1, y + h / 2 - u(8),
                    n.ipucu ~= "" and N.Clr.tdText or N.Clr.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Text(N.Clip((n.alan ~= "" and n.alan or "fuera de zona") .. "  ·  " .. n.pos, "tiny", w * 0.72), "tiny", x + w * 0.1, y + h / 2 + u(9), N.Clr.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Text(rozet, "tiny", x + w - u(110), y + h / 2, N.Clr.gold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
               N.Text(n.uz .. " uds.", "tiny", x + w - u(24), y + h / 2, N.Clr.faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
          end
     })
     kok.Yenile = function() list:SetItems(V().noktalar or {}, true) end
     kok.Yenile()

     local alt = u(H - 126)
     local _, giris = N.PlainEntry(kok, 0, alt, u(W), u(36), "Pista (se dice al Snatcher tras comprar; si está vacía, pista general de la zona)")
     local bw = math.floor((W - 4 * 10) / 5)
     local function B(i, metin, fn, stil, etkin)
          local b = N.Button(kok, u((bw + 10) * (i - 1)), alt + u(46), u(bw), u(36), metin, fn, stil)
          if etkin then b.Think = function(s) s:SetEnabled(etkin()) end end
          return b
     end
     B(1, "Añadir donde estoy", function()
          Admin("nokta_ekle", { ipucu = giris:GetValue() })
          ctx.Flash("Punto añadido: la dirección que miras será la de Sombra.")
     end)
     B(2, "Ir al seleccionado", function() local n = Secili() if n then Admin("nokta_git", { no = n.no }) end end, "ghost", function() return Secili() ~= nil end)
     B(3, "Guardar pista del seleccionado", function()
          local n = Secili()
          if n then Admin("nokta_ipucu", { no = n.no, ipucu = giris:GetValue() }) end
     end, "ghost", function() return Secili() ~= nil end)
     B(4, "Eliminar seleccionado", function()
          local n = Secili()
          if not n then return end
          N.Confirm("Eliminar punto", "Se elimina el punto " .. n.no .. "; Sombra ya no se teletransportará allí.", "Eliminar", function()
               Admin("nokta_sil", { no = n.no })
               sel = nil
          end, true)
     end, "danger", function() return Secili() ~= nil end)
     B(5, "Teletransportar Sombra ahora", function() Admin("simdi") end, nil, function() return #(V().noktalar or {}) > 0 end)
end

----------------------------------------------------------------------------------------
-- Kayıtlar sekmesi
----------------------------------------------------------------------------------------
local function KayitUyar(r, sekme)
     if sekme == "hepsi" then return true end
     if sekme == "kilik" then return r.tur == "donus" or r.tur == "kilik_bitti" end
     if sekme == "isinlanma" then return r.tur == "isinlanma" or r.tur == "nokta" end
     if sekme == "mal" then return r.tur == "mal" or r.tur == "mal_ayar" end
     if sekme == "satin" then return r.tur == "satin" or r.tur == "dolandirma" end
     return r.tur == sekme
end

local function KayitlarKur(N, kok, W, H, ctx)
     local u = N.u
     local sekme, sel, list = "hepsi", nil, nil
     local function satirlar()
          local out = {}
          for _, r in ipairs(S.Kayitlar or {}) do if KayitUyar(r, sekme) then out[#out + 1] = r end end
          return out
     end
     kok.Secili = function()
          for _, r in ipairs(S.Kayitlar or {}) do if r.id == sel then return r end end
     end
     kok.Yenile = function() if IsValid(list) then list:SetItems(satirlar(), true) end end

     N.SubTabs(kok, 0, 0, u(W), KAYIT_SEKME, function() return sekme end, function(id) sekme, sel = id, nil kok.Yenile() end)

     local head = vgui.Create("DPanel", kok)
     head:SetPos(0, u(54))
     head:SetSize(u(W), u(30))
     head.Paint = function(_, w)
          N.TableHead(0, 0, w, { { "Tipo", u(16) }, { "Quién", w * 0.24 }, { "Detalle", w * 0.5 }, { "Fecha", w - u(24), TEXT_ALIGN_RIGHT } })
     end

     list = N.VList(kok, 0, u(84), u(W), u(H - 84 - 8), {
          rowH = u(46),
          gapY = 0,
          emptyText = "Sin registros.",
          onClick = function(r) sel = r.id end,
          paintRow = function(r, _, x, y, w, h, hovered)
               local on = sel == r.id
               if on then
                    N.Box(x, y, w, h, N.Clr.selRow)
                    N.Box(x, y, u(2), h, N.Clr.gold)
               elseif hovered then
                    N.Box(x, y, w, h, N.Clr.hoverRow)
               end
               N.Box(x, y + h - 1, w, 1, N.Clr.tableLine)
               local ust, alt = y + h / 2 - u(8), y + h / 2 + u(9)
               N.Text(TURLER[r.tur] or r.tur or "?", "row", x + u(16), y + h / 2, on and N.Clr.text or N.Clr.tdFirst, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Text(N.Clip((r.kim or "") ~= "" and r.kim or "—", "row", w * 0.25), "row", x + w * 0.24, ust, N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Text(N.Clip((r.hedef or "") ~= "" and ("→ " .. r.hedef) or "", "tiny", w * 0.25), "tiny", x + w * 0.24, alt, N.Clr.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Text(N.Clip(r.ayrinti or "", "tiny", w * 0.34), "tiny", x + w * 0.5, y + h / 2, N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Text(r.zaman and os.date("%d.%m %H:%M", r.zaman) or "—", "tiny", x + w - u(24), y + h / 2, N.Clr.faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
          end
     })
     kok.Yenile()
     S.Iste(S.ISTEK.KAYIT)
end

----------------------------------------------------------------------------------------
-- Mallar sekmesi: Gölge'nin tezgâhına konan Helix eşyaları (sv_3golge S.Mallar; yazma süper admin)
----------------------------------------------------------------------------------------
local KIM_SECENEK = { { "herkes", "Todos" }, { "snatcher", "Solo Snatcher" }, { "diger", "Excepto Snatcher" } }

local function KimAd(k)
     for _, x in ipairs(KIM_SECENEK) do if x[1] == k then return x[2] end end
     return tostring(k)
end

local function EsyaAd(id)
     local it = ix.item.list[id or ""]
     return it and isstring(it.name) and it.name or tostring(id or "?")
end

local function EsyaAra(metin)
     metin = string.lower(string.Trim(metin or ""))
     local t = {}
     if metin == "" then return t end
     for id, it in SortedPairs(ix.item.list) do
          local ad = isstring(it.name) and it.name or ""
          if string.find(string.lower(id), metin, 1, true) or string.find(string.lower(ad), metin, 1, true) then
               t[#t + 1] = { id = id, ad = ad ~= "" and ad or id }
               if #t >= 150 then break end
          end
     end
     return t
end

local function MallarKur(N, kok, W, H, ctx)
     local u = N.u
     local function V() return S.AdminVeri or {} end
     local LW = math.floor(W * 0.4)
     local RX = LW + 16
     local RW = W - RX
     local secId = S.MalSecili
     local sag, FormKur

     local function Bos()
          return { id = 0, esya = "", ad = "", fiyat = 100, snatcherFiyat = 0, stok = -1, kisiSinir = 1, kimler = "herkes", aktif = true, soz = "", veri = "" }
     end
     local function Bul(id)
          for _, m in ipairs(V().mallar or {}) do if m.id == id then return m end end
     end

     N.Button(kok, 0, 0, u(LW), u(36), "Nueva mercancía", function()
          secId, S.MalSecili = 0, 0
          FormKur(Bos())
     end)
     local list = N.VList(kok, 0, u(44), u(LW), u(H - 44), {
          rowH = u(52),
          gapY = 0,
          emptyText = "No hay mercancía en el mostrador. Añade con «Nueva mercancía».",
          onClick = function(m)
               secId, S.MalSecili = m.id, m.id
               FormKur(table.Copy(m))
          end,
          paintRow = function(m, _, x, y, w, h, hovered)
               local on = secId == m.id
               if on then
                    N.Box(x, y, w, h, N.Clr.selRow)
                    N.Box(x, y, u(2), h, N.Clr.gold)
               elseif hovered then
                    N.Box(x, y, w, h, N.Clr.hoverRow)
               end
               N.Box(x, y + h - 1, w, 1, N.Clr.tableLine)
               local ad = (m.ad or "") ~= "" and m.ad or EsyaAd(m.esya)
               N.Text(N.Clip(ad, "row", w - u(130)), "row", x + u(14), y + h / 2 - u(9), m.aktif and N.Clr.text or N.Clr.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Text(N.Clip(m.esya .. "  ·  " .. KimAd(m.kimler) .. (m.gecerli and "" or "  ·  ÍTEM INEXISTENTE"), "tiny", w - u(130)), "tiny", x + u(14), y + h / 2 + u(10),
                    m.gecerli and N.Clr.faint or N.Clr.bad, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Text(string.Comma(m.fiyat) .. " G", "row", x + w - u(14), y + h / 2 - u(9), N.Clr.gold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
               local stok = m.stok < 0 and ("vendidos " .. (m.satilan or 0)) or ((m.satilan or 0) .. "/" .. m.stok .. " vendidos")
               N.Text(stok .. (m.aktif and "" or " · cerrado"), "tiny", x + w - u(14), y + h / 2 + u(10), N.Clr.faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
          end
     })

     FormKur = function(m)
          if IsValid(sag) then sag:Remove() end
          sag = vgui.Create("DPanel", kok)
          sag:SetPos(u(RX), 0)
          sag:SetSize(u(RW), u(H))
          sag.Paint = nil
          if not m then
               sag.Paint = function(_, w, h) N.Text("Elige una mercancía a la izquierda o añade con «Nueva mercancía».", "body", w / 2, h / 2, N.Clr.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
               return
          end
          -- yetki her karede güncel veriden (form, sunucu verisi gelmeden kurulmuş olabilir)
          local function Yaz() return V().yaz == true end
          local half = math.floor((RW - 12) / 2)
          local y = 0

          local bas = vgui.Create("DPanel", sag)
          bas:SetPos(0, 0)
          bas:SetSize(u(RW), u(28))
          bas.Paint = function(_, w, h)
               local secili = (m.esya or "") ~= "" and (EsyaAd(m.esya) .. "  (" .. m.esya .. ")") or "Sin ítem: busca abajo y haz clic"
               N.Text(N.Clip((m.id > 0 and ("Mercancía #" .. m.id .. " · ") or "Nueva mercancía · ") .. secili, "body", w), "body", 0, h / 2,
                    (m.esya or "") ~= "" and N.Clr.gold or N.Clr.warn, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          end
          y = y + 32

          local sonuc
          N.PlainEntry(sag, 0, u(y), u(RW), u(34), "Buscar ítem (nombre o id, p. ej. poción, libro, cuchillo)", function(v)
               if IsValid(sonuc) then sonuc:SetItems(EsyaAra(v), false) end
          end)
          y = y + 40
          sonuc = N.VList(sag, 0, u(y), u(RW), u(112), {
               rowH = u(28),
               gapY = 0,
               emptyText = "Escribe para buscar.",
               onClick = function(e) m.esya = e.id end,
               paintRow = function(e, _, x, yy, w, h, hovered)
                    if m.esya == e.id then N.Box(x, yy, w, h, N.Clr.selRow) elseif hovered then N.Box(x, yy, w, h, N.Clr.hoverRow) end
                    N.Text(N.Clip(e.ad .. "   ·   " .. e.id, "tiny", w - u(16)), "tiny", x + u(8), yy + h / 2, m.esya == e.id and N.Clr.gold or N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               end
          })
          y = y + 120

          local _, adE = N.PlainEntry(sag, 0, u(y), u(RW), u(34), "Nombre visible (si está vacío, el del ítem)", function(v) m.ad = v end)
          adE:SetValue(m.ad or "")
          y = y + 42

          N.Slider(sag, 0, u(y), u(half), "Precio (galeones)", 0, 20000, 0, function() return m.fiyat end, function(v) m.fiyat = math.Round(v) end)
          N.Slider(sag, u(half + 12), u(y), u(half), "Precio Snatcher (0 = igual)", 0, 20000, 0, function() return m.snatcherFiyat end, function(v) m.snatcherFiyat = math.Round(v) end)
          y = y + 62
          N.Slider(sag, 0, u(y), u(half), "Stock semanal (-1 = ilimitado)", -1, 500, 0, function() return m.stok end, function(v) m.stok = math.Round(v) end)
          N.Slider(sag, u(half + 12), u(y), u(half), "Por persona semanal (0 = ilimitado)", 0, 50, 0, function() return m.kisiSinir end, function(v) m.kisiSinir = math.Round(v) end)
          y = y + 62

          N.Combo(sag, 0, u(y + 9), u(half), u(36), KimAd(m.kimler), { "Todos", "Solo Snatcher", "Excepto Snatcher" }, function(val)
               for _, x in ipairs(KIM_SECENEK) do if x[2] == val then m.kimler = x[1] end end
          end)
          N.Toggle(sag, u(half + 12), u(y), u(half), u(54), "En mostrador", function() return m.aktif == true end, function(v) m.aktif = v end, "Si está cerrado no se vende; permanece en la lista.")
          y = y + 62

          local _, sozE = N.PlainEntry(sag, 0, u(y), u(RW), u(34), "Frase de Sombra (entre comillas en la tarjeta; si está vacía, la descripción del ítem)", function(v) m.soz = v end)
          sozE:SetValue(m.soz or "")
          y = y + 42
          local _, veriE = N.PlainEntry(sag, 0, u(y), u(RW), u(34), "Datos del ítem, JSON (avanzado; déjalo vacío en la mayoría)", function(v) m.veri = v end)
          veriE:SetValue(m.veri or "")
          y = y + 46

          local kay = N.Button(sag, 0, u(y), u(half), u(36), m.id > 0 and "Guardar" or "Añadir al mostrador", function()
               if (m.esya or "") == "" then return ctx.Flash("Primero elige un ítem.", "bad") end
               Admin("mal_kaydet", { mal = m })
               if m.id == 0 then
                    secId, S.MalSecili = nil, nil
                    FormKur(nil)
               end
          end)
          kay.Think = function(s) s:SetEnabled(Yaz() and (m.esya or "") ~= "") end
          if m.id > 0 then
               local sil = N.Button(sag, u(half + 12), u(y), u(half), u(36), "Eliminar", function()
                    N.Confirm("Eliminar mercancía", ((m.ad or "") ~= "" and m.ad or EsyaAd(m.esya)) .. " se quitará del mostrador de Sombra.", "Eliminar", function()
                         Admin("mal_sil", { id = m.id })
                         secId, S.MalSecili = nil, nil
                         FormKur(nil)
                    end, true)
               end, "danger")
               sil.Think = function(s) s:SetEnabled(Yaz()) end
          end
          local not1 = vgui.Create("DPanel", sag)
          not1:SetPos(0, u(y + 42))
          not1:SetSize(u(RW), u(24))
          not1.Paint = function(_, w, h)
               if not S.AdminVeri then
                    N.Text("Esperando datos del servidor…", "tiny", 0, h / 2, N.Clr.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               elseif not Yaz() then
                    N.Text("Solo lectura: solo el súper admin puede cambiar las mercancías.", "tiny", 0, h / 2, N.Clr.warn, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               end
          end
     end

     kok.Yenile = function() list:SetItems(V().mallar or {}, true) end
     kok.Yenile()
     local m = secId and secId > 0 and Bul(secId)
     FormKur(m and table.Copy(m) or (secId == 0 and Bos() or nil))
end

local KURUCU = { ayar = AyarlarKur, mal = MallarKur, nokta = NoktalarKur, kayit = KayitlarKur }

----------------------------------------------------------------------------------------
-- Sayfa
----------------------------------------------------------------------------------------
local function SayfaKaydet()
     if not (ShineAdmin and ShineAdmin.RegisterPage and ShineAdmin.GetN) then return false end

     ShineAdmin:RegisterPage("golge", {
          label = "Sombra · Proveedor",
          icon = "lock",
          group = "players",
          order = 34,
          title = "Sombra · Proveedor",
          subtitle = "Mercado negro del Cuchillo de la Realidad: precios y cupos semanales, puntos de Sombra, registros de clavadas y compras.",
          access = "staff",
          rail = true,

          build = function(ctx)
               local N = ShineAdmin.GetN()
               local u = N.u
               local Pn, W, H = ctx.panel, ctx.w, ctx.h
               local sekme = KURUCU[ctx.arg or ""] and ctx.arg or (S.SonSekme or "ayar")
               local kok

               local function Kur()
                    if IsValid(kok) then kok:Remove() end
                    S.SonSekme = sekme
                    kok = vgui.Create("DPanel", Pn)
                    kok:SetPos(0, u(56))
                    kok:SetSize(u(W), u(H - 56))
                    kok.Paint = nil
                    kok.surum = S.AdminSurum
                    kok.kayitSurum = S.KayitSurum
                    kok.Yeniden = function() Kur() end
                    KURUCU[sekme](N, kok, W, H - 56, ctx)
                    kok.Think = function(s)
                         if s.surum ~= S.AdminSurum then
                              s.surum = S.AdminSurum
                              -- ayarlarda kaydedilmemiş değişiklik varken yeniden kurma (yazılanlar gitmesin)
                              if sekme == "ayar" and (not s.Kirli or s.Kirli() == 0) then return Kur() end
                              if (sekme == "nokta" or sekme == "mal") and s.Yenile then s.Yenile() end
                         end
                         if s.kayitSurum ~= S.KayitSurum then
                              s.kayitSurum = S.KayitSurum
                              if sekme == "kayit" and s.Yenile then s.Yenile() end
                         end
                    end
               end

               N.SubTabs(Pn, 0, 0, u(W), SEKMELER, function() return sekme end, function(id)
                    sekme = id
                    Kur()
                    Admin("iste")
               end)

               ctx.SetRail({
                    hero = "icons/lock",
                    badge = { text = "Mercado negro", icon = "lock", color = N.Clr.warn },
                    title = function()
                         if sekme == "kayit" and IsValid(kok) and kok.Secili and kok.Secili() then
                              local r = kok.Secili()
                              return TURLER[r.tur] or r.tur
                         end
                         return "Sombra · Proveedor"
                    end,
                    body = function()
                         if sekme == "kayit" and IsValid(kok) and kok.Secili and kok.Secili() then return kok.Secili().ayrinti or "" end
                         local v = S.AdminVeri
                         if not v then return "Cargando…" end
                         local a = v.ayar or {}
                         return (a.Kapali and "MOSTRADOR CERRADO. " or "") .. "Snatcher puede comprar " .. tostring(a.SnatcherSinir) .. " veces por semana "
                              .. "un paquete de " .. tostring(a.SnatcherPaket) .. " cuchillos (" .. tostring(a.SnatcherFiyat) .. " G); los demás "
                              .. tostring(a.DigerSinir) .. " veces por semana " .. tostring(a.DigerAdet) .. " cuchillo(s) (esta semana "
                              .. tostring(v.digerFiyat) .. " G). Cupos por SteamID; se renuevan los lunes a las 07:00."
                    end,
                    props = function()
                         if sekme == "kayit" and IsValid(kok) and kok.Secili and kok.Secili() then
                              local r = kok.Secili()
                              return {
                                   { "Quién", (r.kim or "") ~= "" and r.kim or "—" },
                                   { "Quién SteamID", (r.kimSid or "") ~= "" and util.SteamIDFrom64(r.kimSid) or "—" },
                                   { "Objetivo", (r.hedef or "") ~= "" and r.hedef or "—" },
                                   { "Objetivo SteamID", (r.hedefSid or "") ~= "" and util.SteamIDFrom64(r.hedefSid) or "—" },
                                   { "Fecha", r.zaman and os.date("%d.%m.%Y %H:%M", r.zaman) or "—" },
                              }
                         end
                         local v = S.AdminVeri or {}
                         return {
                              { "Semana", tostring(v.hafta or "—") },
                              { "Precio otros (esta semana)", tostring(v.digerFiyat or "—") .. " G" },
                              { "Puntos", #(v.noktalar or {}) },
                              { "Permiso", v.yaz and "súper admin (edición)" or "autorizado (solo lectura)" },
                         }
                    end
               })
               ctx.SetHead({ count = function() return #((S.AdminVeri or {}).noktalar or {}) end, note = "PUNTOS" })

               Kur()
               Admin("iste")
               return function() Admin("iste") end
          end
     })
     return true
end

-- kayıt listesi gelince (cl_1kopya S.OP.KAYIT) sayfa yenilensin
hook.Add("Think", "SardonGolge.KayitIzle", function()
     if S.Kayitlar ~= S.sonKayitlar then
          S.sonKayitlar = S.Kayitlar
          S.KayitSurum = S.KayitSurum + 1
     end
end)

-- sardon_golge, sardon_shineadmin'den önce yükleniyor (alfabetik); ShineAdmin gelene kadar dene
if not SayfaKaydet() then
     timer.Create("SardonGolge.Sayfa", 1, 120, function()
          if SayfaKaydet() then timer.Remove("SardonGolge.Sayfa") end
     end)
end
