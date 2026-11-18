-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\cl_5shine.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Bakanlık :: Shine Admin › "Bakanlık" sayfası (yalnız süperadmin).
-- Azkaban hücre / tahliye noktaları, adlı konumlar, Hazine düzeltmesi, kayıt sıfırlama.
-- Sunucu tarafı sv_5ceza.lua (azkaban.nokta) ve sv_8kararname.lua (yonetim.*).

local B = SardonBakanlik

local SIFIRLA = {
     {"olay", "Incidentes"}, {"dosya", "Expedientes y pruebas"}, {"emir", "Órdenes"}, {"sicil", "Registros del expediente"},
     {"kararname", "Decretos"}, {"hazine", "Libro del Tesoro"}, {"log", "Registro de auditoría"},
}

local function Kaydet()
     if not ShineAdmin or not ShineAdmin.RegisterPage or not ShineAdmin.GetN then return false end

     ShineAdmin:RegisterPage("bakanlik", {
          label = "Ministerio de Magia",
          icon = "star",
          group = "magic",
          order = 38,
          title = "Ministerio de Magia",
          subtitle = "Expediente: puntos de Azkaban, ubicaciones con nombre, Tesoro y registros.",
          access = "superadmin",

          build = function(ctx)
               local N = ShineAdmin.GetN()
               local u = N.u
               local P = ctx.panel
               local W = ctx.w

               B.Iste("yonetim.durum", {})

               local kart = vgui.Create("DPanel", P)
               kart:SetPos(0, 0)
               kart:SetSize(u(W), u(104))
               kart.Paint = function(s, w, h)
                    N.Box(0, 0, w, h, N.Clr.toolBg)
                    N.Outline(0, 0, w, h, N.Clr.toolLine, 1)
                    local v = B.Veri["yonetim.durum"]
                    if not v then
                         N.Text("Solicitando al servidor…", "tiny", u(16), u(20), N.Clr.rowDesc)
                         return
                    end
                    local x = u(16)
                    local function Stat(etiket, deger, renk)
                         N.Text(tostring(deger), "count", x, u(40), renk or N.Clr.bigStat, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(etiket, "micro", x, u(74), N.Clr.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         x = x + u(140)
                    end
                    Stat("PUNTO DE CELDA", v.hucre, v.hucre > 0 and N.Clr.goldAccent or N.Clr.warn)
                    Stat("PUNTO DE LIBERACIÓN", v.tahliye and "sí" or "no", v.tahliye and N.Clr.goldAccent or N.Clr.warn)
                    Stat("TESORO", B.Para(v.hazine))
                    Stat("PLANTILLA", v.sayilar.personel)
                    Stat("INCIDENTE", v.sayilar.olay)
                    Stat("EXPEDIENTE", v.sayilar.dosya)
                    Stat("DETENIDOS", v.sayilar.tutuklu)
               end

               local y = 120
               N.Button(P, 0, u(y), u(250), u(36), "Añadir celda aquí", function() B.Iste("azkaban.nokta", {islem = "hucre"}) end)
               N.Button(P, u(260), u(y), u(250), u(36), "Punto de liberación aquí", function() B.Iste("azkaban.nokta", {islem = "tahliye"}) end)
               N.Button(P, u(520), u(y), u(250), u(36), "Borrar puntos de Azkaban", function()
                    N.Confirm("Borrar puntos de Azkaban", "Se eliminan todos los puntos de celda y de liberación. Los detenidos no quedan libres; volverán a la celda cuando se definan nuevos puntos.", "Eliminar", function()
                         B.Iste("azkaban.nokta", {islem = "temizle"})
                    end)
               end)
               N.Button(P, u(780), u(y), u(200), u(36), "Abrir expediente", function()
                    ShineAdmin:Close()
                    timer.Simple(0, function() B.Ac() end)
               end)

               -- Hazine
               y = y + 56
               local miktar = 0
               N.PlainEntry(P, 0, u(y), u(200), u(36), "Galeones", function(v) miktar = math.floor(tonumber(v) or 0) end)
               N.Button(P, u(210), u(y), u(170), u(36), "Añadir al Tesoro", function() B.Iste("yonetim.hazine", {miktar = miktar}) end)
               N.Button(P, u(390), u(y), u(170), u(36), "Descontar del Tesoro", function() B.Iste("yonetim.hazine", {miktar = -miktar}) end)

               -- Adlı konumlar
               y = y + 56
               local ad = ""
               N.PlainEntry(P, 0, u(y), u(300), u(36), "Nombre del lugar (p. ej. Muelle de Azkaban)", function(v) ad = v end)
               N.Button(P, u(310), u(y), u(250), u(36), "Ubicación con nombre aquí", function() B.Iste("yonetim.nokta", {ad = ad}) end)

               local liste = vgui.Create("DPanel", P)
               liste:SetPos(0, u(y + 46))
               liste:SetSize(u(W), u(110))
               liste.Paint = function(s, w, h)
                    local v = B.Veri["yonetim.durum"]
                    local noktalar = v and v.noktalar or {}
                    N.Text("Ubicaciones con nombre que aparecen en los registros de incidentes como «cercanías de…» (los puntos de traslador y las casas se cuentan solos): " ..
                         (#noktalar == 0 and "aún ninguna." or ""), "tiny", 0, u(8), N.Clr.rowDesc)
                    for i, n in ipairs(noktalar) do
                         N.Text(i .. ". " .. tostring(n.ad), "small", u(((i - 1) % 4) * 260), u(32 + math.floor((i - 1) / 4) * 22), N.Clr.tdText)
                    end
               end
               N.Button(P, u(W - 200), u(y), u(200), u(36), "Borrar última ubicación", function()
                    local v = B.Veri["yonetim.durum"]
                    if v and #v.noktalar > 0 then B.Iste("yonetim.nokta", {sil = #v.noktalar}) end
               end)

               -- Sıfırlama
               y = y + 170
               for i, s in ipairs(SIFIRLA) do
                    local bx = ((i - 1) % 4) * 250
                    local by = y + math.floor((i - 1) / 4) * 46
                    N.Button(P, u(bx), u(by), u(240), u(36), "Eliminar: " .. s[2], function()
                         N.Confirm("Eliminar registros: " .. s[2], "Estos registros se borrarán de forma permanente y no se pueden recuperar.", "Eliminar permanentemente", function()
                              B.Iste("yonetim.sifirla", {ne = s[1], onay = "SIFIRLA"})
                         end)
                    end)
               end

               -- Nüfus kaydı ve kimlik belgesi (sv_kimlik.lua yonetim.kimlik)
               y = y + 104
               local kisi = ""
               local etiket = vgui.Create("DPanel", P)
               etiket:SetPos(0, u(y - 26))
               etiket:SetSize(u(W), u(22))
               etiket.Paint = function()
                    N.Text("Registro civil: escribe el nombre del personaje o #número. El estado de sangre se guarda en [fx] raza (por cuenta); emite nueva identidad o consulta el registro.", "tiny", 0, u(11), N.Clr.rowDesc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               end
               N.PlainEntry(P, 0, u(y), u(240), u(36), "Nombre del personaje / #id", function(v) kisi = v end)
               local bx = 250
               for _, k in ipairs(B.Kimlik.Kanlar) do
                    N.Button(P, u(bx), u(y), u(130), u(36), k.ad, function() B.Iste("yonetim.kimlik", {kisi = kisi, islem = "kan", kan = k.id}) end)
                    bx = bx + 140
               end
               N.Button(P, u(bx), u(y), u(150), u(36), "Nueva identidad", function()
                    N.Confirm("Emitir nueva identidad", "Se anulan los documentos válidos del personaje y se entrega uno nuevo gratis (debe estar en el juego).", "Emitir", function()
                         B.Iste("yonetim.kimlik", {kisi = kisi, islem = "ver"})
                    end)
               end)
               N.Button(P, u(bx + 160), u(y), u(110), u(36), "Ver registro", function() B.Iste("yonetim.kimlik", {kisi = kisi}) end)
          end,
     })
     return true
end

if not Kaydet() then
     timer.Create("SardonBakanlik.Shine", 2, 30, function()
          if Kaydet() then timer.Remove("SardonBakanlik.Shine") end
     end)
end

concommand.Add("sardon_bakanlik_admin", function()
     if ShineAdmin and ShineAdmin.Open then ShineAdmin:Open("bakanlik") end
end)