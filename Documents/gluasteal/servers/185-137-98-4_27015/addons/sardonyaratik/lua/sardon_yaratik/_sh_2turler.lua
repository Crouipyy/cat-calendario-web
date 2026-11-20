-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\_sh_2turler.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: türler
--
-- Modeller St_prop3 / 3826305324 "magical_pets" paketinden (models/staylofft/pets/), Kabuluk konnie
-- Diagon Alley hayvanat bahçesinden. Ölçümler (2026-10-25, sunucuda):
--   * hepsi +Y'ye bakıyor → yonOfset -90 (varlık ileri = +X)
--   * sekanslar: idle walk run eat pet sleep lie groom swim (+ fly glide uçanlarda); pet döngüsüz
--   * kök hareketi yok (GroundSpeed 0): hız koddan, oynatma hızı hiz/animHiz
--   * renk bodygroup'u "staylofft_color" (yalnız 5 türde)
--
-- Alanlar:
--   sinif        Bakanlık tehlike sınıfı 1..5 (X..XXXXX)
--   olcek        yetişkin model ölçeği (evre ölçeğiyle çarpılır); tahmini, oyunda ayarlanacak
--   renkler      {ad, bg}: bg = staylofft_color bodygroup değeri; efsanevi/disi listesi bunların sırası
--   hiz          yürüme / koşma (birim/sn); animHiz aynı sekansın doğal göründüğü hız
--   adim         ölçülmüş adım hızı (ayak kemiğinin yere bastığı karelerdeki geri kayması, ölçek 1);
--                varsa oynatma hızı hiz / (adim × ölçek) — ayaklar yerde kaymaz
--   besin        sevdiği yemler (Y.Yemler anahtarları); "genel" her türe yarım etkiyle gider
--   ihtiyac      100'den 0'a iniş süresi (saat)
--   urun         canlıyken: {ad (iksir malzemesi), aralik (saat), adet {en az, en çok}} ya da {galleon = {a, b}}
--   olumUrun     ölünce (yalnız vücut parçaları): {ad, adet = {sıradan, nadir, efsanevi}}
--   kulucka      dakika
--   fiyat        dükkân yumurtası fiyatı (nil: satılmaz)
--   rol          omuz / takip (yanında yürür) / yuru (yürüme animasyonu var mı)
--   kutu         ölçek 1'de {boy (ileri), en, yükseklik}: istemcide nişan/etkileşim kutusu
--   sirt         sırtın yüksekliği / kutu yüksekliği (fırçalama noktaları; kemik ölçümünden)
--   suCizgi      swim sekansında su çizgisinin yüksekliği (ölçek 1, kemik ölçümünden; 10-26). Yoksa
--                kutu yüksekliğinin 0.4'ü. Graphorn'un yüzmesi gömük çizilmiş: kökü su yüzeyinde.

local Y = SardonYaratik

local function R(...) -- renk listesi: R("Ad", bg, "Ad", bg ...)
     local t, a = {}, {...}
     for i = 1, #a, 2 do t[#t + 1] = {ad = a[i], bg = a[i + 1]} end
     return t
end

local PET = "models/staylofft/pets/staylofft_%s.mdl"

Y.Turler = Y.Turler or {}
table.Empty(Y.Turler)
table.Merge(Y.Turler, {
     puffskein = {
          ad = "Puffskein", sinif = 2, model = PET:format("puffskein"), olcek = 0.85, kutu = {28, 24, 20}, sirt = 0.7,
          renkler = R("Marrón rojizo", 0, "Gris ceniza", 1, "Cobre", 2, "Ciruela", 3, "Oro", 4, "Rosa rojizo", 5),
          efsanevi = {5}, disi = 6,
          rol = {omuz = true, takip = true, yuru = true},
          hiz = {yuru = 34, kos = 95}, animHiz = {yuru = 34, kos = 95},
          besin = {"genel", "bocek", "ot", "et"},
          ihtiyac = {aclik = 10, temizlik = 18, sevgi = 12},
          urun = {ad = "Ovillo de pelo de Puffskein", aralik = 3, adet = {1, 2}},
          kulucka = 20, fiyat = 25,
          yumurta = {olcek = 1.6, renk = Color(214, 170, 140)},
          omuz = {olcek = 0.45, ust = 4, ileri = 0, sag = 0, yaw = -90},
          aciklama = "Pequeñas criaturas esféricas de pelaje suave. Con su larga lengua rosa limpian desde restos de comida hasta insectos; ronronean al acariciarlas.",
          ozellikler = {"Come cualquier pienso (sin penalización por comida incorrecta)", "Producto: ovillo de pelo — aglutinante en Piel de Graphorn y Antídoto de unicornio"},
     },
     mooncalf = {
          ad = "Ternero lunar", sinif = 2, model = PET:format("mooncalf"), olcek = 0.9, kutu = {30, 24, 47}, sirt = 0.38,
          renkler = R("Plata lunar", 0),
          rol = {takip = true, yuru = true},
          hiz = {yuru = 32, kos = 100}, animHiz = {yuru = 32, kos = 100},
          besin = {"ot"},
          ihtiyac = {aclik = 9, temizlik = 22, sevgi = 10},
          urun = {ad = "Abono lunar plateado", aralik = 4, adet = {1, 2}},
          kulucka = 40, fiyat = 40,
          yumurta = {olcek = 2.2, renk = Color(206, 214, 226)},
          aciklama = "Criaturas tímidas de patas finas y ojos enormes. Solo salen de sus madrigueras en luna llena para danzar; su estiércol plateado es un abono único para plantas mágicas.",
          ozellikler = {"Producto: abono lunar plateado — en maceta hace crecer la planta más rápido que el abono de dragón", "Danza nocturna: al terminar, guarda abono extra en la bolsa (2 por noche)"},
     },
     diricawl = {
          ad = "Diricawl", sinif = 2, model = PET:format("diricawl"), olcek = 0.9, kutu = {40, 30, 36}, sirt = 0.5,
          renkler = R("Natural", 0),
          rol = {takip = true, yuru = true},
          hiz = {yuru = 36, kos = 120}, animHiz = {yuru = 36, kos = 120},
          besin = {"bocek", "ot"},
          ihtiyac = {aclik = 9, temizlik = 16, sevgi = 14},
          urun = {ad = "Pluma de Diricawl", aralik = 4, adet = {1, 2}},
          kulucka = 30, fiyat = 35,
          yumurta = {olcek = 2.0, renk = Color(226, 204, 168)},
          aciklama = "Aves rechonchas como ovillos de plumas: no vuelan, pero se teletransportan ante el peligro. Los muggles las llaman «dodo» y creen que están extinguidas.",
          ozellikler = {"Producto: pluma de Diricawl — poción Salto de Diricawl", "Si bajas de vida a su lado, te teletransporta lejos del peligro (cada 2 h)"},
     },
     jobberknoll = {
          ad = "Jobberknoll", sinif = 2, model = PET:format("jobberknoll"), olcek = 0.6, kutu = {34, 16, 22}, sirt = 0.5,
          renkler = R("Azul cielo", 0, "Azul moteado", 1, "Azul hielo", 2, "Plata", 3, "Esmeralda", 4),
          efsanevi = {4}, disi = 5,
          rol = {omuz = true, takip = true, yuru = true},
          hiz = {yuru = 26, kos = 70}, animHiz = {yuru = 26, kos = 70},
          besin = {"bocek"},
          ihtiyac = {aclik = 8, temizlik = 16, sevgi = 14},
          urun = {ad = "Pluma de Jobberknoll", aralik = 5, adet = {1, 1}},
          kulucka = 30, fiyat = 40,
          yumurta = {olcek = 1.4, renk = Color(150, 196, 236)},
          omuz = {olcek = 0.5, ust = 3, ileri = 0, sag = 0, yaw = -90},
          aciklama = "Pequeño pájaro azul moteado que no emite sonido en toda su vida. Al morir, grita al revés todos los sonidos que escuchó, en un largo alarido.",
          ozellikler = {"Producto: pluma de Jobberknoll — Poción del Testigo", "Testigo silencioso: recuerda lo oído a tu lado / en el hombro (E › Escuchar); al morir, lo grita al revés"},
     },
     bowtruckle = {
          ad = "Bowtruckle", sinif = 2, model = "models/konnie/diagonalley/zoo/bowtruckle.mdl", olcek = 1, kutu = {12, 10, 12}, sirt = 0.6,
          renkler = R("Corteza", 0),
          rol = {omuz = true, takip = false, yuru = false},
          anim = {idle = "idle1", idle2 = "idle2", idle3 = "idle3"},
          yonOfset = 0,
          hiz = {yuru = 0, kos = 0}, animHiz = {yuru = 1, kos = 1},
          besin = {"agacbiti"},
          ihtiyac = {aclik = 12, temizlik = 30, sevgi = 16},
          urun = {ad = "Hoja de Bowtruckle", aralik = 4, adet = {1, 2}},
          kulucka = 25, fiyat = 30,
          yumurta = {olcek = 1.4, renk = Color(120, 140, 90)},
          omuz = {olcek = 0.7, ust = 1, ileri = 0, sag = 0, yaw = 0},
          aciklama = "Criaturas tímidas de unos veinte centímetros, hechas de corteza y ramitas. Defienden a muerte los árboles de varita donde anidan; sus dedos como agujas abren cerraduras.",
          ozellikler = {"Solo come piojo de árbol", "No camina: se lleva al hombro o en la mano", "Producto: hoja de Bowtruckle — poción Susurro de cerradura", "En el hombro facilita Alohomora y abre cerraduras en silencio"},
     },
     giantpurpletoad = {
          ad = "Sapo morado gigante", sinif = 3, model = PET:format("giantpurpletoad"), olcek = 0.9, kutu = {30, 24, 22}, sirt = 0.55,
          renkler = R("Morado", 0),
          rol = {takip = true, yuru = true},
          hiz = {yuru = 24, kos = 70}, animHiz = {yuru = 24, kos = 70},
          besin = {"bocek"},
          ihtiyac = {aclik = 12, temizlik = 12, sevgi = 18},
          urun = {ad = "Secreción de sapo morado gigante", aralik = 4, adet = {1, 2}},
          kulucka = 35, fiyat = 60,
          yumurta = {olcek = 1.8, renk = Color(150, 96, 170)},
          aciklama = "Grandes sapos morados cubiertos de verrugas. La secreción de su piel es base de potentes pociones como el Elixir Wiggenweld.",
          ozellikler = {"Producto: secreción de sapo morado gigante — Elixir Wiggenweld"},
     },
     fwooper = {
          ad = "Fwooper", sinif = 3, model = PET:format("fwooper"), olcek = 0.85, kutu = {36, 22, 30}, sirt = 0.5,
          renkler = R("Fucsia", 0, "Limón", 1, "Coral", 2, "Turquesa", 3, "Blanco perla", 4, "Lila", 5),
          efsanevi = {5}, disi = 6,
          rol = {omuz = true, takip = true, yuru = true},
          hiz = {yuru = 30, kos = 90}, animHiz = {yuru = 30, kos = 90},
          besin = {"bocek", "ot"},
          ihtiyac = {aclik = 9, temizlik = 14, sevgi = 12},
          urun = {ad = "Pluma de Fwooper", aralik = 4, adet = {1, 2}},
          kulucka = 45, fiyat = 75,
          yumurta = {olcek = 1.6, renk = Color(236, 120, 196)},
          omuz = {olcek = 0.55, ust = 4, ileri = 0, sag = 0, yaw = -90},
          aciklama = "Ave africana de plumaje brillante. Su canto agrada al principio, pero oírlo demasiado vuelve loco; los dueños deben silenciarlo con regularidad.",
          ozellikler = {"Producto: pluma de Fwooper — poción Nana de Fwooper", "Su canto enloquece un rato a quien está cerca; E › Silencio (con varita) lo calla 2 días"},
     },
     kneazle = {
          ad = "Kneazle", sinif = 3, model = PET:format("kneazle"), olcek = 0.85, kutu = {48, 18, 28}, sirt = 0.45,
          renkler = R("Moteado", 0),
          rol = {takip = true, yuru = true},
          hiz = {yuru = 44, kos = 170}, animHiz = {yuru = 44, kos = 170},
          besin = {"et"},
          ihtiyac = {aclik = 10, temizlik = 20, sevgi = 12},
          urun = {ad = "Bigote de Kneazle", aralik = 5, adet = {1, 1}},
          kulucka = 45, fiyat = 85,
          yumurta = {olcek = 1.8, renk = Color(196, 150, 96)},
          aciklama = "Criaturas felinas de cola de león y orejas grandes. Detectan al instante a las personas poco fiables o de malas intenciones.",
          ozellikler = {"Solo come carne", "Producto: bigote de Kneazle — Poción de Intuición", "A tu lado silba si alguien te apunta con varita, si hay un hombre lobo o un Graphorn"},
     },
     niffler = {
          ad = "Niffler", sinif = 3, model = PET:format("niffler"), olcek = 0.7, kutu = {34, 16, 15}, sirt = 0.6,
          renkler = R("Azul noche", 0, "Azul mar", 1, "Marrón", 2, "Morado", 3, "Blanco nieve", 4, "Oliva dorado", 5),
          efsanevi = {5}, disi = 6,
          rol = {takip = true, yuru = true},
          hiz = {yuru = 40, kos = 150}, animHiz = {yuru = 40, kos = 150},
          besin = {"bocek", "et"},
          ihtiyac = {aclik = 9, temizlik = 16, sevgi = 10},
          urun = {galleon = {1, 2}, aralik = 6},  -- 2026-11-07 ekonomi (eski 12-30)
          kulucka = 50, fiyat = 125,
          yumurta = {olcek = 1.8, renk = Color(70, 80, 120)},
          aciklama = "Obsesionado con todo lo brillante y dorado. En su bolsa abdominal, ensanchada por magia, guarda joyas y oro que encuentra.",
          ozellikler = {"Producto: galeones (los acumula en la bolsa)", "A tu lado husmea tesoros y cava; E › Carterismo le saca monedas del bolsillo a alguien cercano"},
     },
     hippogriff = {
          ad = "Hipogrifo", sinif = 3, model = PET:format("hippogriff"), olcek = 1.35, kutu = {110, 40, 80}, sirt = 0.56, suCizgi = 36,
          renkler = R("Gris plata", 0, "Marrón", 1, "Ceniza", 2, "Castaño", 3, "Obsidiana", 4),
          efsanevi = {3, 5}, disi = 4,
          rol = {takip = true, yuru = true, binek = true},
          hiz = {yuru = 80, kos = 300}, animHiz = {yuru = 60, kos = 190}, adim = {yuru = 48, kos = 280},
          besin = {"et", "bocek"},
          ihtiyac = {aclik = 8, temizlik = 12, sevgi = 10},
          urun = {ad = "Pluma de hipogrifo", aralik = 5, adet = {1, 2}},
          kulucka = 60, fiyat = 250,
          yumurta = {olcek = 3.2, renk = Color(190, 190, 196)},
          aciklama = "Criaturas orgullosas: mitad águila delante, mitad caballo detrás. Al acercarte hay que mirarlas a los ojos e inclinarse; corren en tierra y vuelan por el cielo.",
          ozellikler = {"Montura: tierra y vuelo — primero saluda (contacto visual + reverencia); volar pide SYB › Equitación", "Producto: pluma de hipogrifo — poción Ligereza de hipogrifo; aerodinámica a mitad de precio en el Taller de escobas"},
     },
     thestral = {
          ad = "Thestral", sinif = 4, model = PET:format("thestral"), olcek = 1.35, kutu = {120, 40, 80}, sirt = 0.62, suCizgi = 40,
          renkler = R("Sombra", 0),
          rol = {takip = true, yuru = true, binek = true},
          hiz = {yuru = 80, kos = 320}, animHiz = {yuru = 60, kos = 200}, adim = {yuru = 51, kos = 370},
          besin = {"et"},
          ihtiyac = {aclik = 10, temizlik = 16, sevgi = 14},
          urun = {ad = "Pelo de Thestral", aralik = 6, adet = {1, 1}},
          kulucka = 90,
          yumurta = {olcek = 3.2, renk = Color(60, 58, 66)},
          aciklama = "Caballos alados de aspecto esquelético. Solo los ven quienes han contemplado y aceptado la muerte; pese a su fama siniesta, son monturas dóciles y con un sentido de la orientación impecable.",
          ozellikler = {"Solo come carne", "Montura: vuelo y Sentido de la dirección (R) — vuela sola al destino; solo la ven quienes Han visto la muerte", "Producto: pelo de Thestral — poción Visión de Thestral"},
     },
     unicorn = {
          ad = "Unicornio", sinif = 4, model = PET:format("unicorn"), olcek = 1.3, kutu = {130, 36, 85}, sirt = 0.55, suCizgi = 36,
          renkler = R("Blanco puro", 0),
          rol = {takip = true, yuru = true},
          hiz = {yuru = 80, kos = 300}, animHiz = {yuru = 60, kos = 200}, adim = {yuru = 46, kos = 330},
          besin = {"ot"},
          ihtiyac = {aclik = 10, temizlik = 10, sevgi = 10},
          urun = {ad = "Crin de unicornio", aralik = 6, adet = {1, 1}},
          olumUrun = {ad = "Cuerno de unicornio", adet = {1, 1, 2}},
          kulucka = 90,
          yumurta = {olcek = 3.0, renk = Color(244, 240, 232)},
          aciklama = "Seres legendarios de blanco plateado puro. Se acercan con más facilidad a mujeres y a personas de intención pura. Beber su sangre aleja la muerte, pero condena a una vida maldita.",
          ozellikler = {"Producto: crin de unicornio — Antídoto de unicornio", "Al morir: cuerno de unicornio"},
     },
     graphorn = {
          ad = "Graphorn", sinif = 5, model = PET:format("graphorn"), olcek = 1, kutu = {300, 90, 170}, sirt = 0.55, suCizgi = 2,
          renkler = R("Gris acorazado", 0),
          rol = {takip = true, yuru = true, binek = true},
          hiz = {yuru = 110, kos = 360}, animHiz = {yuru = 70, kos = 220}, adim = {yuru = 118, kos = 610},
          besin = {"ot", "et"},
          ihtiyac = {aclik = 7, temizlik = 14, sevgi = 16},
          urun = {ad = "Polvo de cuerno de Graphorn", aralik = 8, adet = {1, 1}},
          olumUrun = {ad = "Cuerno de Graphorn", adet = {1, 1, 2}},
          kulucka = 120,
          yumurta = {olcek = 4.0, renk = Color(120, 110, 104)},
          aciklama = "Gigantes agresivos de piel acorazada y tentáculos en la mandíbula. Su piel es tan gruesa que rebota la mayoría de hechizos.",
          ozellikler = {"Montura: tanque terrestre — SHIFT embiste, ESPACIO golpea el suelo; el 40 % de los hechizos rebotan en su lomo", "Producto: polvo de cuerno — poción Piel de Graphorn", "Al morir: cuerno de Graphorn"},
     },
     phoenix = {
          ad = "Fénix", sinif = 4, model = PET:format("phoenix"), olcek = 1, kutu = {44, 22, 30}, sirt = 0.5,
          renkler = R("Llama", 0),
          rol = {omuz = true, takip = true, yuru = true},
          hiz = {yuru = 30, kos = 90}, animHiz = {yuru = 30, kos = 90},
          besin = {"genel", "ot"},
          ihtiyac = {aclik = 16, temizlik = 24, sevgi = 12},
          urun = {ad = "Pluma de fénix", aralik = 12, adet = {1, 1}},
          olumUrun = {ad = "Ceniza de fénix", adet = {1, 1, 1}},
          kulucka = 240,
          yumurta = {olcek = 2.6, renk = Color(236, 120, 60)},
          omuz = {olcek = 0.55, ust = 5, ileri = 0, sag = 0, yaw = -90},
          yenidenDogar = true,
          aciklama = "Al acabar su vida arde y renace de sus propias cenizas. Sus lágrimas curan al instante incluso los venenos más mortales. No se puede capturar en la naturaleza.",
          ozellikler = {"Inmortal: renace como bebé de sus cenizas", "Producto: pluma de fénix — con su ceniza, poción Resurrección del fénix"},
     },
})

-- Ansiklopedi ve dükkân sırası (tehlikeye göre)
Y.TurSirasi = {"puffskein", "mooncalf", "diricawl", "jobberknoll", "bowtruckle", "giantpurpletoad", "fwooper", "kneazle", "niffler", "hippogriff", "thestral", "unicorn", "phoenix", "graphorn"}

-- Ürünler (iksir sistemi "ingredient" eşyası, type = ad). [sardon] iksir sv_handle.lua IngredientIndexList
-- sonuna ve sh_list.lua WIZZPOTIONSINGLIST'e de eklenmeli (kazana atılınca renk/tarif kodu).
Y.Urunler = Y.Urunler or {}
table.Empty(Y.Urunler)
table.Merge(Y.Urunler, {
     ["Ovillo de pelo de Puffskein"] = "models/alchemy/ingredwhiteseedpod.mdl",
     ["Abono lunar plateado"] = "models/alchemy/ingredglowdust.mdl",
     ["Pluma de Diricawl"] = "models/staylofft/default_props/staylofft_default_quill.mdl",
     ["Pluma de Jobberknoll"] = "models/staylofft/default_props/staylofft_default_quill.mdl",
     ["Hoja de Bowtruckle"] = "models/alchemy/ingredginkgoleaf.mdl",
     ["Secreción de sapo morado gigante"] = "models/alchemylab/potion_green.mdl",
     ["Pluma de Fwooper"] = "models/staylofft/default_props/staylofft_default_quill.mdl",
     ["Bigote de Kneazle"] = "models/alchemy/ingredmilkthistleseeds.mdl",
     ["Pluma de hipogrifo"] = "models/staylofft/default_props/staylofft_default_quill.mdl",
     ["Pelo de Thestral"] = "models/alchemy/ingredbloodgrass.mdl",
     ["Crin de unicornio"] = "models/alchemy/ingredlichor.mdl",
     ["Cuerno de unicornio"] = "models/alchemy/ingredunicornhorn.mdl",
     ["Polvo de cuerno de Graphorn"] = "models/alchemy/ingredvampiredust.mdl",
     ["Cuerno de Graphorn"] = "models/alchemy/ingredminotaurhorn.mdl",
     ["Pluma de fénix"] = "models/staylofft/default_props/staylofft_default_quill.mdl",
     ["Ceniza de fénix"] = "models/alchemy/ingredectoplasm.mdl",
     ["Lágrima de fénix"] = "models/alchemy/garridanstears.mdl",
})

-- Animaciones del modelo → nombre en el Libro.
Y.AnimAdlari = {
     {"idle", "Reposo"}, {"walk", "Andar"}, {"run", "Correr"}, {"eat", "Comer"}, {"pet", "Acariciar"},
     {"sleep", "Dormir"}, {"lie", "Tumbarse"}, {"groom", "Acicalar"}, {"swim", "Nadar"}, {"fly", "Volar"}, {"glide", "Planear"},
}

-- Uçabilen türler: hız (birim/sn), vivaryumda uçuş yüksekliği aralığı, yanında uçarken sahibin
-- ne kadar üstünde durduğu. takipYerde: sahibini takip ederken hiç uçmaz, yerden yürür/koşar
-- (vivaryumdaki uçuş turları sürer).
Y.Ucuslar = Y.Ucuslar or {}
table.Empty(Y.Ucuslar)
table.Merge(Y.Ucuslar, {
     fwooper = {hiz = 260, yukseklik = {90, 260}, takip = 70},
     jobberknoll = {hiz = 240, yukseklik = {80, 220}, takip = 60},
     phoenix = {hiz = 320, yukseklik = {120, 340}, takip = 80},
     hippogriff = {hiz = 520, yukseklik = {200, 480}, takip = 150, takipYerde = true},
     thestral = {hiz = 540, yukseklik = {220, 520}, takip = 160},
})

-- Kişilik: vivaryumdaki davranış ağırlıkları. bekle = bekleme animasyonunu baştan sona, gez/kos,
-- otla = yemlik dışında yeme/eşinme, tima = tımar, uzan, uyu = gündüz şekerlemesi, ucus = uçuş turu,
-- su = göl/gölet arar, dans = çember çizerek dans (gece). gececil türler gündüz uyur, gece dolaşır.
Y.Kisilik = Y.Kisilik or {}
table.Empty(Y.Kisilik)
table.Merge(Y.Kisilik, {
     varsayilan = {bekle = 3, gez = 4, kos = 0.6, otla = 0.6, tima = 1.2, uzan = 1, uyu = 0.3},
     puffskein = {bekle = 4, gez = 2.5, kos = 0.3, otla = 0.8, tima = 1.5, uzan = 2, uyu = 0.8},
     mooncalf = {bekle = 2, gez = 3, kos = 0.2, otla = 1.2, tima = 1, uzan = 1, uyu = 0.5, dans = 2.5, gececil = true},
     diricawl = {bekle = 2.5, gez = 4.5, kos = 1, otla = 1.6, tima = 1, uzan = 0.6, uyu = 0.2},
     jobberknoll = {bekle = 3, gez = 2, kos = 0.3, otla = 0.6, tima = 1.8, uzan = 0.4, uyu = 0.3, ucus = 2.5},
     giantpurpletoad = {bekle = 4, gez = 1.5, kos = 0.2, otla = 0.8, tima = 0.6, uzan = 2.5, uyu = 0.6, su = 3},
     fwooper = {bekle = 2.5, gez = 2, kos = 0.4, otla = 0.6, tima = 2, uzan = 0.4, uyu = 0.3, ucus = 3},
     kneazle = {bekle = 3, gez = 2.5, kos = 0.6, otla = 0.3, tima = 2.6, uzan = 3, uyu = 1},
     niffler = {bekle = 1.5, gez = 4, kos = 2.5, otla = 2, tima = 0.6, uzan = 0.5, uyu = 0.3},
     hippogriff = {bekle = 3, gez = 3, kos = 0.8, otla = 1, tima = 2.2, uzan = 1.4, uyu = 0.3, ucus = 0.8},
     thestral = {bekle = 3, gez = 2.5, kos = 0.5, otla = 1, tima = 1.2, uzan = 2, uyu = 0.4, ucus = 0.8},
     unicorn = {bekle = 2.5, gez = 3.5, kos = 1.2, otla = 2.5, tima = 1, uzan = 1, uyu = 0.3},
     graphorn = {bekle = 3, gez = 2.5, kos = 0.4, otla = 2.2, tima = 0.6, uzan = 2, uyu = 0.4, su = 0.5},
     phoenix = {bekle = 3.5, gez = 1.2, kos = 0.2, otla = 0.4, tima = 2.4, uzan = 0.6, uyu = 0.3, ucus = 2},
})
