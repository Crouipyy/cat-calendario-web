-- "addons\\sardonkitap\\lua\\sardon_kitap\\_sh_2metin_b.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kitap :: metinler 2/2 — Jigger, Spore, Scamander, Bagshot, Waffling (statik bölümler)
-- ve keşif sayfalarının notları (bitki, yaratık, yer). Keşif sayfalarının asıl verisi ilgili
-- sistemden okunur: [sardon] agriculture CROPS, [sardon] yaratik Turler, [sardon] hayvan Turler,
-- Helix alanları, [sardon] ollivander Agaclar/Ozler.

local SK = SardonKitap

SK.Metin.jigger = {
     {id = "kazan", baslik = "Kazan Başında Güvenlik", sayfalar = {
          "İksir yapmak sabır işidir. Kazanın başından ayrılan öğrenci, döndüğünde ya bozulmuş bir karışım ya da delinmiş bir kazan bulur. Kollarını sıva, saçını topla, yüzünü buharın tam üstünde tutma.",
          "Malzemeyi tarifteki sırayla ve tarifteki miktarda koy. 'Bir tane fazlası zarar vermez' diyen öğrencinin kazanı genellikle tavana yapışır.",
     }, soru = {"Tarife bir malzeme fazla koymak çoğu zaman ne olur?", {"Karışım bozulur", "İksir güçlenir", "Hiçbir şey olmaz"}, 1}},

     {id = "ates", baslik = "Ateşin Dili", sayfalar = {
          "Her iksirin sevdiği bir ateş vardır. Kaynatma boyunca ateşi birkaç kez ayarlaman gerekir; ibreyi sıcaklığın doğru aralığında tut. Ateş çok güçlüyse karışım yanar, çok zayıfsa öz çözülmez.",
          "İbre oynarken gözünü kazandan ayırma. Doğru aralık her kademede biraz daha daralır; Temel iksirler bağışlayıcıdır, İleri iksirler değildir.",
     }, soru = {"İksirin ateşi çok güçlü olursa ne olur?", {"Karışım yanar", "İksir daha hızlı olur", "Renk değişir ama zarar vermez"}, 1}},

     {id = "karistirma", baslik = "Karıştırmanın Sayısı", sayfalar = {
          "Karıştırma yönü ve sayısı iksirin kaderidir. Saat yönünde karıştırmak özleri birleştirir, saat yönünün tersine karıştırmak ayırır. Tarifteki sayıyı say; ne bir fazla ne bir eksik.",
          "Bu kitabı bitiren öğrenci, Temel düzey tariflerin hepsini kazan başındaki Tarif Defteri'nde görür ve onları şansa bırakmadan kaynatabilir. Sonraki sayfalarda bu tariflerin tamamı yazılıdır.",
     }, soru = {"Saat yönünde karıştırmak ne yapar?", {"Özleri birleştirir", "Özleri ayırır", "Ateşi söndürür"}, 1}},
}

SK.Metin.spore = {
     {id = "onsoz", baslik = "Toprağın Sabrı", sayfalar = {
          "Büyülü bitkiler, büyücülerin en eski yardımcılarıdır. İksirlerin yarısından fazlası bir yaprak, bir kök ya da bir yumruyla başlar. Bitkiyi tanımak, iksiri tanımanın ilk adımıdır.",
          "Bu kitabın sayfaları sen bir bitkiyi ilk kez yetiştirip hasat ettiğinde dolar. Okulun seralarında ya da kendi saksında yetiştirdiğin her bitki, burada kendi sayfasını bulur.",
     }, soru = {"Bu kitapta bir bitkinin sayfası ne zaman dolar?", {"Onu ilk kez hasat ettiğinde", "Kitabı satın aldığında", "Bitkiyi kokladığında"}, 1}},

     {id = "saksi", baslik = "Saksı, Su ve Gübre", sayfalar = {
          "Her bitki susuzluğa farklı dayanır; suyu biten bitki bir süre bekler, sonra solar. Aguamenti saksıyı doldurmanın en kolay yoludur. Ejderha gübresi büyümeyi hızlandırır ama pahalıdır.",
          "Karanlık bitkiler kafatası saksılarını sever; diğerleri sade bir saksıda daha mutludur. Bazı bitkiler hasatta tehlikelidir: Adam otunu kulaklıksız sökmeye kalkma.",
     }, soru = {"Saksıyı doldurmanın en kolay yolu hangisidir?", {"Aguamenti", "Accio", "Lumos"}, 1}},
}

SK.Metin.scamander = {
     {id = "onsoz", baslik = "Yaratık Nedir?", sayfalar = {
          "Büyücüler yüzyıllarca 'yaratık' ile 'varlık' arasındaki sınırı tartıştılar. Konuşabilen her şey varlık mıdır? Konuşan bir trol de var, konuşmayan bir centaur da. Bu kitap, büyücü toplumunun yasalarını anlayamayacak kadar farklı olan canlılara yaratık der.",
          "Bu kitabın sayfaları, bir yaratıkla ilk kez karşılaştığında açılır. Yaratıkları tanımak onlardan korkmamanın, onları korumanın ilk yoludur. — N.A.F.S.",
     }, soru = {"Bu kitapta bir yaratığın sayfası ne zaman açılır?", {"Onunla ilk kez karşılaştığında", "Onu öldürdüğünde", "Kitabı bitirdiğinde"}, 1}},

     {id = "sinif", baslik = "Bakanlık Sınıflandırması", sayfalar = {
          "Sihir Bakanlığı her yaratığa bir tehlike sınıfı verir. X: sıkıcı. XX: zararsız, evcilleştirilebilir. XXX: yetkin bir büyücü baş edebilir. XXXX: tehlikeli, uzmanlık ister. XXXXX: büyücü öldürdüğü bilinen, evcilleştirilemez.",
          "Bir yaratığın sınıfı, onun kötü olduğunu değil, ona nasıl yaklaşman gerektiğini söyler. Bir hipogrife önce eğilerek selam ver; gözünü kırpmadan bekle.",
     }, soru = {"Bakanlık sınıflandırmasında XXXXX ne anlama gelir?", {"Büyücü öldürdüğü bilinen, evcilleştirilemez", "Sıkıcı", "Zararsız ve evcil"}, 1}},
}

SK.Metin.bagshot = {
     {id = "onsoz", baslik = "Önsöz", sayfalar = {
          "Tarih yalnızca kitaplarda değil, taşlarda, köprülerde, göllerde yaşar. Bu kitap sana yazılanı anlatır; gördüğün her önemli yer ise kitaba kendi sayfasını ekler.",
          "Bir yere ilk kez adım attığında sayfası açılır. Okulun her köşesini gezen öğrenci, yıl sonunda bu kitabın neredeyse tamamını kendi ayaklarıyla yazmış olur.",
     }, soru = {"Sihir Tarihi'ne yer sayfaları nasıl eklenir?", {"O yere ilk kez gidince", "Derste not tutunca", "Kitapçıya ödeme yapınca"}, 1}},

     {id = "kurucular", baslik = "Dört Kurucu", sayfalar = {
          "Hogwarts, bin yılı aşkın bir süre önce dört büyük büyücü tarafından kuruldu: Godric Gryffindor, Helga Hufflepuff, Rowena Ravenclaw ve Salazar Slytherin. Her biri öğrencilerinde başka bir erdem aradı: cesaret, sadakat, akıl ve hırs.",
          "Okulun ilk yıllarında kurucular öğrencilerini kendileri seçti. Onlar gittikten sonra bu işi Gryffindor'un eski şapkası üstlendi. Seçmen Şapka bugün hâlâ aynı soruyu sorar: sen kimsin?",
     }, soru = {"Kurucular gittikten sonra öğrencileri hanelere kim yerleştirdi?", {"Seçmen Şapka", "Müdür", "Bakanlık"}, 1}},

     {id = "gizlilik", baslik = "Gizlilik Yasası (1689)", sayfalar = {
          "Uluslararası Büyücülük Gizlilik Yasası 1689'da imzalandı ve 1692'de yürürlüğe girdi. O günden beri büyücüler, Muggle'lardan saklı yaşar. Bakanlıkların en önemli görevi bu gizliliği korumaktır.",
          "Gizlilik bir korkudan doğdu ama bir anlaşmaya dönüştü. Bugün Hogsmeade, Britanya'nın tamamen büyücülerden oluşan tek köyüdür; bunu mümkün kılan da bu yasadır.",
     }, soru = {"Uluslararası Gizlilik Yasası hangi yıl imzalandı?", {"1689", "1492", "1875"}, 1}},
}

SK.Metin.waffling = {
     {id = "kaynak", baslik = "Büyünün Kaynağı", sayfalar = {
          "Büyü doğuştan gelir; öğrenilmez, geliştirilir. Bir büyücü çocuğun ilk büyüsü çoğunlukla kendiliğinden olur: korktuğunda, kızdığında ya da çok sevindiğinde. Okul, bu kendiliğinden gücü yönlendirmeyi öğretir.",
          "Asa, büyüyü yaratmaz; onu toplar ve yönlendirir. Asasız büyü mümkündür ama kaba ve öngörülemezdir. Bu yüzden büyücü ile asası arasındaki uyum, her şeyden önemlidir.",
     }, soru = {"Waffling'e göre asanın büyüdeki görevi nedir?", {"Büyüyü toplar ve yönlendirir", "Büyüyü yaratır", "Büyüyü saklar"}, 1}},

     {id = "secer", baslik = "Asa Büyücüyü Seçer", sayfalar = {
          "Asa ustalarının en eski sözü şudur: asa büyücüyü seçer. Bir asa, sahibini sevebilir, ona alışabilir ya da onu reddedebilir. Başkasının asasıyla yapılan büyü, kendi asanla yapılandan her zaman biraz zayıftır.",
          "Asanın sadakati kazanılabilir de: bir düelloda yenilen büyücünün asası, bazen yenene geçer. Bu yüzden eski asalar, hikâyeleri en uzun olanlardır.",
     }, soru = {"Başkasının asasıyla yapılan büyü için ne söylenir?", {"Kendi asanla yapılandan biraz zayıftır", "Daha güçlüdür", "Hiç çalışmaz"}, 1}},

     {id = "agacoz", baslik = "Ağaç ve Öz", sayfalar = {
          "Her asanın iki ruhu vardır: ağacı ve özü. Ağaç asanın karakterini, öz ise gücünü taşır. Tekboynuz kılı sadık ve tutarlıdır, ejderha yürek teli güçlü ama huysuzdur, anka tüyü en seçici ve en nadirdir.",
          "Sonraki sayfalarda Ollivanders'ın kullandığı ağaçlar ve özler sıralanmıştır. Kendi asanın ağacı ve özü, sayfada altın varakla işaretlidir.",
     }, soru = {"Asanın gücünü daha çok ne taşır?", {"Özü", "Uzunluğu", "Rengi"}, 1}},
}

/*
*   Sihir Tarihi yer sayfaları: Helix alan adında geçen parçalar (küçük harf) → sayfa.
*   Görseli materials/sardon_kitap/ani/<id>.jpg (anı kartı; sv_4dunya istemciye parça parça yollar).
*   Önce gelen sayfanın deseni önce denenir; desenler birbirini kapsamasın.
*/
SK.YERLER = {
     {id = "hogwarts", ad = "Hogwarts", desen = {"ön bahçe", "ön sur", "orta sur"}, metin = "Hogwarts Cadılık ve Büyücülük Okulu, bin yılı aşkın bir süre önce dört büyük büyücü tarafından İskoçya'nın dağları arasında kuruldu. Bir Muggle şatoya baktığında yalnızca 'Tehlike: Girmeyin' yazan bir tabelayla eski bir harabe görür. Kulelerini sayan öğrenci ertesi sabah başka bir sayı bulur; şato sayılmayı sevmez."},
     {id = "hogsmeade", ad = "Hogsmeade", desen = {"hogsmade meydan", "hogsmade değirmen", "hogsmade telefon"}, metin = "Hogsmeade, Britanya'nın tamamen büyücülerden oluşan tek köyüdür. Efsaneye göre Hengist of Woodcroft tarafından, Muggle zulmünden kaçarken kuruldu. Üçüncü yıldan sonra öğrenciler hafta sonları köye inebilir."},
     {id = "ucsupurge", ad = "Üç Süpürge", desen = {"üç süpürge"}, metin = "Hogsmeade'in en sevilen meyhanesi. Kış akşamlarında içerisi tereyağlı birayla ısınan öğrencilerle dolar. Duvarlarında yüzyıllardır aynı kalan bir sıcaklık vardır."},
     {id = "domuzkafasi", ad = "Domuz Kafası", desen = {"domuz kafası"}, metin = "Köyün ara sokağındaki karanlık han. Pencereleri kirden görünmez, müşterileri yüzlerini saklamayı sever. Burada konuşulanlar dışarı çıkmaz; tarih boyunca pek çok gizli toplantı burada yapıldı."},
     {id = "baraka", ad = "Bağıran Baraka", desen = {"bağıran baraka"}, metin = "Britanya'nın en perili binası diye bilinir. Köylüler geceleri içinden gelen çığlıkları hayaletlere yorar; gerçeği bilenler ise susmayı tercih eder."},
     {id = "ollivanders", ad = "Ollivanders", desen = {"ollivanders"}, metin = "Ollivander ailesi MÖ 382'den beri asa yapar. Dükkânın tozlu rafları binlerce kutuyla doludur ve her kutu sahibini bekler. Ollivander her sattığı asayı hatırladığını söyler."},
     {id = "kitapci", ad = "Hogsmeade Kitapçısı", desen = {"hogsmade kitapcı", "hogsmade kitapçı"}, metin = "Kitapçının raflarında birinci sınıfın ders kitaplarından yasaklı bölüm meraklılarının aradığı tuhaf ciltlere kadar her şey bulunur. Bazı kitaplar rafından kaçmamak için zincirle bağlıdır."},
     {id = "buyuksalon", ad = "Büyük Salon", desen = {"büyük salon"}, metin = "Büyük Salon'un tavanı dışarıdaki gökyüzünü gösterecek şekilde büyülenmiştir. Dört uzun hane masası ve öğretmen kürsüsü buradadır. Her yıl Seçmen Şapka töreni bu salonda yapılır."},
     {id = "kutuphane", ad = "Kütüphane", desen = {"kütüphane", "kütüpane"}, metin = "Hogwarts kütüphanesi on binlerce kitaba ev sahipliği yapar. Yasak Bölüm'deki kitaplar yalnızca bir öğretmenin imzalı izniyle okunabilir. Kütüphanede yüksek sesle konuşmak hâlâ en ağır suçlardan sayılır."},
     {id = "karagol", ad = "Kara Göl", desen = {"kara göl", "göl kenarı", "karanlık iskele", "wigen tree gölü"}, metin = "Kara Göl, okulun güneyinde uzanır. Dev bir mürekkep balığı, deniz insanları ve grindylow'lar burada yaşar. Birinci sınıf öğrencileri okula ilk gece fenerli sandallarla bu gölden geçerek gelir."},
     {id = "orman", ad = "Yasak Orman", desen = {"karanlık orman", "karagöl ormanı"}, metin = "Ormanın derinlikleri centaur'lara, akromantulalara ve tekboynuzlara ev sahipliği yapar. Öğrencilerin ormana girmesi yasaktır; yasağın nedeni her yıl birkaç öğrenci tarafından yeniden öğrenilir."},
     {id = "aydinlik", ad = "Aydınlık Orman", desen = {"aydınlık orman", "ateş böceği"}, metin = "Yasak Orman'ın batı ve güney eteklerinde ağaçlar seyrekleşir, güneş yosunlu taşlara kadar iner. Yaz gecelerinde ateş böcekleri burayı yere inmiş bir yıldız haritasına çevirir. Ürkek tekboynuzlar ve bowtruckle'lar en çok bu kısımda görülür; ama orman ne kadar aydınlık olursa olsun, burada yolunu hiç kaybetmemiş öğrenci yoktur."},
     {id = "hagrid", ad = "Hagrid'in Kulübesi", desen = {"hagrid"}, metin = "Ormanın kıyısındaki taş kulübe, okulun anahtar ve arazi bekçisine aittir. Bacasından çıkan duman genellikle kaya gibi sert kurabiyelerin habercisidir."},
     {id = "baykushane", ad = "Baykuşhane", desen = {"baykuşhane", "baykuş kulesi"}, metin = "Okulun baykuşları ve öğrencilerin kendi baykuşları bu kulede yaşar. Zemin saman, tüy ve kemiklerle kaplıdır. Mektup yazmak isteyen öğrenci merdivenleri tırmanmayı göze almalıdır."},
     {id = "astronomi", ad = "Astronomi Kulesi", desen = {"astronomi"}, metin = "Okulun en yüksek kulesidir. Astronomi dersleri gece yarısı burada yapılır; öğrenciler teleskoplarıyla gezegenlerin ve yıldızların konumlarını haritalar."},
     {id = "quidditch", ad = "Quidditch Sahası", desen = {"quidditch"}, metin = "Altı yüksek halka, dört hane tribünü ve rüzgârın hiç dinmediği bir çayır. Hane Kupası için en çok bağırılan yer burasıdır."},
     {id = "merdivenler", ad = "Hareketli Merdivenler", desen = {"hareketli merdivenler"}, metin = "Hogwarts'ın merdivenleri canlı gibidir: bazıları cuma günleri başka yere çıkar, bazılarının bir basamağı kaybolur. Birinci sınıfların en çok geç kalma nedeni bu merdivenlerdir."},
     {id = "zindanlar", ad = "Zindanlar", desen = {"zindan"}, metin = "Şatonun altındaki soğuk koridorlar iksir derslerine ve Slytherin ortak salonuna çıkar. Duvarlardaki nem, kazanların buharıyla hiç kurumaz."},
     {id = "slytherin", ad = "Slytherin Ortak Salonu", desen = {"slytherin ortak", "slytherin hane", "slytherin yatakhane"}, metin = "Zindanların derinliğinde, Kara Göl'ün altına uzanan uzun ve alçak bir salondur. Pencerelerden süzülen yeşil ışık göl suyundan gelir; şanslı olan camın önünden geçen dev mürekkep balığını görür. Giriş çıplak bir taş duvardır ve yalnızca doğru parolayı söyleyene açılır. Salazar Slytherin öğrencilerinde hırs ve beceriklilik aradı."},
     {id = "gryffindor", ad = "Gryffindor Ortak Salonu", desen = {"gryffindor ortak", "gryffindor hane", "gryffindor kulesi", "gryffindor yatakhane"}, metin = "Bir kulenin tepesinde, Şişman Hanım'ın portresinin ardındadır; parolayı bilmeyen kapıda kalır. İçeride kızıl kadife koltuklar, hiç sönmeyen bir şömine ve aslan işlemeli eski halılar vardır. Godric Gryffindor cesareti her erdemin üstünde tuttu; salonun gece yarısına kadar süren gürültüsü bu mirası hâlâ korur."},
     {id = "ravenclaw", ad = "Ravenclaw Ortak Salonu", desen = {"ravenclaw hane", "ravenclaw ortak", "ravenclaw kulesi"}, metin = "Batı kulelerinden birinin tepesindeki yuvarlak salonun kapısında anahtar deliği yoktur; kartal biçimli tokmak bir bilmece sorar ve doğru cevabı vereni içeri alır. Kubbeli tavana yıldızlar boyanmıştır, geniş pencerelerden bütün okul arazisi görünür. Rowena Ravenclaw'a göre ölçüsüz zekâ insanın en büyük hazinesiydi."},
     {id = "hufflepuff", ad = "Hufflepuff Ortak Salonu", desen = {"hufflepuff ortak", "hufflepuff hane", "hufflepuff yatakhane", "hufflepuff kızlar", "hufflepuff evi"}, metin = "Mutfakların yakınındaki bir koridorda, köşedeki büyük fıçı yığınının ardında gizlidir. Doğru fıçıya doğru ritimle vurmayan başından aşağı sirkeyle ıslanır. İçerisi yuvarlak pencereli, toprak altındaki bir yuva kadar sıcaktır. Helga Hufflepuff kapısını kimseye kapatmadı; ama sabırsızlara da açmadı."},
     {id = "sirlar", ad = "Sırlar Odası", desen = {"sırlar odası"}, metin = "Salazar Slytherin'in okul içinde gizlediği söylenen oda. Yüzyıllarca efsane sanıldı. Girişinin yalnızca çatal dilli konuşan bir büyücüye açıldığı anlatılır."},
     {id = "tuvalet", ad = "Tuvaletler", desen = {"tuvalet"}, metin = "Şatonun tuvaletleri ilk bakışta sıradan görünür: soğuk taş, buğulu pencereler, yüzyıllık pirinç musluklar. Yine de kızlar tuvaletinin lavabolarından biri bir zamanlar çok daha derin bir yere açılırdı. Orada ağlayan bir hayalet duyarsan rahatsız etme; ziyaretçileri pek sevmez, sevdiğini söylediğinde bile."},
     {id = "revir", ad = "Revir", desen = {"revir"}, metin = "Okulun şifacısı burada kırık kemikleri bir gecede onarır, yanlış giden büyülerin izlerini siler. Revir'in yatakları Quidditch maçlarından sonra hiç boş kalmaz."},
     {id = "bakanlik", ad = "Sihir Bakanlığı", desen = {"bakanlık", "bakanık", "mahkeme", "büyü bakanı"}, metin = "Bakanlık, Londra'nın altında, Muggle gözlerinden uzakta çalışır. Gizlilik Yasası'nı korur, büyülü yaratıkları sınıflandırır, büyücüleri yargılar. Ziyaretçi girişi eski bir telefon kulübesinden yapılır."},
     {id = "seherbaz", ad = "Seherbaz Bürosu", desen = {"seherbaz"}, metin = "Karanlık büyücüleri yakalamakla görevli seherbazların bürosu. Seherbaz olmak için üstün notlar, sağlam sinirler ve yıllarca süren bir eğitim gerekir."},
     {id = "azkaban", ad = "Azkaban", desen = {"azkaban"}, metin = "Kuzey Denizi'nin ortasındaki büyücü hapishanesi. Yüzyıllarca Ruh Emiciler tarafından korundu; mahkûmların en büyük cezası mutlu anılarının yavaşça ellerinden alınmasıdır."},
     {id = "mezarlik", ad = "Mezarlık", desen = {"mezarlık", "kilise"}, metin = "Eski mezar taşlarının yazıları rüzgârla silinmiş. Burada yatan büyücü ailelerinin hikâyeleri, köyün en yaşlılarının bile yarım hatırladığı efsanelerdir."},
     {id = "akromantula", ad = "Akromantula Mağarası", desen = {"akromantula"}, metin = "Dev örümceklerin yuvası. Akromantulalar konuşabilir, insan etiyle beslenir ve Bakanlık sınıflandırmasında XXXXX'tir. Bu sayfayı okuyorsan, mağaradan sağ çıkmışsın demektir."},
     {id = "tasavlu", ad = "Taş Avlu", desen = {"taş avlu"}, metin = "Şatonun ortasındaki taş avlu, dersler arasında öğrencilerin toplandığı yerdir. Ortadaki çeşmenin suyu kışın bile donmaz."},
     {id = "ortabahce", ad = "Orta Bahçe", desen = {"ortak bahçe", "avlu arka bahçe"}, metin = "Şatonun kalbindeki revaklı bahçe, dört yanı sivri kemerlerle çevrili sessiz bir çimenliktir. Ders aralarında öğrenciler kemerlerin gölgesinde ödev yetiştirir, bahar gelince çimenlere uzanıp kitaplarını unutur. Kemer taşlarına kazınmış adların bazıları kurucuların zamanından kalmadır; kimin kazıdığını kimse itiraf etmez."},
     {id = "kopru", ad = "Uzun Köprü", desen = {"uzun köprü", "köprü yolu", "köprü girişi", "tahta köprü"}, metin = "Şatoyu araziye bağlayan köprü, rüzgârda hafifçe sallanır. Öğrenciler buna alışır; ziyaretçiler genellikle alışmaz."},
     {id = "mudur", ad = "Müdür Odası", desen = {"müdür odası"}, metin = "Taş bir gargoyle'un arkasındaki döner merdivenle çıkılır. Duvarlarda eski müdürlerin portreleri uyur ya da uyuyormuş gibi yapar. Parola sık sık değişir ve genellikle bir şekerin adıdır."},
     {id = "botanik", ad = "Seralar", desen = {"botanik bahçesi", "botanik sınıfı", "botanik girişi", "botanik arka"}, metin = "Botanik dersleri camlı seralarda yapılır. Birinci sera zararsız bitkilerle doludur; üçüncü seraya ise ancak birkaç yıl sonra girmene izin verilir."},
}

/*
*   Bin Büyülü Bitki ve Mantar: bilinen bitkilere elle yazılmış not (yoksa veriden üretilir)
*/
SK.BITKI_NOT = {
     ["Adam Otu"] = "Mandragora. Kökü insan bebeğine benzer, sökülünce çığlık atar; olgun bir adam otunun çığlığı öldürücüdür. Taşlaşmayı geri çeviren iksirlerin temelidir.",
     ["Çığlıkçı Adamotu"] = "Adam otunun daha huysuz akrabası. Kulaklık takmadan yanına yaklaşma.",
     ["Bubotuber Yumrusu"] = "Kalın, kara, sümüklü bir bitkidir. Yumrularındaki irin, sivilce ve çıbanlara karşı birebirdir; seyreltilmeden dokunulursa cildi yakar.",
     ["Kurtboğan"] = "Akonit ya da kurtboğan da denir. Zehirlidir; kurt adamların dönüşümünü yumuşatan iksirin ana malzemesidir.",
     ["Fluxweed Otu"] = "Dolunayda toplanmalıdır. Çok Özlü İksiri'nin olmazsa olmazıdır.",
     ["Shrivelfig Meyvesi"] = "Abyssinia kökenli buruşuk incir. Küçültme iksirlerinde kullanılır; kabuğu soyulmadan kazana atılmaz.",
     ["Çin Isıran Lahanası"] = "Isırır. Ciddiyim. — P.S.",
     ["Zehirli Tentakula"] = "Dikenli, kıvrak dalları yakaladığını bırakmaz. Tohumları Bakanlık kontrolündedir.",
     ["Flitterbloom Sarmaşığı"] = "Şeytan kapanına çok benzer; ayırt etmek için dallarının ışıktan kaçıp kaçmadığına bak.",
     ["Madımak Bitkisi"] = "Knotgrass. Çok Özlü İksiri'nin sabırlı malzemesi; demet halinde kurutulur.",
     ["Pelinotu"] = "Acı bir ottur. Yaşayan Ölüm Şurubu gibi güçlü iksirlerde kullanılır.",
     ["Öten Nergis"] = "Rüzgâr değince ince bir ses çıkarır. Sınav haftasında serada konuşmayı engeller, bu yüzden pek sevilmez.",
     ["Noel Gülü"] = "Kışın açan nadir çiçeklerdendir; özü sakinleştirici iksirlere girer.",
     ["Niffler Çiçeği"] = "Parlak taç yaprakları nifflerları çeker. Bahçende bir niffler görürsen suçlu bu çiçektir.",
     ["Uyutucu Fasülye"] = "Ezilince uyuşturucu bir öz verir. Kesmek yerine bıçağın yan yüzüyle ez; özü daha çok çıkar.",
     ["Zıplayan Mantar"] = "Hasat sırasında kaçmaya çalışır. Saksıyı devirmemek için önce bir eliyle kapağı tut.",
}

/*
*   Fantastik Canavarlar: Newt'ün kenar notları ve [sardon] hayvan türleri için sınıf/metin
*/
SK.YARATIK_NOT = {
     puffskein = "Bir puffskein'i burnunuzun üstünde tutmayın; dili oraya da uzanır.",
     mooncalf = "Dolunay gecesi tarlada spiral izler görürseniz Muggle'lar uzaylı sanır. Biz bilirsiniz.",
     diricawl = "Muggle'lar onlara dodo der ve neslinin tükendiğini sanır. Diricawl'lar sadece kaybolmayı bilir.",
     jobberknoll = "Ölünce duyduğu her şeyi tersten bağırır. Hafıza iksirlerine tüyü bundan girer.",
     bowtruckle = "Bir asa ağacının bekçisidir. Ağacından dal kesecekseniz önce ona tahta biti verin.",
     giantpurpletoad = "Sanıldığından zekidir; size dil çıkarırsa büyük ihtimalle bir sebebi vardır.",
     fwooper = "Ötüşü sonunda dinleyeni çıldırtır; bu yüzden satılan fwooper'lar susturma büyüsüyle satılmalıdır.",
     kneazle = "Kedi gibidir ama kötü niyetli birini kediden iyi tanır. Size tıslıyorsa düşünün.",
     niffler = "Parlak olan her şeyi çalar. Cebinizi ters çevirin; muhtemelen bir galleon eksik.",
     hippogriff = "Asla gözünü kırpmadan önce eğil. Hipogrif selamını alırsa sırtına binebilirsin.",
     thestral = "Yalnızca ölümü görmüş olanlar onları görebilir. Kötü şans getirdikleri söylenir; getirmezler.",
     unicorn = "Tekboynuz kanı ölümü durdurur, ama bedeli lanetli bir yarım hayattır.",
     graphorn = "Derisi çoğu büyüyü geri sektirir. Dağ trolleri onlara binmeye çalışır; çoğu zaman başaramaz.",
     phoenix = "Ölmek üzereyken alev alıp küllerinden yeniden doğar. Gözyaşları şifa verir.",
}

-- [sardon] hayvan türleri: kendi açıklaması olmadığı için sınıf + metin burada
SK.HAYVAN_BILGI = {
     kurt = {3, "Ormanın kıyılarında sürüyle dolaşır. Bir kurt yalnızsa sürüsü yakındadır."},
     kurtadam = {5, "Dolunayda insan aklını kaybeden bir büyücü ya da Muggle. Isırığı laneti geçirir; Akonit İksiri dönüşümü yumuşatır."},
     grifon = {4, "Kartal başı ve aslan gövdesi. Hazine bekçisi olarak bilinir; çiğ etle beslenir."},
     mantikor = {5, "İnsan başı, aslan gövdesi, akrep kuyruğu. Kurbanını yerken mırıldanır. Derisi çoğu büyüyü geri çevirir."},
     ejderha = {5, "Evcilleştirilemez. Yumurtası ticareti 1709'dan beri yasaktır. Bir ejderhaya yaklaşmanın tek yolu birkaç büyücüyle birlikte yaklaşmaktır."},
     timsah = {3, "Bataklığın sessiz avcısı. Suyun kenarında kımıldamayan bir kütük görürsen iki kez bak."},
     akrep = {4, "Dev akreplerin zehri iksirlerde aranan bir malzemedir; onu toplamak ise ayrı bir maceradır."},
     kurbaga = {2, "Salgısı birçok iksire girer. Öptüğünüz kurbağanın prense dönüşmesini beklemeyin."},
     akbaba = {2, "Leş yiyicidir; ormanda akbaba görmek, yakında ölü bir şey olduğu anlamına gelir."},
     sahin = {2, "Fiyortların hızlı avcısı. Baykuştan hızlı uçar ama mektup taşımaz."},
     anka = {4, "Ölmek üzereyken alev alır ve küllerinden yeniden doğar."},
     kertenkele = {2, "Karnındaki ışık gece yolunu aydınlatır; küçük bir fener gibi taşınabilir."},
     tuykusu = {1, "Tüyleri yumuşak, kendisi zararsızdır. Bakanlık onu sıkıcı bulur."},
     boa = {3, "Sarıldığını kolay bırakmaz. Yılan diliyle konuşan bir büyücüye kulak verdiği söylenir."},
     devboa = {4, "Boa'nın dev akrabası. Bir ineği bütün yutabilir."},
     wyvern = {4, "Ejderhanın iki ayaklı akrabası. Kuyruğundaki diken zehirlidir."},
     wyvern_buz = {4, "Kuzey dağlarının buz nefesli wyverni."},
     wyvern_simsek = {5, "Fırtına bulutlarında doğar; kanat çırpışı şimşek çaktırır."},
     wyvern_zehir = {4, "Nefesi zehirlidir; yeşil bir duman bırakır."},
     wyvern_iskelet = {5, "Kara büyüyle diriltilmiş bir wyvern iskeleti. Ölü bir şeyin bu kadar inatçı olması iyi bir işaret değildir."},
     wyvern_tek = {4, "Tuhaf, mekanik bir wyvern. Kimin yaptığı bilinmez."},
     wyvern_dodo = {2, "Wyvern olduğunu iddia eder. Pek inandırıcı değildir."},
     yuzsaran = {5, "Kara bir pelerin gibi süzülür ve uyuyan kurbanını sessizce sarar. Ona karşı bilinen tek korunma Patronus Büyüsü'dür."},
}
