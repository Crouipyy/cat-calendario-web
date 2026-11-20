-- "addons\\sardonollivander\\lua\\sardon_ollivander\\cl_6yonetim.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Shine Admin › Ollivanders. Sekmeler: Genel (ayarlar), Asalar (kayıtlar), Oyuncular (çevrimiçi:
*   kanon/etkinlik asası ver, kart, sil), Dükkân (noktaları taşı, ızgara, test), Seslendirme
*   (hangi ses dosyaları var), Defter (Ollivander'ın kayıtları). Sunucu tarafı sv_8yonetim.
*   Açmak: Shine Admin › Sistemler › Ollivanders ya da konsol "sardon_ollivander_admin".
*/
local O = SardonOli

O.YVeri = O.YVeri or {}
O.YSurum = O.YSurum or 0

net.Receive("SardonOli.YonetimVeri", function()
     local n = net.ReadUInt(32)
     O.YVeri = util.JSONToTable(util.Decompress(net.ReadData(n)) or "") or {}
     O.YSurum = O.YSurum + 1
end)

local function Iste(islem, arg)
     net.Start("SardonOli.Yonetim")
     net.WriteString(islem)
     net.WriteString(util.TableToJSON(arg or {}))
     net.SendToServer()
end

local function Tarih(t)
     return t and os.date("%d.%m %H:%M", t) or ""
end

local SEKMELER = { { "genel", "General" }, { "asalar", "Varitas" }, { "oyuncular", "Jugadores" }, { "dukkan", "Tienda" }, { "ses", "Locución" }, { "defter", "Cuaderno" } }
local sekme = "genel"

local KURUCU = {}

KURUCU.genel = function(N, kok, W, H)
     local u = N.u
     -- ayarlar sayfaya sığmayınca kaydırılır
     kok = N.Scroll(kok, 0, 0, u(W), u(H))
     W = W - 14
     local V = O.YVeri
     local f = table.Copy(V.ayar or O.Ayar)
     local y = 0
     local yarim = math.floor((W - 20) / 2)

     local bilgi = vgui.Create("DPanel", kok)
     bilgi:SetPos(0, 0)
     bilgi:SetSize(u(W), u(64))
     bilgi.Paint = function(s, w, h)
          N.Box(0, 0, w, h, N.Clr.toolBg)
          N.Outline(0, 0, w, h, N.Clr.toolLine, 1)
          local v = O.YVeri
          N.Text("Varita registrada: " .. #(v.asalar or {}) .. "   ·   Ceremonias en curso: " .. (v.seremoni or 0) .. "   ·   En cola: " .. (v.sira or 0), "small", u(16), u(12), N.Clr.text)
          N.Text("Rejilla de desfile: " .. ((v.izgara or 0) > 0 and ((v.izgara) .. " paradas de estante listas") or "no configurada (sin tienda en el mapa o apertura en curso)"), "tiny", u(16), u(38), (v.izgara or 0) > 0 and N.Clr.ok or N.Clr.warn)
     end
     y = 76
     N.Toggle(kok, 0, u(y), u(yarim), u(50), "Ceremonia activa", function() return f.seremoniAcik end, function(v) f.seremoniAcik = v end, "Desactivada: Ollivander no prueba varitas nuevas; quien tenga varita puede ver su carta.")
     N.Toggle(kok, u(yarim + 20), u(y), u(yarim), u(50), "Modo personal", function() return f.eszamanli == "kisisel" end, function(v) f.eszamanli = v and "kisisel" or "sira" end, "Activo: cada visitante ve su Ollivander. Inactivo: un solo Ollivander + cola.")
     y = y + 62
     N.Slider(kok, 0, u(y), u(yarim), "Desbordamiento de cola (copia personal tras tantas personas)", 1, 8, 0, function() return f.siraTasma end, function(v) f.siraTasma = math.Round(v) end)
     N.Slider(kok, u(yarim + 20), u(y), u(yarim), "Multiplicador de poder (0 = varita solo identidad)", 0, 2, 2, function() return f.gucCarpani end, function(v) f.gucCarpani = math.Round(v, 2) end)
     y = y + 66
     N.Slider(kok, 0, u(y), u(yarim), "Penalización daño segunda varita (%)", 0, 30, 0, function() return f.ikinciCeza end, function(v) f.ikinciCeza = math.Round(v) end)
     N.Slider(kok, u(yarim + 20), u(y), u(yarim), "Multiplicador velocidad de afinidad", 0.2, 3, 2, function() return f.uyumHiz end, function(v) f.uyumHiz = math.Round(v, 2) end)
     y = y + 66
     N.Toggle(kok, 0, u(y), u(yarim), u(50), "La varita puede astillarse / romperse", function() return f.kirilma ~= false end, function(v) f.kirilma = v end, "Desactivado: no se astillan ni retroceden; una rota sigue lanzando hechizos.")
     N.Toggle(kok, u(yarim + 20), u(y), u(yarim), u(50), "Encastre de varitas hermanas", function() return f.kardesKenet ~= false end, function(v) f.kardesKenet = v end, "Varitas con pluma del mismo ancestro: Priori Incantatem; nadie gana.")
     y = y + 62
     N.Slider(kok, 0, u(y), u(yarim), "Probabilidad de astillado al perder encastre (%)", 0, 50, 0, function() return f.catlamaSans or 10 end, function(v) f.catlamaSans = math.Round(v) end)
     N.Slider(kok, u(yarim + 20), u(y), u(yarim), "Probabilidad de retroceso con varita astillada (%)", 0, 30, 0, function() return f.geriTepme or 7 end, function(v) f.geriTepme = math.Round(v) end)
     y = y + 70

     local etiket = vgui.Create("DPanel", kok)
     etiket:SetPos(0, u(y))
     etiket:SetSize(u(W), u(22))
     etiket.Paint = function() N.Text("PRECIOS (GALEONES) Y PESOS DE ESTRELLAS EN CEREMONIA", "micro", 0, u(4), N.Clr.gold) end
     y = y + 26
     local hw = math.floor((W - 40) / 5)
     for i = 1, 5 do
          local e = N.PlainEntry(kok, u((hw + 10) * (i - 1)), u(y), u(hw), u(34), O.YildizAd(i) .. " precio", function(v) f.fiyat[i] = tonumber(v) or f.fiyat[i] end)
          e:SetValue(tostring(f.fiyat[i] or 0))
     end
     y = y + 42
     for i = 1, 4 do
          local e = N.PlainEntry(kok, u((hw + 10) * (i - 1)), u(y), u(hw), u(34), O.YildizAd(i) .. " peso", function(v) f.agirlik[i] = tonumber(v) or f.agirlik[i] end)
          e:SetValue(tostring(f.agirlik[i] or 0))
     end
     local not_ = vgui.Create("DPanel", kok)
     not_:SetPos(u((hw + 10) * 4), u(y))
     not_:SetSize(u(hw), u(34))
     not_.Paint = function() N.Text("No sale de ceremonia mítica", "tiny", u(4), u(10), N.Clr.rowDesc) end
     y = y + 50
     N.Button(kok, 0, u(y), u(220), u(38), "Guardar", function() Iste("ayar", f) end, "primary")
end

local function SatirKutu(N, x, y, w, h, ustunde)
     N.Box(x, y, w, h, ustunde and N.Clr.cardHover or N.Clr.toolBg)
     N.Outline(x, y, w, h, ustunde and N.Clr.btnLine or N.Clr.toolLine, 1)
end

KURUCU.asalar = function(N, kok, W, H)
     local u = N.u
     local liste = N.Scroll(kok, 0, 0, u(W), u(H - 10))
     local function Doldur()
          liste:Clear()
          for _, a in ipairs(O.YVeri.asalar or {}) do
               local satir = vgui.Create("DPanel", liste)
               satir:Dock(TOP)
               satir:DockMargin(0, 0, u(8), u(6))
               satir:SetTall(u(54))
               satir.Paint = function(s, w, h)
                    SatirKutu(N, 0, 0, w, h, s:IsHovered())
                    local y = O.Yildiz[a.yildiz or 1] or O.Yildiz[1]
                    N.Box(0, 0, u(4), h, y.renk)
                    local agac = O.Agac[a.agac or ""]
                    local oz = O.Oz[a.oz or ""]
                    N.Text((a.ad or "?") .. (a.cevrimici and "   ●" or ""), "small", u(16), u(8), a.cevrimici and N.Clr.ok or N.Clr.text)
                    N.Text((a.seri or "") .. "  ·  " .. (agac and agac.ad or "?") .. " / " .. (oz and oz.kisa or "?") .. "  ·  " .. (a.c4 and O.IncYazi(a.c4) or "") .. "  ·  " .. y.ad .. "  ·  uyum %" .. (a.uyum or 0) .. (a.odendi and "" or "  ·  SE FUE") .. ((a.durum and a.durum ~= "saglam") and ("  ·  " .. O.Buyuk(O.DurumAd[a.durum] or a.durum)) or "") .. (a.sadakatAd and ("  ·  lealtad: " .. a.sadakatAd) or ""), "tiny", u(16), u(32), N.Clr.rowDesc)
               end
               local bw = u(96)
               local SONRAKI = { saglam = "catlak", catlak = "kirik", kirik = "saglam" }
               N.Button(satir, u(W) - bw * 4 - u(36), u(10), bw, u(34), O.DurumAd[a.durum or "saglam"] or "Íntegra", function()
                    local yeni = SONRAKI[a.durum or "saglam"] or "saglam"
                    N.Confirm("Estado de la varita", (a.ad or "?") .. ": " .. (O.DurumAd[a.durum or "saglam"] or "?") .. " → " .. O.DurumAd[yeni], "Cambiar", function() Iste("asa.durum", { charid = a.charid, durum = yeni }) end)
               end)
               N.Button(satir, u(W) - bw * 3 - u(30), u(10), bw, u(34), "Carta", function() Iste("kart", { charid = a.charid, userid = a.userid }) end)
               N.Button(satir, u(W) - bw * 2 - u(24), u(10), bw, u(34), "Borrar destino", function()
                    N.Confirm("Borrar destino", (a.ad or "?") .. ": en la próxima ceremonia volverá a tirar el destino. La varita se mantiene.", "Borrar", function() Iste("kader.sil", { charid = a.charid, userid = a.userid }) end)
               end)
               N.Button(satir, u(W) - bw - u(18), u(10), bw, u(34), "Borrar", function()
                    N.Confirm("Borrar varita", "Se borrará la varita (y el destino) del personaje " .. (a.ad or "?") .. ".", "Borrar", function() Iste("asa.sil", { charid = a.charid, userid = a.userid, kader = true }) end, true)
               end, "danger")
          end
     end
     Doldur()
     kok.Yenile = Doldur
end

KURUCU.oyuncular = function(N, kok, W, H)
     local u = N.u
     local secenekler, idler = {}, {}
     for _, s in ipairs(O.Sablonlar) do
          if s.sinif ~= "dukkan" then
               secenekler[#secenekler + 1] = s.id .. "  (" .. s.sinif .. ", " .. O.YildizAd(s.yildiz) .. ")"
               idler[#idler + 1] = s.id
          end
     end
     local secili = idler[1]
     N.Combo(kok, 0, 0, u(W * 0.6), u(36), secenekler[1] or "", secenekler, function(_, _, i) secili = idler[i] end)
     local bilgi = vgui.Create("DPanel", kok)
     bilgi:SetPos(u(W * 0.6 + 12), 0)
     bilgi:SetSize(u(W * 0.4 - 12), u(36))
     bilgi.Paint = function() N.Text("Usa la plantilla seleccionada con «Dar varita».", "tiny", u(4), u(12), N.Clr.rowDesc) end

     local liste = N.Scroll(kok, 0, u(48), u(W), u(H - 58))
     local function Doldur()
          liste:Clear()
          for _, p in ipairs(O.YVeri.oyuncular or {}) do
               local satir = vgui.Create("DPanel", liste)
               satir:Dock(TOP)
               satir:DockMargin(0, 0, u(8), u(6))
               satir:SetTall(u(50))
               satir.Paint = function(s, w, h)
                    SatirKutu(N, 0, 0, w, h, s:IsHovered())
                    N.Text(p.ad or "?", "small", u(16), u(8), N.Clr.text)
                    N.Text((p.asa and "Tiene varita" or "Sin varita") .. "  ·  " .. (p.kader and "destino tirado" or "sin destino"), "tiny", u(16), u(30), p.asa and N.Clr.ok or N.Clr.rowDesc)
               end
               local bw = u(100)
               N.Button(satir, u(W) - bw * 3 - u(30), u(8), bw, u(34), "Dar varita", function() Iste("asa.ver", { userid = p.userid, sablon = secili }) end, "primary")
               N.Button(satir, u(W) - bw * 2 - u(24), u(8), bw, u(34), "Carta", function() Iste("kart", { userid = p.userid }) end)
               N.Button(satir, u(W) - bw - u(18), u(8), bw, u(34), "Borrar varita", function()
                    N.Confirm("Borrar varita", "Se borrarán la varita y el destino del personaje " .. (p.ad or "?") .. ".", "Borrar", function() Iste("asa.sil", { userid = p.userid, kader = true }) end, true)
               end, "danger")
          end
     end
     Doldur()
     kok.Yenile = Doldur
end

KURUCU.dukkan = function(N, kok, W, H)
     local u = N.u
     local not_ = vgui.Create("DPanel", kok)
     not_:SetPos(0, 0)
     not_:SetSize(u(W), u(84))
     not_.Paint = function(s, w, h)
          N.Box(0, 0, w, h, N.Clr.toolBg)
          N.Outline(0, 0, w, h, N.Clr.toolLine, 1)
          N.Text("Para mover un punto, colócate allí y mira bien; «Caja» se mueve donde miras (mira el mostrador).", "tiny", u(16), u(14), N.Clr.rowDesc)
          N.Text("Las paradas de estante vienen de los props del mapa; no hace falta moverlas. Si cambiaste la rejilla, reconfigúrala.", "tiny", u(16), u(36), N.Clr.rowDesc)
          N.Text("Mapa: " .. (O.YVeri.harita or game.GetMap()), "tiny", u(16), u(58), N.Clr.faint)
     end
     local adlar = { { "tezgah", "Mostrador (Ollivander)" }, { "musteri", "Cliente" }, { "giris", "Entrada (aparición)" }, { "kutu", "Caja (sobre mostrador)" }, { "cekmece", "Cajón" } }
     local bw = math.floor((W - 40) / 3)
     for i, n in ipairs(adlar) do
          local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
          N.Button(kok, u((bw + 20) * col), u(100 + row * 48), u(bw), u(38), n[2] .. ": mover aquí", function() Iste("nokta", { ad = n[1] }) end)
     end
     N.Button(kok, 0, u(210), u(bw), u(38), "Reconfigurar rejilla", function() Iste("izgara") end)
     N.Button(kok, u(bw + 20), u(210), u(bw * 2 + 20), u(38), "Prueba: borrar mi varita y destino", function()
          N.Confirm("Ceremonia de prueba", "Se borran tu varita y destino; al pulsar E en Ollivander la ceremonia empieza de nuevo.", "Borrar y empezar", function() Iste("test") end, true)
     end, "danger")
end

KURUCU.ses = function(N, kok, W, H)
     local u = N.u
     local ust = vgui.Create("DPanel", kok)
     ust:SetPos(0, 0)
     ust:SetSize(u(W), u(46))
     ust.Paint = function(s, w, h)
          local var, top = 0, 0
          for _, x in ipairs(O.YVeri.sesler or {}) do top = top + 1 if x.var then var = var + 1 end end
          N.Text("Guardados: " .. var .. " / " .. top .. "   ·   klasör: data/sardon_gorev/sesler/ollivander/", "small", 0, u(6), N.Clr.text)
          N.Text("Sin audio solo subtítulos. Con las cuatro partes del paquete de palabras, Ollivander lee la identidad de la varita en voz.", "tiny", 0, u(28), N.Clr.rowDesc)
     end
     local liste = N.Scroll(kok, 0, u(52), u(W), u(H - 62))
     local function Doldur()
          liste:Clear()
          for _, x in ipairs(O.YVeri.sesler or {}) do
               local satir = vgui.Create("DPanel", liste)
               satir:Dock(TOP)
               satir:DockMargin(0, 0, u(8), u(3))
               satir:SetTall(u(34))
               satir.Paint = function(s, w, h)
                    N.Box(0, 0, w, h, N.Clr.toolBg)
                    N.Box(0, 0, u(4), h, x.var and N.Clr.ok or N.Clr.bad)
                    N.Text(x.yol, "tiny", u(14), u(4), N.Clr.monoText)
                    N.Text(N.Clip(x.metin or "", "tiny", w - u(30)), "tiny", u(14), u(18), N.Clr.rowDesc)
               end
          end
     end
     Doldur()
     kok.Yenile = Doldur
end

local OLAY = { satis = "Venta", ayrildi = "Se fue (sin dinero)", kader = "Destino tirado", seremoni_basladi = "Ceremonia iniciada", seremoni_bitti = "Ceremonia terminada",
     verildi = "Lo dio la administración", sifirlandi = "Reiniciado", asa_silindi = "Varita borrada", kader_silindi = "Destino borrado" }

KURUCU.defter = function(N, kok, W, H)
     local u = N.u
     local liste = N.Scroll(kok, 0, 0, u(W), u(H - 10))
     local function Doldur()
          liste:Clear()
          for _, d in ipairs(O.YVeri.defter or {}) do
               local satir = vgui.Create("DPanel", liste)
               satir:Dock(TOP)
               satir:DockMargin(0, 0, u(8), u(3))
               satir:SetTall(u(34))
               local veri = util.JSONToTable(d.veri or "") or {}
               local ozet = {}
               for k, v in SortedPairs(veri) do ozet[#ozet + 1] = k .. "=" .. tostring(v) end
               satir.Paint = function(s, w, h)
                    N.Box(0, 0, w, h, N.Clr.toolBg)
                    N.Text(Tarih(d.zaman) .. "   #" .. tostring(d.charid) .. "   " .. (OLAY[d.olay] or d.olay), "tiny", u(12), u(4), N.Clr.text)
                    N.Text(N.Clip(table.concat(ozet, "  "), "tiny", w - u(24)), "tiny", u(12), u(18), N.Clr.rowDesc)
               end
          end
     end
     Doldur()
     kok.Yenile = Doldur
end

local function Kaydet()
     if not ShineAdmin or not ShineAdmin.RegisterPage or not ShineAdmin.GetN then return false end
     ShineAdmin:RegisterPage("ollivander", {
          label = "Ollivanders",
          icon = "wand",
          group = "systems",
          order = 47,
          title = "Ollivanders",
          subtitle = "Ceremonia de varitas, varitas registradas, entrega canónica, puntos de tienda y estado de locución.",
          access = "staff",
          build = function(ctx)
               local N = ShineAdmin.GetN()
               local u = N.u
               local Pn, W, H = ctx.panel, ctx.w, ctx.h
               local kok
               local function Kur()
                    if IsValid(kok) then kok:Remove() end
                    kok = vgui.Create("DPanel", Pn)
                    kok:SetPos(0, u(56))
                    kok:SetSize(u(W), u(H - 56))
                    kok.Paint = nil
                    kok.surum = O.YSurum
                    KURUCU[sekme](N, kok, W, H - 56)
                    kok.Think = function(s)
                         if s.surum ~= O.YSurum then
                              s.surum = O.YSurum
                              if sekme == "genel" then Kur() return end
                              if s.Yenile then s.Yenile() end
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
     timer.Create("SardonOli.Shine", 2, 30, function() if Kaydet() then timer.Remove("SardonOli.Shine") end end)
end

concommand.Add("sardon_ollivander_admin", function()
     if ShineAdmin and ShineAdmin.Open then ShineAdmin:Open("ollivander") end
end)
