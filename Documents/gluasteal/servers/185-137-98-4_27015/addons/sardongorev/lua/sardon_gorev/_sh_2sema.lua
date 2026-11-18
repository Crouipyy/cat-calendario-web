-- "addons\\sardongorev\\lua\\sardon_gorev\\_sh_2sema.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Şema: eylem, hedef, koşul, ödül, replik ve actor türlerinin alanları.
*   Editör formları buradan üretilir; sunucu mantığı sv_ dosyalarında aynı kimliğe bağlanır
*   (G.Eylem[t].Calis, G.Hedef[t].Kur/Kontrol/Olay, G.Kosul[t], G.Odul[t]).
*
*   Alan: { k = anahtar, ad = etiket, tip = ..., v = varsayılan, ipucu = "...", goster = fn(e) }
*   tip: metin yazi sayi bool secim yer aktor konusan adim gorev esya buyu ses model anim renk
*        liste kosullar oduller sahne sinif
*/
local G = SardonGorev

G.Sema = { Eylem = {}, Hedef = {}, Kosul = {}, Odul = {} }
G.SemaSira = { Eylem = {}, Hedef = {}, Kosul = {}, Odul = {} }

local function Kaydet(tur, id, t)
     t.id = id
     t.alanlar = t.alanlar or {}
     G.Sema[tur][id] = t
     local sira = G.SemaSira[tur]
     for i, v in ipairs(sira) do
          if v == id then table.remove(sira, i) break end
     end
     sira[#sira + 1] = id
end

-- Varsayılanlarla yeni guardar
function G.SemaYeni(tur, id)
     local s = G.Sema[tur] and G.Sema[tur][id]
     if not s then return end
     local e = { t = id }
     for _, a in ipairs(s.alanlar) do
          if a.v ~= nil then e[a.k] = istable(a.v) and table.Copy(a.v) or a.v end
     end
     return e
end

function G.SemaOzet(tur, e)
     local s = G.Sema[tur] and G.Sema[tur][e and e.t or ""]
     if not s then return "? " .. tostring(e and e.t) end
     if s.ozet then
          local ok, r = pcall(s.ozet, e)
          if ok and r then return r end
     end
     return s.ad
end

local function Y(s) return (s and s ~= "") and s or "?" end
local function M(s, n) return "“" .. G.Kisalt(s or "", n or 38) .. "”" end

/*
*   Ortak seçenek listeleri
*/
G.HareListe = {
     { id = "", ad = "Yok" },
     { id = "ani", ad = "Recuerdo (plateado, suave)" },
     { id = "hayalet", ad = "Fantasma (sem transparente)" },
     { id = "nur", ad = "Resplandor (blanco intenso)" },
     { id = "silik", ad = "Recuerdo borrado (disperso)" },
     { id = "ince", ad = "Aura tenue" },
}

G.EfektListe = {
     { id = "", ad = "Yok" },
     { id = "isik", ad = "Destello de luz" },
     { id = "duman", ad = "Duman" },
     { id = "cinlama", ad = "Cisimlenme (cin sesi)" },
}

G.ParcacikListe = {
     { id = "isik_toz", ad = "Polvo de luz (interno)" },
     { id = "kivilcim", ad = "Chispa dorada (interno)" },
     { id = "buhar", ad = "Vapor plateado (interno)" },
     { id = "[0]_wispambient", ad = "Ruh ışıkları (z_theme)" },
     { id = "[0]_fog_ambient", ad = "Sis (z_theme)" },
     { id = "[0]_starsky", ad = "Yıldızlı gök (z_theme)" },
     { id = "[0]_sakura_ground", ad = "Sakura yaprakları (z_theme)" },
     { id = "[0]_thunder_weather", ad = "Fırtına (z_theme)" },
     { id = "[0]_blood_fog", ad = "Kan sisi (z_theme)" },
     { id = "[0]_tornado", ad = "Kasırga (z_theme)" },
}

local YUMUSATMA = {
     { id = "yumusak", ad = "Suave" }, { id = "dogrusal", ad = "Lineal" },
     { id = "yavasBasla", ad = "Desacelerar al inicio" }, { id = "yavasBitir", ad = "Desacelerar al final" },
}

local MAGAZA = {
     { id = "", ad = "Herhangi" }, { id = "shopic", ad = "Tiendas Sardon" }, { id = "hogshop", ad = "Hogwarts Shop (asa/büyü)" },
     { id = "vendor", ad = "Vendedor Helix" }, { id = "gorev", ad = "Desde diálogo de misión" },
     { id = "aksesuar", ad = "Madam Malkin (aksesuar)" },
}

local KAMERA_HEDEF = {
     { id = "", ad = "Ninguno (ángulo del lugar)" }, { id = "oyuncu", ad = "Jugador" }, { id = "aktor", ad = "Actor" }, { id = "yer", ad = "Yer" },
}

/* ======================================================================================
*   EYLEMLER
* ====================================================================================== */
G.EylemKategori = {
     { id = "konusma", ad = "Diálogo" }, { id = "aktor", ad = "Actor" }, { id = "sahne", ad = "Sahne" },
     { id = "oyuncu", ad = "Jugador" }, { id = "akis", ad = "Flujo" }, { id = "dunya", ad = "Mundo" },
}

local SATIR_ALANLARI = {
     { k = "kim", ad = "Konuşan", tip = "konusan", v = "", ipucu = "Vacío: actor del diálogo" },
     { k = "metin", ad = "Réplica", tip = "yazi", v = "" },
     { k = "ses", ad = "Archivo de sonido", tip = "ses", v = "" },
     { k = "anim", ad = "Hareket", tip = "anim", v = "" },
     { k = "sure", ad = "Duración (0 = auto)", tip = "sayi", v = 0, min = 0, max = 30, ondalik = 1 },
}

local function SatirOzet(s)
     return (s.kim and s.kim ~= "" and (s.kim .. ": ") or "") .. M(s.metin, 50) .. ((s.ses or "") ~= "" and "  ♪" or "")
end

Kaydet("Eylem", "konus", {
     ad = "Diálogo", kat = "konusma", ikon = "konus",
     aciklama = "El actor dice una réplica: el sonido 3D sale de su boca; el dueño de la misión ve subtítulos. Si no hay actor, texto de narrador.",
     alanlar = {
          { k = "aktor", ad = "Actor", tip = "aktor", v = "" },
          { k = "metin", ad = "Réplica", tip = "yazi", v = "" },
          { k = "ses", ad = "Archivo de sonido", tip = "ses", v = "" },
          { k = "anim", ad = "Hareket", tip = "anim", v = "", ipucu = "Ej. gesture_wave (saludo)" },
          { k = "bak", ad = "Jugadorya bak", tip = "bool", v = true },
          { k = "bekle", ad = "Bitene kadar bekle", tip = "bool", v = true },
          { k = "kanal", ad = "Presentación", tip = "secim", v = "altyazi", secenekler = {
               { id = "altyazi", ad = "Subtítulos (dueño de la misión)" }, { id = "balon", ad = "Solo globo sobre la cabeza" } } },
     },
     ozet = function(e) return (e.aktor ~= "" and e.aktor or "Narrador") .. ": " .. M(e.metin) .. ((e.ses or "") ~= "" and "  ♪" or "") end,
})

Kaydet("Eylem", "diyalog", {
     ad = "Diyalog", kat = "konusma", ikon = "diyalog",
     aciklama = "Diálogo en secuencia y opciones. En modo cinemático el jugador se detiene y la cámara gira; en libre, subtítulos y teclas numéricas.",
     alanlar = {
          { k = "aktor", ad = "Actor", tip = "aktor", v = "" },
          { k = "kip", ad = "Kip", tip = "secim", v = "sinematik", secenekler = { { id = "sinematik", ad = "Sinematik" }, { id = "serbest", ad = "Libre (caminando)" } } },
          { k = "satirlar", ad = "Líneas", tip = "liste", v = {}, alanlar = SATIR_ALANLARI, ozet = SatirOzet },
          { k = "secenekler", ad = "Opciones", tip = "liste", v = {}, ozet = function(s)
               return M(s.metin, 44) .. ((s.git or "") ~= "" and ("  → " .. s.git) or "") .. ((tonumber(s.fiyat) or 0) > 0 and ("  " .. s.fiyat .. "G") or "")
          end, alanlar = {
               { k = "metin", ad = "Opción", tip = "metin", v = "" },
               { k = "yanit", ad = "Líneas de respuesta", tip = "liste", v = {}, alanlar = SATIR_ALANLARI, ozet = SatirOzet },
               { k = "donus", ad = "Volver a opciones tras respuesta", tip = "bool", v = false },
               { k = "git", ad = "Ir al paso", tip = "adim", v = "" },
               { k = "bitir", ad = "Resultado", tip = "secim", v = "", secenekler = { { id = "", ad = "Continuar" }, { id = "basari", ad = "Terminar misión (éxito)" }, { id = "basarisiz", ad = "Terminar misión (fallida)" } } },
               { k = "degisken", ad = "Variable", tip = "metin", v = "" },
               { k = "deger", ad = "Valor", tip = "metin", v = "" },
               { k = "fiyat", ad = "Precio (Galeones)", tip = "sayi", v = 0, min = 0, max = 100000 },
               { k = "oduller", ad = "Verilecekler", tip = "oduller", v = {} },
               { k = "kosullar", ad = "Condición de visibilidad", tip = "kosullar", v = {} },
               { k = "satin", ad = "Contar como compra (nombre)", tip = "metin", v = "", ipucu = "Doluysa 'Satın al' objetivoine bu adla sayılır" },
               { k = "olay", ad = "Olay tetikle (ad)", tip = "metin", v = "", ipucu = "Doluysa hook.Run(\"SardonGorevOlay\", oyuncu, ad, gorevId). aksesuar_hediye: Madam Malkin hediye + dükkân, aksesuar_magaza: dükkân" },
          } },
          { k = "kamera", ad = "Kamera", tip = "secim", v = "otomatik", secenekler = { { id = "otomatik", ad = "Girar hacia quien habla" }, { id = "yok", ad = "Yok" } } },
     },
     ozet = function(e) return (e.kip == "serbest" and "Serbest" or "Sinematik") .. " · " .. #(e.satirlar or {}) .. " satır · " .. #(e.secenekler or {}) .. " seçenek" end,
})

-- Actor
Kaydet("Eylem", "aktor_olustur", {
     ad = "Poner actor en escena", kat = "aktor", ikon = "aktor",
     alanlar = {
          { k = "aktor", ad = "Actor", tip = "aktor", v = "" },
          { k = "yer", ad = "Yer", tip = "yer", v = "" },
          { k = "yon", ad = "Dirección", tip = "secim", v = "yer", secenekler = { { id = "yer", ad = "Orientación del lugar" }, { id = "oyuncu", ad = "Hacia el jugador" } } },
          { k = "efekt", ad = "Aparición", tip = "secim", v = "", secenekler = G.EfektListe },
     },
     ozet = function(e) return Y(e.aktor) .. " → " .. Y(e.yer) end,
})

Kaydet("Eylem", "aktor_kaldir", {
     ad = "Quitar actor", kat = "aktor", ikon = "aktor",
     alanlar = {
          { k = "aktor", ad = "Actor", tip = "aktor", v = "" },
          { k = "efekt", ad = "Desaparición", tip = "secim", v = "", secenekler = G.EfektListe },
     },
     ozet = function(e) return Y(e.aktor) end,
})

Kaydet("Eylem", "aktor_yuru", {
     ad = "Hacer caminar al actor", kat = "aktor", ikon = "yuru",
     aciklama = "Rehber açıkken jugador geride kalınca durup bekler, yaklaşınca devam eder. Objetivo bir 'yol' yeriyse yolu izler.",
     alanlar = {
          { k = "aktor", ad = "Actor", tip = "aktor", v = "" },
          { k = "hedef", ad = "Hedef (nokta ya da yol)", tip = "yer", v = "" },
          { k = "rota", ad = "Rota", tip = "secim", v = "otomatik", secenekler = {
               { id = "otomatik", ad = "Si es ruta, la ruta; si no, red Fieldguide" }, { id = "duz", ad = "Línea recta" } } },
          { k = "kip", ad = "Velocidad", tip = "secim", v = "yuru", secenekler = { { id = "yuru", ad = "Caminar" }, { id = "kos", ad = "Correr" } } },
          { k = "hiz", ad = "Velocidad custom (0 = según modo)", tip = "sayi", v = 0, min = 0, max = 400, ipucu = "Caminarme 78, koşma 215 birim/sn" },
          { k = "rehber", ad = "Rehber (jugadoryu bekle)", tip = "bool", v = false },
          { k = "bag", ad = "Bağ: zerre şeridi + jugador koşamaz (actor başka işe geçene dek)", tip = "bool", v = false },
          { k = "bekle", ad = "Varana kadar bekle", tip = "bool", v = false },
          { k = "varinca", ad = "Varınca", tip = "secim", v = "oyuncu", secenekler = { { id = "", ad = "Como está" }, { id = "oyuncu", ad = "Girar hacia jugador" }, { id = "yer", ad = "Girar hacia la orientación del lugar" } } },
     },
     ozet = function(e) return Y(e.aktor) .. " → " .. Y(e.hedef) .. (e.rehber and "  (rehber)" or "") end,
})

Kaydet("Eylem", "aktor_takip", {
     ad = "Actor sigue al jugador", kat = "aktor", ikon = "yuru",
     alanlar = {
          { k = "aktor", ad = "Actor", tip = "aktor", v = "" },
          { k = "acik", ad = "Açık", tip = "bool", v = true },
          { k = "mesafe", ad = "Mesafe", tip = "sayi", v = 110, min = 50, max = 600 },
          { k = "bag", ad = "Bağ: zerre şeridi + jugador koşamaz", tip = "bool", v = false },
     },
     ozet = function(e) return Y(e.aktor) .. (e.acik and (e.bag and " bağla izliyor" or " izliyor") or " izlemeyi bırakır") end,
})

Kaydet("Eylem", "aktor_bak", {
     ad = "Actor mira", kat = "aktor", ikon = "goz",
     alanlar = {
          { k = "aktor", ad = "Actor", tip = "aktor", v = "" },
          { k = "hedef", ad = "Neye", tip = "secim", v = "oyuncu", secenekler = { { id = "oyuncu", ad = "Jugador" }, { id = "aktor", ad = "Otro actor" }, { id = "yer", ad = "Yer" }, { id = "", ad = "Nada" } } },
          { k = "hedefAktor", ad = "Actor objetivo", tip = "aktor", v = "", goster = function(e) return e.hedef == "aktor" end },
          { k = "yer", ad = "Hedef yer", tip = "yer", v = "", goster = function(e) return e.hedef == "yer" end },
     },
     ozet = function(e) return Y(e.aktor) .. " → " .. (e.hedef == "aktor" and Y(e.hedefAktor) or e.hedef == "yer" and Y(e.yer) or e.hedef == "oyuncu" and "jugador" or "—") end,
})

Kaydet("Eylem", "aktor_anim", {
     ad = "Animación del actor", kat = "aktor", ikon = "anim",
     alanlar = {
          { k = "aktor", ad = "Actor", tip = "aktor", v = "" },
          { k = "anim", ad = "Animasyon", tip = "anim", v = "" },
          { k = "dongu", ad = "Bucle (en lugar de espera)", tip = "bool", v = false },
          { k = "sure", ad = "Duración (0 = una vez)", tip = "sayi", v = 0, min = 0, max = 600, ondalik = 1 },
          { k = "bekle", ad = "Bitene kadar bekle", tip = "bool", v = false },
     },
     ozet = function(e) return Y(e.aktor) .. ": " .. Y(e.anim) .. (e.dongu and " (döngü)" or "") end,
})

Kaydet("Eylem", "aktor_hare", {
     ad = "Aura de recuerdo", kat = "aktor", ikon = "hare",
     aciklama = "Envuelve al actor con luz como un recuerdo (aura de recuerdo del cine).",
     alanlar = {
          { k = "aktor", ad = "Actor", tip = "aktor", v = "" },
          { k = "hare", ad = "Görünüm", tip = "secim", v = "ani", secenekler = G.HareListe },
          { k = "gecis", ad = "Transición (s)", tip = "sayi", v = 1.5, min = 0, max = 8, ondalik = 1 },
     },
     ozet = function(e) return Y(e.aktor) .. ": " .. (e.hare ~= "" and e.hare or "kapalı") end,
})

Kaydet("Eylem", "aktor_isinla", {
     ad = "Teletransportar actor", kat = "aktor", ikon = "aktor",
     alanlar = {
          { k = "aktor", ad = "Actor", tip = "aktor", v = "" },
          { k = "yer", ad = "Yer", tip = "yer", v = "" },
          { k = "efekt", ad = "Efekt", tip = "secim", v = "", secenekler = G.EfektListe },
     },
     ozet = function(e) return Y(e.aktor) .. " → " .. Y(e.yer) end,
})

Kaydet("Eylem", "aktor_ad", {
     ad = "Del actor adını değiştir", kat = "aktor", ikon = "aktor",
     aciklama = "Örn. tanışana kadar 'Yabancı', tanışınca gerçek adı.",
     alanlar = {
          { k = "aktor", ad = "Actor", tip = "aktor", v = "" },
          { k = "ad", ad = "Görünen ad", tip = "metin", v = "" },
          { k = "unvan", ad = "Unvan", tip = "metin", v = "" },
     },
     ozet = function(e) return Y(e.aktor) .. " → " .. Y(e.ad) end,
})

-- Sahne
Kaydet("Eylem", "kamera", {
     ad = "Cámara çekimi", kat = "sahne", ikon = "kamera",
     aciklama = "Sabit: kamera yerinden. Kaydır: yer → yer2. Yörünge: objetivoin çevresinde. Diálogo: actor ile jugador arasında omuz çekimi.",
     alanlar = {
          { k = "tur", ad = "Tipo", tip = "secim", v = "sabit", secenekler = {
               { id = "sabit", ad = "Sabit" }, { id = "kaydir", ad = "Kaydır (iki yer arası)" }, { id = "yorunge", ad = "Yörünge" }, { id = "konusma", ad = "Diálogo çekimi" } } },
          { k = "yer", ad = "Kamera yeri", tip = "yer", v = "" },
          { k = "yer2", ad = "Bitiş yeri", tip = "yer", v = "", goster = function(e) return e.tur == "kaydir" end },
          { k = "hedef", ad = "Bakılan", tip = "secim", v = "", secenekler = KAMERA_HEDEF },
          { k = "hedefAktor", ad = "Bakılan actor", tip = "aktor", v = "", goster = function(e) return e.hedef == "aktor" or e.tur == "konusma" or e.tur == "yorunge" end },
          { k = "hedefYer", ad = "Bakılan yer", tip = "yer", v = "", goster = function(e) return e.hedef == "yer" end },
          { k = "sure", ad = "Süre (sn, 0 = kapatılana dek)", tip = "sayi", v = 4, min = 0, max = 120, ondalik = 1 },
          { k = "fov", ad = "Ángulo de visión", tip = "sayi", v = 60, min = 10, max = 110 },
          { k = "yumusatma", ad = "Yumuşatma", tip = "secim", v = "yumusak", secenekler = YUMUSATMA },
          { k = "serit", ad = "Sinema şeritleri", tip = "bool", v = true },
          { k = "kilit", ad = "Jugadoryu durdur", tip = "bool", v = true },
          { k = "bekle", ad = "Bitene kadar bekle", tip = "bool", v = true },
     },
     ozet = function(e) return e.tur .. " · " .. Y(e.yer) .. " · " .. (e.sure or 0) .. " sn" end,
})

Kaydet("Eylem", "kamera_bitir", {
     ad = "Cámarayı jugadorya ver", kat = "sahne", ikon = "kamera",
     alanlar = { { k = "gecis", ad = "Transición (s)", tip = "sayi", v = 0.8, min = 0, max = 5, ondalik = 1 } },
})

Kaydet("Eylem", "sahne", {
     ad = "Sinema sahnesi oynat", kat = "sahne", ikon = "sinema",
     aciklama = "Una ruta del Cine (cámara + actores) se incrusta en la misión y se reproduce al dueño. En el editor: importar ruta de cine.",
     alanlar = {
          { k = "veri", ad = "Sahne", tip = "sahne", v = {} },
          { k = "sure", ad = "Süre (0 = rotanın süresi)", tip = "sayi", v = 0, min = 0, max = 300, ondalik = 1 },
          { k = "hare", ad = "A los actores anı haresi", tip = "secim", v = "", secenekler = G.HareListe },
          { k = "efekt", ad = "Ekran", tip = "secim", v = "", secenekler = {
               { id = "", ad = "Doğal" }, { id = "ani", ad = "Anı (soluk, parlak kenar)" }, { id = "sepya", ad = "Sepya" }, { id = "siyahbeyaz", ad = "Siyah beyaz" }, { id = "ruya", ad = "Rüya" } } },
          { k = "serit", ad = "Sinema şeritleri", tip = "bool", v = true },
          { k = "atlanabilir", ad = "Atlanabilir (bir kez görülünce)", tip = "bool", v = true },
          { k = "bekle", ad = "Bitene kadar bekle", tip = "bool", v = true },
     },
     ozet = function(e) local v = e.veri or {} return (v.ad or "sahne") .. " · " .. #(v.anahtarlar or {}) .. " anahtar · " .. #(v.aktorler or {}) .. " actor" end,
})

Kaydet("Eylem", "karart", {
     ad = "Oscurecer / aclarar pantalla", kat = "sahne", ikon = "karart",
     alanlar = {
          { k = "yon", ad = "Dirección", tip = "secim", v = "kapan", secenekler = { { id = "kapan", ad = "Karar" }, { id = "acil", ad = "Açıl" } } },
          { k = "sure", ad = "Süre", tip = "sayi", v = 1, min = 0, max = 10, ondalik = 1 },
          { k = "renk", ad = "Renk", tip = "secim", v = "siyah", secenekler = { { id = "siyah", ad = "Siyah" }, { id = "beyaz", ad = "Beyaz" } } },
          { k = "bekle", ad = "Bitene kadar bekle", tip = "bool", v = true },
     },
     ozet = function(e) return (e.yon == "kapan" and "Kararır" or "Açılır") .. " · " .. e.sure .. " sn" end,
})

Kaydet("Eylem", "baslik", {
     ad = "Cartel de título", kat = "sahne", ikon = "baslik",
     alanlar = {
          { k = "ust", ad = "Üst línea", tip = "metin", v = "" },
          { k = "baslik", ad = "Başlık", tip = "metin", v = "" },
          { k = "alt", ad = "Alt línea", tip = "metin", v = "" },
          { k = "stil", ad = "Stil", tip = "secim", v = "bolum", secenekler = { { id = "bolum", ad = "Bölüm (ortada, büyük)" }, { id = "yer", ad = "Lugar adı (alt orta)" } } },
          { k = "sure", ad = "Süre", tip = "sayi", v = 5, min = 1, max = 20, ondalik = 1 },
          { k = "bekle", ad = "Bitene kadar bekle", tip = "bool", v = false },
     },
     ozet = function(e) return M(e.baslik) end,
})

Kaydet("Eylem", "efekt", {
     ad = "Ekran efekti", kat = "sahne", ikon = "efekt",
     alanlar = {
          { k = "tur", ad = "Efekt", tip = "secim", v = "ani", secenekler = {
               { id = "ani", ad = "Anı (soluk, parlak kenar)" }, { id = "sepya", ad = "Sepya" }, { id = "siyahbeyaz", ad = "Siyah beyaz" },
               { id = "ruya", ad = "Sueño (bordes borrosos)" }, { id = "titreme", ad = "Temblor" }, { id = "flas", ad = "Destello blanco" }, { id = "", ad = "Kapat" } } },
          { k = "sure", ad = "Süre (0 = paso bitene dek)", tip = "sayi", v = 0, min = 0, max = 120, ondalik = 1 },
          { k = "guc", ad = "Intensidad", tip = "sayi", v = 1, min = 0, max = 2, ondalik = 2 },
     },
     ozet = function(e) return e.tur ~= "" and e.tur or "kapat" end,
})

Kaydet("Eylem", "muzik", {
     ad = "Müzik", kat = "sahne", ikon = "muzik",
     alanlar = {
          { k = "ses", ad = "Archivo de sonido", tip = "ses", v = "" },
          { k = "url", ad = "ya da adres (http)", tip = "metin", v = "" },
          { k = "seviye", ad = "Ses seviyesi", tip = "sayi", v = 0.5, min = 0, max = 1, ondalik = 2 },
          { k = "dongu", ad = "Bucle", tip = "bool", v = true },
          { k = "gecis", ad = "Transición (s)", tip = "sayi", v = 2, min = 0, max = 10, ondalik = 1 },
     },
     ozet = function(e) return (e.ses ~= "" and e.ses) or (e.url ~= "" and "URL") or "?" end,
})

Kaydet("Eylem", "muzik_dur", {
     ad = "Müziği durdur", kat = "sahne", ikon = "muzik",
     alanlar = { { k = "gecis", ad = "Transición (s)", tip = "sayi", v = 2, min = 0, max = 10, ondalik = 1 } },
})

Kaydet("Eylem", "ses_efekti", {
     ad = "Ses efekti", kat = "sahne", ikon = "muzik",
     aciklama = "Oyunun kendi sesleri (sound/ altındaki yol, örn. ambient/levels/citadel/strange_talk1.wav) o archivo de sonido de misión.",
     alanlar = {
          { k = "kaynak", ad = "Kaynak", tip = "secim", v = "oyuncu", secenekler = { { id = "oyuncu", ad = "Jugador" }, { id = "aktor", ad = "Actor" }, { id = "yer", ad = "Yer" } } },
          { k = "aktor", ad = "Actor", tip = "aktor", v = "", goster = function(e) return e.kaynak == "aktor" end },
          { k = "yer", ad = "Yer", tip = "yer", v = "", goster = function(e) return e.kaynak == "yer" end },
          { k = "oyunSesi", ad = "Oyun sesi yolu", tip = "metin", v = "" },
          { k = "ses", ad = "o archivo de sonido de misión", tip = "ses", v = "" },
          { k = "seviye", ad = "Ses seviyesi", tip = "sayi", v = 0.8, min = 0, max = 1, ondalik = 2 },
     },
     ozet = function(e) return (e.oyunSesi ~= "" and e.oyunSesi) or Y(e.ses) end,
})

Kaydet("Eylem", "parcacik", {
     ad = "Parçacık efekti", kat = "sahne", ikon = "efekt",
     alanlar = {
          { k = "kaynak", ad = "Yer", tip = "secim", v = "yer", secenekler = { { id = "yer", ad = "Yer" }, { id = "aktor", ad = "Actor" }, { id = "oyuncu", ad = "Jugador" } } },
          { k = "yer", ad = "Yer", tip = "yer", v = "", goster = function(e) return e.kaynak == "yer" end },
          { k = "aktor", ad = "Actor", tip = "aktor", v = "", goster = function(e) return e.kaynak == "aktor" end },
          { k = "efekt", ad = "Efekt", tip = "secim", v = "isik_toz", secenekler = G.ParcacikListe },
          { k = "sure", ad = "Süre (0 = paso bitene dek)", tip = "sayi", v = 5, min = 0, max = 600, ondalik = 1 },
          { k = "herkes", ad = "Todos cercanos görsün", tip = "bool", v = false },
     },
     ozet = function(e) return e.efekt .. " @ " .. (e.kaynak == "yer" and Y(e.yer) or e.kaynak) end,
})

-- Jugador
Kaydet("Eylem", "isinla", {
     ad = "Teletransportar jugador", kat = "oyuncu", ikon = "isinla",
     alanlar = {
          { k = "yer", ad = "Yer", tip = "yer", v = "" },
          { k = "karart", ad = "Kararıp açılsın", tip = "bool", v = true },
     },
     ozet = function(e) return Y(e.yer) end,
})

Kaydet("Eylem", "sandal", {
     ad = "Sandal yolculuğu", kat = "oyuncu", ikon = "isinla",
     aciklama = "Jugador (ve istersen bir actor) bir sandala oturur, 'yol' yerinin noktaları boyunca kendiliğinden gider. Yol noktaları su yüzeyinde olmalı. Bitirmek için 'Sandaldan in'.",
     alanlar = {
          { k = "yer", ad = "Yol (yol yeri)", tip = "yer", v = "" },
          { k = "hiz", ad = "Velocidad (birim/sn)", tip = "sayi", v = 105, min = 20, max = 400 },
          { k = "aktor", ad = "Sandaldaki actor", tip = "aktor", v = "", ipucu = "Boş: jugador tek başına" },
          { k = "model", ad = "Sandal modeli", tip = "model", v = "", ipucu = "Boş: kürekli ahşap sandal" },
          { k = "bekle", ad = "Varana kadar bekle", tip = "bool", v = false, ipucu = "Cerradoysa sonraki acciónler (diálogolar) yolda oynar" },
     },
     ozet = function(e) return Y(e.yer) .. ((e.aktor or "") ~= "" and ("  + " .. e.aktor) or "") end,
})

Kaydet("Eylem", "sandal_bitir", {
     ad = "Sandaldan in", kat = "oyuncu", ikon = "isinla",
     aciklama = "Sandal varınca (istenirse) ekran kararır ve sandal kalkar. Jugador suyun üstünde kalır: ardından 'Teletransportar jugador ışınla' (kararmasız) koy.",
     alanlar = {
          { k = "varis", ad = "Varmasını bekle", tip = "bool", v = true },
          { k = "karart", ad = "Ekranı karart", tip = "bool", v = true },
     },
     ozet = function(e) return (e.varis ~= false and "varınca" or "hemen") .. (e.karart ~= false and " · kararır" or "") end,
})

Kaydet("Eylem", "kilit", {
     ad = "Detener / liberar jugador", kat = "oyuncu", ikon = "kilit",
     alanlar = { { k = "acik", ad = "Durdur", tip = "bool", v = true } },
     ozet = function(e) return e.acik and "durdur" or "bırak" end,
})

Kaydet("Eylem", "bildirim", {
     ad = "Bildirim / ipucu", kat = "oyuncu", ikon = "bilgi",
     alanlar = {
          { k = "metin", ad = "Metin", tip = "yazi", v = "" },
          { k = "tur", ad = "Tipo", tip = "secim", v = "ipucu", secenekler = { { id = "ipucu", ad = "Pista" }, { id = "bilgi", ad = "Bilgi" }, { id = "uyari", ad = "Advertencia" } } },
          { k = "sure", ad = "Süre", tip = "sayi", v = 6, min = 1, max = 30 },
     },
     ozet = function(e) return M(e.metin) end,
})

Kaydet("Eylem", "esya_ver", {
     ad = "Eşya ver", kat = "oyuncu", ikon = "esya",
     alanlar = {
          { k = "esya", ad = "Eşya", tip = "esya", v = "" },
          { k = "adet", ad = "Adet", tip = "sayi", v = 1, min = 1, max = 50 },
          { k = "veri", ad = "Eşya verisi (JSON)", tip = "metin", v = "" },
     },
     ozet = function(e) return (e.adet or 1) .. " × " .. Y(e.esya) end,
})

Kaydet("Eylem", "esya_al", {
     ad = "Eşya al", kat = "oyuncu", ikon = "esya",
     alanlar = {
          { k = "esya", ad = "Eşya", tip = "esya", v = "" },
          { k = "adet", ad = "Adet", tip = "sayi", v = 1, min = 1, max = 50 },
     },
     ozet = function(e) return (e.adet or 1) .. " × " .. Y(e.esya) end,
})

Kaydet("Eylem", "para", {
     ad = "Para ver / al", kat = "oyuncu", ikon = "para",
     alanlar = { { k = "miktar", ad = "Miktar (eksi = al)", tip = "sayi", v = 10, min = -100000, max = 100000 } },
     ozet = function(e) return (e.miktar >= 0 and "+" or "") .. e.miktar .. " G" end,
})

Kaydet("Eylem", "odul", {
     ad = "Recompensa ver (hemen)", kat = "oyuncu", ikon = "odul",
     alanlar = { { k = "oduller", ad = "Recompensas", tip = "oduller", v = {} } },
     ozet = function(e) return #(e.oduller or {}) .. " ödül" end,
})

-- Akış
Kaydet("Eylem", "bekle", {
     ad = "Bekle", kat = "akis", ikon = "saat",
     alanlar = { { k = "sure", ad = "Duración (s)", tip = "sayi", v = 1, min = 0, max = 600, ondalik = 1 } },
     ozet = function(e) return e.sure .. " sn" end,
})

Kaydet("Eylem", "git", {
     ad = "Ir al paso", kat = "akis", ikon = "git",
     alanlar = { { k = "adim", ad = "Paso", tip = "adim", v = "" } },
     ozet = function(e) return "→ " .. Y(e.adim) end,
})

Kaydet("Eylem", "dallan", {
     ad = "Correrula göre dallan", kat = "akis", ikon = "dallan",
     alanlar = {
          { k = "kosullar", ad = "Correrullar (hepsi)", tip = "kosullar", v = {} },
          { k = "git", ad = "Sağlanırsa paso", tip = "adim", v = "" },
          { k = "degilse", ad = "Sağlanmazsa paso", tip = "adim", v = "" },
     },
     ozet = function(e) return #(e.kosullar or {}) .. " koşul ? " .. Y(e.git) .. " : " .. ((e.degilse or "") ~= "" and e.degilse or "devam") end,
})

Kaydet("Eylem", "rastgele", {
     ad = "Rastgele dal", kat = "akis", ikon = "zar",
     alanlar = {
          { k = "secenekler", ad = "Dallar", tip = "liste", v = {}, alanlar = {
               { k = "adim", ad = "Paso", tip = "adim", v = "" },
               { k = "agirlik", ad = "Ağırlık", tip = "sayi", v = 1, min = 0, max = 100, ondalik = 1 },
          }, ozet = function(s) return Y(s.adim) .. " · " .. (s.agirlik or 1) end },
     },
     ozet = function(e) return #(e.secenekler or {}) .. " dal" end,
})

Kaydet("Eylem", "degisken", {
     ad = "Variable ayarla", kat = "akis", ikon = "degisken",
     alanlar = {
          { k = "ad", ad = "Variable", tip = "metin", v = "" },
          { k = "islem", ad = "İşlem", tip = "secim", v = "=", secenekler = { { id = "=", ad = "=" }, { id = "+", ad = "+" }, { id = "-", ad = "−" } } },
          { k = "deger", ad = "Valor", tip = "metin", v = "" },
     },
     ozet = function(e) return Y(e.ad) .. " " .. e.islem .. " " .. tostring(e.deger) end,
})

Kaydet("Eylem", "bitir", {
     ad = "Misióni bitir", kat = "akis", ikon = "bayrak",
     alanlar = {
          { k = "sonuc", ad = "Resultado", tip = "secim", v = "basari", secenekler = { { id = "basari", ad = "Éxito" }, { id = "basarisiz", ad = "Fallida" } } },
          { k = "mesaj", ad = "Mesaj", tip = "metin", v = "" },
     },
     ozet = function(e) return e.sonuc == "basari" and "başarılı" or "başarısız" end,
})

Kaydet("Eylem", "gorev_baslat", {
     ad = "Iniciar otra misión", kat = "akis", ikon = "gorev",
     alanlar = { { k = "gorev", ad = "Misión", tip = "gorev", v = "" } },
     ozet = function(e) return Y(e.gorev) end,
})

Kaydet("Eylem", "olay", {
     ad = "Olay yayınla (geliştirici)", kat = "akis", ikon = "olay",
     aciklama = "hook.Run(\"SardonGorevOlay\", oyuncu, ad, gorevId) — başka sistemleri tetiklemek için.",
     alanlar = { { k = "ad", ad = "Nombre del evento", tip = "metin", v = "" } },
     ozet = function(e) return Y(e.ad) end,
})

Kaydet("Eylem", "isaret", {
     ad = "Haritaya işaret koy / kaldır", kat = "akis", ikon = "isaret",
     alanlar = {
          { k = "yer", ad = "Yer", tip = "yer", v = "" },
          { k = "metin", ad = "Metin", tip = "metin", v = "" },
          { k = "acik", ad = "Koy (cerradoysa kaldır)", tip = "bool", v = true },
     },
     ozet = function(e) return (e.acik and "+ " or "− ") .. Y(e.yer) end,
})

-- Dünya
Kaydet("Eylem", "varlik", {
     ad = "Varlık / yaratık oluştur", kat = "dunya", ikon = "varlik",
     aciklama = "Sunucuda gerçek varlık (dövüşülebilir). Misión bitince kaldırılır. Tipo de animal doluysa Sardon Hayvan oluşturulur.",
     alanlar = {
          { k = "sinif", ad = "Clase", tip = "sinif", v = "" },
          { k = "hayvan", ad = "Tipo de animal (sardon_hayvan)", tip = "metin", v = "" },
          { k = "model", ad = "Modelo (opcional)", tip = "model", v = "" },
          { k = "yer", ad = "Yer", tip = "yer", v = "" },
          { k = "adet", ad = "Adet", tip = "sayi", v = 1, min = 1, max = 12 },
          { k = "yaricap", ad = "Radio de dispersión", tip = "sayi", v = 120, min = 0, max = 2000 },
          { k = "etiket", ad = "Etiket", tip = "metin", v = "", ipucu = "Öldür objetivoi bu etiketle sayar" },
          { k = "tekil", ad = "Yakında varsa koyma", tip = "bool", v = false, ipucu = "Ör. Seçmen Şapka: zaten oradaysa ikincisini koymaz" },
          { k = "kalici", ad = "Misión bitince kalsın", tip = "bool", v = false },
     },
     ozet = function(e) return (e.adet or 1) .. " × " .. ((e.hayvan or "") ~= "" and e.hayvan or Y(e.sinif)) .. " @ " .. Y(e.yer) end,
})

Kaydet("Eylem", "nesne", {
     ad = "Toplanacak nesne koy", kat = "dunya", ikon = "nesne",
     aciklama = "Solo el dueño de la misiónnin gördüğü, parıldayan nesneler. 'Topla' objetivoi sayar.",
     alanlar = {
          { k = "yerler", ad = "Yerler", tip = "liste", v = {}, alanlar = { { k = "yer", ad = "Yer", tip = "yer", v = "" } }, ozet = function(s) return Y(s.yer) end },
          { k = "model", ad = "Model", tip = "model", v = "models/props_lab/jar01a.mdl" },
          { k = "ad", ad = "Ad", tip = "metin", v = "Nesne" },
          { k = "etiket", ad = "Etiket", tip = "metin", v = "nesne" },
          { k = "parilti", ad = "Brillo", tip = "bool", v = true },
     },
     ozet = function(e) return #(e.yerler or {}) .. " × " .. Y(e.ad) end,
})

/* ======================================================================================
*   HEDEFLER
* ====================================================================================== */
local function H(alanlar)
     table.insert(alanlar, 1, { k = "metin", ad = "Görünen metin", tip = "metin", v = "", ipucu = "Boş: otomatik" })
     alanlar[#alanlar + 1] = { k = "isaret", ad = "Haritada işaretle", tip = "bool", v = true }
     alanlar[#alanlar + 1] = { k = "istege", ad = "Opcional", tip = "bool", v = false }
     alanlar[#alanlar + 1] = { k = "gizli", ad = "Gizli", tip = "bool", v = false }
     return alanlar
end

Kaydet("Hedef", "git", {
     ad = "Bir yere git", ikon = "isaret",
     alanlar = H({ { k = "yer", ad = "Yer", tip = "yer", v = "" }, { k = "yaricap", ad = "Radio", tip = "sayi", v = 160, min = 20, max = 5000 } }),
     ozet = function(e) return "Git: " .. Y(e.yer) end,
})

Kaydet("Hedef", "konus", {
     ad = "Hablar con actor", ikon = "konus",
     alanlar = H({ { k = "aktor", ad = "Actor", tip = "aktor", v = "" } }),
     ozet = function(e) return "Konuş: " .. Y(e.aktor) end,
})

Kaydet("Hedef", "takip", {
     ad = "Al actor takip et", ikon = "yuru",
     aciklama = "Actor 'Hacer caminar al actor' ile objetivoine varınca ve jugador yanındaysa tamamlanır.",
     alanlar = H({ { k = "aktor", ad = "Actor", tip = "aktor", v = "" }, { k = "yakin", ad = "Varışta yakınlık", tip = "sayi", v = 420, min = 100, max = 2000 } }),
     ozet = function(e) return "Takip: " .. Y(e.aktor) end,
})

Kaydet("Hedef", "bolgede_kal", {
     ad = "Bölgede kal", ikon = "saat",
     alanlar = H({ { k = "yer", ad = "Yer", tip = "yer", v = "" }, { k = "yaricap", ad = "Radio", tip = "sayi", v = 300, min = 20, max = 5000 }, { k = "sure", ad = "Duración (s)", tip = "sayi", v = 30, min = 1, max = 3600 } }),
     ozet = function(e) return Y(e.yer) .. " · " .. e.sure .. " sn" end,
})

Kaydet("Hedef", "uzaklas", {
     ad = "Alejarse de la zona", ikon = "yuru",
     alanlar = H({ { k = "yer", ad = "Yer", tip = "yer", v = "" }, { k = "yaricap", ad = "Radio", tip = "sayi", v = 1500, min = 50, max = 20000 } }),
     ozet = function(e) return "Uzaklaş: " .. Y(e.yer) end,
})

Kaydet("Hedef", "esya_edin", {
     ad = "Eşyaya sahip ol", ikon = "esya",
     alanlar = H({ { k = "esya", ad = "Eşya", tip = "esya", v = "" }, { k = "adet", ad = "Adet", tip = "sayi", v = 1, min = 1, max = 100 } }),
     ozet = function(e) return (e.adet or 1) .. " × " .. Y(e.esya) end,
})

Kaydet("Hedef", "esya_teslim", {
     ad = "Eşyayı teslim et", ikon = "esya",
     aciklama = "Jugador actorle al hablar eşya envanterinden alınır.",
     alanlar = H({ { k = "aktor", ad = "Actor", tip = "aktor", v = "" }, { k = "esya", ad = "Eşya", tip = "esya", v = "" }, { k = "adet", ad = "Adet", tip = "sayi", v = 1, min = 1, max = 100 } }),
     ozet = function(e) return (e.adet or 1) .. " × " .. Y(e.esya) .. " → " .. Y(e.aktor) end,
})

Kaydet("Hedef", "satin_al", {
     ad = "Satın al", ikon = "para",
     alanlar = H({
          { k = "magaza", ad = "Mağaza", tip = "secim", v = "", secenekler = MAGAZA },
          { k = "urun", ad = "Ürün adı (boş = herhangi)", tip = "metin", v = "" },
          { k = "adet", ad = "Adet", tip = "sayi", v = 1, min = 1, max = 50 },
          { k = "yer", ad = "Lugar (isteğe bağlı)", tip = "yer", v = "" },
          { k = "yaricap", ad = "Radio", tip = "sayi", v = 600, min = 50, max = 5000 },
     }),
     ozet = function(e) return "Satın al: " .. ((e.urun or "") ~= "" and e.urun or "herhangi") end,
})

Kaydet("Hedef", "para_harca", {
     ad = "Para harca", ikon = "para",
     alanlar = H({ { k = "miktar", ad = "Miktar", tip = "sayi", v = 10, min = 1, max = 100000 }, { k = "yer", ad = "Lugar (isteğe bağlı)", tip = "yer", v = "" }, { k = "yaricap", ad = "Radio", tip = "sayi", v = 600, min = 50, max = 5000 } }),
     ozet = function(e) return e.miktar .. " G harca" end,
})

Kaydet("Hedef", "kullan", {
     ad = "Bir varlığı kullan (E)", ikon = "el",
     alanlar = H({ { k = "sinif", ad = "Clase", tip = "sinif", v = "" }, { k = "yer", ad = "Lugar (isteğe bağlı)", tip = "yer", v = "" }, { k = "yaricap", ad = "Radio", tip = "sayi", v = 300, min = 20, max = 5000 } }),
     ozet = function(e) return "Kullan: " .. Y(e.sinif) end,
})

Kaydet("Hedef", "hane", {
     ad = "Haneye seçil (Seçmen Şapka)", ikon = "sapka",
     alanlar = H({ { k = "yer", ad = "Şapkanın yeri (işaret için)", tip = "yer", v = "" } }),
     ozet = function() return "Haneye seçil" end,
})

Kaydet("Hedef", "buyu_at", {
     ad = "Büyü at", ikon = "asa",
     alanlar = H({ { k = "buyu", ad = "Hechizo (vacío = cualquiera)", tip = "buyu", v = "" }, { k = "adet", ad = "Adet", tip = "sayi", v = 1, min = 1, max = 100 }, { k = "yer", ad = "Lugar (isteğe bağlı)", tip = "yer", v = "" }, { k = "yaricap", ad = "Radio", tip = "sayi", v = 600, min = 50, max = 5000 } }),
     ozet = function(e) return "Büyü: " .. ((e.buyu or "") ~= "" and e.buyu or "herhangi") .. " ×" .. (e.adet or 1) end,
})

Kaydet("Hedef", "oldur", {
     ad = "Yen / öldür", ikon = "kilic",
     alanlar = H({
          { k = "tur", ad = "Hedef", tip = "secim", v = "etiket", secenekler = { { id = "etiket", ad = "Creado por la misión (etiqueta)" }, { id = "sinif", ad = "Clase" }, { id = "hayvan", ad = "Tipo de animal" } } },
          { k = "deger", ad = "Etiket / sınıf / tür", tip = "metin", v = "" },
          { k = "adet", ad = "Adet", tip = "sayi", v = 1, min = 1, max = 100 },
     }),
     ozet = function(e) return "Yen: " .. Y(e.deger) .. " ×" .. (e.adet or 1) end,
})

Kaydet("Hedef", "topla", {
     ad = "Nesneleri topla", ikon = "nesne",
     alanlar = H({ { k = "etiket", ad = "Etiket", tip = "metin", v = "nesne" }, { k = "adet", ad = "Adet (0 = hepsi)", tip = "sayi", v = 0, min = 0, max = 100 } }),
     ozet = function(e) return "Topla: " .. Y(e.etiket) end,
})

Kaydet("Hedef", "etkilesim", {
     ad = "Bir yeri incele (E basılı tut)", ikon = "el",
     alanlar = H({ { k = "yer", ad = "Yer", tip = "yer", v = "" }, { k = "yaricap", ad = "Radio", tip = "sayi", v = 70, min = 20, max = 400 }, { k = "sure", ad = "Duración (s)", tip = "sayi", v = 2.5, min = 0.5, max = 30, ondalik = 1 }, { k = "eylem", ad = "Nombre de acción", tip = "metin", v = "Examinar" } }),
     ozet = function(e) return (e.eylem or "Examinar") .. ": " .. Y(e.yer) end,
})

Kaydet("Hedef", "sohbet", {
     ad = "Sohbete yaz", ikon = "konus",
     alanlar = H({ { k = "kelimeler", ad = "Kelimeler (virgülle, biri yeter)", tip = "metin", v = "" }, { k = "yer", ad = "Lugar (isteğe bağlı)", tip = "yer", v = "" }, { k = "yaricap", ad = "Radio", tip = "sayi", v = 400, min = 50, max = 5000 } }),
     ozet = function(e) return "Söyle: " .. Y(e.kelimeler) end,
})

Kaydet("Hedef", "olay", {
     ad = "Olay bekle (geliştirici)", ikon = "olay",
     aciklama = "SardonGorev.Tetikle(jugador, ad) ya da hook.Run(\"SardonGorevTetikle\", jugador, ad) çağrılınca sayar.",
     alanlar = H({ { k = "ad", ad = "Nombre del evento", tip = "metin", v = "" }, { k = "adet", ad = "Adet", tip = "sayi", v = 1, min = 1, max = 100 } }),
     ozet = function(e) return "Olay: " .. Y(e.ad) end,
})

Kaydet("Hedef", "kosul", {
     ad = "Correrul sağlansın", ikon = "dallan",
     alanlar = H({ { k = "kosullar", ad = "Correrullar (hepsi)", tip = "kosullar", v = {} } }),
     ozet = function(e) return #(e.kosullar or {}) .. " koşul" end,
})

Kaydet("Hedef", "sure", {
     ad = "Süre geçsin", ikon = "saat",
     alanlar = H({ { k = "sure", ad = "Duración (s)", tip = "sayi", v = 30, min = 1, max = 7200 } }),
     ozet = function(e) return e.sure .. " sn" end,
})

/* ======================================================================================
*   KOŞULLAR
* ====================================================================================== */
local function K(alanlar)
     alanlar[#alanlar + 1] = { k = "tersi", ad = "Tersi (değilse)", tip = "bool", v = false }
     return alanlar
end

Kaydet("Kosul", "seviye", { ad = "Seviye", alanlar = K({ { k = "min", ad = "En az", tip = "sayi", v = 1, min = 0, max = 1000 }, { k = "max", ad = "En çok (0 = sınırsız)", tip = "sayi", v = 0, min = 0, max = 1000 } }),
     ozet = function(e) return "seviye " .. e.min .. ((e.max or 0) > 0 and ("–" .. e.max) or "+") end })
Kaydet("Kosul", "hane", { ad = "Hane", alanlar = K({ { k = "deger", ad = "Hane", tip = "secim", v = "yok", secenekler = {
     { id = "yok", ad = "Aún no elegido" }, { id = "var", ad = "Elegido (cualquiera)" }, { id = "1", ad = "Gryffindor" }, { id = "2", ad = "Ravenclaw" }, { id = "3", ad = "Slytherin" }, { id = "4", ad = "Hufflepuff" } } } }),
     ozet = function(e) return "hane: " .. e.deger end })
Kaydet("Kosul", "faction", { ad = "Faction", alanlar = K({ { k = "deger", ad = "uniqueID (virgülle)", tip = "metin", v = "" } }), ozet = function(e) return "faction: " .. Y(e.deger) end })
Kaydet("Kosul", "sinif", { ad = "Clase (class)", alanlar = K({ { k = "deger", ad = "uniqueID (virgülle)", tip = "metin", v = "" } }), ozet = function(e) return "sınıf: " .. Y(e.deger) end })
Kaydet("Kosul", "gorev_bitti", { ad = "Misión completada", alanlar = K({ { k = "gorev", ad = "Misión", tip = "gorev", v = "" }, { k = "adet", ad = "En az kez", tip = "sayi", v = 1, min = 1, max = 1000 } }), ozet = function(e) return "bitti: " .. Y(e.gorev) end })
Kaydet("Kosul", "gorev_aktif", { ad = "Misión sürüyor", alanlar = K({ { k = "gorev", ad = "Misión", tip = "gorev", v = "" } }), ozet = function(e) return "sürüyor: " .. Y(e.gorev) end })
Kaydet("Kosul", "degisken", { ad = "Misión değişkeni", alanlar = K({ { k = "ad", ad = "Variable", tip = "metin", v = "" }, { k = "islem", ad = "Karşılaştırma", tip = "secim", v = "==", secenekler = {
     { id = "==", ad = "=" }, { id = "~=", ad = "≠" }, { id = ">", ad = ">" }, { id = "<", ad = "<" }, { id = ">=", ad = "≥" }, { id = "<=", ad = "≤" } } }, { k = "deger", ad = "Valor", tip = "metin", v = "" } }),
     ozet = function(e) return Y(e.ad) .. " " .. e.islem .. " " .. tostring(e.deger) end })
Kaydet("Kosul", "saat", { ad = "Oyun saati", aciklama = "StormFox saati; yoksa sunucu saati. Gece için bas 21, son 5.", alanlar = K({ { k = "bas", ad = "Inicio (saat)", tip = "sayi", v = 20, min = 0, max = 24, ondalik = 1 }, { k = "son", ad = "Bitiş (saat)", tip = "sayi", v = 5, min = 0, max = 24, ondalik = 1 } }),
     ozet = function(e) return "saat " .. e.bas .. "–" .. e.son end })
Kaydet("Kosul", "gercek_saat", { ad = "Hora real (TR)", alanlar = K({ { k = "bas", ad = "Inicio", tip = "sayi", v = 18, min = 0, max = 24, ondalik = 1 }, { k = "son", ad = "Bitiş", tip = "sayi", v = 23, min = 0, max = 24, ondalik = 1 } }),
     ozet = function(e) return "gerçek saat " .. e.bas .. "–" .. e.son end })
Kaydet("Kosul", "gun", { ad = "Día de la semana", alanlar = K({ { k = "gunler", ad = "Günler (1=Pzt … 7=Paz, virgülle)", tip = "metin", v = "6,7" } }), ozet = function(e) return "gün " .. Y(e.gunler) end })
Kaydet("Kosul", "hava", { ad = "Hava", alanlar = K({ { k = "deger", ad = "Hava", tip = "secim", v = "yagmur", secenekler = {
     { id = "acik", ad = "Açık" }, { id = "yagmur", ad = "Yağmur" }, { id = "kar", ad = "Kar" }, { id = "firtina", ad = "Fırtına" }, { id = "sis", ad = "Sis" }, { id = "bulut", ad = "Bulutlu" } } } }),
     ozet = function(e) return "hava: " .. e.deger end })
Kaydet("Kosul", "esya", { ad = "Eşya var", alanlar = K({ { k = "esya", ad = "Eşya", tip = "esya", v = "" }, { k = "adet", ad = "En az", tip = "sayi", v = 1, min = 1, max = 100 } }), ozet = function(e) return "eşya: " .. Y(e.esya) end })
Kaydet("Kosul", "para", { ad = "Para", alanlar = K({ { k = "min", ad = "En az", tip = "sayi", v = 1, min = 0, max = 1000000 } }), ozet = function(e) return "para ≥ " .. e.min end })
Kaydet("Kosul", "onur", { ad = "Onur", alanlar = K({ { k = "min", ad = "En az", tip = "sayi", v = -1000, min = -1000, max = 1000 }, { k = "max", ad = "En çok", tip = "sayi", v = 1000, min = -1000, max = 1000 } }), ozet = function(e) return "onur " .. e.min .. "…" .. e.max end })
Kaydet("Kosul", "sans", { ad = "Suerte del día", alanlar = K({ { k = "min", ad = "En az kademe (1=D … 15=SS+)", tip = "sayi", v = 7, min = 1, max = 15 } }), ozet = function(e) return "şans ≥ " .. e.min end })
Kaydet("Kosul", "jugador_sayisi", { ad = "Sunucudaki jugador", alanlar = K({ { k = "min", ad = "En az", tip = "sayi", v = 2, min = 1, max = 128 } }), ozet = function(e) return "jugador ≥ " .. e.min end })
Kaydet("Kosul", "rastgele", { ad = "Olasılık", alanlar = K({ { k = "oran", ad = "Oran (0–1)", tip = "sayi", v = 0.5, min = 0, max = 1, ondalik = 2 } }), ozet = function(e) return "%" .. math.Round(e.oran * 100) end })
Kaydet("Kosul", "yakin", { ad = "Jugador bir yere yakın", alanlar = K({ { k = "yer", ad = "Yer", tip = "yer", v = "" }, { k = "yaricap", ad = "Radio", tip = "sayi", v = 500, min = 20, max = 20000 } }), ozet = function(e) return "yakın: " .. Y(e.yer) end })
Kaydet("Kosul", "discord", { ad = "Discord conectado", alanlar = K({}), ozet = function() return "Discord bağlı" end })
Kaydet("Kosul", "yetkili", { ad = "Yetkili (test)", alanlar = K({}), ozet = function() return "yetkili" end })

/* ======================================================================================
*   ÖDÜLLER
* ====================================================================================== */
Kaydet("Odul", "para", { ad = "Para", alanlar = { { k = "miktar", ad = "Galleon", tip = "sayi", v = 25, min = 1, max = 1000000 } }, ozet = function(e) return e.miktar .. " Galleon" end })
Kaydet("Odul", "xp", { ad = "Deneyim", alanlar = { { k = "miktar", ad = "XP", tip = "sayi", v = 50, min = 1, max = 1000000 } }, ozet = function(e) return e.miktar .. " XP" end })
Kaydet("Odul", "esya", { ad = "Eşya", alanlar = { { k = "esya", ad = "Eşya", tip = "esya", v = "" }, { k = "adet", ad = "Adet", tip = "sayi", v = 1, min = 1, max = 50 }, { k = "veri", ad = "Veri (JSON)", tip = "metin", v = "" } }, ozet = function(e) return (e.adet or 1) .. " × " .. Y(e.esya) end })
Kaydet("Odul", "buyu", { ad = "Hechizo / varita", alanlar = { { k = "buyu", ad = "Büyü", tip = "buyu", v = "" }, { k = "tur", ad = "Modo", tip = "secim", v = "ogren", secenekler = { { id = "ogren", ad = "Aprendible (pergamino)" }, { id = "tam", ad = "Enseñar directo (varita)" } } } }, ozet = function(e) return Y(e.buyu) end })
Kaydet("Odul", "onur", { ad = "Onur", alanlar = { { k = "miktar", ad = "Miktar", tip = "sayi", v = 5, min = -1000, max = 1000 } }, ozet = function(e) return (e.miktar >= 0 and "+" or "") .. e.miktar .. " onur" end })
Kaydet("Odul", "gelisim", { ad = "Puntos de desarrollo", alanlar = { { k = "miktar", ad = "Puan", tip = "sayi", v = 1, min = 1, max = 50 } }, ozet = function(e) return e.miktar .. " gelişim puanı" end })
Kaydet("Odul", "sans", { ad = "Şans etkeni", alanlar = { { k = "adim", ad = "Kademe", tip = "sayi", v = 1, min = -5, max = 5 }, { k = "sure", ad = "Süre (dk, 0 = día sonu)", tip = "sayi", v = 60, min = 0, max = 1440 } }, ozet = function(e) return "şans " .. (e.adim >= 0 and "+" or "") .. e.adim end })

/* ======================================================================================
*   REPLİKLER (actorün kendiliğinden söyledikleri) ve AKTÖR TANIMI
* ====================================================================================== */
G.ReplikTetik = {
     { id = "aralik", ad = "Aralıkla (objetivo bitene dek)" },
     { id = "giris", ad = "Objetivoler başlayınca bir kez" },
     { id = "uzak", ad = "Jugador uzaklaşınca" },
     { id = "yakin", ad = "Jugador yaklaşınca" },
     { id = "bosta", ad = "Jugador oyalanınca" },
     { id = "satin", ad = "Jugador bir şey alınca" },
     { id = "ilerleme", ad = "Bir hedef ilerleyince" },
}

G.ReplikAlanlari = {
     { k = "aktor", ad = "Actor", tip = "aktor", v = "" },
     { k = "tetik", ad = "Ne zaman", tip = "secim", v = "aralik", secenekler = G.ReplikTetik },
     { k = "aralik", ad = "Aralık / bekleme (sn)", tip = "sayi", v = 12, min = 1, max = 600, ondalik = 1 },
     { k = "ilk", ad = "İlk gecikme (sn)", tip = "sayi", v = 0, min = 0, max = 600, ondalik = 1 },
     { k = "menzil", ad = "Menzil", tip = "sayi", v = 1400, min = 50, max = 6000 },
     { k = "sira", ad = "Sıra", tip = "secim", v = "sirali", secenekler = { { id = "sirali", ad = "Sırayla" }, { id = "rastgele", ad = "Rastgele" } } },
     { k = "tekrar", ad = "Líneas bitince başa dön", tip = "bool", v = true },
     { k = "bak", ad = "Söylerken jugadorya bak", tip = "bool", v = true },
     { k = "satirlar", ad = "Líneas", tip = "liste", v = {}, alanlar = {
          { k = "metin", ad = "Réplica", tip = "yazi", v = "" },
          { k = "ses", ad = "Archivo de sonido", tip = "ses", v = "" },
          { k = "anim", ad = "Hareket", tip = "anim", v = "" },
     }, ozet = function(s) return M(s.metin, 50) .. ((s.ses or "") ~= "" and "  ♪" or "") end },
}

function G.ReplikOzet(r)
     local t = "?"
     for _, v in ipairs(G.ReplikTetik) do if v.id == r.tetik then t = v.ad end end
     return Y(r.aktor) .. " · " .. t .. " · " .. #(r.satirlar or {}) .. " satır"
end

G.AktorAlanlari = {
     { k = "id", ad = "Kimlik", tip = "metin", v = "" },
     { k = "ad", ad = "Görünen ad", tip = "metin", v = "" },
     { k = "unvan", ad = "Unvan", tip = "metin", v = "" },
     { k = "model", ad = "Model", tip = "model", v = "models/player/group01/female_01.mdl" },
     { k = "skin", ad = "Skin", tip = "sayi", v = 0, min = 0, max = 32 },
     { k = "bg", ad = "Bodygroup (no=değer, virgülle)", tip = "metin", v = "" },
     { k = "boy", ad = "Boy ölçeği", tip = "sayi", v = 1, min = 0.5, max = 1.6, ondalik = 2 },
     { k = "gorunurluk", ad = "Quién lo ve", tip = "secim", v = "cevre", secenekler = { { id = "cevre", ad = "Todos cercanos" }, { id = "kisisel", ad = "Solo el dueño de la misión" } } },
     { k = "isimRenk", ad = "İsim rengi", tip = "renk", v = { 232, 219, 182 } },
     { k = "bekleAnim", ad = "Bekleme animasyonu", tip = "anim", v = "" },
     { k = "yuruAnim", ad = "Caminarme animasyonu", tip = "anim", v = "" },
     { k = "kosAnim", ad = "Correrma animasyonu", tip = "anim", v = "" },
     { k = "hare", ad = "Aura de recuerdo", tip = "secim", v = "", secenekler = G.HareListe },
     { k = "isimGoster", ad = "Baş üstünde ad", tip = "bool", v = true },
}

-- Karşılaşma (rastgele) ayarları
G.KarsilasmaAlanlari = {
     { k = "yerler", ad = "Çıkabileceği yerler", tip = "liste", v = {}, alanlar = { { k = "yer", ad = "Yer", tip = "yer", v = "" } }, ozet = function(s) return Y(s.yer) end },
     { k = "tetik", ad = "Jugador bu kadar yakınken", tip = "sayi", v = 1800, min = 200, max = 8000 },
     { k = "enYakin", ad = "…ama en az bu kadar uzakken", tip = "sayi", v = 500, min = 0, max = 4000, ipucu = "Jugadornun gözü önünde belirmesin" },
     { k = "ilgi", ad = "Karşılaşma başlama mesafesi", tip = "sayi", v = 450, min = 50, max = 3000 },
     { k = "kacirma", ad = "Bu kadar uzaklaşırsa kaybolur", tip = "sayi", v = 2800, min = 500, max = 10000 },
     { k = "sans", ad = "Her yoklamada olasılık", tip = "sayi", v = 0.15, min = 0.01, max = 1, ondalik = 2 },
     { k = "jugadorBekleme", ad = "Jugador başı bekleme (sn)", tip = "sayi", v = 3600, min = 0, max = 604800 },
     { k = "genelBekleme", ad = "Genel bekleme (sn)", tip = "sayi", v = 300, min = 0, max = 86400 },
     { k = "esZamanli", ad = "Aynı anda en çok", tip = "sayi", v = 1, min = 1, max = 16 },
}

-- Pasoın "actorle al hablar" tetikleri (dükkâncılar, sohbet edilebilir figürler)
G.KonusuncaAlanlari = {
     { k = "aktor", ad = "Actor (misión ya da dünya actorü kimliği)", tip = "aktor", v = "" },
     { k = "tekrar", ad = "En cada conversación", tip = "bool", v = false },
     { k = "eylemler", ad = "Eylemler", tip = "liste", v = {}, semaTur = "Eylem", kategoriler = G.EylemKategori },
}

function G.KonusuncaOzet(k)
     return (k.aktor ~= "" and k.aktor or "?") .. " ile al hablar · " .. #(k.eylemler or {}) .. " eylem" .. (k.tekrar and " · her seferinde" or "")
end
