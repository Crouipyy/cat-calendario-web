-- "addons\\sardonkitap\\lua\\sardon_kitap\\cl_9yonetim.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kitap :: Shine Admin › Kitaplar (yalnız süper admin)
--   Ayarlar · Metinler (bölüm başlığı ve sayfaları, K11) · Kitapçı (sahne rafları, tezgâhlar) ·
--   Notlar (son kenar notları, silme) · Test (kendine kitap/mektup/kazan, sahne, ilerleme sıfırlama)

local SK = SardonKitap

local function Istek(islem, yaz)
     net.Start("SardonKitap.Yonetim")
     net.WriteString(islem)
     if yaz then yaz() end
     net.SendToServer()
end

SK.YonetimNotlar = SK.YonetimNotlar or {}
SK.YonetimSurum = SK.YonetimSurum or 0

net.Receive("SardonKitap.YonetimVeri", function()
     local t = {}
     for i = 1, net.ReadUInt(8) do
          t[i] = {no = net.ReadUInt(32), seri = net.ReadUInt(32), kitap = net.ReadString(), bolum = net.ReadString(),
               yazar = net.ReadString(), metin = net.ReadString(), zaman = net.ReadUInt(32)}
     end
     SK.YonetimNotlar = t
     SK.YonetimStok = net.ReadUInt(16)
     SK.YonetimSurum = SK.YonetimSurum + 1
end)

local function Esit(a, b)
     for k, v in pairs(a) do if b[k] ~= v then return false end end
     for k, v in pairs(b) do if a[k] ~= v then return false end end
     return true
end

local sayfa = {
     id = "kitap",
     label = "Libros escolares",
     icon = "book",
     group = "magic",
     order = 37,
     title = "Libros escolares",
     subtitle = "Libros de primer año, librería, notas al margen, inspección y ajustes de examen.",
     access = "superadmin",
     available = function() return SardonKitap ~= nil and SardonKitap.AyarTemizle ~= nil end,

     build = function(ctx)
          local N = ShineAdmin.GetN()
          local u = N.u
          local P = ctx.panel
          local W, H = ctx.w, ctx.h
          local aktif = SK.SonSekme or "ayar"
          local taslak = table.Copy(SK.Ayar)
          local govde

          local SEKMELER = {{"ayar", "Ajustes"}, {"metin", "Textos"}, {"kitapci", "Librería"}, {"notlar", "Notas al margen"}, {"test", "Test"}}
          local SekmeKur

          N.SubTabs(P, 0, 0, u(W), SEKMELER, function() return aktif end, function(id)
               if aktif == id then return end
               aktif = id
               SK.SonSekme = id
               SekmeKur()
          end)

          local GY = 56
          local GH = H - GY

          local function Bilgi(parent, x, y, w, metin)
               local satirlar = N.Wrap and N.Wrap(metin, "tiny", u(w)) or {metin}
               local p = vgui.Create("DPanel", parent)
               p:SetPos(u(x), u(y))
               p:SetSize(u(w), #satirlar * u(15) + u(4))
               p.Paint = function()
                    for i, s in ipairs(satirlar) do N.Text(s, "tiny", 0, (i - 1) * u(15), N.Clr.rowDesc) end
               end
               return #satirlar * 15 + 4
          end

          local KUR = {}

          KUR.ayar = function()
               local sc = N.Scroll(govde, 0, 0, u(W), u(GH - 60))
               local colW = math.floor((W - 30) / 3)
               for i, a in ipairs(SK.AyarAlanlari) do
                    local c, r = (i - 1) % 3, math.floor((i - 1) / 3)
                    N.Slider(sc, u(c * (colW + 10)), u(r * 64), u(colW), a[2], a[3], a[4], 0,
                         function() return taslak[a[1]] end, function(v) taslak[a[1]] = math.floor(v) end)
               end
               local y = math.ceil(#SK.AyarAlanlari / 3) * 64 + 10
               for i, a in ipairs(SK.AyarAnahtarlari) do
                    local c, r = (i - 1) % 2, math.floor((i - 1) / 2)
                    N.Toggle(sc, u(c * (W / 2)), u(y + r * 60), u(W / 2 - 10), u(52), a[2],
                         function() return taslak[a[1]] end, function(v) taslak[a[1]] = v end)
               end
               local bar = N.StickyBar(govde, 0, u(GH - 52), u(W), function()
                    if not Esit(taslak, SK.Ayar) then return "Hay cambios sin guardar.", N.Clr.warn end
                    return "Los ajustes coinciden con el servidor."
               end)
               local kaydet = N.Button(bar, u(W) - u(150), u(8), u(150), u(36), "Guardar", function()
                    Istek("ayar", function() net.WriteTable(taslak) end)
                    ctx.Flash("Ajustes de libros guardados.")
               end, "primary")
               kaydet.Think = function(s) s:SetEnabled(not Esit(taslak, SK.Ayar)) end
               local geri = N.Button(bar, u(W) - u(288), u(8), u(130), u(36), "Deshacer", function()
                    taslak = table.Copy(SK.Ayar)
                    SekmeKur()
               end)
               geri.Think = function(s) s:SetEnabled(not Esit(taslak, SK.Ayar)) end
          end

          KUR.metin = function()
               local sol = N.Scroll(govde, 0, 0, u(300), u(GH))
               local sag = vgui.Create("DPanel", govde)
               sag:SetPos(u(316), 0)
               sag:SetSize(u(W - 316), u(GH))
               sag.Paint = nil
               local secK, secB = SK.SonMetinK, SK.SonMetinB

               local function Duzenle()
                    sag:Clear()
                    local b = secK and SK.BolumBul(secK, secB)
                    if not b then
                         Bilgi(sag, 0, 0, W - 316, "Elige un libro y capítulo a la izquierda. Değişiklik yalnızca başlık ve sayfa metnini değiştirir; büyü, süre ve sınav sorusu dosyada kalır.")
                         return
                    end
                    local ozel = SK.MetinOzel[secK] and SK.MetinOzel[secK][secB]
                    local baslikW, baslikE = N.TextEntry(sag, 0, 0, u(W - 316), u(36), "Título")
                    baslikE:SetValue(b.baslik or "")
                    local girisler = {}
                    local y = 46
                    local sayfaH = math.max(70, math.floor((GH - 46 - 60) / 4) - 8)
                    local sc = N.Scroll(sag, 0, u(y), u(W - 316), u(GH - y - 56))
                    local n = math.max(#b.sayfalar + 1, 3)
                    for i = 1, math.min(n, 8) do
                         local e = vgui.Create("DTextEntry", sc)
                         e:SetPos(0, (i - 1) * u(sayfaH + 8))
                         e:SetSize(u(W - 330), u(sayfaH))
                         e:SetMultiline(true)
                         e:SetPlaceholderText("Página " .. i .. (i > #b.sayfalar and " (si se deja vacío no se añade)" or ""))
                         e:SetValue(b.sayfalar[i] or "")
                         girisler[i] = e
                    end
                    local bar = N.StickyBar(sag, 0, u(GH - 52), u(W - 316), function()
                         return ozel and "Este capítulo se editó desde Shine." or "Texto por defecto del archivo."
                    end)
                    N.Button(bar, u(W - 316) - u(150), u(8), u(150), u(36), "Guardar", function()
                         Istek("metin", function()
                              net.WriteString(secK) net.WriteString(secB) net.WriteBool(false)
                              net.WriteString(baslikE:GetValue() or "")
                              net.WriteUInt(#girisler, 5)
                              for _, e in ipairs(girisler) do net.WriteString(e:GetValue() or "") end
                         end)
                         ctx.Flash("Capítulo guardado; enviado a todos.")
                    end, "primary")
                    N.Button(bar, u(W - 316) - u(330), u(8), u(170), u(36), "Varsayılana dön", function()
                         N.Confirm("Varsayılana dön", "Se borrará la edición de Shine de este capítulo.", "Dön", function()
                              Istek("metin", function() net.WriteString(secK) net.WriteString(secB) net.WriteBool(true) end)
                              ctx.Flash("Capítulo restaurado al predeterminado.")
                              timer.Simple(0.6, function() if IsValid(sag) then Duzenle() end end)
                         end, true)
                    end)
               end

               local y = 0
               for _, k in ipairs(SK.KITAPLAR) do
                    local acik = secK == k.id
                    N.Button(sol, 0, u(y), u(286), u(32), k.ad, function()
                         secK = acik and nil or k.id
                         SK.SonMetinK = secK
                         SekmeKur()
                    end, acik and "primary" or nil)
                    y = y + 36
                    if acik then
                         for i, b in ipairs(SK.Bolumler(k.id)) do
                              local ozel = SK.MetinOzel[k.id] and SK.MetinOzel[k.id][b.id]
                              N.Button(sol, u(16), u(y), u(270), u(28), i .. ". " .. b.baslik .. (ozel and "  ✎" or ""), function()
                                   secB = b.id
                                   SK.SonMetinB = b.id
                                   Duzenle()
                              end, secB == b.id and "primary" or nil)
                              y = y + 31
                         end
                    end
               end
               Duzenle()
          end

          KUR.kitapci = function()
               local y = Bilgi(govde, 0, 0, W, "Raflar haritanın kendi kitapçı rafları (BSP'den). Oyuncu rafa bakıp E'ye basınca kitapçı o rafın kitabını Accio ile indirir; yanlış rafta doğru rafı tarif eder. Buradan rafın adını (oyuncuya ve listeye yazılan) ve tuttuğu kitabı değiştirebilirsin. 'cilt' = üst yıl Standart Büyüler ciltleri.") + 8
               local secenek = {{"", "(vacío)"}, {"cilt", "Volúmenes de cursos superiores (Goshawk 2–7)"}}
               for _, k in ipairs(SK.KITAPLAR) do
                    if not k.cilt then secenek[#secenek + 1] = {k.id, k.ad} end
               end
               local sc = N.Scroll(govde, 0, u(y), u(W), u(GH - y))
               for i, r in ipairs(SK.Harita.raflar or {}) do
                    local satir = vgui.Create("DPanel", sc)
                    satir:SetPos(0, (i - 1) * u(52))
                    satir:SetSize(u(W - 14), u(46))
                    satir.Paint = function(_, w, h)
                         N.Box(0, 0, w, h, N.Clr.hoverRow)
                         local d = LocalPlayer():GetPos():Distance(r.pos)
                         N.Text(math.floor(d * 0.019) .. " m", "small", w - u(250), h / 2, N.Clr.tdText, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    end
                    local _, adE = N.TextEntry(satir, u(8), u(6), u(360), u(34), "Nombre del estante")
                    adE:SetValue(r.ad or "")
                    local secim = r.kitap or ""
                    local adi = "(vacío)"
                    for _, x in ipairs(secenek) do if x[1] == secim then adi = x[2] end end
                    local cb = vgui.Create("DComboBox", satir)
                    cb:SetPos(u(380), u(8))
                    cb:SetSize(u(W - 14) - u(380) - u(260), u(30))
                    cb:SetValue(adi)
                    for _, x in ipairs(secenek) do cb:AddChoice(x[2], x[1]) end
                    cb.OnSelect = function(_, _, _, veri) secim = veri end
                    N.Button(satir, u(W - 14) - u(110), u(6), u(100), u(34), "Guardar", function()
                         Istek("raf", function() net.WriteString(r.id) net.WriteString(adE:GetValue() or "") net.WriteString(secim or "") end)
                         ctx.Flash("Estante guardado.")
                    end, "primary")
               end
               if #(SK.Harita.raflar or {}) == 0 then
                    N.Text("Bu haritada kayıtlı kitapçı rafı yok; karşılamada kitapçı kitapları sırayla kendisi getirir.", "small", 0, u(y + 6), N.Clr.rowDesc)
               end
          end

          KUR.notlar = function()
               Istek("veri")
               local sc = N.Scroll(govde, 0, 0, u(W), u(GH))
               local surum = -1
               sc.Think = function(s)
                    if surum == SK.YonetimSurum then return end
                    surum = SK.YonetimSurum
                    s:Clear()
                    local y = 0
                    if #SK.YonetimNotlar == 0 then
                         N.Text("Aún no hay notas al margen. İkinci el rafında " .. (SK.YonetimStok or 0) .. " kitap var.", "small", 0, 0, N.Clr.rowDesc)
                    end
                    for _, n in ipairs(SK.YonetimNotlar) do
                         local k = SK.Kitap[n.kitap]
                         local satir = vgui.Create("DPanel", s)
                         satir:SetPos(0, u(y))
                         satir:SetSize(u(W - 14), u(52))
                         satir.Paint = function(_, w, h)
                              N.Box(0, 0, w, h, N.Clr.hoverRow)
                              N.Text(n.yazar .. "  ·  " .. (k and k.ad or n.kitap) .. " / " .. n.bolum .. "  ·  seri " .. n.seri .. "  ·  " .. os.date("%d.%m %H:%M", n.zaman), "small", u(10), u(8), N.Clr.gold)
                              N.Text(N.Clip(n.metin, "row", w - u(110)), "row", u(10), u(26), N.Clr.tdFirst)
                         end
                         N.Button(satir, u(W - 14) - u(84), u(10), u(74), u(32), "Borrar", function()
                              N.Confirm("Borrar nota", n.yazar .. ": " .. n.metin, "Borrar", function()
                                   Istek("notSil", function() net.WriteUInt(n.no, 32) end)
                              end, true)
                         end)
                         y = y + 58
                    end
               end
          end

          KUR.test = function()
               local yil = 2
               local y = Bilgi(govde, 0, 0, W, "Bu işlemler yalnızca senin karakterine uygulanır. 'İlerlemeni sıfırla' okunan bölümleri, acemi büyüleri, keşifleri ve sınav kayıtlarını siler; öğrenilmiş büyüler ve Büyü Puanı yerinde kalır.") + 10
               local bw = math.floor((W - 20) / 2)
               local function B(x, yy, metin, fn, stil) N.Button(govde, u(x), u(yy), u(bw), u(38), metin, fn, stil) end
               B(0, y, "Dar libros del 1.º año + correa", function() Istek("test", function() net.WriteString("kitaplar") end) ctx.Flash("Entregado.") end, "primary")
               B(bw + 20, y, "Iniciar escena de librería en mí", function() Istek("test", function() net.WriteString("sahne") end) end)
               y = y + 48
               N.Slider(govde, 0, u(y), u(bw), "Año (volumen / carta)", 1, 7, 0, function() return yil end, function(v) yil = math.floor(v) end)
               B(bw + 20, y + 8, "Dar volumen de este año", function() Istek("test", function() net.WriteString("cilt") net.WriteUInt(math.max(2, yil), 4) end) ctx.Flash("Entregado.") end)
               y = y + 64
               B(0, y, "Dar carta de este año", function() Istek("test", function() net.WriteString("mektup") net.WriteUInt(yil, 4) end) ctx.Flash("Entregado.") end)
               B(bw + 20, y, "Dar caldero escolar", function() Istek("test", function() net.WriteString("kazan") end) ctx.Flash("Entregado.") end)
               y = y + 48
               B(0, y, "Marcar capítulos 1.º año como leídos", function() Istek("test", function() net.WriteString("bitir") end) end)
               B(bw + 20, y, "Reiniciar mi progreso", function()
                    N.Confirm("İlerlemeni sıfırla", "Okunan bölümler, acemi büyüler, keşifler ve sınav kayıtların silinecek.", "Reiniciar", function()
                         Istek("test", function() net.WriteString("sifirla") end)
                    end, true)
               end)
          end

          SekmeKur = function()
               if IsValid(govde) then govde:Remove() end
               govde = vgui.Create("DPanel", P)
               govde:SetPos(0, u(GY))
               govde:SetSize(u(W), u(GH))
               govde.Paint = nil
               if KUR[aktif] then KUR[aktif]() end
          end

          ctx.SetHead({
               note = function()
                    return #(SK.Harita.raflar or {}) .. " ESTANTES  ·  " .. (SK.Harita.tezgah and "MOSTRADOR SÍ" or "SIN MOSTRADOR")
               end
          })
          SekmeKur()
     end
}

ShineAdmin = ShineAdmin or {}
ShineAdmin.Pages = ShineAdmin.Pages or {}
ShineAdmin.Pages.kitap = sayfa

concommand.Add("sardon_kitap_admin", function()
     if ShineAdmin and ShineAdmin.Open then ShineAdmin:Open("kitap") end
end, nil, "Shine Admin > Libros escolares")
