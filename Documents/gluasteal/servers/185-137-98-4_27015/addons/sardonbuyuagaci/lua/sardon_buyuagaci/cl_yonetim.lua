-- "addons\\sardonbuyuagaci\\lua\\sardon_buyuagaci\\cl_yonetim.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Büyü Ağacı :: Shine Admin sayfası "buyuagaci" (yalnızca süper admin)
--
--   Büyü Maliyetleri  :: kademe başına predeterminado puan, hechizos başına özel puan, hechizosyü ağaçta kapatma
--   Ders Puanları     :: predeterminado ders puanı, katılım oranı, en kısa ders, ders başına özel puan
--   Kademe Kilitleri  :: Temel..Feci Yorucu kilidinin Karakter Gelişimi koşulu, ağaç → gelişim dalı bağı
--   Oyuncular         :: çevrimiçi oyuncuya puan ver / al, ağacı sıfırla
--
-- İlk üç sekme ortak bir taslağı düzenler; "Guardar" sunucuya gönderir (sunucu yeniden süzer,
-- data/sardon_buyuagaci/ayar.json'a yazar ve herkese dağıtır).

local BA = SardonBuyuAgaci

BA.YonetimOyuncu = BA.YonetimOyuncu or nil

local function Istek(islem, yaz)
     net.Start("SardonBuyuAgaci.Yonetim")
          net.WriteString(islem)
          if (yaz) then yaz() end
     net.SendToServer()
end

net.Receive("SardonBuyuAgaci.YonetimVeri", function()
     local ent = net.ReadEntity()
     local var = net.ReadBool()
     local v = {ent = ent, var = var}

     if (var) then
          v.ad = net.ReadString()
          v.k = net.ReadUInt(16)
          v.h = net.ReadUInt(16)
          v.acilan = net.ReadTable()
     end

     BA.YonetimOyuncu = v

     local ctx = ShineAdmin and ShineAdmin.ActiveCtx and ShineAdmin:ActiveCtx("buyuagaci")
     if (ctx and ctx.OyuncuYenile) then ctx.OyuncuYenile() end
end)

local function Esit(a, b)
     if (type(a) != type(b)) then return false end
     if (!istable(a)) then return a == b end
     for k, v in pairs(a) do if (!Esit(v, b[k])) then return false end end
     for k in pairs(b) do if (a[k] == nil) then return false end end
     return true
end

local function GelisimKategorileri()
     local out = {}
     for _, k in ipairs(SardonGelisim and SardonGelisim.Kategoriler or {}) do
          out[#out + 1] = {id = k.id, ad = k.ad}
     end
     return out
end

local function GelisimAd(id)
     for _, k in ipairs(GelisimKategorileri()) do
          if (k.id == id) then return k.ad end
     end
     return id or "—"
end

local sayfa = {
     id = "buyuagaci",
     label = "Árbol de hechizos",
     icon = "star",
     group = "magic",
     order = 35,
     title = "Árbol de hechizos",
     subtitle = "Coste en puntos de los hechizos del árbol, Puntos de Hechizo de las clases y bloqueos por nivel.",
     access = "superadmin",
     available = function() return SardonBuyuAgaci and SardonBuyuAgaci.Agaclar and #SardonBuyuAgaci.Agaclar > 0 end,

     build = function(ctx)
          local N = ShineAdmin.GetN()
          local u = N.u
          local P = ctx.panel
          local W, H = ctx.w, ctx.h

          if (!BA.AyarGeldi and BA.AyarIste) then BA.AyarIste() end

          local taslak = table.Copy(BA.Ayar)
          local aktif = ctx.arg and ctx.arg.sekme or "maliyet"
          local govde

          local function Degisti()
               return !Esit(taslak, BA.Ayar)
          end

          local SEKMELER = {
               {"maliyet", "Costes de hechizos"},
               {"ders", "Puntos de clase"},
               {"kilit", "Bloqueos por nivel"},
               {"denge", "Balance de ramas"},
               {"oyuncu", "Jugadores"}
          }

          local SekmeKur

          N.SubTabs(P, 0, 0, u(W), SEKMELER, function() return aktif end, function(id)
               if (aktif == id) then return end
               aktif = id
               SekmeKur()
          end)

          local GY = 56 -- gövde üstü
          local GH = H - GY

          /*
          *   ortak alt şerit (ilk üç sekme)
          */

          local function KaydetSeridi(parent, ph)
               local bar = N.StickyBar(parent, 0, u(ph - 52), u(W), function()
                    if (Degisti()) then return "Hay cambios sin guardar. Al pulsar Guardar se aplican a todos.", N.Clr.warn end
                    return "Los ajustes coinciden con el servidor."
               end)

               local kaydet = N.Button(bar, u(W) - u(150), u(8), u(150), u(36), "Guardar", function()
                    Istek("kaydet", function() net.WriteTable(taslak) end)
                    ctx.Flash("Ajustes del árbol de hechizos guardados.")
               end, "primary")
               kaydet.Think = function(s) s:SetEnabled(Degisti()) end

               local geri = N.Button(bar, u(W) - u(150) - u(8) - u(130), u(8), u(130), u(36), "Deshacer", function()
                    taslak = table.Copy(BA.Ayar)
                    SekmeKur()
               end)
               geri.Think = function(s) s:SetEnabled(Degisti()) end

               N.Button(bar, u(W) - u(150) - u(8) - u(130) - u(8) - u(170), u(8), u(170), u(36), "Restaurar valores", function()
                    N.Confirm("Restaurar valores", "Todos los costes, puntos de clase y bloqueos vuelven al predeterminado; no se envía al servidor hasta Guardar.", "Restaurar", function()
                         taslak = BA.AyarTemizle(table.Copy(BA.Varsayilan))
                         SekmeKur()
                    end, true)
               end, "quiet")

               return bar
          end

          /*
          *   sekme :: hechizos maliyetleri
          */

          local function MaliyetKur(G, gh)
               local colW = math.floor((W - 4 * 10) / 5)
               for i, k in ipairs(BA.Kademeler) do
                    N.Slider(G, u((i - 1) * (colW + 10)), 0, u(colW), k.roma .. " · " .. k.kisa .. " (predeterminado)", 0, 50, 0,
                         function() return taslak.kademeMaliyet[i] end,
                         function(v) taslak.kademeMaliyet[i] = math.floor(v) end)
               end

               local LIST_W = W - 360
               local ust = 66
               local arama, agacFiltre = "", nil
               local secili
               local liste, detay

               local function Satirlar()
                    local out = {}
                    for _, agac in ipairs(BA.Agaclar) do
                         if (!agacFiltre or agacFiltre == agac.id) then
                              for _, d in ipairs(agac.dugumler) do
                                   if (arama == "" or string.find(string.lower(d.buyu), arama, 1, true)) then
                                        out[#out + 1] = {d = d, agac = agac}
                                   end
                              end
                         end
                    end
                    return out
               end

               local function Yenile()
                    if (IsValid(liste)) then liste:SetItems(Satirlar(), true) end
               end

               N.TextEntry(G, 0, u(ust), u(LIST_W - 230), u(36), "Buscar hechizo", function(v)
                    arama = string.lower(string.Trim(v or ""))
                    Yenile()
               end)

               local secenek = {"Todos los árboles"}
               for _, a in ipairs(BA.Agaclar) do secenek[#secenek + 1] = a.ad end
               N.Combo(G, u(LIST_W - 220), u(ust), u(210), u(36), "Todos los árboles", secenek, function(_, _, i)
                    agacFiltre = i > 1 and BA.Agaclar[i - 1].id or nil
                    Yenile()
               end)

               local hy = ust + 46
               local head = vgui.Create("DPanel", G)
               head:SetPos(0, u(hy))
               head:SetSize(u(LIST_W), u(30))
               head.Paint = function(s, w, h)
                    N.TableHead(0, 0, w, {
                         {"Hechizo", u(16)},
                         {"Árbol › rama", u(250)},
                         {"Nivel", w - u(250)},
                         {"Puntos", w - u(120)},
                         {"Durum", w - u(24), TEXT_ALIGN_RIGHT}
                    })
               end

               liste = N.VList(G, 0, u(hy + 30), u(LIST_W), u(gh - hy - 30 - 64), {
                    rowH = u(34),
                    gapY = 0,
                    emptyText = "No se encontró el hechizo.",
                    onClick = function(r)
                         secili = r.d.buyu
                         if (IsValid(detay)) then detay.Kur() end
                    end,
                    paintRow = function(r, i, x, y, w, h, hovered)
                         local d = r.d
                         local on = secili == d.buyu
                         if (on) then
                              N.Box(x, y, w, h, N.Clr.selRow)
                              N.Box(x, y, u(2), h, N.Clr.gold)
                         elseif (hovered) then
                              N.Box(x, y, w, h, N.Clr.hoverRow)
                         end
                         N.Box(x, y + h - 1, w, 1, N.Clr.tableLine)

                         local var = BA.BuyuVar(d.buyu)
                         local ozel = taslak.maliyet[d.buyu]
                         local kapali = taslak.kapali[d.buyu]
                         local puan = ozel or taslak.kademeMaliyet[d.kademe]

                         N.Text(N.Clip(d.buyu, "row", u(220)), "row", x + u(16), y + h / 2, var and N.Clr.tdFirst or N.Clr.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(N.Clip(r.agac.ad .. " › " .. (r.agac.dallar[d.dal] or ""), "small", w - u(250) - u(260)), "small", x + u(250), y + h / 2, N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(BA.Kademeler[d.kademe].roma .. " · " .. BA.Kademeler[d.kademe].kisa, "small", x + w - u(250), y + h / 2, N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(tostring(puan), "strong", x + w - u(120), y + h / 2, ozel and N.Clr.gold or N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                         local dur, dc = "predeterminado", N.Clr.faint
                         if (!var) then dur, dc = "sunucuda yok", N.Clr.bad
                         elseif (kapali) then dur, dc = "cerrado", N.Clr.bad
                         elseif (ozel) then dur, dc = "özel", N.Clr.badgeText end
                         N.Text(dur, "tiny", x + w - u(24), y + h / 2, dc, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    end
               })

               -- sağ: seçili hechizos
               detay = vgui.Create("DPanel", G)
               detay:SetPos(u(LIST_W + 20), u(ust))
               detay:SetSize(u(340), u(gh - ust - 64))
               detay.Paint = function() end

               function detay.Kur()
                    detay:Clear()
                    local d = secili and BA.Dugum(secili)

                    if (!d) then
                         ShineAdmin.Placeholder(detay, 0, 0, u(340), detay:GetTall(), "Elige un hechizo a la izquierda.")
                         return
                    end

                    local bilgi = vgui.Create("DPanel", detay)
                    bilgi:SetPos(0, 0)
                    bilgi:SetSize(u(340), u(92))
                    bilgi.Paint = function(s, w, h)
                         N.Box(0, 0, w, h, N.Clr.toolBg)
                         N.Outline(0, 0, w, h, N.Clr.toolLine, 1)
                         N.Text(N.Clip(d.buyu, "serifsm", w - u(24)), "serifsm", u(14), u(12), N.Clr.text)
                         N.Text(d.agac.ad .. " › " .. (d.agac.dallar[d.dal] or ""), "tiny", u(14), u(38), N.Clr.gold)
                         N.Text(BA.Kademeler[d.kademe].ad .. "  ·  predeterminado " .. taslak.kademeMaliyet[d.kademe] .. " puan", "tiny", u(14), u(56), N.Clr.rowDesc)
                         N.Text(#d.gerek > 0 and ("Requisito previo: " .. N.Clip(table.concat(d.gerek, " / "), "tiny", w - u(90))) or "Sin requisito (raíz)", "tiny", u(14), u(72), N.Clr.rowDesc)
                    end

                    N.Toggle(detay, 0, u(104), u(340), u(52), "Usar coste personalizado",
                         function() return taslak.maliyet[d.buyu] != nil end,
                         function(v)
                              taslak.maliyet[d.buyu] = v and (taslak.kademeMaliyet[d.kademe] or 1) or nil
                              detay.Kur()
                         end, "Si no, se usa el coste por defecto del nivel.")

                    if (taslak.maliyet[d.buyu] != nil) then
                         N.Slider(detay, 0, u(164), u(340), "Coste de este hechizo (Puntos de Hechizo)", 0, 100, 0,
                              function() return taslak.maliyet[d.buyu] or 0 end,
                              function(v) if (taslak.maliyet[d.buyu] != nil) then taslak.maliyet[d.buyu] = math.floor(v) end end)
                    end

                    N.Toggle(detay, 0, u(230), u(340), u(52), "Cerrado en el árbol",
                         function() return taslak.kapali[d.buyu] == true end,
                         function(v) taslak.kapali[d.buyu] = v or nil end,
                         "Visible pero no se puede abrir; los siguientes saltan y miran el requisito anterior.")
               end

               liste:SetItems(Satirlar())
               detay.Kur()
          end

          /*
          *   sekme :: ders puanları
          */

          local function DersKur(G, gh)
               local colW = math.floor((W - 2 * 10) / 3)
               N.Slider(G, 0, 0, u(colW), "Puntos de clase por defecto", 0, 20, 0,
                    function() return taslak.varsayilanDersPuan end,
                    function(v) taslak.varsayilanDersPuan = math.floor(v) end)
               N.Slider(G, u(colW + 10), 0, u(colW), "Asistencia mínima (% de la clase)", 0, 100, 0,
                    function() return taslak.katilimOrani end,
                    function(v) taslak.katilimOrani = math.floor(v) end)
               N.Slider(G, u((colW + 10) * 2), 0, u(colW), "Clase mínima (min.; por debajo no hay puntos)", 0, 120, 0,
                    function() return taslak.enAzDersDakika end,
                    function(v) taslak.enAzDersDakika = math.floor(v) end)

               local LIST_W = W - 360
               local ust = 66
               local secili
               local liste, detay

               local function Dersler()
                    local out = {}
                    for ad in pairs(fx_d and fx_d.dersler or {}) do out[#out + 1] = ad end
                    -- listede olmayan ama ayarı kalmış dersler de görünsün
                    for ad in pairs(taslak.dersPuan) do
                         if (!table.HasValue(out, ad)) then out[#out + 1] = ad end
                    end
                    table.sort(out, function(a, b) return string.lower(a) < string.lower(b) end)
                    return out
               end

               local head = vgui.Create("DPanel", G)
               head:SetPos(0, u(ust))
               head:SetSize(u(LIST_W), u(30))
               head.Paint = function(s, w, h)
                    N.TableHead(0, 0, w, {
                         {"Clase", u(16)},
                         {"Puntos de Hechizo", w - u(220)},
                         {"Origen", w - u(24), TEXT_ALIGN_RIGHT}
                    })
               end

               liste = N.VList(G, 0, u(ust + 30), u(LIST_W), u(gh - ust - 30 - 64), {
                    rowH = u(34),
                    gapY = 0,
                    emptyText = "No se encontró lista de clases ([sardon-fx] ders yüklü mü?).",
                    onClick = function(ad)
                         secili = ad
                         if (IsValid(detay)) then detay.Kur() end
                    end,
                    paintRow = function(ad, i, x, y, w, h, hovered)
                         local on = secili == ad
                         if (on) then
                              N.Box(x, y, w, h, N.Clr.selRow)
                              N.Box(x, y, u(2), h, N.Clr.gold)
                         elseif (hovered) then
                              N.Box(x, y, w, h, N.Clr.hoverRow)
                         end
                         N.Box(x, y + h - 1, w, 1, N.Clr.tableLine)

                         local ozel = taslak.dersPuan[ad]
                         N.Text(N.Clip(ad, "row", w - u(260)), "row", x + u(16), y + h / 2, N.Clr.tdFirst, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(tostring(ozel or taslak.varsayilanDersPuan), "strong", x + w - u(220), y + h / 2, ozel and N.Clr.gold or N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(ozel and (ozel == 0 and "no da puntos" or "özel") or "predeterminado", "tiny", x + w - u(24), y + h / 2, ozel and N.Clr.badgeText or N.Clr.faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    end
               })

               detay = vgui.Create("DPanel", G)
               detay:SetPos(u(LIST_W + 20), u(ust))
               detay:SetSize(u(340), u(gh - ust - 64))
               detay.Paint = function() end

               function detay.Kur()
                    detay:Clear()

                    if (!secili) then
                         local p = vgui.Create("DPanel", detay)
                         p:SetPos(0, 0)
                         p:SetSize(u(340), detay:GetTall())
                         local metin = "Ders bitince (profesör bitirdiğinde ya da süre dolduğunda) dersin en az belirlenen yüzdesinde sınıfta bulunan öğrencilere o dersin Büyü Puanı verilir. Dersi veren profesör puan almaz. Dersin seviye ve hane kısıtları puana da uygulanır. Bir dersi 0 yaparsan o ders no da puntos."
                         p.Paint = function(s, w, h)
                              N.Box(0, 0, w, h, N.Clr.toolBg)
                              N.Outline(0, 0, w, h, N.Clr.toolLine, 1)
                              N.Text("CÓMO FUNCIONA", "micro", u(14), u(14), N.Clr.gold)
                              for i, line in ipairs(N.Wrap(metin, "small", w - u(28))) do
                                   N.Text(line, "small", u(14), u(36) + (i - 1) * u(18), N.Clr.rowDesc)
                              end
                         end
                         return
                    end

                    local bilgi = vgui.Create("DPanel", detay)
                    bilgi:SetPos(0, 0)
                    bilgi:SetSize(u(340), u(70))
                    bilgi.Paint = function(s, w, h)
                         N.Box(0, 0, w, h, N.Clr.toolBg)
                         N.Outline(0, 0, w, h, N.Clr.toolLine, 1)
                         N.Text(N.Clip(secili, "serifsm", w - u(24)), "serifsm", u(14), u(12), N.Clr.text)
                         N.Text("predeterminado: " .. taslak.varsayilanDersPuan .. " puan", "tiny", u(14), u(42), N.Clr.rowDesc)
                    end

                    N.Toggle(detay, 0, u(82), u(340), u(52), "Puntos especiales para esta clase",
                         function() return taslak.dersPuan[secili] != nil end,
                         function(v)
                              taslak.dersPuan[secili] = v and taslak.varsayilanDersPuan or nil
                              detay.Kur()
                         end, "Si no, se usan los puntos por defecto.")

                    if (taslak.dersPuan[secili] != nil) then
                         N.Slider(detay, 0, u(142), u(340), "Puntos de Hechizo de esta clase", 0, 20, 0,
                              function() return taslak.dersPuan[secili] or 0 end,
                              function(v) if (taslak.dersPuan[secili] != nil) then taslak.dersPuan[secili] = math.floor(v) end end)
                    end
               end

               liste:SetItems(Dersler())
               detay.Kur()
          end

          /*
          *   sekme :: kademe kilitleri
          */

          local function KilitKur(G, gh)
               local tipAdlari = {}
               for _, t in ipairs(BA.KilitTipleri) do tipAdlari[#tipAdlari + 1] = t.ad end

               local function Baslik(metin, x, y, w, ikon)
                    local b = vgui.Create("DPanel", G)
                    b:SetPos(u(x), u(y))
                    b:SetSize(u(w), u(20))
                    b.Paint = function(s, pw, ph) N.SectionLabel(metin, 0, u(4), pw, ikon) end
               end

               -- sol: beş kademe (her satırda kural türü + değer)
               local KW = 800
               Baslik("Bloqueos por nivel (Desarrollo del personaje)", 0, 0, KW, "lock")

               local satirH = 54
               for i, k in ipairs(BA.Kademeler) do
                    local y = 26 + (i - 1) * (satirH + 4)
                    local kural = taslak.kilitler[i]

                    local satir = vgui.Create("DPanel", G)
                    satir:SetPos(0, u(y))
                    satir:SetSize(u(KW), u(satirH))
                    satir.Paint = function(s, w, h)
                         N.Box(0, 0, w, h, N.Clr.toolBg)
                         N.Outline(0, 0, w, h, N.Clr.toolLine, 1)
                         N.Text(k.roma, "heading", u(16), h / 2, N.Clr.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(k.ad, "serifsm", u(62), u(9), N.Clr.text)

                         local kr = taslak.kilitler[i]
                         local acik
                         if (kr.tip == "acik") then acik = "Abierto para todos."
                         elseif (kr.tip == "satir") then acik = "En la rama de desarrollo vinculada " .. kr.deger .. ". sıradan bir yetkinlik açılmış olmalı."
                         elseif (kr.tip == "toplam") then acik = "En la rama de desarrollo vinculada toplam " .. kr.deger .. " kademe."
                         elseif (kr.tip == "genel") then acik = "Karakter Gelişimi'nde toplam " .. kr.deger .. " puan harcanmış olmalı."
                         elseif (kr.tip == "seviye") then acik = "Karakter seviyesi en az " .. kr.deger .. "." end
                         N.Text(N.Clip(acik or "", "tiny", u(300)), "tiny", u(62), u(32), N.Clr.rowDesc)
                    end

                    N.Combo(satir, u(372), u(10), u(206), u(34), BA.KilitTipi(kural.tip).ad, tipAdlari, function(_, _, idx)
                         local t = BA.KilitTipleri[idx]
                         taslak.kilitler[i] = {tip = t.id, deger = t.min and math.Clamp(taslak.kilitler[i].deger, t.min, t.max) or 0}
                         SekmeKur()
                    end)

                    local tip = BA.KilitTipi(kural.tip)
                    if (tip.min) then
                         N.Slider(satir, u(588), 0, u(KW - 588), "Valor (" .. tip.birim .. ")", tip.min, tip.max, 0,
                              function() return taslak.kilitler[i].deger end,
                              function(v) taslak.kilitler[i].deger = math.floor(v) end)
                    end
               end

               local not1 = vgui.Create("DPanel", G)
               not1:SetPos(0, u(26 + #BA.Kademeler * (satirH + 4) + 4))
               not1:SetSize(u(KW), u(60))
               local metin = "Varsayılan: Basit / Orta / İleri / Feci Yorucu = bağlı dalda 2 / 8 / 14 / 16 kademe ve dalın ilk kademesinden 0 / 7 / 14 / 21 gün sonra (takvim tabanı, ayar.json \"bekleme\"). \"Sıra\": 1 kök, 2-3 ara, 4 ustalık."
               not1.Paint = function(s, w, h)
                    for i, line in ipairs(N.Wrap(metin, "tiny", w)) do
                         N.Text(line, "tiny", 0, (i - 1) * u(15), N.Clr.faint)
                    end
               end

               -- sağ: ağaç → gelişim dalı
               local RX = KW + 24
               local RW = W - RX
               Baslik("Árbol → rama de desarrollo vinculada", RX, 0, RW, "leaf")

               local kats = GelisimKategorileri()
               local katAdlari = {}
               for _, k in ipairs(kats) do katAdlari[#katAdlari + 1] = k.ad end

               -- bütün ağaçlar sığsın diye satır yüksekliği ağaç sayısına göre daralır
               local rh = math.Clamp(math.floor((gh - 86) / #BA.Agaclar) - 2, 18, 28)
               for i, agac in ipairs(BA.Agaclar) do
                    local cy = 26 + (i - 1) * (rh + 2)
                    if (cy + rh > gh - 60) then break end

                    local kutu = vgui.Create("DPanel", G)
                    kutu:SetPos(u(RX), u(cy))
                    kutu:SetSize(u(RW), u(rh))
                    kutu.Paint = function(s, w, h)
                         N.Box(0, 0, w, h, N.Clr.toolBg)
                         N.Outline(0, 0, w, h, taslak.bag[agac.id] and N.Clr.gold or N.Clr.toolLine, 1)
                         N.Box(0, 0, u(3), h, agac.renk)
                         N.Text(agac.ad, "row", u(12), h / 2, N.Clr.rowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end

                    N.Combo(kutu, u(RW * 0.48), u(2), u(RW * 0.52 - 2), u(rh - 4), GelisimAd(BA.GelisimBag(agac, taslak)), katAdlari, function(_, _, idx)
                         local id = kats[idx] and kats[idx].id
                         taslak.bag[agac.id] = (id and id != BA.VarsayilanBag(agac, taslak)) and id or nil
                    end)
               end
          end

          /*
          *   sekme :: dal dengesi (ana / yan dal tavanı + dengeli dal dağılımı)
          */

          local function DengeKur(G, gh)
               local function Baslik(metin, x, y, w, ikon)
                    local b = vgui.Create("DPanel", G)
                    b:SetPos(u(x), u(y))
                    b:SetSize(u(w), u(20))
                    b.Paint = function(s, pw, ph) N.SectionLabel(metin, 0, u(4), pw, ikon) end
               end

               local KW = math.floor(W * 0.5) - 12
               local rt = taslak.rolTavan

               -- sol: tavan
               Baslik("Tope de rama principal / secundaria", 0, 0, KW, "lock")
               N.Toggle(G, 0, u(26), u(KW), u(50), "Aplicar topes",
                    function() return taslak.rolTavan.acik end,
                    function(v) taslak.rolTavan.acik = v end,
                    "Con topes desactivados Büyü Ağacı'nı etkilemez (eski davranış).")

               local ROLLER = {
                    {"ana", "Rama principal (2 ramas)"},
                    {"yan", "Rama secundaria (1 rama)"},
                    {"diger", "Otras ramas"}
               }
               for i, r in ipairs(ROLLER) do
                    N.Slider(G, 0, u(84 + (i - 1) * 58), u(KW), r[2] .. " · nivel más alto", 1, #BA.Kademeler, 0,
                         function() return taslak.rolTavan[r[1]] end,
                         function(v) taslak.rolTavan[r[1]] = math.floor(v) end)
               end

               local ozet = vgui.Create("DPanel", G)
               ozet:SetPos(0, u(84 + #ROLLER * 58 + 4))
               ozet:SetSize(u(KW), u(70))
               ozet.Paint = function(s, w, h)
                    local t = taslak.rolTavan
                    local metin = t.acik
                         and ("Ana dal: " .. BA.Kademeler[t.ana].kisa .. "  ·  Yan dal: " .. BA.Kademeler[t.yan].kisa .. "  ·  Diğer: " .. BA.Kademeler[t.diger].kisa
                              .. ". Tavan, Kademe Kilitleri sekmesindeki şartların üstüne gelir. Daha önce öğrenilmiş hechizosler oyuncuda kalır.")
                         or "Tavan cerrado: bütün dallar yalnızca Kademe Kilitleri sekmesindeki şartlara bakar."
                    for i, line in ipairs(N.Wrap(metin, "tiny", w)) do
                         N.Text(line, "tiny", 0, (i - 1) * u(15), N.Clr.faint)
                    end
               end

               -- sağ: dağılım
               local RX = KW + 24
               local RW = W - RX
               Baslik("Distribución de hechizos por rama", RX, 0, RW, "leaf")
               local dengeli = next(BA.DengeBag) != nil
               if (dengeli) then
                    N.Toggle(G, u(RX), u(26), u(RW), u(50), "Distribución equilibrada",
                         function() return taslak.dengeBag end,
                         function(v) taslak.dengeBag = v end,
                         "Bazı ağaçlar tematik dalı yerine daha boş bir dala bağlanır. Kapalıyken tematik dallarına döner.")
               end

               local kats = GelisimKategorileri()
               local tablo = vgui.Create("DPanel", G)
               local ty = dengeli and 84 or 26
               tablo:SetPos(u(RX), u(ty))
               tablo:SetSize(u(RW), u(math.max(60, gh - ty - 60)))
               tablo.Paint = function(s, w, h)
                    local say, adlar, enCok = {}, {}, 1
                    for _, agac in ipairs(BA.Agaclar) do
                         local id = BA.GelisimBag(agac, taslak)
                         say[id] = (say[id] or 0) + #agac.dugumler
                         adlar[id] = (adlar[id] and (adlar[id] .. ", ") or "") .. agac.ad
                         enCok = math.max(enCok, say[id])
                    end

                    local rh = math.min(u(34), h / math.max(1, #kats))
                    for i, k in ipairs(kats) do
                         local y = (i - 1) * rh
                         local n = say[k.id] or 0
                         N.Box(0, y, w, rh - u(2), N.Clr.toolBg)
                         N.Box(0, y + rh - u(5), (w * n) / enCok, u(3), N.Clr.gold)
                         N.Text(k.ad, "row", u(10), y + rh / 2 - u(2), N.Clr.rowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(N.Clip(adlar[k.id] or "—", "tiny", w - u(260)), "tiny", u(190), y + rh / 2 - u(2), N.Clr.rowDesc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(n .. " hechizos", "row", w - u(10), y + rh / 2 - u(2), N.Clr.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    end
               end
          end

          /*
          *   sekme :: oyuncular
          */

          local function OyuncuKur(G, gh)
               local secili
               local LIST_W = 340
               local sag

               ShineAdmin.PlayerList(G, 0, 0, u(LIST_W), u(gh), function() return secili end, function(p)
                    secili = p
                    BA.YonetimOyuncu = nil
                    Istek("oyuncu", function() net.WriteEntity(p) end)
                    if (IsValid(sag)) then sag.Kur() end
               end)

               local SX = LIST_W + 24
               local SW = W - SX
               local miktar = 5

               sag = vgui.Create("DPanel", G)
               sag:SetPos(u(SX), 0)
               sag:SetSize(u(SW), u(gh))
               sag.Paint = function() end

               function sag.Kur()
                    sag:Clear()

                    if (!IsValid(secili)) then
                         ShineAdmin.Placeholder(sag, 0, 0, u(SW), u(gh), "Elige un jugador de la izquierda.")
                         return
                    end

                    local kart = vgui.Create("DPanel", sag)
                    kart:SetPos(0, 0)
                    kart:SetSize(u(SW), u(96))
                    kart.Paint = function(s, w, h)
                         N.Box(0, 0, w, h, N.Clr.toolBg)
                         N.Outline(0, 0, w, h, N.Clr.toolLine, 1)

                         local v = BA.YonetimOyuncu
                         N.Text(IsValid(secili) and secili:Nick() or "—", "serifsm", u(16), u(14), N.Clr.text)

                         if (!v or v.ent != secili) then
                              N.Text("Solicitando al servidor…", "tiny", u(16), u(42), N.Clr.rowDesc)
                              return
                         end
                         if (!v.var) then
                              N.Text("Este jugador no tiene personaje seleccionado.", "tiny", u(16), u(42), N.Clr.warn)
                              return
                         end

                         N.Text("Personaje: " .. v.ad, "tiny", u(16), u(40), N.Clr.rowDesc)
                         N.Text("Hechizos abiertos: " .. #v.acilan, "tiny", u(16), u(58), N.Clr.rowDesc)

                         local x = w - u(16)
                         local function Stat(etiket, deger, renk)
                              N.Text(tostring(deger), "count", x, u(38), renk or N.Clr.bigStat, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                              N.Text(etiket, "micro", x, u(68), N.Clr.faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                              x = x - u(120)
                         end
                         Stat("DISPONIBLES", math.max(0, v.k - v.h), N.Clr.goldAccent)
                         Stat("GASTADOS", v.h, N.Clr.tdText)
                         Stat("GANADOS", v.k, N.Clr.tdText)
                    end

                    N.Slider(sag, 0, u(108), u(SW - 300), "Cantidad (Puntos de Hechizo)", 1, 100, 0,
                         function() return miktar end,
                         function(v) miktar = math.Clamp(math.floor(v), 1, 100) end)

                    local function hazir()
                         local v = BA.YonetimOyuncu
                         return IsValid(secili) and v and v.ent == secili and v.var
                    end

                    local ver = N.Button(sag, u(SW - 290), u(117), u(140), u(36), "Dar puntos", function()
                         Istek("puan", function() net.WriteEntity(secili) net.WriteInt(miktar, 16) end)
                    end, "primary")
                    ver.Think = function(s) s:SetEnabled(hazir()) end

                    local al = N.Button(sag, u(SW - 140), u(117), u(140), u(36), "Quitar puntos", function()
                         Istek("puan", function() net.WriteEntity(secili) net.WriteInt(-miktar, 16) end)
                    end)
                    al.Think = function(s) s:SetEnabled(hazir()) end

                    local s1 = N.Button(sag, 0, u(176), u(260), u(36), "Reiniciar árbol (devolver puntos)", function()
                         local p = secili
                         N.Confirm("Reiniciar árbol", p:Nick() .. " karakterinin harcadığı tüm Büyü Puanları iade edilir. Öğrendiği hechizosler kalır; ağaç onları yine açık sayar.", "Reiniciar", function()
                              Istek("sifirla", function() net.WriteEntity(p) net.WriteBool(false) end)
                         end, true)
                    end)
                    s1.Think = function(s) s:SetEnabled(hazir()) end

                    local s2 = N.Button(sag, u(270), u(176), u(320), u(36), "Reiniciar y borrar hechizos del árbol", function()
                         local p = secili
                         N.Confirm("Reiniciar árbol y hechizos", p:Nick() .. " karakterinin puanları iade edilir ve ağaçtan parayla açtığı hechizosler hesabından SİLİNİR (büyüler hesap bazlıdır, diğer karakterlerini de etkiler).", "Reiniciar y borrar", function()
                              Istek("sifirla", function() net.WriteEntity(p) net.WriteBool(true) end)
                         end, true)
                    end, "danger")
                    s2.Think = function(s) s:SetEnabled(hazir()) end

                    local head = vgui.Create("DPanel", sag)
                    head:SetPos(0, u(228))
                    head:SetSize(u(SW), u(30))
                    head.Paint = function(s, w, h)
                         N.TableHead(0, 0, w, {{"Hechizo abierto en árbol", u(16)}, {"Árbol", u(300)}, {"Pagado", w - u(24), TEXT_ALIGN_RIGHT}})
                    end

                    local liste = N.VList(sag, 0, u(258), u(SW), u(gh - 258), {
                         rowH = u(32),
                         gapY = 0,
                         emptyText = "No hay hechizos abiertos desde el árbol.",
                         paintRow = function(r, i, x, y, w, h)
                              N.Box(x, y + h - 1, w, 1, N.Clr.tableLine)
                              local d = BA.Dugum(r.buyu)
                              N.Text(r.buyu, "row", x + u(16), y + h / 2, N.Clr.tdFirst, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                              N.Text(d and (d.agac.ad .. " · " .. BA.Kademeler[d.kademe].kisa) or "—", "small", x + u(300), y + h / 2, N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                              N.Text(tostring(r.odenen), "strong", x + w - u(24), y + h / 2, N.Clr.gold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                         end
                    })

                    liste.Think2 = liste.Think
                    liste.Think = function(s)
                         if (s.Think2) then s:Think2() end
                         local v = BA.YonetimOyuncu
                         local src = v and v.ent == secili and v.acilan or nil
                         if (s.Src != src) then
                              s.Src = src
                              s:SetItems(src or {})
                         end
                    end
               end

               ctx.OyuncuYenile = function() end
               sag.Kur()
          end

          /*
          *   sekme kurucusu
          */

          SekmeKur = function()
               if (IsValid(govde)) then govde:Remove() end

               govde = vgui.Create("DPanel", P)
               govde:SetPos(0, u(GY))
               govde:SetSize(u(W), u(GH))
               govde.Paint = function() end

               if (aktif == "oyuncu") then
                    OyuncuKur(govde, GH)
                    return
               end

               if (aktif == "maliyet") then MaliyetKur(govde, GH)
               elseif (aktif == "ders") then DersKur(govde, GH)
               elseif (aktif == "kilit") then KilitKur(govde, GH)
               elseif (aktif == "denge") then DengeKur(govde, GH) end

               KaydetSeridi(govde, GH)
          end

          -- başka bir süper admin kaydettiğinde (ya da ilk ayar geldiğinde) taslak değişmemişse güncelle
          local izleyici = vgui.Create("DPanel", P)
          izleyici:SetSize(0, 0)
          izleyici.Paint = function() end
          local onceki = table.Copy(BA.Ayar)
          hook.Add("SardonBuyuAgaciAyar", izleyici, function()
               if (Esit(taslak, onceki)) then
                    taslak = table.Copy(BA.Ayar)
                    if (aktif != "oyuncu") then SekmeKur() end
               end
               onceki = table.Copy(BA.Ayar)
          end)

          ctx.SetHead({
               note = function()
                    local n = 0
                    for _, a in ipairs(BA.Agaclar) do n = n + #a.dugumler end
                    return #BA.Agaclar .. " ÁRBOLES  ·  " .. n .. " HECHIZOS"
               end
          })

          SekmeKur()
     end
}

ShineAdmin = ShineAdmin or {}
ShineAdmin.Pages = ShineAdmin.Pages or {}
ShineAdmin.Pages.buyuagaci = sayfa

concommand.Add("sardon_buyuagaci_admin", function()
     if (ShineAdmin and ShineAdmin.Open) then ShineAdmin:Open("buyuagaci") end
end, nil, "Shine Admin > Árbol de hechizos")
