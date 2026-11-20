-- "addons\\sardongacha\\lua\\sardon_gacha\\cl_7yonetim.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Shine Admin › Asa Dileği. Sekmeler:
*   Afişler   — dönem afişleri: ad, etiket, görsel URL (TAB'daki tema görseli), arka plan URL, açıklama,
*               aktif, tür (etkinlik/standart), başlangıç-bitiş, nadirlik oranları ve pity, öne çıkan
*               (UP) payı, havuz (asa, görünen ad, ★3/★4/★5, ağırlık, UP) ve her varitasnın etkin oranı.
*   Ekonomi   — para birimi adları, bilet fiyatı (Ofrenda), toz değerleri, toz→bilet, pity yazısı.
*   Oyuncular — çevrimiçi oyuncular ve SteamID64 ile arama: cüzdana ekle/çıkar, pity sıfırla, son dilekler.
*   Kayıtlar  — afiş başına çekiliş sayıları ve son cüzdan hareketleri.
*   Sunucu tarafı sv_4yonetim (yalnız SG.Yonetici). Açmak: Shine Admin › Sistemler › Asa Dileği
*   ya da konsol "sardon_gacha_admin".
*/
local SG = SardonGacha

SG.YVeri = SG.YVeri or {}
SG.YSurum = SG.YSurum or 0

net.Receive("SardonGacha.YonetimVeri", function()
     local t = SG.Oku()
     if not t then return end
     SG.YVeri = t
     SG.YSurum = SG.YSurum + 1
     if t.ileti and ShineAdmin and ShineAdmin.Ctx and ShineAdmin.Ctx.Flash then ShineAdmin.Ctx.Flash(t.ileti) end
     hook.Run("SardonGachaYonetimVeri", t)
end)

local function Iste(islem, arg)
     local s = util.Compress(util.TableToJSON(arg or {}) or "{}") or ""
     net.Start("SardonGacha.Yonetim")
     net.WriteString(islem)
     net.WriteUInt(#s, 32)
     net.WriteData(s, #s)
     net.SendToServer()
end
SG.YIste = Iste

-- "0,6" → 0.6 (gsub iki değer döndürür; tonumber'a yalnız metin gitsin)
local function SayiOku(v)
     return tonumber((string.gsub(tostring(v or ""), ",", ".")))
end

local function Tarih(t)
     t = tonumber(t) or 0
     return t > 0 and os.date("%d.%m.%Y %H:%M", t) or ""
end

-- "gg.aa.yyyy ss:dd" → unix (boş = 0, hatalı = nil)
local function TarihOku(s)
     s = string.Trim(s or "")
     if s == "" then return 0 end
     local g, a, y, sa, dk = s:match("^(%d+)%.(%d+)%.(%d+)%s*(%d*):?(%d*)$")
     if not g then return nil end
     return os.time({ year = tonumber(y), month = tonumber(a), day = tonumber(g), hour = tonumber(sa) or 0, min = tonumber(dk) or 0, sec = 0 })
end

local function OneriYildiz(skin)
     -- kaplama kendi gacha yıldızını bildiriyorsa o (staylofft beş yıldız varitasları: Skin.GachaYildiz = 5)
     local sp = HpwRewrite and HpwRewrite.GetSpell and HpwRewrite:GetSpell(skin)
     local gy = sp and tonumber(sp.GachaYildiz)
     if gy then return math.Clamp(math.floor(gy), 3, 5) end
     local O = SardonOli
     local s = O and O.SablonKaplama and O.SablonKaplama[skin]
     if not s then return 3 end
     if s.yildiz >= 4 then return 5 end
     if s.yildiz == 3 then return 4 end
     return 3
end

local function Kaplamalar()
     local t = {}
     for ad, sp in pairs(HpwRewrite and HpwRewrite:GetSpells() or {}) do
          if sp.IsSkin then t[#t + 1] = { skin = ad, model = sp.WorldModel or "models/hpwrewrite/w_magicwand.mdl" } end
     end
     table.sort(t, function(a, b) return a.skin:lower() < b.skin:lower() end)
     return t
end

local function Etiket(N, ebeveyn, x, y, w, metin)
     local p = vgui.Create("DPanel", ebeveyn)
     p:SetPos(x, y)
     p:SetSize(w, N.u(18))
     p.Paint = function() N.Text(metin, "tiny", 0, N.u(2), N.Clr.rowDesc) end
     return p
end

-- Etiketli giriş: değer metin olarak yazılır, onChange(v) her harfte çağrılır
local function Alan(N, ebeveyn, x, y, w, etiket, deger, onChange)
     Etiket(N, ebeveyn, x, y, w, etiket)
     local wrap, e = N.PlainEntry(ebeveyn, x, y + N.u(18), w, N.u(32), "", function(v) onChange(v) end)
     e:SetValue(tostring(deger or ""))
     return wrap, e
end

/*
*   Açılır pencere (Shine Admin'in üstünde)
*/
local function Pencere(N, baslik, w, h, kurucu)
     local u = N.u
     local ort = vgui.Create("EditablePanel")
     ort:SetSize(ScrW(), ScrH())
     ort:MakePopup()
     ort:SetKeyboardInputEnabled(true)
     local px, py = ScrW() / 2 - u(w) / 2, ScrH() / 2 - u(h) / 2
     ort.Paint = function(s, pw, ph)
          N.Box(0, 0, pw, ph, Color(0, 0, 0, 170))
          N.Box(px, py, u(w), u(h), N.Clr.bg)
          N.Outline(px, py, u(w), u(h), N.Clr.railLine, 1)
          N.Text(baslik, "title", px + u(24), py + u(16), N.Clr.text)
          N.Box(px + u(24), py + u(58), u(w - 48), 1, N.Clr.headLine)
     end
     ort.OnMousePressed = function(s)
          local mx, my = s:CursorPos()
          if mx < px or mx > px + u(w) or my < py or my > py + u(h) then s:Remove() end
     end
     ort.OnKeyCodePressed = function(s, k) if k == KEY_ESCAPE then s:Remove() end end
     N.Button(ort, px + u(w - 110), py + u(14), u(86), u(32), "Cerrar", function() ort:Remove() end, "quiet")
     local ic = vgui.Create("EditablePanel", ort)
     ic:SetPos(px + u(24), py + u(72))
     ic:SetSize(u(w - 48), u(h - 92))
     kurucu(ic, w - 48, h - 92, ort)
     return ort
end

/*
*   Asa seçici: aranır, Ollivander yıldızına göre önerilen nadirlikle eklenir
*/
local function AsaSecici(N, havuz, eklendi)
     local u = N.u
     local hepsi = Kaplamalar()
     Pencere(N, "Añadir varita al pool", 980, 660, function(ic, W, H, ort)
          local filtre = ""
          local liste
          local function Var(skin)
               for _, e in ipairs(havuz) do if e.skin == skin then return true end end
               return false
          end
          local function Gorunen()
               local t = {}
               local f = filtre:lower()
               for _, k in ipairs(hepsi) do
                    if f == "" or k.skin:lower():find(f, 1, true) or SG.AsaAd(k.skin):lower():find(f, 1, true) then t[#t + 1] = k end
               end
               return t
          end
          local function Ekle(k, y)
               if Var(k.skin) then return end
               havuz[#havuz + 1] = { skin = k.skin, ad = "", y = y, w = 1, up = false, model = k.model }
               eklendi()
          end
          local function Doldur()
               liste:Clear()
               for _, k in ipairs(Gorunen()) do
                    local satir = vgui.Create("DPanel", liste)
                    satir:Dock(TOP)
                    satir:DockMargin(0, 0, u(8), u(4))
                    satir:SetTall(u(52))
                    local oneri = OneriYildiz(k.skin)
                    satir.Paint = function(s, w, h)
                         local var = Var(k.skin)
                         N.Box(0, 0, w, h, s:IsHovered() and N.Clr.cardHover or N.Clr.toolBg)
                         N.Box(0, 0, u(3), h, SG.YildizRenk(oneri))
                         local sx, sy = s:LocalToScreen(u(10), u(4))
                         SG.AsaCiz(k.model, sx, sy, u(120), h - u(8), { aci = 18, donus = 30, dolu = 0.95, isik = SG.YildizIsik(oneri) })
                         N.Text(SG.AsaAd(k.skin), "small", u(144), u(9), var and N.Clr.faint or N.Clr.text)
                         N.Text(k.skin .. "   ·   sugerida ★" .. oneri .. (var and "   ·   en el pool" or ""), "tiny", u(144), u(30), var and N.Clr.ok or N.Clr.rowDesc)
                    end
                    for y = 3, 5 do
                         N.Button(satir, u(W - 8) - u(78) * (6 - y) - u(10), u(10), u(70), u(32), "★" .. y, function()
                              Ekle(k, y)
                         end, y == oneri and "primary" or "ghost")
                    end
               end
          end
          N.TextEntry(ic, 0, 0, u(W * 0.5), u(36), "Buscar varita (nombre o skin)…", function(v)
               filtre = v or ""
               Doldur()
          end)
          N.Button(ic, u(W * 0.5 + 12), 0, u(W * 0.5 - 12), u(36), "Añadir visibles con estrella sugerida", function()
               for _, k in ipairs(Gorunen()) do Ekle(k, OneriYildiz(k.skin)) end
          end)
          liste = N.Scroll(ic, 0, u(48), u(W), u(H - 48))
          Doldur()
     end)
end

/*
*   Sekmeler
*/
local SEKMELER = { { "afisler", "Pósters" }, { "ekonomi", "Economía" }, { "oyuncular", "Jugadores" }, { "kayit", "Registros" } }
local sekme = "afisler"
local secili, duzen
local KURUCU = {}

local function AfisKopya(a)
     local t = table.Copy(a)
     t.havuz = t.havuz or {}
     for _, e in ipairs(t.havuz) do
          local sp = HpwRewrite and HpwRewrite:GetSpell(e.skin)
          e.model = sp and sp.WorldModel or "models/hpwrewrite/w_magicwand.mdl"
     end
     return t
end

local function YeniAfis()
     local a = table.Copy(SG.AfisVarsayilan)
     a.id = ""
     a.ad = "Póster nuevo"
     a.bas = os.time()
     a.bit = os.time() + 21 * 86400
     return a
end

local function Durum(a)
     if not a.aktif then return "Cerrado", false end
     local simdi = os.time() + (SG.SaatFark or 0)
     if (a.bas or 0) > 0 and simdi < a.bas then return "En espera", nil end
     if (a.bit or 0) > 0 and simdi >= a.bit then return "Terminado", nil end
     return "Abierto", true
end

KURUCU.afisler = function(N, kok, W, H, yenidenKur)
     local u = N.u
     local V = SG.YVeri
     local afisler = V.afisler or {}

     -- seçim
     if V.secili then
          secili = V.secili
          V.secili = nil
          duzen = nil
     end
     if not duzen then
          for _, a in ipairs(afisler) do if a.id == secili then duzen = AfisKopya(a) end end
          if not duzen and afisler[1] and secili ~= "" then
               secili = afisler[1].id
               duzen = AfisKopya(afisler[1])
          end
     end

     -- sol liste
     local LW = 290
     N.Button(kok, 0, 0, u(LW), u(36), "+  Nuevo póster", function()
          secili = ""
          duzen = YeniAfis()
          yenidenKur()
     end, "primary")
     local liste = N.Scroll(kok, 0, u(46), u(LW), u(H - 46))
     for _, a in ipairs(afisler) do
          local satir = vgui.Create("DButton", liste)
          satir:SetText("")
          satir:Dock(TOP)
          satir:DockMargin(0, 0, u(6), u(4))
          satir:SetTall(u(58))
          satir.DoClick = function()
               secili = a.id
               duzen = AfisKopya(a)
               yenidenKur()
          end
          satir.Paint = function(s, w, h)
               local sec = secili == a.id
               N.Box(0, 0, w, h, sec and N.Clr.cardSel or (s:IsHovered() and N.Clr.cardHover or N.Clr.toolBg))
               local dt, acik = Durum(a)
               N.Box(0, 0, u(3), h, acik and N.Clr.ok or N.Clr.faint)
               N.Text(N.Clip(a.ad or "?", "small", w - u(24)), "small", u(14), u(8), sec and N.Clr.goldAccent or N.Clr.text)
               N.Text(dt .. "  ·  " .. (a.tur == "standart" and "Estándar" or "Evento") .. "  ·  " .. #(a.havuz or {}) .. " varitas", "tiny", u(14), u(30), N.Clr.rowDesc)
          end
     end

     if not duzen then
          local bos = vgui.Create("DPanel", kok)
          bos:SetPos(u(LW + 16), 0)
          bos:SetSize(u(W - LW - 16), u(H))
          bos.Paint = function(_, w, h) N.Text("Elige un póster a la izquierda o crea uno nuevo.", "small", w / 2, h / 2, N.Clr.rowDesc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
          return
     end

     -- düzenleyici
     local EX = LW + 16
     local EW = W - EX - 14
     local sc = N.Scroll(kok, u(EX), 0, u(EW + 14), u(H - 50))
     local d = duzen
     local y = 0
     local yarim = math.floor((EW - 16) / 2)
     local ceyrek = math.floor((EW - 48) / 4)

     Alan(N, sc, 0, u(y), u(yarim), "Nombre del póster (título grande en la pestaña)", d.ad, function(v) d.ad = v end)
     Alan(N, sc, u(yarim + 16), u(y), u(yarim), "Etiqueta (pastilla arriba a la izq.; si vacía, nombre del tipo)", d.etiket, function(v) d.etiket = v end)
     y = y + 62
     Alan(N, sc, 0, u(y), u(EW - 150), "URL de imagen (tema en pestaña; png/jpg, ~2:1 horizontal recomendado)", d.gorsel, function(v) d.gorsel = string.Trim(v) end)
     N.Button(sc, u(EW - 140), u(y + 18), u(140), u(32), "Volver a descargar", function() SG.UrlUnut(d.gorsel) end)
     y = y + 62
     -- önizleme
     local on = vgui.Create("DPanel", sc)
     on:SetPos(0, u(y))
     on:SetSize(u(EW), u(170))
     on.Paint = function(_, w, h)
          N.Box(0, 0, w, h, N.Clr.inputBg)
          N.Outline(0, 0, w, h, N.Clr.inputLine, 1)
          local pw, ph = u(330), h - u(16)
          local mat, durum = SG.UrlMat(d.gorsel)
          if mat then SG.Kapla(mat, u(8), u(8), pw, ph, 1) else N.Text(d.gorsel == "" and "Sin imagen (se usa fondo celestial)" or (durum == "iniyor" and "Descargando…" or "No se pudo descargar: el enlace debe ser png/jpg directo"), "tiny", u(8) + pw / 2, h / 2, N.Clr.rowDesc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
          N.Outline(u(8), u(8), pw, ph, N.Clr.goldSoft, 1)
          local ox = u(356)
          local _, base = SG.AsaOranlari(d)
          N.Text("Vista previa y resumen de probabilidades", "small", ox, u(12), N.Clr.goldAccent)
          N.Text("★5 base " .. SG.Yuzde(taban[5], 2) .. "  ·  media con pity " .. SG.Yuzde(SG.Ortalama5(d), 2), "small", ox, u(40), N.Clr.text)
          N.Text("★4 base " .. SG.Yuzde(taban[4], 2) .. "  ·  media " .. SG.Yuzde(SG.Ortalama4(d), 2), "small", ox, u(62), N.Clr.text)
          N.Text("★3 base " .. SG.Yuzde(taban[3], 2), "small", ox, u(84), N.Clr.text)
          local say = { [3] = 0, [4] = 0, [5] = 0 }
          local up = 0
          for _, e in ipairs(d.havuz) do say[e.y] = (say[e.y] or 0) + 1 if e.up then up = up + 1 end end
          N.Text("Havuz: ★5 " .. say[5] .. "  ·  ★4 " .. say[4] .. "  ·  ★3 " .. say[3] .. "  ·  destacadas " .. up, "small", ox, u(112), N.Clr.text)
          local uyari
          if say[5] == 0 or say[4] == 0 or say[3] == 0 then uyari = "Aviso: hay rareza vacía; si sale, salta a la rareza llena más cercana." end
          if d.tur ~= "standart" and up == 0 then uyari = "Nota: sin varita destacada (UP); no funciona el cartel «Probabilidad aumentada» ni el 50/50." end
          if uyari then N.Text(uyari, "tiny", ox, u(140), N.Clr.warn) end
     end
     y = y + 182
     Alan(N, sc, 0, u(y), u(EW), "URL fondo de página (opcional; si vacío, cielo Celestial)", d.arkaplan, function(v) d.arkaplan = string.Trim(v) end)
     y = y + 62
     Etiket(N, sc, 0, u(y), u(EW), "Descripción (bajo el título; si vacía, texto por defecto)")
     local _, ae = N.PlainEntry(sc, 0, u(y + 18), u(EW), u(66), "", function(v) d.aciklama = v end)
     ae:SetMultiline(true)
     ae:SetTall(u(62))
     ae:SetValue(d.aciklama or "")
     y = y + 96

     local tw = math.floor((EW - 32) / 3)
     N.Toggle(sc, 0, u(y), u(tw), u(50), "Aktif", function() return d.aktif end, function(v) d.aktif = v end, "Si está cerrado no aparece en la pestaña.")
     N.Toggle(sc, u(tw + 16), u(y), u(tw), u(50), "Modelo ★5 destacado", function() return d.model end, function(v) d.model = v end, "Varita 3D girando sobre la imagen.")
     N.Toggle(sc, u((tw + 16) * 2), u(y), u(tw), u(50), "Garanti (50/50)", function() return d.garanti end, function(v) d.garanti = v end, "Quien falla la destacada la obtiene en el siguiente intento garantizado.")
     y = y + 62

     Etiket(N, sc, 0, u(y), u(ceyrek), "Tipo")
     N.Combo(sc, 0, u(y + 18), u(ceyrek), u(32), d.tur == "standart" and "Estándar" or "Evento", { "Evento", "Estándar" }, function(_, _, i) d.tur = i == 2 and "standart" or "etkinlik" end)
     Alan(N, sc, u(ceyrek + 16), u(y), u(ceyrek), "Orden (menor = primero)", d.sira, function(v) d.sira = tonumber(v) or d.sira end)
     local _, basE = Alan(N, sc, u((ceyrek + 16) * 2), u(y), u(ceyrek), "Inicio (dd.mm.aaaa hh:mm)", Tarih(d.bas), function(v) local t = TarihOku(v) if t then d.bas = t end end)
     local _, bitE = Alan(N, sc, u((ceyrek + 16) * 3), u(y), u(ceyrek), "Fin (vacío = sin límite)", Tarih(d.bit), function(v) local t = TarihOku(v) if t then d.bit = t end end)
     y = y + 62
     local hizli = { { "Empezar ahora", function() d.bas = os.time() basE:SetValue(Tarih(d.bas)) end },
          { "+7 días", function() d.bit = math.max(os.time(), d.bas or 0) + 7 * 86400 bitE:SetValue(Tarih(d.bit)) end },
          { "+14 días", function() d.bit = math.max(os.time(), d.bas or 0) + 14 * 86400 bitE:SetValue(Tarih(d.bit)) end },
          { "+21 días", function() d.bit = math.max(os.time(), d.bas or 0) + 21 * 86400 bitE:SetValue(Tarih(d.bit)) end },
          { "Sin límite", function() d.bit = 0 bitE:SetValue("") end } }
     local hw = math.floor((EW - 4 * 10) / 5)
     for i, hz in ipairs(hizli) do N.Button(sc, u((hw + 10) * (i - 1)), u(y), u(hw), u(30), hz[1], hz[2]) end
     y = y + 44

     Etiket(N, sc, 0, u(y), u(EW), "PROBABILIDADES Y PITY  (Genshin varsayılanı: ★5 %0,6 · ★4 %5,1 · ★5 kesin 90 · yumuşak 74'ten +%6 · ★4 kesin 10 · UP %50)")
     y = y + 22
     local sayilar = {
          { "b5", "★5 base (%)" }, { "b4", "★4 base (%)" }, { "h5", "★5 garantía (tirada)" }, { "s5", "Inicio pity suave (tirada, 0 = ninguno)" },
          { "a5", "Incremento suave (% / tirada)" }, { "h4", "★4+ garantía (tirada)" }, { "up5", "Cuota ★5 destacada (%)" }, { "up4", "Cuota ★4 destacada (%)" },
     }
     for i, s in ipairs(sayilar) do
          local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
          Alan(N, sc, u((ceyrek + 16) * col), u(y + row * 58), u(ceyrek), s[2], d[s[1]], function(v) d[s[1]] = SayiOku(v) or d[s[1]] end)
     end
     y = y + 124

     -- havuz
     local hb = vgui.Create("DPanel", sc)
     hb:SetPos(0, u(y))
     hb:SetSize(u(EW), u(36))
     hb.Paint = function(_, w, h)
          N.Text("HAVUZ  ·  " .. #d.havuz .. " varitas", "small", 0, h / 2, N.Clr.goldAccent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     end
     N.Button(sc, u(EW - 180), u(y), u(180), u(34), "+  Añadir varita", function() AsaSecici(N, d.havuz, function() yenidenKur() end) end, "primary")
     y = y + 44
     local sutun = { 0, 270, 490, 600, 690, 790 }
     local bas = vgui.Create("DPanel", sc)
     bas:SetPos(0, u(y))
     bas:SetSize(u(EW), u(26))
     bas.Paint = function(_, w, h)
          N.Box(0, 0, w, h, N.Clr.tableHead)
          local k = EW / 940
          for i, ad in ipairs({ "Varita (skin)", "Nombre visible", "Rareza", "Peso", "Destacada", "Prob. efectiva" }) do
               N.Text(ad, "micro", u(10 + sutun[i] * k), h / 2, N.Clr.thText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          end
     end
     y = y + 30
     local k = EW / 940
     for i, e in ipairs(d.havuz) do
          local satir = vgui.Create("DPanel", sc)
          satir:SetPos(0, u(y))
          satir:SetSize(u(EW), u(46))
          satir.Paint = function(s, w, h)
               N.Box(0, 0, w, h, i % 2 == 0 and N.Clr.toolBg or Color(0, 0, 0, 0))
               N.Box(0, 0, u(3), h, SG.YildizRenk(e.y))
               local sx, sy = s:LocalToScreen(u(8), u(4))
               SG.AsaCiz(e.model, sx, sy, u(70), h - u(8), { aci = 18, donus = 30, dolu = 0.95, isik = SG.YildizIsik(e.y) })
               N.Text(N.Clip(e.skin, "tiny", u(180 * k)), "tiny", u(84), h / 2, N.Clr.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               local o = SG.AsaOranlari(d)[i] or 0
               N.Text(SG.Yuzde(o, 3), "small", u(10 + sutun[6] * k), h / 2, N.Clr.goldAccent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          end
          local _, ade = N.PlainEntry(satir, u(10 + sutun[2] * k), u(7), u(200 * k), u(32), SG.AsaAd(e.skin), function(v) e.ad = v end)
          ade:SetValue(e.ad or "")
          N.Combo(satir, u(10 + sutun[3] * k), u(7), u(100 * k), u(32), "★" .. e.y, { "★3", "★4", "★5" }, function(_, _, idx) e.y = idx + 2 end)
          local _, we = N.PlainEntry(satir, u(10 + sutun[4] * k), u(7), u(76 * k), u(32), "1", function(v) e.w = SayiOku(v) or e.w end)
          we:SetValue(tostring(e.w or 1))
          N.Button(satir, u(10 + sutun[5] * k), u(7), u(86 * k), u(32), e.up and "UP" or "—", function(b)
               e.up = not e.up
               b.Label = e.up and "UP" or "—"
               b.Style = e.up and "primary" or "ghost"
          end, e.up and "primary" or "ghost")
          N.Button(satir, u(EW - 66), u(7), u(62), u(32), "Quitar", function()
               table.remove(d.havuz, i)
               yenidenKur()
          end, "danger")
          y = y + 50
     end
     if #d.havuz == 0 then
          local bos = vgui.Create("DPanel", sc)
          bos:SetPos(0, u(y))
          bos:SetSize(u(EW), u(40))
          bos.Paint = function(_, w, h) N.Text("Pool vacío. Añade skins con «Añadir varita».", "small", w / 2, h / 2, N.Clr.rowDesc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
          y = y + 44
     end
     local alt = vgui.Create("DPanel", sc)
     alt:SetPos(0, u(y))
     alt:SetSize(u(EW), u(20))
     alt.Paint = nil

     -- kaydet çubuğu
     local cub = vgui.Create("DPanel", kok)
     cub:SetPos(u(EX), u(H - 42))
     cub:SetSize(u(EW + 14), u(42))
     cub.Paint = function(_, w, h)
          N.Box(0, 0, w, 1, N.Clr.headLine)
          N.Text(d.id == "" and "Póster nuevo (sin guardar)" or ("Id: " .. d.id), "tiny", 0, h / 2 + u(2), N.Clr.rowDesc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     end
     N.Button(cub, u(EW + 14 - 180), u(6), u(180), u(34), "Guardar", function()
          local gonder = table.Copy(d)
          for _, e in ipairs(gonder.havuz) do e.model = nil end
          Iste("afis.kaydet", gonder)
     end, "primary")
     N.Button(cub, u(EW + 14 - 330), u(6), u(140), u(34), "Crear copia", function()
          local k2 = table.Copy(d)
          k2.id = ""
          k2.ad = d.ad .. " (copia)"
          k2.aktif = false
          secili = ""
          duzen = k2
          yenidenKur()
     end)
     if d.id ~= "" then
          N.Button(cub, u(EW + 14 - 450), u(6), u(110), u(34), "Borrar", function()
               N.Confirm("Borrar póster", (d.ad or "?") .. " se borrará. El historial y pity de jugadores se mantienen.", "Borrar", function()
                    Iste("afis.sil", { id = d.id })
                    secili, duzen = nil, nil
               end, true)
          end, "danger")
     end
end

KURUCU.ekonomi = function(N, kok, W, H)
     local u = N.u
     local sc = N.Scroll(kok, 0, 0, u(W), u(H - 50))
     local f = table.Copy(SG.YVeri.ayar or SG.Ayar)
     local EW = W - 14
     local yarim = math.floor((EW - 16) / 2)
     local ucte = math.floor((EW - 32) / 3)
     local y = 0
     Alan(N, sc, 0, u(y), u(ucte), "Nombre de moneda", f.adakAd, function(v) f.adakAd = v end)
     Alan(N, sc, u(ucte + 16), u(y), u(ucte), "Nombre de boleto", f.biletAd, function(v) f.biletAd = v end)
     Alan(N, sc, u((ucte + 16) * 2), u(y), u(ucte), "Nombre de polvo", f.tozAd, function(v) f.tozAd = v end)
     y = y + 62
     Alan(N, sc, 0, u(y), u(yarim), "1 boleto cuesta cuántas ofrendas", f.biletFiyat, function(v) f.biletFiyat = tonumber(v) or f.biletFiyat end)
     Alan(N, sc, u(yarim + 16), u(y), u(yarim), "1 boleto cuesta cuánto Polvo de estrellas", f.tozBoleto, function(v) f.tozBoleto = tonumber(v) or f.tozBoleto end)
     y = y + 62
     Alan(N, sc, 0, u(y), u(ucte), "Varita ★3 duplicada → polvo", f.toz3, function(v) f.toz3 = tonumber(v) or f.toz3 end)
     Alan(N, sc, u(ucte + 16), u(y), u(ucte), "Varita ★4 duplicada → polvo", f.toz4, function(v) f.toz4 = tonumber(v) or f.toz4 end)
     Alan(N, sc, u((ucte + 16) * 2), u(y), u(ucte), "Varita ★5 duplicada → polvo", f.toz5, function(v) f.toz5 = tonumber(v) or f.toz5 end)
     y = y + 62
     N.Toggle(sc, 0, u(y), u(yarim), u(50), "Mostrar contador pity en el póster", function() return f.pityGoster end, function(v) f.pityGoster = v end, "\"★5 garantisine N dilek\" yazısı.")
     y = y + 62
     Alan(N, sc, 0, u(y), u(EW), "Cómo ganar ofrendas (Dükkân'da ve yetersiz Ofrenda uyarısında görünür)", f.adakNasil, function(v) f.adakNasil = v end)
     y = y + 62
     Alan(N, sc, 0, u(y), u(yarim), "Comando Shine Store (eklenti gelince sayfadaki düğme çalıştırır)", f.storeKomut, function(v) f.storeKomut = string.Trim(v) end)
     y = y + 70
     local not_ = vgui.Create("DPanel", sc)
     not_:SetPos(0, u(y))
     not_:SetSize(u(EW), u(96))
     not_.Paint = function(_, w, h)
          N.Box(0, 0, w, h, N.Clr.infoBg)
          N.Outline(0, 0, w, h, N.Clr.infoLine, 1)
          N.Text("Dar ofrendas: en recompensas de misión tipo «Ofrenda (deseo de varita)»; en código SardonGacha.AdakVer(jugador, cantidad, \"motivo\").", "small", u(14), u(14), N.Clr.infoText)
          N.Text("Chat: /AdakVer <jugador> <cantidad> [motivo] · /BiletVer · /TozVer (cantidad negativa quita) · /GachaCuzdan <jugador>", "small", u(14), u(38), N.Clr.infoText)
          N.Text("Todos los saldos van a la cuenta (SteamID64); persisten al cambiar de personaje.", "small", u(14), u(62), N.Clr.infoText)
     end
     N.Button(kok, u(W - 180), u(H - 42), u(180), u(34), "Guardar", function() Iste("ayar", f) end, "primary")
end

local function CuzdanPenceresi(N, sid, ad)
     local u = N.u
     Pencere(N, "Monedero · " .. (ad or sid), 620, 330, function(ic, W, H, ort)
          local alan, miktar, sebep = "adak", 0, ""
          Etiket(N, ic, 0, 0, u(W), "Qué")
          N.Combo(ic, 0, u(18), u(W / 3 - 8), u(32), SG.Ayar.adakAd, { SG.Ayar.adakAd, SG.Ayar.biletAd, SG.Ayar.tozAd }, function(_, _, i) alan = ({ "adak", "bilet", "toz" })[i] end)
          Alan(N, ic, u(W / 3 + 4), 0, u(W / 3 - 8), "Cantidad (negativo = quitar)", "", function(v) miktar = tonumber(v) or 0 end)
          Alan(N, ic, u(W * 2 / 3 + 8), 0, u(W / 3 - 8), "Motivo (se registra)", "", function(v) sebep = v end)
          N.Button(ic, u(W - 180), u(H - 44), u(180), u(36), "Aplicar", function()
               if miktar == 0 then return end
               Iste("cuzdan", { sid = sid, alan = alan, miktar = miktar, sebep = sebep })
               ort:Remove()
          end, "primary")
     end)
end

KURUCU.oyuncular = function(N, kok, W, H)
     local u = N.u
     local V = SG.YVeri
     local LW = math.floor(W * 0.56)
     local ara = ""
     N.PlainEntry(kok, 0, 0, u(LW - 120), u(36), "Buscar por SteamID64 (también offline)", function(v) ara = string.Trim(v or "") end)
     N.Button(kok, u(LW - 110), 0, u(110), u(36), "Buscar", function() Iste("ara", { sid = ara }) end, "primary")
     local liste = N.Scroll(kok, 0, u(46), u(LW), u(H - 46))
     for _, p in ipairs(V.oyuncular or {}) do
          local satir = vgui.Create("DPanel", liste)
          satir:Dock(TOP)
          satir:DockMargin(0, 0, u(6), u(4))
          satir:SetTall(u(56))
          satir.Paint = function(s, w, h)
               N.Box(0, 0, w, h, s:IsHovered() and N.Clr.cardHover or N.Clr.toolBg)
               N.Text(p.ad, "small", u(12), u(8), N.Clr.text)
               N.Text(SG.Sayi(p.adak) .. " ofrendas · " .. SG.Sayi(p.bilet) .. " boletos · " .. SG.Sayi(p.toz) .. " polvo · contador ★5 " .. p.p5 .. (p.g5 == 1 and " (garantizado)" or "") .. " · " .. p.toplam .. " tiradas · " .. p.kol .. " varitas", "tiny", u(12), u(32), N.Clr.rowDesc)
          end
          local bw = u(84)
          N.Button(satir, u(LW - 6) - bw * 2 - u(18), u(12), bw, u(32), "Monedero", function() CuzdanPenceresi(N, p.sid, p.ad) end, "primary")
          N.Button(satir, u(LW - 6) - bw - u(12), u(12), bw, u(32), "Detalle", function() Iste("ara", { sid = p.sid }) end)
     end

     -- sağ: arama sonucu
     local RX = LW + 16
     local RW = W - RX
     local sag = vgui.Create("DPanel", kok)
     sag:SetPos(u(RX), 0)
     sag:SetSize(u(RW), u(H))
     local a = V.arama
     sag.Paint = function(_, w, h)
          N.Box(0, 0, w, h, N.Clr.toolBg)
          N.Outline(0, 0, w, h, N.Clr.toolLine, 1)
          if not a then
               N.Text("Pulsa Detalle de un jugador o busca por SteamID64.", "small", w / 2, h / 2, N.Clr.rowDesc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               return
          end
          N.Text(a.ad or a.sid, "small", u(14), u(12), N.Clr.goldAccent)
          N.Text(a.sid, "tiny", u(14), u(34), N.Clr.rowDesc)
          N.Text(SG.Sayi(a.adak) .. " Ofrenda  ·  " .. SG.Sayi(a.bilet) .. " bilet  ·  " .. SG.Sayi(a.toz) .. " toz", "small", u(14), u(56), N.Clr.text)
          N.Text("Ofrendas totales ganadas " .. SG.Sayi(a.kazanilan) .. "  ·  contador ★5 " .. a.p5 .. (a.g5 == 1 and " (garantizado)" or "") .. "  ·  ★4 sayacı " .. a.p4 .. "  ·  " .. a.kol .. " varitas", "tiny", u(14), u(80), N.Clr.rowDesc)
          N.Box(u(14), u(140), w - u(28), 1, N.Clr.headLine)
          N.Text("ÚLTIMAS TIRADAS", "micro", u(14), u(148), N.Clr.gold)
     end
     if a then
          N.Button(sag, u(14), u(100), u(120), u(32), "Monedero", function() CuzdanPenceresi(N, a.sid, a.ad) end, "primary")
          N.Button(sag, u(144), u(100), u(140), u(32), "Reiniciar pity", function()
               N.Confirm("Reiniciar pity", (a.ad or a.sid) .. ": se reinician contadores ★5/★4 y banderas de garantía.", "Reiniciar", function() Iste("pity.sifirla", { sid = a.sid }) end, true)
          end, "danger")
          local gl = N.Scroll(sag, u(10), u(166), u(RW - 20), u(H - 176))
          for _, r in ipairs(a.gecmis or {}) do
               local sr = vgui.Create("DPanel", gl)
               sr:Dock(TOP)
               sr:DockMargin(0, 0, u(6), u(2))
               sr:SetTall(u(26))
               sr.Paint = function(_, w, h)
                    N.Box(0, 0, u(3), h, SG.YildizRenk(r.y))
                    N.Text("★" .. r.y .. "  " .. r.ad .. (r.yeni and "  · nuevo" or ("  · +" .. r.toz .. " toz")), "tiny", u(10), h / 2, r.y >= 4 and SG.YildizIsik(r.y) or N.Clr.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    N.Text(os.date("%d.%m %H:%M", r.t or 0), "tiny", w - u(8), h / 2, N.Clr.rowDesc, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
               end
          end
     end
end

KURUCU.kayit = function(N, kok, W, H)
     local u = N.u
     local V = SG.YVeri
     local ust = vgui.Create("DPanel", kok)
     ust:SetPos(0, 0)
     ust:SetSize(u(W), u(96))
     ust.Paint = function(_, w, h)
          N.Box(0, 0, w, h, N.Clr.toolBg)
          N.Outline(0, 0, w, h, N.Clr.toolLine, 1)
          N.Text("TIRADAS POR PÓSTER", "micro", u(14), u(10), N.Clr.gold)
          local yy = u(30)
          local i = 0
          for _, s in SortedPairsByMemberValue(V.ist or {}, "ad") do
               i = i + 1
               if i > 3 then break end
               local top = (s[3] or 0) + (s[4] or 0) + (s[5] or 0)
               N.Text((s.ad or "?") .. ":  " .. top .. " tiradas  ·  ★5 " .. (s[5] or 0) .. "  ·  ★4 " .. (s[4] or 0) .. "  ·  ★3 " .. (s[3] or 0), "small", u(14), yy, N.Clr.text)
               yy = yy + u(20)
          end
          if i == 0 then N.Text("Aún no hay tiradas.", "small", u(14), yy, N.Clr.rowDesc) end
     end
     local AD = { adak = "Ofrenda", bilet = "Boleto", toz = "Polvo" }
     local liste = N.Scroll(kok, 0, u(106), u(W), u(H - 106))
     for _, r in ipairs(V.kayit or {}) do
          local sr = vgui.Create("DPanel", liste)
          sr:Dock(TOP)
          sr:DockMargin(0, 0, u(6), u(2))
          sr:SetTall(u(28))
          sr.Paint = function(_, w, h)
               N.Box(0, 0, w, h, N.Clr.toolBg)
               N.Text(os.date("%d.%m %H:%M", r.t or 0), "tiny", u(10), h / 2, N.Clr.rowDesc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Text(r.sid or "?", "tiny", u(110), h / 2, N.Clr.monoText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Text((AD[r.alan] or r.alan or "?") .. " " .. ((r.miktar or 0) > 0 and "+" or "") .. SG.Sayi(r.miktar) .. " → " .. SG.Sayi(r.yeni), "tiny", u(290), h / 2, (r.miktar or 0) > 0 and N.Clr.ok or N.Clr.warn, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Text(N.Clip(r.sebep or "", "tiny", w - u(480)), "tiny", u(470), h / 2, N.Clr.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          end
     end
end

local function Kaydet()
     if not ShineAdmin or not ShineAdmin.RegisterPage or not ShineAdmin.GetN then return false end
     if ShineAdmin.Access then ShineAdmin.Access.gacha = function(p) return SG.Yonetici(p) end end
     ShineAdmin:RegisterPage("gacha", {
          label = "Deseo de varita",
          icon = "wand",
          group = "systems",
          order = 46,
          title = "Deseo de varita (Gacha)",
          subtitle = "Pósters de temporada, imagen temática, pool y probabilidades; economía de ofrendas/boletos; monederos de jugadores.",
          access = function(p) return SG.Yonetici(p) end,
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
                    kok.surum = SG.YSurum
                    KURUCU[sekme](N, kok, W, H - 56, Kur)
                    kok.Think = function(s)
                         if s.surum ~= SG.YSurum then
                              s.surum = SG.YSurum
                              -- düzenlenen afiş "duzen"de durur; yeniden kurmak yazılanı kaybettirmez
                              Kur()
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
     timer.Create("SardonGacha.Shine", 2, 30, function() if Kaydet() then timer.Remove("SardonGacha.Shine") end end)
end

concommand.Add("sardon_gacha_admin", function()
     if ShineAdmin and ShineAdmin.Open then ShineAdmin:Open("gacha") end
end)
