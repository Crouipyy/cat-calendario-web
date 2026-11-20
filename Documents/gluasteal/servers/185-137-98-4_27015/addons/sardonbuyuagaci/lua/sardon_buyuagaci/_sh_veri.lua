-- "addons\\sardonbuyuagaci\\lua\\sardon_buyuagaci\\_sh_veri.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Büyü Ağacı :: 9 ağaç, her biri 3 dal ve 5 kademe (200 büyü).
-- _sh_config.lua'dan sonra yüklenir (alfabetik: "_sh_c" < "_sh_v").
--
-- Yerleşim 2026-10-11'de planlayıcı sitesinden (buyu-agaci-planlayici) gelen plana göre kuruldu.
-- 2026-11-13 kullanıcı listesi: kademe/yol taşımaları; Holy Hell, Dimentio, Omnilardius, Chibiterasu çıkarıldı.
--            Aynı gün Alohomora ve Finite Temel'e geri alındı.
--
-- Düğüm: {büyü adı, kademe 1-5, dal 1-3}. Büyü adı HpwRewrite:AddSpell'deki adla birebir aynı olmalı;
-- sunucuda olmayan büyü ağaçta "yüklü değil" diye görünür ve zinciri koparmaz.
-- Ön koşul kendiliğinden kurulur: aynı daldaki en yakın alt kademe düğümlerinden BİRİ açık olmalı;
-- dalın en alt düğümü ağacın Temel düğümlerinden birine bağlanır. Elle vermek için 4. alan: {"A", "B"}.
--
-- gelisim: kademe kilidinin bakacağı Karakter Gelişimi dalı (Shine Admin'den değiştirilebilir).
--          Ağaç listesi de sayfada bu dala göre başlık altında toplanır (BA.Gruplar).
-- arma: asa menüsü kitap temasındaki kategori armalarından biri (12_kitap_doku_*.lua).

local BA = SardonBuyuAgaci

local function D(buyu, kademe, dal, gerekAd)
     return {buyu = buyu, kademe = kademe, dal = dal, gerekAd = gerekAd}
end

BA.Agaclar = {
     {
          id = "iksir", ad = "İksir", arma = "cat_healing", gelisim = "iksir",
          renk = Color(132, 196, 120),
          ust = "KAZAN · ÖZ · PANZEHİR",
          aciklama = "Kazanın başındaki sabır asanın ucuna taşınır: kaynar özler, sinsi zehirler ve onları çözen panzehirler.",
          dallar = {"I. Yol", "II. Yol", "III. Yol"},
          dugumler = {
               D("Aguamenti", 1, 1),
               D("Flarus", 2, 1),
               D("Deletrius", 3, 1),
               D("Vapor", 4, 1),
               D("Aglaures Tears", 5, 1),

               D("Aguacalidi", 1, 2),
               D("Lightborne", 2, 2),
               D("Frigus", 3, 2),
               D("Venenum Subsisto", 4, 2),
               D("Crepitus Inpulsa", 4, 2),
               D("Damnare Anguis", 5, 2),

               D("Depulso", 1, 3),
               D("Reducto", 2, 3),
               D("Fireball", 2, 3),
               D("Immobulus", 3, 3),
               D("Iniectio", 4, 3),
               D("Confringo", 5, 3),
               D("Deprimo", 5, 3)
          }
     },
     {
          id = "lanet", ad = "Lanet", arma = "cat_curse", gelisim = "lanet",
          renk = Color(196, 86, 78),
          ust = "UĞURSUZLUK · İŞKENCE · KARA LANET",
          aciklama = "Küçük nahoşluklarla başlayan yol, en karanlık lanetlere iner. Her basamak bedenden çok ruhu yorar.",
          dallar = {"I. Yol", "II. Yol", "III. Yol"},
          dugumler = {
               D("Colloshoo", 1, 1),
               D("Flatso", 1, 1),
               D("Babbling Curse", 1, 1),
               D("Conjunctivitis Curse", 2, 1),
               D("Slagus Erectos", 2, 1),
               D("Anguish", 3, 1),
               D("Gonfiare", 3, 1),
               D("Gonfiare Infernum", 4, 1),
               D("Black Cineres Maxima", 4, 1),
               D("Avada kedavra", 5, 1),

               D("Inepta", 1, 2),
               D("Labellum", 1, 2),
               D("Petrificus Totalus", 1, 2),
               D("Black Cineres", 2, 2),
               D("Imferedem Secrum", 3, 2),
               D("Winborium", 3, 2),
               D("Mortis Tenebris", 4, 2),
               D("Winborium Duo", 4, 2),
               D("Winborium Maxima", 5, 2),
               D("Fulgur Merlin", 5, 2),

               D("Tarantallegra", 1, 3),
               D("Virtus", 2, 3),
               D("Ear shrivelling Curse", 2, 3),
               D("Moribunda", 3, 3),
               D("Morietur", 4, 3),
               D("Sectumsempra", 5, 3),
               D("Suppression", 5, 3)
          }
     },
     {
          id = "tilsim", ad = "Tılsım", arma = "cat_physics", gelisim = "tilsim",
          renk = Color(222, 192, 112),
          ust = "HAREKET · İTME-ÇEKME · NESNE",
          aciklama = "Nesnelere ve bedene niyet işlemek: havaya kaldır, hızlan, sıçra, kilidi aç, kırılanı onar ya da engeli yerinden söküp at.",
          dallar = {"I. Yol", "II. Yol", "III. Yol"},
          dugumler = {
               D("Speedom", 1, 1),
               D("Speedavec", 1, 1),
               D("Arrow-shooting spell", 2, 1),
               D("Everte Statum", 2, 1),
               D("Incarcerous", 2, 1),
               D("Aeternum", 3, 1),
               D("Reparo", 3, 1),
               D("Aeternum Maxima", 4, 1),
               D("Reparo Maxima", 4, 1),
               D("Aeternum Totalum", 5, 1),

               D("Salire", 1, 2),
               D("Spongify", 1, 2),
               D("Wingardium Leviosa", 1, 2),
               D("Capriole", 2, 2),
               D("Arresto Momentum", 2, 2),
               D("Legimmio", 2, 2),
               D("Legimmio Maxima", 3, 2),
               D("Auxillium", 3, 2),
               D("Fulgur Totalum", 4, 2),
               D("Cineres Maxima", 4, 2),
               D("Protego Firestorm", 5, 2),

               D("Alarte Ascendare", 1, 3),
               D("Punchek", 1, 3),
               D("Ascendio", 1, 3),
               D("Punchek Duo", 2, 3),
               D("Alohomora", 1, 3),
               D("Cineres Comet", 2, 3),
               D("Emancipare", 2, 3),
               D("Expulso", 3, 3),
               D("Bombarda", 3, 3),
               D("Bombarda Maxima", 4, 3),
               D("Protego Diabolica", 5, 3)
          }
     },
     {
          id = "saklanma", ad = "Saklanma", arma = "cat_app", gelisim = "syb",
          renk = Color(132, 156, 178),
          ust = "GÖRÜNMEZLİK · KAÇIŞ · SEZGİ",
          aciklama = "Gözden kaybolmanın, iz bırakmadan çekilmenin ve saklananı sezmenin sessiz sanatı.",
          dallar = {"I. Yol", "II. Yol", "III. Yol"},
          dugumler = {
               D("Fallaciae", 1, 1),
               D("Fire Solis", 1, 1),
               D("Occulto", 2, 1),
               D("Carpe Retractum", 2, 1),
               D("Homonculous", 3, 1),
               D("Acriea", 4, 1),

               D("Fumos", 1, 2),
               D("Fumus Obscura", 2, 2, {"Fumos"}),
               D("Home Teleport", 2, 2),
               D("Homenum revelio", 3, 2),
               D("Obscuro", 3, 2),
               D("Salvio Hexia", 4, 2),
               D("Dragoner", 5, 2),

               D("Silentium", 1, 3),
               D("Expelliarmus", 1, 3),
               D("Exanimum", 2, 3),
               D("Muffliato", 3, 3),
               D("Stomp", 4, 3),
               D("Spiritum", 5, 3)
          }
     },
     {
          id = "bicim", ad = "Biçim Değiştirme", arma = "cat_trans", gelisim = "baskalasim",
          renk = Color(172, 136, 206),
          ust = "BOYUT · ÖZ DÖNÜŞÜM · HEDEF DÖNÜŞÜM",
          aciklama = "Maddenin dilini öğren: rengini, boyutunu, en sonunda da canlının kendisini değiştir.",
          dallar = {"I. Yol", "II. Yol", "III. Yol"},
          dugumler = {
               D("Book a mons", 1, 1),
               D("Engorgio", 2, 1),
               D("Brevis Circuitous", 2, 1),
               D("Engorgio Skullus", 3, 1),
               D("Ratte", 3, 1),
               D("Guffia", 4, 1),
               D("Reducio", 4, 1),

               D("Colovaria", 1, 2),
               D("Descendo", 2, 2),
               D("Gravitas", 3, 2),
               D("Oppugno", 3, 2),
               D("Revelio", 3, 2),
               D("Gigante", 4, 2),
               D("Skelett", 4, 2),
               D("Nulla Virtus", 5, 2),

               D("Avis", 1, 3),
               D("Orchideous", 1, 3),
               D("Avis Sard", 2, 3),
               D("Candy Avis", 2, 3),
               D("Vera Verto", 3, 3),
               D("Switching Spell", 4, 3)
          }
     },
     {
          id = "sifa", ad = "Şifacılık", arma = "cat_special", gelisim = "sifa",
          renk = Color(176, 222, 172),
          ust = "ONARIM · IŞIK ŞİFASI · DİRİLİŞ",
          aciklama = "Yarayı kapatmakla başlar, ışıkla arındırmaya, en sonunda yitip giden yaşamı geri çağırmaya varır.",
          dallar = {"I. Yol", "II. Yol", "III. Yol"},
          dugumler = {
               D("Episkey", 1, 1),
               D("Episkey Duo", 2, 1),
               D("Episkey Maxima", 3, 1),
               D("Episkey Totalum", 4, 1),
               D("Resecuto", 5, 1),
               D("Healing Reducto", 5, 1),

               D("Sanitatem", 1, 2),
               D("Sanitatem Beneficia", 2, 2),
               D("Sanitatem Maxima", 3, 2),
               D("Sanitatem Totalum", 4, 2),
               D("Sanitatem Ultimo", 4, 2),
               D("Fulgur Tempestas", 4, 2),
               D("Fulgur Sanitatem", 5, 2),

               D("Detoxify", 1, 3),
               D("Heal", 2, 3),
               D("Devotion", 2, 3),
               D("Ubi Vulneribus", 2, 3),
               D("Rennervate", 3, 3),
               D("Antihellia", 3, 3),
               D("Healstorm", 3, 3),
               D("Vulnera Sanentur", 4, 3),
               D("Hillium", 5, 3)
          }
     },
     {
          id = "zihnifend", ad = "Zihnifend", arma = "cat_kontrol", gelisim = "ksks",
          renk = Color(112, 162, 222),
          ust = "ZİHİN OKUMA · BULANDIRMA · HAKİMİYET",
          aciklama = "Başkasının zihnine uzanan yol: düşünceyi oku, aklı bulandır, hafızayı sil ve en sonunda iradeyi ele geçir.",
          dallar = {"I. Yol", "II. Yol", "III. Yol"},
          dugumler = {
               D("Lente", 1, 1),
               D("Legilimens", 2, 1),
               D("Levicorpus", 2, 1),
               D("Confusione Nigrum", 3, 1),
               D("Infinitum", 4, 1),
               D("Imperius", 5, 1),

               D("Confundo", 1, 2),
               D("Def", 2, 2),
               D("Raielectro", 2, 2),
               D("Apparition", 2, 2),
               D("Obscuratio", 3, 2),
               D("Subsisto", 4, 2),
               D("Crucio", 5, 2),

               D("Obliviate", 2, 3),
               D("Mimblewimble", 3, 3),
               D("Heyedillio", 4, 3),
               D("Gemini Mortis", 5, 3)
          }
     },
     {
          id = "zihnibend", ad = "Zihnibend", arma = "cat_protecting", gelisim = "ksks",
          renk = Color(182, 112, 204),
          ust = "KALKAN · KARŞI BÜYÜ · BARİYER",
          aciklama = "Zihni ve bedeni kapatan yol: anlık kalkanlardan karşı büyülere, aşılmaz bariyerlere ve Patronus'a uzanır.",
          dallar = {"I. Yol", "II. Yol", "III. Yol"},
          dugumler = {
               D("Protego", 1, 1),
               D("Finite", 1, 1),
               D("Chillus", 3, 1),
               D("Protec", 3, 1),
               D("Refuctus Chillus", 4, 1),
               D("Brokes Lekas", 4, 1),
               D("Protego Custos", 5, 1),

               D("Aeri Protegat", 1, 2),
               D("Colloportus", 2, 2),
               D("Godivillio", 3, 2),
               D("Expecto Patronum", 4, 2),
               D("Duro", 4, 2),
               D("Venuste Subsisto Maxima", 5, 2),
               D("Fianto Duri", 5, 2),

               D("Lux Bulbus", 1, 3),
               D("Lux Vitae", 2, 3),
               D("Lux Imbre", 2, 3),
               D("Daímonas Thrínos", 3, 3),
               D("Magicus Extremos", 4, 3),
               D("Memoria Argentea", 4, 3),
               D("Magicus Maximus", 5, 3),
               D("Magicus Maximortis", 5, 3)
          }
     },
     {
          id = "bitki", ad = "Bitki Bilim", arma = "cat_generic", gelisim = "botanik",
          renk = Color(146, 202, 104),
          ust = "TOPRAK · RÜZGAR · AYAZ",
          aciklama = "Toprağın, suyun ve rüzgarın sabrı: bitkiyi büyüt, rüzgarı düşmanına sal, ayazı bahçene çağır.",
          dallar = {"I. Yol", "II. Yol", "III. Yol"},
          dugumler = {
               D("Watterbalo", 1, 1),
               D("Blattaria", 1, 1),
               D("Impedimenta", 1, 1),
               D("Ventus Ruptus", 2, 1),
               D("Waddiwasi", 2, 1),
               D("Armis Glacies", 3, 1),
               D("Armis Glacies Totalum", 4, 1),
               D("Armis Glacies Maxima", 5, 1),

               D("Leverio", 1, 2),
               D("Ventus", 1, 2),
               D("Ventus Duo", 2, 2),
               D("Lumos", 1, 2),
               D("Vortex", 3, 2, {"Ventus Duo"}),
               D("Herbifors", 3, 2),
               D("Ignis Solis", 4, 2),
               D("Meteora", 5, 2),

               D("Collapsio", 1, 3),
               D("Extinguishing Spell", 2, 3),
               D("Bubblius", 3, 3),
               D("Toxicus Crepitus", 4, 3),
               D("Lumos Maxima", 4, 3),
               D("Vanesco", 5, 3)
          }
     }
}

BA.HaritaKur()

-- Sunucu dosyası/admin taslağı ağaç verisinden önce temizlendiyse yeniden süz
BA.Ayar = BA.AyarTemizle(BA.Ayar)
