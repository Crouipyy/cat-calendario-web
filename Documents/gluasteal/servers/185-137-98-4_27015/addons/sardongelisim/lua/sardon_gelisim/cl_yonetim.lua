-- "addons\\sardongelisim\\lua\\sardon_gelisim\\cl_yonetim.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Gelişim :: Shine Admin sayfası "gelisim" (yalnızca süper admin)
-- Çevrimiçi bir oyuncunun karakter gelişimini dal dal yönetir: dala XP ya da ek puan verir/alır,
-- dalın kademelerini, bütün kademeleri ya da (XP dahil) her şeyi sıfırlar. Sunucu tarafı sv_yonetim.lua.
-- 2026-11-09: puan dal XP'sinden gelir (dal seviyesi = o dalda açılabilecek kademe).

local G = SardonGelisim

G.YonetimOyuncu = G.YonetimOyuncu or nil

local function Istek(islem, hedef, yaz)
     net.Start("SardonGelisim.Yonetim")
          net.WriteString(islem)
          net.WriteEntity(hedef)
          if (yaz) then yaz() end
     net.SendToServer()
end

net.Receive("SardonGelisim.YonetimVeri", function()
     local ent = net.ReadEntity()
     local v = net.ReadTable()
     v.ent = ent
     G.YonetimOyuncu = v
end)

local ROL = {ana = "RAMA PRINCIPAL", yan = "RAMA SECUNDARIA"}

local sayfa = {
     id = "gelisim",
     label = "Desarrollo del personaje",
     icon = "leaf",
     group = "magic",
     order = 36,
     title = "Desarrollo del personaje",
     subtitle = "Da o quita XP o puntos extra a una rama; reinicia rangos por rama, por completo o incluyendo XP.",
     access = "superadmin",
     available = function() return SardonGelisim and SardonGelisim.Kategoriler and #SardonGelisim.Kategoriler > 0 end,

     build = function(ctx)
          local N = ShineAdmin.GetN()
          local u = N.u
          local P = ctx.panel
          local W, H = ctx.w, ctx.h

          local secili
          local LIST_W = 340
          local SX = LIST_W + 24
          local SW = W - SX
          local sag

          local function Veri()
               local v = G.YonetimOyuncu
               if (IsValid(secili) and v and v.ent == secili) then return v end
          end

          local function Hazir()
               local v = Veri()
               return v and v.var
          end

          ShineAdmin.PlayerList(P, 0, 0, u(LIST_W), u(H), function() return secili end, function(p)
               secili = p
               G.YonetimOyuncu = nil
               Istek("oyuncu", p)
               if (IsValid(sag)) then sag.Kur() end
          end)

          sag = vgui.Create("DPanel", P)
          sag:SetPos(u(SX), 0)
          sag:SetSize(u(SW), u(H))
          sag.Paint = function() end

          function sag.Kur()
               sag:Clear()

               if (!IsValid(secili)) then
                    ShineAdmin.Placeholder(sag, 0, 0, u(SW), u(H), "Elige un jugador de la izquierda.")
                    return
               end

               local kart = vgui.Create("DPanel", sag)
               kart:SetPos(0, 0)
               kart:SetSize(u(SW), u(96))
               kart.Paint = function(s, w, h)
                    N.Box(0, 0, w, h, N.Clr.toolBg)
                    N.Outline(0, 0, w, h, N.Clr.toolLine, 1)
                    N.Text(IsValid(secili) and secili:Nick() or "—", "serifsm", u(16), u(14), N.Clr.text)

                    local v = Veri()
                    if (!v) then
                         N.Text("Solicitando al servidor…", "tiny", u(16), u(42), N.Clr.rowDesc)
                         return
                    end
                    if (!v.var) then
                         N.Text("Este jugador no tiene personaje seleccionado.", "tiny", u(16), u(42), N.Clr.warn)
                         return
                    end

                    N.Text("Personaje: " .. v.ad, "tiny", u(16), u(40), N.Clr.rowDesc)
                    local roller = {}
                    for i, d in ipairs(v.dallar) do
                         if (d.rol) then roller[#roller + 1] = G.Kategoriler[i].ad .. (d.rol == "yan" and " (secundaria)" or "") end
                    end
                    N.Text("Ramas: " .. (#roller > 0 and table.concat(roller, ", ") or "aún no elegidas"), "tiny", u(16), u(58), N.Clr.rowDesc)

                    local x = w - u(16)
                    local function Stat(etiket, deger, renk)
                         N.Text(tostring(deger), "count", x, u(38), renk or N.Clr.bigStat, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                         N.Text(etiket, "micro", x, u(68), N.Clr.faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                         x = x - u(120)
                    end
                    Stat("DISPONIBLES", v.puan, N.Clr.goldAccent)
                    Stat("RANGOS ABIERTOS", v.harcanan, N.Clr.tdText)
                    Stat("PUNTOS EXTRA", v.ek or 0, N.Clr.tdText)
               end

               local tumu = N.Button(sag, 0, u(108), u(210), u(36), "Reiniciar rangos", function()
                    local p = secili
                    if (!IsValid(p)) then return end
                    N.Confirm("Reiniciar todos los rangos", "Se borrarán los rangos de todas las ramas del personaje de " .. p:Nick() .. " y se anulará la elección de rama principal/secundaria. El XP y los niveles de rama se mantienen; los puntos vuelven a estar disponibles.", "Reiniciar", function()
                         Istek("tumu", p)
                    end, true)
               end, "danger")
               tumu.Think = function(s) s:SetEnabled(Hazir() and true or false) end

               local tam = N.Button(sag, u(218), u(108), u(170), u(36), "Reiniciar con XP", function()
                    local p = secili
                    if (!IsValid(p)) then return end
                    N.Confirm("Reiniciar desarrollo por completo", "Se borrarán todo el XP de ramas, niveles, rangos, puntos extra y la elección principal/secundaria del personaje de " .. p:Nick() .. ". No se puede deshacer.", "Reiniciar todo", function()
                         Istek("tam", p)
                    end, true)
               end, "danger")
               tam.Think = function(s) s:SetEnabled(Hazir() and true or false) end

               -- seçili dala XP / ek puan (satıra tıklayınca dal seçilir)
               local miktar, seciliDal = nil, 1
               local giris = N.PlainEntry(sag, 0, u(150), u(120), u(36), "Cantidad", function(v)
                    miktar = tonumber(v) and math.floor(math.abs(tonumber(v))) or nil
               end)
               giris.Entry:SetNumeric(true)
               local function MiktarHazir() return Hazir() and miktar and miktar >= 1 and true or false end
               local function XPIste(carpan)
                    local p = secili
                    if (!IsValid(p) or !miktar) then return end
                    Istek("xp", p, function() net.WriteUInt(seciliDal, 4) net.WriteInt(math.min(miktar, 20000) * carpan, 32) end)
               end
               local function EkIste(carpan)
                    local p = secili
                    if (!IsValid(p) or !miktar) then return end
                    Istek("ek", p, function() net.WriteUInt(seciliDal, 4) net.WriteInt(math.min(miktar, 16) * carpan, 16) end)
               end
               local bx = 128
               for _, d in ipairs({{"+XP", 70, function() XPIste(1) end}, {"−XP", 70, function() XPIste(-1) end},
                    {"+Puntos extra", 96, function() EkIste(1) end}, {"−Puntos extra", 96, function() EkIste(-1) end}}) do
                    local btn = N.Button(sag, u(bx), u(150), u(d[2]), u(36), d[1], d[3])
                    btn.Think = function(s) s:SetEnabled(MiktarHazir()) end
                    bx = bx + d[2] + 8
               end
               local etiket = vgui.Create("DPanel", sag)
               etiket:SetPos(u(bx + 8), u(150))
               etiket:SetSize(u(math.max(60, SW - bx - 8)), u(36))
               etiket.Paint = function(s, w, h)
                    local kat = G.Kategoriler[seciliDal]
                    N.Text("Rama seleccionada: " .. (kat and kat.ad or "?") .. "  ·  XP máx. 20.000, puntos extra máx. 16", "tiny", 0, h / 2, N.Clr.rowDesc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               end

               local head = vgui.Create("DPanel", sag)
               head:SetPos(0, u(196))
               head:SetSize(u(SW), u(30))
               head.Paint = function(s, w, h)
                    N.TableHead(0, 0, w, {{"Rama de desarrollo", u(16)}, {"Rol", u(170)}, {"Nivel · XP", u(270)}, {"Rango", u(420)}, {"Puntos", u(500)}})
               end

               local RH = 34 -- gövde 514 yüksekliğinde: 226 + 8 × 34 = 498
               for i, kat in ipairs(G.Kategoriler) do
                    local satir = vgui.Create("DPanel", sag)
                    satir:SetPos(0, u(226 + (i - 1) * RH))
                    satir:SetSize(u(SW), u(RH))
                    satir:SetCursor("hand")
                    satir.OnMousePressed = function() seciliDal = i end
                    satir.Paint = function(s, w, h)
                         if (seciliDal == i) then N.Box(0, 0, w, h, N.Clr.toolBg) end
                         N.Box(0, h - 1, w, 1, N.Clr.tableLine)
                         local v = Veri()
                         local d = v and v.var and v.dallar[i]
                         N.Text(kat.ad, "row", u(16), h / 2, d and (d.n > 0 or d.xp > 0) and N.Clr.tdFirst or N.Clr.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         if (!d) then return end
                         N.Text(ROL[d.rol] or (d.etkin == "rolsuz" and "otra" or "—"), "small", u(170), h / 2, d.rol == "ana" and N.Clr.gold or (d.rol and N.Clr.tdText or N.Clr.faint), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text("Nv " .. d.sv .. "/" .. d.tavan .. " · " .. d.xp, "small", u(270), h / 2, d.xp > 0 and N.Clr.tdText or N.Clr.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(d.n .. " / " .. d.ust, "small", u(420), h / 2, N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(d.hak .. (d.ek != 0 and (" (extra " .. d.ek .. ")") or ""), "strong", u(500), h / 2, d.hak > 0 and N.Clr.gold or N.Clr.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end

                    local btn = N.Button(satir, u(SW - 130), u((RH - 28) / 2), u(130), u(28), "Reiniciar", function()
                         local p = secili
                         local v = Veri()
                         local d = v and v.var and v.dallar[i]
                         if (!IsValid(p) or !d) then return end
                         N.Confirm("Reiniciar rangos de " .. kat.ad, "Se borrarán " .. d.n .. " rangos de la rama " .. kat.ad .. " del personaje de " .. p:Nick() .. "; el nivel y XP de la rama se mantienen y los puntos vuelven a estar disponibles." .. (d.rol and (" Quedará libre el hueco de rama " .. (d.rol == "ana" and "principal" or "secundaria") .. "; la siguiente rama que abra un rango ocupará ese hueco.") or ""), "Reiniciar", function()
                              Istek("dal", p, function() net.WriteUInt(i, 4) end)
                         end, true)
                    end)
                    btn.Think = function(s)
                         local v = Veri()
                         local d = v and v.var and v.dallar[i]
                         s:SetEnabled(d and (d.n > 0 or d.rol != nil) and true or false)
                    end
               end
          end

          ctx.SetHead({
               note = function()
                    return #G.Kategoriler .. " RAMAS DE DESARROLLO"
               end
          })

          sag.Kur()
     end
}

ShineAdmin = ShineAdmin or {}
ShineAdmin.Pages = ShineAdmin.Pages or {}
ShineAdmin.Pages.gelisim = sayfa

concommand.Add("sardon_gelisim_admin", function()
     if (ShineAdmin and ShineAdmin.Open) then ShineAdmin:Open("gelisim") end
end, nil, "Abre Shine Admin > Desarrollo del personaje")