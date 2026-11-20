-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\cl_9yonetim.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: Shine Admin sayfası "yaratik" + alanın dünyada gösterimi
--
-- Alan: vivaryumun bir köşesine git "1. köşe", karşı köşeye git "2. köşe". Yemlik/yuva: bakılan
-- yere eklenir. Oyuncu seç → sus criaturas gör, test işlemleri uygula ya da criaturas/huevo ver.

-- 11-13 opt (kodmod): kare başı kurulan sabitler dosya yereline alındı
local OPT_V_0_0_80 = Vector(0, 0, 80)
local OPT_V_0_0_30 = Vector(0, 0, 30)
local OPT_R_160_160_160 = Color(160, 160, 160)
local OPT_V_n14_n14_0 = Vector(-14, -14, 0)
local OPT_V_14_14_10 = Vector(14, 14, 10)
local OPT_V_0_0_8 = Vector(0, 0, 8)
local OPT_V_0_0_140 = Vector(0, 0, 140)
local OPT_V_0_0_200 = Vector(0, 0, 200)
local Y = SardonYaratik

Y.YonetimVeri = Y.YonetimVeri or {oyuncular = {}, yaratiklar = {}}
Y.AlanGoster = Y.AlanGoster or false

------------------------------------------------------------------------ dünyada alan

local renkAlan = Color(150, 220, 140)
local renkYemlik = Color(230, 170, 90)
local renkYuva = Color(240, 210, 120)
local renkYasam = Color(120, 200, 230)
local renkAgil = Color(225, 150, 185)

hook.Add("PostDrawTranslucentRenderables", "SardonYaratik.AlanGoster", function(derinlik, gok)
     if not Y.AlanGoster or gok or derinlik then return end
     if Y.AlanVar() then
          local a, b = Y.Alan.min, Y.Alan.max
          render.DrawWireframeBox(vector_origin, angle_zero, Vector(a.x, a.y, a.z - 8), Vector(b.x, b.y, b.z + 120), renkAlan, true)
     end
     -- yetkilinin noktaları kişisel vivaryumların varsayılan yemlik/yuvası (Y.Alan.yemlik bulunulan dünyanınki)
     for _, p in ipairs(Y.Alan.varsayilanYemlik or Y.Alan.yemlik or {}) do
          render.DrawWireframeSphere(p, 18, 10, 10, renkYemlik, true)
          render.DrawLine(p, p + OPT_V_0_0_80, renkYemlik, true)
     end
     local cik = istable(Y.Alan.cikis) and Y.Alan.cikis[1]
     if isvector(cik) then
          render.DrawWireframeSphere(cik + OPT_V_0_0_30, 30, 10, 10, renkAlan, true)
          render.DrawLine(cik, cik + Angle(0, Y.Alan.cikis[2] or 0, 0):Forward() * 80, renkAlan, true)
     end
     if Y.EvIzi then
          render.DrawWireframeBox(vector_origin, angle_zero, Y.EvIzi.min, Y.EvIzi.max, OPT_R_160_160_160, true)
     end
     for _, p in ipairs(Y.Alan.varsayilanYuva or Y.Alan.yuva or {}) do
          render.DrawWireframeBox(p, angle_zero, OPT_V_n14_n14_0, OPT_V_14_14_10, renkYuva, true)
          render.DrawLine(p, p + OPT_V_0_0_80, renkYuva, true)
     end
     -- Çiftleşme Ağılı: çit kare, giriş tarafı ok
     for i, p in ipairs(Y.Alan.agil or {}) do
          local yaw = Y.YerYon("agil", i)
          local s = Y.AgilYari or 256
          render.DrawWireframeBox(p, Angle(0, yaw, 0), Vector(-s, -s, 0), Vector(s, s, 70), renkAgil, true)
          local giris = Y.YerKonum(p, yaw, -s - 60, 0)
          render.DrawLine(p + OPT_V_0_0_8, giris + OPT_V_0_0_8, renkAgil, true)
     end
     -- criaturas salvajes yaşam alanları: yarıçap çemberi
     for _, y in ipairs(Y.Alan.yasam or {}) do
          local n = 40
          local onceki
          for i = 0, n do
               local a = i / n * math.pi * 2
               local q = y.p + Vector(math.cos(a) * y.r, math.sin(a) * y.r, 6)
               if onceki then render.DrawLine(onceki, q, renkYasam, true) end
               onceki = q
          end
          render.DrawLine(y.p, y.p + OPT_V_0_0_140, renkYasam, true)
     end
     local k = Y.YonetimVeri and Y.YonetimVeri.kose
     for i = 1, 2 do
          local p = k and k[i]
          if isvector(p) then render.DrawLine(p, p + OPT_V_0_0_200, renkAlan, true) end
     end
end)

------------------------------------------------------------------------ sayfa

local NADIR_AD = {"Común", "Nadir", "Legendario"}
local EVRE_AD = {"Cría", "Joven", "Adulto"}

local sayfa = {
     id = "yaratik",
     label = "Criaturas",
     icon = "leaf",
     group = "systems",
     order = 41,
     title = "Criaturas mágicas",
     subtitle = "Vivario, puntos de comederos/nidos; dar criaturas y huevos a jugadores y pruebas.",
     access = "staff",
     available = function() return SardonYaratik and SardonYaratik.Turler end,

     build = function(ctx)
          local N = ShineAdmin.GetN()
          local u = N.u
          local P = ctx.panel
          local V = function() return Y.YonetimVeri or {} end

          local seciliOyuncu, seciliYaratik
          local form = {tur = Y.TurSirasi[1], nadir = 1, cins = "aleatorio", evre = 1, huevo = false}

          local x = 0
          local function Ust(w, yazi, fn, stil)
               local d = N.Button(P, u(x), 0, u(w), u(34), yazi, fn, stil)
               x = x + w + 8
               return d
          end
          Ust(124, "1.ª esquina: aquí", function() Y.Yonetim("kose", {i = 1, hedef = seciliOyuncu}) end, "primary")
          Ust(124, "2.ª esquina: aquí", function() Y.Yonetim("kose", {i = 2, hedef = seciliOyuncu}) end, "primary")
          Ust(110, "Añadir comedero", function() Y.Yonetim("nokta_ekle", {cesit = "yemlik", hedef = seciliOyuncu}) end)
          Ust(100, "Añadir nido", function() Y.Yonetim("nokta_ekle", {cesit = "yuva", hedef = seciliOyuncu}) end)
          Ust(100, "Añadir corral", function() Y.Yonetim("nokta_ekle", {cesit = "agil", hedef = seciliOyuncu}) end)
          Ust(110, "Borrar punto", function() Y.Yonetim("nokta_sil", {hedef = seciliOyuncu}) end)
          local goster = Ust(130, function() return Y.AlanGoster and "Ocultar zona" or "Mostrar zona" end, function() Y.AlanGoster = not Y.AlanGoster end)
          goster.NoCaps = true
          Ust(100, "Teletransportarse", function() Y.Yonetim("git", {}) end)
          Ust(90, "Borrar zona", function()
               N.Confirm("Borrar zona del vivero", "Se quitan zona y esquinas (yemlik/yuva noktaları kalır).", "Borrar", function()
                    Y.Yonetim("alan_sil", {})
               end, true)
          end, "danger")

          local durum = vgui.Create("DPanel", P)
          durum:SetPos(0, u(42))
          durum:SetSize(u(ctx.w), u(22))
          durum.Paint = function(s, pw, ph)
               local v = V()
               local alan = v.alan and string.format("alan %d × %d", v.alan.max.x - v.alan.min.x, v.alan.max.y - v.alan.min.y) or "SIN ZONA"
               N.Text(string.format("%s  ·  %d comederos  ·  %d nidos  ·  salida %s  ·  %d viveros abiertos  ·  en vivero %d/%d criaturas  ·  cerca %d/%d  ·  caché %d registros  ·  %d zonas de vida",
                    alan, #(v.yemlik or {}), #(v.yuva or {}), v.cikis and "var" or "YOK", v.dunya or 0, v.vivaryum or 0, v.sinir and v.sinir.viv or 0, v.takip or 0, v.sinir and v.sinir.takip or 0, v.kayit or 0,
                    #(v.yasam or {})),
                    "small", 0, ph / 2, N.Clr.rowDesc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          end
          -- kişisel vivaryumların çıkış sütunu (baktığın yer, önü sana dönük)
          N.Button(P, u(ctx.w - 150), u(42), u(150), u(22), "Poner salida aquí", function() Y.Yonetim("cikis", {hedef = seciliOyuncu}) end)

          -- criaturas salvajes yaşam alanı (Faz 3): hazır yaşam türü ya da tek tür, yarıçap, nüfus; baktığın yere
          local yasamForm = {hazir = 1, tur = nil, r = 600, n = 3}
          local secenekler, secimler = {}, {}
          for i, h in ipairs(Y.YasamHazir or {}) do
               local adlar = {}
               for _, id in ipairs(h.turler) do adlar[#adlar + 1] = Y.Turler[id] and Y.Turler[id].ad or id end
               local ad = h.ad .. " (" .. table.concat(adlar, ", ") .. ")"
               secenekler[#secenekler + 1] = ad
               secimler[ad] = {hazir = i}
          end
          for _, id in ipairs(Y.TurSirasi) do
               if not (Y.YabaniYok or {})[id] then
                    local ad = "Yalnız " .. Y.Turler[id].ad
                    secenekler[#secenekler + 1] = ad
                    secimler[ad] = {tur = id}
               end
          end
          local yy = 70
          N.Combo(P, 0, u(yy), u(300), u(32), secenekler[1] or "", secenekler, function(v)
               local s = secimler[v]
               if s then yasamForm.hazir, yasamForm.tur = s.hazir, s.tur end
          end)
          local YARICAP = {"300 unidades", "600 unidades", "900 unidades", "1200 unidades"}
          N.Combo(P, u(308), u(yy), u(110), u(32), "600 unidades", YARICAP, function(v) yasamForm.r = tonumber(v:match("%d+")) or 600 end)
          local NUFUS = {"2 criaturas", "3 criaturas", "4 criaturas", "6 criaturas"}
          N.Combo(P, u(426), u(yy), u(110), u(32), "3 criaturas", NUFUS, function(v) yasamForm.n = tonumber(v:match("%d+")) or 3 end)
          N.Button(P, u(544), u(yy), u(150), u(32), "Añadir zona de vida", function()
               Y.Yonetim("yasam_ekle", {hazir = yasamForm.hazir, tur = yasamForm.tur, r = yasamForm.r, n = yasamForm.n, hedef = seciliOyuncu})
          end, "primary")
          N.Button(P, u(702), u(yy), u(170), u(32), "Borrar zona cercana", function() Y.Yonetim("yasam_sil", {hedef = seciliOyuncu}) end)
          N.Button(P, u(880), u(yy), u(150), u(32), "Actualizar salvajes", function() Y.Yonetim("yasam_tazele", {hedef = seciliOyuncu}) end)

          local ustH = 112
          local LW = 300
          local oyuncular = N.VList(P, 0, u(ustH), u(LW), u(ctx.h - ustH), {
               rowH = u(52), gapY = u(6), emptyText = "No hay personajes en línea.",
               onClick = function(o)
                    seciliOyuncu = o.char
                    seciliYaratik = nil
                    Y.Yonetim("veri", {hedef = o.char})
               end,
               paintRow = function(o, i, rx, ry, cw, ch, hovered)
                    local on = seciliOyuncu == o.char
                    N.Box(rx, ry, cw, ch, on and N.Clr.selRow or (hovered and N.Clr.hoverRow or N.Clr.toolBg))
                    N.Outline(rx, ry, cw, ch, on and N.Clr.gold or N.Clr.toolLine, 1)
                    N.Text(o.ad, "row", rx + u(12), ry + u(9), on and N.Clr.goldAccent or N.Clr.rowText)
                    local ek = (o.olum and "  ·  Ve vidente" or "") .. (o.binek and "  ·  montado" or "")
                    N.Text(o.steam .. "  ·  " .. o.sayi .. " criaturas" .. ek, "micro", rx + u(12), ry + u(30), N.Clr.rowDesc)
               end
          })

          local DX = LW + 20
          local DW = ctx.w - DX
          local liste = N.VList(P, u(DX), u(ustH), u(DW), u(ctx.h - ustH - 236), {
               rowH = u(46), gapY = u(5), emptyText = "Elige un jugador de la izquierda.",
               onClick = function(k) seciliYaratik = k.id end,
               paintRow = function(k, i, rx, ry, cw, ch, hovered)
                    local on = seciliYaratik == k.id
                    local tur = Y.Turler[k.tur]
                    N.Box(rx, ry, cw, ch, on and N.Clr.selRow or (hovered and N.Clr.hoverRow or N.Clr.toolBg))
                    N.Outline(rx, ry, cw, ch, on and N.Clr.gold or N.Clr.toolLine, 1)
                    local evre = k.evre == 0 and "huevo" or ((Y.Evreler[k.evre] or {}).ad or "?")
                    N.Text("#" .. k.id .. "  " .. (k.ad or "?") .. "  ·  " .. (tur and tur.ad or k.tur), "row", rx + u(12), ry + u(7), on and N.Clr.goldAccent or N.Clr.rowText)
                    N.Text(string.format("%s · %s · %s · %s · mutlu %%%d · bağ %d · sv %d · kalan %s · ceza %s",
                         k.durum, evre, NADIR_AD[k.nadir or 1] or "?", k.cins == "d" and "hembra" or (k.cins == "e" and "macho" or "?"),
                         k.mutlu or 0, k.bag or 0, k.seviye or 0, k.kalan and Y.SureYazi(k.kalan) or "—", Y.SureYazi(k.ceza or 0)),
                         "micro", rx + u(12), ry + u(27), N.Clr.rowDesc)
               end
          })

          -- seçili criaturas işlemleri
          local islemY = ctx.h - 230
          local bx = DX
          local function Islem(w, yazi, ne, stil)
               N.Button(P, u(bx), u(islemY), u(w), u(32), yazi, function()
                    if not seciliYaratik then return end
                    if ne == "sil" or ne == "oldur" then
                         N.Confirm(yazi, "#" .. seciliYaratik .. " için geri alınamaz.", yazi, function()
                              Y.Yonetim("islem", {id = seciliYaratik, ne = ne})
                         end, true)
                         return
                    end
                    Y.Yonetim("islem", {id = seciliYaratik, ne = ne})
               end, stil)
               bx = bx + w + 6
          end
          Islem(110, "Llenar necesidades", "doldur")
          Islem(110, "Avanzar etapa", "evre")
          Islem(110, "Envejecer 6 h", "yaslandir")
          Islem(96, "Producir", "urun")
          Islem(110, "Reiniciar penalización", "ceza")
          Islem(80, "Matar", "oldur", "danger")
          Islem(70, "Borrar", "sil", "danger")

          -- ver formu
          local fy = ctx.h - 184
          N.SectionLabel("Dar al jugador seleccionado", u(DX), u(fy), u(DW), "plus")
          fy = fy + 26
          local turlar, turIdler = {}, {}
          for _, id in ipairs(Y.TurSirasi) do
               turlar[#turlar + 1] = Y.Turler[id].ad
               turIdler[Y.Turler[id].ad] = id
          end
          N.Combo(P, u(DX), u(fy), u(200), u(32), Y.Turler[form.tur].ad, turlar, function(v) form.tur = turIdler[v] or form.tur end)
          N.Combo(P, u(DX + 210), u(fy), u(130), u(32), NADIR_AD[form.nadir], NADIR_AD, function(v)
               for i, a in ipairs(NADIR_AD) do if a == v then form.nadir = i end end
          end)
          N.Combo(P, u(DX + 350), u(fy), u(120), u(32), "aleatorio", {"aleatorio", "macho", "hembra"}, function(v)
               form.cins = v == "macho" and "e" or (v == "hembra" and "d" or "aleatorio")
          end)
          N.Combo(P, u(DX + 480), u(fy), u(130), u(32), EVRE_AD[form.evre], EVRE_AD, function(v)
               for i, a in ipairs(EVRE_AD) do if a == v then form.evre = i end end
          end)
          N.Toggle(P, u(DX + 620), u(fy), u(150), u(32), "Como huevo", function() return form.huevo end, function(v) form.huevo = v end)
          N.Button(P, u(DX + 780), u(fy), u(100), u(32), "Ver", function()
               if not seciliOyuncu then return end
               Y.Yonetim("ver", {char = seciliOyuncu, tur = form.tur, nadir = form.nadir, cins = form.cins, evre = form.evre, huevo = form.huevo})
          end, "primary")

          local not_ = vgui.Create("DPanel", P)
          not_:SetPos(u(DX), u(fy + 44))
          not_:SetSize(u(DW), u(60))
          not_.Paint = function(s, pw, ph)
               N.Text("Huevo: el pool de padres usa la rareza elegida; la rareza se fija al incubar. La criatura nacida empieza en la etapa seleccionada.", "micro", 0, u(8), N.Clr.rowDesc)
               N.Text("Avanzar etapa: termina la incubación o prepara cría/joven en edad y vínculo. Los cambios se aplican al dueño al instante.", "micro", 0, u(26), N.Clr.rowDesc)
          end

          -- seçili oyuncu: Thestral görme statüsü ve montadon indirme
          local by = fy + 104
          N.Button(P, u(DX), u(by), u(220), u(30), "Ve vidente: activar / desactivar", function()
               if seciliOyuncu then Y.Yonetim("olum", {char = seciliOyuncu, hedef = seciliOyuncu}) end
          end)
          N.Button(P, u(DX + 230), u(by), u(170), u(30), "Bajar de montura", function()
               if seciliOyuncu then Y.Yonetim("indir", {char = seciliOyuncu, hedef = seciliOyuncu}) end
          end)

          function ctx.YaratikYenile()
               local v = V()
               if IsValid(oyuncular) then oyuncular:SetItems(v.oyuncular or {}, true) end
               if IsValid(liste) then liste:SetItems((v.hedef == seciliOyuncu) and (v.yaratiklar or {}) or {}, true) end
          end

          ctx.SetHead({
               note = function()
                    local v = V()
                    return (v.vivaryum or 0) .. " EN VIVERO  ·  " .. (v.takip or 0) .. " CERCA"
               end
          })

          oyuncular:SetItems(V().oyuncular or {})
          Y.Yonetim("veri", {})
     end
}

ShineAdmin = ShineAdmin or {}
ShineAdmin.Pages = ShineAdmin.Pages or {}
ShineAdmin.Pages.yaratik = sayfa

concommand.Add("sardon_yaratik_admin", function()
     if ShineAdmin and ShineAdmin.Open then ShineAdmin:Open("yaratik") end
end)
