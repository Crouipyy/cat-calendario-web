-- "addons\\sardoniksir\\lua\\sardon_iksir\\potion_zkazan\\cl_7yonetim.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon İksir :: Shine Admin › Kazanlar (yetkili görür, süper admin yazar; sunucu sv_3yonetim.lua)
--   Kademeler: fiyat ve istatistikler · Oyuncular: calderos ver / kademe değiştir · Kayıt: alım, yükseltme,
--   yönetim işlemleri · Ayar: Discord webhook, dünya kipi, sınıf standları (/KazanStand)

local I = SardonIksir

I.Yon = I.Yon or {veri = nil, surum = 0}
local Y = I.Yon

local function Istek(islem, tablo)
     local veri = tablo and util.TableToJSON(tablo) or ""
     net.Start("SardonKazan.Yonetim")
     net.WriteString(islem)
     net.WriteUInt(#veri, 16)
     if #veri > 0 then net.WriteData(veri, #veri) end
     net.SendToServer()
end

net.Receive("SardonKazan.YonetimVeri", function()
     local n = net.ReadUInt(32)
     Y.veri = util.JSONToTable(util.Decompress(net.ReadData(n)) or "") or {}
     Y.surum = Y.surum + 1
end)

local ALANLAR = {
     {"fiyat", "Precio (G)", 0}, {"bolge", "Zona de fuego ×", 2}, {"sure", "Duración ×", 2},
     {"bonus", "Puntos +", 3}, {"cift", "Segunda frasco", 2}, {"direnc", "Resistencia ×", 2},
}

local ISLEM_AD = {al = "Compró estaño", yukselt = "Mejoró", ver = "Lo dio administración", kademe = "Cambió de nivel", ayar = "Ajustes"}

local sayfa = {
     id = "kazan",
     label = "Calderos",
     icon = "flame",
     group = "magic",
     order = 38,
     title = "Calderos por rareza",
     subtitle = "Calderos del señor Arthur: estadísticas por nivel, dar calderos a jugadores, registro de compras y mejoras.",
     access = "staff",
     available = function() return SardonIksir ~= nil and SardonIksir.KazanTanim ~= nil end,

     build = function(ctx)
          local N = ShineAdmin.GetN()
          local u = N.u
          local P = ctx.panel
          local W, H = ctx.w, ctx.h
          local aktif = Y.sonSekme or "kademe"
          local govde, SekmeKur
          local GY = 56
          local GH = H - GY

          N.SubTabs(P, 0, 0, u(W), {{"kademe", "Niveles"}, {"oyuncu", "Jugadores"}, {"kayit", "Registro"}, {"ayar", "Ajustes"}},
               function() return aktif end, function(id)
                    if aktif == id then return end
                    aktif = id
                    Y.sonSekme = id
                    SekmeKur()
               end)

          local function Bilgi(parent, x, y, w, metin, renk)
               local satirlar = N.Wrap and N.Wrap(metin, "tiny", u(w)) or {metin}
               local p = vgui.Create("DPanel", parent)
               p:SetPos(u(x), u(y))
               p:SetSize(u(w), #satirlar * u(15) + u(4))
               p.Paint = function()
                    for i, s in ipairs(satirlar) do N.Text(s, "tiny", 0, (i - 1) * u(15), renk or N.Clr.rowDesc) end
               end
               return #satirlar * 15 + 4
          end

          local function Yazabilir() return Y.veri and Y.veri.yaz end

          local KUR = {}

          -- Kademeler: her satır bir kademe, alanlar metin kutusu (boş = varsayılan)
          KUR.kademe = function()
               local taslak = table.Copy(Y.veri and Y.veri.ayar or {})
               local colW = math.floor((W - 200) / #ALANLAR)
               local sc = N.Scroll(govde, 0, 0, u(W), u(GH - 60))
               local bas = vgui.Create("DPanel", sc)
               bas:SetSize(u(W), u(30))
               bas.Paint = function()
                    local cols = {{"Nivel", u(10)}}
                    for i, a in ipairs(ALANLAR) do cols[#cols + 1] = {a[2], u(190 + (i - 1) * colW)} end
                    N.TableHead(0, 0, u(W), cols)
               end
               for k = 0, I.KAZAN_EN_UST do
                    local t = I.KazanVarsayilan[k]
                    local y = 38 + k * 46
                    local ad = vgui.Create("DPanel", sc)
                    ad:SetPos(0, u(y))
                    ad:SetSize(u(185), u(38))
                    ad.Paint = function()
                         N.Box(0, u(16), u(4), u(10), t.renk)
                         N.Text(t.ad .. " · " .. t.nadir, "body", u(12), u(20), N.Clr.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end
                    taslak[k] = taslak[k] or taslak[tostring(k)] or {}
                    taslak[tostring(k)] = nil
                    for i, a in ipairs(ALANLAR) do
                         local w, e = N.PlainEntry(sc, u(190 + (i - 1) * colW), u(y), u(colW - 10), u(36), tostring(t[a[1]]))
                         local v = taslak[k][a[1]]
                         if v ~= nil then e:SetValue(tostring(v)) end
                         e:SetEnabled(Yazabilir() and true or false)
                         e.OnValueChange = function(s, deger)
                              local x = tonumber(deger)
                              taslak[k][a[1]] = x
                         end
                    end
               end
               local bar = N.StickyBar(govde, 0, u(GH - 52), u(W), function()
                    if not Yazabilir() then return "Solo el superadmin puede cambiar." end
                    return "Los campos vacíos usan el valor por defecto. Platino «mezcla por sí mismo» está activo en código."
               end)
               if Yazabilir() then
                    N.Button(bar, u(W) - u(150), u(8), u(150), u(36), "Guardar", function()
                         -- anahtarlar metin: 0..6 sayısal kalırsa JSON 0'ı (Klasik) dizi dışı sayıp düşürebilir
                         local gonder = {}
                         for k, t in pairs(taslak) do gonder[tostring(k)] = t end
                         Istek("ayar", {veri = gonder})
                         ctx.Flash("Ajustes de caldero enviados.")
                    end, "primary")
                    N.Button(bar, u(W) - u(330), u(8), u(170), u(36), "Restaurar valores", function()
                         N.Confirm("Restaurar valores", "Precios y estadísticas de todos los niveles vuelven a los valores del código.", "Restaurar", function()
                              Istek("sifirla")
                         end, true)
                    end)
               end
          end

          -- Oyuncular: çevrimiçi karakterler ve calderosları
          KUR.oyuncu = function()
               local v = Y.veri or {}
               local sol = N.Scroll(govde, 0, 0, u(W), u(GH))
               local y = 0
               if not Yazabilir() then
                    y = Bilgi(sol, 0, 0, W, "Modo solo lectura: dar calderos y cambiar nivel solo para superadmin.", N.Clr.warn) + 8
               end
               for _, o in ipairs(v.oyuncular or {}) do
                    local satirH = 44 + #o.kazanlar * 40
                    local p = vgui.Create("DPanel", sol)
                    p:SetPos(0, u(y))
                    p:SetSize(u(W - 12), u(satirH))
                    p.Paint = function(s, pw, ph)
                         N.Card(0, 0, pw, ph)
                         N.Text(o.ad, "body", u(14), u(20), N.Clr.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(o.sid .. "  ·  " .. #o.kazanlar .. " calderos", "tiny", u(220), u(20), N.Clr.rowDesc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         for j, kz in ipairs(o.kazanlar) do
                              local t = I.KazanTanim(kz.k)
                              N.Box(u(14), u(44 + (j - 1) * 40 + 10), u(4), u(14), t.renk)
                              N.Text("#" .. kz.id .. "  " .. t.ad .. " Kazan" .. (kz.kurulu and "  (kurulu)" or ""), "small", u(26), u(44 + (j - 1) * 40 + 17), N.Clr.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         end
                    end
                    if Yazabilir() then
                         local secK = 1
                         local secenek = {}
                         for k = 1, I.KAZAN_EN_UST do secenek[k] = I.KazanAdi(k) end
                         -- N.Combo: seçenekler düz metin, geri çağrı (değer, veri, sıra)
                         N.Combo(p, u(W - 430), u(6), u(150), u(32), I.KazanAdi(1), secenek, function(_, _, sira)
                              secK = math.Clamp(tonumber(sira) or 1, 1, I.KAZAN_EN_UST)
                         end)
                         N.Button(p, u(W - 270), u(6), u(240), u(32), "Dar este caldero", function()
                              Istek("ver", {i = o.i, k = secK})
                         end, "primary")
                         for j, kz in ipairs(o.kazanlar) do
                              local yy = 44 + (j - 1) * 40 + 3
                              N.Button(p, u(W - 270), u(yy), u(110), u(30), "− nivel", function()
                                   Istek("kademe", {id = kz.id, k = kz.k - 1})
                              end)
                              N.Button(p, u(W - 150), u(yy), u(110), u(30), "+ nivel", function()
                                   Istek("kademe", {id = kz.id, k = kz.k + 1})
                              end)
                         end
                    end
                    y = y + satirH + 8
               end
               if #(v.oyuncular or {}) == 0 then Bilgi(sol, 0, y, W, "No hay personajes en línea.") end
          end

          -- Kayıt
          KUR.kayit = function()
               local v = Y.veri or {}
               local sc = N.Scroll(govde, 0, 0, u(W), u(GH))
               local bas = vgui.Create("DPanel", sc)
               bas:SetSize(u(W - 12), u(30))
               bas.Paint = function()
                    N.TableHead(0, 0, u(W - 12), {{"Fecha", u(10)}, {"Personaje", u(150)}, {"Acción", u(390)}, {"Caldero", u(540)}, {"Coste", u(730)}, {"Admin", u(830)}})
               end
               for i, r in ipairs(v.kayit or {}) do
                    local p = vgui.Create("DPanel", sc)
                    p:SetPos(0, u(32 + (i - 1) * 30))
                    p:SetSize(u(W - 12), u(28))
                    p.Paint = function(s, pw, ph)
                         if i % 2 == 0 then N.Box(0, 0, pw, ph, N.Clr.card) end
                         local c = N.Clr.text
                         N.Text(os.date("%d.%m %H:%M", r.z or 0), "tiny", u(10), ph / 2, N.Clr.rowDesc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(r.ad or "", "small", u(150), ph / 2, c, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(ISLEM_AD[r.i] or r.i or "", "small", u(390), ph / 2, c, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         if r.i ~= "ayar" then
                              local a = (r.e or 0) > 0 and I.KazanTanim(r.e).ad or "—"
                              N.Text(a .. " → " .. I.KazanTanim(r.y or 1).ad, "small", u(540), ph / 2, c, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         end
                         N.Text((r.b or 0) > 0 and (r.b .. " G") or "", "small", u(730), ph / 2, c, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(r.yon or "", "tiny", u(830), ph / 2, N.Clr.rowDesc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end
               end
               if #(v.kayit or {}) == 0 then Bilgi(sc, 0, 40, W, "Aún no hay registros.") end
          end

          -- Ayar: Discord, dünya kipi, sınıf standları
          KUR.ayar = function()
               local v = Y.veri or {}
               local y = Bilgi(govde, 0, 0, W, "Discord: compras, mejoras y acciones de administración van a este webhook. La URL solo se guarda en el servidor, no se envía a clientes.") + 8
               if Yazabilir() then
                    local w, e = N.PlainEntry(govde, 0, u(y), u(W - 180), u(36), v.discord and "(hay URL guardada — pega una nueva o deja vacío y guarda)" or "https://discord.com/api/webhooks/…")
                    N.Button(govde, u(W - 170), u(y), u(170), u(36), "Guardar webhook", function()
                         Istek("discord", {url = e:GetValue()})
                    end, "primary")
                    y = y + 48
               else
                    y = y + Bilgi(govde, 0, y, W, v.discord and "Webhook guardado." or "No hay webhook guardado.") + 8
               end
               y = y + 10
               y = y + Bilgi(govde, 0, y, W, "Modo mundo: " .. (v.dunya and "ACTIVO (hervir junto al caldero, en el mundo)" or "DESACTIVADO (pantalla 2D antigua)") .. ". Para desactivar: potion_zkazan/_sh_1kademe.lua → SardonIksir.DunyaKipi = false.") + 10
               y = y + Bilgi(govde, 0, y, W, "Atriles de clase: " .. (v.stand or 0) .. " atriles, " .. (v.standAtanan or 0) .. " con caldero Clásico. Para colocar: cerca del atril, mira suelo plano y /KazanStand; quitar: /KazanStandSil; lista: /KazanStandlar. Atril sin caldero usa la pantalla antigua.")
          end

          SekmeKur = function()
               if IsValid(govde) then govde:Remove() end
               govde = vgui.Create("DPanel", P)
               govde:SetPos(0, u(GY))
               govde:SetSize(u(W), u(GH))
               govde.Paint = nil
               govde.surum = Y.surum
               govde.veriYok = Y.veri == nil
               govde.Think = function(s)
                    if s.surum ~= Y.surum then
                         s.surum = Y.surum
                         -- Kademeler'de yazılanlar gitmesin diye yeniden kurulmaz; ama veri gelmeden kurulduysa kurulur
                         -- (11-06: "Cargando…" ekranında takılı kalıyordu)
                         if aktif ~= "kademe" or s.veriYok then SekmeKur() end
                    end
               end
               if not Y.veri then
                    Bilgi(govde, 0, 0, W, "Cargando…")
                    return
               end
               if KUR[aktif] then KUR[aktif]() end
          end

          ctx.SetHead({
               note = function()
                    local v = Y.veri or {}
                    return #(v.oyuncular or {}) .. " EN LÍNEA  ·  " .. #(v.kayit or {}) .. " REGISTROS"
               end
          })
          SekmeKur()
          Istek("iste")
          return function() Istek("iste") end
     end
}

ShineAdmin = ShineAdmin or {}
ShineAdmin.Pages = ShineAdmin.Pages or {}
ShineAdmin.Pages.kazan = sayfa

concommand.Add("sardon_kazan_admin", function()
     if not ShineAdmin or not isfunction(ShineAdmin.Open) then
          local msg = "Shine Admin no está cargado en el cliente. Reconecta al servidor e inténtalo de nuevo."
          MsgC(Color(255, 130, 80), "[kazan_admin] ", color_white, msg .. "\n")
          chat.AddText(Color(255, 130, 80), "[kazan_admin] ", color_white, msg)
          return
     end
     ShineAdmin:Open("kazan")
end, nil, "Shine Admin > Calderos")
