-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\_sh_config.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Ministerio :: ayarlar, daireler ve sınıf eşlemesi.
-- Dosya adı "_" ile başlıyor ki SardonUtil'in alfabetik yüklemesinde cl_/sv_ dosyalarından atrás gelsin.
--
-- ARAÇ: "Expediente". Protean (Değişken) büyüsüyle bütün kopyaları aynı anda güncellenen
-- Ministerio defteri; FiveM'deki MDT tabletinin sihir dünyasındaki karşılığı.
--
-- KİM KULLANIR: Ministerio de Magia ve Aurorlık fraksiyonlarındaki karakterler. Yetki, Helix
-- sınıfından (B.Siniflar) türeyen 1..5 kademe + daire ile belirlenir; sunucu her eylemde
-- yeniden denetler (_sh_yetki.lua). Fraksiyon dışındakiler aynı tuşla "Vatandaş Gişesi"ni görür.
--
-- DİĞER EKLENTİLER: hiçbiri düzenlenmez; kancalar ve sarmalayıcılarla bağlanılır (sv_3olay.lua,
-- sv_6emir.lua, sv_7iz.lua). Eklenti yoksa ilgili besleme sessizce atlanır.

SardonBakanlik = SardonBakanlik or {}
local B = SardonBakanlik

local AYAR = {
     AracAdi = "Expediente",

     -- Fraksiyon kategorileri (gamemodes/darkrp/schema/factions): defteri açabilenler
     Kategoriler = {["Büyü Bakanlığı"] = true, ["Seherbazlık"] = true},

     -- ==== Hapis (Azkaban) ====
     DogrudanHapis = 300,     -- s; Aurorın onaysız verebildiği en uzun hapis
     AzamiHapis = 900,        -- s; onayla ya da Wizengamot hükmüyle verilebilen tavan
     AzkabanYaricap = 320,    -- hücre noktasından bu kadar uzaklaşan geri alınır
     FirarMumkun = false,     -- true: yarıçap dışına çıkan "firari" olur (aranır), geri alınmaz
     AzkabanOnur = 10,        -- cezasını tamamlayana verilen onur (0 = kapalı)
     GozaltiMenzil = 160,     -- sevk/ceza/inceleme için bağlı şüpheliye azami mesafe

     -- ==== Multa ====
     CezaAzami = 500,
     CezaVade = 2 * 3600,     -- s (gerçek zaman); dolunca Çığırtkan gider
     MemurPayi = 0.15,        -- tahsil edilen cezadan kesen memura giden pay; kalanı Hazine'ye
     CezaCarpani = 1,         -- kararnameyle değişir

     -- ==== Sala de rastros ====
     SinsioskopKisi = 2,
     SinsioskopToplam = 12,
     SinsioskopYaricap = 1500,
     SinsioskopCan = 60,
     SinsioskopBekleme = 25,  -- aynı dedektör iki ihbar arasında en az (sn)
     PrioriBoy = 10,          -- asanın hatırladığı büyü sayısı
     PrioriOmur = 1800,       -- s; daha eski büyüler silikleşir (listelenmez)
     PrioriSure = 4,          -- inceleme süresi (sn)
     TabuSure = 600,
     TabuBekleme = 1800,
     TabuUcret = 25,
     TabuEnAz = 4,

     -- ==== Olay / sevk ====
     IhbarBekleme = 60,
     IhbarMaks = 220,         -- harf
     OlayOmru = 1200,         -- s; üstlenilmeyen olay kendiliğinden kapanır
     OlayAzami = 80,          -- açık olay sınırı (eskiler kapanır)
     NotSure = 14,            -- kâğıt uçak notunun ekranda kaldığı süre (sn)

     -- ==== Órdenes ====
     AramaEmriSure = 1200,    -- s
     OdulAzami = 200,

     -- ==== Notificación oficial (yazılı Çığırtkan, [sardon] cigirtkan) ====
     TebligatBekleme = 90,    -- s; bir agente defterden iki tebligat arasında bekler
     TebligatMetin = 360,     -- harf; defterden yazılan tebligatın tavanı

     -- ==== Wizengamot ====
     MahkemeYaricap = 1400,   -- başkanın çevresinde bu yarıçaptakiler salonda sayılır
     OylamaSure = 45,
     AsaMenAzami = 1800,      -- s

     -- ==== Daire masaları ====
     RuhEmiciUcret = 40,
     RuhEmiciSure = 300,
     RuhEmiciAdet = 2,
     HasarOdul = 4,           -- sihirsel hasar olayını kapatan memura Hazine'den
     KurtAdamTanik = 1200,    -- registrossız dönüşümün ihbar olması için tanığın azami uzaklığı

     -- ==== Metin sınırları ====
     BaslikMaks = 80,
     MetinMaks = 1200,
     NotMaks = 400,

     -- Karanlık sayılan büyü kategorileri ([hogwarts] wand hpwrewrite/categories.lua görünen adlar)
     KaranlikKategoriler = {["Ölümcül"] = "Imperdonable / maldición letal", ["Lanetler"] = "Maldición"},
     -- Kategorisi ne olursa olsun karanlık sayılan büyüler (ad -> tür etiketi)
     KaranlikBuyuler = {
          ["Morsmordre"] = "Marca Tenebrosa",
          ["Morsmordre Win"] = "Marca Tenebrosa",
          ["Protego Diabolica"] = "Protección oscura",
     },
     -- Atıldığında bütün mesaidekilere Alarma roja notu giden büyüler
     AlarmBuyuleri = {["Morsmordre"] = true},
}

-- Canlı yeniden yüklemede tablo YERİNDE güncellenir: diğer dosyalar "local A = B.Ayar" tutuyor; yeni
-- tablo atansaydı yenilenmeyen dosyalar eskisini, yenilenenler yenisini okurdu. Decreto etkisiyle
-- çalışma anında değişen ayar (CezaCarpani, sv_8kararname) korunur.
local CALISMA_ANI = {CezaCarpani = true}
B.Ayar = B.Ayar or {}
for k, v in pairs(AYAR) do
     if not (CALISMA_ANI[k] and B.Ayar[k] ~= nil) then B.Ayar[k] = v end
end

-- Nivel de amenaza (GlobalInt "SBTehdit")
B.Tehdit = {
     [0] = {ad = "Normal", alt = "Servicio en régimen normal.", renk = Color(174, 181, 153)},
     [1] = {ad = "En alerta", alt = "Patrullas reforzadas.", renk = Color(223, 193, 128)},
     [2] = {ad = "Alarma roja", alt = "Todos los aurores en servicio.", renk = Color(214, 96, 84)},
}

-- Daireler: Ministerio binasının katlarıyla (kanon). "birimler" yalnızca etiket.
B.Daireler = {
     {id = "makam", ad = "Despacho del Ministro", kisa = "MAKAM", kat = 1, glif = "M",
          aciklama = "Ministro, subsecretario y equipo de apoyo. Decretos, Tesoro, prensa e inspección educativa.",
          birimler = {"Gabinete del Ministro", "Prensa", "Inspección educativa"}},
     {id = "yasa", ad = "Departamento de Aplicación de la Ley Mágica", kisa = "YASA", kat = 2, glif = "Y",
          aciclama = "Aurores, magos de choque y Wizengamot. Investigación, detención y sanciones.",
          birimler = {"Oficina de Aurores", "Magos de choque", "Oficina de uso indebido de la magia", "Consejo de investigación", "Secretaría del Wizengamot"}},
     {id = "kaza", ad = "Departamento de Accidentes y Catástrofes Mágicas", kisa = "KAZA", kat = 3, glif = "K",
          aciclama = "Equipo de reversión de hechizos accidentales y Obliviators. Reparación de daños mágicos.",
          birimler = {"Equipo de reversión", "Obliviators"}},
     {id = "yaratik", ad = "Departamento de Regulación y Control de Criaturas Mágicas", kisa = "YARATIK", kat = 4, glif = "C",
          aciclama = "Registros de hombres lobo y animagus, criaturas peligrosas y envío de dementores.",
          birimler = {"División de bestias", "Registro de hombres lobo", "Registro de animagus"}},
     {id = "ulasim", ad = "Departamento de Transporte Mágico", kisa = "ULAŞIM", kat = 6, glif = "U",
          aciclama = "Oficina de portkeys, licencias de aparición e inspección de escobas.",
          birimler = {"Oficina de portkeys", "Centro de examen de aparición", "Inspección de escobas"}},
     {id = "oyun", ad = "Departamento de Juegos y Deportes Mágicos", kisa = "OYUN", kat = 7, glif = "O",
          aciclama = "Quidditch y permisos de duelo.",
          birimler = {"Liga de Quidditch", "Permisos de duelo"}},
     {id = "esrar", ad = "Departamento de Misterios", kisa = "ESRAR", kat = 9, glif = "E",
          aciclama = "Arcanos. Sala de profecías, cámara de pruebas y expedientes secretos.",
          birimler = {"Sala de profecías", "Cámara de pruebas"}},
}

B.DaireIndex = {}
for i, d in ipairs(B.Daireler) do B.DaireIndex[d.id] = d d.sira = i end

function B.DaireAd(id, kisa)
     local d = B.DaireIndex[id or ""]
     if not d then return kisa and "SIN ASIGNAR" or "Departamento sin asignar" end
     return kisa and d.kisa or d.ad
end

-- Resmî tebligat türleri (yazılı Çığırtkan; B.Tebligat sv_2sicil.lua). kisa: belge numarasındaki kısaltma
B.TebligatTema = {
     ihtar = {tur = "Apercibimiento", kisa = "İHT", damga = "Último apercibimiento", renk = {150, 22, 28}},
     celp = {tur = "Citación", kisa = "CLP", damga = "Citado", renk = {92, 46, 128}},
     hukum = {tur = "Notificación de sentencia", kisa = "HKM", damga = "Firme", renk = {44, 40, 52}},
     arama = {tur = "Notificación de orden de registro", kisa = "ARM", damga = "Orden de registro", renk = {128, 74, 24}},
     kinama = {tur = "Amonestación", kisa = "KNM", damga = "Amonestado", renk = {150, 22, 28}},
     iptal = {tur = "Notificación de anulación", kisa = "İPT", damga = "Anulado", renk = {150, 22, 28}},
     uyari = {tur = "Advertencia", kisa = "UYR", damga = "Advertido", renk = {160, 96, 20}},
     bildirim = {tur = "Notificación oficial", kisa = "TBL", damga = "Notificado", renk = {34, 58, 110}},
}
-- Defterden elle gönderilebilenler (sırasıyla)
B.TebligatElle = {"celp", "ihtar", "uyari", "bildirim"}

-- Sınıf eşlemesi. Anahtar Helix sınıf uniqueID'si = klasör_dosya (classes/bakanlik/sh_avukat.lua ->
-- "bakanlik_avukat"). kademe 1..5; sira = kadro listesinde sıralama; zincir = Auror rütbe
-- merdivenindeki basamak; serbest = daire/unvan defterden atanır; ozel = adlı karakter rolü
-- (defterden atanamaz). Burada olmayan sınıf (Ruh Emici, Molly Weasley...) defteri kullanamaz.
B.Siniflar = {
     bakanlik_buyubakan = {daire = "makam", kademe = 5, sira = 100, unvan = "Ministro de Magia", bakan = true},
     bakanlik_mustesar = {daire = "makam", kademe = 5, sira = 95, unvan = "Subsecretario"},
     bakanlik_vekil = {daire = "makam", kademe = 4, sira = 90, unvan = "Viceministro"},
     bakanlik_bartemis_crouch_sr = {daire = "yasa", kademe = 4, sira = 86, unvan = "Presidente de departamento", ozel = true},
     bakanlik_seherbaz_buro = {daire = "yasa", kademe = 4, sira = 85, birim = "Oficina de Aurores", unvan = "Jefe de la Oficina de Aurores"},
     bakanlik_seherbaz_buroyard = {daire = "yasa", kademe = 4, sira = 84, birim = "Oficina de Aurores", unvan = "Subjefe de oficina"},
     bakanlik_sorusturnabaskan = {daire = "yasa", kademe = 4, sira = 83, birim = "Consejo de investigación", unvan = "Presidente del Consejo de investigación"},
     bakanlik_esrarbuyubakani = {daire = "esrar", kademe = 4, sira = 83, unvan = "Presidente del Departamento de Misterios"},
     bakanlik_sorusturnaca = {daire = "yasa", kademe = 2, sira = 34, birim = "Consejo de investigación", unvan = "Agente de investigación"},
     bakanlik_hitwizard = {daire = "yasa", kademe = 2, sira = 32, birim = "Magos de choque", unvan = "Mago de choque"},
     bakanlik_avukat = {daire = "yasa", kademe = 2, sira = 30, birim = "Wizengamot Kalemi", unvan = "Abogado", avukat = true},
     bakanlik_gelecek_posta_gorevli = {daire = "makam", kademe = 1, sira = 12, birim = "Prensa", unvan = "Redactor de El Profeta"},
     bakanlik_bakanlikcalisani = {kademe = 1, sira = 10, unvan = "Funcionario del Ministerio", serbest = true},

     seherbaz_lider = {daire = "yasa", kademe = 4, sira = 80, zincir = 10, birim = "Oficina de Aurores", unvan = "Lider Auror"},
     seherbaz_general = {daire = "yasa", kademe = 4, sira = 78, zincir = 9, birim = "Oficina de Aurores", unvan = "Auror Generali"},
     seherbaz_bas = {daire = "yasa", kademe = 4, sira = 76, zincir = 8, birim = "Oficina de Aurores", unvan = "Auror jefe"},
     seherbaz_sef = {daire = "yasa", kademe = 4, sira = 74, zincir = 7, birim = "Oficina de Aurores", unvan = "Comandante de aurores"},
     seherbaz_seckin = {daire = "yasa", kademe = 3, sira = 60, zincir = 6, birim = "Oficina de Aurores", unvan = "Auror distinguido"},
     seherbaz_kidemli = {daire = "yasa", kademe = 3, sira = 58, zincir = 5, birim = "Oficina de Aurores", unvan = "Auror senior"},
     seherbaz_usta = {daire = "yasa", kademe = 3, sira = 56, zincir = 4, birim = "Oficina de Aurores", unvan = "Auror experto"},
     seherbaz_uzman = {daire = "yasa", kademe = 2, sira = 44, zincir = 3, birim = "Oficina de Aurores", unvan = "Auror especialista"},
     seherbaz_seherbazss = {daire = "yasa", kademe = 2, sira = 42, zincir = 2, birim = "Oficina de Aurores", unvan = "Auror"},
     seherbaz_stajyer = {daire = "yasa", kademe = 1, sira = 20, zincir = 1, birim = "Oficina de Aurores", unvan = "Auror en prácticas"},
     seherbaz_hitwizard = {daire = "yasa", kademe = 2, sira = 32, birim = "Magos de choque", unvan = "Mago de choque"},
     seherbaz_alostor_moody = {daire = "yasa", kademe = 3, sira = 62, birim = "Oficina de Aurores", unvan = "Auror", ozel = true},
     seherbaz_kingsley = {daire = "yasa", kademe = 3, sira = 62, birim = "Oficina de Aurores", unvan = "Auror", ozel = true},
     seherbaz_nymphadora_tonks = {daire = "yasa", kademe = 2, sira = 46, birim = "Oficina de Aurores", unvan = "Auror", ozel = true},
     seherbaz_potter = {daire = "yasa", kademe = 2, sira = 46, birim = "Oficina de Aurores", unvan = "Auror", ozel = true},
     seherbaz_sirius = {daire = "yasa", kademe = 2, sira = 46, birim = "Oficina de Aurores", unvan = "Auror", ozel = true},
}

-- Fraksiyonda olup sınıfı eşlemede bulunmayan (sınıfsız) karakterin varsayılanı. false = erişim yok.
B.SinifsizKademe = {["Büyü Bakanlığı"] = false, ["Seherbazlık"] = 1}

-- Olay türleri: ad, hangi dairelere not gider, atráslik (1 düşük .. 4 acil)
B.OlayTur = {
     ihbar = {ad = "Denuncia ciudadana", daire = {"yasa"}, oncelik = 2},
     dilekce = {ad = "Petición", daire = {"makam"}, oncelik = 1},
     soygun = {ad = "Robo de vivienda", daire = {"yasa"}, oncelik = 3},
     karanlik = {ad = "Rastro de magia oscura", daire = {"yasa"}, oncelik = 3},
     sinsioskop = {ad = "Sinsioscopio silenciado", daire = {"yasa"}, oncelik = 2},
     tabu = {ad = "Tabú violado", daire = {"yasa"}, oncelik = 3},
     gozalti = {ad = "Detención", daire = {"yasa"}, oncelik = 1},
     alarm = {ad = "Alarma roja", daire = {"yasa", "makam"}, oncelik = 4},
     takviye = {ad = "Llamada de refuerzos", daire = {"yasa"}, oncelik = 4},
     firar = {ad = "Fuga de Azkaban", daire = {"yasa", "makam"}, oncelik = 4},
     ruhemici = {ad = "Ataque de Dementor", daire = {"yasa", "yaratik"}, oncelik = 2},
     yaratik = {ad = "Criatura peligrosa", daire = {"yaratik"}, oncelik = 2},
     kurtadam = {ad = "Hombre lobo no registrado", daire = {"yaratik", "yasa"}, oncelik = 3},
     hasar = {ad = "Daño mágico", daire = {"kaza"}, oncelik = 1},
     hafiza = {ad = "Hechizo de memoria", daire = {"kaza"}, oncelik = 1},
     durusma = {ad = "Vista del Wizengamot", daire = {"yasa", "makam"}, oncelik = 2},
}

B.OlayDurum = {yeni = "Nuevo", yolda = "De camino", yerinde = "En el lugar", kapali = "Cerrado"}
B.OncelikAd = {"Baja", "Normal", "Alta", "URGENTE"}

-- Ruhsat / registros türleri (sicilde "ruhsat" kaydı; mekanik etkisi yok, RP ve suç dayanağı)
B.Ruhsatlar = {
     {id = "cisimlenme", ad = "Licencia de aparición", daire = "ulasim"},
     {id = "supurge", ad = "Registro de escoba", daire = "ulasim"},
     {id = "portkey", ad = "Permiso de fabricación de portkey", daire = "ulasim"},
     {id = "animagus", ad = "Registro de animagus", daire = "yaratik"},
     {id = "kurtadam", ad = "Registro de hombre lobo", daire = "yaratik"},
     {id = "yaratik", ad = "Permiso de cría de criaturas", daire = "yaratik"},
     {id = "duello", ad = "Permiso de duelo", daire = "oyun"},
     {id = "quidditch", ad = "Licencia de Quidditch", daire = "oyun"},
}

B.RuhsatIndex = {}
for _, r in ipairs(B.Ruhsatlar) do B.RuhsatIndex[r.id] = r end

-- Marcadores del expediente (kişi dosyasının üstünde rozet)
B.Bayraklar = {
     {id = "tehlikeli", ad = "Peligroso"},
     {id = "silahli", ad = "Usa magia oscura"},
     {id = "firari", ad = "Proclive a fugarse"},
     {id = "muhbir", ad = "Informante"},
     {id = "koruma", ad = "Bajo protección"},
}

-- 11-13 opt: B.Kanca her çağrıda {xpcall(...)} tablosu kuruyordu (HUD gibi kare başı kancalarda da). Aynı sonuç
-- tablosuz: hata metni aynı; başarıda fn'in dönüşleri eskisi gibi (unpack(sonuc, 2, table.maxn(sonuc))) sondaki
-- nil'ler atılarak döner: hiç dönmeyen ya da yalnız nil dönen kanca yine "değer yok" döner.
local function kancaIlk(n, a, ...)
     if n <= 1 then return a end
     return a, kancaIlk(n - 1, ...)
end

local function kancaSonuc(olay, ok, ...)
     if not ok then
          local hata = ...
          ErrorNoHalt("[Sardon Ministerio] '" .. olay .. "' kancası hata verdi:\n" .. tostring(hata) .. "\n")
          return
     end
     local n = select("#", ...)
     if n == 0 or select(n, ...) ~= nil then return ... end
     repeat n = n - 1 until n == 0 or select(n, ...) ~= nil
     if n == 0 then return end
     return kancaIlk(n, ...)
end

-- Kanca: hook.Add ile aynı, ama hatayı yutar. Başka eklentilerin olaylarına (büyü atışı, sohbet,
-- karakter yükleme, tuş basma…) bağlanan kodumuz hata verirse o olayın geri kalanı bozulmasın.
function B.Kanca(olay, kimlik, fn)
     hook.Add(olay, kimlik, function(...)
          return kancaSonuc(olay, xpcall(fn, debug.traceback, ...))
     end)
end

B.NW_GOREV = "SBGorev"
B.NW_TUTUKLU = "SBDetenido"
B.NW_TUTUKLU_BITIS = "SBDetenidoBitis"
B.NW_EKIP = "SBEkip"
B.NW_ARANAN = "SBAranan"

----------------------------------------------------------------------------------------
-- Ortak küçük yardımcılar
----------------------------------------------------------------------------------------
local BUYUK = {["i"] = "İ", ["ı"] = "I", ["ç"] = "Ç", ["ş"] = "Ş", ["ğ"] = "Ğ", ["ü"] = "Ü", ["ö"] = "Ö"}
function B.Buyuk(s)
     s = string.gsub(tostring(s or ""), "[%z\1-\127\194-\244][\128-\191]*", function(c) return BUYUK[c] or c end)
     return string.upper(s)
end

local KUCUK = {["İ"] = "i", ["I"] = "ı", ["Ç"] = "ç", ["Ş"] = "ş", ["Ğ"] = "ğ", ["Ü"] = "ü", ["Ö"] = "ö"}
function B.Kucuk(s)
     s = string.gsub(tostring(s or ""), "[%z\1-\127\194-\244][\128-\191]*", function(c) return KUCUK[c] or c end)
     return string.lower(s)
end

function B.Sure(sn)
     s = math.max(0, math.ceil(tonumber(sn) or 0))
     if s >= 3600 then return string.format("%d h %02d min", math.floor(sn / 3600), math.floor(sn % 3600 / 60)) end
     return string.format("%02d:%02d", math.floor(sn / 60), s % 60)
end

function B.SureUzun(sn)
     s = math.max(0, math.floor(tonumber(sn) or 0))
     if s >= 3600 then return math.floor(sn / 3600) .. " h " .. math.floor(sn % 3600 / 60) .. " min" end
     if s >= 60 then return math.floor(sn / 60) .. " min" .. (sn % 60 > 0 and (" " .. s % 60 .. " s") or "") end
     return s .. " s"
end

local AYLAR = {"enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"}
function B.Tarih(zaman, saatli)
     local t = os.date("*t", tonumber(zaman) or os.time())
     local s = t.day .. " " .. AYLAR[t.month]
     if saatli == false then return s .. " " .. t.year end
     return s .. " " .. string.format("%02d:%02d", t.hour, t.min)
end

-- "3  min atrás"
function B.Once(zaman)
     local f = math.max(0, os.time() - (tonumber(zaman) or 0))
     if f < 60 then return "hace un momento" end
     if f < 3600 then return math.floor(f / 60) .. "  min atrás" end
     if f < 86400 then return math.floor(f / 3600) .. " h atrás" end
     return math.floor(f / 86400) .. " d atrás"
end

function B.Para(miktar)
     miktar = math.floor(tonumber(miktar) or 0)
     if ix and ix.currency and ix.currency.Get then return ix.currency.Get(miktar) end
     return miktar .. " Galleon"
end

-- Serbest metni kırp, satır sonu/denetim karakterlerini temizle
function B.Metin(s, maks, cokSatir)
     s = tostring(s or "")
     s = string.gsub(s, "[%z\1-\9\11-\31]", " ")
     if not cokSatir then s = string.gsub(s, "\n", " ") end
     s = string.Trim(s)
     if maks and #s > maks then
          s = string.sub(s, 1, maks)
          -- yarım kalan UTF-8 dizisini at
          s = string.gsub(s, "[\194-\244][\128-\191]*$", function(son)
               local b = string.byte(son, 1)
               local gerek = b >= 240 and 4 or (b >= 224 and 3 or 2)
               return #son == gerek and son or ""
          end)
     end
     return s
end
