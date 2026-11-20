-- "addons\\sardonportkey\\lua\\sardon_portkey\\cl_5shine.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Portkey :: Shine Admin › Portkey Ağı. Sekmeler: Hedefler (süperadmin düzenler), Satıcılar
-- (kalıcı; süperadmin), Etkinlik (çizme; yetkili), Açık Geçitler (yetkili). Sunucu tarafı sv_4admin.
-- Açmak: Shine Admin › Sistemler › Portkey Ağı ya da konsol "sardon_portkey_admin".

local P = SardonPortkey

P.AdminSurum = P.AdminSurum or 0

net.Receive("SardonPortkey.AdminVeri", function()
     local n = net.ReadUInt(16)
     P.AdminVeri = util.JSONToTable(util.Decompress(net.ReadData(n)) or "") or {}
     P.AdminSurum = P.AdminSurum + 1
end)

local function Iste(islem, arg)
     net.Start("SardonPortkey.Admin")
          net.WriteString(islem)
          net.WriteString(util.TableToJSON(arg or {}))
     net.SendToServer()
end
P.AdminIste = Iste

local function Veri() return P.AdminVeri or {} end

local function HedefBul(id)
     for _, h in ipairs(Veri().hedefler or {}) do
          if h.id == id then return h end
     end
end

local function HedefAd(id)
     local h = HedefBul(id)
     return h and h.name or tostring(id)
end

local HANE_SECIM = {"Sin restricción de casa", "Solo Gryffindor", "Solo Ravenclaw", "Solo Slytherin", "Solo Hufflepuff"}
local SECILI_ARKA = Color(201, 174, 119, 16)

-- Satır sonundaki tıklanabilir metin düğmeleri (sağdan sola, her biri 70 birim)
local function SatirDugmeleri(N, x, y, cw, ch, hx, dugmeler)
     local u = N.u
     for i, d in ipairs(dugmeler) do
          local sag = cw - u(70) * (i - 1)
          local ustunde = hx and hx > sag - u(70) and hx <= sag
          N.Text(d[1], "micro", x + sag - u(35), y + ch / 2, ustunde and N.Clr.gold or (d[2] or N.Clr.faint), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end
end

local function SatirDugmesi(N, relX, cw)
     local i = math.floor((cw - relX) / N.u(70)) + 1
     return relX > cw - N.u(70) * 3 and i or nil
end

local function Satir(N, x, y, cw, ch, secili, ustunde)
     N.Box(x, y, cw, ch, secili and SECILI_ARKA or N.Clr.toolBg)
     N.Outline(x, y, cw, ch, secili and N.Clr.gold or (ustunde and N.Clr.btnLine or N.Clr.toolLine), 1)
end

----------------------------------------------------------------------------------------
-- Hedefler
----------------------------------------------------------------------------------------
local secili

local function HedefDetay(N, kap, DW, DH, h, super)
     local u = N.u
     local f = {name = h.name, price = h.price or 0, hane = h.hane or 0, ic = h.ic and true or false, aktif = h.aktif ~= false,
          renk = h.renk or 1, zfar = h.zfar or (h.ic and 3000 or 8000)}

     local kart = vgui.Create("DPanel", kap)
     kart:SetPos(0, 0)
     kart:SetSize(u(DW), u(76))
     kart.Paint = function(s, w, hh)
          N.Box(0, 0, w, hh, N.Clr.toolBg)
          N.Outline(0, 0, w, hh, N.Clr.toolLine, 1)
          N.Text(h.name, "serif", u(16), u(12), N.Clr.text)
          local durum, renk
          if h.bozuk then
               durum, renk = "ROTO: " .. h.bozuk .. ". Hedefte durup “Mover donde estoy” ile düzelt.", N.Clr.bad
          elseif h.aktif == false then
               durum, renk = "Cerrado: no se vende ni abre con llave.", N.Clr.warn
          elseif h.uyari then
               durum, renk = "Funciona pero: " .. h.uyari .. ". Para corregir, colócate en el destino y mueve.", N.Clr.warn
          else
               durum, renk = "Válido: en vendedores y llaves.", N.Clr.ok
          end
          N.Text(N.Clip(durum, "tiny", w - u(32)), "tiny", u(16), u(46), renk)
          N.Text(string.format("%s  ·  %d, %d, %d  ·  rumbo %d°", h.id, h.x or 0, h.y or 0, h.z or 0, h.yaw or 0), "tiny", w - u(16), u(18), N.Clr.faint, TEXT_ALIGN_RIGHT)
     end

     if not super then
          local not_ = vgui.Create("DPanel", kap)
          not_:SetPos(0, u(90))
          not_:SetSize(u(DW), u(40))
          not_.Paint = function() N.Text("Solo superadmin edita destinos. «Ir allí» para todos.", "tiny", 0, u(10), N.Clr.rowDesc) end
          N.Button(kap, 0, u(136), u(200), u(36), "Ir allí", function() Iste("hedef.git", {id = h.id}) end)
          return
     end

     local y = 90
     local adW = math.floor(DW * 0.62)
     local adE = N.PlainEntry(kap, 0, u(y), u(adW), u(36), "Nombre visible", function(v) f.name = v end)
     adE:SetValue(h.name)
     local fiyatE = N.PlainEntry(kap, u(adW + 10), u(y), u(DW - adW - 10), u(36), "Fiyat (ʛ)", function(v) f.price = tonumber(v) or f.price end)
     fiyatE:SetValue(tostring(h.price or 0))

     y = y + 48
     local yarim = math.floor((DW - 10) / 2)
     N.Combo(kap, 0, u(y), u(yarim), u(36), HANE_SECIM[f.hane + 1], HANE_SECIM, function(_, _, i) f.hane = i - 1 end)
     local renkAdlari = {}
     for i, r in ipairs(P.Renkler) do renkAdlari[i] = "Renk: " .. r[1] end
     N.Combo(kap, u(yarim + 10), u(y), u(yarim), u(36), renkAdlari[f.renk] or renkAdlari[1], renkAdlari, function(_, _, i) f.renk = i end)

     y = y + 48
     N.Toggle(kap, 0, u(y), u(DW), u(50), "Interior", function() return f.ic end, function(v) f.ic = v end,
          "Niebla a distancia, no se dibuja cielo 3D (más barato). Desactivar en exteriores.")
     y = y + 52
     N.Toggle(kap, 0, u(y), u(DW), u(50), "Aktif", function() return f.aktif end, function(v) f.aktif = v end,
          "Destino cerrado: no se vende ni abre con llave; el registro permanece.")
     y = y + 60
     N.Slider(kap, 0, u(y), u(DW), "Distancia de visión (zfar, unidades)", 800, 16000, 0, function() return f.zfar end, function(v) f.zfar = v end)

     y = y + 66
     local bw = math.floor((DW - 30) / 4)
     N.Button(kap, 0, u(y), u(bw), u(36), "Guardar", function()
          Iste("hedef.kaydet", {id = h.id, name = f.name, price = f.price, hane = f.hane, ic = f.ic, aktif = f.aktif, renk = f.renk, zfar = math.floor(f.zfar)})
     end, "primary")
     N.Button(kap, u(bw + 10), u(y), u(bw), u(36), "Mover donde estoy", function()
          N.Confirm("Mover destino", h.name .. " se mueve a donde estás; los viajeros salen hacia donde miras.", "Mover", function()
               Iste("hedef.tasi", {id = h.id})
          end)
     end)
     N.Button(kap, u((bw + 10) * 2), u(y), u(bw), u(36), "Ir allí", function() Iste("hedef.git", {id = h.id}) end)
     N.Button(kap, u((bw + 10) * 3), u(y), u(bw), u(36), "Abrir portal de prueba", function() Iste("hedef.test", {id = h.id}) end)

     y = y + 46
     N.Button(kap, 0, u(y), u(bw), u(36), "Borrar", function()
          N.Confirm("Borrar destino", h.name .. " se borrará. Las llaves de este destino ya no abrirán; vendedores quedan huérfanos.", "Borrar", function()
               Iste("hedef.sil", {id = h.id})
               secili = nil
          end, true)
     end, "danger")

     local bilgi = vgui.Create("DPanel", kap)
     bilgi:SetPos(u(bw + 10), u(y))
     bilgi:SetSize(u(DW - bw - 10), u(44))
     bilgi.Paint = function()
          N.Text("Portal de prueba 10 s donde miras; no entra en registro del Ministerio.", "tiny", u(4), u(4), N.Clr.rowDesc)
          N.Text("Al mover, colócate en el destino y mira la salida (48 unidades libres delante).", "tiny", u(4), u(22), N.Clr.rowDesc)
     end
end

local function Hedefler(N, kok, W, H)
     local u = N.u
     local LW = 430
     local yeniId = ""

     local super = Veri().super
     if super then
          N.PlainEntry(kok, 0, 0, u(200), u(36), "nuevo id (ej. torre)", function(v) yeniId = string.lower(string.Trim(v)) end)
          N.Button(kok, u(208), 0, u(LW - 208), u(36), "Nuevo destino donde estoy", function()
               if yeniId == "" then return end
               Iste("hedef.kaydet", {id = yeniId, yeni = true})
               secili = yeniId
          end, "primary")
     end

     local listeY = super and 46 or 0
     local liste = N.VList(kok, 0, u(listeY), u(LW), u(H - listeY - (super and 46 or 0)), {
          rowH = u(58),
          emptyText = "Hedef yok.",
          onClick = function(h)
               secili = h.id
               kok.Detay(true)
          end,
          paintRow = function(h, _, x, y, cw, ch, ustunde)
               Satir(N, x, y, cw, ch, secili == h.id, ustunde)
               N.Text(N.Clip(h.name, "serif", cw - u(120)), "serif", x + u(14), y + u(9), N.Clr.text)
               N.Text(h.id .. "  ·  " .. (h.price or 0) .. " ʛ" .. (h.hane and ("  ·  " .. (P.HaneAd[h.hane] or "")) or "") .. (h.ic and "  ·  iç" or ""),
                    "tiny", x + u(14), y + u(36), N.Clr.rowDesc)
               local durum, renk = "VÁLIDO", N.Clr.ok
               if h.bozuk then durum, renk = "BOZUK", N.Clr.bad
               elseif h.aktif == false then durum, renk = "KAPALI", N.Clr.warn
               elseif h.uyari then durum, renk = "UYARI", N.Clr.warn end
               N.Text(durum, "micro", x + cw - u(14), y + u(14), renk, TEXT_ALIGN_RIGHT)
          end
     })

     if super then
          N.Button(kok, 0, u(H - 38), u(LW), u(36), "Revalidar todo", function() Iste("yenile") end)
     end

     local detay, detayImza
     function kok.Detay(zorla)
          local h = HedefBul(secili)
          local imza = h and util.TableToJSON(h) or ""
          if not zorla and imza == detayImza then return end
          detayImza = imza

          if IsValid(detay) then detay:Remove() end
          detay = vgui.Create("DPanel", kok)
          detay:SetPos(u(LW + 20), 0)
          detay:SetSize(u(W - LW - 20), u(H))
          detay.Paint = nil

          if not h then
               detay.Paint = function() N.Text("Elige un destino a la izquierda.", "body", 0, u(10), N.Clr.faint) end
               return
          end
          HedefDetay(N, detay, W - LW - 20, H, h, super)
     end

     kok.Yenile = function()
          liste:SetItems(Veri().hedefler or {}, true)
          kok.Detay(false)
     end
end

----------------------------------------------------------------------------------------
-- Satıcılar
----------------------------------------------------------------------------------------
local saticiHedef

local function HedefSecenekleri(ekNokta)
     local adlar, idler = {}, {}
     if ekNokta then
          adlar[1], idler[1] = "Punto de evento guardado", "_nokta"
     end
     for _, h in ipairs(Veri().hedefler or {}) do
          adlar[#adlar + 1] = h.name .. ((h.bozuk or h.aktif == false) and " (no disponible)" or "")
          idler[#idler + 1] = h.id
     end
     return adlar, idler
end

local function Saticilar(N, kok, W, H)
     local u = N.u
     local super = Veri().super

     local ust = 0
     if super then
          local adlar, idler = HedefSecenekleri(false)
          N.Combo(kok, 0, 0, u(320), u(36), saticiHedef and HedefAd(saticiHedef) or "Destino del vendedor…", adlar, function(_, _, i) saticiHedef = idler[i] end)
          N.Button(kok, u(330), 0, u(280), u(36), "Colocar vendedor donde apunto", function()
               Iste("satici.ekle", {hedef = saticiHedef})
          end, "primary")
          ust = 46
     end

     local not_ = vgui.Create("DPanel", kok)
     not_:SetPos(0, u(ust))
     not_:SetSize(u(W), u(30))
     not_.Paint = function()
          N.Text("Los vendedores guardados se colocan al cargar el mapa ve temizlikten sonra kendiliğinden kurulur. Physgun ile taşırsan yeni yeri, sağ tık › Portkey Hedefi ile hedefi kaydedilir.",
               "tiny", 0, u(6), N.Clr.rowDesc)
     end

     local liste = N.VList(kok, 0, u(ust + 36), u(W), u(H - ust - 36), {
          rowH = u(50),
          emptyText = "No hay vendedores guardados. Elle koyulan (kaydedilmemiş) satıcılar burada görünmez.",
          onClick = function(s, _, relX, _, cw)
               local d = SatirDugmesi(N, relX, cw)
               if d == 1 and super then
                    N.Confirm("Borrar vendedor", HedefAd(s.hedef) .. ": se quita el vendedor y su registro.", "Borrar", function()
                         Iste("satici.sil", {anahtar = s.anahtar})
                    end, true)
               elseif d == 2 then
                    Iste("satici.git", {anahtar = s.anahtar})
               end
          end,
          paintRow = function(s, _, x, y, cw, ch, ustunde, hx)
               Satir(N, x, y, cw, ch, false, ustunde)
               N.Text(HedefAd(s.hedef), "row", x + u(14), y + u(10), N.Clr.rowText)
               N.Text(string.format("%d, %d, %d", s.x, s.y, s.z), "tiny", x + u(14), y + u(30), N.Clr.rowDesc)
               SatirDugmeleri(N, x, y, cw, ch, hx, super and {{"BORRAR", N.Clr.bad}, {"IR"}} or {{""}, {"GİT"}})
          end
     })

     kok.Yenile = function() liste:SetItems(Veri().saticilar or {}, true) end
end

----------------------------------------------------------------------------------------
-- Etkinlik
----------------------------------------------------------------------------------------
local etkHedef, etkSure, etkAd = nil, 60, ""

local function Etkinlik(N, kok, W, H)
     local u = N.u
     local adlar, idler = HedefSecenekleri(true)
     local yarim = math.floor((W - 10) / 2)

     local not_ = vgui.Create("DPanel", kok)
     not_:SetPos(0, 0)
     not_:SetSize(u(W), u(46))
     not_.Paint = function()
          N.Text("Bota antigua: los jugadores se agarran con E, sayaç bitince tutunanların hepsi hedefe savrulur (halka düzeninde).", "tiny", 0, u(4), N.Clr.rowDesc)
          N.Text("Hedef kayıtlı bir hedef ya da önceden kaydettiğin bir nokta olabilir. Kaçış engelleri (kelepçe, düello, abluka, çatışma) geçerli.", "tiny", 0, u(22), N.Clr.rowDesc)
     end

     local y = 54
     N.PlainEntry(kok, 0, u(y), u(yarim), u(36), "Nombre del punto (ej. Copa Mundial de Quidditch)", function(v) etkAd = v end)
     N.Button(kok, u(yarim + 10), u(y), u(yarim), u(36), "Hacer de mi posición un punto de evento", function()
          Iste("etkinlik.nokta", {ad = etkAd})
     end)

     y = y + 44
     local nokta = vgui.Create("DPanel", kok)
     nokta:SetPos(0, u(y))
     nokta:SetSize(u(W), u(24))
     nokta.Paint = function()
          local n = Veri().nokta
          N.Text(n and string.format("Kayıtlı nokta: %s (%d, %d, %d)", n.ad, n.x, n.y, n.z) or "No tienes punto de evento guardado.", "tiny", 0, u(4), n and N.Clr.ok or N.Clr.faint)
     end

     y = y + 30
     N.Combo(kok, 0, u(y), u(yarim), u(36), etkHedef and (etkHedef == "_nokta" and adlar[1] or HedefAd(etkHedef)) or "Destino de la bota…", adlar,
          function(_, _, i) etkHedef = idler[i] end)
     N.Slider(kok, u(yarim + 10), u(y - 9), u(yarim), "Cuenta atrás (s)", 10, 600, 0, function() return etkSure end, function(v) etkSure = v end)

     y = y + 54
     N.Button(kok, 0, u(y), u(W), u(36), "Colocar bota donde apunto", function()
          Iste("etkinlik.kur", {hedef = etkHedef, sure = math.floor(etkSure)})
     end, "primary")

     y = y + 50
     N.SectionLabel("Botas en espera", 0, u(y), u(W), "star")
     local liste = N.VList(kok, 0, u(y + 24), u(W), u(H - y - 24), {
          rowH = u(46),
          emptyText = "No hay botas en espera.",
          onClick = function(e, _, relX, _, cw)
               if SatirDugmesi(N, relX, cw) == 1 then Iste("etkinlik.iptal", {idx = e.idx}) end
          end,
          paintRow = function(e, _, x, yy, cw, ch, ustunde, hx)
               Satir(N, x, yy, cw, ch, false, ustunde)
               N.Text(e.ad, "row", x + u(14), yy + u(8), N.Clr.rowText)
               N.Text(e.sure .. " s restantes  ·  " .. e.tutunan .. " personas agarradas", "tiny", x + u(14), yy + u(27), N.Clr.rowDesc)
               SatirDugmeleri(N, x, yy, cw, ch, hx, {{"CANCELAR", N.Clr.bad}})
          end
     })

     kok.Yenile = function() liste:SetItems(Veri().etkinlikler or {}, true) end
     kok.Canli = true
end

----------------------------------------------------------------------------------------
-- Açık geçitler
----------------------------------------------------------------------------------------
local function AcikGecitler(N, kok, W, H)
     local u = N.u

     N.Button(kok, 0, 0, u(220), u(36), "Hepsini kapat", function()
          N.Confirm("Cerrar todos los portales", "Todos los portales abiertos se cierran al instante; içinden geçmekte olan yoktur, kimse zarar görmez.", "Cerrar", function()
               Iste("portal.hepsi")
          end, true)
     end, "danger")

     local liste = N.VList(kok, 0, u(46), u(W), u(H - 46), {
          rowH = u(50),
          emptyText = "No hay portales abiertos.",
          onClick = function(p, _, relX, _, cw)
               if SatirDugmesi(N, relX, cw) == 1 then Iste("portal.kapat", {idx = p.idx}) end
          end,
          paintRow = function(p, _, x, y, cw, ch, ustunde, hx)
               Satir(N, x, y, cw, ch, false, ustunde)
               N.Text(p.acan .. "  →  " .. HedefAd(p.hedef) .. (p.test and "  (test)" or ""), "row", x + u(14), y + u(9), N.Clr.rowText)
               N.Text(string.format("%d sn  ·  %d/%d yer  ·  %d viajeros pasaron", p.sure, p.kalan, p.kapasite, p.yolcu), "tiny", x + u(14), y + u(29), N.Clr.rowDesc)
               SatirDugmeleri(N, x, y, cw, ch, hx, {{"KAPAT", N.Clr.bad}})
          end
     })

     kok.Yenile = function() liste:SetItems(Veri().portallar or {}, true) end
     kok.Canli = true
end

----------------------------------------------------------------------------------------
-- Sayfa
----------------------------------------------------------------------------------------
local SEKMELER = {{"hedefler", "Destinos"}, {"saticilar", "Vendedores"}, {"etkinlik", "Evento"}, {"acik", "Portales abiertos"}}
local KURUCU = {hedefler = Hedefler, saticilar = Saticilar, etkinlik = Etkinlik, acik = AcikGecitler}
local sekme = "hedefler"

local function Kaydet()
     if not ShineAdmin or not ShineAdmin.RegisterPage or not ShineAdmin.GetN then return false end

     ShineAdmin:RegisterPage("portkey", {
          label = "Red de Portkeys",
          icon = "lightning",
          group = "systems",
          order = 46,
          title = "Red de Portkeys",
          subtitle = "Destinos de portales y validación, vendedores permanentes, mapa de eventos y portales abiertos.",
          access = "staff",

          build = function(ctx)
               local N = ShineAdmin.GetN()
               local u = N.u
               local Pn, W, H = ctx.panel, ctx.w, ctx.h
               if KURUCU[ctx.arg or ""] then sekme = ctx.arg end

               local kok
               local function Kur()
                    if IsValid(kok) then kok:Remove() end
                    kok = vgui.Create("DPanel", Pn)
                    kok:SetPos(0, u(56))
                    kok:SetSize(u(W), u(H - 56))
                    kok.Paint = nil
                    kok.surum = -1
                    kok.istek = 0
                    kok.super = Veri().super and true or false
                    KURUCU[sekme](N, kok, W, H - 56)

                    kok.Think = function(s)
                         -- yetki bilgisi ilk veriyle gelir; değişirse düzen (süperadmin düğmeleri) yeniden kurulur
                         if (Veri().super and true or false) ~= s.super then
                              Kur()
                              return
                         end
                         if s.surum ~= P.AdminSurum then
                              s.surum = P.AdminSurum
                              if s.Yenile then s.Yenile() end
                         end
                         if s.Canli and RealTime() > s.istek then
                              s.istek = RealTime() + 2
                              Iste("durum")
                         end
                    end
               end

               N.SubTabs(Pn, 0, 0, u(W), SEKMELER, function() return sekme end, function(id)
                    sekme = id
                    Kur()
               end)

               Iste("durum")
               Kur()

               return function() Iste("durum") end
          end,
     })
     return true
end

if not Kaydet() then
     timer.Create("SardonPortkey.Shine", 2, 30, function()
          if Kaydet() then timer.Remove("SardonPortkey.Shine") end
     end)
end

concommand.Add("sardon_portkey_admin", function()
     if ShineAdmin and ShineAdmin.Open then ShineAdmin:Open("portkey") end
end)
