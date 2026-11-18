-- "addons\\sardongorev\\lua\\sardon_gorev\\cl_9b_editor.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Taller de misiones (editör). Açma: /GorevEditor, konsol sardon_gorev_editor, Shine Admin > Misiónler.
*   Sol: misión listesi. Orta: sekmeler (Genel, Actorler, Pasolar, Replikler, Seslendirme, JSON).
*   Alt: kaydet (Ctrl+S), bana test et (seçili pasodan), bitir/iptal, ilerlememi sıfırla.
*/
local G = SardonGorev
local R, O, F = G.R, G.O, G.F
local K = G.K

G.E = G.E or { liste = {}, yerler = {}, dunya = {}, harita = "", def = nil, kirli = false, sekme = "genel", adimNo = 1, aktorNo = 1 }
local E = G.E

function G.EditorIste(op, t)
     net.Start("SardonGorev.Yonetim")
     net.WriteString(op)
     G.YazTablo(t or {})
     net.SendToServer()
end

local function Not(metin, tur)
     notification.AddLegacy(metin, tur == "hata" and NOTIFY_ERROR or NOTIFY_GENERIC, 4)
     if tur == "hata" then G.Cal("basarisiz") else G.Cal("ilerleme") end
end

/*
*   Alanlar
*/
local TUR_SECENEK = {}
for _, t in ipairs(G.Turler) do TUR_SECENEK[#TUR_SECENEK + 1] = { id = t.id, ad = t.ad } end

local GENEL = {
     { k = "id", ad = "ID", tip = "metin", ipucu = "Minúsculas, números y guion bajo. Si cambia, se borra la entrada antigua." },
     { k = "ad", ad = "Nombre", tip = "metin" },
     { k = "tur", ad = "Tipo", tip = "secim", secenekler = TUR_SECENEK },
     { k = "ozet", ad = "Resumen corto", tip = "yazi", ipucu = "Línea en cursiva en el cartel y el diario. Puedes usar {jugador}, {ad}, {hane}." },
     { k = "aciklama", ad = "Descripción", tip = "yazi" },
     { k = "aktif", ad = "Publicada", tip = "bool", ipucu = "Si está apagada, solo se puede probar." },
     { k = "baslatma", ad = "Cómo empieza", tip = "secim", goster = function(d) return d.tur ~= "karsilasma" and d.tur ~= "gunluk" end, secenekler = {
          { id = "otomatik", ad = "Automático (cuando se cumplan las condiciones)" }, { id = "veren", ad = "Desde un actor del mundo que da la misión" },
          { id = "olay", ad = "Con un evento (SardonGorev.Tetikle)" }, { id = "elle", ad = "Solo a mano / desde otra misión" } } },
     { k = "olay", ad = "Nombre del evento", tip = "metin", goster = function(d) return d.baslatma == "olay" end },
     { k = "siralama", ad = "Orden (menor primero)", tip = "sayi", min = 0, max = 10000 },
     { k = "tekrar", ad = "Repetición", tip = "secim", secenekler = {
          { id = "yok", ad = "Una vez" }, { id = "gunluk", ad = "Una vez al día" }, { id = "haftalik", ad = "Una vez a la semana" },
          { id = "bekleme", ad = "Tras un tiempo de espera" }, { id = "sinirsiz", ad = "Ilimitada" } } },
     { k = "bekleme", ad = "Espera (s)", tip = "sayi", min = 0, max = 2592000, goster = function(d) return d.tekrar == "bekleme" end },
     { k = "kapsam", ad = "Registro de progreso", tip = "secim", secenekler = { { id = "karakter", ad = "Por personaje" }, { id = "hesap", ad = "Por cuenta (Steam)" } } },
     { k = "iptal", ad = "El jugador puede abandonar", tip = "bool" },
     { k = "olunce", ad = "Al morir", tip = "secim", secenekler = { { id = "devam", ad = "Continúa" }, { id = "kontrol", ad = "Reiniciar desde el punto de control" }, { id = "basarisiz", ad = "Fracasa" } } },
     { k = "karsilasmaEngel", ad = "Sin encuentros mientras está activa", tip = "bool" },
     { k = "gunlukAgirlik", ad = "Peso de selección diaria", tip = "sayi", min = 0, max = 100, goster = function(d) return d.tur == "gunluk" end },
     { k = "kosullar", ad = "Condiciones de inicio", tip = "kosullar" },
     { k = "oduller", ad = "Recompensas", tip = "oduller" },
}

local ADIM = {
     { k = "id", ad = "ID", tip = "metin" },
     { k = "ad", ad = "Nombre en el rastreador", tip = "metin" },
     { k = "not", ad = "Nota del editor", tip = "yazi" },
     { k = "hedefKip", ad = "Cuándo termina el paso", tip = "secim", secenekler = { { id = "hepsi", ad = "Cuando terminen todos los objetivos obligatorios" }, { id = "biri", ad = "Cuando termine cualquier objetivo" } } },
     { k = "sonraki", ad = "Siguiente paso", tip = "adim" },
     { k = "kontrol", ad = "Punto de control", tip = "bool", ipucu = "Si el jugador sale y vuelve, continúa desde este paso." },
}

local LISTE_GIRIS = { k = "giris", ad = "Acciones de entrada", tip = "liste", semaTur = "Eylem", kategoriler = G.EylemKategori }
local LISTE_HEDEF = { k = "hedefler", ad = "Objetivos", tip = "liste", semaTur = "Hedef" }
local LISTE_REPLIK = { k = "replikler", ad = "Réplicas", tip = "liste", alanlar = G.ReplikAlanlari, ozet = G.ReplikOzet }
local LISTE_CIKIS = { k = "cikis", ad = "Acciones de salida", tip = "liste", semaTur = "Eylem", kategoriler = G.EylemKategori }
local LISTE_KONUSUNCA = { k = "konusunca", ad = "Al hablar", tip = "liste", alanlar = G.KonusuncaAlanlari, ozet = G.KonusuncaOzet }

/*
*   Pencere
*/
local function Kirlet()
     E.kirli = true
end

local function Ctx()
     return { def = E.def, yenile = nil }
end

local SEKMELER = {
     { id = "genel", ad = "General" }, { id = "aktorler", ad = "Actores" }, { id = "adimlar", ad = "Pasos" },
     { id = "replikler", ad = "Réplicas generales" }, { id = "seslendirme", ad = "Locución" }, { id = "json", ad = "JSON" },
}

local function Bolum(parent, metin)
     local l = vgui.Create("EditablePanel", parent)
     l:Dock(TOP)
     l:SetTall(O(34))
     l:DockMargin(0, O(10), 0, O(4))
     l.Paint = function(_, w, h)
          G.Baklava(O(6), h / 2, O(4), R.altin)
          G.Yaz(G.Buyuk(metin), F(13, "kalin"), O(18), h / 2, R.altin, 0, O(2))
          G.AltinCizgi(0, h - 1, w, 90)
     end
     return l
end

local SekmeKur = {}

SekmeKur.genel = function(p)
     local kay = K.Kaydir(p)
     kay:Dock(FILL)
     local form = K.Form(kay, GENEL, E.def, Ctx(), function(k)
          Kirlet()
          if k == "tur" then timer.Simple(0, function() if IsValid(G.EditorPencere) then G.EditorPencere:SekmeAc("genel") end end) end
     end)
     form:DockMargin(0, 0, O(12), 0)
     if E.def.tur == "karsilasma" then
          Bolum(kay, "Encuentro (aparición aleatoria)")
          local k = K.Form(kay, G.KarsilasmaAlanlari, E.def.karsilasma, Ctx(), Kirlet)
          k:DockMargin(0, 0, O(12), 0)
          local bilgi = K.Etiket(kay, "En las acciones, '@karsilasma' es el punto elegido y '@jugador' la posición del jugador. Añade requisitos de hora / clima / nivel en 'Condiciones de inicio'.", R.soluk, F(12, "italik"))
          bilgi:Dock(TOP)
          bilgi:SetWrap(true)
          bilgi:SetAutoStretchVertical(true)
     end
end

SekmeKur.aktorler = function(p)
     local def = E.def
     E.aktorNo = math.Clamp(E.aktorNo, 1, math.max(1, #def.aktorler))

     local sol = vgui.Create("EditablePanel", p)
     sol:Dock(LEFT)
     sol:SetWide(O(260))
     local liste = K.Kaydir(sol)
     liste:Dock(FILL)
     for i, a in ipairs(def.aktorler) do
          local b = liste:Add("DButton")
          b:Dock(TOP)
          b:SetTall(O(46))
          b:DockMargin(0, 0, O(6), O(4))
          b:SetText("")
          b.Paint = function(s, w, h)
               local sec = E.aktorNo == i
               G.Kutu(0, 0, w, h, sec and Color(34, 46, 36, 240) or Color(16, 24, 20, s:IsHovered() and 240 or 200))
               if sec then G.Kutu(0, 0, O(3), h, R.altin) end
               G.Yaz(a.id or "?", F(14, "kalin"), O(12), O(15), R.fildisi)
               G.Yaz(a.ad or "", F(12, "italik"), O(12), O(32), R.soluk)
          end
          b.DoClick = function() E.aktorNo = i G.EditorPencere:SekmeAc("aktorler") end
     end
     local alt = vgui.Create("EditablePanel", sol)
     alt:Dock(BOTTOM)
     alt:SetTall(O(36))
     local ekle = K.Dugme(alt, "+ Actor", function()
          local yeni = {}
          for _, a in ipairs(G.AktorAlanlari) do yeni[a.k] = istable(a.v) and table.Copy(a.v) or a.v end
          yeni.id = "aktor" .. (#def.aktorler + 1)
          yeni.ad = "Nuevo actor"
          def.aktorler[#def.aktorler + 1] = yeni
          E.aktorNo = #def.aktorler
          Kirlet()
          G.EditorPencere:SekmeAc("aktorler")
     end, "ana")
     ekle:Dock(LEFT)
     ekle:SetWide(O(120))
     local sil = K.Dugme(alt, "Eliminar", function()
          if not def.aktorler[E.aktorNo] then return end
          table.remove(def.aktorler, E.aktorNo)
          Kirlet()
          G.EditorPencere:SekmeAc("aktorler")
     end, "tehlike")
     sil:Dock(RIGHT)
     sil:SetWide(O(80))

     local a = def.aktorler[E.aktorNo]
     if not a then
          local l = K.Etiket(p, "Aún no hay actores. Los actores son las figuras de la misión (guía, tendero, desconocido…).", R.soluk, F(15, "italik"))
          l:Dock(FILL)
          l:DockMargin(O(20), 0, 0, 0)
          return
     end
     local kay = K.Kaydir(p)
     kay:Dock(FILL)
     kay:DockMargin(O(16), 0, 0, 0)
     local form = K.Form(kay, G.AktorAlanlari, a, { def = def, model = a.model }, function(k)
          Kirlet()
          if k == "model" then timer.Simple(0, function() if IsValid(G.EditorPencere) then G.EditorPencere:SekmeAc("aktorler") end end) end
     end)
     form:DockMargin(0, 0, O(12), 0)
     local onizle = vgui.Create("DModelPanel", kay)
     onizle:Dock(TOP)
     onizle:SetTall(O(300))
     onizle:SetModel((isstring(a.model) and file.Exists(a.model, "GAME")) and a.model or "models/player/group01/male_07.mdl")
     onizle:SetFOV(30)
     onizle:SetCamPos(Vector(110, 0, 50))
     onizle:SetLookAt(Vector(0, 0, 40))
     if IsValid(onizle.Entity) then
          onizle.Entity:SetSkin(tonumber(a.skin) or 0)
          for no, deger in string.gmatch(tostring(a.bg or ""), "(%d+)%s*=%s*(%d+)") do onizle.Entity:SetBodygroup(tonumber(no), tonumber(deger)) end
          local seq = onizle.Entity:LookupSequence((a.bekleAnim or "") ~= "" and a.bekleAnim or "idle_all_01")
          if seq and seq >= 0 then onizle.Entity:ResetSequence(seq) end
     end
     onizle.LayoutEntity = function(s, ent) ent:SetAngles(Angle(0, RealTime() * 20 % 360, 0)) s:RunAnimation() end
end

SekmeKur.adimlar = function(p)
     local def = E.def
     E.adimNo = math.Clamp(E.adimNo, 1, math.max(1, #def.adimlar))

     local sol = vgui.Create("EditablePanel", p)
     sol:Dock(LEFT)
     sol:SetWide(O(280))
     local liste = K.Kaydir(sol)
     liste:Dock(FILL)
     for i, a in ipairs(def.adimlar) do
          local b = liste:Add("DButton")
          b:Dock(TOP)
          b:SetTall(O(54))
          b:DockMargin(0, 0, O(6), O(4))
          b:SetText("")
          b.Paint = function(s, w, h)
               local sec = E.adimNo == i
               G.Kutu(0, 0, w, h, sec and Color(34, 46, 36, 240) or Color(16, 24, 20, s:IsHovered() and 240 or 200))
               if sec then G.Kutu(0, 0, O(3), h, R.altin) end
               G.Yaz(i .. ".", F(13, "kalin"), O(12), O(16), R.altin)
               G.Yaz(a.id or "?", F(14, "kalin"), O(36), O(16), R.fildisi)
               G.Yaz(G.Kisalt(a.ad or "", 30), F(12, "italik"), O(36), O(32), R.soluk)
               G.Yaz(#(a.giris or {}) .. " acciones · " .. #(a.hedefler or {}) .. " objetivos · " .. #(a.replikler or {}) .. " réplicas" .. ((a.sonraki or "") ~= "" and ("  → " .. a.sonraki) or ""), F(11, "govde"), O(36), O(46), R.soluk)
          end
          b.DoClick = function() E.adimNo = i G.EditorPencere:SekmeAc("adimlar") end
     end
     local alt = vgui.Create("EditablePanel", sol)
     alt:Dock(BOTTOM)
     alt:SetTall(O(36))
     local function D(m, f, tur, w)
          local b = K.Dugme(alt, m, f, tur)
          b:Dock(LEFT)
          b:SetWide(w or O(50))
          b:DockMargin(0, 0, O(4), 0)
     end
     D("+ Paso", function()
          local yeni = { id = "adim" .. (#def.adimlar + 1), ad = "Nuevo paso", giris = {}, hedefler = {}, cikis = {}, replikler = {}, hedefKip = "hepsi", sonraki = "", kontrol = true }
          table.insert(def.adimlar, E.adimNo + 1, yeni)
          E.adimNo = E.adimNo + 1
          Kirlet()
          G.EditorPencere:SekmeAc("adimlar")
     end, "ana", O(84))
     D("⧉", function()
          local a = def.adimlar[E.adimNo]
          if not a then return end
          local k = table.Copy(a)
          k.id = a.id .. "_k"
          table.insert(def.adimlar, E.adimNo + 1, k)
          E.adimNo = E.adimNo + 1
          Kirlet()
          G.EditorPencere:SekmeAc("adimlar")
     end, nil, O(36))
     D("↑", function()
          local i = E.adimNo
          if i > 1 then def.adimlar[i], def.adimlar[i - 1] = def.adimlar[i - 1], def.adimlar[i] E.adimNo = i - 1 Kirlet() G.EditorPencere:SekmeAc("adimlar") end
     end, nil, O(36))
     D("↓", function()
          local i = E.adimNo
          if i < #def.adimlar then def.adimlar[i], def.adimlar[i + 1] = def.adimlar[i + 1], def.adimlar[i] E.adimNo = i + 1 Kirlet() G.EditorPencere:SekmeAc("adimlar") end
     end, nil, O(36))
     D("Eliminar", function()
          if #def.adimlar <= 1 then Not("La misión debe tener al menos un paso.", "hata") return end
          table.remove(def.adimlar, E.adimNo)
          Kirlet()
          G.EditorPencere:SekmeAc("adimlar")
     end, "tehlike", O(56))

     local a = def.adimlar[E.adimNo]
     if not a then return end
     for _, k in ipairs({ "giris", "hedefler", "cikis", "replikler", "konusunca" }) do a[k] = istable(a[k]) and a[k] or {} end

     local kay = K.Kaydir(p)
     kay:Dock(FILL)
     kay:DockMargin(O(16), 0, 0, 0)
     local ctx = Ctx()
     local form = K.Form(kay, ADIM, a, ctx, Kirlet)
     form:DockMargin(0, 0, O(12), 0)

     Bolum(kay, "1 · Acciones de entrada (en orden; las que tienen 'esperar' bloquean hasta terminar)")
     local f1 = K.Form(kay, { LISTE_GIRIS }, a, ctx, Kirlet)
     f1:DockMargin(0, 0, O(12), 0)
     Bolum(kay, "2 · Objetivos (empiezan al terminar la entrada)")
     local f2 = K.Form(kay, { LISTE_HEDEF }, a, ctx, Kirlet)
     f2:DockMargin(0, 0, O(12), 0)
     Bolum(kay, "Al hablar con el actor (mientras hay objetivos; tendero, charla)")
     local f5 = K.Form(kay, { LISTE_KONUSUNCA }, a, ctx, Kirlet)
     f5:DockMargin(0, 0, O(12), 0)
     Bolum(kay, "Réplicas (lo que el actor dice solo mientras hay objetivos)")
     local f3 = K.Form(kay, { LISTE_REPLIK }, a, ctx, Kirlet)
     f3:DockMargin(0, 0, O(12), 0)
     Bolum(kay, "3 · Acciones de salida (al terminar los objetivos)")
     local f4 = K.Form(kay, { LISTE_CIKIS }, a, ctx, Kirlet)
     f4:DockMargin(0, 0, O(12), 0)
end

SekmeKur.replikler = function(p)
     local kay = K.Kaydir(p)
     kay:Dock(FILL)
     local bilgi = K.Etiket(kay, "Estas réplicas valen en todos los pasos de la misión (si el actor está en escena). Añade réplicas propias del paso en la pestaña Pasos.", R.soluk, F(13, "italik"))
     bilgi:Dock(TOP)
     bilgi:SetTall(O(30))
     local f = K.Form(kay, { LISTE_REPLIK }, E.def, Ctx(), Kirlet)
     f:DockMargin(0, 0, O(12), 0)
end

/*
*   Seslendirme: misióndeki bütün sözler ve ses dosyaları
*/
local function Sozler(def)
     local out = {}
     local function Satir(konum, kim, s)
          if not istable(s) or (s.metin or "") == "" then return end
          out[#out + 1] = { konum = konum, kim = kim or "", s = s }
     end
     local function Eylemler(liste, on)
          for i, e in ipairs(liste or {}) do
               if e.t == "konus" then Satir(on .. " · acción " .. i, e.aktor ~= "" and e.aktor or "narrador", e)
               elseif e.t == "diyalog" then
                    for j, s in ipairs(e.satirlar or {}) do Satir(on .. " · diálogo " .. i .. "." .. j, (s.kim or "") ~= "" and s.kim or e.aktor, s) end
                    for j, c in ipairs(e.secenekler or {}) do
                         for k, s in ipairs(c.yanit or {}) do Satir(on .. " · diálogo " .. i .. " opción " .. j .. "." .. k, (s.kim or "") ~= "" and s.kim or e.aktor, s) end
                    end
               end
          end
     end
     for _, a in ipairs(def.adimlar or {}) do
          Eylemler(a.giris, a.id)
          for i, k in ipairs(a.konusunca or {}) do Eylemler(k.eylemler, a.id .. " (al hablar " .. i .. ")") end
          Eylemler(a.cikis, a.id .. " (salida)")
          for i, r in ipairs(a.replikler or {}) do
               for j, s in ipairs(r.satirlar or {}) do Satir(a.id .. " · réplica " .. i .. "." .. j, r.aktor, s) end
          end
     end
     for i, r in ipairs(def.replikler or {}) do
          for j, s in ipairs(r.satirlar or {}) do Satir("réplica general " .. i .. "." .. j, r.aktor, s) end
     end
     return out
end

SekmeKur.seslendirme = function(p)
     local def = E.def
     if #G.SesListe == 0 then G.EditorIste("sesler") end
     local var = {}
     for _, s in ipairs(G.SesListe) do var[s.yol] = s end

     local ust = vgui.Create("EditablePanel", p)
     ust:Dock(TOP)
     ust:SetTall(O(40))
     local sozler = Sozler(def)
     local doldur = K.Dugme(ust, "Rellenar rutas de audio vacías", function()
          local sayac = {}
          for _, x in ipairs(sozler) do
               if (x.s.ses or "") == "" then
                    local on = G.Kimlik(string.match(x.konum, "^(%S+)") or "satir")
                    sayac[on] = (sayac[on] or 0) + 1
                    x.s.ses = def.id .. "/" .. on .. "_" .. string.format("%02d", sayac[on]) .. ".mp3"
               end
          end
          Kirlet()
          G.EditorPencere:SekmeAc("seslendirme")
     end, "ana")
     doldur:Dock(LEFT)
     doldur:SetWide(O(220))
     local kopya = K.Dugme(ust, "Copiar texto al portapapeles", function()
          local satirlar = { "# " .. (def.ad or def.id) .. " — texto de locución", "" }
          for _, x in ipairs(sozler) do
               satirlar[#satirlar + 1] = string.format("[%s]  %s  →  %s", x.kim, x.s.metin, (x.s.ses or "") ~= "" and x.s.ses or "(sin nombre de archivo)")
          end
          SetClipboardText(table.concat(satirlar, "\n"))
          Not("Texto de locución copiado al portapapeles (" .. #sozler .. " líneas).")
     end)
     kopya:Dock(LEFT)
     kopya:SetWide(O(200))
     kopya:DockMargin(O(8), 0, 0, 0)
     local yenile = K.Dugme(ust, "Actualizar sonidos del servidor", function() G.EditorIste("sesler") end)
     yenile:Dock(LEFT)
     yenile:SetWide(O(220))
     yenile:DockMargin(O(8), 0, 0, 0)
     local bilgi = K.Etiket(ust, "Archivos: garrysmod/data/sardon_gorev/sesler/ (mp3 · ogg · wav)", R.soluk, F(12, "italik"))
     bilgi:Dock(FILL)
     bilgi:DockMargin(O(14), 0, 0, 0)

     local kay = K.Kaydir(p)
     kay:Dock(FILL)
     kay:DockMargin(0, O(8), 0, 0)
     local eksik = 0
     for _, x in ipairs(sozler) do
          local yol = G.SesYolu(x.s.ses)
          local durum = yol and var[yol]
          if not durum then eksik = eksik + 1 end
          local r = kay:Add("EditablePanel")
          r:Dock(TOP)
          r:SetTall(O(52))
          r:DockMargin(0, 0, O(6), O(4))
          r.Paint = function(_, w, h)
               G.Kutu(0, 0, w, h, Color(16, 24, 20, 210))
               G.Kutu(0, 0, O(3), h, durum and R.yesil or R.kirmizi)
               G.Yaz(x.konum .. "  ·  " .. x.kim, F(11, "kalin"), O(12), O(13), R.altin)
               G.Yaz(G.Kisalt(x.s.metin, 110), F(14, "govde"), O(12), O(33), R.fildisi)
               G.Yaz((x.s.ses or "") ~= "" and (x.s.ses .. (durum and string.format("  ·  %.1f s", durum.sure or 0) or "  ·  no está en el servidor")) or "sin ruta de audio",
                    F(12, "govde"), w - O(110), O(13), durum and R.soluk or R.kirmizi, 2)
          end
          local dinle = K.Dugme(r, "▶", function() if yol then G.SesOnizle(yol) end end)
          dinle:SetSize(O(40), O(30))
          dinle:Dock(RIGHT)
          dinle:DockMargin(0, O(11), O(10), O(11))
     end
     bilgi:SetText("Archivos: garrysmod/data/sardon_gorev/sesler/ (mp3 · ogg · wav)   ·   " .. #sozler .. " líneas, " .. eksik .. " audio faltante")
end

SekmeKur.json = function(p)
     local ust = vgui.Create("EditablePanel", p)
     ust:Dock(TOP)
     ust:SetTall(O(40))
     local e
     local uygula = K.Dugme(ust, "Aplicar", function()
          local t = util.JSONToTable(e:GetValue() or "")
          if not istable(t) or not istable(t.adimlar) then Not("No se pudo leer el JSON.", "hata") return end
          E.def = t
          Kirlet()
          G.EditorPencere:Yenile()
          Not("JSON aplicado (no olvides guardar).")
     end, "ana")
     uygula:Dock(LEFT)
     uygula:SetWide(O(120))
     local kop = K.Dugme(ust, "Copiar al portapapeles", function() SetClipboardText(e:GetValue()) Not("Copiado.") end)
     kop:Dock(LEFT)
     kop:SetWide(O(160))
     kop:DockMargin(O(8), 0, 0, 0)
     e = K.Giris(p, util.TableToJSON(E.def, true), true)
     e:Dock(FILL)
     e:DockMargin(0, O(8), 0, 0)
     e:SetFont(F(13, "govde"))
end

/*
*   Ana pencere
*/
local PENCERE = {}

function PENCERE:Init()
     self:SetSize(ScrW() - O(60), ScrH() - O(60))
     self:Center()
     self:MakePopup()
     self.acilis = RealTime()

     -- üst şerit
     local ust = vgui.Create("EditablePanel", self)
     ust:Dock(TOP)
     ust:SetTall(O(64))
     ust.Paint = function(_, w, h)
          G.Yaz("TALLER DE MISIONES", F(12, "kalin"), O(24), O(22), R.altin, 0, O(4))
          local ad = E.def and ((E.def.ad or "") .. "  ·  " .. (E.def.id or "")) or "Elige una misión o crea una nueva"
          G.Yaz(ad .. (E.kirli and "   ●  sin guardar" or ""), F(20, "baslik"), O(24), O(46), E.kirli and R.altinAcik or R.fildisi)
          G.AltinCizgi(0, h - 1, w, 120)
     end
     local function UstDugme(m, f, tur, w)
          local b = K.Dugme(ust, m, f, tur)
          b:Dock(RIGHT)
          b:SetWide(w or O(110))
          b:DockMargin(O(6), O(14), 0, O(14))
          return b
     end
     UstDugme("Cerrar", function() self:Kapat() end, "tehlike", O(90))
     UstDugme("Ocultar", function()
          self:SetVisible(false)
          notification.AddLegacy("Editor oculto. Para reabrir: sardon_gorev_editor o /GorevEditor", NOTIFY_HINT, 6)
     end, nil, O(90))
     UstDugme("Jugadores", function() G.EditorIste("jugadorlar") end, nil, O(110))
     UstDugme("Actores del mundo", function() if G.DunyaPenceresi then G.DunyaPenceresi() end end, nil, O(150))
     UstDugme("Lugares", function() if G.YerPenceresi then G.YerPenceresi() end end, nil, O(100))

     -- sol: misión listesi
     local sol = vgui.Create("EditablePanel", self)
     sol:Dock(LEFT)
     sol:SetWide(O(320))
     sol:DockPadding(O(16), O(12), O(10), O(12))
     self.ara = K.Giris(sol, "", false, function() self:ListeYenile() end)
     self.ara:Dock(TOP)
     self.ara:SetTall(O(30))
     self.ara:SetPlaceholderText("Buscar misión…")
     self.filtre = K.Secim(sol, { { id = "", ad = "Todos los tipos" }, unpack(TUR_SECENEK) }, "", function(v) self.turFiltre = v self:ListeYenile() end)
     self.filtre:Dock(TOP)
     self.filtre:SetTall(O(28))
     self.filtre:DockMargin(0, O(6), 0, O(6))
     local alt = vgui.Create("EditablePanel", sol)
     alt:Dock(BOTTOM)
     alt:SetTall(O(34))
     local yeni = K.Dugme(alt, "+ Nueva", function() self:YeniGorev() end, "ana")
     yeni:Dock(LEFT)
     yeni:SetWide(O(96))
     local kopya = K.Dugme(alt, "Copiar", function()
          if not E.def then return end
          local k = table.Copy(E.def)
          k.id = (E.def.id or "gorev") .. "_kopya"
          k.ad = (E.def.ad or "") .. " (copia)"
          k.surum = 0
          E.def, E.eskiId, E.kirli = k, nil, true
          self:Yenile()
     end)
     kopya:Dock(LEFT)
     kopya:SetWide(O(90))
     kopya:DockMargin(O(6), 0, 0, 0)
     local sil = K.Dugme(alt, "Eliminar", function()
          if not E.def or not E.eskiId then return end
          Derma_Query("¿Eliminar “" .. (E.def.ad or E.eskiId) .. "”? También se cerrarán las instancias en curso.", "Eliminar misión", "Eliminar", function()
               G.EditorIste("sil", { id = E.eskiId })
               E.def, E.eskiId, E.kirli = nil, nil, false
               self:Yenile()
          end, "Cancelar")
     end, "tehlike")
     sil:Dock(RIGHT)
     sil:SetWide(O(70))
     self.liste = K.Kaydir(sol)
     self.liste:Dock(FILL)

     -- alt şerit
     local ayak = vgui.Create("EditablePanel", self)
     ayak:Dock(BOTTOM)
     ayak:SetTall(O(58))
     ayak:DockPadding(O(16), O(10), O(16), O(10))
     ayak.Paint = function(_, w) G.AltinCizgi(0, 0, w, 120) end
     self.ayak = ayak
     local kaydet = K.Dugme(ayak, "Guardar  (Ctrl+S)", function() self:Kaydet() end, "ana")
     kaydet:Dock(LEFT)
     kaydet:SetWide(O(170))
     local function Test(m, islem, w, tur)
          local b = K.Dugme(ayak, m, function()
               if not E.def or not E.eskiId then Not("Guarda primero.", "hata") return end
               local function Yap()
                    local adim = islem == "baslat" and self.testAdim or (islem == "adim" and self.testAdim) or nil
                    G.EditorIste("test", { islem = islem, id = E.eskiId, adim = adim, hedef = "ben" })
               end
               if E.kirli and (islem == "baslat" or islem == "adim") then
                    self:Kaydet()
                    timer.Simple(0.6, Yap)
               else
                    Yap()
               end
          end, tur)
          b:Dock(LEFT)
          b:SetWide(w)
          b:DockMargin(O(8), 0, 0, 0)
          return b
     end
     Test("▶ Iniciar en mí", "baslat", O(140))
     self.adimSecim = vgui.Create("EditablePanel", ayak)
     self.adimSecim:Dock(LEFT)
     self.adimSecim:SetWide(O(220))
     self.adimSecim:DockMargin(O(6), 0, 0, 0)
     Test("Saltar al paso", "adim", O(110))
     Test("Terminar ✓", "bitir", O(90))
     Test("Cancelar", "iptal", O(70))
     Test("Resetear mi progreso", "sifirla", O(150), "tehlike")
     local karsi = Test("Montar encuentro", "karsilasma", O(150))
     karsi.Think = function(s) s:SetVisible(E.def ~= nil and E.def.tur == "karsilasma") end

     -- orta
     local orta = vgui.Create("EditablePanel", self)
     orta:Dock(FILL)
     orta:DockPadding(O(10), O(10), O(16), O(6))
     self.sekmeler = vgui.Create("EditablePanel", orta)
     self.sekmeler:Dock(TOP)
     self.sekmeler:SetTall(O(36))
     self.icerik = vgui.Create("EditablePanel", orta)
     self.icerik:Dock(FILL)
     self.icerik:DockMargin(0, O(10), 0, 0)

     self:ListeYenile()
     self:Yenile()
end

function PENCERE:Paint(w, h)
     local a = G.Yumusak((RealTime() - self.acilis) / 0.25)
     G.Pano(0, 0, w, h, a, Color(9, 15, 13, 248))
end

function PENCERE:Think()
     if input.IsKeyDown(KEY_S) and input.IsKeyDown(KEY_LCONTROL) and not self.ctrlS then
          self.ctrlS = true
          self:Kaydet()
     elseif not input.IsKeyDown(KEY_S) then
          self.ctrlS = nil
     end
end

function PENCERE:Kapat()
     local function Kapa()
          G.EditorIste("kapat")
          self:Remove()
          G.EditorPencere = nil
     end
     if E.kirli then
          Derma_Query("Hay cambios sin guardar. ¿Cerrar?", "Taller de misiones", "Cerrar sin guardar", Kapa, "Cancelar")
     else
          Kapa()
     end
end

function PENCERE:Kaydet()
     if not E.def then return end
     E.def.id = G.Kimlik(E.def.id)
     if E.def.id == "" then Not("El ID de la misión no puede estar vacío.", "hata") return end
     G.EditorIste("kaydet", { def = E.def, eskiId = E.eskiId })
end

function PENCERE:YeniGorev()
     local function Yap()
          local id, n = "yeni_gorev", 1
          local var = {}
          for _, g in ipairs(E.liste) do var[g.id] = true end
          while var[id] do n = n + 1 id = "yeni_gorev_" .. n end
          E.def = {
               id = id, ad = "Nueva misión", tur = "yan", ozet = "", aciklama = "", aktif = false, siralama = 100,
               baslatma = "elle", olay = "", tekrar = "yok", bekleme = 0, kapsam = "karakter", iptal = true, olunce = "devam",
               karsilasmaEngel = false, gunlukAgirlik = 1, kosullar = {}, oduller = {}, aktorler = {}, replikler = {},
               karsilasma = {}, adimlar = { { id = "baslangic", ad = "Inicio", giris = {}, hedefler = {}, cikis = {}, replikler = {}, hedefKip = "hepsi", sonraki = "", kontrol = true } },
          }
          for _, a in ipairs(G.KarsilasmaAlanlari) do E.def.karsilasma[a.k] = istable(a.v) and table.Copy(a.v) or a.v end
          E.eskiId, E.kirli, E.sekme, E.adimNo = nil, true, "genel", 1
          self:Yenile()
     end
     if E.kirli then Derma_Query("Se perderán los cambios sin guardar.", "Nueva misión", "Continuar", Yap, "Cancelar") else Yap() end
end

function PENCERE:ListeYenile()
     if not IsValid(self.liste) then return end
     self.liste:Clear()
     local ara = G.Kucuk(IsValid(self.ara) and self.ara:GetValue() or "")
     local liste = table.Copy(E.liste or {})
     table.sort(liste, function(a, b)
          local ta, tb = G.Tur(a.tur).sira, G.Tur(b.tur).sira
          if ta ~= tb then return ta < tb end
          if (a.siralama or 100) ~= (b.siralama or 100) then return (a.siralama or 100) < (b.siralama or 100) end
          return (a.ad or "") < (b.ad or "")
     end)
     for _, g in ipairs(liste) do
          if (ara == "" or string.find(G.Kucuk((g.ad or "") .. " " .. g.id), ara, 1, true)) and (not self.turFiltre or self.turFiltre == "" or g.tur == self.turFiltre) then
               local b = self.liste:Add("DButton")
               b:Dock(TOP)
               b:SetTall(O(56))
               b:DockMargin(0, 0, O(6), O(4))
               b:SetText("")
               b.Paint = function(s, w, h)
                    local sec = E.eskiId == g.id
                    local renk = G.TurRenk(g.tur)
                    G.Kutu(0, 0, w, h, sec and Color(34, 46, 36, 240) or Color(16, 24, 20, s:IsHovered() and 240 or 195))
                    G.Kutu(0, 0, O(3), h, sec and R.altin or G.Renk(renk, 160))
                    G.Yaz(G.Tur(g.tur).kisa .. (g.aktif and "" or "  ·  BORRADOR"), F(10, "kalin"), O(12), O(13), g.aktif and renk or R.soluk, 0, O(2))
                    G.Yaz(G.Kisalt(g.ad or g.id, 30), F(14, "kalin"), O(12), O(31), R.fildisi)
                    G.Yaz(g.id .. "  ·  " .. (g.adim or 0) .. " pasos  ·  v" .. (g.surum or 0), F(11, "govde"), O(12), O(46), R.soluk)
               end
               b.DoClick = function()
                    local function Ac()
                         G.EditorIste("al", { id = g.id })
                         E.istenen = g.id
                    end
                    if E.kirli then Derma_Query("Se perderán los cambios sin guardar.", "Abrir misión", "Continuar", Ac, "Cancelar") else Ac() end
               end
          end
     end
end

function PENCERE:SekmeAc(id)
     E.sekme = id
     self.icerik:Clear()
     self.sekmeler:Clear()
     if not E.def then
          local l = K.Etiket(self.icerik, "Elige una misión a la izquierda o empieza con “+ Nueva”.", R.soluk, F(18, "italik"))
          l:Dock(FILL)
          l:SetContentAlignment(5)
          return
     end
     for _, s in ipairs(SEKMELER) do
          local b = vgui.Create("DButton", self.sekmeler)
          b:Dock(LEFT)
          b:SetWide(G.Genislik(G.Buyuk(s.ad), F(13, "kalin"), O(2)) + O(34))
          b:SetText("")
          b.Paint = function(s2, w, h)
               local sec = E.sekme == s.id
               G.Yaz(G.Buyuk(s.ad), F(13, "kalin"), w / 2, h / 2 - O(2), sec and R.altinAcik or (s2:IsHovered() and R.fildisi or R.soluk), 1, O(2))
               if sec then G.Kutu(O(10), h - O(3), w - O(20), O(2), R.altin) end
          end
          b.DoClick = function() G.Cal("tik") self:SekmeAc(s.id) end
     end
     local f = SekmeKur[id]
     if f then
          local ok, hata = pcall(f, self.icerik)
          if not ok then
               ErrorNoHalt("[Sardon Misión] editor: " .. tostring(hata) .. "\n")
               local l = K.Etiket(self.icerik, "No se pudo abrir la pestaña: " .. tostring(hata), R.kirmizi, F(14, "govde"))
               l:Dock(TOP)
          end
     end
end

function PENCERE:AdimSecimYenile()
     if not IsValid(self.adimSecim) then return end
     self.adimSecim:Clear()
     if not E.def then return end
     local sec = { { id = "", ad = "— desde el primer paso —" } }
     for i, a in ipairs(E.def.adimlar or {}) do sec[#sec + 1] = { id = a.id, ad = i .. ". " .. a.id } end
     self.testAdim = nil
     local c = K.Secim(self.adimSecim, sec, "", function(v) self.testAdim = v ~= "" and v or nil end)
     c:Dock(FILL)
end

function PENCERE:Yenile()
     self:SekmeAc(E.sekme or "genel")
     self:AdimSecimYenile()
end

vgui.Register("SardonGorev.Editor", PENCERE, "EditablePanel")

function G.EditorAc()
     if not G.Editor(LocalPlayer()) then
          notification.AddLegacy("No tienes permiso para el editor de misiones.", NOTIFY_ERROR, 4)
          return
     end
     if IsValid(G.EditorPencere) then
          G.EditorPencere:SetVisible(true)
          G.EditorPencere:MakePopup()
          return
     end
     G.EditorPencere = vgui.Create("SardonGorev.Editor")
     G.EditorIste("ac")
     G.EditorIste("sesler")
end

concommand.Add("sardon_gorev_editor", G.EditorAc)

/*
*   Sunucu yanıtları
*/
local YANIT = {}

YANIT.liste = function(t)
     E.liste = t.gorevler or {}
     E.yerler = t.yerler or {}
     E.dunya = t.dunya or {}
     E.harita = t.harita or ""
     if IsValid(G.EditorPencere) then G.EditorPencere:ListeYenile() end
     hook.Run("SardonGorevEditorListe")
end

YANIT.gorev = function(t)
     if not t.def then return end
     E.def = t.def
     E.eskiId = t.def.id
     E.kirli = false
     E.adimNo, E.aktorNo = 1, 1
     if IsValid(G.EditorPencere) then G.EditorPencere:Yenile() G.EditorPencere:ListeYenile() end
end

YANIT.kaydedildi = function(t)
     E.eskiId = t.id
     E.kirli = false
     if E.def then
          E.def.surum = t.surum
          E.def.id = t.id
     end
     Not("Guardado: " .. t.id .. " (versión " .. (t.surum or "?") .. ")")
     if IsValid(G.EditorPencere) then G.EditorPencere:AdimSecimYenile() G.EditorPencere:ListeYenile() end
end

YANIT.hata = function(t) Not(t.metin or "Error", "hata") end

YANIT.sesler = function(t)
     G.SesListe = t.liste or {}
     if IsValid(G.EditorPencere) and E.sekme == "seslendirme" then G.EditorPencere:SekmeAc("seslendirme") end
end

YANIT.jugadorlar = function(t)
     local p = K.Pencere("Misiones de los jugadores", O(720), O(600))
     local kay = K.Kaydir(p.govde)
     kay:Dock(FILL)
     for _, o in ipairs(t.liste or {}) do
          local satir = kay:Add("EditablePanel")
          satir:Dock(TOP)
          local metinler = {}
          for _, g in ipairs(o.gorevler or {}) do metinler[#metinler + 1] = g.id .. " · " .. g.adim .. (g.gizli and " (emboscada)" or "") end
          local h = O(30) + #metinler * O(18)
          satir:SetTall(h)
          satir:DockMargin(0, 0, O(6), O(4))
          satir.Paint = function(_, w, hh)
               G.Kutu(0, 0, w, hh, Color(16, 24, 20, 210))
               G.Yaz(o.ad .. "  ·  " .. o.sid, F(14, "kalin"), O(10), O(14), R.fildisi)
               for i, m in ipairs(metinler) do G.Yaz(m, F(12, "govde"), O(24), O(28) + (i - 0.5) * O(18), R.govde) end
               if #metinler == 0 then G.Yaz("sin misiones", F(12, "italik"), w - O(10), O(14), R.soluk, 2) end
          end
     end
end

net.Receive("SardonGorev.Yonetim", function()
     local op = net.ReadString()
     local t = G.OkuTablo()
     local f = YANIT[op]
     if f then f(t) end
end)
