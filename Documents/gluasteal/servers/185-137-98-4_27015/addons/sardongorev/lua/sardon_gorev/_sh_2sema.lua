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
     { id = "", ad = "Ninguno" },
     { id = "ani", ad = "Recuerdo (plateado, suave)" },
     { id = "hayalet", ad = "Fantasma (semi transparente)" },
     { id = "nur", ad = "Resplandor (blanco intenso)" },
     { id = "silik", ad = "Recuerdo borrado (disperso)" },
     { id = "ince", ad = "Aura tenue" },
}

G.EfektListe = {
     { id = "", ad = "Ninguno" },
     { id = "isik", ad = "Destello de luz" },
     { id = "duman", ad = "Humo" },
     { id = "cinlama", ad = "Aparición (sonido de genio)" },
}

G.ParcacikListe = {
     { id = "isik_toz", ad = "Polvo de luz (interno)" },
     { id = "kivilcim", ad = "Chispa dorada (interno)" },
     { id = "buhar", ad = "Vapor plateado (interno)" },
     { id = "[0]_wispambient", ad = "Luces del alma (z_theme)" },
     { id = "[0]_fog_ambient", ad = "Niebla (z_theme)" },
     { id = "[0]_starsky", ad = "Cielo estrellado (z_theme)" },
     { id = "[0]_sakura_ground", ad = "Pétalos de sakura (z_theme)" },
     { id = "[0]_thunder_weather", ad = "Tormenta (z_theme)" },
     { id = "[0]_blood_fog", ad = "Niebla de sangre (z_theme)" },
     { id = "[0]_tornado", ad = "Tornado (z_theme)" },
}

local YUMUSATMA = {
     { id = "yumusak", ad = "Suave" }, { id = "dogrusal", ad = "Lineal" },
     { id = "yavasBasla", ad = "Desacelerar al inicio" }, { id = "yavasBitir", ad = "Desacelerar al final" },
}

local MAGAZA = {
     { id = "", ad = "Cualquiera" }, { id = "shopic", ad = "Tiendas Sardon" }, { id = "hogshop", ad = "Hogwarts Shop (varita/hechizo)" },
     { id = "vendor", ad = "Vendedor Helix" }, { id = "gorev", ad = "Desde diálogo de misión" },
     { id = "aksesuar", ad = "Madam Malkin (accesorio)" },
}

local KAMERA_HEDEF = {
     { id = "", ad = "Ninguno (ángulo del lugar)" }, { id = "oyuncu", ad = "Jugador" }, { id = "aktor", ad = "Actor" }, { id = "yer", ad = "Lugar" },
}

/* ======================================================================================
*   EYLEMLER
* ====================================================================================== */
G.EylemKategori = {
     { id = "konusma", ad = "Diálogo" }, { id = "aktor", ad = "Actor" }, { id = "sahne", ad = "Escena" },
     { id = "oyuncu", ad = "Jugador" }, { id = "akis", ad = "Flujo" }, { id = "dunya", ad = "Mundo" },
}

local SATIR_ALANLARI = {
     { k = "kim", ad = "Quien habla", tip = "konusan", v = "", ipucu = "Vacío: actor del diálogo" },
     { k = "metin", ad = "Réplica", tip = "yazi", v = "" },
     { k = "ses", ad = "Archivo de sonido", tip = "ses", v = "" },
     { k = "anim", ad = "Movimiento", tip = "anim", v = "" },
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
          { k = "anim", ad = "Movimiento", tip = "anim", v = "", ipucu = "Ej. gesture_wave (saludo)" },
          { k = "bak", ad = "Mirar al jugador", tip = "bool", v = true },
          { k = "bekle", ad = "Esperar hasta terminar", tip = "bool", v = true },
          { k = "kanal", ad = "Presentación", tip = "secim", v = "altyazi", secenekler = {
               { id = "altyazi", ad = "Subtítulos (dueño de la misión)" }, { id = "balon", ad = "Solo globo sobre la cabeza" } } },
     },
     ozet = function(e) return (e.aktor ~= "" and e.aktor or "Narrador") .. ": " .. M(e.metin) .. ((e.ses or "") ~= "" and "  ♪" or "") end,
})

Kaydet("Eylem", "diyalog", {
     ad = "Diálogo", kat = "konusma", ikon = "diyalog",
     aciklama = "Diálogo en secuencia y opciones. En modo cinemático el jugador se detiene y la cámara gira; en libre, subtítulos y teclas numéricas.",
     alanlar = {
          { k = "aktor", ad = "Actor", tip = "aktor", v = "" },
          { k = "kip", ad = "Modo", tip = "secim", v = "sinematik", secenekler = { { id = "sinematik", ad = "Cinemático" }, { id = "serbest", ad = "Libre (caminando)" } } },
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
               { k = "oduller", ad = "Recompensas a dar", tip = "oduller", v = {} },
               { k = "kosullar", ad = "Condición de visibilidad", tip = "kosullar", v = {} },
               { k = "satin", ad = "Contar como compra (nombre)", tip = "metin", v = "", ipucu = "Si está relleno, cuenta para el objetivo 'Comprar' con este nombre" },
               { k = "olay", ad = "Disparar evento (nombre)", tip = "metin", v = "", ipucu = "Si está relleno, hook.Run(\"SardonGorevOlay\", jugador, ad, gorevId). aksesuar_hediye: regalo Madam Malkin + tienda, aksesuar_magaza: tienda" },
          } },
          { k = "kamera", ad = "Cámara", tip = "secim", v = "otomatik", secenekler = { { id = "otomatik", ad = "Girar hacia quien habla" }, { id = "yok", ad = "Ninguno" } } },
     },
     ozet = function(e) return (e.kip == "serbest" and "Libre" or "Cinemático") .. " · " .. #(e.satirlar or {}) .. " líneas · " .. #(e.secenekler or {}) .. " opciones" end,
})

-- Actor
Kaydet("Eylem", "aktor_olustur", {
     ad = "Poner actor en escena", kat = "aktor", ikon = "aktor",
     alanlar = {
          { k = "aktor", ad = "Actor", tip = "aktor", v = "" },
          { k = "yer", ad = "Lugar", tip = "yer", v = "" },
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
     aciklama = "Con guía activa, si el jugador se queda atrás se detiene y espera; al acercarse continúa. Si el objetivo es una ruta, la sigue.",
     alanlar = {
          { k = "aktor", ad = "Actor", tip = "aktor", v = "" },
          { k = "hedef", ad = "Objetivo (punto o ruta)", tip = "yer", v = "" },
          { k = "rota", ad = "Ruta", tip = "secim", v = "otomatik", secenekler = {
               { id = "otomatik", ad = "Si es ruta, la ruta; si no, red Fieldguide" }, { id = "duz", ad = "Línea recta" } } },
          { k = "kip", ad = "Velocidad", tip = "secim", v = "yuru", secenekler = { { id = "yuru", ad = "Caminar" }, { id = "kos", ad = "Correr" } } },
          { k = "hiz", ad = "Velocidad personalizada (0 = según modo)", tip = "sayi", v = 0, min = 0, max = 400, ipucu = "Caminar ~78, correr ~215 unidades/s" },
          { k = "rehber", ad = "Guía (esperar al jugador)", tip = "bool", v = false },
          { k = "bag", ad = "Vínculo: franja de partículas + el jugador no puede correr (hasta que el actor pase a otra tarea)", tip = "bool", v = false },
          { k = "bekle", ad = "Esperar a llegar", tip = "bool", v = false },
          { k = "varinca", ad = "Al llegar", tip = "secim", v = "oyuncu", secenekler = { { id = "", ad = "Como está" }, { id = "oyuncu", ad = "Girar hacia el jugador" }, { id = "yer", ad = "Girar hacia la orientación del lugar" } } },
     },
     ozet = function(e) return Y(e.aktor) .. " → " .. Y(e.hedef) .. (e.rehber and "  (guía)" or "") end,
})

Kaydet("Eylem", "aktor_takip", {
     ad = "Actor sigue al jugador", kat = "aktor", ikon = "yuru",
     alanlar = {
          { k = "aktor", ad = "Actor", tip = "aktor", v = "" },
          { k = "acik", ad = "Activo", tip = "bool", v = true },
          { k = "mesafe", ad = "Distancia", tip = "sayi", v = 110, min = 50, max = 600 },
          { k = "bag", ad = "Vínculo: franja de partículas + el jugador no puede correr", tip = "bool", v = false },
     },
     ozet = function(e) return Y(e.aktor) .. (e.acik and (e.bag and " vinculado siguiendo" or " siguiendo") or " deja de seguir") end,
})

Kaydet("Eylem", "aktor_bak", {
     ad = "Actor mira", kat = "aktor", ikon = "goz",
     alanlar = {
          { k = "aktor", ad = "Actor", tip = "aktor", v = "" },
          { k = "hedef", ad = "Hacia qué", tip = "secim", v = "oyuncu", secenekler = { { id = "oyuncu", ad = "Jugador" }, { id = "aktor", ad = "Otro actor" }, { id = "yer", ad = "Lugar" }, { id = "", ad = "Nada" } } },
          { k = "hedefAktor", ad = "Actor objetivo", tip = "aktor", v = "", goster = function(e) return e.hedef == "aktor" end },
          { k = "yer", ad = "Lugar objetivo", tip = "yer", v = "", goster = function(e) return e.hedef == "yer" end },
     },
     ozet = function(e) return Y(e.aktor) .. " → " .. (e.hedef == "aktor" and Y(e.hedefAktor) or e.hedef == "yer" and Y(e.yer) or e.hedef == "oyuncu" and "jugador" or "—") end,
})

Kaydet("Eylem", "aktor_anim", {
     ad = "Animación del actor", kat = "aktor", ikon = "anim",
     alanlar = {
          { k = "aktor", ad = "Actor", tip = "aktor", v = "" },
          { k = "anim", ad = "Animación", tip = "anim", v = "" },
          { k = "dongu", ad = "Bucle (en lugar de espera)", tip = "bool", v = false },
          { k = "sure", ad = "Duración (0 = una vez)", tip = "sayi", v = 0, min = 0, max = 600, ondalik = 1 },
          { k = "bekle", ad = "Esperar hasta terminar", tip = "bool", v = false },
     },
     ozet = function(e) return Y(e.aktor) .. ": " .. Y(e.anim) .. (e.dongu and " (bucle)" or "") end,
})

Kaydet("Eylem", "aktor_hare", {
     ad = "Aura de recuerdo", kat = "aktor", ikon = "hare",
     aciklama = "Envuelve al actor con luz como un recuerdo (aura de recuerdo del cine).",
     alanlar = {
          { k = "aktor", ad = "Actor", tip = "aktor", v = "" },
          { k = "hare", ad = "Apariencia", tip = "secim", v = "ani", secenekler = G.HareListe },
          { k = "gecis", ad = "Transición (s)", tip = "sayi", v = 1.5, min = 0, max = 8, ondalik = 1 },
     },
     ozet = function(e) return Y(e.aktor) .. ": " .. (e.hare ~= "" and e.hare or "apagado") end,
})

Kaydet("Eylem", "aktor_isinla", {
     ad = "Teletransportar actor", kat = "aktor", ikon = "aktor",
     alanlar = {
          { k = "aktor", ad = "Actor", tip = "aktor", v = "" },
          { k = "yer", ad = "Lugar", tip = "yer", v = "" },
          { k = "efekt", ad = "Efecto", tip = "secim", v = "", secenekler = G.EfektListe },
     },
     ozet = function(e) return Y(e.aktor) .. " → " .. Y(e.yer) end,
})

Kaydet("Eylem", "aktor_ad", {
     ad = "Cambiar el nombre del actor", kat = "aktor", ikon = "aktor",
     aciklama = "Ej. 'Desconocido' hasta presentarse; luego el nombre real.",
     alanlar = {
          { k = "aktor", ad = "Actor", tip = "aktor", v = "" },
          { k = "ad", ad = "Nombre visible", tip = "metin", v = "" },
          { k = "unvan", ad = "Título", tip = "metin", v = "" },
     },
     ozet = function(e) return Y(e.aktor) .. " → " .. Y(e.ad) end,
})

-- Sahne
Kaydet("Eylem", "kamera", {
     ad = "Toma de cámara", kat = "sahne", ikon = "kamera",
     aciklama = "Fija: desde el lugar de cámara. Deslizar: lugar → lugar2. Órbita: alrededor del objetivo. Diálogo: plano al hombro entre actor y jugador.",
     alanlar = {
          { k = "tur", ad = "Tipo", tip = "secim", v = "sabit", secenekler = {
               { id = "sabit", ad = "Fija" }, { id = "kaydir", ad = "Deslizar (entre dos lugares)" }, { id = "yorunge", ad = "Órbita" }, { id = "konusma", ad = "Plano de diálogo" } } },
          { k = "yer", ad = "Lugar de cámara", tip = "yer", v = "" },
          { k = "yer2", ad = "Lugar final", tip = "yer", v = "", goster = function(e) return e.tur == "kaydir" end },
          { k = "hedef", ad = "Mirada hacia", tip = "secim", v = "", secenekler = KAMERA_HEDEF },
          { k = "hedefAktor", ad = "Actor mirado", tip = "aktor", v = "", goster = function(e) return e.hedef == "aktor" or e.tur == "konusma" or e.tur == "yorunge" end },
          { k = "hedefYer", ad = "Lugar mirado", tip = "yer", v = "", goster = function(e) return e.hedef == "yer" end },
          { k = "sure", ad = "Duración (s, 0 = hasta cerrar)", tip = "sayi", v = 4, min = 0, max = 120, ondalik = 1 },
          { k = "fov", ad = "Ángulo de visión", tip = "sayi", v = 60, min = 10, max = 110 },
          { k = "yumusatma", ad = "Suavizado", tip = "secim", v = "yumusak", secenekler = YUMUSATMA },
          { k = "serit", ad = "Bandas de cine", tip = "bool", v = true },
          { k = "kilit", ad = "Detener al jugador", tip = "bool", v = true },
          { k = "bekle", ad = "Esperar hasta terminar", tip = "bool", v = true },
     },
     ozet = function(e) return e.tur .. " · " .. Y(e.yer) .. " · " .. (e.sure or 0) .. " s" end,
})

Kaydet("Eylem", "kamera_bitir", {
     ad = "Devolver la cámara al jugador", kat = "sahne", ikon = "kamera",
     alanlar = { { k = "gecis", ad = "Transición (s)", tip = "sayi", v = 0.8, min = 0, max = 5, ondalik = 1 } },
})

Kaydet("Eylem", "sahne", {
     ad = "Reproducir escena de cine", kat = "sahne", ikon = "sinema",
     aciklama = "Una ruta del Cine (cámara + actores) se incrusta en la misión y se reproduce al dueño. En el editor: importar ruta de cine.",
     alanlar = {
          { k = "veri", ad = "Escena", tip = "sahne", v = {} },
          { k = "sure", ad = "Duración (0 = duración de la ruta)", tip = "sayi", v = 0, min = 0, max = 300, ondalik = 1 },
          { k = "hare", ad = "Aura de recuerdo a los actores", tip = "secim", v = "", secenekler = G.HareListe },
          { k = "efekt", ad = "Pantalla", tip = "secim", v = "", secenekler = {
               { id = "", ad = "Natural" }, { id = "ani", ad = "Recuerdo (tenue, borde brillante)" }, { id = "sepya", ad = "Sepya" }, { id = "siyahbeyaz", ad = "Blanco y negro" }, { id = "ruya", ad = "Sueño" } } },
          { k = "serit", ad = "Bandas de cine", tip = "bool", v = true },
          { k = "atlanabilir", ad = "Se puede saltar (tras verla una vez)", tip = "bool", v = true },
          { k = "bekle", ad = "Esperar hasta terminar", tip = "bool", v = true },
     },
     ozet = function(e) local v = e.veri or {} return (v.ad or "sahne") .. " · " .. #(v.anahtarlar or {}) .. " claves · " .. #(v.aktorler or {}) .. " actor" end,
})

Kaydet("Eylem", "karart", {
     ad = "Oscurecer / aclarar pantalla", kat = "sahne", ikon = "karart",
     alanlar = {
          { k = "yon", ad = "Dirección", tip = "secim", v = "kapan", secenekler = { { id = "kapan", ad = "Oscurecer" }, { id = "acil", ad = "Aclarar" } } },
          { k = "sure", ad = "Duración", tip = "sayi", v = 1, min = 0, max = 10, ondalik = 1 },
          { k = "renk", ad = "Color", tip = "secim", v = "siyah", secenekler = { { id = "siyah", ad = "Negro" }, { id = "beyaz", ad = "Blanco" } } },
          { k = "bekle", ad = "Esperar hasta terminar", tip = "bool", v = true },
     },
     ozet = function(e) return (e.yon == "kapan" and "Se oscurece" or "Se aclara") .. " · " .. e.sure .. " s" end,
})

Kaydet("Eylem", "baslik", {
     ad = "Cartel de título", kat = "sahne", ikon = "baslik",
     alanlar = {
          { k = "ust", ad = "Línea superior", tip = "metin", v = "" },
          { k = "baslik", ad = "Título", tip = "metin", v = "" },
          { k = "alt", ad = "Línea inferior", tip = "metin", v = "" },
          { k = "stil", ad = "Estilo", tip = "secim", v = "bolum", secenekler = { { id = "bolum", ad = "Capítulo (centro, grande)" }, { id = "yer", ad = "Nombre de lugar (abajo centro)" } } },
          { k = "sure", ad = "Duración", tip = "sayi", v = 5, min = 1, max = 20, ondalik = 1 },
          { k = "bekle", ad = "Esperar hasta terminar", tip = "bool", v = false },
     },
     ozet = function(e) return M(e.baslik) end,
})

Kaydet("Eylem", "efekt", {
     ad = "Efecto de pantalla", kat = "sahne", ikon = "efekt",
     alanlar = {
          { k = "tur", ad = "Efecto", tip = "secim", v = "ani", secenekler = {
               { id = "ani", ad = "Recuerdo (tenue, borde brillante)" }, { id = "sepya", ad = "Sepya" }, { id = "siyahbeyaz", ad = "Blanco y negro" },
               { id = "ruya", ad = "Sueño (bordes borrosos)" }, { id = "titreme", ad = "Temblor" }, { id = "flas", ad = "Destello blanco" }, { id = "", ad = "Cerrar" } } },
          { k = "sure", ad = "Duración (0 = hasta fin del paso)", tip = "sayi", v = 0, min = 0, max = 120, ondalik = 1 },
          { k = "guc", ad = "Intensidad", tip = "sayi", v = 1, min = 0, max = 2, ondalik = 2 },
     },
     ozet = function(e) return e.tur ~= "" and e.tur or "kapat" end,
})

Kaydet("Eylem", "muzik", {
     ad = "Música", kat = "sahne", ikon = "muzik",
     alanlar = {
          { k = "ses", ad = "Archivo de sonido", tip = "ses", v = "" },
          { k = "url", ad = "o dirección (http)", tip = "metin", v = "" },
          { k = "seviye", ad = "Volumen", tip = "sayi", v = 0.5, min = 0, max = 1, ondalik = 2 },
          { k = "dongu", ad = "Bucle", tip = "bool", v = true },
          { k = "gecis", ad = "Transición (s)", tip = "sayi", v = 2, min = 0, max = 10, ondalik = 1 },
     },
     ozet = function(e) return (e.ses ~= "" and e.ses) or (e.url ~= "" and "URL") or "?" end,
})

Kaydet("Eylem", "muzik_dur", {
     ad = "Detener música", kat = "sahne", ikon = "muzik",
     alanlar = { { k = "gecis", ad = "Transición (s)", tip = "sayi", v = 2, min = 0, max = 10, ondalik = 1 } },
})

Kaydet("Eylem", "ses_efekti", {
     ad = "Efecto de sonido", kat = "sahne", ikon = "muzik",
     aciklama = "Sonidos propios del juego (ruta bajo sound/, ej. ambient/levels/citadel/strange_talk1.wav) o archivo de sonido de misión.",
     alanlar = {
          { k = "kaynak", ad = "Origen", tip = "secim", v = "oyuncu", secenekler = { { id = "oyuncu", ad = "Jugador" }, { id = "aktor", ad = "Actor" }, { id = "yer", ad = "Lugar" } } },
          { k = "aktor", ad = "Actor", tip = "aktor", v = "", goster = function(e) return e.kaynak == "aktor" end },
          { k = "yer", ad = "Lugar", tip = "yer", v = "", goster = function(e) return e.kaynak == "yer" end },
          { k = "oyunSesi", ad = "Ruta de sonido del juego", tip = "metin", v = "" },
          { k = "ses", ad = "Archivo de sonido de misión", tip = "ses", v = "" },
          { k = "seviye", ad = "Volumen", tip = "sayi", v = 0.8, min = 0, max = 1, ondalik = 2 },
     },
     ozet = function(e) return (e.oyunSesi ~= "" and e.oyunSesi) or Y(e.ses) end,
})

Kaydet("Eylem", "parcacik", {
     ad = "Efecto de partículas", kat = "sahne", ikon = "efekt",
     alanlar = {
          { k = "kaynak", ad = "Lugar", tip = "secim", v = "yer", secenekler = { { id = "yer", ad = "Lugar" }, { id = "aktor", ad = "Actor" }, { id = "oyuncu", ad = "Jugador" } } },
          { k = "yer", ad = "Lugar", tip = "yer", v = "", goster = function(e) return e.kaynak == "yer" end },
          { k = "aktor", ad = "Actor", tip = "aktor", v = "", goster = function(e) return e.kaynak == "aktor" end },
          { k = "efekt", ad = "Efecto", tip = "secim", v = "isik_toz", secenekler = G.ParcacikListe },
          { k = "sure", ad = "Duración (0 = hasta fin del paso)", tip = "sayi", v = 5, min = 0, max = 600, ondalik = 1 },
          { k = "herkes", ad = "Que lo vean todos los cercanos", tip = "bool", v = false },
     },
     ozet = function(e) return e.efekt .. " @ " .. (e.kaynak == "yer" and Y(e.yer) or e.kaynak) end,
})

-- Jugador
Kaydet("Eylem", "isinla", {
     ad = "Teletransportar jugador", kat = "oyuncu", ikon = "isinla",
     alanlar = {
          { k = "yer", ad = "Lugar", tip = "yer", v = "" },
          { k = "karart", ad = "Oscurecer y aclarar", tip = "bool", v = true },
     },
     ozet = function(e) return Y(e.yer) end,
})

Kaydet("Eylem", "sandal", {
     ad = "Viaje en barca", kat = "oyuncu", ikon = "isinla",
     aciklama = "El jugador (y opcionalmente un actor) se sienta en una barca y avanza solo por los puntos del lugar 'ruta'. Los puntos deben estar en la superficie del agua. Para terminar, añade 'Bajar de la barca'.",
     alanlar = {
          { k = "yer", ad = "Ruta (lugar tipo ruta)", tip = "yer", v = "" },
          { k = "hiz", ad = "Velocidad (unidades/s)", tip = "sayi", v = 105, min = 20, max = 400 },
          { k = "aktor", ad = "Actor en la barca", tip = "aktor", v = "", ipucu = "Vacío: el jugador solo" },
          { k = "model", ad = "Modelo de barca", tip = "model", v = "", ipucu = "Vacío: barca de madera con remos" },
          { k = "bekle", ad = "Esperar a llegar", tip = "bool", v = false, ipucu = "Si está cerrado, las siguientes acciones (diálogos) se reproducen en ruta" },
     },
     ozet = function(e) return Y(e.yer) .. ((e.aktor or "") ~= "" and ("  + " .. e.aktor) or "") end,
})

Kaydet("Eylem", "sandal_bitir", {
     ad = "Bajar de la barca", kat = "oyuncu", ikon = "isinla",
     aciklama = "Al llegar la barca (opcional) se oscurece la pantalla y la barca se elimina. El jugador queda sobre el agua: luego pon 'Teletransportar jugador' (sin oscurecer).",
     alanlar = {
          { k = "varis", ad = "Esperar a que llegue", tip = "bool", v = true },
          { k = "karart", ad = "Oscurecer pantalla", tip = "bool", v = true },
     },
     ozet = function(e) return (e.varis ~= false and "al llegar" or "ya") .. (e.karart ~= false and " · oscurece" or "") end,
})

Kaydet("Eylem", "kilit", {
     ad = "Detener / liberar jugador", kat = "oyuncu", ikon = "kilit",
     alanlar = { { k = "acik", ad = "Detener", tip = "bool", v = true } },
     ozet = function(e) return e.acik and "detener" or "liberar" end,
})

Kaydet("Eylem", "bildirim", {
     ad = "Notificación / pista", kat = "oyuncu", ikon = "bilgi",
     alanlar = {
          { k = "metin", ad = "Texto", tip = "yazi", v = "" },
          { k = "tur", ad = "Tipo", tip = "secim", v = "ipucu", secenekler = { { id = "ipucu", ad = "Pista" }, { id = "bilgi", ad = "Info" }, { id = "uyari", ad = "Advertencia" } } },
          { k = "sure", ad = "Duración", tip = "sayi", v = 6, min = 1, max = 30 },
     },
     ozet = function(e) return M(e.metin) end,
})

Kaydet("Eylem", "esya_ver", {
     ad = "Dar objeto", kat = "oyuncu", ikon = "esya",
     alanlar = {
          { k = "esya", ad = "Objeto", tip = "esya", v = "" },
          { k = "adet", ad = "Cantidad", tip = "sayi", v = 1, min = 1, max = 50 },
          { k = "veri", ad = "Datos del objeto (JSON)", tip = "metin", v = "" },
     },
     ozet = function(e) return (e.adet or 1) .. " × " .. Y(e.esya) end,
})

Kaydet("Eylem", "esya_al", {
     ad = "Quitar objeto", kat = "oyuncu", ikon = "esya",
     alanlar = {
          { k = "esya", ad = "Objeto", tip = "esya", v = "" },
          { k = "adet", ad = "Cantidad", tip = "sayi", v = 1, min = 1, max = 50 },
     },
     ozet = function(e) return (e.adet or 1) .. " × " .. Y(e.esya) end,
})

Kaydet("Eylem", "para", {
     ad = "Dar / quitar dinero", kat = "oyuncu", ikon = "para",
     alanlar = { { k = "miktar", ad = "Cantidad (negativo = quitar)", tip = "sayi", v = 10, min = -100000, max = 100000 } },
     ozet = function(e) return (e.miktar >= 0 and "+" or "") .. e.miktar .. " G" end,
})

Kaydet("Eylem", "odul", {
     ad = "Dar recompensa (ahora)", kat = "oyuncu", ikon = "odul",
     alanlar = { { k = "oduller", ad = "Recompensas", tip = "oduller", v = {} } },
     ozet = function(e) return #(e.oduller or {}) .. " recompensa" end,
})

-- Akış
Kaydet("Eylem", "bekle", {
     ad = "Esperar", kat = "akis", ikon = "saat",
     alanlar = { { k = "sure", ad = "Duración (s)", tip = "sayi", v = 1, min = 0, max = 600, ondalik = 1 } },
     ozet = function(e) return e.sure .. " s" end,
})

Kaydet("Eylem", "git", {
     ad = "Ir al paso", kat = "akis", ikon = "git",
     alanlar = { { k = "adim", ad = "Paso", tip = "adim", v = "" } },
     ozet = function(e) return "→ " .. Y(e.adim) end,
})

Kaydet("Eylem", "dallan", {
     ad = "Ramificar según condición", kat = "akis", ikon = "dallan",
     alanlar = {
          { k = "kosullar", ad = "Condiciones (todas)", tip = "kosullar", v = {} },
          { k = "git", ad = "Si se cumple → paso", tip = "adim", v = "" },
          { k = "degilse", ad = "Si no se cumple → paso", tip = "adim", v = "" },
     },
     ozet = function(e) return #(e.kosullar or {}) .. " condición ? " .. Y(e.git) .. " : " .. ((e.degilse or "") ~= "" and e.degilse or "continuar") end,
})

Kaydet("Eylem", "rastgele", {
     ad = "Rama aleatoria", kat = "akis", ikon = "zar",
     alanlar = {
          { k = "secenekler", ad = "Ramas", tip = "liste", v = {}, alanlar = {
               { k = "adim", ad = "Paso", tip = "adim", v = "" },
               { k = "agirlik", ad = "Peso", tip = "sayi", v = 1, min = 0, max = 100, ondalik = 1 },
          }, ozet = function(s) return Y(s.adim) .. " · " .. (s.agirlik or 1) end },
     },
     ozet = function(e) return #(e.secenekler or {}) .. " ramas" end,
})

Kaydet("Eylem", "degisken", {
     ad = "Asignar variable", kat = "akis", ikon = "degisken",
     alanlar = {
          { k = "ad", ad = "Variable", tip = "metin", v = "" },
          { k = "islem", ad = "Operación", tip = "secim", v = "=", secenekler = { { id = "=", ad = "=" }, { id = "+", ad = "+" }, { id = "-", ad = "−" } } },
          { k = "deger", ad = "Valor", tip = "metin", v = "" },
     },
     ozet = function(e) return Y(e.ad) .. " " .. e.islem .. " " .. tostring(e.deger) end,
})

Kaydet("Eylem", "bitir", {
     ad = "Terminar misión", kat = "akis", ikon = "bayrak",
     alanlar = {
          { k = "sonuc", ad = "Resultado", tip = "secim", v = "basari", secenekler = { { id = "basari", ad = "Éxito" }, { id = "basarisiz", ad = "Fallida" } } },
          { k = "mesaj", ad = "Mensaje", tip = "metin", v = "" },
     },
     ozet = function(e) return e.sonuc == "basari" and "éxito" or "fracaso" end,
})

Kaydet("Eylem", "gorev_baslat", {
     ad = "Iniciar otra misión", kat = "akis", ikon = "gorev",
     alanlar = { { k = "gorev", ad = "Misión", tip = "gorev", v = "" } },
     ozet = function(e) return Y(e.gorev) end,
})

Kaydet("Eylem", "olay", {
     ad = "Publicar evento (desarrollador)", kat = "akis", ikon = "olay",
     aciklama = "hook.Run(\"SardonGorevOlay\", jugador, ad, gorevId) — para disparar otros sistemas.",
     alanlar = { { k = "ad", ad = "Nombre del evento", tip = "metin", v = "" } },
     ozet = function(e) return Y(e.ad) end,
})

Kaydet("Eylem", "isaret", {
     ad = "Poner / quitar marca en el mapa", kat = "akis", ikon = "isaret",
     alanlar = {
          { k = "yer", ad = "Lugar", tip = "yer", v = "" },
          { k = "metin", ad = "Texto", tip = "metin", v = "" },
          { k = "acik", ad = "Poner (si está cerrado, quitar)", tip = "bool", v = true },
     },
     ozet = function(e) return (e.acik and "+ " or "− ") .. Y(e.yer) end,
})

-- Dünya
Kaydet("Eylem", "varlik", {
     ad = "Crear entidad / criatura", kat = "dunya", ikon = "varlik",
     aciklama = "Entidad real en el servidor (se puede combatir). Se elimina al terminar la misión. Si Tipo de animal está relleno, se crea un animal Sardon.",
     alanlar = {
          { k = "sinif", ad = "Clase", tip = "sinif", v = "" },
          { k = "hayvan", ad = "Tipo de animal (sardon_hayvan)", tip = "metin", v = "" },
          { k = "model", ad = "Modelo (opcional)", tip = "model", v = "" },
          { k = "yer", ad = "Lugar", tip = "yer", v = "" },
          { k = "adet", ad = "Cantidad", tip = "sayi", v = 1, min = 1, max = 12 },
          { k = "yaricap", ad = "Radio de dispersión", tip = "sayi", v = 120, min = 0, max = 2000 },
          { k = "etiket", ad = "Etiqueta", tip = "metin", v = "", ipucu = "El objetivo Matar cuenta con esta etiqueta" },
          { k = "tekil", ad = "No colocar si ya hay cerca", tip = "bool", v = false, ipucu = "Ej. Sombrero Seleccionador: si ya está ahí, no coloca un segundo" },
          { k = "kalici", ad = "Que quede al terminar la misión", tip = "bool", v = false },
     },
     ozet = function(e) return (e.adet or 1) .. " × " .. ((e.hayvan or "") ~= "" and e.hayvan or Y(e.sinif)) .. " @ " .. Y(e.yer) end,
})

Kaydet("Eylem", "nesne", {
     ad = "Colocar objeto recogible", kat = "dunya", ikon = "nesne",
     aciklama = "Objetos brillantes que solo ve el dueño de la misión. Cuentan para el objetivo 'Recoger'.",
     alanlar = {
          { k = "yerler", ad = "Lugares", tip = "liste", v = {}, alanlar = { { k = "yer", ad = "Lugar", tip = "yer", v = "" } }, ozet = function(s) return Y(s.yer) end },
          { k = "model", ad = "Modelo", tip = "model", v = "models/props_lab/jar01a.mdl" },
          { k = "ad", ad = "Nombre", tip = "metin", v = "Objeto" },
          { k = "etiket", ad = "Etiqueta", tip = "metin", v = "nesne" },
          { k = "parilti", ad = "Brillo", tip = "bool", v = true },
     },
     ozet = function(e) return #(e.yerler or {}) .. " × " .. Y(e.ad) end,
})

/* ======================================================================================
*   HEDEFLER
* ====================================================================================== */
local function H(alanlar)
     table.insert(alanlar, 1, { k = "metin", ad = "Texto visible", tip = "metin", v = "", ipucu = "Vacío: automático" })
     alanlar[#alanlar + 1] = { k = "isaret", ad = "Marcar en el mapa", tip = "bool", v = true }
     alanlar[#alanlar + 1] = { k = "istege", ad = "Opcional", tip = "bool", v = false }
     alanlar[#alanlar + 1] = { k = "gizli", ad = "Oculto", tip = "bool", v = false }
     return alanlar
end

Kaydet("Hedef", "git", {
     ad = "Ir a un lugar", ikon = "isaret",
     alanlar = H({ { k = "yer", ad = "Lugar", tip = "yer", v = "" }, { k = "yaricap", ad = "Radio", tip = "sayi", v = 160, min = 20, max = 5000 } }),
     ozet = function(e) return "Ir: " .. Y(e.yer) end,
})

Kaydet("Hedef", "konus", {
     ad = "Hablar con actor", ikon = "konus",
     alanlar = H({ { k = "aktor", ad = "Actor", tip = "aktor", v = "" } }),
     ozet = function(e) return "Hablar: " .. Y(e.aktor) end,
})

Kaydet("Hedef", "takip", {
     ad = "Seguir al actor", ikon = "yuru",
     aciklama = "Se completa cuando el actor llega a su objetivo con 'Hacer caminar al actor' y el jugador está cerca.",
     alanlar = H({ { k = "aktor", ad = "Actor", tip = "aktor", v = "" }, { k = "yakin", ad = "Proximidad al llegar", tip = "sayi", v = 420, min = 100, max = 2000 } }),
     ozet = function(e) return "Seguir: " .. Y(e.aktor) end,
})

Kaydet("Hedef", "bolgede_kal", {
     ad = "Permanecer en la zona", ikon = "saat",
     alanlar = H({ { k = "yer", ad = "Lugar", tip = "yer", v = "" }, { k = "yaricap", ad = "Radio", tip = "sayi", v = 300, min = 20, max = 5000 }, { k = "sure", ad = "Duración (s)", tip = "sayi", v = 30, min = 1, max = 3600 } }),
     ozet = function(e) return Y(e.yer) .. " · " .. e.sure .. " s" end,
})

Kaydet("Hedef", "uzaklas", {
     ad = "Alejarse de la zona", ikon = "yuru",
     alanlar = H({ { k = "yer", ad = "Lugar", tip = "yer", v = "" }, { k = "yaricap", ad = "Radio", tip = "sayi", v = 1500, min = 50, max = 20000 } }),
     ozet = function(e) return "Alejar: " .. Y(e.yer) end,
})

Kaydet("Hedef", "esya_edin", {
     ad = "Poseer objeto", ikon = "esya",
     alanlar = H({ { k = "esya", ad = "Objeto", tip = "esya", v = "" }, { k = "adet", ad = "Cantidad", tip = "sayi", v = 1, min = 1, max = 100 } }),
     ozet = function(e) return (e.adet or 1) .. " × " .. Y(e.esya) end,
})

Kaydet("Hedef", "esya_teslim", {
     ad = "Entregar objeto", ikon = "esya",
     aciklama = "Al hablar con el actor, el objeto se quita del inventario del jugador.",
     alanlar = H({ { k = "aktor", ad = "Actor", tip = "aktor", v = "" }, { k = "esya", ad = "Objeto", tip = "esya", v = "" }, { k = "adet", ad = "Cantidad", tip = "sayi", v = 1, min = 1, max = 100 } }),
     ozet = function(e) return (e.adet or 1) .. " × " .. Y(e.esya) .. " → " .. Y(e.aktor) end,
})

Kaydet("Hedef", "satin_al", {
     ad = "Comprar", ikon = "para",
     alanlar = H({
          { k = "magaza", ad = "Tienda", tip = "secim", v = "", secenekler = MAGAZA },
          { k = "urun", ad = "Nombre del producto (vacío = cualquiera)", tip = "metin", v = "" },
          { k = "adet", ad = "Cantidad", tip = "sayi", v = 1, min = 1, max = 50 },
          { k = "yer", ad = "Lugar (opcional)", tip = "yer", v = "" },
          { k = "yaricap", ad = "Radio", tip = "sayi", v = 600, min = 50, max = 5000 },
     }),
     ozet = function(e) return "Comprar: " .. ((e.urun or "") ~= "" and e.urun or "cualquiera") end,
})

Kaydet("Hedef", "para_harca", {
     ad = "Gastar dinero", ikon = "para",
     alanlar = H({ { k = "miktar", ad = "Cantidad", tip = "sayi", v = 10, min = 1, max = 100000 }, { k = "yer", ad = "Lugar (opcional)", tip = "yer", v = "" }, { k = "yaricap", ad = "Radio", tip = "sayi", v = 600, min = 50, max = 5000 } }),
     ozet = function(e) return e.miktar .. " G gastados" end,
})

Kaydet("Hedef", "kullan", {
     ad = "Usar una entidad (E)", ikon = "el",
     alanlar = H({ { k = "sinif", ad = "Clase", tip = "sinif", v = "" }, { k = "yer", ad = "Lugar (opcional)", tip = "yer", v = "" }, { k = "yaricap", ad = "Radio", tip = "sayi", v = 300, min = 20, max = 5000 } }),
     ozet = function(e) return "Usar: " .. Y(e.sinif) end,
})

Kaydet("Hedef", "hane", {
     ad = "Ser seleccionado a una casa (Sombrero Seleccionador)", ikon = "sapka",
     alanlar = H({ { k = "yer", ad = "Lugar del sombrero (para marca)", tip = "yer", v = "" } }),
     ozet = function() return "Seleccionado a casa" end,
})

Kaydet("Hedef", "buyu_at", {
     ad = "Lanzar hechizo", ikon = "asa",
     alanlar = H({ { k = "buyu", ad = "Hechizo (vacío = cualquiera)", tip = "buyu", v = "" }, { k = "adet", ad = "Cantidad", tip = "sayi", v = 1, min = 1, max = 100 }, { k = "yer", ad = "Lugar (opcional)", tip = "yer", v = "" }, { k = "yaricap", ad = "Radio", tip = "sayi", v = 600, min = 50, max = 5000 } }),
     ozet = function(e) return "Hechizo: " .. ((e.buyu or "") ~= "" and e.buyu or "cualquiera") .. " ×" .. (e.adet or 1) end,
})

Kaydet("Hedef", "oldur", {
     ad = "Derrotar / matar", ikon = "kilic",
     alanlar = H({
          { k = "tur", ad = "Objetivo", tip = "secim", v = "etiket", secenekler = { { id = "etiket", ad = "Creado por la misión (etiqueta)" }, { id = "sinif", ad = "Clase" }, { id = "hayvan", ad = "Tipo de animal" } } },
          { k = "deger", ad = "Etiqueta / clase / tipo", tip = "metin", v = "" },
          { k = "adet", ad = "Cantidad", tip = "sayi", v = 1, min = 1, max = 100 },
     }),
     ozet = function(e) return "Derrotar: " .. Y(e.deger) .. " ×" .. (e.adet or 1) end,
})

Kaydet("Hedef", "topla", {
     ad = "Recoger objetos", ikon = "nesne",
     alanlar = H({ { k = "etiket", ad = "Etiqueta", tip = "metin", v = "nesne" }, { k = "adet", ad = "Cantidad (0 = todos)", tip = "sayi", v = 0, min = 0, max = 100 } }),
     ozet = function(e) return "Recoger: " .. Y(e.etiket) end,
})

Kaydet("Hedef", "etkilesim", {
     ad = "Inspeccionar un lugar (mantener E)", ikon = "el",
     alanlar = H({ { k = "yer", ad = "Lugar", tip = "yer", v = "" }, { k = "yaricap", ad = "Radio", tip = "sayi", v = 70, min = 20, max = 400 }, { k = "sure", ad = "Duración (s)", tip = "sayi", v = 2.5, min = 0.5, max = 30, ondalik = 1 }, { k = "eylem", ad = "Nombre de acción", tip = "metin", v = "Examinar" } }),
     ozet = function(e) return (e.eylem or "Examinar") .. ": " .. Y(e.yer) end,
})

Kaydet("Hedef", "sohbet", {
     ad = "Escribir en el chat", ikon = "konus",
     alanlar = H({ { k = "kelimeler", ad = "Palabras (separadas por coma; basta una)", tip = "metin", v = "" }, { k = "yer", ad = "Lugar (opcional)", tip = "yer", v = "" }, { k = "yaricap", ad = "Radio", tip = "sayi", v = 400, min = 50, max = 5000 } }),
     ozet = function(e) return "Decir: " .. Y(e.kelimeler) end,
})

Kaydet("Hedef", "olay", {
     ad = "Esperar evento (desarrollador)", ikon = "olay",
     aciklama = "Cuenta cuando se llama SardonGorev.Tetikle(jugador, ad) o hook.Run(\"SardonGorevTetikle\", jugador, ad).",
     alanlar = H({ { k = "ad", ad = "Nombre del evento", tip = "metin", v = "" }, { k = "adet", ad = "Cantidad", tip = "sayi", v = 1, min = 1, max = 100 } }),
     ozet = function(e) return "Evento: " .. Y(e.ad) end,
})

Kaydet("Hedef", "kosul", {
     ad = "Que se cumpla la condición", ikon = "dallan",
     alanlar = H({ { k = "kosullar", ad = "Condiciones (todas)", tip = "kosullar", v = {} } }),
     ozet = function(e) return #(e.kosullar or {}) .. " condición" end,
})

Kaydet("Hedef", "sure", {
     ad = "Que pase la duración", ikon = "saat",
     alanlar = H({ { k = "sure", ad = "Duración (s)", tip = "sayi", v = 30, min = 1, max = 7200 } }),
     ozet = function(e) return e.sure .. " s" end,
})

/* ======================================================================================
*   KOŞULLAR
* ====================================================================================== */
local function K(alanlar)
     alanlar[#alanlar + 1] = { k = "tersi", ad = "Inverso (si no)", tip = "bool", v = false }
     return alanlar
end

Kaydet("Kosul", "seviye", { ad = "Nivel", alanlar = K({ { k = "min", ad = "Mínimo", tip = "sayi", v = 1, min = 0, max = 1000 }, { k = "max", ad = "Máximo (0 = ilimitado)", tip = "sayi", v = 0, min = 0, max = 1000 } }),
     ozet = function(e) return "nivel " .. e.min .. ((e.max or 0) > 0 and ("–" .. e.max) or "+") end })
Kaydet("Kosul", "hane", { ad = "Casa", alanlar = K({ { k = "deger", ad = "Casa", tip = "secim", v = "yok", secenekler = {
     { id = "yok", ad = "Aún no elegido" }, { id = "var", ad = "Elegido (cualquiera)" }, { id = "1", ad = "Gryffindor" }, { id = "2", ad = "Ravenclaw" }, { id = "3", ad = "Slytherin" }, { id = "4", ad = "Hufflepuff" } } } }),
     ozet = function(e) return "casa: " .. e.deger end })
Kaydet("Kosul", "faction", { ad = "Faction", alanlar = K({ { k = "deger", ad = "uniqueID (separados por coma)", tip = "metin", v = "" } }), ozet = function(e) return "faction: " .. Y(e.deger) end })
Kaydet("Kosul", "sinif", { ad = "Clase (class)", alanlar = K({ { k = "deger", ad = "uniqueID (separados por coma)", tip = "metin", v = "" } }), ozet = function(e) return "clase: " .. Y(e.deger) end })
Kaydet("Kosul", "gorev_bitti", { ad = "Misión completada", alanlar = K({ { k = "gorev", ad = "Misión", tip = "gorev", v = "" }, { k = "adet", ad = "Mínimo de veces", tip = "sayi", v = 1, min = 1, max = 1000 } }), ozet = function(e) return "completada: " .. Y(e.gorev) end })
Kaydet("Kosul", "gorev_aktif", { ad = "Misión en curso", alanlar = K({ { k = "gorev", ad = "Misión", tip = "gorev", v = "" } }), ozet = function(e) return "en curso: " .. Y(e.gorev) end })
Kaydet("Kosul", "degisken", { ad = "Variable de misión", alanlar = K({ { k = "ad", ad = "Variable", tip = "metin", v = "" }, { k = "islem", ad = "Comparación", tip = "secim", v = "==", secenekler = {
     { id = "==", ad = "=" }, { id = "~=", ad = "≠" }, { id = ">", ad = ">" }, { id = "<", ad = "<" }, { id = ">=", ad = "≥" }, { id = "<=", ad = "≤" } } }, { k = "deger", ad = "Valor", tip = "metin", v = "" } }),
     ozet = function(e) return Y(e.ad) .. " " .. e.islem .. " " .. tostring(e.deger) end })
Kaydet("Kosul", "saat", { ad = "Hora del juego", aciklama = "Hora de StormFox; si no, hora del servidor. Para noche: inicio 21, fin 5.", alanlar = K({ { k = "bas", ad = "Inicio (hora)", tip = "sayi", v = 20, min = 0, max = 24, ondalik = 1 }, { k = "son", ad = "Fin (hora)", tip = "sayi", v = 5, min = 0, max = 24, ondalik = 1 } }),
     ozet = function(e) return "hora " .. e.bas .. "–" .. e.son end })
Kaydet("Kosul", "gercek_saat", { ad = "Hora real", alanlar = K({ { k = "bas", ad = "Inicio", tip = "sayi", v = 18, min = 0, max = 24, ondalik = 1 }, { k = "son", ad = "Fin", tip = "sayi", v = 23, min = 0, max = 24, ondalik = 1 } }),
     ozet = function(e) return "hora real " .. e.bas .. "–" .. e.son end })
Kaydet("Kosul", "gun", { ad = "Día de la semana", alanlar = K({ { k = "gunler", ad = "Días (1=lun … 7=dom, separados por coma)", tip = "metin", v = "6,7" } }), ozet = function(e) return "día " .. Y(e.gunler) end })
Kaydet("Kosul", "hava", { ad = "Clima", alanlar = K({ { k = "deger", ad = "Clima", tip = "secim", v = "yagmur", secenekler = {
     { id = "acik", ad = "Despejado" }, { id = "yagmur", ad = "Lluvia" }, { id = "kar", ad = "Nieve" }, { id = "firtina", ad = "Tormenta" }, { id = "sis", ad = "Niebla" }, { id = "bulut", ad = "Nublado" } } } }),
     ozet = function(e) return "clima: " .. e.deger end })
Kaydet("Kosul", "esya", { ad = "Tiene objeto", alanlar = K({ { k = "esya", ad = "Objeto", tip = "esya", v = "" }, { k = "adet", ad = "Mínimo", tip = "sayi", v = 1, min = 1, max = 100 } }), ozet = function(e) return "objeto: " .. Y(e.esya) end })
Kaydet("Kosul", "para", { ad = "Dinero", alanlar = K({ { k = "min", ad = "Mínimo", tip = "sayi", v = 1, min = 0, max = 1000000 } }), ozet = function(e) return "dinero ≥ " .. e.min end })
Kaydet("Kosul", "onur", { ad = "Honor", alanlar = K({ { k = "min", ad = "Mínimo", tip = "sayi", v = -1000, min = -1000, max = 1000 }, { k = "max", ad = "Máximo", tip = "sayi", v = 1000, min = -1000, max = 1000 } }), ozet = function(e) return "honor " .. e.min .. "…" .. e.max end })
Kaydet("Kosul", "sans", { ad = "Suerte del día", alanlar = K({ { k = "min", ad = "Nivel mínimo (1=D … 15=SS+)", tip = "sayi", v = 7, min = 1, max = 15 } }), ozet = function(e) return "suerte ≥ " .. e.min end })
Kaydet("Kosul", "jugador_sayisi", { ad = "Jugadores en el servidor", alanlar = K({ { k = "min", ad = "Mínimo", tip = "sayi", v = 2, min = 1, max = 128 } }), ozet = function(e) return "jugador ≥ " .. e.min end })
Kaydet("Kosul", "rastgele", { ad = "Probabilidad", alanlar = K({ { k = "oran", ad = "Ratio (0–1)", tip = "sayi", v = 0.5, min = 0, max = 1, ondalik = 2 } }), ozet = function(e) return "%" .. math.Round(e.oran * 100) end })
Kaydet("Kosul", "yakin", { ad = "Jugador cerca de un lugar", alanlar = K({ { k = "yer", ad = "Lugar", tip = "yer", v = "" }, { k = "yaricap", ad = "Radio", tip = "sayi", v = 500, min = 20, max = 20000 } }), ozet = function(e) return "cerca: " .. Y(e.yer) end })
Kaydet("Kosul", "discord", { ad = "Discord conectado", alanlar = K({}), ozet = function() return "Discord conectado" end })
Kaydet("Kosul", "yetkili", { ad = "Autorizado (test)", alanlar = K({}), ozet = function() return "autorizado" end })

/* ======================================================================================
*   ÖDÜLLER
* ====================================================================================== */
Kaydet("Odul", "para", { ad = "Dinero", alanlar = { { k = "miktar", ad = "Galeones", tip = "sayi", v = 25, min = 1, max = 1000000 } }, ozet = function(e) return e.miktar .. " galeones" end })
Kaydet("Odul", "xp", { ad = "Experiencia", alanlar = { { k = "miktar", ad = "XP", tip = "sayi", v = 50, min = 1, max = 1000000 } }, ozet = function(e) return e.miktar .. " XP" end })
Kaydet("Odul", "esya", { ad = "Objeto", alanlar = { { k = "esya", ad = "Objeto", tip = "esya", v = "" }, { k = "adet", ad = "Cantidad", tip = "sayi", v = 1, min = 1, max = 50 }, { k = "veri", ad = "Datos (JSON)", tip = "metin", v = "" } }, ozet = function(e) return (e.adet or 1) .. " × " .. Y(e.esya) end })
Kaydet("Odul", "buyu", { ad = "Hechizo / varita", alanlar = { { k = "buyu", ad = "Hechizo", tip = "buyu", v = "" }, { k = "tur", ad = "Modo", tip = "secim", v = "ogren", secenekler = { { id = "ogren", ad = "Aprendible (pergamino)" }, { id = "tam", ad = "Enseñar directo (varita)" } } } }, ozet = function(e) return Y(e.buyu) end })
Kaydet("Odul", "onur", { ad = "Honor", alanlar = { { k = "miktar", ad = "Cantidad", tip = "sayi", v = 5, min = -1000, max = 1000 } }, ozet = function(e) return (e.miktar >= 0 and "+" or "") .. e.miktar .. " honor" end })
Kaydet("Odul", "gelisim", { ad = "Puntos de desarrollo", alanlar = { { k = "miktar", ad = "Puntos", tip = "sayi", v = 1, min = 1, max = 50 } }, ozet = function(e) return e.miktar .. " pts. de desarrollo" end })
Kaydet("Odul", "sans", { ad = "Factor de suerte", alanlar = { { k = "adim", ad = "Nivel", tip = "sayi", v = 1, min = -5, max = 5 }, { k = "sure", ad = "Duración (min, 0 = fin del día)", tip = "sayi", v = 60, min = 0, max = 1440 } }, ozet = function(e) return "suerte " .. (e.adim >= 0 and "+" or "") .. e.adim end })

/* ======================================================================================
*   REPLİKLER (actorün kendiliğinden söyledikleri) ve AKTÖR TANIMI
* ====================================================================================== */
G.ReplikTetik = {
     { id = "aralik", ad = "Por intervalo (hasta terminar el objetivo)" },
     { id = "giris", ad = "Una vez al empezar los objetivos" },
     { id = "uzak", ad = "Cuando el jugador se aleje" },
     { id = "yakin", ad = "Cuando el jugador se acerque" },
     { id = "bosta", ad = "Cuando el jugador se quede parado" },
     { id = "satin", ad = "Cuando el jugador recoja algo" },
     { id = "ilerleme", ad = "Cuando avance un objetivo" },
}

G.ReplikAlanlari = {
     { k = "aktor", ad = "Actor", tip = "aktor", v = "" },
     { k = "tetik", ad = "Cuándo", tip = "secim", v = "aralik", secenekler = G.ReplikTetik },
     { k = "aralik", ad = "Intervalo / espera (s)", tip = "sayi", v = 12, min = 1, max = 600, ondalik = 1 },
     { k = "ilk", ad = "Retraso inicial (s)", tip = "sayi", v = 0, min = 0, max = 600, ondalik = 1 },
     { k = "menzil", ad = "Alcance", tip = "sayi", v = 1400, min = 50, max = 6000 },
     { k = "sira", ad = "Orden", tip = "secim", v = "sirali", secenekler = { { id = "sirali", ad = "En secuencia" }, { id = "rastgele", ad = "Aleatorio" } } },
     { k = "tekrar", ad = "Al terminar las líneas, volver al inicio", tip = "bool", v = true },
     { k = "bak", ad = "Mirar al jugador al hablar", tip = "bool", v = true },
     { k = "satirlar", ad = "Líneas", tip = "liste", v = {}, alanlar = {
          { k = "metin", ad = "Réplica", tip = "yazi", v = "" },
          { k = "ses", ad = "Archivo de sonido", tip = "ses", v = "" },
          { k = "anim", ad = "Movimiento", tip = "anim", v = "" },
     }, ozet = function(s) return M(s.metin, 50) .. ((s.ses or "") ~= "" and "  ♪" or "") end },
}

function G.ReplikOzet(r)
     local t = "?"
     for _, v in ipairs(G.ReplikTetik) do if v.id == r.tetik then t = v.ad end end
     return Y(r.aktor) .. " · " .. t .. " · " .. #(r.satirlar or {}) .. " líneas"
end

G.AktorAlanlari = {
     { k = "id", ad = "ID", tip = "metin", v = "" },
     { k = "ad", ad = "Nombre visible", tip = "metin", v = "" },
     { k = "unvan", ad = "Título", tip = "metin", v = "" },
     { k = "model", ad = "Modelo", tip = "model", v = "models/player/group01/female_01.mdl" },
     { k = "skin", ad = "Skin", tip = "sayi", v = 0, min = 0, max = 32 },
     { k = "bg", ad = "Bodygroup (nº=valor, separados por coma)", tip = "metin", v = "" },
     { k = "boy", ad = "Escala de altura", tip = "sayi", v = 1, min = 0.5, max = 1.6, ondalik = 2 },
     { k = "gorunurluk", ad = "Quién lo ve", tip = "secim", v = "cevre", secenekler = { { id = "cevre", ad = "Todos los cercanos" }, { id = "kisisel", ad = "Solo el dueño de la misión" } } },
     { k = "isimRenk", ad = "Color del nombre", tip = "renk", v = { 232, 219, 182 } },
     { k = "bekleAnim", ad = "Animación de espera", tip = "anim", v = "" },
     { k = "yuruAnim", ad = "Animación de caminar", tip = "anim", v = "" },
     { k = "kosAnim", ad = "Animación de correr", tip = "anim", v = "" },
     { k = "hare", ad = "Aura de recuerdo", tip = "secim", v = "", secenekler = G.HareListe },
     { k = "isimGoster", ad = "Nombre sobre la cabeza", tip = "bool", v = true },
}

-- Karşılaşma (rastgele) ayarları
G.KarsilasmaAlanlari = {
     { k = "yerler", ad = "Lugares donde puede aparecer", tip = "liste", v = {}, alanlar = { { k = "yer", ad = "Lugar", tip = "yer", v = "" } }, ozet = function(s) return Y(s.yer) end },
     { k = "tetik", ad = "Cuando el jugador esté así de cerca", tip = "sayi", v = 1800, min = 200, max = 8000 },
     { k = "enYakin", ad = "…pero al menos a esta distancia", tip = "sayi", v = 500, min = 0, max = 4000, ipucu = "Que no aparezca delante de los ojos del jugador" },
     { k = "ilgi", ad = "Distancia de inicio del encuentro", tip = "sayi", v = 450, min = 50, max = 3000 },
     { k = "kacirma", ad = "Si se aleja tanto, desaparece", tip = "sayi", v = 2800, min = 500, max = 10000 },
     { k = "sans", ad = "Probabilidad en cada comprobación", tip = "sayi", v = 0.15, min = 0.01, max = 1, ondalik = 2 },
     { k = "jugadorEsperarme", ad = "Espera por jugador (s)", tip = "sayi", v = 3600, min = 0, max = 604800 },
     { k = "genelEsperarme", ad = "Espera general (s)", tip = "sayi", v = 300, min = 0, max = 86400 },
     { k = "esZamanli", ad = "Máximo a la vez", tip = "sayi", v = 1, min = 1, max = 16 },
}

-- Pasoın "con el actor al hablar" tetikleri (dükkâncılar, sohbet edilebilir figürler)
G.KonusuncaAlanlari = {
     { k = "aktor", ad = "Actor (ID de actor de misión o del mundo)", tip = "aktor", v = "" },
     { k = "tekrar", ad = "En cada conversación", tip = "bool", v = false },
     { k = "eylemler", ad = "Acciones", tip = "liste", v = {}, semaTur = "Eylem", kategoriler = G.EylemKategori },
}

function G.KonusuncaOzet(k)
     return (k.aktor ~= "" and k.aktor or "?") .. " · al hablar · " .. #(k.eylemler or {}) .. " acciones" .. (k.tekrar and " · cada vez" or "")
end
